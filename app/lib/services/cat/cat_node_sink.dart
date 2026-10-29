// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a session reports through: one callback per [EquipmentSink] report,
// each wired by `CatService` to the node the session belongs to.

part of 'cat_service.dart';

class _NodeSink implements EquipmentSink, SpectrumSink, SdrSink, TunerSink, PassbandSink, RadioAntennaSink, TransmitAudioSink {
  final EquipmentConnection connection;
  final double? Function() linkedVfo;
  final void Function(VfoReading) onReading;
  final void Function(num) onPower;
  final void Function(bool) onTransmitting;
  final void Function(RadioMeter, num) onMeter;
  final void Function(int) onKeyerSpeed;
  final void Function(CwSendProgress?) onCwProgress;
  final void Function(VoiceActivity?) onVoiceActivity;
  final void Function(List<VoiceMemory>) onVoiceMemories;
  final void Function(String?) onDiagnostic;
  final void Function(String?) onProblem;
  final void Function(List<EquipmentChannel>) onChannels;
  final void Function(List<SwitchAntenna>, List<SwitchPort>) onSwitchState;
  final void Function() onAlive;
  final void Function(SpectrumFrame) onSpectrum;
  final void Function(SpectrumSettings) onSpectrumSettings;
  final void Function(String?) onSpectrumProblem;
  final void Function(TunerStatus?) onTuner;
  final void Function(Passband?) onPassband;
  final void Function(RadioAntennas?) onAntennas;
  final void Function(List<int> bytes) onSend;

  _NodeSink({
    required this.connection,
    required this.linkedVfo,
    required this.onSend,
    required this.onReading,
    required this.onPower,
    required this.onTransmitting,
    required this.onMeter,
    required this.onKeyerSpeed,
    required this.onCwProgress,
    required this.onVoiceActivity,
    required this.onVoiceMemories,
    required this.onDiagnostic,
    required this.onProblem,
    required this.onChannels,
    required this.onSwitchState,
    required this.onAlive,
    required this.onSpectrum,
    required this.onSpectrumSettings,
    required this.onSpectrumProblem,
    required this.onTuner,
    required this.onPassband,
    required this.onAntennas,
  });

  @override
  void send(List<int> bytes) {
    onSend(bytes);
    connection.send(bytes);
  }

  @override
  TransmitAudioConnection? get transmitAudio => switch (connection) {
    final TransmitAudioConnection audio when audio.carriesTransmitAudio => audio,
    _ => null,
  };

  @override
  void report(VfoReading reading) => onReading(reading);

  @override
  void reportPower(num watts) => onPower(watts);

  @override
  void reportTransmitting(bool transmitting) => onTransmitting(transmitting);

  @override
  void reportMeter(RadioMeter meter, num value) => onMeter(meter, value);

  @override
  void reportKeyerSpeed(int wpm) => onKeyerSpeed(wpm);

  @override
  void reportCwProgress(CwSendProgress? progress) => onCwProgress(progress);

  @override
  void reportVoiceActivity(VoiceActivity? activity) => onVoiceActivity(activity);

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) => onVoiceMemories(memories);

  @override
  void reportDiagnostic(String? note) => onDiagnostic(note);

  @override
  void reportProblem(String? message) => onProblem(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => onChannels(channels);

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => onSwitchState(antennas, ports);

  @override
  void reportAlive() => onAlive();

  @override
  void reportSpectrum(SpectrumFrame frame) => onSpectrum(frame);

  @override
  void reportSpectrumSettings(SpectrumSettings settings) => onSpectrumSettings(settings);

  @override
  void reportSpectrumProblem(String? message) => onSpectrumProblem(message);

  @override
  double? get linkedVfoHz => linkedVfo();

  @override
  void reportTuner(TunerStatus? status) => onTuner(status);

  @override
  void reportPassband(Passband? passband) => onPassband(passband);

  @override
  void reportAntennas(RadioAntennas? antennas) => onAntennas(antennas);
}
