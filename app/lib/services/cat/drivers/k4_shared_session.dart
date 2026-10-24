// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';

import '../../error_reporting_service.dart';
import '../driver.dart';
import '../equipment.dart';
import '../spectrum.dart';
import 'cat_ascii_codec.dart';
import 'cw_send_queue.dart';
import 'k4_codec.dart';
import 'k4_receiver_codec.dart';
import 'k4_remote_codec.dart';
import 'k4_shared_session_config.dart';
import 'k4_spectrum_presenter.dart';
import 'kenwood_cat_codec.dart';
import 'kenwood_driver.dart';

part 'k4_shared_session_receiver.dart';

/// One CAT command owner for all logical receivers on a physical K4 link.
/// The connection pool alone owns its lifetime; receiver facades never close
/// the connection or initialize another AI stream, key queue, or TX owner.
class K4SharedSession implements EquipmentSink {
  final void Function(List<int>) _sendBytes;
  final Stream<K4RemotePanPacket> _pan;
  final Map<String, dynamic> _config;

  K4SharedSession({required void Function(List<int>) send, required this._pan, required Map<String, dynamic> config})
    : _sendBytes = send,
      _config = Map.of(config);

  late final _radio = KenwoodSession(
    this,
    isK4: true,
    remote: true,
    cwDialect: KenwoodDriver.cwDialectFrom(_config),
    voiceDialect: KenwoodDriver.voiceDialectFrom(_config),
    voiceMemories: KenwoodDriver.voiceMemoriesFrom(_config),
    voiceMemoryCeiling: voiceCeilingFromConfig(_config),
    config: _config,
  );
  final _framer = AsciiCatFramer();
  final _receivers = {for (final receiver in K4Receiver.values) receiver: _ReceiverState()};
  final _facades = <_K4ReceiverSession>{};
  final _global = <String, void Function(EquipmentSink)>{};
  StreamSubscription<K4RemotePanPacket>? _panSubscription;
  bool _started = false, _disposed = false, _closing = false, _panEnded = false;
  int _panEpoch = 0;
  bool? _diversity, _subOn;
  int? _cwPitchHz;
  String? _problem;
  _K4ReceiverSession? _pttOwner;
  _K4ReceiverSession? _cwOwner, _voiceOwner;

  EquipmentSession attach(EquipmentSink sink, {required String receiver}) {
    if (_disposed || _closing) throw StateError('K4 session is closed');
    final selected = parseK4Receiver(receiver);
    if (selected == null) throw ArgumentError.value(receiver, 'receiver');
    final facade = _K4ReceiverSession(this, sink, selected);
    _facades.add(facade);
    return facade;
  }

  void _start(_K4ReceiverSession facade) {
    if (_disposed || _closing || facade._disposed || facade._active) return;
    facade._active = true;
    if (!_started) {
      _started = true;
      _radio.startUpdates();
      if (_disposed) return;
      _send('FA;FB;MD;MD\$;DT;DT\$;DV;SB;BW;BW\$;IS;IS\$;CW;SMH1;');
    }
    for (final report in _global.values.toList()) {
      if (!facade._active || _disposed) return;
      report(facade.sink);
    }
    _publish(facade);
    _publishChannels();
  }

  void _detach(_K4ReceiverSession facade) {
    facade._active = false;
    if (_cwOwner == facade) {
      _cwOwner = null;
      _radio.stopCw();
    }
    if (_voiceOwner == facade) {
      _voiceOwner = null;
      _radio.stopVoice();
    }
    if (_pttOwner == facade) {
      _pttOwner = null;
      _radio.setPtt(false);
    }
    facade.stopSpectrum();
  }

  K4Receiver? _binding(K4Receiver receiver) => receiver == K4Receiver.main
      ? K4Receiver.main
      : switch (_diversity) {
          true => K4Receiver.main,
          false => K4Receiver.sub,
          null => null,
        };

  void _send(String text) => send(ascii.encode(text));

  @override
  void send(List<int> bytes) {
    if (!_disposed) _sendBytes(bytes);
  }

  /// Called once by the physical connection, regardless of lease count.
  void handleData(Uint8List bytes) {
    if (_disposed || _closing) return;
    _radio.handleData(bytes);
    if (_disposed) return;
    for (final command in _framer.add(ascii.decode(bytes, allowInvalid: true))) {
      if (_disposed) return;
      _handle(command);
    }
  }

