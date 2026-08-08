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

import 'package:flutter/animation.dart' show Cubic;

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
Path segmentPath(
  ClockSegment segment, {
  required Size cellSize,
  required double stroke,
  double gap = 1.5,
}) {
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

/// How long the SBB second hand takes to go round, before it waits.
///
/// The pause is the face's signature, not a quirk: the hand is driven to 12
/// early and holds there for the minute impulse from the master clock. A
/// smooth 60-second sweep is a different clock that merely looks similar.
const int swissSweepMillis = 58500;

/// The SBB second hand, in degrees clockwise from 12 — linear over
/// [swissSweepMillis], then motionless at 12 until the minute rolls over.
///
/// Derived from wall-clock time on every frame, never integrated from frame
/// deltas: an integrated hand accumulates error and arrives at 12 late, which
/// is the one thing this face exists to get right.
double swissSecondAngle(int msIntoMinute) {
  if (msIntoMinute <= 0) return 0;
  if (msIntoMinute >= swissSweepMillis) return 360;
  return msIntoMinute * 360 / swissSweepMillis;
}

/// The SBB minute hand's step, in degrees clockwise from 12.
///
/// It does not creep. It rests, then snaps to the next mark with a slight
/// overshoot as the impulse lands — [_swissStep] is that motion. A minute
/// hand that advances smoothly makes this face indistinguishable from the
/// plain analog one.
double swissMinuteAngle(int minute, int msIntoMinute) {
  const stepMillis = 200;
  final target = (minute % 60) * 6.0;
  if (msIntoMinute >= stepMillis) return target;
  final t = msIntoMinute <= 0 ? 0.0 : msIntoMinute / stepMillis;
  return target - 6.0 * (1 - _swissStep.transform(t));
}

/// Overshoot-and-settle. The `y > 1` control point is what puts the hand
/// slightly past the mark before it drops back.
const _swissStep = Cubic(0.4, 2.08, 0.55, 0.44);

/// The plain round face's hands, in degrees clockwise from 12.
///
/// The hour hand creeps with the minutes and the minute hand with the
/// seconds; only the second hand steps. Sharing [swissMinuteAngle]'s stepping
/// here would collapse the two faces into one.
({double hour, double minute, double second}) analogHandAngles(DateTime wall) {
  final second = wall.second.toDouble();
  final minute = wall.minute + second / 60;
  final hour = wall.hour % 12 + minute / 60;
  return (hour: hour * 30, minute: minute * 6, second: second * 6);
}

/// The SBB dial's marks — twelve hour bars and forty-eight minute bars — as
/// one path in a circle of [radius] centred on the origin.
///
/// Filled rects, never strokes: one logical pixel is well under a device
/// pixel at the smaller font scales, and a hairline stroke antialiases into a
/// grey smear where a filled bar stays crisp.
///
/// Proportions are SBB's, normalized from the 105-unit drawing: hour bars
/// 3.5 wide spanning radius 36.5→48.5, minute bars 1.4 wide spanning
/// 45.0→48.5, on a 52.5 radius.
Path swissMarksPath(double radius) {
  final k = radius / 52.5;
  final path = Path();
  for (var i = 0; i < 60; i++) {
    final isHour = i % 5 == 0;
    final halfWidth = (isHour ? 3.5 : 1.4) * k / 2;
    final inner = (isHour ? 36.5 : 45.0) * k;
    final outer = 48.5 * k;
    final angle = i * math.pi / 30;
    final sin = math.sin(angle);
    final cos = math.cos(angle);
    // Built at 12 and rotated into place by hand — a Canvas rotation per mark
    // would be 60 save/restore pairs per frame on the sweeping face.
    void add(double x, double y) {
      final rx = x * cos - y * sin;
      final ry = x * sin + y * cos;
      if (x == -halfWidth && y == -outer) {
        path.moveTo(rx, ry);
      } else {
        path.lineTo(rx, ry);
      }
    }

    add(-halfWidth, -outer);
    add(halfWidth, -outer);
    add(halfWidth, -inner);
    add(-halfWidth, -inner);
    path.close();
  }
  return path;
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

/// The smallest dial worth drawing. SBB's own minimum for the face; below it
/// the minute bars stop resolving and it reads as a smudged circle.
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
