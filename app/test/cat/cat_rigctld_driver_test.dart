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
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/rigctld_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) => powers.add(watts);

  final txReports = <bool>[];
  final meterReports = <(RadioMeter, num)>[];
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meterReports.add((meter, value));

  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

extension on RigctldSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

/// A session whose TX watch is set so slow it never fires inside a test.
///
/// The tests below assert on the exact lines the STATE poll puts on the
/// wire, and the two pollers write to the same socket on different
/// cadences. Unlike flrig, nothing here would be misread — rigctld labels
/// every extended answer — so this is about keeping those assertions about
/// the poll they are describing. The watch has its own tests below.
RigctldSession _stateOnlySession(EquipmentSink sink) => RigctldSession(sink, const {telemetryIntervalConfigKey: 600000});

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
      _stateOnlySession(sink).feed('get_freq:\nFrequency: 14250000\nRPRT 0\n');
      expect(sink.readings, [const VfoReading(freqKHz: 14250)]);
    });

    test('a mode answer reports the app spelling and ignores the passband', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).feed('get_mode:\nMode: PKTUSB\nPassband: 3000\nRPRT 0\n');
      expect(sink.readings, [const VfoReading(mode: 'DATA-USB')]);
    });

    test('a response split across chunks still parses', () {
      // TCP delivers arbitrary chunks; a line straddling two reads is the
      // expected case, not a rare one.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.feed('get_freq:\nFrequen');
      expect(sink.readings, isEmpty);
      session.feed('cy: 7074000\r\nRPRT 0\n');
      expect(sink.readings, [const VfoReading(freqKHz: 7074)]);
    });

    test('a labeled power line reports watts', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).feed('get_level:\nRFPOWER_METER_WATTS: 12.500000\n');
      expect(sink.powers, [12.5]);
    });

    test('error reports and unlabeled lines report nothing', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      // What a plain-protocol answer or a failed command would look like:
      // neither may be mistaken for a reading.
      session.feed('RPRT -1\n14250000\nUSB\nFrequency: garbage\n');
      expect(sink.readings, isEmpty);
    });
  });

  group('writing', () {
    test('frequency goes out as plain Hz on the current VFO', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).setFrequency(14250);
      expect(sink.sent, ['F 14250000\n']);
    });

    test('sub-kHz precision survives the kHz-to-Hz conversion', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).setFrequency(7074.5);
      expect(sink.sent, ['F 7074500\n']);
    });

    test('mode goes out translated, with the passband left unchanged', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).setMode('CW-R');
      // -1 = leave passband alone: retuning the mode must not clobber a
      // filter width the operator set at the radio.
      expect(sink.sent, ['M CWR -1\n']);
    });

    test('an unexpressible mode sends nothing rather than a malformed command', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).setMode('NO-SUCH');
      expect(sink.sent, isEmpty);
    });

    test('power goes out as an RFPOWER fraction, not the read-only meter level', () {
      // RFPOWER_METER_WATTS is Hamlib's read-only measured-output level —
      // set_level against it is rejected by every correct backend. RFPOWER
      // is the genuinely settable one, at the cost of an assumed 100W max.
      final sink = _FakeSink();
      _stateOnlySession(sink).setPower(75);
      expect(sink.sent, ['L RFPOWER 0.750\n']);
    });

    test('a power above the assumed maximum clamps to full scale, not over 1.0', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).setPower(150);
      expect(sink.sent, ['L RFPOWER 1.000\n']);
    });
  });

  group('polling', () {
    test('startUpdates probes the parser, then asks with self-labeling reads', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      // The + prefix is what makes each answer parse on its own — a plain
      // `f` answers with a bare number indistinguishable from a plain `m`'s
      // passband line without order bookkeeping. The probe leads so its
      // answer lands before the SECOND poll; the burst behind it goes out
      // bare on purpose rather than waiting one RTT.
      expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n', '+l RFPOWER_METER_WATTS\n']);
      session.teardown();
    });

    test('a quiet daemon is asked again on the slow cadence', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        sink.sent.clear();
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, ['+f\n', '+m\n', '+l RFPOWER_METER_WATTS\n']);
        session.teardown();
      });
    });

    test('a moving radio drops the poll to the fast cadence', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('Frequency: 14250000\n');
        expect(session.pollInterval, kPollSlow, reason: 'the first reading is the answer to startUpdates, not movement');
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
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        sink.sent.clear();
        async.elapse(kPollSlow + const Duration(milliseconds: 10));
        expect(sink.sent, ['+f currVFO\n', '+m currVFO\n', '+l currVFO RFPOWER_METER_WATTS\n']);
        session.setFrequency(14250);
        session.setMode('CW-R');
        expect(sink.sent.sublist(3), ['F currVFO 14250000\n', 'M currVFO CWR -1\n']);
        session.teardown();
      });
    });

    test('the older CHKVFO spelling of the answer counts too', () {
      // Hamlib's reply spelling changed across versions; missing the old
      // one would read an old --vfo daemon as plain and lose its mode.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
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
        final session = _stateOnlySession(sink);
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
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        session.stopUpdates();
        sink.sent.clear();
        session.startUpdates();
        expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n', '+l RFPOWER_METER_WATTS\n']);
        session.teardown();
      });
    });

    test('teardown stops the polling', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.teardown();
        sink.sent.clear();
        async.elapse(kPollSlow * 5);
        expect(sink.sent, isEmpty);
      });
    });
  });
  group('the meters', () {
    RigctldSession watching(_FakeSink sink) => RigctldSession(sink, const {telemetryIntervalConfigKey: 200});

    test('the PTT is watched on its own cadence, and asked for nothing else', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        sink.sent.clear();
        async.elapse(const Duration(milliseconds: 450));
        expect(sink.sent, ['+t\n', '+t\n']);
        session.teardown();
      });
    });

    test('a keyed rig has every meter read, and each label is parsed', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        async.elapse(const Duration(milliseconds: 250));
        sink.sent.clear();

        session.feed('PTT: 1\n');
        expect(sink.txReports, [true]);
        expect(sink.sent, [
          // The watch rides along with the meters: re-asking is how the
          // unkey is noticed, and dropping it would leave the strip
          // reading a transmission that ended.
          '+t\n',
          '+l RFPOWER_METER_WATTS\n',
          '+l SWR\n',
          '+l ALC\n',
          '+l VD_METER\n',
        ]);

        session.feed('SWR: 1.400000\n');
        session.feed('ALC: 0.250000\n');
        session.feed('VD_METER: 13.600000\n');
        session.feed('RFPOWER_METER_WATTS: 48.5\n');
        expect(sink.meterReports, [(RadioMeter.swr, 1.4), (RadioMeter.alc, 0.25), (RadioMeter.supplyVolts, 13.6), (RadioMeter.powerOut, 48.5)]);
        // Hamlib is the one protocol here whose "power" IS a measurement,
        // so the same reading is both the app's power and the meter — see
        // the note at the parse.
        expect(sink.powers, [48.5]);
        session.teardown();
      });
    });

    test('a transmitting rig does not starve the frequency poll', () {
      // The half of the starvation that only bites during a transmission:
      // the meter cycle re-asks RFPOWER_METER_WATTS several times a second,
      // and that label is also what the STATE poll asks for — so an answer
      // counted as "the daemon told us something" re-arms the state timer
      // for as long as the operator holds the key.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('PTT: 1\n');
        sink.sent.clear();
        for (var i = 0; i < 20; i++) {
          async.elapse(const Duration(milliseconds: 200));
          session.feed('RFPOWER_METER_WATTS: 48.5\n');
        }
        expect(sink.sent.where((c) => c == '+f\n'), isNotEmpty, reason: 'the frequency poll was starved while transmitting');
        session.teardown();
      });
    });

    test('a backend answering zero for a meter it does not have says nothing', () {
      // Hamlib answers RPRT -11 for an unsupported level, but a backend
      // that implements the level against hardware that has no such meter
      // answers 0 — and a 0.0 SWR on the strip reads as a perfect match.
      final sink = _FakeSink();
      final session = watching(sink);
      session.feed('SWR: 0.000000\n');
      expect(sink.meterReports, isEmpty);
      session.teardown();
    });
  });
}
