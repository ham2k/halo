// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Same conditional-export shape as the CAT transports. The stub THROWS
// rather than returning something inert (the tcp_transport_stub.dart
// dialect, not the udp one): discovery finding nothing on web is a normal
// answer, but being asked to open a link there is a caller bug worth
// hearing about.

export 'peer_link_stub.dart' if (dart.library.io) 'peer_link_io.dart';
