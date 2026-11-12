// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a spectrum control does with the pointer: a click or the wheel tunes,
// a drag along the axis or a pinch zooms, a drag across the axis moves it,
// a drag over the panadapter or the waterfall pans — each the host's, the
// extension's, or nobody's, as the scene's `gestures` say
// (docs/design/panel-scenes.md § Spectrum). The level strip's drags are in
// scene_spectrum_levels.dart.

part of 'scene_spectrum.dart';

/// How far apart, in pixels, a zoom spreads the sweep's points at most —
/// further, the trace is a few straight strokes — and how far apart they
/// may be where a zoom ends before the radio's span is narrowed: closer,
/// the span is left alone, since each change jolts the radio's own screen
/// and restretches the waterfall.
const _zoomPixelsPerPoint = 10.0, _fitPixelsPerPoint = 5.0;

/// Where a drag, a pinch or a trackpad gesture took hold: whether it zooms,
/// where along the frequency axis (in the spectrum's own frame), and the
/// window then — its width and its middle — with the frequency under the
/// pointer and how far across the window it was, which a zoom keeps there.
typedef _Grip = ({bool zoom, double x, double width, double center, double anchorHz, double fraction});

/// A drag of the tuned frequency's line: how far from the line it took hold,
/// in pixels, which it keeps, and where the pointer is now.
typedef _Dial = ({double offset, double x});

/// The gestures as this control takes them: the scene's, or its bundle's API's default.
typedef _Gestures = ({
  SceneSpectrumGesture tune,
  SceneSpectrumGesture zoom,
  SceneSpectrumGesture pan,
  SceneSpectrumGesture split,
  SceneSpectrumGesture levels,
  bool wheel,
});

/// How far either side of the tuned frequency's line a drag takes hold of
/// it: a finger's width in all.
const _dialReach = 12.0;

/// How fast, in widths of the window a second, a line dragged into the
/// outer [_edgeShare] pans it: in proportion to how far in, this fast at the
/// edge and past it.
const _dialPanWidths = .6;

/// Within [_fineWindowMs] of the last tune, a click within [_fineReachHz]
/// of the dial is the operator adjusting, on the fine step, and one within
/// [_mediumReachHz] on the medium; any other is a jump to a signal, on the
/// coarse step, which still lands on it.
const _fineReachHz = 1000.0, _mediumReachHz = 3000.0, _fineWindowMs = 5000;

/// A click within this share of the window from either edge glides the
/// window just far enough to put the new frequency that far in, rather than
/// leaving it at the edge or taking it all the way to the middle.
const _edgeShare = .15;

/// The medium and coarse steps' ceiling, in Hz, where signals sit — unless
/// the fine step is already coarser.
const _coarseMaxHz = 1000.0;

/// Wheel notches at least [_slowNotchMs] apart are on the fine step, at
/// least [_fastNotchMs] on the medium, closer than that — a spin — on the coarse.
const _slowNotchMs = 120, _fastNotchMs = 40;

/// A glide's length: [_glideMsPerWidth] for a move of the window's whole
/// width, in proportion for less, between [_glideMinMs] and [_glideMaxMs].
const _glideMsPerWidth = 600, _glideMinMs = 150, _glideMaxMs = 350;

/// How long, in ms, the dial is drawn where the operator put it while the
/// source has yet to give it there: a tune waits its turn in the panels'
/// paced queue before the app's VFO has it, and the VFO holds it from there
/// against the radio's reports (docs/design/cat.md).
const _dialHold = 1500;

/// Scroll travel that makes one notch of the wheel: a mouse's notch is one
/// event past it, a trackpad's swipe many small ones that add up to it.
const _wheelNotch = 20.0;

extension _SpectrumGestures on _SceneSpectrumViewState {
  _Gestures get _gestures {
    const off = SceneSpectrumGesture.off;
    if (widget.disabled) return (tune: off, zoom: off, pan: off, split: off, levels: off, wheel: false);
    final g = _spec.gestures, native = widget.source?.nativeGestures ?? true;
    return (
      tune: g.tune ?? (native ? SceneSpectrumGesture.native : SceneSpectrumGesture.event),
      zoom: g.zoom ?? SceneSpectrumGesture.native,
      pan: g.pan ?? SceneSpectrumGesture.native,
      // Only where there are two parts to share the height.
      split: _spec.pan && _spec.waterfall ? g.split ?? SceneSpectrumGesture.native : off,
      levels: g.levels ?? SceneSpectrumGesture.native,
      // Before API 17 the wheel over a spectrum scrolled the scene; a scene naming its tune asked for it.
      wheel: native || g.tune != null,
    );
  }

  _Way get _way => (flow: _spec.flow, reversed: _spec.reversed);

  Offset _canonicalAt(Offset at) => _toCanonical(_way, _screen, at);

  bool _onAxis(Offset at) => _axis?.contains(_canonicalAt(at)) ?? false;

  /// The panadapter's share of the height: the operator's, while the scene's `split` is the one they dragged over.
  double get _panShare => _split != null && _splitOver == _spec.split ? _split! : _spec.split;

  /// Where a drag may begin: on the tuned frequency's line to tune, on the axis to zoom, anywhere else to pan.
  bool _dragsAt(Offset at) {
    final g = _gestures;
    if (_dialAt(at) != null) return true;
    return _onAxis(at) ? g.zoom != SceneSpectrumGesture.off : g.pan != SceneSpectrumGesture.off;
  }

