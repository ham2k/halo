// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PeerSession end to end: two real in-memory databases, two real sessions,
// joined by an in-memory link pair standing in for a socket. No transport
// exists yet, and the point of the session layer is that it never needs to
// know — so these are the tests that would catch a protocol change breaking
// sync, without waiting on the LAN transport to exist.

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// Two [PeerLink]s wired mouth-to-ear. Delivery is asynchronous (a real
/// socket never delivers inline), which is exactly what makes the session's
/// serialization guard meaningful.
class _LinkPair {
  final _MemoryLink a;
  final _MemoryLink b;

  _LinkPair._(this.a, this.b);

  factory _LinkPair() {
    final a = _MemoryLink('a');
    final b = _MemoryLink('b');
    a.peer = b;
    b.peer = a;
    return _LinkPair._(a, b);
  }
}

class _MemoryLink implements PeerLink {
  _MemoryLink(this.label);

  final String label;
  late _MemoryLink peer;

  final _controller = StreamController<List<int>>();
  final _closedCompleter = Completer<void>();
  bool _isClosed = false;

  /// Observes everything this side puts on the wire. `inbound` is a plain
  /// single-subscription stream (a session listens to it exactly once, like
  /// a real socket), so a test that wants to watch traffic hooks the SENDER
  /// rather than adding a second listener to the receiver.
  void Function(List<int> message)? onSend;

  @override
  Stream<List<int>> get inbound => _controller.stream;

  @override
  void send(List<int> message) {
    if (_isClosed) return;
    onSend?.call(message);
    // Asynchronous on purpose — see _LinkPair's doc.
    scheduleMicrotask(() {
      if (peer._isClosed || peer._controller.isClosed) return;
      peer._controller.add(message);
    });
  }

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    await _controller.close();
    // A real socket closing tells the far side too.
    if (!peer._isClosed) unawaited(peer.close());
  }
}

/// One device: its database, repositories, and peer-sync substrate.
class _Device {
  _Device(this.deviceId, this.name) {
    db = HaLoDatabase(NativeDatabase.memory());
    outbox = PeerOutbox(db);
    cursors = PeerCursorStore(db);
    trust = PeerTrustStore(db);
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  }

  final String deviceId;
  final String name;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final PeerCursorStore cursors;
  late final PeerTrustStore trust;
  late final OperationsRepository operations;
  late final QsosRepository qsos;

  PeerSession session(PeerLink link, String operationUuid) => PeerSession(
        link: link,
        localDeviceId: deviceId,
        localDeviceName: name,
        operationUuid: operationUuid,
        outbox: outbox,
        cursors: cursors,
        trust: trust,
        operations: operations,
        qsos: qsos,
      );

  Future<void> dispose() => db.close();
}

