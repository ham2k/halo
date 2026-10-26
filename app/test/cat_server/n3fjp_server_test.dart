// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat_server/n3fjp_server.dart';

import 'fake_cat_server_rig.dart';

void main() {
  late FakeCatServerRig rig;
  late N3fjpServerConnection connection;
  late List<String> sent;

  setUp(() {
    rig = FakeCatServerRig(freqKHz: 7228.02, mode: 'LSB');
    sent = [];
    connection = N3fjpServerConnection(rig, send: (bytes) => sent.add(utf8.decode(bytes)), hangUp: () {});
  });

  tearDown(() => connection.close());

  void receive(String text) => connection.receive(Uint8List.fromList(utf8.encode(text)));

  test('READBMF answers band, mode, mode class and MHz as the API documents them', () {
    receive('<CMD><READBMF></CMD>\r\n');
    expect(sent.single, '<CMD><READBMFRESPONSE><BAND>40</BAND><MODE>LSB</MODE><MODETEST>PH</MODETEST><FREQ>7.228020</FREQ></CMD>\r\n');
  });

  test('commands are cut at </CMD>, not at line ends: several per read, or one per two reads', () {
    receive('<CMD><PROGRAM></CMD><CMD><RE');
    receive('ADBMF></CMD>\r\n');
    expect(sent, hasLength(2));
    expect(sent[0], contains('<PROGRAMRESPONSE>'));
    expect(sent[1], contains('<READBMFRESPONSE>'));
  });

  test('tags match whatever their case', () {
    receive('<cmd><readbmf></cmd>');
    expect(sent.single, contains('<READBMFRESPONSE>'));
  });

  test('a change on the radio is pushed without being asked — GridTracker only listens', () {
    rig.move(freqKHz: 14074, mode: 'DATA-USB');
    expect(sent.single, '<CMD><READBMFRESPONSE><BAND>20</BAND><MODE>DATA</MODE><MODETEST>DIG</MODETEST><FREQ>14.074000</FREQ></CMD>\r\n');
  });

  test('a notification that changed nothing a client sees pushes nothing', () {
    // CatService notifies for far more than the VFO — telemetry, keying,
    // status. Each one is not a new band, mode or frequency.
    rig.move(freqKHz: 14074);
    rig.move(freqKHz: 14074);
    expect(sent, hasLength(1));
  });

  test('a closed connection stops listening to the radio', () {
    connection.close();
    rig.move(freqKHz: 14074);
    expect(sent, isEmpty);
  });

  test('CHANGEFREQ takes MHz and answers with what it was given', () {
    receive('<CMD><CHANGEFREQ><VALUE>21.446</VALUE><SUPPRESSMODEDEFAULT>TRUE</SUPPRESSMODEDEFAULT></CMD>');
    expect(rig.tunes.first.freqKHz, closeTo(21446, 0.001));
    expect(sent.first, '<CMD><CHANGEFREQRESPONSE><VALUE>21.446</VALUE></CMD>\r\n');
  });

  test('a NaN frequency is ignored, not tuned', () {
    receive('<CMD><CHANGEFREQ><VALUE>NaN</VALUE></CMD>');
    expect(rig.tunes, isEmpty);
  });

  test('CHANGEMODE tunes the mode, DATA as the data sideband', () {
    receive('<CMD><CHANGEMODE><VALUE>DATA</VALUE></CMD>');
    expect(rig.tunes.single, (freqKHz: null, mode: 'DATA-USB'));
  });

  test('a mode nothing here knows is ignored rather than written into the logging panel', () {
    receive('<CMD><CHANGEMODE><VALUE>XYZ</VALUE></CMD>');
    expect(rig.tunes, isEmpty);
  });

  test('a web page\'s request is hung up on before its body can be read as commands', () {
    var hungUp = 0;
    final pageConnection = N3fjpServerConnection(rig, send: (bytes) => sent.add(utf8.decode(bytes)), hangUp: () => hungUp++);
    addTearDown(pageConnection.close);
    pageConnection.receive(Uint8List.fromList(utf8.encode('POST / HTTP/1.1\r\nHost: localhost:1100\r\n\r\n<CMD><CHANGEFREQ><VALUE>7.0</VALUE></CMD>')));
    expect(hungUp, 1);
    expect(rig.tunes, isEmpty);
  });

  test('a logging command is not found rather than pretended to', () {
    receive('<CMD><ACTION><VALUE>ENTER</VALUE></CMD>');
    expect(sent.single, '<CMD><CMD_NOT_FOUND></CMD>\r\n');
  });

  test('with no radio connected, READBMF answers as N3FJP does with none attached', () {
    rig.available = false;
    receive('<CMD><READBMF></CMD>');
    expect(sent.single, contains('<FREQ>0.000000</FREQ>'));
    receive('<CMD><CHANGEFREQ><VALUE>21.446</VALUE></CMD>');
    expect(rig.tunes, isEmpty);
  });

  test('RIGTX keys only once the operator allows it, and RIGRX unkeys; neither has a reply', () {
    receive('<CMD><RIGTX></CMD>');
    expect(rig.ptts, isEmpty);
    rig.transmitAllowed = true;
    receive('<CMD><RIGTX></CMD><CMD><RIGRX></CMD><CMD><RIGTX></CMD>');
    expect(sent, isEmpty);
    connection.close();
    expect(rig.ptts, [true, false, true, false], reason: 'a client gone keyed is unkeyed');
  });
}
