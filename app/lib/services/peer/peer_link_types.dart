// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The io-free half of the peer link listener (HALO-310), split out for the
// same reason `peer_beacon_types.dart` is: the `_io`/`_stub` pair, the tests
// and `PeerService` all need to NAME these types, and only one of them may
// pull in `dart:io`.
//
// `PeerLink` itself lives in halo_core — it is what `PeerSession` speaks, so
// it belongs beside the session rather than beside the socket.

import 'package:halo_core/halo_core.dart';

/// A media link and the ticket it presented (HALO-369).
///
/// The media path carries no `hello` and cannot be admitted the way the
/// control link is, so it arrives bearing a one-time ticket the control
/// link — which IS trusted and established — handed out. The server does not
/// judge the ticket; it hands both to whoever minted it.
class PeerMediaConnection {
  final String ticket;
  final PeerLink link;

  const PeerMediaConnection({required this.ticket, required this.link});
}

/// A media link that would not open (HALO-369), with what the dial said.
/// The wrapper is what scopes `ErrorPolicy`'s `peer-media-unreachable`
/// rule to a dial: a bare `SocketException` from anywhere else has no peer
/// to blame.
class PeerMediaDialFailure implements Exception {
  final String peerDeviceId;
  final Object cause;

  const PeerMediaDialFailure(this.peerDeviceId, this.cause);

  @override
  String toString() => 'Media link to $peerDeviceId failed: $cause';
}

/// Accepts incoming peer links, however they arrive.
///
/// An interface rather than the WebSocket class itself so a test can hand
/// `PeerService` a listener with no socket under it. The LAN implementation
/// is `WebSocketPeerLinkServer`; BLE links do not come through here at all
/// (they arrive already-established from `PeerBleTransport`).
///
/// The media PATH and ping interval are deliberately not here: they are wire
/// details of the WebSocket implementation, and nothing outside it needs to
/// name them.
abstract class PeerLinkServer {
  /// What to publish in the beacon, so a peer knows where to dial.
  int get port;

  Stream<PeerLink> get connections;

  /// Inbound media links, each with the ticket it presented.
  Stream<PeerMediaConnection> get mediaConnections;

  Future<void> close();
}
