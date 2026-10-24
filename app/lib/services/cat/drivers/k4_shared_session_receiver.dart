// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'k4_shared_session.dart';

/// A logical receiver has its own VFO/display demand while TX capabilities
/// address the one physical transmitter without changing its split selection.
class _K4ReceiverSession
    implements TransceiverSession, SpectrumSession, PassbandSession, PttSession, CwKeyerSession, VoiceKeyerSession, RawCommandSession, AntennaTunerSession {
  final K4SharedSession owner;
  final EquipmentSink sink;
  final K4Receiver receiver;
  bool _active = false, _disposed = false, _spectrumWanted = false;
  String? _spectrumProblem;
  late final _presenter = K4SpectrumPresenter(sink: sink is SpectrumSink ? sink as SpectrumSink : null);

  _K4ReceiverSession(this.owner, this.sink, this.receiver);

  bool get _usable => _active && !_disposed && !owner._disposed && !owner._closing;
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void handleData(Uint8List bytes) {}
  @override
  void startUpdates() => owner._start(this);
  @override
  void stopUpdates() => owner._detach(this);
  @override
  void teardown() {
    if (_disposed) return;
    _disposed = true;
    owner._detach(this);
    owner._facades.remove(this);
  }

  K4Receiver? get _target {
    if (!_usable) return null;
    if (receiver == K4Receiver.sub && owner._subOn == false) return null;
    final binding = owner._binding(receiver);
    // An unknown diversity state cannot authorize a write to VFO B: it may
    // be the split TX holding register rather than this receiver's tuning.
    if (binding == null) owner._send('DV;');
    return binding;
  }

  void _refresh(K4Receiver target) {
    // Main band recalls and diversity can change B as a side effect. AI4
    // excludes this client's changes, including those coupled settings.
    if (target == K4Receiver.main) {
      owner._readReceivers();
    } else {
      owner._send('FB;MD\$;DT\$;');
    }
  }

  @override
  void setFrequency(double freqKHz) {
    final target = _target;
    if (target == null) return;
    final command = buildK4ReceiverFrequency(target, freqKHz);
    if (command == null) return;
    final state = owner._receivers[target]!;
    final band = k4BandNumber(freqKHz);
    if (band != null && band != state.band) owner._send('BN${target.suffix}${band.toString().padLeft(2, '0')};');
    state.band = band;
    owner._send(command);
    _refresh(target);
  }

  @override
  void setMode(String mode) {
    final target = _target;
    if (target == null) return;
    final command = buildK4ReceiverMode(target, mode);
    if (command == null) return;
    owner._send(command);
    _refresh(target);
  }

  @override
  void setPassband(Passband passband) {
    final target = _target;
    if (target == null || passband.widthHz <= 0) return;
    final state = owner._receivers[target]!;
    if (k4ReceiverPassband(mode: state.mode, widthHz: state.widthHz, centerHz: state.centerHz, cwPitchHz: owner._cwPitchHz) == null) return;
    // K40's center SET format remains ambiguous; preserve the radio's center
    // and read back its actual width.
    final width = (passband.widthHz / 10).round().clamp(0, 9999).toString().padLeft(4, '0');
    owner._send('BW${target.suffix}$width;BW${target.suffix};IS${target.suffix};');
  }

  @override
  String? get spectrumUnavailable => null;
  @override
  SpectrumCapabilities get spectrumCapabilities => _presenter.capabilities;
  @override
  void startSpectrum() {
    if (!_usable || _spectrumWanted) return;
    _spectrumWanted = true;
    _presenter.start();
    if (_usable && _spectrumWanted) owner._spectrumDemand();
  }

  @override
  void stopSpectrum() {
    if (!_spectrumWanted) return;
    _spectrumWanted = false;
    _presenter.stop();
    owner._spectrumDemand();
    _reportSpectrumProblem(null);
  }

  @override
  bool setSpectrum(SpectrumRequest request) => _usable && _presenter.set(request);

  void _reportSpectrumProblem(String? message) {
    if (_spectrumProblem == message) return;
    _spectrumProblem = message;
    if (sink case final SpectrumSink spectrum) spectrum.reportSpectrumProblem(message);
  }

  @override
  void setPower(num watts) {
    if (_usable) owner._radio.setPower(watts);
  }

  @override
  void setPtt(bool on) {
    if (!_usable) return;
    // A release from another receiver must not drop the owner's CAT key.
    if (!on && owner._pttOwner != null && owner._pttOwner != this) return;
    owner._pttOwner = on ? this : null;
    owner._radio.setPtt(on);
  }

  @override
  void sendCw(String text) {
    if (!_usable || sanitizeCwText(text).isEmpty) return;
    owner._cwOwner = this;
    owner._radio.sendCw(text);
  }

  @override
  void stopCw() {
    if (_usable) owner._radio.stopCw();
  }

  @override
  bool get cwSending => owner._radio.cwSending;
  @override
  void dropQueuedCw(int id) {
    if (_usable) owner._radio.dropQueuedCw(id);
  }

  @override
  void setKeyerSpeed(int wpm) {
    if (_usable) owner._radio.setKeyerSpeed(wpm);
  }

  @override
  ({int min, int max}) get keyerSpeedRange => owner._radio.keyerSpeedRange;
  @override
  void refreshKeyerSpeed() {
    if (_usable) owner._radio.refreshKeyerSpeed();
  }

  @override
  int get voiceMemoryCount => owner._radio.voiceMemoryCount;
  @override
  bool get canRecordVoice => owner._radio.canRecordVoice;
  @override
  Duration get voiceMemoryCeiling => owner._radio.voiceMemoryCeiling;
  @override
  void playVoiceMemory(int n) {
    if (!_usable || n < 1 || n > voiceMemoryCount) return;
    owner._voiceOwner = this;
    owner._radio.playVoiceMemory(n);
  }

  @override
  void recordVoiceMemory(int n) {
    if (!_usable || !canRecordVoice || n < 1 || n > voiceMemoryCount) return;
    owner._voiceOwner = this;
    owner._radio.recordVoiceMemory(n);
  }

  @override
  void stopVoice() {
    if (_usable) owner._radio.stopVoice();
  }

  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) => _usable ? owner._radio.sendRaw(bytes, onAnswer: onAnswer) : null;
  @override
  bool get canStartTune => owner._radio.canStartTune;
  @override
  void setTuner({required bool inline}) {
    if (_usable) owner._radio.setTuner(inline: inline);
  }

  @override
  void startTune() {
    if (_usable) owner._radio.startTune();
  }

  @override
  void stopTune() {
    if (_usable) owner._radio.stopTune();
  }
}
