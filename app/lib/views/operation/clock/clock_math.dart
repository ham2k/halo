// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The clock faces' geometry and arithmetic, with no widget and no
// BuildContext, so all of it unit-tests without pumping anything.
//
// Every angle here is DEGREES CLOCKWISE FROM 12, which is not what
// `Canvas.rotate` takes — the painters convert. Keeping the maths in the
// units a horologist would use is what makes the expected values in
// panel_clock_*_test.dart readable as clock positions rather than as
// radians-minus-a-quarter-turn.
//
// Dimensions are plain logical pixels. The Font Scale setting already scales
// the whole UI from one root wrapper, so nothing here may be multiplied by it
// (docs/design/ui-scaling.md).

import 'dart:math' as math;
import 'dart:ui';

/// Seven-segment positions: `a` the top bar, then clockwise, with `g` the
/// middle bar.
enum ClockSegment { a, b, c, d, e, f, g }

const _digitSegments = <Set<ClockSegment>>[
  {ClockSegment.a, ClockSegment.b, ClockSegment.c, ClockSegment.d, ClockSegment.e, ClockSegment.f},
  {ClockSegment.b, ClockSegment.c},
  {ClockSegment.a, ClockSegment.b, ClockSegment.g, ClockSegment.e, ClockSegment.d},
  {ClockSegment.a, ClockSegment.b, ClockSegment.g, ClockSegment.c, ClockSegment.d},
  {ClockSegment.f, ClockSegment.g, ClockSegment.b, ClockSegment.c},
  {ClockSegment.a, ClockSegment.f, ClockSegment.g, ClockSegment.c, ClockSegment.d},
  {ClockSegment.a, ClockSegment.f, ClockSegment.g, ClockSegment.e, ClockSegment.c, ClockSegment.d},
  {ClockSegment.a, ClockSegment.b, ClockSegment.c},
  {...ClockSegment.values},
  {ClockSegment.a, ClockSegment.b, ClockSegment.c, ClockSegment.d, ClockSegment.f, ClockSegment.g},
];

/// The segments [digit] lights. Empty for null, which is how a suppressed
/// leading zero is drawn — as nothing, not as `0`.
///
/// A Set rather than a bitmask deliberately: `1 << 30` is POSITIVE on web
/// where it is negative natively, and the native suite cannot see the
/// difference (docs/DEVELOPMENT.md's browser step is the only place that
/// would, and CI never runs it).
Set<ClockSegment> segmentsForDigit(int? digit) {
  if (digit == null || digit < 0 || digit > 9) return const {};
  return _digitSegments[digit];
}

/// One bevelled-hexagon segment inside a cell of [cellSize], [stroke] thick.
///
/// The 45° tips are the whole point: a plain rectangle reads as a font, and
/// the diagonal notch where two segments meet is what makes it read as a
/// physical display. [gap] is the unlit hairline between neighbours.
Path segmentPath(ClockSegment segment, {required Size cellSize, required double stroke, double gap = 1.5}) {
  final w = cellSize.width;
  final h = cellSize.height;
  final t = stroke;
  final half = t / 2;
  // Horizontal bars run the cell's width less a half-stroke at each end (the
  // verticals occupy that), vertical bars run half the cell's height.
  final hLength = w - t - gap * 2;
  final vLength = h / 2 - t - gap * 2;

  Path horizontal(double cy) {
    final x0 = half + gap;
    final x1 = x0 + hLength;
    return Path()
      ..moveTo(x0, cy)
      ..lineTo(x0 + half, cy - half)
      ..lineTo(x1 - half, cy - half)
      ..lineTo(x1, cy)
      ..lineTo(x1 - half, cy + half)
      ..lineTo(x0 + half, cy + half)
      ..close();
  }

  Path vertical(double cx, double top) {
    final y0 = top;
    final y1 = y0 + vLength;
    return Path()
      ..moveTo(cx, y0)
      ..lineTo(cx + half, y0 + half)
      ..lineTo(cx + half, y1 - half)
      ..lineTo(cx, y1)
      ..lineTo(cx - half, y1 - half)
      ..lineTo(cx - half, y0 + half)
      ..close();
  }

  switch (segment) {
    case ClockSegment.a:
      return horizontal(half);
    case ClockSegment.g:
      return horizontal(h / 2);
    case ClockSegment.d:
      return horizontal(h - half);
    case ClockSegment.f:
      return vertical(half, half + gap);
    case ClockSegment.b:
      return vertical(w - half, half + gap);
    case ClockSegment.e:
      return vertical(half, h / 2 + gap);
    case ClockSegment.c:
      return vertical(w - half, h / 2 + gap);
  }
}

/// The plain round face's hands, in degrees clockwise from 12.
///
/// The hour hand creeps with the minutes and the minute hand with the
/// seconds — none of the three hands step.
({double hour, double minute, double second}) analogHandAngles(DateTime wall) {
  final second = wall.second.toDouble();
  final minute = wall.minute + second / 60;
  final hour = wall.hour % 12 + minute / 60;
  return (hour: hour * 30, minute: minute * 6, second: second * 6);
}

/// Which readout fits the pane.
enum ClockForm {
  /// A round dial, or `HH:MM:SS`.
  full,

  /// `HH:MM` — the box is too tight for seconds, or seconds are off.
  short,

  /// A single line of plain text, for a pane too small for a face at all.
  compact,
}

/// The smallest dial worth drawing. Below it the analog face's minute ticks
/// stop resolving and it reads as a smudged circle.
const double minClockDiameter = 75;

/// Past this a dial stops looking like an instrument and starts looking like
/// a mistake — the marks scale with it and turn into slabs.
const double maxClockDiameter = 420;

/// The diameter for a round face in [box], or null when [box] cannot hold the
/// floor — the caller falls back to [ClockForm.compact].
double? clockDiameterFor(Size box) {
  final d = math.min(box.width, box.height);
  if (d < minClockDiameter) return null;
  return math.min(d, maxClockDiameter);
}

/// Which form fits [box]. A hard cut between forms, never a crossfade: an
/// AnimatedSwitcher here steals the semantics node on web
/// (docs/design/user-interface.md).
ClockForm clockFormFor(Size box, {required bool round, required bool showSeconds}) {
  if (round) return clockDiameterFor(box) == null ? ClockForm.compact : ClockForm.full;
  if (box.height < 28 || box.width < 90) return ClockForm.compact;
  // A six-digit readout needs half again the width of a four-digit one, and
  // the cell height is what makes it legible rather than the width.
  if (showSeconds && box.width >= 190) return ClockForm.full;
  return ClockForm.short;
}
