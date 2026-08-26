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

import '../../tools/backoff.dart';
import 'peer_beacon_types.dart';

/// Opens the shared beacon socket on [port].
///
/// Errors are reported on [PeerBeaconSocket.beacons] rather than thrown, the
/// same contract `udpBroadcastDatagrams` uses: a port held by another app, or
/// a sandbox refusing the bind, must leave the caller with "nothing found"
/// and a reason instead of an exception out of a UI callback.
///
/// A socket that could not be opened is NOT a dead one. The returned object
/// keeps trying on the same backoff a socket lost mid-session uses, because
/// the two are the same failure and differ only in whether the network
/// happened to be down at the moment the operator turned peer sync on.
Future<PeerBeaconSocket> openPeerBeaconSocket({
  int port = peerBeaconPort,
  @visibleForTesting String broadcastAddress = '255.255.255.255',
  @visibleForTesting DatagramBinder bind = _bind,
}) async {
  final socket = _PeerBeaconSocket(port, broadcastAddress, bind);
  // Awaited so an ordinary open still behaves exactly as it always did: the
  // caller gets a socket that is already bound and listening, not one that
  // will be a tick later.
  await socket.open();
  return socket;
}

/// How this socket gets a [RawDatagramSocket]. The only seam the tests need
/// to drive the retry ladder: a held port, a sandbox denial and an interface
/// that is not up yet all reach this class as a throw from here, and none of
/// them can be produced on demand from a real socket without racing the
/// machine for a port.
typedef DatagramBinder = Future<RawDatagramSocket> Function(int port);

class _PeerBeaconSocket implements PeerBeaconSocket {
  _PeerBeaconSocket(this._port, this._broadcastAddress, this._bind) {
    // Deferred to the FIRST listener rather than added when it happens. A
    // broadcast controller drops anything added while nobody is subscribed,
    // and the opening failure lands before the caller can possibly have
    // subscribed — so adding it there would discard the only signal that the
    // socket never opened, leaving the operator with an empty peer list
    // indistinguishable from an empty room.
    _controller = StreamController<PeerBeacon>.broadcast(onListen: _flushPendingFailure);
  }

  late final StreamController<PeerBeacon> _controller;
  final int _port;

  /// Overridden only by tests, which need a deterministic destination —
  /// a real broadcast may or may not loop back depending on the host's
  /// interfaces, which would make the test pass or fail on the machine
  /// rather than on the code.
  final String _broadcastAddress;

  final DatagramBinder _bind;

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
  String? _bindFailure;

  /// Set by a send, cleared by the failure a send reports. Still set at the
  /// next tick means the previous datagram left the machine — the only
  /// evidence a UDP send ever offers, since a send that works says nothing.
  bool _sentLastTick = false;
  String? _sendFailure;

  /// The two halves of the retry ladder, added together to space attempts.
  ///
  /// Kept apart because they clear on different evidence, and a single
  /// counter gets one of them wrong. Binds clear when one succeeds. Sends
  /// cannot: an outage is a loop of SUCCEEDING binds and failing sends —
  /// binding wants no route, sending does — so a counter that reset on a
  /// bind would sit at the bottom rung rebinding forever while the Wi-Fi is
  /// off. Only [_noteWorking] clears the send half.
  int _bindFailures = 0;
  int _sendFailures = 0;

  Duration get _retryDelay => exponentialBackoff(_bindFailures + _sendFailures, cap: rebindBackoffCap);

  @override
  final List<Duration> retryDelays = [];

  /// The opening failure, held until somebody subscribes.
  Object? _pendingFailure;
  StackTrace? _pendingFailureStack;

  /// The reason last put on [beacons], so an outage is reported once.
  /// [PeerService] uploads a crash report for anything arriving there, and a
  /// ladder that re-reported every rung would rebuild the storm. Keyed on the
  /// reason rather than a flag: a failure that CHANGES — another app taking
  /// the port after a permission denial — is a different fault and has to
  /// get through.
  String? _surfacedFailure;
  bool _closed = false;

  void _flushPendingFailure() {
    final failure = _pendingFailure;
    if (failure == null || _controller.isClosed) return;
    // Held, not dropped, while nobody is listening — which is the state it
    // is written in, and the whole reason it is held at all.
    if (!_controller.hasListener) return;
    _controller.addError(failure, _pendingFailureStack ?? StackTrace.current);
    // Delivered, so a listener that comes and goes is not handed a stale
    // failure again; [_surfacedFailure] is what holds the once-per-outage
    // rule for as long as the outage lasts.
    _pendingFailure = null;
    _pendingFailureStack = null;
  }

  /// The first attempt. Its failure is reported the way every later one is
  /// kept silent — see [_surfacedFailure].
  Future<void> open() => _rebind();