  void _handle(AsciiCatCommand command) {
    final sub = command.params.startsWith(r'$');
    final receiver = sub ? K4Receiver.sub : K4Receiver.main;
    final params = sub ? command.params.substring(1) : command.params;
    final state = _receivers[receiver]!;
    switch (command.command) {
      case 'FA' || 'FB':
        final frequency = parseKenwoodFrequencyParams(command.params);
        if (frequency == null) return;
        final target = _receivers[command.command == 'FA' ? K4Receiver.main : K4Receiver.sub]!;
        target.freqKHz = frequency / 1000;
        target.band = k4BandNumber(target.freqKHz!);
      case 'MD':
        if (!RegExp(r'^[1-79]$').hasMatch(params)) return;
        if (state.modeCode != params) {
          state.widthHz = state.centerHz = null;
          _send('BW${receiver.suffix};IS${receiver.suffix};');
        }
        state.modeCode = params;
        if (params == '6' || params == '9') {
          state.dataCode = null;
          _send('DT${receiver.suffix};');
        }
      case 'DT':
        if (!RegExp(r'^[0-3]$').hasMatch(params)) return;
        state.dataCode = params;
      case 'DV':
        if (params != '0' && params != '1') return;
        final changed = _diversity != null && _diversity != (params == '1');
        _diversity = params == '1';
        if (changed) {
          // Diversity copies mode/filter settings into B. AI4 omits our own
          // coupled changes, so cached B settings cannot describe the result.
          final secondary = _receivers[K4Receiver.sub]!;
          secondary.modeCode = secondary.dataCode = null;
          secondary.widthHz = secondary.centerHz = null;
          _readReceivers();
        }
      case 'SB':
        if (params != '0' && params != '1') return;
        _subOn = params == '1';
      case 'BW':
        final width = parseElecraftBandwidthParams(params);
        if (width == null) return;
        state.widthHz = width;
      case 'IS':
        final center = parseKenwoodShiftParams(params, k4: true);
        if (center == null) return;
        state.centerHz = center;
      case 'CW':
        final pitch = parseElecraftPitchParams(params);
        if (pitch == null) return;
        _cwPitchHz = pitch;
      case 'SM':
        final signal = parseK4Signal(command.params);
        if (signal == null) return;
        for (final facade in _facades.toList()) {
          if (facade._active && facade.receiver == signal.receiver) facade.sink.reportMeter(RadioMeter.signalDbm, signal.dbm);
        }
        return;
      default:
        return;
    }
    for (final facade in _facades.toList()) {
      _publish(facade);
    }
    _publishChannels();
  }

  void _publish(_K4ReceiverSession facade) {
    if (_disposed || !facade._active) return;
    final binding = _binding(facade.receiver);
    if (binding != null) {
      final state = _receivers[binding]!;
      final reading = VfoReading(freqKHz: state.freqKHz, mode: state.mode);
      if (reading.freqKHz != null || reading.mode != null) facade.sink.report(reading);
      if (_disposed || !facade._active) return;
      if (facade.sink case final PassbandSink sink) {
        sink.reportPassband(k4ReceiverPassband(mode: state.mode, widthHz: state.widthHz, centerHz: state.centerHz, cwPitchHz: _cwPitchHz));
      }
    }
    if (!_disposed && facade._active) {
      facade.sink.reportProblem(facade.receiver == K4Receiver.sub && _subOn == false ? t.settings.station.k4SubReceiverOff : _problem);
    }
  }

  void _readReceivers() => _send(r'FA;FB;MD;MD$;DT;DT$;BW;BW$;IS;IS$;');

  void _publishChannels() {
    final channels = [
      for (final receiver in K4Receiver.values)
        EquipmentChannel(
          key: receiver.name,
          label: k4ReceiverLabel(receiver.name),
          inUse: receiver == K4Receiver.main || _subOn == true,
          freqKHz: _receivers[_binding(receiver)]?.freqKHz,
          mode: _receivers[_binding(receiver)]?.mode,
        ),
    ];
    _broadcast((sink) => sink.reportChannels(channels));
  }

