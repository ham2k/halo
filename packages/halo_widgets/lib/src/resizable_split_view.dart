// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The side-by-side pane split of docs/design/layouts.md: a primary pane at a
// preferred width and a secondary pane taking the rest — ALL of the rest:
// the divider consumes no layout space. It is a transparent drag overlay on
// the secondary's leftmost `dividerWidth` pixels (so tab strips, headers,
// and backgrounds stretch to the very boundary), the boundary itself is
// drawn by the shadow the divider casts rightward onto the secondary (a
// glow in dark mode), and secondary content that wants clearance from the
// grab area pads itself. Pass
// `secondary: null` on single-pane shirt sizes instead of swapping widget
// trees — the primary subtree stays mounted across the flip (scroll
// positions and in-progress input survive) and its width animates between
// full-width and the preferred width.
//
// The preferred width is a USER PREFERENCE owned by the caller (persisted
// via SettingsService.layoutDimension): it flows in through
// `preferredPrimaryWidth` and back out through
// `onPreferredPrimaryWidthChanged`, which fires on drag end only. When the
// window is too small for the preference it is clamped for layout — never
// written back — so a temporarily small window can't corrupt the setting.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'ui_scale.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget primary;

  /// The expanding right-side pane, or null to let [primary] fill the width.
  final Widget? secondary;

  /// The caller-owned preferred width for [primary] (see the header
  /// comment), or null when the user has never dragged this divider — the
  /// primary then defaults to about two thirds of the available width,
  /// capped at [ShirtSize.sMax] (issue #85 follow-up).
  final double? preferredPrimaryWidth;

  final double minPrimaryWidth;
  final double maxPrimaryWidth;
  final double minSecondaryWidth;

  /// Fired with the new preferred width when a divider drag ends.
  final ValueChanged<double>? onPreferredPrimaryWidthChanged;

  const ResizableSplitView({
    super.key,
    required this.primary,
    this.secondary,
    this.preferredPrimaryWidth,
    this.minPrimaryWidth = minPaneWidth,
    this.maxPrimaryWidth = double.infinity,
    this.minSecondaryWidth = minPaneWidth,
    this.onPreferredPrimaryWidthChanged,
  });

  /// Width of the divider's transparent grab/hover strip, overlaid on the
  /// secondary pane's left edge (no layout space of its own).
  static const double dividerWidth = 11.0;

  /// Width of the shadow (glow, in dark mode) the divider casts rightward
  /// onto the secondary pane. Pure paint (rendered under an IgnorePointer),
  /// so controls and scrollbars underneath stay fully clickable.
  static const double dividerShadowWidth = 12.0;

  /// The shadow gradient's strongest alpha, at the divider edge. The dark-
  /// mode glow needs less strength than the light-mode shadow to read as
  /// the same weight.
  static const double dividerShadowAlpha = 0.16;
  static const double dividerShadowAlphaDark = 0.10;

  /// LOAD-BEARING, not decoration: the engine only routes pointer events
  /// over a native platform view (the Mapbox webview) back to Flutter where
  /// Flutter has PAINTED above it — an unpainted strip would let the native
  /// view take the events and pan the map instead of dragging the divider.
  /// Painting the strip at this near-invisible alpha claims it. Do NOT
  /// "clean up" the wash; no widget test can catch its removal (platform-
  /// view hit routing isn't exercisable in tests).
  static const double _platformViewHitWashAlpha = 0.001;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  /// Null until the user drags (or the caller supplies a persisted width) —
  /// layout then uses the 2/3-capped-at-sMax default computed per build.
  late double? _preferredWidth = widget.preferredPrimaryWidth;
  bool _dragging = false;

  /// What the primary actually measured in the latest build — the seed for
  /// a drag that starts while no preference exists yet. Overwritten by
  /// every build before any drag can begin (the handle must be laid out to
  /// be hit), so the initializer is never observed.
  double _effectiveWidthForDrag = 0;

  /// The preference as it was when the current drag started, restored if
  /// the gesture turns out to be a mere click or gets cancelled — a click
  /// must not convert the adaptive null-preference default into a
  /// persisted fixed width.
  double? _preferredBeforeDrag;
  bool _dragMoved = false;

  /// The UNCLAMPED drag position, tracking the pointer 1:1 including
  /// overshoot past the limits. The divider lays out (and persists) the
  /// clamped [_preferredWidth]; accumulating the overshoot here means a
  /// direction reversal is ignored until the pointer has traveled back to
  /// the divider — without it, the divider would start moving the instant
  /// the mouse reverses, far away from the cursor.
  double _dragPosition = 0;

  /// The available width from the previous build — a change means the
  /// WINDOW is being resized, and widths must track it instantly (see
  /// build); only preference changes and mode flips animate.
  double? _lastTotal;

  /// The clamp bounds from the most recent layout, so drag updates (which
  /// happen outside build) keep the laid-out and persisted width inside
  /// what currently fits — only [_dragPosition] deliberately runs past
  /// them.
  double _dragLowerBound = minPaneWidth;
  double _dragUpperBound = double.infinity;

  @override
  void didUpdateWidget(ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Flipping to single-pane unmounts the handle without an onCancel, so
    // a drag in progress at that moment would leave _dragging stuck true
    // (killing animations and external syncs forever) — treat it as a
    // cancelled gesture.
    if (widget.secondary == null && _dragging) {
      _dragging = false;
      _preferredWidth = _preferredBeforeDrag;
    }
    // An external preference change (another window, a settings reset) wins
    // unless the user is mid-drag right here.
    if (!_dragging && widget.preferredPrimaryWidth != oldWidget.preferredPrimaryWidth) {
      _preferredWidth = widget.preferredPrimaryWidth;
    }
  }

  void _handleDragStart() {
    setState(() {
      _dragging = true;
      _dragMoved = false;
      _preferredBeforeDrag = _preferredWidth;
      // Turn the default into an explicit base so deltas can accumulate;
      // reverted unless the gesture actually moves.
      _preferredWidth ??= _effectiveWidthForDrag;
      // The pointer starts ON the divider: virtual position = actual.
      _dragPosition = _preferredWidth!.clamp(_dragLowerBound, _dragUpperBound);
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragMoved = true;
      _dragPosition += details.delta.dx;
      _preferredWidth = _dragPosition.clamp(_dragLowerBound, _dragUpperBound);
    });
  }

  void _handleDragEnd() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      // A mere click (down + up, no movement) is not a resize: restore the
      // pre-drag preference — in particular, don't convert the adaptive
      // null-preference default into a persisted fixed width.
      if (!_dragMoved) _preferredWidth = _preferredBeforeDrag;
    });
    if (_dragMoved) {
      // Whole pixels only — the layout below rounds anyway, and a
      // fractional persisted width would just come back as a rounding
      // no-op. Non-null: _dragMoved implies a seeded, updated preference.
      widget.onPreferredPrimaryWidthChanged?.call(_preferredWidth!.roundToDouble());
    }
  }

  void _handleDragCancel() {
    // Cancels can arrive WITHOUT a preceding start (pointer cancelled
    // before arena resolution) — nothing to revert or persist then.
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _preferredWidth = _preferredBeforeDrag;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final lower = widget.minPrimaryWidth;
        // The grab strip overlays the secondary's leftmost pixels, so the
        // bound reserves dividerWidth on top of minSecondaryWidth — at max
        // drag the secondary still has its full minimum USABLE. The window
        // may be too small to honor both minimums; the primary's minimum
        // wins (upper >= lower keeps clamp() valid).
        final upper = math.max(
          lower,
          math.min(widget.maxPrimaryWidth, total - widget.minSecondaryWidth - ResizableSplitView.dividerWidth),
        );
        _dragLowerBound = lower;
        _dragUpperBound = upper;
        // Pane edges snap to whole DEVICE pixels: one logical (UiScale-
        // divided) px paints as `UiScale × devicePixelRatio` device px, and
        // an edge that lands between device pixels antialiases against the
        // neighboring pane as a hairline seam along the divider. Snapping
        // whole logical pixels isn't enough — at a non-1.0 font scale those
        // still land off the device grid.
        final grid = UiScale.of(context) * MediaQuery.devicePixelRatioOf(context);
        double snapRound(double v) => (v * grid).roundToDouble() / grid;
        double snapFloor(double v) => (v * grid).floorToDouble() / grid;
        // No preference yet → the primary takes about two thirds of the
        // width, never more than sMax (the widest a single-pane phone
        // layout gets — content designed for a pane reads fine up to
        // there).
        final preferred = _preferredWidth ?? math.min(total * 2 / 3, ShirtSize.sMax);
        final effectiveWidth = snapRound(preferred.clamp(lower, upper).toDouble());
        _effectiveWidthForDrag = effectiveWidth;

        final twoPane = widget.secondary != null;
        // Snap 1:1 with the pointer while dragging, and track a live WINDOW
        // resize instantly — animating toward a moving `total` would lag
        // behind the window edge, exposing a trailing strip of background
        // for the animation's duration after every grow. Animation is for
        // mode flips and external preference changes at a stable size.
        final resized = _lastTotal != null && _lastTotal != total;
        _lastTotal = total;
        final duration = (_dragging || resized) ? Duration.zero : layoutAnimationDuration;
        // In dark mode a black shadow disappears into dark pane surfaces —
        // the boundary reads better as a light "shadow" (a glow) instead,
        // and the hairline flips the other way: dark gray on light
        // surfaces, lighter gray on dark ones.
        final theme = Theme.of(context);
        final dark = theme.brightness == Brightness.dark;
        final shadowColor = dark ? Colors.white : theme.colorScheme.shadow;
        // The hairline only exists in dark mode, where the subdued glow
        // alone doesn't mark the boundary crisply enough; in light mode the
        // shadow does the whole job.
        final borderColor = dark ? Colors.grey.shade700 : null;
        final shadowAlpha = dark ? ResizableSplitView.dividerShadowAlphaDark : ResizableSplitView.dividerShadowAlpha;

        // The divider owns NO layout space: the secondary pane stretches to
        // the primary's very edge and the handle is a transparent overlay
        // on its leftmost pixels (secondary content pads itself if it needs
        // clearance — see the class doc). With no divider slot there is no
        // primary + divider sum to overflow; the per-frame cap below only
        // guards an abrupt window shrink outrunning the tween.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: twoPane ? effectiveWidth : total),
              duration: duration,
              curve: layoutAnimationCurve,
              builder: (context, width, child) {
                // Every boundary snaps to the device grid (see the
                // effectiveWidth comment above) — mid-animation included;
                // FLOORED so snapping can't exceed `total` (in-flight tween
                // values during an abrupt shrink, or a tiny window where
                // minPrimaryWidth > total), and exactly `total` at
                // single-pane rest so no right-edge gap.
                return SizedBox(width: width >= total ? total : snapFloor(width), child: child);
              },
              child: widget.primary,
            ),
            Expanded(
              child: widget.secondary == null
                  ? const SizedBox.shrink()
                  : Stack(
                      children: [
                        Positioned.fill(
                          // Advisory clearance: the grab strip owns the
                          // pane's leftmost pixels, so content that needs
                          // clicks/hover near that edge reads
                          // PaneSafeArea.leftOf(context) and pads itself —
                          // backgrounds and rows still render edge-to-edge.
                          child: PaneSafeArea(left: ResizableSplitView.dividerWidth, child: widget.secondary!),
                        ),
                        // The divider casts its shadow (a glow in dark
                        // mode) RIGHTWARD onto the secondary pane — the
                        // primary stays untouched. Paint-only: IgnorePointer
                        // keeps everything under it clickable; only the
                        // grab strip below intercepts.
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: ResizableSplitView.dividerShadowWidth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    shadowColor.withValues(alpha: shadowAlpha),
                                    shadowColor.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // A crisp hairline at the boundary itself, on top
                        // of the glow's brightest edge (dark mode only).
                        if (borderColor != null)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 1,
                            child: IgnorePointer(child: ColoredBox(color: borderColor)),
                          ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: ResizableSplitView.dividerWidth,
                          child: _DividerHandle(
                            onDragStart: _handleDragStart,
                            onDragUpdate: _handleDragUpdate,
                            onDragEnd: _handleDragEnd,
                            onDragCancel: _handleDragCancel,
                            dragging: _dragging,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Advisory clearance a split pane's content can read: the divider's grab
/// strip overlays the secondary pane's edge pixels, so controls that need
/// clicks or hover near that edge should inset by [left]/[right] —
/// backgrounds, ink, and rows still render edge-to-edge, only their content
/// shifts. Zero when not inside a split (single-pane layouts, the narrow
/// arrangements), so consumers can read it unconditionally.
class PaneSafeArea extends InheritedWidget {
  final double left;
  final double right;

  const PaneSafeArea({super.key, this.left = 0, this.right = 0, required super.child});

  static PaneSafeArea? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PaneSafeArea>();

  static double leftOf(BuildContext context) => maybeOf(context)?.left ?? 0;

  static double rightOf(BuildContext context) => maybeOf(context)?.right ?? 0;

  @override
  bool updateShouldNotify(PaneSafeArea oldWidget) => left != oldWidget.left || right != oldWidget.right;
}

class _DividerHandle extends StatefulWidget {
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  /// Keeps the dots at full strength while a drag is in progress even if
  /// the pointer overshoots off the strip (which would end the hover).
  final bool dragging;

  const _DividerHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.dragging,
  });

  /// The grab dots' resting opacity; hovering (or dragging) raises them to
  /// full strength.
  static const double restingDotOpacity = 0.5;

  @override
  State<_DividerHandle> createState() => _DividerHandleState();
}

class _DividerHandleState extends State<_DividerHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Pointer deltas arrive already in the UiScale-divided space (the whole
    // tree, gestures included, lives inside the FittedBox transform), so no
    // scale math here.
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => widget.onDragStart(),
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        onHorizontalDragCancel: widget.onDragCancel,
        // Visually transparent: the secondary pane's own background shows
        // through (its content stretches to the very edge — tabs, headers,
        // all of it), and the drop shadow on the primary marks the
        // boundary. The wash is NOT decoration — see
        // [ResizableSplitView._platformViewHitWashAlpha].
        child: SizedBox(
          width: ResizableSplitView.dividerWidth,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: ResizableSplitView._platformViewHitWashAlpha),
            child: Center(
              // Subdued until the pointer is over the strip (or dragging):
              // the dots are an invitation, not furniture. Light mode dims
              // them via opacity; dark mode instead rests them at pure
              // black and lets hover bring up the usual light color (a
              // half-transparent light dot would just vanish against the
              // glow). Hover changes never coincide with the resize-snap
              // frames, so these transitions actually play (unlike
              // flip-driven ones).
              child: Builder(
                builder: (context) {
                  final dark = Theme.of(context).brightness == Brightness.dark;
                  final active = _hovered || widget.dragging;
                  final opacity = active || dark ? 1.0 : _DividerHandle.restingDotOpacity;
                  final dotColor = dark && !active ? Colors.black : colors.onSurfaceVariant;
                  return AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 2.5),
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
