// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `spectrum` control: the radio's panadapter and waterfall, drawn
// by the host from sweeps that never cross the extension bridge
// (docs/design/panel-scenes.md § Spectrum).

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/cat/spectrum.dart';
import 'scene_model.dart';

/// Where a scene's spectrum controls get their sweeps, and its `radio.` values
/// their readings. Null on the scene view for a panel that may not read the
/// radio, which then shows the control as unavailable rather than drawing
/// nothing, and the values as no reading.
abstract class SceneSpectrumSource {
  /// The node a control's `radio` names; null names the designated radio.
  /// Null when there is no such radio.
  String? resolve(String? radio);

  /// Subscribing is what starts the radio's scope, so only a pane on screen
  /// subscribes.
  Stream<SpectrumFrame> frames(String uuid);

  /// Why there is nothing to draw, in words for the operator, or null.
  String? problem(String uuid);

  /// Where the radio is tuned, for the marker.
  double? vfoHz(String uuid);

  /// Fires when [problem], [vfoHz] or what [resolve] answers may have changed.
  Listenable get changes;

  /// The words for a control with no radio, or one waiting for a first sweep.
  String get noRadio;
  String get waiting;

  /// [uuid]'s live readings, by `RadioMeter` name, and `transmitting` as 1 or
  /// 0 — empty while it is not connected, and without any meter it has not
  /// fresh.
  Map<String, num> readings(String uuid);

  /// Fires when [readings] may have changed — at meter rate, so only what
  /// draws them listens.
  Listenable get readingChanges;

  /// Moves [uuid]'s scope to centre on [centerHz], for a control that
  /// `follow`s the VFO. False where the radio's window is not the app's to
  /// move, or the panel may not command the radio.
  bool recenter(String uuid, int centerHz);
}

/// How long a display goes without a sweep before it says it is waiting,
/// rather than holding the last picture as though it were live.
const _staleAfter = Duration(seconds: 3);

/// Rows of waterfall history kept.
const _waterfallRows = 240;

const _defaultAverage = 40.0;

/// The gap between the panadapter and the waterfall a `scale` leaves when it
/// names none, in logical pixels.
const _defaultGap = 20.0;
const _defaultFps = 15.0;

class SceneSpectrumView extends StatefulWidget {
  final SceneControl control;
  final SceneSpectrumSource? source;

  /// Off while the pane or the app is hidden: the radio's scope stops with
  /// the last display that is actually seen.
  final bool awake;

  /// The scene's values, for the spec's numbers that name one.
  final Map<String, double> values;
  final void Function(double hz, double db)? onHover;
  final void Function(double hz)? onTune;

  /// A click on an annotation with an event, at the frequency it marks.
  final void Function(SceneSpectrumAnnotation annotation, double hz)? onAnnotation;

  const SceneSpectrumView({
    super.key,
    required this.control,
    required this.source,
    required this.awake,
    this.values = const {},
    this.onHover,
    this.onTune,
    this.onAnnotation,
  });

  @override
  State<SceneSpectrumView> createState() => _SceneSpectrumViewState();
}

class _SceneSpectrumViewState extends State<SceneSpectrumView> {
  StreamSubscription<SpectrumFrame>? _subscription;
  String? _uuid;
  ({SceneSpectrumSource? source, String? uuid})? _historyIdentity;
  int _subscriptionEpoch = 0;
  int _rowEpoch = 0;

  /// The last sweep, its levels averaged — what the trace draws.
  SpectrumFrame? _frame;

  /// One check a second while subscribed, against the last sweep's arrival
  /// — not a timer per sweep, which would be thirty made and cancelled a
  /// second.
  Timer? _staleTimer;
  int _lastFrameMillis = 0;
  final _texts = _TextCache();
  bool _stale = true;

  /// Bumped to repaint without rebuilding the tree — each part on its own
  /// schedule: the trace at [SceneSpectrumSpec.fps], the waterfall per row.
  final _panRepaint = ValueNotifier<int>(0);
  final _waterfallRepaint = ValueNotifier<int>(0);
  final _rows = <_Row>[];

  /// The loudest reading of each bin since the last row, so a waterfall
  /// slower than the sweeps still marks a signal that came and went between —
  /// over [_peakFrame]'s frequencies only: a bin of another range is another
  /// frequency, and its peak would be drawn where it never was.
  Float32List? _rowPeak;
  SpectrumFrame? _peakFrame;
  int _lastRowMillis = 0;
  int _lastPaintMillis = 0;
  int _lastRecenterMillis = 0;

