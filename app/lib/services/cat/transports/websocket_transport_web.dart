// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback. A browser could open the WebSocket, but the web build shows
// no Station Configuration at all, and a page served over HTTPS may not
// reach a `ws://` server on another machine. This throws rather than
// no-opping, for the reason tcp_transport_web.dart gives.

import '../transport.dart';
import 'tcp_transport_config.dart';

class WebSocketTransport extends EquipmentTransport with TcpTransportConfig {
  const WebSocketTransport({this.portConfigKey = 'port', this.connectTimeout = const Duration(seconds: 5)});

  @override
  final String portConfigKey;

  final Duration connectTimeout;

  static const transportKey = 'websocket';

  @override
  String get key => transportKey;

  @override
  bool get isSupportedOnThisPlatform => false;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('CAT control is not available in the web build.');
  }
}
