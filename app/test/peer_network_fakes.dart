// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A fake LAN for the peer transport tests (HALO-310): datagram sockets and
// links wired back-to-back in memory, with the event ordering and failure
// shapes dart:io actually produces. Same intent as `peer_ble_fakes.dart` —
// these exist so the transport's POLICY (the retry ladder, the dedup of
// reported failures, dial/teardown ordering) is testable without the machine
// having a say in it.
//
// WHY, rather than real loopback sockets: forcing a bind to fail means
// holding the port first, and the port has to be guessed free. Releasing it
// again is a race against everything else on the box, which surfaces as
// `Address already in use` escaping as an unhandled async error — and the
// retry ladder that outlives its own test then reports into whichever test
// runs next. Both were live flakes here.
//
// The fake is deliberately at the `RawDatagramSocket` level, not the
// `PeerBeaconSocket` level: the ladder is the thing under test, so the tests
// run the REAL `_PeerBeaconSocket` over fake sockets rather than a
// reimplementation of its behaviour that could agree with itself while the
// shipping code is wrong.
//
// What it deliberately does NOT model: datagram loss and reordering (UDP
// allows both; nothing in the beacon protocol depends on either, since a
// dropped beacon is covered by the next one three seconds later), MTU
// limits, partial WebSocket frames, or real address/routing semantics — a
// send reaches every socket bound on the port, or fails, and there is no
// third answer. `peer_transport_test.dart` keeps a small real-socket group
// pinning the dart:io facts this file assumes.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
// The `_io` halves directly, not the conditional-export façades: these fakes
// only ever run on the VM, and the façade resolves to the web stub under
// analysis — which has neither the test seams nor a socket.
import 'package:ham2k_logger/services/peer/peer_beacon_io.dart';
import 'package:ham2k_logger/services/peer/peer_beacon_types.dart';
import 'package:ham2k_logger/services/peer/peer_link_types.dart';
import 'package:ham2k_logger/services/peer/peer_network.dart';

/// The beacon port every test on a fake segment uses. A fixed number is safe
/// — and a real one would not be — because the segment is in memory: nothing
/// outside the test can hold it, and nothing outside the test can take it
/// back. Shared from here so the test files cannot drift apart, which would
/// make a `sendRaw` land on a port nobody is listening to and pass vacuously.
const fakeBeaconPort = peerBeaconPort;

/// One in-memory network segment. Every [FakeHost] on it can hear every
/// other's broadcasts and dial every other's links.
class FakeLan {
  final List<_FakeDatagramSocket> _bound = [];

  /// Keyed by address AND port, so a dial to the right port at the WRONG
  /// address finds nothing — the beacon carries an address precisely so a
  /// peer knows where to dial, and a fake that ignored it would let a
  /// misdirected dial connect anyway.
  final Map<String, _FakeLinkServer> _linkServers = {};

  /// Ports that refuse a bind, the way a port another app holds does.
  /// Held/released explicitly rather than by binding a real socket, which is
  /// the race this whole file exists to remove.
  final Set<int> _heldPorts = {};

  int _nextHost = 1;
  int _nextLinkPort = 41000;

  /// Datagram sockets currently bound, across every host. What proves a
  /// teardown actually RELEASED its socket rather than merely dropping the
  /// reference — over a fake segment no later bind can fail, so "starting
  /// again works" is no longer evidence that anything was let go.
  int get openSockets => _bound.where((s) => !s._closed).length;

  /// Link servers still accepting, across every host. Same reasoning:
  /// `bindLinkServer` hands out a fresh port every time, so a leaked server
  /// is invisible to anything but a count.
  int get openLinkServers => _linkServers.values.where((s) => !s._closed).length;

  /// A device on this segment. The address is what its beacons arrive
  /// carrying, so tests can tell two devices apart the way `PeerService`
  /// does when it decides where to dial.
  FakeHost host({String? address}) => FakeHost._(this, address ?? '10.0.0.${_nextHost++}');

  /// Makes [port] refuse every bind until [releasePort]. The deterministic
  /// stand-in for the field cases: a sandbox denial, a port another program
  /// owns, an interface not up yet.
  void holdPort(int port) => _heldPorts.add(port);

  void releasePort(int port) => _heldPorts.remove(port);

  /// Puts [payload] on [port] as if some other program on the segment had
  /// sent it. Nothing here is a HaLo, so there is no socket to bind — which
  /// is the point: the discovery port is shared with whatever else the
  /// operator runs.
  void sendRaw(List<int> payload, {required int port, String from = '10.0.0.254', int fromPort = 5000}) {
    _deliverTo(payload, port, InternetAddress(from), fromPort);
  }

  void _deliver(_FakeDatagramSocket from, List<int> payload, int port) {
    // Every socket on the port, the sender included: a broadcast loops back
    // to the sending host's own sockets, which is why `PeerService` has to
    // drop beacons carrying its own device id ("our own, heard back").
    _deliverTo(payload, port, InternetAddress(from.host.address), from.port);
  }

