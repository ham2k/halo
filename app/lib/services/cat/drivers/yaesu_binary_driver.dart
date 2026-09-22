// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks the five-byte binary CAT of the FT-817/818, FT-857 and FT-897 —
// see yaesu_binary_codec.dart, which holds the protocol itself. Like every
// driver here it deals only in already-framed bytes handed to it by a
// transport, in practice a serial port behind a CT-62-style adapter on the
// radio's ACC/CAT jack.
//
// NOT VERIFIED AGAINST HARDWARE. Written from Yaesu's own published CAT
// chart; nothing in it has been sent to a radio. The two places that
// matters most are called out where they are: the PTT bit's polarity
// (yaesu_binary_codec.dart) and whether Set Frequency acknowledges.
//
// ## Why this file is mostly a request pump
//
// This protocol has no framing at all — no preamble, no terminator, no
// length, and no echo of the command. A reply is bare bytes, and the ONLY
// thing that says what they mean is which question is outstanding. Two
// questions in flight at once and a one-byte status answer becomes the
// first digit pair of a frequency, which decodes as a plausible frequency
// and retunes nothing but the app's idea of where the radio is.
//
// So the session sends ONE command at a time and waits for exactly the
// number of bytes that command's answer is: [_pump]. That costs nothing
// here — a whole exchange is ten bytes, 21 ms at 4800 baud — and it is what
// makes every other guarantee in this file possible. The two failure modes
// it has to survive are both silent:
//
//   - a radio that answers with FEWER bytes than expected (a command it
//     does not implement, a set command that does not ack) would leave the
//     pump waiting forever, so every request has a deadline and the pump
//     moves on when it expires;
//   - a byte arriving with nothing outstanding is line noise or the tail of
//     an abandoned answer, and is DISCARDED rather than buffered — buffering
//     it would offset every later reply by one byte for the life of the
//     connection.
//
// The deadline is between BYTES, not around the whole answer, and giving up
// on one puts the pump into a resync ([_resyncing]) rather than straight
// into the next command. Both exist for the same case, which is the nastiest
// one here: an answer that arrives in pieces and stalls halfway. Deadlined
// as a whole, a radio spacing its bytes at the 200 ms the chart allows is
// abandoned mid-answer every time; and sending the next command while three
// bytes of the last answer are still in flight hands those bytes to it —
// `56` read as a TX status is a receiving radio reported as KEYED, which is
// a reading that gates antenna relays.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'telemetry_config.dart';
import 'yaesu_binary_codec.dart';

/// What the radio's CAT RATE menu ships set to across all three models
/// (FT-817 menu #14, FT-857/FT-897 menu #19). Only a default: a radio set
/// to 9600 or 38400 answers with nothing at all, and nothing anywhere
/// reports why.
const yaesuBinaryDefaultBaudRate = 4800;

/// Read TX Status: five bytes out, one back.
const yaesuBinaryTxWatchBytes = 6;

/// How long the pump waits for the NEXT byte of an answer — from the
/// command going out, and re-armed by every byte that arrives.
///
/// Per byte rather than per answer because Yaesu's own chart allows 200 ms
/// between the bytes of a command: a five-byte answer at that spacing takes
/// 800 ms, and a deadline around the whole thing would abandon a radio that
/// was answering perfectly well, every time. Generous against the wire time
/// it covers — a ten-byte exchange at 4800 baud is 21 ms — because what it
/// is really waiting out is a radio that will never answer at all, and the
/// cost of being slow about that is one deferred poll.
const yaesuBinaryReplyTimeout = Duration(milliseconds: 500);

/// How long the line must be quiet before the pump trusts it again, after
/// giving up on an answer.
///
/// The abandoned answer's remaining bytes are still coming, and they are
/// indistinguishable from the next answer — so nothing is sent until the
/// radio has stopped talking, and everything that arrives meanwhile is
/// dropped. Without this the pump recovers from a stall by handing the
/// stall's tail to the next command.
const yaesuBinaryResyncQuietTime = Duration(milliseconds: 500);

