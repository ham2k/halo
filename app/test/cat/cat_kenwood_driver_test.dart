// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Kenwood driver, which has never met a radio: it is written from
// published CAT references, so these tests are the only thing standing
// between a reference-reading mistake and a shipped one.
//
// Most of the file is about ONE decision — that the mode's position inside
// the `IF` packet is learned from the radio rather than assumed. The widths
// ahead of it differ across the Kenwood line, and a wrong offset does not
// fail: it reports a plausible wrong mode, forever, silently. So the tests
// below care less about the happy path than about what happens when the
// evidence is ambiguous, stale, or contradicted.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cat_ascii_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/meter_calibration.dart';

class _FakeSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final diagnostics = <String?>[];

  /// The next send throws, as a write on a dropped link can.
  bool failNextSend = false;

  @override
  void send(List<int> bytes) {
    if (failNextSend) {
      failNextSend = false;
      throw StateError('link down');
    }
    sent.add(ascii.decode(bytes));
  }

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

void main() {
  group('the codec', () {
    test('frequency is ELEVEN digits, not Yaesu\'s nine', () {
      // The single likeliest way to port this protocol wrong: a nine-digit
      // command is ignored by the radio rather than rejected, so it looks
      // like a dead cable.
      expect(buildKenwoodSetFrequencyCommand(14250000), 'FA00014250000;');
      expect(encodeKenwoodFrequencyHz(14250000).length, 11);
      expect(parseKenwoodFrequencyParams('00014250000'), 14250000);
      expect(parseKenwoodFrequencyParams('014250000'), isNull, reason: 'nine digits is a Yaesu frequency');
    });

    test('MD carries no VFO selector, unlike Yaesu', () {
      // Yaesu's is MD0<code>. Sending that shape to a Kenwood sets nothing.
      expect(buildKenwoodSetModeCommand('USB'), 'MD2;');
      expect(buildKenwoodSetModeCommand('CW'), 'MD3;');
      expect(parseKenwoodModeParams('2'), 'USB');
      expect(parseKenwoodModeParams('02'), isNull, reason: 'a two-character answer is Yaesu framing, not a Kenwood mode');
    });

    test('a mode the radio has no code for sends nothing', () {
      // Rather than a malformed command it would silently reject.
      expect(buildKenwoodSetModeCommand('PSK'), isNull);
      expect(buildKenwoodSetModeCommand(null), isNull);
    });

    test('auto-information asks for level 2, which reports host changes too', () {
      // AI1 reports only what the RADIO changed. AI2 is what makes a retune
      // from the app come back as confirmation.
      expect(buildKenwoodAutoInformationCommand(true), 'AI2;');
      expect(buildKenwoodAutoInformationCommand(false), 'AI0;');
    });

    test('the IF frequency is read from the head, which is stable across the line', () {
      expect(
        parseKenwoodInfoFrequency(
          '00014250000'
          '0000'
          '+00000'
          '00',
        ),
        14250000,
      );
      expect(parseKenwoodInfoFrequency('0001425'), isNull, reason: 'truncated');
    });

    test('PC is a 3-digit level this driver treats as watts directly', () {
      expect(buildKenwoodSetPowerCommand(100), 'PC100;');
      expect(buildKenwoodSetPowerCommand(5), 'PC005;');
      expect(parseKenwoodPowerParams('100'), 100);
      expect(parseKenwoodPowerParams('05'), isNull, reason: 'PC is always 3 digits, unlike a two-digit stray');
    });

    test('a power outside the documented range is clamped, not sent malformed', () {
      expect(buildKenwoodSetPowerCommand(150), 'PC100;');
      expect(buildKenwoodSetPowerCommand(-5), 'PC000;');
    });
  });

  group('learning where the mode sits in an IF packet', () {
    test('the frequency digits are never mistaken for the mode', () {
      // A mode code is one character and frequencies are full of them: '1'
      // is LSB and also the first digit of 14 MHz. Skipping the frequency
      // field is what keeps the search honest.
      const params =
          '00014250000'
          '0000'
          '+00000'
          '2';
      expect(kenwoodModeOffsetIn(params, '2'), params.length - 1);
    });

    test('an ambiguous packet teaches nothing rather than guessing', () {
      // Two fields hold the code. Picking either would be a coin flip whose
      // wrong side is silent and permanent.
      const params =
          '00014250000'
          '2000'
          '+00000'
          '2';
      expect(kenwoodModeOffsetIn(params, '2'), isNull);
    });

    test('a code that appears nowhere teaches nothing', () {
      // The radio moved between the MD answer and this packet, or this is
      // not a layout we understand.
      expect(
        kenwoodModeOffsetIn(
          '00014250000'
              '0000',
          '7',
        ),
        isNull,
      );
    });
  });

  group('the session', () {
    late _FakeSink sink;
    late KenwoodSession session;

    setUp(() {
      sink = _FakeSink();
      session = KenwoodSession(sink);
    });

    void receive(String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));

    test('startUpdates turns AI on and asks for everything once', () {
      session.startUpdates();
      expect(sink.sent, containsAll(['AI2;', 'FA;', 'MD;', 'IF;']));
    });

    test('every poll asks for IF too, or the offset can never be learned', () {
      // The pair the learner needs — an IF beside a FRESH MD — otherwise
      // cannot reliably occur: while Auto-Information pushes, the adaptive
      // poller sees data and defers, so no MD is asked for; when the radio is
      // quiet enough to poll, it is not pushing IFs. Asking for all three
      // together is what makes the pair happen at all.
      //
      // Mutation check: drop IF; from _requestState and this fails, and the
      // learning tests below keep passing while the feature never completes
      // on a real radio.
      fakeAsync((async) {
        final polled = KenwoodSession(sink)..startUpdates();
        sink.sent.clear();
        async.elapse(const Duration(seconds: 30));
        expect(sink.sent, containsAll(['FA;', 'MD;', 'IF;']));
        polled.stopUpdates();
      });
    });

    test('teardown before startUpdates does not write to the connection', () {
      // A session superseded mid-handshake never configured the radio, so it
      // has nothing to put back.
      KenwoodSession(sink).teardown();
      expect(sink.sent, isEmpty);
    });

    test('stopUpdates leaves the radio quiet again', () {
      // AI persists across a disconnect, so a logger that never turns it off
      // leaves the rig chattering at whatever connects next.
      session.startUpdates();
      sink.sent.clear();
      session.stopUpdates();
      expect(sink.sent, contains('AI0;'));
    });

    group('PTT', () {
      test('keys with a bare TX; and unkeys with RX;', () {
        // The bare form on purpose: `TX1;` is DATA SEND on the TS-590/890/990,
        // which takes the rear-panel audio instead of the operator's mic.
        session.setPtt(true);
        session.setPtt(false);
        expect(sink.sent, ['TX;', 'RX;']);
      });

      test('the TX watch never asks with TX;', () {
        // On this line `TX;` is not a question: a watch that asked it would
        // key the radio five times a second.
        fakeAsync((async) {
          final watched = KenwoodSession(sink)..startUpdates();
          async.elapse(const Duration(seconds: 2));
          expect(sink.sent.where((c) => c == 'IF;').length, greaterThan(2), reason: 'the watch ran');
          expect(sink.sent, isNot(contains('TX;')));
          watched.teardown();
        });
      });

      test('teardown unkeys a radio the app keyed, first', () {
        // A teardown that forgets the unkey leaves the transmitter on the air
        // with nothing left to turn it off.
        session.startUpdates();
        session.setPtt(true);
        sink.sent.clear();
        session.teardown();
        expect(sink.sent.first, 'RX;');
      });

      test('an unkey that throws is sent again at teardown', () {
        // A session that forgot it keyed the moment it tried to unkey would
        // leave a radio whose unkey never went out keyed after the disconnect.
        session.startUpdates();
        session.setPtt(true);
        sink.failNextSend = true;
        expect(() => session.setPtt(false), throwsStateError);
        sink.sent.clear();
        session.teardown();
        expect(sink.sent.first, 'RX;');
      });

      test('teardown sends no RX; on a radio the app never keyed', () {
        // An unkey from a session that never keyed would cut off the operator
        // transmitting from the radio's own mic.
        session.startUpdates();
        session.teardown();
        expect(sink.sent, isNot(contains('RX;')));
      });
    });

    test('a frequency and a mode arrive as readings, in kHz', () {
      receive('FA00014250000;MD2;');
      expect(sink.readings.first.freqKHz, 14250.0);
      expect(sink.readings.last.mode, 'USB');
    });

    test('a PC reply reports power upward', () {
      receive('PC100;');
      expect(sink.powers, [100]);
    });

    test('setPower sends PC, and startUpdates polls for it', () {
      session.setPower(75);
      expect(sink.sent, contains('PC075;'));

      sink.sent.clear();
      session.startUpdates();
      expect(sink.sent, contains('PC;'));
    });

    test('a command split across two chunks still reads', () {
      // Serial delivers arbitrary chunks; this is the residual buffer's whole
      // reason for existing.
      receive('FA000142');
      expect(sink.readings, isEmpty);
      receive('50000;');
      expect(sink.readings.single.freqKHz, 14250.0);
    });

    test('IF reports its frequency immediately, and no mode until the offset is known', () {
      // The safe half of the packet is usable from the first one. The unsafe
      // half waits for evidence.
      receive(
        'IF00014250000'
        '0000'
        '+00000'
        '2;',
      );
      expect(sink.readings.single.freqKHz, 14250.0);
      expect(sink.readings.single.mode, isNull, reason: 'nothing has confirmed where the mode lives yet');
      expect(session.modeOffset, isNull);
    });

    test('two IF packets agreeing against fresh MD answers settle the offset', () {
      const tail =
          '0000'
          '+00000'
          '2';
      // Each IF has to be matched against its OWN MD answer, or two packets
      // from a single reading would "agree" without proving anything.
      receive('MD2;IF00014250000$tail;');
      expect(session.modeOffset, isNull, reason: 'one sighting is a coincidence');

      receive('MD2;IF00014255000$tail;');
      expect(session.modeOffset, 21);

      // And from here IF alone carries the mode.
      sink.readings.clear();
      receive(
        'IF00014260000'
        '0000'
        '+00000'
        '3;',
      );
      expect(sink.readings.single.freqKHz, 14260.0);
      expect(sink.readings.single.mode, 'CW');
    });

    test('the transmit flag rides in IF, one place ahead of the mode', () {
      // Kenwood's `TX;` KEYS the radio — there is no readable transmit
      // status anywhere on the line — so this flag is the only way to ask,
      // and it is read against the same offset the mode is. Getting it from
      // an offset of its own would be a second unverified guess about a
      // layout this driver deliberately refuses to guess about once.
      const rx =
          '0000'
          '+0000'
          '0';
      const tx =
          '0000'
          '+0000'
          '1';
      receive(
        'MD2;IF00014250000$rx'
        '2;',
      );
      receive(
        'MD2;IF00014255000$rx'
        '2;',
      );
      expect(session.modeOffset, 21, reason: 'the offset has to be settled before the flag can be located');
      // Not from the packet that SETTLED the offset: that one is read with
      // the offset it had on arrival, which is none — the same rule the
      // mode itself follows here.
      expect(sink.txReports, isEmpty);

      receive(
        'IF00014255000$rx'
        '2;',
      );
      expect(sink.txReports, [false]);
      receive(
        'IF00014255000$tx'
        '2;',
      );
      expect(sink.txReports, [false, true]);
      receive(
        'IF00014255000$tx'
        '2;',
      );
      expect(sink.txReports, [false, true], reason: 'still transmitting is not news');
      receive(
        'IF00014255000$rx'
        '2;',
      );
      expect(sink.txReports, [false, true, false]);
    });

    test('an unlearned layout says nothing about transmitting', () {
      // The flag is located by the mode offset, so before that is settled
      // there is no character to read — and reading one anyway would report
      // a digit out of the clarifier offset as the PTT, which decides
      // whether an antenna relay may move.
      receive(
        'IF00014250000'
        '0000'
        '+0000'
        '1'
        '2;',
      );
      expect(session.modeOffset, isNull);
      expect(sink.txReports, isEmpty);
    });

    test('an IF with no MD before it teaches nothing', () {
      // Mutation check: drop the `_pendingModeCode = null` and this passes
      // while the offset gets confirmed by evidence that was never fresh.
      const tail =
          '0000'
          '+00000'
          '2';
      receive('MD2;IF00014250000$tail;');
      receive('IF00014255000$tail;');
      expect(session.modeOffset, isNull, reason: 'the second packet was never matched against a reading of its own');
    });

    test('disagreeing sightings restart the count rather than averaging', () {
      // A layout that looks like one offset once and another the next time is
      // not a layout we have understood.
      receive(
        'MD2;IF00014250000'
        '0000'
        '+00000'
        '2;',
      );
      receive(
        'MD3;IF00014250000'
        '0003'
        '+00000'
        '9;',
      );
      expect(session.modeOffset, isNull);
    });

    test('writes go out in the radio\'s own shapes', () {
      session.setFrequency(14250.0);
      session.setMode('CW');
      expect(sink.sent, ['FA00014250000;', 'MD3;']);
    });

    group('the DATA submode', () {
      late KenwoodSession ts590;
      setUp(() => ts590 = KenwoodSession(sink, dataMode: true));
      void receive590(String text) => ts590.handleData(Uint8List.fromList(ascii.encode(text)));

      // `MD` has no FT8 or DATA-USB code: without `DA1;` the rig stays in
      // whatever mode a band recall brought back, and the log takes that.
      test('a data mode is its base mode with DA1', () {
        ts590.setMode('DATA-USB');
        expect(sink.sent, ['MD2;', 'DA1;']);
      });

      test('plain USB switches it off, so a rig left in USB-DATA does not stay there', () {
        ts590.setMode('USB');
        expect(sink.sent, ['MD2;', 'DA0;']);
      });

      test('CW has no DATA submode to state', () {
        ts590.setMode('CW');
        expect(sink.sent, ['MD3;']);
      });

      // `MD2;` never says DATA; reported alone, a rig running FT8 in USB-DATA
      // would log USB.
      test('USB with DA1 reports as DATA-USB, and back to USB with DA0', () {
        receive590('MD2;DA1;');
        expect(sink.readings.last, const VfoReading(mode: 'DATA-USB'));
        receive590('DA0;');
        expect(sink.readings.last, const VfoReading(mode: 'USB'));
      });

      // The poll's `MD` answer arrives before its `DA`. Reported against the
      // flag from before the set, it says USB, and the log loses the FT8 it
      // was just told.
      test('a data mode just set is reported as set, before the radio confirms it', () {
        ts590.setMode('DATA-USB');
        receive590('MD2;');
        expect(sink.readings.last, const VfoReading(mode: 'DATA-USB'));
      });

      test('is polled with everything else', () {
        fakeAsync((async) {
          ts590.startUpdates();
          sink.sent.clear();
          async.elapse(const Duration(seconds: 30));
          expect(sink.sent, contains('DA;'));
          expect(sink.sent.indexOf('DA;'), lessThan(sink.sent.indexOf('MD;')), reason: 'MD is reported against the flag DA reads');
          ts590.stopUpdates();
        });
      });

      // A radio without it gets the base mode and nothing else: DA on a K4
      // is its digital-audio command, and elsewhere a refused question.
      test('a radio without it is still put in the base mode', () {
        session.setMode('DATA-USB');
        expect(sink.sent, ['MD2;']);
      });
    });

    test('a session polls, so it reports a poll cadence rather than claiming to push', () {
      // Smart VFO Snap uses this to tell a settled VFO from an unasked one.
      expect(session.expectedUpdateInterval, isNotNull);
      expect(session.expectedUpdateInterval, session.pollInterval);
    });

    test('a declared offset is used from the very first packet', () {
      // What a SPECIFIC radio built on this driver gets: its definition
      // already knows the layout, so nothing has to be worked out.
      final known = KenwoodSession(sink, declaredModeOffset: 21)..startUpdates();
      known.handleData(
        Uint8List.fromList(
          ascii.encode(
            'IF00014250000'
            '0000'
            '+00000'
            '2;',
          ),
        ),
      );

      expect(sink.readings.single.mode, 'USB', reason: 'no learning period for a radio we already know');
      expect(known.modeOffset, 21);
      expect(sink.diagnostics, contains('IF mode offset 21 (declared)'));
    });

    test('a declared offset the radio contradicts is reported, not trusted silently', () {
      // The reason declaring one does not switch the checking off: a wrong
      // entry in OUR table reports the wrong mode forever, and this is the
      // only place that could ever notice. It reaches a developer through the
      // row's devMode line rather than needing the radio on a bench.
      final wrong = KenwoodSession(sink, declaredModeOffset: 15);
      wrong.handleData(
        Uint8List.fromList(
          ascii.encode(
            'MD2;IF00014250000'
            '0000'
            '+00000'
            '2;',
          ),
        ),
      );

      expect(sink.diagnostics, contains('IF mode offset 15 declared, radio says 21'));
    });

    test('a contradicted declaration stops being read, rather than reporting a wrong mode forever', () {
      // The trap the previous test cannot spring: its wrong index holds a
      // character that is no mode at all, so parsing there fails safe. Here
      // index 14 holds '1' — LSB, perfectly valid — while the radio's own
      // answer is USB. Keep reading at the declared index and every later
      // packet reports LSB, silently, for the whole connection.
      final wrong = KenwoodSession(sink, declaredModeOffset: 14);
      wrong.handleData(
        Uint8List.fromList(
          ascii.encode(
            'MD2;IF00014250000'
            '0001'
            '+00000'
            '2;',
          ),
        ),
      );

      expect(sink.diagnostics, contains('IF mode offset 14 declared, radio says 21'));
      expect(sink.readings.last.mode, 'USB', reason: 'the wrong reading is corrected from where the radio says the mode is');

      // A further packet with no fresh MD to lean on: mode now comes from
      // MD; alone, which is slower and right, rather than from an index the
      // radio has already contradicted.
      wrong.handleData(
        Uint8List.fromList(
          ascii.encode(
            'IF00014250000'
            '0001'
            '+00000'
            '2;',
          ),
        ),
      );
      expect(sink.readings.last.mode, isNull, reason: 'nothing is read at the discredited index');
    });

    test('a contradiction is reported once, and policing then stops', () {
      // The layout does not change mid-session, so re-deciding it on every
      // packet forever would add nothing — and it writes through to the row.
      final known = KenwoodSession(sink, declaredModeOffset: 15);
      for (var i = 0; i < 4; i++) {
        known.handleData(
          Uint8List.fromList(
            ascii.encode(
              'MD2;IF00014250000'
              '0000'
              '+00000'
              '2;',
            ),
          ),
        );
      }
      expect(sink.diagnostics.where((d) => d!.contains('radio says')), hasLength(1));
    });

    test('a nonsense declared offset is ignored rather than trusted', () {
      // Below the frequency field it could only ever be pointing at a digit.
      final type = EquipmentRegistry().typeFor('kenwood-serial')!;
      final session = type.driver.createSession(sink, {KenwoodDriver.ifModeOffsetKey: 3}) as KenwoodSession;
      expect(session.declaredModeOffset, isNull);
    });

    test('the QMX, QCX and FX-4CR pin the layout the driver would otherwise spend a connection learning', () {
      // The override has to travel through driverConfig() to reach the
      // session: a pinned offset that never arrives costs nothing visible —
      // the radio is simply read the slow way — so nothing else here would
      // notice it going missing. The FX-4CR carries the QMX's pin because
      // that is the entry its operators proved this radio on, as does the QCX.
      for (final key in ['qmx-serial', 'qcx-serial', 'fx4cr-serial']) {
        final type = EquipmentRegistry().typeFor(key)!;
        final session = type.driver.createSession(sink, type.driverConfig(const {})) as KenwoodSession;
        expect(session.declaredModeOffset, 27, reason: key);
      }
    });

    test('the KX2 and KX3 pin the same layout, and the generic Elecraft entry pins none', () {
      // The pin is the ONLY thing separating a named Elecraft from the
      // generic one — same driver, same transport, same baud rate. Drop it
      // and both named entries become duplicates that nothing distinguishes,
      // while still connecting, so no other test here would notice.
      for (final key in ['kx2-serial', 'kx3-serial']) {
        final type = EquipmentRegistry().typeFor(key)!;
        final session = type.driver.createSession(sink, type.driverConfig(const {})) as KenwoodSession;
        expect(session.declaredModeOffset, 27, reason: '$key pins the offset both radios were seen using');
      }

      // The rest of the Elecraft line has not been seen, and an offset
      // asserted for a radio nobody has run is the mistake the check in the
      // driver exists to catch rather than one to ship.
      final generic = EquipmentRegistry().typeFor('elecraft-serial')!;
      final session = generic.driver.createSession(sink, generic.driverConfig(const {})) as KenwoodSession;
      expect(session.declaredModeOffset, isNull);
    });

    test('the driver declares its offset key, so a radio definition may override it', () {
      // The registry self-check refuses an override of a key no transport or
      // driver recognizes, so without this a specific radio pinning its
      // layout would fail a test rather than silently doing nothing.
      expect(const KenwoodDriver().recognizedConfigKeys, contains(KenwoodDriver.ifModeOffsetKey));
    });

    test('line noise does not throw out of the stream callback', () {
      // A noise byte becomes a replacement character in FRONT of a good
      // command; on a serial line beside a transmitting rig that is expected.
      session.handleData(Uint8List.fromList([0xFF, ...ascii.encode('FA00014250000;')]));
      expect(sink.readings.single.freqKHz, 14250.0);
    });
  });

  group('the Lab599 TX-500 line', () {
    late _FakeSink sink;

    setUp(() => sink = _FakeSink());

    KenwoodSession sessionFor(String typeKey) {
      final type = EquipmentRegistry().typeFor(typeKey)!;
      return type.driver.createSession(sink, type.driverConfig(const {})) as KenwoodSession;
    }

    void receive(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));

    test('every TX-500 entry pins the LAB599 mode table, through driverConfig', () {
      // Without the pin the radio reads as a plain Kenwood: its DIG reports
      // as RTTY, a mode it does not have, and nothing fails.
      for (final key in ['tx500-serial', 'tx500mp-serial', 'tx500mp-bluetooth']) {
        expect(sessionFor(key).modeDialect, KenwoodModeDialect.lab599, reason: key);
      }
    });

    test('MD6 is DIG on the TX-500, and RTTY on any other Kenwood', () {
      final lab599 = sessionFor('tx500mp-serial');
      receive(lab599, 'MD6;');
      expect(sink.readings.last.mode, 'DATA-USB');

      sink.readings.clear();
      final kenwood = sessionFor('kenwood-serial');
      receive(kenwood, 'MD6;');
      expect(sink.readings.last.mode, 'RTTY');
    });

    test('the mode table offers DIG and no RTTY', () {
      final type = EquipmentRegistry().typeFor('tx500mp-serial')!;
      final modes = type.driver.settableModes(type.driverConfig(const {}));
      expect(modes, contains('DATA-USB'));
      expect(modes, isNot(contains('RTTY')));
      expect(modes, isNot(contains('RTTY-R')));
    });

    test('only a TX-500 is asked for its ID', () {
      // ID tells the radio's two CAT protocols apart. Asking it of the rest of
      // the line would add a question every Kenwood answers and nothing reads.
      final lab599 = sessionFor('tx500mp-serial');
      lab599.startUpdates();
      expect(sink.sent, contains('ID;'));

      sink.sent.clear();
      sessionFor('kenwood-serial').startUpdates();
      expect(sink.sent, isNot(contains('ID;')));
    });

    test('a TX-500 asks its ID until it answers, and then no more', () {
      // An ID; sent before the operator hands CAT to the LiNK500MP goes
      // unanswered. Asked once, the session runs without PT, VL or DIG.
      fakeAsync((async) {
        final session = sessionFor('tx500mp-serial');
        session.startUpdates();
        sink.sent.clear();
        async.elapse(const Duration(seconds: 10));
        expect(sink.sent, contains('ID;'));

        receive(session, 'ID505;');
        sink.sent.clear();
        async.elapse(const Duration(seconds: 10));
        expect(sink.sent, contains('FA;'), reason: 'still polling');
        expect(sink.sent, isNot(contains('ID;')));
        session.teardown();
      });
    });

    test('DIG goes out as MD6 only on the LAB599 protocol', () {
      // On TS-2000 the radio refuses MD6, which would leave it in whatever
      // mode it was in. Its USB base is what a radio without DIG gets.
      final session = sessionFor('tx500mp-serial');
      session.startUpdates();

      sink.sent.clear();
      session.setMode('DATA-USB');
      expect(sink.sent, ['MD2;'], reason: 'the radio has not said which protocol it is on yet');

      receive(session, 'ID505;');
      sink.sent.clear();
      session.setMode('DATA-USB');
      expect(sink.sent, ['MD6;']);

      session.startUpdates();
      receive(session, 'ID019;');
      sink.sent.clear();
      session.setMode('DATA-USB');
      expect(sink.sent, ['MD2;'], reason: 'ID019 is the TS-2000 protocol');
    });

    test('the original TX-500 answers ID500, and that is LAB599 too', () {
      final session = sessionFor('tx500-serial');
      session.startUpdates();
      receive(session, 'ID500;');
      sink.sent.clear();
      session.setMode('DATA-USB');
      expect(sink.sent, ['MD6;']);
    });

    test('a mode the TX-500 has no code for sends nothing', () {
      final session = sessionFor('tx500mp-serial');
      session.startUpdates();
      receive(session, 'ID505;');
      sink.sent.clear();
      session.setMode('RTTY');
      expect(sink.sent, isEmpty);
    });

    test('a learned IF offset reads DIG from the LAB599 table too', () {
      // The IF path has its own lookup: miss the dialect there and a learned
      // offset reports RTTY on every packet after the MD answers that taught it.
      final session = sessionFor('tx500mp-serial');
      const tail =
          '0000'
          '+00000'
          '6';
      receive(session, 'MD6;IF00014074000$tail;');
      receive(session, 'MD6;IF00014075000$tail;');
      expect(session.modeOffset, 21);
      sink.readings.clear();
      receive(session, 'IF00014076000$tail;');
      expect(sink.readings.single.mode, 'DATA-USB');
    });

    group('GPS sentences interleaved by the LiNK500MP', () {
      // A sentence holds no `;`, so framed as CAT it fuses with the command
      // after it — `$GPRMC,…\r\nFA…;` reads as a `GP` command and the
      // frequency is lost, on every GPS fix, with nothing logged.
      const rmc =
          r'$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A'
          '\r\n';

      test('are dropped, so the command after one still reads', () {
        final session = sessionFor('tx500mp-ble');
        receive(session, '${rmc}FA00014074000;');
        expect(sink.readings.single.freqKHz, 14074.0);
      });

      test('are dropped when a read splits one, or the command it sits in front of', () {
        final session = sessionFor('tx500mp-bluetooth');
        receive(session, 'FA0001${rmc.substring(0, 20)}');
        receive(session, rmc.substring(20, 50));
        receive(session, '${rmc.substring(50)}4074000;');
        expect(sink.readings.single.freqKHz, 14074.0);
      });

      test('a stray dollar sign with no line end holds nothing up', () {
        // Waiting for a line end that never comes would park every command
        // behind it in the residual for good.
        final session = sessionFor('tx500mp-serial');
        receive(
          session,
          r'$'
          '${'x' * 90}FA00014074000;',
        );
        expect(sink.readings.single.freqKHz, 14074.0);
      });

      test('a stray dollar sign never swallows the replies behind it', () {
        // No sentence holds a `;`, so one ends a would-be sentence: read on to
        // the next GPS fix's line end, a noise `$` takes every reply before it.
        final session = sessionFor('tx500mp-serial');
        receive(session, '\$FA00014074000;MD2;$rmc');
        expect(sink.readings.first.freqKHz, 14074.0);
        expect(sink.readings.last.mode, 'USB');
      });

      test('only the TX-500 line drops them: a dollar sign is CAT on the K4', () {
        // The K4 marks its sub receiver with `$`. Filtered, its `MD$2;` sub
        // report would come out as `MD2;`, the main receiver's.
        expect(AsciiCatFramer().add(r'MD$2;'), [const AsciiCatCommand('MD', r'$2')]);
      });
    });

    group('power', () {
      test('PC is a share of the rated output, not watts', () {
        // Read as watts, a TX-500 at full power shows 100 W.
        final session = sessionFor('tx500mp-ble');
        receive(session, 'FA00014074000;PC100;PC055;');
        expect(sink.powers, [10, 5.5]);
      });

      test('on 6 m the rated output is 7 W', () {
        final session = sessionFor('tx500mp-serial');
        receive(session, 'FA00050313000;PC100;');
        expect(sink.powers, [7]);
      });

      test('a set goes out as a share, inside the 10–100 the radio takes, and is read back', () {
        // Sent as watts, 5 W is PC005: below 10, which the radio ignores.
        final session = sessionFor('tx500mp-ble');
        receive(session, 'FA00014074000;');
        session.setPower(5);
        session.setPower(0.5);
        session.setPower(20);
        expect(sink.sent, ['PC050;', 'PC;', 'PC010;', 'PC;', 'PC100;', 'PC;']);
      });

      test('the entries cap the power control at the radio\'s 10 W', () {
        for (final key in ['tx500-serial', 'tx500mp-serial', 'tx500mp-ble']) {
          expect(EquipmentRegistry().typeFor(key)!.driverConfig(const {})['maxWatts'], 10, reason: key);
        }
      });
    });

    group('meters', () {
      // The TX flag sits one character ahead of the mode.
      const txInfo = 'IF00014074000${'0000+00001'}2;';
      const rxInfo = 'IF00014074000${'0000+00000'}2;';

      // Learns the IF offset, then reports the radio keyed.
      void keyed(KenwoodSession session) {
        receive(session, 'FA00014074000;ID505;');
        for (final freq in ['00014074000', '00014075000']) {
          receive(session, 'MD2;IF$freq${'0000+00000'}2;');
        }
        receive(session, txInfo);
      }

      setUp(() {
        final json = File('lib/services/cat/drivers/info/lab599/tx500.json').readAsStringSync();
        MeterCalibrations.instance.setForTesting({'lab599/tx500': MeterCalibration.fromJson(jsonDecode(json) as Map<String, dynamic>)});
        addTearDown(() => MeterCalibrations.instance.setForTesting({}));
      });

      test('the TX-500 entries read power out and volts, and no other Kenwood reads any', () {
        // Every other Kenwood meters through RM, which changes the meter on
        // the operator's own panel.
        for (final key in ['tx500-serial', 'tx500mp-serial', 'tx500mp-ble']) {
          final type = EquipmentRegistry().typeFor(key)!;
          expect(type.driver.telemetryMetersWith(type.driverConfig(const {})), {RadioMeter.powerOut, RadioMeter.supplyVolts}, reason: key);
        }
        final kenwood = EquipmentRegistry().typeFor('kenwood-serial')!;
        expect(kenwood.driver.telemetryMetersWith(kenwood.driverConfig(const {})), isEmpty);
      });

      test('keyed, SM0 is read as power out on the calibration file\'s scale, and VL as volts', () {
        fakeAsync((async) {
          final session = sessionFor('tx500mp-ble');
          keyed(session);
          expect(sink.sent, containsAllInOrder(['SM0;', 'VL;', 'PT;', 'IF;']), reason: 'the PT or IF after SM is what confirms it');
          expect(sink.sent, isNot(contains(startsWith('RM'))), reason: 'RM changes the meter on the radio');

          receive(session, 'SM00015;VL11.7 ;$txInfo');
          expect(sink.meterReports, [(RadioMeter.supplyVolts, 11.7), (RadioMeter.powerOut, 5.0)]);
          session.teardown();
        });
      });

      test('an SM answer while receiving is the S-meter, and is not reported as power', () {
        // Even when the PT after it finds the radio keyed: held while
        // receiving, an S9 would open the over as its first power-out.
        final session = sessionFor('tx500mp-ble');
        receive(session, 'ID505;SM00015;PT1;');
        expect(sink.meterReports, isEmpty);
      });

      test('an SM answer the next IF finds unkeyed is the S-meter, and is not reported as power', () {
        // Reported, an S9 would stand on the strip as power out for the
        // meter linger after every over the radio unkeyed mid-cycle.
        fakeAsync((async) {
          final session = sessionFor('tx500mp-ble');
          keyed(session);
          receive(session, 'SM00015;$rxInfo');
          expect(sink.meterReports, isEmpty);
          session.teardown();
        });
      });

      test('in DIG, where IF goes unanswered, PT still sees the radio keyed and confirms its meter', () {
        // Lab599's reference: IF cannot read the status in Data mode. Watched
        // through IF alone, an FT8 over is never seen, and never metered.
        fakeAsync((async) {
          final session = sessionFor('tx500mp-ble');
          session.startUpdates();
          receive(session, 'FA00014074000;MD6;ID505;');
          async.elapse(const Duration(seconds: 1));
          expect(sink.sent, contains('PT;'), reason: 'asked while receiving, or keying is never seen');

          receive(session, 'PT1;');
          expect(sink.txReports, [true]);
          sink.sent.clear();
          async.elapse(const Duration(seconds: 1));
          expect(sink.sent, containsAllInOrder(['SM0;', 'PT;']));

          receive(session, 'SM00030;PT1;');
          expect(sink.meterReports, [(RadioMeter.powerOut, 10.0)]);
          receive(session, 'SM00015;PT0;');
          expect(sink.meterReports, hasLength(1), reason: 'answered after the unkey, SM is the S-meter');
          expect(sink.txReports, [true, false]);
          session.teardown();
        });
      });

      test('only the TX-500 line\'s placeholder cadence counts its meter reads', () {
        // Every Kenwood shares the driver: counted for all, a TS-590 at 9600
        // shows a slower default than it runs at.
        final kenwood = EquipmentRegistry().typeFor('kenwood-serial')!;
        expect(kenwood.defaultTelemetryIntervalFor(const {'baudRate': 9600}), kTelemetryInterval);
        final tx500 = EquipmentRegistry().typeFor('tx500mp-serial')!;
        expect(
          tx500.defaultTelemetryIntervalFor(const {'baudRate': 9600}),
          telemetryFloor(cycleBytes: kenwoodTxWatchBytes + lab599PttBytes + lab599MeterBytes, baudRate: 9600),
        );
      });

      test('the TS-2000 protocol, which has no VL or PT, is not asked for either', () {
        fakeAsync((async) {
          final session = sessionFor('tx500mp-ble');
          keyed(session);
          sink.sent.clear();
          receive(session, 'ID019;');
          async.elapse(const Duration(seconds: 1));
          expect(sink.sent, contains('SM0;'));
          expect(sink.sent, isNot(contains('VL;')));
          expect(sink.sent, isNot(contains('PT;')));
          session.teardown();
        });
      });
    });
  });
}
