// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat_server/flrig_server.dart';

import 'fake_cat_server_rig.dart';

/// A request as Hamlib's flrig backend writes it, malformed processing
/// instruction and all.
String hamlibRequest(String method, [String? param]) {
  final params = param == null ? '' : '<params><param><value>$param</value></param></params>';
  final body = '<?xml version="1.0"?>\n<?clientid="hamlib(28106)"?>\n<methodCall><methodName>$method</methodName>\n$params</methodCall>\n';
  return 'POST /RPC2 HTTP/1.1\r\nUser-Agent: XMLRPC++ 0.8\r\nHost: 127.0.0.1:12345\r\nContent-type: text/xml\r\nContent-length: ${utf8.encode(body).length}\r\n\r\n$body';
}

void main() {
  late FakeCatServerRig rig;
  late FlrigServerConnection connection;
  late List<String> sent;
  late int hangUps;

  setUp(() {
    rig = FakeCatServerRig(freqKHz: 14074, mode: 'USB');
    sent = [];
    hangUps = 0;
    connection = FlrigServerConnection(rig, send: (bytes) => sent.add(utf8.decode(bytes)), hangUp: () => hangUps++);
  });

  void receive(String text) => connection.receive(Uint8List.fromList(utf8.encode(text)));

  String valueOf(String response) => RegExp(r'<param>\s*<value>(.*)</value>\s*</param>', dotAll: true).firstMatch(response)!.group(1)!;

  test('answers in HTTP/1.1, which Hamlib compares character for character', () {
    receive(hamlibRequest('main.get_version'));
    expect(sent.single, startsWith('HTTP/1.1 200 OK\r\n'));
  });

  test('reads a request despite Hamlib\'s malformed clientid instruction', () {
    // A strict XML parser rejects `<?clientid="hamlib(…)"?>` and answers a
    // fault to every request — Hamlib then cannot open the radio at all.
    receive(hamlibRequest('rig.get_vfoA'));
    expect(valueOf(sent.single), '14074000');
  });

  test('Content-length measures the body, so a client reading exactly that many bytes stays in step', () {
    receive(hamlibRequest('rig.get_xcvr'));
    final response = sent.single;
    final split = response.indexOf('\r\n\r\n') + 4;
    final declared = int.parse(RegExp(r'Content-length: (\d+)').firstMatch(response)!.group(1)!);
    expect(utf8.encode(response.substring(split)).length, declared);
  });

  test('two requests in one read, and one split across reads, are each answered once', () {
    final both = hamlibRequest('rig.get_vfo') + hamlibRequest('rig.get_mode');
    receive(both.substring(0, 30));
    expect(sent, isEmpty);
    receive(both.substring(30));
    expect(sent.map(valueOf), ['14074000', 'USB']);
  });

  test('modes read and write in flrig\'s spelling', () {
    rig.move(mode: 'DATA-USB');
    receive(hamlibRequest('rig.get_modeA'));
    expect(valueOf(sent.single), 'USB-D');

    receive(hamlibRequest('rig.set_modeA', 'USB-D'));
    expect(rig.tunes.last, (freqKHz: null, mode: 'DATA-USB'));
  });

  test('a mode nothing here knows is a fault, and the rig is not told', () {
    receive(hamlibRequest('rig.set_modeA', 'DV'));
    expect(sent.single, contains('<fault>'));
    expect(rig.tunes, isEmpty);
  });

  test('headers that never end hang up rather than buffering without limit', () {
    receive('POST /RPC2 HTTP/1.1\r\nX-Pad: ${'x' * 70000}');
    expect(hangUps, 1);
    expect(sent, isEmpty);
  });

  test('a request from a web page is refused — any page open in a browser could otherwise retune the radio', () {
    // A page's `fetch('http://localhost:12345', {method: 'POST', mode: 'no-cors'})`
    // needs no permission. The browser always names the page's origin; no
    // flrig client does.
    final request = hamlibRequest('rig.set_vfoA', '<double>7000000</double>').replaceFirst('\r\n', '\r\nOrigin: https://evil.example\r\n');
    receive(request);
    expect(hangUps, 1);
    expect(rig.tunes, isEmpty);
    expect(sent, isEmpty);
  });

  test('listMethods offers exactly what is answered — a client that checks it first finds every method', () {
    rig.available = true;
    receive(hamlibRequest('system.listMethods'));
    final methods = RegExp(r'<value>([a-zA-Z_.]+)</value>').allMatches(sent.single).map((m) => m.group(1)!).toList();
    expect(methods, containsAll(['rig.get_bwA', 'rig.set_bwA', 'rig.get_modeB', 'rig.get_pwrmeter_scale', 'main.set_frequency']));
    sent.clear();
    for (final method in methods) {
      receive(hamlibRequest(method, '0'));
    }
    expect(sent.where((r) => r.contains('unknown method')), isEmpty);
  });

  test('the data sideband is on the mode list, or a client cannot choose it', () {
    receive(hamlibRequest('rig.get_modes'));
    expect(valueOf(sent.single), contains('<value>USB-D</value>'));
  });

  test('a frequency in Hz, typed as a double, reaches the rig in kHz', () {
    receive(hamlibRequest('rig.set_vfoA', '<double>7074000</double>'));
    expect(rig.tunes.single, (freqKHz: 7074.0, mode: null));
  });

  test('a NaN frequency is a fault, not a tune', () {
    receive(hamlibRequest('rig.set_vfoA', '<double>NaN</double>'));
    expect(sent.single, contains('<fault>'));
    expect(rig.tunes, isEmpty);
  });

  test('fldigi\'s and HaLo\'s own spelling of the same set works too', () {
    receive(hamlibRequest('rig.set_frequency', '<double>21074000</double>'));
    expect(rig.tunes.single.freqKHz, 21074.0);
  });

  test('with no radio connected, reads and writes are faults, not a stale frequency', () {
    rig.available = false;
    receive(hamlibRequest('rig.get_vfo'));
    receive(hamlibRequest('rig.set_vfo', '<double>7074000</double>'));
    expect(sent, everyElement(contains('<fault>')));
    expect(rig.tunes, isEmpty);
  });

  test('PTT is a fault unless the operator allows it, so a client falls back to its own keying', () {
    receive(hamlibRequest('rig.set_ptt', '<i4>1</i4>'));
    expect(sent.single, contains('<fault>'));
    expect(rig.ptts, isEmpty);
  });

  test('PTT keys and unkeys once allowed, and a client gone keyed is unkeyed', () {
    rig.transmitAllowed = true;
    receive(hamlibRequest('rig.set_ptt', '<i4>1</i4>'));
    receive(hamlibRequest('rig.set_ptt', '<i4>0</i4>'));
    receive(hamlibRequest('rig.set_ptt', '<i4>1</i4>'));
    expect(sent, everyElement(isNot(contains('<fault>'))));
    connection.close();
    expect(rig.ptts, [true, false, true, false]);
  });
}
