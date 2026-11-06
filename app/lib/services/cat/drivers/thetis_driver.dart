// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Drives an Apache Labs ANAN through Thetis, the SDR program that runs it,
// over Thetis's TCP/IP CAT server and its `ZZ` command set — see
// thetis_codec.dart, which holds the protocol.
//
// NOT VERIFIED AGAINST A RUNNING THETIS. Written from the CAT reference
// that ships with it; the troubleshooting note asks for a report.
//
// Polled, never pushed. `ZZAI1` would have Thetis announce a dial turn, but
// only behind a checkbox in its Setup, and it would change a setting the
// operator's other CAT clients share — the same server answers N1MM or
// WSJT-X on the same machine. Over TCP a poll costs nothing worth saving.

import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../telemetry_poller.dart';
import 'cat_ascii_codec.dart';
import 'cw_send_queue.dart';
import 'poll_config.dart';
import 'rated_power_config.dart';
import 'telemetry_config.dart';
import 'thetis_codec.dart';

class ThetisDriver extends EquipmentDriver {
  const ThetisDriver();

  static const defaultPort = thetisDefaultPort;

  @override
  String get key => 'thetis';

  @override
  String get name => 'Thetis (ANAN)';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(thetisModeCodes.keys);

  /// Thetis's CWX keyer takes text over `ZZKY` on every ANAN.
  @override
  bool get canKeyCw => true;

  // No meters: `ZZRM` reads them, but the reference gives no unit for its
  // answer and says its SWR works only while tuning. The telemetry is the
  // TX watch alone.
  @override
  int get telemetryWatchBytes => thetisTxWatchBytes;

  @override
  int get telemetryCycleBytes => thetisTxWatchBytes;

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    ratedPowerConfigElement(),
    telemetryConfigElement(),
    pollConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    ratedWattsConfigKey => validateRatedWatts(value),
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    pollIntervalConfigKey => validatePollInterval(value),
    _ => null,
  };

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => ThetisSession(sink, config: config);
}

class ThetisSession implements ReadBackSession, PttSession, CwKeyerSession, RawCommandSession {
  final EquipmentSink _sink;
  final Map<String, dynamic> _config;

  /// What Thetis's drive percentage is a share of.
  final num _ratedWatts;

