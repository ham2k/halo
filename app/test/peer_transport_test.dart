// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The LAN peer transport (HALO-310). The session layer already has its own
// tests against an in-memory link (packages/halo_core), so the point here is
// specifically the part those cannot reach: that the transport frames,
// connects and tears down the way `PeerLink` promises, that the beacon
// socket's retry ladder behaves, and that two full sessions really do sync
// across a link.
//
// Three groups, three different reasons for the level they run at:
//
//  - The link server runs on REAL loopback sockets. It binds port 0 and lets
//    the OS choose, so nothing is guessed and nothing is held; what it proves
//    — the 400 for a non-upgrade request, the Origin-header refusal, message
//    boundaries surviving the wire — is exactly the behaviour a fake would be
//    asserting about itself.
//  - The beacon socket runs the REAL socket over a fake segment
//    (`peer_network_fakes.dart`) under `fakeAsync`. Its failures are the
//    thing under test, and every one of them — a held port, a send with no
//    route — can only be produced against a real socket by racing the
//    machine for a port. That race was this file's flake.
//  - Two small contract tests keep the fake honest, on real sockets, by
//    pinning the two dart:io facts the beacon socket's code depends on.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/peer_beacon_io.dart';
import 'package:ham2k_logger/services/peer/peer_beacon_types.dart';
import 'package:ham2k_logger/services/peer/peer_link_io.dart';
import 'package:ham2k_logger/services/peer/peer_link_types.dart';

import 'peer_network_fakes.dart';

