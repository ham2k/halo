// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The port/baud-rate config section, identical on every platform — only
// `availableSerialPorts()` and `connect()` differ between
// serial_transport_io.dart and serial_transport_stub.dart, so this is the
// one place the rest of that logic lives.

import '../../../i18n/strings.g.dart';
import '../transport.dart';
import 'config_field_helpers.dart';

/// What the radio's CAT menu offers. Anything the port doesn't support
/// fails at open rather than silently misbehaving.
const supportedBaudRates = [4800, 9600, 19200, 38400, 57600, 115200];

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

mixin SerialTransportConfig implements EquipmentTransport {
  /// Ports the app could open, enumerated fresh — a USB adapter can appear
  /// or vanish between one look and the next, so this must never be cached.
  List<SerialPortOption> get availablePorts;

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [
        if (!overrides.containsKey('port'))
          {
            'type': 'field',
            'fieldType': 'select',
            'key': 'port',
            'label': t.settings.station.serialPort,
            'description': t.settings.station.serialPortDescription,
            'options': [
              for (final port in availablePorts) {'value': port.name, 'label': port.label},
            ],
          },
        if (!overrides.containsKey('baudRate'))
          {
            'type': 'field',
            'fieldType': 'select',
            'key': 'baudRate',
            'label': t.settings.station.baudRate,
            'description': t.settings.station.baudRateDescription,
            'options': [
              for (final rate in _allowedBaudRates(restrictions)) {'value': rate, 'label': '$rate'},
            ],
          },
      ];

  static List<int> _allowedBaudRates(Map<String, dynamic> restrictions) {
    final allowed = restrictions['baudRate'];
    if (allowed is! List) return supportedBaudRates;
    return supportedBaudRates.where(allowed.contains).toList();
  }

  /// A static literal, deliberately not derived from [configElements] the
  /// way the base [EquipmentTransport.recognizedConfigKeys] default is:
  /// that default calls [configElements], which for this transport means
  /// [availablePorts] — a live hardware enumeration. `validate()` calls
  /// this on every connect and every unattended reconnect retry, and it
  /// has no business scanning serial hardware just to learn a field's key.
  @override
  Set<String> get recognizedConfigKeys => const {'port', 'baudRate'};

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != 'port') return null;
    return serialPort({...config, 'port': value}).isEmpty ? t.settings.station.serialPortRequired : null;
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
        'port': serialPort(config),
        'baudRate': serialBaudRate(config),
      };

  @override
  String describeTarget(Map<String, dynamic> config) => '${serialPort(config)} @ ${serialBaudRate(config)}';

  static String serialPort(Map<String, dynamic> config) => stringFromConfig(config, 'port').trim();

  static int serialBaudRate(Map<String, dynamic> config) =>
      numberFromConfig(config, 'baudRate', supportedBaudRates.first);
}
