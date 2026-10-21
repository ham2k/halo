// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks flrig's XML-RPC protocol: HTTP/1.1 POSTs over one persistent TCP
// connection to an flrig instance the operator already runs, which drives
// the radio itself — the flrig sibling of the rigctld driver.
//
// flrig pushes nothing, so this driver is poll-driven on the same
// AdaptivePoller cadence as rigctld and the FT-891. But the wire rules are
// the opposite of rigctld's: an XML-RPC response carries no method name,
// and flrig's server (XMLRPC++ 0.8) keeps the connection alive yet DROPS a
// request that arrives before the previous response went out. Both facts
// point at the same discipline — exactly one request outstanding, the rest
// queued, answers correlated to questions by order. A second request on
// the wire wouldn't just risk desync, it would simply never be answered.
//
// Wire shapes, captured against flrig 2.0.12:
//   rig.get_vfo        → <value>14070000</value>          (Hz, as text)
//   rig.get_mode       → <value>USB</value>
//   rig.get_power      → <value><i4>0</i4></value>        (watts)
//   rig.get_ptt        → <value><i4>0</i4></value>
//   rig.get_pwrmeter   → <value>0</value>
//   rig.get_swrmeter   → <value>0</value>
//   rig.set_frequency  → <value><i4>1</i4></value>        (double param, Hz)
//   rig.set_mode       → <value></value>                  (string param)
//   unknown method     → HTTP 200 with a <fault> struct
// The Content-length header is spelled lowercase-l; parse it blind to case.
// The power, PTT and meter shapes come from an flrig with no rig behind it,
// which answers 0 to each; what they read with a rig keyed, and whether
// set_power takes the double it is sent, are not captured.

import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../telemetry_poller.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import '../driver.dart';
import '../equipment.dart';

/// App mode names → flrig's spellings, where they differ. flrig reports
/// whatever names the rig's own table uses — pinned against a live
/// IC-705's `rig.get_modes` (LSB USB AM FM CW CW-R RTTY RTTY-R LSB-D
/// USB-D AM-D FM-D DV WFM): CW-R already matches the app's spelling, and
/// names with no app equivalent (DV, WFM, AM-D) pass through in both
/// directions, the way the rigctld driver passes Hamlib tokens.
const flrigModesByAppMode = <String, String>{'DATA-USB': 'USB-D', 'DATA-LSB': 'LSB-D', 'DATA-FM': 'FM-D', 'RTTY-LSB': 'RTTY', 'RTTY-USB': 'RTTY-R'};

const appModesByFlrigMode = <String, String>{
  'USB-D': 'DATA-USB',
  'LSB-D': 'DATA-LSB',
  'FM-D': 'DATA-FM',
  // Plain RTTY is the conventional (LSB) side, mirroring the rigctld map.
  'RTTY': 'RTTY-LSB',
  'RTTY-R': 'RTTY-USB',
};

String flrigModeForAppMode(String mode) => flrigModesByAppMode[mode.toUpperCase()] ?? mode.toUpperCase();

String appModeForFlrigMode(String name) => appModesByFlrigMode[name.toUpperCase()] ?? name.toUpperCase();

class FlrigDriver extends EquipmentDriver {
  const FlrigDriver();

  /// flrig's own default XML-RPC port.
  static const defaultPort = 12345;

  @override
  String get key => 'flrig';

  @override
  String get name => 'flrig';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(['LSB', 'USB', 'CW', 'CW-R', 'AM', 'FM', ...flrigModesByAppMode.keys]);

  /// Everything flrig publishes a meter method for. Its power meter answers
  /// watts outright and its SWR a ratio, so this is the one driver here
  /// converting nothing on the way up. No ALC or supply voltage: flrig
  /// 2.0.12 has no method for either (`system.listMethods` offers none, and
  /// asking faults).
  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.powerOut, RadioMeter.swr};

  /// The meter cadence, and nothing else: where flrig is and which port it
  /// listens on are the TCP transport's questions.
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
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => FlrigSession(sink, config);
}

/// What kind of answer the outstanding request will produce — the only
/// correlation an XML-RPC response offers is "it answers the oldest
/// unanswered question".
enum _Ask { frequency, mode, power, transmitting, meterPower, meterSwr, ptt, ignored, raw }

