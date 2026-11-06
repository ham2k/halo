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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_svg/flutter_svg.dart' show PictureInfo, SvgStringLoader, vg;
import 'package:halo_core/halo_core.dart' show BandInfo, bands, frequencyMark, nowMillis, realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/cat/spectrum.dart';
import 'scene_gestures.dart';
import 'scene_model.dart';

part 'scene_spectrum_archery.dart';
part 'scene_spectrum_follow.dart';
part 'scene_spectrum_gestures.dart';
part 'scene_spectrum_layers.dart';
part 'scene_spectrum_levels.dart';
part 'scene_spectrum_text.dart';
part 'scene_spectrum_trace.dart';

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

  /// [uuid]'s live numeric readings, by the `radio.` value's name less the
  /// prefix: its meters (without any it has not fresh), its dial and its
  /// transmit state — see [sceneRadioValues] for which are kept while it is
  /// not connected.
  Map<String, num> readings(String uuid);

  /// [uuid]'s live readings that are words, named as [readings]' are; see
  /// [sceneRadioStrings].
  Map<String, String> readingStrings(String uuid);

  /// Fires when [readings] or [readingStrings] may have changed — at meter
  /// rate, so only what draws them listens.
  Listenable get readingChanges;

  /// Every radio's dial — frequency, mode, passband, transmitting, PTT,
  /// connection and its set's operating style, never a meter — as a list
  /// equal to an earlier answer exactly when none of them moved: what a
  /// panel's `radio` trigger fires on. Read on [readingChanges].
  List<Object?> dialState();

  /// Moves [uuid]'s scope to centre on [centerHz], for a control that
  /// `follow`s the VFO. False where the radio's window is not the app's to
  /// move, or the panel may not command the radio.
  bool recenter(String uuid, int centerHz);

  /// [owner] shows [widthHz] of [uuid]'s sweeps — its `span`, or the
  /// operator's zoom; 0 where it names neither and draws the whole sweep —
  /// or null once it shows none: where the span is the app's to choose, the
  /// scope is run wide enough for the widest.
  void showWidth(String uuid, Object owner, int? widthHz);

  /// Whether a spectrum's gestures are the host's where its scene names
  /// none: for a bundle declaring extension API 17 or later. Before it a
  /// click only sent the control's event, on which the extension tuned — the
  /// host tuning as well would tune twice.
  bool get nativeGestures;

  /// The widest window, in Hz, [uuid]'s scope can be made to show here:
  /// past the sweep it sends now where the app sizes the scope, or the panel
  /// may command it. Null: no wider than the sweep.
  int? maxWidthHz(String uuid);

  /// Whether [tune] can reach the radio [uuid]'s sweeps are of: the panel
  /// may command it, and the radio is there to be told.
  bool canTune(String uuid);

  /// Tunes the radio [uuid]'s sweeps are of to [hz]; [dial] for the wheel,
  /// which Smart VFO Snap settles as it does a turned knob. False when the
  /// panel may not command the radio: the click is then the control's event.
  /// [refused] runs if the radio answers no — transmitting, gone, or the
  /// request too long queued — so the dial drawn where the operator put it
  /// goes back at once rather than claiming a frequency the radio never took.
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused});

  /// Sets a scope whose widths are the radio's own to the narrowest that
  /// shows [widthHz] and every other display drawing it: wider for a zoom
  /// past the sweep, narrower where a zoom in ends. False where the app sizes
  /// the scope itself, or the panel may not command the radio.
  bool fitSpan(String uuid, int widthHz);
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

/// The axis a spectrum gets when its scene names no `scale`: labels in the
/// default gap, ticks from the panadapter's base.
final _defaultScale = SceneSpectrumScale(const {'ticks': true});

class SceneSpectrumView extends StatefulWidget {
  final SceneControl control;
  final SceneSpectrumSource? source;

  /// Off while the pane or the app is hidden: the radio's scope stops with
  /// the last display that is actually seen.
  final bool awake;

  /// The scene's values, for the spec's numbers that name one.
  final Map<String, double> values;
  final void Function(double hz, double db)? onHover;

  /// One of the spec's `widthHz`, `stepHz` or `vfoHz`, named by its scene
  /// value, whenever what it reads changes.
  final void Function(String name, double hz)? onReadout;

  /// A click, or a turn of the wheel, as the control's event: at the
  /// frequency to tune to, already rounded to the step.
  final void Function(double hz)? onTune;

  /// A zoom (the width in Hz) or a pan (the middle in Hz) the scene asked to
  /// hear rather than have the host make: `change` while it moves, `commit`
  /// when it ends.
  final void Function(String gesture, String phase, double value)? onGesture;

  /// Shown but inert: hover reads, nothing else does.
  final bool disabled;

  /// The axis a scrolling scene scrolls this control along; a trackpad swipe
  /// that way is the scroll's, not a pan or a tune. Null where it does not.
  final Axis? scrollAxis;

  /// A click on an annotation with an event or a menu: the [action] (the
  /// event, or the menu's item picked), the frequency it marks, and where
  /// the click landed (`at` in docs/extensions/scenes.md).
  final void Function(SceneSpectrumAnnotation annotation, String action, double hz, Map<String, Object> at)? onAnnotation;

