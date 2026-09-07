// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two charts' geometry, which is measurable where a Canvas is not.
//
// What is actually at stake in both is SCALE: a bar whose height means
// something different each day, or a line fitted to a span it does not have,
// draws a plausible shape describing nothing — and neither is visible to
// anyone who has not memorised yesterday's numbers.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/solar/solar_charts.dart';

void main() {
  const size = Size(300, 60);

  group('solarLine', () {
    test('spans the full width and puts the extremes at the padded edges', () {
      final chart = solarLine([100, 150, 200], size);

      expect(chart.points.first.dx, 0);
      expect(chart.points.last.dx, size.width);
      // Padded, not flush: without it the highest day is clipped by the top
      // edge and the lowest sits on the baseline, where it reads as missing.
      expect(chart.points[2].dy, greaterThan(0));
      expect(chart.points.first.dy, lessThan(size.height));
      expect(chart.points[2].dy, lessThan(chart.points[1].dy));
    });

    test('a flat month is drawn flat, not as a mountain range', () {
      final chart = solarLine([142, 143, 142, 143], size);

      // Fitted to its own two-point span, a quiet month would swing between
      // the top and bottom of the pane — which is the alarm this panel most
      // needs not to raise falsely. The minimum span is what keeps the shape
      // proportional to what actually moved.
      final ys = chart.points.map((p) => p.dy).toList();
      final swing = ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b);
      expect(swing, lessThan(size.height * 0.2));
    });

    test('a calm hour of wind is drawn calm, on its own scale', () {
      // The guard is in the SERIES' units. The wind sits near 300 and wanders
      // by ten or fifteen on a quiet hour — two per cent, and meaningless —
      // so measured against the flux axis's 20 a calm hour comes out as a
      // storm.
      final calm = [296.0, 305.0, 298.0, 309.0, 300.0];
      final onFluxScale = solarLine(calm, size);
      final onWindScale = solarLine(calm, size, minSpan: solarMinWindSpan);

      double swing(List<Offset> points) {
        final ys = points.map((point) => point.dy);
        return ys.reduce(math.max) - ys.reduce(math.min);
      }

      expect(swing(onWindScale.points), lessThan(size.height * 0.25));
      expect(swing(onWindScale.points), lessThan(swing(onFluxScale.points)));
    });

    test('one observation is not a trend', () {
      // A single point drawn as a flat line across the pane claims a month of
      // data the panel does not have.
      expect(solarLine([143], size).points, isEmpty);
      expect(solarLine([], size).points, isEmpty);
    });

    test('a degenerate box produces nothing rather than throwing', () {
      expect(solarLine([100, 200], const Size(0, 60)).points, isEmpty);
      expect(solarLine([100, 200], const Size(300, 0)).points, isEmpty);
    });
  });

  group('solarBars', () {
    test('height is measured against the Kp scale, never against the data', () {
      final quiet = solarBars([1, 2, 1], size);
      final stormy = solarBars([1, 2, 8], size);

      // The bar for the same Kp is the same height in both — a quiet week
      // fitted to its own maximum would draw a Kp of 2 at full height, which
      // is exactly the false alarm this chart exists to avoid.
      expect(quiet[1].height, closeTo(stormy[1].height, 0.001));
      expect(stormy[2].height, closeTo(size.height * 8 / solarKpCeiling, 0.001));
    });

    test('a Kp of zero still leaves a mark', () {
      // "Quiet" and "no reading" are different, and the second is drawn by
      // there being no bar at all.
      expect(solarBars([0], size).single.height, greaterThan(0));
    });

    test('a reading past the scale is clamped, not drawn off the top', () {
      expect(solarBars([12], size).single.top, greaterThanOrEqualTo(0));
      expect(solarBars([12], size).single.height, closeTo(size.height, 0.001));
    });

    test('bars are separated columns, and stay inside the box', () {
      final bars = solarBars([1, 2, 3, 4], size);

      expect(bars, hasLength(4));
      expect(bars.first.left, greaterThanOrEqualTo(0));
      expect(bars.last.right, lessThanOrEqualTo(size.width));
      // Butted together, 24 three-hour readings read as a filled area chart
      // rather than as discrete observations.
      expect(bars[1].left, greaterThan(bars[0].right));
    });
  });

  group('threshold colours', () {
    test('K follows the SOLAR command\'s own thresholds', () {
      // Ported from `emojiForKIndex` in extensions/shared/spaceWeather.ts,
      // which the runtime owns and Dart cannot reach. A threshold changed
      // there and not here has a command and a panel describing the same
      // storm differently — this is what catches that.
      expect(solarKColor(3), SolarPalette.good);
      expect(solarKColor(4), SolarPalette.fair);
      expect(solarKColor(5), SolarPalette.poor);
      expect(solarKColor(7), SolarPalette.severe);
    });

    test('A follows emojiForAIndex, with its brown band folded into poor', () {
      expect(solarAColor(19), SolarPalette.good);
      expect(solarAColor(20), SolarPalette.fair);
      expect(solarAColor(30), SolarPalette.poor);
      expect(solarAColor(60), SolarPalette.poor, reason: 'the emoji table\'s 🟤 band');
      expect(solarAColor(100), SolarPalette.severe);
    });

    test('flux runs the other way — a high number is the good news', () {
      // The one scale here that inverts. A red 200 beside a grid of "Good"
      // would contradict the row under it.
      expect(solarFluxColor(90), SolarPalette.poor);
      expect(solarFluxColor(120), SolarPalette.fair);
      expect(solarFluxColor(200), SolarPalette.good);
    });
  });
}
