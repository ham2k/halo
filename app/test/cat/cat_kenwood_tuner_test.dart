// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Kenwood antenna tuner over `AC`, written from the CAT references
// rather than a capture. Three things here are hazards rather than features:
// a set that starts a tune puts a carrier on the air, a set that rewrites the
// receive-side AT changes a setting the operator owns, and one driver serves
// radios whose `AC` is not a tuner at all.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, TunerSink {
  final sent = <String>[];
  final tuner = <TunerStatus?>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void reportTuner(TunerStatus? status) => tuner.add(status);
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

/// Long enough for [kenwoodTunerReadEvery] idle polls to go by.
const _oneTunerRead = Duration(seconds: 20);

void main() {
  late _FakeSink sink;
  late KenwoodSession session;

  setUp(() {
    sink = _FakeSink();
    session = KenwoodSession(sink);
  });

  void receive(String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));
  int tunerReads() => sink.sent.where((c) => c == 'AC;').length;

  group('the AC codec', () {
    test('no set the app can build starts a tune', () {
      // P3 `1` keys a carrier to find a match. The app reads a tune; a set
      // that carried it would transmit on a button meant only to switch.
      for (final rx in [false, true]) {
        for (final inline in [false, true]) {
          expect(buildKenwoodSetTunerCommand(rxInline: rx, inline: inline), endsWith('0;'));
        }
      }
      expect(buildKenwoodSetTunerCommand(rxInline: true, inline: false), 'AC100;');
      expect(buildKenwoodSetTunerCommand(rxInline: false, inline: true), 'AC010;');
    });

    test('only three 0/1 flags are a tuner answer', () {
      // Anything else is a different command sharing the letters, and must
      // not be read as a tuner state.
      expect(parseKenwoodTunerParams('101'), (rxInline: true, txInline: false, tuning: true));
      expect(parseKenwoodTunerParams('01'), isNull);
      expect(parseKenwoodTunerParams('0100'), isNull);
      expect(parseKenwoodTunerParams('020'), isNull);
    });
  });

  group('reading the tuner', () {
    test('the transmit-side AT decides in line, and a running tune wins', () {
      // RX-AT alone matches nothing the transmitter sees, so `AC100` is
      // bypassed as far as the operator's power and SWR are concerned.
      receive('AC010;AC000;AC100;AC011;AC111;');
      expect(sink.tuner, [TunerStatus.inline, TunerStatus.bypassed, TunerStatus.bypassed, TunerStatus.tuning, TunerStatus.tuning]);
    });

    test('rides the state poll at a fraction of its rate', () {
      // First thing on a connection, then every Nth poll: the tuner moves on
      // a button press, and a read every poll spends the link on an answer
      // that is almost always the last one again.
      fakeAsync((async) {
        session.startUpdates();
        expect(tunerReads(), 1, reason: 'asked at connect');
        async.elapse(const Duration(minutes: 1));
        final polls = sink.sent.where((c) => c == 'FA;').length;
        expect(polls, greaterThan(kenwoodTunerReadEvery * 2));
        expect(tunerReads(), (polls / kenwoodTunerReadEvery).ceil());
        session.stopUpdates();
      });
    });

    test('the K4 is never asked', () {
      // Its command set is its own; `AC` is not documented there as Kenwood's.
      fakeAsync((async) {
        final k4 = KenwoodSession(sink, isK4: true)..startUpdates();
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent, isNot(contains('AC;')));
        k4.stopUpdates();
      });
    });
  });

  group('a radio that refuses AC', () {
    test('reports no tuner once and stops asking', () {
      // A QMX or an Elecraft on this driver has no `AC`. Asking forever
      // spends the link on a question with a known answer.
      fakeAsync((async) {
        session.startUpdates();
        receive('?;');
        async.elapse(_oneTunerRead);
        expect(sink.tuner, isEmpty, reason: 'one refusal is not proof — see the next test');
        receive('?;');
        async.elapse(_oneTunerRead);
        expect(sink.tuner, [null]);

        sink.sent.clear();
        async.elapse(const Duration(minutes: 2));
        expect(tunerReads(), 0, reason: 'not asked again');
        expect(sink.tuner, [null], reason: 'said once');
        session.stopUpdates();
      });
    });

    test('a refusal heard on the air is no strike', () {
      // The K3 line answers `?;` to commands it will not take while
      // transmitting, which says nothing about whether it has them. Counted,
      // a long over would cost the tuner readout for the connection.
      fakeAsync((async) {
        session.startUpdates();
        const rx = '0000+00000', tx = '0000+00001';
        // Two packets settle where the transmit flag sits; the third keys.
        receive('MD2;IF00014250000${rx}2;');
        receive('MD2;IF00014255000${rx}2;');
        receive('IF00014255000${tx}2;');
        for (var i = 0; i < 3; i++) {
          receive('?;');
          async.elapse(_oneTunerRead);
        }
        expect(sink.tuner, isEmpty);
        session.stopUpdates();
      });
    });

    test('a refusal of some other question does not cost the tuner', () {
      // `?;` names no command. The PC asked in the same poll can draw one on
      // a radio that does have a tuner; the AC answer after it is what proves
      // which question was refused.
      fakeAsync((async) {
        session.startUpdates();
        for (var i = 0; i < 4; i++) {
          receive('?;AC010;');
          async.elapse(_oneTunerRead);
        }
        expect(sink.tuner, isNot(contains(null)));
        sink.sent.clear();
        async.elapse(_oneTunerRead);
        expect(tunerReads(), greaterThan(0), reason: 'still asked');
        session.stopUpdates();
      });
    });

    test('a refusal beside an answered read is no strike against the next', () {
      // The trap: counting every `?;` rather than only one beside an
      // unanswered `AC;`. Then a stray refusal on an answered read plus one
      // answer lost to noise reads as two refusals in a row, and a radio
      // with a tuner loses it for the connection.
      fakeAsync((async) {
        session.startUpdates();
        receive('?;AC010;');
        async.elapse(_oneTunerRead);
        receive('?;');
        async.elapse(_oneTunerRead);
        expect(sink.tuner, isNot(contains(null)));
        session.stopUpdates();
      });
    });
  });

  group('switching the tuner', () {
    test('in line and bypass keep the operator\'s RX-AT, never tune, and read back', () {
      // P1 is the receive-side AT the operator set on the front panel; the
      // app's button is about transmit only.
      receive('AC110;');
      sink.sent.clear();
      session.setTuner(inline: false);
      expect(sink.sent, ['AC100;', 'AC;']);

      receive('AC000;');
      sink.sent.clear();
      session.setTuner(inline: true);
      expect(sink.sent, ['AC010;', 'AC;']);
    });

    test('bypassing mid-tune still never sends a tune', () {
      receive('AC011;');
      sink.sent.clear();
      session.setTuner(inline: true);
      expect(sink.sent.first, 'AC010;');
    });

    test('writes nothing to a radio that never answered AC', () {
      // One driver serves Kenwood, Elecraft and QRP rigs. Until the radio has
      // answered in Kenwood's shape, `AC` is not known to be a tuner on it —
      // and its RX-AT, which the write must carry back, is not known either.
      session.setTuner(inline: true);
      expect(sink.sent, isEmpty);
    });

    test('writes nothing once the radio has refused AC', () {
      fakeAsync((async) {
        session.startUpdates();
        receive('?;');
        async.elapse(_oneTunerRead);
        receive('?;');
        async.elapse(_oneTunerRead);
        sink.sent.clear();
        session.setTuner(inline: true);
        expect(sink.sent, isEmpty);
        session.stopUpdates();
      });
    });
  });
}
