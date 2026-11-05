// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spectrum's trace and the fill under it: smoothed, dashed, colored by
// level, and drawn in each overlay's own look over the frequencies it spans
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

/// How the trace and its fill are drawn, resolved: [traceColors] and
/// [fillColors] are stops by level, in place of [trace] and of [fill] with
/// [fillBottom].
typedef _Look = ({
  Color trace,
  List<SceneSpectrumStop>? traceColors,
  double width,
  bool dashed,
  Color fill,
  Color? fillBottom,
  List<SceneSpectrumStop>? fillColors,
});

/// [base] with what an overlay's [trace] names in its place: a color replaces
/// the stops beneath it, and stops the color.
_Look _overlayLook(_Look base, SceneSpectrumTrace trace, double? Function(SceneNumber?) number) {
  final fill = trace.fill != null || trace.fillColors != null;
  return (
    trace: trace.color ?? base.trace,
    traceColors: trace.color != null ? null : trace.colors ?? base.traceColors,
    width: number(trace.width) ?? base.width,
    dashed: trace.dashed ?? base.dashed,
    fill: trace.fill ?? base.fill,
    fillBottom: fill ? null : base.fillBottom,
    fillColors: trace.fill != null ? null : trace.fillColors ?? base.fillColors,
  );
}

/// The sweep's [bins] across [size], [floor] to [floor] + [range] dB up it:
/// each overlay with a trace look draws its frequencies, a later one over an
/// earlier, and the control's look the rest.
void _paintTrace(Canvas canvas, Size size, SpectrumFrame bins, SpectrumFrame window, double floor, double range, _Style style, _Marks marks) {
  final levels = bins.levels, span = (window.highHz - window.lowHz).toDouble();
  final n = levels.length, binHz = (bins.highHz - bins.lowHz) / (n - 1);
  double x(int i) => (bins.lowHz + i * binHz - window.lowHz) / span * size.width;
  // Bin i at lowHz + i × the sweep's width / (n − 1), so a window that is the
  // whole sweep runs the trace edge to edge; bins off the window are skipped,
  // all but one either side, which carries the line to the edge.
  final first = ((window.lowHz - bins.lowHz) / binHz).floor().clamp(0, n - 1);
  final last = ((window.highHz - bins.lowHz) / binHz).ceil().clamp(0, n - 1);
  if (last <= first) return;
  double y(double level) => size.height - ((level - floor) / range).clamp(0.0, 1.0) * size.height;
  final smooth = style.smooth;
  final path = Path();
  if (smooth <= 0) {
    for (var i = first; i <= last; i++) {
      i == first ? path.moveTo(x(i), y(levels[i])) : path.lineTo(x(i), y(levels[i]));
    }
  } else {
    // Each point the mean of the bins within half [smooth] pixels of it, and a
    // curve through them: at least its neighbours, however wide a bin is.
    final pixelsPerBin = binHz / span * size.width;
    final reach = math.max(1, (smooth / 2 / pixelsPerBin).round());
    final sums = Float64List(n + 1);
    for (var i = 0; i < n; i++) {
      sums[i + 1] = sums[i] + levels[i];
    }
    Offset at(int i) {
      final (lo, hi) = (math.max(0, i - reach), math.min(n - 1, i + reach));
      return Offset(x(i), y((sums[hi + 1] - sums[lo]) / (hi - lo + 1)));
    }

    var previous = at(first);
    path.moveTo(previous.dx, previous.dy);
    for (var i = first + 1; i <= last; i++) {
      final point = at(i), middle = (previous + point) / 2;
      path.quadraticBezierTo(previous.dx, previous.dy, middle.dx, middle.dy);
      previous = point;
    }
    path.lineTo(previous.dx, previous.dy);
  }
  final fill = Path.from(path)
    ..lineTo(x(last), size.height)
    ..lineTo(x(first), size.height)
    ..close();
  Path? dashed;
  final noise = window.noiseDb ?? bins.noiseDb;
  Shader byLevel(List<SceneSpectrumStop> stops) => _byLevel(stops, size, noise: noise, floor: floor, range: range);
  void draw(_Look look) {
    canvas.drawPath(fill, _fillPaint(look, size, byLevel));
    final stroke = Paint()
      ..color = look.traceColors == null ? look.trace : _opaque
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.width
      ..shader = look.traceColors == null ? null : byLevel(look.traceColors!);
    canvas.drawPath(look.dashed ? dashed ??= _dash(path) : path, stroke);
  }

  final ranges = _traceRanges(size, window, style, marks);
  if (ranges.isEmpty) return draw(style.look);
  // Each part of the width once, in the look of the last range over it.
  final whole = Offset.zero & size;
  for (var i = -1; i < ranges.length; i++) {
    var area = Path()..addRect(i < 0 ? whole : ranges[i].rect);
    for (final later in ranges.skip(i + 1)) {
      area = Path.combine(PathOperation.difference, area, Path()..addRect(later.rect));
    }
    canvas.save();
    canvas.clipPath(area);
    draw(i < 0 ? style.look : ranges[i].look);
    canvas.restore();
  }
}

