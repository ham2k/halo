// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shared geometry for the eight-hour SVG temperature curve.
//
// The x mapping is a contract with the hour strip the panel draws below this:
// both put hour `i` at the centre of the `i`th of `n` equal columns, so a
// column's icon sits under its own point on the curve. Changing one without
// the other slides the labels off the shape they describe.
//
// The geometry is separated from the painting on purpose — `weatherCurve`
// answers with SVG commands and an equivalent measurable Path.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The centre of the `i`th of [count] equal columns across [width].
double weatherColumnCenter(double width, int count, int index) => width * (index + 0.5) / count;

/// The smallest temperature span the vertical axis will show. Without it a
/// forecast that varies by half a degree is drawn as a mountain range.
const double _minSpan = 4;

/// Vertical breathing room, so the warmest hour is not clipped by the top
/// edge and the coldest does not sit on the baseline.
const double _padding = 6;

/// The temperature curve for [temperatures] across [size], and the points it
/// passes through.
///
/// Null entries are gaps in the response: the curve is drawn through what is
/// there rather than treating a missing hour as zero degrees. The path runs
/// flat out to both edges, so it spans the pane rather than floating half a
/// column short of each side — extending the SHAPE, not inventing data, since
/// those ends carry no marker and no label.
///
/// Empty path and no points when nothing is known.
({Path path, List<Offset> points, String svgPath}) weatherCurve(List<double?> temperatures, Size size) {
  final known = temperatures.whereType<double>().toList();
  if (known.isEmpty || size.width <= 0 || size.height <= 0) {
    return (path: Path(), points: const [], svgPath: '');
  }

  var lo = known.reduce(math.min);
  var hi = known.reduce(math.max);
  if (hi - lo < _minSpan) {
    final middle = (hi + lo) / 2;
    lo = middle - _minSpan / 2;
    hi = middle + _minSpan / 2;
  }
  final top = _padding;
  final bottom = size.height - _padding;

  final points = <Offset>[];
  for (var i = 0; i < temperatures.length; i++) {
    final value = temperatures[i];
    if (value == null) continue;
    final t = (value - lo) / (hi - lo);
    points.add(Offset(
      weatherColumnCenter(size.width, temperatures.length, i),
      bottom - t * (bottom - top),
    ));
  }

  final path = Path()
    ..moveTo(0, points.first.dy)
    ..lineTo(points.first.dx, points.first.dy);
  final svg = StringBuffer('M0 ${points.first.dy} L${points.first.dx} ${points.first.dy}');
  _appendSpline(path, points, svg);
  path.lineTo(size.width, points.last.dy);
  svg.write(' L${size.width} ${points.last.dy}');
  return (path: path, points: points, svgPath: svg.toString());
}

/// Catmull-Rom through [points], as cubics, with each control point clamped
/// to the vertical span of the segment it belongs to.
///
/// The clamp is the whole reason this is not a plain spline: unclamped, three
/// hours of 61°, 61°, 55° bulge ABOVE 61 on the way down, and the panel draws
/// an hour warmer than any hour in the forecast.
void _appendSpline(Path path, List<Offset> points, StringBuffer svg) {
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i == 0 ? 0 : i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
    final low = math.min(p1.dy, p2.dy);
    final high = math.max(p1.dy, p2.dy);
    final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, (p1.dy + (p2.dy - p0.dy) / 6).clamp(low, high));
    final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, (p2.dy - (p3.dy - p1.dy) / 6).clamp(low, high));
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    svg.write(' C${c1.dx} ${c1.dy} ${c2.dx} ${c2.dy} ${p2.dx} ${p2.dy}');
  }
}
