// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat_server/rigctld_server.dart';

import 'fake_cat_server_rig.dart';

void main() {
  late FakeCatServerRig rig;
  late RigctldServerConnection connection;
  late List<String> sent;
  late int hangUps;
  late int quits;

  setUp(() {
    rig = FakeCatServerRig(freqKHz: 14074, mode: 'USB');
    sent = [];
    hangUps = 0;
    quits = 0;
    connection = RigctldServerConnection(rig, send: (bytes) => sent.add(utf8.decode(bytes)), hangUp: () => hangUps++, quit: () => quits++);
  });

  String ask(String line) => connection.respond(line)!;

  group('what Hamlib\'s NET client asks while opening a radio', () {
    // The exchange `rigctl -m 2` runs before it will answer a single `f`. A
    // reply it cannot parse, or none at all, fails WSJT-X's rig test with
    // nothing on screen but a timeout.
    test('answers every opening command, in the shape a real rigctld does', () {
      expect(ask(r'\get_powerstat'), '1\n');
      expect(ask(r'\chk_vfo'), '0\n');
      expect(ask('v'), 'VFOA\n');
      expect(ask('l KEYSPD'), '0\n');
    });

    test('dump_state ends with done, or the client reads until it times out', () {
      final lines = ask(r'\dump_state').split('\n');
      expect(lines.first, '1', reason: 'protocol version 1 is the form every Hamlib 4 client parses');
      expect(lines.where((l) => l.isNotEmpty).last, 'done');
    });

    test('dump_state claims the data sideband, or Hamlib refuses to select it', () {
      // Hamlib's client checks a requested mode against the rx range's mode
      // mask before sending it. PKTUSB is bit 11 in rig.h; a mask without it
      // is WSJT-X unable to put the radio in DATA.
      final rxRange = ask(r'\dump_state').split('\n')[3].split(' ');
      final mask = int.parse(rxRange[2].substring(2), radix: 16);
      expect(mask & (1 << 11), isNonZero);
      expect(mask & (1 << 2), isNonZero, reason: 'USB');
    });

    test('dump_state in the extended form is framed by its header and a status', () {
      // Pinned against `rigctld -m 1` (Hamlib 4.7.2): the separator joins only
      // the header to the block, which keeps its own newlines. A client reading
      // the extended form waits for the RPRT line; without it, it reads the
      // next reply as this one's status.
      final plain = ask(r'\dump_state');
      expect(ask(r'+\dump_state'), 'dump_state:\n${plain}RPRT 0\n');
      expect(ask(r';\dump_state'), 'dump_state:;${plain}RPRT 0\n');
      expect(ask(r'|\dump_state'), 'dump_state:|${plain}RPRT 0\n');
      expect(plain, startsWith('1\n'), reason: 'the plain form stays bare');
    });

    test('dump_state offers no CAT PTT, which HaLo cannot do', () {
      expect(ask(r'\dump_state'), contains('ptt_type=0x0\n'));
    });

    test('get_lock_mode answers a value AND a status, as the real one does', () {
      // Hamlib's client reads both lines; with one, the next command's reply
      // is read as this one's status and every answer after it is one late.
      expect(ask(r'\get_lock_mode'), '0\nRPRT 0\n');
    });
  });

  group('reading the radio', () {
    test('frequency in Hz, mode as Hamlib spells it with a passband', () {
      rig.move(freqKHz: 7074.5, mode: 'DATA-USB');
      expect(ask('f'), '7074500\n');
      expect(ask('m'), 'PKTUSB\n3000\n');
    });

    test('a digital app mode reads as the data sideband the radio sits in', () {
      rig.move(mode: 'FT8');
      expect(ask('m'), 'PKTUSB\n3000\n');
    });

    test('a generic SSB reads as the sideband the band runs', () {
      rig.move(freqKHz: 7200, mode: 'SSB');
      expect(ask('m'), startsWith('LSB\n'));
    });

    test('the extended form labels every value, the way HaLo\'s own driver reads it', () {
      // Pinned against `rigctld -m 1` answering `+f`, `+m` and `;f`.
      expect(ask('+f'), 'get_freq:\nFrequency: 14074000\nRPRT 0\n');
      expect(ask('+m'), 'get_mode:\nMode: USB\nPassband: 3000\nRPRT 0\n');
      expect(ask(';f'), 'get_freq:;Frequency: 14074000;RPRT 0\n');
      expect(ask(r'+\get_mode'), 'get_mode:\nMode: USB\nPassband: 3000\nRPRT 0\n');
    });

    test('but a level\'s value is bare in every extended form, the header naming it', () {
      // Pinned against `rigctld -m 1` (Hamlib 4.7.2). A client reading the
      // extended form takes the line after `get_level:` as the number, and
      // `Level Value: 0` is not one.
      expect(ask('+l KEYSPD'), 'get_level: KEYSPD\n0\nRPRT 0\n');
      expect(ask(';l KEYSPD'), 'get_level: KEYSPD;0;RPRT 0\n');
      expect(ask('|l KEYSPD'), 'get_level: KEYSPD|0|RPRT 0\n');
      expect(ask(',l KEYSPD'), 'get_level: KEYSPD,0,RPRT 0\n');
      expect(ask(r'+\get_level KEYSPD'), 'get_level: KEYSPD\n0\nRPRT 0\n');
    });

    test('with no radio connected, a read is an IO error rather than a stale frequency', () {
      rig.available = false;
      expect(ask('f'), 'RPRT -6\n');
      expect(ask('+f'), 'get_freq:\nRPRT -6\n');
      expect(ask(r'\get_powerstat'), '0\n');
    });
  });

  group('tuning the radio', () {
    test('a frequency in Hz reaches the rig in kHz', () {
      expect(ask('F 7074000.000000'), 'RPRT 0\n');
      expect(rig.tunes.single, (freqKHz: 7074.0, mode: null));
    });

    test('a Hamlib mode reaches the rig by its app name, passband ignored', () {
      expect(ask('M PKTUSB 0'), 'RPRT 0\n');
      expect(rig.tunes.single, (freqKHz: null, mode: 'DATA-USB'));
    });

    test('the extended form echoes the arguments', () {
      expect(ask('+F 7074000'), 'set_freq: 7074000\nRPRT 0\n');
    });

    test('CWR reaches the rig as CW: the log has no reverse-sideband mode', () {
      expect(ask('M CWR 0'), 'RPRT 0\n');
      expect(rig.tunes.single, (freqKHz: null, mode: 'CW'));
    });

    test('a mode nothing here knows is refused, not written into the logging panel', () {
      expect(ask('M ? 0'), 'RPRT -1\n');
      expect(ask('M WFM 0'), 'RPRT -1\n');
      expect(rig.tunes, isEmpty);
    });

    test('NaN, infinity and absurd frequencies are refused: each parses as a number', () {
      // Written into vfoA, any of them reaches the logging panel, a logged
      // contact and the radio, and every later read of the frequency throws.
      for (final hz in ['NaN', 'Infinity', 'inf', '1e400', '-7074000', '0', '1e15']) {
        expect(ask('F $hz'), 'RPRT -1\n', reason: hz);
      }
      expect(rig.tunes, isEmpty);
    });

    test('a frequency that is not a number is refused, not sent', () {
      expect(ask('F abc'), 'RPRT -1\n');
      expect(rig.tunes, isEmpty);
    });

    test('with no radio connected nothing is tuned', () {
      rig.available = false;
      expect(ask('F 7074000'), 'RPRT -6\n');
      expect(rig.tunes, isEmpty);
    });

    test('PTT is refused as unavailable, so a client falls back to its own keying', () {
      expect(ask('T 1'), 'RPRT -11\n');
    });

    test('split can be turned off but not on', () {
      expect(ask('S 0 VFOA'), 'RPRT 0\n');
      expect(ask('S 1 VFOB'), 'RPRT -11\n');
    });
  });

  group('the stream', () {
    test('a command split across two reads is answered once, whole', () {
      connection.receive(Uint8List.fromList(utf8.encode('+')));
      connection.receive(Uint8List.fromList(utf8.encode('f\nm\n')));
      expect(sent, ['get_freq:\nFrequency: 14074000\nRPRT 0\n', 'USB\n3000\n']);
    });

    test('an unknown command still gets an answer, or the client waits out its timeout', () {
      expect(ask(r'\no_such_command'), 'RPRT -11\n');
    });

    test('a line that never ends hangs up rather than buffering without limit', () {
      connection.receive(Uint8List(40 * 1024));
      expect(hangUps, 0, reason: 'short of the limit, still a client');
      connection.receive(Uint8List(40 * 1024));
      expect(hangUps, 1);
    });

    test('a web page\'s request is hung up on before its body can be read as commands', () {
      // A page can POST to localhost:4532 without asking; read line by line,
      // `F 7000000` in its body would retune the radio.
      connection.receive(Uint8List.fromList(utf8.encode('POST / HTTP/1.1\r\nHost: localhost:4532\r\n\r\nF 7000000\n')));
      expect(hangUps, 1);
      expect(rig.tunes, isEmpty);
    });

    test('q ends the connection', () {
      connection.receive(Uint8List.fromList(utf8.encode('q\nf\n')));
      expect(quits, 1, reason: 'a quit, not a hang-up: replies already sent are still owed');
      expect(hangUps, 0);
      expect(sent, isEmpty, reason: 'nothing after the quit is answered');
    });
  });
}
