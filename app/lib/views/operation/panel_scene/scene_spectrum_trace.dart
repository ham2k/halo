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

/// How many pixels the picture and the filler past the sweep take to fade
/// one into the other, at most.
const _unsweptFadePixels = 24.0;

/// Darkens a paint's colors by half, its shader's included, keeping their alpha.
const _darker = ColorFilter.matrix([.5, 0, 0, 0, 0, 0, .5, 0, 0, 0, 0, 0, .5, 0, 0, 0, 0, 0, 1, 0]);

/// The sweep's [bins] across [size], [floor] to [floor] + [range] dB up it,
/// and past the sweep — a window off to one side of a scope that stays on
/// the dial, wider than the scope, or ahead of sweeps on their way — a
/// dashed line at the trace's middle level — the median of the bins drawn,
/// which carries on from the trace, as the noise estimated from the raw
/// sweeps does not — over the fill darkened: the picture's level kept,
/// marked as no reading. Left blank, a band past the scope reads as
/// silent; drawn alike, as heard. The two fade one into the other over the
/// sweep's last pixels, so its edge reads as the end of the reading rather
/// than a cliff in the band.
void _paintTrace(Canvas canvas, Size size, SpectrumFrame bins, SpectrumFrame window, double floor, double range, _Style style, _Marks marks) {
  final span = (window.highHz - window.lowHz).toDouble();
  double x(int hz) => (hz - window.lowHz) / span * size.width;
  final (left, right, noise) = (x(bins.lowHz), x(bins.highHz), window.noiseDb ?? bins.noiseDb);
  if (left <= 0 && right >= size.width) return _paintSweep(canvas, size, bins, window, floor, range, style, marks);
  final whole = Offset.zero & size;
  final fade = math.min(_unsweptFadePixels, (right - left) / 4);
  final shown = right > 0 && left < size.width;
  if (shown) {
    // The picture and the filler, each masked to its share, added into one layer: over the fade
    // their shares sum to the whole, where one laid over the other would thin both.
    canvas.saveLayer(whole, Paint());
    canvas.saveLayer(whole, Paint());
    _paintSweep(canvas, size, bins, window, floor, range, style, marks);
    canvas.drawRect(
      whole,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _sweptMask(size, left, right, fade, swept: true),
    );
    canvas.restore();
    canvas.saveLayer(whole, Paint()..blendMode = BlendMode.plus);
  }
  final middle = (Float32List.fromList(bins.levels)..sort())[bins.levels.length ~/ 2];
  final level = size.height - ((middle - floor) / range).clamp(0.0, 1.0) * size.height;
  final look = style.look;
  canvas.drawRect(
    Rect.fromLTRB(0, level, size.width, size.height),
    _fillPaint(look, size, (stops) => _byLevel(stops, size, noise: noise, floor: floor, range: range))..colorFilter = _darker,
  );
  canvas.drawPath(
    _dash(
      Path()
        ..moveTo(0, level)
        ..lineTo(size.width, level),
    ),
    Paint()
      ..color = look.trace
      ..style = PaintingStyle.stroke
      ..strokeWidth = look.width,
  );
  if (shown) {
    canvas.drawRect(
      whole,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _sweptMask(size, left, right, fade, swept: false),
    );
    canvas.restore();
    canvas.restore();
  }
}

/// Opaque over the sweep between [left] and [right] where [swept], and
/// past it where not, the two fading into each other over [fade] pixels
/// inside each of its edges the window shows.
Shader _sweptMask(Size size, double left, double right, double fade, {required bool swept}) {
  const opaque = Color(0xFFFFFFFF), clear = Color(0x00FFFFFF);
  final (on, off) = swept ? (opaque, clear) : (clear, opaque);
  final stops = <double>[], colors = <Color>[];
  void at(double x, Color color) {
    stops.add((x / size.width).clamp(0.0, 1.0));
    colors.add(color);
  }

  at(0, left > 0 ? off : on);
  if (left > 0) {
    at(left, off);
    at(left + fade, on);
  }
  if (right < size.width) {
    at(right - fade, on);
    at(right, off);
  }
  at(size.width, right < size.width ? off : on);
  return LinearGradient(colors: colors, stops: stops).createShader(Offset.zero & size);
}

/// The sweep's [bins] across [size]: each overlay with a trace look draws
/// its frequencies, a later one over an earlier, and the control's look the
/// rest.
void _paintSweep(Canvas canvas, Size size, SpectrumFrame bins, SpectrumFrame window, double floor, double range, _Style style, _Marks marks) {
  final levels = bins.levels, span = (window.highHz - window.lowHz).toDouble();
  final n = levels.length, binHz = (bins.highHz - bins.lowHz) / (n - 1);
  double x(int i) => (bins.lowHz + i * binHz - window.lowHz) / span * size.width;
  // Bin i at lowHz + i × the sweep's width / (n − 1), so a window that is the
  // whole sweep runs the trace edge to edge; bins off the window are skipped,
  // all but one either side, which carries the line to the edge.
  final first = ((window.lowHz - bins.lowHz) / binHz).floor().clamp(0, n - 1);
  final last = ((window.highHz - bins.lowHz) / binHz).ceil().clamp(0, n - 1);
  double y(double level) => size.height - ((level - floor) / range).clamp(0.0, 1.0) * size.height;
  if (last <= first) return;
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
