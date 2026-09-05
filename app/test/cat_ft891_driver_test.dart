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
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/meter_calibration.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink {
  final problems = <String?>[];
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
Ft891Session _stateOnlySession(EquipmentSink sink) =>
    Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000});

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
      expect(framer.add('FA014250000;MD02;'), [
        const AsciiCatCommand('FA', '014250000'),
        const AsciiCatCommand('MD', '02'),
      ]);
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
      expect(found, [
        const AsciiCatCommand('MD', '03'),
        const AsciiCatCommand('FA', '007074000'),
      ]);
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
        expect(sink.sent, ['AI1;', 'FA;', 'MD0;', 'PC;', 'KS;']);
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
  });

  test('the CP2105 match is a guess, and only ever a suggestion', () {
    expect(Ft891Driver.matchesUsbIds(vendorId: 0x10C4, productId: 0xEA70), isTrue);
    expect(Ft891Driver.matchesUsbIds(vendorId: 0x10C4, productId: 0xEA60), isFalse);
    expect(Ft891Driver.matchesUsbIds(), isFalse);
  });

  test('the driver claims hardware verification, because it has met a radio', () {
    // app-polo shipped this untested. It has since been run against a real
    // FT-891 at 4800 baud over the radio's own CP2105 bridge, in BOTH
    // directions: reading (including the IF packets transceive pushes) and
    // writing (a spot click in the app retuned the rig, exercising the
    // whole suggestion -> RadioService -> CatService -> driver chain).
    expect(const Ft891Driver().hardwareVerified, isTrue);
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
        expect(sink.sent.where((c) => c == 'FA;'), isNotEmpty,
            reason: 'the frequency poll was starved by the TX watch');
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
        final session = Ft891Session(sink, config: const {
          telemetryIntervalConfigKey: 200,
          yaesuMeterCaptureConfigKey: true,
        });
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
        'yaesu/ftdx10': MeterCalibration(model: 'FTdx10', tables: const {
          MeterTable.swr: [MeterPoint(0, 1.0), MeterPoint(89, 2.0)],
          MeterTable.power: [MeterPoint(0, 0), MeterPoint(147, 50.0)],
        }),
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
        'yaesu/ftdx10': MeterCalibration(model: 'FTdx10', tables: const {
          MeterTable.swr: [MeterPoint(0, 1.0)],
          MeterTable.voltage: [MeterPoint(192, 13.8)],
        }),
      });
      addTearDown(() => MeterCalibrations.instance.setForTesting({}));
      expect(
        const Ft891Driver().telemetryMetersWith(const {meterInfoConfigKey: 'yaesu/ftdx10'}),
        {RadioMeter.swr, RadioMeter.supplyVolts},
      );
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
