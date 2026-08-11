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
//   rig.set_frequency  → <value><i4>1</i4></value>        (double param, Hz)
//   rig.set_mode       → <value></value>                  (string param)
//   unknown method     → HTTP 200 with a <fault> struct
// The Content-length header is spelled lowercase-l; parse it blind to case.
//
// rig.get_power/rig.set_power (watts, as a plain number) are documented
// flrig XML-RPC methods but were NOT captured against a live instance —
// unverified, same caveat CatService's `hardwareVerified` flag exists for.

import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';

/// App mode names → flrig's spellings, where they differ. flrig reports
/// whatever names the rig's own table uses — pinned against a live
/// IC-705's `rig.get_modes` (LSB USB AM FM CW CW-R RTTY RTTY-R LSB-D
/// USB-D AM-D FM-D DV WFM): CW-R already matches the app's spelling, and
/// names with no app equivalent (DV, WFM, AM-D) pass through in both
/// directions, the way the rigctld driver passes Hamlib tokens.
const flrigModesByAppMode = <String, String>{
  'DATA-USB': 'USB-D',
  'DATA-LSB': 'LSB-D',
  'DATA-FM': 'FM-D',
  'RTTY-LSB': 'RTTY',
  'RTTY-USB': 'RTTY-R',
};

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

  /// Exercised against a real IC-705 behind a real flrig 2.0.12 over USB
  /// serial — connect, follow, and set all proven end to end. Which rigs
  /// flrig itself handles well is flrig's contract, not this driver's.
  @override
  bool get hardwareVerified => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => FlrigSession(sink);
}

/// What kind of answer the outstanding request will produce — the only
/// correlation an XML-RPC response offers is "it answers the oldest
/// unanswered question".
enum _Ask { frequency, mode, power, ignored }

class FlrigSession implements EquipmentSession {
  final EquipmentSink _sink;

  FlrigSession(this._sink);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode);

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

  void _pump() {
    if (_outstanding != null || _queue.isEmpty) return;
    final (ask, request) = _queue.removeAt(0);
    _outstanding = ask;
    _sink.send(ascii.encode(request));
  }

  static String _httpRequest(String method, String params) {
    final body = '<?xml version="1.0"?><methodCall><methodName>$method</methodName><params>$params</params></methodCall>';
    return 'POST /RPC2 HTTP/1.1\r\n'
        'Host: flrig\r\n'
        'Content-Type: text/xml\r\n'
        'Content-Length: ${body.length}\r\n'
        '\r\n'
        '$body';
  }

  void _requestFrequencyAndMode() {
    // A backed-up queue means flrig is answering slower than the poll
    // cadence; asking again would only deepen the backlog it's behind on.
    if (_outstanding != null || _queue.isNotEmpty) return;
    _call(_Ask.frequency, 'rig.get_vfo');
    _call(_Ask.mode, 'rig.get_mode');
    // Documented flrig XML-RPC method (rig.get_power/rig.set_power, watts as
    // a plain number) — unlike get_vfo/get_mode above, not captured against
    // a live flrig instance, so treat the exact reply shape as unverified.
    _call(_Ask.power, 'rig.get_power');
  }

  @override
  void handleData(Uint8List chunk) {
    _poller.noteData();
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
          _outstanding = null;
          _pump();
        }
        return;
      }
      final lengthMatch = RegExp(r'^content-length:\s*(\d+)', caseSensitive: false, multiLine: true)
          .firstMatch(text.substring(0, headerEnd));
      // A response with no length can never be completed reliably; drop
      // the connection's worth of buffer rather than guess. Pumping here
      // can collide with that response's still-inbound body — flrig then
      // drops the pumped request — which costs one answer, re-asked by
      // the next poll.
      if (lengthMatch == null) {
        _buffer.clear();
        _outstanding = null;
        _pump();
        return;
      }
      final bodyStart = headerEnd + 4;
      final bodyLength = int.parse(lengthMatch.group(1)!);
      if (_buffer.length < bodyStart + bodyLength) return;
      _handleResponse(ascii.decode(_buffer.sublist(bodyStart, bodyStart + bodyLength), allowInvalid: true));
      _buffer.removeRange(0, bodyStart + bodyLength);
      _outstanding = null;
      _pump();
    }
  }

  void _handleResponse(String body) {
    final ask = _outstanding;
    if (ask == null) return;
    // A fault answers the question with nothing; the next poll re-asks.
    if (body.contains('<fault>')) return;
    final value = RegExp(r'<value>([^<]*)</value>').firstMatch(body)?.group(1)?.trim();
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
        final watts = double.tryParse(value);
        if (watts != null) _sink.reportPower(watts);
      case _Ask.ignored:
        break;
    }
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? _lastReported?.freqKHz,
      mode: reading.mode ?? _lastReported?.mode,
    );
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
  void setFrequency(double freqKHz) =>
      _call(_Ask.ignored, 'rig.set_frequency', '<param><value><double>${(freqKHz * 1000).round()}</double></value></param>');

  @override
  void setMode(String mode) => _call(_Ask.ignored, 'rig.set_mode', '<param><value>${flrigModeForAppMode(mode)}</value></param>');

  @override
  void setPower(num watts) =>
      _call(_Ask.ignored, 'rig.set_power', '<param><value><double>$watts</double></value></param>');

  @override
  void startUpdates() {
    _buffer.clear();
    _queue.clear();
    _outstanding = null;
    _requestFrequencyAndMode();
    _poller.start();
  }

  @override
  void stopUpdates() => _poller.stop();


  /// The poller's CURRENT cadence, not its floor: it runs fast while the
  /// dial is moving and eases off when it isn't, and a caller asking "how
  /// long until I'd hear about a change" wants whichever is in force now.
  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() {
    // flrig holds no per-client state; stopping the poll is the farewell.
    stopUpdates();
  }
}
