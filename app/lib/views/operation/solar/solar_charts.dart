// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two series the solar panel draws: a month of solar flux as a line, and
// three days of planetary Kp as bars.
//
// The geometry is separated from the painting on purpose, the same way
// weather_chart.dart does it — `solarLine` and `solarBars` answer with a Path
// and a list of Rects, which are measurable, where a Canvas is not.
//
// A polyline, deliberately, where the weather curve is a spline: these are
// daily observations a month wide, and smoothing them would invent a
// Tuesday's flux that nobody measured. The weather curve interpolates because
// temperature between two hours genuinely is continuous; F10.7 is one number
// per day, read at 20:00 UTC.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The colours the panel uses for a rating or an index level, in a single
/// place because three surfaces have to agree: the band grid's cells, the Kp
/// bars, and the headline numbers' own accents. A green bar over a cell
/// called "Poor" is the failure this prevents.
///
/// Fixed values rather than `ColorScheme` roles, and the same in both
/// brightnesses. There is no green/amber/red in the scheme to take, and these
/// have to keep their MEANING rather than invert with the theme — an operator
/// reads "red" as a warning at midnight too. Mid-tones, so each stays legible
/// on the light surface (#FDFCFF) and the dark one (#191C1E) alike.
class SolarPalette {
  static const Color good = Color(0xFF2E9E4F);
  static const Color fair = Color(0xFFC08316);
  static const Color poor = Color(0xFFD04A34);

  /// Beyond poor: a severe geomagnetic storm, which the K scale reaches and
  /// the band ratings do not. Violet rather than a darker red, matching the
  /// SOLAR command's own 🟣 (`extensions/shared/spaceWeather.ts`) — the two
  /// must not disagree about what a K of 8 looks like.
  static const Color severe = Color(0xFF8B5CC7);
}

/// The colour for a Kp or K reading, on the same thresholds
/// `emojiForKIndex` uses in `extensions/shared/spaceWeather.ts`. Ported
/// rather than shared because that table lives in the extension runtime and
/// cannot be reached from Dart — a threshold changed there has to be changed
/// here too, or a command and a panel describe the same storm differently.
Color solarKColor(double k) {
  if (k <= 3) return SolarPalette.good;
  if (k < 5) return SolarPalette.fair;
  if (k < 7) return SolarPalette.poor;
  return SolarPalette.severe;
}

/// The colour for an A index, likewise ported from `emojiForAIndex`. Its
/// 🟤 band (50–99) folds into [SolarPalette.poor] here: brown reads as a
/// muted colour rather than a worse one at chip size, so the scale would go
/// backwards on screen where it does not in emoji.
Color solarAColor(int a) {
  if (a < 20) return SolarPalette.good;
  if (a < 30) return SolarPalette.fair;
  if (a < 100) return SolarPalette.poor;
  return SolarPalette.severe;
}

/// The colour for a solar flux index, from `emojiForSFI`. Its scale runs the
/// other way — a HIGH flux is the good news — and its 🔵 band (150–199) has
/// no equivalent here, so it folds up into [SolarPalette.good] rather than
/// down: 150 is a good day on the air, and a colour saying otherwise would
/// contradict the band grid beside it.
Color solarFluxColor(int sfi) {
  if (sfi < 100) return SolarPalette.poor;
  if (sfi < 150) return SolarPalette.fair;
  return SolarPalette.good;
}

/// Vertical breathing room, so the highest point is not clipped by the top
/// edge and the lowest does not sit on the baseline.
const double _padding = 4;

/// The smallest span the flux axis will show. Without it a quiet month that
/// varies by two points is drawn as a mountain range.
const double solarMinFluxSpan = 20;

/// The same guard for wind speed, in km/s, where the units are far bigger and
/// so is a boring hour. The wind sits near 300 and a quiet one wanders by ten
/// or fifteen — two per cent, and meaningless — where the changes that matter
/// to an operator are the climbs into the 500s and 600s. Measured on the flux
/// axis's 20, a calm hour is drawn as a storm.
const double solarMinWindSpan = 100;

