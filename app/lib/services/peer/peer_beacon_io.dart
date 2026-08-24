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
  _PeerBeaconSocket(RawDatagramSocket socket, this._controller, this._port, this._broadcastAddress) {
    _attach(socket);
  }

  final StreamController<PeerBeacon> _controller;
  final int _port;

  /// Overridden only by tests, which need a deterministic destination —
  /// a real broadcast may or may not loop back depending on the host's
  /// interfaces, which would make the test pass or fail on the machine
  /// rather than on the code.
  final String _broadcastAddress;

  /// Null between losing a socket and getting one back. dart:io closes a
  /// datagram socket after ANY error event of its own, so the socket this
  /// class holds is not the one it was handed for the whole of its life.
  RawDatagramSocket? _socket;

  /// Runs only while the socket is missing. A timer of its own rather than
  /// the caller's announce tick: [PeerService] suppresses that tick entirely
  /// when its link server has no port — a device that can still HEAR peers —
  /// and a rebind driven by it would never run in exactly that state.
  Timer? _rebindTimer;
  bool _rebinding = false;
  String? _rebindFailure;

  /// Set by a send, cleared by the failure a send reports. Still set at the
  /// next tick means the previous datagram left the machine — the only
  /// evidence of a working send there is, since a UDP send that succeeds
  /// says nothing at all.
  bool _sentLastTick = false;
  int _sendFailures = 0;
  String? _sendFailure;
  bool _closed = false;

  void _attach(RawDatagramSocket socket) {
    // Published only once the socket is both broadcast-enabled and listened
    // to. Either step can throw — a sandbox refusing SO_BROADCAST is the
    // documented one — and a half-attached socket left in [_socket] would be
    // sent on for the rest of the session while nothing ever received on it.
    socket.broadcastEnabled = true;
    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null || _controller.isClosed) return;
        final beacon = _parse(datagram.data, datagram.address.address);
        if (beacon != null) _controller.add(beacon);
      },
      onError: (Object e, StackTrace st) => _onSocketError(socket, e, st),
      // Never closes the controller: the socket is replaceable, the
      // listener's subscription is not. Only [close] ends discovery.
      onDone: () => _release(socket),
    );
    _socket = socket;
    _rebindTimer?.cancel();
    _rebindTimer = null;
  }

  /// Drops [socket] if it is still the live one, and starts trying to
  /// replace it. dart:io closes a socket after reporting an error on it, so
  /// a superseded socket's `onDone` can land after a replacement is
  /// attached — clearing the field then would discard a working socket that
  /// nothing would ever close.
  void _release(RawDatagramSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    _sentLastTick = false;
    if (_closed || _rebindTimer != null) return;
    _rebindTimer = Timer.periodic(rebindInterval, (_) => unawaited(_rebind()));
    unawaited(_rebind());
  }

  /// dart:io does not throw a UDP send failure out of `send()` — it reports
  /// it here, on the socket's error handler, and closes the socket behind
  /// it. So a moment without a route (Wi-Fi off, a VPN coming up, a laptop
  /// between networks) does not merely lose one beacon: it leaves the device
  /// deaf until something binds again, which is what [_release] starts.
  ///
  /// Console only, and only while the operator has peer sync switched on —
  /// which is to say only while they are actively trying to link two
  /// devices, where "no route to the segment" is the first thing worth
  /// knowing. It is not a defect, not actionable beyond fixing the network,
  /// and a notice for every downed interface would train the operator to
  /// dismiss the ones that matter.
  ///
  /// One line per outage, not one per attempt: the rebind that follows
  /// succeeds even with no route (binding wants no route, sending does), so
  /// the send fails again on the next tick for as long as the outage lasts.
  /// Logging each round would bury everything else the console is for.
  void _onSocketError(RawDatagramSocket socket, Object e, StackTrace st) {
    _release(socket);
    if (e is SocketException && e.message == 'Send failed') {
      _sendFailures++;
      if (_sendFailure != e.toString()) {
        _sendFailure = e.toString();
        debugPrint('[peer] beacon send failed: $e');
      }
      return;
    }
    // Anything else is a receive-side failure the operator's peer list is
    // silently wrong about, so it still travels to the listener — a rebind
    // may follow it, but the reason must be visible either way.
    if (!_controller.isClosed) _controller.addError(e, st);
  }

  Future<void> _rebind() async {
    if (_rebinding || _closed || _socket != null) return;
    _rebinding = true;
    // Held until [_attach] has taken it over, so a bind that succeeds into a
    // closed socket — or an attach that throws — closes rather than leaks it.
    RawDatagramSocket? bound;
    try {
      bound = await _bind(_port);
      if (_closed) return;
      _attach(bound);
      bound = null;
      // Only after a failure the console was told about. A rebind is the
      // ordinary second half of every send failure, and announcing each one
      // would restore the per-tick spam the line above exists to avoid.
      if (_rebindFailure != null) {
        _rebindFailure = null;
        debugPrint('[peer] beacon socket bound again on $_port');
      }
    } catch (e) {
      // Keyed on the reason, so a failure that CHANGES — a port grabbed by
      // another app after a permission denial — still says so.
      if (_rebindFailure != e.toString()) {
        _rebindFailure = e.toString();
        debugPrint('[peer] beacon socket rebind failed: $e');
      }
    } finally {
      bound?.close();
      _rebinding = false;
    }
  }

  @override
  Stream<PeerBeacon> get beacons => _controller.stream;

  @override
  bool get healthy => _socket != null;

  @override
  void announce(PeerBeacon beacon) {
    if (_closed) return;
    final socket = _socket;
    if (socket == null) return; // the rebind timer is already on it
    if (_sentLastTick && _sendFailures > 0) {
      debugPrint('[peer] beacon sending again, after $_sendFailures failed');
      _sendFailures = 0;
      _sendFailure = null;
    }
    final payload = utf8.encode(jsonEncode(beacon.toJson()));
    try {
      // 255.255.255.255 rather than a per-interface directed broadcast: the
      // app has no reliable way to enumerate which interface the operator's
      // other device is on (a phone hotspot, a field router, a laptop
      // bridging both), and the limited broadcast address reaches every
      // interface the socket is bound to.
      socket.send(payload, InternetAddress(_broadcastAddress), _port);
      _sentLastTick = true;
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
    _rebindTimer?.cancel();
    _rebindTimer = null;
    _socket?.close();
    _socket = null;
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
  bool get healthy => false;

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
