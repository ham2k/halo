// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects an extension's socket, stamping HaLo's canonical [userAgent] on
/// the handshake as host.fetch does on every request (docs/design/network.md).
///
/// Set on the client rather than passed as a header: dart:io adds its own
/// `Dart/x (dart:io)` agent to any header given, so the server would see both.
///
/// The handshake is an ordinary GET, and dart:io follows a redirect on it,
/// headers and all: an admitted host answering 3xx would move the socket to
/// a host and scheme nobody judged. Every connection the client opens is
/// pinned to the host and port that were ([handshakeConnection]), so a
/// redirect anywhere else fails to connect.
WebSocketChannel connectExtensionSocket(Uri uri, {List<String>? protocols, String? userAgent}) {
  final client = HttpClient()..connectionFactory = (url, proxyHost, proxyPort) => handshakeConnection(uri, url, proxyHost, proxyPort);
  if (userAgent != null) client.userAgent = userAgent;
  return IOWebSocketChannel.connect(uri, protocols: protocols, customClient: client);
}

/// The connection the handshake of a socket to [judged] opens for [url]: to
/// [url] only while it is still [judged]'s host and port, through the
/// operator's proxy when there is one.
Future<ConnectionTask<Socket>> handshakeConnection(Uri judged, Uri url, String? proxyHost, int? proxyPort) {
  final port = handshakePort(url);
  if (url.host != judged.host || port != handshakePort(judged)) {
    return Future.error(SocketException("socket refused: '${judged.host}' redirected the handshake to '${url.host}:$port'"));
  }
  if (proxyHost != null) return Socket.startConnect(proxyHost, proxyPort!);
  return url.scheme == 'https' ? SecureSocket.startConnect(url.host, port) : Socket.startConnect(url.host, port);
}

/// [url]'s port, its scheme's own when it names none. `Uri` knows no default
/// for `ws` and `wss`, so `wss://host/` reads as port 0, and dart:io hands
/// the factory `https://host:0/`: connecting there fails every socket that
/// names no port.
@visibleForTesting
int handshakePort(Uri url) => url.port != 0 ? url.port : (url.scheme == 'https' || url.scheme == 'wss' ? 443 : 80);