/// The line through [values] across [size], and the points it passes through.
///
/// Empty path and no points for fewer than two values: a single observation
/// is not a trend, and drawing it as a flat line across the pane would claim
/// a month of data the panel does not have.
({Path path, List<Offset> points}) solarLine(
  List<double> values,
  Size size, {
  double minSpan = solarMinFluxSpan,
}) {
  if (values.length < 2 || size.width <= 0 || size.height <= 0) {
    return (path: Path(), points: const []);
  }

  var lo = values.reduce(math.min);
  var hi = values.reduce(math.max);
  if (hi - lo < minSpan) {
    final middle = (hi + lo) / 2;
    lo = middle - minSpan / 2;
    hi = middle + minSpan / 2;
  }
  final top = _padding;
  final bottom = size.height - _padding;

  final points = <Offset>[
    for (final (index, value) in values.indexed)
      Offset(
        size.width * index / (values.length - 1),
        bottom - ((value - lo) / (hi - lo)) * (bottom - top),
      ),
  ];

  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return (path: path, points: points);
}

/// The Kp scale's ceiling. Fixed rather than fitted to the data, and that is
/// the whole point: a quiet week fitted to its own maximum would draw a Kp of
/// 2 as a full-height bar, which is exactly the alarm this panel exists to
/// avoid raising. A bar's height means the same thing every day.
const double solarKpCeiling = 9;

/// Where a storm starts — NOAA's G1. The chart draws a line here so a bar is
/// read against the threshold rather than against its neighbours.
const double solarKpStorm = 5;

/// One bar per value across [size], each at most [solarKpCeiling] tall.
///
/// Bars are laid out as equal columns with a gap, rather than butted
/// together: three days is 24 of them, and a solid block reads as a filled
/// area chart rather than as discrete three-hour readings.
List<Rect> solarBars(List<double> values, Size size) {
  if (values.isEmpty || size.width <= 0 || size.height <= 0) return const [];
  final column = size.width / values.length;
  final width = math.max(1.0, column * 0.72);
  return [
    for (final (index, value) in values.indexed)
      () {
        // Floored at a hairline so a Kp of 0 is still a mark on the axis —
        // "quiet" and "no reading" are different, and the second is drawn by
        // there being no bar at all.
        final height = math.max(1.0, size.height * (value.clamp(0, solarKpCeiling) / solarKpCeiling));
        return Rect.fromLTWH(
          column * index + (column - width) / 2,
          size.height - height,
          width,
          height,
        );
      }(),
  ];
}

/// A chart band's own minimum, checked by the painters against the height
/// they are actually given. Below this a curve is a smear rather than a
/// shape, and bars are a texture.
///
/// Checked HERE rather than by a `LayoutBuilder` around each chart. That is
/// not a style preference: three of them, nested inside the readout's own,
/// rebuild their whole subtree during layout every time the constraints
/// change — and a pane being resized changes them on every frame. They cost
/// about 5ms per relayout between them where the painting they guard costs
/// 0.3ms, which is the difference between a divider that follows the pointer
/// and one that moves in steps. The painter is handed the size anyway.
const double solarChartFloor = 24;

/// A label pinned to one mark on a chart: what the mark reads, and when it
/// was.
///
/// Both strings are built by the panel, not here — one carries a localized
/// date and the other a number formatted the way the rest of the pane formats
/// numbers, and neither belongs in a painter that otherwise knows only
/// geometry.
typedef SolarChartLabel = ({int index, String metric, String detail});

/// Lays out and draws chart labels.
///
/// Labels sit ON the charts because the charts run to the pane's edges and
/// there is no margin to put them in. That is also why each one is drawn over
/// a plate of the pane's own background: a bare label is crossed by the very
/// line or bar it is describing, which is only obvious against real data —
/// a fixture whose curve happens to run elsewhere hides it completely.
class _LabelDrawer {
  final Canvas canvas;
  final Size size;

