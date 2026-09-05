// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio panel's LCD face, as a painter.
//
// Like the clock's faces it takes already-resolved Colors and no
// BuildContext, and derives every dimension from the Size given to `paint`,
// in plain logical pixels — the Font Scale setting scales the whole UI from
// one root wrapper, so multiplying anything here by it would scale it twice
// (docs/design/ui-scaling.md).
//
// The seven-segment geometry itself comes from the clock's `clock_math.dart`
// rather than being written again here: a second copy of the segment paths
// is a second place for the same rendering bug to live, and the shapes are
// not clock-specific — only their file is.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../clock/clock_math.dart';

/// What the Radio panel's faces need to know about colour.
///
/// The LCD wears the app's shared LCD palette (`lcdPalette`), in its dark
/// variant whatever the app's brightness: it copies a physical object, a
/// themed one stops being the thing it copies, and a rig's display is backlit.
/// The Modern face adopts the app's scheme instead and sits in the dock like
/// every other pane.
@immutable
class RadioPalette {
  /// Behind the whole face — the display's glass.
  final Color face;

  /// Lit segments and the readout's text.
  final Color ink;

  /// Unlit segments. Null on a face with no segments to leave unlit.
  final Color? ghost;

  /// The units, mode and power annotations beside the frequency.
  final Color label;

  const RadioPalette({
    required this.face,
    required this.ink,
    this.ghost,
    required this.label,
  });

  /// The same palette dimmed to [alpha] — what a radio that is not connected
  /// wears.
  ///
  /// The glass keeps its colour and everything drawn ON it fades, which is
  /// what makes the pane read as a dark display rather than as a lit one
  /// behind a veil. The ghosts fade with the lit segments, not independently:
  /// holding them at full strength while the digits drop to a third closes
  /// the gap between lit and unlit until the frequency stops being readable
  /// — and the last frequency the radio was on is the whole value of the off
  /// state.
  RadioPalette dimmed(double alpha) => RadioPalette(
        face: face,
        ink: ink.withValues(alpha: alpha),
        ghost: ghost?.withValues(alpha: (ghost?.a ?? 1) * alpha),
        label: label.withValues(alpha: alpha),
      );
}

/// One cell of the frequency readout: a digit, a blank, or a separator.
///
/// Separators are cells rather than gaps because a radio's display gives the
/// decimal point and the MHz separator a column of their own — and because
/// laying them out as narrow cells is what keeps the digits on a fixed pitch
/// as the frequency changes width.
enum LcdCell {
  /// A digit cell with nothing lit — a suppressed leading zero.
  blank,

  /// The decimal point.
  dot,

  /// The MHz grouping mark.
  comma,

  /// A grouping column with no mark drawn, because the digit before it is
  /// blank. It still takes its column: the painter solves the cell size from
  /// the TOTAL slot count, so a readout that omitted this slot would draw
  /// larger digits and put the decimal point one column left — which is the
  /// sideways slide [lcdCellsForFrequency] exists to prevent, appearing at
  /// exactly the two moments it is least wanted (the first reading after a
  /// blank display, and an LF/MF operator crossing 1 MHz).
  gap,
}

/// A seven-segment frequency readout.
///
/// [cells] is one entry per column: an `int` 0-9 for a digit, or an
/// [LcdCell] for a blank or a separator.
class RadioLcdPainter extends CustomPainter {
  final List<Object> cells;
  final RadioPalette palette;

  const RadioLcdPainter({required this.cells, required this.palette});

  /// Cell proportions, and the bar thickness as a fraction of cell width —
  /// the clock LCD's, so the two faces read as the same kind of display.
  ///
  /// Public because [lcdWidthForCells] has to solve the same geometry to
  /// measure a readout: a second copy of these numbers is a second thing to
  /// forget when one of them moves, and the symptom would be a readout
  /// silently clipped or adrift from the edge it is aligned to.
  static const cellAspect = 1.8;
  static const _strokeRatio = 0.18;

  /// A separator column, as a fraction of a digit's width.
  static const separatorWidth = 0.34;

