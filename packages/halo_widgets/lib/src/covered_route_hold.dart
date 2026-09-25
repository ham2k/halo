// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps a route that is covered by another route's keyboard at the height it
// had before that keyboard came up.

import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lays [child] out at the height it had before the on-screen keyboard came
/// up, clipped to what the route is actually given, while the keyboard
/// belongs to something outside this route.
///
/// The app shell shrinks the whole Navigator by the keyboard's height (the
/// status footer rides above it), so without this every route behind a
/// dialog is laid out again at the shorter size the moment the dialog's
/// field takes focus. That is wasted work on the hottest path the keyboard
/// has, and it is not harmless: a lazy list in the route behind drops the
/// rows that fall outside its cache, and a widget whose disposal has side
/// effects runs them under the dialog — a topmost AutofillGroup finishing the
/// platform's autofill context closes the dialog's own iOS keyboard.
///
/// Held here, the route sees the same constraints it had, so it is not laid
/// out at all. Its bottom sits behind the keyboard meanwhile, under whatever
/// has the keyboard.
///
/// The rule has no memory: the route holds while the keyboard is up, unless
/// the focus is inside the route on something other than a bare scope —
/// the route's own, or one nested in it. So:
/// - a route whose own field (or web view, or anything else focusable) has
///   the keyboard shrinks above it;
/// - a route behind a dialog, a Modal Pane, or a layer drawn above the
///   Navigator (onboarding) holds, current route or not;
/// - a dialog closed with its field still focused hands the focus back to
///   whatever the route below last focused; a bare scope keeps it holding
///   until the keyboard is down — the pop comes first and the keyboard
///   animates down after, and letting go at the pop would shrink the route
///   under the fading dialog and grow it back frame by frame. A focusable
///   that is not a scope (a list, a button) lets go at the pop: telling it
///   from a web view that has the keyboard is not possible from here.
///
/// The height held is the one last laid out while not holding, and it is
/// applied only at the width it was laid out at: after a rotation or resize
/// the route takes what it is offered, since a height from another layout
/// would put its content wherever that layout had it.
///
/// Every route the app shows puts its content in one of these:
/// [haloPageTransitionsTheme] for page routes, the Modal Pane routes'
/// `buildPage`, [showHaloDialog], and each hand-built route in the app, which
/// the app's `test/guards/covered_route_hold_test.dart` checks. A route
/// without one is laid out at the shrunk height like any other widget.
class HoldSizeWhileCovered extends StatefulWidget {
  final Widget child;

  const HoldSizeWhileCovered({super.key, required this.child});

  @override
  State<HoldSizeWhileCovered> createState() => _HoldSizeWhileCoveredState();
}

class _HoldSizeWhileCoveredState extends State<HoldSizeWhileCovered> with WidgetsBindingObserver {
  /// The route's own focus scope: every route wraps its content in one, and
  /// this widget sits at the root of that content, so the nearest scope IS
  /// the route's. Looked up without a dependency — the FocusManager listener
  /// already hears every focus move, and a dependency would rebuild this on
  /// each one inside the route as well.
  FocusScopeNode? _scope;
  FlutterView? _view;
  bool _hold = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_update);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = Focus.maybeOf(context, scopeOk: true, createDependency: false)?.nearestScope;
    _view = View.of(context);
    _hold = _computeHold();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The keyboard's inset lives only on the raw view: the shell removes it
  /// from the MediaQuery every route reads.
  @override
  void didChangeMetrics() => _update();

  void _update() {
    if (!mounted) return;
    final hold = _computeHold();
    if (hold != _hold) setState(() => _hold = hold);
  }

  bool _computeHold() {
    // First, and cheapest: with no keyboard there is nothing to hold against,
    // which is every frame on a desktop.
    if ((_view?.viewInsets.bottom ?? 0) <= 0) return false;
    final scope = _scope;
    if (scope == null) return false;
    // A bare scope — the route's own, or one nested in it, like the logging
    // panel's after its field lets go — types nothing.
    return !(scope.hasFocus && FocusManager.instance.primaryFocus is! FocusScopeNode);
  }

  @override
  Widget build(BuildContext context) => _HoldHeight(hold: _hold, child: widget.child);
}

class _HoldHeight extends SingleChildRenderObjectWidget {
  final bool hold;

  const _HoldHeight({required this.hold, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoldHeight(hold);

  @override
  void updateRenderObject(BuildContext context, _RenderHoldHeight renderObject) => renderObject.hold = hold;
}

class _RenderHoldHeight extends RenderProxyBox {
  _RenderHoldHeight(this._hold);

  bool _hold;
  bool get hold => _hold;
  set hold(bool value) {
    if (value == _hold) return;
    _hold = value;
    markNeedsLayout();
  }

  /// The constraints last offered while not holding.
  BoxConstraints? _uncovered;
  bool _clipped = false;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  /// What the child is given: [constraints] as offered, or — held, at the
  /// width the uncovered height was measured at, and offered less height
  /// than that — the same width rules with the uncovered height. A tight
  /// height stays tight at that value, which is what makes the child's
  /// constraints identical to its last uncovered layout.
  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final uncovered = _uncovered;
    if (!_hold || uncovered == null || !constraints.hasBoundedHeight) return constraints;
    if (uncovered.maxWidth != constraints.maxWidth || uncovered.maxHeight <= constraints.maxHeight) return constraints;
    final held = uncovered.maxHeight;
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: constraints.minHeight == constraints.maxHeight ? held : constraints.minHeight,
      maxHeight: held,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(_childConstraints(constraints)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    if (!_hold && constraints.hasBoundedHeight) _uncovered = constraints;
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
    _clipped = child.size.height > size.height;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (!_clipped) {
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint, oldLayer: _clipLayer.layer);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _clipped ? Offset.zero & size : null;

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// Puts [inner]'s transition inside a [HoldSizeWhileCovered].
class _HoldingPageTransitionsBuilder extends PageTransitionsBuilder {
  final PageTransitionsBuilder inner;

  const _HoldingPageTransitionsBuilder(this.inner);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      // Outside the transition, not inside: a transition may change the shape
      // of its own tree mid-route (Android's predictive back does, when a
      // gesture starts or ends), and a hold rebuilt there loses the height it
      // was holding.
      HoldSizeWhileCovered(child: inner.buildTransitions<T>(route, context, animation, secondaryAnimation, child));
}

/// Flutter's default page transitions, each inside a [HoldSizeWhileCovered]
/// — how every `MaterialPageRoute` gets one without each push site having to
/// remember.
final PageTransitionsTheme haloPageTransitionsTheme = PageTransitionsTheme(
  builders: {for (final entry in const PageTransitionsTheme().builders.entries) entry.key: _HoldingPageTransitionsBuilder(entry.value)},
);