  /// The detail line's style. The metric above it is this, emboldened.
  final TextStyle style;

  /// What the label is drawn over, so the mark beneath it does not run
  /// through the type.
  final Color plate;

  _LabelDrawer(this.canvas, this.size, this.style, this.plate);

  /// Draws a label beside [anchor], or does nothing if there is no room for
  /// it inside the box.
  ///
  /// [preferBelow] is a preference, not an instruction: a label for the
  /// highest point of a series has to go below it or leave the box, and one
  /// for the lowest has to go above.
  void at(Offset anchor, String metric, String detail, {required bool preferBelow}) {
    // Anchored INWARD near the edges: a label centred on the first point of a
    // series starts off the left of the box, and clamping it back would slide
    // it away from the mark it names.
    final TextAlign align;
    if (anchor.dx < size.width / 3) {
      align = TextAlign.left;
    } else if (anchor.dx > size.width * 2 / 3) {
      align = TextAlign.right;
    } else {
      align = TextAlign.center;
    }

    final painter = TextPainter(
      text: TextSpan(
        style: style,
        children: [
          // The reading is what the pointer was asking for; the date is what
          // qualifies it.
          TextSpan(text: metric, style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: '\n$detail'),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
    )..layout();

    final double left = switch (align) {
      TextAlign.left => anchor.dx,
      TextAlign.right => anchor.dx - painter.width,
      _ => anchor.dx - painter.width / 2,
    };

    const gap = 4.0;
    // Held off the pane's edges. The charts run edge to edge, so a label for
    // the first or last mark sits exactly on one, and a glyph flush against
    // the boundary reads as clipped whether or not it is.
    const margin = 6.0;
    final rightmost = math.max(0.0, size.width - painter.width - margin);
    for (final below in [preferBelow, !preferBelow]) {
      final top = below ? anchor.dy + gap : anchor.dy - gap - painter.height;
      final rect = Rect.fromLTWH(
        left.clamp(math.min(margin, rightmost), rightmost),
        top,
        painter.width,
        painter.height,
      );
      if (rect.top < 0 || rect.bottom > size.height) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(2)),
        Paint()..color = plate,
      );
      painter.paint(canvas, rect.topLeft);
      return;
    }
  }
}

/// A line chart. Two series use it now — the month of flux and the hour of
/// wind — which is why it is named for the SHAPE rather than for either.
class SolarLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color line;
  final Color fill;

  /// The day the pointer is over, or null. Marked on the curve so the number
  /// the caption is showing has a place on the chart — a bare readout of "SFI
  /// 132" over a thirty-day line leaves the operator to guess WHICH day it
  /// read that.
  final int? hovered;

  /// The marks that name themselves, in priority order — see [_LabelDrawer].
  final List<SolarChartLabel> labels;

  /// What those labels are drawn in, and what they are drawn over.
  final TextStyle labelStyle;
  final Color labelPlate;

  /// The smallest range the axis will show — the guard against a quiet series
  /// drawn as a mountain range. Per SERIES, because it is in the series' own
  /// units: see [solarMinFluxSpan] and [solarMinWindSpan].
  final double minSpan;

  const SolarLineChartPainter({
    required this.values,
    required this.line,
    required this.fill,
    required this.labelStyle,
    required this.labelPlate,
    this.minSpan = solarMinFluxSpan,
    this.labels = const [],
    this.hovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < solarChartFloor) return;
    final chart = solarLine(values, size, minSpan: minSpan);
    if (chart.points.isEmpty) return;

    final under = Path.from(chart.path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      under,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill, fill.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      chart.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );

    // The most recent day, marked. The line's right end is the only point on
    // this chart an operator matches against the big number above it.
    canvas.drawCircle(chart.points.last, 2.5, Paint()..color = line);

    // Bounds-checked rather than trusted: the index comes from a pointer
    // position measured against the LAST painted size, and a pane resized
    // under a stationary cursor delivers the old index against a shorter
    // series.
    if (hovered case final index? when index >= 0 && index < chart.points.length) {
      final point = chart.points[index];
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, size.height),
        Paint()
          ..strokeWidth = 1
          ..color = line.withValues(alpha: 0.35),
      );
      canvas.drawCircle(point, 3.5, Paint()..color = line);
    }

    final drawer = _LabelDrawer(canvas, size, labelStyle, labelPlate);
    for (final label in labels) {
      if (label.index < 0 || label.index >= chart.points.length) continue;
      final point = chart.points[label.index];
      // Below when the point is high in the box, above when it is low —
      // whichever side has the room.
      drawer.at(point, label.metric, label.detail, preferBelow: point.dy < size.height / 2);
    }
  }

  @override
  bool shouldRepaint(SolarLineChartPainter old) =>
      !listEquals(old.values, values) ||
      old.line != line ||
      old.fill != fill ||
      old.minSpan != minSpan ||
      old.hovered != hovered ||
      old.labelStyle != labelStyle ||
      old.labelPlate != labelPlate ||
      !listEquals(old.labels, labels);
}