  /// The gap between digits, as a fraction of a digit's width.
  static const gap = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Slot widths in units of one digit's width, so the cell size can be
    // solved for once rather than measured twice.
    var slots = 0.0;
    for (final cell in cells) {
      slots += isSeparator(cell) ? separatorWidth : 1.0;
      slots += gap;
    }
    slots -= gap;

    final byWidth = size.width / slots;
    final byHeight = size.height / cellAspect;
    final cellWidth = math.min(byWidth, byHeight);
    final cellHeight = cellWidth * cellAspect;
    final stroke = cellWidth * _strokeRatio;
    final cell = Size(cellWidth, cellHeight);

    final lit = Paint()..color = palette.ink;
    final unlit = palette.ghost == null ? null : (Paint()..color = palette.ghost!);

    canvas.save();
    canvas.translate((size.width - slots * cellWidth) / 2, (size.height - cellHeight) / 2);
    for (var i = 0; i < cells.length; i++) {
      final value = cells[i];
      if (value is int || value == LcdCell.blank) {
        // A blank is a cell with nothing lit, not a gap: on a real display a
        // suppressed leading zero still shows its unlit segments, and skipping
        // the column entirely would slide the rest of the readout sideways.
        final on = segmentsForDigit(value is int ? value : null);
        for (final segment in ClockSegment.values) {
          // The unlit segments are drawn too, faintly — they are what makes
          // it read as a physical display rather than as text in a blocky
          // font, and without them a `1` floats with nothing to sit in.
          final paint = on.contains(segment) ? lit : unlit;
          if (paint == null) continue;
          canvas.drawPath(segmentPath(segment, cellSize: cell, stroke: stroke), paint);
        }
        canvas.translate(cellWidth, 0);
      } else if (value == LcdCell.gap) {
        canvas.translate(cellWidth * separatorWidth, 0);
      } else if (value == LcdCell.dot || value == LcdCell.comma) {
        // Both sit on the baseline; the comma is the dot with a tail, which
        // is how a real display distinguishes the MHz grouping from the
        // decimal point without a column of its own for each.
        final r = stroke * 0.5;
        final x = cellWidth * separatorWidth / 2;
        final y = cellHeight - r;
        canvas.drawCircle(Offset(x, y), r, lit);
        if (value == LcdCell.comma) {
          canvas.drawPath(
            Path()
              ..moveTo(x - r, y)
              ..lineTo(x + r, y)
              ..lineTo(x - r * 0.2, y + r * 2.4)
              ..close(),
            lit,
          );
        }
        canvas.translate(cellWidth * separatorWidth, 0);
      } else {
        canvas.translate(cellWidth, 0);
      }
      if (i < cells.length - 1) canvas.translate(cellWidth * gap, 0);
    }
    canvas.restore();
  }

  static bool isSeparator(Object cell) =>
      cell == LcdCell.dot || cell == LcdCell.comma || cell == LcdCell.gap;

  @override
  bool shouldRepaint(RadioLcdPainter old) =>
      !listEquals(old.cells, cells) || old.palette.ink != palette.ink || old.palette.ghost != palette.ghost;
}

