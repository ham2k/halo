// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rigctld driver with no daemon and no socket. This pins the protocol
// as Hamlib's rigctld documents it — extended-response reads, plain
// writes, `\n` framing — and the mode-name translation in both directions.
// It does NOT establish that a real radio behind a real Hamlib backend
// behaves; that claim rests on a live pass against an IC-705 behind
// `rigctld -m 3085`, which is what `hardwareVerified` reports.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/rigctld_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);
}

extension on RigctldSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

void main() {
  group('mode names', () {
    test('translate between the app\'s spellings and Hamlib\'s tokens', () {
      expect(hamlibModeForAppMode('CW-R'), 'CWR');
      expect(hamlibModeForAppMode('DATA-USB'), 'PKTUSB');
      expect(hamlibModeForAppMode('usb'), 'USB', reason: 'case-insensitive');
      expect(appModeForHamlibMode('CWR'), 'CW-R');
      expect(appModeForHamlibMode('PKTLSB'), 'DATA-LSB');
    });

    test('both RTTY sidebands reach Hamlib, which spells them RTTY/RTTYR', () {
      expect(hamlibModeForAppMode('RTTY-LSB'), 'RTTY');
      expect(hamlibModeForAppMode('RTTY-USB'), 'RTTYR');
    });

    test('RTTY round-trips instead of answering back in Hamlib spelling', () {
      // Without the reverse entries, setting RTTY-USB shows raw "RTTYR" on
      // the next poll — a spelling no other surface of the app uses.
      expect(appModeForHamlibMode('RTTYR'), 'RTTY-USB');
      expect(appModeForHamlibMode('RTTY'), 'RTTY-LSB');
    });

    test('a token with no app spelling passes through instead of vanishing', () {
      // Hamlib's mode list is far longer than the table here; WFM on the
      // dial must not read as "no mode".
      expect(appModeForHamlibMode('WFM'), 'WFM');
      expect(hamlibModeForAppMode('PSK'), 'PSK');
    });

    test('a mode that cannot be a protocol token builds nothing', () {
      // A hyphenated name with no mapping would split into two arguments on
      // the wire — sending nothing is the only safe encoding.
      expect(hamlibModeForAppMode('NO-SUCH'), isNull);
      expect(hamlibModeForAppMode(null), isNull);
    });
  });

  group('reading', () {
    test('a labeled frequency line reports in kHz', () {
      final sink = _FakeSink();
      RigctldSession(sink).feed('get_freq:\nFrequency: 14250000\nRPRT 0\n');
      expect(sink.readings, [const VfoReading(freqKHz: 14250)]);
    });

    test('a mode answer reports the app spelling and ignores the passband', () {
      final sink = _FakeSink();
      RigctldSession(sink).feed('get_mode:\nMode: PKTUSB\nPassband: 3000\nRPRT 0\n');
      expect(sink.readings, [const VfoReading(mode: 'DATA-USB')]);
    });

    test('a response split across chunks still parses', () {
      // TCP delivers arbitrary chunks; a line straddling two reads is the
      // expected case, not a rare one.
      final sink = _FakeSink();
      final session = RigctldSession(sink);
      session.feed('get_freq:\nFrequen');
      expect(sink.readings, isEmpty);
      session.feed('cy: 7074000\r\nRPRT 0\n');
      expect(sink.readings, [const VfoReading(freqKHz: 7074)]);
    });

    test('error reports and unlabeled lines report nothing', () {
      final sink = _FakeSink();
      final session = RigctldSession(sink);
      // What a plain-protocol answer or a failed command would look like:
      // neither may be mistaken for a reading.
      session.feed('RPRT -1\n14250000\nUSB\nFrequency: garbage\n');
      expect(sink.readings, isEmpty);
    });
  });

  group('writing', () {
    test('frequency goes out as plain Hz on the current VFO', () {
      final sink = _FakeSink();
      RigctldSession(sink).setFrequency(14250);
      expect(sink.sent, ['F 14250000\n']);
    });

    test('sub-kHz precision survives the kHz-to-Hz conversion', () {
      final sink = _FakeSink();
      RigctldSession(sink).setFrequency(7074.5);
      expect(sink.sent, ['F 7074500\n']);
    });

    test('mode goes out translated, with the passband left unchanged', () {
      final sink = _FakeSink();
      RigctldSession(sink).setMode('CW-R');
      // -1 = leave passband alone: retuning the mode must not clobber a
      // filter width the operator set at the radio.
      expect(sink.sent, ['M CWR -1\n']);
    });

    test('an unexpressible mode sends nothing rather than a malformed command', () {
      final sink = _FakeSink();
      RigctldSession(sink).setMode('NO-SUCH');
      expect(sink.sent, isEmpty);
    });
  });

  group('polling', () {
    test('startUpdates probes the parser, then asks with self-labeling reads', () {
      final sink = _FakeSink();
      final session = RigctldSession(sink);
      session.startUpdates();
      // The + prefix is what makes each answer parse on its own — a plain
      // `f` answers with a bare number indistinguishable from a plain `m`'s
      // passband line without order bookkeeping. The probe leads so its
      // answer lands before the SECOND poll; the burst behind it goes out
      // bare on purpose rather than waiting one RTT.
      expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n']);
      session.teardown();
    });

    test('a quiet daemon is asked again on the slow cadence', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        sink.sent.clear();
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, ['+f\n', '+m\n']);
        session.teardown();
      });
    });

    test('a moving radio drops the poll to the fast cadence', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        session.feed('Frequency: 14250000\n');
        expect(session.pollInterval, kPollSlow,
            reason: 'the first reading is the answer to startUpdates, not movement');
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        session.feed('Frequency: 14260000\n');
        expect(session.pollInterval, kPollFast);
        session.teardown();
      });
    });

    test('a ChkVFO: 1 answer switches every command to naming the VFO', () {
      // A `--vfo` daemon reads a VFO token on every command; sent bare, our
      // `+f` consumes the `+m` behind it as that token and the mode is
      // never answered again. `currVFO` addresses whatever the rig has
      // selected — the same thing plain mode addresses implicitly.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        sink.sent.clear();
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, ['+f currVFO\n', '+m currVFO\n']);
        session.setFrequency(14250);
        session.setMode('CW-R');
        expect(sink.sent.sublist(2), ['F currVFO 14250000\n', 'M currVFO CWR -1\n']);
        session.teardown();
      });
    });

    test('the older CHKVFO spelling of the answer counts too', () {
      // Hamlib's reply spelling changed across versions; missing the old
      // one would read an old --vfo daemon as plain and lose its mode.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        session.feed('CHKVFO 1\n');
        sink.sent.clear();
        session.setFrequency(14250);
        expect(sink.sent, ['F currVFO 14250000\n']);
        session.teardown();
      });
    });

    test('a ChkVFO: 0 answer keeps commands bare', () {
      // The forms are mutually unintelligible: a plain daemon reads a
      // `currVFO` token as further commands and executes garbage.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
        sink.sent.clear();
        session.setFrequency(14250);
        expect(sink.sent, ['F 14250000\n']);
        session.teardown();
      });
    });

    test('the parser mode is re-learned on every startUpdates', () {
      // A reconnect may reach a daemon restarted the other way; carrying
      // the old answer over would speak the wrong dialect from the start.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        session.stopUpdates();
        sink.sent.clear();
        session.startUpdates();
        expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n']);
        session.teardown();
      });
    });

    test('teardown stops the polling', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink);
        session.startUpdates();
        session.teardown();
        sink.sent.clear();
        async.elapse(kPollSlow * 5);
        expect(sink.sent, isEmpty);
      });
    });
  });
}