  /// [SceneSpectrumSpec.follow]: with the tuned frequency inside the margin
  /// at either edge — or off the window altogether — the window moves just
  /// far enough to put it ON that margin, so the picture scrolls with the
  /// dial rather than jumping to centre it. At most four moves a second: the
  /// radio's window catches up over a few sweeps, and a move sent on each
  /// of them would overshoot.
  void _keepInView(SpectrumFrame frame, int now) {
    final margin = _spec.follow;
    final (uuid, source) = (_uuid, widget.source);
    if (margin == null || uuid == null || source == null || now - _lastRecenterMillis < 250) return;
    final vfo = source.vfoHz(uuid);
    final width = (frame.highHz - frame.lowHz).toDouble();
    if (vfo == null || width <= 0) return;
    final double center;
    if (vfo < frame.lowHz + margin * width) {
      center = vfo + (.5 - margin) * width;
    } else if (vfo > frame.highHz - margin * width) {
      center = vfo - (.5 - margin) * width;
    } else {
      return;
    }
    if (source.recenter(uuid, center.round())) _lastRecenterMillis = now;
  }

  late List<int> _palette = _paletteFor(_spec);

  /// Where the annotations were last drawn, topmost last — what a click and
  /// the pointer's cursor test against.
  final _annotationHits = <_AnnotationHit>[];
  bool _overClickable = false;

  _AnnotationHit? _annotationAt(Offset at) {
    for (final hit in _annotationHits.reversed) {
      if (hit.rect.contains(at)) return hit;
    }
    return null;
  }

  SceneSpectrumSpec get _spec => widget.control.spectrum!;

  double? _number(SceneNumber? n) => n?.resolve(widget.values);

  @override
  void initState() {
    super.initState();
    widget.source?.changes.addListener(_onSourceChanged);
    _follow();
  }

