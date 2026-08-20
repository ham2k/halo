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
