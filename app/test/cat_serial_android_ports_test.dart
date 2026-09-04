// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Android port picker for a USB device with more than one serial port.
//
// A Xiegu X6100 is one USB device carrying audio plus TWO CDC/ACM serial
// ports, and CI-V lives on the second. The library under usb_serial opens
// the first CDC data interface unless handed an index, so a picker with one
// entry per device can only ever reach the wrong port — the operator sees
// the radio, picks it, sets 19200, and nothing answers.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// The io file directly, not the conditional export: the analyzer resolves
// that export to the stub, where none of this exists.
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('androidCdcDataInterfaces', () {
    const channel = MethodChannel('ham2k/usb_interfaces');
    void answer(Future<Object?> Function(MethodCall call)? handler) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
    tearDown(() => answer(null));

    test('keeps only the CDC data interfaces, by index, in descriptor order', () async {
      // The X6100's shape: audio, then two ACM pairs. A control interface
      // (class 2) is not a port — listing it would offer the X6100 as four.
      const classes = [1, 1, 1, 2, 10, 2, 10];
      MethodCall? seen;
      answer((call) async {
        seen = call;
        return [
          for (final (i, c) in classes.indexed) {'index': i, 'interfaceClass': c, 'interfaceSubclass': 0, 'interfaceProtocol': 0},
        ];
      });

      expect(await androidCdcDataInterfaces('/dev/bus/usb/001/004'), [4, 6]);
      expect(seen?.method, 'list');
      expect(seen?.arguments, {'deviceName': '/dev/bus/usb/001/004'});
    });

    test('a native build without the channel falls back to the single auto-detected port', () async {
      // No handler at all: the platform side answers "not implemented".
      expect(await androidCdcDataInterfaces('/dev/bus/usb/001/004'), isEmpty);
    });

    test('a device gone since enumeration falls back the same way', () async {
      answer((_) async => throw PlatformException(code: 'no_device'));
      expect(await androidCdcDataInterfaces('/dev/bus/usb/001/004'), isEmpty);
    });

    test('a malformed answer is a bug in our own channel, and stays loud', () async {
      answer((_) async => [
            {'interfaceClass': 10},
          ]);
      expect(androidCdcDataInterfaces('/dev/bus/usb/001/004'), throwsA(isA<TypeError>()));
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
        cdcDataInterfaces: [4, 6],
      );

      expect(options.map((o) => o.name), ['/dev/bus/usb/001/004#4', '/dev/bus/usb/001/004#6']);
      expect(options[0].label, contains('port 1 of 2'));
      expect(options[1].label, contains('port 2 of 2'));
      // The radio is still recognisable in every entry.
      expect(options[1].label, contains('Xiegu'));
      expect(options[1].label, contains('X6100'));
    });

    test('a single-port device keeps its bare name, so stored configs still match', () {
      for (final interfaces in [<int>[], [1]]) {
        final options = androidSerialPortOptions(
          deviceName: '/dev/bus/usb/001/002',
          productName: 'CP2102',
          cdcDataInterfaces: interfaces,
        );
        expect(options.map((o) => o.name), ['/dev/bus/usb/001/002']);
        expect(options.single.label, isNot(contains('port 1')));
      }
    });
  });

  group('androidPortTarget', () {
    test('a suffixed name yields the device and the interface index the entry was built from', () {
      final options = androidSerialPortOptions(deviceName: '/dev/bus/usb/001/004', cdcDataInterfaces: [4, 6]);
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