  @override
  void didUpdateWidget(SceneSpectrumView old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      old.source?.changes.removeListener(_onSourceChanged);
      widget.source?.changes.addListener(_onSourceChanged);
    }
    final was = old.control.spectrum!;
    if (was.palette != _spec.palette || !listEquals(was.waterfallColors, _spec.waterfallColors)) {
      _palette = _paletteFor(_spec);
      _clearRows();
    }
    _follow();
  }

  void _onSourceChanged() {
    _follow();
    if (mounted) setState(() {});
  }

  /// Subscribes to the radio this control names, while it is seen.
  void _follow() {
    final resolved = widget.source?.resolve(_spec.radio);
    final identity = (source: widget.source, uuid: resolved);
    final changed = identity != _historyIdentity;
    if (changed) {
      _historyIdentity = identity;
      _clearHistory();
    }
    final uuid = widget.awake ? resolved : null;
    if (!changed && uuid == _uuid && (_subscription != null) == (uuid != null)) return;
    final epoch = ++_subscriptionEpoch;
    _subscription?.cancel();
    _subscription = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _uuid = uuid;
    if (uuid == null) return;
    _subscription = widget.source!.frames(uuid).listen((frame) {
      if (epoch == _subscriptionEpoch) _onFrame(frame);
    });
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_stale && realNowMillis() - _lastFrameMillis > _staleAfter.inMilliseconds) setState(() => _stale = true);
    });
  }

  void _onFrame(SpectrumFrame sweep) {
    if (!mounted) return;
    // Everything below — trace, waterfall, follow, labels — works on the window shown.
    final frame = cropSpectrumFrame(sweep, _number(_spec.span));
    final wasStale = _stale;
    _frame = _averaged(frame);
    _stale = false;
    // The real clock: a frame rate is about the screen in front of the
    // operator, and must not travel with the app clock.
    final now = realNowMillis();
    _lastFrameMillis = now;
    _keepInView(frame, now);
    if (_spec.waterfall) _feedWaterfall(frame, now);
    if (wasStale) {
      setState(() {});
    } else if (now - _lastPaintMillis >= 1000 / (_number(_spec.fps) ?? _defaultFps).clamp(1, 60)) {
      _lastPaintMillis = now;
      _panRepaint.value++;
    }
  }

  /// An exponential average per bin, restarted whenever the bins stop
  /// meaning the same frequencies — a span or a retune.
  SpectrumFrame _averaged(SpectrumFrame frame) {
    final previous = _frame;
    final keep = (_number(_spec.average) ?? _defaultAverage).clamp(0, 99) / 100;
    if (previous == null || keep == 0 || previous.levels.length != frame.levels.length || previous.lowHz != frame.lowHz || previous.highHz != frame.highHz) {
      return frame;
    }
    final levels = Float32List(frame.levels.length);
    for (var i = 0; i < levels.length; i++) {
      levels[i] = previous.levels[i] * keep + frame.levels[i] * (1 - keep);
    }
    return SpectrumFrame(
      lowHz: frame.lowHz,
      highHz: frame.highHz,
      levels: levels,
      floorDb: frame.floorDb,
      ceilingDb: frame.ceilingDb,
      atMillis: frame.atMillis,
    );
  }

  void _feedWaterfall(SpectrumFrame frame, int now) {
    final levels = frame.levels;
    final last = _peakFrame;
    if (last == null || last.levels.length != levels.length || last.lowHz != frame.lowHz || last.highHz != frame.highHz) _rowPeak = null;
    _peakFrame = frame;
    final peak = _rowPeak ??= Float32List.fromList(levels);
    for (var i = 0; i < levels.length; i++) {
      if (levels[i] > peak[i]) peak[i] = levels[i];
    }
    final speed = _number(_spec.waterfallSpeed);
    if (speed != null && now - _lastRowMillis < 1000 / speed) return;
    _lastRowMillis = now;
    _rowPeak = null;
    _addRow(peak, frame);
  }

  (double, double) _panScale(SpectrumFrame frame) {
    final floor = frame.floorDb + (_number(_spec.floor) ?? 0);
    return (floor, _number(_spec.range) ?? frame.ceilingDb - frame.floorDb);
  }

  (double, double) _waterfallScale(SpectrumFrame frame) {
    final (floor, range) = _panScale(frame);
    return (
      switch (_number(_spec.waterfallFloor)) {
        final offset? => frame.floorDb + offset,
        null => floor,
      },
      _number(_spec.waterfallRange) ?? range,
    );
  }

  void _addRow(Float32List levels, SpectrumFrame frame) {
    final (floor, range) = _waterfallScale(frame);
    final pixels = Uint32List(levels.length);
    for (var i = 0; i < levels.length; i++) {
      final t = (levels[i] - floor) / range;
      // NaN passes clamp; its round() throws.
      pixels[i] = _palette[t.isFinite ? (t.clamp(0.0, 1.0) * 255).round() : 0];
    }
    final (lowHz, highHz) = (frame.lowHz, frame.highHz);
    final epoch = _rowEpoch;
    ui.decodeImageFromPixels(pixels.buffer.asUint8List(), levels.length, 1, ui.PixelFormat.rgba8888, (image) {
      if (!mounted || epoch != _rowEpoch) {
        image.dispose();
        return;
      }
      _rows.insert(0, (image: image, lowHz: lowHz, highHz: highHz));
      while (_rows.length > _waterfallRows) {
        _rows.removeLast().image.dispose();
      }
      _waterfallRepaint.value++;
    });
  }

  void _clearRows() {
    _rowEpoch++;
    for (final row in _rows) {
      row.image.dispose();
    }
    _rows.clear();
  }

  void _clearHistory() {
    _clearRows();
    _frame = null;
    _rowPeak = null;
    _peakFrame = null;
    _stale = true;
    _lastFrameMillis = 0;
    _lastRowMillis = 0;
    _lastPaintMillis = 0;
    _lastRecenterMillis = 0;
    _annotationHits.clear();
    _overClickable = false;
  }

  @override
  void dispose() {
    _subscriptionEpoch++;
    widget.source?.changes.removeListener(_onSourceChanged);
    _subscription?.cancel();
    _staleTimer?.cancel();
    _texts.dispose();
    _clearRows();
    _panRepaint.dispose();
    _waterfallRepaint.dispose();
    super.dispose();
  }

  /// How far along the sweep [at] is, 0 to 1, whichever way it flows.
  double? _fractionAt(Offset at, Size size) {
    final width = _canonical(_spec.flow, size).width;
    if (width <= 0) return null;
    return (_toCanonical(_spec.flow, size, at).dx / width).clamp(0.0, 1.0);
  }

  double? _hzAt(Offset at, Size size) {
    final frame = _frame, fraction = _fractionAt(at, size);
    if (frame == null || fraction == null) return null;
    return frame.lowHz + fraction * (frame.highHz - frame.lowHz);
  }

  void _hover(Offset at, Size size) {
    final clickable = _annotationAt(at)?.annotation.event != null && widget.onAnnotation != null;
    if (clickable != _overClickable) setState(() => _overClickable = clickable);
    final frame = _frame, hz = _hzAt(at, size), fraction = _fractionAt(at, size);
    if (frame == null || hz == null || fraction == null || widget.onHover == null || frame.levels.isEmpty) return;
    final bin = (fraction * (frame.levels.length - 1)).round().clamp(0, frame.levels.length - 1);
    widget.onHover!(hz, frame.levels[bin].toDouble());
  }

  BorderSide _side(SceneSpectrumBorder? border) {
    final width = _number(border?.width) ?? 1;
    if (border == null || border.color == null || width <= 0) return BorderSide.none;
    return BorderSide(color: border.color!, width: width);
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final uuid = _uuid ?? source?.resolve(_spec.radio);
    final message = source == null
        ? context.t.settings.station.spectrumUnavailable
        : uuid == null
        ? source.noRadio
        : source.problem(uuid) ?? (_stale ? source.waiting : null);
    final scheme = Theme.of(context).colorScheme;
    final spec = _spec;
    final trace = spec.traceColor ?? scheme.primary;
    final vfoHz = uuid == null ? null : source?.vfoHz(uuid);
    final _Style style = (
      trace: trace,
      traceWidth: _number(spec.traceWidth) ?? 1,
      fill: spec.fillColor ?? trace.withValues(alpha: .25),
      fillBottom: spec.fillColorBottom,
      grid: spec.gridColor ?? scheme.outlineVariant.withValues(alpha: .5),
      gridDashed: spec.gridDashed,
      waterfallGrid: spec.waterfallGridColor,
      marker: scheme.error.withValues(alpha: .7),
    );
    final marks = (spec: spec, number: _number, vfoHz: vfoHz);
    return Semantics(
      label: widget.control.label,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return MouseRegion(
            cursor: _overClickable ? SystemMouseCursors.click : MouseCursor.defer,
            onHover: (e) => _hover(e.localPosition, size),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.onTune == null && widget.onAnnotation == null
                  ? null
                  : (e) {
                      if (_annotationAt(e.localPosition) case final hit? when hit.annotation.event != null && widget.onAnnotation != null) {
                        widget.onAnnotation!(hit.annotation, hit.hz);
                      } else if (_hzAt(e.localPosition, size) case final hz? when widget.onTune != null) {
                        widget.onTune!(hz);
                      }
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: spec.backgroundColor ?? scheme.surfaceContainerLowest),
                  ...() {
                    final scale = spec.scale;
                    final flow = spec.flow;
                    // Laid out as if flowing down, then mapped onto the box.
                    final frame = _canonical(flow, size);
                    final toScreen = _flowMatrix(flow, size);
                    final gap = scale == null ? 0.0 : (_number(scale.gap) ?? _defaultGap).clamp(0.0, frame.height);
                    final rest = frame.height - gap;
                    final panHeight = !spec.pan ? 0.0 : (spec.waterfall ? rest * spec.split : rest);
                    // What labels and ticks measure from: under the
                    // panadapter, or atop the waterfall.
                    final base = spec.pan ? panHeight : gap;
                    Rect place(double top, double height) => _toScreen(toScreen, Rect.fromLTWH(0, top, frame.width, height));
                    // The gap's own top and bottom, wherever the flow turns them.
                    final (nearSide, farSide) = (_side(scale?.borderTop), _side(scale?.borderBottom));
                    final border = switch (flow) {
                      SceneSpectrumFlow.down => Border(top: nearSide, bottom: farSide),
                      SceneSpectrumFlow.up => Border(bottom: nearSide, top: farSide),
                      SceneSpectrumFlow.right => Border(left: nearSide, right: farSide),
                      SceneSpectrumFlow.left => Border(right: nearSide, left: farSide),
                    };
                    final labelStyle = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
                    return [
                      if (spec.pan)
                        Positioned.fromRect(
                          rect: place(0, panHeight),
                          child: ClipRect(
                            child: CustomPaint(
                              painter: _PanPainter(
                                repaint: _panRepaint,
                                flow: flow,
                                frame: () => _stale ? null : _frame,
                                scale: _panScale,
                                marks: marks,
                                style: style,
                              ),
                            ),
                          ),
                        ),
                      if (scale != null && gap > 0)
                        Positioned.fromRect(
                          rect: place(panHeight, gap),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: scale.background, border: border),
                          ),
                        ),
                      if (spec.waterfall)
                        Positioned.fromRect(
                          rect: place(panHeight + gap, frame.height - panHeight - gap),
                          child: ClipRect(
                            child: CustomPaint(
                              painter: _WaterfallPainter(repaint: _waterfallRepaint, flow: flow, rows: _rows, frame: () => _frame, marks: marks, style: style),
                            ),
                          ),
                        ),
                      if (spec.annotations.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _AnnotationPainter(
                                texts: _texts,
                                repaint: _panRepaint,
                                flow: flow,
                                frame: () => _frame,
                                marks: marks,
                                panBottom: spec.pan ? panHeight : null,
                                waterfallTop: spec.waterfall ? panHeight + gap : null,
                                hits: _annotationHits,
                                text: labelStyle.copyWith(color: scheme.onSurface),
                                background: scheme.surface.withValues(alpha: .8),
                              ),
                            ),
                          ),
                        ),
                      if (scale != null && (scale.labels != null || scale.ticks != null))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ScalePainter(
                                texts: _texts,
                                repaint: _panRepaint,
                                flow: flow,
                                frame: () => _frame,
                                base: base,
                                gap: gap,
                                labels: scale.labels,
                                ticks: scale.ticks,
                                number: _number,
                                text: labelStyle.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ),
                    ];
                  }(),
                  if (message != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.md),
                        child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The spectrum's own frame — frequency along x, the panadapter, gap and
