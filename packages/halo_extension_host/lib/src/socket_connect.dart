// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects an extension's socket. A browser lets no page set the handshake's
/// `User-Agent`, so [userAgent] is dropped here; socket_connect_io.dart sends
/// it everywhere else (docs/design/network.md).
WebSocketChannel connectExtensionSocket(Uri uri, {List<String>? protocols, String? userAgent}) => WebSocketChannel.connect(uri, protocols: protocols);
