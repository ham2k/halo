// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A scene grid's slots: [unit]-sized, [gap] apart, filled row by row in child order, each child
/// at the first place it fits from where the one before it went (CSS grid's `auto-flow: row`, not
/// `dense`), so the order on screen is the order the scene wrote. With [columns] the grid is that
/// many slots wide; without, as many as its width allows, and never fewer than its widest child
/// needs. A child's place comes from its [SceneGridSlot].
class SceneGridLayout extends MultiChildRenderObjectWidget {
  final Size unit;
  final Offset gap;
  final int? columns;

  const SceneGridLayout({super.key, required this.unit, required this.gap, this.columns, required List<SceneGridSlot> super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSceneGrid(unit, gap, columns, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderSceneGrid renderObject) => renderObject
    ..unit = unit
    ..gap = gap
    ..columns = columns
    ..textDirection = Directionality.of(context);
}

/// Where a grid child goes: [span] slots across and down, given exactly their area; or, with no
/// span, the slots its own size covers, measured within the grid's width; or, [fullRow], a whole
/// row of the grid, at least [minColumns] wide, as many slots down as its height covers.
class SceneGridSlot extends ParentDataWidget<SceneGridParentData> {
  final ({int columns, int rows})? span;
  final bool fullRow;
  final int minColumns;

  const SceneGridSlot({super.key, this.span, this.fullRow = false, this.minColumns = 1, required super.child});

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as SceneGridParentData;
    if (data.span == span && data.fullRow == fullRow && data.minColumns == minColumns) return;
    data
      ..span = span
      ..fullRow = fullRow
      ..minColumns = minColumns;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => SceneGridLayout;
}

/// A grid child's [SceneGridSlot], as its render object carries it.
class SceneGridParentData extends ContainerBoxParentData<RenderBox> {
  ({int columns, int rows})? span;
  bool fullRow = false;
  int minColumns = 1;
}

/// Lays out a [SceneGridLayout].
class RenderSceneGrid extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, SceneGridParentData>, RenderBoxContainerDefaultsMixin<RenderBox, SceneGridParentData> {
  RenderSceneGrid(this._unit, this._gap, this._columns, this._textDirection);

  Size _unit;
  set unit(Size value) {
    if (value == _unit) return;
    _unit = value;
    markNeedsLayout();
  }

  Offset _gap;
  set gap(Offset value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  int? _columns;
  set columns(int? value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! SceneGridParentData) child.parentData = SceneGridParentData();
  }

  @override
  void performLayout() => size = _arrange(constraints, ChildLayoutHelper.layoutChild, place: true);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _arrange(constraints, ChildLayoutHelper.dryLayoutChild, place: false);

  Size _arrange(BoxConstraints constraints, ChildLayouter layoutChild, {required bool place}) {
    final across = _unit.width + _gap.dx, down = _unit.height + _gap.dy;
    int slots(double extent, double unit, double gap) => math.max(1, ((extent + gap) / (unit + gap) - 1e-6).ceil());
    final children = <RenderBox>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      children.add(child);
    }
    SceneGridParentData data(RenderBox child) => child.parentData! as SceneGridParentData;

    var columns = _columns ?? (constraints.hasBoundedWidth ? ((constraints.maxWidth + _gap.dx) / across + 1e-6).floor() : 1);
    if (_columns == null) {
      for (final child in children) {
        final d = data(child);
        columns = math.max(columns, d.fullRow ? d.minColumns : d.span?.columns ?? 1);
      }
    }
    columns = math.max(columns, 1);
    final width = columns * across - _gap.dx;
    // The box can be wider than its slots (the outermost grid fills the pane): the slack goes at the
    // end of the line, so right to left the slots are measured from the box's right edge.
    final boxWidth = constraints.constrain(Size(width, 0)).width;
    double extent(int n, double unit, double gap) => n * unit + (n - 1) * gap;

    // The row each column is free from. Placement only moves forward, and every child placed so far
    // started at or above the cursor's row, so a column is taken at a row at or below the cursor's
    // exactly when it is not yet free there. Finding a place costs a pass along a row, however
    // tall the children are.
    final freeFrom = List.filled(columns, 0);
    var row = 0, col = 0, rows = 0;
    for (final child in children) {
      final d = data(child);
      final int w, h;
      if (d.fullRow) {
        w = columns;
        h = slots(layoutChild(child, BoxConstraints(minWidth: width, maxWidth: width)).height, _unit.height, _gap.dy);
      } else if (d.span case final span?) {
        w = math.min(span.columns, columns);
        h = span.rows;
      } else {
        final measured = layoutChild(child, BoxConstraints(maxWidth: width));
        w = math.min(slots(measured.width, _unit.width, _gap.dx), columns);
        h = slots(measured.height, _unit.height, _gap.dy);
      }
      if (d.fullRow) {
        // A whole row: below everything placed so far.
        row = math.max(col > 0 ? row + 1 : row, freeFrom.reduce(math.max));
        col = 0;
      } else {
        while (true) {
          var run = 0, found = -1;
          for (var c = col; c < columns; c++) {
            run = freeFrom[c] <= row ? run + 1 : 0;
            if (run == w) {
              found = c - w + 1;
              break;
            }
          }
          if (found >= 0) {
            col = found;
            break;
          }
          // Nothing fits on this row: on to the next row where a column comes free.
          var next = -1;
          for (final f in freeFrom) {
            if (f > row && (next < 0 || f < next)) next = f;
          }
          row = next < 0 ? row + 1 : next;
          col = 0;
        }
      }
      for (var c = col; c < col + w; c++) {
        freeFrom[c] = row + h;
      }
      final area = Size(extent(w, _unit.width, _gap.dx), extent(h, _unit.height, _gap.dy));
      layoutChild(child, BoxConstraints.tight(area));
      if (place) {
        final x = col * across;
        d.offset = Offset(_textDirection == TextDirection.rtl ? boxWidth - x - area.width : x, row * down);
      }
      rows = math.max(rows, row + h);
      col += w;
    }
    return constraints.constrain(Size(width, rows == 0 ? 0 : rows * down - _gap.dy));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// A grid's scroll view along [axis]. Dragged by any pointer, a mouse included, wherever no
/// control under the pointer takes the drag first. Each edge with content hidden past it fades:
/// gone over its first [solid] pixels, so a widget cut by the edge is gone before it is cut, then
/// coming back over [ramp] more. The fade thins to nothing as the hidden content runs out, so a
/// row cut off by the pane reads as one that goes on, and one scrolled to its end shows its end whole.
class SceneGridScroll extends StatefulWidget {
  static const solid = 4.0, ramp = 40.0, fade = solid + ramp;

  final Axis axis;
  final Widget child;

  const SceneGridScroll({super.key, required this.axis, required this.child});

  @override
  State<SceneGridScroll> createState() => SceneGridScrollState();
}

/// The state of a [SceneGridScroll], public only so a test can read how far each edge fades.
class SceneGridScrollState extends State<SceneGridScroll> {
  /// How far the left (or top) and right (or bottom) edges fade, 0 to 1: the content hidden past
  /// each, as a share of [SceneGridScroll.fade]. On screen, whichever way the content runs.
  double _start = 0, _end = 0;

  /// The fades waiting for the end of the frame, which a later notification is measured against.
  ({double start, double end})? _pending;

  /// Keeps the scroll view, and its position, as the mask comes and goes around it.
  final _scroller = GlobalKey();

  @visibleForTesting
  ({double start, double end}) get fades => (start: _start, end: _end);

  bool _onMetrics(Notification note) {
    final metrics = switch (note) {
      ScrollMetricsNotification(:final metrics, :final depth) when depth == 0 => metrics,
      ScrollNotification(:final metrics, :final depth) when depth == 0 => metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != widget.axis || !metrics.hasContentDimensions) return false;
    double share(double hidden) => (hidden / SceneGridScroll.fade).clamp(0.0, 1.0);
    // Right to left, a row's first content is at the right: what is hidden "before" is past that edge.
    final reversed = metrics.axisDirection == AxisDirection.left || metrics.axisDirection == AxisDirection.up;
    final (start, end) = reversed ? (share(metrics.extentAfter), share(metrics.extentBefore)) : (share(metrics.extentBefore), share(metrics.extentAfter));
    final current = _pending ?? (start: _start, end: _end);
    if ((start - current.start).abs() < 0.01 && (end - current.end).abs() < 0.01) return false;
    _pending = (start: start, end: end);
    // Metrics arrive during layout as well as while scrolling; a rebuild then waits for the frame.
    void apply() {
      final next = _pending;
      _pending = null;
      if (!mounted || next == null) return;
      setState(() {
        _start = next.start;
        _end = next.end;
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final across = widget.axis == Axis.horizontal;
    final start = _start, end = _end;
    final scroller = KeyedSubtree(
      key: _scroller,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet(), scrollbars: false),
        child: SingleChildScrollView(scrollDirection: widget.axis, child: widget.child),
      ),
    );
    return NotificationListener<Notification>(
      onNotification: _onMetrics,
      // With nothing hidden, no mask: a mask is a layer of its own, drawn again on every frame of
      // anything animating under it.
      child: start == 0 && end == 0
          ? scroller
          : ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final length = across ? rect.width : rect.height;
                // In a pane too short for two whole fades, each takes half and keeps its proportions.
                final f = length > 0 ? math.min(SceneGridScroll.fade / length, 0.5) : 0.0;
                final band = f * SceneGridScroll.solid / SceneGridScroll.fade;
                const shown = Color(0xFFFFFFFF);
                final first = shown.withValues(alpha: 1 - start), last = shown.withValues(alpha: 1 - end);
                return LinearGradient(
                  begin: across ? Alignment.centerLeft : Alignment.topCenter,
                  end: across ? Alignment.centerRight : Alignment.bottomCenter,
                  colors: [first, first, shown, shown, last, last],
                  stops: [0, band, f, 1 - f, 1 - band, 1],
                ).createShader(rect);
              },
              child: scroller,
            ),
    );
  }
}