  /// A click on a layer with an event or a menu, at the frequency clicked.
  final void Function(SceneSpectrumLayer layer, String action, double? hz, Map<String, Object> at)? onLayer;

  const SceneSpectrumView({
    super.key,
    required this.control,
    required this.source,
    required this.awake,
    this.values = const {},
    this.onHover,
    this.onReadout,
    this.onTune,
    this.onGesture,
    this.onAnnotation,
    this.onLayer,
    this.disabled = false,
    this.scrollAxis,
  });

  @override
  State<SceneSpectrumView> createState() => _SceneSpectrumViewState();
}

class _SceneSpectrumViewState extends State<SceneSpectrumView> with TickerProviderStateMixin {
  StreamSubscription<SpectrumFrame>? _subscription;
  String? _uuid;
  ({SceneSpectrumSource? source, String? uuid})? _historyIdentity;
  int _subscriptionEpoch = 0;
  int _rowEpoch = 0;

  /// The width last told to a source, and which source and node it was told
  /// for: see [SceneSpectrumSource.showWidth].
  (SceneSpectrumSource, String, int)? _shown;

  /// The last sweep in full, its levels averaged.
  SpectrumFrame? _sweep;

  /// The window shown — the scene's `span`, or the operator's zoom and pan —
  /// which the trace, labels, marks and clicks all work on. Its range only:
  /// its levels are empty, and the trace draws [_sweep]'s bins where their
  /// frequencies fall in it.
  SpectrumFrame? _frame;

  /// The operator's window: its width and its middle, in Hz. Null: the
  /// scene's `span`, and the sweep's middle.
  double? _viewWidth, _viewCenter;

  /// The `span` the operator zoomed over: a scene that changes it takes its
  /// width back.
  double? _zoomedOverSpan;

  /// The panadapter's share as the operator dragged it, over the scene's
  /// `split` then: a scene that changes its split takes it back.
  double? _split, _splitOver;

  /// The height the panadapter and waterfall share, as last laid out.
  double _shared = 0;

  void _resplit(double share) => setState(() {
    _split = share;
    _splitOver = _spec.split;
  });

  /// Where the dial was when the operator last panned: `follow` leaves the
  /// window there until the dial moves.
  double? _pannedAtVfo;

  /// Whether the radio moved its scope when last asked; null until asked.
  bool? _recenters;
  int _lastFitMillis = 0;

  /// The sweep's width before this control's zoom first narrowed the radio's
  /// scope: what a reset widens it back to.
  double? _sweepBeforeNarrowing;

  /// The box last laid out, and the spectrum's own frame for it: what the
  /// gestures map the pointer through. [_axis], in that frame, is the strip
  /// a drag zooms on; null with no axis drawn.
  Size _screen = Size.zero, _laidOut = Size.zero;
  Rect? _axis;

  /// The pointer is over something dragged sideways: the axis, or the tuned frequency's line.
  bool _overHandle = false;

  /// The gesture under way, as [scene_spectrum_gestures.dart] reads it.
  /// Held here, not in the recognizers' handlers, which every build replaces.
  _Grip? _grip, _pinch, _trackpad;

  /// A drag of the tuned frequency's line.
  _Dial? _dial;

  /// The panadapter's floor offset and range and the waterfall's speed, as
  /// the operator dragged them on the level strip.
  _Held? _floorHeld, _rangeHeld, _speedHeld;
  _LevelGrip? _levelGrip;

  /// Sweeps a second as they arrive, averaged, and the same held still until
  /// it moves by more than a sixth: the waterfall's time scale where no speed
  /// is set.
  double? _sweepRate, _steadySweepRate;

  /// Where the panadapter and the waterfall lie on the screen, as last laid
  /// out, for the level strip beside them.
  Rect? _panBand, _fallBand;

  /// A click on the axis waiting to see whether a second makes it a reset,
  /// and an edge click's glide waiting for the clicks to rest.
  Timer? _axisClick, _edgeGlide;

  /// The window's middle gliding from and to, after a click near an edge
  /// or a move to follow the dial.
  (double, double)? _glideSpan;

  /// Where a glide moved the radio's scope, the window held there until the
  /// sweeps arrive from it, then the sweeps' again.
  double? _releaseAt;
  late final AnimationController _glide;
  Curve _glideCurve = Curves.easeOutCubic;

  /// Where the operator put the dial — a click, the wheel, a drag of the
  /// line — shown ahead of the radio's report of it: while the line is
  /// dragged, and until the radio reports it there or
  /// [_heldMillis] is [_dialHold] old — a radio that settled elsewhere wins.
  double? _heldVfo;

  /// When the panel last tuned, which a click reads to tell adjusting from jumping.
  int _heldMillis = 0;

  /// The tuned frequency as drawn.
  double? get _vfo {
    final uuid = _uuid, reported = uuid == null ? null : widget.source?.vfoHz(uuid);
    final held = _heldVfo;
    if (held != null && (_dial != null || (reported != held && realNowMillis() - _heldMillis < _dialHold))) return held;
    return reported;
  }

  /// A drag across the axis: the panadapter's share, and where the pointer
  /// was across the frequency, when it took hold.
  (double, double)? _splitGrip;