/// waterfall stacked down y — mapped onto a [screen] box for [flow]. A
/// mirror for `up`, a quarter turn for `right` and `left`, with frequency
/// rising up the screen in both.
Matrix4 _flowMatrix(SceneSpectrumFlow flow, Size screen) {
  Matrix4 rows(List<double> x, List<double> y) => Matrix4.zero()
    ..setEntry(0, 0, x[0])
    ..setEntry(0, 1, x[1])
    ..setEntry(0, 3, x[2])
    ..setEntry(1, 0, y[0])
    ..setEntry(1, 1, y[1])
    ..setEntry(1, 3, y[2])
    ..setEntry(2, 2, 1)
    ..setEntry(3, 3, 1);
  final (w, h) = (screen.width, screen.height);
  return switch (flow) {
    SceneSpectrumFlow.down => Matrix4.identity(),
    SceneSpectrumFlow.up => rows([1, 0, 0], [0, -1, h]),
    SceneSpectrumFlow.right => rows([0, 1, 0], [-1, 0, h]),
    SceneSpectrumFlow.left => rows([0, -1, w], [-1, 0, h]),
  };
}

bool _turned(SceneSpectrumFlow flow) => flow == SceneSpectrumFlow.right || flow == SceneSpectrumFlow.left;

/// The spectrum's own frame for a [screen] box.
Size _canonical(SceneSpectrumFlow flow, Size screen) => _turned(flow) ? screen.flipped : screen;

