// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The LAN peer transport over REAL sockets (HALO-310) — a real WebSocket
// server, real dials, a real UDP socket. The session layer already has its
// own tests against an in-memory link (packages/halo_core), so the point
// here is specifically the part those cannot reach: that the socket code
// frames, connects, and tears down the way `PeerLink` promises, and that two
// full sessions really do sync across it.
//
// Everything binds an ephemeral port on loopback, so nothing here depends on
// the machine's network.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/peer_beacon_io.dart';
import 'package:ham2k_logger/services/peer/peer_beacon_types.dart';
import 'package:ham2k_logger/services/peer/peer_link_io.dart';

/// An ephemeral port the OS just handed back, then released — the same
/// probe-bind-and-close trick cat_discovery_test.dart uses, so two test runs
/// on one machine never collide on a hard-coded number.
Future<int> freeUdpPort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  probe.close();
  return port;
}

void main() {
  group('PeerLinkServer + dialPeerLink', () {
    late PeerLinkServer server;

    setUp(() async => server = await PeerLinkServer.bind());
    tearDown(() async => server.close());

    test('the server publishes a real port a peer can dial', () async {
      expect(server.port, greaterThan(0));
      final accepted = server.connections.first;
      final dialled = await dialPeerLink('127.0.0.1', server.port);
      addTearDown(dialled.close);
      expect(await accepted, isA<PeerLink>());
    });

    test('messages cross intact, in order, with boundaries preserved', () async {
      final acceptedFuture = server.connections.first;
      final client = await dialPeerLink('127.0.0.1', server.port);
      final accepted = await acceptedFuture;
      addTearDown(client.close);

      final received = <String>[];
      final done = Completer<void>();
      accepted.inbound.listen((bytes) {
        received.add(utf8.decode(bytes));
        if (received.length == 3) done.complete();
      });

      // Three sends in one synchronous burst: a byte-stream transport would
      // coalesce these into one arrival, which is exactly the failure
      // PeerLink's message-oriented contract exists to rule out.
      client.send(utf8.encode('one'));
      client.send(utf8.encode('two'));
      client.send(utf8.encode('three'));

      await done.future.timeout(const Duration(seconds: 5));
      expect(received, ['one', 'two', 'three']);
    });

    test('closing one end completes the other end\'s closed future', () async {
      final acceptedFuture = server.connections.first;
      final client = await dialPeerLink('127.0.0.1', server.port);
      final accepted = await acceptedFuture;

      await client.close();
      await accepted.closed.timeout(const Duration(seconds: 5));
    });

    test('send after close is silently dropped, never thrown', () async {
      final acceptedFuture = server.connections.first;
      final client = await dialPeerLink('127.0.0.1', server.port);
      await acceptedFuture;
      await client.close();

      // The contract every caller relies on: writes happen from timers and
      // message handlers that have no way to know the link just died.
      expect(() => client.send(utf8.encode('after close')), returnsNormally);
    });

    test('close is idempotent', () async {
      final acceptedFuture = server.connections.first;
      final client = await dialPeerLink('127.0.0.1', server.port);
      await acceptedFuture;
      await client.close();
      await client.close();
    });

    test('dialling a port nothing listens on fails instead of hanging', () async {
      final deadPort = await freeUdpPort();
      await expectLater(
        dialPeerLink('127.0.0.1', deadPort, timeout: const Duration(seconds: 2)),
        throwsA(anything),
      );
    });

    test('a non-WebSocket request is refused without disturbing the server', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.get('127.0.0.1', server.port, '/');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.badRequest);

      // And the server still accepts a real peer afterwards.
      final acceptedFuture = server.connections.first;
      final link = await dialPeerLink('127.0.0.1', server.port);
      addTearDown(link.close);
      expect(await acceptedFuture, isA<PeerLink>());
    });
  });

  group('PeerBeacon over a real UDP socket', () {
    test('a beacon round-trips and arrives carrying its SENDER address', () async {
      final port = await freeUdpPort();
      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '127.0.0.1');
      addTearDown(socket.close);

      final first = socket.beacons.first;
      socket.announce(const PeerBeacon(
        deviceId: 'device-a',
        deviceName: 'Laptop',
        operationUuid: 'op-1',
        port: 4321,
      ));

      final received = await first.timeout(const Duration(seconds: 5));
      expect(received.deviceId, 'device-a');
      expect(received.operationUuid, 'op-1');
      expect(received.port, 4321);
      // The whole reason this doesn't reuse udpBroadcastDatagrams: that helper
      // hands back bytes only, and a peer that cannot learn where a beacon
      // came from has nothing to dial.
      expect(received.address, '127.0.0.1');
    });

    test('traffic from anything else on the port is ignored, not surfaced', () async {
      final port = await freeUdpPort();
      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '127.0.0.1');
      addTearDown(socket.close);

      final seen = <PeerBeacon>[];
      socket.beacons.listen(seen.add);

      final other = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(other.close);
      for (final junk in [
        utf8.encode('not json at all'),
        utf8.encode(jsonEncode({'hello': 'from some other app'})),
        utf8.encode(jsonEncode({'halo': 'peer'})), // ours, but missing every field
      ]) {
        other.send(junk, InternetAddress('127.0.0.1'), port);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(seen, isEmpty);

      // A real beacon on the same socket still gets through.
      socket.announce(const PeerBeacon(
        deviceId: 'device-b',
        deviceName: 'Phone',
        operationUuid: 'op-1',
        port: 9999,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(seen.map((b) => b.deviceId), ['device-b']);
    });

    /// Holds [port] the way another app would. `reuseAddress: false` is the
    /// load-bearing part and not the default: `_bind` falls back to a plain
    /// SO_REUSEADDR bind for Windows' sake, and a holder that also set
    /// SO_REUSEADDR would let that fallback through on the platforms where
    /// the flag means "share this port" — Linux, which is what CI runs, and
    /// where a branch's tests are first run only AFTER it merges. With the
    /// flag withheld here, every platform refuses both attempts.
    ///
    /// The deterministic stand-in for the field cases: a sandbox denial, a
    /// port another program owns, an interface not up yet.
    Future<RawDatagramSocket> holdPort(int port) =>
        RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: false);

    test('a socket that cannot open says why ONCE, to a listener that arrives later', () async {
      final port = await freeUdpPort();
      final holder = await holdPort(port);
      addTearDown(holder.close);

      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '127.0.0.1');
      addTearDown(socket.close);
      expect(socket.healthy, isFalse);

      // Subscribing AFTER the failure, which is the only order that ever
      // happens: PeerService cannot listen to a socket it has not been
      // handed yet. A broadcast controller drops what is added before the
      // first listener, so an error added when it happened would be gone.
      final errors = <Object>[];
      socket.beacons.listen((_) {}, onError: errors.add);
      // Long enough that the ladder has failed again after the opening
      // attempt — the operator is told their peer list is empty and why,
      // once, not once per attempt. PeerService uploads a crash report for
      // anything arriving here.
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(errors, hasLength(1), reason: 'one outage, one report');
      expect(errors.single.toString(), contains('Address already in use'));
      // Closed here rather than left to the teardown: a ladder still running
      // when the body returns keeps reporting into a test the framework has
      // already finished with, and that lands as an unhandled error on
      // whatever test happens to be running next.
      await socket.close();
    });

    test('attempts space out and stop hammering a port that is never coming back', () async {
      final port = await freeUdpPort();
      final holder = await holdPort(port);
      addTearDown(holder.close);

      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '127.0.0.1');
      addTearDown(socket.close);
      socket.beacons.listen((_) {}, onError: (Object _) {});

      // The delays the socket scheduled, not the wall clock: a test that
      // timed the gaps would be measuring the machine's load as much as the
      // ladder, and this has to survive a busy CI box.
      await Future<void>.delayed(const Duration(seconds: 7));
      expect(socket.retryDelays.length, greaterThanOrEqualTo(2),
          reason: 'a port held forever has to keep being retried at all');
      // The whole point of the ladder. A fixed interval — which is what this
      // replaces, and what an innocent-looking edit would restore — gives
      // identical gaps and leaves everything else about the socket the same.
      expect(socket.retryDelays[1], greaterThan(socket.retryDelays[0]));
      expect(socket.retryDelays.last, lessThanOrEqualTo(rebindBackoffCap));
      await socket.close();
    });

    test('a socket that cannot open keeps trying, and starts working when the port frees up', () async {
      final port = await freeUdpPort();
      final holder = await holdPort(port);
      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '127.0.0.1');
      addTearDown(socket.close);
      // ONE subscription, and it handles errors. A second listener taking
      // only values (`beacons.first`) would take the errors too, with
      // nowhere to put them — and this socket can legitimately report
      // another failure at any moment, since a freed ephemeral port is fair
      // game for whatever else the suite is binding at the time.
      final heard = Completer<PeerBeacon>();
      socket.beacons.listen(
        (beacon) {
          if (!heard.isCompleted) heard.complete(beacon);
        },
        onError: (Object _) {},
      );
      expect(socket.healthy, isFalse, reason: 'the port is held — nothing could have bound it');

      // Turning peer sync on before the WiFi associates is the everyday
      // version of this. Without a retry the socket never opens again:
      // discovery is dead for the session, and toggling the switch is the
      // only way back.
      holder.close();
      // Generous against the ladder rather than against the machine: each
      // attempt that lands before the OS has actually let the port go pushes
      // the next one further out, so a tight window would be testing how
      // fast this box releases a socket.
      for (var i = 0; i < 400 && !socket.healthy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(socket.healthy, isTrue);

      // Bound is not the same as listening: the proof is a beacon arriving.
      socket.announce(const PeerBeacon(deviceId: 'device-d', deviceName: 'Tablet', port: 4321));
      expect((await heard.future.timeout(const Duration(seconds: 5))).deviceId, 'device-d');
      await socket.close();
    });

    test('a datagram that ARRIVES counts as evidence, and lets the ladder back down', () async {
      final port = await freeUdpPort();
      // Sends always fail here, receives are untouched — the shape of a VPN
      // holding the default route, or an access point isolating its clients.
      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '::1');
      addTearDown(socket.close);
      socket.beacons.listen((_) {}, onError: (Object _) {});
      const beacon = PeerBeacon(deviceId: 'device-e', deviceName: 'Handheld', port: 4321);

      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 400 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }

      // Two failed sends, so the ladder has climbed a rung it can be seen
      // coming back down from.
      socket.announce(beacon);
      await until(() => !socket.healthy);
      await until(() => socket.healthy);
      socket.announce(beacon);
      await until(() => !socket.healthy);
      await until(() => socket.healthy);
      final climbed = socket.retryDelays.last;

      final other = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(other.close);
      other.send(utf8.encode(jsonEncode(beacon.toJson())), InternetAddress('127.0.0.1'), port);
      await until(() => socket.retryDelays.length > 2 || !socket.healthy);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      socket.announce(beacon);
      await until(() => socket.retryDelays.last != climbed || !socket.healthy);
      // Without this, a device that hears peers but cannot broadcast to them
      // climbs to the ceiling and stays there — bound for a couple of
      // seconds out of every minute, and deaf for the rest, over a socket
      // that was receiving perfectly well the whole time.
      expect(socket.retryDelays.last, lessThan(climbed),
          reason: 'a beacon arrived, so the socket is working whatever its sends are doing');
      await socket.close();
    });

    test('a send with no route to the segment neither ends discovery nor is surfaced', () async {
      final port = await freeUdpPort();
      // '::1' out of an IPv4 socket is the deterministic stand-in for the
      // real trigger (errno 51, network unreachable): both fail the send
      // inside dart:io, which reports it on the socket's ERROR handler and
      // closes the socket behind it. A test that only closed the socket
      // would exercise none of that.
      final socket = await openPeerBeaconSocket(port: port, broadcastAddress: '::1');
      addTearDown(socket.close);

      Object? surfaced;
      var ended = false;
      final heard = Completer<PeerBeacon>();
      socket.beacons.listen(
        (beacon) {
          if (!heard.isCompleted) heard.complete(beacon);
        },
        onError: (Object e) => surfaced = e,
        onDone: () => ended = true,
      );

      const beacon = PeerBeacon(deviceId: 'device-c', deviceName: 'Handheld', port: 4321);
      socket.announce(beacon);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // An interface without a route is the operator's network, not a defect
      // of ours, and it must not reach PeerService's onError — which turns
      // anything arriving there into an upload and an on-screen notice.
      expect(surfaced, isNull);
      expect(ended, isFalse);
      // Nothing here calls anything to bring the socket back: it rebinds on
      // a timer of its own, precisely so a caller that stops announcing —
      // PeerService does exactly that when its link server has no port —
      // cannot strand it deaf for the session. The deaf window itself is not
      // asserted: it is real but shorter than one bind, and pinning it would
      // race the recovery this is here to prove.
      for (var i = 0; i < 100 && !socket.healthy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // What PeerService reads to decide whether the failure it reported is
      // still true — a banner over a working peer list is its own defect.
      expect(socket.healthy, isTrue, reason: 'nothing else is going to bring discovery back');

      final other = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(other.close);
      // Resent until it lands rather than fired once after a fixed wait: UDP
      // drops a datagram sent while nothing holds the port, so a one-shot
      // probe would turn "the rebind was a few ms slower here" into a
      // failure — and this branch's tests first run on CI after the merge.
      final probe = Timer.periodic(const Duration(milliseconds: 50), (_) {
        other.send(utf8.encode(jsonEncode(beacon.toJson())), InternetAddress('127.0.0.1'), port);
      });
      addTearDown(probe.cancel);
      expect((await heard.future.timeout(const Duration(seconds: 5))).deviceId, 'device-c');
      await socket.close();
    });
  });

  group('two PeerSessions over a real socket', () {
    test('a QSO logged on one device reaches the other across the wire', () async {
      final dbA = HaLoDatabase(NativeDatabase.memory());
      final dbB = HaLoDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
      });

      final outboxA = PeerOutbox(dbA);
      final operationsA = OperationsRepository(dbA);
      final qsosA = QsosRepository(dbA);
      final outboxB = PeerOutbox(dbB);
      final operationsB = OperationsRepository(dbB);
      final qsosB = QsosRepository(dbB);

      // Already paired, so this test is about the wire and not the prompt.
      await PeerTrustStore(dbA).trust('device-b', name: 'Phone');
      await PeerTrustStore(dbB).trust('device-a', name: 'Laptop');

      final op = await operationsA.create(stationCall: 'KI2D', userTitle: 'Field');
      await operationsB.mergeFromPeer([
        {'uuid': op.uuid, 'stationCall': 'KI2D', 'updatedAtMillis': op.updatedAtMillis},
      ]);
      outboxA.activeOperationUuid = op.uuid;
      outboxB.activeOperationUuid = op.uuid;

      await qsosA.add(op.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
      });
      await outboxA.scanNow();

      final server = await PeerLinkServer.bind();
      addTearDown(server.close);
      final acceptedFuture = server.connections.first;
      final dialled = await dialPeerLink('127.0.0.1', server.port);
      final accepted = await acceptedFuture;

      final sessionA = PeerSession(
        link: accepted,
        localDeviceId: 'device-a',
        localDeviceName: 'Laptop',
        sharedOperationUuid: op.uuid,
        outbox: outboxA,
        cursors: PeerCursorStore(dbA),
        trust: PeerTrustStore(dbA),
        operations: operationsA,
        qsos: qsosA,
      );
      final sessionB = PeerSession(
        link: dialled,
        localDeviceId: 'device-b',
        localDeviceName: 'Phone',
        sharedOperationUuid: op.uuid,
        outbox: outboxB,
        cursors: PeerCursorStore(dbB),
        trust: PeerTrustStore(dbB),
        operations: operationsB,
        qsos: qsosB,
      );
      addTearDown(() async {
        await sessionA.close();
        await sessionB.close();
      });

      await sessionA.start();
      await sessionB.start();

      // Real sockets, so this waits on arrival rather than on a fixed number
      // of microtask drains.
      final landed = Completer<void>();
      final poll = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        final rows = await qsosB.watchForOperation(op.uuid).first;
        if (rows.isNotEmpty && !landed.isCompleted) {
          timer.cancel();
          landed.complete();
        }
      });
      addTearDown(poll.cancel);
      await landed.future.timeout(const Duration(seconds: 10));

      final onB = await qsosB.watchForOperation(op.uuid).first;
      expect(onB.single.theirCall, 'W1AW');
      expect(onB.single.band, '20m');
      expect(sessionB.state, PeerSessionState.live);
      expect(sessionA.state, PeerSessionState.live);
    });
  });
}
