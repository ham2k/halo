// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// See peer_link.dart for why this throws rather than no-ops.

import 'package:halo_core/halo_core.dart';

import 'peer_link_types.dart';

Future<PeerLinkServer> bindPeerLinkServer({int port = 0}) =>
    throw UnsupportedError('Peer links need dart:io');

Future<PeerLink> dialPeerLink(
  String address,
  int port, {
  Duration timeout = const Duration(seconds: 5),
  String? mediaTicket,
}) =>
    throw UnsupportedError('Peer links need dart:io');
