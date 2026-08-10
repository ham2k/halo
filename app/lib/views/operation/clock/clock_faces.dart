// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The clock faces, as painters.
//
// Each takes already-resolved Colors and no BuildContext: a painter that both
// pins a palette and reads a theme is silently wrong in one brightness, and
// nothing else in this app hands a context to a CustomPainter.
//
// Every dimension is derived from the Size given to `paint`, in plain logical
// pixels. The Font Scale setting scales the whole UI from one root wrapper,
// so multiplying anything here by it would scale it twice
// (docs/design/ui-scaling.md).

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';

import 'clock_math.dart';

/// What one face needs to know about colour. Resolved from the theme by the
/// pane, so the faces that adopt the app's scheme and the faces that own
/// their palette look the same from here.
@immutable
class ClockPalette {
  /// Behind the whole face — the LCD's glass, the dial's paper.
  final Color face;

  /// Digits, numerals, hour hand, minute hand.
  final Color ink;

  /// Unlit LCD segments, and the dial's minute ticks.
  final Color ghost;

  /// The second hand, and nothing else.
  final Color accent;

  const ClockPalette({
    required this.face,
    required this.ink,
    required this.ghost,
    required this.accent,
  });
}

/// A seven-segment readout.
///
/// [digits] is one entry per cell, null for a blank (a suppressed leading
/// zero). A colon is drawn in each gap named by [colonsAfter].
class LcdFacePainter extends CustomPainter {
  final List<int?> digits;
  final Set<int> colonsAfter;
  final ClockPalette palette;

  const LcdFacePainter({required this.digits, required this.colonsAfter, required this.palette});

  /// Cell proportions, and the bar thickness as a fraction of cell width.
  /// A real display's bars are chunky; a thin one reads as a stencil font.
  static const _cellAspect = 1.8;
  static const _strokeRatio = 0.18;

  /// The glass border, as a fraction of the shorter side. The digits do not
  /// run to the edge of a real display either, and without it the lit
  /// segments touch the bezel and stop reading as a panel.
  static const _margin = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    if (digits.isEmpty) return;

    // The glass. Without it the segments float on whatever the pane's own
    // background is, and the ghosts — which only make sense against a
    // display — read as damage.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.shortestSide * 0.07)),
      Paint()..color = palette.face,
    );

    final inset = size.shortestSide * _margin;
    final glassSize = Size(size.width - inset * 2, size.height - inset * 2);
    if (glassSize.width <= 0 || glassSize.height <= 0) return;
    canvas.save();
    canvas.translate(inset, inset);

    // A colon costs about a third of a digit's width.
    final slots = digits.length + colonsAfter.length * 0.34;
    final gap = 0.16;
    final unitWidth = glassSize.width / (slots + gap * (digits.length - 1));
    final cellHeight = math.min(unitWidth * _cellAspect, glassSize.height);
    final cellWidth = cellHeight / _cellAspect;
    final stroke = cellWidth * _strokeRatio;
    final cell = Size(cellWidth, cellHeight);

    // Re-measured from the cell that actually fit, so the row stays centred
    // when height rather than width is the binding constraint.
    var totalWidth = 0.0;
    for (var i = 0; i < digits.length; i++) {
      totalWidth += cellWidth;
      if (i < digits.length - 1) totalWidth += cellWidth * gap;
      if (colonsAfter.contains(i)) totalWidth += cellWidth * 0.34;
    }

    final lit = Paint()..color = palette.ink;
    final unlit = Paint()..color = palette.ghost;

    canvas.save();
    canvas.translate((glassSize.width - totalWidth) / 2, (glassSize.height - cellHeight) / 2);
    for (var i = 0; i < digits.length; i++) {
      final on = segmentsForDigit(digits[i]);
      for (final segment in ClockSegment.values) {
        // The unlit segments are drawn too, faintly. They are what makes it
        // read as a physical display rather than as text in a blocky font —
        // and without them a `1` floats with nothing to sit in.
        canvas.drawPath(segmentPath(segment, cellSize: cell, stroke: stroke), on.contains(segment) ? lit : unlit);
      }
      canvas.translate(cellWidth, 0);
      if (i < digits.length - 1) canvas.translate(cellWidth * gap, 0);
      if (colonsAfter.contains(i)) {
        final r = stroke * 0.42;
        final x = cellWidth * 0.17;
        canvas.drawCircle(Offset(x, cellHeight * 0.34), r, lit);
        canvas.drawCircle(Offset(x, cellHeight * 0.66), r, lit);
        canvas.translate(cellWidth * 0.34, 0);
      }
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(LcdFacePainter old) =>
      !listEquals(old.digits, digits) ||
      !setEquals(old.colonsAfter, colonsAfter) ||
      old.palette.ink != palette.ink;
}

/// A plain round face: minute ticks, hour marks, three tapered hands.
class AnalogFacePainter extends CustomPainter {
  /// Degrees clockwise from 12.
  final double hourAngle;
  final double minuteAngle;
  final double secondAngle;
  final bool showSeconds;
  final ClockPalette palette;

  const AnalogFacePainter({
    required this.hourAngle,
    required this.minuteAngle,
    required this.secondAngle,
    required this.showSeconds,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    canvas.drawCircle(Offset.zero, r, Paint()..color = palette.face);
    canvas.drawCircle(
      Offset.zero,
      r - r * 0.015,
      Paint()
        ..color = palette.ghost
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03,
    );

    for (var i = 0; i < 60; i++) {
      final isHour = i % 5 == 0;
      final paint = Paint()
        ..color = isHour ? palette.ink : palette.ghost
        ..strokeWidth = r * (isHour ? 0.05 : 0.018)
        ..strokeCap = StrokeCap.round;
      final inner = r * (isHour ? 0.80 : 0.86);
      final angle = i * math.pi / 30 - math.pi / 2;
      canvas.drawLine(
        Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        Offset(math.cos(angle) * r * 0.91, math.sin(angle) * r * 0.91),
        paint,
      );
    }

    void hand(double degrees, double length, double width, Color color, {double tail = 0.0}) {
      final radians = degrees * math.pi / 180 - math.pi / 2;
      final dx = math.cos(radians);
      final dy = math.sin(radians);
      canvas.drawLine(
        Offset(-dx * tail, -dy * tail),
        Offset(dx * length, dy * length),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand(hourAngle, r * 0.50, r * 0.075, palette.ink);
    hand(minuteAngle, r * 0.74, r * 0.052, palette.ink);
    if (showSeconds) {
      hand(secondAngle, r * 0.80, r * 0.020, palette.accent, tail: r * 0.18);
    }
    canvas.drawCircle(Offset.zero, r * 0.045, Paint()..color = showSeconds ? palette.accent : palette.ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnalogFacePainter old) =>
      old.hourAngle != hourAngle ||
      old.minuteAngle != minuteAngle ||
      old.secondAngle != secondAngle ||
      old.showSeconds != showSeconds ||
      old.palette.ink != palette.ink;
}
