// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The plugin-free face of BLE for the peer transport (HALO-342). Everything
// `PeerBleTransport` decides — who to connect to, when, what the handshake
// means — happens against this interface, so a fake pair of gateways wired
// back-to-back can run the whole transport in a plain unit test. The one
// real implementation (`peer_ble_io.dart`) is deliberately mechanical:
// plugin calls in, events out, no policy.
//
// Both roles live on one gateway because both run at once: every device
// advertises (peripheral) AND scans (central), and either side of a pair
// may end up connecting. The underlying plugin APIs are process-global
// singletons, so there is exactly one gateway per app — the transport, not
// the gateway, keys state per peer.

import 'dart:typed_data';

/// The service and characteristic UUIDs of the HaLo peer pipe. NUS-shaped —
/// a write characteristic in, a notify characteristic out — under UUIDs of
/// our own: the advertised service UUID doubles as the scan filter, so
/// borrowing Nordic's would make every real UART gadget a false positive.
const String peerBleServiceUuid = '1cec4c5f-355c-4fd1-9e97-921c328b59cd';

/// Central → peripheral, write-without-response.
const String peerBleRxUuid = '322d096e-8dfc-4d0c-8432-c4b3d1348aee';

/// Peripheral → central, notify.
const String peerBleTxUuid = '562ee8a0-8848-43b5-b4d4-abaa07a2f39f';

/// What the radio can do right now, per role.
class PeerBleReadiness {
  const PeerBleReadiness({required this.canCentral, required this.canPeripheral, this.problem});

  final bool canCentral;
  final bool canPeripheral;

  /// Operator-readable reason when a role (or the whole radio) is out —
  /// powered off, permission denied, hardware absent.
  final String? problem;

  bool get usable => canCentral || canPeripheral;
}

/// A device seen advertising the peer service.
class PeerBleSighting {
  const PeerBleSighting({required this.addressId, this.nameHint});

  /// The platform's handle for the advertiser — an address on Android, an
  /// opaque UUID on Apple platforms. NOT the peer's device id: addresses
  /// rotate (RPA), so identity only exists after the protocol hello.
  final String addressId;

  /// The advertised local name, if the scan caught one. Carries the
  /// device-id token this transport advertises — a routing hint only,
  /// never identity.
  final String? nameHint;
}

/// Events from the peripheral (server) role.
sealed class PeerBleServerEvent {
  const PeerBleServerEvent(this.centralId);

  /// The platform's handle for the connected central.
  final String centralId;
}

/// A central subscribed to the TX characteristic — the moment a link can
/// start talking to it.
class PeerBleCentralSubscribed extends PeerBleServerEvent {
  const PeerBleCentralSubscribed(super.centralId);
}

/// The central unsubscribed or dropped the connection. May arrive more than
/// once for one central (a CCCD write and a disconnect both report it);
/// consumers treat it as idempotent.
class PeerBleCentralUnsubscribed extends PeerBleServerEvent {
  const PeerBleCentralUnsubscribed(super.centralId);
}

/// Bytes a central wrote to the RX characteristic.
class PeerBleWriteReceived extends PeerBleServerEvent {
  const PeerBleWriteReceived(super.centralId, this.value);

  final Uint8List value;
}

/// One established central-side connection, subscribed and ready to talk.
abstract class PeerBleClientConnection {
  /// Largest packet this side believes the link carries, from the
  /// negotiated MTU. A view, not a guarantee — the frame layer's HELLO
  /// min-exchange is what makes it safe.
  int get chunkLimit;

  /// Packets the peripheral notified. One element per notification.
  Stream<Uint8List> get notifications;

  /// Writes one packet, without response. Completes when the local stack
  /// accepted it — which is real pacing on both platforms — and throws when
  /// the link is gone; the caller closes on failure.
  Future<void> write(Uint8List packet);

  /// Completes when the connection drops, however it drops. Never an error.
  Future<void> get disconnected;

  /// Idempotent; tolerates an already-dead connection.
  Future<void> disconnect();
}

abstract class PeerBleGateway {
  /// Checks availability and permissions for both roles, prompting the OS
  /// permission dialogs if [requestPermission] — the sub-switch turning on
  /// is the consent for that prompt, so only that path passes true.
  Future<PeerBleReadiness> prepare({required bool requestPermission});

  /// Fires when the radio's availability may have changed (Bluetooth
  /// toggled, permission granted elsewhere). The transport re-prepares and
  /// reconciles; the event carries nothing.
  Stream<void> get availabilityChanged;

  // ---- peripheral role ----

  /// Registers the peer service and starts advertising it, with [localName]
  /// as the advertised name. Idempotent per start/stop pairing.
  Future<void> startServer({required String localName});

  Future<void> stopServer();

  Stream<PeerBleServerEvent> get serverEvents;

  /// Notifies one packet to one subscribed central. Completion does NOT
  /// mean delivery (the notify path has no native backpressure) — the frame
  /// layer's window is the guarantee.
  Future<void> notify(String centralId, Uint8List packet);

  /// This side's packet-size view for notifications to [centralId].
  Future<int> serverChunkLimit(String centralId);

  /// Drops one central, if the platform can. Best-effort: a central that
  /// will not leave is handled by the link going silent.
  Future<void> disconnectCentral(String centralId);

  // ---- central role ----

  /// Scans for the peer service. Sightings repeat while the peer stays in
  /// range; the transport dedupes.
  Future<void> startScan();

  Future<void> stopScan();

  Stream<PeerBleSighting> get sightings;

  /// Connects, negotiates MTU, verifies the peer service, and subscribes to
  /// TX. Throws on any failure, fully cleaned up.
  Future<PeerBleClientConnection> connect(String addressId);
}