  /// What a trackpad's gesture became once it moved far enough to tell: a
  /// pinch zooming, a swipe scrolling one way, or nothing. Null until then.
  ({bool zoom, SceneSpectrumScroll? does, bool sideways})? _trackpadMode;
  double _pinchFrom = 0;
  final _touches = <int, double>{};
  (String, double)? _heard;

  /// The native gestures since the last settled, for [_report].
  final _toReport = <String>{};
  Timer? _settleTimer, _tuneTimer;
  double? _tunePending, _wheelHz;
  double _wheelTravel = 0;
  int _wheelMillis = 0;

  /// One check a second while subscribed, against the last sweep's arrival
  /// — not a timer per sweep, which would be thirty made and cancelled a
  /// second.
  Timer? _staleTimer;
  int _lastFrameMillis = 0;
  final _texts = SpectrumTextCache();
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

  /// The dial follow last saw, when it last moved, and whether that move
  /// was a step of a spin rather than a jump.
  double? _followedVfo;
  int _vfoMovedMillis = 0;
  bool _spinning = false;

  /// Chases a spinning dial, a frame at a time; [_chasedAt] is the last
  /// frame's time, and [_chaseFree] whether the window was the radio's
  /// sweep when the chase began.
  late final Ticker _chaser = createTicker(_onChase);
  Duration? _chasedAt;
  bool _chaseFree = false;

  /// How many digits past the kHz the dial's label shows: as many as the
  /// dial has, or more while it moves, so a turn through 14.0745 to 14.075
  /// reads 14.0750 rather than jumping a digit shorter and back on each
  /// step; once it stands [_labelSettleMs], as many as it has. Its duration
  /// is for all three digits: a move of one takes a third of it.
  late final AnimationController _labelDigits = AnimationController(
    vsync: this,
    upperBound: 3,
    duration: const Duration(milliseconds: 3 * _labelDigitMs),
  )..addListener(() => _panRepaint.value++);
  Timer? _labelSettle;
  double? _labelledVfo;
  double _labelTarget = 0;

  /// Pans the window under a line dragged near its edge; [_dialPannedAt] is the last frame's time.
  late final Ticker _dialPanner = createTicker(_onDialPan);
  Duration? _dialPannedAt;

  /// How fast that pan last moved the dial, in Hz a millisecond: the step it lands on when it stops.
  double _dialPanSpeed = 0;

  /// The line drawn as a bow's string, and its swing and flight a frame at a time.
  _Bow? _bow;
  late final Ticker _archer = createTicker(_onBow);

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

  /// Where the clickable layers were last drawn, topmost last: those over
  /// the picture, and those behind it, which a click reaches after them.
  final _layerHits = <_LayerHit>[], _behindLayerHits = <_LayerHit>[];

  SceneSpectrumLayer? _layerAt(Offset at) {
    if (widget.onLayer == null) return null;
    for (final hit in [..._layerHits.reversed, ..._behindLayerHits.reversed]) {
      if (hit.contains(at)) return hit.layer;
    }
    return null;
  }

  /// The layers' artwork by its source, drawn once loaded.
  final _pictures = <String, PictureInfo>{};
  final _loading = <String>{};

  void _loadArt(String svg) {
    if (!_loading.add(svg)) return;
    vg.loadPicture(SvgStringLoader(svg), null).then(
      (art) {
        if (!mounted || !_spec.layers.any((l) => l.svg == svg)) return art.picture.dispose();
        _pictures[svg] = art;
        _panRepaint.value++;
      },
      // Left undrawn: the scene's artwork passed the same checks every scene's does, so this is a
      // picture that will not render, which a retry would not change.
      onError: (Object e) => debugPrint('[panel scene] spectrum layer artwork failed: $e'),
    );
  }

  SceneSpectrumSpec get _spec => widget.control.spectrum!;

