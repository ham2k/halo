// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import '../transport.dart';
import 'k4_remote_transport_config.dart';
import 'tcp_transport_config.dart';

class K4RemoteTransport extends EquipmentTransport with TcpTransportConfig, K4RemoteTransportConfig {
  const K4RemoteTransport();

  static const transportKey = 'k4-remote';
  @override
  String get key => transportKey;
  @override
  String get portConfigKey => 'remotePort';
  @override
  bool get isSupportedOnThisPlatform => false;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async =>
      throw UnsupportedError('K4 Remote requires native TCP and TLS support');
}