void main() {
  group('PeerLinkServer + dialPeerLink', () {
    late PeerLinkServer server;

    setUp(() async => server = await bindPeerLinkServer());
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
      // A server bound and immediately closed, rather than a port probed
      // free: this one is known to have had nothing on it a moment ago AND
      // to be a TCP port, which a UDP probe cannot tell you.
      final vacated = await bindPeerLinkServer();
      final deadPort = vacated.port;
      await vacated.close();

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

    test('a message sent immediately before close still reaches the far side', () async {
      // `PeerSession` refuses a pairing by sending `refuse` and closing in the
      // same breath (`rejectPairing`, `_refuse`). A transport that dropped the
      // in-flight write would leave the declined peer with an unexplained
      // disconnect instead of a reason — and nothing else would say so.
      final acceptedFuture = server.connections.first;
      final client = await dialPeerLink('127.0.0.1', server.port);
      final accepted = await acceptedFuture;

      final received = <String>[];
      accepted.inbound.listen((bytes) => received.add(utf8.decode(bytes)));
      client.send(utf8.encode('refuse'));
      await client.close();

      for (var i = 0; i < 100 && received.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(received, ['refuse']);
    });

    test('an upgrade carrying an Origin header is refused', () async {
      // A web page the operator merely VISITS is outside the threat model,
      // and `ws://` is not subject to CORS — so without this check a page
      // could scan localhost, upgrade, and talk the peer protocol. Browsers
      // always send Origin on a WebSocket handshake and this app never does.
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.get('127.0.0.1', server.port, '/');
      request.headers
        ..set('connection', 'Upgrade')
        ..set('upgrade', 'websocket')
        ..set('sec-websocket-version', '13')
        ..set('sec-websocket-key', base64.encode(List<int>.filled(16, 0)))
        ..set('origin', 'http://evil.example');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.forbidden);
    });
  });

  group('PeerBeaconSocket over a fake segment', () {
    /// Runs [body] with the fake clock, then drains whatever the socket left
    /// behind.
    ///
    /// Every test here ends with a socket whose retry ladder is still armed,
    /// and that is now harmless: a timer created inside this zone fires only
    /// when THIS zone's clock is advanced, so once the test returns nothing
    /// can ever fire into a later one. On the real clock that same armed
    /// ladder kept reporting into whichever test happened to be running
    /// next, which is what made the failures land nowhere near their cause.
    void withFakeLan(void Function(FakeAsync async, FakeLan lan) body) {
      fakeAsync((async) {
        final lan = FakeLan();
        body(async, lan);
        async.flushMicrotasks();
      });
    }

    /// Opens the real beacon socket on [host] and settles the bind, which is
    /// a microtask away rather than a wall-clock one.
    PeerBeaconSocket open(FakeAsync async, FakeHost host) {
      PeerBeaconSocket? opened;
      unawaited(openPeerBeaconSocket(
        port: fakeBeaconPort,
        broadcastAddress: host.address,
        bind: host.binder,
      ).then((socket) => opened = socket));
      async.flushMicrotasks();
      return opened!;
    }

    test('a beacon round-trips and arrives carrying its SENDER address', () {
      withFakeLan((async, lan) {
        final host = lan.host(address: '10.0.0.7');
        final socket = open(async, host);

        final received = <PeerBeacon>[];
        socket.beacons.listen(received.add, onError: (Object _) {});
        socket.announce(const PeerBeacon(
          deviceId: 'device-a',
          deviceName: 'Laptop',
          operationUuid: 'op-1',
          port: 4321,
        ));
        async.flushMicrotasks();

        expect(received, hasLength(1));
        expect(received.single.deviceId, 'device-a');
        expect(received.single.operationUuid, 'op-1');
        expect(received.single.port, 4321);
        // The whole reason this doesn't reuse udpBroadcastDatagrams: that
        // helper hands back bytes only, and a peer that cannot learn where a
        // beacon came from has nothing to dial.
        expect(received.single.address, '10.0.0.7');

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('traffic from anything else on the port is ignored, not surfaced', () {
      withFakeLan((async, lan) {
        final socket = open(async, lan.host());

        final seen = <PeerBeacon>[];
        final errors = <Object>[];
        socket.beacons.listen(seen.add, onError: errors.add);

        // Another app on the same port, not another HaLo — so it has no
        // beacon socket of its own, it just puts bytes on the segment.
        for (final junk in [
          utf8.encode('not json at all'),
          utf8.encode(jsonEncode({'hello': 'from some other app'})),
          utf8.encode(jsonEncode({'halo': 'peer'})), // ours, but missing every field
        ]) {
          lan.sendRaw(junk, port: fakeBeaconPort);
        }
        async.flushMicrotasks();
        expect(seen, isEmpty);
        expect(errors, isEmpty, reason: 'a stray datagram is ordinary traffic, not a fault');

        // A real beacon on the same socket still gets through.
        socket.announce(const PeerBeacon(
          deviceId: 'device-b',
          deviceName: 'Phone',
          operationUuid: 'op-1',
          port: 9999,
        ));
        async.flushMicrotasks();
        expect(seen.map((b) => b.deviceId), ['device-b']);

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('a socket that cannot open says why ONCE, to a listener that arrives later', () {
      withFakeLan((async, lan) {
        lan.holdPort(fakeBeaconPort);
        final socket = open(async, lan.host());
        expect(socket.healthy, isFalse);

        // Subscribing AFTER the failure, which is the only order that ever
        // happens: PeerService cannot listen to a socket it has not been
        // handed yet. A broadcast controller drops what is added before the
        // first listener, so an error added when it happened would be gone.
        final errors = <Object>[];
        socket.beacons.listen((_) {}, onError: errors.add);

        // Long enough that the ladder has failed many more times after the
        // opening attempt — the operator is told their peer list is empty
        // and why, ONCE, not once per attempt. PeerService uploads a crash
        // report for anything arriving here, so a ladder that re-reported
        // every rung would rebuild the storm this exists to stop.
        async.elapse(const Duration(minutes: 5));
        expect(socket.retryDelays.length, greaterThan(5), reason: 'the ladder really did keep trying');
        expect(errors, hasLength(1), reason: 'one outage, one report');
        expect(errors.single.toString(), contains('Address already in use'));

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('attempts space out and stop hammering a port that is never coming back', () {
      withFakeLan((async, lan) {
        lan.holdPort(fakeBeaconPort);
        final socket = open(async, lan.host());
        socket.beacons.listen((_) {}, onError: (Object _) {});

        async.elapse(const Duration(minutes: 10));

        // The whole point of the ladder. A fixed interval — which is what
        // this replaces, and what an innocent-looking edit would restore —
        // gives identical gaps and leaves everything else about the socket
        // the same.
        expect(socket.retryDelays[1], greaterThan(socket.retryDelays[0]));
        expect(socket.retryDelays.last, rebindBackoffCap, reason: 'and it stops climbing at the cap');
        // Exact, not approximate: the fake clock means the ladder can be
        // read rung by rung, so a doubling that silently became a fixed 1s
        // or a 4x jump is a failure rather than something inside a tolerance.
        //
        // It starts at TWO seconds, not one: `open()` is itself the first
        // attempt, so the first delay recorded is already the second rung.
        expect(socket.retryDelays.take(7).toList(), [
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          const Duration(seconds: 8),
          const Duration(seconds: 16),
          const Duration(seconds: 32),
          rebindBackoffCap,
          rebindBackoffCap,
        ]);

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('a socket that cannot open keeps trying, and starts working when the port frees up', () {
      withFakeLan((async, lan) {
        final host = lan.host();
        lan.holdPort(fakeBeaconPort);
        final socket = open(async, host);

        final heard = <PeerBeacon>[];
        socket.beacons.listen(heard.add, onError: (Object _) {});
        expect(socket.healthy, isFalse, reason: 'the port is held — nothing could have bound it');

        // Turning peer sync on before the WiFi associates is the everyday
        // version of this. Without a retry the socket never opens again:
        // discovery is dead for the session, and toggling the switch is the
        // only way back.
        async.elapse(const Duration(seconds: 30));
        lan.releasePort(fakeBeaconPort);
        async.elapse(rebindBackoffCap);
        expect(socket.healthy, isTrue);

        // Bound is not the same as listening: the proof is a beacon arriving.
        socket.announce(const PeerBeacon(deviceId: 'device-d', deviceName: 'Tablet', port: 4321));
        async.flushMicrotasks();
        expect(heard.map((b) => b.deviceId), ['device-d']);

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('a send with no route to the segment neither ends discovery nor is surfaced', () {
      withFakeLan((async, lan) {
        final host = lan.host();
        final socket = open(async, host);

        Object? surfaced;
        var ended = false;
        final heard = <PeerBeacon>[];
        socket.beacons.listen(heard.add, onError: (Object e) => surfaced = e, onDone: () => ended = true);

        // dart:io reports a send failure on the socket's ERROR handler and
        // closes the socket behind it — so a moment without a route does not
        // merely lose one beacon, it leaves the device deaf.
        host.sendsFail = true;
        socket.announce(const PeerBeacon(deviceId: 'device-c', deviceName: 'Handheld', port: 4321));
        async.flushMicrotasks();
        expect(socket.healthy, isFalse, reason: 'the failed send cost the socket');

        // An interface without a route is the operator's network, not a
        // defect of ours, and it must not reach PeerService's onError —
        // which turns anything arriving there into an upload and an
        // on-screen notice.
        expect(surfaced, isNull);
        expect(ended, isFalse);

        // Nothing here calls anything to bring the socket back: it rebinds
        // on a timer of its own, precisely so a caller that stops announcing
        // — PeerService does exactly that when its link server has no port —
        // cannot strand it deaf for the session.
        async.elapse(const Duration(seconds: 5));
        // What PeerService reads to decide whether the failure it reported
        // is still true — a banner over a working peer list is its own
        // defect.
        expect(socket.healthy, isTrue, reason: 'nothing else is going to bring discovery back');

        host.sendsFail = false;
        socket.announce(const PeerBeacon(deviceId: 'device-c', deviceName: 'Handheld', port: 4321));
        async.flushMicrotasks();
        expect(heard.map((b) => b.deviceId), ['device-c']);

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('a send that throws synchronously gets the same accounting as one that does not', () {
      withFakeLan((async, lan) {
        final host = lan.host();
        final socket = open(async, host);
        socket.beacons.listen((_) {}, onError: (Object _) {});

        host.sendsFail = true;
        host.sendsFailSynchronously = true;
        // Never throws out of announce, whichever way dart:io reports it:
        // callers announce from a timer and have no way to catch this.
        expect(
          () => socket.announce(const PeerBeacon(deviceId: 'device-f', deviceName: 'Handheld', port: 1)),
          returnsNormally,
        );
        async.flushMicrotasks();
        expect(socket.healthy, isFalse, reason: 'the socket is given up so something rebinds it');
        expect(socket.retryDelays, isNotEmpty, reason: 'and the ladder counts it, rather than spinning per tick');

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('a socket that binds but cannot broadcast is retried too, and says which half failed', () {
      withFakeLan((async, lan) {
        final host = lan.host();
        // The BIND succeeds and enabling broadcast refuses — a sandbox
        // denial, which a held port cannot reproduce. Retrying only the bind
        // would end discovery for the session here, while the identical
        // outcome one line earlier recovers on its own.
        host.broadcastRefused = true;
        final socket = open(async, host);
        final errors = <Object>[];
        socket.beacons.listen((_) {}, onError: errors.add);
        expect(socket.healthy, isFalse);

        async.elapse(const Duration(seconds: 30));
        expect(socket.retryDelays, isNotEmpty, reason: 'the attach half is on the ladder, not just the bind');
        expect(errors, hasLength(1), reason: 'one outage, one report — whichever half refused');
        expect(errors.single.toString(), contains('Permission denied'));

        // And it recovers when the sandbox stops refusing, without anything
        // asking it to.
        host.broadcastRefused = false;
        async.elapse(rebindBackoffCap);
        expect(socket.healthy, isTrue);

        unawaited(socket.close());
        async.flushMicrotasks();
      });
    });

    test('a datagram that ARRIVES counts as evidence, and lets the ladder back down', () {
      withFakeLan((async, lan) {
        final host = lan.host();
        final socket = open(async, host);
        socket.beacons.listen((_) {}, onError: (Object _) {});
        const beacon = PeerBeacon(deviceId: 'device-e', deviceName: 'Handheld', port: 4321);

        // Sends fail, receives are untouched — the shape of a VPN holding
        // the default route, or an access point isolating its clients. Two
        // failed sends, so the ladder has climbed a rung it can be seen
        // coming back down from.
        host.sendsFail = true;
        for (var i = 0; i < 2; i++) {
          socket.announce(beacon);
          async.elapse(const Duration(seconds: 30));
        }
        final climbed = socket.retryDelays.last;
        expect(climbed, greaterThan(const Duration(seconds: 1)), reason: 'the ladder climbed at all');

        // A peer we can hear but cannot answer.
        final peer = lan.host();
        final peerSocket = open(async, peer);
        peerSocket.announce(beacon);
        async.flushMicrotasks();

        socket.announce(beacon);
        async.elapse(const Duration(seconds: 30));
        // Without this, a device that hears peers but cannot broadcast to
        // them climbs to the ceiling and stays there — bound for a couple of
        // seconds out of every minute, and deaf for the rest, over a socket
        // that was receiving perfectly well the whole time.
        expect(socket.retryDelays.last, lessThan(climbed),
            reason: 'a beacon arrived, so the socket is working whatever its sends are doing');

        unawaited(socket.close());
        unawaited(peerSocket.close());
        async.flushMicrotasks();
      });
    });
  });

  // The two dart:io behaviours `_PeerBeaconSocket` is built on, and which
  // `peer_network_fakes.dart` therefore reproduces. Neither is documented as
  // a guarantee, both are string- or shape-matched in shipping code, and a
  // Dart SDK that changed either would otherwise leave every test above
  // passing while the retry ladder quietly stopped working in the field.
  //
  // Real sockets, but nothing is guessed and nothing is held for long: both
  // bind port 0 or a port this test just took, and neither waits on a clock.
  group('the dart:io contract the fake segment stands in for', () {
    test('a send with no route is reported on the ERROR handler and closes the socket', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(socket.close);

      Object? reported;
      var done = false;
      socket.listen((_) {}, onError: (Object e) => reported = e, onDone: () => done = true);

      // '::1' out of an IPv4 socket, the deterministic stand-in for the real
      // trigger (errno 51, network unreachable).
      socket.send(utf8.encode('x'), InternetAddress('::1'), socket.port);
      for (var i = 0; i < 100 && reported == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // `_onSocketError` matches this message EXACTLY to tell a send failure
      // (console only, counted into the send half of the ladder) from a
      // receive-side one (surfaced to the operator). A changed string sends
      // every downed interface to the operator as a notice and an upload.
      expect(reported, isA<SocketException>());
      expect((reported! as SocketException).message, 'Send failed');
      // And the socket is gone behind it — which is why a failed send costs
      // a rebind rather than one lost beacon.
      for (var i = 0; i < 100 && !done; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(done, isTrue, reason: 'dart:io closes a datagram socket after any error of its own');
    });

    test('a port already held refuses the bind, saying so', () async {
      // `reuseAddress: false` on the holder is load-bearing and not the
      // default: `_bind` falls back to a plain SO_REUSEADDR bind for
      // Windows' sake, and a holder that also set SO_REUSEADDR would let
      // that fallback through on the platforms where the flag means "share
      // this port" — Linux, which is what CI runs. With the flag withheld,
      // every platform refuses.
      // The holder takes port 0 and reports what it got, rather than a probe
      // finding a free port and releasing it: the gap between releasing and
      // re-taking is a race against the rest of the machine, which is the
      // whole failure mode this file was rewritten to remove.
      final holder = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
      addTearDown(holder.close);

      await expectLater(
        RawDatagramSocket.bind(InternetAddress.anyIPv4, holder.port, reuseAddress: false),
        throwsA(isA<SocketException>().having(
          (e) => e.osError?.message,
          'osError.message',
          contains('Address already in use'),
        )),
      );
    });
  });

  // The fake stands in for the transport in every PeerService test, so where
  // it and a real socket disagree, those tests are asserting about a world
  // that does not exist. These pin the two places the difference would be
  // silent rather than loud.
  group('the fake segment matches the real transport', () {
    test('a message sent immediately before close still reaches the far side', () async {
      // The real-socket test of the same name is the reference. Without this,
      // `PeerSession`'s refuse frame vanishes over the fake and the declined
      // peer never reaches `refused` — while every LAN test stays green.
      final lan = FakeLan();
      final listener = lan.host();
      final server = await listener.network.bindLinkServer();
      addTearDown(server.close);
      final acceptedFuture = server.connections.first;
      final dialled = await lan.host().network.dial(listener.address, server.port);
      final accepted = await acceptedFuture;

      final received = <String>[];
      accepted.inbound.listen((bytes) => received.add(utf8.decode(bytes)));
      dialled.send(utf8.encode('refuse'));
      await dialled.close();
      await Future<void>.delayed(Duration.zero);

      expect(received, ['refuse']);
    });

    test('a dial to the right port at the wrong address finds nothing', () async {
      // The beacon carries a sender address so a peer knows where to dial.
      // A fake that keyed on the port alone would let a dial to the WRONG
      // address connect, and no test of that address could then fail.
      final lan = FakeLan();
      final listener = lan.host();
      final server = await listener.network.bindLinkServer();
      addTearDown(server.close);

      await expectLater(
        lan.host().network.dial('10.99.99.99', server.port),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('two PeerSessions over a link', () {
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

      final lan = FakeLan();
      final laptop = lan.host();
      final phone = lan.host();
      final server = await laptop.network.bindLinkServer();
      addTearDown(server.close);
      final acceptedFuture = server.connections.first;
      final dialled = await phone.network.dial(laptop.address, server.port);
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

      // The link crosses the event loop rather than the wire, but the
      // handshake still takes several round trips and the sync writes to a
      // real database — so this waits on arrival rather than on a fixed
      // number of drains.
      var rows = <Qso>[];
      for (var i = 0; i < 200 && rows.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
        rows = await qsosB.watchForOperation(op.uuid).first;
      }

      // Before the `single` assertions: on exhaustion those fail as
      // "Bad state: No element", which points at the assertion rather than at
      // the sync that never happened.
      expect(rows, isNotEmpty, reason: 'the QSO never crossed the link');
      expect(rows.single.theirCall, 'W1AW');
      expect(rows.single.band, '20m');
      expect(sessionB.state, PeerSessionState.live);
      expect(sessionA.state, PeerSessionState.live);
    });
  });
}