  double? _number(SceneNumber? n) => n?.resolve(widget.values);

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..addListener(_onGlide);
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
    // A dial held for one radio is not another's.
    if (old.source != widget.source || was.radio != _spec.radio) _heldVfo = null;
    if (was.palette != _spec.palette || !listEquals(was.waterfallColors, _spec.waterfallColors)) {
      _palette = _paletteFor(_spec);
      _clearRows();
    }
    // Artwork a scene no longer draws is let go: a scene that changes its layers' svg as it updates
    // would otherwise keep every picture it ever drew.
    final drawn = {for (final layer in _spec.layers) ?layer.svg};
    _loading.removeWhere((svg) => !drawn.contains(svg));
    _pictures.removeWhere((svg, art) {
      if (drawn.contains(svg)) return false;
      art.picture.dispose();
      return true;
    });
    _follow();
  }

  void _onSourceChanged() {
    // A scope that would not move may now: a radio reconnected, its capabilities reported.
    if (_recenters == false) _recenters = null;
    _follow();
    if (!mounted) return;
    _labelDial();
    _keepInView(realNowMillis());
    _tellReadouts();
    setState(() {});
  }

  /// Subscribes to the radio this control names, while it is seen.
  void _follow() {
    _subscribe();
    _showWidth();
  }

  /// Tells the source the width this control crops its sweeps to while it
  /// draws them, 0 for the whole sweep.
  void _showWidth() {
    final (source, uuid, width) = (widget.source, _uuid, (_viewWidth ?? _number(_spec.span))?.round());
    final now = source == null || uuid == null ? null : (source, uuid, width == null || width <= 0 ? 0 : width);
    if (now == _shown) return;
    if (_shown case (final source, final uuid, _)) source.showWidth(uuid, this, null);
    _shown = now;
    if (now case (final source, final uuid, final width)) source.showWidth(uuid, this, width);
  }

  void _subscribe() {
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

  /// The window shown over [sweep]. Held inside it, except where the radio
  /// moves its scope: there the window runs ahead of the sweeps, its unswept
  /// part blank until they catch up, so a pan or zoom keeps the pointer's
  /// pace rather than waiting on the radio's.
  SpectrumFrame _window(SpectrumFrame sweep) {
    final span = _number(_spec.span);
    if (_viewWidth != null && span != _zoomedOverSpan) _viewWidth = null;
    final (low, high) = spectrumWindow(sweep, _viewWidth ?? span, centerHz: _viewCenter, held: _recenters != true);
    return SpectrumFrame(
      lowHz: low.round(),
      highHz: high.round(),
      levels: Float32List(0),
      floorDb: sweep.floorDb,
      ceilingDb: sweep.ceilingDb,
      noiseDb: sweep.noiseDb,
      atMillis: sweep.atMillis,
    );
  }

  /// Redraws the window shown now, between sweeps: a gesture moves it at the pointer's pace.
  void _reframe() {
    if (_sweep case final sweep?) _frame = _window(sweep);
    _tellReadouts();
    _panRepaint.value++;
    _waterfallRepaint.value++;
  }

  /// What [SceneSpectrumView.onReadout] was last told, by scene value.
  final _told = <String, double>{};

  void _tellReadouts() {
    final tell = widget.onReadout;
    if (tell == null) return;
    void say(String? name, double? hz) {
      if (name == null || hz == null || _told[name] == hz) return;
      _told[name] = hz;
      tell(name, hz);
    }

    final frame = _frame;
    if (frame != null && frame.highHz > frame.lowHz) say(_spec.widthHz, (frame.highHz - frame.lowHz).toDouble());
    say(_spec.stepHz, _fineStep());
    say(_spec.vfoHz, _vfo);
  }

  void _onFrame(SpectrumFrame sweep) {
    if (!mounted) return;
    final wasStale = _stale;
    _sweep = _averaged(sweep);
    if (_releaseAt case final at?
        when _glideSpan == null && !_chaser.isActive && ((sweep.lowHz + sweep.highHz) / 2 - at).abs() <= (sweep.highHz - sweep.lowHz) / 100) {
      _releaseAt = null;
      _viewCenter = null;
    }
    // The trace, follow and labels work on the window shown; the waterfall keeps whole sweeps,
    // each row drawn where its frequencies sit in the window, so a zoom or a pan keeps the history.
    _frame = _window(_sweep!);
    _tellReadouts();
    _stale = false;
    // The real clock: a frame rate is about the screen in front of the
    // operator, and must not travel with the app clock.
    final now = realNowMillis();
    if (_lastFrameMillis > 0 && now > _lastFrameMillis) {
      final rate = 1000 / (now - _lastFrameMillis), was = _sweepRate;
      final average = _sweepRate = was == null ? rate : was * .8 + rate * .2;
      final steady = _steadySweepRate;
      if (steady == null || (average - steady).abs() > steady / 6) _steadySweepRate = average;
    }
    _lastFrameMillis = now;
    _labelDial();
    _keepInView(now);
    if (_spec.waterfall) _feedWaterfall(sweep, now);
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
    final previous = _sweep;
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
      noiseDb: frame.noiseDb,
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
    final speed = _speedNow;
    if (speed != null && now - _lastRowMillis < 1000 / speed) return;
    _lastRowMillis = now;
    _rowPeak = null;
    _addRow(peak, frame);
  }

  /// The waterfall's time scale: the age labels' and what a layer's seconds measure.
  double? _secondsPerPixel() {
    final rows = _rowsPerSecond, fall = _fallBand;
    if (rows == null || rows <= 0 || fall == null) return null;
    return 1 / (rows * math.max(1.0, fall.height / _waterfallRows));
  }

  (double, double) _panScale(SpectrumFrame frame) {
    final floor = frame.floorDb + (_floorNow ?? 0);
    return (floor, _rangeNow ?? frame.ceilingDb - frame.floorDb);
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
    // When it was taken, which places it down the waterfall: a change of speed re-spaces the history at once.
    final (lowHz, highHz, at) = (frame.lowHz, frame.highHz, realNowMillis());
    final epoch = _rowEpoch;
    ui.decodeImageFromPixels(pixels.buffer.asUint8List(), levels.length, 1, ui.PixelFormat.rgba8888, (image) {
      if (!mounted || epoch != _rowEpoch) {
        image.dispose();
        return;
      }
      _rows.insert(0, (image: image, lowHz: lowHz, highHz: highHz, atMillis: at));
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
    _sweep = null;
    _frame = null;
    _viewWidth = null;
    _viewCenter = null;
    _pannedAtVfo = null;
    _recenters = null;
    _sweepBeforeNarrowing = null;
    // Another radio's: a dial held, a wheel's run, a tune or a glide on its way would land on this one.
    _heldVfo = _wheelHz = _tunePending = _releaseAt = _followedVfo = _labelledVfo = null;
    _tuneTimer?.cancel();
    _stopGlide();
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
    if (_shown case (final source, final uuid, _)) source.showWidth(uuid, this, null);
    _staleTimer?.cancel();
    _settleTimer?.cancel();
    _tuneTimer?.cancel();
    _glide.dispose();
    _chaser.dispose();
    _labelDigits.dispose();
    _labelSettle?.cancel();
    _dialPanner.dispose();
    _archer.dispose();
    _axisClick?.cancel();
    _edgeGlide?.cancel();
    _texts.dispose();
    for (final art in _pictures.values) {
      art.picture.dispose();
    }
    _clearRows();
    _panRepaint.dispose();
    _waterfallRepaint.dispose();
    super.dispose();
  }

  /// How far along the sweep [at] is, 0 to 1, whichever way it flows.
  double? _fractionAt(Offset at, Size size) {
    final way = (flow: _spec.flow, reversed: _spec.reversed);
    final width = _canonical(way, size).width;
    if (width <= 0) return null;
    return (_toCanonical(way, size, at).dx / width).clamp(0.0, 1.0);
  }

  double? _hzAt(Offset at, Size size) {
    final frame = _frame, fraction = _fractionAt(at, size);
    if (frame == null || fraction == null) return null;
    return frame.lowHz + fraction * (frame.highHz - frame.lowHz);
  }

  void _hover(Offset at, Size size) {
    final clickable = ((_annotationAt(at)?.annotation?.clickable ?? false) && widget.onAnnotation != null) || _layerAt(at) != null;
    // The axis and the tuned frequency's line are dragged sideways.
    final handle = (_onAxis(at) && _gestures.zoom != SceneSpectrumGesture.off) || _dialAt(at) != null;
    if (clickable != _overClickable || handle != _overHandle) {
      setState(() {
        _overClickable = clickable;
        _overHandle = handle;
      });
    }
    final sweep = _sweep, hz = _hzAt(at, size);
    if (sweep == null || hz == null || widget.onHover == null || sweep.levels.length < 2 || sweep.highHz <= sweep.lowHz) return;
    final n = sweep.levels.length;
    final bin = ((hz - sweep.lowHz) / (sweep.highHz - sweep.lowHz) * (n - 1)).round().clamp(0, n - 1);
    widget.onHover!(hz, sweep.levels[bin].toDouble());
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
    final look = spec.trace, trace = look.color ?? scheme.primary;
    final _Style style = (
      look: (
        trace: trace,
        traceColors: look.colors,
        width: _number(look.width) ?? 1,
        dashed: look.dashed ?? false,
        fill: look.fill ?? trace.withValues(alpha: .25),
        fillBottom: look.fillBottom,
        fillColors: look.fillColors,
      ),
      smooth: _number(look.smooth) ?? 0,
      grid: spec.gridColor ?? scheme.outlineVariant.withValues(alpha: .5),
      gridDashed: spec.gridDashed,
      waterfallGrid: spec.waterfallGridColor,
      marker: scheme.error.withValues(alpha: .7),
    );
    final marks = (spec: spec, number: _number, vfoHz: _drawnDial, strung: () => _bow != null);
    // A scene that names no scale gets the host's axis, from API 17; `false` is none.
    final scale = spec.scale ?? (spec.noScale || !(source?.nativeGestures ?? true) ? null : _defaultScale);
    return Semantics(
      label: widget.control.label,
      child: LayoutBuilder(
        builder: (context, box) {
          final _Way way = (flow: spec.flow, reversed: spec.reversed);
          // The level strip takes its width from beside the spectrum, which lays out in the rest.
          final levels = _levelScaleFor(way), turned = _turned(way);
          // Sideways it lies along the top or bottom, as deep as a label is tall.
          final strip = levels == null ? 0.0 : (_number(levels.width) ?? (turned ? 24 : 40)).clamp(0.0, (turned ? box.maxHeight : box.maxWidth) / 3);
          final beside = levels?.over ?? true ? 0.0 : strip;
          final size = turned ? Size(box.maxWidth, box.maxHeight - beside) : Size(box.maxWidth - beside, box.maxHeight);
          _screen = size;
          _laidOut = _canonical(way, size);
          final spectrum = MouseRegion(
            cursor: _overClickable
                ? SystemMouseCursors.click
                : _overHandle
                ? (_turned(way) ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.resizeLeftRight)
                : MouseCursor.defer,
            onHover: (e) => _hover(e.localPosition, size),
            // Outside the gesture arena: a pinch and the wheel take nothing a scrolling scene's own drag needs.
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: _signal,
              onPointerPanZoomStart: _trackpadStart,
              onPointerPanZoomUpdate: _trackpadUpdate,
              onPointerPanZoomEnd: _trackpadEnd,
              onPointerDown: _touchDown,
              onPointerMove: _touchMove,
              onPointerUp: _touchUp,
              onPointerCancel: _touchUp,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: _recognizers(axis: scale != null),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: spec.backgroundColor ?? scheme.surfaceContainerLowest),
                    ...() {
                      // Laid out as if flowing down, then mapped onto the box.
                      final frame = _canonical(way, size);
                      final toScreen = _flowMatrix(way, size);
                      final gap = scale == null ? 0.0 : (_number(scale.gap) ?? _defaultGap).clamp(0.0, frame.height);
                      // Over the picture, the axis takes no height of its own: it lies across the
                      // waterfall's head, or the panadapter's foot — whichever the scene says, and
                      // is there.
                      final over = scale?.over != null;
                      final rest = frame.height - (over ? 0 : gap);
                      _shared = rest;
                      final panHeight = !spec.pan ? 0.0 : (spec.waterfall ? rest * _panShare : rest);
                      final fallTop = over ? panHeight : panHeight + gap;
                      final onPan = spec.pan && (scale?.over == 'spectrum' || !spec.waterfall);
                      final axisTop = over && onPan ? panHeight - gap : panHeight;
                      // What labels and ticks measure from: the axis's top over the picture; else under
                      // the panadapter, or atop the waterfall.
                      final base = over ? axisTop : (spec.pan ? panHeight : gap);
                      // The strip a drag zooms on: the axis, or a finger's width about the labels' base.
                      _axis = scale == null
                          ? null
                          : gap >= 12
                          ? Rect.fromLTWH(0, axisTop, frame.width, gap)
                          : Rect.fromLTRB(0, base - 12, frame.width, base + gap + 12);
                      Rect place(double top, double height) => _toScreen(toScreen, Rect.fromLTWH(0, top, frame.width, height));
                      _panBand = spec.pan ? place(0, panHeight) : null;
                      _fallBand = spec.waterfall ? place(fallTop, frame.height - fallTop) : null;
                      // The gap's own top and bottom, wherever the flow turns them.
                      final (nearSide, farSide) = (_side(scale?.borderTop), _side(scale?.borderBottom));
                      final border = switch (way.flow) {
                        SceneSpectrumFlow.down => Border(top: nearSide, bottom: farSide),
                        SceneSpectrumFlow.up => Border(bottom: nearSide, top: farSide),
                        SceneSpectrumFlow.right => Border(left: nearSide, right: farSide),
                        SceneSpectrumFlow.left => Border(right: nearSide, left: farSide),
                      };
                      final labelStyle = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
                      // The dial's label takes the line's own color, where the panadapter draws the line; from API 17.
                      final vfoLabel = !spec.pan || spec.noVfoLabel || !(source?.nativeGestures ?? true) || (spec.center != null && spec.center!.pan == null)
                          ? null
                          : spec.center?.pan?.color ?? style.marker;
                      final _Parts parts = (
                        spectrum: spec.pan ? (top: 0.0, bottom: panHeight) : null,
                        axis: scale != null && gap > 0 ? (top: axisTop, bottom: axisTop + gap) : null,
                        waterfall: spec.waterfall ? (top: fallTop, bottom: frame.height) : null,
                      );
                      // Behind: over the background, under the spectrum's grid, areas and trace.
                      Widget layers({required bool behind}) => Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _LayerPainter(
                              repaint: _panRepaint,
                              way: way,
                              frame: () => _frame,
                              layers: [
                                for (final layer in spec.layers)
                                  if (layer.behind == behind) layer,
                              ],
                              values: widget.values,
                              vfoHz: _drawnDial,
                              parts: parts,
                              levels: _panScale,
                              secondsPerPixel: _secondsPerPixel,
                              texts: _texts,
                              text: labelStyle,
                              ink: scheme.onSurface,
                              pictures: _pictures,
                              load: _loadArt,
                              hits: behind ? _behindLayerHits : _layerHits,
                            ),
                          ),
                        ),
                      );
                      final (front, back) = (spec.layers.any((layer) => !layer.behind), spec.layers.any((layer) => layer.behind));
                      // A painter no longer drawn leaves its last hits: clicks there would reach layers that are gone.
                      if (!front) _layerHits.clear();
                      if (!back) _behindLayerHits.clear();
                      return [
                        if (back) layers(behind: true),
                        if (spec.pan)
                          Positioned.fromRect(
                            rect: place(0, panHeight),
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _PanPainter(
                                  repaint: _panRepaint,
                                  way: way,
                                  frame: () => _stale ? null : _frame,
                                  sweep: () => _sweep,
                                  scale: _panScale,
                                  marks: marks,
                                  style: style,
                                ),
                              ),
                            ),
                          ),
                        if (spec.waterfall)
                          Positioned.fromRect(
                            rect: place(fallTop, frame.height - fallTop),
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _WaterfallPainter(
                                  repaint: _waterfallRepaint,
                                  way: way,
                                  rows: _rows,
                                  rowsPerSecond: () => _rowsPerSecond,
                                  frame: () => _frame,
                                  marks: marks,
                                  style: style,
                                ),
                              ),
                            ),
                          ),
                        // After both parts, so over the picture it is drawn on top of them.
                        if (scale != null && gap > 0)
                          Positioned.fromRect(
                            rect: place(axisTop, gap),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: over ? _seeThrough(scale.background ?? spec.backgroundColor ?? scheme.surfaceContainerLowest) : scale.background,
                                border: border,
                              ),
                            ),
                          ),
                        if (_tunesNatively)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _BowPainter(
                                  repaint: _panRepaint,
                                  way: way,
                                  bow: () => _bow,
                                  frame: () => _frame,
                                  color: (spec.center?.pan ?? spec.center?.waterfall)?.color ?? style.marker,
                                  width: _number((spec.center?.pan ?? spec.center?.waterfall)?.width) ?? 1,
                                ),
                              ),
                            ),
                          ),
                        if (front) layers(behind: false),
                        if (spec.annotations.isNotEmpty || vfoLabel != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _AnnotationPainter(
                                  texts: _texts,
                                  repaint: _panRepaint,
                                  way: way,
                                  frame: () => _frame,
                                  marks: marks,
                                  panBottom: spec.pan ? panHeight : null,
                                  waterfallTop: spec.waterfall ? fallTop : null,
                                  parts: parts,
                                  levels: _panScale,
                                  secondsPerPixel: _secondsPerPixel,
                                  hits: _annotationHits,
                                  text: labelStyle.copyWith(color: scheme.onSurface),
                                  background: scheme.surface.withValues(alpha: .8),
                                  vfoLabel: vfoLabel,
                                  vfoDigits: () => spec.vfoLabel.hzDigits?.toDouble() ?? _labelDigits.value,
                                  vfoLabelHz: () => _labelHz,
                                  vfoLabelBackground: (spec.backgroundColor ?? scheme.surfaceContainerLowest).withValues(alpha: .7),
                                ),
                              ),
                            ),
                          ),
                        if (scale != null && (scale.labels != null || scale.ticks != null))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ScalePainter(
                                  styled: widget.source?.nativeGestures ?? true,
                                  texts: _texts,
                                  repaint: _panRepaint,
                                  way: way,
                                  frame: () => _frame,
                                  base: base,
                                  gap: gap,
                                  labels: scale.labels,
                                  ticks: scale.ticks,
                                  number: _number,
                                  text: labelStyle.copyWith(color: scheme.onSurfaceVariant),
                                  clear: levels == null || !levels.over ? null : _stripRect(size, strip, start: levels.start, turned: turned),
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
            ),
          );
          if (levels == null) return spectrum;
          final side = _levelStrip(levels, scale, way, strip, scheme, Theme.of(context).textTheme.labelSmall ?? const TextStyle());
          // Over the picture the strip is a sibling on top, so its drags and double clicks never
          // reach the spectrum's own clicks and pans beneath it.
          if (levels.over) {
            return Stack(
              fit: StackFit.expand,
              children: [
                spectrum,
                Positioned.fromRect(
                  rect: _stripRect(size, strip, start: levels.start, turned: turned),
                  child: side,
                ),
              ],
            );
          }
          return Flex(
            direction: turned ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: levels.start ? [side, Expanded(child: spectrum)] : [Expanded(child: spectrum), side],
          );
        },
      ),
    );
  }
}