/// How many requests may wait behind the one in flight.
///
/// A radio that has stopped answering still has pollers enqueueing at it,
/// and an unbounded queue would spend the whole connection sending
/// questions whose answers are already stale. Reads are dropped at the cap
/// and writes never are — a retune the operator asked for must not be lost
/// to a backlog of status polls.
const yaesuBinaryMaxQueued = 8;

/// The config key for the bench capture — see [YaesuBinaryDriver]'s config
/// field. Its own key rather than the ASCII line's, because it captures a
/// different number: this protocol's PO meter is a 0-15 nibble, not `RM`'s
/// 0-255.
const yaesuBinaryMeterCaptureConfigKey = 'yaesuBinaryMeterCapture';

/// The config key naming which model this node is, so the session knows
/// whether the radio has the FT-857/FT-897 narrow-FM set code. Pinned per
/// catalogue entry and never shown as a field: which radio a named entry is
/// for is a fact about the entry, not a setting anyone should be asked for.
const yaesuBinaryNarrowFmConfigKey = 'yaesuBinaryNarrowFm';

class YaesuBinaryDriver extends EquipmentDriver {
  const YaesuBinaryDriver();

  @override
  String get key => 'yaesu-binary';

  @override
  String get name => 'Yaesu FT-817/857/897 CAT';

  /// This protocol has no keyer command and no voice memory command: the
  /// chart's seventeen opcodes are frequency, mode, PTT, repeater and tone
  /// settings, and the two status reads. Nothing to declare.
  @override
  bool get canKeyCw => false;

  /// Nothing: the PO meter is a raw 0-15 with no published scale, and HI
  /// SWR is one bit rather than a ratio — neither is a number the panel
  /// could show. What a node CAN do with them is the capture below, which
  /// is what a scale would have to be built from.
  @override
  Set<RadioMeter> get telemetryMeters => const {};

  @override
  int get telemetryWatchBytes => yaesuBinaryTxWatchBytes;

  /// The same: the PO reading and the SWR flag arrive inside the TX status
  /// byte this driver already reads, so transmitting costs exactly what
  /// receiving does.
  @override
  int get telemetryCycleBytes => yaesuBinaryTxWatchBytes;

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, yaesuBinaryNarrowFmConfigKey};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    // Developer mode only, and off by default: it puts a line of raw
    // numbers on screen that only a developer can use. It exists to
    // BUILD the scale that would make the PO nibble a wattage, not to
    // be a feature.
    {
      'type': 'field',
      'fieldType': 'checkbox',
      'key': yaesuBinaryMeterCaptureConfigKey,
      'label': t.settings.station.yaesuMeterCapture,
      'description': t.settings.station.yaesuBinaryMeterCaptureDescription,
      'devMode': true,
    },
    telemetryConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    _ => null,
  };

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => YaesuBinarySession(sink, config: config);
}

class YaesuBinarySession implements TransceiverSession {
  final EquipmentSink _sink;
  final Map<String, dynamic> _config;

  /// Whether this radio takes the FT-857/FT-897 narrow-FM set code.
  final bool _narrowFm;

  /// Whether to print what the TX status byte carries, raw — the bench
  /// switch a scale would be built from.
  final bool _captureMeters;

