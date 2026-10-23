// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host/port/login config section, identical on every platform — only
// `connect()` differs between icom_network_transport_io.dart and
// icom_network_transport_web.dart, so this is the one place that logic
// lives.

import 'package:halo_i18n/halo_i18n.dart';
import '../transport.dart';
import 'config_field_helpers.dart';
import 'icom_network_protocol.dart' show icomControlPort, icomSerialPort;

mixin IcomNetworkTransportConfig implements EquipmentTransport {
  /// The password lives in the platform keychain via
  /// `SettingsService.equipmentSecret`, never in the plain config blob —
  /// [CatService] moves it there on save.
  @override
  Set<String> get secretFields => const {'password'};

  /// The radio's two UDP ports, as its network menu names them. Each can be
  /// changed there, and a radio reached from outside its own network is
  /// usually forwarded to on others.
  static const controlPortConfigKey = 'controlPort';
  static const serialPortConfigKey = 'serialPort';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey('host')) hostConfigElement(),
    if (!overrides.containsKey(controlPortConfigKey))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': controlPortConfigKey,
        'label': t.settings.station.icomControlPort,
        'description': t.settings.station.icomControlPortDescription,
      },
    if (!overrides.containsKey(serialPortConfigKey))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': serialPortConfigKey,
        'label': t.settings.station.icomSerialPort,
        'description': t.settings.station.icomSerialPortDescription,
      },
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
      case controlPortConfigKey:
      case serialPortConfigKey:
        // Absent is a node saved before the fields existed, which connects
        // on the factory port. Present but null is the editor's reading of
        // a field the operator cleared or typed something unparseable into,
        // and connecting that on the factory port would hide the mistake.
        if (value == null && !config.containsKey(key)) return null;
        final port = value is num && value == value.truncate() ? value.toInt() : int.tryParse(value is String ? value.trim() : '');
        if (port == null || port < 1 || port > 65535) return t.settings.station.portInvalid;
        // One port for both opens the serial session on the control one,
        // and the radio answers it with silence.
        final other = key == controlPortConfigKey ? serialPortConfigKey : controlPortConfigKey;
        return port == _port(config, other, other == controlPortConfigKey ? icomControlPort : icomSerialPort) ? t.settings.station.icomPortsDiffer : null;
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
    controlPortConfigKey: _port(config, controlPortConfigKey, icomControlPort),
    serialPortConfigKey: _port(config, serialPortConfigKey, icomSerialPort),
    'username': stringFromConfig(config, 'username').trim(),
    'password': stringFromConfig(config, 'password'),
  };

  @override
  bool isUnconfigured(Map<String, dynamic> config) => blankInConfig(config, 'host');

  /// The host alone while the radio is on its factory port, so the row for
  /// an ordinary LAN radio carries nothing it was not told.
  @override
  String describeTarget(Map<String, dynamic> config) {
    final port = _port(config, controlPortConfigKey, icomControlPort);
    return port == icomControlPort ? trimmedHost(config) : '${trimmedHost(config)}:$port';
  }

  /// A node saved before the port fields existed holds neither, and means
  /// the radio's factory port, which is what every such node has always
  /// connected to. The editor refuses a blank one ([validateField]).
  int _port(Map<String, dynamic> config, String key, int fallback) => blankInConfig(config, key) ? fallback : numberFromConfig(config, key, 0);
}