Offset _toCanonical(SceneSpectrumFlow flow, Size screen, Offset at) => switch (flow) {
  SceneSpectrumFlow.down => at,
  SceneSpectrumFlow.up => Offset(at.dx, screen.height - at.dy),
  SceneSpectrumFlow.right => Offset(screen.height - at.dy, at.dx),
  SceneSpectrumFlow.left => Offset(screen.height - at.dy, screen.width - at.dx),
};

Rect _toScreen(Matrix4 m, Rect canonical) => MatrixUtils.transformRect(m, canonical);

/// Draws a part in its own frame: [paint] gets the canonical size.
void _inFlow(Canvas canvas, Size screen, SceneSpectrumFlow flow, void Function(Size size) paint) {
  canvas.save();
  canvas.transform(_flowMatrix(flow, screen).storage);
  paint(_canonical(flow, screen));
  canvas.restore();
}

typedef _Style = ({Color trace, double traceWidth, Color fill, Color? fillBottom, Color grid, bool gridDashed, Color? waterfallGrid, Color marker});

/// What the tuned-frequency line and the overlays need: the spec, how to read
/// its numbers, and where the radio is tuned.
typedef _Marks = ({SceneSpectrumSpec spec, double? Function(SceneNumber?) number, double? vfoHz});

/// A step of 1, 2 or 5 × 10ⁿ Hz that puts four to ten lines across [span].
double _gridStep(double span) {
  var step = math.pow(10, (math.log(span / 8) / math.ln10).floor()).toDouble();
  for (final factor in const [1, 2, 5, 10]) {
    if (span / (step * factor) <= 10) return step * factor;
  }
  return step * 10;
}

void _line(Canvas canvas, Offset a, Offset b, Paint paint, {bool dashed = false}) {
  if (!dashed) return canvas.drawLine(a, b, paint);
  final length = (b - a).distance;
  if (length == 0) return;
  final unit = (b - a) / length;
  for (var d = 0.0; d < length; d += 6) {
    canvas.drawLine(a + unit * d, a + unit * math.min(d + 3, length), paint);
  }
}

void _paintFrequencyLines(Canvas canvas, Size size, SpectrumFrame frame, Color color, {bool dashed = false}) {
  final span = (frame.highHz - frame.lowHz).toDouble();
  if (span <= 0) return;
  final step = _gridStep(span);
  final paint = Paint()..color = color;
  for (var hz = (frame.lowHz / step).ceil() * step; hz <= frame.highHz; hz += step) {
    final x = (hz - frame.lowHz) / span * size.width;
    _line(canvas, Offset(x, 0), Offset(x, size.height), paint, dashed: dashed);
  }
}

/// The overlays and the tuned-frequency line on one part, in two passes:
/// what goes behind whatever the part draws next, and what goes in [front].
void _paintMarks(Canvas canvas, Size size, SpectrumFrame? frame, _Marks marks, _Style style, {required bool pan, required bool front}) {
  if (frame == null || frame.highHz <= frame.lowHz) return;
  final span = (frame.highHz - frame.lowHz).toDouble();
  double x(double hz) => (hz - frame.lowHz) / span * size.width;
  SceneSpectrumStyle? styleOf(SceneSpectrumMark mark) => pan ? mark.pan : mark.waterfall;
  for (final mark in marks.spec.overlays) {
    final s = styleOf(mark);
    final anchor = switch (mark.anchor) {
      SceneSpectrumAnchor.vfo => marks.vfoHz,
      SceneSpectrumAnchor.center => (frame.lowHz + frame.highHz) / 2,
      SceneSpectrumAnchor.absolute => 0.0,
    };
    if (s == null || anchor == null) continue;
    final linesNow = front != mark.behind;
    final edge = Paint()
      ..color = s.color ?? style.marker
      ..strokeWidth = marks.number(s.width) ?? 1;
    if (marks.number(mark.at) case final at?) {
      if (linesNow && s.color != null) canvas.drawLine(Offset(x(anchor + at), 0), Offset(x(anchor + at), size.height), edge);
      continue;
    }
    final (from, to) = (marks.number(mark.from), marks.number(mark.to));
    if (from == null || to == null) continue;
    final (left, right) = (x(anchor + math.min(from, to)), x(anchor + math.max(from, to)));
    if (!front && s.fill != null) canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), Paint()..color = s.fill!);
    if (linesNow && s.color != null) {
      canvas.drawLine(Offset(left, 0), Offset(left, size.height), edge);
      canvas.drawLine(Offset(right, 0), Offset(right, size.height), edge);
    }
  }
  if (!front || marks.vfoHz == null) return;
  final center = marks.spec.center;
  final s = center == null ? null : styleOf(center);
  if (center != null && s == null) return;
  final vx = x(marks.vfoHz!);
  if (vx < 0 || vx > size.width) return;
  canvas.drawLine(
    Offset(vx, 0),
    Offset(vx, size.height),
    Paint()
      ..color = s?.color ?? style.marker
      ..strokeWidth = marks.number(s?.width) ?? 1,
  );
}