  /// The radio answers nothing on its own: this protocol has no
  /// auto-information, so the poll is not a backstop the way it is on the
  /// ASCII line — it is the only way a dial turn is ever seen.
  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode);

  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: (_) => _request(readTransmitStatusCommand),
    idleInterval: telemetryIntervalFor(_config, cycleBytes: yaesuBinaryTxWatchBytes, baudRate: serialBaudRateOrNull(_config)),
    txInterval: telemetryIntervalFor(_config, cycleBytes: yaesuBinaryTxWatchBytes, baudRate: serialBaudRateOrNull(_config)),
  );

  /// What was last reported upward, so a repeat can be told from a move.
  VfoReading? _lastReported;

  /// Whether the app keyed the radio, so [teardown] can unkey it. A logger
  /// that disconnects while the transmitter is on leaves a radio keyed into
  /// an antenna with nothing left to turn it off.
  bool _keyedByUs = false;

  final _queue = Queue<YaesuBinaryCommand>();
  YaesuBinaryCommand? _inFlight;
  final _reply = <int>[];
  Timer? _deadline;

  /// Waiting out the tail of an answer we gave up on — see
  /// [yaesuBinaryResyncQuietTime]. Nothing is sent and nothing is read
  /// while this is armed.
  Timer? _resyncing;

  YaesuBinarySession(this._sink, {Map<String, dynamic> config = const {}})
    : _config = config,
      _narrowFm = config[yaesuBinaryNarrowFmConfigKey] == true,
      _captureMeters = config[yaesuBinaryMeterCaptureConfigKey] == true;

  /// The poller's current cadence — for tests, which could otherwise only
  /// infer it from timing.
  Duration get pollInterval => _poller.interval;

  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  // ---------------------------------------------------------------- pump

  /// Queues one exchange. Reads are dropped at [yaesuBinaryMaxQueued] and
  /// writes are not — see that constant.
  void _request(YaesuBinaryCommand command, {bool isWrite = false}) {
    if (!isWrite && _queue.length >= yaesuBinaryMaxQueued) return;
    _queue.add(command);
    _pump();
  }

  void _pump() {
    if (_inFlight != null || _resyncing != null || _queue.isEmpty) return;
    final command = _queue.removeFirst();
    // Whatever is left in the buffer belongs to a request that is over.
    // Carrying it into this one would offset every byte of the answer.
    _reply.clear();
    _sink.send(command.bytes);
    _inFlight = command;
    _armDeadline(command);
  }

  void _armDeadline(YaesuBinaryCommand command) {
    _deadline?.cancel();
    _deadline = Timer(yaesuBinaryReplyTimeout, () => _abandon(command));
  }

  void _abandon(YaesuBinaryCommand command) {
    if (!identical(_inFlight, command)) return;
    // A tolerated missing acknowledgement is not news — see
    // [YaesuBinaryCommand.replyOptional]. Anything else is a radio that
    // did not answer a question the chart says it answers, which is what a
    // developer looking at a silent rig needs to see.
    if (!command.replyOptional) {
      _sink.reportDiagnostic('no answer to opcode 0x${command.bytes.last.toRadixString(16)}');
    }
    _clearInFlight();
    _startResync();
  }

  /// Holds the pump until the radio has been quiet for
  /// [yaesuBinaryResyncQuietTime], re-armed by anything that arrives.
  void _startResync() {
    _resyncing?.cancel();
    _resyncing = Timer(yaesuBinaryResyncQuietTime, () {
      _resyncing = null;
      _pump();
    });
  }

  void _clearInFlight() {
    _deadline?.cancel();
    _deadline = null;
    _inFlight = null;
    _reply.clear();
  }

  void _finish() {
    _clearInFlight();
    _pump();
  }

  @override
  void handleData(Uint8List chunk) {
    // The tail of an answer we gave up on, still arriving. Dropped, and it
    // pushes the quiet window out: the pump stays silent until the radio
    // has actually stopped talking.
    if (_resyncing != null) {
      _startResync();
      return;
    }

    final command = _inFlight;
    // Nothing outstanding: line noise, or a byte the radio sent late enough
    // that even the resync had ended. Dropped rather than kept — see the
    // file header on why buffering it is the one unrecoverable mistake.
    if (command == null) return;

    _reply.addAll(chunk);
    // The radio is mid-answer, so the deadline starts again — see
    // [yaesuBinaryReplyTimeout].
    if (_reply.length < command.replyLength) {
      _armDeadline(command);
      return;
    }

    final reply = _reply.sublist(0, command.replyLength);
    // A radio that sent MORE than the answer is out of step with us, and
    // the surplus is dropped with the rest of the buffer by [_finish].
    _finish();
    _deliver(command, reply);
  }

  void _deliver(YaesuBinaryCommand command, List<int> reply) {
    // [AdaptivePoller.noteData] is deliberately never called. It defers the
    // next poll on the grounds that the radio just VOLUNTEERED something —
    // and this protocol has no unsolicited traffic at all, so every byte
    // that arrives is an answer to a question of ours. Feeding the TX
    // watch's answers to it would re-arm the poll timer several times a
    // second, and the frequency would only ever arrive on the poller's
    // staleness ceiling: a dial turn taking nine seconds to reach the app,
    // on a radio where the poll is the only source there is.
    switch (command.bytes.last) {
      case YaesuBinaryOpcode.readFrequencyAndMode:
        final reading = parseFrequencyAndMode(reply);
        // Unreadable BCD is a reply this session is out of step with; the
        // frequency it would decode to is arbitrary, and reporting it
        // would move the app's idea of the radio to somewhere it is not.
        if (reading == null) {
          _sink.reportDiagnostic('unreadable frequency reply');
          return;
        }
        _report(VfoReading(freqKHz: reading.freqHz / 1000, mode: reading.mode));

      case YaesuBinaryOpcode.readTransmitStatus:
        final status = parseTransmitStatus(reply.first);
        if (_telemetry.noteTransmitting(status.transmitting)) {
          _sink.reportTransmitting(status.transmitting);
        }
        if (status.transmitting) _captureTransmitStatus(status);

      // Every other opcode here is a set command, whose answer is an
      // acknowledgement the radio has already acted on. Nothing to read
      // out of it: the frequency the app shows comes from the next poll,
      // never from the fact that a write was accepted.
      default:
        _sink.reportAlive();
    }
  }

  void _captureTransmitStatus(YaesuBinaryTransmitStatus status) {
    if (!_captureMeters) return;
    final note = 'TX PO=${status.powerOut} SWR=${status.highSwr ? 'HIGH' : 'ok'}';
    _sink.reportDiagnostic(note);
    // Also on the console, which is where a capture is actually read from:
    // the diagnostic line holds only the latest value, and a transmission's
    // worth of them is a series.
    debugPrint('[cat] yaesu binary $note');
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

  void _requestFrequencyAndMode() => _request(readFrequencyAndModeCommand);

  // ------------------------------------------------------------ commands

  @override
  void setFrequency(double freqKHz) => _request(buildSetFrequencyCommand((freqKHz * 1000).round()), isWrite: true);

  @override
  void setMode(String mode) {
    final command = buildSetModeCommand(mode, narrowFm: _narrowFm);
    // A mode the radio has no code for sends nothing, rather than a
    // command it would read as some other mode.
    if (command != null) _request(command, isWrite: true);
  }

  /// Nothing: this protocol has no RF power command at all. The radio's
  /// power level lives in its menu, and the only way CAT reaches it is an
  /// undocumented EEPROM write at an address that differs by model and
  /// firmware — a wrong byte there corrupts a setting the operator cannot
  /// see, so it stays unwritten.
  @override
  void setPower(num watts) {}

  /// Keys or unkeys the transmitter over CAT.
  ///
  /// Tracked ([_keyedByUs]) so [teardown] can put it back: this protocol
  /// has no dead-man's switch, and a disconnect with the transmitter on
  /// leaves a keyed radio and nothing to unkey it.
  void setPtt(bool on) {
    _keyedByUs = on;
    _request(buildPttCommand(on), isWrite: true);
  }

  // ------------------------------------------------------------ lifetime

  @override
  void startUpdates() {
    _requestFrequencyAndMode();
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
      // Ahead of whatever is queued, and sent even though the connection
      // is closing: an unkey that waits its turn behind a poll may not go
      // out at all.
      _keyedByUs = false;
      _sink.send(buildPttCommand(false).bytes);
    }
    _queue.clear();
    _clearInFlight();
    _resyncing?.cancel();
    _resyncing = null;
    _telemetry.dispose();
  }
}
