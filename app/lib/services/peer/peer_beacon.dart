// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Same conditional-export shape as udp_broadcast.dart — the web build has no
// sockets of any kind.

export 'peer_beacon_stub.dart' if (dart.library.io) 'peer_beacon_io.dart';
