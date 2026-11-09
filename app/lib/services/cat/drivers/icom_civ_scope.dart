// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scope's side of a CI-V session: the `SpectrumSession` calls, reading
// the scope's settings back, and turning what the radio sends (`0x27`) into
// sweeps and settings for the display.

part of 'icom_civ_driver.dart';

/// Pinned `true` by an entry whose radio streams its scope over CI-V (0x27).
/// Never a field: it is a fact about the model, and a radio without one
/// answers every scope command with a NAK.
const civScopeConfigKey = 'civScope';

/// Pinned by an entry whose scope is drawn on another scale than the
/// IC-705's: the top of its amplitude bytes ([civScopeAmplitudeMax] where
/// absent — 200 on an IC-7610 or IC-7760, 136 on an IC-7850/7851), and the
/// REF range as `[min, max]` dB ([civScopeRefMinDb]..[civScopeRefMaxDb] where
/// absent — −30..+10 on an IC-7610 or IC-7760, which refuse a REF past +10).
/// Never fields: facts about the model, from Icom's CI-V reference guides.
const civScopeTopConfigKey = 'civScopeTop';
const civScopeRefRangeConfigKey = 'civScopeRefRange';

/// Pinned by an entry whose fixed-edge band ranges are not
/// [civScopeEdgeRanges]' — the IC-705, IC-9700 and IC-905.
const civScopeEdgeRangesConfigKey = 'civScopeEdgeRanges';

/// Whether HaLo adjusts the radio's scope — [civScopeAdjustApp], the
/// default: its reference level (REF) so the noise shows as on every other
/// radio, and its mode and edges so a tune moves the dial, not the picture —
/// or leaves every setting of it as the operator has it ([civScopeAdjustRadio]).
/// Not a field of the equipment editor: the Station panel offers it under the
/// current transceiver, where [civScopeConfigKey] is pinned — what the radio's
/// own screen shows is a choice about the radio in use, not a wiring detail.
const civScopeAdjustConfigKey = 'civScopeAdjust';
const civScopeAdjustApp = 'app';
const civScopeAdjustRadio = 'radio';

/// The scope's keys beyond [civScopeConfigKey], for the driver's `recognizedConfigKeys`.
const civScopeConfigKeys = {civScopeAdjustConfigKey, civScopeTopConfigKey, civScopeRefRangeConfigKey, civScopeEdgeRangesConfigKey};

const _civSpeeds = {SpectrumSpeed.fast: 0x00, SpectrumSpeed.mid: 0x01, SpectrumSpeed.slow: 0x02};

/// The automatic reference's timing and dead band. Real time: a settling
/// spell is a duration (docs/design/time.md §1).
const _autoRefQuietMillis = 1000;
const _autoRefReadMillis = 1000;
const _autoRefToleranceDb = 3.0;

/// How long a switch to Scroll-F has to show in the sweeps before it is
/// asked again. Real time, like the reference's.
const _takeOverRetryMillis = 2000;

/// The narrowest a preset's edges are placed: the narrowest span's width.
const _narrowestEdgesHz = 5000;

/// The lowest the noise target goes, however far the operator turns REF
/// down: further than the dead band from 0, where the radio clips the noise,
/// or a clipped reading would count as on target and the screen stay black.
const _autoRefLowestDb = 5.0;

