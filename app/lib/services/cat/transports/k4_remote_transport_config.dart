// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import '../transport.dart';
import 'config_field_helpers.dart';
import 'tcp_transport_config.dart';

mixin K4RemoteTransportConfig on EquipmentTransport implements TcpTransportConfig {
  @override
  Set<String> get secretFields => const {'password'};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    ...super.configElements(overrides: overrides, restrictions: restrictions),
    if (!overrides.containsKey('password')) {'type': 'field', 'fieldType': 'secret', 'key': 'password', 'label': t.settings.station.radioPass},
  ];

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {...super.targetFor(config), 'password': stringFromConfig(config, 'password')};
}
