// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The side-by-side pane split of docs/design/layouts.md: a primary pane at a
// preferred width, a draggable divider handle, and a secondary pane taking
// the rest. Pass `secondary: null` on single-pane shirt sizes instead of
// swapping widget trees — the primary subtree stays mounted across the flip
// (scroll positions and in-progress input survive) and its width animates
// between full-width and the preferred width.
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

  /// The caller-owned preferred width for [primary]; see the header comment.
  final double preferredPrimaryWidth;

  final double minPrimaryWidth;
  final double maxPrimaryWidth;
  final double minSecondaryWidth;

  /// Fired with the new preferred width when a divider drag ends.
  final ValueChanged<double>? onPreferredPrimaryWidthChanged;

  const ResizableSplitView({
    super.key,
    required this.primary,
    this.secondary,
    this.preferredPrimaryWidth = idealPaneWidth,
    this.minPrimaryWidth = minPaneWidth,
    this.maxPrimaryWidth = double.infinity,
    this.minSecondaryWidth = minPaneWidth,
    this.onPreferredPrimaryWidthChanged,
  });

  /// Width consumed by the divider handle: a 1px line centered in a wider
  /// grab/hover target.
  static const double dividerWidth = 9.0;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _preferredWidth = widget.preferredPrimaryWidth;
  bool _dragging = false;

  /// The available width from the previous build — a change means the
  /// WINDOW is being resized, and widths must track it instantly (see
  /// build); only preference changes and mode flips animate.
  double? _lastTotal;

  /// The clamp bounds from the most recent layout, so drag updates (which
  /// happen outside build) can keep the width inside what currently fits —
  /// otherwise overshooting the edge would accumulate invisible width that
  /// the user has to drag back through, and would persist out-of-range.
  double _dragLowerBound = minPaneWidth;
  double _dragUpperBound = double.infinity;

  @override
  void didUpdateWidget(ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An external preference change (another window, a settings reset) wins
    // unless the user is mid-drag right here.
    if (!_dragging && widget.preferredPrimaryWidth != oldWidget.preferredPrimaryWidth) {
      _preferredWidth = widget.preferredPrimaryWidth;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _preferredWidth = (_preferredWidth + details.delta.dx).clamp(_dragLowerBound, _dragUpperBound);
    });
  }

  void _handleDragEnd() {
    setState(() => _dragging = false);
    // Whole pixels only — the layout below rounds anyway, and a fractional
    // persisted width would just come back as a rounding no-op.
    widget.onPreferredPrimaryWidthChanged?.call(_preferredWidth.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final lower = widget.minPrimaryWidth;
        // The window may be too small to honor both minimums; the primary's
        // minimum wins (upper >= lower keeps clamp() valid).
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
        final effectiveWidth = snapRound(_preferredWidth.clamp(lower, upper).toDouble());

        final twoPane = widget.secondary != null;
        // Snap 1:1 with the pointer while dragging, and track a live WINDOW
        // resize instantly — animating toward a moving `total` would lag
        // behind the window edge, exposing a trailing strip of background
        // for the animation's duration after every grow. Animation is for
        // mode flips and external preference changes at a stable size.
        final resized = _lastTotal != null && _lastTotal != total;
        _lastTotal = total;
        final duration = (_dragging || resized) ? Duration.zero : layoutAnimationDuration;

        // The divider slot and the Expanded secondary slot stay mounted even
        // when single-pane (at zero width), so the pane widths ANIMATE on a
        // shirt-size flip — implicit animations only tween on widgets that
        // were already in the tree. The outer tween drives the divider's
        // in-flight width; the primary is capped per FRAME at
        // `total - that width`, so primary + divider can never exceed the
        // Row (a RenderFlex overflow) — not mid-flip, and not when the
        // window shrinks abruptly while a tween catches up.
        // (AnimatedContainer can't do this — it only clamps the target.)
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: twoPane ? ResizableSplitView.dividerWidth : 0.0),
          duration: duration,
          curve: layoutAnimationCurve,
          builder: (context, animatedDividerWidth, _) {
            // Every horizontal boundary snaps to the device grid (see the
            // effectiveWidth comment above) — mid-animation included. The
            // primary FLOORS its cap so snapping can never re-introduce the
            // sum-exceeds-total overflow; at rest the cap is exactly `total`
            // (single-pane) or inactive, so nothing is lost to the floor.
            final dividerSlot = snapRound(animatedDividerWidth);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: twoPane ? effectiveWidth : total),
                  duration: duration,
                  curve: layoutAnimationCurve,
                  builder: (context, width, child) {
                    final capped = math.min(width, total - dividerSlot);
                    return SizedBox(width: capped >= total ? total : snapFloor(capped), child: child);
                  },
                  child: widget.primary,
                ),
                SizedBox(
                  width: dividerSlot,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: ResizableSplitView.dividerWidth,
                      minWidth: ResizableSplitView.dividerWidth,
                      child: twoPane
                          ? _DividerHandle(
                              onDragStart: () => setState(() => _dragging = true),
                              onDragUpdate: _handleDragUpdate,
                              onDragEnd: _handleDragEnd,
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(child: widget.secondary == null ? const SizedBox.shrink() : widget.secondary!),
              ],
            );
          },
        );
      },
    );
  }
}

class _DividerHandle extends StatelessWidget {
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  const _DividerHandle({required this.onDragStart, required this.onDragUpdate, required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Pointer deltas arrive already in the UiScale-divided space (the whole
    // tree, gestures included, lives inside the FittedBox transform), so no
    // scale math here.
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: (_) => onDragEnd(),
        onHorizontalDragCancel: onDragEnd,
        // A solid primary strip edge to edge, with contrasting dots centered
        // as the grab affordance. The whole strip is draggable; the dots are
        // just the visual invitation.
        child: Container(
          width: ResizableSplitView.dividerWidth,
          color: colors.primary,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 2.5),
                  decoration: BoxDecoration(color: colors.onPrimary, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
