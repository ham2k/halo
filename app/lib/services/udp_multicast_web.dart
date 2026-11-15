// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback — see udp_broadcast_web.dart for why this doesn't throw.

import 'udp_datagram.dart';

Stream<UdpDatagram> udpMulticastDatagrams({required int port, required String multicastGroup}) => const Stream.empty();

Future<bool> isThisDevice(String address) async => false;
