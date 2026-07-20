// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The SOLID pane divider — the default separator between side-by-side (or
// stacked) panes: a header-colored bar of [paneDividerWidth] that owns its
// own layout space. No overlay, no drop shadow; the alternative "surfaces"
// style (the shadow-casting overlay divider) lives in
// resizable_split_view.dart and is opt-in per view — see
// docs/design/layouts.md.
//
// Shared by ResizableSplitView (solid style) and the dock layout's split
// dividers so both split systems keep one visual language. Being an opaque
// painted bar, it needs no platform-view hit wash: its own surface claims
// pointer events even next to the native map view.

import 'package:flutter/material.dart';

import 'layout.dart';

class SolidPaneDivider extends StatefulWidget {
  /// The axis the divider moves ALONG: [Axis.horizontal] separates
  /// side-by-side panes (a vertical bar, left-right drag), [Axis.vertical]
  /// separates stacked panes (a horizontal bar, up-down drag). Matches the
  /// axis of the split that owns it.
  final Axis axis;

  final VoidCallback? onDragStart;

  /// Pointer delta along [axis], in logical pixels (already in the
  /// UiScale-divided space — see resizable_split_view.dart's note).
  final ValueChanged<double> onDragUpdate;

  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  /// Keeps the grab dots at full strength while a drag is in progress even
  /// if the pointer overshoots off the bar (which would end the hover).
  final bool dragging;

  const SolidPaneDivider({
    super.key,
    required this.axis,
    required this.onDragUpdate,
    this.onDragStart,
    this.onDragEnd,
    this.onDragCancel,
    this.dragging = false,
  });

  /// The grab dots' resting opacity; hovering (or dragging) raises them to
  /// full strength — same invitation-not-furniture treatment as the
  /// surfaces divider's dots.
  static const double restingDotOpacity = 0.5;

  @override
  State<SolidPaneDivider> createState() => _SolidPaneDividerState();
}

class _SolidPaneDividerState extends State<SolidPaneDivider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontal = widget.axis == Axis.horizontal;
    // The header's own surface: the divider reads as chrome, not content.
    final barColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final active = _hovered || widget.dragging;
    final dotColor = theme.colorScheme.onPrimary;
    final dots = AnimatedOpacity(
      opacity: active ? 1.0 : SolidPaneDivider.restingDotOpacity,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Flex(
        direction: widget.axis == Axis.horizontal ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
        ],
      ),
    );
    return MouseRegion(
      cursor: horizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: horizontal ? (_) => widget.onDragStart?.call() : null,
        onHorizontalDragUpdate: horizontal ? (d) => widget.onDragUpdate(d.delta.dx) : null,
        onHorizontalDragEnd: horizontal ? (_) => widget.onDragEnd?.call() : null,
        onHorizontalDragCancel: horizontal ? () => widget.onDragCancel?.call() : null,
        onVerticalDragStart: horizontal ? null : (_) => widget.onDragStart?.call(),
        onVerticalDragUpdate: horizontal ? null : (d) => widget.onDragUpdate(d.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => widget.onDragEnd?.call(),
        onVerticalDragCancel: horizontal ? null : () => widget.onDragCancel?.call(),
        child: Container(
          width: horizontal ? paneDividerWidth : null,
          height: horizontal ? null : paneDividerWidth,
          color: barColor,
          child: Center(child: dots),
        ),
      ),
    );
  }
}