/// The overlays with a trace look, where their frequencies fall across [size].
List<({Rect rect, _Look look})> _traceRanges(Size size, SpectrumFrame window, _Style style, _Marks marks) {
  final span = (window.highHz - window.lowHz).toDouble();
  return [
    for (final mark in marks.spec.overlays)
      if (mark.trace case final trace?)
        if (switch (mark.anchor) {
              SceneSpectrumAnchor.vfo => marks.vfoHz(),
              SceneSpectrumAnchor.center => (window.lowHz + window.highHz) / 2,
              SceneSpectrumAnchor.absolute => 0.0,
            }
            case final anchor?)
          if ((marks.number(mark.from), marks.number(mark.to)) case (final from?, final to?))
            (
              rect: Rect.fromLTRB(
                (anchor + math.min(from, to) - window.lowHz) / span * size.width,
                0,
                (anchor + math.max(from, to) - window.lowHz) / span * size.width,
                size.height,
              ),
              look: _overlayLook(style.look, trace, marks.number),
            ),
  ];
}

/// A shaded paint's color: its alpha scales the shader's, which carries each
/// stop's own already.
const _opaque = Color(0xFF000000);

Paint _fillPaint(_Look look, Size size, Shader Function(List<SceneSpectrumStop>) byLevel) {
  final paint = Paint()..color = look.fill;
  if (look.fillColors case final stops?) {
    return paint
      ..color = _opaque
      ..shader = byLevel(stops);
  }
  // Top of the pane to its bottom, not along the trace: a signal reads
  // brighter the taller it stands.
  if (look.fillBottom case final bottom?) {
    paint.color = _opaque;
    paint.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [look.fill, bottom]).createShader(Offset.zero & size);
  }
  return paint;
}

/// Stops lowest level first, from the spectrum's bottom to its top: spread
/// evenly, or each at its level. Until the noise is known one placed by it
/// has no level, and the stops are spread evenly meanwhile.
Shader _byLevel(List<SceneSpectrumStop> stops, Size size, {double? noise, required double floor, required double range}) {
  final placed = [
    for (final stop in stops)
      if (stop.at?.at((_) => (top: 0, bottom: size.height), size.height, noise: noise, floor: floor, range: range) case final y?)
        (color: stop.color, share: size.height <= 0 ? 0.0 : (1 - y / size.height).clamp(0.0, 1.0)),
  ];
  if (placed.length < stops.length || placed.length < 2) {
    return LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [for (final s in stops) s.color]).createShader(Offset.zero & size);
  }
  // A gradient's stops rise; levels named from the noise and from the edges can cross as the floor moves.
  placed.sort((a, b) => a.share.compareTo(b.share));
  return LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [for (final p in placed) p.color],
    stops: [for (final p in placed) p.share],
  ).createShader(Offset.zero & size);
}

/// [path] in dashes six pixels long, four apart, measured along it.
Path _dash(Path path) {
  final dashes = Path();
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += 10) {
      dashes.addPath(metric.extractPath(d, math.min(d + 6, metric.length)), Offset.zero);
    }
  }
  return dashes;
}
