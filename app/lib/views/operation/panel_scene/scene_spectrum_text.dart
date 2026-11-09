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
/// Where the tuned frequency's label was last drawn, on the screen: the
/// annotations' painter writes it, and the axis's, painted after it, dims
/// the labels it would otherwise draw over.
class _VfoLabelBox {
  Rect? rect;
}

/// How strongly an axis label under the tuned frequency's label is drawn.
const _underVfoLabel = .3;

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

  /// The tuned frequency's label, which a label under it is dimmed for.
  final _VfoLabelBox? vfoLabel;

  /// The axis from extension API 17: labels read as frequencies do elsewhere,
  /// every kHz digit shown, and ticks short between and tall at a label. A
  /// bundle before it draws the plain axis it was written against.
  final bool styled;

  _ScalePainter({
    this.clear,
    this.vfoLabel,
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
        // From the offset toward the waterfall, or back toward the spectrum with `end`.
        final up = ticks.align == 'end';
        void tick(double x, double long, Paint paint) => canvas.drawLine(Offset(x, top), Offset(x, up ? top - long : top + long), paint);
        if (!styled) {
          for (final (x, _) in _stops(current, number(ticks.interval) ?? labelStep, size.width)) {
            tick(x, length, paint);
          }
          return;
        }
        bool on(double hz, double step) => ((hz / step) - (hz / step).round()).abs() < 1e-6;
        // Short between, the scene's interval, and tall and heavy where a label is — drawn on
        // labels or not, so the axis keeps its rhythm in a pane too narrow for every label.
        if (spectrumMinorTick(span, size.width, labelStep) case final minor?) {
          for (final (x, hz) in _stops(current, minor, size.width)) {
            if (!on(hz, labelStep)) tick(x, length / 2, paint);
          }
        }
        if (number(ticks.interval) case final interval?) {
          for (final (x, hz) in _stops(current, interval, size.width)) {
            if (!on(hz, labelStep)) tick(x, length, paint);
          }
        }
        final labelled = Paint()
          ..color = paint.color
          ..strokeWidth = width * 2;
        for (final (x, _) in _stops(current, labelStep, size.width)) {
          tick(x, length * 1.75, labelled);
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
      final offset = number(shown.offset);
      final top =
          base +
          switch (shown.align) {
            'start' => offset ?? 0,
            'end' => (offset ?? gap) - across,
            'center' => (offset ?? gap / 2) - across / 2,
            _ => offset ?? (gap - across) / 2,
          };
      final box = _toScreen(toScreen, Rect.fromLTWH(left, top, along, across));
      if (clear?.overlaps(box) ?? false) continue;
      lastRight = left + along;
      if (vfoLabel?.rect?.overlaps(box) ?? false) {
        canvas.saveLayer(box.inflate(1), Paint()..color = Color.fromRGBO(0, 0, 0, _underVfoLabel));
        painter.paint(canvas, box.topLeft);
        canvas.restore();
      } else {
        painter.paint(canvas, box.topLeft);
      }
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
/// Where an annotation, or the tuned frequency's label, takes clicks; open with
/// more lines, where each line ends down the screen, for a click to name it.
typedef _AnnotationHit = ({Rect rect, SceneSpectrumAnnotation? annotation, double hz, bool away, List<double>? lines});

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

/// A badge's text beside the annotation's.
const _badgeScale = .85;

/// Where an annotation's box goes and what it is drawn with: [centring] is how far its text sits
/// into a box stretched over a passband, and [hold] where an open one stood closed, on the screen.
typedef _Placed = ({
  Rect rect,
  Path shape,
  TextPainter painter,
  TextRange? badge,
  double padX,
  double padY,
  double lift,
  double centring,
  double hz,
  double x,
  double near,
  Rect? hold,
});

/// An annotation's text as drawn: its icon, its text and its badge, and open, the lines it stands
/// for under it — every line's text past an icon's room where any line has an icon, a line without
/// one keeping the room blank. The text alone, what else it is built from, where the badge lies in
/// it, and the span.
({String plain, String key, TextRange? badge, InlineSpan Function()? build}) _annotationText(SceneSpectrumAnnotation a, TextStyle style, {required bool open}) {
  final lines = [(text: a.text, icon: a.icon), if (open) ...?a.more];
  final room = lines.map((l) => l.icon).nonNulls.firstOrNull;
  final badge = a.badge;
  if (room == null && badge == null) {
    final plain = lines.map((l) => l.text).join('\n');
    return (plain: plain, key: '', badge: null, build: null);
  }
  final spans = <InlineSpan>[];
  final plain = StringBuffer();
  TextRange? at;
  for (final (i, line) in lines.indexed) {
    if (i > 0) {
      spans.add(const TextSpan(text: '\n'));
      plain.write('\n');
    }
    if (room != null) {
      // Without an icon, the room's glyph, unseen.
      final icon = line.icon ?? (name: room.name, color: const Color(0x00000000));
      final data = resolveIconName(icon.name), glyph = String.fromCharCode(data.codePoint);
      spans.add(
        TextSpan(
          text: glyph,
          style: style.copyWith(fontFamily: data.fontFamily, package: data.fontPackage, fontFamilyFallback: const [], color: icon.color),
        ),
      );
      spans.add(const TextSpan(text: ' '));
      plain.write('$glyph ');
    }
    spans.add(TextSpan(text: line.text));
    plain.write(line.text);
    if (i == 0 && badge != null) {
      spans.add(const TextSpan(text: ' '));
      plain.write(' ');
      final start = plain.length;
      spans.add(
        TextSpan(
          text: badge.text,
          style: style.copyWith(fontSize: (style.fontSize ?? 14) * _badgeScale, color: badge.color),
        ),
      );
      plain.write(badge.text);
      at = TextRange(start: start, end: plain.length);
      // Room past it for its pill's end.
      spans.add(const TextSpan(text: '\u2009'));
      plain.write('\u2009');
    }
  }
  final key = [for (final l in lines) '${l.icon?.name}:${l.icon?.color?.toARGB32()}', '${badge?.text}:${badge?.color?.toARGB32()}'].join('|');
  return (plain: plain.toString(), key: key, badge: at, build: () => TextSpan(style: style, children: spans));
}

FontWeight? _weight(double? w) => w == null ? null : FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

/// The capitals' height in [painter]'s first line and how far below the line's top they start:
/// from the baseline up by Roboto's capital height, 0.71 em.
(double, double) _capitals(TextPainter painter, double size) {
  final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final height = math.min(baseline, size * .71);
  return (height, baseline - height);
}

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

  /// Where the tuned frequency's label is drawn, written on every paint for the axis's.
  final _VfoLabelBox? vfoLabelBox;

  _AnnotationPainter({
    required this.revealed,
    this.clear,
    this.vfoLabelBox,
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
    vfoLabelBox?.rect = null;
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
    _Placed? place(SceneSpectrumAnnotation a, {bool open = false}) {
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
      // Open, the lines it stands for under its own.
      final opened = open && (a.more?.isNotEmpty ?? false);
      final (:plain, :key, :badge, :build) = _annotationText(a, style, open: opened);
      final painter = texts.get(plain, style, span: build, spanKey: key);
      final padX = number(a.padding) ?? 2, padY = number(a.paddingY) ?? 2;
      // Upright on the screen, the text is as tall as its lines, or with `baseline`, from its
      // capitals' tops, [lift] below the first line's, to its baseline — or with more lines under
      // it, to the last line's foot.
      var (upright, lift) = a.baseline ? _capitals(painter, style.fontSize ?? 14) : (painter.height, 0.0);
      if (opened) upright = painter.height - lift;
      final (padAlong, padAcross) = turned ? (padY, padX) : (padX, padY);
      final (textAlong, textAcross) = turned ? (upright, painter.width) : (painter.width, upright);
      var width = textAlong + padAlong * 2;
      final height = textAcross + padAcross * 2;
      var left = switch (a.align) {
        'start' => x,
        'end' => x - width,
        _ => x - width / 2,
      };
      // Over a span longer than the text, the box covers it, the text in its middle.
      var centring = 0.0;
      if (a.stretch case final stretch? when !opened) {
        final (from, to) = (number(stretch.from), number(stretch.to));
        if (from != null && to != null) {
          final (low, high) = ((hz + math.min(from, to) - current.lowHz) / span * size.width, (hz + math.max(from, to) - current.lowHz) / span * size.width);
          if (high - low > width) {
            centring = (high - low - width) / 2;
            (left, width) = (low, high - low);
          }
        }
      }
      if (left + width < 0 || left > size.width) return null;
      final top = a.onWaterfall ? near : near - height;
      var rect = Rect.fromLTWH(left, top, width, height);
      // Open with more lines, it hangs down the screen from where its text stood closed, its first
      // line in place — moved up or left only as far as it must to stay on the screen. It still holds
      // where it stood closed, so a pointer on a part of that the open box leaves keeps it open.
      Rect? hold;
      if (opened) {
        final closed = place(a), fromScreen = Matrix4.tryInvert(toScreen);
        if (closed != null && fromScreen != null) {
          final (shut, grown) = (_toScreen(toScreen, closed.rect), _toScreen(toScreen, rect));
          final textAt = shut.topLeft + (turned ? Offset(0, closed.centring) : Offset(closed.centring, 0));
          final left = math.max(0.0, math.min(textAt.dx, screen.width - grown.width));
          final top = math.max(0.0, math.min(textAt.dy, screen.height - grown.height));
          rect = MatrixUtils.transformRect(fromScreen, Rect.fromLTWH(left, top, grown.width, grown.height));
          hold = closed.shape.getBounds();
        }
      }
      final shape = _bubble(rect, number(a.radius) ?? 2, x: x, align: a.align, point: point, up: up).transform(toScreen.storage);
      return (
        rect: rect,
        shape: shape,
        painter: painter,
        badge: badge,
        padX: padX,
        padY: padY,
        lift: lift,
        centring: centring,
        hz: hz,
        x: x,
        near: near,
        hold: hold,
      );
    }

    void draw(SceneSpectrumAnnotation a, _Placed at, {bool open = false}) {
      final (rect, shape) = (at.rect, at.shape);
      canvas.drawPath(shape, Paint()..color = (open ? a.openBackground : null) ?? a.background ?? background);
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
      final textAt = _toScreen(toScreen, rect).topLeft + Offset(at.padX + (turned ? 0 : at.centring), at.padY - at.lift + (turned ? at.centring : 0));
      // Open, its border facing the edge it stands from.
      if (a.openBorder case final border? when open) {
        // The open box's own edge: grown down the screen, it may reach past the closed one's.
        final near = a.onWaterfall ? rect.top : rect.bottom;
        canvas.drawPath(
          (Path()
                ..moveTo(rect.left, near)
                ..lineTo(rect.right, near))
              .transform(toScreen.storage),
          Paint()
            ..color = border.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = number(border.width) ?? 2,
        );
      }
      // The badge's pill, behind its text: from a little over its capitals to a little under the baseline.
      if ((at.badge, a.badge) case (final range?, final badge?)) {
        final boxes = at.painter.getBoxesForSelection(TextSelection(baseOffset: range.start, extentOffset: range.end));
        final first = at.painter.computeLineMetrics().firstOrNull;
        if (boxes.isNotEmpty && first != null) {
          final (left, right) = (boxes.map((b) => b.left).reduce(math.min), boxes.map((b) => b.right).reduce(math.max));
          final baseline = textAt.dy + first.baseline, capitals = (number(a.size) ?? text.fontSize ?? 14) * _badgeScale * .71;
          final pill = Rect.fromLTRB(textAt.dx + left - 4, baseline - capitals - 2.5, textAt.dx + right + 4, baseline + 2.5);
          canvas.drawRRect(RRect.fromRectAndRadius(pill, Radius.circular(pill.height / 2)), Paint()..color = badge.background ?? const Color(0x33808080));
        }
      }
      at.painter.paint(canvas, textAt);
      final lines = !open || (a.more?.isEmpty ?? true) ? null : [for (final line in at.painter.computeLineMetrics()) textAt.dy + line.baseline + line.descent];
      hits.add((rect: at.hold == null ? shape.getBounds() : shape.getBounds().expandToInclude(at.hold!), annotation: a, hz: at.hz, away: false, lines: lines));
    }

    // A collapsed one the pointer is on, drawn whole over the rest, or one with more lines with
    // them under it: those it would cover wait.
    final shown = revealed();
    final open = shown == null ? null : marks.spec.annotations.where((a) => a.id == shown && a.opens).firstOrNull;
    final opened = open == null ? null : place(open, open: true);
    for (final a in marks.spec.annotations) {
      if (a == open) continue;
      if (a.collapsed) {
        final at = place(a);
        if (at == null) continue;
        final width = a.collapsedBox ? at.rect.width : a.collapsedWidth ?? at.rect.width * .8, middle = at.rect.center.dx;
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
          lines: null,
        ));
        continue;
      }
      final at = place(a);
      if (at == null || (opened != null && at.rect.overlaps(opened.rect))) continue;
      draw(a, at);
    }
    // Laid out again to be drawn: what it was placed with may have been let go meanwhile.
    if (open != null && opened != null) draw(open, place(open, open: true) ?? opened, open: true);
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
    hits.add((rect: _toScreen(toScreen, away == 0 ? rect : whole), annotation: null, hz: vfo, away: away != 0, lines: null));
    final onScreen = _toScreen(toScreen, rect);
    vfoLabelBox?.rect = _toScreen(toScreen, whole);
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