/// Where a level strip [strip] deep lies over a spectrum of [size]: at its
/// left or right upright, its top or bottom sideways.
Rect _stripRect(Size size, double strip, {required bool start, required bool turned}) =>
    turned ? Rect.fromLTWH(0, start ? 0 : size.height - strip, size.width, strip) : Rect.fromLTWH(start ? 0 : size.width - strip, 0, strip, size.height);

/// An axis's background drawn over the picture: the trace shows through it.
Color _seeThrough(Color color) => color.withValues(alpha: color.a * .7);

/// Which way a spectrum lies: the waterfall's [flow], and whether
/// frequency runs against the way that flow gives it.
typedef _Way = ({SceneSpectrumFlow flow, bool reversed});

/// The spectrum's own frame — frequency rising along x, the panadapter, gap
/// and waterfall stacked down y — mapped onto a [screen] box for [way]. A
/// mirror for `up`; for `right` and `left`, frequency runs down the screen.
/// Reversed, frequency is mirrored first.
Matrix4 _flowMatrix(_Way way, Size screen) {
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
  final turn = switch (way.flow) {
    SceneSpectrumFlow.down => Matrix4.identity(),
    SceneSpectrumFlow.up => rows([1, 0, 0], [0, -1, h]),
    SceneSpectrumFlow.right => rows([0, 1, 0], [1, 0, 0]),
    SceneSpectrumFlow.left => rows([0, -1, w], [1, 0, 0]),
  };
  return way.reversed ? (turn..multiply(rows([-1, 0, _canonical(way, screen).width], [0, 1, 0]))) : turn;
}

