// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Android port picker for a USB device with more than one serial port.
//
// A Xiegu X6100 is one USB device carrying audio plus TWO CDC/ACM serial
// ports, and CI-V lives on the second. A CP2105 (behind most Yaesu USB
// interfaces) or an FT2232 is one device with two vendor-class ports, CAT
// on one and PTT on the other. The library under usb_serial opens the
// first interface unless handed an index, so a picker with one entry per
// device can only ever reach one port — the operator sees the radio,
// picks it, sets the baud, and nothing answers.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// The io file directly, not the conditional export: the analyzer resolves
// that export to the stub, where none of this exists.
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart';

/// Descriptors the way `UsbInterfacesChannel.kt` reports them, one per class.
List<Map<String, int>> descriptors(List<int> classes) => [
      for (final (i, c) in classes.indexed) {'index': i, 'interfaceClass': c, 'interfaceSubclass': 0, 'interfaceProtocol': 0},
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ftdi = 0x0403;
  const siliconLabs = 0x10C4;
  const vendorClass = 0xFF;

  group('androidSerialInterfaceIndexes', () {
    test('a CDC device keeps only its data interfaces, in descriptor order', () {
      // The X6100's shape: audio, then two ACM pairs. A control interface
      // (class 2) is not a port — listing it would offer the X6100 as four.
      expect(androidSerialInterfaceIndexes(vendorId: 0x1D6B, interfaces: descriptors([1, 1, 1, 2, 10, 2, 10])), [4, 6]);
    });

    test('a Silicon Labs bridge is one port per interface: CP2105 two, CP2108 four, CP2102 one', () {
      expect(androidSerialInterfaceIndexes(vendorId: siliconLabs, interfaces: descriptors([vendorClass, vendorClass])), [0, 1]);
      expect(androidSerialInterfaceIndexes(vendorId: siliconLabs, interfaces: descriptors(List.filled(4, vendorClass))), [0, 1, 2, 3]);
      expect(androidSerialInterfaceIndexes(vendorId: siliconLabs, interfaces: descriptors([vendorClass])), [0]);
    });

    test('an FTDI bridge is one port per interface: FT2232 two, FT232 one', () {
      expect(androidSerialInterfaceIndexes(vendorId: ftdi, interfaces: descriptors([vendorClass, vendorClass])), [0, 1]);
      expect(androidSerialInterfaceIndexes(vendorId: ftdi, interfaces: descriptors([vendorClass])), [0]);
    });

    test('a bridge maker\'s non-UART interfaces are not ports, whatever the vendor id says', () {
      // A CP2114 is Silicon Labs audio plus one vendor-class interface;
      // offered as three ports, two of them open and fail as "permission
      // denied".
      expect(androidSerialInterfaceIndexes(vendorId: siliconLabs, interfaces: descriptors([1, 1, vendorClass])), [2]);
      // An FT260 is HID throughout: no port at all.
      expect(androidSerialInterfaceIndexes(vendorId: ftdi, interfaces: descriptors([3, 3])), isEmpty);
    });

    test('a vendor-class interface under any other vendor is not a port', () {
      // A CH340 or PL2303 is a single vendor-class interface; it stays on
      // auto-detect, and a two-interface composite of some other make is
      // not split on a guess.
      expect(androidSerialInterfaceIndexes(vendorId: 0x1A86, interfaces: descriptors([vendorClass])), isEmpty);
      expect(androidSerialInterfaceIndexes(vendorId: 0x1234, interfaces: descriptors([vendorClass, vendorClass])), isEmpty);
      expect(androidSerialInterfaceIndexes(vendorId: null, interfaces: descriptors([vendorClass, 10])), [1]);
    });
  });

  group('androidSerialInterfaces', () {
    const channel = MethodChannel('ham2k/usb_interfaces');
    void answer(Future<Object?> Function(MethodCall call)? handler) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
    tearDown(() => answer(null));

    test('asks the channel for the device by name and applies the vendor rule to its answer', () async {
      MethodCall? seen;
      answer((call) async {
        seen = call;
        return descriptors([vendorClass, vendorClass]);
      });

      expect(await androidSerialInterfaces('/dev/bus/usb/001/004', vendorId: siliconLabs), [0, 1]);
      expect(await androidSerialInterfaces('/dev/bus/usb/001/004', vendorId: 0x1D6B), isEmpty);
      expect(seen?.method, 'list');
      expect(seen?.arguments, {'deviceName': '/dev/bus/usb/001/004'});
    });

    test('a native build without the channel falls back to the single auto-detected port', () async {
      // No handler at all: the platform side answers "not implemented".
      expect(await androidSerialInterfaces('/dev/bus/usb/001/004', vendorId: siliconLabs), isEmpty);
    });

    test('a device gone since enumeration falls back the same way', () async {
      answer((_) async => throw PlatformException(code: 'no_device'));
      expect(await androidSerialInterfaces('/dev/bus/usb/001/004', vendorId: siliconLabs), isEmpty);
    });

    test('a malformed answer is a bug in our own channel, and stays loud', () async {
      answer((_) async => [
            {'interfaceClass': 10},
          ]);
      expect(androidSerialInterfaces('/dev/bus/usb/001/004', vendorId: 0x1D6B), throwsA(isA<TypeError>()));
    });
  });

  group('androidSerialPortOptions', () {
    test('a device with two serial interfaces gets one entry per interface, numbered in order', () {
      // Audio interfaces at 0-2, then two ACM pairs: control 3 / data 4,
      // control 5 / data 6. Only the data interfaces are serial ports.
      final options = androidSerialPortOptions(
        deviceName: '/dev/bus/usb/001/004',
        manufacturer: 'Xiegu',
        productName: 'X6100',
        serialInterfaces: [4, 6],
      );

      expect(options.map((o) => o.name), ['/dev/bus/usb/001/004#4', '/dev/bus/usb/001/004#6']);
      expect(options[0].label, contains('port 1 of 2'));
      expect(options[1].label, contains('port 2 of 2'));
      // The radio is still recognisable in every entry.
      expect(options[1].label, contains('Xiegu'));
      expect(options[1].label, contains('X6100'));
    });

    test('a CP2105 splits the same way, port 1 being the Enhanced port a Yaesu puts CAT on', () {
      final options = androidSerialPortOptions(
        deviceName: '/dev/bus/usb/001/007',
        manufacturer: 'Silicon Labs',
        productName: 'CP2105 Dual USB to UART Bridge Controller',
        vendorId: siliconLabs,
        productId: 0xEA70,
        serialInterfaces: [0, 1],
      );
      expect(options.map((o) => o.name), ['/dev/bus/usb/001/007#0', '/dev/bus/usb/001/007#1']);
      expect(options[0].label, contains('port 1 of 2'));
      // The USB identity travels with every entry, so a driver's VID/PID
      // match still recognises the bridge in either.
      expect(options.map((o) => o.productId), everyElement(0xEA70));
    });

    test('a single-port device keeps its bare name, so stored configs still match', () {
      for (final interfaces in [<int>[], [0]]) {
        final options = androidSerialPortOptions(
          deviceName: '/dev/bus/usb/001/002',
          productName: 'CP2102',
          serialInterfaces: interfaces,
        );
        expect(options.map((o) => o.name), ['/dev/bus/usb/001/002']);
        expect(options.single.label, isNot(contains('port 1')));
      }
    });
  });

  group('androidPortTarget', () {
    test('a suffixed name yields the device and the interface index the entry was built from', () {
      final options = androidSerialPortOptions(deviceName: '/dev/bus/usb/001/004', serialInterfaces: [4, 6]);
      expect(androidPortTarget(options[1].name), (deviceName: '/dev/bus/usb/001/004', iface: 6));
    });

    test('a bare name asks usb_serial to auto-detect, which is -1', () {
      expect(androidPortTarget('/dev/bus/usb/001/002'), (deviceName: '/dev/bus/usb/001/002', iface: -1));
    });

    test('a suffix that is not a number is part of the name, not an index', () {
      expect(androidPortTarget('/dev/bus/usb/001/00#x'), (deviceName: '/dev/bus/usb/001/00#x', iface: -1));
    });
  });
}
