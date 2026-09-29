// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's Bluetooth serial profile (SPP). Once paired, the operating system
// presents it as one more serial port, so this IS the serial transport — the
// same connection, fields and validation. What differs is what the operator
// chose: a radio set up over Bluetooth keeps saying so, and its port picker
// ranks the ports that are not USB first, which is where a paired radio is.

import 'serial_transport.dart';

class BluetoothSerialTransport extends SerialTransport {
  const BluetoothSerialTransport();

  static const transportKey = 'bluetoothSerial';

  @override
  String get key => transportKey;

  /// A radio's own Bluetooth serial profile has no RTS or DTR wire behind
  /// it, so there is nothing to offer, and nothing to write: a Bluetooth
  /// driver that refuses a modem-control write, or reports the lines back
  /// oddly, would otherwise fail a link that never had them. Whatever a USB
  /// pairing of the same radio left in the form never reaches the port.
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    for (final element in super.configElements(overrides: overrides, restrictions: restrictions))
      if (element['key'] != serialRtsHighConfigKey && element['key'] != serialDtrHighConfigKey) element,
  ];

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
    for (final entry in super.targetFor(config).entries)
      if (entry.key != serialRtsHighConfigKey && entry.key != serialDtrHighConfigKey) entry.key: entry.value,
    serialNoControlLinesKey: true,
  };

  /// A paired device's port, as each platform names it: one that says
  /// Bluetooth (Windows' "Standard Serial over Bluetooth link"), a Linux
  /// `rfcomm`, or on macOS a `cu.<name>` with no USB identity. Never the
  /// ports every machine has — macOS's own Bluetooth-Incoming-Port and
  /// debug-console, a PC's built-in `ttyS`/COM ports — which open and then
  /// answer nothing.
  @override
  bool prefersPort(SerialPortOption port) {
    if (_systemPorts.hasMatch(port.name)) return false;
    final label = [port.name, ?port.description, ?port.productName].join(' ');
    if (_bluetooth.hasMatch(label) || _rfcomm.hasMatch(port.name)) return true;
    return port.vendorId == null && port.name.startsWith('/dev/cu.') && !_usb.hasMatch(port.name);
  }

  static final _systemPorts = RegExp(r'Bluetooth-Incoming-Port|debug-console|/dev/ttyS\d', caseSensitive: false);
  static final _bluetooth = RegExp('bluetooth', caseSensitive: false);
  static final _rfcomm = RegExp(r'/dev/rfcomm\d');
  static final _usb = RegExp('usb', caseSensitive: false);
}
