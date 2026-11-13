// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a rotator map paints, bottom up: the sea and the raster, the world's
// outlines and the rings, the decorations cut at the rim, the rim, those
// drawn past it, and the station (scene_rotator.dart).

part of 'scene_rotator.dart';

class _RotatorMapPainter extends CustomPainter {
  final RotatorFrame frame;
  final SceneRotatorSpec spec;
  final WorldMapBase world;
  final MapColors colors;
  final bool dark;
  final MapPalette palette;
  final List<_Drawn> drawn;
  final Map<String, PictureInfo> pictures;
  final void Function(String svg) load;
  final Map<String, double> values;
  final Color rimColor, sea;
  final TextStyle labelStyle;

  /// North, east, south and west, in that order.
  final List<String> compass;
  final bool showStation;

  _RotatorMapPainter({
    required this.frame,
    required this.spec,
    required this.world,
    required this.colors,
    required this.dark,
    required this.palette,
    required this.drawn,
    required this.pictures,
    required this.load,
    required this.values,
    required this.rimColor,
    required this.sea,
    required this.labelStyle,
    required this.compass,
    required this.showStation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.base <= 0) return;
    canvas.save();
    canvas.clipPath(frame.rimPath);
    canvas.drawPaint(Paint()..color = sea);
    world.paint(canvas, origin: frame.station, scale: frame.discPx, style: spec.map, colors: colors, closeness: frame.zoom, dark: dark);
    for (final ring in spec.rings) {
      _paintRing(canvas, ring);
    }
    // In the scene's order, each over the ones before: the rim goes in just
    // before the first decoration let past it — over a beam's fill, so the
    // edge and its marks stay sharp; under an arrow's head or a label on the
    // edge. A cut one after that is cut on its own, still over the arrows
    // listed before it: the station being logged, marked over the heading.
    var rimDrawn = false;
    for (final d in drawn) {
      if (!rimDrawn && !d.layer.clip) {
        canvas.restore();
        _paintRim(canvas);
        rimDrawn = true;
      }
      if (rimDrawn && d.layer.clip) {
        canvas.save();
        canvas.clipPath(frame.rimPath);
        _paintLayer(canvas, d);
        canvas.restore();
      } else {
        _paintLayer(canvas, d);
      }
    }
    if (!rimDrawn) {
      canvas.restore();
      _paintRim(canvas);
    }
    if (showStation) {
      canvas.drawCircle(frame.station, 5, Paint()..color = Colors.white);
      canvas.drawCircle(frame.station, 3.5, Paint()..color = const Color(0xFF222222));
    }
  }