bool _turned(_Way way) => way.flow == SceneSpectrumFlow.right || way.flow == SceneSpectrumFlow.left;

/// The spectrum's own frame for a [screen] box.
Size _canonical(_Way way, Size screen) => _turned(way) ? screen.flipped : screen;

Offset _toCanonical(_Way way, Size screen, Offset at) {
  final turned = switch (way.flow) {
    SceneSpectrumFlow.down => at,
    SceneSpectrumFlow.up => Offset(at.dx, screen.height - at.dy),
    SceneSpectrumFlow.right => Offset(at.dy, at.dx),
    SceneSpectrumFlow.left => Offset(at.dy, screen.width - at.dx),
  };
  return way.reversed ? Offset(_canonical(way, screen).width - turned.dx, turned.dy) : turned;
}

Rect _toScreen(Matrix4 m, Rect canonical) => MatrixUtils.transformRect(m, canonical);

/// Draws a part in its own frame: [paint] gets the canonical size.
void _inFlow(Canvas canvas, Size screen, _Way way, void Function(Size size) paint) {
  canvas.save();
  canvas.transform(_flowMatrix(way, screen).storage);
  paint(_canonical(way, screen));
  canvas.restore();
}

typedef _Style = ({_Look look, double smooth, Color grid, bool gridDashed, Color? waterfallGrid, Color marker});

