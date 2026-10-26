// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/hrd_codec.dart';
import 'package:ham2k_logger/services/cat_server/hrd_server.dart';

import 'fake_cat_server_rig.dart';

void main() {
  late FakeCatServerRig rig;
  late HrdServerConnection connection;
  late List<Uint8List> sent;
  late int hangUps;

  setUp(() {
    rig = FakeCatServerRig(freqKHz: 14074, mode: 'USB');
    sent = [];
    hangUps = 0;
    connection = HrdServerConnection(rig, send: (bytes) => sent.add(Uint8List.fromList(bytes)), hangUp: () => hangUps++);
  });

  String replyText(Uint8List frame) => decodeUtf16le(frame.sublist(16));

  group('the frame', () {
    test('is laid out as HRD clients build it', () {
      // `get context`: 16 header bytes, then 11 UTF-16LE characters and a NUL.
      final frame = encodeHrdFrame('get context');
      expect(frame.length, 40);
      expect(frame.sublist(0, 16), [0x28, 0, 0, 0, 0xcd, 0xab, 0x34, 0x12, 0x34, 0x12, 0xcd, 0xab, 0, 0, 0, 0]);
      expect(frame.sublist(16, 20), [0x67, 0, 0x65, 0]);
      expect(frame.sublist(38), [0, 0]);
    });

    test('a request is answered in a frame, and its reply is the text', () {
      connection.receive(encodeHrdFrame('get frequency'));
      expect(replyText(sent.single), '14074000');
      expect(ByteData.sublistView(sent.single).getUint32(0, Endian.little), sent.single.length);
    });

    test('frames split and joined across reads are each answered once', () {
      final both = Uint8List.fromList([...encodeHrdFrame('get frequency'), ...encodeHrdFrame('get radio')]);
      connection.receive(both.sublist(0, 10));
      connection.receive(both.sublist(10, 50));
      connection.receive(both.sublist(50));
      expect(sent.map(replyText), ['14074000', 'HaLo']);
    });

    test('a length no frame could have hangs up, quietly — bad input from the network is not a bug here', () {
      final bogus = encodeHrdFrame('get frequency');
      ByteData.sublistView(bogus).setUint32(0, 0x7fffffff, Endian.little);
      connection.receive(bogus);
      expect(hangUps, 1);
      expect(sent, isEmpty);
    });

    test('a web page\'s request is hung up on, not read as HRD text commands', () {
      connection.receive(Uint8List.fromList(utf8.encode('POST / HTTP/1.1\r\n\r\nset frequency-hz 7000000\n')));
      expect(hangUps, 1);
      expect(rig.tunes, isEmpty);
    });

    test('a client speaking plain lines is answered in plain lines', () {
      connection.receive(Uint8List.fromList(utf8.encode('get id\n')));
      expect(utf8.decode(sent.single), 'Ham2K Logger\n');
    });
  });

  group('commands', () {
    String ask(String command) => connection.respond(command);

    test('a context prefix is accepted and ignored — there is one radio', () {
      expect(ask('get context'), '1');
      expect(ask('[1] get frequency'), '14074000');
    });

    test('the mode is the "Mode" dropdown, whatever a client calls it', () {
      rig.move(mode: 'DATA-USB');
      expect(ask('[1] get dropdown-text {Mode}'), 'Mode: PKT-U');
      expect(ask('[1] get dropdown-text {Main Mode}'), 'Main Mode: PKT-U');
      expect(ask('[1] get dropdown-text Main~Mode'), 'Main Mode: PKT-U');
    });

    test('setting the dropdown tunes the mode by its app name', () {
      expect(ask('[1] set dropdown Mode PKT-U 11'), 'OK');
      expect(rig.tunes.single, (freqKHz: null, mode: 'DATA-USB'));
    });

    test('a mode nothing here knows is an error, and the rig is not told', () {
      expect(ask('[1] set dropdown Mode XYZ 3'), startsWith('ERROR'));
      expect(rig.tunes, isEmpty);
    });

    test('a frequency in Hz reaches the rig in kHz', () {
      expect(ask('[1] set frequency-hz 7074000'), 'OK');
      expect(rig.tunes.single, (freqKHz: 7074.0, mode: null));
    });

    test('a NaN frequency is an error, not a tune', () {
      expect(ask('[1] set frequency-hz NaN'), startsWith('ERROR'));
      expect(rig.tunes, isEmpty);
    });

    test('the TX button reads, but keys the radio only once the operator allows it', () {
      rig.transmitting = true;
      expect(ask('[1] get button-select TX'), '1');
      expect(ask('[1] set button-select TX 1'), startsWith('ERROR'));
      expect(rig.ptts, isEmpty);
    });

    test('the TX button keys and unkeys once allowed, and a client gone keyed is unkeyed', () {
      rig.transmitAllowed = true;
      expect(ask('[1] set button-select TX 1'), 'OK');
      expect(ask('[1] set button-select TX 0'), 'OK');
      expect(ask('[1] set button-select TX 1'), 'OK');
      expect(ask('[1] set button-select Tune 1'), startsWith('ERROR'));
      connection.close();
      expect(rig.ptts, [true, false, true, false]);
    });

    test('with no radio connected nothing is read or tuned', () {
      rig.available = false;
      expect(ask('[1] get frequency'), startsWith('ERROR'));
      expect(ask('[1] set frequency-hz 7074000'), startsWith('ERROR'));
      expect(rig.tunes, isEmpty);
    });
  });
}