/// An XML-RPC scalar: bare text, which the spec reads as a string, or text
/// inside one type element. flrig sends both — `rig.get_vfo` answers bare,
/// `rig.get_power` and `rig.get_ptt` as `<i4>` — so a parse that reads only
/// the bare form loses every typed answer without a trace.
final _scalar = RegExp(r'<value>(?:<(i4|int|double|string|boolean)>([^<]*)</\1>|([^<]*))</value>');

class FlrigSession implements TransceiverSession, PttSession, RawCommandSession {
  final EquipmentSink _sink;

  FlrigSession(this._sink, [this._config = const {}]);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode, slow: idlePollIntervalFor(_config));

  /// Watches for the operator to key the rig, and reads its meters while
  /// they hold it. Separate from [_poller], which follows the opposite rule
  /// — see telemetry_poller.dart.
  ///
  /// No baud rate anywhere: this is an XML-RPC server over TCP, so both
  /// cadences fall back to the flat default rather than a budget computed
  /// from a wire nobody measured.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: _pollTelemetry,
    idleInterval: telemetryIntervalFor(_config, cycleBytes: 0),
    txInterval: telemetryIntervalFor(_config, cycleBytes: 0),
  );

  final Map<String, dynamic> _config;

  /// What was last reported upward, so a repeat can be told from a move —
  /// the poller's fast/slow choice rides on this, same as the FT-891's.
  VfoReading? _lastReported;

  /// Bytes of the response currently being received.
  final _buffer = <int>[];

  /// Requests not yet on the wire, oldest first.
  final _queue = <(_Ask, String)>[];

  /// The one request on the wire, or null. Never more than one: flrig
  /// drops — not defers — a request that arrives mid-response.
  _Ask? _outstanding;

  /// Far past any real flrig header (~120 bytes); reached only when the
  /// peer isn't speaking HTTP at all.
  static const _maxUnframedBytes = 8192;

  /// The cadence the poller has settled on — for tests, which otherwise
  /// could only infer it from timing.
  Duration get pollInterval => _poller.interval;

  void _call(_Ask ask, String method, [String params = '']) {
    _queue.add((ask, _httpRequest(method, params)));
    _pump();
  }

  /// An extension's raw XML-RPC call, as given (`<?xml …?><methodCall>…`),
  /// posted like the driver's own and queued behind them — flrig drops a
  /// request that arrives mid-response. Its answer is the response's body.
  @override
  int sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    final body = utf8.decode(bytes, allowMalformed: true);
    if (body.trim().isEmpty) throw const FormatException('no call');
    _rawAnswers.add(onAnswer ?? (_) {});
    _queue.add((_Ask.raw, _post(body)));
    _pump();
    return 1;
  }

  /// Who waits for each raw call's answer, in the order queued.
  final _rawAnswers = <void Function(List<int> answer)>[];

  /// Hands the raw call on the wire its answer — nothing, for a response lost.
  /// None is waiting after [teardown], which leaves the call outstanding.
  void _answerRaw(List<int> answer) {
    if (_outstanding == _Ask.raw && _rawAnswers.isNotEmpty) _rawAnswers.removeAt(0)(answer);
  }

  void _pump() {
    if (_outstanding != null || _queue.isEmpty) return;
    final (ask, request) = _queue.removeAt(0);
    _outstanding = ask;
    _sink.send(utf8.encode(request));
  }

  static String _httpRequest(String method, String params) =>
      _post('<?xml version="1.0"?><methodCall><methodName>$method</methodName><params>$params</params></methodCall>');

  /// Content-Length counts bytes, which a raw call may spell in more than ASCII.
  static String _post(String body) =>
      'POST /RPC2 HTTP/1.1\r\n'
      'Host: flrig\r\n'
      'Content-Type: text/xml\r\n'
      'Content-Length: ${utf8.encode(body).length}\r\n'
      '\r\n'
      '$body';

  void _requestFrequencyAndMode() {
    // A backed-up queue means flrig is answering slower than the poll
    // cadence; asking again would only deepen the backlog it's behind on.
    //
    // The QUEUE alone, not the outstanding request: the TX watch runs many
    // times faster than this poll and leaves a `get_ptt` in flight most of
    // the time, so waiting for an idle socket would starve the state poll
    // outright — the radio's frequency would stop updating, with nothing to
    // point at but a driver that had gone quiet. One request in flight and
    // an empty queue is the normal state of a healthy session, not a
    // backlog.
    if (_queue.isNotEmpty) return;
    _call(_Ask.frequency, 'rig.get_vfo');
    _call(_Ask.mode, 'rig.get_mode');
    _call(_Ask.power, 'rig.get_power');
  }

  /// One turn of the telemetry cadence.
  ///
  /// Skipped while anything is still WAITING, so an flrig that has gone
  /// slow cannot accumulate a queue of meter reads whose answers are stale
  /// before they arrive — the same protection [_requestFrequencyAndMode]
  /// gives itself, against a cadence several times faster.
  ///
  /// It does NOT wait for the outstanding request to be answered, unlike
  /// that one. The burst that matters most is fired from inside the
  /// handling of a response — the PTT answer that says the rig has just
  /// been keyed — and at that moment the request being answered is still
  /// the outstanding one. Guarding on it would drop the meter read for
  /// every transmission, at the exact moment there was finally something to
  /// measure, and the queue exists so a request can wait its turn.
  void _pollTelemetry(bool transmitting) {
    if (_queue.isNotEmpty) return;
    if (!transmitting) {
      _call(_Ask.transmitting, 'rig.get_ptt');
      return;
    }
    // Only the meters flrig has a method for: every request here waits its
    // turn on a one-at-a-time connection, so asking for one flrig lacks
    // costs a round-trip per cycle and answers nothing. What each meter
    // ANSWERS IN while keyed is not captured, and is handled at the parse.
    _call(_Ask.transmitting, 'rig.get_ptt');
    _call(_Ask.meterPower, 'rig.get_pwrmeter');
    _call(_Ask.meterSwr, 'rig.get_swrmeter');
  }

  @override
  void handleData(Uint8List chunk) {
    _buffer.addAll(chunk);
    // Consume as many complete responses as the buffer holds — TCP chunks
    // align with nothing.
    while (true) {
      final text = ascii.decode(_buffer, allowInvalid: true);
      final headerEnd = text.indexOf('\r\n\r\n');
      if (headerEnd < 0) {
        // Only flrig's own framing ever completes a header. A non-flrig
        // service on the configured port (rigctld and Flex both stream
        // newline-framed text with no blank line) would otherwise grow
        // this buffer without bound, re-decoded in full on every chunk.
        if (_buffer.length > _maxUnframedBytes) {
          _buffer.clear();
          _answerRaw(const []);
          _outstanding = null;
          _pump();
        }
        return;
      }
      final lengthMatch = RegExp(r'^content-length:\s*(\d+)', caseSensitive: false, multiLine: true).firstMatch(text.substring(0, headerEnd));
      // A response with no length can never be completed reliably; drop
      // the connection's worth of buffer rather than guess. Pumping here
      // can collide with that response's still-inbound body — flrig then
      // drops the pumped request — which costs one answer, re-asked by
      // the next poll.
      if (lengthMatch == null) {
        _buffer.clear();
        _answerRaw(const []);
        _outstanding = null;
        _pump();
        return;
      }
      final bodyStart = headerEnd + 4;
      final bodyLength = int.parse(lengthMatch.group(1)!);
      if (_buffer.length < bodyStart + bodyLength) return;
      final body = _buffer.sublist(bodyStart, bodyStart + bodyLength);
      _answerRaw(body);
      _handleResponse(ascii.decode(body, allowInvalid: true));
      _buffer.removeRange(0, bodyStart + bodyLength);
      _outstanding = null;
      _pump();
    }
  }

  void _handleResponse(String body) {
    final ask = _outstanding;
    if (ask == null) return;
    // Deferring the state poll is for what flrig volunteers about the RADIO,
    // never for an answer to a question of our own — and the TX watch asks
    // one several times a second. Counted as data, those re-arm the poll
    // timer before it can ever fire, leaving the frequency to arrive only on
    // AdaptivePoller's 9-second staleness ceiling.
    if (ask == _Ask.frequency || ask == _Ask.mode || ask == _Ask.power) _poller.noteData();
    // A fault answers the question with nothing; the next poll re-asks.
    if (body.contains('<fault>')) return;
    final match = _scalar.firstMatch(body);
    final value = (match?.group(2) ?? match?.group(3))?.trim();
    if (value == null || value.isEmpty) return;
    switch (ask) {
      case _Ask.frequency:
        final hz = double.tryParse(value);
        // flrig reports Hz; everything above here speaks kHz.
        if (hz != null && hz > 0) {
          _report(VfoReading(freqKHz: double.parse((hz / 1000).toStringAsFixed(3))));
        }
      case _Ask.mode:
        _report(VfoReading(mode: appModeForFlrigMode(value)));
      case _Ask.power:
        // flrig answers 0 with no rig behind it. No rig is set to 0 W, and
        // passing it on would reset the operator's power on every poll.
        final watts = double.tryParse(value);
        if (watts != null && watts > 0) _sink.reportPower(watts);
      case _Ask.transmitting:
        // "1" transmitting, "0" receiving. Anything else — an flrig that
        // does not implement it — is left as "nobody knows" rather than
        // read as receiving, which is what keeps the antenna gate honest.
        final ptt = int.tryParse(value);
        if (ptt != null) _noteTransmitting(ptt != 0);
      case _Ask.meterPower:
        // Read as WATTS, which is the assumption most likely to be right —
        // flrig owns the radio's own calibration and its power display is in
        // watts — and the one that is wrong in a visible way if it is not: a
        // 100 W rig reading 35 would show 35 W beside a bar drawn against
        // the power the operator set, which is a disagreement they can see.
        final watts = double.tryParse(value);
        if (watts != null) _sink.reportMeter(RadioMeter.powerOut, watts);
      case _Ask.meterSwr:
        final swr = double.tryParse(value);
        if (swr != null && swr >= 1) _sink.reportMeter(RadioMeter.swr, swr);
      case _Ask.ptt:
      case _Ask.ignored:
      case _Ask.raw:
        break;
    }
  }

  /// The server answered the TX watch: tell the app, and move the cadence.
  /// Deduped here, not left to CatService — see IcomCivSession._noteTransmitting.
  void _noteTransmitting(bool transmitting) {
    if (_telemetry.noteTransmitting(transmitting)) _sink.reportTransmitting(transmitting);
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The FIRST reading is the answer to the question startUpdates just
    // asked, not the radio moving — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  @override
  void setFrequency(double freqKHz) => _call(_Ask.ignored, 'rig.set_frequency', '<param><value><double>${(freqKHz * 1000).round()}</double></value></param>');

  @override
  void setMode(String mode) => _call(_Ask.ignored, 'rig.set_mode', '<param><value>${flrigModeForAppMode(mode)}</value></param>');

  @override
  void setPower(num watts) => _call(_Ask.ignored, 'rig.set_power', '<param><value><double>$watts</double></value></param>');

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  static String _pttRequest(bool on) => _httpRequest('rig.set_ptt', '<param><value><i4>${on ? 1 : 0}</i4></value></param>');

  /// At the head of the queue, not the tail: behind a TX watch and two meter
  /// reads an unkey waits a round-trip per request while the transmitter
  /// stays on. A set still queued goes with it — left behind this one it
  /// would go out after it, and undo it.
  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _queue.removeWhere((entry) => entry.$1 == _Ask.ptt);
    _queue.insert(0, (_Ask.ptt, _pttRequest(on)));
    _pump();
    _keyedByUs = on;
  }

  @override
  void startUpdates() {
    _buffer.clear();
    _queue.clear();
    _rawAnswers.clear();
    _outstanding = null;
    _requestFrequencyAndMode();
    _poller.start();
    _telemetry.start();
  }

  @override
  void stopUpdates() {
    _poller.stop();
    _telemetry.stop();
  }

  /// The poller's CURRENT cadence, not its floor: it runs fast while the
  /// dial is moving and eases off when it isn't, and a caller asking "how
  /// long until I'd hear about a change" wants whichever is in force now.
  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() {
    if (_keyedByUs) {
      // Straight to the wire, ahead of the queue: the connection is closing,
      // and nothing else will unkey this radio. flrig drops a request that
      // lands mid-response, so this can be lost to one in flight — there is
      // no later moment to send it at.
      _keyedByUs = false;
      _sink.send(ascii.encode(_pttRequest(false)));
    }
    // A key still queued must not follow the unkey out, should one more
    // response arrive and pump it.
    _queue.clear();
    _rawAnswers.clear();
    // flrig holds no per-client state; stopping the poll is the farewell.
    stopUpdates();
    _telemetry.dispose();
  }
}