  /// The tuned frequency's line, where [at] is close enough to drag it: off
  /// the axis, which zooms, and only where the wheel would tune.
  _Dial? _dialAt(Offset at) {
    final frame = _frame, uuid = _uuid, width = _laidOut.width;
    if (!_wheelTunes || _onAxis(at) || frame == null || uuid == null || width <= 0 || frame.highHz <= frame.lowHz) return null;
    final vfo = _vfo;
    if (vfo == null) return null;
    final x = _canonicalAt(at).dx, offset = x - (vfo - frame.lowHz) / (frame.highHz - frame.lowHz) * width;
    if (offset.abs() > _dialReach) return null;
    return (offset: offset, x: x);
  }

  /// Where across [grip]'s window a zoom drag holds still: the dial's line,
  /// which the eye zooms about, or the middle where the line is out of the
  /// window.
  double _zoomPivot(_Grip grip) {
    final vfo = _vfo;
    final at = vfo == null ? .5 : (vfo - (grip.center - grip.width / 2)) / grip.width;
    return at >= 0 && at <= 1 ? at : .5;
  }

  _Grip? _gripAt(double x, {required bool zoom}) {
    final frame = _frame, width = _laidOut.width;
    if (frame == null || width <= 0 || frame.highHz <= frame.lowHz) return null;
    final span = (frame.highHz - frame.lowHz).toDouble(), fraction = (x / width).clamp(0.0, 1.0);
    return (zoom: zoom, x: x, width: span, center: frame.lowHz + span / 2, anchorHz: frame.lowHz + fraction * span, fraction: fraction);
  }

