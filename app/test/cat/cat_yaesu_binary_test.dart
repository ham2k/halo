// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The five-byte Yaesu binary CAT (FT-817/818, FT-857, FT-897), with no
// radio and no serial port.
//
// What this establishes is the protocol as Yaesu's own CAT chart documents
// it, and — more importantly — the request pump that gives an unframed
// protocol its framing. What it cannot establish is that a real FT-817
// answers this way: nothing here has met hardware, which is why the driver
// says `hardwareVerified` is false. The one place that gap has teeth is the
// PTT bit's polarity, which Yaesu's chart never states; these tests pin the
// interpretation the driver chose so a bench session that contradicts it
// fails here rather than silently flipping meaning.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_binary_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_binary_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';

class _FakeSink implements EquipmentSink {
  final sent = <List<int>>[];
  final readings = <VfoReading>[];
  final diagnostics = <String?>[];
  final txReports = <bool>[];
  final aliveCount = <int>[];

  @override
  void send(List<int> bytes) => sent.add(bytes);

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() => aliveCount.add(1);
}

extension on YaesuBinarySession {
  void feed(List<int> bytes) => handleData(Uint8List.fromList(bytes));
}

/// A radio that answers, so a test exercises the pump's real queueing
/// rather than sidestepping it: every command the session sends gets the
/// reply Yaesu's chart says that opcode has.
class _FakeRadio {
  final YaesuBinarySession session;
  final _FakeSink sink;
  int _answered = 0;

  _FakeRadio(this.session, this.sink);

  void answerEverythingAsked() {
    while (_answered < sink.sent.length) {
      final command = sink.sent[_answered++];
      switch (command.last) {
        case YaesuBinaryOpcode.readFrequencyAndMode:
          session.feed([0x00, 0x70, 0x74, 0x00, 0x01]);
        case YaesuBinaryOpcode.readTransmitStatus:
          session.feed([yaesuBinaryTransmitStatusIdle]);
        default:
          session.feed([0x00]);
      }
    }
  }
}

/// A session whose TX watch is set so slow it never fires inside a test —
/// the watch writes to the same port the state poll does, and every
/// assertion below counts exact commands. The watch has its own tests.
YaesuBinarySession _stateOnlySession(EquipmentSink sink, {Map<String, dynamic> config = const {}}) =>
    YaesuBinarySession(sink, config: {telemetryIntervalConfigKey: 600000, ...config});

