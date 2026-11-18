// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Elecraft K3 and K3S on the Kenwood driver, written from Elecraft's
// programmer's reference (rev. G5) rather than a capture: its M1-M4 voice
// keyer, the option modules that decide which of its keyer, antenna ports and
// ATU exist, the K31 command mode its ATU and DATA submode reads need, and
// its own transmit meters.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/k3_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _Sink implements EquipmentSink, RadioAntennaSink, TunerSink {
  final sent = <String>[];
  final meters = <(RadioMeter, num)>[];
  final activities = <VoiceActivity?>[];
  final antennas = <RadioAntennas?>[];
  final diagnostics = <String?>[];
  final tuners = <TunerStatus?>[];
  final modes = <String>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void report(VfoReading reading) {
    if (reading.mode case final mode?) modes.add(mode);
  }

  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) => meters.add((meter, value));
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) => activities.add(activity);
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
  @override
  void reportAntennas(RadioAntennas? antennas) => this.antennas.add(antennas);
  @override
  void reportTuner(TunerStatus? status) => tuners.add(status);
}

/// A K3 `DS` answer: eight display bytes, the basic icon byte, then the K31
/// icon byte, with the ATU's in-line flag at bit 4.
List<int> _display({required bool atu}) => [...ascii.encode('DS 1406000'), 0x80, atu ? 0x90 : 0x80, ...ascii.encode(';')];

/// A K3 `IF` answer: the transmit flag at 26, the mode at 27, and under K31
/// the DATA submode at 32.
String _info({required bool tx, String mode = '3', String submode = '0'}) => 'IF00014060000     +000000 00${tx ? 1 : 0}${mode}0000${submode}1 ;';

