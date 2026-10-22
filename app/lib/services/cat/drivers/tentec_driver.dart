// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Drives the radios that speak Ten-Tec's Orion command set — the Orion,
// the Orion II and the Eagle — over their serial ports. The protocol itself
// is in tentec_codec.dart.
//
// NOT VERIFIED AGAINST HARDWARE. Written from Ten-Tec's programmer's
// reference guides; nothing here has been sent to a radio.
//
// The radio volunteers nothing, so this polls on the AdaptivePoller, and
// one question is on the wire at a time (request_queue.dart). Answers name
// what they answer, but the Eagle's refusal is a bare `Z`: with two
// questions out, there is no telling which one it refused. A set — PTT
// included — waits out [_setGap] before anything follows it, the pause the
// Eagle's guide asks for between commands, so a refusal of the set arrives
// while nothing is outstanding and cannot be taken for the answer to the
// read-back behind it.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show bandForFrequency, dataModeBases;
import 'package:halo_i18n/halo_i18n.dart';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../request_queue.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'cw_send_queue.dart';
import 'line_framer.dart';
import 'optional_read.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'tentec_codec.dart';

/// `?S` and its longest answer, `@STF100R100S99.9`, with their CRs.
const tenTecSignalCycleBytes = 21;

/// Long past either radio's answer at 57,600 baud; short enough that a
/// question one ignores costs a skipped poll rather than a frozen radio.
const _answerTimeout = Duration(seconds: 1);

/// The silence that ends a drain after a timeout (request_queue.dart).
const _quiet = Duration(milliseconds: 500);

/// The pause after a set: the Eagle's guide asks for 200 ms between
/// commands that are not each followed by a query.
const _setGap = Duration(milliseconds: 200);

/// The CW-from-text command takes one character, so a message is never
/// limited by the radio — this is only how much the queue hands over at
/// once, and so how much a stop can still leave going out.
const _cwChunkLength = 24;

class TenTecDriver extends EquipmentDriver {
  const TenTecDriver();

  /// The config key a catalogue entry pins the radio's command set under:
  /// `orion` or `eagle` ([TenTecDialect]).
  static const dialectConfigKey = 'tenTecDialect';

  @override
  String get key => 'tentec';

  @override
  String get name => 'Ten-Tec (Orion, Orion II, Eagle)';

  static TenTecDialect dialectFrom(Map<String, dynamic> config) => TenTecDialect.fromConfig(config[dialectConfigKey]) ?? TenTecDialect.eagle;

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(dialectFrom(config).modeCodes.keys);

  @override
  bool canKeyCwWith(Map<String, dynamic> config) => dialectFrom(config).keysCw;

  /// Both radios answer `?S` with their forward and reflected power while
  /// keyed. The receive reading is not here — see [TenTecReceiving].
  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.powerOut, RadioMeter.swr};

  @override
  int get telemetryWatchBytes => tenTecSignalCycleBytes;

  @override
  int get telemetryCycleBytes => tenTecSignalCycleBytes;

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, dialectConfigKey};

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
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => TenTecSession(sink, config: config);
}

/// What the outstanding message will answer, or [set] for one it will not.
enum _Ask { assignment, frequency, mode, power, filter, shift, signal, keyer, keyerSpeed, version, set }

class TenTecSession implements TransceiverSession, PttSession, PassbandSession, CwKeyerSession, RawCommandSession {
  final EquipmentSink _sink;
  final Map<String, dynamic> _config;
  final TenTecDialect dialect;

  TenTecSession(this._sink, {Map<String, dynamic> config = const {}}) : _config = config, dialect = TenTecDriver.dialectFrom(config);

