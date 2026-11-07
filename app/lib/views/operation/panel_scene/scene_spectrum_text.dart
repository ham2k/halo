// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a spectrum control writes over its picture: the frequency axis's
// labels and ticks, the scene's annotations, and the dial's own label
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

/// The dial's label, larger than the axis's: it is the one number on the picture an operator reads first.
const _vfoLabelSize = 21.0;

/// The frequency labels and ticks, over the whole control so an offset can
/// put them anywhere: in the gap, or over the panadapter or the waterfall.
class _ScalePainter extends CustomPainter {
  final _Way way;
  final SpectrumFrame? Function() frame;
  final SpectrumTextCache texts;

  /// Where offsets measure from: the base of the panadapter, or the top of
  /// the waterfall where there is none.
  final double base;
  final double gap;
  final SceneSpectrumLabels? labels;
  final SceneSpectrumTicks? ticks;
  final double? Function(SceneNumber?) number;
  final TextStyle text;

  /// On the screen, where the level strip lies over the picture: no label
  /// is drawn under it, where it could not be read. Its ticks still are.
  final Rect? clear;

  /// The axis from extension API 17: labels read as frequencies do elsewhere,
  /// every kHz digit shown, and ticks short between and tall at a label. A
  /// bundle before it draws the plain axis it was written against.
  final bool styled;

  _ScalePainter({
    this.clear,
    required this.styled,
    required Listenable repaint,
    required this.way,
    required this.texts,
    required this.frame,
    required this.base,
    required this.gap,
    required this.labels,
    required this.ticks,
    required this.number,
    required this.text,
  }) : super(repaint: repaint);

  /// The multiples of [step] across the sweep, as x positions with their Hz.
  Iterable<(double, double)> _stops(SpectrumFrame frame, double step, double width) sync* {
    final span = (frame.highHz - frame.lowHz).toDouble();
    // A step that would put more than a line per pixel is a mistake, not a scale.
    if (step < span / width) return;
    for (var hz = (frame.lowHz / step).ceil() * step; hz <= frame.highHz; hz += step) {
      yield ((hz - frame.lowHz) / span * width, hz);
    }
  }

