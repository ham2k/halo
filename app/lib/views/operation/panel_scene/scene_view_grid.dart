// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'scene_view.dart';

/// Cells and grids: the pieces of a scene drawn at their own size, in slots that reflow.
extension _SceneGrids on _PanelSceneViewState {
  /// A cell, at its own size in logical pixels: never scaled, so a meter is as big in a wide pane
  /// as in a narrow one, and the grid around it reflows instead.
  Widget _cell(String id) {
    final size = widget.scene.cells[id]!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Align(
      child: SizedBox.fromSize(
        key: ValueKey('cell:$id'),
        size: size,
        child: ClipRect(child: _stack(reduceMotion, cell: id)),
      ),
    );
  }

  /// A grid in its box. The outermost grid scrolls the pane: down where its rows run past the
  /// bottom, across where its widest child is wider than the pane. A grid with `columns` scrolls
  /// across on its own where it is wider than the room it is given, so a row of controls scrolls
  /// while the board around it stays put.
  Widget _grid(SceneLayoutNode node, Widget Function() artwork, {required bool outermost}) {
    final cells = widget.scene.cells;
    Widget slots = SceneGridLayout(
      unit: node.unit!,
      gap: node.gap!,
      columns: node.columns,
      children: [
        for (final c in node.children)
          SceneGridSlot(
            span: c.spanIn(node, cells),
            fullRow: c.type == 'grid' && c.columns == null,
            minColumns: c.type == 'grid' && c.columns == null ? c.minColumnsIn(node, cells) : 1,
            child: _layout(c, artwork, inGrid: true),
          ),
      ],
    );
    if (node.columns != null) slots = SceneGridScroll(axis: Axis.horizontal, child: slots);
    final style = node.style;
    Color? color(String? name) => name == null ? null : panelColorRole(context, name) ?? parseExtensionColor(name);
    Widget box = Padding(
      padding: node.padding,
      child: style?.title == null
          ? slots
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: node.gap!.dy),
                  child: Text(style!.title!, style: panelTextRole(context, 'label'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                slots,
              ],
            ),
    );
    if (style != null && (style.background != null || style.borderColor != null)) {
      box = DecoratedBox(
        decoration: BoxDecoration(
          color: color(style.background),
          // A zero-width side is a hairline in Flutter, not none.
          border: style.borderColor == null || style.borderWidth == 0 ? null : Border.all(color: color(style.borderColor)!, width: style.borderWidth),
          borderRadius: BorderRadius.circular(style.radius),
        ),
        child: box,
      );
    }
    if (!outermost) return box;
    final minWidth = node.minSlotsWidth(cells) + node.padding.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        // At least the whole pane, so the board starts at its leading edge and its box fills it.
        final width = constraints.hasBoundedWidth ? math.max(minWidth, constraints.maxWidth) : null;
        Widget pane = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: width ?? 0,
            maxWidth: width ?? double.infinity,
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: box,
        );
        if (constraints.hasBoundedWidth && minWidth > constraints.maxWidth) {
          pane = SceneGridScroll(axis: Axis.horizontal, child: pane);
        }
        return constraints.hasBoundedHeight ? SceneGridScroll(axis: Axis.vertical, child: pane) : pane;
      },
    );
  }
}

/// How a drawn slider or knob takes a drag, and, in a cell, the pointer.
extension _ControlDrag on _ControlViewState {
  void _panStart(BuildContext context, DragStartDetails d) {
    final c = widget.control;
    if (widget.disabled) return;
    _dragging = true;
    if (_focusesFromPointer) _focusFromPointer(Focus.of(context), hold: false);
    widget.onStart();
    _dragValue = widget.value;
    _dragValueY = widget.valueY ?? 0;
    _movedX = _movedY = false;
    if (c.kind == 'slider') {
      widget.onChange(c.atX(d.localPosition.dx));
    }
  }