  final _framer = AsciiCatFramer();

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestState, slow: idlePollIntervalFor(_config));

  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: (_) => _send(buildThetisReadVfoStatusCommand()),
    idleInterval: telemetryIntervalFor(_config, cycleBytes: thetisTxWatchBytes),
    txInterval: telemetryIntervalFor(_config, cycleBytes: thetisTxWatchBytes),
  );

  /// What was last reported upward, so a repeat can be told from a move.
  VfoReading? _lastReported;

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  /// Whether Thetis has said its version on this connection — said once.
  bool _versionSaid = false;

  /// What CWX last said its speed is — the pace [_cwQueue] spaces chunks by.
  int? _keyerSpeed;

  /// `ZZKY` says only whether CWX's buffer is full, so the queue paces by
  /// arithmetic, as the Kenwood session does with `KY`.
  late final CwSendQueue _cwQueue = CwSendQueue(
    maxChunkLength: thetisKeyerMaxChars,
    send: (chunk) => _send(buildThetisSendCwCommand(chunk)),
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  ThetisSession(this._sink, {Map<String, dynamic> config = const {}}) : _config = config, _ratedWatts = ratedWattsFrom(config);

  /// The poller's current cadence — for tests.
  Duration get pollInterval => _poller.interval;

  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  void _send(String command) => _sink.send(ascii.encode(command));

  /// An extension's raw commands, written as given: every `ZZ` answer names
  /// its command, so none is taken for another's.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    _sink.send(bytes);
    return null;
  }

  // ------------------------------------------------------------- reading

  @override
  void handleData(Uint8List chunk) {
    _poller.noteData();
    for (final frame in _framer.add(ascii.decode(chunk, allowInvalid: true))) {
      final command = thetisCommandOf(frame);
      if (command != null) _handle(command.command, command.params);
    }
  }

  void _handle(String command, String params) {
    switch (command) {
      case 'ZZFA':
        final freqHz = parseThetisFrequencyParams(params);
        if (freqHz != null) _report(VfoReading(freqKHz: freqHz / 1000));
      case 'ZZMD':
        final mode = parseThetisModeParams(params);
        // A code with no app mode (DSB, SPEC, DRM) is reported as nothing,
        // so the mode last shown is not overwritten with a wrong one.
        if (mode != null) _report(VfoReading(mode: mode));
      case 'ZZPC':
        final level = parseThetisDriveParams(params);
        if (level != null) _sink.reportPower(wattsForDriveShare(level, ratedWatts: _ratedWatts));
      case 'ZZXV':
        final transmitting = parseThetisTransmittingParams(params);
        if (transmitting != null && _telemetry.noteTransmitting(transmitting)) _sink.reportTransmitting(transmitting);
      case 'ZZKS':
        final wpm = parseThetisKeyerSpeedParams(params);
        if (wpm != null) {
          _keyerSpeed = wpm;
          _sink.reportKeyerSpeed(wpm);
        }
      case 'ZZVN' when !_versionSaid:
        _versionSaid = true;
        _sink.reportDiagnostic('Thetis ${params.trim()}');
    }
    _sink.reportAlive();
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The first reading answers the question startUpdates asked; counting it
    // as movement would poll fast for a radio nobody is touching.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  void _requestState() {
    _send(buildThetisReadFrequencyCommand());
    _send(buildThetisReadModeCommand());
    _send(buildThetisReadDriveCommand());
  }

  // ------------------------------------------------------------ commands

  @override
  void readBack() => _poller.pollNow();

  @override
  void setFrequency(double freqKHz) => _send(buildThetisSetFrequencyCommand((freqKHz * 1000).round()));

  @override
  void setMode(String mode) {
    final command = buildThetisSetModeCommand(mode);
    if (command != null) _send(command);
  }

  /// Sets the drive, then reads it back, so the value shown is Thetis's.
  @override
  void setPower(num watts) {
    _send(buildThetisSetDriveCommand(watts, ratedWatts: _ratedWatts));
    _send(buildThetisReadDriveCommand());
  }

  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _send(buildThetisSetMoxCommand(on));
    _keyedByUs = on;
  }

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  /// Empties the queue, and stops CWX mid-character with `ZZSS`.
  @override
  void stopCw() {
    _cwQueue.clear();
    _send(buildThetisStopCwCommand());
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => thetisKeyerSpeedRange;

  /// Sets, then reads back, so the value shown is what CWX took.
  @override
  void setKeyerSpeed(int wpm) {
    _send(buildThetisSetKeyerSpeedCommand(wpm));
    _send(buildThetisReadKeyerSpeedCommand());
  }

  @override
  void refreshKeyerSpeed() => _send(buildThetisReadKeyerSpeedCommand());

  // ------------------------------------------------------------ lifetime

  @override
  void startUpdates() {
    _framer.reset();
    _versionSaid = false;
    _send(buildThetisReadVersionCommand());
    _requestState();
    // Once, not per poll: CWX's speed moves only when someone sets it, and
    // a surface that shows it asks again first.
    _send(buildThetisReadKeyerSpeedCommand());
    _poller.start();
    _telemetry.start();
  }

  @override
  void stopUpdates() {
    _poller.stop();
    _telemetry.stop();
  }

  @override
  void teardown() {
    if (_keyedByUs) {
      // First, and sent even though the connection is closing: nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _send(buildThetisSetMoxCommand(false));
    }
    _cwQueue.clear();
    stopUpdates();
    _framer.reset();
    _telemetry.dispose();
  }
}
