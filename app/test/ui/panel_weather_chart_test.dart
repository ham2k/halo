// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The temperature curve's geometry.
//
// Both of these are wrong in ways that still LOOK like a weather panel: an
// unclamped spline draws an hour warmer than any hour in the forecast, and a
// curve whose x mapping drifts from the hour strip's puts every icon under
// the wrong point without anything overlapping or overflowing.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/weather/weather_chart.dart';

void main() {
  const box = Size(320, 120);

  /// Every y the path actually passes through, sampled along its length —
  /// measured off the Path the painter draws rather than recomputed, so a
  /// change to the spline shows up here instead of being mirrored by the
  /// test.
  List<double> sampled(List<double?> temperatures) {
    final path = weatherCurve(temperatures, box).path;
    final ys = <double>[];
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d <= metric.length; d += 0.5) {
        ys.add(metric.getTangentForOffset(d)!.position.dy);
      }
    }
    return ys;
  }

  group('the curve never leaves the forecast', () {
    test('a peak followed by a fall does not bulge above the peak', () {
      // The unclamped Catmull-Rom case: 61, 61, 55 overshoots on the way
      // down, and the panel draws an hour warmer than any hour it was given.
      // y is inverted, so "warmer" is a SMALLER y.
      const temperatures = <double?>[61, 61, 55, 54, 54, 53, 52, 52];
      final curve = weatherCurve(temperatures, box);
      final warmest = curve.points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final coldest = curve.points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

      for (final y in sampled(temperatures)) {
        expect(y, greaterThanOrEqualTo(warmest - 0.01));
        expect(y, lessThanOrEqualTo(coldest + 0.01));
      }
    });

    test('a valley does not dip below the coldest hour', () {
      const temperatures = <double?>[70, 62, 62, 71, 72, 73, 74, 75];
      final curve = weatherCurve(temperatures, box);
      final coldest = curve.points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      for (final y in sampled(temperatures)) {
        expect(y, lessThanOrEqualTo(coldest + 0.01));
      }
    });
  });

  group('a flat forecast is drawn flat', () {
    test('rather than amplified into a mountain range', () {
      // Without a floor on the span, normalising to min/max turns a half-
      // degree drift into the full height of the pane.
      const temperatures = <double?>[70, 70.2, 70.1, 70, 70.3, 70.1, 70, 70.2];
      final ys = sampled(temperatures);
      final spread = ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(box.height * 0.25));
    });

    test('an identical forecast does not divide by zero', () {
      final ys = sampled(const [68, 68, 68, 68, 68, 68, 68, 68]);
      expect(ys, isNotEmpty);
      expect(ys.every((y) => y.isFinite), isTrue);
    });
  });

  group('gaps in the response', () {
    test('a missing hour is skipped, not read as zero degrees', () {
      // Zero would drag the whole curve to the floor and rescale every other
      // hour against it — a single null hour would make the panel unreadable.
      final withGap = weatherCurve(const [70, null, 72, 73, 74, 75, 76, 77], box);
      expect(withGap.points.length, 7);
      expect(sampled(const [70, null, 72, 73, 74, 75, 76, 77]).every((y) => y <= box.height), isTrue);
    });

    test('nothing known at all draws nothing, rather than throwing', () {
      expect(weatherCurve(const [null, null], box).points, isEmpty);
      expect(weatherCurve(const [], box).points, isEmpty);
    });

    test('a zero-sized pane draws nothing', () {
      expect(weatherCurve(const [70, 72], Size.zero).points, isEmpty);
    });
  });

  group('the curve and the hour strip share one x mapping', () {
    test('point i sits at the centre of column i', () {
      // The strip is a Row of `n` Expanded columns, so column i is centred at
      // (i + 0.5) * width / n. A curve laid out edge-to-edge instead would
      // put every icon under the wrong hour, with nothing visibly broken.
      const temperatures = <double?>[70, 71, 72, 73, 74, 75, 76, 77];
      final points = weatherCurve(temperatures, box).points;
      for (var i = 0; i < points.length; i++) {
        expect(points[i].dx, closeTo(weatherColumnCenter(box.width, temperatures.length, i), 0.001));
      }
    });

    test('the path still spans the full width', () {
      // Half a column of dead space at each end reads as a rendering bug, so
      // the SHAPE runs flat out to both edges — without inventing points,
      // which is what the mapping above would then mislabel.
      final path = weatherCurve(const [70, 71, 72, 73, 74, 75, 76, 77], box).path;
      expect(path.getBounds().left, closeTo(0, 0.001));
      expect(path.getBounds().right, closeTo(box.width, 0.001));
    });
  });
}
