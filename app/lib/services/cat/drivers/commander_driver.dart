// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Follows and tunes a radio through DXLab Commander's TCP network service
// (commander_codec.dart) — for an operator whose rig is already
// Commander's to drive.
//
// Written from Commander's published "TCPIP Messages" document; no exchange
// with a real Commander has been captured.
//
// Commander pushes nothing, so this is poll-driven on the AdaptivePoller:
// `CmdGetFreq` and `CmdSendMode`, and `CmdSendTX` on the PTT watch.
//
// One message is on the wire at a time (request_queue.dart). The document
// says nothing about two messages arriving in one read, and a server that
// parses the first field pair of each read would silently drop the second —
// so a question waits for its answer, and a set, which Commander does not
// answer, is followed by [_setGap] before anything else goes out.
//
// A set's frequency is read in the locale of the machine Commander runs on
// (commander_codec.dart), so the session asks `CmdSendFreq`, whose answer is
// in that locale, with every poll until one answer settles the decimal
// separator — a radio that is off answers `0,000`, which cannot. Until then
// a set goes out in whole kHz, which reads the same in every locale: half a
// kHz off rather than a thousand times. A set's text is built when it is
// sent, so one asked for just before the answer still uses it.

import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../request_queue.dart';
import '../telemetry_poller.dart';
import 'commander_codec.dart';

class CommanderDriver extends EquipmentDriver {
  const CommanderDriver();

  /// The third port of DXLab's default block (52000): DXKeeper takes the
  /// second, Commander the third.
  static const defaultPort = 52002;

  @override
  String get key => 'dxlab-commander';

  @override
  String get name => 'DXLab Commander';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(['LSB', 'USB', 'CW', 'CW-R', 'AM', 'FM', ...commanderModesByAppMode.keys]);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => CommanderSession(sink);
}

/// What the outstanding message will answer, or [set] for one it will not.
enum _Ask { locale, frequency, mode, transmitting, set }

/// Long past a local Commander's answer, short enough that a question it
/// ignores costs one skipped poll rather than a frozen radio.
const _answerTimeout = Duration(seconds: 1);

/// The silence that ends a drain after a timeout (request_queue.dart).
const _quiet = Duration(milliseconds: 500);

/// The pause after a set, which has no answer to wait for.
const _setGap = Duration(milliseconds: 100);

/// How many unanswered `CmdSendFreq` end the asking. Each one stalls the
/// poll behind it for a timeout and a drain; past this the session keeps to
/// whole-kHz sets, which read the same in every locale.
const _localeTries = 3;

/// Far past any real answer; reached only when the peer is not Commander.
const _maxPending = 64 * 1024;

class CommanderSession implements TransceiverSession {
  final EquipmentSink _sink;

