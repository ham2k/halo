// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PeerOutbox/PeerCursorStore (the durable local substrate for HALO-310 peer
// device sync) and the repositories' mergeFromPeer entrypoints. No transport
// exists yet — the "two devices" tests simulate one by round-tripping
// through two independent in-memory databases exactly the way a real
// transport eventually will: scan on one, read with eventsSince, apply with
// mergeFromPeer on the other, advance the cursor.
//
// PeerOutbox is scan-based, not a call-site hook: it doesn't know when a
// repository writes anything, it only knows how to catch up on whatever
// changed since its last scan. Every test below calls scanNow() directly
// rather than waiting on notifyChanged's debounce, for determinism — the
// debounce itself gets its own test.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('PeerOutbox', () {
    late HaLoDatabase db;
    late OperationsRepository operations;
    late QsosRepository qsos;
    late PeerOutbox outbox;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      outbox = PeerOutbox(db);
      operations = OperationsRepository(db);
      qsos = QsosRepository(db);
    });

    tearDown(() async {
      outbox.dispose();
      await db.close();
    });

    test('scanNow records nothing when no operation is active', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await outbox.scanNow();
      expect(await outbox.latestSeq(op.uuid), 0);
    });

    test('scanNow only picks up the active operation, not others', () async {
      final shared = await operations.create(stationCall: 'KI2D', userTitle: 'Shared');
      final other = await operations.create(stationCall: 'KI2D', userTitle: 'Not shared');
      outbox.activeOperationUuid = shared.uuid;

      await qsos.add(shared.uuid, {'their': {'call': 'W1AW'}});
      await qsos.add(other.uuid, {'their': {'call': 'K1ABC'}});
      await outbox.scanNow();

      expect(await outbox.latestSeq(shared.uuid), greaterThan(0));
      expect(await outbox.latestSeq(other.uuid), 0);
    });

    test('the first scan after sharing starts is a full snapshot of the operation and its QSOs', () async {
      final op = await operations.create(stationCall: 'KI2D', userTitle: 'Already underway');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      // Sharing turns on AFTER these were already logged.
      outbox.activeOperationUuid = op.uuid;
      await outbox.scanNow();

      final events = await outbox.eventsSince(op.uuid, 0);
      expect(events.map((e) => e.recordUuid).toSet(), {op.uuid, qso.uuid});
    });

    test('separate scans each pick up only what changed since the last one', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      await outbox.scanNow(); // the freshly-created (empty) operation

      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await outbox.scanNow();
      final second = await qsos.add(op.uuid, {'their': {'call': 'K1ABC'}});
      await outbox.scanNow();

      final qsoEvents = (await outbox.eventsSince(op.uuid, 0)).where((e) => e.kind == 'qso');
      expect(qsoEvents.map((e) => e.recordUuid), [qso.uuid, second.uuid]);
    });

    test('rapid edits scanned together coalesce into one event carrying the final state', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;

      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await qsos.update(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'edited'}));
      await qsos.softDelete(qso);
      await outbox.scanNow(); // one scan, after all three writes already committed

      final qsoEvents = (await outbox.eventsSince(op.uuid, 0)).where((e) => e.recordUuid == qso.uuid);
      expect(qsoEvents, hasLength(1), reason: 'PeerEvents is a snapshot log, not a diff — only the final state matters');
      expect(qsoEvents.single.data, contains('"deleted":true'));
    });

    test('purging a shared Test Operation records purged:true for the operation and every QSO', () async {
      final op = await operations.create(stationCall: 'KI2D/T');
      outbox.activeOperationUuid = op.uuid;
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      await operations.purge(op.uuid);
      await qsos.purgeForOperation(op.uuid);
      await outbox.scanNow();

      final events = await outbox.eventsSince(op.uuid, 0);
      final opEvent = events.singleWhere((e) => e.kind == 'operation' && e.recordUuid == op.uuid);
      expect(opEvent.data, contains('"purged":true'),
          reason: 'a peer must learn this was an unrecoverable purge, not an ordinary soft-delete');

      final qsoEvent = events.singleWhere((e) => e.kind == 'qso' && e.recordUuid == qso.uuid);
      expect(qsoEvent.data, contains('"purged":true'));
      expect(qsoEvent.data, contains('"deleted":true'));
    });

    test('a batch import into a shared operation reaches the outbox (inserts and updates)', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      final existing = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'notes': 'before import'});
      await outbox.scanNow();

      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [
          {'their': {'call': 'K1ABC'}, 'startAtMillis': 2000},
        ],
        updates: [
          Qso(uuid: existing.uuid, operationUuid: op.uuid, data: {...existing.data, 'notes': 'merged by import'}),
        ],
      );
      await outbox.scanNow();

      final events = await outbox.eventsSince(op.uuid, 0);
      final existingEvents = events.where((e) => e.recordUuid == existing.uuid);
      expect(existingEvents, hasLength(2), reason: 'the pre-import snapshot, then the import\'s update');
      expect(existingEvents.last.data, contains('"notes":"merged by import"'));

      final inserted = events.singleWhere((e) => e.data.contains('K1ABC'));
      expect(inserted.kind, 'qso');
    });

    test('an operation title change appends a fresh "operation" event', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      await outbox.scanNow();

      await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'userTitle': 'Renamed'}));
      await outbox.scanNow();

      final opEvents = (await outbox.eventsSince(op.uuid, 0)).where((e) => e.kind == 'operation');
      expect(opEvents, hasLength(2), reason: 'the creation snapshot, then the rename');
      expect(opEvents.last.data, contains('Renamed'));
    });

    test('eventsSince only returns events strictly newer than the given seq', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      await outbox.scanNow(); // the operation's own baseline snapshot

      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      final second = await qsos.add(op.uuid, {'their': {'call': 'K1ABC'}});
      await outbox.scanNow();

      final fromStart = (await outbox.eventsSince(op.uuid, 0)).where((e) => e.kind == 'qso').toList();
      expect(fromStart, hasLength(2));

      final caughtUp = await outbox.eventsSince(op.uuid, fromStart.first.seq);
      expect(caughtUp, hasLength(1));
      expect(caughtUp.single.recordUuid, second.uuid);
    });

    test('switching the active operation resets the watermark, so re-sharing re-snapshots everything', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await outbox.scanNow();
      final firstRoundCount = (await outbox.eventsSince(op.uuid, 0)).length;

      outbox.activeOperationUuid = null; // stop sharing
      outbox.activeOperationUuid = op.uuid; // and start again, nothing else changed
      await outbox.scanNow();

      final events = await outbox.eventsSince(op.uuid, 0);
      expect(events.length, greaterThan(firstRoundCount),
          reason: 'restart re-emits the operation and QSO even though neither changed since');
      expect(events.where((e) => e.recordUuid == qso.uuid), hasLength(2));
    });

    test('notifyChanged debounces into one scan', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      outbox.notifyChanged();
      expect(await outbox.latestSeq(op.uuid), 0); // not yet — still debouncing

      await Future<void>.delayed(PeerOutbox.debounceDelay + const Duration(milliseconds: 200));
      expect(await outbox.latestSeq(op.uuid), greaterThan(0));
    });

    test('two concurrent scans for the same operation do not duplicate events', () async {
      final op = await operations.create(stationCall: 'KI2D');
      outbox.activeOperationUuid = op.uuid;
      await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      // Both calls start in the same synchronous stretch, so the second
      // hits the reentrancy guard before the first's scan has even queried
      // the database.
      await Future.wait([outbox.scanNow(), outbox.scanNow()]);

      final events = await outbox.eventsSince(op.uuid, 0);
      expect(events.map((e) => e.recordUuid).toSet(), hasLength(events.length));
    });

    test('switching the active operation mid-scan does not corrupt the new operation\'s watermark', () async {
      final opA = await operations.create(stationCall: 'KI2D', userTitle: 'A');
      final opB = await operations.create(stationCall: 'KI2D', userTitle: 'B');
      outbox.activeOperationUuid = opA.uuid;
      await qsos.add(opA.uuid, {'their': {'call': 'W1AW'}});

      // Start A's scan but don't await it yet — it suspends at its first
      // `await`, having already captured operationUuid=A/generation=0.
      final scanA = outbox.scanNow();
      // Switch to B before A's scan resumes: bumps the generation and
      // resets the watermark to 0 for B.
      outbox.activeOperationUuid = opB.uuid;
      await scanA;

      // If A's completion had clobbered the watermark it just reset, this
      // scan would use A's (nonzero) watermark instead of B's fresh 0 and
      // silently skip B's own baseline snapshot.
      final qsoB = await qsos.add(opB.uuid, {'their': {'call': 'K1ABC'}});
      await outbox.scanNow();

      final eventsB = await outbox.eventsSince(opB.uuid, 0);
      expect(eventsB.map((e) => e.recordUuid), containsAll([opB.uuid, qsoB.uuid]));
    });
  });

  group('PeerCursorStore', () {
    late HaLoDatabase db;
    late PeerCursorStore cursors;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      cursors = PeerCursorStore(db);
    });

    tearDown(() async => db.close());

    test('an unknown peer/operation pair starts at 0', () async {
      expect(await cursors.lastAppliedSeq('peer-a', 'op-1'), 0);
    });

    test('advanceTo never rewinds a cursor that already moved further', () async {
      await cursors.advanceTo('peer-a', 'op-1', 5);
      await cursors.advanceTo('peer-a', 'op-1', 2); // a stale/out-of-order delivery
      expect(await cursors.lastAppliedSeq('peer-a', 'op-1'), 5);

      await cursors.advanceTo('peer-a', 'op-1', 9);
      expect(await cursors.lastAppliedSeq('peer-a', 'op-1'), 9);
    });

    test('two concurrent advances for the same pair never let the smaller value win', () async {
      // A live push (small seq) racing a catch-up batch (larger seq) for the
      // same peer/operation — without a transaction tying each call's read
      // to its write, both could read the same starting cursor and whichever
      // commits last would win outright, regardless of its value.
      await Future.wait([
        cursors.advanceTo('peer-a', 'op-1', 3),
        cursors.advanceTo('peer-a', 'op-1', 12),
      ]);
      expect(await cursors.lastAppliedSeq('peer-a', 'op-1'), 12);
    });

    test('cursors are independent per (peer, operation) pair', () async {
      await cursors.advanceTo('peer-a', 'op-1', 5);
      expect(await cursors.lastAppliedSeq('peer-a', 'op-2'), 0);
      expect(await cursors.lastAppliedSeq('peer-b', 'op-1'), 0);
    });
  });

  group('mergeFromPeer', () {
    late HaLoDatabase db;
    late OperationsRepository operations;
    late QsosRepository qsos;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
      qsos = QsosRepository(db);
    });

    tearDown(() async => db.close());

    test('unlike mergeFromSync, an applied record is left dirty so it still reaches LoFi', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await qsos.mergeFromPeer([
        {'uuid': 'peer-qso-1', 'operation': op.uuid, 'their': {'call': 'W1AW'}, 'updatedAtMillis': 1000},
      ]);
      expect(await qsos.hasUnsynced(), isTrue,
          reason: 'the originating peer device may never reach the internet itself');
    });

    test('a peer record never overwrites a newer local edit', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'notes': 'local edit'});

      await qsos.mergeFromPeer([
        {
          'uuid': qso.uuid,
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'notes': 'stale peer copy',
          'updatedAtMillis': qso.updatedAtMillis! - 1000,
        },
      ]);
      expect((await qsos.watchForOperation(op.uuid).first).single.notes, 'local edit');
    });

    test('a peer delete tombstones the local row', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      await qsos.mergeFromPeer([
        {
          'uuid': qso.uuid,
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'deleted': true,
          'updatedAtMillis': qso.updatedAtMillis! + 1000,
        },
      ]);
      expect(await qsos.watchForOperation(op.uuid).first, isEmpty);
      expect(await qsos.watchForOperation(op.uuid, includeDeleted: true).first, hasLength(1));
    });

    test('operations: applying twice (a redelivered event) is idempotent, not a duplicate', () async {
      final record = {
        'uuid': 'peer-op-1',
        'stationCall': 'KI2D',
        'userTitle': 'From a peer',
        'updatedAtMillis': 1000,
      };
      await operations.mergeFromPeer([record]);
      await operations.mergeFromPeer([record]);
      expect(await operations.watchAll().first, hasLength(1));
    });
  });

  group('two devices round-tripping through the outbox', () {
    test('a QSO logged on device A reaches device B via eventsSince + mergeFromPeer', () async {
      final dbA = HaLoDatabase(NativeDatabase.memory());
      final outboxA = PeerOutbox(dbA);
      final operationsA = OperationsRepository(dbA);
      final qsosA = QsosRepository(dbA);

      final dbB = HaLoDatabase(NativeDatabase.memory());
      final operationsB = OperationsRepository(dbB);
      final qsosB = QsosRepository(dbB);
      final cursorsB = PeerCursorStore(dbB);

      addTearDown(() async {
        outboxA.dispose();
        await dbA.close();
        await dbB.close();
      });

      // Both devices already agree on the operation itself (created earlier,
      // synced through LoFi, or shared via its own peer event) — this test
      // is only about the QSO stream.
      final op = await operationsA.create(stationCall: 'KI2D', userTitle: 'Shared activation');
      await operationsB.mergeFromPeer([
        {'uuid': op.uuid, 'stationCall': 'KI2D', 'userTitle': 'Shared activation', 'updatedAtMillis': op.updatedAtMillis},
      ]);
      outboxA.activeOperationUuid = op.uuid;

      await qsosA.add(op.uuid, {'their': {'call': 'W1AW'}});
      await qsosA.add(op.uuid, {'their': {'call': 'K1ABC'}});
      await outboxA.scanNow();

      // Device B catches up from scratch (cursor 0).
      final since = await cursorsB.lastAppliedSeq('device-a', op.uuid);
      final events = await outboxA.eventsSince(op.uuid, since);
      await qsosB.mergeFromPeer(events.map((e) => _decode(e.data)).toList());
      await cursorsB.advanceTo('device-a', op.uuid, events.last.seq);

      final onB = await qsosB.watchForOperation(op.uuid).first;
      expect(onB.map((q) => q.theirCall).toSet(), {'W1AW', 'K1ABC'});
      expect(await qsosB.hasUnsynced(), isTrue);

      // A third QSO, scanned, then a reconnect-style catch-up from the
      // advanced cursor only replays what's new — not the whole operation.
      await qsosA.add(op.uuid, {'their': {'call': 'EA4XYZ'}});
      await outboxA.scanNow();
      final resumeSince = await cursorsB.lastAppliedSeq('device-a', op.uuid);
      final resumeEvents = await outboxA.eventsSince(op.uuid, resumeSince);
      expect(resumeEvents, hasLength(1));
      await qsosB.mergeFromPeer(resumeEvents.map((e) => _decode(e.data)).toList());

      final finalOnB = await qsosB.watchForOperation(op.uuid).first;
      expect(finalOnB, hasLength(3));
    });
  });
}

Map<String, dynamic> _decode(String json) => jsonDecode(json) as Map<String, dynamic>;
