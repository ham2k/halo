// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a serial connection does with RTS and DTR. RTS is the PTT line on a
// Digirig, a SignaLink and most home-made cables, and DTR keys CW or PTT on
// many more, so a wrong default here keys somebody's transmitter the moment
// the app connects.

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/bluetooth_serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart' show serialLinesMismatch;

import '../support/fake_serial_ports.dart';

void main() {
  setUp(() => useSerialPortsForTest(const []));

  final registry = EquipmentRegistry();
  final serialTypes = [
    for (final type in registry.types)
      if (type.transport is SerialTransport) type,
  ];
  // Bluetooth has its own test: it names no line at all.
  final cableTypes = [
    for (final type in serialTypes)
      if (type.transportKey != BluetoothSerialTransport.transportKey) type,
  ];

  test('no entry in the catalogue raises either line unless the operator asks', () {
    // Whatever a new entry prefills, these are the lines that transmit. The
    // prefill is what a new node starts from; the bare port is a node saved
    // before the settings existed.
    expect(cableTypes, isNotEmpty, reason: 'sanity: the loop below must check something');
    for (final type in cableTypes) {
      for (final stored in [
        {...type.defaultConfig, 'port': '/dev/tty.fake'},
        {'port': '/dev/tty.fake'},
      ]) {
        final target = type.targetFor(stored);
        expect(target[serialRtsHighConfigKey], isFalse, reason: '${type.key} would key a Digirig on connect');
        expect(target[serialDtrHighConfigKey], isFalse, reason: '${type.key} would key a cable that keys from DTR');
      }
    }
  });

  test('a cable pairing always manages its lines', () {
    // Absent means managed, so a target that forgets to say is the safe one.
    for (final type in cableTypes) {
      expect(type.targetFor({'port': '/dev/tty.fake'})[serialNoControlLinesKey], isNot(isTrue), reason: type.key);
    }
  });

  test("the operator's choice reaches the connection", () {
    final type = registry.typeFor('ft817-serial')!;
    expect(type.targetFor({'port': 'COM3', serialDtrHighConfigKey: true})[serialDtrHighConfigKey], isTrue, reason: 'a cable powered from DTR');
    expect(type.targetFor({'port': 'COM3', serialRtsHighConfigKey: true})[serialRtsHighConfigKey], isTrue, reason: 'a Yaesu with CAT RTS on');
  });

  test('both lines are offered, and folded under Advanced Settings', () {
    final fields = {
      for (final e in registry.typeFor('ft817-serial')!.configElements())
        if (e['type'] == 'field') e['key']: e,
    };
    expect(fields[serialRtsHighConfigKey]?['advanced'], isTrue);
    expect(fields[serialDtrHighConfigKey]?['advanced'], isTrue);
  });

  test('a Bluetooth link leaves the lines alone, and offers neither', () {
    // No wire behind them, so nothing to write or read back — a driver that
    // refuses a modem-control write would otherwise fail a link that never
    // had lines. And a USB pairing of the same radio can leave line values in
    // the node's config (the editor seeds every pairing at once), which must
    // never reach the port.
    final type = registry.types.firstWhere((t) => t.transportKey == BluetoothSerialTransport.transportKey);
    final target = type.targetFor({'port': '/dev/cu.IC-705', serialRtsHighConfigKey: true, serialDtrHighConfigKey: true});
    expect(target[serialNoControlLinesKey], isTrue);
    expect(target, isNot(contains(serialRtsHighConfigKey)));
    expect(target, isNot(contains(serialDtrHighConfigKey)));
    expect([for (final e in type.configElements()) e['key']], isNot(anyOf(contains(serialRtsHighConfigKey), contains(serialDtrHighConfigKey))));
  });

  test('the troubleshooting notes name the settings the way the editor does, in every language', () async {
    // The notes quote the labels as text, so renaming a label would leave
    // them pointing at a control that no longer exists under that name.
    for (final locale in AppLocale.values) {
      final st = (await locale.build()).settings.station;
      for (final note in [st.ft891Troubleshooting, st.yaesuTroubleshooting, st.yaesuRs232Troubleshooting, st.yaesuUsbTroubleshooting]) {
        expect(note, contains(st.serialRtsHigh), reason: '${locale.languageCode}: a CAT RTS note');
        expect(note, contains(st.advancedSettings), reason: '${locale.languageCode}: a CAT RTS note');
      }
      expect(st.yaesuBinaryTroubleshooting, contains(st.serialDtrHigh), reason: locale.languageCode);
      expect(st.yaesuBinaryTroubleshooting, contains(st.advancedSettings), reason: locale.languageCode);
    }
  });

  group('the lines read back from the open port', () {
    // libserialport can report success without having set a line, so the
    // desktop connection refuses the port on what it reads back rather than
    // on what it wrote.
    test('match what was asked', () {
      expect(serialLinesMismatch(rts: SerialPortRts.off, dtr: SerialPortDtr.off, rtsHigh: false, dtrHigh: false), isNull);
      expect(serialLinesMismatch(rts: SerialPortRts.on, dtr: SerialPortDtr.on, rtsHigh: true, dtrHigh: true), isNull);
    });

    test('a line still high after asking for low refuses the port', () {
      // What the OS leaves after open when the write was silently dropped.
      expect(serialLinesMismatch(rts: SerialPortRts.on, dtr: SerialPortDtr.off, rtsHigh: false, dtrHigh: false), contains('RTS'));
      expect(serialLinesMismatch(rts: SerialPortRts.off, dtr: SerialPortDtr.on, rtsHigh: false, dtrHigh: false), contains('DTR'));
    });

    test('a line that did not come up refuses too', () {
      // A cable powered from DTR stays dead; say so instead of a silent radio.
      expect(serialLinesMismatch(rts: SerialPortRts.off, dtr: SerialPortDtr.off, rtsHigh: false, dtrHigh: true), contains('DTR'));
    });

    test('hardware flow control left on by another program refuses, and says why', () {
      // The driver moves RTS on its own under CRTSCTS, whatever was written.
      final reason = serialLinesMismatch(rts: SerialPortRts.flowControl, dtr: SerialPortDtr.off, rtsHigh: false, dtrHigh: false);
      expect(reason, contains('hardware flow control'));
    });
  });
}