  void _deliverTo(List<int> payload, int port, InternetAddress from, int fromPort) {
    for (final socket in _bound.toList()) {
      if (socket.port != port || socket._closed) continue;
      socket._enqueue(Datagram(Uint8List.fromList(payload), from, fromPort));
    }
  }
}

/// One device's view of the segment: where its datagrams come from, and the
/// [PeerNetwork] to hand its `PeerService`.
class FakeHost {
  FakeHost._(this.lan, this.address);

  final FakeLan lan;
  final String address;

  /// Sends from this host fail, the way they do with no route to the
  /// segment — a VPN holding the default route, an access point isolating
  /// its clients, Wi-Fi simply off.
  ///
  /// Failing SENDS while binds still succeed is the combination worth
  /// modelling: it is the one an outage actually produces, and the one that
  /// tells a single retry counter from the two the socket really keeps.
  bool sendsFail = false;

  /// Whether a failing send throws from `send()` or arrives on the socket's
  /// error handler. dart:io does the latter for a downed interface, which is
  /// the path `_onSocketError` exists for; the synchronous throw is the
  /// rarer shape `announce`'s try/catch covers.
  bool sendsFailSynchronously = false;

  /// Enabling broadcast on a freshly bound socket throws — a sandbox refusing
  /// SO_BROADCAST, which `_PeerBeaconSocket._rebind` tracks as its own
  /// `stage` because it has a different remedy from a port another app holds.
  /// The bind SUCCEEDS and the attach fails, which is the half a held port
  /// cannot reach.
  bool broadcastRefused = false;

  /// Hand this to `openPeerBeaconSocket(bind: host.binder)` to run the real
  /// beacon socket, retry ladder and all, over the fake segment.
  Future<RawDatagramSocket> binder(int port) async {
    if (lan._heldPorts.contains(port)) {
      throw SocketException(
        'Failed to create datagram socket',
        osError: const OSError('Address already in use', 48),
        address: InternetAddress.anyIPv4,
        port: port,
      );
    }
    final socket = _FakeDatagramSocket(this, port);
    lan._bound.add(socket);
    return socket;
  }

  /// What `PeerService` takes. Beacons run the real socket over [binder];
  /// links are wired straight through the segment.
  PeerNetwork get network => _FakePeerNetwork(this);
}

class _FakePeerNetwork implements PeerNetwork {
  _FakePeerNetwork(this.host);

  final FakeHost host;

  @override
  Future<PeerBeaconSocket> openBeaconSocket({required int port}) =>
      // The REAL socket, over a fake binder — see the file header.
      openPeerBeaconSocket(port: port, broadcastAddress: host.address, bind: host.binder);

  @override
  Future<PeerLinkServer> bindLinkServer() async {
    final port = host.lan._nextLinkPort++;
    final server = _FakeLinkServer(port);
    host.lan._linkServers['${host.address}:$port'] = server;
    return server;
  }

  @override
  Future<PeerLink> dial(String address, int port) async {
    final server = host.lan._linkServers['$address:$port'];
    // Nothing listening answers the way a dial to a peer that has left does:
    // an exception, not a link that never delivers.
    if (server == null || server._closed) {
      throw SocketException('Connection refused', address: InternetAddress(address), port: port);
    }
    final (dialled, accepted) = _linkPair();
    server._accept(accepted);
    return dialled;
  }
}

class _FakeDatagramSocket extends Stream<RawSocketEvent> implements RawDatagramSocket {
  _FakeDatagramSocket(this.host, this.port);

  final FakeHost host;

  @override
  final int port;

  final _events = StreamController<RawSocketEvent>();
  final _inbox = <Datagram>[];
  bool _closed = false;

  void _enqueue(Datagram datagram) {
    if (_closed) return;
    _inbox.add(datagram);
    // A microtask rather than a synchronous add: dart:io delivers read
    // events from the event loop, and a listener that ran inside `send`
    // would let a test pass on ordering the real socket never produces.
    scheduleMicrotask(() {
      if (_closed || _events.isClosed) return;
      _events.add(RawSocketEvent.read);
    });
  }

  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _events.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Datagram? receive() => _inbox.isEmpty ? null : _inbox.removeAt(0);

  @override
  int send(List<int> buffer, InternetAddress address, int port) {
    if (_closed) return 0;
    if (host.sendsFail) {
      final failure = SocketException(
        'Send failed',
        osError: const OSError('Network is unreachable', 51),
        address: address,
        port: port,
      );
      if (host.sendsFailSynchronously) throw failure;
      // dart:io reports it on the error handler and CLOSES the socket behind
      // it, which is the whole reason a failed send costs a rebind rather
      // than one lost beacon.
      scheduleMicrotask(() {
        if (_closed || _events.isClosed) return;
        _events.addError(failure, StackTrace.current);
        close();
      });
      return 0;
    }
    host.lan._deliver(this, buffer, port);
    return buffer.length;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inbox.clear();
    // Asynchronously, like dart:io: `onDone` after the close returns, so a
    // caller that closes and rebinds in one go does not see the release land
    // inside its own call.
    scheduleMicrotask(() {
      if (!_events.isClosed) _events.close();
    });
  }

