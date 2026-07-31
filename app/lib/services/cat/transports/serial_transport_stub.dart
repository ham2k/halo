// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback. Like the TCP stub this throws rather than no-opping —
// reaching it means a platform gate is missing, and a silent no-op would
// present a radio as merely "not connected" forever. Enumeration returns
// empty instead: "no ports here" is a true answer, and the port picker asks
// before anyone has chosen to connect.

import '../transport.dart';

/// Declared here as well as in the io library: a conditional export has to
/// present the same API on both sides, or the web build stops compiling for
/// a reason that has nothing to do with web.
const supportedBaudRates = [4800, 9600, 19200, 38400, 57600, 115200];

class SerialTransport implements EquipmentTransport {
  const SerialTransport();

  static const transportKey = 'serial';

  @override
  String get key => transportKey;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('CAT control needs a serial port, which the web build does not have.');
  }
}

/// Ports the app could open, newest enumeration each call.
List<SerialPortOption> availableSerialPorts() => const [];

class SerialPortOption {
  final String name;
  final String? description;
  final String? manufacturer;
  final String? productName;
  final String? serialNumber;
  final int? vendorId;
  final int? productId;

  const SerialPortOption({
    required this.name,
    this.description,
    this.manufacturer,
    this.productName,
    this.serialNumber,
    this.vendorId,
    this.productId,
  });

  /// What to show in the picker. The raw device name rarely identifies
  /// anything — a dual-port bridge (the CP2105 behind most Yaesu USB
  /// interfaces) presents two of them, one carrying CAT and one carrying
  /// PTT, distinguishable only by whatever the USB descriptors say.
  String get label {
    final detail = description ??
        [
          if (manufacturer != null) manufacturer!,
          if (productName != null) productName!,
        ].join(' ');
    return detail.isEmpty ? name : '$name — $detail';
  }
}
