// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback — see udp_broadcast_stub.dart for why this doesn't throw.

import 'dart:typed_data';

Stream<Uint8List> udpMulticastDatagrams({required int port, required String multicastGroup}) => const Stream.empty();
