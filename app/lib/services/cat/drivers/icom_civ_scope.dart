// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scope's side of a CI-V session: the `SpectrumSession` calls, reading
// the scope's settings back, and turning what the radio sends (`0x27`) into
// sweeps and settings for the display.

part of 'icom_civ_driver.dart';

const _civSpeeds = {SpectrumSpeed.fast: 0x00, SpectrumSpeed.mid: 0x01, SpectrumSpeed.slow: 0x02};

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
  SpectrumSettings _scopeSettings = const SpectrumSettings();
  String? _scopeProblem;

  @override
  String? get spectrumUnavailable {
    if (!_scopeSupported) return t.settings.station.spectrumUnsupported;
    final baud = _baudRate;
    if (baud != null && baud < civScopeMinBaud) return t.settings.station.spectrumRequiresBaud;
    return null;
  }

  @override
  SpectrumCapabilities get spectrumCapabilities => const SpectrumCapabilities(
    spansHz: civScopeSpans,
    refMinDb: civScopeRefMinDb,
    refMaxDb: civScopeRefMaxDb,
    refStepDb: civScopeRefStepDb,
    modes: {SpectrumMode.center, SpectrumMode.fixed},
    speeds: {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
  );

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
    _send(buildScopeOutputFrame(to: radioAddress, from: controllerAddress, on: false));
    if (_scopeTurnedOn) _send(buildScopeOnOffFrame(to: radioAddress, from: controllerAddress, on: false));
    _scopeTurnedOn = false;
    // Forgotten with the display, so the next one hears them again.
    _scopeSettings = const SpectrumSettings();
    _scopeProblem = null;
  }

  @override
  bool setSpectrum(SpectrumRequest request) {
    if (!_scopeWanted) return false;
    final caps = spectrumCapabilities;
    if (request.mode case final mode?) _send(buildScopeModeFrame(to: radioAddress, from: controllerAddress, fixed: mode == SpectrumMode.fixed));
    if (request.spanHz case final span?) _send(buildScopeSpanFrame(to: radioAddress, from: controllerAddress, spanHz: caps.snapSpan(span)));
    if (request.refLevelDb case final ref?) _send(buildScopeRefFrame(to: radioAddress, from: controllerAddress, refDb: caps.snapRef(ref)));
    if (request.speed case final speed?) _send(buildScopeSpeedFrame(to: radioAddress, from: controllerAddress, speed: _civSpeeds[speed]));
    // A set is ACKed, not echoed, and the ACK names no command — so what the
    // radio actually took is read back rather than assumed.
    _readScopeSettings();
    return true;
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
        _spectrumSink?.reportSpectrum(
          SpectrumFrame(
            lowHz: sweep.lowHz,
            highHz: sweep.highHz,
            // Each step is half a dB of the radio's screen — a scale, not a
            // calibration: what the bottom of the screen means moves with REF.
            levels: Float32List.fromList([for (final a in sweep.amplitudes) a / 2]),
            floorDb: 0,
            ceilingDb: civScopeAmplitudeMax / 2,
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
        if (parseScopeFixed(data) case final fixed?) {
          final was = _scopeSettings;
          // Edges belong to fixed mode only: a centered scope has none.
          _reportScopeSettings(
            fixed ? was.copyWith(mode: SpectrumMode.fixed) : SpectrumSettings(spanHz: was.spanHz, refLevelDb: was.refLevelDb, speed: was.speed),
          );
        }
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
