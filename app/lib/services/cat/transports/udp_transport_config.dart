// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host/port config section, identical on every platform — only
// `connect()` differs between udp_transport_io.dart and
// udp_transport_web.dart.

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';

mixin UdpTransportConfig implements EquipmentTransport {
  /// The key the destination port is stored under: its own, so a model with
  /// a TCP variant beside this one does not share one port number between
  /// two protocols.
  String get portConfigKey;

  /// How far above the destination port the replies arrive — the port this
  /// transport listens on.
  int get replyPortOffset;

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey('host')) hostConfigElement(),
    if (!overrides.containsKey(portConfigKey)) {'type': 'field', 'fieldType': 'number', 'key': portConfigKey, 'label': t.settings.station.port},
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == 'host') return validateHostField(key, value, config);
    if (key == portConfigKey) {
      // The reply port has to be a port too.
      final port = udpPort({...config, portConfigKey: value});
      return (port < 1 || port + replyPortOffset > 65535) ? t.settings.station.portInvalid : null;
    }
    return null;
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
    'host': trimmedHost(config),
    'port': udpPort(config),
    'replyPort': udpPort(config) + replyPortOffset,
  };

  @override
  bool isUnconfigured(Map<String, dynamic> config) => blankInConfig(config, 'host');

  @override
  String describeTarget(Map<String, dynamic> config) => '${trimmedHost(config)}:${udpPort(config)}';

  /// `0` for a value that does not parse, for [TcpTransportConfig.tcpPort]'s
  /// reason: [validateField] refuses it before `connect()` sees it.
  int udpPort(Map<String, dynamic> config) => numberFromConfig(config, portConfigKey, 0);
}
