// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Voice keying at the driver layer, with no radio: what each dialect puts
// on the wire, and — the part that decides what the operator sees — when a
// session says a memory is over. None of these protocols report a memory's
// progress and only some answer "still playing?", so every session here is
// a bet on a particular question; these tests pin which question, and that
// the answer (or the ceiling) actually clears what was shown. A session
// that never clears shows a memory playing forever; one that clears on the
// wrong answer hides a memory still on the air.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/voice_activity_tracker.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

import '../support/fake_serial_ports.dart';

class _Sink implements EquipmentSink {
  final sent = <List<int>>[];
  final activities = <VoiceActivity?>[];

  List<String> get sentAscii => [for (final b in sent) ascii.decode(b)];

  /// The radio's side of the bus, for a CI-V session: answers every command
  /// with an ACK, as a radio does, so the driver's one-command-at-a-time
  /// sending moves on. Null is a radio that answers nothing.
  void Function(Uint8List frame)? answer;

  @override
  void send(List<int> bytes) {
    sent.add(bytes);
    answer?.call(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], 0xFB, 0xFD]));
  }

  @override
  void reportVoiceActivity(VoiceActivity? activity) => activities.add(activity);

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
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
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

const playing3 = VoiceActivity(memory: 3);
const recording2 = VoiceActivity(memory: 2, recording: true);

