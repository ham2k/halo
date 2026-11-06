// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A WebSocket to a program that serves its radio over one — TCI, as Thetis
// and ExpertSDR3 serve it. Same conditional-export shape as tcp_transport.dart:
// the web build shows no CAT at all, so it gets a stub that throws.

export 'websocket_transport_web.dart' if (dart.library.io) 'websocket_transport_io.dart';
