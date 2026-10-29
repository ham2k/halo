// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback, for tcp_transport_web.dart's reason: a browser has no
// sockets, and reaching this means a platform gate is missing.

import '../transport.dart';
import 'udp_transport_config.dart';

class UdpTransport extends EquipmentTransport with UdpTransportConfig {
  const UdpTransport({required this.portConfigKey, required this.replyPortOffset});

  @override
  final String portConfigKey;

  @override
  final int replyPortOffset;

  static const transportKey = 'udp';

  @override
  String get key => transportKey;

  @override
  bool get isSupportedOnThisPlatform => false;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('CAT control needs raw sockets, which the web build does not have.');
  }
}
