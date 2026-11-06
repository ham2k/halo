// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Drives a radio through a TCI server — Thetis for an Apache Labs ANAN,
// ExpertSDR3 for a SunSDR — over the WebSocket transport. tci_codec.dart
// holds the protocol, tci_spectrum.dart the scope.
//
// NOT VERIFIED AGAINST A RUNNING SERVER. Written from the TCI 2.1 spec; the
// troubleshooting note asks for a report.
//
// Pushed, never polled: the server sends every change to every client, and
// a set from one client to all of them. What this session sends on its own
// is a read of the VFO every [_resyncEvery], so a server with nothing to
// say still answers inside the app's silence window (`catStaleAfter`).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../driver.dart';
import '../equipment.dart';
import '../spectrum.dart';
import 'cw_send_queue.dart';
import 'rated_power_config.dart';
import 'tci_codec.dart';
import 'tci_spectrum.dart';

/// Well inside `catStaleAfter` (30 s), with room for a lost answer.
const _resyncEvery = Duration(seconds: 10);

class TciDriver extends EquipmentDriver {
  const TciDriver();

  static const defaultPort = tciDefaultPort;

  @override
  String get key => 'tci';

  @override
  String get name => 'TCI';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(tciSettableModes);

  @override
  bool get canKeyCw => true;

  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.signalDbm, RadioMeter.powerOut, RadioMeter.swr};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey(ratedWattsConfigKey)) ratedPowerConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => key == ratedWattsConfigKey ? validateRatedWatts(value) : null;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => TciSession(sink, config: config);
}

class TciSession implements TransceiverSession, PttSession, CwKeyerSession, RawCommandSession, SpectrumSession {
  final EquipmentSink _sink;

  /// What `DRIVE`'s 0–100 is a share of.
  final num _ratedWatts;

  final _framer = TciFramer();

  late final TciSpectrum _spectrum = TciSpectrum(
    send: _send,
    sink: switch (_sink) {
      final SpectrumSink sink => sink,
      _ => null,
    },
    frames: switch (_sink) {
      final BinaryFramesSink sink => sink.binaryFrames,
      _ => null,
    },
  );

  Timer? _resync;

  /// The server's `MODULATIONS_LIST`, its own spelling of each mode.
  List<String> _modulations = const [];

  String? _program;
  String? _protocolVersion;
  String? _device;

  /// Said once a connection, on `READY`.
  bool _identified = false;

  /// `TRX` and `TUNE` as last pushed: either is RF on the air.
  bool? _trx;
  bool? _tune;
  bool? _reportedOnAir;

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  int? _keyerSpeed;

  /// The server queues macros itself, so a message goes whole and the queue
  /// only estimates when it is done, for the progress the status bar shows.
  late final CwSendQueue _cwQueue = CwSendQueue(
    maxChunkLength: tciCwMaxChars,
    send: (chunk) => _send(buildTciSendCwCommand(chunk)),
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  TciSession(this._sink, {Map<String, dynamic> config = const {}}) : _ratedWatts = ratedWattsFrom(config);

  /// Pushed: a change is reported as it happens.
  @override
  Duration? get expectedUpdateInterval => null;

  void _send(String command) => _sink.send(utf8.encode(command));

  /// An extension's raw commands, written as given: every TCI answer names
  /// its command, so none is taken for another's.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    _sink.send(bytes);
    return null;
  }

  // ------------------------------------------------------------- reading

  @override
  void handleData(Uint8List chunk) {
    for (final command in _framer.add(utf8.decode(chunk, allowMalformed: true))) {
      _handle(command);
      _sink.reportAlive();
    }
  }