  final _framer = LineFramer(crTerminates: true);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _poll, slow: idlePollIntervalFor(_config));

  /// Watching and reading are one question here: `?S` answers with the
  /// S-meter while receiving and the power meters while keyed, so the shape
  /// of the answer IS the transmit state.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: (_) => _pollSignal(),
    idleInterval: telemetryIntervalFor(_config, cycleBytes: tenTecSignalCycleBytes, baudRate: serialBaudRateOrNull(_config)),
    txInterval: telemetryIntervalFor(_config, cycleBytes: tenTecSignalCycleBytes, baudRate: serialBaudRateOrNull(_config)),
  );

  late final RequestQueue<_Ask> _requests = RequestQueue(send: _sink.send, onUnanswered: _unanswered, answerTimeout: _answerTimeout, quiet: _quiet);

  late final _filterRead = OptionalRead(_sink, 'radio refuses ?RMF; filter width not asked again', onGiveUp: () => _setFilter(null));
  late final _shiftRead = OptionalRead(_sink, 'radio refuses ?RMP; passband shift not asked again', onGiveUp: () => _setShift(null));

  /// The Orion's keyer reads, given up by firmware older than 1.366 — which
  /// has no CW over CAT either, so [sendCw] says so rather than queueing.
  late final _keyerRead = OptionalRead(_sink, 'radio refuses ?CK/?CS; no CW over CAT', onGiveUp: () {}, asked: dialect.keysCw);

  final _rawGrace = RawRefusalGrace();

  /// Which VFO the main receiver is on — always A on the Eagle; on an Orion,
  /// whatever the last `@KV` said. Read when a question is SENT, so a poll
  /// queued before the answer still asks the right one.
  String _mainRxVfo = 'A';

  /// Which VFO transmits, and where VFO B is — read only to keep an Eagle
  /// out of the cross-band split its guide warns about (see [setFrequency]).
  String? _txVfo;
  int? _vfoBHz;

  String? _mode;
  int? _filterHz;
  int? _shiftHz;

  VfoReading? _lastReported;
  Passband? _passband;
  bool _passbandReported = false;

  /// Whether the app keyed the radio, so [teardown] can unkey it: both radios
  /// stay keyed until told otherwise, and a logger that disconnects while
  /// transmitting leaves nothing else to do it.
  bool _keyedByUs = false;

  bool? _keyerOn;
  int? _keyerSpeed;

  late final CwSendQueue _cwQueue = CwSendQueue(
    maxChunkLength: _cwChunkLength,
    send: _keyChunk,
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  /// The characters of the chunk going out, each waiting for its own start.
  final _cwTimers = <Timer>[];

  /// The question on the wire, as sent — what an Orion's `Z!xx` is checked
  /// against — and the last set, which is all an Eagle's bare `Z` can be
  /// named by.
  String? _lastQuery;
  String? _lastSet;

  /// The keying asked for and not yet written. One PTT request is ever
  /// queued, writing whatever this says when its turn comes: two queued at
  /// the front of the line would go out in reverse, an unkey ahead of its
  /// key, leaving the radio transmitting.
  bool? _pendingPtt;

  Duration get pollInterval => _poller.interval;

  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  void _ask(_Ask ask, String? Function() message) => _requests.ask(ask, () {
    final text = message();
    if (text != null) _lastQuery = text.trim();
    return _encode(text);
  });

  void _tell(String? Function() message, {bool first = false}) => _requests.tell(
    _Ask.set,
    () {
      final text = message();
      if (text == null) return null;
      _lastSet = text.trim();
      return _encode(text);
    },
    gap: _setGap,
    first: first,
  );

  static List<int>? _encode(String? message) => message == null ? null : ascii.encode(message);

  // ------------------------------------------------------------- polling

  void _poll() {
    // See FlrigSession._requestFrequencyAndMode for why the outstanding
    // message alone is not a backlog.
    if (!_requests.backlogged) _requestState();
  }

  void _requestState() {
    _ask(_Ask.assignment, () => tenTecQuery('KV'));
    _ask(_Ask.frequency, () => tenTecQuery('${_mainRxVfo}F'));
    // VFO B only for what [setFrequency] needs it for.
    _ask(_Ask.frequency, () => dialect == TenTecDialect.eagle && _txVfo == 'B' ? tenTecQuery('BF') : null);
    _ask(_Ask.mode, () => tenTecQuery('RMM'));
    _ask(_Ask.power, () => tenTecQuery('TP'));
    _ask(_Ask.filter, () => _filterRead.available && _hasPassband(_mode) ? tenTecQuery('RMF') : null);
    _ask(_Ask.shift, () => _shiftRead.available && _hasPassband(_mode) ? tenTecQuery('RMP') : null);
    // Every poll, not only on connect: the keyer's speed paces each character
    // [sendCw] writes, and its knob turns without the app hearing of it.
    _requestKeyer();
  }

  void _requestKeyer() {
    _ask(_Ask.keyer, () => _keyerRead.available ? tenTecQuery('CK') : null);
    _ask(_Ask.keyerSpeed, () => _keyerRead.available ? tenTecQuery('CS') : null);
  }

  void _pollSignal() {
    if (_requests.backlogged || _requests.holds(_Ask.signal)) return;
    _ask(_Ask.signal, () => tenTecQuery('S'));
  }

  void _unanswered(_Ask ask) {
    switch (ask) {
      case _Ask.filter:
        _filterRead.unanswered();
      case _Ask.shift:
        _shiftRead.unanswered();
      case _Ask.keyer || _Ask.keyerSpeed:
        _keyerRead.unanswered();
      // Firmware that does not know it says nothing about the rest.
      case _Ask.version:
        break;
      default:
        _filterRead.radioWentSilent();
        _shiftRead.radioWentSilent();
        _keyerRead.radioWentSilent();
        _sink.reportDiagnostic('radio did not answer ${_lastQuery ?? ask.name}');
    }
  }

  // ------------------------------------------------------------- reading

  @override
  void handleData(Uint8List chunk) {
    for (final line in _framer.add(chunk)) {
      _handleLine(line);
    }
  }

  void _handleLine(String line) {
    final reply = parseTenTecReply(line, dialect);
    if (reply == null) return;
    _sink.reportAlive();
    _filterRead.heardFromRadio();
    _shiftRead.heardFromRadio();
    _keyerRead.heardFromRadio();

    final ask = _requests.replyArrived();
    if (reply is TenTecRefusal) {
      final ours = ask != null && _refusesOutstanding(reply);
      _refused(ours ? ask : null, reply);
      if (ours) _requests.settle();
      return;
    }
    if (reply is TenTecUnreadable) {
      // Taken as the outstanding question's answer — the radio did answer —
      // so the poll does not stall a timeout on every cycle behind it.
      _sink.reportDiagnostic('unreadable answer "${reply.text}"');
      if (ask != null) _requests.settle();
      return;
    }
    _apply(reply);
    if (ask != null && _answers(ask, reply)) _requests.settle();
  }

  /// Whether [reply] is what [ask] asked for. A reply that is not is still
  /// applied — it names what it reports — but leaves the question waiting.
  static bool _answers(_Ask ask, TenTecReply reply) => switch (ask) {
    _Ask.assignment => reply is TenTecVfoAssignment,
    _Ask.frequency => reply is TenTecFrequency,
    _Ask.mode => reply is TenTecMode,
    _Ask.power => reply is TenTecPower,
    _Ask.filter => reply is TenTecFilterWidth,
    _Ask.shift => reply is TenTecPassbandShift,
    _Ask.signal => reply is TenTecReceiving || reply is TenTecTransmitting,
    _Ask.keyer => reply is TenTecKeyerEnabled,
    _Ask.keyerSpeed => reply is TenTecKeyerSpeed,
    _Ask.version => reply is TenTecIdentity,
    _Ask.set => false,
  };

  /// Whether [refusal] is the outstanding question's. An Eagle's bare `Z`
  /// is taken as it: one question is in flight, and a set's refusal arrives
  /// inside its own [_setGap]. An Orion names the start of what it refused,
  /// so one naming something else — a CW character, a PTT, a late set — is
  /// not, and must not cost the question a strike or its answer.
  ///
  /// A name shorter than two characters is not a command's: after a VFO
  /// assignment the Orion names the VFO that was out of range (`Z!A`), which
  /// would otherwise match `?AF`.
  bool _refusesOutstanding(TenTecRefusal refusal) {
    final named = refusal.command;
    final query = _lastQuery;
    if (named == null) return true;
    if (named.length < 2 || query == null) return false;
    return query.startsWith(named) || query.substring(1).startsWith(named);
  }

  /// [ask] is the question refused, or null when what was refused is not
  /// the outstanding question — a set, or a command written past the queue.
  void _refused(_Ask? ask, TenTecRefusal refusal) {
    // An extension's raw command may be what was refused.
    if (_rawGrace.active) return;
    switch (ask) {
      case _Ask.filter:
        _filterRead.refused();
      case _Ask.shift:
        _shiftRead.refused();
      case _Ask.keyer || _Ask.keyerSpeed:
        _keyerRead.refused();
      case _Ask.version:
        break;
      default:
        final what = refusal.command ?? (ask == null ? _lastSet : _lastQuery) ?? 'a command';
        _sink.reportDiagnostic('radio refused $what');
    }
  }

  void _apply(TenTecReply reply) {
    switch (reply) {
      case TenTecVfoAssignment(:final mainRx, :final tx):
        if (dialect.mainReceiverFollowsAssignment) _mainRxVfo = mainRx;
        _txVfo = tx;
      case TenTecFrequency(:final vfo, :final hz):
        if (vfo == 'B') _vfoBHz = hz;
        if (vfo == _mainRxVfo) _report(VfoReading(freqKHz: hz / 1000));
      case TenTecMode(:final code):
        final mode = dialect.modeFor(code);
        if (mode == null) {
          _sink.reportDiagnostic('radio reports mode code $code');
          return;
        }
        if (mode != _mode) {
          // A filter is the mode's: the width read in the last one says
          // nothing about this one until the radio is asked again.
          _filterHz = null;
          _shiftHz = null;
        }
        _mode = mode;
        _report(VfoReading(mode: mode));
        _reportPassband();
      case TenTecPower(:final value):
        _sink.reportPower(value);
      case TenTecFilterWidth(:final hz):
        _filterRead.reset();
        _setFilter(hz);
      case TenTecPassbandShift(:final hz):
        _shiftRead.reset();
        _setShift(hz);
      // The reading itself is not a meter until a capture says what unit it
      // is in (TenTecReceiving).
      case TenTecReceiving():
        if (_telemetry.noteTransmitting(false)) _sink.reportTransmitting(false);
      case TenTecTransmitting(:final forwardWatts, :final swr):
        if (_telemetry.noteTransmitting(true)) _sink.reportTransmitting(true);
        _sink.reportMeter(RadioMeter.powerOut, forwardWatts);
        if (swr != null) _sink.reportMeter(RadioMeter.swr, swr);
      case TenTecKeyerEnabled(:final on):
        _keyerRead.reset();
        _keyerOn = on;
        if (on) _sink.reportProblem(null);
      case TenTecKeyerSpeed(:final wpm):
        _keyerRead.reset();
        _keyerSpeed = wpm;
        _sink.reportKeyerSpeed(wpm);
      case TenTecIdentity(:final text):
        _sink.reportDiagnostic('radio identifies as "$text"');
      case TenTecRefusal() || TenTecUnreadable():
        break;
    }
  }

  void _report(VfoReading reading) {
    _poller.noteData();
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The first reading answers startUpdates' question — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  // ------------------------------------------------------------ passband

  /// The modes the filter's place is known in: centred on the tuned
  /// frequency — CW on the pitch the dial shows, AM around its carrier.
  /// Not SSB or RTTY, where it sits at an offset neither guide states; a
  /// passband drawn there would be a guess (IcomCivSession._widthsFor makes
  /// the same call).
  static bool _hasPassband(String? mode) => mode == 'CW' || mode == 'CW-R' || mode == 'AM';

  void _setFilter(int? hz) {
    _filterHz = hz;
    _reportPassband();
  }

  void _setShift(int? hz) {
    _shiftHz = hz;
    _reportPassband();
  }

  /// Only on a change: the poll restates the width every few seconds.
  void _reportPassband() {
    final width = _filterHz;
    final passband = width == null || !_hasPassband(_mode) ? null : Passband(-width ~/ 2 + (_shiftHz ?? 0), width - width ~/ 2 + (_shiftHz ?? 0));
    if (_passbandReported && passband == _passband) return;
    _passbandReported = true;
    _passband = passband;
    if (_sink case final PassbandSink sink) sink.reportPassband(passband);
  }

  /// The width, and on an Orion the shift that centres it — then both read
  /// back. Only in a mode [_reportPassband] can show, since a set nothing
  /// reads back is one nobody sees land.
  @override
  void setPassband(Passband passband) {
    if (!_filterRead.available || !_hasPassband(_mode)) return;
    _tell(() => tenTecSetFilterWidth(dialect, passband.widthHz));
    _ask(_Ask.filter, () => tenTecQuery('RMF'));
    if (dialect.canSetPassbandShift && _shiftRead.available) {
      _tell(() => tenTecSetPassbandShift((passband.lowHz + passband.highHz) ~/ 2));
      _ask(_Ask.shift, () => tenTecQuery('RMP'));
    }
  }

  // ------------------------------------------------------------ commands

  /// Retunes the main receiver's VFO, then reads it back.
  ///
  /// An Eagle in split to another band is taken out of split first. Its
  /// front panel will not set up a cross-band split, its guide says the
  /// serial port can and that "care must be taken to avoid these
  /// situations" — and a split left behind by a band change is never what
  /// the operator meant, since its offset belonged to the old frequency.
  @override
  void setFrequency(double freqKHz) {
    final hz = (freqKHz * 1000).round();
    if (tenTecSetFrequency(_mainRxVfo, hz) == null) {
      _sink.reportDiagnostic('cannot send $freqKHz kHz: past the radio\'s eight-digit field');
      return;
    }
    if (dialect == TenTecDialect.eagle && _txVfo == 'B') {
      final vfoBHz = _vfoBHz;
      if (vfoBHz == null || bandForFrequency(vfoBHz / 1000) != bandForFrequency(freqKHz)) {
        _txVfo = 'A';
        _tell(tenTecSetVfoAssignment);
        _ask(_Ask.assignment, () => tenTecQuery('KV'));
      }
    }
    _tell(() => tenTecSetFrequency(_mainRxVfo, hz));
    _ask(_Ask.frequency, () => tenTecQuery('${_mainRxVfo}F'));
  }

  /// A data mode is put in its base mode — neither radio has a DATA
  /// submode — rather than leaving the radio wherever a band recall put it
  /// (KenwoodSession.setMode does the same).
  @override
  void setMode(String mode) {
    final command = tenTecSetMode(dialect, dataModeBases[mode] ?? mode);
    if (command == null) return;
    _tell(() => command);
    _ask(_Ask.mode, () => tenTecQuery('RMM'));
  }

  @override
  void setPower(num watts) {
    _tell(() => tenTecSetPower(watts));
    _ask(_Ask.power, () => tenTecQuery('TP'));
  }

  /// A set like any other, at the front of the line: it waits for the one
  /// question on the wire and no further, and is followed by [_setGap] like
  /// every set — the Eagle's guide asks for the gap "to maintain proper
  /// transmit and receive transition timing", and an unkey the radio drops
  /// leaves it transmitting with nothing left to unkey it. Its refusal then
  /// lands inside its own gap, where it cannot be taken for a question's.
  @override
  void setPtt(bool on) {
    // Set before a key and cleared only once an unkey is written: a key
    // still queued, or one that throws, leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    final queued = _pendingPtt != null;
    _pendingPtt = on;
    if (queued) return;
    _tell(first: true, () {
      final key = _pendingPtt;
      _pendingPtt = null;
      if (key == null) return null;
      _keyedByUs = key;
      return tenTecPtt(key);
    });
  }

  /// Each line as a command, written as given — past the queue, as the
  /// contract's null answer says, so the caller's wait for a reply starts
  /// when the command goes out. The answers are not counted: a query's names
  /// itself, and arrives as any other line.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    for (final line in rawCommandLines(bytes)) {
      _rawGrace.sent();
      _sink.send(ascii.encode('$line\r'));
    }
    return null;
  }

  // ------------------------------------------------------------------ CW

  /// Nothing is queued when the radio is known to ignore it — its keyer off,
  /// or firmware with no CW over CAT — and the operator is told why, where
  /// it can be seen: a queue would show the message going out while the
  /// radio keyed nothing.
  @override
  void sendCw(String text) {
    if (!dialect.keysCw) return;
    if (!_keyerRead.available) return _sink.reportProblem(t.settings.station.tenTecNoCw);
    if (_keyerOn == false) return _sink.reportProblem(t.settings.station.tenTecKeyerOff);
    _cwQueue.enqueue(tenTecCwText(text));
  }

  void _keyChunk(String chunk) {
    _cancelCwCharacters();
    for (final (start, command) in tenTecCwSchedule(chunk, _keyerSpeed ?? defaultCwSpeedWpm)) {
      _cwTimers.add(Timer(start, () => _sink.send(ascii.encode(command))));
    }
  }

  void _cancelCwCharacters() {
    for (final timer in _cwTimers) {
      timer.cancel();
    }
    _cwTimers.clear();
  }

  /// The radio has no command that stops its keyer, so only what has not
  /// been written yet is stopped: at most the character keying now goes out.
  @override
  void stopCw() {
    _cwQueue.clear();
    _cancelCwCharacters();
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => tenTecKeyerSpeedRange;

  @override
  void setKeyerSpeed(int wpm) {
    if (!dialect.keysCw) return;
    _tell(() => tenTecSetKeyerSpeed(wpm));
    _ask(_Ask.keyerSpeed, () => tenTecQuery('CS'));
  }

  @override
  void refreshKeyerSpeed() => _requestKeyer();

  // ------------------------------------------------------------ lifetime

  @override
  void startUpdates() {
    _framer.reset();
    _requests.clear();
    // Whatever PTT the cleared queue held is gone with it.
    _pendingPtt = null;
    _filterRead.reset();
    _shiftRead.reset();
    _keyerRead.reset();
    // Which firmware is answering, once, on the Eagle — the Orion's guide
    // documents no version query, and one it ignored would hold every
    // connect a timeout. Never `X`: the Eagle answers it with its name, but
    // on an Orion `XX` RESTARTS the radio.
    if (dialect == TenTecDialect.eagle) _ask(_Ask.version, () => tenTecQuery('V'));
    _requestState();
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
    stopCw();
    _requests.clear();
    _pendingPtt = null;
    if (_keyedByUs) {
      // Sent at once, past whatever the queue held, and even though the
      // connection is closing: nothing else will unkey this radio.
      _keyedByUs = false;
      _sink.send(ascii.encode(tenTecPtt(false)));
    }
    _framer.reset();
    _telemetry.dispose();
  }
}
