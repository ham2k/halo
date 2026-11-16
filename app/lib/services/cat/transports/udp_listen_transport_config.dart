// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The listening port, identical on every platform — only `connect()` differs
// between udp_listen_transport_io.dart and udp_listen_transport_web.dart.

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';

/// The key the listening port is stored under: its own, so a model with a
/// TCP variant beside this one does not share one port number between the
/// port it dials and the port it listens on.
const udpListenPortConfigKey = 'listenPort';

mixin UdpListenTransportConfig implements EquipmentTransport {
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey(udpListenPortConfigKey))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': udpListenPortConfigKey,
        'label': t.settings.station.listenPort,
        'description': t.settings.station.listenPortDescription,
      },
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != udpListenPortConfigKey) return null;
    final port = listenPort({...config, udpListenPortConfigKey: value});
    return (port < 1 || port > 65535) ? t.settings.station.portInvalid : null;
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {'port': listenPort(config)};

  @override
  String describeTarget(Map<String, dynamic> config) => t.settings.station.listeningOn(port: listenPort(config));

  /// `0` for a value that does not parse, for [TcpTransportConfig.tcpPort]'s
  /// reason: [validateField] refuses it before `connect()` sees it.
  int listenPort(Map<String, dynamic> config) => numberFromConfig(config, udpListenPortConfigKey, 0);
}
