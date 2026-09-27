// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The N3FJP driver with no N3FJP and no socket. This pins the API as N3FJP
// publishes it — `<CMD>` messages, MHz, a log's modes, the unprompted
// report — and the translation of a log's mode into a radio's. It does NOT
// establish that a real N3FJP program answers this way; nothing has been
// captured from one.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/n3fjp_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final problems = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

extension on N3fjpSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));

  void bmf({required String band, required String mode, String modeTest = '', required String freq}) =>
      feed('<CMD><READBMFRESPONSE><BAND>$band</BAND><MODE>$mode</MODE><MODETEST>$modeTest</MODETEST><FREQ>$freq</FREQ></CMD>\r\n');
}

void main() {
  test('opens by asking whether a radio is behind N3FJP, and where it is', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      expect(sink.sent, ['<CMD><RIGENABLED></CMD>\r\n', '<CMD><READBMF></CMD>\r\n']);
      session.teardown();
    });
  });

  test('reads a log\'s mode as the radio mode behind it', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      // N3FJP's own example: SSB on 40 m. No radio has an SSB mode, and 40 m
      // runs the lower sideband.
      session.bmf(band: '40', mode: 'SSB', modeTest: 'PH', freq: '7.22802');
      expect(sink.readings.last, const VfoReading(freqKHz: 7228.02, mode: 'LSB'));

      session.bmf(band: '20', mode: 'SSB', modeTest: 'PH', freq: '14.25');
      expect(sink.readings.last.mode, 'USB');

      // FT8 is the data sideband, which the VFO reads back as FT8 when that
      // is what the operator chose.
      session.bmf(band: '20', mode: 'FT8', modeTest: 'DIG', freq: '14.074');
      expect(sink.readings.last.mode, 'DATA-USB');
      session.bmf(band: '20', mode: 'DATA', modeTest: 'DIG', freq: '14.074');
      expect(sink.readings.last.mode, 'DATA-USB');

      // A program that leaves the mode blank still writes its contest class.
      session.bmf(band: '20', mode: '', modeTest: 'CW', freq: '14.03');
      expect(sink.readings.last.mode, 'CW');
      session.teardown();
    });
  });

  test('a zero frequency is no reading, not a radio at 0 kHz', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      session.bmf(band: '', mode: '', freq: '0.000000');
      expect(sink.readings, isEmpty);
      session.teardown();
    });
  });

  test('messages split and joined across reads are each taken once', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      const both =
          '<CMD><READBMFRESPONSE><BAND>20</BAND><MODE>CW</MODE><FREQ>14.030</FREQ></CMD>\r\n'
          '<CMD><READBMFRESPONSE><BAND>40</BAND><MODE>CW</MODE><FREQ>7.030</FREQ></CMD>\r\n';
      session
        ..feed(both.substring(0, 30))
        ..feed(both.substring(30, 100))
        ..feed(both.substring(100));
      expect(sink.readings.map((r) => r.freqKHz), [14030, 7030]);
      session.teardown();
    });
  });

  test('an N3FJP with no radio interface is followed, and says so for as long as it lasts', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      // What it reports is what was typed into its entry window, and a tune
      // goes nowhere: a connected row with no word about that would look
      // like a radio that ignores the app.
      session.feed('<CMD><RIGRESPONSE><RIG>None</RIG></CMD>\r\n');
      expect(sink.problems.last, t.settings.station.n3fjpNoRig);
      // Asked again with the poll: the operator sets up N3FJP's rig
      // interface without reconnecting, and the problem must not outlive it.
      final asked = sink.sent.where((s) => s.contains('<RIGENABLED>')).length;
      async.elapse(const Duration(seconds: 10));
      expect(sink.sent.where((s) => s.contains('<RIGENABLED>')).length, greaterThan(asked));
      session.feed('<CMD><RIGRESPONSE><RIG>Icom</RIG></CMD>\r\n');
      expect(sink.problems.last, isNull);
      session.teardown();
    });
  });

  test('an unprompted report stands in for the poll', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      session.bmf(band: '20', mode: 'CW', freq: '14.030');
      // A report every second leaves nothing to ask, short of the poller's
      // staleness ceiling.
      for (var i = 0; i < 8; i++) {
        async.elapse(const Duration(seconds: 1));
        session.bmf(band: '20', mode: 'CW', freq: '14.030');
      }
      expect(sink.sent.where((s) => s.contains('<READBMF>')), hasLength(1));
      session.teardown();
    });
  });

  test('a frequency is tuned in MHz, leaving the mode alone', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      session.setFrequency(21074.5);
      // Without SUPPRESSMODEDEFAULT, N3FJP picks a mode for the new sub-band.
      expect(sink.sent.last, '<CMD><CHANGEFREQ><VALUE>21.074500</VALUE><SUPPRESSMODEDEFAULT>TRUE</SUPPRESSMODEDEFAULT></CMD>\r\n');
      session.teardown();
    });
  });

  test('a mode is tuned by the name N3FJP\'s mode field uses', () {
    fakeAsync((async) {
      final sink = _FakeSink();
      final session = N3fjpSession(sink)..startUpdates();
      session.setMode('DATA-USB');
      expect(sink.sent.last, '<CMD><CHANGEMODE><VALUE>DATA</VALUE></CMD>\r\n');
      session.setMode('CW-R');
      expect(sink.sent.last, '<CMD><CHANGEMODE><VALUE>CW</VALUE></CMD>\r\n');
      session.teardown();
    });
  });
}