  @override
  InternetAddress get address => InternetAddress(host.address);

  bool _broadcastEnabled = true;

  @override
  bool get broadcastEnabled => _broadcastEnabled;

  @override
  set broadcastEnabled(bool value) {
    if (host.broadcastRefused) {
      throw SocketException('Failed to set socket option', osError: const OSError('Permission denied', 13));
    }
    _broadcastEnabled = value;
  }

  @override
  bool readEventsEnabled = true;

  @override
  bool writeEventsEnabled = true;

  @override
  bool multicastLoopback = true;

  @override
  int multicastHops = 1;

  @override
  @Deprecated('This property is not implemented.')
  NetworkInterface? multicastInterface;

  // Peer discovery is broadcast, never multicast, and deliberately so — see
  // peer_beacon_io.dart's header on the iOS entitlement. Reaching these from
  // the beacon socket is the bug, so they say so rather than no-op.
  @override
  void joinMulticast(InternetAddress group, [NetworkInterface? interface]) =>
      throw UnsupportedError('peer discovery is broadcast, not multicast');

  @override
  void leaveMulticast(InternetAddress group, [NetworkInterface? interface]) =>
      throw UnsupportedError('peer discovery is broadcast, not multicast');

  @override
  Uint8List getRawOption(RawSocketOption option) => Uint8List(0);

  @override
  void setRawOption(RawSocketOption option) {}
}

class _FakeLinkServer implements PeerLinkServer {
  _FakeLinkServer(this.port);

  @override
  final int port;

  final _controller = StreamController<PeerLink>.broadcast();

  /// Always empty. A media link (HALO-369) is dialled straight through
  /// `dialPeerLink` by `peer_screen_views.dart`, not through [PeerNetwork],
  /// so nothing on a fake segment ever produces one — an empty stream is the
  /// honest answer rather than a stub that could be mistaken for coverage.
  final _mediaController = StreamController<PeerMediaConnection>.broadcast();
  bool _closed = false;

  void _accept(PeerLink link) {
    if (_closed || _controller.isClosed) {
      unawaited(link.close());
      return;
    }
    // A microtask, so an inbound link never arrives inside the dialling
    // caller's own `dial` — the real accept crosses the event loop, and a
    // test that depended on it landing synchronously would be pinning
    // ordering the sockets do not give.
    scheduleMicrotask(() {
      if (_closed || _controller.isClosed) {
        unawaited(link.close());
        return;
      }
      _controller.add(link);
    });
  }

  @override
  Stream<PeerLink> get connections => _controller.stream;

  @override
  Stream<PeerMediaConnection> get mediaConnections => _mediaController.stream;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_controller.isClosed) await _controller.close();
    if (!_mediaController.isClosed) await _mediaController.close();
  }
}

/// Two ends of one link, each delivering into the other.
(PeerLink, PeerLink) _linkPair() {
  final a = _FakeLink();
  final b = _FakeLink();
  a._peer = b;
  b._peer = a;
  return (a, b);
}

/// Message-oriented, like every real `PeerLink`: one `send` is exactly one
/// element on the far side's `inbound`, never joined and never split.
class _FakeLink implements PeerLink {
  _FakeLink? _peer;
  final _controller = StreamController<List<int>>();
  final _closedCompleter = Completer<void>();
  bool _isClosed = false;

  @override
  Stream<List<int>> get inbound => _controller.stream;

  @override
  void send(List<int> message) {
    // Never throws, even after the link is dead — the contract every caller
    // relies on, since writes happen from timers that cannot know.
    if (_isClosed) return;
    final peer = _peer;
    if (peer == null || peer._isClosed) return;
    scheduleMicrotask(() {
      if (peer._isClosed || peer._controller.isClosed) return;
      peer._controller.add(message);
    });
  }

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  Future<void> close() async {
    if (_isClosed) {
      await _closedCompleter.future;
      return;
    }
    _isClosed = true;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    // One microtask turn before the far side is told, and it is load-bearing:
    // a message [send] queued a moment ago sits AHEAD of this continuation in
    // the queue, so it gets delivered rather than dropped. A real socket
    // flushes a pending write on close, and `PeerSession` refuses a pairing
    // by sending `refuse` and closing in the same breath (`rejectPairing`,
    // `_refuse`) — a fake that dropped it would leave the declined peer with
    // an unexplained disconnect instead of a reason, every test still green.
    //
    // NOT `await _controller.close()`, which is how halo_core's `_MemoryLink`
    // spells the same flush: that future completes only once a listener has
    // taken the done event, so it hangs forever on a link nobody listened to
    // — which a transport test legitimately has.
    await Future<void>.value();
    if (!_controller.isClosed) unawaited(_controller.close());
    // Closing one end takes the other down, which is what makes a peer that
    // walked away observable at all.
    final peer = _peer;
    if (peer != null && !peer._isClosed) await peer.close();
  }
}