/// The LCD cells for [khz], at Hz precision — the frequency a radio is
/// actually on, which is the whole reason this panel exists.
///
/// Leading zeros are suppressed to blanks rather than dropped, so the decimal
/// point stays in the same column whether the rig is on 3.5 MHz or 145 MHz.
/// A radio's own display does exactly this, and a readout that slid sideways
/// as the operator crossed 10 MHz would be unreadable at a glance.
///
/// [digitsBeforeDot] is how many MHz-and-kHz digits to reserve. Six covers
/// every band a transceiver with a CAT port is likely to be on, through
/// 70 cm at 435,000 kHz. A frequency wider than the reserve is NOT truncated
/// — it takes the extra column it needs — so 23 cm and up render correctly
/// and simply sit wider. Reserving seven for them instead would spend a
/// blank column on every operator who never leaves HF.
List<Object> lcdCellsForFrequency(double? khz, {int digitsBeforeDot = 6}) {
  final digits = khz == null
      ? ' ' * digitsBeforeDot
      : ((khz * 1000).round().abs() ~/ 1000).toString().padLeft(digitsBeforeDot, ' ');

  final cells = <Object>[];
  for (var i = 0; i < digits.length; i++) {
    // The grouping column is reserved at every grouping position, whether or
    // not a mark is drawn in it. Emitting it only where a digit precedes it
    // makes a sub-MHz reading — and the blank placeholder — one column
    // narrower than everything else, and the painter answers a narrower
    // readout with bigger digits in different places.
    if (i > 0 && (digits.length - i) % 3 == 0) {
      cells.add(digits[i - 1] == ' ' ? LcdCell.gap : LcdCell.comma);
    }
    cells.add(digits[i] == ' ' ? LcdCell.blank : int.parse(digits[i]));
  }
  cells.add(LcdCell.dot);
  final fraction = khz == null ? null : (khz * 1000).round().abs() % 1000;
  for (var i = 0; i < 3; i++) {
    cells.add(fraction == null ? LcdCell.blank : int.parse(fraction.toString().padLeft(3, '0')[i]));
  }
  return cells;
}

/// A power reading as text — the ONE spelling, so the segments, the Modern
/// face and the screen reader cannot state different numbers for the same
/// watts.
///
/// Never rounded to a whole number. A QRPp rig reporting 0.5 W would read
/// "0 W", which is not merely imprecise: 0 W is a meaningful reading (a dead
/// transmitter), so rounding invents the one answer an operator must be able
/// to trust. Trailing zeros are trimmed instead, so a driver reporting the
/// double `100.0` and one reporting the int `100` agree.
String powerText(num watts) {
  if (watts == watts.roundToDouble()) return watts.round().toString();
  final fixed = watts.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// The LCD cells for a power reading, spelled by [powerText].
///
/// No blank padding, unlike [lcdCellsForFrequency]: a power reading changes
/// rarely and sits against the pane's right edge, so reserving columns for
/// digits it may never have would push it away from that edge and leave a gap
/// that reads as a fault.
List<Object> lcdCellsForPower(num watts) => [
      for (final char in powerText(watts).split(''))
        if (char == '.') LcdCell.dot else if (char == '-') LcdCell.blank else int.parse(char),
    ];

/// How wide [cells] paints at [height], so a row can give the painter a box
/// that fits the digits exactly.
///
/// The painter derives its cell size from whichever of width and height
/// binds, so a box measured any other way either clips the readout or
/// centres it inside slack — and against a right edge, slack reads as a
/// misalignment rather than as padding.
double lcdWidthForCells(List<Object> cells, double height) {
  final cellWidth = height / RadioLcdPainter.cellAspect;
  var slots = 0.0;
  for (final cell in cells) {
    slots += RadioLcdPainter.isSeparator(cell) ? RadioLcdPainter.separatorWidth : 1.0;
    slots += RadioLcdPainter.gap;
  }
  return (slots - RadioLcdPainter.gap) * cellWidth;
}

/// A lit legend on an LCD — the mode, and anything else a rig names rather
/// than counts.
///
/// A box with text, NOT seven-segment digits: a real display prints these as
/// fixed legends that light up, because seven segments cannot spell them
/// (there is no `W` on a seven-segment cell, so `CW` is unrenderable). Faking
/// it with the nearest-looking glyphs would produce a mode readout that is
/// wrong for exactly the modes an operator most needs to trust.
class LcdAnnunciator extends StatelessWidget {
  final String text;
  final RadioPalette palette;

  /// The cap height to match — the row this sits in, so the legend and a
  /// segment readout beside it share a baseline.
  final double height;

  const LcdAnnunciator({super.key, required this.text, required this.palette, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: height * 0.22, vertical: height * 0.08),
      decoration: BoxDecoration(
        // The unlit ghost behind it, like the segments' — it is what makes
        // the legend read as part of the display rather than as a chip
        // floating on the glass.
        color: palette.ghost,
        border: Border.all(color: palette.ink, width: height * 0.06),
        borderRadius: BorderRadius.circular(height * 0.16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.ink,
          fontSize: height * 0.62,
          fontWeight: FontWeight.w700,
          // Tight and even, the way a printed legend is — a proportional
          // face makes it read as prose set on the glass.
          letterSpacing: height * 0.06,
          height: 1.0,
        ),
      ),
    );
  }
}