/// What the tuned-frequency line and the overlays need: the spec, how to read
/// its numbers, and where the radio is tuned.
/// [vfoHz] is read at paint: a dragged line moves with the pointer, between builds.
/// While [strung], the line is a bow's string, which [_BowPainter] draws over every part.
typedef _Marks = ({SceneSpectrumSpec spec, double? Function(SceneNumber?) number, double? Function() vfoHz, bool Function() strung});

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
      SceneSpectrumAnchor.vfo => marks.vfoHz(),
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
  final vfo = marks.vfoHz();
  if (!front || vfo == null || marks.strung()) return;
  final center = marks.spec.center;
  final s = center == null ? null : styleOf(center);
  if (center != null && s == null) return;
  final vx = x(vfo);
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
  final _Way way;
  final SpectrumFrame? Function() frame;

  /// The bins, drawn where their frequencies fall in [frame]'s window.
  final SpectrumFrame? Function() sweep;
  final (double, double) Function(SpectrumFrame) scale;
  final _Marks marks;
  final _Style style;

  _PanPainter({
    required Listenable repaint,
    required this.way,
    required this.frame,
    required this.sweep,
    required this.scale,
    required this.marks,
    required this.style,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) => _inFlow(canvas, screen, way, (size) => _paint(canvas, size));

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
    final bins = sweep();
    if (bins != null && bins.levels.length >= 2 && current.highHz > current.lowHz) _paintTrace(canvas, size, bins, current, floor, range, style, marks);
    _paintMarks(canvas, size, current, marks, style, pan: true, front: true);
  }

  // Rebuilt only when the tree is: a tuning, a scene value, a theme.
  @override
  bool shouldRepaint(_PanPainter old) => true;
}

