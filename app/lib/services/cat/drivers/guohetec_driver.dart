// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Drives a Guohetec Q900 (and, on the same protocol, a PMR-171) over its
// own control protocol rather than the FT-817 costume it also wears — see
// guohetec_codec.dart, which holds the protocol itself.
//
// NOT VERIFIED AGAINST HARDWARE. Written from the Q900 manual's Appendix 2;
// nothing here has been sent to a radio. The readings the manual does not
// state are marked in the codec, and the one with teeth is the PTT
// polarity.
//
// ## Why this is so much shorter than the Yaesu binary driver
//
// That protocol has no framing, so a reply means whatever the outstanding
// question says it means, and the driver is mostly a pump that keeps
// exactly one question in flight (yaesu_binary_driver.dart). This one is
// framed and checksummed: a packet says what it is, so commands go out as
// they are asked for and answers are matched by their command byte. There
// is nothing to serialise and no resync to run.
//
// ## The one hard constraint: there is no single-VFO command
//
// `0x09` sets BOTH frequencies and `0x0A` sets BOTH modes. So retuning the
// active VFO means transmitting a value for the other one too, and a
// session that does not know where the other VFO is would drag it — onto
// the active VFO's old frequency, or onto zero. Everything about
// [_lastStatus] and [_pendingFrequencyHz] exists for that: the session
// tunes only from a known pair, and holds a retune that arrives before the
// first status sync rather than guessing at the half it cannot see.

import 'package:flutter/foundation.dart';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'meter_calibration.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'guohetec_codec.dart';

/// What the radio's serial port runs at.
///
/// Only a default, and on the usual cable it is not even that: the Q900
/// presents a USB CDC port, which ignores the rate entirely — its manual
/// says as much, that "stop bit and baud rate do not need to be set". The
/// number matters on the radio's RS232 jack and on a Bluetooth SPP bridge,
/// and it is what the meter cadence budgets the wire against.
const guohetecDefaultBaudRate = 115200;

/// A meters exchange: eight bytes out, ten back. Both carry the four
/// preamble bytes, the length and the CRC that the payloads sit inside.
const guohetecMeterCycleBytes = 18;

/// The rated HF output this driver assumes when a catalogue entry does not
/// say — the Q900's own figure.
///
/// Only used to turn watts into the protocol's 0-100, which is why a wrong
/// value here shows up as a power setting that lands somewhere else on the
/// dial rather than as anything dangerous.
const guohetecAssumedMaxWatts = 20;

/// The config key naming a node's rated power, so [TransceiverSession.setPower]
/// can scale watts onto the radio's 0-100.
const guohetecMaxWattsConfigKey = 'maxWatts';

class GuohetecDriver extends EquipmentDriver {
  const GuohetecDriver();

  @override
  String get key => 'guohetec';

  @override
  String get name => 'Guohetec (Q900, PMR-171)';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(guohetecModeCodes.keys);

  /// This protocol has a keyer speed and a sidetone, but no command that
  /// keys TEXT — nothing that takes a message and sends it as CW. Nothing
  /// to declare.
  @override
  bool get canKeyCw => false;

  /// Supply voltage always, and whatever else a node's calibration table
  /// describes.
  ///
  /// Voltage needs no table and is not waiting for one: the protocol states
  /// its unit outright — one byte of tenths of a volt — so there is nothing
  /// left to calibrate, and it is the one reading that means something while
  /// the radio is merely receiving.
  ///
  /// The rest are a different case, and no table ships for them. The manual
  /// gives every one of those the same bare 0-34, says nothing about what
  /// any number means, and CONTRADICTS ITSELF over which of the two non-SWR
  /// scales is ALC (guohetec_codec.dart). An invented SWR would be measured
  /// against the threshold an operator is warned at.
  @override
  Set<RadioMeter> get telemetryMeters => telemetryMetersWith(const {});

  @override
  Set<RadioMeter> telemetryMetersWith(Map<String, dynamic> config) {
    final calibration = calibrationFor(config);
    return {
      RadioMeter.supplyVolts,
      if (calibration?.has(MeterTable.powerFraction) ?? false) RadioMeter.powerOut,
      if (calibration?.has(MeterTable.swr) ?? false) RadioMeter.swr,
    };
  }

  @override
  int get telemetryWatchBytes => guohetecMeterCycleBytes;