void main() {
  late _Sink sink;
  setUp(() => sink = _Sink());

  KenwoodSession sessionFor(String typeKey) {
    final type = EquipmentRegistry().typeFor(typeKey)!;
    // Through driverConfig(): an override that never reaches the session
    // costs nothing visible — the radio just keys nothing.
    return type.driver.createSession(sink, type.driverConfig(const {})) as KenwoodSession;
  }

  void receive(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));
  void receiveBytes(KenwoodSession session, List<int> bytes) => session.handleData(Uint8List.fromList(bytes));

  group('the K3 and K3S entries', () {
    test('pin the KX3\'s IF layout, Elecraft\'s KY, and the M1-M4 voice keyer', () {
      for (final key in ['k3-serial', 'k3s-serial']) {
        final type = EquipmentRegistry().typeFor(key)!;
        final config = type.driverConfig(const {});
        final session = sessionFor(key);
        expect(session.declaredModeOffset, 27, reason: key);
        expect(session.cwDialect, KenwoodCwDialect.elecraft, reason: key);
        expect(session.voiceDialect, KenwoodVoiceDialect.k3, reason: key);
        expect(session.voiceMemoryCount, 4, reason: key);
        expect(session.antennaDialect, KenwoodAntennaDialect.k3, reason: key);
        expect(session.k3, isTrue, reason: key);
        expect(type.driver.canKeyCwWith(config), isTrue, reason: key);
        expect(type.driver.telemetryMetersWith(config), {RadioMeter.powerOut, RadioMeter.swr, RadioMeter.alc}, reason: key);
      }
    });

    test('the KX3 and the generic Elecraft are not K3s', () {
      // `OM`, `BG` and `SW` mean something else, or nothing, on the rest of
      // the line: a KX answers OM in another layout.
      for (final key in ['kx3-serial', 'elecraft-serial']) {
        final session = sessionFor(key)..startUpdates();
        expect(session.k3, isFalse, reason: key);
        expect(sink.sent, isNot(contains('OM;')), reason: key);
        // The KX3 takes K3 commands: a K31 sent to it changes the radio.
        expect(sink.sent, isNot(contains('K3;')), reason: key);
        session.teardown();
      }
    });
  });

  group('the option modules', () {
    test('OM is asked until the radio answers, then not again', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        expect(sink.sent, contains('OM;'));
        receive(session, 'OM AP-SD-----;');
        sink.sent.clear();
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent, isNot(contains('OM;')));
        session.teardown();
      });
    });

    test('a K3 without a KDVR3 has no voice memories once OM says so', () {
      // Its M1-M4 would then play CW messages, or nothing, while the pane
      // showed a voice memory going out.
      final session = sessionFor('k3-serial');
      receive(session, 'OM AP-S------;');
      expect(session.voiceMemoryCount, 0);
      expect(sink.diagnostics.last, contains('no KDVR3'));

      final withDvr = sessionFor('k3s-serial');
      receive(withDvr, 'OM AP-SD----R;');
      expect(withDvr.voiceMemoryCount, 4);
      expect(sink.diagnostics.last, startsWith('K3S'));
    });

    test('a KX\'s OM layout is not read as a K3\'s', () {
      // Its letters sit at other positions: read as a K3's, its `F` would be
      // taken for the KDVR3's slot and its `X` for the KXV3's.
      expect(parseK3ModulesParams(' APF---TBXI02'), isNull);
      expect(parseK3ModulesParams(' AP-SD----R--'), (atu: true, rxAntenna: false, voiceRecorder: true, k3s: true));

      // Unread, OM leaves every module unknown for the connection: said once.
      final session = sessionFor('k3-serial');
      receive(session, 'OM APF---TBXI02;OM APF---TBXI02;');
      expect(sink.diagnostics.where((d) => d?.contains('not understood') ?? false), hasLength(1));
    });
  });

  group('the voice keyer', () {
    test('M1-M4 are taps of their own keys, RX stops, TQ is the question', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial');
        for (final (n, tap) in [(1, 'SWT21;'), (2, 'SWT31;'), (3, 'SWT35;'), (4, 'SWT39;')]) {
          sink.sent.clear();
          session.playVoiceMemory(n);
          expect(sink.sent.first, tap, reason: 'M$n');
          session.stopVoice();
          expect(sink.sent.last, 'RX;', reason: 'the reference\'s stop for message play');
        }
        session.playVoiceMemory(2);
        async.elapse(const Duration(seconds: 1));
        expect(sink.sent.last, 'TQ;');
        receive(session, 'TQ1;');
        expect(sink.activities.last, const VoiceActivity(memory: 2));
        receive(session, 'TQ0;');
        expect(sink.activities.last, isNull);
      });
    });
  });

  group('the transmit meters', () {
    test('keyed, TM BG SW are asked ahead of the IF that confirms them; receiving, none', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, _info(tx: false));
        sink.sent.clear();
        async.elapse(const Duration(seconds: 2));
        expect(sink.sent, isNot(contains('BG;')));

        receive(session, _info(tx: true));
        sink.sent.clear();
        async.elapse(const Duration(seconds: 1));
        expect(sink.sent, containsAllInOrder(['TM;', 'BG;', 'SW;', 'IF;']));
        // `TM1;` would flip the operator's own METER switch.
        expect(sink.sent.where((c) => c.startsWith('TM')), everyElement('TM;'));
        session.teardown();
      });
    });

    test('the power bars are watts or tens of watts, as the set power puts the scale', () {
      // The panel's scale changes at 13 W: one bar per watt below, ten above.
      // Reading 5 bars as 5 W at 100 W set would report a tenth of the power.
      final session = sessionFor('k3-serial');
      receive(session, '${_info(tx: true)}PC100;TM0;BG05T;SW015;${_info(tx: true)}');
      expect(sink.meters, [(RadioMeter.powerOut, 50), (RadioMeter.swr, 1.5)]);

      sink.meters.clear();
      receive(session, 'PC010;TM0;BG05T;${_info(tx: true)}');
      expect(sink.meters, [(RadioMeter.powerOut, 5)]);
    });

    test('under TM1 the bars are ALC, out of seven', () {
      final session = sessionFor('k3-serial');
      receive(session, '${_info(tx: true)}TM1;BG07T;${_info(tx: true)}');
      expect(sink.meters, [(RadioMeter.alc, 1.0)]);
    });

    test('a bargraph that says it is receiving, or read on an unknown scale, is dropped', () {
      // BG across the unkey is the S-meter; before TM answers, the bars could
      // be either meter.
      final session = sessionFor('k3-serial');
      receive(session, '${_info(tx: true)}BG05T;TM0;BG09R;${_info(tx: true)}');
      expect(sink.meters, isEmpty);
      // Before PC answers, 5 bars could be 5 W or 50 W.
      receive(session, 'BG05T;${_info(tx: true)}');
      expect(sink.meters, isEmpty);
    });

    test('SW answered while receiving is the last over\'s, and not reported', () {
      final session = sessionFor('k3-serial');
      receive(session, '${_info(tx: false)}SW030;${_info(tx: false)}');
      expect(sink.meters, isEmpty);
    });
  });

  group('the antenna ports', () {
    void polledAntennas(KenwoodSession session, FakeAsync async) {
      for (var i = 0; i < kenwoodAntennaReadEvery + 1; i++) {
        async.elapse(session.pollInterval);
      }
    }

    test('nothing is read until OM says which jacks exist, and nothing with neither option', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        polledAntennas(session, async);
        expect(sink.sent, isNot(contains('AN;')));
        receive(session, 'OM -P-S------;');
        polledAntennas(session, async);
        expect(sink.sent, isNot(contains('AN;')), reason: 'one jack is no choice');
        session.teardown();
      });
    });

    test('with the ATU and KXV3: ANT1/ANT2 for transmit, the transmit port or RX ANT for receive', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, 'OM APXS------;');
        polledAntennas(session, async);
        expect(sink.sent, containsAllInOrder(['AR;', 'AN;']));
        receive(session, 'AR1;AN2;');
        expect(sink.antennas.last, const RadioAntennas(rxPorts: ['ANT2', 'RX ANT'], txPorts: ['ANT1', 'ANT2'], rx: 'RX ANT', tx: 'ANT2', separate: true));

        sink.sent.clear();
        session.setAntenna(rx: 'ANT2');
        expect(sink.sent.take(1), ['AR0;'], reason: 'receiving on the transmit port switches RX ANT out');
        sink.sent.clear();
        session.setAntenna(tx: 'ANT1', rx: 'RX ANT');
        expect(sink.sent.take(2), ['AN1;', 'AR1;']);
        sink.sent.clear();
        session.setAntenna(rx: 'ANT1');
        expect(sink.sent, isEmpty, reason: 'it receives on ANT1 only while transmitting there');
        session.teardown();
      });
    });

    test('with the ATU alone: two ports, one for both', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, 'OM AP-S------;');
        polledAntennas(session, async);
        expect(sink.sent, isNot(contains('AR;')), reason: 'no RX ANT without the KXV3');
        receive(session, 'AN1;');
        expect(sink.antennas.last, const RadioAntennas(rxPorts: ['ANT1', 'ANT2'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT1', tx: 'ANT1'));
        session.teardown();
      });
    });
  });

  group('the command mode', () {
    test('K31 is switched on only if the radio was in K30, and switched back off on the way out', () {
      // K31 is the radio's setting: another program connecting after HaLo
      // finds it as HaLo left it.
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        expect(sink.sent, contains('K3;'));
        expect(sink.sent, isNot(contains('K31;')), reason: 'not before the radio says what it was');
        receive(session, 'K30;');
        expect(sink.sent.last, 'K31;');
        receive(session, 'K31;');
        sink.sent.clear();
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent, isNot(contains('K3;')), reason: 'asked until answered, then not again');
        session.teardown();
        expect(sink.sent, contains('K30;'));
      });
    });

    test('a radio already in K31 is left in it', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, 'K31;');
        session.teardown();
        expect(sink.sent.where((c) => c.startsWith('K3') && c != 'K3;'), isEmpty);
      });
    });
  });

  group('the ATU', () {
    void polledTuner(KenwoodSession session, FakeAsync async) {
      for (var i = 0; i < kenwoodTunerReadEvery + 1; i++) {
        async.elapse(session.pollInterval);
      }
    }

    test('is read from DS once OM names the KAT3 and K31 is on, never with AC', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, 'OM AP-S------;');
        receive(session, 'K30;');
        polledTuner(session, async);
        expect(sink.sent, isNot(contains('DS;')), reason: 'under K30 the ATU flag is always clear: it would read as bypassed');
        receive(session, 'K31;');
        polledTuner(session, async);
        expect(sink.sent, contains('DS;'));
        expect(sink.sent, isNot(contains('AC;')), reason: 'the K3 has no AC');
        receiveBytes(session, _display(atu: true));
        expect(sink.tuners.last, TunerStatus.inline);
        receiveBytes(session, _display(atu: false));
        expect(sink.tuners.last, TunerStatus.bypassed);
        session.teardown();
      });
    });

    test('nothing is read without the KAT3', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, 'OM -P-S------;K31;');
        polledTuner(session, async);
        expect(sink.sent, isNot(contains('DS;')));
        session.teardown();
      });
    });

    test('the ATU key is held only to change it, once per change', () {
      // The key toggles: a hold for a state the radio is already in, or a
      // second hold before the read-back, would switch it the wrong way.
      final session = sessionFor('k3-serial');
      receive(session, 'OM AP-S------;K31;');
      receiveBytes(session, _display(atu: true));
      session.setTuner(inline: true);
      expect(sink.sent, isNot(contains('SWH19;')));
      session.setTuner(inline: false);
      session.setTuner(inline: false);
      expect(sink.sent.where((c) => c == 'SWH19;'), hasLength(1));
      expect(sink.sent.last, 'DS;');
      expect(session.canStartTune, isFalse);

      // Escape's stopTune would otherwise hold the key into a bypassed ATU.
      receiveBytes(session, _display(atu: false));
      sink.sent.clear();
      session.stopTune();
      expect(sink.sent, isEmpty);
    });
  });

  group('DATA', () {
    test('under K31 the IF names the DATA submode; before it, a K3 in DATA reports no mode', () {
      // Under K30 the submode position is a fixed 0, which would read as
      // DATA A whatever the radio is in; and RTTY reported meanwhile would
      // replace an FT8 the operator set, which the DATA-USB after it would
      // not bring back.
      final session = sessionFor('k3-serial');
      receive(session, 'K30;${_info(tx: false, mode: '6')}MD6;${_info(tx: false, mode: '2')}');
      expect(sink.modes, ['USB'], reason: 'a mode other than DATA is reported as ever');
      receive(session, 'K31;');
      for (final (mode, submode, name) in [
        ('6', '0', 'DATA-USB'),
        ('9', '0', 'DATA-LSB'),
        ('6', '1', 'RTTY'),
        ('6', '2', 'RTTY'),
        ('9', '2', 'RTTY-R'),
        ('6', '3', 'PSK'),
      ]) {
        receive(session, _info(tx: false, mode: mode, submode: submode));
        expect(sink.modes.last, name, reason: 'MD$mode DT$submode');
      }
    });

    test('an MD6 under K31 asks for the IF rather than reporting RTTY', () {
      // MD carries no submode: reported, it would flash RTTY on every poll
      // until the IF behind it put DATA back.
      final session = sessionFor('k3-serial');
      receive(session, 'K31;${_info(tx: false, mode: '6')}');
      sink.modes.clear();
      sink.sent.clear();
      receive(session, 'MD6;');
      expect(sink.modes, isEmpty);
      expect(sink.sent, ['IF;']);
    });

    test('a DATA mode is set as MD and DT, and DATA-FM is not offered', () {
      // FT8 sent as USB would leave the K3 out of DATA A, with its voice
      // processing on the data audio.
      final session = sessionFor('k3-serial');
      for (final (mode, sent) in [('FT8', 'MD6;DT0;'), ('DATA-LSB', 'MD9;DT0;'), ('RTTY', 'MD6;DT2;'), ('PSK', 'MD6;DT3;'), ('USB', 'MD2;')]) {
        sink.sent.clear();
        session.setMode(mode);
        expect(sink.sent.first, sent, reason: mode);
      }
      final type = EquipmentRegistry().typeFor('k3-serial')!;
      expect(type.driver.settableModes(type.driverConfig(const {})), allOf(contains('PSK'), isNot(contains('DATA-FM'))));
    });
  });

  group('CW VOX', () {
    test('is read in CW only, and VX0 there makes the CW sidetone only', () {
      fakeAsync((async) {
        final session = sessionFor('k3-serial')..startUpdates();
        receive(session, 'MD2;');
        sink.sent.clear();
        async.elapse(session.pollInterval);
        expect(sink.sent, isNot(contains('VX;')), reason: 'in USB, VX answers for the voice VOX');
        receive(session, 'MD3;');
        sink.sent.clear();
        async.elapse(session.pollInterval);
        expect(sink.sent, contains('VX;'));
        // Answered in order: a VX asked ahead of the poll's MD would be
        // judged against the last poll's mode, and a switch out of CW since
        // would take the voice VOX for the CW one.
        expect(sink.sent.indexOf('VX;'), greaterThan(sink.sent.indexOf('MD;')));
        expect(session.cwSidetoneOnly, isNull, reason: 'unread is not off');
        receive(session, 'VX0;');
        expect(session.cwSidetoneOnly, isNotNull);
        receive(session, 'VX1;');
        expect(session.cwSidetoneOnly, isNull);
        session.teardown();
      });
    });

    test('a VX answered outside CW is not taken for the CW VOX', () {
      final session = sessionFor('k3-serial')..startUpdates();
      receive(session, 'MD3;VX1;');
      expect(session.cwSidetoneOnly, isNull);
      // A poll's VX, asked in CW and answered after the switch to USB: the
      // voice VOX, off by habit, which says nothing about CW.
      receive(session, 'MD2;VX0;');
      expect(session.cwSidetoneOnly, isNull, reason: 'outside CW there is no CW to hold off the air');
      receive(session, 'MD3;');
      expect(session.cwSidetoneOnly, isNull, reason: 'CW VOX is still on');
      session.teardown();
    });

    test('the KX3 and the generic Elecraft never ask', () {
      for (final key in ['kx3-serial', 'elecraft-serial']) {
        fakeAsync((async) {
          final session = sessionFor(key)..startUpdates();
          receive(session, 'MD3;');
          async.elapse(session.pollInterval);
          expect(sink.sent, isNot(contains('VX;')), reason: key);
          expect(session.cwSidetoneOnly, isNull, reason: key);
          session.teardown();
        });
      }
    });
  });
}
