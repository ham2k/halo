// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio that knows which of its bridge's ports carries CAT picks it for
// the operator, where the platform can tell the ports apart.
//
// Choosing wrong looks exactly like a dead cable: the port opens, the
// commands go out, nothing answers. The X6100's CI-V is on the second of
// its two ports; a Yaesu's is on the first of its CP2105's. Offering both
// and a note is what the operator gets on desktop, where the OS named the
// ports and nothing here knows they are siblings — so the restriction must
// only ever act on ports this transport itself split.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

class _Ports extends EquipmentTransport with SerialTransportConfig {
  @override
  final List<SerialPortOption> availablePorts;

  const _Ports(this.availablePorts);

  @override
  String get key => 'serial';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) =>
      throw UnimplementedError();
}

/// An Android device split into [count] ports, the way serial_transport_io
/// builds them.
List<SerialPortOption> split(String device, int count, {int? vendorId, String? productName}) => [
      for (var i = 0; i < count; i++)
        SerialPortOption(name: '$device#$i', productName: productName, vendorId: vendorId, portIndex: i, portCount: count),
    ];

void main() {
  const x6100 = '/dev/bus/usb/001/004';
  const cp2105 = '/dev/bus/usb/001/007';
  const ft2232 = '/dev/bus/usb/001/009';
  final ports = _Ports([
    const SerialPortOption(name: '/dev/bus/usb/001/002', productName: 'CP2102', vendorId: 0x10C4),
    ...split(x6100, 2, productName: 'X6100'),
    ...split(cp2105, 2, vendorId: 0x10C4, productName: 'CP2105'),
    ...split(ft2232, 2, vendorId: 0x0403, productName: 'FT2232'),
  ]);

  List<String> names(Object? restriction) => [for (final c in ports.portChoices(restriction)) c.name];

  test('with no restriction every port is offered, split ones saying which they are', () {
    expect(names(null), ['/dev/bus/usb/001/002', '$x6100#0', '$x6100#1', '$cp2105#0', '$cp2105#1', '$ft2232#0', '$ft2232#1']);
    expect(ports.portChoices(null)[2].label, contains('port 2 of 2'));
  });

  test('an index picks that port of every split device, and drops the ordinal from its label', () {
    // The X6100's rule: CI-V on the second port, whatever the bridge.
    final choices = ports.portChoices({'index': 1});
    expect([for (final c in choices) c.name], ['/dev/bus/usb/001/002', '$x6100#1', '$cp2105#1', '$ft2232#1']);
    expect(choices[1].label, isNot(contains('port')));
    expect(choices[1].label, contains('X6100'));
  });

  test('a vendor id confines the rule to that maker, so another adapter still offers both ports', () {
    // A Yaesu reached through its own CP2105 gets the Enhanced port only;
    // the same radio on an FTDI cable is somebody else's wiring.
    expect(names(Ft891Driver.cp2105CatPort), ['/dev/bus/usb/001/002', '$x6100#0', '$x6100#1', '$cp2105#0', '$ft2232#0', '$ft2232#1']);
  });

  test('an index the device does not have leaves it listed whole rather than empty', () {
    // Either side of the range: a too-large index matches no port, and a
    // negative one would match none while claiming every device.
    expect(names({'index': 3}), names(null));
    expect(names({'index': -1}), names(null));
  });

  test('a restriction that is not a map, or an index that is not a number, narrows nothing', () {
    expect(names('second'), names(null));
    expect(names({'index': '1'}), names(null));
  });

  test('the port field the editor renders is built from these choices, not the raw port list', () {
    // The seam: with this line reverted to `availablePorts`, every test
    // above still passes and no radio ever picks its port.
    final field = ports.configElements(restrictions: {
      'port': {'index': 1},
    }).firstWhere((e) => e['key'] == 'port');
    final offered = [for (final o in field['options'] as List) (o as Map)['value']];
    expect(offered, ['/dev/bus/usb/001/002', '$x6100#1', '$cp2105#1', '$ft2232#1']);
  });

  group('the registry declares the CAT port for the radios whose bridge is known', () {
    final registry = EquipmentRegistry();

    test('every port restriction has the shape portChoices reads, so a typo inside it cannot narrow nothing', () {
      // The registry self-check only sees the outer key; `{'idx': 1}` or a
      // string vendor id would pass it and silently switch the rule off.
      for (final type in registry.types) {
        final port = type.restrictions['port'];
        if (port == null) continue;
        expect(port, isA<Map>(), reason: type.key);
        expect((port as Map)['index'], isA<int>(), reason: type.key);
        expect(port['index'] as int, isNonNegative, reason: type.key);
        expect(port['vendorId'], anyOf(isNull, isA<int>()), reason: type.key);
        expect(port.keys.toSet().difference({'index', 'vendorId'}), isEmpty, reason: type.key);
      }
    });

    test('the X6100 speaks CI-V on the second of its two ports', () {
      expect(registry.typeFor('x6100-serial')!.restrictions['port'], {'index': 1});
    });

    test('the CP2105 Yaesus speak CAT on the Enhanced port, the first, and only on a Silicon Labs bridge', () {
      for (final key in ['ft891-serial', 'ftdx10-serial']) {
        expect(registry.typeFor(key)!.restrictions['port'], {'index': 0, 'vendorId': 0x10C4}, reason: key);
      }
    });

    test('the generics declare nothing: their adapter is whatever the operator plugged in', () {
      for (final key in ['icom-generic-serial', 'yaesu-serial', 'kenwood-serial', 'elecraft-serial']) {
        expect(registry.typeFor(key)!.restrictions.containsKey('port'), isFalse, reason: key);
      }
    });
  });
}
