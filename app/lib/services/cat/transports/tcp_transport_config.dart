// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host/port config section, identical on every platform — only
// `connect()` differs between tcp_transport_io.dart and
// tcp_transport_web.dart, so this is the one place that logic lives.

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';

mixin TcpTransportConfig implements EquipmentTransport {
  /// A radio with both serial and TCP variants must not store its serial
  /// device path and TCP port number under the same configuration key.
  String get portConfigKey;

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey('host')) hostConfigElement(),
    if (!overrides.containsKey(portConfigKey)) {'type': 'field', 'fieldType': 'number', 'key': portConfigKey, 'label': t.settings.station.port},
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == 'host') return validateHostField(key, value, config);
    if (key == portConfigKey) {
      final port = tcpPort({...config, portConfigKey: value});
      return (port < 1 || port > 65535) ? t.settings.station.portInvalid : null;
    }
    return null;
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {'host': trimmedHost(config), 'port': tcpPort(config)};

  @override
  String describeTarget(Map<String, dynamic> config) => '${trimmedHost(config)}:${tcpPort(config)}';

  /// `0` is deliberately not a plausible-looking port like 4992 — a stored
  /// value that fails to parse should read as obviously broken. This
  /// transport is shared by any TCP radio now, not just FlexRadio, so it
  /// has no business assuming one radio's default; `validate()` rejects
  /// anything outside 1-65535 before `connect()` ever sees it.
  int tcpPort(Map<String, dynamic> config) => numberFromConfig(config, portConfigKey, 0);
}