  CommanderSession(this._sink);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _poll);

  late final TelemetryPoller _telemetry = TelemetryPoller(onPoll: _pollTelemetry);

  final _txBackoff = WatchBackoff();

  late final RequestQueue<_Ask> _requests = RequestQueue(send: _sink.send, onUnanswered: _unanswered, answerTimeout: _answerTimeout, quiet: _quiet);

  VfoReading? _lastReported;

  var _pending = '';

  /// The decimal separator of the machine Commander runs on, or null until
  /// a `CmdSendFreq` answer settles it.
  String? _decimal;

  int _localeMisses = 0;

  /// Whether a question has gone unanswered, or been answered under a name
  /// it does not answer to, this session — each said once, as a diagnostic,
  /// since either is the first thing to look at when Commander half-works.
  bool _reportedUnanswered = false;
  bool _reportedMismatch = false;

  Duration get pollInterval => _poller.interval;

  void _ask(_Ask ask, String Function() message) => _requests.ask(ask, () => ascii.encode(message()));

  void _unanswered(_Ask ask) {
    if (ask == _Ask.transmitting) _txBackoff.unanswered();
    if (ask == _Ask.locale) _localeMisses++;
    if (!_reportedUnanswered) {
      _reportedUnanswered = true;
      _sink.reportDiagnostic('Commander did not answer a ${ask.name} request');
    }
  }

  void _poll() {
    // See FlrigSession._requestFrequencyAndMode for why the outstanding
    // message alone is not a backlog.
    if (!_requests.backlogged) _requestFrequencyAndMode();
  }

  void _requestFrequencyAndMode() {
    if (_decimal == null && _localeMisses < _localeTries) _ask(_Ask.locale, () => commanderMessage('CmdSendFreq'));
    _ask(_Ask.frequency, () => commanderMessage('CmdGetFreq'));
    _ask(_Ask.mode, () => commanderMessage('CmdSendMode'));
  }

  void _pollTelemetry(bool transmitting) {
    if (_requests.backlogged || _requests.holds(_Ask.transmitting) || !_txBackoff.shouldAsk()) return;
    _ask(_Ask.transmitting, () => commanderMessage('CmdSendTX'));
  }

  @override
  void handleData(Uint8List chunk) {
    _pending += latin1.decode(chunk);
    while (true) {
      final field = takeCommanderField(_pending);
      if (field == null) break;
      _pending = _pending.substring(field.consumed);
      final ask = _requests.replyArrived();
      if (ask != null) _handleField(ask, field.name.toUpperCase(), field.value.trim());
    }
    if (_pending.length > _maxPending) _pending = '';
  }

  void _handleField(_Ask ask, String name, String value) {
    // Every answer names what it reports, but `CmdGetFreq` and `CmdSendFreq`
    // both answer as `CmdFreq` — only the question tells them apart.
    final expected = switch (ask) {
      _Ask.locale || _Ask.frequency => 'CMDFREQ',
      _Ask.mode => 'CMDMODE',
      _Ask.transmitting => 'CMDTX',
      _Ask.set => null,
    };
    if (name != expected) {
      // Left to time out: a field this question does not name may be a late
      // answer to another, and nothing here can say which.
      if (!_reportedMismatch) {
        _reportedMismatch = true;
        _sink.reportDiagnostic('Commander answered a ${ask.name} request with a $name field');
      }
      return;
    }
    if (ask == _Ask.frequency || ask == _Ask.mode) _poller.noteData();
    switch (ask) {
      case _Ask.locale:
        _decimal = commanderDecimalSeparator(value) ?? _decimal;
      case _Ask.frequency:
        final kHz = commanderKHz(value);
        if (kHz != null) _report(VfoReading(freqKHz: double.parse(kHz.toStringAsFixed(3))));
      case _Ask.mode:
        // Empty until the radio has reported one.
        if (value.isNotEmpty) _report(VfoReading(mode: appModeForCommanderMode(value)));
      case _Ask.transmitting:
        _txBackoff.answered();
        final on = switch (value.toUpperCase()) {
          'ON' => true,
          'OFF' => false,
          _ => null,
        };
        if (on != null && _telemetry.noteTransmitting(on)) _sink.reportTransmitting(on);
      case _Ask.set:
        break;
    }
    _requests.settle();
  }

  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The first reading answers startUpdates' question — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  @override
  void setFrequency(double freqKHz) => _requests.tell(
    _Ask.set,
    () => ascii.encode(commanderMessage('CmdSetFreq', commanderField('xcvrfreq', commanderFrequency(freqKHz, decimal: _decimal)))),
    gap: _setGap,
  );

  @override
  void setMode(String mode) {
    final name = commanderModeForAppMode(mode);
    // `CmdSetMode` takes its mode as a field named `1`.
    if (name != null) _requests.tell(_Ask.set, () => ascii.encode(commanderMessage('CmdSetMode', commanderField('1', name))), gap: _setGap);
  }

  @override
  void setPower(num watts) {}

  @override
  void startUpdates() {
    _pending = '';
    _requests.clear();
    _txBackoff.reset();
    _decimal = null;
    _localeMisses = 0;
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
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() {
    // Commander holds no per-client state; stopping the poll is the farewell.
    stopUpdates();
    _requests.clear();
    _telemetry.dispose();
  }
}