/// A segmented bar — a rig's own LED meter, in the pane's colours.
///
/// Segments rather than a continuous fill because that is what the thing
/// being copied does, and because it reads at a glance: an operator watching
/// a transmission is counting blocks out of the corner of their eye, not
/// measuring a bar's length. It also stops a 200 ms cadence from looking
/// twitchier than the radio is — a value wobbling by a percent moves a
/// continuous fill on every poll and a segmented one not at all.
///
/// The SCALE is the caller's, not this widget's: watts against the power the
/// radio was set to, SWR against 1.0-3.0. All this knows is a fraction and
/// where the red zone starts.
class MeterBarPainter extends CustomPainter {
  /// How much of the bar is lit, 0.0-1.0. Values above 1 pin the bar full
  /// rather than overflowing it — an SWR off the end of the scale is still
  /// only "as bad as this bar can say", and the number beside it is what
  /// carries the rest.
  final double fraction;

  /// Where the alert zone begins, as a fraction — 0.4 for SWR, whose scale
  /// runs 1.0-3.0 and whose threshold is 1.8. Null for a meter with no such
  /// zone.
  final double? alertFrom;

  final Color lit;
  final Color unlit;
  final Color alert;

  const MeterBarPainter({
    required this.fraction,
    required this.lit,
    required this.unlit,
    required this.alert,
    this.alertFrom,
  });

  /// A segment and the gap after it. Fixed, with the COUNT derived from the
  /// width — so a wide pane gets a finer bar rather than fatter blocks, and
  /// a narrow one degrades to a handful of chunky ones instead of a row of
  /// slivers.
  static const _segmentWidth = 4.0;
  static const _segmentGap = 2.0;
  static const _minSegments = 4;
  static const _maxSegments = 32;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final count = ((size.width + _segmentGap) / (_segmentWidth + _segmentGap))
        .floor()
        .clamp(_minSegments, _maxSegments);
    final width = (size.width - _segmentGap * (count - 1)) / count;
    if (width <= 0) return;
    final litCount = litSegments(fraction, count);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final inAlertZone = isAlertSegment(i, count, alertFrom);
      paint.color = switch ((i < litCount, inAlertZone)) {
        (true, true) => alert,
        (true, false) => lit,
        // The red zone is printed on the scale of a real meter whether the
        // needle is in it or not, and that is worth keeping: it says where
        // the line IS before the operator crosses it.
        (false, true) => alert.withValues(alpha: 0.22),
        (false, false) => unlit,
      };
      canvas.drawRect(Rect.fromLTWH(i * (width + _segmentGap), 0, width, size.height), paint);
    }
  }

  /// How many of [count] segments a [fraction] lights.
  ///
  /// Any reading at all lights one. Rounding alone shows an EMPTY bar for a
  /// real transmission at the bottom of its scale — a QRP rig measured
  /// against a 100 W set level — which reads as a radio putting out nothing
  /// at the exact moment it is putting out something.
  static int litSegments(double fraction, int count) {
    final target = fraction.clamp(0.0, 1.0);
    return target <= 0 ? 0 : (target * count).round().clamp(1, count);
  }

  /// Whether segment [i] of [count] falls in the red zone. Measured at the
  /// segment's MIDDLE, so the segment straddling the threshold belongs to
  /// whichever side most of it is on.
  static bool isAlertSegment(int i, int count, double? alertFrom) =>
      alertFrom != null && (i + 0.5) / count >= alertFrom;

  @override
  bool shouldRepaint(MeterBarPainter old) =>
      old.fraction != fraction ||
      old.alertFrom != alertFrom ||
      old.lit != lit ||
      old.unlit != unlit ||
      old.alert != alert;
}
