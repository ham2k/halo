// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback, for tcp_transport_web.dart's reason: a browser has no
// sockets, and reaching this means a platform gate is missing.

import '../transport.dart';
import 'udp_listen_transport_config.dart';

class UdpListenTransport extends EquipmentTransport with UdpListenTransportConfig {
  const UdpListenTransport();

  static const transportKey = 'udpListen';

  @override
  String get key => transportKey;

  @override
  bool get isSupportedOnThisPlatform => false;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('Listening for datagrams needs raw sockets, which the web build does not have.');
  }
}
