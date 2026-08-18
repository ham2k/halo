// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Peer LAN discovery over UDP broadcast (HALO-310).
//
// Broadcast, not multicast, deliberately: joining a multicast group on iOS
// needs `com.apple.developer.networking.multicast`, which Apple grants case
// by case on application (docs/design/cat.md), and a device that silently
// never sees a group is indistinguishable from one with no peers. Broadcast
// needs no entitlement anywhere. The cost is that it does not cross subnets,
// which peer sync does not need — devices on different networks are the
// relay transport's job, not this one's.
//
// Binding a UDP port is a LISTENING socket, so macOS needs
// `com.apple.security.network.server` in BOTH entitlement files (already
// present, added for CAT discovery — see udp_broadcast_io.dart).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'peer_beacon_types.dart';

/// Opens the shared beacon socket on [port].
///
/// Errors are reported on [PeerBeaconSocket.beacons] rather than thrown, the
/// same contract `udpBroadcastDatagrams` uses: a port held by another app, or
/// a sandbox refusing the bind, must leave the caller with "nothing found"
/// and a reason instead of an exception out of a UI callback.
Future<PeerBeaconSocket> openPeerBeaconSocket({
  int port = peerBeaconPort,
  @visibleForTesting String broadcastAddress = '255.255.255.255',
}) async {
  final RawDatagramSocket socket;
  try {
    socket = await _bind(port);
  } catch (e, st) {
    // Deferred to the FIRST listener rather than added now. A broadcast
    // controller drops anything added while nobody is subscribed, and the
    // caller cannot possibly have subscribed yet — so adding the error here
    // (and closing) discards the only signal that the bind failed, leaving
    // the operator with an empty peer list indistinguishable from an empty
    // room. That is precisely the failure this reports.
    return _DeadBeaconSocket(Stream<PeerBeacon>.error(e, st));
  }
  return _PeerBeaconSocket(socket, StreamController<PeerBeacon>.broadcast(), port, broadcastAddress);
}

class _PeerBeaconSocket implements PeerBeaconSocket {
  _PeerBeaconSocket(this._socket, this._controller, this._port, this._broadcastAddress) {
    _socket.broadcastEnabled = true;
    _socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket.receive();
        if (datagram == null || _controller.isClosed) return;
        final beacon = _parse(datagram.data, datagram.address.address);
        if (beacon != null) _controller.add(beacon);
      },
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  final RawDatagramSocket _socket;
  final StreamController<PeerBeacon> _controller;
  final int _port;

  /// Overridden only by tests, which need a deterministic destination —
  /// a real broadcast may or may not loop back depending on the host's
  /// interfaces, which would make the test pass or fail on the machine
  /// rather than on the code.
  final String _broadcastAddress;
  bool _closed = false;

  @override
  Stream<PeerBeacon> get beacons => _controller.stream;

  @override
  void announce(PeerBeacon beacon) {
    if (_closed) return;
    final payload = utf8.encode(jsonEncode(beacon.toJson()));
    try {
      // 255.255.255.255 rather than a per-interface directed broadcast: the
      // app has no reliable way to enumerate which interface the operator's
      // other device is on (a phone hotspot, a field router, a laptop
      // bridging both), and the limited broadcast address reaches every
      // interface the socket is bound to.
      _socket.send(payload, InternetAddress(_broadcastAddress), _port);
    } catch (e) {
      // Routine, not exceptional: an interface can be down or refuse
      // broadcast between one beacon and the next, and the timer will try
      // again. Reporting it would train the operator to ignore the report.
      debugPrint('[peer] beacon send failed: $e');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _socket.close();
    if (!_controller.isClosed) await _controller.close();
  }
}

/// The bind failed. Holds the error stream so the caller learns why, and
/// makes every other call a no-op — a caller should not have to null-check a
/// socket it was handed.
class _DeadBeaconSocket implements PeerBeaconSocket {
  _DeadBeaconSocket(this.beacons);

  @override
  final Stream<PeerBeacon> beacons;

  @override
  void announce(PeerBeacon beacon) {}

  @override
  Future<void> close() async {}
}

PeerBeacon? _parse(List<int> data, String address) {
  try {
    final decoded = jsonDecode(utf8.decode(data, allowMalformed: true));
    if (decoded is! Map) return null;
    return PeerBeacon.fromJson(decoded.cast<String, dynamic>(), address: address);
  } catch (_) {
    // Anything else sharing this port. Silent on purpose — logging every
    // stray datagram would spam the console for as long as discovery runs.
    return null;
  }
}

Future<RawDatagramSocket> _bind(int port) async {
  // Sharing the port matters: a second HaLo window, or another app listening
  // for the same beacons, must not lock everyone else out. Windows doesn't
  // implement SO_REUSEPORT and throws on it, so fall back rather than lose
  // discovery on that platform entirely (same as udp_broadcast_io.dart).
  try {
    return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true, reusePort: true);
  } catch (e) {
    debugPrint('[peer] SO_REUSEPORT unavailable ($e), binding $port without it');
    return RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
  }
}
