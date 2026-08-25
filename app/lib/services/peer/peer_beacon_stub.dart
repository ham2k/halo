// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web has no sockets. Silent-empty rather than throwing, matching
// udp_broadcast_stub.dart: a browser build has no LAN peers, which is
// "nothing found" — the same answer a desktop gets on a network with no
// other devices — not a defect the caller must guard against.

import 'dart:async';

import 'peer_beacon_types.dart';

Future<PeerBeaconSocket> openPeerBeaconSocket({int port = peerBeaconPort}) async => _StubBeaconSocket();

class _StubBeaconSocket implements PeerBeaconSocket {
  @override
  Stream<PeerBeacon> get beacons => const Stream.empty();

  /// Never — web has no socket to lose, and a caller retiring an error on
  /// the strength of this would be retiring it on nothing.
  @override
  bool get healthy => false;

  /// Nothing is ever attempted, so nothing is ever waited.
  @override
  List<Duration> get retryDelays => const [];

  @override
  void announce(PeerBeacon beacon) {}

  @override
  Future<void> close() async {}
}
