// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a Green Heron Everyware server and its devices are reached
// (docs/design/cat.md § Green Heron Everyware): the server over plain TCP
// with an optional login, and each device through its server's connection.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:halo_i18n/halo_i18n.dart';

import '../drivers/everyware_server.dart';
import '../transport.dart';
import 'tcp_transport.dart';

/// TCP, plus the login a server with authentication on asks for. Its own
/// key rather than plain `tcp`: the password is a secret, and which fields
/// are secret is the transport's to say.
class EverywareServerTransport extends TcpTransport {
  static const transportKey = 'gh-everyware';

  const EverywareServerTransport();

  @override
  String get key => transportKey;

  @override
  Set<String> get secretFields => const {everywarePasswordConfigKey};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    final st = t.settings.station;
    return [
      ...super.configElements(overrides: overrides, restrictions: restrictions),
      {'type': 'field', 'fieldType': 'text', 'key': everywareUserConfigKey, 'label': st.everywareUser, 'description': st.everywareUserDescription},
      {'type': 'field', 'fieldType': 'secret', 'key': everywarePasswordConfigKey, 'label': st.everywarePassword},
    ];
  }
}

/// A device's connection is a share of its server's, which CatService hands
/// it; nothing here opens anything.
class EverywareDeviceTransport extends EquipmentTransport {
  static const transportKey = 'gh-everyware-device';

  const EverywareDeviceTransport();

  @override
  String get key => transportKey;

  /// As its server's: the web build has no sockets.
  @override
  bool get isSupportedOnThisPlatform => !kIsWeb;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('an Everyware device is reached through its server');
  }
}
