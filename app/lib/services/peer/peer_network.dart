// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Everything peer sync asks of the network, in one place (HALO-310), so a
// test can hand `PeerService` a LAN with no sockets under it.
//
// One interface rather than three injected functions because the three are
// not independent: a beacon advertises the port the link server bound, and a
// dial goes to a port some other device's beacon advertised. A fake that
// implements them together can wire that up; three separate seams leave each
// test re-deriving the same plumbing.
//
// BLE is deliberately NOT here. Its links arrive already-established from
// `PeerBleTransport`, which has its own gateway seam and its own fakes
// (`peer_ble_fakes.dart`) — folding both transports into one interface would
// give every LAN test a Bluetooth stack to stub out.

import 'package:halo_core/halo_core.dart';

import 'peer_beacon.dart';
import 'peer_beacon_types.dart';
import 'peer_link.dart';

abstract class PeerNetwork {
  /// Never throws: a port another app holds, or a sandbox refusing the bind,
  /// leaves the caller with a socket that reports the reason on its stream
  /// and keeps retrying. See `openPeerBeaconSocket`.
  Future<PeerBeaconSocket> openBeaconSocket({required int port});

  /// Throws if nothing can be bound — a device that cannot listen can still
  /// dial out, but the caller has to know so it can say so.
  Future<PeerLinkServer> bindLinkServer();

  Future<PeerLink> dial(String address, int port);
}

/// The real one: UDP broadcast for discovery, WebSocket over TCP for links.
class RealPeerNetwork implements PeerNetwork {
  const RealPeerNetwork();

  @override
  Future<PeerBeaconSocket> openBeaconSocket({required int port}) => openPeerBeaconSocket(port: port);

  @override
  Future<PeerLinkServer> bindLinkServer() => bindPeerLinkServer();

  @override
  Future<PeerLink> dial(String address, int port) => dialPeerLink(address, port);
}
