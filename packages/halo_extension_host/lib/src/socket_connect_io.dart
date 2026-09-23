// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects an extension's socket, stamping HaLo's canonical [userAgent] on
/// the handshake as host.fetch does on every request (docs/design/network.md).
///
/// Set on the client rather than passed as a header: dart:io adds its own
/// `Dart/x (dart:io)` agent to any header given, so the server would see both.
WebSocketChannel connectExtensionSocket(Uri uri, {List<String>? protocols, String? userAgent}) =>
    IOWebSocketChannel.connect(uri, protocols: protocols, customClient: userAgent == null ? null : (HttpClient()..userAgent = userAgent));
