// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A dock pane shown full size (docs/design/layouts.md, "Full size"): the same
// pane, moved out of its slot into a card covering most of the window, under
// a title bar drawn like the pane's own with a close box at its end.
//
// Drawn in the dock's own Stack, over its panes, not pushed as a route. The
// view holding the dock stays the current route, so whatever it does only
// while it is current — CW and VFO keys, the keep-awake hold — goes on with a
// pane full size, and the card is under everything the view wraps its dock
// in: its theme, density and font scale, its pointer listener, the Offstage
// of a hidden destination. It also takes the host's latest props in the same
// build as everything else.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dock_tab.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';
import 'platform_chrome.dart' show isMobilePlatform;
import 'platform_view_shield.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'spacing.dart';
import 'theme.dart';
import 'ui_scale.dart' show PixelGrid;

/// Calls [onDoubleTap] on a second tap close in time and place to the first,
/// without entering the gesture arena.
///
/// A [GestureDetector]'s `onDoubleTap` holds the arena until the double-tap
/// timeout passes, so every single tap on what it wraps would answer that
/// much late. This only watches pointers go by.
///
/// Pointers only: a semantics tap (a screen reader, or a click on a button
/// node with the web's accessibility DOM on) never reaches it. Wrap what has
/// no tap of its own — a title — and count a button's taps from its own
/// callback instead.
class DoubleTapListener extends StatefulWidget {
  final VoidCallback? onDoubleTap;
  final Widget child;

  const DoubleTapListener({super.key, required this.onDoubleTap, required this.child});

  /// [child] — a button inside a [DoubleTapListener] — with its taps kept
  /// from counting: a quick double click on a title's action runs the
  /// action, and must not also enlarge or close the pane.
  static Widget exclude({required Widget child}) => Listener(
    // Dispatched before the enclosing listener's, which is further up the
    // hit-test path.
    onPointerDown: (event) => _excluded.add(event.pointer),
    // Forgotten once the pointer is up, for a button with no listener
    // around it to take its mark away.
    onPointerUp: (event) => _excluded.remove(event.pointer),
    onPointerCancel: (event) => _excluded.remove(event.pointer),
    child: child,
  );

  static final Set<int> _excluded = {};

  @override
  State<DoubleTapListener> createState() => _DoubleTapListenerState();
}

class _DoubleTapListenerState extends State<DoubleTapListener> {
  int? _pointer;
  Offset? _downAt;

  /// Where the first tap of a pair ended, while a second can still follow it.
  Offset? _firstTapAt;

  /// A timer, not a comparison of event timestamps: a test's synthesized
  /// pointer events all carry the same timestamp, so two taps a second apart
  /// would read as a double tap.
  Timer? _window;

  void _reset() {
    _window?.cancel();
    _window = null;
    _firstTapAt = null;
  }

  @override
  void dispose() {
    _window?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onDoubleTap == null) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (DoubleTapListener._excluded.remove(event.pointer)) return _reset();
        if (_pointer != null || event.buttons != kPrimaryButton) return;
        _pointer = event.pointer;
        _downAt = event.position;
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _pointer = null;
      },
      onPointerUp: (event) {
        if (event.pointer != _pointer) return;
        _pointer = null;
        // A drag is not a tap, and ends any pair it interrupts.
        if ((event.position - _downAt!).distance > kTouchSlop) return _reset();
        final first = _firstTapAt;
        if (first != null && (event.position - first).distance <= kDoubleTapSlop) {
          _reset();
          widget.onDoubleTap?.call();
          return;
        }
        _reset();
        _firstTapAt = event.position;
        _window = Timer(kDoubleTapTimeout, _reset);
      },
      child: widget.child,
    );
  }
}

