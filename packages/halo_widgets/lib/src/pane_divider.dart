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
// dividers so both split systems keep one visual language. The bar's own
// surface is only a few device pixels wide, so it drives its drag from a
// root-level capture overlay rather than its own hit-testing once the
// pointer is down — see _SolidPaneDividerState's field doc.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'platform_chrome.dart';

/// Thickness of the SOLID pane divider — the default separator between
/// side-by-side panes: a header-colored bar that owns its own layout space
/// (no overlay, no shadow). Shared by ResizableSplitView's solid style and
/// the dock layout's split dividers so the two systems can't drift apart
/// visually.
///
/// It widens on two axes. A fingertip lands where a mouse pointer does not,
/// so the mobile PLATFORMS get a few pixels more everywhere — `isMobilePlatform`,
/// i.e. iOS or Android and not web, the same gate `LayoutDensity` uses for
/// its own touch minimum. A touch tablet running the web build reads as a
/// pointer here; nothing in this codebase sizes for touch on web, and a
/// layout that guessed from the last pointer kind would change width under
/// the operator mid-session.
///
/// The second axis is edit mode: while a layout is being EDITED the divider
/// is one of the gestures on offer, competing with pane drags for the same
/// pointer, so it advertises itself as a grab target rather than reading as
/// furniture between panes. A caller may not be able to afford the full
/// editing width — see the dock's `_dividerExtentFor`.
///
/// Plain logical pixels (docs/design/ui-scaling.md rule 4): never multiply
/// by the font scale.
double paneDividerWidth({bool editing = false}) => editing
    ? (isMobilePlatform ? 16.0 : 11.0)
    : (isMobilePlatform ? 9.0 : 7.0);

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

  /// Keeps the grab line at full strength while a drag is in progress even
  /// if the pointer overshoots off the bar (which would end the hover).
  final bool dragging;

  /// The bar's thickness across [axis] — [paneDividerWidth] for the mode the
  /// owning layout is in, DEVICE-PIXEL-SNAPPED by the caller (see `PixelGrid`)
  /// so the bar's far edge lands on the grid too: the near edge being snapped
  /// is only half the boundary, and an off-grid far edge is a hairline seam
  /// against the next pane just the same.
  ///
  /// Required, with no default of its own. Only the owner knows whether its
  /// layout is being edited and what its splits can afford, and a default
  /// here would silently render one bar at the resting width beside dividers
  /// that widened — unsnapped, at that.
  final double extent;

  const SolidPaneDivider({
    super.key,
    required this.axis,
    required this.onDragUpdate,
    required this.extent,
    this.onDragStart,
    this.onDragEnd,
    this.onDragCancel,
    this.dragging = false,
  });

  /// The grab line's resting opacity; hovering (or dragging) raises it to
  /// full strength — same invitation-not-furniture treatment as the
  /// surfaces divider's own grab line.
  static const double restingLineOpacity = 0.5;

  @override
  State<SolidPaneDivider> createState() => _SolidPaneDividerState();
}

class _SolidPaneDividerState extends State<SolidPaneDivider> {
  bool _hovered = false;

  /// Non-null for the duration of a drag: a root-level, PURELY VISUAL
  /// overlay entry that covers the ENTIRE window, above every platform view
  /// (the map webview) regardless of where in the tree it lives. The bar
  /// itself is only a few device pixels wide — a fast drag routinely puts
  /// the pointer well past it, and if that lands on a native platform view,
  /// the OS can hand subsequent events (including the terminating mouse-up)
  /// straight to the platform view instead of Flutter, leaving the drag
  /// stuck "active" forever.
  ///
  /// The overlay does NOT itself receive pointer events: Flutter hit-tests a
  /// pointer once, at its PointerDownEvent, and routes every later event of
  /// that same gesture to that cached target regardless of where the cursor
  /// currently is — inserting a new widget mid-gesture doesn't change that.
  /// So the very [Listener] below that started the drag also has to keep
  /// handling its move/up/cancel; this overlay only occupies the screen so
  /// the platform view has nothing left to steal a raw OS event to.
  OverlayEntry? _captureOverlay;