void main() {
  group('the codec', () {
    test('frequency is four BCD bytes counting tens of hertz', () {
      // The manual's own example: 01 42 34 56 is 14.23456 MHz.
      expect(encodeBcdFrequency(14234560), [0x01, 0x42, 0x34, 0x56]);
      expect(encodeBcdFrequency(7074000), [0x00, 0x70, 0x74, 0x00]);
      expect(decodeBcdFrequency([0x01, 0x42, 0x34, 0x56]), 14234560);
    });

    // The radio's step is 10 Hz, so the last digit of a Hz value cannot be
    // sent at all. Truncating would land a spot one step BELOW where
    // everyone else is; rounding lands on it.
    test('a frequency between steps rounds to the nearest 10 Hz', () {
      expect(decodeBcdFrequency(encodeBcdFrequency(14074005)), 14074010);
      expect(decodeBcdFrequency(encodeBcdFrequency(14074004)), 14074000);
    });

    // A nibble above 9 is not BCD, which means these bytes are not a
    // frequency — the session is out of step with the radio. Decoding them
    // anyway would move the app's idea of the radio to an arbitrary place
    // and log QSOs there.
    test('a reply that is not valid BCD decodes to nothing', () {
      expect(decodeBcdFrequency([0x01, 0x4A, 0x34, 0x56]), isNull);
      expect(parseFrequencyAndMode([0xFF, 0xFF, 0xFF, 0xFF, 0x01]), isNull);
      // Five bytes exactly, or this is not the answer we asked for.
      expect(parseFrequencyAndMode([0x01, 0x42, 0x34, 0x56]), isNull);
      // Nothing on this protocol tunes to 0 Hz, and 0x00 is the likeliest
      // stray byte there is — it is what every set command acknowledges
      // with. Four of them is a misread answer, not a radio at DC.
      expect(parseFrequencyAndMode([0x00, 0x00, 0x00, 0x00, 0x01]), isNull);
    });

    test('a frequency-and-mode reply carries both', () {
      final reading = parseFrequencyAndMode([0x01, 0x42, 0x34, 0x56, 0x02]);
      expect(reading?.freqHz, 14234560);
      expect(reading?.mode, 'CW');
    });

    // The frequency in a reply is good even when the mode byte is one the
    // chart does not list. Reporting a guessed mode beside a right
    // frequency is what puts a wrong mode in a log that looks trustworthy.
    test('an unknown mode code leaves the mode unsaid, not guessed', () {
      final reading = parseFrequencyAndMode([0x01, 0x42, 0x34, 0x56, 0x77]);
      expect(reading?.freqHz, 14234560);
      expect(reading?.mode, isNull);
    });

    test('modes use the chart codes', () {
      expect(buildSetModeCommand('USB')?.bytes, [0x01, 0, 0, 0, 0x07]);
      expect(buildSetModeCommand('CW-R')?.bytes, [0x03, 0, 0, 0, 0x07]);
      expect(buildSetModeCommand('DATA-USB')?.bytes, [0x0A, 0, 0, 0, 0x07]);
    });

    // WFM appears only in the READ table: the radio reports it and no Set
    // Operating Mode parameter produces it. Sending a command for it would
    // put P1 = 0x06 on the wire, which the chart does not define.
    test('a read-only mode has no set command', () {
      expect(yaesuBinaryModeNameForCode(0x06), 'WFM');
      expect(buildSetModeCommand('WFM'), isNull);
    });

    // The FT-857 and FT-897 take 0x88 for narrow FM and the FT-817 has no
    // such parameter — so on an 817 this must send NOTHING rather than a
    // parameter the radio would read as some other mode.
    test('narrow FM is only sent to a radio that has the code', () {
      expect(buildSetModeCommand('FM-N', narrowFm: true)?.bytes, [0x88, 0, 0, 0, 0x07]);
      expect(buildSetModeCommand('FM-N'), isNull);
    });

    // 0xFF is what a receiving radio answers with: the register holds no
    // reading, and every flag in it reads as its "1" state. What keeps that
    // off the operator's screen is the PTT gating — drop the `transmitting
    // &&` from either flag and this radio, transmitting into nothing,
    // reports a HIGH SWR.
    test('the idle 0xFF is receiving, not a high SWR', () {
      final status = parseTransmitStatus(yaesuBinaryTransmitStatusIdle);
      expect(status.transmitting, isFalse);
      expect(status.highSwr, isFalse);
      expect(status.powerOut, 0);
    });

    // The polarity Yaesu's chart never states — see parseTransmitStatus.
    // If a bench session shows it backwards, this is the test that has to
    // change, and it should be loud about it.
    test('bit 7 low is keyed, and the flags below it are read only then', () {
      final status = parseTransmitStatus(0x4B);
      expect(status.transmitting, isTrue);
      expect(status.highSwr, isTrue, reason: 'bit 6 set is HI SWR "ON"');
      expect(status.split, isTrue, reason: 'bit 5 clear is SPLIT "ON"');
      expect(status.powerOut, 0x0B);
    });
  });

  group('the request pump', () {
    // The whole point of the pump. This protocol has no framing, so two
    // questions in flight means the one-byte answer to the second is read
    // as the first byte of the answer to the first — a status byte
    // decoding as a plausible frequency.
    test('only one question is on the wire at a time', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setFrequency(14074.0);
      session.setMode('USB');
      expect(sink.sent.length, 1, reason: 'the mode command waits for the frequency to be answered');
      expect(sink.sent.single.last, YaesuBinaryOpcode.setFrequency);

      session.feed([0x00]); // the acknowledgement
      expect(sink.sent.length, 2);
      expect(sink.sent[1].last, YaesuBinaryOpcode.setMode);
    });

    test('a reply split across chunks is reassembled', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.feed([0x01, 0x42]);
      expect(sink.readings, isEmpty, reason: 'two bytes are not a five-byte answer');
      session.feed([0x34, 0x56, 0x01]);
      expect(sink.readings.single.freqKHz, closeTo(14234.56, 0.001));
      expect(sink.readings.single.mode, 'USB');
    });

    // A radio that answers a question the chart says it answers with
    // nothing would otherwise leave the pump waiting forever, and the
    // session would go silent for the rest of the connection with a green
    // status and a frozen frequency.
    test('an unanswered read is abandoned and the next question goes out', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        expect(sink.sent.length, 1);

        session.setFrequency(14074.0);
        expect(sink.sent.length, 1, reason: 'still waiting on the read');

        async.elapse(yaesuBinaryReplyTimeout);
        expect(sink.diagnostics, contains(contains('no answer')));
        // Not yet: the abandoned answer's bytes may still be arriving, and
        // the pump waits the line out before it trusts it again.
        expect(sink.sent, hasLength(1));

        async.elapse(yaesuBinaryResyncQuietTime);
        expect(sink.sent.length, 2);
        expect(sink.sent[1].last, YaesuBinaryOpcode.setFrequency);
        session.teardown();
      });
    });

    // Yaesu's chart shows no returned byte for Set Frequency and the field
    // reports disagree. A tolerated silence must not read as a fault, or
    // every retune on a radio that does not ack files a diagnostic.
    test('a set command that never acknowledges is not reported as a fault', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.setFrequency(14074.0);
        async.elapse(yaesuBinaryReplyTimeout);
        expect(sink.diagnostics, isEmpty);
        session.teardown();
      });
    });

    // The unrecoverable mistake: a byte kept from an abandoned answer
    // offsets every later reply by one, and the session reports a wrong
    // frequency for the life of the connection rather than failing.
    test('a late byte from an abandoned answer does not offset the next one', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        async.elapse(yaesuBinaryReplyTimeout);
        // The abandoned read's answer, arriving after we gave up on it.
        // Kept, it becomes the first byte of the NEXT five-byte answer:
        // 7.074 MHz reads back as 1.007074 MHz, and every reading after it
        // is wrong the same way for the life of the connection.
        session.feed([0x01]);

        final before = sink.sent.length;
        for (var i = 0; i < 60 && sink.sent.length == before; i++) {
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(sink.sent.last.last, YaesuBinaryOpcode.readFrequencyAndMode);
        session.feed([0x00, 0x70, 0x74, 0x00, 0x01]);
        expect(sink.readings.single.freqKHz, closeTo(7074.0, 0.001));
        session.teardown();
      });
    });

    // The nastiest case this protocol has, and the one a whole-answer
    // deadline creates: an answer that stalls halfway. Sending the next
    // command while three bytes of the last one are still coming hands
    // those bytes to it — `56` read as a TX status is bit 7 clear, so a
    // receiving radio is reported as KEYED, and that reading gates antenna
    // relays.
    test('the tail of a stalled answer is not fed to the next command', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = YaesuBinarySession(sink, config: const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        session.feed([0x01, 0x42, 0x34]);

        async.elapse(yaesuBinaryReplyTimeout);
        final sentWhenAbandoned = sink.sent.length;
        // The rest of the abandoned answer, arriving while the pump is
        // waiting the line out.
        session.feed([0x56]);
        expect(sink.sent, hasLength(sentWhenAbandoned), reason: 'nothing is sent into a line still talking');
        expect(sink.txReports, isEmpty, reason: 'a stray byte is not a transmit status');

        // Quiet again, so the pump resumes.
        async.elapse(yaesuBinaryResyncQuietTime);
        expect(sink.sent.length, greaterThan(sentWhenAbandoned));
        session.teardown();
      });
    });

    // Yaesu's chart allows 200 ms between the bytes of a command. Deadlined
    // as a whole answer rather than per byte, a radio spacing its bytes
    // that far apart is abandoned mid-answer every single time, and the
    // session never reads a frequency at all.
    test('an answer arriving slowly is not abandoned mid-flight', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = _stateOnlySession(sink);
        session.startUpdates();
        for (final byte in [0x00, 0x70, 0x74, 0x00, 0x01]) {
          async.elapse(const Duration(milliseconds: 200));
          session.feed([byte]);
        }
        expect(sink.readings.single.freqKHz, closeTo(7074.0, 0.001));
        expect(sink.diagnostics, isEmpty);
        session.teardown();
      });
    });

    test('the queue is capped for reads and never for writes', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        // A watch that asks every 200 ms against a radio that answers
        // nothing: requests arrive faster than the pump's deadline drains
        // them, which is exactly the backlog the cap exists for.
        final session = YaesuBinarySession(sink, config: const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        async.elapse(const Duration(seconds: 10));

        // Ten seconds of unanswered polling, and the operator taps a spot.
        // Capped, the backlog ahead of it is [yaesuBinaryMaxQueued]
        // deadlines; uncapped it is every question the last ten seconds
        // asked, and the retune goes out minutes later or not at all.
        session.setFrequency(14074.0);
        async.elapse((yaesuBinaryReplyTimeout + yaesuBinaryResyncQuietTime) * (yaesuBinaryMaxQueued + 2));
        expect(sink.sent.map((c) => c.last), contains(YaesuBinaryOpcode.setFrequency));
        session.teardown();
      });
    });
  });

  group('the session', () {
    test('a poll asks for frequency and mode together', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      expect(sink.sent.single, [0, 0, 0, 0, YaesuBinaryOpcode.readFrequencyAndMode]);
      session.teardown();
    });

    // This protocol has no auto-information at all, so the poll is the only
    // way a dial turn is ever seen. A session that deferred its poll on the
    // TX watch's own answers — which arrive several times a second — would
    // only ever report a frequency at the poller's staleness ceiling.
    test('the TX watch does not defer the state poll', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = YaesuBinarySession(sink, config: const {telemetryIntervalConfigKey: 200});
        final radio = _FakeRadio(session, sink);
        session.startUpdates();

        // A radio answering its watch five times a second, and nothing
        // else happening. A session that treated those answers as the
        // radio volunteering something would re-arm the poll timer before
        // it could ever fire.
        for (var i = 0; i < 20; i++) {
          async.elapse(const Duration(milliseconds: 200));
          radio.answerEverythingAsked();
        }
        expect(
          sink.sent.where((c) => c.last == YaesuBinaryOpcode.readFrequencyAndMode).length,
          greaterThan(1),
          reason: 'the state poll must survive a chattering TX watch',
        );
        session.teardown();
      });
    });

    test('a transmit status is reported once per change', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = YaesuBinarySession(sink, config: const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        session.feed([0x00, 0x70, 0x74, 0x00, 0x01]);

        async.elapse(const Duration(milliseconds: 200));
        session.feed([0xFF]);
        expect(sink.txReports, [false], reason: 'the first answer is news even when it is "receiving"');

        async.elapse(const Duration(milliseconds: 200));
        session.feed([0x08]);
        expect(sink.txReports, [false, true]);
        session.teardown();
      });
    });

    // A keyed radio with the app gone is a transmitter nothing can turn
    // off: this protocol has no dead-man's switch, and the operator's own
    // PTT was never pressed.
    test('teardown unkeys a radio the app keyed', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setPtt(true);
      session.teardown();
      expect(sink.sent.last, [0, 0, 0, 0, YaesuBinaryOpcode.pttOff]);
    });

    test('teardown keys nothing on a radio the app never keyed', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.startUpdates();
      session.teardown();
      expect(sink.sent.map((c) => c.last), isNot(contains(YaesuBinaryOpcode.pttOff)));
    });

    test('a retune goes out as a set-frequency command', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setFrequency(14074.0);
      expect(sink.sent.single, [0x01, 0x40, 0x74, 0x00, YaesuBinaryOpcode.setFrequency]);
    });

    // There is no CAT power command on these radios at all. Writing the
    // EEPROM byte the power level lives in is model- and firmware-specific,
    // and a wrong address corrupts a setting the operator cannot see.
    test('setting power sends nothing', () {
      final sink = _FakeSink();
      final session = _stateOnlySession(sink);
      session.setPower(5);
      expect(sink.sent, isEmpty);
    });

    // Off by default, and the raw numbers are what a scale would be built
    // from — nothing converts them, so nothing may reach a meter.
    test('the capture prints the raw TX byte only when it is switched on', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = YaesuBinarySession(sink, config: const {telemetryIntervalConfigKey: 200, yaesuBinaryMeterCaptureConfigKey: true});
        session.startUpdates();
        session.feed([0x00, 0x70, 0x74, 0x00, 0x01]);
        async.elapse(const Duration(milliseconds: 200));
        session.feed([0x4B]);
        expect(sink.diagnostics, contains(contains('PO=11')));
        session.teardown();
      });
    });
  });
}
