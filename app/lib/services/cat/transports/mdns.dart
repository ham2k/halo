// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Browsing for a service by Multicast DNS. Same shape as udp_broadcast.dart:
// on web, which has no sockets, a browse finds nothing.

export 'mdns_web.dart' if (dart.library.io) 'mdns_io.dart';
