// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Datagrams something else SENDS to this device, on a port of the
// operator's choosing — a phone app pushing its GPS as NMEA. Nothing is sent
// back and nothing is dialled: unlike udp_transport.dart, there is no host.
// The tcp_transport.dart shape: the web build has no sockets, so it gets a
// stub that throws.

export 'udp_listen_transport_web.dart' if (dart.library.io) 'udp_listen_transport_io.dart';
export 'udp_listen_transport_config.dart' show udpListenPortConfigKey;
