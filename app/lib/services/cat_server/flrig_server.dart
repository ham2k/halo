// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Answers as flrig's XML-RPC server does, for the programs that drive a radio
// "through flrig" (fldigi, WSJT-X, JS8Call, and Hamlib's flrig backend).
//
// XML-RPC over HTTP/1.1, one TCP connection carrying many requests. Pinned
// against what Hamlib's flrig backend sends while opening and polling:
// `main.get_version`, `rig.get_xcvr`, `rig.get_pwrmeter_scale`,
// `rig.get_modeA`/`B`, `rig.get_vfoA`, `rig.get_bwA`, `rig.set_bwA`,
// `rig.get_AB`, `rig.get_modes`, `rig.get_split`, `rig.set_vfoA`,
// `rig.set_modeA`, `rig.get_ptt`, `rig.set_ptt`. fldigi and HaLo's own flrig
// driver use the unsuffixed `rig.get_vfo`/`rig.set_frequency` spellings.
//
// The request body is read with patterns, not an XML parser: Hamlib opens
// every request with `<?clientid="hamlib(…)"?>`, which is not a well-formed
// processing instruction, and flrig accepts it. So must this.
//
// Hamlib also checks the status line character for character — it expects
// exactly `HTTP/1.1 200 OK`, and `HTTP/1.0` fails its open.
//
// A request carrying an `Origin` header came from a web page, not from a
// radio program, and is refused: any page the operator has open could
// otherwise post to `localhost:12345` and retune the radio. No flrig client
// sends one; a browser always does on a POST.

import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';

import '../cat/drivers/flrig_driver.dart';
import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';

/// The mode names this "radio" offers, in flrig's spelling.
const _modes = ['LSB', 'USB', 'CW', 'CW-R', 'AM', 'FM', 'RTTY', 'RTTY-R', 'LSB-D', 'USB-D', 'FM-D'];

final _headerEnd = RegExp(r'\r?\n\r?\n');
final _origin = RegExp(r'^origin:', caseSensitive: false, multiLine: true);
final _contentLength = RegExp(r'^content-length:\s*(\d+)', caseSensitive: false, multiLine: true);
final _methodName = RegExp(r'<methodName>\s*([^<\s]+)\s*</methodName>');
final _paramValue = RegExp(r'<param>\s*<value>\s*(?:<(\w+)>([^<]*)</\1>|([^<]*))\s*</value>\s*</param>');

typedef _Method = String Function(List<String> params);

class FlrigServerConnection implements CatServerConnection {
  final CatServerRig rig;
  final CatServerSend send;
  final CatServerHangUp hangUp;

  FlrigServerConnection(this.rig, {required this.send, required this.hangUp}) : _ptt = CatServerPtt(rig);

  final CatServerPtt _ptt;

  final _buffer = BytesBuilder();

  @override
  void receive(Uint8List bytes) {
    _buffer.add(bytes);
    // A request larger than any flrig client sends, or headers that never
    // end, is not a client this can serve.
    if (_buffer.length > catServerMaxPending) {
      hangUp();
      return;
    }
    while (true) {
      final pending = _buffer.toBytes();
      // Latin-1 keeps one character per byte, so the offsets found in the
      // text are byte offsets and Content-Length can be measured against them.
      final text = latin1.decode(pending);
      final end = _headerEnd.firstMatch(text);
      if (end == null) return;
      final headers = text.substring(0, end.start);
      if (_origin.hasMatch(headers)) {
        hangUp();
        return;
      }
      final length = int.tryParse(_contentLength.firstMatch(headers)?.group(1) ?? '') ?? 0;
      if (pending.length < end.end + length) return;
      final body = utf8.decode(pending.sublist(end.end, end.end + length), allowMalformed: true);
      _buffer.clear();
      _buffer.add(pending.sublist(end.end + length));
      send(utf8.encode(_httpResponse(respond(body))));
    }
  }

  @override
  void close() => _ptt.drop();

  /// The `<methodResponse>` document answering one request body.
  String respond(String body) {
    final method = _methodName.firstMatch(body)?.group(1);
    if (method == null) return _fault('no methodName');
    final params = [for (final m in _paramValue.allMatches(body)) (m.group(2) ?? m.group(3) ?? '').trim()];
    final answer = _answers[method];
    if (answer != null) return answer(params);
    final tune = _tunes[method];
    if (tune == null) return _fault('unknown method $method');
    if (!rig.available) return _fault('no radio connected');
    return tune(params);
  }