class SolarKpChartPainter extends CustomPainter {
  final List<double> values;
  final Color storm;

  /// The bar the pointer is over, or null. See [SolarLineChartPainter.hovered].
  final int? hovered;

  /// What the hovered bar is outlined in. Its own colour rather than [storm]:
  /// the threshold rule is drawn faint on purpose, and an outline that faint
  /// is invisible against the bar it is meant to be picking out — which is
  /// only obvious in the light theme, where `storm` is palest.
  final Color highlight;

  /// The bars that name themselves, in priority order — see [_LabelDrawer].
  final List<SolarChartLabel> labels;

  /// What those labels are drawn in, and what they are drawn over.
  final TextStyle labelStyle;
  final Color labelPlate;

  const SolarKpChartPainter({
    required this.values,
    required this.storm,
    required this.highlight,
    required this.labelStyle,
    required this.labelPlate,
    this.labels = const [],
    this.hovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height < solarChartFloor) return;

    final stormY = size.height * (1 - solarKpStorm / solarKpCeiling);
    // Dashed, so it reads as a threshold rather than as another series.
    final dash = Paint()
      ..strokeWidth = 1
      ..color = storm;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, stormY), Offset(math.min(x + 3, size.width), stormY), dash);
    }

    for (final (index, rect) in solarBars(values, size).indexed) {
      final bar = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(1.5),
        topRight: const Radius.circular(1.5),
      );
      canvas.drawRRect(bar, Paint()..color = solarKColor(values[index]));
      // Outlined rather than recoloured: every bar's colour already MEANS
      // something here, and a hover that changed one would be saying the
      // period got quieter or stormier under the cursor.
      if (index == hovered) {
        canvas.drawRRect(
          bar,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = highlight,
        );
      }
    }

    final bars = solarBars(values, size);
    final drawer = _LabelDrawer(canvas, size, labelStyle, labelPlate);
    for (final label in labels) {
      if (label.index < 0 || label.index >= bars.length) continue;
      final bar = bars[label.index];
      // Above the bar's TOP, which is where the reading is. Above its base
      // would put the label along the bottom, naming the bar by proximity
      // rather than by height.
      drawer.at(Offset(bar.center.dx, bar.top), label.metric, label.detail, preferBelow: false);
    }
  }

  @override
  bool shouldRepaint(SolarKpChartPainter old) =>
      !listEquals(old.values, values) ||
      old.storm != storm ||
      old.highlight != highlight ||
      old.hovered != hovered ||
      old.labelStyle != labelStyle ||
      old.labelPlate != labelPlate ||
      !listEquals(old.labels, labels);
}