class _PanPainter extends CustomPainter {
  final SceneSpectrumFlow flow;
  final SpectrumFrame? Function() frame;
  final (double, double) Function(SpectrumFrame) scale;
  final _Marks marks;
  final _Style style;

  _PanPainter({required Listenable repaint, required this.flow, required this.frame, required this.scale, required this.marks, required this.style})
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) => _inFlow(canvas, screen, flow, (size) => _paint(canvas, size));

  void _paint(Canvas canvas, Size size) {
    final current = frame();
    if (current == null) return;
    final (floor, range) = scale(current);
    final gridPaint = Paint()..color = style.grid;
    for (var db = 10.0; db < range; db += 10) {
      final y = size.height - db / range * size.height;
      _line(canvas, Offset(0, y), Offset(size.width, y), gridPaint, dashed: style.gridDashed);
    }
    _paintFrequencyLines(canvas, size, current, style.grid, dashed: style.gridDashed);
    _paintMarks(canvas, size, current, marks, style, pan: true, front: false);
    final levels = current.levels;
    if (levels.length >= 2) {
      final path = Path();
      for (var i = 0; i < levels.length; i++) {
        final x = i / (levels.length - 1) * size.width;
        final y = size.height - ((levels[i] - floor) / range).clamp(0.0, 1.0) * size.height;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final fill = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()..color = style.fill;
      // Top of the pane to its bottom, not along the trace: a signal reads
      // brighter the taller it stands.
      if (style.fillBottom case final bottom?) {
        fillPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.fill, bottom],
        ).createShader(Offset.zero & size);
      }
      canvas.drawPath(fill, fillPaint);
      canvas.drawPath(
        path,
        Paint()
          ..color = style.trace
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.traceWidth,
      );
    }
    _paintMarks(canvas, size, current, marks, style, pan: true, front: true);
  }

  // Rebuilt only when the tree is: a tuning, a scene value, a theme.
  @override
  bool shouldRepaint(_PanPainter old) => true;
}

/// [frame] cut down to [widthHz] about its middle, whole bins only; as it
/// is when it is no wider, or no width is asked for.
@visibleForTesting
SpectrumFrame cropSpectrumFrame(SpectrumFrame frame, double? widthHz) {
  final span = frame.highHz - frame.lowHz, bins = frame.levels.length;
  if (widthHz == null || widthHz >= span || bins < 2) return frame;
  final keep = math.max(2, (bins * widthHz / span).round());
  final first = (bins - keep) ~/ 2;
  final binHz = span / bins;
  return SpectrumFrame(
    lowHz: (frame.lowHz + first * binHz).round(),
    highHz: (frame.lowHz + (first + keep) * binHz).round(),
    levels: Float32List.sublistView(frame.levels, first, first + keep),
    floorDb: frame.floorDb,
    ceilingDb: frame.ceilingDb,
    atMillis: frame.atMillis,
  );
}

/// Where a row taken over [rowLowHz]–[rowHighHz] lies across a display
/// [width] wide that now shows [lowHz]–[highHz]: its left and right edges,
/// either of which may fall off the display.
@visibleForTesting
(double, double) waterfallRowExtent(int rowLowHz, int rowHighHz, int lowHz, int highHz, double width) {
  if (highHz <= lowHz) return (0, width);
  final span = (highHz - lowHz).toDouble();
  return ((rowLowHz - lowHz) / span * width, (rowHighHz - lowHz) / span * width);
}

/// One waterfall row, and the frequencies it was taken over.
typedef _Row = ({ui.Image image, int lowHz, int highHz});

class _WaterfallPainter extends CustomPainter {
  final SceneSpectrumFlow flow;
  final List<_Row> rows;

  /// For the frequency lines and the marks, which follow the latest sweep.
  final SpectrumFrame? Function() frame;
  final _Marks marks;
  final _Style style;

