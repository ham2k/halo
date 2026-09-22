// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one part of the web serial transport with no JS interop in it, so it
// can run under the plain VM test runner — no browser needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transports/web_serial_port_keys.dart';

void main() {
  group('assignWebSerialPortKeys', () {
    test('keys a single granted port by its vendor:product pair', () {
      expect(assignWebSerialPortKeys([(0x10C4, 0xEA70)]), ['4292:60016']);
    });

    test('a missing vendor or product id reads as 0, not a crash', () {
      expect(assignWebSerialPortKeys([(null, null)]), ['0:0']);
      expect(assignWebSerialPortKeys([(0x10C4, null)]), ['4292:0']);
    });

    test('different devices keep their own keys, in enumeration order', () {
      expect(assignWebSerialPortKeys([(0x10C4, 0xEA70), (0x0403, 0x6001)]), ['4292:60016', '1027:24577']);
    });

    // Web Serial exposes nothing else to tell two identical devices apart
    // by — this is the best the API allows, not a design choice.
    test('two identical devices get disambiguated with a #n suffix', () {
      expect(assignWebSerialPortKeys([(0x10C4, 0xEA70), (0x10C4, 0xEA70), (0x10C4, 0xEA70)]), ['4292:60016', '4292:60016#2', '4292:60016#3']);
    });

    test('a repeat after a different device in between still keys correctly', () {
      expect(assignWebSerialPortKeys([(0x10C4, 0xEA70), (0x0403, 0x6001), (0x10C4, 0xEA70)]), ['4292:60016', '1027:24577', '4292:60016#2']);
    });
  });

  group('describeWebSerialUsbId', () {
    test('formats as hex VID:PID, uppercase and zero-padded to 4 digits', () {
      expect(describeWebSerialUsbId(0x10C4, 0xEA70), 'USB 10C4:EA70');
      expect(describeWebSerialUsbId(0x1, 0x2), 'USB 0001:0002');
    });

    test('a missing vendor or product id means nothing to describe', () {
      expect(describeWebSerialUsbId(null, 0xEA70), isNull);
      expect(describeWebSerialUsbId(0x10C4, null), isNull);
      expect(describeWebSerialUsbId(null, null), isNull);
    });
  });
}
