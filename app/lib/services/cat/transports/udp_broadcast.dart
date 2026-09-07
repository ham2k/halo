// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Listening for the broadcast announcements equipment makes about itself.
// Same conditional-export shape as tcp_transport.dart — the web build has
// no sockets of any kind.

export 'udp_broadcast_web.dart' if (dart.library.io) 'udp_broadcast_io.dart';
