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

  /// Where this port sits among its device's serial ports, and how many
  /// the device has — set only where the platform can tell (Android),
  /// and only for a device presenting more than one. Null means the OS
  /// already gave the port its own name and nothing here knows its
  /// siblings.
  final int? portIndex;
  final int? portCount;

  const SerialPortOption({
    required this.name,
    this.description,
    this.manufacturer,
    this.productName,
    this.serialNumber,
    this.vendorId,
    this.productId,
    this.portIndex,
    this.portCount,
  });

  /// What to show in the picker. The raw device name rarely identifies
  /// anything — a dual-port bridge (the CP2105 behind most Yaesu USB
  /// interfaces) presents two of them, one carrying CAT and one carrying
  /// PTT, distinguishable only by whatever the USB descriptors say. Where
  /// [portIndex] is known the label says "port N of M" as well; [bareLabel]
  /// leaves that off, for a list that has already picked the port.
  String get label => _label(withPort: true);

  String get bareLabel => _label(withPort: false);

  String _label({required bool withPort}) {
    final detail = [
      if (description != null) description! else ...[?manufacturer, ?productName],
      if (withPort && portIndex != null && portCount != null)
        '(${t.settings.station.serialPortOrdinal(n: portIndex! + 1, total: portCount!)})',
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
              for (final choice in portChoices(restrictions['port'])) {'value': choice.name, 'label': choice.label},
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

  /// The picker's entries once a `port` restriction has had its say.
  ///
  /// `{'index': n}` says which of a multi-port device's serial ports the
  /// radio's CAT is on, counted from 0 in descriptor order — the X6100's
  /// CI-V is on 1, a Yaesu's on its CP2105's 0. That device then shows
  /// only that port, under a label with no "port N of M". With
  /// `'vendorId'` the rule applies only to that maker's bridges, so a
  /// radio reached through some other adapter's two ports still offers
  /// both. A device the platform could not split, or with fewer ports
  /// than the index names, is listed whole: the restriction narrows what
  /// this transport knows to be siblings and never hides a port the OS
  /// named on its own.
  List<({String name, String label})> portChoices(Object? restriction) {
    final index = restriction is Map ? restriction['index'] : null;
    final vendorId = restriction is Map ? restriction['vendorId'] : null;
    bool decides(SerialPortOption port) =>
        index is int &&
        index >= 0 &&
        port.portIndex != null &&
        index < (port.portCount ?? 0) &&
        (vendorId == null || port.vendorId == vendorId);
    return [
      for (final port in availablePorts)
        if (!decides(port))
          (name: port.name, label: port.label)
        else if (port.portIndex == index)
          (name: port.name, label: port.bareLabel),
    ];
  }

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
  /// `stopBits` is never a field: a driver whose device needs two (the
  /// WinKeyer) pins it in its model's `overrides`.
  @override
  Set<String> get recognizedConfigKeys => const {'port', 'baudRate', 'stopBits'};

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != 'port') return null;
    return serialPort({...config, 'port': value}).isEmpty ? t.settings.station.serialPortRequired : null;
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
        'port': serialPort(config),
        'baudRate': serialBaudRate(config),
        'stopBits': serialStopBits(config),
      };

  @override
  String describeTarget(Map<String, dynamic> config) => '${serialPort(config)} @ ${serialBaudRate(config)}';

  static String serialPort(Map<String, dynamic> config) => stringFromConfig(config, 'port').trim();

  static int serialBaudRate(Map<String, dynamic> config) =>
      numberFromConfig(config, 'baudRate', supportedBaudRates.first);

  /// 1 unless the model says 2; nothing here uses 1.5.
  static int serialStopBits(Map<String, dynamic> config) => numberFromConfig(config, 'stopBits', 1) == 2 ? 2 : 1;
}