/// The range a display shows over [sweep]: [widthHz] about [centerHz], each
/// the sweep's own when null. [held] keeps it inside the sweep — no wider,
/// and moved back within its edges — for a scope the app cannot move;
/// otherwise it may run past them. Any width, any centre: not whole bins,
/// so a pan or zoom moves the picture by the pixel, not the bin.
@visibleForTesting
(double, double) spectrumWindow(SpectrumFrame sweep, double? widthHz, {double? centerHz, bool held = true}) {
  final span = (sweep.highHz - sweep.lowHz).toDouble();
  var width = widthHz ?? span, center = centerHz ?? sweep.lowHz + span / 2;
  if (held) {
    width = math.min(width, span);
    center = center.clamp(sweep.lowHz + width / 2, sweep.highHz - width / 2);
  }
  return (center - width / 2, center + width / 2);
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
typedef _Row = ({ui.Image image, int lowHz, int highHz, int atMillis});

/// Where a row taken at [atMillis] lies down a waterfall moving
/// [pixelsPerSecond], the newest taken at [newestMillis]: from its age to the
/// age of the row before it, [olderMillis], so irregular sweeps leave no
/// gaps; the oldest, with none before it, a [rowHeight] deep.
@visibleForTesting
(double, double) waterfallRowSpan(int newestMillis, int atMillis, int? olderMillis, double pixelsPerSecond, double rowHeight) {
  final top = (newestMillis - atMillis) / 1000 * pixelsPerSecond;
  final bottom = olderMillis == null ? top + rowHeight : (newestMillis - olderMillis) / 1000 * pixelsPerSecond;
  return (top, math.max(bottom, top + 1));
}

class _WaterfallPainter extends CustomPainter {
  final _Way way;
  final List<_Row> rows;

  /// Rows a second as they arrive now, which spaces them by when they were
  /// taken; null, one row deep each.
  final double? Function() rowsPerSecond;

  /// For the frequency lines and the marks, which follow the latest sweep.
  final SpectrumFrame? Function() frame;
  final _Marks marks;
  final _Style style;

  _WaterfallPainter({
    required Listenable repaint,
    required this.way,
    required this.rows,
    required this.rowsPerSecond,
    required this.frame,
    required this.marks,
    required this.style,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) => _inFlow(canvas, screen, way, (size) => _paint(canvas, size));

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
    final perSecond = rowsPerSecond();
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final (top, bottom) = perSecond == null || perSecond <= 0
          ? (i * rowHeight, (i + 1) * rowHeight)
          : waterfallRowSpan(rows.first.atMillis, row.atMillis, i + 1 < rows.length ? rows[i + 1].atMillis : null, perSecond * rowHeight, rowHeight);
      if (top >= size.height) break;
      final (left, right) = current == null ? (0.0, size.width) : waterfallRowExtent(row.lowHz, row.highHz, current.lowHz, current.highHz, size.width);
      if (right <= 0 || left >= size.width) continue;
      canvas.drawImageRect(row.image, Rect.fromLTWH(0, 0, row.image.width.toDouble(), 1), Rect.fromLTRB(left, top, right, bottom + .5), paint);
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
