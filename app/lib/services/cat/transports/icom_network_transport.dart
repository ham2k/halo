// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An IC-705 (or any RS-BA1-compatible Icom) over WiFi. Same
// conditional-export shape as the TCP and serial transports; the web build
// has no sockets.

export 'icom_network_transport_web.dart' if (dart.library.io) 'icom_network_transport_io.dart';