/// The full-size card and the barrier around it, laid over the dock's own
/// area. Inside the dock rather than over the window: it is under whatever
/// the view puts around its dock — its font scale, its activity listener,
/// the Offstage a hidden destination sits in — and the view's header stays
/// where it is.
///
/// The keyboard is the dock's to hand over: [scope] is its node, and the
/// dock decides when the card takes focus and where it goes back to
/// ([DockLayoutViewState.showFullSize]).
class DockFullSizeView extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget pane;
  final String closeLabel;
  final VoidCallback onClose;
  final FocusScopeNode scope;

  /// See [DockLayoutView.fullSizeEscapeClaimed].
  final bool Function()? escapeClaimed;

  const DockFullSizeView({
    super.key,
    required this.title,
    required this.action,
    required this.pane,
    required this.closeLabel,
    required this.onClose,
    required this.scope,
    this.escapeClaimed,
  });

  @override
  Widget build(BuildContext context) {
    // Checked on every build: a dock its host keeps across the S/L boundary
    // re-presents the pane in place. (The app's hosts swap docks there, which
    // closes the card.)
    final dialog = ShirtSize.of(context).isTwoPane;
    final pane = Material(
      // InkWell content paints its splashes on the nearest Material.
      color: Theme.of(context).colorScheme.surface,
      // The card keeps the dock's insets clear itself (below), so the pane
      // inside it has none of its own to keep.
      child: PaneSafeArea(child: this.pane),
    );
    return FocusScope(
      node: scope,
      // Last in line: a dialog over the card has the keyboard to itself, and
      // whatever in the pane answers Escape — a menu, an open control — has
      // had it first. What reaches here was spent on nothing, unless it
      // stopped a transmission.
      onKeyEvent: (node, event) {
        if (!const SingleActivator(LogicalKeyboardKey.escape).accepts(event, HardwareKeyboard.instance)) return KeyEventResult.ignored;
        if (!(escapeClaimed?.call() ?? false)) onClose();
        return KeyEventResult.handled;
      },
      child: dialog ? _buildDialog(context, pane) : _buildFullScreen(context, pane),
    );
  }

  /// Fills the dock, clear of the insets its panes keep (a phone's home
  /// indicator, a notch at the side).
  Widget _buildFullScreen(BuildContext context, Widget pane) => PlatformViewShield(
    child: Padding(
      padding: EdgeInsets.only(left: PaneSafeArea.leftOf(context), right: PaneSafeArea.rightOf(context), bottom: PaneSafeArea.bottomOf(context)),
      child: _card(context, pane),
    ),
  );

  Widget _buildDialog(BuildContext context, Widget pane) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The barrier. Gesture plumbing only: a dock-sized button node in
        // front of a platform view on the web takes every click meant for
        // it, and the close box is the pane's dismissal for a screen reader.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          excludeFromSemantics: true,
          child: PlatformViewShield(child: ColoredBox(color: haloBarrierColor(context))),
        ),
        Padding(
          // A dialog's margins: its side inset, and a little above and below,
          // since the view's header already keeps the card off the window's
          // top edge. On a phone or tablet, the same margin all round.
          padding: isMobilePlatform ? const EdgeInsets.all(Space.xl) : const EdgeInsets.symmetric(horizontal: dialogSideInset, vertical: Space.xl),
          child: PlatformViewShield(
            child: Material(
              color: theme.colorScheme.surface,
              elevation: modalSurfaceElevation,
              shadowColor: haloDialogShadowColor,
              surfaceTintColor: theme.colorScheme.surfaceTint,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: _card(context, pane, titleInset: Space.md),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Widget pane, {double titleInset = 0}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
          // Clear of a rounded card's corners at either end.
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: titleInset),
            child: _titleBar(context),
          ),
        ),
        Expanded(child: pane),
      ],
    );
  }

  /// The pane's own title bar — the same [DockTab] a pane alone in its group
  /// is headed by — with the close box at its far end.
  Widget _titleBar(BuildContext context) {
    final theme = Theme.of(context);
    final onHeader = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final height = PixelGrid.of(context).snap(DockTab.stripHeightOf(context));
    return DoubleTapListener(
      onDoubleTap: onClose,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DockTab(
                title: title,
                selected: true,
                editing: false,
                solo: true,
                isFirst: true,
                isLast: true,
                showHandle: false,
                pinned: false,
                action: action,
                onTap: () {},
                moduleId: '',
                onDragStarted: (_) {},
                onDragEnded: () {},
              ),
            ),
            DoubleTapListener.exclude(
              child: IconButton(
                icon: Icon(MdiIcons.close, semanticLabel: closeLabel),
                color: onHeader,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: height, height: height),
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