  @override
  void paint(Canvas canvas, Size screen) {
    final current = frame();
    if (current == null || current.highHz <= current.lowHz) return;
    final span = (current.highHz - current.lowHz).toDouble();
    final labelStep = number(labels?.interval) ?? _gridStep(span);
    if (ticks case final ticks?) {
      _inFlow(canvas, screen, way, (size) {
        final width = number(ticks.width) ?? 1;
        final paint = Paint()
          ..color = ticks.color ?? text.color ?? const Color(0xFF888888)
          ..strokeWidth = width;
        final top = base + (number(ticks.offset) ?? 0);
        final length = number(ticks.length) ?? 4;
        if (!styled) {
          for (final (x, _) in _stops(current, number(ticks.interval) ?? labelStep, size.width)) {
            canvas.drawLine(Offset(x, top), Offset(x, top + length), paint);
          }
          return;
        }
        bool on(double hz, double step) => ((hz / step) - (hz / step).round()).abs() < 1e-6;
        // Short between, the scene's interval, and tall and heavy where a label is — drawn on
        // labels or not, so the axis keeps its rhythm in a pane too narrow for every label.
        if (spectrumMinorTick(span, size.width, labelStep) case final minor?) {
          for (final (x, hz) in _stops(current, minor, size.width)) {
            if (!on(hz, labelStep)) canvas.drawLine(Offset(x, top), Offset(x, top + length / 2), paint);
          }
        }
        if (number(ticks.interval) case final interval?) {
          for (final (x, hz) in _stops(current, interval, size.width)) {
            if (!on(hz, labelStep)) canvas.drawLine(Offset(x, top), Offset(x, top + length), paint);
          }
        }
        final labelled = Paint()
          ..color = paint.color
          ..strokeWidth = width * 2;
        for (final (x, _) in _stops(current, labelStep, size.width)) {
          canvas.drawLine(Offset(x, top), Offset(x, top + length * 1.75), labelled);
        }
      });
    }
    // Text is laid out in the spectrum's frame but drawn upright: its box is
    // mapped onto the screen, and the text set in that box.
    final size = _canonical(way, screen);
    final toScreen = _flowMatrix(way, screen);
    final turned = _turned(way);
    final shown = labels;
    if (shown == null) return;
    final style = text.copyWith(
      fontFamily: shown.fontFamily,
      fontSize: number(shown.size),
      fontWeight: _weight(number(shown.weight)),
      fontStyle: shown.italic ? FontStyle.italic : null,
      color: shown.color,
    );
    // Every kHz digit, and the Hz ones it takes to tell one label from the next, unless the scene
    // fixed them; before API 17, only the digits it takes.
    final decimals = shown.decimals ?? (6 - (math.log(labelStep) / math.ln10).floor()).clamp(styled ? 3 : 0, 6);
    // A label that would touch the last one drawn is skipped: in a narrow
    // pane that leaves every other one, rather than a run of digits.
    var lastRight = double.negativeInfinity;
    for (final (x, hz) in _stops(current, labelStep, size.width)) {
      final label = (hz / 1e6).toStringAsFixed(decimals);
      final painter = styled ? texts.get(label, style, span: () => spectrumAxisLabel(label, style)) : texts.get(label, style);
      // Its length along the frequency axis, and across it.
      final (along, across) = turned ? (painter.height, painter.width) : (painter.width, painter.height);
      final left = x - along / 2;
      if (left < 0 || left + along > size.width || left < lastRight + painter.height / 2) continue;
      final top = base + (number(shown.offset) ?? (gap - across) / 2);
      final box = _toScreen(toScreen, Rect.fromLTWH(left, top, along, across));
      if (clear?.overlaps(box) ?? false) continue;
      lastRight = left + along;
      painter.paint(canvas, box.topLeft);
    }
  }

  // Rebuilt only when the tree is: a scene value, a theme, the layout.
  @override
  bool shouldRepaint(_ScalePainter old) => true;
}

/// The Hz between the short ticks drawn among an axis's labels, [labelStep]
/// apart, across [span] Hz shown on [width] pixels: every 100 Hz once the
/// labels are 1 kHz apart or closer, every 1 kHz otherwise — each only at
/// least four pixels apart and finer than the labels — or none, where even
/// 1 kHz would make a solid bar.
@visibleForTesting
double? spectrumMinorTick(double span, double width, double labelStep) {
  if (span <= 0 || width <= 0) return null;
  for (final hz in [if (labelStep <= 1000) 100.0, 1000.0]) {
    if (hz * width / span >= 4 && hz < labelStep) return hz;
  }
  return null;
}

/// [mhz] (`14.0505`) split the way the rest of the app splits a frequency:
/// MHz bold, kHz at the label's weight, Hz smaller — or, below 1 MHz, the kHz
/// bold, since `0.472` is not a reading anyone writes.
@visibleForTesting
InlineSpan spectrumAxisLabel(String mhz, TextStyle style) {
  final [whole, fraction] = mhz.contains('.') ? mhz.split('.') : [mhz, ''];
  final khz = fraction.length > 3 ? fraction.substring(0, 3) : fraction, sub = fraction.length > 3 ? fraction.substring(3) : '';
  final bold = style.copyWith(fontWeight: (style.fontWeight?.value ?? 400) > 700 ? style.fontWeight : FontWeight.w700);
  final small = style.copyWith(fontSize: (style.fontSize ?? 14) * .8);
  final kiloOnly = whole == '0' && khz.length == 3;
  return TextSpan(
    style: style,
    children: [
      if (kiloOnly) TextSpan(text: int.parse(khz).toString(), style: bold) else TextSpan(text: whole, style: bold),
      if (!kiloOnly && khz.isNotEmpty) TextSpan(text: '$frequencyMark$khz'),
      if (sub.isNotEmpty) ...[TextSpan(text: frequencyMark), TextSpan(text: sub, style: small)],
    ],
  );
}

