// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Yaesu radio's own antenna ports (`AN`), with no radio and no serial
// port. Pinned against the FTDX101MP/FTDX101D CAT Operation Reference Manual
// and the line's other CAT manuals, which have no `AN` — not against a
// radio: none of this has met one.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';

class _Sink implements EquipmentSink, RadioAntennaSink {
  final sent = <String>[];
  final antennas = <RadioAntennas?>[];

  @override
  void reportAntennas(RadioAntennas? value) => antennas.add(value);

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

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

extension on Ft891Session {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

const _ftdx101d = '0681';
const _ftdx101mp = '0682';

const _ports = ['ANT1', 'ANT2'];

RadioAntennas _on(String? port) => RadioAntennas(rxPorts: _ports, txPorts: _ports, rx: port, tx: port);

void main() {
  group('the codec', () {
    test('reads and sets the MAIN band, never the SUB', () {
      expect(buildReadAntennaCommand(), 'AN0;');
      expect(buildSetAntennaCommand(2), 'AN02;');
    });

    test('an answer is read only in the manual\'s layout', () {
      expect(parseAntennaParams('010'), 1);
      expect(parseAntennaParams('020'), 2);
      expect(parseAntennaParams('030'), 3);
      // The SUB band's antenna is not the one the VFO here is on.
      expect(parseAntennaParams('110'), isNull);
      // A frame that lost or gained a digit is not a port.
      expect(parseAntennaParams('01'), isNull);
      expect(parseAntennaParams('0100'), isNull);
      expect(parseAntennaParams('040'), isNull);
    });

    test('only the FTDX101 has ports to choose from', () {
      expect(yaesuAntennaPortsById[_ftdx101d], _ports);
      expect(yaesuAntennaPortsById[_ftdx101mp], _ports);
      // FT-891, FT-991, FT-991A, FTDX10, FT-710: no `AN` in their manuals.
      // FT-450's two IDs: one port. FTX-1: no manual here to name its ports.
      // A port list guessed for any of them is a choice the radio refuses
      // or does not have.
      for (final id in ['0650', '0570', '0670', '0761', '0800', '0241', '0244', '0840', '9999']) {
        expect(yaesuAntennaPortsById[id], isNull, reason: id);
      }
    });
  });

  group('the session', () {
    late _Sink sink;
    late Ft891Session session;

    setUp(() {
      sink = _Sink();
      session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000});
    });

    List<String> antennaCommands() => sink.sent.where((c) => c.startsWith('AN')).toList();

    test('asks once the radio says it is an FTDX101, and reports its answer', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(antennaCommands(), isEmpty, reason: 'not before the radio has said what it is');
        session.feed('ID$_ftdx101mp;');
        expect(antennaCommands(), ['AN0;']);
        session.feed('AN020;');
        expect(sink.antennas, [_on('ANT2')]);
        expect(sink.antennas.single!.separate, isFalse, reason: 'one port serves receive and transmit');
        session.teardown();
      });
    });

    test('a radio without ports is never asked, and a set sends nothing', () {
      for (final id in ['0650', '0570', '0761', '0800', '0241']) {
        fakeAsync((async) {
          final sink = _Sink();
          final session = Ft891Session(sink, config: const {telemetryIntervalConfigKey: 600000});
          session.startUpdates();
          session.feed('ID$id;');
          async.elapse(const Duration(minutes: 1));
          session.setAntenna(rx: 'ANT2', tx: 'ANT2');
          // An `AN` answer on the line is another program's question.
          session.feed('AN020;');
          expect(sink.sent.where((c) => c.startsWith('AN')), isEmpty, reason: id);
          expect(sink.antennas, isEmpty, reason: id);
          session.teardown();
        });
      }
    });

    test('an answer before the radio has identified itself is not reported', () {
      // Which ports exist is the model's; without it, `AN02` names nothing.
      session.feed('AN020;');
      expect(sink.antennas, isEmpty);
    });

    test('a later ID does not change the radio under the connection', () {
      session.feed('ID0650;');
      session.feed('ID$_ftdx101d;');
      expect(antennaCommands(), isEmpty);
    });

    test('ANT3 is reported as unknown, never as a port both ways', () {
      // ANT3's role — transmit, receive-only, or receive paired with ANT1
      // or ANT2 — is a menu this session does not read; naming it as the
      // transmit antenna could be wrong.
      session.feed('ID$_ftdx101d;AN010;AN030;');
      expect(sink.antennas, [_on('ANT1'), _on(null)]);
    });

    test('an answer pushed by Auto-Information is reported', () {
      session.feed('ID$_ftdx101d;AN010;');
      session.feed('AN020;');
      expect(sink.antennas.last, _on('ANT2'));
    });

    test('the same port reported again says nothing new', () {
      session.feed('ID$_ftdx101d;AN010;AN010;');
      expect(sink.antennas, [_on('ANT1')]);
    });

    test('the SUB band\'s antenna is not reported as the MAIN band\'s', () {
      session.feed('ID$_ftdx101d;AN010;AN120;');
      expect(sink.antennas, [_on('ANT1')]);
    });

    test('a set selects the port by name and reads it back', () {
      session.feed('ID$_ftdx101d;AN010;');
      sink.sent.clear();
      session.setAntenna(rx: 'ANT2', tx: 'ANT2');
      expect(sink.sent, ['AN02;', 'AN0;']);
      sink.sent.clear();
      session.setAntenna(tx: 'ANT1');
      expect(sink.sent, ['AN01;', 'AN0;'], reason: 'either name picks the one port');
    });

    test('a set naming a port the radio has not got sends nothing', () {
      session.feed('ID$_ftdx101d;AN010;');
      sink.sent.clear();
      session.setAntenna(rx: 'ANT3');
      session.setAntenna(rx: 'RX A');
      session.setAntenna();
      expect(sink.sent, isEmpty);
    });

    test('is read far less often than the frequency, but still read', () {
      fakeAsync((async) {
        session.startUpdates();
        session.feed('ID$_ftdx101d;AN010;');
        sink.sent.clear();
        async.elapse(const Duration(minutes: 2));
        final fa = sink.sent.where((c) => c == 'FA;').length;
        final an = sink.sent.where((c) => c == 'AN0;').length;
        expect(an, greaterThan(1), reason: 'a port changed from the front panel with AI off must still be seen');
        expect(an, lessThanOrEqualTo(fa ~/ 4), reason: 'not riding on every state poll');
        session.teardown();
      });
    });

    test('a radio that refuses AN twice is reported as having no ports, and is not asked again', () {
      fakeAsync((async) {
        session.startUpdates();
        session.feed('ID$_ftdx101d;AN010;');
        session.setAntenna(rx: 'ANT2');
        session.feed('?;');
        async.elapse(const Duration(minutes: 1));
        expect(sink.antennas, [_on('ANT1')], reason: 'one refusal is not yet proof: `?;` names no command');
        expect(antennaCommands().last, 'AN0;');
        session.feed('?;');
        async.elapse(const Duration(minutes: 1));
        expect(sink.antennas.last, isNull);

        sink.sent.clear();
        async.elapse(const Duration(minutes: 2));
        session.setAntenna(rx: 'ANT2');
        session.feed('AN020;');
        expect(antennaCommands(), isEmpty);
        expect(sink.antennas.last, isNull, reason: 'after giving up, an `AN` on the line is another program\'s');
        session.teardown();
      });
    });

    test('a refusal beside an AN answer is not AN refused', () {
      fakeAsync((async) {
        session.startUpdates();
        session.feed('ID$_ftdx101d;');
        for (var i = 0; i < 4; i++) {
          session.feed('?;AN010;');
          async.elapse(const Duration(minutes: 1));
        }
        sink.sent.clear();
        async.elapse(const Duration(minutes: 1));
        expect(antennaCommands(), contains('AN0;'));
        session.teardown();
      });
    });
  });
}
