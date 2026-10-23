// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a scene's controls read the pointer beyond a click: a scroll's step,
// and the drag that zooms a scrolling scene (docs/design/panel-scenes.md).

import 'package:flutter/gestures.dart';

import 'scene_model.dart';

/// A drag along a scrolling scene's axis, claimed only where it begins on a `zoom` strip. Deeper
/// than the scroll view, it wins a drag there that the scroll view would otherwise take.
///
/// Never a trackpad's two-finger swipe: that arrives as a pan-zoom, which [isPointerAllowed] never
/// sees, and is the operator scrolling — on the strip as anywhere else. Without this the zoom drag
/// claims every swipe in the pane, and nothing scrolls. A pinch on the strip zooms by its own
/// scale instead (`_pinchUpdate` in scene_view.dart).
///
/// Two twins rather than one mixin: [DragGestureRecognizer] is sealed, and [GestureRecognizer]'s
/// narrower [isPointerAllowed] leaves a mixin on it no way to call the drag's own.
class VerticalZoomDrag extends VerticalDragGestureRecognizer {
  VerticalZoomDrag(this.allowedAt);
  final bool Function(Offset at) allowedAt;

  @override
  bool isPointerAllowed(PointerEvent event) => allowedAt(event.localPosition) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;
}

class HorizontalZoomDrag extends HorizontalDragGestureRecognizer {
  HorizontalZoomDrag(this.allowedAt);
  final bool Function(Offset at) allowedAt;

  @override
  bool isPointerAllowed(PointerEvent event) => allowedAt(event.localPosition) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;
}

/// What a scroll of [d] does to [c]: one step of its value, or of its second axis's for an
/// up-and-down scroll where it has one. Down and left are less. A one-axis control takes a
/// sideways scroll by its own direction, so a horizontal swipe is not read as an upward one.
({bool second, double delta}) sceneScrollStep(SceneControl c, Offset d) {
  if (c.yAxis case final y? when d.dy.abs() >= d.dx.abs()) return (second: true, delta: d.dy > 0 ? -y.step : y.step);
  if (c.yAxis != null || d.dx.abs() > d.dy.abs()) return (second: false, delta: d.dx > 0 ? c.step : -c.step);
  return (second: false, delta: d.dy > 0 ? -c.step : c.step);
}