  /// Methods answered whether or not a radio is connected: what this "radio"
  /// is, rather than where it is tuned. With [_tunes], the whole of what
  /// `system.listMethods` offers, so the list cannot drift from the answers.
  late final Map<String, _Method> _answers = {
    'main.get_version': (_) => _value(_string('2.0.05')),
    'rig.get_xcvr': (_) => _value(_string('HaLo')),
    'rig.get_modes': (_) => _value(_array(_modes.map(_string))),
    'rig.get_AB': (_) => _value(_string('A')),
    'rig.get_split': (_) => _value(_int(0)),
    'rig.set_split': (params) => params.isNotEmpty && params.first == '0' ? _value(_int(0)) : _fault('split is not supported'),
    'rig.get_ptt': (_) => _value(_int(rig.transmitting ? 1 : 0)),
    'rig.set_ptt': (params) {
      final ptt = params.isEmpty ? null : int.tryParse(params.first);
      if (ptt == null) return _fault('PTT needs 0 or 1');
      return _ptt.set(ptt != 0) ? _value(_int(0)) : _fault('PTT is not allowed');
    },
    'rig.get_pwrmeter_scale': (_) => _value(_string('1')),
    for (final m in ['rig.get_bw', 'rig.get_bwA', 'rig.get_bwB']) m: (_) => _value(_array([_string(''), _string('')])),
    for (final m in ['rig.set_bw', 'rig.set_bwA', 'rig.set_bwB']) m: (_) => _value(_int(0)),
    'rig.get_bws': (_) => _value(
      _array([
        _array([_string('NONE')]),
      ]),
    ),
    'system.listMethods': (_) => _value(_array([..._answers.keys, ..._tunes.keys].map(_string))),
  };

  /// Methods that read or move the radio, answered only while there is one.
  late final Map<String, _Method> _tunes = {
    for (final m in ['rig.get_vfo', 'rig.get_vfoA', 'rig.get_vfoB']) m: (_) => _frequency(),
    for (final m in ['rig.set_vfo', 'rig.set_vfoA', 'rig.set_vfoB', 'rig.set_frequency', 'rig.set_verify_vfoA', 'rig.set_verify_vfoB', 'main.set_frequency'])
      m: _setFrequency,
    for (final m in ['rig.get_mode', 'rig.get_modeA', 'rig.get_modeB']) m: (_) => _mode(),
    for (final m in ['rig.set_mode', 'rig.set_modeA', 'rig.set_modeB', 'rig.set_verify_mode', 'rig.set_verify_modeA', 'rig.set_verify_modeB']) m: _setMode,
    'rig.get_power': (_) => _value(_int(0)),
  };

  String _frequency() {
    final freq = rig.freqKHz;
    if (freq == null) return _fault('no frequency');
    return _value(_string((freq * 1000).round().toString()));
  }

  String _setFrequency(List<String> params) {
    final hz = params.isEmpty ? null : double.tryParse(params.first);
    if (hz == null || !isTunableFrequencyKHz(hz / 1000)) return _fault('invalid frequency');
    rig.tune(freqKHz: hz / 1000);
    return _value(_int(0));
  }

  String _mode() {
    final mode = radioModeForAppMode(rig.mode, rig.freqKHz);
    if (mode == null) return _fault('no mode');
    return _value(_string(flrigModeForAppMode(mode)));
  }

  String _setMode(List<String> params) {
    final mode = params.isEmpty ? null : tunableAppMode(appModeForFlrigMode(params.first));
    if (mode == null) return _fault('invalid mode');
    rig.tune(mode: mode);
    return _value(_int(0));
  }
}

String _httpResponse(String xml) {
  final body = utf8.encode(xml);
  return 'HTTP/1.1 200 OK\r\nServer: XMLRPC++ 0.8\r\nContent-Type: text/xml\r\nContent-length: ${body.length}\r\n\r\n$xml';
}

String _escape(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _string(String text) => _escape(text);

String _int(int n) => '<i4>$n</i4>';

String _array(Iterable<String> values) => '<array><data>${values.map((v) => '<value>$v</value>').join()}</data></array>';

String _value(String value) => '<?xml version="1.0"?>\r\n<methodResponse><params><param>\r\n\t<value>$value</value>\r\n</param></params></methodResponse>\r\n';

String _fault(String message) =>
    '<?xml version="1.0"?>\r\n<methodResponse><fault>\r\n\t<value><struct>'
    '<member><name>faultCode</name><value><i4>-1</i4></value></member>'
    '<member><name>faultString</name><value>${_escape(message)}</value></member>'
    '</struct></value>\r\n</fault></methodResponse>\r\n';
