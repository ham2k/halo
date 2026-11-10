// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// AF gain, RF gain and mute on the wire (driver.dart's ReceiveLevelSession):
// what each family sends for a level, and which radios are sent nothing
// because their range is their own.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _Sink implements EquipmentSink {
  final sent = <String>[];
  @override
  void send(List<int> bytes) => sent.add(latin1.decode(bytes));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ReceiveLevelSession _session(String typeKey, _Sink sink, [Map<String, dynamic> config = const {}]) {
  final type = EquipmentRegistry().typeFor(typeKey)!;
  return type.driver.createSession(sink, type.driverConfig({...type.defaultConfig, ...config})) as ReceiveLevelSession;
}

void main() {
  test('a level lands on the radio\'s own scale, top included', () {
    expect(receiveLevelOn(1, 255), 255);
    expect(receiveLevelOn(0.5, 255), 128);
    expect(receiveLevelOn(-0.2, 100), 0);
  });

  test('Icom: 0x14 01 and 0x14 02, BCD 0000–0255', () {
    expect(buildSetLevelFrame(to: 0xA4, level: civLevelAfGain, value: 255), [0xFE, 0xFE, 0xA4, 0xE0, 0x14, 0x01, 0x02, 0x55, 0xFD]);
    expect(buildSetLevelFrame(to: 0xA4, level: civLevelRfGain, value: 128), [0xFE, 0xFE, 0xA4, 0xE0, 0x14, 0x02, 0x01, 0x28, 0xFD]);
  });

  test('Yaesu: the main receiver\'s AG0 and RG0, 000–255', () {
    // The digit after the command names the receiver: 0 is the main one,
    // which is what the app's VFO is.
    expect(buildSetAfGainCommand(255), 'AG0255;');
    expect(buildSetRfGainCommand(7), 'RG0007;');
  });

  group('Kenwood', () {
    test('the TS-590SG and TS-480s are sent AG0 and RG', () {
      for (final key in ['ts590sg-serial', 'ts480-serial', 'ts480hx-serial']) {
        final sink = _Sink();
        final session = _session(key, sink);
        expect(session.receiveLevels.af && session.receiveLevels.rf, isTrue, reason: key);
        session
          ..setAfGain(1)
          ..setRfGain(0.5);
        expect(sink.sent, ['AG0255;', 'RG128;'], reason: key);
      }
    });

    test('an Elecraft, a QMX or a generic entry is sent nothing', () {
      // Their AG and RG take ranges of their own, so a TS-590's 255 would be
      // out of range at best and full volume at worst.
      for (final key in ['kx3-serial', 'kx2-serial', 'elecraft-serial', 'qmx-serial', 'kenwood-serial']) {
        final sink = _Sink();
        final session = _session(key, sink);
        expect(session.receiveLevels.af || session.receiveLevels.rf, isFalse, reason: key);
        session
          ..setAfGain(1)
          ..setRfGain(1);
        expect(sink.sent, isEmpty, reason: key);
      }
    });
  });

  test('rigctld: Hamlib\'s 0…1 levels and its MUTE function', () {
    final sink = _Sink();
    _session('rigctld-tcp', sink, {'host': 'localhost'})
      ..setAfGain(0.25)
      ..setRfGain(1)
      ..setMute(true);
    expect(sink.sent, ['L AF 0.250\n', 'L RF 1.000\n', 'U MUTE 1\n']);
  });

  test('flrig: volume and RF gain on 0–100, and no mute', () {
    final sink = _Sink();
    final session = _session('flrig-tcp', sink, {'host': 'localhost'});
    expect(session.receiveLevels.mute, isFalse);
    session.setAfGain(0.5);
    expect(sink.sent.single, allOf(contains('rig.set_volume'), contains('<i4>50</i4>')));
  });

  test('Flex: the slice\'s audio level and mute, and no RF gain', () {
    final sink = _Sink();
    final session = _session('flexradio-tcp', sink, {'host': 'localhost'});
    expect(session.receiveLevels, (af: true, rf: false, mute: true));
    session
      ..setAfGain(0.4)
      ..setMute(true);
    expect(sink.sent.join(), allOf(contains('audio_level=40'), contains('audio_mute=1')));
  });
}