  void _paintRing(Canvas canvas, SceneRotatorRing ring) {
    final r = ring.km * frame.pxPerKm;
    final color = ring.color ?? rimColor.withValues(alpha: 0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = ring.width;
    final circle = Path()..addOval(Rect.fromCircle(center: frame.station, radius: r));
    canvas.drawPath(ring.dashed ? dashedPath(circle) : circle, paint);
    for (final label in ring.labels) {
      final text = label.text ?? '${(ring.unit == 'mi' ? ring.km / 1.609344 : ring.km).round()} ${ring.unit}';
      _label(canvas, text, frame.along(label.az, r), labelStyle.copyWith(fontSize: label.size, color: label.color ?? color, fontWeight: FontWeight.normal));
    }
  }

  void _paintLayer(Canvas canvas, _Drawn d) {
    final layer = d.layer;
    double? n(SceneNumber? x) => x?.resolve(values);
    // Thicker once a rubber band is loaded: the operator can feel for the point a shot spins.
    final width = (n(layer.width) ?? 1) + (d.loaded ? 1 : 0);
    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    switch (layer.kind) {
      case SceneRotatorLayerKind.defaults:
        return;
      case SceneRotatorLayerKind.line:
        final (a, b) = (d.from!, d.to!);
        final color = d.color ?? rimColor;
        // Pulled as a rubber band, the head points along the half it is on.
        final c = d.nock ?? a;
        final dir = (b - c).distance == 0 ? Offset.zero : (b - c) / (b - c).distance;
        final head = layer.head;
        final end = head == null ? b : b - dir * head.length;
        final line = Path()..moveTo(a.dx, a.dy);
        if (d.nock case final nock?) line.lineTo(nock.dx, nock.dy);
        line.lineTo(end.dx, end.dy);
        final normal = Offset(-dir.dy, dir.dx);
        final tip = head == null
            ? null
            : (Path()
                ..moveTo(b.dx, b.dy)
                ..lineTo((end + normal * head.width / 2).dx, (end + normal * head.width / 2).dy)
                ..lineTo((end - normal * head.width / 2).dx, (end - normal * head.width / 2).dy)
                ..close());
        // A pixel of the casing either side, under the line and round its head.
        if (layer.casing case final casing?) {
          canvas.drawPath(layer.dashed ? dashedPath(line) : line, stroke(casing)..strokeWidth = width + 2);
          if (tip != null) {
            canvas.drawPath(
              tip,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = casing
                ..strokeWidth = 2
                ..strokeJoin = StrokeJoin.round,
            );
          }
        }
        canvas.drawPath(layer.dashed ? dashedPath(line) : line, stroke(color));
        if (tip != null) canvas.drawPath(tip, Paint()..color = color);
      case SceneRotatorLayerKind.wedge:
        if (d.fill case final fill?) canvas.drawPath(d.path!, Paint()..color = fill);
        final edge = layer.dashed ? dashedPath(d.path!) : d.path!;
        // Along the outside of each side only: the arc mostly lies on the rim,
        // which has its own line, and inside, the casing would wash the fill.
        if ((d.color, layer.casing) case (_?, final casing?)) {
          final along = Path();
          for (final (a, b, out) in d.sides!) {
            final shift = out * (width / 2 + 0.5);
            along
              ..moveTo((a + shift).dx, (a + shift).dy)
              ..lineTo((b + shift).dx, (b + shift).dy);
          }
          canvas.drawPath(layer.dashed ? dashedPath(along) : along, stroke(casing)..strokeWidth = 1);
        }
        if (d.color case final color?) canvas.drawPath(edge, stroke(color));
      case SceneRotatorLayerKind.circle:
        final radius = n(layer.radius) ?? 4;
        if (d.fill case final fill?) canvas.drawCircle(d.from!, radius, Paint()..color = fill);
        if (d.color case final color? when width > 0) canvas.drawCircle(d.from!, radius, stroke(color));
      case SceneRotatorLayerKind.text:
        final box = d.textBox!;
        if (layer.background case final bg?) canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = bg);
        final pad = layer.padding?.literal ?? 2;
        d.text!.paint(canvas, box.topLeft + Offset(pad, pad));
      case SceneRotatorLayerKind.svg:
        final art = pictures[layer.svg!];
        if (art == null) {
          load(layer.svg!);
          return;
        }
        if (art.size.width <= 0 || art.size.height <= 0) return;
        final box = Rect.fromCenter(center: d.from!, width: layer.svgWidth, height: layer.svgHeight);
        canvas.save();
        canvas.translate(box.left, box.top);
        canvas.scale(box.width / art.size.width, box.height / art.size.height);
        canvas.drawPicture(art.picture);
        canvas.restore();
    }
  }

  void _paintRim(Canvas canvas) {
    final rim = spec.rim;
    final color = rim?.color ?? rimColor.withValues(alpha: 0.8);
    if (rim?.background case final bg?) {
      canvas.save();
      canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & frame.size), frame.rimPath));
      canvas.drawPaint(Paint()..color = bg);
      canvas.restore();
    }
    canvas.drawPath(
      frame.rimPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = rim?.width ?? 1.5,
    );
    final ticks = rim?.ticks ?? [_defaultTicks10, _defaultTicks30];
    for (final set in ticks) {
      final paint = Paint()
        ..color = set.color ?? color
        ..strokeWidth = set.width;
      for (final b in set.bearings) {
        final out = frame.rimAt(b);
        canvas.drawLine(frame.along(b, out - set.length), frame.along(b, out), paint);
      }
    }
    final labels = rim?.labels;
    if (labels == null) {
      for (var i = 0; i < 4; i++) {
        final b = i * 90.0;
        _label(canvas, compass[i], frame.along(b, frame.rimAt(b) - 14), labelStyle.copyWith(color: rimColor));
      }
      return;
    }
    for (final set in labels) {
      final bearings = set.bearings;
      for (final (i, b) in bearings.indexed) {
        final text = set.text?[i] ?? '${b.round()}°';
        final style = labelStyle.copyWith(
          color: set.color ?? rimColor,
          fontSize: set.size,
          fontWeight: set.weight == null ? null : FontWeight.values[((set.weight! / 100).round() - 1).clamp(0, 8)],
        );
        _label(canvas, text, frame.along(b, frame.rimAt(b) - set.offset), style);
      }
    }
  }

  static final _defaultTicks10 = SceneRotatorRimMarks(const {'every': 10, 'length': 4}, labels: false);
  static final _defaultTicks30 = SceneRotatorRimMarks(const {'every': 30, 'length': 7}, labels: false);

  void _label(Canvas canvas, String text, Offset at, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_RotatorMapPainter old) => true;
}