mixin _CivScope implements SpectrumSession {
  EquipmentSink get _sink;
  int get radioAddress;
  int get controllerAddress;
  bool get _scopeSupported;
  int? get _baudRate;
  int? get _freqHz;
  void _send(List<int> frame);
  void _poll(List<int> frame);

  bool _scopeWanted = false;

  /// The radio's scope was off when the display asked for it, so it goes off
  /// again with the display — the operator's own screen is not ours to keep.
  bool _scopeTurnedOn = false;

  final _scopeAssembler = CivScopeAssembler();

  /// The noise a scene places things by. Under [_scopeAdjusts] it places the
  /// display too, as on every other radio; otherwise the display is the
  /// radio's own screen, as REF leaves it.
  final _scopeNoise = NoiseFloor();
  SpectrumSettings _scopeSettings = const SpectrumSettings();
  String? _scopeProblem;

  Map<String, dynamic> get _config;

  /// See [civScopeAdjustConfigKey].
  bool get _scopeAdjusts => _config[civScopeAdjustConfigKey] != civScopeAdjustRadio;

  /// See [civScopeEdgeRangesConfigKey].
  List<List<int>> get _scopeEdgeRanges => switch (_config[civScopeEdgeRangesConfigKey]) {
    final List<dynamic> ranges => [for (final range in ranges) List<int>.from(range as List)],
    _ => civScopeEdgeRanges,
  };

  /// The top of the radio's screen, on the levels' scale. See [civScopeTopConfigKey].
  double get _scopeTopDb => ((_config[civScopeTopConfigKey] as num?) ?? civScopeAmplitudeMax) / 2;

  /// How far the operator has moved the automatic reference's noise target,
  /// by turning REF while it steers. Kept for the session, so a display
  /// reopened keeps the brightness the operator chose.
  double _autoRefNudgeDb = 0;

  /// Sweeps from this real-clock moment count towards the next reading;
  /// null until the first sweep of a display.
  int? _autoRefFrom;
  String? _autoRefBand;
  final _autoRefNoise = <double>[];

  /// The radio's scope mode as the sweeps last said; the one it had before
  /// HaLo put it in Scroll-F, to give back with the display; and when that
  /// was last asked. All under [_scopeAdjusts] only.
  int? _scopeMode;
  int? _scopeModeBefore;
  int? _scopeTakenOverAt;

  /// The fixed-edge preset the radio shows in Scroll-F, as it answers: the
  /// one HaLo moves. Its edges are never written before it is known.
  int? _scopeEdgeNumber;

  /// The last edges frame the radio refused: not asked again, or a dial held
  /// near a band range's end would send it four times a second.
  List<int>? _refusedEdges;

  /// The radio refused Scroll-F, or the read of its preset: a model or
  /// firmware without them. The scope stays in its own mode for the display,
  /// rather than being asked again every 2 s under a notice that flickers.
  bool _takeOverRefused = false;

  @override
  String? get spectrumUnavailable {
    if (!_scopeSupported) return t.settings.station.spectrumUnsupported;
    final baud = _baudRate;
    if (baud != null && baud < civScopeMinBaud) return t.settings.station.spectrumRequiresBaud;
    return null;
  }

  /// Under [_scopeAdjusts], the window is the app's — span and centre alike
  /// are a preset's edges — and the mode is the one it keeps. Otherwise
  /// nothing about the scope is: no span to fit, no REF or speed to send, no
  /// window to move, so a display zooms and pans only within the sweep.
  @override
  SpectrumCapabilities get spectrumCapabilities {
    if (!_scopeAdjusts) return const SpectrumCapabilities(spansHz: [], refMinDb: 0, refMaxDb: 0, refStepDb: civScopeRefStepDb, modes: {});
    final [refMin, refMax] = switch (_config[civScopeRefRangeConfigKey]) {
      [final num min, final num max] => [min.toDouble(), max.toDouble()],
      _ => [civScopeRefMinDb, civScopeRefMaxDb],
    };
    return SpectrumCapabilities(
      spansHz: civScopeSpans,
      refMinDb: refMin,
      refMaxDb: refMax,
      refStepDb: civScopeRefStepDb,
      modes: const {},
      speeds: const {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
      canRecenter: true,
      spanSetsEdges: true,
    );
  }

  @override
  void startSpectrum() {
    if (_scopeWanted || spectrumUnavailable != null) return;
    _scopeWanted = true;
    // Whether the screen shows the scope decides what [stopSpectrum] leaves
    // behind; the answer turns it on if it is off.
    _send(buildScopeOnOffFrame(to: radioAddress, from: controllerAddress));
    _send(buildScopeOutputFrame(to: radioAddress, from: controllerAddress, on: true));
    _readScopeSettings();
  }

  @override
  void stopSpectrum() {
    if (!_scopeWanted) return;
    _scopeWanted = false;
    if (_scopeModeBefore case final mode?) _send(buildScopeModeFrame(to: radioAddress, from: controllerAddress, mode: mode));
    _send(buildScopeOutputFrame(to: radioAddress, from: controllerAddress, on: false));
    if (_scopeTurnedOn) _send(buildScopeOnOffFrame(to: radioAddress, from: controllerAddress, on: false));
    _scopeTurnedOn = false;
    // Forgotten with the display, so the next one hears them again.
    _scopeSettings = const SpectrumSettings();
    _scopeProblem = null;
    _autoRefFrom = null;
    _autoRefNoise.clear();
    _scopeMode = _scopeModeBefore = _scopeTakenOverAt = _scopeEdgeNumber = null;
    _refusedEdges = null;
    _takeOverRefused = false;
  }

  /// A mode is not taken: the scope's is the app's to keep, or the radio's.
  @override
  bool setSpectrum(SpectrumRequest request) {
    if (!_scopeWanted || !_scopeAdjusts) return false;
    final caps = spectrumCapabilities;
    // Said done only for what went to the radio: a window believed moved where it was not runs off
    // into filler, and a move never sent is never tried again.
    var done = request.refLevelDb != null || request.speed != null;
    if (request.spanHz != null || request.centerHz != null) {
      final (low, high) = (_scopeSettings.lowHz, _scopeSettings.highHz);
      if (low != null && high != null && _scopeMode == civScopeModeScrollF) {
        done = _placeScopeEdges(request.centerHz ?? (low + high) ~/ 2, request.spanHz == null ? high - low : 2 * caps.snapSpan(request.spanHz!)) || done;
      }
    }
    if (request.refLevelDb case final ref?) {
      final snapped = caps.snapRef(ref);
      if (_scopeSettings.refLevelDb != null) {
        // The operator's turn moves the target with it, or the next reading
        // would turn it straight back.
        _autoRefNudgeDb = (_autoRefNudgeDb + snapped - _scopeSettings.refLevelDb!).clamp(
          _autoRefLowestDb - NoiseFloor.belowNoiseDb,
          _scopeTopDb - NoiseFloor.belowNoiseDb,
        );
        _quietScopeRef();
      }
      _send(buildScopeRefFrame(to: radioAddress, from: controllerAddress, refDb: snapped));
    }
    if (request.speed case final speed?) _send(buildScopeSpeedFrame(to: radioAddress, from: controllerAddress, speed: _civSpeeds[speed]));
    // A set is ACKed, not echoed, and the ACK names no command — so what the
    // radio actually took is read back rather than assumed. Edges come back
    // in the very next sweep's header, so a pan reads nothing.
    if (request.refLevelDb != null || request.speed != null) _readScopeSettings();
    return done;
  }

  SpectrumSink? get _spectrumSink => switch (_sink) {
    final SpectrumSink sink => sink,
    _ => null,
  };

  void _readScopeSettings() {
    _poll(buildScopeModeFrame(to: radioAddress, from: controllerAddress));
    _poll(buildScopeSpanFrame(to: radioAddress, from: controllerAddress));
    _poll(buildScopeRefFrame(to: radioAddress, from: controllerAddress));
    _poll(buildScopeSpeedFrame(to: radioAddress, from: controllerAddress));
    if (_scopeAdjusts) _poll(buildScopeEdgeNumberFrame(to: radioAddress, from: controllerAddress));
  }

  /// Under [_scopeAdjusts], puts the scope in Scroll-F, first writing the
  /// window it shows into the selected preset so the picture does not jump.
  /// There a tune moves the dial and not the picture, and the scene's follow
  /// moves the window (`canRecenter`) before the dial reaches its edge,
  /// where the radio would scroll it. A radio turned back to another mode on
  /// its own panel is put back again, once its sweeps have had time to show
  /// the last switch.
  void _takeOverScope(CivScopeSweep sweep) {
    _scopeMode = sweep.mode;
    if (sweep.mode == civScopeModeScrollF || _takeOverRefused) return;
    final now = realNowMillis();
    if (_scopeTakenOverAt != null && now - _scopeTakenOverAt! < _takeOverRetryMillis) return;
    if (_scopeEdgeNumber == null) {
      // Asked with the scope's settings when the display opened; an answer lost there would hold
      // the takeover off for as long as the display stays open.
      _scopeTakenOverAt = now;
      return _poll(buildScopeEdgeNumberFrame(to: radioAddress, from: controllerAddress));
    }
    // Outside every band range of the model, no mode with edges can show it.
    if (!_placeScopeEdges((sweep.lowHz + sweep.highHz) ~/ 2, sweep.highHz - sweep.lowHz)) return;
    _scopeTakenOverAt = now;
    _scopeModeBefore ??= sweep.mode;
    _send(buildScopeModeFrame(to: radioAddress, from: controllerAddress, mode: civScopeModeScrollF));
    // REF is read again, and the noise afresh: the radio may keep another for the mode it is now in.
    _poll(buildScopeRefFrame(to: radioAddress, from: controllerAddress));
    _quietScopeRef();
  }

  /// Writes the selected preset's edges [widthHz] apart about [centerHz],
  /// whole kHz, as the radio takes them, and kept inside the band range of
  /// the operating frequency, which is the preset Scroll-F shows — and with
  /// the dial a kHz inside them: Scroll-F scrolls edges that leave it out
  /// back over it, away from the window they were placed for, so a window
  /// off past the dial gets what of it they can cover instead. False where
  /// there is no range, or no preset or frequency known yet. Edges the
  /// radio already shows in Scroll-F are not written again.
  bool _placeScopeEdges(int centerHz, int widthHz) {
    final (edge, freq) = (_scopeEdgeNumber, _freqHz);
    if (edge == null || freq == null) return false;
    final ranges = _scopeEdgeRanges;
    // Neighbouring ranges share their ends: one ending where the next begins takes the dial only below it.
    final index = ranges.indexWhere((range) => freq >= range[0] && (freq < range[1] || (freq == range[1] && range == ranges.last)));
    if (index < 0) return false;
    final [rangeLow, rangeHigh] = ranges[index];
    final width = ((widthHz / 1000).round() * 1000).clamp(_narrowestEdgesHz, math.min(civScopeMaxEdgeWidthHz, rangeHigh - rangeLow)).toInt();
    final (lowest, highest) = (((freq - width + 1000) / 1000).ceil() * 1000, ((freq - 1000) / 1000).floor() * 1000);
    final low = (((centerHz - width / 2) / 1000).round() * 1000).clamp(lowest, math.max(lowest, highest)).toInt();
    final placed = math.max(rangeLow, math.min(low, rangeHigh - width));
    if (_scopeMode == civScopeModeScrollF && _scopeSettings.lowHz == placed && _scopeSettings.highHz == placed + width) return true;
    final frame = buildScopeEdgesFrame(to: radioAddress, from: controllerAddress, range: index + 1, edge: edge, lowHz: placed, highHz: placed + width);
    if (listEquals(frame, _refusedEdges)) return false;
    _send(frame);
    // A new width moves the noise in each point — a tenth the width, a tenth the noise — so the
    // reading starts over, and REF is read again, cheaply, in case the radio keeps one per span.
    if ((_scopeSettings.lowHz, _scopeSettings.highHz) case (final low?, final high?) when high - low != width) {
      _poll(buildScopeRefFrame(to: radioAddress, from: controllerAddress));
      _quietScopeRef();
    }
    return true;
  }

  /// The radio refused [frame], one of the scope's. A display left waiting
  /// on a refused scope would wait forever, so it is said — except for
  /// edges, which a radio sold with narrower bands than its CI-V guide's
  /// refuses at their ends: the window then only stays where it was, and
  /// the radio scrolls it when the dial leaves it. Those are remembered, and
  /// not asked again.
  void _scopeRefused(List<int>? frame) {
    if (frame != null && frame.length > 5 && frame[5] == civScopeEdges) {
      _refusedEdges = frame;
      return;
    }
    // The takeover's own: the switch to Scroll-F (a set, longer than a read) or the preset's read.
    if (frame != null && frame.length > 5 && ((frame[5] == civScopeMode && frame.length > 8) || frame[5] == civScopeEdgeNumber)) {
      _takeOverRefused = true;
      return;
    }
    if (!_scopeWanted) return;
    _reportScopeProblem(t.settings.station.spectrumScopeRefused);
  }

  /// With [_scopeAdjusts], moves the radio's REF until the noise sits where
  /// [NoiseFloor] puts every other radio's: [NoiseFloor.belowNoiseDb] above
  /// the bottom of the display, plus the operator's nudge. The radio keeps
  /// the REF it is left with, per band, on its own screen too.
  ///
  /// A REF move reaches the sweeps a moment after it is sent, and a new band
  /// brings the REF the radio keeps for it, so each starts a quiet spell
  /// whose sweeps are not read. After it, a whole second of sweeps is read
  /// as one, so a burst of static does not move REF; a noise read as 0 is
  /// clipped by the radio, and REF goes up by the whole target to find it.
  void _steerScopeRef(Float32List levels, int centerHz) {
    final ref = _scopeSettings.refLevelDb;
    if (!_scopeAdjusts || ref == null || levels.isEmpty) return;
    final now = realNowMillis();
    final band = bandForFrequency(centerHz / 1000);
    if (_autoRefFrom == null || band != _autoRefBand) {
      // A new band brings the REF the radio keeps for it: steered from the last band's, it can stall
      // at a limit the new band's REF is nowhere near.
      if (_autoRefBand != null) _poll(buildScopeRefFrame(to: radioAddress, from: controllerAddress));
      _autoRefBand = band;
      _quietScopeRef();
    }
    if (now < _autoRefFrom!) return;
    final sorted = Float32List.fromList(levels)..sort();
    _autoRefNoise.add(sorted[sorted.length ~/ 5]);
    if (now < _autoRefFrom! + _autoRefReadMillis) return;
    final noise = (_autoRefNoise..sort())[_autoRefNoise.length ~/ 2];
    _autoRefNoise.clear();
    _autoRefFrom = now;
    final target = NoiseFloor.belowNoiseDb + _autoRefNudgeDb;
    if ((noise - target).abs() <= _autoRefToleranceDb) return;
    final next = spectrumCapabilities.snapRef(ref + target - noise);
    // Held at a limit: read REF again, in case the radio's is not the one last heard.
    if (next == ref) return _poll(buildScopeRefFrame(to: radioAddress, from: controllerAddress));
    _send(buildScopeRefFrame(to: radioAddress, from: controllerAddress, refDb: next));
    _poll(buildScopeRefFrame(to: radioAddress, from: controllerAddress));
    _quietScopeRef();
  }

  /// A REF move shifts every level at once, so the display's noise starts
  /// over too, rather than holding the old level for its settling time.
  void _quietScopeRef() {
    _autoRefFrom = realNowMillis() + _autoRefQuietMillis;
    _autoRefNoise.clear();
    _scopeNoise.reset();
  }

  void _reportScopeProblem(String? message) {
    if (message == _scopeProblem) return;
    _scopeProblem = message;
    _spectrumSink?.reportSpectrumProblem(message);
  }

  void _reportScopeSettings(SpectrumSettings settings) {
    if (settings == _scopeSettings) return;
    _scopeSettings = settings;
    _spectrumSink?.reportSpectrumSettings(settings);
  }

  void _handleScope(List<int> data) {
    if (data.isEmpty) return;
    switch (data[0]) {
      case civScopeWaveform:
        if (!_scopeWanted) return;
        // There the sweep header's frequencies are six bytes too, and the
        // assembler reads five: every field after the first lands a byte off
        // and the sweep would draw as noise across the wrong range.
        if ((_freqHz ?? 0) >= civSixByteFrequencyHz) return _reportScopeProblem(t.settings.station.spectrumBandUnsupported);
        final sweep = _scopeAssembler.add(data);
        if (sweep == null) return;
        if (_scopeAdjusts) _takeOverScope(sweep);
        // The header restates mode and span on every sweep, so a turn of the
        // radio's own span knob reaches the settings without a read.
        final fixed = sweep.fixed ? SpectrumMode.fixed : SpectrumMode.center;
        _reportScopeSettings(
          sweep.fixed
              ? _scopeSettings.copyWith(mode: fixed, lowHz: sweep.lowHz, highHz: sweep.highHz)
              : SpectrumSettings(mode: fixed, spanHz: sweep.secondHz, refLevelDb: _scopeSettings.refLevelDb, speed: _scopeSettings.speed),
        );
        // The radio says why there is nothing to draw: say it, rather than
        // let the display go stale.
        if (sweep.outOfRange) return _reportScopeProblem(t.settings.station.spectrumOutOfRange);
        _reportScopeProblem(null);
        // Each step is half a dB of the radio's screen — a scale, not a
        // calibration: what the bottom of the screen means moves with REF.
        final levels = Float32List.fromList([for (final a in sweep.amplitudes) a / 2]);
        // The dial's band, not the sweep's: the radio keeps REF by the band it is on, and a sweep panned
        // across a band's edge would start each reading over as it crossed, and never steer.
        final bandHz = _freqHz ?? (sweep.lowHz + sweep.highHz) ~/ 2;
        _steerScopeRef(levels, bandHz);
        final range = levels.isEmpty ? null : _scopeNoise.update(levels, centerHz: bandHz);
        final followNoise = _scopeAdjusts && range != null;
        _spectrumSink?.reportSpectrum(
          SpectrumFrame(
            lowHz: sweep.lowHz,
            highHz: sweep.highHz,
            levels: levels,
            floorDb: followNoise ? range.floor : 0,
            ceilingDb: followNoise ? range.ceiling : _scopeTopDb,
            noiseDb: range?.noise,
            atMillis: nowMillis(),
          ),
        );
      case civScopeOnOff:
        if (parseScopeFlag(data) == false && _scopeWanted && !_scopeTurnedOn) {
          _scopeTurnedOn = true;
          _send(buildScopeOnOffFrame(to: radioAddress, from: controllerAddress, on: true));
          // The output again, after the scope: whether turning the scope on
          // resets it has not been pinned down, and asking twice costs one
          // exchange.
          _send(buildScopeOutputFrame(to: radioAddress, from: controllerAddress, on: true));
        }
      case civScopeMode:
        if (parseScopeMode(data) case final mode?) {
          final fixed = mode != civScopeModeCenter;
          _scopeMode = mode;
          final was = _scopeSettings;
          // Edges belong to fixed mode only: a centered scope has none.
          _reportScopeSettings(
            fixed ? was.copyWith(mode: SpectrumMode.fixed) : SpectrumSettings(spanHz: was.spanHz, refLevelDb: was.refLevelDb, speed: was.speed),
          );
        }
      case civScopeEdgeNumber:
        _scopeEdgeNumber = parseScopeEdgeNumber(data) ?? _scopeEdgeNumber;
      case civScopeSpan:
        if (parseScopeSpan(data) case final span?) _reportScopeSettings(_scopeSettings.copyWith(spanHz: span));
      case civScopeRef:
        if (parseScopeRef(data) case final ref?) _reportScopeSettings(_scopeSettings.copyWith(refLevelDb: ref));
      case civScopeSpeed:
        if (parseScopeSpeed(data) case final code?) {
          _reportScopeSettings(_scopeSettings.copyWith(speed: _civSpeeds.entries.firstWhere((e) => e.value == code).key));
        }
    }
  }
}