/// Laid-out text, kept across paints: the labels and annotations are the
/// same few strings at the same few styles, redrawn up to sixty times a
/// second. Past [limit] the least recently used is let go, one at a time,
/// never all at once: a paint still holding a painter from an earlier [get]
/// would otherwise draw a disposed one. The limit is over what one paint
/// can ask for — 256 annotations, the text of 512 layers, the axis's and
/// the level strip's labels — or each paint would let go of what it laid
/// out a moment before, and lay everything out again every frame.
@visibleForTesting
class SpectrumTextCache {
  static const limit = 1024;
  final _painters = <(String, TextStyle, Object?), TextPainter>{};

  /// How many are kept now.
  @visibleForTesting
  int get length => _painters.length;

  /// [span], where given, is what [text] is drawn as; [spanKey] names what
  /// else, beside [style], the span is built from.
  TextPainter get(String text, TextStyle style, {InlineSpan Function()? span, Object? spanKey}) {
    final key = (text, style, span == null ? null : (spanKey ?? true));
    // Taken out and put back, so the map's order is the order of use.
    if (_painters.remove(key) case final cached?) return _painters[key] = cached;
    if (_painters.length >= limit) _painters.remove(_painters.keys.first)!.dispose();
    return _painters[key] = TextPainter(
      text: span?.call() ?? TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void dispose() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

/// [annotation] is null for the dial's label: drawn over the annotations, it
/// takes a click on what it covers.
typedef _AnnotationHit = ({Rect rect, SceneSpectrumAnnotation? annotation, double hz, bool away});

/// An annotation's box with its point at [x]: a corner drawn out to it for a
/// box that starts or ends there, a notch in the middle of an edge for one
/// centered on it. [point] 0 is the plain rounded box.
Path _bubble(Rect rect, double radius, {required double x, required String align, required double point, required bool up}) {
  final r = Radius.circular(radius);
  if (point <= 0) return Path()..addRRect(RRect.fromRectAndRadius(rect, r));
  final square = Radius.zero;
  final start = align == 'start', end = align == 'end';
  final box = RRect.fromRectAndCorners(
    rect,
    topLeft: up && start ? square : r,
    topRight: up && end ? square : r,
    bottomLeft: !up && start ? square : r,
    bottomRight: !up && end ? square : r,
  );
  final edge = up ? rect.top : rect.bottom, tip = up ? rect.top - point : rect.bottom + point;
  final tail = Path()
    ..moveTo(start ? x : x - point, edge)
    ..lineTo(end ? x : x + point, edge)
    ..lineTo(x, tip)
    ..close();
  return Path.combine(PathOperation.union, Path()..addRRect(box), tail);
}

/// [text] after its annotation's icon, a glyph of the icon's font at the
/// text's size: a canvas paints text, not widgets.
InlineSpan _withIcon(String text, TextStyle style, ({String name, Color? color}) icon) {
  final data = resolveIconName(icon.name);
  return TextSpan(
    style: style,
    children: [
      TextSpan(
        text: String.fromCharCode(data.codePoint),
        style: style.copyWith(fontFamily: data.fontFamily, package: data.fontPackage, fontFamilyFallback: const [], color: icon.color),
      ),
      TextSpan(text: ' $text'),
    ],
  );
}

FontWeight? _weight(double? w) => w == null ? null : FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

class _AnnotationPainter extends CustomPainter {
  final _Way way;
  final SpectrumFrame? Function() frame;
  final SpectrumTextCache texts;
  final _Marks marks;

  /// Null where the part is not shown: its annotations are not drawn.
  final double? panBottom, waterfallTop;

  /// What an annotation's `y` measures by, as a layer's coordinates do.
  final _Parts parts;
  final (double, double) Function(SpectrumFrame frame) levels;
  final double? Function() secondsPerPixel;

  /// Rewritten on every paint, for the view's clicks and cursor.
  final List<_AnnotationHit> hits;
  final TextStyle text;
  final Color background;

  /// The tuned frequency's label color, or null for none, and its box's:
  /// the panadapter's own, see-through, so the label reads over the trace
  /// without blotting it out.
  final Color? vfoLabel, vfoLabelBackground;

  /// How many digits past the kHz the label shows — the scene's, where it
  /// fixes them — part way between two as one is revealed or hidden.
  final double Function() vfoDigits;

  /// The frequency the label shows, which may differ from the line's.
  final double? Function() vfoLabelHz;

  /// The id of the collapsed annotation the pointer is on, drawn whole.
  final String? Function() revealed;

  /// A level strip lying over the picture, on screen, which the label keeps
  /// to the window's side of.
  final Rect? clear;

  _AnnotationPainter({
    required this.revealed,
    this.clear,
    required Listenable repaint,
    required this.vfoDigits,
    required this.vfoLabelHz,
    this.vfoLabel,
    this.vfoLabelBackground,
    required this.way,
    required this.texts,
    required this.frame,
    required this.marks,
    required this.panBottom,
    required this.waterfallTop,
    required this.parts,
    required this.levels,
    required this.secondsPerPixel,
    required this.hits,
    required this.text,
    required this.background,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) {
    // An annotation near an edge is drawn as far as the edge: past it, it
    // would paint over the pane beside the scope.
    canvas.save();
    canvas.clipRect(Offset.zero & screen);
    _paint(canvas, screen);
    canvas.restore();
  }

  void _paint(Canvas canvas, Size screen) {
    hits.clear();
    // Laid out in the spectrum's frame, as the scale's labels are; the box
    // and its point are mapped onto the screen, the text set upright in it.
    final size = _canonical(way, screen);
    final toScreen = _flowMatrix(way, screen);
    final turned = _turned(way);
    final current = frame();
    if (current == null || current.highHz <= current.lowHz) return;
    final span = (current.highHz - current.lowHz).toDouble();
    final number = marks.number;
    final (floor, range) = levels(current);
    final perPixel = secondsPerPixel();
    // Where an annotation's box goes, and what it is drawn with; null off the window or not known yet.
    ({Rect rect, Path shape, TextPainter painter, double pad, double hz, double x, double near})? place(SceneSpectrumAnnotation a) {
      // Not drawn where its part is not shown, nor at a `y` not known yet: the noise before it is estimated.
      final part = a.onWaterfall ? waterfallTop : panBottom;
      final y = a.y;
      final edge = part == null || y == null
          ? part
          : y.at(
              (p) => switch (p) {
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
      final anchor = switch (a.anchor) {
        SceneSpectrumAnchor.vfo => marks.vfoHz(),
        SceneSpectrumAnchor.center => (current.lowHz + current.highHz) / 2,
        SceneSpectrumAnchor.absolute => 0.0,
      };
      final at = number(a.hz);
      if (edge == null || anchor == null || at == null) return null;
      final hz = anchor + at;
      final x = (hz - current.lowHz) / span * size.width;
      final pointer = a.pointer;
      final point = pointer == null ? 0.0 : (number(pointer.size) ?? 4);
      final up = (pointer?.corner ?? (a.onWaterfall ? 'top' : 'bottom')) == 'top';
      // The offset places the tip, so a box with a point stands that much
      // further from the edge than one without.
      final offset = number(a.offset) ?? 4;
      // The border facing the edge it stands from, whatever the box's height.
      final near = a.onWaterfall ? edge + offset + (up ? point : 0) : edge - offset - (up ? 0 : point);
      final style = text.copyWith(
        fontFamily: a.fontFamily,
        fontSize: number(a.size),
        fontWeight: _weight(number(a.weight)),
        fontStyle: a.italic ? FontStyle.italic : null,
        color: a.color,
      );
      final icon = a.icon;
      final painter = texts.get(a.text, style, span: icon == null ? null : () => _withIcon(a.text, style, icon), spanKey: icon);
      final pad = number(a.padding) ?? 2;
      final (textAlong, textAcross) = turned ? (painter.height, painter.width) : (painter.width, painter.height);
      final width = textAlong + pad * 2, height = textAcross + pad * 2;
      final left = switch (a.align) {
        'start' => x,
        'end' => x - width,
        _ => x - width / 2,
      };
      if (left + width < 0 || left > size.width) return null;
      final top = a.onWaterfall ? near : near - height;
      final rect = Rect.fromLTWH(left, top, width, height);
      final shape = _bubble(rect, number(a.radius) ?? 2, x: x, align: a.align, point: point, up: up).transform(toScreen.storage);
      return (rect: rect, shape: shape, painter: painter, pad: pad, hz: hz, x: x, near: near);
    }

    void draw(SceneSpectrumAnnotation a, ({Rect rect, Path shape, TextPainter painter, double pad, double hz, double x, double near}) at) {
      final (rect, shape) = (at.rect, at.shape);
      canvas.drawPath(shape, Paint()..color = a.background ?? background);
      final border = number(a.borderWidth) ?? (a.borderColor == null ? 0 : 1);
      if (a.borderColor != null && border > 0) {
        final stroke = Paint()
          ..color = a.borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = border;
        if (a.borderNear) {
          // The edge facing the one it stands from: an underline on the spectrum, an overline on the waterfall.
          canvas.drawPath(
            (Path()
                  ..moveTo(rect.left, at.near)
                  ..lineTo(rect.right, at.near))
                .transform(toScreen.storage),
            stroke,
          );
        } else {
          canvas.drawPath(shape, stroke);
        }
      }
      at.painter.paint(canvas, _toScreen(toScreen, rect).topLeft + Offset(at.pad, at.pad));
      hits.add((rect: shape.getBounds(), annotation: a, hz: at.hz, away: false));
    }

    // A collapsed one the pointer is on, drawn whole over the rest: those it would cover wait.
    final shown = revealed();
    final open = shown == null ? null : marks.spec.annotations.where((a) => a.id == shown && a.collapsed).firstOrNull;
    final opened = open == null ? null : place(open);
    for (final a in marks.spec.annotations) {
      if (a == open) continue;
      if (a.collapsed) {
        final at = place(a);
        if (at == null) continue;
        final width = a.collapsedWidth ?? at.rect.width * .8, middle = at.rect.center.dx;
        canvas.drawPath(
          (Path()
                ..moveTo(middle - width / 2, at.near)
                ..lineTo(middle + width / 2, at.near))
              .transform(toScreen.storage),
          Paint()
            ..color = a.borderColor ?? a.color ?? text.color ?? background
            ..style = PaintingStyle.stroke
            ..strokeWidth = number(a.borderWidth) ?? 1,
        );
        // Mostly on the side away from the labels over it, which keep their own: the line is too
        // thin to find, and a reach over it would take the labels' bottoms.
        final (over, under) = a.onWaterfall ? (8.0, 3.0) : (3.0, 8.0);
        hits.add((
          rect: _toScreen(toScreen, Rect.fromLTRB(middle - width / 2, at.near - over, middle + width / 2, at.near + under)),
          annotation: a,
          hz: at.hz,
          away: false,
        ));
        continue;
      }
      final at = place(a);
      if (at == null || (opened != null && at.rect.overlaps(opened.rect))) continue;
      draw(a, at);
    }
    // Laid out again to be drawn: what it was placed with may have been let go meanwhile.
    if (open != null && opened != null) draw(open, place(open) ?? opened);
    // Last, so the tuned frequency stays readable over the annotations crowding the dial.
    _paintVfoLabel(canvas, size, toScreen, turned, current, span);
  }

  /// The tuned frequency, at the top of its line, over the passband — the
  /// first area the scene draws from the dial — where it sits above the
  /// signals heard; centred over the line with no passband drawn. With the
  /// dial out of the window, at the edge it is past, an arrow on that side
  /// in the line's color pointing the way: a click there brings it back.
  void _paintVfoLabel(Canvas canvas, Size size, Matrix4 toScreen, bool turned, SpectrumFrame current, double span) {
    final color = vfoLabel, line = marks.vfoHz(), vfo = vfoLabelHz();
    if (color == null || line == null || vfo == null || panBottom == null) return;
    final x = (line - current.lowHz) / span * size.width;
    final away = x < 0 ? -1 : (x > size.width ? 1 : 0);
    final settings = marks.spec.vfoLabel;
    final (mhz, khz, hz) = spectrumVfoLabelStyles(text.copyWith(color: color, fontSize: _vfoLabelSize), settings, marks.number);
    TextPainter labelled(int digits) {
      final label = spectrumVfoLabel(vfo, digits);
      return texts.get(label, mhz, spanKey: (khz, hz), span: () => spectrumVfoLabelSpan(label, mhz, khz, hz));
    }

    // Between two lengths, the longer is drawn in a box part way between them: the digit it adds
    // slides out from under the box's edge, or back under it.
    final shown = vfoDigits().clamp(0.0, 3.0);
    final (shorter, painter) = (labelled(shown.floor()), labelled(shown.ceil()));
    final textWidth = shorter.width + (painter.width - shorter.width) * (shown - shown.floor());
    const pad = 2.0, gap = 3.0;
    final (along, across) = turned ? (painter.height, textWidth) : (textWidth, painter.height);
    final width = along + pad * 2, height = across + pad * 2;
    final arrow = away == 0 || settings.noArrow ? 0.0 : marks.number(settings.arrowSize) ?? painter.height * .45;
    final box = width + (arrow > 0 ? arrow + gap : 0);
    final side = spectrumPassbandSide(marks.spec, marks.number);
    var left = switch (away) {
      < 0 => 0.0,
      > 0 => size.width - box,
      _ => side > 0 ? x + gap : (side < 0 ? x - gap - width : x - width / 2),
    };
    // Short of a level strip over the picture at either end, rather than under it.
    var (low, high) = (0.0, size.width);
    final (strip, fromScreen) = (clear, Matrix4.tryInvert(toScreen));
    if (strip != null && fromScreen != null) {
      final along = MatrixUtils.transformRect(fromScreen, strip);
      if (along.left <= 1) low = math.max(low, along.right);
      if (along.right >= size.width - 1) high = math.min(high, along.left);
    }
    left = left.clamp(low, math.max(low, high - box));
    final rect = Rect.fromLTWH(away < 0 && arrow > 0 ? left + arrow + gap : left, pad, width, height);
    final whole = Rect.fromLTWH(left, pad, box, height);
    canvas.drawPath(
      _bubble(whole, 2, x: x, align: 'center', point: 0, up: false).transform(toScreen.storage),
      Paint()..color = vfoLabelBackground ?? background,
    );
    if (arrow > 0) {
      final (tip, base, middle) = away < 0
          ? (left + pad, left + pad + arrow, pad + height / 2)
          : (left + box - pad, left + box - pad - arrow, pad + height / 2);
      final half = math.min(arrow * .5, height / 2 - pad);
      final shape = Path()
        ..moveTo(tip, middle)
        ..lineTo(base, middle - half)
        ..lineTo(base, middle + half)
        ..close();
      canvas.drawPath(shape.transform(toScreen.storage), Paint()..color = settings.arrowColor ?? color);
    }
    // On the screen, as every other hit is: in the spectrum's own frame, a turned one's label would
    // shadow whatever lies where its box would be upright, and leave what it covers clickable.
    hits.add((rect: _toScreen(toScreen, away == 0 ? rect : whole), annotation: null, hz: vfo, away: away != 0));
    final onScreen = _toScreen(toScreen, rect);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(onScreen.left + pad, onScreen.top + pad, textWidth, painter.height));
    painter.paint(canvas, onScreen.topLeft + const Offset(pad, pad));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}

/// Which way from the dial the passband lies, as the scene draws it — its
/// first area anchored to the dial: 1 above, -1 below, 0 straddling it or
/// not drawn.
@visibleForTesting
int spectrumPassbandSide(SceneSpectrumSpec spec, double? Function(SceneNumber?) number) {
  for (final mark in spec.overlays) {
    if (mark.anchor != SceneSpectrumAnchor.vfo) continue;
    final from = number(mark.from), to = number(mark.to);
    if (from == null || to == null) continue;
    return (from + to).sign.toInt();
  }
  return 0;
}

/// The tuned frequency's label's MHz, kHz and Hz, from [base]: each part
/// takes what [settings] does not name for it from the part before, but the
/// MHz is bold where the kHz is light, and the Hz four fifths the kHz's size.
@visibleForTesting
(TextStyle, TextStyle, TextStyle) spectrumVfoLabelStyles(TextStyle base, SceneSpectrumVfoLabel settings, double? Function(SceneNumber?) number) {
  TextStyle part(TextStyle from, SceneSpectrumVfoLabelPart? part, {FontWeight? weight, double? size}) => from.copyWith(
    fontFamily: part?.fontFamily,
    fontSize: number(part?.size) ?? size,
    fontWeight: _weight(number(part?.weight)) ?? weight,
    fontStyle: switch (part?.italic) {
      null => null,
      true => FontStyle.italic,
      false => FontStyle.normal,
    },
    color: part?.color,
  );
  final mhz = part(base, settings.mhz, weight: FontWeight.w700);
  final khz = part(mhz, settings.khz, weight: FontWeight.w300);
  return (mhz, khz, part(khz, settings.hz, size: (khz.fontSize ?? _vfoLabelSize) * .8));
}

/// [spectrumVfoLabel]'s text in its three parts' styles; the marks before the
/// kHz and the Hz are the kHz's. Below 1 MHz the kHz leads, in the MHz's
/// style, as on the axis.
@visibleForTesting
InlineSpan spectrumVfoLabelSpan(String label, TextStyle mhz, TextStyle khz, TextStyle hz) {
  final [whole, fraction] = label.split('.');
  final kilo = fraction.substring(0, 3), sub = fraction.substring(3);
  return TextSpan(
    style: khz,
    children: [
      if (whole == '0')
        TextSpan(text: int.parse(kilo).toString(), style: mhz)
      else ...[
        TextSpan(text: whole, style: mhz),
        TextSpan(text: '$frequencyMark$kilo'),
      ],
      if (sub.isNotEmpty) ...[TextSpan(text: frequencyMark), TextSpan(text: sub, style: hz)],
    ],
  );
}

/// A tuned frequency in MHz, with [digits] past the kHz — by default as many
/// as it has: `14.074`, `14.0745`, `14.07425`. More are zeros, `14.0740`;
/// fewer cut, never rounded, so a digit is never one the dial is not on.
@visibleForTesting
String spectrumVfoLabel(double hz, [int? digits]) {
  final total = hz.round();
  final within = (total % 1000000).toString().padLeft(6, '0').substring(0, 3 + (digits ?? spectrumVfoDigits(hz)).clamp(0, 3));
  return '${total ~/ 1000000}.$within';
}

/// How many digits past the kHz [hz] has: 0 to 3.
@visibleForTesting
int spectrumVfoDigits(double hz) {
  final within = hz.round() % 1000;
  return within == 0 ? 0 : (within % 100 == 0 ? 1 : (within % 10 == 0 ? 2 : 3));
}