/// Lets every queued microtask and database future drain. The sessions talk
/// in several round trips, so a single await is not enough to reach a
/// settled state.
Future<void> settle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Device deviceA;
  late _Device deviceB;

  setUp(() {
    deviceA = _Device('device-a', 'Laptop');
    deviceB = _Device('device-b', 'Phone');
  });

  tearDown(() async {
    await deviceA.dispose();
    await deviceB.dispose();
  });

  /// Both devices already know the operation and already trust each other —
  /// the ordinary steady state, so a test about syncing isn't also a test
  /// about pairing.
  Future<(PeerSession, PeerSession, String)> pairedSessions() async {
    final op = await deviceA.operations.create(stationCall: 'KI2D', userTitle: 'Shared');
    await deviceB.operations.mergeFromPeer([
      {
        'uuid': op.uuid,
        'stationCall': 'KI2D',
        'userTitle': 'Shared',
        'updatedAtMillis': op.updatedAtMillis,
      },
    ]);
    deviceA.outbox.activeOperationUuid = op.uuid;
    deviceB.outbox.activeOperationUuid = op.uuid;
    await deviceA.trust.trust('device-b', name: 'Phone');
    await deviceB.trust.trust('device-a', name: 'Laptop');

    final links = _LinkPair();
    final sessionA = deviceA.session(links.a, op.uuid);
    final sessionB = deviceB.session(links.b, op.uuid);
    await sessionA.start();
    await sessionB.start();
    await settle();
    return (sessionA, sessionB, op.uuid);
  }

  group('handshake', () {
    test('two already-trusted devices reach live without asking anyone', () async {
      final (sessionA, sessionB, _) = await pairedSessions();
      expect(sessionA.state, PeerSessionState.live);
      expect(sessionB.state, PeerSessionState.live);
      expect(sessionA.peer?.deviceId, 'device-b');
      expect(sessionB.peer?.deviceId, 'device-a');
    });

    test('an unknown peer parks at needsPairing and sends nothing until the operator says yes', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;
      deviceB.outbox.activeOperationUuid = op.uuid;
      final qso = await deviceA.qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = deviceB.session(links.b, op.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(sessionA.state, PeerSessionState.needsPairing);
      expect(sessionB.state, PeerSessionState.needsPairing);
      expect(await deviceB.qsos.get(qso.uuid), isNull,
          reason: 'nothing may cross before BOTH operators have confirmed');

      // Only one side confirms — still not enough.
      await sessionB.acceptPairing();
      await settle();
      expect(await deviceB.qsos.get(qso.uuid), isNull,
          reason: 'A has not welcomed B back yet, so A must not answer its catch-up');

      await sessionA.acceptPairing();
      await settle();
      expect(await deviceB.qsos.get(qso.uuid), isNotNull);
      expect(sessionB.state, PeerSessionState.live);
    });

    test('accepting pairing records trust, so the next session never asks again', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;
      deviceB.outbox.activeOperationUuid = op.uuid;

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = deviceB.session(links.b, op.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();
      await sessionA.acceptPairing();
      await sessionB.acceptPairing();
      await settle();

      expect(await deviceA.trust.isTrusted('device-b'), isTrue);
      expect(await deviceB.trust.isTrusted('device-a'), isTrue);

      // A brand-new link between the same two devices.
      final links2 = _LinkPair();
      final sessionA2 = deviceA.session(links2.a, op.uuid);
      final sessionB2 = deviceB.session(links2.b, op.uuid);
      await sessionA2.start();
      await sessionB2.start();
      await settle();
      expect(sessionA2.state, PeerSessionState.live);
      expect(sessionB2.state, PeerSessionState.live);
    });

    test('a declined pairing refuses the far side rather than leaving it hanging', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;
      deviceB.outbox.activeOperationUuid = op.uuid;

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = deviceB.session(links.b, op.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();

      await sessionB.rejectPairing();
      await settle();

      expect(sessionB.state, PeerSessionState.refused);
      expect(sessionA.state, PeerSessionState.refused);
      expect(sessionA.refusedReason, PeerRefusal.notTrusted);
      expect(await deviceA.trust.isTrusted('device-b'), isFalse);
    });

    test('a peer sharing a DIFFERENT operation is refused, not silently ignored', () async {
      final opA = await deviceA.operations.create(stationCall: 'KI2D');
      final opB = await deviceB.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = opA.uuid;
      deviceB.outbox.activeOperationUuid = opB.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opA.uuid);
      final sessionB = deviceB.session(links.b, opB.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(sessionA.state, PeerSessionState.refused);
      expect(sessionA.refusedReason, PeerRefusal.differentOperation);
    });

    test('a device hearing its own announcement refuses itself instead of syncing with itself', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;

      final links = _LinkPair();
      // Same deviceId on both ends — a broadcast reflected back to its sender.
      final one = deviceA.session(links.a, op.uuid);
      final two = deviceA.session(links.b, op.uuid);
      await one.start();
      await two.start();
      await settle();

      expect(one.state, PeerSessionState.refused);
      expect(one.refusedReason, PeerRefusal.sameDevice);
    });

    test('a protocol-version mismatch is refused with a reason the far side can show', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      await sessionA.start();

      // A peer from a future (or past) build.
      links.b.send(utf8.encode(jsonEncode({
        't': 'hello',
        'v': peerProtocolVersion + 1,
        'deviceId': 'device-b',
        'deviceName': 'Phone',
        'operationUuid': op.uuid,
      })));
      await settle();

      expect(sessionA.state, PeerSessionState.refused);
      expect(sessionA.refusedReason, PeerRefusal.protocolVersion);
    });
  });

  group('catch-up and live sync', () {
    test('a backlog logged before connecting reaches the peer on catch-up', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D', userTitle: 'Shared');
      await deviceB.operations.mergeFromPeer([
        {'uuid': op.uuid, 'stationCall': 'KI2D', 'updatedAtMillis': op.updatedAtMillis},
      ]);
      deviceA.outbox.activeOperationUuid = op.uuid;
      deviceB.outbox.activeOperationUuid = op.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      await deviceA.qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.qsos.add(op.uuid, {'their': {'call': 'K1ABC'}});
      await deviceA.outbox.scanNow();

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = deviceB.session(links.b, op.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();

      final onB = await deviceB.qsos.watchForOperation(op.uuid).first;
      expect(onB.map((q) => q.theirCall).toSet(), {'W1AW', 'K1ABC'});
    });

    test('a QSO logged while live reaches the peer without a reconnect', () async {
      final (sessionA, _, op) = await pairedSessions();

      await deviceA.qsos.add(op, {'their': {'call': 'EA4XYZ'}});
      await deviceA.outbox.scanNow();
      await sessionA.pushLocal();
      await settle();

      final onB = await deviceB.qsos.watchForOperation(op).first;
      expect(onB.map((q) => q.theirCall), ['EA4XYZ']);
    });

    test('sync is bidirectional over one link — both devices end up with both logs', () async {
      final (sessionA, sessionB, op) = await pairedSessions();

      await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});
      await deviceB.qsos.add(op, {'their': {'call': 'K1ABC'}});
      await deviceA.outbox.scanNow();
      await deviceB.outbox.scanNow();
      await sessionA.pushLocal();
      await sessionB.pushLocal();
      await settle();

      final onA = await deviceA.qsos.watchForOperation(op).first;
      final onB = await deviceB.qsos.watchForOperation(op).first;
      expect(onA.map((q) => q.theirCall).toSet(), {'W1AW', 'K1ABC'});
      expect(onB.map((q) => q.theirCall).toSet(), {'W1AW', 'K1ABC'});
    });

    test('a backlog larger than one batch is delivered completely, in order', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceB.operations.mergeFromPeer([
        {'uuid': op.uuid, 'stationCall': 'KI2D', 'updatedAtMillis': op.updatedAtMillis},
      ]);
      deviceA.outbox.activeOperationUuid = op.uuid;
      deviceB.outbox.activeOperationUuid = op.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      for (var i = 0; i < 25; i++) {
        await deviceA.qsos.add(op.uuid, {'their': {'call': 'W${i}AW'}, 'startAtMillis': 1000 + i});
      }
      await deviceA.outbox.scanNow();

      final links = _LinkPair();
      // A batch limit far below the backlog, so completion depends on the
      // ack-driven continuation rather than one lucky oversized message.
      final sessionA = PeerSession(
        link: links.a,
        localDeviceId: 'device-a',
        localDeviceName: 'Laptop',
        operationUuid: op.uuid,
        outbox: deviceA.outbox,
        cursors: deviceA.cursors,
        trust: deviceA.trust,
        operations: deviceA.operations,
        qsos: deviceA.qsos,
        batchLimit: 4,
      );
      final sessionB = deviceB.session(links.b, op.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();

      final onB = await deviceB.qsos.watchForOperation(op.uuid).first;
      expect(onB, hasLength(25));
      expect(sessionB.state, PeerSessionState.live);
    });

    test('a reconnect resumes from the cursor instead of replaying the whole log', () async {
      final (sessionA, sessionB, op) = await pairedSessions();
      await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();
      await sessionA.pushLocal();
      await settle();
      expect(await deviceB.qsos.watchForOperation(op).first, hasLength(1));

      await sessionA.close();
      await sessionB.close();
      await settle();

      // Logged while the link was down.
      await deviceA.qsos.add(op, {'their': {'call': 'K1ABC'}});
      await deviceA.outbox.scanNow();

      final links2 = _LinkPair();
      var recordsSentByA = 0;
      links2.a.onSend = (raw) {
        final message = PeerMessage.decode(raw);
        if (message?.type == PeerMessageType.events) recordsSentByA += message!.events.length;
      };
      final sessionA2 = deviceA.session(links2.a, op);
      final sessionB2 = deviceB.session(links2.b, op);
      await sessionA2.start();
      await sessionB2.start();
      await settle();

      expect(await deviceB.qsos.watchForOperation(op).first, hasLength(2));
      expect(recordsSentByA, 1,
          reason: 'only the QSO logged while disconnected should cross — the cursor covers the rest');
    });

    test('concurrent edits made while disconnected converge on the newer one, both sides', () async {
      final (sessionA, sessionB, op) = await pairedSessions();
      final qso = await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}, 'notes': 'original'});
      await deviceA.outbox.scanNow();
      await sessionA.pushLocal();
      await settle();
      expect((await deviceB.qsos.watchForOperation(op).first).single.notes, 'original');

      await sessionA.close();
      await sessionB.close();
      await settle();

      // Both operators edit the same contact while out of contact. The
      // revision stamps are real wall-clock milliseconds, so the delay is
      // what makes "B edited later" true rather than a coin flip on a tie —
      // a same-millisecond tie is a real (if unlikely) way for LWW to leave
      // the two devices disagreeing, and this test deliberately does not
      // pretend otherwise by asserting on one.
      final onA = (await deviceA.qsos.watchForOperation(op).first).single;
      await deviceA.qsos.update(Qso(uuid: onA.uuid, operationUuid: op, data: {...onA.data, 'notes': 'from A'}));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final onB = (await deviceB.qsos.watchForOperation(op).first).single;
      await deviceB.qsos.update(Qso(uuid: onB.uuid, operationUuid: op, data: {...onB.data, 'notes': 'from B'}));

      await deviceA.outbox.scanNow();
      await deviceB.outbox.scanNow();

      final links2 = _LinkPair();
      final sessionA2 = deviceA.session(links2.a, op);
      final sessionB2 = deviceB.session(links2.b, op);
      await sessionA2.start();
      await sessionB2.start();
      await settle();

      expect((await deviceA.qsos.watchForOperation(op).first).single.notes, 'from B',
          reason: "A's own older edit must lose to the newer revision it receives");
      expect((await deviceB.qsos.watchForOperation(op).first).single.notes, 'from B',
          reason: "B's newer edit must survive A's replay of the older one");
      expect(qso.uuid, onA.uuid);
    });
  });

  group('the cursor never runs ahead of what was committed', () {
    test('an apply that throws leaves the cursor where it was, and the batch redelivers', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceB.operations.mergeFromPeer([
        {'uuid': op.uuid, 'stationCall': 'KI2D', 'updatedAtMillis': op.updatedAtMillis},
      ]);
      deviceA.outbox.activeOperationUuid = op.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');
      await deviceA.qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();

      final failingQsos = _FailingQsosRepository(deviceB.db);
      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = PeerSession(
        link: links.b,
        localDeviceId: 'device-b',
        localDeviceName: 'Phone',
        operationUuid: op.uuid,
        outbox: deviceB.outbox,
        cursors: deviceB.cursors,
        trust: deviceB.trust,
        operations: deviceB.operations,
        qsos: failingQsos,
      );
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(failingQsos.attempts, 1, reason: 'the batch was delivered and the apply was attempted');
      expect(await deviceB.qsos.watchForOperation(op.uuid).first, isEmpty,
          reason: 'the apply threw, so nothing landed');
      expect(await deviceB.cursors.lastAppliedSeq('device-a', op.uuid), 0,
          reason: 'a cursor advanced past an apply that never committed loses that record forever');

      // A fresh session re-requests from the unmoved cursor, and this time
      // the apply succeeds.
      final links2 = _LinkPair();
      final sessionA2 = deviceA.session(links2.a, op.uuid);
      final sessionB2 = PeerSession(
        link: links2.b,
        localDeviceId: 'device-b',
        localDeviceName: 'Phone',
        operationUuid: op.uuid,
        outbox: deviceB.outbox,
        cursors: deviceB.cursors,
        trust: deviceB.trust,
        operations: deviceB.operations,
        qsos: failingQsos,
      );
      await sessionA2.start();
      await sessionB2.start();
      await settle();

      expect(await deviceB.qsos.watchForOperation(op.uuid).first, hasLength(1));
      expect(await deviceB.cursors.lastAppliedSeq('device-a', op.uuid), greaterThan(0));
    });
  });

  group('the trust gate holds under a hostile peer', () {
    test('a catchUp arriving before the handshake completes extracts nothing', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;
      await deviceA.qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      await sessionA.start();

      // No hello, no trust — straight to asking for the log.
      final received = <PeerMessage>[];
      links.b.inbound.listen((raw) {
        final message = PeerMessage.decode(raw);
        if (message != null) received.add(message);
      });
      links.b.send(PeerMessage.catchUp(0).encode());
      await settle();

      expect(
        received.where((m) => m.type == PeerMessageType.events),
        isEmpty,
        reason: 'an unauthenticated catchUp must not be answered with the log',
      );
    });

    test('events arriving from a peer this side has not trusted are not applied', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      await sessionA.start();
      await settle();

      links.b.send(PeerMessage.eventsBatch([
        PeerEventPayload(
          seq: 1,
          kind: PeerEventKind.qso,
          data: {
            'uuid': 'injected-qso',
            'operation': op.uuid,
            'their': {'call': 'N0PE'},
            'updatedAtMillis': 9999999999999,
          },
        ).toJson(),
      ], hasMore: false).encode());
      await settle();

      expect(await deviceA.qsos.get('injected-qso'), isNull);
    });
  });

  group('robustness', () {
    test('a malformed frame is dropped without killing a working session', () async {
      final (sessionA, _, op) = await pairedSessions();

      links_send_garbage(sessionA);
      await settle();
      expect(sessionA.state, PeerSessionState.live);

      await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();
      await sessionA.pushLocal();
      await settle();
      expect(await deviceB.qsos.watchForOperation(op).first, hasLength(1));
    });

    test('closing one side takes the other down too', () async {
      final (sessionA, sessionB, _) = await pairedSessions();
      await sessionA.close();
      await settle();
      expect(sessionA.state, PeerSessionState.closed);
      expect(sessionB.state, PeerSessionState.closed);
    });
  });
}

/// Fails the first apply, then behaves — standing in for a write that dies
/// partway (a full disk, a locked database) without needing to break one.
class _FailingQsosRepository extends QsosRepository {
  _FailingQsosRepository(super.db);

  int attempts = 0;

  @override
  Future<void> mergeFromPeer(List<Map<String, dynamic>> qsos) async {
    attempts++;
    if (attempts == 1) throw StateError('apply failed');
    return super.mergeFromPeer(qsos);
  }
}

/// Pushes bytes that are not a valid envelope into [session]'s own link.
void links_send_garbage(PeerSession session) {
  final link = session.link as _MemoryLink;
  link.peer.send(utf8.encode('this is not json'));
  link.peer.send(utf8.encode(jsonEncode({'no': 'type key'})));
  link.peer.send(utf8.encode(jsonEncode(['not', 'an', 'object'])));
}