  /// The pointer this divider is currently watching, from its
  /// PointerDownEvent to its up/cancel — null the rest of the time. A raw
  /// [Listener], unlike the [GestureDetector] it replaced, enforces no
  /// single-active-gesture invariant on its own: without this, a second
  /// pointer going down mid-drag (a second finger on a touch device) would
  /// overwrite [_lastPosition] and orphan the current [_captureOverlay] —
  /// permanently, since nothing left could ever remove it.
  int? _trackingPointer;

  /// Set once the tracked pointer has actually moved past [_dragSlop] —
  /// null before that. Distinguishes a real drag (which owns
  /// [_captureOverlay] and has called [SolidPaneDivider.onDragStart]) from a
  /// plain click still being watched for one: a raw Listener fires
  /// PointerDownEvent for every press, so without this gate every click
  /// would flash the full-window opaque cover for a frame.
  int? _activePointer;
  Offset? _downPosition;
  Offset? _lastPosition;

  /// How far the tracked pointer must move before a press reads as a drag.
  /// Mice report sub-pixel jitter on a plain click; touch needs more slack
  /// for a finger to stay a tap. Matches the two-tier slop
  /// DragGestureRecognizer itself uses (kPrecisePointerPanSlop / kTouchSlop)
  /// closely enough without pulling in its gesture-settings plumbing.
  static double _dragSlop(PointerDeviceKind kind) => kind == PointerDeviceKind.touch ? kTouchSlop : kPrecisePointerPanSlop;

  void _handlePointerDown(PointerDownEvent event) {
    // One pointer at a time: a second press while the first is still being
    // watched (pre-slop) or actively dragging is ignored outright, not
    // merged into it.
    if (_trackingPointer != null) return;
    // Matches DragGestureRecognizer's default allowedButtonsFilter — a
    // right- or middle-click-drag on the bar does nothing, same as before.
    if (event.buttons != kPrimaryButton) return;
    _trackingPointer = event.pointer;
    _downPosition = event.position;
    _lastPosition = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackingPointer) return;
    if (_activePointer == null) {
      if ((event.position - _downPosition!).distance < _dragSlop(event.kind)) return;
      _activePointer = event.pointer;
      widget.onDragStart?.call();
      final overlay = Overlay.of(context, rootOverlay: true);
      _captureOverlay = OverlayEntry(
        // Fully opaque, not a near-invisible wash: this also hides a native
        // platform view (the map webview) from its own resize flicker,
        // which a merely-transparent occluder wouldn't. IgnorePointer: it's
        // paint-only, see the field doc above for why it can't drive the
        // drag itself.
        builder: (context) =>
            Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Theme.of(context).colorScheme.surface))),
      );
      overlay.insert(_captureOverlay!);
    }
    final last = _lastPosition!;
    final horizontal = widget.axis == Axis.horizontal;
    final delta = horizontal ? event.position.dx - last.dx : event.position.dy - last.dy;
    _lastPosition = event.position;
    widget.onDragUpdate(delta);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _trackingPointer) return;
    _endTracking(cancelled: false);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _trackingPointer) return;
    _endTracking(cancelled: true);
  }

  void _endTracking({required bool cancelled}) {
    final wasActive = _activePointer != null;
    _trackingPointer = null;
    _activePointer = null;
    _downPosition = null;
    _lastPosition = null;
    // A plain click never started a drag (no overlay, no onDragStart) —
    // nothing to end.
    if (!wasActive) return;
    _captureOverlay?.remove();
    _captureOverlay = null;
    if (cancelled) {
      widget.onDragCancel?.call();
    } else {
      widget.onDragEnd?.call();
    }
  }

  @override
  void dispose() {
    // The overlay outlives a mere rebuild but not the divider itself — a
    // style/layout flip mid-drag must not leave a dangling entry painting
    // over a tree that no longer owns it.
    _captureOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontal = widget.axis == Axis.horizontal;
    // The header's own surface: the divider reads as chrome, not content.
    final barColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final active = _hovered || widget.dragging;
    final lineColor = theme.colorScheme.onPrimary;
    final grabLine = AnimatedOpacity(
      opacity: active ? 1.0 : SolidPaneDivider.restingLineOpacity,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        width: horizontal ? 3 : 16,
        height: horizontal ? 16 : 3,
        decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(1.5)),
      ),
    );
    return MouseRegion(
      cursor: horizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Container(
          width: horizontal ? widget.extent : null,
          height: horizontal ? null : widget.extent,
          color: barColor,
          child: Center(child: grabLine),
        ),
      ),
    );
  }
}