  void _broadcast(void Function(EquipmentSink) report) {
    for (final facade in _facades.toList()) {
      if (!_disposed && facade._active) report(facade.sink);
    }
  }

  void _remember(String key, void Function(EquipmentSink) report) {
    _global[key] = report;
    _broadcast(report);
  }

  void _spectrumDemand() {
    if (_disposed) return;
    final wanted = _facades.any((facade) => facade._spectrumWanted);
    if (!wanted) {
      _panEpoch++;
      final subscription = _panSubscription;
      _panSubscription = null;
      if (subscription != null) unawaited(subscription.cancel());
      return;
    }
    if (_panEnded) {
      _spectrumProblem(t.settings.station.spectrumK4RemoteUnavailable);
      return;
    }
    if (_panSubscription != null) return;
    final epoch = ++_panEpoch;
    bool current() => !_disposed && epoch == _panEpoch && _facades.any((facade) => facade._spectrumWanted);
    final subscription = _pan.listen(
      (packet) {
        if (!current()) return;
        for (final facade in _facades.toList()) {
          if (facade._spectrumWanted && facade.receiver.panId == packet.receiver) {
            facade._reportSpectrumProblem(null);
            if (!current() || !facade._spectrumWanted) continue;
            facade._presenter.add(centerHz: packet.centerHz, sampleRateHz: packet.sampleRateHz, levels: packet.levels);
          }
        }
      },
      onDone: () {
        if (!current()) return;
        _panEnded = true;
        _panSubscription = null;
        _spectrumProblem(t.settings.station.spectrumK4RemoteUnavailable);
      },
      onError: (Object error, StackTrace stack) {
        if (!current()) return;
        ErrorReportingService.report(error, stack, context: 'cat:k4-shared-spectrum');
        _spectrumProblem(t.settings.station.spectrumK4RemoteUnavailable);
      },
    );
    if (current() && !_panEnded) {
      _panSubscription = subscription;
    } else {
      unawaited(subscription.cancel());
    }
  }

  void _spectrumProblem(String message) {
    for (final facade in _facades.toList()) {
      if (!_disposed && facade._spectrumWanted) facade._reportSpectrumProblem(message);
    }
  }

  /// Only the physical owner's final release may tear down shared keying.
  void teardown() {
    if (_disposed || _closing) return;
    _closing = true;
    _radio.teardown();
    _disposed = true;
    _panEpoch++;
    for (final facade in _facades.toList()) {
      facade._active = false;
      facade._spectrumWanted = false;
      facade._presenter.stop();
      facade._disposed = true;
    }
    _facades.clear();
    final subscription = _panSubscription;
    _panSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _framer.reset();
    _global.clear();
  }

  // IF is the legacy operating/TX snapshot, not two independent RX readings.
  // Receiver state comes from FA/FB and MD/DT, including diversity binding.
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) => _remember('power', (sink) => sink.reportPower(watts));
  @override
  void reportTransmitting(bool transmitting) => _remember('tx', (sink) => sink.reportTransmitting(transmitting));
  @override
  void reportMeter(RadioMeter meter, num value) => _broadcast((sink) => sink.reportMeter(meter, value));
  @override
  void reportKeyerSpeed(int wpm) => _remember('speed', (sink) => sink.reportKeyerSpeed(wpm));
  @override
  void reportCwProgress(CwSendProgress? progress) {
    if (progress == null) _cwOwner = null;
    _remember('cw', (sink) => sink.reportCwProgress(progress));
  }

  @override
  void reportVoiceActivity(VoiceActivity? activity) {
    if (activity == null) _voiceOwner = null;
    _remember('voice', (sink) => sink.reportVoiceActivity(activity));
  }

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) => _remember('memories', (sink) => sink.reportVoiceMemories(memories));
  @override
  void reportDiagnostic(String? note) => _remember('diagnostic', (sink) => sink.reportDiagnostic(note));
  @override
  void reportProblem(String? message) {
    _problem = message;
    for (final facade in _facades.toList()) {
      _publish(facade);
    }
  }

  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() => _broadcast((sink) => sink.reportAlive());
}

class _ReceiverState {
  double? freqKHz;
  String? modeCode, dataCode;
  int? band, widthHz, centerHz;
  String? get mode => modeCode == null ? null : k4ModeForCodes(modeCode!, dataCode ?? '');
}
