// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The io-free half of peer LAN discovery (HALO-310): what a beacon says and
// what a listener hands back. Kept out of the `_io`/`_stub` pair so the stub,
// the tests and any UI can name these types without pulling in `dart:io`.

/// One device announcing "I am here, dial me at this port" — plus which
/// operation it is sharing, if any. Deliberately tiny: a beacon goes out
/// every few seconds to every device on the segment, and it carries no log
/// content — only enough for a listener to decide whether to open a real
/// link, where the handshake and trust check actually happen (see
/// `PeerSession`).
///
/// [address] is never carried IN the payload; it is read from the datagram's
/// sender. A device behind NAT, or one that moved networks since it composed
/// the message, cannot report its own reachable address correctly — the
/// receiving socket always can. (FlexRadio's discovery puts an `ip=` field in
/// the payload precisely because the app's existing UDP helper throws the
/// sender away; this one doesn't, so it doesn't have to.)
class PeerBeacon {
  /// Stable per-install id — the only thing trust is ever keyed on.
  final String deviceId;

  /// Self-asserted, for display beside the id in the pairing prompt. Never
  /// treat it as identity.
  final String deviceName;

  /// Which operation this device is offering to share — null when none is
  /// open. Informational only since sessions bind to the device: nothing
  /// filters on it, and the real sharing state travels in the session's own
  /// `sharing` messages.
  final String? operationUuid;

  /// Where to dial it for the real link.
  final int port;

  /// Filled in from the datagram's sender by [PeerBeaconListener], not from
  /// the payload. Null on a beacon this device composed to send.
  final String? address;

  const PeerBeacon({
    required this.deviceId,
    required this.deviceName,
    this.operationUuid,
    required this.port,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'halo': 'peer',
        'deviceId': deviceId,
        'deviceName': deviceName,
        'operationUuid': ?operationUuid,
        'port': port,
      };

  /// Null for anything that isn't one of ours — the discovery port is shared
  /// with whatever else the operator runs, so a datagram that doesn't parse
  /// is ordinary traffic, not an error.
  static PeerBeacon? fromJson(Map<String, dynamic> json, {String? address}) {
    if (json['halo'] != 'peer') return null;
    final deviceId = json['deviceId'];
    final operationUuid = json['operationUuid'];
    final port = (json['port'] as num?)?.toInt();
    if (deviceId is! String || deviceId.isEmpty) return null;
    if (port == null || port <= 0 || port > 65535) return null;
    return PeerBeacon(
      deviceId: deviceId,
      deviceName: (json['deviceName'] as String?) ?? '',
      operationUuid: operationUuid is String && operationUuid.isNotEmpty ? operationUuid : null,
      port: port,
      address: address,
    );
  }

  PeerBeacon withAddress(String? address) => PeerBeacon(
        deviceId: deviceId,
        deviceName: deviceName,
        operationUuid: operationUuid,
        port: port,
        address: address,
      );
}

/// The default UDP port peer beacons go out on. Not registered with IANA and
/// not configurable yet — if it ever collides with something an operator
/// runs, it becomes a setting rather than a different constant.
const int peerBeaconPort = 7373;

/// Sends and receives [PeerBeacon]s on one shared socket.
///
/// One socket for both directions on purpose: a beacon must be sent FROM the
/// port it is received on, or a peer replying to the datagram's sender would
/// answer an ephemeral port that nothing is listening on.
abstract class PeerBeaconSocket {
  Stream<PeerBeacon> get beacons;

  /// Broadcasts [beacon] to the local segment. Never throws — a send on a
  /// downed interface is normal, and discovery is retried on a timer anyway.
  void announce(PeerBeacon beacon);

  Future<void> close();
}
