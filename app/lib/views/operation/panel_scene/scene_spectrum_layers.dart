// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spectrum's `layers`: what a scene places by frequency over the picture,
// redrawn with every zoom, pan and glide (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

/// Where a clickable layer was last drawn, on the screen.
typedef _LayerHit = ({bool Function(Offset at) contains, SceneSpectrumLayer layer});

/// Each part's extent across the control, in its own frame; null where it is not shown.
typedef _Parts = ({({double top, double bottom})? spectrum, ({double top, double bottom})? axis, ({double top, double bottom})? waterfall});

class _LayerPainter extends CustomPainter {
  final _Way way;
  final SpectrumFrame? Function() frame;
  final List<SceneSpectrumLayer> layers;
  final Map<String, double> values;
  final double? Function() vfoHz;
  final _Parts parts;

  /// The spectrum's floor and range in dB as it draws them now, and the
  /// waterfall's seconds a pixel: what `noise` and seconds measure by.
  final (double, double) Function(SpectrumFrame frame) levels;
  final double? Function() secondsPerPixel;

  final SpectrumTextCache texts;
  final TextStyle text;
  final Color ink;

  /// Artwork by its source, once it has loaded; [load] asks for one that has not.
  final Map<String, PictureInfo> pictures;
  final void Function(String svg) load;
  final List<_LayerHit> hits;

  _LayerPainter({
    required Listenable repaint,
    required this.way,
    required this.frame,
    required this.layers,
    required this.values,
    required this.vfoHz,
    required this.parts,
    required this.levels,
    required this.secondsPerPixel,
    required this.texts,
    required this.text,
    required this.ink,
    required this.pictures,
    required this.load,
    required this.hits,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) {
    hits.clear();
    final current = frame();
    if (current == null || current.highHz <= current.lowHz) return;
    final size = _canonical(way, screen);
    final toScreen = _flowMatrix(way, screen);
    final (low, high, vfo) = (current.lowHz.toDouble(), current.highHz.toDouble(), vfoHz());
    final (floor, range) = levels(current);
    final perPixel = secondsPerPixel();
    double? along(SceneSpectrumAlong? at) => at?.at(low, high, size.width, vfo, values);
    double? across(SceneSpectrumAcross? at, {required bool end}) => at == null
        ? (end ? size.height : 0)
        : at.at(
            (part) => switch (part) {
              SceneSpectrumPart.spectrum => parts.spectrum,
              SceneSpectrumPart.axis => parts.axis,
              SceneSpectrumPart.waterfall => parts.waterfall,
            },
            size.height,
            noise: current.noiseDb,
            floor: floor,
            range: range,
            secondsPerPixel: perPixel,
          );
    double? n(SceneNumber? number) => number?.resolve(values);
    canvas.save();
    canvas.clipRect(Offset.zero & screen);
    for (final layer in layers) {
      final (x, y) = (along(layer.x), across(layer.y, end: false));
      if (x == null || y == null) continue;
      void hit(bool Function(Offset at) contains) {
        if (layer.clickable) hits.add((contains: contains, layer: layer));
      }

      switch (layer.kind) {
        case SceneSpectrumLayerKind.rect || SceneSpectrumLayerKind.svg:
          final (x2, y2) = (along(layer.x2), across(layer.y2, end: true));
          if (x2 == null || y2 == null) continue;
          final box = Rect.fromLTRB(math.min(x, x2), math.min(y, y2), math.max(x, x2), math.max(y, y2));
          final onScreen = _toScreen(toScreen, box);
          if (layer.kind == SceneSpectrumLayerKind.rect) {
            final shape = RRect.fromRectAndRadius(onScreen, Radius.circular(n(layer.radius) ?? 0));
            if (layer.fill case final fill?) canvas.drawRRect(shape, Paint()..color = fill);
            if (layer.color case final color?) {
              canvas.drawRRect(
                shape,
                Paint()
                  ..color = color
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = n(layer.width) ?? 1,
              );
            }
          } else if (pictures[layer.svg!] case final art?) {
            // Upright, stretched to its box: a box an edge of which is pixels from a frequency keeps that width at any zoom.
            if (art.size.width > 0 && art.size.height > 0) {
              canvas.save();
              canvas.translate(onScreen.left, onScreen.top);
              canvas.scale(onScreen.width / art.size.width, onScreen.height / art.size.height);
              canvas.drawPicture(art.picture);
              canvas.restore();
            }
          } else {
            load(layer.svg!);
          }
          hit(onScreen.contains);
        case SceneSpectrumLayerKind.line:
          final (x2, y2) = (along(layer.x2) ?? x, across(layer.y2, end: true));
          if (y2 == null) continue;
          final width = n(layer.width) ?? 1;
          final (a, b) = (MatrixUtils.transformPoint(toScreen, Offset(x, y)), MatrixUtils.transformPoint(toScreen, Offset(x2, y2)));
          _line(
            canvas,
            a,
            b,
            Paint()
              ..color = layer.color ?? ink
              ..strokeWidth = width,
            dashed: layer.dashed,
          );
          // A finger's reach either side of a hairline.
          hit((at) => _toSegment(at, a, b) <= math.max(6, width / 2 + 2));
        case SceneSpectrumLayerKind.text:
          final label = layer.text ?? _formatted(layer, values[layer.value]);
          if (label == null) continue;
          final style = text.copyWith(
            color: layer.color ?? ink,
            fontSize: n(layer.size),
            fontWeight: _weight(n(layer.weight)),
            fontFamily: layer.fontFamily,
            fontStyle: layer.italic ? FontStyle.italic : null,
          );
          final painter = texts.get(label, style);
          final pad = n(layer.padding) ?? (layer.background == null ? 0 : 2);
          // Its length along the frequency and across it, upright whichever way the control lies.
          final (long, deep) = _turned(way) ? (painter.height + 2 * pad, painter.width + 2 * pad) : (painter.width + 2 * pad, painter.height + 2 * pad);
          final left = switch (layer.align) {
            'center' => x - long / 2,
            'end' => x - long,
            _ => x,
          };
          final top = switch (layer.valign) {
            'center' => y - deep / 2,
            'bottom' => y - deep,
            _ => y,
          };
          final onScreen = _toScreen(toScreen, Rect.fromLTWH(left, top, long, deep));
          if (layer.background case final background?) {
            canvas.drawRRect(RRect.fromRectAndRadius(onScreen, Radius.circular(n(layer.radius) ?? 3)), Paint()..color = background);
          }
          painter.paint(canvas, onScreen.topLeft + Offset(pad, pad));
          hit(onScreen.contains);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LayerPainter old) => true;
}

String? _formatted(SceneSpectrumLayer layer, double? value) =>
    value == null || !value.isFinite ? null : '${layer.prefix ?? ''}${value.toStringAsFixed(layer.decimals)}${layer.suffix ?? ''}';

/// How far [at] is from the segment [a]–[b].
double _toSegment(Offset at, Offset a, Offset b) {
  final ab = b - a, length = ab.distanceSquared;
  if (length == 0) return (at - a).distance;
  final t = (((at - a).dx * ab.dx + (at - a).dy * ab.dy) / length).clamp(0.0, 1.0);
  return (at - (a + ab * t)).distance;
}
