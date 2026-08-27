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

  /// Both devices are the same operator's by default — the ordinary case,
  /// and what lets an operation neither has shared before cross at all. A
  /// test about the account gate reassigns this before building its session.
  String? accountTag = 'account-1';
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final PeerCursorStore cursors;
  late final PeerTrustStore trust;
  late final OperationsRepository operations;
  late final QsosRepository qsos;

  PeerSession session(
    PeerLink link,
    String? sharing, {
    List<String> capabilities = const [],
    void Function(PeerSession, PeerMessage)? onEphemeral,
    void Function(PeerSession)? onEstablished,
  }) =>
      PeerSession(
        link: link,
        localDeviceId: deviceId,
        localDeviceName: name,
        sharedOperationUuid: sharing,
        localAccountTag: accountTag,
        localCapabilities: capabilities,
        outbox: outbox,
        cursors: cursors,
        trust: trust,
        operations: operations,
        qsos: qsos,
        onEphemeral: onEphemeral,
        onEstablished: onEstablished,
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

    test('a side that has confirmed reports it, while the state waits for the other', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = deviceB.session(links.b, op.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();

      await sessionB.acceptPairing();
      await settle();

      // The trap: `needsPairing` means "not yet mutual", NOT "this operator
      // has not answered". A caller that prompts on the state alone re-asks
      // B's operator on every notification until A's operator confirms.
      expect(sessionB.state, PeerSessionState.needsPairing,
          reason: 'mutual trust still needs A, so the state cannot advance yet');
      expect(sessionB.localTrusts, isTrue, reason: 'B answered — nothing may ask B again');
      expect(sessionA.localTrusts, isFalse, reason: 'A has not been asked yet');
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

    test('an operation open on the peer reaches a device that has never seen it', () async {
      // The reason receiving follows the PEER's declaration and not a match
      // between the two: B cannot name opA — it has no such row — so a rule
      // that waited for both sides to name the same operation would leave a
      // newly created one permanently unreachable.
      //
      // The operator's own two devices, on one account (the harness default)
      // — the only pair an operation neither has shared before crosses.
      final opA = await deviceA.operations.create(stationCall: 'KI2D', userTitle: 'Field day');
      deviceA.outbox.activeOperationUuid = opA.uuid;
      await deviceA.qsos.add(opA.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opA.uuid);
      // Nothing open on B at all — the case the operator actually hits when
      // they pick up a second device.
      final sessionB = deviceB.session(links.b, null);
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect((await deviceB.operations.get(opA.uuid))?.userTitle, 'Field day',
          reason: 'the operation itself must arrive, not just its QSOs');
      expect((await deviceB.qsos.watchForOperation(opA.uuid).first).map((q) => q.theirCall),
          ['W1AW']);
      expect(sessionB.state, PeerSessionState.live);
      expect(sessionA.state, PeerSessionState.live,
          reason: 'the device being pulled FROM is carrying a log, not idling');
    });

    test('a QSO logged after the pull keeps streaming, with nothing shared back', () async {
      // The live push is gated on the peer having ASKED for this operation,
      // never on it sharing one back — the puller shares nothing, so a gate
      // on a matching operation would hand it the backlog once and then go
      // quiet until the link dropped.
      final opA = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = opA.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opA.uuid);
      final sessionB = deviceB.session(links.b, null);
      await sessionA.start();
      await sessionB.start();
      await settle();

      // Logged AFTER catch-up finished, so only a live push can carry it.
      await deviceA.qsos.add(opA.uuid, {'their': {'call': 'K1ABC'}});
      await deviceA.outbox.scanNow();
      await sessionA.pushLocal();
      await settle();

      expect((await deviceB.qsos.watchForOperation(opA.uuid).first).map((q) => q.theirCall),
          ['K1ABC']);
    });

    test('sync engages in place when an operation is opened mid-session', () async {
      // The whole point of device-bound sessions: opening an operation moves
      // the sync without touching the link.
      final opA = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceA.qsos.add(opA.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      // Neither side is in an operation, so there is nothing to carry yet.
      final sessionA = deviceA.session(links.a, null);
      final sessionB = deviceB.session(links.b, null);
      await sessionA.start();
      await sessionB.start();
      await settle();
      expect(sessionA.state, PeerSessionState.connected, reason: 'sanity: idle with nothing open');
      expect(sessionB.state, PeerSessionState.connected);

      // The laptop opens its operation.
      deviceA.outbox.activeOperationUuid = opA.uuid;
      await deviceA.outbox.scanNow();
      await sessionA.setSharing(opA.uuid);
      await settle();

      expect(sessionB.state, PeerSessionState.live);
      final onB = await deviceB.qsos.watchForOperation(opA.uuid).first;
      expect(onB.map((q) => q.theirCall), ['W1AW'],
          reason: 'catch-up must run for the newly opened operation over the SAME link');
    });

    test('closing the operation on one device does not stop the other\'s log arriving', () async {
      // Closing an operation stops what this device SERVES, not what it
      // receives: the far side is still in that operation and still logging,
      // and a laptop put down mid-activation must not stop collecting what
      // the phone works.
      final (sessionA, sessionB, op) = await pairedSessions();
      expect(sessionA.state, PeerSessionState.live, reason: 'sanity');

      await sessionA.setSharing(null);
      await settle();

      await deviceB.qsos.add(op, {'their': {'call': 'K1ABC'}});
      await deviceB.outbox.scanNow();
      await sessionB.pushLocal();
      await settle();

      expect((await deviceA.qsos.watchForOperation(op).first).map((q) => q.theirCall),
          contains('K1ABC'));
    });

    test('with neither side in the operation the sync idles without dropping the session',
        () async {
      final (sessionA, sessionB, op) = await pairedSessions();
      expect(sessionA.state, PeerSessionState.live, reason: 'sanity');

      await sessionA.setSharing(null);
      await sessionB.setSharing(null);
      await settle();

      expect(sessionA.state, PeerSessionState.connected);
      expect(sessionB.state, PeerSessionState.connected,
          reason: 'each side hears the other\'s sharing change and idles too');

      // A QSO logged on B for the now-closed operation must not cross.
      await deviceB.qsos.add(op, {'their': {'call': 'K1ABC'}});
      await deviceB.outbox.scanNow();
      await sessionB.pushLocal();
      await settle();
      final onA = await deviceA.qsos.watchForOperation(op).first;
      expect(onA.where((q) => q.theirCall == 'K1ABC'), isEmpty);

      // Re-opening it resumes over the same link, from the cursor.
      await sessionB.setSharing(op);
      await settle();
      expect((await deviceA.qsos.watchForOperation(op).first).map((q) => q.theirCall).toSet(),
          contains('K1ABC'));
      expect(sessionA.state, PeerSessionState.live);
    });

    test('an unseen operation is NOT taken from a peer on another account', () async {
      // The consent line: what two operators have already shared keeps
      // flowing, but an operation one of them has never seen does not cross
      // an account boundary — that needs the owner's say-so, and there is
      // nowhere yet for them to give it.
      deviceB.accountTag = 'account-2';
      final opA = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = opA.uuid;
      await deviceA.qsos.add(opA.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opA.uuid);
      final sessionB = deviceB.session(links.b, null);
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(await deviceB.operations.get(opA.uuid), isNull);
      expect(await deviceB.qsos.watchForOperation(opA.uuid).first, isEmpty);
      expect(sessionB.state, PeerSessionState.connected,
          reason: 'the pair stays up for ephemeral traffic — it is the durable sync that idles');
    });

    test('an operation BOTH already have still syncs across accounts', () async {
      // A joint activation the two operators have shared before. Refusing
      // this would break the pairing they already had.
      deviceB.accountTag = 'account-2';
      final (sessionA, sessionB, op) = await pairedSessions();

      await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();
      await sessionA.pushLocal();
      await settle();

      expect((await deviceB.qsos.watchForOperation(op).first).map((q) => q.theirCall), ['W1AW']);
      expect(sessionB.state, PeerSessionState.live);
    });

    test('two devices signed in to nothing do not read as one account', () async {
      // Null must never match null: an account-less pair cannot show they
      // belong to one operator, and treating them as if they could would
      // hand the whole gate to anyone willing to sign out.
      deviceA.accountTag = null;
      deviceB.accountTag = null;
      final opA = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = opA.uuid;
      await deviceA.qsos.add(opA.uuid, {'their': {'call': 'W1AW'}});
      await deviceA.outbox.scanNow();
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opA.uuid);
      final sessionB = deviceB.session(links.b, null);
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(await deviceB.operations.get(opA.uuid), isNull);
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
        sharedOperationUuid: op.uuid,
        localAccountTag: deviceA.accountTag,
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

    test('a serve interrupted mid-backlog does not pin the session at syncing', () async {
      // `syncing` must mean a batch is really in train. The operator closing
      // the operation between a full batch and its ack leaves the serve
      // stalled with no ack coming — and a session that reads "Syncing…"
      // forever afterwards is a healthy link the operator sees as broken.
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;
      await deviceA.trust.trust('device-b', name: 'Phone');
      for (var i = 0; i < 6; i++) {
        await deviceA.qsos.add(op.uuid, {'their': {'call': 'W${i}AW'}, 'startAtMillis': 1000 + i});
      }
      await deviceA.outbox.scanNow();

      final links = _LinkPair();
      final sessionA = PeerSession(
        link: links.a,
        localDeviceId: 'device-a',
        localDeviceName: 'Laptop',
        sharedOperationUuid: op.uuid,
        localAccountTag: deviceA.accountTag,
        outbox: deviceA.outbox,
        cursors: deviceA.cursors,
        trust: deviceA.trust,
        operations: deviceA.operations,
        qsos: deviceA.qsos,
        // Below the backlog, so the first batch A sends says hasMore.
        batchLimit: 2,
      );
      await sessionA.start();

      // A hand-driven peer: it shares the operation and answers A's own
      // catch-up with nothing, so A's RECEIVE direction settles — then it
      // asks for the backlog and never acks a byte of it.
      links.b.send(PeerMessage.hello(
        deviceId: 'device-b',
        deviceName: 'Phone',
        operationUuid: op.uuid,
      ).encode());
      links.b.send(PeerMessage.trusted().encode());
      links.b.send(PeerMessage.eventsBatch(op.uuid, const [], hasMore: false).encode());
      links.b.send(PeerMessage.catchUp(op.uuid, 0).encode());
      await settle();
      expect(sessionA.state, PeerSessionState.syncing,
          reason: 'sanity: a full batch went out and its ack is outstanding');

      await sessionA.setSharing(null);
      await settle();

      expect(sessionA.state, PeerSessionState.live,
          reason: 'A serves nothing now, so the abandoned batch must stop counting as in train');
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
        sharedOperationUuid: op.uuid,
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
        sharedOperationUuid: op.uuid,
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
      // The real uuid on purpose: beacons leak it, so an attacker has it,
      // and this test must prove the TRUST gate alone stops the extraction.
      links.b.send(PeerMessage.catchUp(op.uuid, 0).encode());
      await settle();

      expect(
        received.where((m) => m.type == PeerMessageType.events),
        isEmpty,
        reason: 'an unauthenticated catchUp must not be answered with the log',
      );
    });

    test('a trusted peer asking for an UNSHARED operation gets silence, not the log', () async {
      // The outbox keeps roughly one row per record of every operation ever
      // shared, indefinitely. Sharing is the operator's per-operation
      // consent, so a peer — even a trusted one — asking for an operation
      // this side is not currently sharing must extract nothing: without
      // this, closing an operation would not end its exposure.
      final opShared = await deviceA.operations.create(stationCall: 'KI2D');
      final opClosed = await deviceA.operations.create(stationCall: 'KI2D/P');
      deviceA.outbox.activeOperationUuid = opClosed.uuid;
      await deviceA.qsos.add(opClosed.uuid, {'their': {'call': 'SECRET1'}});
      await deviceA.outbox.scanNow();
      deviceA.outbox.activeOperationUuid = opShared.uuid;
      await deviceA.outbox.scanNow();
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opShared.uuid);
      final sessionB = deviceB.session(links.b, opShared.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();
      expect(sessionA.state, PeerSessionState.live, reason: 'sanity: fully established');

      final received = <PeerMessage>[];
      links.b.onSend = null;
      final linkB = links.b;
      // B "goes rogue" below the session: raw catch-up for the closed
      // operation, on an otherwise legitimate, fully trusted link.
      var closedOpEvents = 0;
      linkB.peer.onSend = null;
      links.a.onSend = (raw) {
        final message = PeerMessage.decode(raw);
        if (message?.type == PeerMessageType.events &&
            message!.operationUuid == opClosed.uuid &&
            message.events.isNotEmpty) {
          closedOpEvents += message.events.length;
        }
        if (message != null) received.add(message);
      };
      linkB.send(PeerMessage.catchUp(opClosed.uuid, 0).encode());
      await settle();

      expect(closedOpEvents, 0,
          reason: 'rows for an operation no longer shared must never be served');
    });

    test('a trusted peer pushing events for an UNSHARED operation writes nothing', () async {
      // The write-side twin of the catch-up guard above: a batch is applied
      // only for the operation this side ASKED for. An unsolicited one aimed
      // at an operation nobody is catching up on writes nothing — which
      // bounds a confused or stale peer, not a determined one: declaring the
      // operation first would get it in (see _onEvents' comment on what this
      // gate is and is not).
      final opShared = await deviceA.operations.create(stationCall: 'KI2D');
      final opClosed = await deviceA.operations.create(stationCall: 'KI2D/P');
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, opShared.uuid);
      final sessionB = deviceB.session(links.b, opShared.uuid);
      await sessionA.start();
      await sessionB.start();
      await settle();
      expect(sessionA.state, PeerSessionState.live, reason: 'sanity: fully established');

      links.b.send(PeerMessage.eventsBatch(opClosed.uuid, [
        PeerEventPayload(
          seq: 1,
          kind: PeerEventKind.qso,
          data: {
            'uuid': 'injected-into-closed',
            'operation': opClosed.uuid,
            'their': {'call': 'N0PE'},
            'updatedAtMillis': 9999999999999,
          },
        ).toJson(),
      ], hasMore: false).encode());
      await settle();

      expect(await deviceA.qsos.get('injected-into-closed'), isNull);
      expect(await deviceA.cursors.lastAppliedSeq('device-b', opClosed.uuid), 0,
          reason: 'nor may the rejected batch move any cursor');
    });

    test('events arriving from a peer this side has not trusted are not applied', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      deviceA.outbox.activeOperationUuid = op.uuid;

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      await sessionA.start();
      await settle();

      links.b.send(PeerMessage.eventsBatch(op.uuid, [
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

  group('the ephemeral channel', () {
    test('an established pair exchanges ephemeral messages both ways', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final seenByA = <PeerMessage>[];
      final seenByB = <PeerMessage>[];
      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid, onEphemeral: (_, m) => seenByA.add(m));
      // Different operation on purpose: ephemeral traffic must not depend on
      // the durable sync being engaged.
      final sessionB = deviceB.session(links.b, null, onEphemeral: (_, m) => seenByB.add(m));
      await sessionA.start();
      await sessionB.start();
      await settle();

      sessionA.sendEphemeral(const PeerMessage('position', {'lat': 40.7, 'lon': -74.0}));
      sessionB.sendEphemeral(const PeerMessage('catStatus', {'freqKHz': 14285.0}));
      await settle();

      expect(seenByB.single.type, 'position');
      expect(seenByB.single.fields['lat'], 40.7);
      expect(seenByA.single.type, 'catStatus');
    });

    test('nothing ephemeral is sent or delivered before mutual trust', () async {
      // The security property, both directions. A peer that has not been
      // welcomed must neither feed this device positions nor receive its
      // own — an untrusted device tuning a radio is the concrete stake.
      final op = await deviceA.operations.create(stationCall: 'KI2D');

      final seenByA = <PeerMessage>[];
      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid, onEphemeral: (_, m) => seenByA.add(m));
      await sessionA.start();
      await settle();

      // Inbound from a stranger mid-handshake: dropped before the callback.
      links.b.send(const PeerMessage('position', {'lat': 1.0}).encode());
      await settle();
      expect(seenByA, isEmpty);

      // Outbound while not established: dropped at the send.
      final sent = <String>[];
      links.a.onSend = (raw) {
        final message = PeerMessage.decode(raw);
        if (message != null) sent.add(message.type);
      };
      sessionA.sendEphemeral(const PeerMessage('position', {'lat': 2.0}));
      await settle();
      expect(sent, isEmpty);
    });

    test('a type from a newer build reaches the consumer instead of being eaten', () async {
      // Forward compatibility is the point of routing UNKNOWN types to the
      // callback: a consumer that cares can act, one that does not ignores
      // it, and the session itself never has to learn new features. The
      // trap this pins: a session that switched on a KNOWN-type list would
      // silently eat everything a newer build invents.
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final seenByB = <PeerMessage>[];
      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid);
      final sessionB = deviceB.session(links.b, op.uuid, onEphemeral: (_, m) => seenByB.add(m));
      await sessionA.start();
      await sessionB.start();
      await settle();

      sessionA.sendEphemeral(const PeerMessage('somethingFromTheFuture', {'x': 1}));
      await settle();

      expect(seenByB.map((m) => m.type), contains('somethingFromTheFuture'));
    });

    test('onEstablished fires exactly once, in time to send a snapshot', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final seenByB = <PeerMessage>[];
      var establishedCount = 0;
      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid, onEstablished: (session) {
        establishedCount++;
        // The snapshot pattern: latest-value state sent the moment the peer
        // can receive it. If this send is dropped, onEstablished fired too
        // early to be usable and the whole snapshot design is broken.
        session.sendEphemeral(const PeerMessage('position', {'lat': 40.7}));
      });
      final sessionB = deviceB.session(links.b, op.uuid, onEphemeral: (_, m) => seenByB.add(m));
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(establishedCount, 1);
      expect(seenByB.map((m) => m.type), contains('position'));
    });

    test('capabilities travel in the hello and surface on the far side', () async {
      final op = await deviceA.operations.create(stationCall: 'KI2D');
      await deviceA.trust.trust('device-b', name: 'Phone');
      await deviceB.trust.trust('device-a', name: 'Laptop');

      final links = _LinkPair();
      final sessionA = deviceA.session(links.a, op.uuid, capabilities: const ['cat']);
      final sessionB = deviceB.session(links.b, op.uuid, capabilities: const ['gps']);
      await sessionA.start();
      await sessionB.start();
      await settle();

      expect(sessionA.peer?.capabilities, ['gps']);
      expect(sessionB.peer?.capabilities, ['cat']);
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
