// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Datagrams to a host and port, and the replies a program sends back —
// either to a fixed port of its own choosing (PstRotator's UDP Control
// answers on the port after the one it listens on) or to whichever port the
// command came from (a BuddiHex rotator). The tcp_transport.dart shape: the
// web build has no sockets, so it gets a stub that throws.

export 'udp_transport_web.dart' if (dart.library.io) 'udp_transport_io.dart';