  void _panUpdate(DragUpdateDetails d) {
    final c = widget.control;
    if (!_dragging) return;
    if (c.kind == 'slider') {
      widget.onChange(c.atX(d.localPosition.dx));
    } else {
      // Range only, not `c.clamp`: that also snaps to the step, and
      // a slow drag whose deltas are under half a step would never
      // move. Unclamped, a drag past an end stop owes the same
      // distance back before the value moves again.
      // `invertDrag`: the value moves the other way, as content held under the finger does.
      final delta = c.invertDrag ? -d.delta : d.delta;
      if (c.yAxis case final y?) {
        // Each axis its own: across for the first value, up for the second.
        if (delta.dx != 0) {
          _movedX = true;
          _dragValue = (_dragValue + delta.dx * c.sensitivity).clamp(c.min, c.max).toDouble();
          widget.onChange(_dragValue);
        }
        if (delta.dy != 0) {
          _movedY = true;
          _dragValueY = (_dragValueY - delta.dy * y.sensitivity).clamp(y.min, y.max).toDouble();
          widget.onChangeY!(_dragValueY);
        }
      } else {
        _dragValue = (_dragValue + (delta.dx - delta.dy) * c.sensitivity).clamp(c.min, c.max).toDouble();
        widget.onChange(_dragValue);
      }
    }
  }

  void _panEnd(BuildContext context) {
    final c = widget.control;
    if (!_dragging) return;
    _dragging = false;
    _holdPointerFocus(Focus.of(context));
    if (c.yAxis == null || _movedX) widget.onCommit();
    if (_movedY) widget.onCommitY?.call();
  }

  void _panCancel(BuildContext context) {
    if (!_dragging) return;
    _dragging = false;
    _holdPointerFocus(Focus.of(context));
    widget.onCancel();
  }

  /// Whether a click or drag gives this control the focus. Not in a cell: a board's controls are
  /// worked mid-QSO, and the operator's next keystroke belongs in the logging fields, so a board
  /// slider or knob takes none, as a drawn button never does; Tab still reaches it, and the wheel
  /// adjusts it without focus.
  bool get _focusesFromPointer => widget.control.cell == null;

  /// A slider or knob in a cell keeps a drag begun on it from the grid scrolling around it; see
  /// [_CellPan]. Elsewhere a scene's `scroll` takes a drag along it, as the scene contract says.
  Widget _draggedInCell(BuildContext context, Widget child) => widget.control.cell == null || widget.control.kind == 'button'
      ? child
      : RawGestureDetector(
          gestures: {
            _CellPan: GestureRecognizerFactoryWithHandlers<_CellPan>(
              () => _CellPan(enabled: () => !widget.disabled),
              (pan) => pan
                ..across = widget.control.kind == 'slider'
                // The device's own slop, as the scroll view around it uses: with the default one in
                // its place, a phone whose slop is smaller would give the scroll every drag.
                ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                ..onStart = ((d) => _panStart(context, d))
                ..onUpdate = _panUpdate
                ..onEnd = ((_) => _panEnd(context))
                ..onCancel = (() => _panCancel(context)),
            ),
          },
          child: child,
        );
}

/// A pan that accepts as soon as a scroll view's drag would, where a plain pan waits for twice the
/// distance and so loses every drag to the grid scrolling around it. Deeper in the hit path than
/// that scroll view, it hears each move first and wins the tie.
///
/// [across]: a slider's, which moves along one axis only, claims only a drag that goes mostly
/// across; one that goes mostly down is the operator scrolling the board, and claimed, it would
/// set the slider to wherever the finger landed. A disabled control claims nothing, so the board
/// still scrolls under it, and a trackpad's pan is the board's to scroll.
class _CellPan extends PanGestureRecognizer {
  _CellPan({required this.enabled});

  bool across = false;
  final bool Function() enabled;
  Offset? _down;
  Offset _moved = Offset.zero;

  @override
  bool isPointerAllowed(PointerEvent event) => enabled() && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _down = event.position;
    _moved = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _down != null) _moved = event.position - _down!;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) =>
      _moved.distance > computeHitSlop(pointerDeviceKind, gestureSettings) && (!across || _moved.dx.abs() >= _moved.dy.abs());
}
