// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a scene's controls read the pointer beyond a click: a scroll's step,
// the drag that zooms a scrolling scene, and the regions a spectrum's drags
// and double taps belong to (docs/design/panel-scenes.md).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'scene_model.dart';

/// A drag along one axis, claimed only where [allowedAt] says it may begin: a scrolling scene's
/// `zoom` strip, or the part of a spectrum that pans or zooms. Deeper than the scroll view, it wins
/// a drag there that the scroll view would otherwise take.
///
/// Never a trackpad's two-finger swipe: that arrives as a pan-zoom, which [isPointerAllowed] never
/// sees, and is the operator scrolling — on the strip as anywhere else. Without this the drag
/// claims every swipe in the pane, and nothing scrolls. A pinch zooms by its own scale instead
/// (`_pinchUpdate` in scene_view.dart, `_trackpadUpdate` in scene_spectrum_gestures.dart).
///
/// Two twins rather than one mixin: [DragGestureRecognizer] is sealed, and [GestureRecognizer]'s
/// narrower [isPointerAllowed] leaves a mixin on it no way to call the drag's own.
class VerticalRegionDrag extends VerticalDragGestureRecognizer {
  VerticalRegionDrag(this.allowedAt);

  /// Settable: a recognizer is kept across rebuilds by its type, so one that changes job
  /// — a spectrum turned, whose drag along the frequency and across the axis swap types —
  /// takes its new region here, in its factory's initializer.
  bool Function(Offset at) allowedAt;

  @override
  bool isPointerAllowed(PointerEvent event) => allowedAt(event.localPosition) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => false;
}

class HorizontalRegionDrag extends HorizontalDragGestureRecognizer {
  HorizontalRegionDrag(this.allowedAt);

  /// Settable: a recognizer is kept across rebuilds by its type, so one that changes job
  /// — a spectrum turned, whose drag along the frequency and across the axis swap types —
  /// takes its new region here, in its factory's initializer.
  bool Function(Offset at) allowedAt;

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

/// A step a spectrum tunes by while it shows [hzPerPixel]: the smallest 1, 2 or 5 × 10ⁿ Hz that
/// covers [pixels] of it, then [shift] rungs further along that ladder, never under 1 Hz. A finer
/// step than a pixel names a frequency nobody could have aimed at; zoomed in, the steps shrink with
/// the pixels.
double spectrumTuneStep(double hzPerPixel, {double pixels = 1, int shift = 0}) {
  final want = math.max(1.0, hzPerPixel * pixels);
  var rung = 3 * (math.log(want) / math.ln10).floor();
  while (_rung(rung) < want) {
    rung++;
  }
  return _rung(math.max(0, rung + shift));
}

/// 1, 2, 5, 10, 20, 50… Hz for rungs 0, 1, 2, 3, 4, 5….
double _rung(int rung) => math.pow(10, rung ~/ 3).toDouble() * const [1, 2, 5][rung % 3];