  void _handle(TciCommand command) {
    final args = command.args;
    // Every state command names the receiver first; another receiver's is
    // another node's business.
    bool ours(int index) => args.length > index && int.tryParse(args[0]) == tciReceiver;
    switch (command.name) {
      case 'vfo' when ours(2) && int.tryParse(args[1]) == tciChannel:
        if (int.tryParse(args[2]) case final hz? when hz > 0) _sink.report(VfoReading(freqKHz: hz / 1000));
      case 'modulation' when ours(1):
        // A mode with no app name (DSB, DRM) is reported as nothing, so the
        // mode last shown is not overwritten with a wrong one.
        if (tciModeFor(args[1]) case final mode?) _sink.report(VfoReading(mode: mode));
      case 'trx' when ours(1):
        _trx = tciBool(args[1]);
        _reportOnAir();
      case 'tune' when ours(1):
        _tune = tciBool(args[1]);
        if (_sink case final TuneCarrierSink sink) sink.reportTuneCarrier(_tune!);
        _reportOnAir();
      case 'drive' when ours(1):
        if (int.tryParse(args[1]) case final share? when share >= 0 && share <= 100) {
          _sink.reportPower(wattsForDriveShare(share, ratedWatts: _ratedWatts));
        }
      case 'cw_macros_speed' when args.isNotEmpty:
        if (int.tryParse(args[0]) case final wpm? when wpm >= tciKeyerSpeedRange.min && wpm <= tciKeyerSpeedRange.max) {
          _keyerSpeed = wpm;
          _sink.reportKeyerSpeed(wpm);
        }
      case 'rx_sensors' when ours(1):
        if (double.tryParse(args[1]) case final dbm? when dbm.isFinite) _sink.reportMeter(RadioMeter.signalDbm, dbm);
      case 'tx_sensors' when ours(4):
        // Read only on the air: what a transmitter "puts out" while
        // receiving is noise, and an SWR from it could raise the alarm.
        if (_reportedOnAir != true) break;
        if (double.tryParse(args[2]) case final watts? when watts.isFinite && watts >= 0) _sink.reportMeter(RadioMeter.powerOut, watts);
        if (double.tryParse(args[4]) case final swr? when swr.isFinite && swr >= 1) _sink.reportMeter(RadioMeter.swr, swr);
      case 'dds' when ours(1):
        if (int.tryParse(args[1]) case final hz?) _spectrum.dds(hz);
      case 'modulations_list':
        _modulations = [
          for (final name in args)
            if (name.isNotEmpty) name,
        ];
      case 'protocol' when args.length >= 2:
        _program = args[0];
        _protocolVersion = args[1];
      case 'device' when args.isNotEmpty:
        _device = args[0];
      case 'ready' when !_identified:
        _identified = true;
        _sink.reportDiagnostic(['TCI', ?_program, ?_protocolVersion, if (_device case final device?) '· $device'].join(' '));
    }
  }

  void _reportOnAir() {
    final onAir = (_trx ?? false) || (_tune ?? false);
    if (onAir == _reportedOnAir) return;
    _reportedOnAir = onAir;
    _sink.reportTransmitting(onAir);
  }

  // ------------------------------------------------------------ commands

  @override
  void setFrequency(double freqKHz) => _send(buildTciSetVfoCommand((freqKHz * 1000).round()));

  @override
  void setMode(String mode) {
    final command = buildTciSetModulationCommand(mode, offered: _modulations);
    if (command != null) _send(command);
  }

  /// Sets the drive, then reads it back: a set inside another client's
  /// 200 ms hold on the parameter is dropped, and the read shows what held.
  @override
  void setPower(num watts) {
    _send(buildTciSetDriveCommand(driveShareFor(watts, ratedWatts: _ratedWatts)));
    _send(buildTciReadDriveCommand());
  }

  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _send(buildTciSetTrxCommand(on));
    _keyedByUs = on;
  }

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  @override
  void stopCw() {
    _cwQueue.clear();
    _send(buildTciStopCwCommand());
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => tciKeyerSpeedRange;

  @override
  void setKeyerSpeed(int wpm) {
    _send(buildTciSetKeyerSpeedCommand(wpm));
    _send(buildTciReadKeyerSpeedCommand());
  }

  @override
  void refreshKeyerSpeed() => _send(buildTciReadKeyerSpeedCommand());

  // ------------------------------------------------------------ spectrum

  @override
  String? get spectrumUnavailable => null;

  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum.capabilities;

  @override
  void startSpectrum() => _spectrum.start();

  @override
  void stopSpectrum() => _spectrum.stop();

  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum.set(request);

  // ------------------------------------------------------------ lifetime

  @override
  void startUpdates() {
    _framer.reset();
    _identified = false;
    // The server sends its state on connect unasked; these reads cover a
    // server that sends less, and are answered like any change.
    for (final read in [
      buildTciReadVfoCommand(),
      buildTciReadModulationCommand(),
      buildTciReadDriveCommand(),
      buildTciReadTrxCommand(),
      buildTciReadTuneCommand(),
      buildTciReadKeyerSpeedCommand(),
      buildTciReadDdsCommand(),
    ]) {
      _send(read);
    }
    _send(buildTciRxSensorsCommand(true));
    _send(buildTciTxSensorsCommand(true));
    _resync?.cancel();
    _resync = Timer.periodic(_resyncEvery, (_) => _send(buildTciReadVfoCommand()));
  }

  @override
  void stopUpdates() {
    _resync?.cancel();
    _resync = null;
  }

  @override
  void teardown() {
    if (_keyedByUs) {
      // First, and sent even though the connection is closing: nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _send(buildTciSetTrxCommand(false));
    }
    _cwQueue.clear();
    _spectrum.teardown();
    // The meters are per client, but a server that outlives this socket
    // need not keep timing them for nobody.
    _send(buildTciRxSensorsCommand(false));
    _send(buildTciTxSensorsCommand(false));
    stopUpdates();
    _framer.reset();
  }
}