  _WaterfallPainter({required Listenable repaint, required this.flow, required this.rows, required this.frame, required this.marks, required this.style})
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) => _inFlow(canvas, screen, flow, (size) => _paint(canvas, size));

  void _paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final rowHeight = math.max(1.0, size.height / _waterfallRows);
    final paint = Paint()..filterQuality = FilterQuality.low;
    final current = frame();
    // Each row where its frequencies are NOW: a retune slides the history
    // sideways and a width change stretches it, rather than redrawing old
    // signals at frequencies they were never on. Off the window, clipped.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < rows.length; i++) {
      final top = i * rowHeight;
      if (top >= size.height) break;
      final row = rows[i];
      final (left, right) = current == null ? (0.0, size.width) : waterfallRowExtent(row.lowHz, row.highHz, current.lowHz, current.highHz, size.width);
      if (right <= 0 || left >= size.width) continue;
      canvas.drawImageRect(row.image, Rect.fromLTWH(0, 0, row.image.width.toDouble(), 1), Rect.fromLTRB(left, top, right, top + rowHeight + .5), paint);
    }
    canvas.restore();
    if (style.waterfallGrid case final grid? when current != null) _paintFrequencyLines(canvas, size, current, grid, dashed: style.gridDashed);
    // Both passes over the rows: under them, nothing would show.
    _paintMarks(canvas, size, current, marks, style, pan: false, front: false);
    _paintMarks(canvas, size, current, marks, style, pan: false, front: true);
  }

  @override
  bool shouldRepaint(_WaterfallPainter old) => true;
}

/// The frequency labels and ticks, over the whole control so an offset can
/// put them anywhere: in the gap, or over the panadapter or the waterfall.
class _ScalePainter extends CustomPainter {
  final SceneSpectrumFlow flow;
  final SpectrumFrame? Function() frame;
  final _TextCache texts;

  /// Where offsets measure from: the base of the panadapter, or the top of
  /// the waterfall where there is none.
  final double base;
  final double gap;
  final SceneSpectrumLabels? labels;
  final SceneSpectrumTicks? ticks;
  final double? Function(SceneNumber?) number;
  final TextStyle text;

  _ScalePainter({
    required Listenable repaint,
    required this.flow,
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
      _inFlow(canvas, screen, flow, (size) {
        final paint = Paint()
          ..color = ticks.color ?? text.color ?? const Color(0xFF888888)
          ..strokeWidth = number(ticks.width) ?? 1;
        final top = base + (number(ticks.offset) ?? 0);
        final length = number(ticks.length) ?? 4;
        for (final (x, _) in _stops(current, number(ticks.interval) ?? labelStep, size.width)) {
          canvas.drawLine(Offset(x, top), Offset(x, top + length), paint);
        }
      });
    }
    // Text is laid out in the spectrum's frame but drawn upright: its box is
    // mapped onto the screen, and the text set in that box.
    final size = _canonical(flow, screen);
    final toScreen = _flowMatrix(flow, screen);
    final turned = _turned(flow);
    final shown = labels;
    if (shown == null) return;
    final style = text.copyWith(
      fontFamily: shown.fontFamily,
      fontSize: number(shown.size),
      fontWeight: _weight(number(shown.weight)),
      fontStyle: shown.italic ? FontStyle.italic : null,
      color: shown.color,
    );
    // Enough decimals of MHz to tell one label from the next, unless the scene fixed them.
    final decimals = shown.decimals ?? (6 - (math.log(labelStep) / math.ln10).floor()).clamp(0, 6);
    // A label that would touch the last one drawn is skipped: in a narrow
    // pane that leaves every other one, rather than a run of digits.
    var lastRight = double.negativeInfinity;
    for (final (x, hz) in _stops(current, labelStep, size.width)) {
      final painter = texts.get((hz / 1e6).toStringAsFixed(decimals), style);
      // Its length along the frequency axis, and across it.
      final (along, across) = turned ? (painter.height, painter.width) : (painter.width, painter.height);
      final left = x - along / 2;
      if (left < 0 || left + along > size.width || left < lastRight + painter.height / 2) continue;
      lastRight = left + along;
      final top = base + (number(shown.offset) ?? (gap - across) / 2);
      painter.paint(canvas, _toScreen(toScreen, Rect.fromLTWH(left, top, along, across)).topLeft);
    }
  }

  // Rebuilt only when the tree is: a scene value, a theme, the layout.
  @override
  bool shouldRepaint(_ScalePainter old) => true;
}

/// Laid-out text, kept across paints: the labels and annotations are the
/// same few strings at the same few styles, redrawn up to sixty times a
/// second. Emptied when it grows past what one display could show, which
/// is what a retune that changes every label does.
class _TextCache {
  static const _limit = 256;
  final _painters = <(String, TextStyle), TextPainter>{};

