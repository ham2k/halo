// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Icom CI-V driver and its serial equipment type, with no radio.
//
// Most of what's asserted here is bus discipline. CI-V is a shared bus: the
// radio echoes what you send it, other controllers may be talking on the
// same wire, and a wrong address produces silence rather than an error.
// app-polo's driver checked none of that.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

class _FakeSink implements EquipmentSink {
  final sent = <List<int>>[];
  final readings = <VfoReading>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(bytes);

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
}

void main() {
  const ic705 = 0xA4;
  const us = civDefaultControllerAddress;

  late _FakeSink sink;
  late IcomCivSession session;

  setUp(() {
    sink = _FakeSink();
    session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us);
  });

  void feed(List<int> bytes) => session.handleData(Uint8List.fromList(bytes));

  group('reading the radio', () {
    test('an answer to our read becomes a VFO reading in kHz', () {
      feed([0xFE, 0xFE, us, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, [const VfoReading(freqKHz: 14074)]);
    });

    test('an unsolicited transceive announcement is read the same way', () {
      // Broadcast, command 0x00 — what the radio sends on its own when
      // transceive is on and the operator turns the dial.
      feed([0xFE, 0xFE, 0x00, ic705, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, [const VfoReading(freqKHz: 14074)]);
    });

    group('expectedUpdateInterval', () {
      // Nothing in CI-V asks whether transceive is on, so the driver has to
      // notice. Getting it wrong is invisible either way — readings arrive —
      // but Smart VFO Snap adds this to its settle delay, so claiming the
      // 5s poll on a radio that announces in milliseconds makes the feature
      // feel broken, and claiming none when the poll IS the cadence settles
      // a snap in the silence between polls.
      test('claims the poll rate until the radio proves it announces', () {
        expect(session.expectedUpdateInterval, const Duration(seconds: 5));
        // An answer to OUR read (0x03) proves nothing about transceive.
        feed([0xFE, 0xFE, us, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(session.expectedUpdateInterval, const Duration(seconds: 5));
      });

      test('stops claiming one as soon as the radio announces on its own', () {
        feed([0xFE, 0xFE, 0x00, ic705, 0x00, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(session.expectedUpdateInterval, isNull);
        // Transceive is a menu setting, not something that lapses between
        // frames — a later poll answer must not take the claim back.
        feed([0xFE, 0xFE, us, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
        expect(session.expectedUpdateInterval, isNull);
      });
    });

    test('mode comes through, filter byte and all', () {
      feed([0xFE, 0xFE, us, ic705, 0x04, 0x03, 0x01, 0xFD]);
      expect(sink.readings, [const VfoReading(mode: 'CW')]);
    });

    test('keeps sub-kHz precision the way CI-V reports it', () {
      // CI-V carries down to 1 Hz; 14074123 Hz.
      feed([0xFE, 0xFE, us, ic705, 0x03, 0x23, 0x41, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings.single.freqKHz, closeTo(14074.123, 0.0001));
    });
  });

  group('bus discipline — what polo did not do', () {
    test('our own echo is not read back as the radio reporting', () {
      // The radio reflects what we send. Without this the driver reads its
      // own set-frequency as confirmation, so every command looks like it
      // worked — including ones the radio went on to reject.
      session.setFrequency(14074);
      final ourFrame = sink.sent.single;
      feed(ourFrame);
      expect(sink.readings, isEmpty);
    });

    test('traffic for another controller on the same bus is ignored', () {
      feed([0xFE, 0xFE, 0xE1, ic705, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, isEmpty);
    });

    test('a different radio on the same bus is ignored', () {
      // An IC-7300 (0x94) answering its own controller.
      feed([0xFE, 0xFE, us, 0x94, 0x03, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(sink.readings, isEmpty);
    });

    test('an NG is not mistaken for data, and does not report a reading', () {
      feed([0xFE, 0xFE, us, ic705, 0xFA, 0xFD]);
      expect(sink.readings, isEmpty);
    });

    test('an ACK is consumed quietly', () {
      feed([0xFE, 0xFE, us, ic705, 0xFB, 0xFD]);
      expect(sink.readings, isEmpty);
    });
  });

  group('commanding the radio', () {
    test('set frequency is a CI-V frame with BCD payload', () {
      session.setFrequency(14074);
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x05, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
    });

    test('set mode leaves the operator filter alone', () {
      session.setMode('USB');
      // No trailing filter byte: polo sent 01 every time, forcing FIL1.
      expect(sink.sent.single, [0xFE, 0xFE, ic705, us, 0x06, 0x01, 0xFD]);
    });

    test('a mode CI-V has no code for sends nothing', () {
      session.setMode('SSB');
      expect(sink.sent, isEmpty);
    });

    test('polls for frequency and mode, and stops when told', () {
      fakeAsync((async) {
        session.startUpdates();
        expect(sink.sent, hasLength(2), reason: 'asks once immediately');
        sink.sent.clear();

        async.elapse(const Duration(seconds: 5));
        expect(sink.sent, hasLength(2));

        sink.sent.clear();
        session.stopUpdates();
        async.elapse(const Duration(minutes: 1));
        expect(sink.sent, isEmpty);
      });
    });
  });

  group('the address is configuration, not a constant', () {
    test('a driver session honours a non-default radio address', () {
      // An IC-7300 on the same driver.
      const driver = IcomCivDriver();
      final other = driver.createSession(sink, {'civAddress': '94'}) as IcomCivSession;
      expect(other.radioAddress, 0x94);

      other.setFrequency(7074);
      expect(sink.sent.single[2], 0x94, reason: 'addressed to the configured radio');
    });

    test('an address round-tripped through JSON as a number still works', () {
      const driver = IcomCivDriver();
      expect((driver.createSession(sink, {'civAddress': 0xA4}) as IcomCivSession).radioAddress, 0xA4);
      expect((driver.createSession(sink, {'civAddress': '0xA4'}) as IcomCivSession).radioAddress, 0xA4);
    });

    test('an unusable address falls back to the IC-705 default rather than sending garbage', () {
      const driver = IcomCivDriver();
      expect((driver.createSession(sink, {}) as IcomCivSession).radioAddress, 0xA4);
      expect((driver.createSession(sink, {'civAddress': 'zz'}) as IcomCivSession).radioAddress, 0xA4);
    });
  });

  group('the equipment type', () {
    final type = EquipmentRegistry().typeFor('icom-generic-serial')!;

    test('rides the serial transport that already shipped — no new transport code', () {
      expect(type.transportKey, SerialTransport.transportKey);
      expect(type.category, kCategoryTransceiver);
      // The DRIVER is verified on hardware (a real IC-705 over WiFi), but
      // this type pairs it with the SERIAL transport and that pairing has
      // never met a radio. Asserting on the type rather
      // than the driver is the whole point: flipping the driver flag would
      // otherwise have silently dropped the caveat from this type too.
      expect(type.driver.hardwareVerified, isTrue, reason: 'the CI-V driver itself is proven');
      expect(type.hardwareVerified, isFalse, reason: 'over serial, this pairing is not');
    });

    test('defaults to the IC-705 address and Icom\'s CI-V default speed', () {
      expect(type.defaultConfig['civAddress'], 'A4');
      expect(type.defaultConfig['baudRate'], 19200);
    });

    test('asks for port, speed and address', () {
      expect(
        [for (final e in type.configElements()) if (e['type'] == 'field') e['key']],
        ['port', 'baudRate', 'civAddress'],
      );
    });

    test('warns about a radio offering two serial ports at once', () {
      // Several Icom radios (the IC-705 among them) expose two USB serial
      // ports simultaneously, and neither the OS nor this app can tell them
      // apart beyond a `#n` suffix — found by an operator confused by
      // exactly that after granting access to one and seeing two.
      final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
      expect(note['text'], contains('Port A'), reason: 'which one to pick');
    });

    test('a bad address is refused in the editor, not discovered at the bench', () {
      // A wrong address is silent on the wire — the radio ignores frames
      // addressed elsewhere, which looks exactly like a dead cable.
      expect(type.validate({'port': 'COM3', 'civAddress': 'A4'}), isNull);
      expect(type.validate({'port': 'COM3', 'civAddress': ''}), isNotNull);
      expect(type.validate({'port': 'COM3', 'civAddress': 'zz'}), isNotNull);
      expect(type.validate({'port': 'COM3', 'civAddress': '00'}), isNotNull, reason: '0x00 is broadcast');
      expect(type.validate({'port': '', 'civAddress': 'A4'}), isNotNull, reason: 'no port');
    });

    test('the row says where it is and which radio it is addressing', () {
      expect(
        type.describeTarget({'port': 'COM3', 'baudRate': 19200, 'civAddress': 'a4'}),
        'COM3 @ 19200 · CI-V A4',
      );
    });

    test('the registry offers it alongside the others', () {
      final registry = EquipmentRegistry();
      expect(registry.typeFor('icom-generic-serial')?.key, 'icom-generic-serial');
      // The CI-V driver is shared between the serial and WiFi types — the
      // transport/driver split paying off directly.
      expect(registry.typeFor('ic705-network')?.driver.key, 'icom-civ');
      expect(registry.typeFor('icom-generic-serial')?.driver.key, 'icom-civ');
      expect(registry.transports.keys, containsAll(['tcp', 'serial', 'icom-network']));
    });
  });
}