  Map<Type, GestureRecognizerFactory> _recognizers({required bool axis}) {
    final g = _gestures;
    const off = SceneSpectrumGesture.off;
    final taps =
        _tuneGoes ||
        (widget.onAnnotation != null && _spec.annotations.isNotEmpty) ||
        (widget.onLayer != null && _spec.layers.any((l) => l.clickable)) ||
        (axis && g.zoom == SceneSpectrumGesture.native) ||
        // The dial's label waiting at an edge, which a click follows back to the dial.
        (g.pan == SceneSpectrumGesture.native && _spec.pan && !_spec.noVfoLabel);
    // Measured from where the finger came down, not where the drag was recognised past its slop.
    void drag(DragGestureRecognizer r) => r
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = ((d) {
        _stopGlide();
        if (_drawsBow(d.localPosition)) return _drawBow(d.localPosition);
        _dial = _dialAt(d.localPosition);
        _grip = _dial == null ? _gripAt(_canonicalAt(d.localPosition).dx, zoom: _onAxis(d.localPosition)) : null;
      })
      ..onUpdate = _dragUpdate
      ..onEnd = ((_) => _dragEnd())
      ..onCancel = _dragEnd;
    return {
      if (taps) TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(TapGestureRecognizer.new, (r) => r.onTapUp = _tap),
      // Along the frequency axis only, so a drag across it still scrolls a scene that scrolls.
      if (g.zoom != off || g.pan != off || _wheelTunes)
        if (_turned(_way))
          VerticalRegionDrag: GestureRecognizerFactoryWithHandlers<VerticalRegionDrag>(() => VerticalRegionDrag(_dragsAt), (r) => drag(r..allowedAt = _dragsAt))
        else
          HorizontalRegionDrag: GestureRecognizerFactoryWithHandlers<HorizontalRegionDrag>(
            () => HorizontalRegionDrag(_dragsAt),
            (r) => drag(r..allowedAt = _dragsAt),
          ),
      // Across the axis, which the drag along it leaves alone.
      if (axis && g.split != off)
        if (_turned(_way))
          HorizontalRegionDrag: GestureRecognizerFactoryWithHandlers<HorizontalRegionDrag>(
            () => HorizontalRegionDrag(_onAxis),
            (r) => _splitDrag(r..allowedAt = _onAxis),
          )
        else
          VerticalRegionDrag: GestureRecognizerFactoryWithHandlers<VerticalRegionDrag>(
            () => VerticalRegionDrag(_onAxis),
            (r) => _splitDrag(r..allowedAt = _onAxis),
          ),
    };
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_bow?.phase == _BowPhase.drawn) return _pullBow(d.localPosition);
    if (_dial != null) return _dialTo(_canonicalAt(d.localPosition).dx);
    final grip = _grip;
    // A second finger makes it a pinch, which the drag gives way to.
    if (grip == null || _touches.length > 1) return;
    final dx = _canonicalAt(d.localPosition).dx - grip.x;
    if (grip.zoom) {
      // The dial's line holds still — the window's middle with the line out
      // of it — and the frequency pressed on stays exactly under the
      // pointer: the axis is stretched between the two, away from the line
      // narrowing, toward it widening. On the line or past it no width does
      // both, and the window waits for the pointer to come back.
      final pivot = _zoomPivot(grip), pivotHz = grip.center + (pivot - .5) * grip.width;
      final (hz, along) = (grip.anchorHz - pivotHz, (grip.x + dx) / _laidOut.width - pivot);
      if (hz * along <= 0 || along.abs() * _laidOut.width < 2) return;
      _zoom((zoom: true, x: grip.x, width: grip.width, center: grip.center, anchorHz: pivotHz, fraction: pivot), hz / along);
    } else {
      _pan(grip.center - dx * grip.width / _laidOut.width);
    }
  }

  /// A drag across the axis moves it, toward the waterfall growing the
  /// panadapter, between a tenth and nine tenths of the height they share.
  void _splitDrag(DragGestureRecognizer r) => r
    ..dragStartBehavior = DragStartBehavior.down
    ..onStart = ((d) => _splitGrip = (_panShare, _canonicalAt(d.localPosition).dy))
    ..onUpdate = ((d) {
      if (_splitGrip case (final from, final y) when _shared > 0) {
        final share = (from + (_canonicalAt(d.localPosition).dy - y) / _shared).clamp(.1, .9);
        switch (_gestures.split) {
          case SceneSpectrumGesture.off:
            return;
          case SceneSpectrumGesture.event:
            return _hear('split', share);
          case SceneSpectrumGesture.native when share != _panShare:
            _toReport.add('split');
            _resplit(share);
          case SceneSpectrumGesture.native:
            return;
        }
      }
    })
    ..onEnd = ((_) => _splitEnd())
    ..onCancel = _splitEnd;

  void _splitEnd() {
    _splitGrip = null;
    _settle();
  }

  /// The line dragged to [x]: the dial goes to the frequency under it — as
  /// far from the pointer as the drag took hold, so taking hold moves
  /// nothing — on no step, so the line moves smoothly with the pointer, its
  /// label on the fine step ([_labelHz]); let go, it lands there
  /// ([_landDial]). In the outer [_edgeShare] the window pans under it
  /// ([_onDialPan]), the line staying with the pointer.
  void _dialTo(double x) {
    final (dial, frame, width) = (_dial, _frame, _laidOut.width);
    if (dial == null || frame == null || width <= 0) return;
    _dial = (offset: dial.offset, x: x);
    final hz = frame.lowHz + (x - dial.offset) / width * (frame.highHz - frame.lowHz);
    if (hz != (_tunePending ?? _wheelHz)) {
      _wheelHz = hz;
      _wheelMillis = realNowMillis();
      _tuneSoon(hz);
      _holdDial(hz);
    }
    if (!_dialPanner.isActive && _dialPanShare(x / width) != 0) {
      _dialPannedAt = null;
      _dialPanSpeed = 0;
      _dialPanner.start();
    }
  }

  /// How fast, as a share of [_dialPanWidths], a line dragged to [share] of
  /// the way across pans the window: from nothing at the outer
  /// [_edgeShare]'s inner edge to all of it at the edge and past, down the
  /// band below the middle and up it above.
  double _dialPanShare(double share) => share < _edgeShare
      ? -math.min(1.0, (_edgeShare - share) / _edgeShare)
      : share > 1 - _edgeShare
      ? math.min(1.0, (share - 1 + _edgeShare) / _edgeShare)
      : 0.0;

  /// A frame of a dragged line's pan: the window moves at the pace where the
  /// pointer is calls for, and the dial with it, under the pointer.
  void _onDialPan(Duration elapsed) {
    final ms = _dialPannedAt == null ? 1000 / 60 : (elapsed - _dialPannedAt!).inMicroseconds / 1000;
    _dialPannedAt = elapsed;
    final (dial, frame, width) = (_dial, _frame, _laidOut.width);
    final pace = dial == null || frame == null || width <= 0 ? 0.0 : _dialPanShare(dial.x / width);
    if (pace == 0) return _landDialPan();
    final from = _viewCenter ?? (frame!.lowHz + frame.highHz) / 2;
    final speed = pace * _dialPanWidths * (frame!.highHz - frame.lowHz) / 1000;
    _moveTo(from + speed * ms);
    _toReport.add('pan');
    _reframe();
    // Against the edge of a scope that will not move: as far as it goes.
    if (_viewCenter == from) return _landDialPan();
    _dialPanSpeed = speed.abs();
    _dialTo(dial!.x);
  }

  /// A dragged line's pan come to a stop: the dial, tuned through every Hz on
  /// the way, lands on the step [spectrumLandingStep] picks for how fast it
  /// went, since where it stops is where the operator listens.
  void _landDialPan() {
    if (!_dialPanner.isActive) return;
    _dialPanner.stop();
    final (fine, medium, coarse) = (_fineStep(), _mediumStep(), _coarseStep());
    if (_dialPanSpeed <= 0 || fine == null || medium == null || coarse == null) return;
    _landDial(spectrumLandingStep(_dialPanSpeed, fine: fine, medium: medium, coarse: coarse));
  }

  /// The dragged dial, tuned through every Hz on the way, put on [step].
  void _landDial(double? step) {
    final hz = _wheelHz;
    if (hz == null || step == null || step <= 0) return;
    final landed = (hz / step).round() * step;
    if (landed == hz) return;
    _wheelHz = landed;
    _wheelMillis = realNowMillis();
    _tuneSoon(landed);
    _holdDial(landed);
  }

  /// Draws the dial at [hz] now, ahead of the radio's report of it: the line,
  /// the `vfoHz` readout and follow. Drawn from reports, they trail the
  /// operator by the pacing and the round trip. Only for a tune the app sends
  /// the radio itself: one that goes out as the control's event may be put to
  /// another use, or refused, and drawn it would show a dial the radio never
  /// took. Either way it starts the time a click stays on the finer steps.
  void _holdDial(double hz) {
    final now = realNowMillis();
    _heldMillis = now;
    if (!_tunesNatively) return;
    _heldVfo = hz;
    _labelDial();
    _tellReadouts();
    _keepInView(now);
    _reframe();
  }

  void _dragEnd() {
    if (_bow?.phase == _BowPhase.drawn) return _looseBow();
    if (_dial != null) {
      // Let go mid-pan, on the step for its speed; otherwise on the fine step the label showed.
      if (_dialPanner.isActive) {
        _landDialPan();
      } else {
        _landDial(_fineStep());
      }
      _dial = null;
      // The last place the line was left goes out now, not after the pacing.
      if (_tunePending != null) {
        _tuneTimer?.cancel();
        _flushTune();
      }
      // Where the drag panned the window, the scope goes there and the scene hears of it.
      if (_toReport.contains('pan')) _settle();
      return;
    }
    if (_grip == null) return;
    _grip = null;
    _settle();
  }

  /// A zoom to [width] that keeps [grip]'s frequency where it was across the window.
  void _zoom(_Grip grip, double width) {
    final w = _clampWidth(width);
    final center = grip.anchorHz + (.5 - grip.fraction) * w;
    switch (_gestures.zoom) {
      case SceneSpectrumGesture.off:
        return;
      case SceneSpectrumGesture.event:
        return _hear('zoom', w);
      case SceneSpectrumGesture.native:
        // The operator's window now, not the radio's to hand back.
        _releaseAt = null;
        _toReport.add('zoom');
        _viewWidth = w;
        _zoomedOverSpan = _number(_spec.span);
        _moveTo(center, gesture: true);
        _showWidth();
        _fitSpan(w);
        _reframe();
    }
  }

  void _pan(double center) {
    switch (_gestures.pan) {
      case SceneSpectrumGesture.off:
        return;
      case SceneSpectrumGesture.event:
        return _hear('pan', center);
      case SceneSpectrumGesture.native:
        _releaseAt = null;
        _toReport.add('pan');
        final uuid = _uuid;
        // The dial as drawn — what follow compares with — not the radio's last report, which a tune
        // just sent may not have reached: the pan would otherwise read as a dial moved, and be undone.
        _pannedAtVfo = uuid == null ? null : _vfo;
        _moveTo(center, gesture: true);
        _reframe();
    }
  }

  /// A zoom or pan the scene hears rather than the host makes: `change`
  /// while it moves, and the last of them as `commit` at [_settle].
  void _hear(String gesture, double value) {
    _heard = (gesture, value);
    widget.onGesture?.call(gesture, 'change', value);
  }

  /// The end of a gesture: the scene hears its commit, or the radio its last
  /// move and the scene where it left the window.
  void _settle() {
    _settleTimer?.cancel();
    if (_heard case (final gesture, final value)) {
      _heard = null;
      widget.onGesture?.call(gesture, 'commit', value);
      return;
    }
    if (_viewCenter case final center?) _moveTo(center, last: true, gesture: true);
    final zoomed = _toReport.contains('zoom');
    // The scene told first: a driver throwing at the span would otherwise cost it where the zoom ended.
    _report();
    if (_viewWidth case final width?) _fitSpan(width, last: true, narrow: zoomed);
  }

  /// Tells the scene, as a `commit` naming the gesture, where a native zoom,
  /// pan, split or level drag left things, so it can keep them: the width
  /// shown, the window's middle, the panadapter's share, its floor offset and
  /// range in dB, the waterfall's rows a second. Not to a bundle before API 17,
  /// whose commits are its clicks.
  void _report() {
    final reports = {..._toReport};
    _toReport.clear();
    if (!(widget.source?.nativeGestures ?? true)) return;
    final frame = _frame;
    for (final gesture in reports) {
      final value = switch (gesture) {
        'zoom' => _viewWidth ?? (frame == null ? null : (frame.highHz - frame.lowHz).toDouble()),
        'pan' => _viewCenter,
        'split' => _split,
        'floor' => _floorHeld?.value,
        'range' => _rangeHeld?.value,
        _ => _speedHeld?.value,
      };
      if (value != null) widget.onGesture?.call(gesture, 'commit', value);
    }
  }

  /// The narrowest a zoom goes — the scene's `minWidthHz`, or a hundred
  /// hertz or the narrowest sweep the scope can be made to send spread
  /// [_zoomPixelsPerPoint] apart, taken to have as many points as this one —
  /// and the widest:
  /// the scene's `maxWidthHz`, or what the scope can be made to show.
  double _clampWidth(double width) {
    final (sweep, uuid) = (_sweep, _uuid);
    if (sweep == null) return width;
    final sweepWidth = (sweep.highHz - sweep.lowHz).toDouble();
    final narrowestSweep = math.min(sweepWidth, (uuid == null ? null : widget.source?.minWidthHz(uuid))?.toDouble() ?? sweepWidth);
    final widest = _spec.maxWidthHz ?? _scopeWidest(sweep);
    final narrowest = math.min(
      widest,
      _spec.minWidthHz ?? math.max(100.0, _laidOut.width / _zoomPixelsPerPoint * narrowestSweep / math.max(1, sweep.levels.length)),
    );
    return width.clamp(narrowest, widest);
  }

  /// The widest window [sweep]'s scope can be made to show: past the sweep where the app may widen it.
  double _scopeWidest(SpectrumFrame sweep) {
    final uuid = _uuid;
    return math.max((sweep.highHz - sweep.lowHz).toDouble(), (uuid == null ? null : widget.source?.maxWidthHz(uuid))?.toDouble() ?? 0);
  }

  /// Whether a window [width] wide is past what the scope can be made to
  /// show — a scene's `maxWidthHz` allowing it — so the sweep covers only
  /// part of it, and follows the dial rather than the window.
  bool _pastScope(double width) {
    final sweep = _sweep;
    return sweep != null && width > _scopeWidest(sweep);
  }

  /// Moves the window's middle to [center]. Within the sweep that is only a
  /// crop; past its edge the radio's scope moves too, where it will, at most
  /// four times a second — [last] sends the final move regardless — and
  /// where it will not, the window goes on until its middle reaches the
  /// edge, the rest drawn as filler: what lies past a scope held on the dial
  /// is still the operator's to look at, spots and band plan included. A window wider than
  /// the scope can be made never moves the scope, which follows the dial
  /// ([_keepSweepOnDial]); an operator's [gesture] there, and any move on a
  /// scope that stays put, stops where the sweep reaches the window's edge.
  void _moveTo(double center, {bool last = false, bool gesture = false}) {
    final sweep = _sweep;
    if (sweep == null) return;
    final sweepWidth = (sweep.highHz - sweep.lowHz).toDouble();
    final width = _viewWidth ?? _number(_spec.span) ?? sweepWidth;
    if (_pastScope(width)) {
      _viewCenter = gesture || _recenters != true ? center.clamp(sweep.highHz - width / 2, sweep.lowHz + width / 2) : center;
      return;
    }
    final half = math.min(width, sweepWidth) / 2;
    final (low, high) = (sweep.lowHz + half, sweep.highHz - half);
    if (center >= low && center <= high) {
      _viewCenter = center;
      return;
    }
    final (uuid, source, now) = (_uuid, widget.source, realNowMillis());
    if (_recenters != false && uuid != null && source != null && (last || now - _lastRecenterMillis >= 250)) {
      final moved = _recenters = source.recenter(uuid, center.round());
      if (moved) {
        _lastRecenterMillis = _sweepAskedMillis = now;
        _sweepAskedHz = center;
      }
    }
    _viewCenter = _recenters == true ? center : center.clamp(sweep.lowHz.toDouble(), sweep.highHz.toDouble());
  }

  /// A radio whose scope widths are its own, fitted to a window [width]
  /// wide: widened for a zoom past the sweep, at most four times a second,
  /// and narrowed only where a zoom ends ([narrow]) — narrowed as it went, a
  /// zoom in would step the radio through every span on the way. Asked for
  /// the window where it sits, which a scope centred on the dial covers only
  /// with more than its width.
  void _fitSpan(double width, {bool last = false, bool narrow = false}) {
    final (sweep, uuid, source, now) = (_sweep, _uuid, widget.source, realNowMillis());
    if (sweep == null || uuid == null || source == null) return;
    if (!narrow && width <= sweep.highHz - sweep.lowHz) return;
    if (!last && now - _lastFitMillis < 250) return;
    final (middle, swept) = ((sweep.lowHz + sweep.highHz) / 2, (sweep.highHz - sweep.lowHz).toDouble());
    final center = _viewCenter ?? middle, covering = width + 2 * (center - middle).abs();
    if (covering < swept && width / swept * sweep.levels.length >= _laidOut.width / _fitPixelsPerPoint) return;
    if (covering < swept) _sweepBeforeNarrowing ??= swept;
    if (source.fitSpan(uuid, width.round(), centerHz: center.round(), offCenterHz: (center - middle).abs().round())) _lastFitMillis = now;
  }

  /// A double tap on the axis: the scene's width again, centred on the dial,
  /// and the scene told so as a zoom to 0 — a scene keeping the operator's
  /// width in its `span` puts its own back. A radio's scope this control's
  /// zoom narrowed is widened back to what it swept before — left narrow, the
  /// reset would only crop the narrowed sweep — and not fitted to the scene's
  /// `span`, which at this point may still be the zoom being undone.
  void _reset() {
    _toReport.clear();
    if (widget.source?.nativeGestures ?? true) widget.onGesture?.call('zoom', 'commit', 0);
    _viewWidth = null;
    _viewCenter = null;
    _pannedAtVfo = null;
    _showWidth();
    if (_sweepBeforeNarrowing case final back?) {
      _sweepBeforeNarrowing = null;
      _fitSpan(back, last: true, narrow: true);
    }
    final uuid = _uuid;
    if (uuid != null) {
      if (_vfo case final vfo?) _moveTo(vfo, last: true);
    }
    _reframe();
  }

  /// The fine step: the scene's `tuneStep`, or a rung above what a pixel
  /// tells apart — one pixel's lands on digits nobody tunes by. The `stepHz`
  /// readout's.
  double? _fineStep() => _step(shift: 1);

  /// The medium step, a rung above the fine one, and the coarse, two: no
  /// coarser than [_coarseMaxHz] unless the fine one is, and the scene's
  /// `tuneStep` where it has one.
  double? _mediumStep() => _coarser(1);
  double? _coarseStep() => _coarser(2);

  double? _coarser(int rungs) {
    final fine = _fineStep();
    if (fine == null) return null;
    return math.max(fine, math.min(_step(shift: 1 + rungs)!, _coarseMaxHz));
  }

  /// The scene's `tuneStep`, or [shift] rungs of 1, 2, 5 × 10ⁿ above what
  /// [pixels] tell apart at this zoom. Null before API 17, whose clicks go
  /// out where they land.
  double? _step({double pixels = 1, int shift = 0}) {
    if (_number(_spec.tuneStep) case final step? when step > 0) return step;
    final frame = _frame;
    if (!(widget.source?.nativeGestures ?? true) || frame == null || _laidOut.width <= 0) return null;
    return spectrumTuneStep((frame.highHz - frame.lowHz) / _laidOut.width, pixels: pixels, shift: shift);
  }

  void _tap(TapUpDetails e) {
    final at = e.localPosition;
    if ((_annotationAt(at)?.away ?? false) && _gestures.pan == SceneSpectrumGesture.native) return _toVfo();
    // A collapsed one is read before it is acted on: a touch, with no hover to open it, opens it first.
    if (_annotationAt(at)?.annotation case final collapsed? when collapsed.collapsed && collapsed.id != _revealed) return _reveal(collapsed.id);
    // And closes again with a touch anywhere else, which no pointer leaving it does.
    if (_revealed != null && _annotationAt(at)?.annotation?.id != _revealed) _reveal(null);
    if (_annotationAt(at) case (:final annotation?, :final hz, rect: _, away: _) when annotation.clickable && widget.onAnnotation != null) {
      return _click(annotation.event, annotation.menu, e, (action, details) => widget.onAnnotation!(annotation, action, hz, details));
    }
    if (_layerAt(at) case final layer?) {
      final hz = _hzAt(at, _screen);
      return _click(layer.event, layer.menu, e, (action, details) => widget.onLayer!(layer, action, hz, details));
    }
    // A double click on the axis resets the zoom, so a click there waits out the double-click time
    // before it tunes: tuning at once, the first click of a reset would also move the dial. Only
    // there — a double-tap recognizer would hold back every click on the picture too.
    if (_onAxis(at) && _gestures.zoom == SceneSpectrumGesture.native) {
      if (_axisClick?.isActive ?? false) {
        _axisClick!.cancel();
        _axisClick = null;
        return _reset();
      }
      _axisClick = Timer(kDoubleTapTimeout, () {
        _axisClick = null;
        if (mounted) _clickTune(at);
      });
      return;
    }
    _clickTune(at);
  }

  /// A click on the dial's label waiting at an edge: the window goes to the
  /// dial, centred on it — at once from more than a few widths away.
  void _toVfo() {
    final (vfo, frame) = (_vfo, _frame);
    if (vfo == null || frame == null) return;
    _pannedAtVfo = null;
    final width = (frame.highHz - frame.lowHz).toDouble();
    _glideTo(vfo, jump: (vfo - (frame.lowHz + frame.highHz) / 2).abs() > _glideWidths * width);
  }

  /// Sends [event], or opens [menu] at the pointer and sends the item picked.
  /// Where the click landed is taken as it lands: the waterfall moves on while the menu is open.
  void _click(String? event, SceneMenu? menu, TapUpDetails e, void Function(String action, Map<String, Object> at) send) {
    final at = _clickAt(e);
    if (menu == null) return send(event!, at);
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(e.globalPosition);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(point & Size.zero, Offset.zero & overlay.size),
      items: [for (final item in menu) PopupMenuItem(value: item.event, child: Text(item.label))],
    ).then((picked) {
      if (picked != null && mounted) send(picked, at);
    });
  }

  /// Where a click landed, as an event's `at`: pixels in the control and,
  /// placed by a rect, scene units; the part, the frequency, and on the
  /// spectrum the level — on the radio's own scale, and above the noise — or
  /// on the waterfall the age of the row and when it was taken.
  Map<String, Object> _clickAt(TapUpDetails e) {
    final box = context.findRenderObject() as RenderBox?;
    final whole = box == null ? e.localPosition : box.globalToLocal(e.globalPosition);
    final c = _canonicalAt(e.localPosition), frame = _frame, rect = widget.control.rect;
    Rect? canonical(Rect? band) => band == null ? null : Rect.fromPoints(_canonicalAt(band.topLeft), _canonicalAt(band.bottomRight));
    final (pan, fall) = (canonical(_panBand), canonical(_fallBand));
    final part = _onAxis(e.localPosition)
        ? 'axis'
        : pan != null && pan.contains(c)
        ? 'spectrum'
        : fall != null && fall.contains(c)
        ? 'waterfall'
        : null;
    final at = <String, Object>{'x': whole.dx, 'y': whole.dy, 'part': ?part, 'hz': ?_hzAt(e.localPosition, _screen)};
    if (rect != null && box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
      at['sceneX'] = rect.left + whole.dx / box.size.width * rect.width;
      at['sceneY'] = rect.top + whole.dy / box.size.height * rect.height;
    }
    if (part == 'spectrum' && frame != null && pan!.height > 0) {
      final (floor, range) = _panScale(frame);
      final db = floor + (pan.bottom - c.dy) / pan.height * range;
      at['db'] = db;
      if (frame.noiseDb case final noise?) at['aboveNoiseDb'] = db - noise;
    }
    if (_secondsPerPixel() case final perPixel? when part == 'waterfall') {
      final age = math.max(0.0, c.dy - fall!.top) * perPixel;
      at['ageSeconds'] = age;
      at['atMillis'] = nowMillis() - (age * 1000).round();
    }
    return at;
  }

  /// A click's tune, to [at] on the step its distance from the dial and the
  /// time since the last tune call for.
  void _clickTune(Offset at) {
    final hz = _hzAt(at, _screen), vfo = _vfo;
    if (hz == null || !_tuneGoes) return;
    final distance = vfo == null || realNowMillis() - _heldMillis >= _fineWindowMs ? double.infinity : (hz - vfo).abs();
    final step = distance <= _fineReachHz
        ? _fineStep()
        : distance <= _mediumReachHz
        ? _mediumStep()
        : _coarseStep();
    final target = step == null ? hz : (hz / step).round() * step;
    if (_frame case final frame? when _tunesNatively) {
      final width = (frame.highHz - frame.lowHz).toDouble(), share = (target - frame.lowHz) / width;
      final center = share < _edgeShare
          ? target + (.5 - _edgeShare) * width
          : share > 1 - _edgeShare
          ? target - (.5 - _edgeShare) * width
          : null;
      // After the clicks come to rest, as follow waits for the dial: a run of clicks near an edge
      // glides once, from the last, rather than starting a glide on each.
      _edgeGlide?.cancel();
      _edgeGlide = null;
      if (center != null) {
        _edgeGlide = Timer(const Duration(milliseconds: _jumpRestMs), () {
          _edgeGlide = null;
          if (mounted) _glideTo(center);
        });
      }
    }
    _holdDial(target);
    _tuneTo(target);
  }

  /// Tunes as the scene asked: the host, or the control's event — which is
  /// also where a native tune goes when the panel may not command the radio.
  void _tuneTo(double hz, {bool dial = false}) {
    final g = _gestures.tune, uuid = _uuid;
    if (g == SceneSpectrumGesture.off) return;
    if (g == SceneSpectrumGesture.native && uuid != null && (widget.source?.tune(uuid, hz, dial: dial, refused: () => _refused(hz)) ?? false)) return;
    widget.onTune?.call(hz);
  }

  /// The wheel's tunes, at most four a second, the newest kept: a spun
  /// wheel would otherwise queue a walk through every step behind the radio's pace.
  void _tuneSoon(double hz) {
    _tunePending = hz;
    if (!(_tuneTimer?.isActive ?? false)) _flushTune();
  }

  void _flushTune() {
    final hz = _tunePending;
    _tunePending = null;
    if (hz == null || !mounted) return;
    _tuneTo(hz, dial: true);
    _tuneTimer = Timer(const Duration(milliseconds: 250), _flushTune);
  }

  /// The wheel: up and down, and sideways, each do what the scene's `scroll`
  /// says — by default up and down tune a step, from the dial (or from the
  /// last step taken, while the radio has yet to report it), and sideways
  /// pans. Along the scene's own scroll a sideways turn, and a trackpad's
  /// swipe either way (as a browser delivers it), are the scene's: taken
  /// here, the scene would stop scrolling over every spectrum in it. A mouse
  /// wheel turned up or down over the spectrum is the spectrum's, scrolling
  /// scene or not.
  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final d = event.scrollDelta;
    final sideways = d.dx.abs() > d.dy.abs();
    if (widget.scrollAxis == (sideways ? Axis.horizontal : Axis.vertical) && (sideways || event.kind == PointerDeviceKind.trackpad)) return;
    final does = _scrollDoes(sideways);
    if (does == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _scrollBy(does, sideways ? Offset(d.dx, 0) : Offset(0, d.dy), event.localPosition);
      if (does != SceneSpectrumScroll.pan) return;
      _settleTimer?.cancel();
      _settleTimer = Timer(const Duration(milliseconds: 300), _settle);
    });
  }

  /// What a scroll [sideways], or up and down, does here: null where the
  /// scene says nothing, or where what it says goes nowhere.
  SceneSpectrumScroll? _scrollDoes(bool sideways) {
    final does = sideways ? _spec.gestures.horizontal : _spec.gestures.vertical;
    return switch (does) {
      SceneSpectrumScroll.tune when _wheelTunes => does,
      SceneSpectrumScroll.pan when _gestures.pan != SceneSpectrumGesture.off => does,
      _ => null,
    };
  }

  /// A scroll of [delta] at [at], tuning or panning toward higher
  /// frequencies by how far it runs that way: along the frequency where the
  /// scroll runs along it on screen, so the dial or the window follows the
  /// pointer's way whichever way the spectrum lies; across it, up and right
  /// are higher, as a wheel tunes an upright spectrum.
  void _scrollBy(SceneSpectrumScroll does, Offset delta, Offset at) {
    final along = (delta.dx != 0) != _turned(_way);
    final higher = along ? _canonicalAt(at + delta).dx - _canonicalAt(at).dx : (delta.dx != 0 ? delta.dx : -delta.dy);
    if (does == SceneSpectrumScroll.tune) return _wheelBy(-higher);
    final frame = _frame;
    if (frame == null || _laidOut.width <= 0) return;
    _pan((frame.lowHz + frame.highHz) / 2 + higher * (frame.highHz - frame.lowHz) / _laidOut.width);
  }

  bool get _wheelTunes => _gestures.wheel && _tuneGoes;

  /// Whether a tune goes anywhere: to the radio, natively, where the panel
  /// may command it; else as the control's event, where it has one. Where
  /// neither, nothing tunes — and nothing draws a dial it moved, or takes a
  /// click, a notch or a drag of the line as though it had.
  bool get _tuneGoes => _tunesNatively || (_gestures.tune != SceneSpectrumGesture.off && widget.onTune != null);

  /// Whether a tune goes to the radio from the app itself.
  bool get _tunesNatively {
    final uuid = _uuid;
    return _gestures.tune == SceneSpectrumGesture.native && uuid != null && (widget.source?.canTune(uuid) ?? false);
  }

  /// Scroll travel across the frequency, a wheel's or a trackpad's, down
  /// positive: each notch's worth tunes a step down or up, the click's steps,
  /// finer the slower the notches come.
  void _wheelBy(double dy) {
    _wheelTravel += dy;
    if (_wheelTravel.abs() < _wheelNotch && dy.abs() < _wheelNotch) return;
    final down = _wheelTravel > 0;
    _wheelTravel = 0;
    final now = realNowMillis();
    final base = (now - _wheelMillis < 1000 ? _wheelHz : null) ?? _vfo;
    final gap = now - _wheelMillis;
    final step =
        (gap >= _slowNotchMs
            ? _fineStep()
            : gap >= _fastNotchMs
            ? _mediumStep()
            : _coarseStep()) ??
        1;
    if (base == null) return;
    final hz = down ? ((base / step).ceil() - 1) * step : ((base / step).floor() + 1) * step;
    _wheelHz = hz;
    _wheelMillis = now;
    _tuneSoon(hz);
    _holdDial(hz);
  }

  /// The radio said no to a tune of [hz]: the dial goes back to its own at
  /// once, unless the operator has put it somewhere else since.
  void _refused(double hz) {
    if (!mounted || _heldVfo != hz) return;
    _heldVfo = null;
    _tellReadouts();
    _reframe();
  }

  /// Moves the window's middle to [hz] — the radio's scope at once, where it
  /// moves — and draws the way there over [_glide], so the eye can follow the
  /// signal clicked instead of losing it to a jump; or, to [jump], at once;
  /// or over [ms] on [curve], where the move has a pace of its own.
  void _glideTo(double hz, {bool jump = false, int? ms, Curve curve = Curves.easeOutCubic}) {
    final frame = _frame;
    if (frame == null) return;
    final from = (frame.lowHz + frame.highHz) / 2;
    // A window that was the radio's sweep becomes the radio's again once the
    // sweeps reach where its scope was moved, so it goes on following the
    // radio — a scope moved from the radio itself included.
    final free = _viewCenter == null;
    _moveTo(hz, last: true);
    final to = _viewCenter ?? from;
    _releaseAt = free && _recenters == true ? to : null;
    if (jump) {
      _glide.stop();
      _glideSpan = null;
      // A jump beyond a scope that stays put waits for the sweep at the new band.
      if (_recenters != true && to != hz) _viewCenter = null;
      return _reframe();
    }
    if ((to - from).abs() < 1) return;
    _glideSpan = (from, to);
    _glideCurve = curve;
    _viewCenter = from;
    // As long as the move is far: a short one done quickly, a long one slowly enough to follow.
    final width = (frame.highHz - frame.lowHz).toDouble();
    _glide.duration = Duration(milliseconds: ms ?? (_glideMsPerWidth * (to - from).abs() / width).round().clamp(_glideMinMs, _glideMaxMs));
    _glide.forward(from: 0);
  }

  void _onGlide() {
    final span = _glideSpan;
    if (span == null) return;
    _viewCenter = span.$1 + (span.$2 - span.$1) * _glideCurve.transform(_glide.value);
    if (_glide.isCompleted) _glideSpan = null;
    _reframe();
  }

  /// A gesture taking hold of the window ends a glide where it is, and one
  /// still waiting, and leaves the bow's string straight.
  void _stopGlide() {
    _unstring();
    _edgeGlide?.cancel();
    _edgeGlide = null;
    _chaser.stop();
    _dialPanner.stop();
    if (_glideSpan == null) return;
    _glide.stop();
    _glideSpan = null;
  }

  /// A trackpad's two fingers: a pinch zooms about where it began; a swipe
  /// along the frequency axis pans and one across it tunes, as the wheel —
  /// except along a scrolling scene's axis, which is the scroll's.
  void _trackpadStart(PointerPanZoomStartEvent event) {
    _stopGlide();
    _trackpad = _gripAt(_canonicalAt(event.localPosition).dx, zoom: false);
    _trackpadMode = null;
  }

  void _trackpadUpdate(PointerPanZoomUpdateEvent event) {
    final grip = _trackpad, g = _gestures;
    if (grip == null) return;
    if ((_trackpadMode == null || _trackpadMode!.zoom) && g.zoom != SceneSpectrumGesture.off && (event.scale - 1).abs() > .02) {
      _trackpadMode = (zoom: true, does: null, sideways: false);
      return _zoom(grip, grip.width / event.scale);
    }
    // A swipe is a scroll, each way doing what the wheel's does.
    if (_trackpadMode == null && event.pan.distance > 6) {
      // The scene's scroll takes the same swipe outside the gesture arena; both taking it would tune
      // or pan the radio as the scene scrolls.
      final sideways = event.pan.dx.abs() > event.pan.dy.abs();
      final scrolls = widget.scrollAxis == (sideways ? Axis.horizontal : Axis.vertical);
      _trackpadMode = (zoom: false, does: scrolls ? null : _scrollDoes(sideways), sideways: sideways);
      _wheelTravel = 0;
    }
    if (_trackpadMode case (zoom: false, does: final does?, :final sideways)) {
      // The content follows the fingers, as a scroll does: a swipe is the scroll the other way.
      final d = -event.panDelta;
      _scrollBy(does, sideways ? Offset(d.dx, 0) : Offset(0, d.dy), event.localPosition);
    }
  }

  void _trackpadEnd(PointerPanZoomEndEvent _) {
    final mode = _trackpadMode;
    _trackpad = null;
    _trackpadMode = null;
    if (mode != null && (mode.zoom || mode.does == SceneSpectrumScroll.pan)) _settle();
  }

  /// Touches, followed outside the gesture arena: a second finger down makes
  /// a pinch, which zooms and pans together, the frequency first between the
  /// fingers staying between them.
  void _touchDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches[event.pointer] = _canonicalAt(event.localPosition).dx;
    if (_touches.length != 2 || _gestures.zoom == SceneSpectrumGesture.off) return;
    _grip = null;
    final [a, b] = _touches.values.toList();
    _pinch = _gripAt((a + b) / 2, zoom: true);
    _pinchFrom = math.max(24, (a - b).abs());
  }

  void _touchMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = _canonicalAt(event.localPosition).dx;
    final pinch = _pinch;
    if (pinch == null || _touches.length < 2) return;
    final [a, b, ...] = _touches.values.toList();
    final x = (a + b) / 2;
    _zoom((
      zoom: true,
      x: x,
      width: pinch.width,
      center: pinch.center,
      anchorHz: pinch.anchorHz,
      fraction: (x / _laidOut.width).clamp(0.0, 1.0),
    ), pinch.width * _pinchFrom / math.max(24, (a - b).abs()));
  }

  void _touchUp(PointerEvent event) {
    if (_touches.remove(event.pointer) == null || _pinch == null || _touches.length >= 2) return;
    _pinch = null;
    _settle();
  }
}

/// The step a dial moving at [hzPerMs] lands on when it stops: the one the
/// wheel would be on, spun as fast — [fine] where its notches would come
/// [_slowNotchMs] or more apart, [medium] down to [_fastNotchMs], [coarse]
/// faster.
@visibleForTesting
double spectrumLandingStep(double hzPerMs, {required double fine, required double medium, required double coarse}) => fine / hzPerMs >= _slowNotchMs
    ? fine
    : medium / hzPerMs >= _fastNotchMs
    ? medium
    : coarse;