  /// Evidence the socket is doing its job, from either direction: a datagram
  /// that arrived, or one that left without the failure a send reports.
  ///
  /// A RECEIVED datagram counts, and has to. A device whose link server
  /// never bound is never asked to announce at all ([PeerService] suppresses
  /// that tick), and a VPN or an isolating access point can block outbound
  /// broadcast while inbound beacons still arrive — with only sends counting,
  /// both of those pin the ladder at its ceiling for the session and spend it
  /// deaf, over a socket that was receiving the whole time.
  void _noteWorking() {
    if (_sendFailures > 0) {
      debugPrint('[peer] beacon socket working again, after $_sendFailures failed');
    }
    _sendFailures = 0;
    _sendFailure = null;
    _surfacedFailure = null;
  }

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
        if (_sendFailures > 0 || _surfacedFailure != null) _noteWorking();
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
    _bindFailures = 0;
    _pendingFailure = null;
    _pendingFailureStack = null;
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
    // Scheduled, never immediate. A no-route outage is a loop of succeeding
    // binds and failing sends, so a socket rebound the instant it is lost
    // would bind and close one every few seconds for as long as the Wi-Fi is
    // off. The ladder still recovers a one-off loss in a couple of seconds.
    _scheduleRebind();
  }

  /// One attempt at a time, spaced by [_retryDelay]. Rescheduled from the end
  /// of each attempt rather than run on a period: an attempt that outlasts
  /// its own interval would otherwise queue the next one behind it.
  void _scheduleRebind() {
    if (_closed || _socket != null || _rebindTimer != null) return;
    final delay = _retryDelay;
    retryDelays.add(delay);
    _rebindTimer = Timer(delay, () {
      _rebindTimer = null;
      unawaited(_rebind());
    });
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
  /// succeeds even with no route, so the send fails again on the next tick
  /// for as long as the outage lasts. Logging each round would bury
  /// everything else the console is for.
  void _onSocketError(RawDatagramSocket socket, Object e, StackTrace st) {
    if (e is SocketException && e.message == 'Send failed') {
      // Counted BEFORE the release, so the ladder this loss schedules is
      // spaced by the failure that caused it rather than by the one before.
      _noteSendFailure(e);
      _release(socket);
      return;
    }
    _release(socket);
    // Anything else is a receive-side failure the operator's peer list is
    // silently wrong about, so it still travels to the listener — a rebind
    // may follow it, but the reason must be visible either way.
    if (!_controller.isClosed) _controller.addError(e, st);
  }

  void _noteSendFailure(Object e) {
    _sendFailures++;
    if (_sendFailure == e.toString()) return;
    _sendFailure = e.toString();
    debugPrint('[peer] beacon send failed: $e');
  }

  /// Both halves of getting a socket — the bind and the attach — because
  /// they fail the same way from the operator's side: no discovery. Retrying
  /// only the bind would leave a sandbox's SO_BROADCAST refusal ending
  /// discovery for the session, while the identical outcome one line earlier
  /// recovers on its own.
  Future<void> _rebind() async {
    if (_rebinding || _closed || _socket != null) return;
    _rebinding = true;
    // Held until [_attach] has taken it over, so a bind that succeeds into a
    // closed socket — or an attach that throws — closes rather than leaks it.
    RawDatagramSocket? bound;
    var stage = 'bind';
    try {
      bound = await _bind(_port);
      if (_closed) return;
      stage = 'broadcast';
      _attach(bound);
      bound = null;
      // Only after a failure the console was told about. A rebind is the
      // ordinary second half of every send failure, and announcing each one
      // would restore the per-tick spam the line above exists to avoid.
      if (_bindFailure != null) {
        _bindFailure = null;
        debugPrint('[peer] beacon socket bound again on $_port');
      }
    } catch (e, st) {
      _bindFailures++;
      // The reason travels to the listener once per outage — the operator
      // needs to know why their peer list is empty, and needs to be told
      // that once rather than at every rung of the ladder.
      if (_surfacedFailure != e.toString()) {
        _surfacedFailure = e.toString();
        _pendingFailure = e;
        _pendingFailureStack = st;
        _flushPendingFailure();
      }
      // Which half refused matters to whoever is reading: a port another app
      // holds and a sandbox denying SO_BROADCAST are different problems with
      // different remedies, and the exception text alone does not say which.
      if (_bindFailure != e.toString()) {
        _bindFailure = e.toString();
        debugPrint('[peer] beacon socket $stage failed: $e');
      }
    } finally {
      bound?.close();
      _rebinding = false;
      _scheduleRebind();
    }
  }

  @override
  Stream<PeerBeacon> get beacons => _controller.stream;

  /// Bound and listening. NOT a claim that anything is getting through: a
  /// send can still fail over a perfectly healthy socket, which is what the
  /// send half of the ladder is for.
  @override
  bool get healthy => _socket != null;

  @override
  void announce(PeerBeacon beacon) {
    if (_closed) return;
    final socket = _socket;
    if (socket == null) return; // the retry ladder is already on it
    if (_sentLastTick) _noteWorking();
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
      // The synchronous half of the same failure dart:io usually reports
      // asynchronously, and it gets the same accounting: deduped, counted
      // into the ladder, and the socket given up so something rebinds it.
      // Left to itself it would print every announce tick over a socket
      // nothing could send on.
      _noteSendFailure(e);
      _release(socket);
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
    // Once per process: Windows refuses SO_REUSEPORT every single time, and
    // the ladder would otherwise print this at every rung of every outage.
    if (!_reusePortReported) {
      _reusePortReported = true;
      debugPrint('[peer] SO_REUSEPORT unavailable ($e), binding $port without it');
    }
    return RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
  }
}

bool _reusePortReported = false;
