// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's own antenna ports over Kenwood `AN`, written from Kenwood's
// TS-480HX/SAT and TS-590S/SG command references rather than a capture. The
// hazards: a one-port radio on this driver may still answer `AN`, the
// TS-590's answer carries an RX ANT jack that is not a third transmit port,
// and its set carries a DRV field the app must never touch.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, RadioAntennaSink {
  final sent = <String>[];
  final antennas = <RadioAntennas?>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void reportAntennas(RadioAntennas? value) => antennas.add(value);
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

/// Long enough for [kenwoodAntennaReadEvery] idle polls to go by.
const _oneAntennaRead = Duration(seconds: 20);

/// An `IF` packet in a layout whose mode sits at 21, the transmit flag at 20.
String _info({required bool tx}) => 'IF000142550000000+0000${tx ? 1 : 0}2;';

void main() {
  late _FakeSink sink;

  setUp(() => sink = _FakeSink());

  void receive(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));
  int antennaReads() => sink.sent.where((c) => c == 'AN;').length;

  group('the codec', () {
    test('no TS-590 set the app can build touches the DRV jack', () {
      // P3 is DRV out — on the TS-590SG an antenna output by menu. The app
      // offers no such choice, so every set leaves it as the operator has it.
      for (final port in [null, 1, 2]) {
        for (final rx in [null, false, true]) {
          expect(buildTs590SetAntennaCommand(port: port, rxAntenna: rx), endsWith('9;'));
        }
      }
      expect(buildTs590SetAntennaCommand(port: 2), 'AN299;');
      expect(buildTs590SetAntennaCommand(rxAntenna: true), 'AN919;');
    });

    test('each dialect accepts only its own answer', () {
      // The two shapes share the letters; reading one as the other would
      // report a port from a field that means something else.
      expect(parseKenwoodAntennaParams('2'), 2);
      expect(parseKenwoodAntennaParams('210'), isNull);
      expect(parseKenwoodAntennaParams('3'), isNull);
      expect(parseTs590AntennaParams('210'), (port: 2, rxAntenna: true));
      expect(parseTs590AntennaParams('2'), isNull);
      expect(parseTs590AntennaParams('299'), isNull, reason: 'an answer never carries "no change"');
    });
  });

  group('a radio with no pinned dialect', () {
    test('is never asked, and reports nothing', () {
      // A KX2 or a QMX has one port. Asking anyway could draw an `AN1;` and
      // a two-port choice the radio does not have.
      fakeAsync((async) {
        final session = KenwoodSession(sink)..startUpdates();
        receive(session, 'AN1;');
        async.elapse(const Duration(minutes: 1));
        expect(antennaReads(), 0);
        expect(sink.antennas, isEmpty);
        session.setAntenna(tx: 'ANT2');
        expect(sink.sent, isNot(contains(startsWith('AN'))));
        session.stopUpdates();
      });
    });

    test('the catalogue pin is what turns it on, and never on the K4', () {
      // The K4's `AN` picks among three ATU ports in a shape of its own.
      final pinned = {KenwoodDriver.antennaDialectKey: 'ts590'};
      expect((const KenwoodDriver().createSession(sink, pinned) as KenwoodSession).antennaDialect, KenwoodAntennaDialect.ts590);
      expect((const KenwoodDriver().createSession(sink, const {}) as KenwoodSession).antennaDialect, isNull);
      expect((const KenwoodDriver.k4().createSession(sink, pinned) as KenwoodSession).antennaDialect, isNull);
    });
  });

  group('a two-port radio', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, antennaDialect: KenwoodAntennaDialect.twoPort));

    test('one port serves both, so it is not separate', () {
      receive(session, 'AN2;');
      expect(sink.antennas, [
        const RadioAntennas(rxPorts: ['ANT1', 'ANT2'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT2', tx: 'ANT2'),
      ]);
    });

    test('rides the state poll at a fraction of its rate', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(antennaReads(), 1, reason: 'asked at connect');
        async.elapse(const Duration(minutes: 1));
        final polls = sink.sent.where((c) => c == 'FA;').length;
        expect(polls, greaterThan(kenwoodAntennaReadEvery * 2));
        expect(antennaReads(), (polls / kenwoodAntennaReadEvery).ceil());
        session.stopUpdates();
      });
    });

    test('a set names either side and reads back', () {
      receive(session, 'AN1;');
      sink.sent.clear();
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, ['AN2;', 'AN;']);
      sink.sent.clear();
      session.setAntenna(rx: 'ANT1');
      expect(sink.sent, ['AN1;', 'AN;']);
    });

    test('writes nothing before the radio has answered in its shape', () {
      // Until then `AN` is not known to be this command on this radio.
      session.setAntenna(tx: 'ANT2');
      receive(session, 'AN210;');
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, isEmpty);
      expect(sink.antennas, isEmpty);
    });

    test('a new connection writes nothing until the radio answers again', () {
      // The answer that allowed writes was the last connection's; what is on
      // the other end now has not said its `AN` is this one.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, 'AN1;');
        session.stopUpdates();
        session.startUpdates();
        sink.sent.clear();
        session.setAntenna(tx: 'ANT2');
        expect(sink.sent, isEmpty);
        session.stopUpdates();
      });
    });

    test('writes nothing for a port the radio did not offer', () {
      receive(session, 'AN1;');
      sink.sent.clear();
      session.setAntenna(tx: 'ANT3');
      expect(sink.sent, isEmpty);
    });
  });

  group('a TS-590', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, antennaDialect: KenwoodAntennaDialect.ts590, declaredModeOffset: 21));

    test('receives on the transmit port or RX ANT, never the other transmit port', () {
      // RX ANT is a receive-only jack beside ANT1/ANT2, and with it out the
      // radio receives where it transmits. Offering ANT2 for receive while
      // transmitting on ANT1 would offer a pairing the radio cannot make.
      receive(session, 'AN100;');
      expect(sink.antennas.last, const RadioAntennas(rxPorts: ['ANT1', 'RX ANT'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT1', tx: 'ANT1', separate: true));
      receive(session, 'AN211;');
      expect(sink.antennas.last, const RadioAntennas(rxPorts: ['ANT2', 'RX ANT'], txPorts: ['ANT1', 'ANT2'], rx: 'RX ANT', tx: 'ANT2', separate: true));
    });

    test('sets each side alone, the other left as "no change"', () {
      receive(session, 'AN100;');
      sink.sent.clear();
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, ['AN299;', 'AN;']);
      sink.sent.clear();
      session.setAntenna(rx: 'RX ANT');
      expect(sink.sent, ['AN919;', 'AN;']);
      sink.sent.clear();
      // Receiving on the transmit port is RX ANT switched out.
      session.setAntenna(rx: 'ANT1');
      expect(sink.sent, ['AN909;', 'AN;']);
    });

    test('a receive pick is judged against the transmit port it lands on', () {
      receive(session, 'AN110;');
      sink.sent.clear();
      session.setAntenna(rx: 'ANT2', tx: 'ANT2');
      expect(sink.sent, ['AN209;', 'AN;']);
      sink.sent.clear();
      // ANT1 for receive while transmitting on ANT2 is not a setting it has.
      session.setAntenna(rx: 'ANT1', tx: 'ANT2');
      expect(sink.sent, ['AN299;', 'AN;']);
      sink.sent.clear();
      session.setAntenna(rx: 'ANT2');
      expect(sink.sent, isEmpty);
    });

    test('nothing moves while it transmits', () {
      // The relay is the radio's own, but switching one under RF is still
      // what destroys it; a pick made before the over is not honoured after.
      receive(session, 'AN100;');
      receive(session, _info(tx: true));
      sink.sent.clear();
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, isEmpty);
      receive(session, _info(tx: false));
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, ['AN299;', 'AN;']);
    });

    test('is not asked while transmitting', () {
      // A refusal on the air must not count toward giving up on the reads.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, _info(tx: true));
        sink.sent.clear();
        async.elapse(const Duration(minutes: 1));
        expect(antennaReads(), 0);
        session.stopUpdates();
      });
    });
  });

  group('a radio that refuses AN', () {
    late KenwoodSession session;
    setUp(() => session = KenwoodSession(sink, antennaDialect: KenwoodAntennaDialect.twoPort));

    test('reports no ports once, stops asking, and writes nothing', () {
      fakeAsync((async) {
        session.startUpdates();
        receive(session, '?;');
        async.elapse(_oneAntennaRead);
        expect(sink.antennas, isEmpty, reason: 'one refusal is not proof — `?;` names no command');
        receive(session, '?;');
        async.elapse(_oneAntennaRead);
        expect(sink.antennas, [null]);

        sink.sent.clear();
        async.elapse(const Duration(minutes: 2));
        expect(antennaReads(), 0, reason: 'not asked again');
        session.setAntenna(tx: 'ANT2');
        expect(sink.sent, isNot(contains('AN2;')));
        session.stopUpdates();
      });
    });

    test('one that answered and then refuses is written to no more', () {
      // Its one answer no longer says `AN` is this command on it; the ports
      // went away with the null, and so does the write they allowed.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, 'AN1;');
        async.elapse(_oneAntennaRead);
        receive(session, '?;');
        async.elapse(_oneAntennaRead);
        receive(session, '?;');
        async.elapse(_oneAntennaRead);
        expect(sink.antennas.last, isNull);
        sink.sent.clear();
        session.setAntenna(tx: 'ANT2');
        expect(sink.sent, isEmpty);
        session.stopUpdates();
      });
    });

    test('a refusal of some other question does not cost the ports', () {
      // The PC or AC asked in the same poll can draw the `?;`; the AN answer
      // beside it proves which question was refused.
      fakeAsync((async) {
        session.startUpdates();
        for (var i = 0; i < 4; i++) {
          receive(session, '?;AN1;');
          async.elapse(_oneAntennaRead);
        }
        expect(sink.antennas, isNot(contains(null)));
        sink.sent.clear();
        async.elapse(_oneAntennaRead);
        expect(antennaReads(), greaterThan(0), reason: 'still asked');
        session.stopUpdates();
      });
    });

    test('a refusal beside an answered read is no strike against the next', () {
      // The trap: an answered read still judged as unanswered. A stray
      // refusal beside it plus one answer lost to noise would then read as
      // two refusals in a row, and a two-port radio would lose its ports.
      fakeAsync((async) {
        session.startUpdates();
        receive(session, '?;AN1;');
        async.elapse(_oneAntennaRead);
        receive(session, '?;');
        async.elapse(_oneAntennaRead);
        expect(sink.antennas, isNot(contains(null)));
        session.stopUpdates();
      });
    });
  });
}
