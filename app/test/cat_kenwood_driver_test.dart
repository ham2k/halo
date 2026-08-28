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
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';

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

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
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
      expect(parseKenwoodModeParams('02'), isNull,
          reason: 'a two-character answer is Yaesu framing, not a Kenwood mode');
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
      expect(parseKenwoodInfoFrequency('00014250000' '0000' '+00000' '00'), 14250000);
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
      const params = '00014250000' '0000' '+00000' '2';
      expect(kenwoodModeOffsetIn(params, '2'), params.length - 1);
    });

    test('an ambiguous packet teaches nothing rather than guessing', () {
      // Two fields hold the code. Picking either would be a coin flip whose
      // wrong side is silent and permanent.
      const params = '00014250000' '2000' '+00000' '2';
      expect(kenwoodModeOffsetIn(params, '2'), isNull);
    });

    test('a code that appears nowhere teaches nothing', () {
      // The radio moved between the MD answer and this packet, or this is
      // not a layout we understand.
      expect(kenwoodModeOffsetIn('00014250000' '0000', '7'), isNull);
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
      receive('IF00014250000' '0000' '+00000' '2;');
      expect(sink.readings.single.freqKHz, 14250.0);
      expect(sink.readings.single.mode, isNull, reason: 'nothing has confirmed where the mode lives yet');
      expect(session.modeOffset, isNull);
    });

    test('two IF packets agreeing against fresh MD answers settle the offset', () {
      const tail = '0000' '+00000' '2';
      // Each IF has to be matched against its OWN MD answer, or two packets
      // from a single reading would "agree" without proving anything.
      receive('MD2;IF00014250000$tail;');
      expect(session.modeOffset, isNull, reason: 'one sighting is a coincidence');

      receive('MD2;IF00014255000$tail;');
      expect(session.modeOffset, 21);

      // And from here IF alone carries the mode.
      sink.readings.clear();
      receive('IF00014260000' '0000' '+00000' '3;');
      expect(sink.readings.single.freqKHz, 14260.0);
      expect(sink.readings.single.mode, 'CW');
    });

    test('an IF with no MD before it teaches nothing', () {
      // Mutation check: drop the `_pendingModeCode = null` and this passes
      // while the offset gets confirmed by evidence that was never fresh.
      const tail = '0000' '+00000' '2';
      receive('MD2;IF00014250000$tail;');
      receive('IF00014255000$tail;');
      expect(session.modeOffset, isNull,
          reason: 'the second packet was never matched against a reading of its own');
    });

    test('disagreeing sightings restart the count rather than averaging', () {
      // A layout that looks like one offset once and another the next time is
      // not a layout we have understood.
      receive('MD2;IF00014250000' '0000' '+00000' '2;');
      receive('MD3;IF00014250000' '0003' '+00000' '9;');
      expect(session.modeOffset, isNull);
    });

    test('writes go out in the radio\'s own shapes', () {
      session.setFrequency(14250.0);
      session.setMode('CW');
      expect(sink.sent, ['FA00014250000;', 'MD3;']);
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
      known.handleData(Uint8List.fromList(ascii.encode('IF00014250000' '0000' '+00000' '2;')));

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
      wrong.handleData(Uint8List.fromList(ascii.encode('MD2;IF00014250000' '0000' '+00000' '2;')));

      expect(sink.diagnostics, contains('IF mode offset 15 declared, radio says 21'));
    });

    test('a contradicted declaration stops being read, rather than reporting a wrong mode forever', () {
      // The trap the previous test cannot spring: its wrong index holds a
      // character that is no mode at all, so parsing there fails safe. Here
      // index 14 holds '1' — LSB, perfectly valid — while the radio's own
      // answer is USB. Keep reading at the declared index and every later
      // packet reports LSB, silently, for the whole connection.
      final wrong = KenwoodSession(sink, declaredModeOffset: 14);
      wrong.handleData(Uint8List.fromList(ascii.encode('MD2;IF00014250000' '0001' '+00000' '2;')));

      expect(sink.diagnostics, contains('IF mode offset 14 declared, radio says 21'));
      expect(sink.readings.last.mode, 'USB',
          reason: 'the wrong reading is corrected from where the radio says the mode is');

      // A further packet with no fresh MD to lean on: mode now comes from
      // MD; alone, which is slower and right, rather than from an index the
      // radio has already contradicted.
      wrong.handleData(Uint8List.fromList(ascii.encode('IF00014250000' '0001' '+00000' '2;')));
      expect(sink.readings.last.mode, isNull, reason: 'nothing is read at the discredited index');
    });

    test('a contradiction is reported once, and policing then stops', () {
      // The layout does not change mid-session, so re-deciding it on every
      // packet forever would add nothing — and it writes through to the row.
      final known = KenwoodSession(sink, declaredModeOffset: 15);
      for (var i = 0; i < 4; i++) {
        known.handleData(Uint8List.fromList(ascii.encode('MD2;IF00014250000' '0000' '+00000' '2;')));
      }
      expect(sink.diagnostics.where((d) => d!.contains('radio says')), hasLength(1));
    });

    test('a nonsense declared offset is ignored rather than trusted', () {
      // Below the frequency field it could only ever be pointing at a digit.
      final type = EquipmentRegistry().typeFor('kenwood-serial')!;
      final session = type.driver.createSession(sink, {KenwoodDriver.ifModeOffsetKey: 3}) as KenwoodSession;
      expect(session.declaredModeOffset, isNull);
    });

    test('the QMX definition pins the layout the driver would otherwise spend a connection learning', () {
      // The override has to travel through driverConfig() to reach the
      // session: a pinned offset that never arrives costs nothing visible —
      // the radio is simply read the slow way — so nothing else here would
      // notice it going missing.
      final type = EquipmentRegistry().typeFor('qmx-serial')!;
      final session = type.driver.createSession(sink, type.driverConfig(const {})) as KenwoodSession;
      expect(session.declaredModeOffset, 27);
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
}