  TextPainter get(String text, TextStyle style) {
    final key = (text, style);
    if (_painters[key] case final cached?) return cached;
    if (_painters.length >= _limit) dispose();
    return _painters[key] = TextPainter(
      text: TextSpan(text: text, style: style),
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

typedef _AnnotationHit = ({Rect rect, SceneSpectrumAnnotation annotation, double hz});

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

FontWeight? _weight(double? w) => w == null ? null : FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

class _AnnotationPainter extends CustomPainter {
  final SceneSpectrumFlow flow;
  final SpectrumFrame? Function() frame;
  final _TextCache texts;
  final _Marks marks;

  /// Null where the part is not shown: its annotations are not drawn.
  final double? panBottom, waterfallTop;

  /// Rewritten on every paint, for the view's clicks and cursor.
  final List<_AnnotationHit> hits;
  final TextStyle text;
  final Color background;

  _AnnotationPainter({
    required Listenable repaint,
    required this.flow,
    required this.texts,
    required this.frame,
    required this.marks,
    required this.panBottom,
    required this.waterfallTop,
    required this.hits,
    required this.text,
    required this.background,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) {
    hits.clear();
    // Laid out in the spectrum's frame, as the scale's labels are; the box
    // and its point are mapped onto the screen, the text set upright in it.
    final size = _canonical(flow, screen);
    final toScreen = _flowMatrix(flow, screen);
    final turned = _turned(flow);
    final current = frame();
    if (current == null || current.highHz <= current.lowHz) return;
    final span = (current.highHz - current.lowHz).toDouble();
    final number = marks.number;
    for (final a in marks.spec.annotations) {
      final edge = a.onWaterfall ? waterfallTop : panBottom;
      final anchor = switch (a.anchor) {
        SceneSpectrumAnchor.vfo => marks.vfoHz,
        SceneSpectrumAnchor.center => (current.lowHz + current.highHz) / 2,
        SceneSpectrumAnchor.absolute => 0.0,
      };
      final at = number(a.hz);
      if (edge == null || anchor == null || at == null) continue;
      final hz = anchor + at;
      final x = (hz - current.lowHz) / span * size.width;
      final painter = texts.get(
        a.text,
        text.copyWith(
          fontFamily: a.fontFamily,
          fontSize: number(a.size),
          fontWeight: _weight(number(a.weight)),
          fontStyle: a.italic ? FontStyle.italic : null,
          color: a.color,
        ),
      );
      final pad = number(a.padding) ?? 2;
      final (textAlong, textAcross) = turned ? (painter.height, painter.width) : (painter.width, painter.height);
      final width = textAlong + pad * 2, height = textAcross + pad * 2;
      final left = switch (a.align) {
        'start' => x,
        'end' => x - width,
        _ => x - width / 2,
      };
      if (left + width < 0 || left > size.width) continue;
      final pointer = a.pointer;
      final point = pointer == null ? 0.0 : (number(pointer.size) ?? 4);
      final up = (pointer?.corner ?? (a.onWaterfall ? 'top' : 'bottom')) == 'top';
      // The offset places the tip, so a box with a point stands that much
      // further from the edge than one without.
      final offset = number(a.offset) ?? 4;
      final top = a.onWaterfall ? edge + offset + (up ? point : 0) : edge - offset - height - (up ? 0 : point);
      final rect = Rect.fromLTWH(left, top, width, height);
      final shape = _bubble(rect, number(a.radius) ?? 2, x: x, align: a.align, point: point, up: up).transform(toScreen.storage);
      canvas.drawPath(shape, Paint()..color = a.background ?? background);
      final border = number(a.borderWidth) ?? (a.borderColor == null ? 0 : 1);
      if (a.borderColor != null && border > 0) {
        canvas.drawPath(
          shape,
          Paint()
            ..color = a.borderColor!
            ..style = PaintingStyle.stroke
            ..strokeWidth = border,
        );
      }
      painter.paint(canvas, _toScreen(toScreen, rect).topLeft + Offset(pad, pad));
      hits.add((rect: shape.getBounds(), annotation: a, hz: hz));
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}

/// 256 RGBA colors, packed for a little-endian `rgba8888` row.
List<int> _paletteFor(SceneSpectrumSpec spec) {
  final stops =
      spec.waterfallColors ??
      switch (spec.palette) {
        'gray' => const [Color(0xFF000000), Color(0xFFFFFFFF)],
        'heat' => const [Color(0xFF000000), Color(0xFF7F0000), Color(0xFFFF4000), Color(0xFFFFFF00), Color(0xFFFFFFFF)],
        _ => const [Color(0xFF000010), Color(0xFF0000A0), Color(0xFF00C0FF), Color(0xFFFFFF00), Color(0xFFFF0000)],
      };
  return [
    for (var i = 0; i < 256; i++)
      () {
        final t = i / 255 * (stops.length - 1);
        final index = t.floor().clamp(0, stops.length - 2);
        final c = Color.lerp(stops[index], stops[index + 1], t - index)!;
        int byte(double v) => (v * 255).round() & 0xFF;
        return byte(c.a) << 24 | byte(c.b) << 16 | byte(c.g) << 8 | byte(c.r);
      }(),
  ];
}
