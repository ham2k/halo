// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a serial connection does with RTS and DTR. RTS is the PTT line on a
// Digirig, a SignaLink and most home-made cables, and DTR keys CW or PTT on
// many more, so a wrong default here keys somebody's transmitter the moment
// the app connects.

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
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

  // The entries whose radio waits for RTS before it answers, and so prefill it
  // high — each one a decision, since on a Digirig the same line transmits.
  // The Orions' guide wires RTS/CTS as the port's handshake, and so does
  // every Kenwood's CAT port — but not the other rigs on Kenwood's protocol.
  const rtsHighByDefault = {'tentec-565-serial', 'tentec-566-serial', 'ts590sg-serial', 'ts480-serial', 'kenwood-serial'};

  test('no entry in the catalogue raises either line unless it is known to need it', () {
    // Whatever a new entry prefills, these are the lines that transmit. The
    // prefill is what a new node starts from; the bare port is a node saved
    // before the settings existed.
    expect(cableTypes, isNotEmpty, reason: 'sanity: the loop below must check something');
    for (final type in cableTypes) {
      final prefilled = type.targetFor({...type.defaultConfig, 'port': '/dev/tty.fake'});
      expect(prefilled[serialRtsHighConfigKey], rtsHighByDefault.contains(type.key), reason: '${type.key}: RTS keys a Digirig on connect');
      expect(prefilled[serialDtrHighConfigKey], isFalse, reason: '${type.key} would key a cable that keys from DTR');

      final bare = type.targetFor({'port': '/dev/tty.fake'});
      expect(bare[serialRtsHighConfigKey], isFalse, reason: '${type.key}: a node saved without the setting never raises RTS');
      expect(bare[serialDtrHighConfigKey], isFalse, reason: '${type.key} would key a cable that keys from DTR');
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

  group('picking a port in the editor sets RTS for a Yaesu on its own USB port', () {
    // A Yaesu with CAT RTS on answers nothing while RTS is low, but the same
    // entry is just as often reached through a Digirig, where RTS is PTT —
    // so the port picked is what decides, never the entry alone.
    const enhanced = SerialPortOption(name: '/dev/ttyUSB0', description: 'CP2105 Dual USB to UART Bridge Controller', vendorId: 0x10C4, productId: 0xEA70);
    const standard = SerialPortOption(name: '/dev/ttyUSB1', description: 'CP2105 Dual USB to UART Bridge Controller', vendorId: 0x10C4, productId: 0xEA70);
    // Same maker, same vendor id: only the product says it is not the radio.
    const digirig = SerialPortOption(name: '/dev/ttyUSB2', description: 'CP2102N USB to UART Bridge Controller', vendorId: 0x10C4, productId: 0xEA60);
    final ownUsbPortTypes = [
      for (final key in ['ft891-serial', 'ft991a-serial', 'ft710-serial', 'ftdx10-serial', 'ftx1-serial']) registry.typeFor(key)!,
    ];

    setUp(() => useSerialPortsForTest(const [enhanced, standard, digirig]));

    test("the radio's own bridge ticks Hold RTS high", () {
      for (final type in ownUsbPortTypes) {
        expect(type.fieldChanged('port', enhanced.name), {serialRtsHighConfigKey: true}, reason: type.key);
      }
    });

    test('a Digirig unticks it', () {
      for (final type in ownUsbPortTypes) {
        expect(type.fieldChanged('port', digirig.name), {serialRtsHighConfigKey: false}, reason: '${type.key} would key the transmitter through a Digirig');
      }
    });

    test('a port that has gone leaves the box alone', () {
      // Re-picking the stored port with the radio unplugged must not clear
      // a tick that was right, under a fold the operator never opens.
      expect(registry.typeFor('ftdx10-serial')!.fieldChanged('port', '/dev/ttyUSB9'), isNull);
    });

    test("Windows' Standard port unticks it, though the suggestion cannot tell it from the Enhanced", () {
      const winEnhanced = SerialPortOption(
        name: 'COM5',
        description: 'Silicon Labs Dual CP2105 USB to UART Bridge: Enhanced COM Port',
        vendorId: 0x10C4,
        productId: 0xEA70,
      );
      const winStandard = SerialPortOption(
        name: 'COM6',
        description: 'Silicon Labs Dual CP2105 USB to UART Bridge: Standard COM Port',
        vendorId: 0x10C4,
        productId: 0xEA70,
      );
      useSerialPortsForTest(const [winEnhanced, winStandard]);
      final type = registry.typeFor('ftdx10-serial')!;
      expect(type.fieldChanged('port', winEnhanced.name), {serialRtsHighConfigKey: true});
      expect(type.fieldChanged('port', winStandard.name), {serialRtsHighConfigKey: false}, reason: 'PTT and keying: RTS transmits with PC KEYING set to it');
    });

    test('a port an action picks sets the box too', () {
      // The editor applies an action's updates without reporting them as
      // changes — the web's "add a USB device" picks a port that way.
      final ftdx10 = registry.typeFor('ftdx10-serial')!;
      final type = EquipmentType(
        ftdx10.model,
        EquipmentVariant(key: ftdx10.key, driver: ftdx10.driver, transport: const _PickingTransport(), restrictions: ftdx10.restrictions),
      );
      expect(
        type.runAction('grant', 'pick', const {}),
        completion(isA<EquipmentActionResult>().having((r) => r.fieldUpdates, 'fieldUpdates', {serialRtsHighConfigKey: true, 'port': enhanced.name})),
      );
    });

    test("where the platform tells the bridge's ports apart, its second port unticks it", () {
      // The second is PTT and keying, and transmits from RTS with the
      // radio's PC KEYING set to it. Elsewhere both ports tick, which is the
      // risk this entry accepts.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const first = SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB0', description: 'CP2105 Dual USB to UART Bridge Controller');
      const second = SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB1', description: 'CP2105 Dual USB to UART Bridge Controller');
      useSerialPortsForTest(const [first, second]);
      final type = registry.typeFor('ftdx10-serial')!;
      expect(type.fieldChanged('port', first.name), {serialRtsHighConfigKey: true});
      expect(type.fieldChanged('port', second.name), {serialRtsHighConfigKey: false});
    });

    test('an entry reached through some other cable leaves RTS where the operator put it', () {
      for (final key in [
        'yaesu-serial',
        'ft450-serial',
        'ft950-serial',
        'ftdx1200-serial',
        'ft2000-serial',
        'ftdx5000-serial',
        'ft817-serial',
        'tentec-566-serial',
      ]) {
        expect(registry.typeFor(key)!.fieldChanged('port', enhanced.name), isNull, reason: key);
      }
    });

    test('a Bluetooth link of the same radio sets nothing', () {
      // It has no lines, and the box it would tick belongs to the USB pairing
      // rendered beside it.
      final restrictions = registry.typeFor('ftdx10-serial')!.restrictions;
      expect(const BluetoothSerialTransport().fieldChanged('port', enhanced.name, restrictions: restrictions), isNull);
    });

    test('a node keeps what it stored: connecting never decides', () {
      // Every node saved through the editor stores the box, ticked or not;
      // a port that later reads as the radio's own must not override it.
      final type = registry.typeFor('ftdx10-serial')!;
      expect(type.targetFor({'port': enhanced.name, serialRtsHighConfigKey: false})[serialRtsHighConfigKey], isFalse);
    });
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
    final english = (await AppLocale.en.build()).settings.station;
    for (final locale in AppLocale.values) {
      final st = (await locale.build()).settings.station;
      for (final (note, base) in [
        (st.ft891Troubleshooting, english.ft891Troubleshooting),
        (st.yaesuTroubleshooting, english.yaesuTroubleshooting),
        (st.yaesuRs232Troubleshooting, english.yaesuRs232Troubleshooting),
        (st.yaesuUsbTroubleshooting, english.yaesuUsbTroubleshooting),
        (st.tenTecOrionTroubleshooting, english.tenTecOrionTroubleshooting),
      ]) {
        // The Ten-Tec note is not yet translated, so it falls back to English
        // beside labels that are: checked once a translation arrives. Only
        // that one — a translated note reverting to English is a regression.
        if (locale != AppLocale.en && note == base && base == english.tenTecOrionTroubleshooting) continue;
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

/// The serial transport, with an action that picks the radio's own port the
/// way the web's "add a USB device" does.
class _PickingTransport extends SerialTransport {
  const _PickingTransport();

  @override
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) async =>
      const EquipmentActionResult(fieldUpdates: {'port': '/dev/ttyUSB0'});
}