void main() {
  setUp(() => useSerialPortsForTest(const []));

  group('the tracker', () {
    test('disposing from the start report leaves no polling or delayed stop', () {
      fakeAsync((async) {
        final reports = <VoiceActivity?>[];
        var polls = 0;
        var stops = 0;
        late final VoiceActivityTracker tracker;
        tracker = VoiceActivityTracker(
          report: (activity) {
            reports.add(activity);
            if (activity != null) tracker.dispose();
          },
          poll: () => polls++,
          stop: () => stops++,
          ceiling: () => voiceActivityCeiling,
        );

        tracker.start(playing3);
        expect(reports, [playing3, null]);
        expect(tracker.active, isFalse);
        expect(async.pendingTimers, isEmpty, reason: 'a disconnected receiver must not rearm activity timers');
        async.elapse(voiceActivityCeiling + voiceActivityPollInterval);
        expect(polls, 0);
        expect(stops, 0, reason: 'the abandoned activity must not later stop another receiver\'s playback');
      });
    });

    test('reports the start, polls every second, and at the ceiling STOPS the radio and ends', () {
      fakeAsync((async) {
        final reports = <VoiceActivity?>[];
        var polls = 0;
        var stops = 0;
        late final VoiceActivityTracker tracker;
        tracker = VoiceActivityTracker(report: reports.add, poll: () => polls++, stop: () => stops++, ceiling: () => voiceActivityCeiling);
        tracker.start(playing3);
        expect(reports, [playing3]);
        async.elapse(const Duration(seconds: 5));
        expect(polls, 5);
        expect(stops, 0);
        async.elapse(voiceActivityCeiling - const Duration(seconds: 5));
        // The trap: ending only what is SHOWN — a recording the radio never
        // ends on its own would run on with its Stop control gone.
        expect(stops, 1, reason: 'the session\'s own stop goes to the radio');
        expect(reports.last, isNull, reason: 'the ceiling is the only end a silent radio gets');
        expect(tracker.active, isFalse);
        final pollsAtEnd = polls;
        async.elapse(const Duration(seconds: 5));
        expect(polls, pollsAtEnd, reason: 'no more questions once it is over');
      });
    });

    test('the ceiling is the session\'s — a radio whose memory holds ninety seconds is not cut at fifteen', () {
      fakeAsync((async) {
        var stops = 0;
        final tracker = VoiceActivityTracker(report: (_) {}, stop: () => stops++, ceiling: () => const Duration(seconds: 90));
        tracker.start(recording2);
        async.elapse(voiceActivityCeiling + const Duration(seconds: 1));
        expect(stops, 0, reason: 'still recording past the default ceiling');
        async.elapse(const Duration(seconds: 90));
        expect(stops, 1);
      });
    });

    test('"not going" before any "going" is a refusal: doubtful for a second, then stopped and over', () {
      fakeAsync((async) {
        final reports = <VoiceActivity?>[];
        var stops = 0;
        var polls = 0;
        final tracker = VoiceActivityTracker(report: reports.add, stop: () => stops++, poll: () => polls++, ceiling: () => voiceActivityCeiling);
        tracker.start(playing3);
        async.elapse(const Duration(seconds: 1));
        tracker.endFromPoll();
        expect(reports.last, const VoiceActivity(memory: 3, doubtful: true));
        expect(tracker.active, isTrue, reason: 'still shown, with its question mark');
        final pollsAtDoubt = polls;
        tracker.endFromPoll();
        expect(reports.last, const VoiceActivity(memory: 3, doubtful: true), reason: 'a second "not going" changes nothing');
        async.elapse(voiceDoubtLinger);
        expect(reports.last, isNull);
        // The trap: doubt as an end — a memory the radio was slow to start
        // would then play on behind a cleared strip with no Stop to reach it.
        expect(stops, 1, reason: 'a stop to an idle radio costs nothing; to a slow one it is the only stop');
        expect(polls, greaterThanOrEqualTo(pollsAtDoubt), reason: 'polling ran on through the doubt');
        // The trap: the same answer AFTER a confirmation read as a refusal —
        // a memory that played to its end would show a question mark.
        tracker.start(playing3);
        tracker.confirm();
        tracker.endFromPoll();
        expect(reports.last, isNull);
        expect(reports.where((r) => r?.doubtful ?? false), hasLength(1));
      });
    });

    test('a "going" after a doubt withdraws it — a radio slow to key up is not a refused play', () {
      fakeAsync((async) {
        final reports = <VoiceActivity?>[];
        var stops = 0;
        final tracker = VoiceActivityTracker(report: reports.add, stop: () => stops++, ceiling: () => voiceActivityCeiling);
        tracker.start(playing3);
        // The radio gets a poll interval to key up before anything it says
        // reads as a refusal — on CI-V the telemetry watch asks the same
        // question several times a second, and its first answer lands while
        // the rig is still keying.
        async.elapse(voiceActivityPollInterval);
        tracker.endFromPoll();
        expect(reports.last, const VoiceActivity(memory: 3, doubtful: true));
        tracker.confirm();
        expect(reports.last, playing3, reason: 'the question mark goes');
        async.elapse(voiceDoubtLinger * 2);
        expect(reports.last, playing3, reason: 'the withdrawn doubt does not end it');
        expect(stops, 0);
        tracker.endFromPoll();
        expect(reports.last, isNull, reason: 'confirmed, so the next "not going" is the end');
        // The ceiling still stands behind a doubted play.
        tracker.start(playing3);
        async.elapse(voiceActivityPollInterval);
        tracker.endFromPoll();
        tracker.confirm();
        async.elapse(voiceActivityCeiling + const Duration(seconds: 1));
        expect(stops, 1, reason: 'the ceiling survived the doubt');
      });
    });

    test('a "going" with nothing active is ignored — a late answer to the last play must not confirm the next', () {
      fakeAsync((async) {
        final reports = <VoiceActivity?>[];
        final tracker = VoiceActivityTracker(report: reports.add, stop: () {}, ceiling: () => voiceActivityCeiling);
        tracker.confirm();
        tracker.start(playing3);
        async.elapse(voiceActivityPollInterval);
        tracker.endFromPoll();
        expect(reports.last, const VoiceActivity(memory: 3, doubtful: true), reason: 'not confirmed by the stray answer');
      });
    });

    test('end is idempotent, and a start replaces what was going', () {
      fakeAsync((async) {
        final reports = <VoiceActivity?>[];
        final tracker = VoiceActivityTracker(report: reports.add, stop: () {}, ceiling: () => voiceActivityCeiling);
        tracker.end();
        expect(reports, isEmpty, reason: 'nothing to end, nothing reported');
        tracker.start(playing3);
        tracker.start(recording2);
        expect(reports, [playing3, recording2], reason: 'the second start is not an end of the first');
        tracker.end();
        tracker.end();
        expect(reports, [playing3, recording2, null]);
      });
    });
  });

  group('Icom CI-V', () {
    const radio = 0x94;
    const us = civDefaultControllerAddress;
    late _Sink sink;
    late IcomCivSession session;

    setUp(() {
      sink = _Sink();
      session = IcomCivSession(sink, radioAddress: radio, controllerAddress: us);
      sink.answer = session.handleData;
    });

    void feed(List<int> bytes) => session.handleData(Uint8List.fromList(bytes));

    test('plays with 0x28 0x00 nn and stops with 0x28 0x00 0x00; eight memories, no recording', () {
      expect(session.voiceMemoryCount, 8);
      expect(session.canRecordVoice, isFalse);
      session.playVoiceMemory(3);
      expect(sink.sent.single, [0xFE, 0xFE, radio, us, 0x28, 0x00, 0x03, 0xFD]);
      expect(sink.activities, [playing3]);
      session.stopVoice();
      expect(sink.sent.last, [0xFE, 0xFE, radio, us, 0x28, 0x00, 0x00, 0xFD]);
      expect(sink.activities.last, isNull);
      session.recordVoiceMemory(1);
      expect(sink.sent, hasLength(2), reason: 'nothing in CI-V records a memory');
    });

    test('while playing, asks whether it is transmitting, and ends when it is not', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        async.elapse(const Duration(seconds: 1));
        expect(sink.sent.last, [0xFE, 0xFE, radio, us, 0x1C, 0x00, 0xFD]);
        // Transmitting: still going.
        feed([0xFE, 0xFE, us, radio, 0x1C, 0x00, 0x01, 0xFD]);
        expect(sink.activities.last, playing3);
        feed([0xFE, 0xFE, us, radio, 0x1C, 0x00, 0x00, 0xFD]);
        expect(sink.activities.last, isNull, reason: 'seen transmitting, so this is the end, not a refusal');
      });
    });

    test('never seen transmitting, a play is doubtful for a second — the memory empty, or the mode wrong', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        async.elapse(const Duration(seconds: 1));
        feed([0xFE, 0xFE, us, radio, 0x1C, 0x00, 0x00, 0xFD]);
        expect(sink.activities.last, const VoiceActivity(memory: 3, doubtful: true));
        async.elapse(voiceDoubtLinger);
        expect(sink.activities.last, isNull);
        expect(sink.sent.last, [0xFE, 0xFE, radio, us, 0x28, 0x00, 0x00, 0xFD], reason: 'stopped, in case it was merely slow');
      });
    });

    test('the telemetry watch does not turn every play into a refusal', () {
      // The regression this exists for: the TX watch asks "are you
      // transmitting?" several times a second, and on CI-V that is the SAME
      // question the voice tracker polls with — so its answers reach the
      // tracker too. The first lands ~200 ms after the play command, while
      // the rig is still keying, and read as a refusal it puts a question
      // mark on every single play. On a slow link the doubt then expires and
      // STOPS a memory that is on the air.
      fakeAsync((async) {
        final sink = _Sink();
        final session = const IcomCivDriver().createSession(sink, const {voiceMemoriesConfigKey: 8, telemetryIntervalConfigKey: 200}) as VoiceKeyerSession;
        (session as EquipmentSession).startUpdates();
        session.playVoiceMemory(1);
        expect(sink.activities.last?.doubtful, isFalse);

        // Three watch cycles' worth of "not transmitting" while the radio
        // keys up — exactly what a real rig answers in that window.
        for (var i = 0; i < 3; i++) {
          async.elapse(const Duration(milliseconds: 200));
          session.handleData(Uint8List.fromList([0xFE, 0xFE, civDefaultControllerAddress, 0xA4, 0x1C, 0x00, 0x00, 0xFD]));
        }
        expect(sink.activities.last?.doubtful, isFalse, reason: 'the radio has not had a poll interval to key up');
        expect(sink.activities.last, isNotNull, reason: 'and the memory has certainly not been stopped');
        (session as EquipmentSession).teardown();
      });
    });

    test('a radio that keys up on the second poll loses its question mark', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        async.elapse(const Duration(seconds: 1));
        feed([0xFE, 0xFE, us, radio, 0x1C, 0x00, 0x00, 0xFD]);
        async.elapse(const Duration(milliseconds: 500));
        feed([0xFE, 0xFE, us, radio, 0x1C, 0x00, 0x01, 0xFD]);
        expect(sink.activities.last, playing3);
        async.elapse(const Duration(seconds: 2));
        expect(sink.activities.last, playing3, reason: 'the doubt did not expire into an end');
      });
    });

    test('a NAK ends nothing — it names no command, and the poll settles a refused play a second later', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        // The trap: a NAK in flight from the poll's meter read, read as the
        // play being refused, ending a memory that is on the air.
        feed([0xFE, 0xFE, us, radio, 0xFA, 0xFD]);
        expect(sink.activities, [playing3]);
        async.elapse(const Duration(seconds: 1));
        feed([0xFE, 0xFE, us, radio, 0x1C, 0x00, 0x00, 0xFD]); // receiving: it never started
        expect(sink.activities.last, const VoiceActivity(memory: 3, doubtful: true));
        async.elapse(voiceDoubtLinger);
        expect(sink.activities.last, isNull);
      });
    });

    test('an entry can pin a count of zero — a rig on this driver with no voice keyer', () {
      final none = IcomCivSession(sink, radioAddress: radio, controllerAddress: us, voiceMemories: 0);
      expect(none.voiceMemoryCount, 0);
      final type = EquipmentRegistry().typeFor('ic706mkiig-serial')!;
      final session = type.driver.createSession(sink, type.driverConfig(const {})) as IcomCivSession;
      expect(session.voiceMemoryCount, 0, reason: 'the IC-706 has none, and its entry says so');
      final ic7300 = EquipmentRegistry().typeFor('ic7300-serial')!;
      expect((ic7300.driver.createSession(sink, ic7300.driverConfig(const {})) as IcomCivSession).voiceMemoryCount, 8);
    });

    test('a stop with nothing playing sends nothing', () {
      session.stopVoice();
      expect(sink.sent, isEmpty);
    });

    test('teardown clears what was showing', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        session.teardown();
        expect(sink.activities.last, isNull);
        async.elapse(const Duration(seconds: 3));
        expect(sink.sent, hasLength(1), reason: 'no polls after teardown');
      });
    });
  });

  group('Yaesu', () {
    late _Sink sink;
    late Ft891Session session;

    setUp(() {
      sink = _Sink();
      session = Ft891Session(sink);
    });

    void feed(String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));

    test('PB0n plays, PB00 stops; LM0n records, LM00 stops; five memories', () {
      expect(session.voiceMemoryCount, 5);
      expect(session.canRecordVoice, isTrue);
      session.playVoiceMemory(3);
      // TX first: PB alone plays into the monitor and never reaches the air.
      expect(sink.sentAscii, ['TX1;', 'PB03;']);
      expect(sink.activities, [playing3]);
      session.stopVoice();
      expect(sink.sentAscii, ['TX1;', 'PB03;', 'PB00;', 'TX0;']);
      session.recordVoiceMemory(2);
      expect(sink.sentAscii.last, 'LM02;');
      expect(sink.activities.last, recording2);
      // Not LM02 again: the manual says that toggles, and a stop must not
      // depend on remembering which channel to toggle.
      session.stopVoice();
      expect(sink.sentAscii.last, 'LM00;');
      expect(sink.activities.last, isNull);
    });

    test('while playing, asks both TX and PB every second', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        async.elapse(const Duration(seconds: 1));
        // Both, because the two radios on this driver answer different ones:
        // the FT-891 comes out of transmit by itself, the FTDX10 answers PB.
        expect(sink.sentAscii.sublist(sink.sentAscii.length - 2), ['TX;', 'PB0;']);
      });
    });

    test('the radio leaving transmit ends the play, and nothing unkeys it twice', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        feed('TX1;'); // the FT-891 pushes this unprompted
        async.elapse(const Duration(seconds: 1));
        expect(sink.activities.last, playing3);
        feed('TX0;');
        expect(sink.activities.last, isNull);
        // The trap: unkeying a radio that already unkeyed itself. TX0 is the
        // END of the play here, not a stop the app has to make.
        expect(sink.sentAscii, isNot(contains('PB00;')));
        expect(sink.sentAscii.where((c) => c == 'TX0;'), isEmpty);
      });
    });

    test('a TX0 before the radio ever answered "transmitting" is a rig still keying up', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        // The trap: ending on the first answer. A radio that has not keyed
        // yet answers 0, and a play stopped there never reaches the air.
        feed('TX0;');
        expect(sink.activities.last, playing3, reason: 'not confirmed yet');
        feed('TX1;');
        feed('TX0;');
        expect(sink.activities.last, isNull);
      });
    });

    test('a PB00 is believed only after a PB answer named a memory playing', () {
      fakeAsync((async) {
        session.playVoiceMemory(3);
        // The FT-891 answers 00 from the first poll while the audio is
        // plainly going out — believing it cut every message short at two
        // seconds, and is the reason for the confirm-first rule.
        feed('PB00;');
        async.elapse(const Duration(seconds: 2));
        feed('PB00;');
        expect(sink.activities.last, playing3, reason: 'never confirmed, so never believed');

        // The FTDX10 does name the memory, and then its 0 is the end — and
        // it does NOT unkey itself, so the end is what sends TX0.
        feed('PB03;');
        feed('PB00;');
        expect(sink.activities.last, isNull);
        expect(sink.sentAscii.last, 'TX0;');
      });
    });

    test('a recording never keys the transmitter', () {
      fakeAsync((async) {
        session.recordVoiceMemory(2);
        async.elapse(voiceActivityCeiling + const Duration(seconds: 1));
        expect(sink.sentAscii, isNot(contains('TX1;')));
        expect(sink.sentAscii, isNot(contains('TX0;')));
      });
    });

    test('a recording is never polled, and no answer ends it', () {
      fakeAsync((async) {
        session.recordVoiceMemory(2);
        final sentAfterStart = sink.sentAscii.length;
        async.elapse(const Duration(seconds: 3));
        // The trap this test exists for: asking. The FT-891 answers `LM0;`
        // with `LM00;` while its own panel blinks REC, so a poll here reads
        // as a recording that never started — and the stop that follows took
        // the operator's audio with it, two seconds in.
        expect(sink.sentAscii.length, sentAfterStart, reason: 'nothing is asked while recording');
        feed('LM00;');
        feed('PB00;');
        feed('TX0;');
        expect(sink.activities.last, recording2, reason: 'no answer ends a recording');
      });
    });

    test('at the ceiling a recording is stopped on the radio, not only on the screen', () {
      fakeAsync((async) {
        session.recordVoiceMemory(2);
        async.elapse(voiceActivityCeiling + const Duration(seconds: 1));
        expect(sink.sentAscii.last, 'LM00;', reason: 'LM recording never ends on its own');
        expect(sink.activities.last, isNull);
        final sentBefore = sink.sent.length;
        async.elapse(const Duration(seconds: 3));
        expect(sink.sent.length, sentBefore, reason: 'no polls after the end');
      });
    });

    test('the codec clamps a memory number to the five that exist', () {
      expect(buildPlayVoiceMemoryCommand(9), 'PB05;');
      expect(buildRecordVoiceMemoryCommand(0), 'LM01;');
      expect(parseVoiceChannelParams('04'), 4);
      expect(parseVoiceChannelParams('4'), isNull);
      expect(parseVoiceChannelParams('004'), isNull);
    });
  });

  group('Kenwood CAT, by dialect', () {
    void feedTo(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));

    test('no dialect means no voice keyer, whatever count was declared', () {
      final session = KenwoodSession(_Sink(), voiceMemories: 4);
      expect(session.voiceMemoryCount, 0, reason: 'a QMX on this driver has no memories to offer');
      expect(session.canRecordVoice, isFalse);
    });

    test('a dialect with no count takes the dialect\'s own, and never more than it can address', () {
      expect(KenwoodDriver.voiceMemoriesFrom({'voiceDialect': 'pb'}), 4);
      expect(KenwoodDriver.voiceMemoriesFrom({'voiceDialect': 'k4', 'voiceMemories': 0}), 8);
      expect(KenwoodDriver.voiceMemoriesFrom({'voiceDialect': 'kx', 'voiceMemories': 6}), 2);
      expect(KenwoodDriver.voiceMemoriesFrom({'voiceDialect': 'pb', 'voiceMemories': 12}), 8, reason: 'the labels stop at eight');
      expect(KenwoodDriver.voiceMemoriesFrom({'voiceMemories': 4}), 0, reason: 'no dialect, no keyer');
    });

    test('pb: PBn plays, PB0 stops, PB; is the question, no recording', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.pb, voiceMemories: 4);
        expect(session.voiceMemoryCount, 4);
        expect(session.canRecordVoice, isFalse);
        session.playVoiceMemory(3);
        expect(sink.sentAscii, ['PB3;']);
        async.elapse(const Duration(seconds: 1));
        expect(sink.sentAscii.last, 'PB;');
        feedTo(session, 'PB3;');
        expect(sink.activities.last, playing3);
        feedTo(session, 'PB0;');
        expect(sink.activities.last, isNull);
        session.recordVoiceMemory(1);
        expect(sink.activities.last, isNull, reason: 'nothing to record with');
      });
    });

    test('k4: PBn plays, DA; is the question, and a recording is saved on stop', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.k4, voiceMemories: 8);
        expect(session.canRecordVoice, isTrue);
        session.playVoiceMemory(3);
        expect(sink.sentAscii, ['PB3;']);
        async.elapse(const Duration(seconds: 1));
        expect(sink.sentAscii.last, 'DA;');
        feedTo(session, 'DAPM0120090000M11;');
        expect(sink.activities.last, playing3, reason: 'playing to the transmitter');
        feedTo(session, 'DA0;');
        expect(sink.activities.last, isNull);
        session.playVoiceMemory(1);
        session.stopVoice();
        expect(sink.sentAscii.last, 'DA0;', reason: 'playback stops the same way');

        session.recordVoiceMemory(2);
        expect(sink.sentAscii.last, 'DARM;');
        expect(sink.activities.last, recording2);
        // The trap: DA0 read as "not playing" ending a RECORDING that is
        // still running — the answer for a recording is DARM, not DAPM.
        feedTo(session, 'DARM0050090000;');
        expect(sink.activities.last, recording2);
        session.stopVoice();
        expect(sink.sentAscii.sublist(sink.sentAscii.length - 2), [
          'DA0;',
          'DAMS2;',
        ], reason: 'DA0 is the K4\'s stop for any digital-audio action; a recording is not a memory until saved');
        expect(sink.activities.last, isNull);
      });
    });

    test('k4: at the ceiling the recording is stopped AND saved, as an operator\'s stop would', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.k4, voiceMemories: 8);
        session.recordVoiceMemory(3);
        async.elapse(voiceActivityCeiling + const Duration(seconds: 1));
        expect(sink.sentAscii.sublist(sink.sentAscii.length - 2), ['DA0;', 'DAMS3;']);
        expect(sink.activities.last, isNull);
      });
    });

    test('k4: the radio ending a recording itself (its 90 s cap) clears it, unsaved', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.k4, voiceMemories: 8);
        session.recordVoiceMemory(2);
        async.elapse(const Duration(seconds: 1));
        feedTo(session, 'DARM0050090000;'); // confirmed recording
        feedTo(session, 'DA0;');
        expect(sink.activities.last, isNull);
        expect(sink.sentAscii.where((c) => c.startsWith('DAMS')), isEmpty, reason: 'saving is the operator\'s stop, not something a poll answer does');
      });
    });

    test('kx: MSG then the digit plays, RX stops, TQ; is the question', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.kx, voiceMemories: kxVoiceMemoryCount);
        expect(session.voiceMemoryCount, 2);
        session.playVoiceMemory(2);
        expect(sink.sentAscii, ['SWT11;', 'SWT27;']);
        async.elapse(const Duration(seconds: 1));
        expect(sink.sentAscii.last, 'TQ;');
        feedTo(session, 'TQ1;');
        expect(sink.activities.last, const VoiceActivity(memory: 2));
        feedTo(session, 'TQ0;');
        expect(sink.activities.last, isNull);
        session.playVoiceMemory(1);
        expect(sink.sentAscii.last, 'SWT19;');
        session.stopVoice();
        expect(sink.sentAscii.last, 'RX;');
      });
    });

    test('a TQ0 or a DA0 on a pb radio, or a PB0 on a kx, ends nothing — each dialect hears only its own answer', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.pb, voiceMemories: 4);
        session.playVoiceMemory(1);
        feedTo(session, 'TQ0;');
        expect(sink.activities.last, isNotNull);
        // On a Kenwood `DA` is the DATA-mode command; AI2 announces `DA0;`
        // for a front-panel DATA toggle while a memory is on the air.
        feedTo(session, 'DA0;');
        expect(sink.activities.last, isNotNull);
        final kx = KenwoodSession(sink, voiceDialect: KenwoodVoiceDialect.kx, voiceMemories: 2);
        kx.playVoiceMemory(1);
        feedTo(kx, 'PB0;');
        expect(sink.activities.last, isNotNull);
      });
    });

    test('the catalogue pins a dialect and a count on the named entries, and none on the QMX or the generics', () {
      final registry = EquipmentRegistry();
      final sink = _Sink();
      KenwoodSession sessionFor(String typeKey, [Map<String, dynamic> config = const {}]) {
        final type = registry.typeFor(typeKey)!;
        // Through driverConfig(): an override that never travels costs
        // nothing visible — the radio simply has no voice keyer.
        return type.driver.createSession(sink, type.driverConfig(config)) as KenwoodSession;
      }

      expect(sessionFor('kx2-serial').voiceDialect, KenwoodVoiceDialect.kx);
      expect(sessionFor('kx3-serial').voiceMemoryCount, 2);
      expect(sessionFor('qmx-serial').voiceMemoryCount, 0);
      // The generics: nothing until a developer names a dialect — a K3 on
      // the Elecraft entry or a TS-890 on the Kenwood one would otherwise
      // get a `PB1;` it ignores and 90 s of "Playing".
      for (final key in ['kenwood-serial', 'elecraft-serial']) {
        final type = registry.typeFor(key)!;
        expect(sessionFor(key, type.defaultConfig).voiceMemoryCount, 0, reason: '$key prefilled');
        expect(sessionFor(key, {'voiceDialect': 'k4', 'voiceMemories': 8}).voiceMemoryCount, 8, reason: '$key told');
        expect(sessionFor(key, {'voiceDialect': 'k4', 'voiceMemories': 8}).canRecordVoice, isTrue);
      }
    });
  });

  group('the keyer facts a generic entry asks a developer for', () {
    final registry = EquipmentRegistry();

    test('the generics prefill both keyers off, and the fields are developer-mode only', () {
      for (final key in ['icom-generic-serial', 'yaesu-serial', 'kenwood-serial', 'elecraft-serial']) {
        final type = registry.typeFor(key)!;
        final prefilled = type.driverConfig(type.defaultConfig);
        expect(type.driver.canKeyCwWith(prefilled), isFalse, reason: '$key keys nothing out of the box');
        final session = type.driver.createSession(_Sink(), prefilled);
        expect((session as VoiceKeyerSession).voiceMemoryCount, 0, reason: '$key plays nothing out of the box');
        final fields = type.configElements().where((el) => el['type'] == 'field').toList();
        final keyerFields = fields.where((el) => ['cwKeyer', 'cwDialect', 'voiceDialect', 'voiceMemories'].contains(el['key']));
        expect(keyerFields, isNotEmpty, reason: '$key asks');
        for (final el in keyerFields) {
          expect(el['devMode'], isTrue, reason: '${el['key']} on $key is a developer\'s question');
        }
      }
    });

    test('a named entry pins them, so it asks nothing', () {
      for (final key in [
        'ic7300-serial',
        'ft891-serial',
        'ftx1-serial',
        'kx3-serial',
        'ic706mkiig-serial',
        'fx4cr-serial',
        'qcx-serial',
        'ts590sg-serial',
        'ts480-serial',
        'g90-serial',
      ]) {
        final type = registry.typeFor(key)!;
        final asked = type.configElements().where((el) => el['type'] == 'field').map((el) => el['key']);
        expect(asked, isNot(contains('cwKeyer')), reason: key);
        expect(asked, isNot(contains('cwDialect')), reason: key);
        // The pinned-off dialect is what makes voiceMemoryCount zero, so an
        // assertion on that count cannot fail for a mutation of this entry;
        // the question the entry stops asking is where the pin shows.
        expect(asked, isNot(contains('voiceDialect')), reason: key);
        expect(asked, isNot(contains('voiceMemories')), reason: key);
      }
      expect(registry.typeFor('ic7300-serial')!.driver.canKeyCwWith(registry.typeFor('ic7300-serial')!.driverConfig(const {})), isTrue);
      expect(registry.typeFor('ic706mkiig-serial')!.driver.canKeyCwWith(registry.typeFor('ic706mkiig-serial')!.driverConfig(const {})), isFalse);
      expect(registry.typeFor('kx3-serial')!.driver.canKeyCwWith(registry.typeFor('kx3-serial')!.driverConfig(const {})), isTrue);
      expect(registry.typeFor('qmx-serial')!.driver.canKeyCwWith(registry.typeFor('qmx-serial')!.driverConfig(const {})), isFalse);
    });

    test('a developer turning the CW keyer on, or off, is what the driver answers from', () {
      final icom = registry.typeFor('icom-generic-serial')!;
      expect(icom.driver.canKeyCwWith(icom.driverConfig({'cwKeyer': true})), isTrue);
      expect(icom.driver.canKeyCwWith(icom.driverConfig({'cwKeyer': false})), isFalse);
      // A node stored before the field existed keys, as it always did.
      expect(icom.driver.canKeyCwWith(icom.driverConfig(const {})), isTrue);
      expect(icom.driver.validateField('voiceMemories', '-1', const {}), isNotNull);
      expect(icom.driver.validateField('voiceMemories', '', const {}), isNull);
      expect(icom.driver.validateField('voiceMemories', 5, const {}), isNull);
      // Above the eight labels the strip would index past its icons.
      expect(icom.driver.validateField('voiceMemories', 9, const {}), isNotNull);
      final tooMany = icom.driver.createSession(_Sink(), icom.driverConfig({'voiceMemories': 12})) as IcomCivSession;
      expect(tooMany.voiceMemoryCount, 8, reason: 'clamped even when validation was bypassed');
      final yaesu = registry.typeFor('yaesu-serial')!;
      final overCount = yaesu.driver.createSession(_Sink(), yaesu.driverConfig({'voiceMemories': 8})) as Ft891Session;
      expect(overCount.voiceMemoryCount, 5, reason: 'never more than PB can address');
    });

    test('the ceiling is the memory length the entry pinned, and fifteen seconds where none was', () {
      Duration ceilingOf(String typeKey) {
        final type = registry.typeFor(typeKey)!;
        return (type.driver.createSession(_Sink(), type.driverConfig(const {})) as VoiceKeyerSession).voiceMemoryCeiling;
      }

      expect(ceilingOf('ic7300-serial'), const Duration(seconds: 90));
      expect(ceilingOf('ft891-serial'), const Duration(seconds: 20));
      expect(ceilingOf('ftdx10-serial'), const Duration(seconds: 90));
      expect(ceilingOf('kx3-serial'), const Duration(seconds: 15));
      // Unknown, or generic: the default, not a guess.
      expect(ceilingOf('ft710-serial'), voiceActivityCeiling);
      expect(ceilingOf('icom-generic-serial'), voiceActivityCeiling);
      expect(ceilingOf('elecraft-serial'), voiceActivityCeiling);
      expect(voiceCeilingFromConfig({'voiceCeilingSeconds': 0}), voiceActivityCeiling, reason: 'zero is not a length');
    });

    test('a generic node stored before the field existed plays nothing — a generic knows no rig', () {
      final icom = registry.typeFor('icom-generic-serial')!;
      expect((icom.driver.createSession(_Sink(), icom.driverConfig(const {})) as IcomCivSession).voiceMemoryCount, 0);
      final yaesu = registry.typeFor('yaesu-serial')!;
      expect((yaesu.driver.createSession(_Sink(), yaesu.driverConfig(const {})) as Ft891Session).voiceMemoryCount, 0);
    });
  });

  group('Kenwood CAT CW keying, by dialect', () {
    test('no dialect keys nothing, and is not a keyer', () {
      final sink = _Sink();
      final session = KenwoodSession(sink);
      session.sendCw('CQ');
      session.setKeyerSpeed(20);
      session.stopCw();
      expect(sink.sent, isEmpty);
      expect(const KenwoodDriver().canKeyCwWith(const {}), isFalse);
      expect(const KenwoodDriver().canKeyCwWith({'cwDialect': 'elecraft'}), isTrue);
    });

    test('kenwood: KY padded to a fixed 28 bytes, KY0 stops, KS 4-60', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, cwDialect: KenwoodCwDialect.kenwood);
        session.sendCw('cq test');
        expect(sink.sentAscii.single, 'KY CQ TEST                 ;');
        expect(sink.sent.single.length, 28, reason: 'the radio ignores any other length');
        session.stopCw();
        expect(sink.sentAscii.last, 'KY0;');
        session.setKeyerSpeed(70);
        expect(sink.sentAscii.sublist(sink.sentAscii.length - 2), ['KS060;', 'KS;'], reason: 'clamped, then read back');
        expect(session.keyerSpeedRange, (min: 4, max: 60));
      });
    });

    test('elecraft: KY text as is, KY @ terminates, KS 8-50', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, cwDialect: KenwoodCwDialect.elecraft);
        session.sendCw('cq test');
        expect(sink.sentAscii.single, 'KY CQ TEST;');
        session.stopCw();
        expect(sink.sentAscii.last, 'KY @;');
        session.setKeyerSpeed(5);
        expect(sink.sentAscii.sublist(sink.sentAscii.length - 2), ['KS008;', 'KS;']);
      });
    });

    test('a message longer than 24 characters goes in paced pieces, on word boundaries', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = KenwoodSession(sink, cwDialect: KenwoodCwDialect.elecraft);
        session.handleData(Uint8List.fromList(ascii.encode('KS020;')));
        session.sendCw('CQ CQ CQ DE N0CALL N0CALL N0CALL K');
        expect(sink.sentAscii.where((c) => c.startsWith('KY ')), ['KY CQ CQ CQ DE N0CALL;'], reason: 'the second piece waits for the first to be keyed');
        async.elapse(const Duration(seconds: 20));
        expect(sink.sentAscii.where((c) => c.startsWith('KY ')), ['KY CQ CQ CQ DE N0CALL;', 'KY N0CALL N0CALL K;']);
      });
    });

    test('a KS answer is the keyer speed only with a dialect — on a rig with none it is noise', () {
      final speeds = <int>[];
      final sink = _SpeedSink(speeds);
      KenwoodSession(sink).handleData(Uint8List.fromList(ascii.encode('KS022;')));
      expect(speeds, isEmpty);
      KenwoodSession(sink, cwDialect: KenwoodCwDialect.kenwood).handleData(Uint8List.fromList(ascii.encode('KS022;')));
      expect(speeds, [22]);
    });

    test('startUpdates reads the speed once, only with a dialect', () {
      final sink = _Sink();
      KenwoodSession(sink, cwDialect: KenwoodCwDialect.elecraft).startUpdates();
      expect(sink.sentAscii, contains('KS;'));
      final none = _Sink();
      KenwoodSession(none).startUpdates();
      expect(none.sentAscii, isNot(contains('KS;')));
    });
  });
}

class _SpeedSink extends _Sink {
  final List<int> speeds;
  _SpeedSink(this.speeds);
  @override
  void reportKeyerSpeed(int wpm) => speeds.add(wpm);
}
