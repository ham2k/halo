// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback. Throws rather than no-opping, per the convention
// web_download_io.dart states — reaching it means a platform gate is
// missing, and a silent no-op would present a radio as merely "not
// connected" forever.

import '../transport.dart';
import 'icom_network_transport_config.dart';

class IcomNetworkTransport extends EquipmentTransport with IcomNetworkTransportConfig {
  const IcomNetworkTransport();

  static const transportKey = 'icom-network';

  @override
  String get key => transportKey;

  @override
  bool get isSupportedOnThisPlatform => false;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('CAT over WiFi needs UDP sockets, which the web build does not have.');
  }
}
