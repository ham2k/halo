// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Yaesu CAT and the FT-891 driver, with no radio and no serial port.
//
// Worth being clear about what this does and doesn't establish: it pins the
// protocol as the FT-891 CAT Operation Reference Book documents it, and the
// framing against the way serial actually delivers bytes. It does NOT
// establish that a real FT-891 answers this way — app-polo shipped this
// driver without ever testing it against hardware, and neither has anyone
// since. `hardwareVerified` is false for exactly that reason.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/meter_calibration.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, TunerSink, PassbandSink {
  final problems = <String?>[];
  final tunerReports = <TunerStatus?>[];
  final passbandReports = <Passband?>[];

  @override
  void reportTuner(TunerStatus? status) => tunerReports.add(status);

  @override
  void reportPassband(Passband? passband) => passbandReports.add(passband);

  List<EquipmentChannel> channels = const [];
  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final keyerSpeeds = <int>[];
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
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}

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

extension on Ft891Session {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

/// A session whose TX watch is set so slow it never fires inside a test.
///
/// The tests below assert on the exact commands the STATE poll sends, and
/// the watch writes `TX;` to the same port several times a second. It has
/// its own tests below.
Ft891Session _stateOnlySession(EquipmentSink sink) => Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000});

void main() {
  group('the codec', () {
    test('frequency is nine zero-padded digits of Hz, not BCD', () {
      expect(buildSetFrequencyCommand(14250000), 'FA014250000;');
      expect(buildSetFrequencyCommand(1840000), 'FA001840000;');
      // 30 kHz is the bottom of the documented P1 range.
      expect(buildSetFrequencyCommand(30000), 'FA000030000;');
    });

    test('a frequency response parses only at exactly nine digits', () {
      expect(parseFrequencyParams('014250000'), 14250000);
      // A truncated read landing mid-command is not a frequency; taking it
      // would jump the radio to a decimal shift of where it really is.
      expect(parseFrequencyParams('01425000'), isNull);
      expect(parseFrequencyParams('0142500000'), isNull);
      expect(parseFrequencyParams(''), isNull);
      expect(parseFrequencyParams('01425000X'), isNull);
    });

    test('modes round-trip through the MD table, and unknown modes build nothing', () {
      expect(buildSetModeCommand('LSB'), 'MD01;');
      expect(buildSetModeCommand('cw'), 'MD03;', reason: 'case-insensitive');
      expect(buildSetModeCommand('DATA-USB'), 'MD0C;');
      expect(parseModeParams('01'), 'LSB');
      expect(parseModeParams('0C'), 'DATA-USB');

      // 'SSB' never reaches a driver — CatService resolves it to a real
      // sideband first — and the radio has no code for it either way.
      expect(buildSetModeCommand('SSB'), isNull);
      expect(buildSetModeCommand(null), isNull);
      // 'A' is reserved in the MD table.
      expect(parseModeParams('0A'), isNull);
    });

    test('PC is a 3-digit level, watts directly per the CAT manual', () {
      expect(buildSetPowerCommand(100), 'PC100;');
      expect(buildSetPowerCommand(5), 'PC005;');
      expect(parsePowerParams('100'), 100);
      expect(parsePowerParams('05'), isNull, reason: 'PC is always 3 digits');
    });

    test('a power outside the documented 5-100 range is clamped', () {
      expect(buildSetPowerCommand(150), 'PC100;');
      expect(buildSetPowerCommand(0), 'PC005;');
    });

    // The FTX-1's answers are four characters where the FT-891's are three:
    // read with the FT-891's parser they are no reading at all, and its
    // commands are ones the radio refuses.
    test('the FTX-1 PC names the unit before the level, and each unit has its own range', () {
      expect(parseHeadPowerParams('1010'), (head: 1, watts: 10));
      expect(parseHeadPowerParams('10.5'), (head: 1, watts: 0.5));
      expect(parseHeadPowerParams('2100'), (head: 2, watts: 100));
      expect(parseHeadPowerParams('100'), isNull, reason: "the FT-891's form");
      expect(parseHeadPowerParams('3010'), isNull);

      expect(buildSetHeadPowerCommand(1, 6), 'PC1006;');
      expect(buildSetHeadPowerCommand(1, 1.5), 'PC11.5;');
      expect(buildSetHeadPowerCommand(1, 100), 'PC1010;', reason: 'a field head tops out at 10 W');
      expect(buildSetHeadPowerCommand(2, 50), 'PC2050;');
      expect(buildSetHeadPowerCommand(2, 1), 'PC2005;');
    });

    test('a command is only a command once terminated', () {
      expect(parseAsciiCatCommand('FA014250000;'), const AsciiCatCommand('FA', '014250000'));
      expect(parseAsciiCatCommand('FA014250000'), isNull, reason: 'no terminator');
      expect(parseAsciiCatCommand('fa014250000;'), isNull, reason: 'commands are uppercase');
      expect(parseAsciiCatCommand(';'), isNull);
    });
  });

  group('framing', () {
    test('splits several commands out of one chunk', () {
      final framer = AsciiCatFramer();
      expect(framer.add('FA014250000;MD02;'), [const AsciiCatCommand('FA', '014250000'), const AsciiCatCommand('MD', '02')]);
    });

    test('carries a partial command across chunks', () {
      // Serial hands over arbitrary chunk sizes, so this is the normal case
      // rather than an edge one.
      final framer = AsciiCatFramer();
      expect(framer.add('FA0142'), isEmpty);
      expect(framer.add('50000;'), [const AsciiCatCommand('FA', '014250000')]);
    });

    test('survives a command split one byte at a time', () {
      final framer = AsciiCatFramer();
      final found = <AsciiCatCommand>[];
      for (final char in 'MD03;FA007074000;'.split('')) {
        found.addAll(framer.add(char));
      }
      expect(found, [const AsciiCatCommand('MD', '03'), const AsciiCatCommand('FA', '007074000')]);
    });

    test('reset drops a partial tail so it cannot prefix the next connection', () {
      final framer = AsciiCatFramer();
      framer.add('FA0142');
      framer.reset();
      // Without the reset this would frame as 'FA014250000;' — a frequency
      // assembled from two different sessions.
      expect(framer.add('50000;'), isEmpty);
    });
  });

  group('the session', () {
    late _FakeSink sink;
    late Ft891Session session;

    setUp(() {
      sink = _FakeSink();
      session = _stateOnlySession(sink);
    });

    test('reports frequency in kHz from the radio\'s exact Hz', () {
      session.feed('FA014250000;');
      expect(sink.readings, [const VfoReading(freqKHz: 14250)]);
    });

    test('keeps sub-kHz precision', () {
      session.feed('FA007074123;');
      expect(sink.readings.single.freqKHz, closeTo(7074.123, 0.0001));
    });

    test('reports mode', () {
      session.feed('MD03;');
      expect(sink.readings, [const VfoReading(mode: 'CW')]);
    });

    test('ignores acknowledgements and anything it does not track', () {
      // AI mode makes the radio chatty; unrecognised traffic must be inert.
      session.feed('AI1;PS1;SH0031;');
      expect(sink.readings, isEmpty);
    });

    test('line noise costs the frame it lands in, then the link resyncs', () {
      // A noise burst on a serial link is not exceptional. It must not throw
      // out of the stream callback, and recovery is at the next ';' — the
      // only framing the protocol has.
      session.handleData(Uint8List.fromList([0xFF, 0x00, 0x81]));
      expect(sink.readings, isEmpty);

      // This one shares a segment with the garbage and is still read: the
      // parse skips to the first plausible command start instead of
      // anchoring, because losing a whole frequency to one stray byte is
      // the common case on a 4800-baud line beside a transmitting rig.
      session.feed('FA014250000;');
      expect(sink.readings, [const VfoReading(freqKHz: 14250)]);

      // The next frame is clean.
      session.feed('FA007074000;');
      expect(sink.readings.last, const VfoReading(freqKHz: 7074));
    });

    test('builds a tune command from kHz', () {
      session.setFrequency(7074.5);
      expect(sink.sent, ['FA007074500;']);
    });

    test('sends nothing for a mode the radio has no code for', () {
      session.setMode('SSB');
      expect(sink.sent, isEmpty);
    });

    test('reports a PC reply as power', () {
      session.feed('PC100;');
      expect(sink.powers, [100]);
    });

    test('builds a power command from watts', () {
      session.setPower(75);
      expect(sink.sent, ['PC075;']);
    });

    group('with the FTX-1 power form pinned', () {
      late Ft891Session ftx1;
      setUp(() => ftx1 = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000, yaesuHeadPowerConfigKey: true}));

      test('reads the level after the unit', () {
        ftx1.feed('PC1010;');
        expect(sink.powers, [10]);
      });

      // CatService records a set as delivered once it returns, and never
      // sends the same value twice — so a set dropped for want of a unit
      // would be lost, not retried. The answer that releases it is the level
      // being replaced, so it is not reported.
      test('holds a set until the radio has said which unit it drives, then sends it for that unit', () {
        ftx1.setPower(50);
        expect(sink.sent, isEmpty);
        ftx1.feed('PC2100;');
        expect(sink.sent, ['PC2050;']);
        expect(sink.powers, isEmpty);
        sink.sent.clear();
        ftx1.setPower(5);
        expect(sink.sent, ['PC2005;']);
      });

      // The head form comes from hamlib, not a capture. A radio that answers
      // in the FT-891's form after all must not be left with a power control
      // that holds every change forever.
      test('a radio answering in the FT-891 form is read and set in that form', () {
        ftx1.setPower(50);
        ftx1.feed('PC100;');
        expect(sink.sent, ['PC050;']);
        ftx1.feed('PC050;');
        expect(sink.powers, [50]);
      });

      test('an answer in no known form stops the wait, and sends nothing it would have to guess', () {
        ftx1.setPower(50);
        ftx1.feed('PC9;');
        expect(sink.sent, isEmpty);
        expect(sink.powers, isEmpty);
        ftx1.setPower(40);
        expect(sink.sent, isEmpty);
      });
    });

    // The FT-2000's and FTDX5000's `PC` is 000-255 of the rated output, and
    // one entry covers the 100 W FT-2000 and the 200 W FT-2000D. Sent as
    // watts, a 200 W radio asked for 100 W puts out 78; scaled against the
    // wrong rating, the FT-2000 puts out half or is refused.
    group('with the relative power form pinned', () {
      late Ft891Session ft2000;
      setUp(() => ft2000 = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000, yaesuRelativePowerConfigKey: true}));

      test("scales against the rating the radio's ID names", () {
        ft2000.feed('ID0252;');
        ft2000.feed('PC255;');
        expect(sink.powers, [200]);
        ft2000.setPower(100);
        expect(sink.sent.last, 'PC128;');
      });

      test('the 100 W FT-2000 reads its full scale as 100 W', () {
        ft2000.feed('ID0251;');
        ft2000.feed('PC255;');
        expect(sink.powers, [100]);
        ft2000.setPower(150);
        expect(sink.sent.last, 'PC255;', reason: 'clamped to the rating, not past full scale');
      });

      // The same trap as the FTX-1's: CatService never re-sends a value it
      // recorded as delivered, so a set dropped for want of a rating is lost.
      test('holds a set and a reading until the radio has identified itself', () {
        ft2000.setPower(100);
        ft2000.feed('PC051;');
        expect(sink.sent, isEmpty);
        expect(sink.powers, isEmpty);
        ft2000.feed('ID0362;');
        expect(sink.sent, ['PC128;']);
        expect(sink.powers, isEmpty, reason: 'the level read is the one being replaced');
      });

      test('reports a level read before the ID once the rating is known', () {
        ft2000.feed('PC051;');
        ft2000.feed('ID0362;');
        expect(sink.powers, [40]);
      });

      // The one `ID;` at start can be lost — the line settling, or a radio
      // with CAT RTS on answering a single burst. Without asking again,
      // every level read is parked and every set waits for the session.
      test('asks ID again on the poll until the radio has answered it', () {
        fakeAsync((async) {
          ft2000.startUpdates();
          sink.sent.clear();
          async.elapse(const Duration(seconds: 5));
          expect(sink.sent, contains('ID;'));
          ft2000.feed('ID0362;');
          sink.sent.clear();
          async.elapse(const Duration(seconds: 5));
          expect(sink.sent, isNot(contains('ID;')));
          ft2000.teardown();
          async.flushTimers();
        });
      });

      test('an ID with no known rating neither reads nor sets power, and says so', () {
        ft2000.feed('ID0999;');
        ft2000.feed('PC100;');
        ft2000.setPower(50);
        expect(sink.powers, isEmpty);
        expect(sink.sent, isEmpty);
        expect(sink.diagnostics.single, contains('0999'));
      });

      // A radio that refuses `ID` would otherwise be asked on every poll
      // forever, with every set the operator makes parked and never sent.
      test('a radio that never answers ID is asked a few times, then given up on', () {
        fakeAsync((async) {
          ft2000.startUpdates();
          ft2000.setPower(50);
          async.elapse(const Duration(minutes: 2));
          sink.sent.clear();
          async.elapse(const Duration(minutes: 1));
          expect(sink.sent, isNot(contains('ID;')), reason: 'given up');
          expect(sink.diagnostics.where((d) => d?.contains('never answered ID') ?? false), hasLength(1), reason: 'said once, not on every poll');
          ft2000.setPower(40);
          ft2000.feed('ID0362;');
          expect(sink.sent.where((c) => c.startsWith('PC0')), isEmpty, reason: 'the held set was dropped, not replayed later');
          ft2000.teardown();
          async.flushTimers();
        });
      });
    });

    // The FT-450's `FA` and `IF` carry eight digits of Hz (hamlib's
    // newcat.c). On the line's nine every answer is dropped as malformed
    // and every tune is refused, with nothing anywhere saying why.
    group('with eight frequency digits pinned', () {
      late Ft891Session ft450;
      setUp(() => ft450 = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000, yaesuFrequencyDigitsConfigKey: 8}));

      test('reads an eight-digit FA', () {
        ft450.feed('FA14250000;');
        expect(sink.readings, [const VfoReading(freqKHz: 14250)]);
      });

      test('tunes with eight digits', () {
        ft450.setFrequency(7074.5);
        expect(sink.sent, ['FA07074500;']);
      });

      test('reads the IF packet one place shorter, mode included', () {
        // The FT-891 capture above with P2 one digit narrower: 27 bytes, the
        // length hamlib reads an eight-digit radio by.
        ft450.feed('IF00114233700+000000200000;');
        expect(sink.readings, [const VfoReading(freqKHz: 14233.7, mode: 'USB')]);
      });

      test('a nine-digit answer is a malformed frame, not a frequency', () {
        // Cut to its first eight digits it reads as a tenth of the frequency.
        ft450.feed('FA014250000;');
        expect(sink.readings, isEmpty);
      });
    });

    group('CW keying', () {
      test('KS is a 3-digit WPM, clamped to the manual\'s 4-60', () {
        expect(buildSetKeyerSpeedCommand(25), 'KS025;');
        expect(buildSetKeyerSpeedCommand(2), 'KS004;');
        expect(buildSetKeyerSpeedCommand(99), 'KS060;');
        expect(parseKeyerSpeedParams('025'), 25);
        expect(parseKeyerSpeedParams('25'), isNull, reason: 'KS is always 3 digits');
      });

      test('reports a KS reply as the keyer speed', () {
        session.feed('KS022;');
        expect(sink.keyerSpeeds, [22]);
        expect(session.keyerSpeedRange, (min: 4, max: 60));
      });

      test('setting the speed reads it back, so what shows is what the radio took', () {
        session.setKeyerSpeed(25);
        expect(sink.sent, ['KS025;', 'KS;']);
      });

      test('a message is written into text memory 5 and played back from it', () {
        // Yaesu has no "key this text" command — see yaesu_cat_codec.dart.
        // Memory 5 by choice, `KYA;` because the TEXT memories play from 6-A.
        session.sendCw('cq test de n0dev');
        expect(sink.sent, ['KM5CQ TEST DE N0DEV;', 'KYA;']);
      });

      test('an entry names the memory it takes over', () {
        // The FT-450 has three text memories: `KM5` there writes nothing and
        // `KYA` plays nothing, so every message would vanish unsent.
        final ft450 = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000, yaesuKeyerMemoryConfigKey: 3});
        ft450.sendCw('cq test');
        expect(sink.sent, ['KM3CQ TEST;', 'KY8;']);
        ft450.teardown();
      });

      test('an entry names how long its memories are', () {
        // The FT-450's hold forty. A fifty-character write overruns the
        // memory, and the radio says nothing about what it kept.
        fakeAsync((async) {
          final ft450 = Ft891Session(
            sink,
            config: const {telemetryIntervalConfigKey: 600000, yaesuKeyerMemoryConfigKey: 3, yaesuKeyerMemoryCharsConfigKey: 40},
          );
          ft450.feed('KS020;');
          sink.sent.clear();
          const message = 'CQ CQ CQ DE N0DEV N0DEV N0DEV K CQ CQ CQ DE N0DEV';
          ft450.sendCw(message);
          async.flushTimers();
          final writes = [
            for (final c in sink.sent)
              if (c.startsWith('KM3')) c.substring(3, c.length - 1),
          ];
          expect(writes, everyElement(hasLength(lessThanOrEqualTo(40))));
          // Split, not cut: every word of the message still goes out.
          expect(writes.join(' ').split(RegExp(r'\s+')), message.split(' '));
          expect(sink.sent.where((c) => c.startsWith('KY')), everyElement('KY8;'));
          ft450.teardown();
        });
      });

      test('the FT-710 plays a text memory by channel', () {
        // Its `KY` names the memory kind first; the line's `KYA;` is no
        // command there, and the message is written but never sent.
        final ft710 = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000, yaesuKeyerPlayByChannelConfigKey: true});
        ft710.sendCw('cq test');
        expect(sink.sent, ['KM5CQ TEST;', 'KY05;']);
        ft710.teardown();
      });

      test('a message longer than the memory goes in paced pieces', () {
        fakeAsync((async) {
          session.feed('KS020;');
          sink.sent.clear();
          final long = 'CQ CQ CQ DE N0DEV N0DEV N0DEV K CQ CQ CQ DE N0DEV N0DEV N0DEV K';
          expect(long.length, greaterThan(50));

          session.sendCw(long);
          expect(sink.sent, hasLength(2), reason: 'one write and one play, nothing else yet');
          expect(sink.sent.first.length, lessThanOrEqualTo('KM5'.length + 50 + 1));
          expect(session.cwSending, isTrue);

          // Rewriting the memory while it is playing would clobber the
          // message mid-air, so the second piece waits out the first.
          async.elapse(const Duration(seconds: 5));
          expect(sink.sent, hasLength(2));
          async.elapse(const Duration(seconds: 30));
          expect(sink.sent, hasLength(4));
          expect(sink.sent[2], startsWith('KM5'));
          expect(sink.sent[3], 'KYA;');

          async.flushTimers();
          expect(session.cwSending, isFalse);
          session.teardown();
        });
      });

      test('stopCw only stops queuing — the manual has no way to interrupt playback', () {
        fakeAsync((async) {
          session.sendCw('EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE EEE');
          expect(sink.sent, hasLength(2));
          session.stopCw();
          // Honest about the radio: the memory it is playing plays out, so
          // the session still counts as sending until that chunk's end.
          expect(session.cwSending, isTrue);
          async.elapse(const Duration(minutes: 1));
          expect(session.cwSending, isFalse);
          expect(sink.sent, hasLength(2), reason: 'nothing more is written or played');
        });
      });
    });

    test('starting updates enables auto-information and asks once immediately', () {
      fakeAsync((async) {
        session.startUpdates();
        // `KS;` once here and never in the poll below: the keyer speed
        // only moves when someone turns the knob.
        // `ID;` once too: which radio answers decides its filter tables.
        expect(sink.sent, ['AI1;', 'ID;', 'FA;', 'MD0;', 'PC;', 'AC;', 'KS;']);
        session.teardown();
        async.flushTimers();
      });
    });

    test('polls as a safety net, because AI mode is not fully documented', () {
      fakeAsync((async) {
        session.startUpdates();
        sink.sent.clear();

        async.elapse(const Duration(seconds: 5));
        expect(sink.sent, ['FA;', 'MD0;', 'PC;']);

        sink.sent.clear();
        session.stopUpdates();
        sink.sent.clear();
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent, isEmpty, reason: 'the poll stops with updates');
      });
    });

    test('teardown turns auto-information back off', () {
      fakeAsync((async) {
        session.startUpdates();
        sink.sent.clear();

        session.teardown();
        // AI mode persists across a disconnect: leaving it on would have the
        // radio chattering at whatever connects next.
        expect(sink.sent, ['AI0;']);

        sink.sent.clear();
        async.elapse(const Duration(minutes: 5));
        expect(sink.sent, isEmpty);
      });
    });

    group('the antenna tuner', () {
      /// Lets the state poll run until it asks for the tuner, and says when.
      void untilTunerRead(FakeAsync async) {
        sink.sent.clear();
        for (var i = 0; i < 120 && !sink.sent.contains('AC;'); i++) {
          async.elapse(const Duration(milliseconds: 500));
        }
      }

      test('AC writes are in line or bypass, and the switch builder cannot start a tune', () {
        // P3 2 is "tune start" — a carrier on the air, and buildStartTuneCommand's alone.
        // Taking a bool rather than a P3 is what keeps it out of a switch's reach.
        expect(buildSetTunerCommand(inline: true), 'AC001;');
        expect(buildSetTunerCommand(inline: false), 'AC000;');
        expect(parseTunerParams('000'), 0);
        expect(parseTunerParams('001'), 1);
        expect(parseTunerParams('002'), 2);
        expect(parseTunerParams('01'), isNull, reason: 'a frame that lost a byte');
        expect(parseTunerParams('101'), isNull, reason: 'P1P2 is a fixed 00');
        expect(parseTunerParams('003'), isNull);
      });

      test('a tune is AC002; and a read-back, only once the radio has answered AC', () {
        // Before an answer, AC is not known to reach a tuner: the carrier would go
        // into whatever the radio has on its antenna port.
        expect(session.canStartTune, isFalse);
        session.startTune();
        expect(sink.sent, isEmpty);
        session.feed('AC000;');
        expect(session.canStartTune, isTrue);
        session.startTune();
        expect(sink.sent, ['AC002;', 'AC;']);
      });

      test('a tune is not started over a transmission', () {
        fakeAsync((async) {
          session.startUpdates();
          session.feed('AC001;');
          session.feed('TX2;');
          async.elapse(const Duration(seconds: 1));
          sink.sent.clear();
          expect(session.canStartTune, isTrue, reason: 'refused for transmitting, not for want of a tuner');
          session.startTune();
          expect(sink.sent, isNot(contains('AC002;')));
          session.teardown();
        });
      });

      test('a tune is not started into one already running', () {
        // A second start mid-tune cancels or restarts it on the air.
        session.feed('AC002;');
        expect(session.canStartTune, isTrue);
        session.startTune();
        expect(sink.sent, isNot(contains('AC002;')));
      });

      test('a tune is ended by putting the tuner in line, even on the air', () {
        fakeAsync((async) {
          session.startUpdates();
          session.feed('AC002;');
          session.feed('TX2;');
          async.elapse(const Duration(seconds: 1));
          sink.sent.clear();
          session.stopTune();
          expect(sink.sent.first, 'AC001;');
          session.teardown();
        });
      });

      test('a tune it started is read on the air, even when the first read-back beat it', () {
        // The tuner is otherwise never read while transmitting: answered `AC001;`
        // just before the tune began, it would read `inline` for the whole tune.
        fakeAsync((async) {
          session.startUpdates();
          session.feed('AC001;');
          session.startTune();
          session.feed('AC001;');
          session.feed('TX2;');
          sink.sent.clear();
          async.elapse(const Duration(seconds: 4));
          expect(sink.sent, contains('AC;'));
          // Once the tune's transmission ends, an over is just an over again.
          session.feed('TX0;');
          session.feed('TX2;');
          async.elapse(const Duration(seconds: 1));
          sink.sent.clear();
          async.elapse(const Duration(seconds: 30));
          expect(sink.sent, isNot(contains('AC;')));
          session.teardown();
        });
      });

      test('in line and bypass each write once and read back, and neither starts a tune', () {
        session.setTuner(inline: true);
        session.setTuner(inline: false);
        // The read-back is what shows what the radio took, not what was asked.
        expect(sink.sent, ['AC001;', 'AC;', 'AC000;', 'AC;']);
        expect(sink.sent.where((c) => c.startsWith('AC') && c.endsWith('2;')), isEmpty);
      });

      test('each answer is reported as the tuner it describes', () {
        session.feed('AC000;');
        session.feed('AC001;');
        session.feed('AC002;');
        expect(sink.tunerReports, [TunerStatus.bypassed, TunerStatus.inline, TunerStatus.tuning]);
        // A malformed answer is no answer: reporting it as "bypassed" would
        // tell an operator their tuner is out of line when it is not.
        session.feed('AC01;');
        expect(sink.tunerReports, hasLength(3));
      });

      test('is read far less often than the frequency, but still read', () {
        // A 4800-baud link spends ~27 ms on each `AC;` exchange, and the
        // tuner moves only when someone presses a button.
        fakeAsync((async) {
          session.startUpdates();
          async.elapse(const Duration(minutes: 2));
          final fa = sink.sent.where((c) => c == 'FA;').length;
          final ac = sink.sent.where((c) => c == 'AC;').length;
          expect(ac, greaterThan(1), reason: 'a tuner switched from the front panel must still be seen');
          expect(ac, lessThanOrEqualTo(fa ~/ 4), reason: 'not riding on every state poll');
          session.teardown();
        });
      });

      test('a tune in progress is read on every poll until it ends', () {
        // At the slow cadence a tune's outcome would otherwise show up to a
        // whole tuner interval after the radio had it.
        fakeAsync((async) {
          session.startUpdates();
          session.feed('AC002;');
          sink.sent.clear();
          async.elapse(const Duration(seconds: 4));
          expect(sink.sent, containsAllInOrder(['FA;', 'AC;']));
          session.feed('AC001;');
          sink.sent.clear();
          async.elapse(const Duration(seconds: 4));
          expect(sink.sent, contains('FA;'));
          expect(sink.sent, isNot(contains('AC;')), reason: 'settled, it goes back to the slow rate');
          session.teardown();
        });
      });

      test('a radio that refuses AC is reported as having no tuner, once, and is not asked again', () {
        fakeAsync((async) {
          session.startUpdates();
          session.feed('?;');
          untilTunerRead(async);
          expect(sink.sent, contains('AC;'), reason: 'one refusal is not yet proof: `?;` names no command');
          session.feed('?;');
          untilTunerRead(async);
          expect(sink.sent, isNot(contains('AC;')));
          expect(sink.tunerReports, [null]);

          sink.sent.clear();
          async.elapse(const Duration(minutes: 2));
          session.setTuner(inline: true);
          // A refused command every fifteen seconds for the life of the
          // connection, and a switch that writes to a tuner nobody has.
          expect(sink.sent.where((c) => c.startsWith('AC')), isEmpty);
          expect(sink.tunerReports, [null]);
          session.teardown();
        });
      });

      // A `?;` names no command: a raw command the radio refuses, counted,
      // would twice in a row cost a read that happened to be out.
      test('a refusal just after an extension\'s raw command is no strike — and one after that is', () {
        final followed = AppClock.followZoneClock;
        AppClock.followZoneClock = true;
        addTearDown(() => AppClock.followZoneClock = followed);
        fakeAsync((async) {
          session.startUpdates();
          for (var i = 0; i < 3; i++) {
            session.sendRaw(ascii.encode('ZZ;'));
            session.feed('?;');
            untilTunerRead(async);
          }
          expect(sink.tunerReports, isEmpty);

          session.sendRaw(ascii.encode('ZZ;'));
          async.elapse(rawRefusalGrace);
          session.feed('?;');
          untilTunerRead(async);
          session.feed('?;');
          untilTunerRead(async);
          expect(sink.tunerReports, [null], reason: 'the grace ends');
          session.teardown();
        });
      });

      test('a long over neither asks for the tuner nor counts the refusals heard on the air', () {
        // A radio may refuse what it will not handle while transmitting: counted, two refusals
        // during one long CQ would end the tuner's readout for the rest of the connection.
        fakeAsync((async) {
          session.startUpdates();
          session.feed('TX2;');
          sink.sent.clear();
          for (var i = 0; i < 12; i++) {
            session.feed('?;');
            async.elapse(const Duration(seconds: 5));
          }
          expect(sink.sent, isNot(contains('AC;')));
          session.feed('TX0;');
          untilTunerRead(async);
          expect(sink.sent, contains('AC;'));
          expect(sink.tunerReports, isEmpty, reason: 'never reported as a radio without a tuner');
          session.teardown();
        });
      });

      test('a refusal beside an AC answer is not the tuner refused, and only refusals in a row count', () {
        // `?;` names no command: a generic Yaesu that refuses `PC;` on every
        // poll answers it in the same batch as the `AC;` it does have. Were
        // that counted, or a strike outlived the answer that followed it, a
        // radio with a tuner would lose its readout to two stray refusals
        // minutes apart.
        fakeAsync((async) {
          session.startUpdates();
          for (final answer in ['?;', '?;AC001;', '?;AC001;', '?;']) {
            session.feed(answer);
            untilTunerRead(async);
            expect(sink.sent, contains('AC;'), reason: 'after $answer');
          }
          expect(sink.tunerReports, [TunerStatus.inline, TunerStatus.inline]);
          session.teardown();
        });
      });
    });

    group('PTT', () {
      test('keys with TX1; and unkeys with TX0;', () {
        // TX1 is CAT TX ON in the manual's P1 table; the bare `TX;` the
        // watch sends is the read, and would key nothing.
        session.setPtt(true);
        session.setPtt(false);
        expect(sink.sent, ['TX1;', 'TX0;']);
        expect(sink.txReports, isEmpty, reason: 'keyed is what the TX watch hears, never what was asked');
      });

      test('teardown unkeys a radio the app keyed, before anything else', () {
        // A teardown that forgets the unkey leaves the transmitter on the air
        // with nothing left to turn it off.
        session.startUpdates();
        session.setPtt(true);
        sink.sent.clear();
        session.teardown();
        expect(sink.sent, ['TX0;', 'AI0;']);
      });

      test('teardown sends no TX0; on a radio the app never keyed', () {
        // An unkey from a session that never keyed would cut off the operator
        // transmitting from the radio's own mic.
        session.startUpdates();
        sink.sent.clear();
        session.teardown();
        expect(sink.sent, ['AI0;']);
      });
    });
  });

  test('the CP2105 match is a guess, and only ever a suggestion', () {
    expect(Ft891Driver.matchesUsbIds(vendorId: 0x10C4, productId: 0xEA70), isTrue);
    expect(Ft891Driver.matchesUsbIds(vendorId: 0x10C4, productId: 0xEA60), isFalse);
    expect(Ft891Driver.matchesUsbIds(), isFalse);
  });

  test('a noise byte in front of a command does not take the command with it', () {
    // handleData decodes with allowInvalid, so one bad byte on the wire
    // becomes U+FFFD sitting IN FRONT of a perfectly good reading. An
    // anchored parse threw the whole thing away silently — on a 4800-baud
    // line beside a transmitting rig, that is the expected case.
    final sink = _FakeSink();
    final session = _stateOnlySession(sink);
    session.handleData(Uint8List.fromList([0xFF, ...ascii.encode('FA014233700;')]));
    expect(sink.readings, [const VfoReading(freqKHz: 14233.7)]);
  });

  test('a first reading is an answer, not the radio moving', () {
    // startUpdates asks immediately; treating that answer as movement
    // dropped every single connection into 200ms polling for the second or
    // so it took to ramp back down, for a radio nobody was touching.
    final sink = _FakeSink();
    final session = _stateOnlySession(sink)..startUpdates();
    session.handleData(Uint8List.fromList(ascii.encode('FA014233700;')));
    expect(session.pollInterval, kPollSlow);

    // A genuine move still speeds it up.
    session.handleData(Uint8List.fromList(ascii.encode('FA014240000;')));
    expect(session.pollInterval, kPollFast);
    session.teardown();
  });

  test('teardown says goodbye exactly once', () {
    // stopUpdates and teardown both used to send AI0; independently, so a
    // normal disconnect wrote it twice and the teardown protocol lived in
    // two places.
    final sink = _FakeSink();
    _stateOnlySession(sink)
      ..startUpdates()
      ..teardown();
    final offs = sink.sent.where((c) => c == 'AI0;').length;
    expect(offs, 1);
  });
  group('the TX watch', () {
    test('asks whether the radio is keyed, on its own cadence', () {
      // NOT folded into the five-second state poll: a whole over fits
      // inside one of those, and Auto-Information pushes nothing about the
      // PTT — `IF` carries the frequency and the mode and no TX flag.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        sink.sent.clear();
        async.elapse(const Duration(milliseconds: 450));
        expect(sink.sent, ['TX;', 'TX;']);
        session.teardown();
      });
    });

    test('reads all three answers, and says nothing for a radio that will not answer', () {
      final sink = _FakeSink();
      final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 200});
      session.feed('TX0;');
      expect(sink.txReports, [false]);
      // TX1 is the radio's own PTT — the mic, a footswitch — and TX2 is CAT
      // asking. Reading only TX2 as transmitting would leave the antenna
      // gate open for every over the operator keys by hand, which is most
      // of them.
      session.feed('TX1;');
      expect(sink.txReports, [false, true]);
      session.feed('TX2;');
      expect(sink.txReports, [false, true], reason: 'still transmitting is not news');
      session.feed('TX0;');
      expect(sink.txReports, [false, true, false]);

      sink.txReports.clear();
      session.feed('TX9;');
      expect(sink.txReports, isEmpty, reason: 'an answer nobody can read is not "receiving"');
      session.teardown();
    });

    test('the watch does not starve the frequency poll', () {
      // The trap, and it is invisible from either side alone: the watch
      // answers several times a second, AdaptivePoller defers on incoming
      // data, and a state poll that is re-armed every 200 ms never fires at
      // all. What is left is the 9-second staleness ceiling — so a dial turn
      // reaches the app nine seconds later, on exactly the radios (AI off)
      // where the poll is the only source of a frequency there is.
      //
      // Every other test here uses a session with the watch silenced, which
      // is why this one builds a live one.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        sink.sent.clear();

        // The radio answering the watch, as it would, all the way through.
        for (var i = 0; i < 20; i++) {
          async.elapse(const Duration(milliseconds: 200));
          session.feed('TX0;');
        }
        // Four seconds have passed: at the slow cadence the state poll is
        // due at least once, and it must have gone out.
        expect(sink.sent.where((c) => c == 'FA;'), isNotEmpty, reason: 'the frequency poll was starved by the TX watch');
        session.teardown();
      });
    });

    test('the meter capture is off unless a developer asks for it', () {
      // It costs three extra reads per cycle on a link that may be running
      // at 4800, and produces a line of raw numbers only a developer can
      // use. Left on by default it would be a permanent tax on every Yaesu
      // for a readout nobody sees.
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 200});
        session.startUpdates();
        session.feed('TX1;');
        sink.sent.clear();
        async.elapse(const Duration(milliseconds: 250));
        expect(sink.sent, ['TX;'], reason: 'the watch alone, no RM');
        session.teardown();
      });
    });

    test('with the capture on, a keyed rig has its meters read', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 200, yaesuMeterCaptureConfigKey: true});
        session.startUpdates();
        sink.sent.clear();
        // The transition reads them immediately: a capture that waited for
        // the next tick would miss a short over, which on a bench is most of
        // them.
        session.feed('TX1;');
        // The watch rides along with the meters: re-asking `TX;` is how the
        // unkey is noticed, and dropping it would leave the capture running
        // after the transmission ended.
        // PO, SWR, ALC and — on an FTDX10, which has the meter — VDD.
        expect(sink.sent, ['TX;', 'RM5;', 'RM6;', 'RM4;', 'RM8;']);

        sink.sent.clear();
        session.feed('TX0;');
        async.elapse(const Duration(milliseconds: 250));
        expect(sink.sent, ['TX;'], reason: 'nothing to measure on a receiving rig');
        session.teardown();
      });
    });

    test('both answer shapes on the Yaesu line are read', () {
      // The FT-891 answers `RM5123;` and the FTDX10 `RM5123000;` — its
      // manual documents a fixed three-digit tail the 891 does not have.
      // A parser that took only the short form would read NOTHING from an
      // FTDX10, and an unparsed answer looks exactly like a radio that
      // never replied.
      expect(parseMeterParams('5123'), (meter: 5, level: 123));
      expect(parseMeterParams('5123000'), (meter: 5, level: 123));
      // Neither a meter answer: `RM0;` selects what the front panel shows.
      expect(parseMeterParams('0'), isNull);
      expect(parseMeterParams('51x'), isNull);
    });

    test('a captured reading is reported RAW, and survives the unkey', () {
      final sink = _FakeSink();
      final session = Ft891Session(sink, config: const {yaesuMeterCaptureConfigKey: true});
      session.feed('RM5201;');
      session.feed('RM6012;');
      // Raw 0-255, unconverted. The whole point of the capture is that
      // Yaesu publishes no scale — a value that arrived here already turned
      // into watts or an SWR would be the guess this exists to avoid.
      expect(sink.diagnostics.last, contains('5=201'));
      expect(sink.diagnostics.last, contains('6=12'));

      // Kept after the rig unkeys: the numbers are read off a screen by a
      // person, and a line that blanked the moment they let go of the key
      // could not be read by the only thing that can use it.
      session.feed('TX0;');
      expect(sink.diagnostics.last, contains('5=201'));
      session.teardown();
    });

    test('an RM answer nobody asked for is ignored', () {
      // Without the capture on, an `RM` on the line belongs to something
      // else — another program on a shared port, a radio answering its own
      // front panel — and reading it would put numbers on a developer line
      // nobody switched on.
      final sink = _FakeSink();
      final session = Ft891Session(sink);
      session.feed('RM5201;');
      expect(sink.diagnostics, isEmpty);
      session.teardown();
    });

    test('a radio with a calibration reports real meters, in real units', () {
      // The other half of the capture: once a table exists, the same raw
      // reading becomes something an operator can act on. The FTDX10's own
      // table puts 89 at an SWR of 2.0 and 147 at 50 W.
      MeterCalibrations.instance.setForTesting({
        'yaesu/ftdx10': MeterCalibration(
          model: 'FTdx10',
          tables: const {
            MeterTable.swr: [MeterPoint(0, 1.0), MeterPoint(89, 2.0)],
            MeterTable.power: [MeterPoint(0, 0), MeterPoint(147, 50.0)],
          },
        ),
      });
      addTearDown(() => MeterCalibrations.instance.setForTesting({}));

      final sink = _FakeSink();
      final session = Ft891Session(sink, config: const {meterInfoConfigKey: 'yaesu/ftdx10'});
      session.feed('RM6089;');
      session.feed('RM5147;');
      expect(sink.meterReports, [(RadioMeter.swr, 2.0), (RadioMeter.powerOut, 50.0)]);

      // A meter the table does not describe stays off: the FTDX10 has an
      // ALC meter, but a table with no ALC rows cannot say what its numbers
      // mean, and a slot that never fills is worse than no slot.
      session.feed('RM4064;');
      expect(sink.meterReports.length, 2);
      session.teardown();
    });

    test('a radio with no calibration reads no meters at all', () {
      // The generic Yaesu entry, which does not know which radio is behind
      // it. Reading the meters anyway would spend three commands per cycle
      // on numbers nothing can interpret.
      MeterCalibrations.instance.setForTesting({});
      final sink = _FakeSink();
      final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 200});
      session.startUpdates();
      session.feed('TX1;');
      sink.sent.clear();
      session.feed('RM6089;');
      expect(sink.meterReports, isEmpty);
      expect(const Ft891Driver().telemetryMetersWith(const {}), isEmpty);
      session.teardown();
    });

    test('what a radio can show follows its table, not its driver', () {
      // One driver serves the whole Yaesu line and the scales do not: the
      // panel reserves a slot per meter BEFORE the first transmission, so
      // this answer decides what an operator sees on a radio that has never
      // been keyed.
      MeterCalibrations.instance.setForTesting({
        'yaesu/ftdx10': MeterCalibration(
          model: 'FTdx10',
          tables: const {
            MeterTable.swr: [MeterPoint(0, 1.0)],
            MeterTable.voltage: [MeterPoint(192, 13.8)],
          },
        ),
      });
      addTearDown(() => MeterCalibrations.instance.setForTesting({}));
      expect(const Ft891Driver().telemetryMetersWith(const {meterInfoConfigKey: 'yaesu/ftdx10'}), {RadioMeter.swr, RadioMeter.supplyVolts});
    });

    test('the meters are deliberately not read', () {
      // Yaesu answers `RM` with a raw 0-255 and publishes no scale for it,
      // so any SWR taken from one would be invented — and this app warns
      // the operator at 1.8. The capture above is how the scale gets built;
      // until it has been, the driver declaring no meters is what keeps the
      // panel from reserving slots that will never fill.
      expect(const Ft891Driver().telemetryMeters, isEmpty);
    });
  });
}
