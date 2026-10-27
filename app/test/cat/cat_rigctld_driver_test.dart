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
import 'package:ham2k_logger/services/cat/drivers/voice_activity_tracker.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import '../support/fake_clock.dart';

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

  final keyerSpeeds = <int>[];
  @override
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  final voiceActivity = <VoiceActivity?>[];
  @override
  void reportVoiceActivity(VoiceActivity? activity) => voiceActivity.add(activity);

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}

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

    test('a level reads from the bare value after its get_level header', () {
      // Hamlib labels `+f`'s answer (`Frequency: …`) but NOT `+l`'s: the value
      // is bare, told apart only by the header before it — as captured from
      // rigctld 4.7.2, and the same in 4.5. A parser waiting for
      // `VD_METER: 13.8` reads no level from a real daemon at all.
      final sink = _FakeSink();
      _stateOnlySession(sink).feed('get_level: VD_METER\n13.800000\nRPRT 0\n');
      expect(sink.meterReports, [(RadioMeter.supplyVolts, 13.8)]);
    });

    test('a --vfo daemon\'s header names the VFO, and the level still reads', () {
      final sink = _FakeSink();
      _stateOnlySession(sink).feed('get_level: currVFO:VD_METER\n13.7\nRPRT 0\n');
      expect(sink.meterReports, [(RadioMeter.supplyVolts, 13.7)]);
    });

    test('a server that labels the value anyway still reads', () {
      // Emulations differ from Hamlib here; the header is what names the
      // level, whatever label the value line carries.
      final sink = _FakeSink();
      _stateOnlySession(sink).feed('get_level: VD_METER\nLevel Value: 13.9\nRPRT 0\n');
      expect(sink.meterReports, [(RadioMeter.supplyVolts, 13.9)]);
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

  group('PTT', () {
    test('keys with T 1 and unkeys with T 0', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setPtt(true);
      session.setPtt(false);
      expect(sink.sent, ['T 1\n', 'T 0\n']);
    });

    test('a --vfo daemon is told the VFO on PTT too', () {
      // Sent bare to a `--vfo` daemon, `T 1` is misparsed — its `1` taken
      // for the VFO name — and the radio silently never keys.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.feed('ChkVFO: 1\n');
      session.setPtt(true);
      expect(sink.sent, ['T currVFO 1\n']);
    });

    test('teardown unkeys a radio the app keyed', () {
      // rigctld holds the radio after we hang up: a teardown that forgets
      // the unkey leaves the transmitter on the air with nothing left to
      // turn it off.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.setPtt(true);
      sink.sent.clear();
      session.teardown();
      expect(sink.sent, ['T 0\n']);
    });

    test('teardown sends no PTT on a radio the app never keyed', () {
      // An unkey from a session that never keyed would cut off the operator
      // transmitting from the radio's own mic.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      sink.sent.clear();
      session.teardown();
      expect(sink.sent, isEmpty);
    });
  });

  group('polling', () {
    test('startUpdates probes the parser, then asks with self-labeling reads', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      // Nothing but the probe until it is answered: a read sent blind leaves
      // a `--vfo` daemon waiting for its VFO or level name, and it takes the
      // next line it is sent as that — running the rest of the line as
      // commands (rigctld 4.7.2 -o, captured).
      expect(sink.sent, ['+\\chk_vfo\n']);
      // The + prefix is what makes each answer parse on its own — a plain
      // `f` answers with a bare number indistinguishable from a plain `m`'s
      // passband line without order bookkeeping.
      session.feed('ChkVFO: 0\n');
      expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n']);
      session.teardown();
    });

    test('a quiet daemon is asked again on the slow cadence', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
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
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('CHKVFO 1\n');
        sink.sent.clear();
        session.setFrequency(14250);
        expect(sink.sent, ['F currVFO 14250000\n']);
        session.teardown();
      });
    });

    test('a daemon too old to know the probe answers an error, and is polled plain', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('RPRT -4\n');
        expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n']);
        session.teardown();
      });
    });

    test('a probe nobody answers still ends in a polled connection', () {
      // Waiting forever would leave a daemon that drops the probe connected
      // and never read.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        async.elapse(const Duration(milliseconds: 1900));
        expect(sink.sent, ['+\\chk_vfo\n']);
        async.elapse(const Duration(milliseconds: 200));
        expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n']);
        session.teardown();
      });
    });

    test('no poll of either kind reaches a daemon that has not answered the probe', () {
      // A real TX watch runs every 200 ms; a probe slower than that would have
      // the daemon parse a bare `+t` before it says how it wants addressing.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink, const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        async.elapse(const Duration(milliseconds: 1900));
        expect(sink.sent, ['+\\chk_vfo\n']);
        session.teardown();
      });
    });

    test('an answer after the timeout still corrects the addressing', () {
      // A slow --vfo daemon is polled plain at first; left that way, every
      // command for the rest of the connection is misparsed.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        async.elapse(const Duration(seconds: 2));
        session.feed('ChkVFO: 1\n');
        sink.sent.clear();
        session.setFrequency(14250);
        expect(sink.sent, ['F currVFO 14250000\n']);
        expect(sink.diagnostics.last, contains('--vfo'));
        session.teardown();
      });
    });

    test('an answer arriving after the session stopped starts nothing', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.stopUpdates();
        session.feed('ChkVFO: 0\n');
        async.elapse(const Duration(seconds: 10));
        expect(sink.sent, ['+\\chk_vfo\n']);
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
        expect(sink.sent, ['+\\chk_vfo\n'], reason: 'asked again, not assumed from the last connection');
        session.feed('ChkVFO: 0\n');
        expect(sink.sent, ['+\\chk_vfo\n', '+f\n', '+m\n']);
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
        session.feed('ChkVFO: 0\n');
        sink.sent.clear();
        async.elapse(const Duration(milliseconds: 450));
        expect(sink.sent, ['+t\n', '+t\n']);
        session.teardown();
      });
    });

    test('a keyed rig has every meter read, and each answer is parsed', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
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

        session.feed('get_level: SWR\n1.400000\nRPRT 0\n');
        session.feed('get_level: ALC\n0.250000\nRPRT 0\n');
        session.feed('get_level: VD_METER\n13.600000\nRPRT 0\n');
        session.feed('get_level: RFPOWER_METER_WATTS\n48.5\nRPRT 0\n');
        expect(sink.meterReports, [(RadioMeter.swr, 1.4), (RadioMeter.alc, 0.25), (RadioMeter.supplyVolts, 13.6), (RadioMeter.powerOut, 48.5)]);
        // A measurement, never the station's power: reported as power, the
        // 0 W between overs would replace the operator's on every QSO logged.
        expect(sink.powers, isEmpty);
        session.teardown();
      });
    });

    test('the state poll\'s own answer defers its next round', () {
      // The other half of the rule the starvation tests pin: the answers that
      // DO defer. Without it the poll re-asks on a schedule set before the
      // answer arrived, which is a question asked twice for nothing.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        async.elapse(kPollSlow - const Duration(milliseconds: 100));
        sink.sent.clear();
        session.feed('get_freq:\nFrequency: 14074000\nRPRT 0\n');
        async.elapse(const Duration(milliseconds: 200));
        expect(sink.sent.where((c) => c == '+f\n'), isEmpty, reason: 'the poll was due, but the frequency had just arrived');
        async.elapse(kPollSlow);
        expect(sink.sent.where((c) => c == '+f\n'), isNotEmpty);
        session.teardown();
      });
    });

    test('an idle rig\'s PTT watch does not starve the frequency poll', () {
      // A real rigctld answers each `+t` with a header and a status around the
      // value — `get_ptt:`, `PTT: 0`, `RPRT 0` — several times a second. Any
      // of those lines counted as news re-arms the state timer before it can
      // fire, and a radio tuned by hand is then read only on the 9-second
      // staleness ceiling instead of the 3-second slow poll.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        var answered = 0;
        // Answers every question the way rigctld does, the radio sitting
        // still, for [duration].
        void run(Duration duration) {
          for (var t = Duration.zero; t < duration; t += const Duration(milliseconds: 200)) {
            async.elapse(const Duration(milliseconds: 200));
            for (final command in sink.sent.skip(answered)) {
              if (command == '+t\n') session.feed('get_ptt:\nPTT: 0\nRPRT 0\n');
              if (command == '+f\n') session.feed('get_freq:\nFrequency: 14074000\nRPRT 0\n');
              if (command == '+m\n') session.feed('get_mode:\nMode: USB\nPassband: 3000\nRPRT 0\n');
            }
            answered = sink.sent.length;
          }
        }

        run(const Duration(seconds: 12)); // past the first staleness ceiling, so the window below holds at most one
        final before = sink.sent.where((c) => c == '+f\n').length;
        run(const Duration(seconds: 6));
        final polls = sink.sent.where((c) => c == '+f\n').length - before;
        expect(polls, greaterThanOrEqualTo(2), reason: 'a still radio is re-read on the slow poll, not the staleness ceiling');
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
          // Each meter answered as a real rigctld answers it: header, value,
          // status.
          session.feed('get_ptt:\nPTT: 1\nRPRT 0\n');
          session.feed('get_level: RFPOWER_METER_WATTS\n48.5\nRPRT 0\n');
          session.feed('get_level: SWR\n1.4\nRPRT 0\n');
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
      session.feed('get_level: SWR\n0.000000\nRPRT 0\n');
      expect(sink.meterReports, isEmpty);
      session.teardown();
    });
  });

  group('levels the daemon refuses', () {
    RigctldSession watching(_FakeSink sink) => RigctldSession(sink, const {telemetryIntervalConfigKey: 200});

    /// The meter reads one keyed poll puts on the wire.
    List<String> meterReads(_FakeSink sink, void Function() poll) {
      sink.sent.clear();
      poll();
      return sink.sent.where((c) => c.startsWith('+l')).toList();
    }

    test('a refused meter is not asked for again on every keyed poll', () {
      // Without this a rig with no ALC meter is asked for one several times
      // a second for as long as the operator transmits, and answers RPRT -11
      // every time.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('PTT: 1\n');
        session.feed('get_level: ALC\nRPRT -11\n');
        session.feed('get_level: VD_METER\nRPRT -4\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), ['+l RFPOWER_METER_WATTS\n', '+l SWR\n']);
        session.teardown();
      });
    });

    test('a level name the daemon does not know is retired too', () {
      // An older Hamlib has no RFPOWER_METER_WATTS and answers RPRT -1 for
      // it — several times a second, for as long as the operator transmits.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
        session.feed('PTT: 1\n');
        session.feed('get_level: RFPOWER_METER_WATTS\nRPRT -1\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), isNot(contains('+l RFPOWER_METER_WATTS\n')));
        session.teardown();
      });
    });

    test('a refusal just after an extension\'s raw command retires nothing — and one after that does', () {
      // A raw `\get_level SWR 1` is refused under the same header as the
      // driver's own SWR read: counted, it would end the SWR meter for the
      // connection.
      followFakeClock();
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('PTT: 1\n');
        session.sendRaw(ascii.encode('+\\get_level SWR 1\n'));
        session.feed('get_level: SWR\nRPRT -1\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), contains('+l SWR\n'));

        async.elapse(rawRefusalGrace);
        session.feed('get_level: SWR\nRPRT -1\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), isNot(contains('+l SWR\n')), reason: 'the grace ends');
        session.teardown();
      });
    });

    test('a failure that could pass is not a refusal', () {
      // RPRT -5 is a timeout talking to the radio: asked again, it may answer.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('PTT: 1\n');
        session.feed('get_level: SWR\nRPRT -5\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), contains('+l SWR\n'));
        session.teardown();
      });
    });

    test('a refusal is a fact about this connection, re-learned on the next', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
        session.feed('get_level: SWR\nRPRT -11\n');
        session.stopUpdates();
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
        session.feed('PTT: 1\n');
        expect(
          meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))),
          contains('+l SWR\n'),
          reason: 'a reconnect may reach a different daemon or backend',
        );
        session.teardown();
      });
    });

    test('a refusal of a question the daemon misparsed retires nothing', () {
      // The reads sent before `\chk_vfo` is answered reach a `--vfo` daemon
      // with no VFO, and it answers with one of its own making (captured
      // from rigctld 4.7.2 -o). That RPRT -1 is about the parse, not the
      // level — retiring on it would lose a meter the rig does have.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        session.feed('get_level: None:SWR\nRPRT -1\n');
        session.feed('PTT: 1\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), contains('+l currVFO SWR\n'));
        session.teardown();
      });
    });

    test('what the session negotiated and was refused is one developer diagnostic', () {
      // The sink keeps a single diagnostic, so separate calls would each hide
      // the last — "why no SWR through rigctld?" needs the mode and the
      // refusals together.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        session.feed('get_level: currVFO:SWR\nRPRT -11\n');
        session.feed('get_level: currVFO:ALC\nRPRT -4\n');
        expect(sink.diagnostics.last, '--vfo · refused SWR -11, ALC -4');
        session.teardown();
      });
    });

    test('an RPRT that answers something else retires nothing', () {
      // `RPRT -11` after a refused `F` or `T` is not about any level.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = watching(sink);
        session.startUpdates();
        session.feed('PTT: 1\n');
        session.feed('get_level: SWR\n1.2\nRPRT 0\nRPRT -11\n');
        expect(meterReads(sink, () => async.elapse(const Duration(milliseconds: 200))), contains('+l SWR\n'));
        session.teardown();
      });
    });
  });

  group('CW', () {
    final registry = EquipmentRegistry();

    test('offered on the SOTAcat entry, and on a generic rigctld only when a developer says', () {
      // Whether the backend behind a daemon keys Morse cannot be asked
      // without keying it, and most answer `send_morse` with RPRT -4.
      const driver = RigctldDriver();
      expect(driver.canKeyCwWith(const {}), isFalse);
      expect(driver.canKeyCwWith(const {cwKeyerConfigKey: true}), isTrue);
      final sotacat = registry.typeFor('sotacat-tcp')!;
      expect(sotacat.driver.canKeyCwWith(sotacat.driverConfig(const {})), isTrue);
      final generic = registry.typeFor('rigctld-tcp')!;
      expect(generic.driver.canKeyCwWith(generic.driverConfig(const {})), isFalse);
    });

    test('a message goes out with b, never naming a VFO, even to a --vfo daemon', () {
      // `send_morse` takes the rest of the line as its text: a `currVFO`
      // there is keyed as Morse (captured against rigctld 4.7.2 -o).
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        sink.sent.clear();
        session.sendCw('cq test');
        expect(sink.sent, ['+b CQ TEST\n']);
        session.teardown();
      });
    });

    test('a long message is paced out in Elecraft-buffer chunks', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        sink.sent.clear();
        session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
        expect(sink.sent.single.length, lessThanOrEqualTo('+b \n'.length + rigctldMorseChunkChars));
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent.where((c) => c.startsWith('+b ')), hasLength(2));
        session.teardown();
      });
    });

    test('stop abandons the queue and tells the daemon to stop keying, with no VFO', () {
      // A --vfo daemon reads a VFO after `\stop_morse` as a further command.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
        sink.sent.clear();
        session.stopCw();
        expect(sink.sent, ['+\\stop_morse\n']);
        expect(session.cwSending, isFalse);
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent.where((c) => c.startsWith('+b ')), isEmpty, reason: 'the rest of the message must not follow the stop');
        session.teardown();
      });
    });

    test('the keyer speed is read once the probe is answered, never in the connect burst', () {
      // Sent blind, `+l KEYSPD` reaches a `--vfo` daemon behind a level read
      // that swallows its `+l`, and the daemon then runs `KEYSPD` as one-letter
      // commands — `E` is set_mem, `Y` set_ant (rigctld 4.7.2 -o, captured).
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = RigctldSession(sink, const {telemetryIntervalConfigKey: 600000, cwKeyerConfigKey: true});
        session.startUpdates();
        expect(sink.sent.where((c) => c.contains('KEYSPD')), isEmpty);
        session.feed('ChkVFO: 1\n');
        expect(sink.sent.where((c) => c.contains('KEYSPD')), ['+l currVFO KEYSPD\n']);
        session.feed('ChkVFO: 1\n');
        expect(sink.sent.where((c) => c.contains('KEYSPD')), hasLength(1), reason: 'once per connection');
        session.teardown();
      });
    });

    test('a plain daemon is asked bare, and a node that does not key is not asked', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final keys = RigctldSession(sink, const {telemetryIntervalConfigKey: 600000, cwKeyerConfigKey: true});
        keys.startUpdates();
        keys.feed('ChkVFO: 0\n');
        expect(sink.sent, contains('+l KEYSPD\n'));
        keys.teardown();

        final quiet = _FakeSink();
        final plain = _stateOnlySession(quiet);
        plain.startUpdates();
        plain.feed('ChkVFO: 0\n');
        expect(quiet.sent.where((c) => c.contains('KEYSPD')), isEmpty, reason: 'a daemon with no keyer would only refuse it');
        plain.teardown();
      });
    });

    test('the keyer speed is set on the VFO, clamped, then read back', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        sink.sent.clear();
        session.setKeyerSpeed(99);
        expect(sink.sent, ['L currVFO KEYSPD ${rigctldKeyerSpeedRange.max}\n', '+l currVFO KEYSPD\n']);
        session.feed('get_level: currVFO:KEYSPD\n25\nRPRT 0\n');
        expect(sink.keyerSpeeds, [25]);
        session.teardown();
      });
    });

    test('an entry\'s pinned range is what the speed control offers and the set clamps to', () {
      // The SOTAcat's KX2/KX3 take 8-50; offered the generic 4-60, the control
      // shows speeds the radio silently refuses.
      final sotacat = EquipmentRegistry().typeFor('sotacat-tcp')!;
      final sink = _FakeSink();
      final session = sotacat.driver.createSession(sink, sotacat.driverConfig(const {})) as RigctldSession;
      expect(session.keyerSpeedRange, (min: 8, max: 50));
      session.setKeyerSpeed(60);
      expect(sink.sent.first, 'L KEYSPD 50\n');
      session.teardown();
    });

    test('where the speed cannot be read back, the set speed paces the queue', () {
      // Paced at the 20 WPM default instead, a 12 WPM keyer is handed its next
      // chunk while the last is still going out, and overruns its buffer.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('get_level: KEYSPD\nRPRT -11\n');
        session.setKeyerSpeed(12);
        expect(sink.keyerSpeeds, isEmpty, reason: 'never reported as the radio\'s');
        sink.sent.clear();
        session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
        // The first chunk's duration at 12 WPM is well past its duration at 20.
        final firstChunk = sink.sent.single.substring(3).trim();
        async.elapse(cwDuration(firstChunk, defaultCwSpeedWpm) + const Duration(milliseconds: 50));
        expect(sink.sent.where((c) => c.startsWith('+b ')), hasLength(1), reason: 'the second chunk waits for the 12 WPM keyer');
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent.where((c) => c.startsWith('+b ')), hasLength(2));
        session.teardown();
      });
    });

    test('a refused send keys nothing, so the strip stops showing it and the developer is told', () {
      // A backend without Morse answers `send_morse` with RPRT -4. Paced on
      // regardless, the strip animates a message nobody hears.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
        session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
        session.feed('send_morse: CQ CQ CQ DE N0DEV N0DEV\nRPRT -4\n');
        expect(session.cwSending, isFalse);
        expect(sink.diagnostics.last, contains('send_morse -4'));
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent.where((c) => c.startsWith('+b ')), hasLength(1), reason: 'the rest of the message must not follow');
        session.teardown();
      });
    });

    test('a refused stop is told to the developer: the chunk on the radio plays out', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 1\n');
        session.stopCw();
        session.feed('stop_morse: currVFO\nRPRT -11\n');
        expect(sink.diagnostics.last, contains('stop_morse -11'));
        session.teardown();
      });
    });

    test('a read-back of zero leaves the asked speed pacing the queue', () {
      // A backend that sets KEYSPD but reads it back as 0: ignoring the 0 is
      // right for the speed control, and pacing must not fall back to 20 WPM.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        session.feed('ChkVFO: 0\n');
        session.setKeyerSpeed(12);
        session.feed('get_level: KEYSPD\n0\nRPRT 0\n');
        sink.sent.clear();
        session.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
        final firstChunk = sink.sent.single.substring(3).trim();
        async.elapse(cwDuration(firstChunk, defaultCwSpeedWpm) + const Duration(milliseconds: 50));
        expect(sink.sent.where((c) => c.startsWith('+b ')), hasLength(1), reason: 'the second chunk waits for the 12 WPM keyer');
        session.teardown();
      });
    });

    test('a keyer speed of zero is a backend without one, not a stopped keyer', () {
      // The dummy backend answers 0 until a speed is set. Reported, the
      // speed control would show 0 WPM and the queue would pace at it.
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.feed('get_level: KEYSPD\n0\nRPRT 0\n');
      expect(sink.keyerSpeeds, isEmpty);
      session.teardown();
    });
  });

  group('voice', () {
    final registry = EquipmentRegistry();

    /// The SOTAcat entry's session, already answered as a plain or `--vfo`
    /// daemon.
    RigctldSession sotacat(_FakeSink sink, {bool vfoMode = false}) {
      final type = registry.typeFor('sotacat-tcp')!;
      final session = type.driver.createSession(sink, {...type.driverConfig(const {}), telemetryIntervalConfigKey: 600000}) as RigctldSession;
      session.startUpdates();
      session.feed('ChkVFO: ${vfoMode ? 1 : 0}\n');
      sink.sent.clear();
      return session;
    }

    test('offered on the SOTAcat entry with the KX DVR\'s two memories, and nowhere it is not pinned', () {
      final sotacatType = registry.typeFor('sotacat-tcp')!;
      expect(sotacatType.driver.voiceMemoryCountWith(sotacatType.driverConfig(const {})), 2);
      final generic = registry.typeFor('rigctld-tcp')!;
      expect(generic.driver.voiceMemoryCountWith(generic.driverConfig(const {})), 0);
      final session = sotacat(_FakeSink());
      expect(session.voiceMemoryCount, 2);
      expect(session.canRecordVoice, isFalse, reason: 'Hamlib has no command that records');
      expect(session.voiceMemoryCeiling, const Duration(seconds: 15));
      session.teardown();
    });

    test('a memory plays with send_voice_mem, never naming a VFO, even to a --vfo daemon', () {
      // The `+` form on a `--vfo` daemon waits for an argument it never gets,
      // and a VFO there is read as the memory (rigctld 4.7.2 -o, captured).
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = sotacat(sink, vfoMode: true);
        session.playVoiceMemory(2);
        expect(sink.sent, ['\\send_voice_mem 2\n']);
        expect(sink.voiceActivity, [const VoiceActivity(memory: 2)]);
        session.teardown();
      });
    });

    test('a memory the radio does not have is not sent', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = sotacat(sink);
        session.playVoiceMemory(3);
        session.playVoiceMemory(0);
        expect(sink.sent, isEmpty);
        expect(sink.voiceActivity, isEmpty);
        session.teardown();
      });
    });

    test('the memory is over when the radio stops transmitting', () {
      // Hamlib has no "still playing?", so the transmitter is the answer —
      // what the KX's own TQ; is on the Kenwood driver.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = sotacat(sink);
        session.playVoiceMemory(1);
        async.elapse(voiceActivityPollInterval);
        expect(sink.sent, contains('+t\n'), reason: 'asked while it plays, not left to the slow PTT watch');
        session.feed('get_ptt:\nPTT: 1\nRPRT 0\n');
        session.feed('get_ptt:\nPTT: 0\nRPRT 0\n');
        expect(sink.voiceActivity, [const VoiceActivity(memory: 1), null]);
        session.teardown();
      });
    });

    test('a memory the radio never keys for is shown doubtful, not as a short play', () {
      // An empty memory, or the rig not in a voice mode: refused with an
      // unlabeled RPRT nothing ties back to the play.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = sotacat(sink);
        session.playVoiceMemory(1);
        // Past the radio's chance to key up, which the tracker waits out.
        async.elapse(voiceActivityPollInterval);
        session.feed('get_ptt:\nPTT: 0\nRPRT 0\n');
        expect(sink.voiceActivity.last, const VoiceActivity(memory: 1, doubtful: true));
        session.teardown();
      });
    });

    test('stop tells the daemon, with no VFO, and clears what showed', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = sotacat(sink, vfoMode: true);
        session.playVoiceMemory(1);
        sink.sent.clear();
        session.stopVoice();
        expect(sink.sent, ['\\stop_voice_mem\n']);
        expect(sink.voiceActivity.last, isNull);
        session.teardown();
      });
    });

    test('a memory still showing at its 15 s length is stopped on the air', () {
      // A rig whose PTT read never comes back would otherwise show the message
      // playing forever — and one the app stops showing must not still be
      // transmitting.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = sotacat(sink);
        session.playVoiceMemory(1);
        session.feed('get_ptt:\nPTT: 1\nRPRT 0\n');
        async.elapse(const Duration(seconds: 16));
        expect(sink.sent, contains('\\stop_voice_mem\n'));
        expect(sink.voiceActivity.last, isNull);
        session.teardown();
      });
    });
  });
}