  @override
  int get telemetryCycleBytes => guohetecMeterCycleBytes;

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, meterInfoConfigKey, guohetecMaxWattsConfigKey};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    telemetryConfigElement(),
    pollConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    pollIntervalConfigKey => validatePollInterval(value),
    _ => null,
  };

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => GuohetecSession(sink, config: config);
}

class GuohetecSession implements ReadBackSession, PttSession, RawCommandSession {
  final EquipmentSink _sink;
  final Map<String, dynamic> _config;
  final String? _meterInfoKey;
  final num _maxWatts;

  /// Resolved per reading, not once: the tables load asynchronously, so a
  /// session that came up before they landed starts converting the moment
  /// they do. Snapshotting this at construction leaves an auto-connect at
  /// startup reporting no meters for the whole life of that connection.
  MeterCalibration? get _calibration => MeterCalibrations.instance[_meterInfoKey];

  final _framer = GuohetecFramer();

  /// The radio volunteers nothing: this protocol has no auto-information,
  /// so a dial turn is only ever seen by asking.
  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestStatus, slow: idlePollIntervalFor(_config));

  /// Both cadences read the same packet — the meters command carries the
  /// transmit flag and the readings together, so watching costs exactly
  /// what reading does.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: (_) => _send(buildMetersCommand()),
    idleInterval: telemetryIntervalFor(_config, cycleBytes: guohetecMeterCycleBytes, baudRate: serialBaudRateOrNull(_config)),
    txInterval: telemetryIntervalFor(_config, cycleBytes: guohetecMeterCycleBytes, baudRate: serialBaudRateOrNull(_config)),
  );

  /// The last complete picture of the radio.
  ///
  /// Load-bearing, not a cache: it is the only source for the OTHER VFO's
  /// frequency and mode, which every retune has to send — see the file
  /// header.
  GuohetecStatus? _lastStatus;

  /// A retune or mode change that arrived before the first status sync.
  ///
  /// Held rather than sent, because sending it would mean inventing the
  /// other VFO. Applied by the first status that arrives, which is normally
  /// milliseconds away — [startUpdates] asks for one immediately.
  int? _pendingFrequencyHz;
  String? _pendingMode;

  /// What was last reported upward, so a repeat can be told from a move.
  VfoReading? _lastReported;

  /// Whether the app keyed the radio, so [teardown] can unkey it. A logger
  /// that disconnects while the transmitter is on leaves a radio keyed into
  /// an antenna with nothing left to turn it off.
  bool _keyedByUs = false;

  /// Whether any packet has ever passed its CRC on this connection.
  ///
  /// Paired with the framer's failure count to diagnose the one failure
  /// this codec's provenance makes likely: the CRC is inferred from the
  /// manual's C listing, and if that inference is wrong then EVERY packet
  /// fails and the session looks simply dead. Said once, not per packet.
  bool _everFramed = false;
  bool _saidCrcFailing = false;

  GuohetecSession(this._sink, {Map<String, dynamic> config = const {}})
    : _config = config,
      _meterInfoKey = config[meterInfoConfigKey] as String?,
      _maxWatts = _ratedWatts(config[guohetecMaxWattsConfigKey]);

  /// The node's rated output, however a stored config spells it.
  ///
  /// A `cast` here would throw out of the CONSTRUCTOR, taking down the
  /// session rather than the setting — and config arrives from stored JSON,
  /// where a number that was once typed into a text field is a string. Zero
  /// and negatives fall back too: they are not a radio's rating, and
  /// [setPower] divides by this.
  static num _ratedWatts(dynamic raw) {
    final value = raw is num ? raw : (raw is String ? num.tryParse(raw.trim()) : null);
    return (value != null && value > 0) ? value : guohetecAssumedMaxWatts;
  }

  /// The poller's current cadence — for tests, which could otherwise only
  /// infer it from timing.
  Duration get pollInterval => _poller.interval;

  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  void _send(List<int> bytes) => _sink.send(bytes);

  /// An extension's raw packets, written as given: every answer is framed and
  /// names its command byte, so none is taken for another's.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    _send(bytes);
    return null;
  }

  // ------------------------------------------------------------- reading

  @override
  void handleData(Uint8List chunk) {
    for (final frame in _framer.add(chunk)) {
      _everFramed = true;
      _deliver(frame);
    }
    _checkCrcHealth();
  }

  /// Says once, and only once, that nothing on this connection has ever
  /// checksummed — which on this protocol has one likely cause and one fix.
  void _checkCrcHealth() {
    if (_everFramed || _saidCrcFailing || _framer.crcFailures == 0) return;
    _saidCrcFailing = true;
    final note =
        'every packet fails its CRC (${_framer.crcFailures} so far) — '
        'the radio checksums differently than the manual describes';
    _sink.reportDiagnostic(note);
    debugPrint('[cat] guohetec $note');
  }

  void _deliver(GuohetecFrame frame) {
    switch (frame.command) {
      case GuohetecOpcode.statusSync:
        final status = parseStatus(frame.data);
        // The CRC has already passed, so a payload this cannot read means
        // the firmware disagrees with the manual about the packet's shape.
        // Reporting the fields it would decode puts a frequency together
        // out of whatever bytes happen to be there.
        if (status == null) {
          _sink.reportDiagnostic('unreadable status packet (${frame.data.length} bytes)');
          return;
        }
        _applyStatus(status);

      case GuohetecOpcode.meters:
        // Transmit power / S-meter, then SWR/AUD/ALC — the same two bytes
        // the status packet ends with.
        if (frame.data.length < 2) return;
        final signal = parseSignalMeter(frame.data[0]);
        // Which scale the radio answers on follows the PTT, so this packet
        // reports the transmit state as surely as the status packet does —
        // and it is the only one on the fast cadence. Read BOTH ways, not
        // just the keying: an S-scale byte is the radio saying it is
        // receiving, and treating it as merely "no evidence of transmit"
        // leaves the flag latched on until the slow status poll comes
        // round, with the meter cycle running and the TX indicator lit for
        // seconds after the operator let go.
        final transmitting = signal.scale == GuohetecMeterScale.power;
        if (_telemetry.noteTransmitting(transmitting)) {
          _sink.reportTransmitting(transmitting);
        }
        _applyMeters(signal, parseSwrMeter(frame.data[1]));

      case GuohetecOpcode.equipmentType:
        if (frame.data.isEmpty) return;
        // Named rather than assumed: the manual lists one value, and a
        // radio answering anything else is a model this driver has never
        // been told about — most likely a PMR-171, which shares the
        // protocol. Worth a developer seeing which.
        _sink.reportDiagnostic(
          frame.data.first == GuohetecEquipmentType.q900
              ? 'radio identifies as Q900'
              : 'radio reports unknown equipment type 0x${frame.data.first.toRadixString(16)}',
        );

      // Every other packet here answers a set command, and the radio has
      // already acted on it. Nothing to read out: what the app shows comes
      // from the next status sync, never from the fact that a write was
      // accepted.
      default:
        _sink.reportAlive();
    }
  }

  void _applyStatus(GuohetecStatus status) {
    _lastStatus = status;

    // This packet's own transmit field decides, and nothing after it in
    // this method may revisit that: the meter byte carries the same fact as
    // an inference, and letting the inference run second would make it the
    // winner on every status packet — flapping the flag that gates antenna
    // relays whenever the two disagree.
    if (_telemetry.noteTransmitting(status.transmitting)) {
      _sink.reportTransmitting(status.transmitting);
    }

    // Needs no calibration table, so it is reported whatever else is
    // missing — see [GuohetecDriver.telemetryMeters].
    _sink.reportMeter(RadioMeter.supplyVolts, status.voltageVolts);
    _applyMeters(status.signalMeter, status.swrMeter);
    _flushPending();

    _report(VfoReading(freqKHz: status.activeFreqHz / 1000, mode: status.activeMode));
  }

  /// Reports the two calibrated meters, and NOTHING about the transmit
  /// state — each caller has already settled that from its own packet, and
  /// a second opinion here would overrule the one with better evidence.
  void _applyMeters(GuohetecMeterReading signal, GuohetecMeterReading? swr) {
    final calibration = _calibration;
    // No table means no meters — see [GuohetecDriver.telemetryMeters].
    if (calibration == null) return;

    if (signal.scale == GuohetecMeterScale.power) {
      final fraction = calibration.convert(MeterTable.powerFraction, signal.raw);
      if (fraction != null) _sink.reportMeter(RadioMeter.powerOut, fraction * _maxWatts);
    }
    if (swr != null && swr.scale == GuohetecMeterScale.swr) {
      final ratio = calibration.convert(MeterTable.swr, swr.raw);
      if (ratio != null) _sink.reportMeter(RadioMeter.swr, ratio);
    }
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    // The FIRST reading is not the radio moving — it is the answer to the
    // question startUpdates just asked. Treating it as movement would drop
    // every connection into fast polling for the second or so it takes to
    // ramp back, for a radio nobody is touching.
    final first = _lastReported == null;
    if (reading != _lastReported) {
      _lastReported = reading;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  void _requestStatus() => _send(buildStatusSyncCommand());

  // ------------------------------------------------------------ commands

  /// Sends whatever was asked for before the radio's state was known.
  ///
  /// Frequency and mode are applied in that order and independently: an
  /// operator who set both gets both, and one who set only a mode does not
  /// have a frequency invented for them.
  void _flushPending() {
    final freqHz = _pendingFrequencyHz;
    final mode = _pendingMode;
    _pendingFrequencyHz = null;
    _pendingMode = null;
    if (freqHz != null) _tuneTo(freqHz);
    if (mode != null) _setModeNow(mode);
  }

  /// Retunes the ACTIVE VFO, carrying the other one through untouched.
  ///
  /// The carried-through value is whatever the last status said, and stays
  /// that even after a retune of our own: the slot we write is always the
  /// caller's new frequency, and the slot we carry is one only the operator
  /// can move. Predicting either would mean reporting a frequency the radio
  /// never confirmed.
  void _tuneTo(int freqHz) {
    final status = _lastStatus;
    if (status == null) {
      _pendingFrequencyHz = freqHz;
      return;
    }
    final vfoAHz = status.vfoBActive ? status.vfoAHz : freqHz;
    final vfoBHz = status.vfoBActive ? freqHz : status.vfoBHz;
    _send(buildSetFrequenciesCommand(vfoAHz: vfoAHz, vfoBHz: vfoBHz));
  }

  void _setModeNow(String mode) {
    final status = _lastStatus;
    if (status == null) {
      _pendingMode = mode;
      return;
    }
    final vfoAMode = status.vfoBActive ? status.vfoAMode : mode;
    final vfoBMode = status.vfoBActive ? mode : status.vfoBMode;
    final command = buildSetModesCommand(vfoAMode: vfoAMode, vfoBMode: vfoBMode);
    // Null when either VFO's mode has no code here — including the case
    // where the OTHER VFO is sitting in a mode this driver cannot name, so
    // the command that would carry it cannot be built without inventing
    // one. Sending nothing leaves the radio where it is; sending a guess
    // moves a VFO the operator did not touch.
    if (command == null) {
      _sink.reportDiagnostic('cannot set mode $mode without a code for the other VFO');
      return;
    }
    _send(command);
  }

  @override
  void readBack() => _poller.pollNow();

  @override
  void setFrequency(double freqKHz) => _tuneTo((freqKHz * 1000).round());

  @override
  void setMode(String mode) => _setModeNow(mode);

  /// Sets RF output as the protocol's 0-100.
  ///
  /// UNVERIFIED: the manual gives the range and never the unit. Read as a
  /// percentage of the radio's rated output, which is the only reading that
  /// makes 0-100 mean the same thing on a 20 W Q900 and a 20 W PMR-171. If
  /// it is really watts, this lands low rather than high — the safe way to
  /// be wrong about a power command.
  @override
  void setPower(num watts) {
    final percent = ((watts / _maxWatts) * 100).round().clamp(0, 100);
    _send(buildPowerLevelCommand(percent));
  }

  /// Keys or unkeys the transmitter over CAT.
  ///
  /// Tracked ([_keyedByUs]) so [teardown] can put it back: this protocol
  /// has no dead-man's switch, and a disconnect with the transmitter on
  /// leaves a keyed radio and nothing to unkey it.
  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _send(buildPttCommand(on));
    _keyedByUs = on;
  }

  // ------------------------------------------------------------ lifetime

  @override
  void startUpdates() {
    // Which model is answering, once. It costs one exchange and it is the
    // difference between a developer reading "radio identifies as Q900" and
    // guessing at why a PMR-171 behaves differently.
    _send(buildEquipmentTypeCommand());
    _requestStatus();
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
    stopUpdates();
    if (_keyedByUs) {
      // Sent even though the connection is closing: nothing else will
      // unkey this radio.
      _keyedByUs = false;
      _send(buildPttCommand(false));
    }
    _framer.reset();
    _telemetry.dispose();
  }
}
