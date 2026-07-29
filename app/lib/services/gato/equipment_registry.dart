// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The catalogue of equipment the app knows how to talk to, and the
// transports it can reach them over.
//
// An [EquipmentType] is a (model × transport) pair — "FlexRadio over the
// network", "Yaesu FT-891 over USB serial" — because that pair is what
// decides the connection settings the user has to fill in. The protocol
// itself is NOT duplicated per transport: the type points at one shared
// [EquipmentDriver] per protocol family. See docs/design/gato.md.

import '../../i18n/strings.g.dart';
import 'discovery.dart';
import 'driver.dart';
import 'drivers/flexradio_driver.dart';
import 'equipment.dart';
import 'transport.dart';
import 'transports/tcp_transport.dart';
import 'transports/udp_broadcast.dart';

abstract class EquipmentType {
  /// Stable id, stored in [EquipmentNode.typeKey]. Never change it once
  /// shipped — a user's configured node is looked up by this.
  String get key;

  /// General characteristics, per data-model.md — `transceiver` today.
  String get category;

  /// What the user picks from the type list.
  String get name;

  /// Which [EquipmentTransport] reaches it.
  String get transportKey;

  EquipmentDriver get driver;

  /// FormRenderer elements for the connection parameters and any
  /// device-specific settings.
  List<Map<String, dynamic>> configElements();

  /// Sensible starting values for a new node of this type.
  Map<String, dynamic> get defaultConfig => const {};

  /// Turns the user's configuration into the map the transport connects
  /// with. Keeping this on the type is what lets two types share one
  /// transport with different settings.
  Map<String, dynamic> targetFor(Map<String, dynamic> config);

  /// A one-line "where is it" for the equipment list.
  String describeTarget(Map<String, dynamic> config);

  /// Null when the whole configuration is usable, otherwise why it isn't —
  /// the check [GatoService] runs before it bothers opening a socket.
  String? validate(Map<String, dynamic> config);

  /// Per-field version, for the editor: FormRenderer validates one field at
  /// a time and anchors the message on that field.
  String? validateField(String key, dynamic value, Map<String, dynamic> config);
}

/// FlexRadio radios reachable over the SmartSDR TCP API.
///
/// Found automatically: a Flex announces itself over UDP broadcast on 4992.
/// Address and port can always be typed in as well — a radio on another
/// subnet, or behind a router that doesn't forward broadcasts, never
/// announces, and neither app-polo branch had a manual path at all.
class FlexRadioTcpType implements EquipmentType, EquipmentDiscoverer {
  const FlexRadioTcpType();

  static const _driver = FlexRadioDriver();

  @override
  String get key => 'flexradio-tcp';

  @override
  String get category => kCategoryTransceiver;

  @override
  String get name => t.settings.station.types.flexRadioTcp;

  @override
  String get transportKey => TcpTransport.transportKey;

  @override
  EquipmentDriver get driver => _driver;

  @override
  Map<String, dynamic> get defaultConfig => {'port': FlexRadioDriver.defaultPort};

  @override
  List<Map<String, dynamic>> configElements() => [
        {
          'type': 'field',
          'fieldType': 'text',
          'key': 'host',
          'label': t.settings.station.host,
          'description': t.settings.station.hostDescription,
        },
        {
          'type': 'field',
          'fieldType': 'number',
          'key': 'port',
          'label': t.settings.station.port,
        },
      ];

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
        'host': _host(config),
        'port': _port(config),
      };

  @override
  String describeTarget(Map<String, dynamic> config) => '${_host(config)}:${_port(config)}';

  @override
  Stream<DiscoveredEquipment> discover() =>
      udpBroadcastDatagrams(port: FlexRadioDriver.defaultPort).map(parseFlexDiscovery).where((found) => found != null).map(
            (found) => DiscoveredEquipment(
              typeKey: key,
              // Serial when the radio offers one, so a radio that moves to a
              // new address updates its entry instead of appearing twice.
              id: found!.serial ?? '${found.host}:${found.port}',
              name: found.nickname ?? found.model,
              detail: [found.model, if (found.version != null) 'v${found.version}', found.host].join(' · '),
              config: {'host': found.host, 'port': found.port},
            ),
          );

  @override
  String? validate(Map<String, dynamic> config) =>
      validateField('host', config['host'], config) ?? validateField('port', config['port'], config);

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    final merged = {...config, key: value};
    switch (key) {
      case 'host':
        return _host(merged).isEmpty ? t.settings.station.hostRequired : null;
      case 'port':
        final port = _port(merged);
        return (port < 1 || port > 65535) ? t.settings.station.portInvalid : null;
      default:
        return null;
    }
  }

  static String _host(Map<String, dynamic> config) => (config['host'] as String? ?? '').trim();

  // The number field hands back an int, but a value round-tripped through
  // JSON or typed into a text field can arrive as a double or a string.
  static int _port(Map<String, dynamic> config) {
    final raw = config['port'];
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? FlexRadioDriver.defaultPort;
  }
}

/// What the app can talk to, and how it gets there.
///
/// A plain Dart list today. When extensions can contribute rig definitions
/// this gains a second source and merges them, the way [SettingsView]
/// already merges Dart settings groups with extension-contributed panels.
class EquipmentRegistry {
  final List<EquipmentType> types;
  final Map<String, EquipmentTransport> transports;

  EquipmentRegistry({List<EquipmentType>? types, Map<String, EquipmentTransport>? transports})
      : types = types ?? const [FlexRadioTcpType()],
        transports = transports ?? {TcpTransport.transportKey: const TcpTransport()};

  EquipmentType? typeFor(String? key) {
    for (final type in types) {
      if (type.key == key) return type;
    }
    return null;
  }

  EquipmentTransport? transportFor(String? key) => key == null ? null : transports[key];
}
