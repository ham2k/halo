// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host/login config section, identical on every platform — only
// `connect()` differs between icom_network_transport_io.dart and
// icom_network_transport_web.dart, so this is the one place that logic
// lives.

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';

mixin IcomNetworkTransportConfig implements EquipmentTransport {
  /// The password lives in the platform keychain via
  /// `SettingsService.equipmentSecret`, never in the plain config blob —
  /// [CatService] moves it there on save.
  @override
  Set<String> get secretFields => const {'password'};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey('host')) hostConfigElement(),
    if (!overrides.containsKey('username'))
      {'type': 'field', 'fieldType': 'text', 'key': 'username', 'label': t.settings.station.radioUser, 'description': t.settings.station.radioLoginDescription},
    if (!overrides.containsKey('password'))
      {
        // 'secret' is the app's obscured field type; CatService routes
        // this one to the keychain.
        'type': 'field',
        'fieldType': 'secret',
        'key': 'password',
        'label': t.settings.station.radioPass,
      },
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    switch (key) {
      case 'host':
        return validateHostField(key, value, config);
      case 'username':
        // A blank username fails at login with a timeout that looks like a
        // network problem, so catch it in the editor.
        return stringFromConfig({...config, key: value}, key).trim().isEmpty ? t.settings.station.radioUserRequired : null;
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {
    'host': trimmedHost(config),
    'username': stringFromConfig(config, 'username').trim(),
    'password': stringFromConfig(config, 'password'),
  };

  @override
  bool isUnconfigured(Map<String, dynamic> config) => blankInConfig(config, 'host');

  @override
  String describeTarget(Map<String, dynamic> config) => trimmedHost(config);
}
