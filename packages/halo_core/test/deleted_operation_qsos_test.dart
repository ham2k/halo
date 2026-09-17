// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Deleting an operation deliberately does NOT tombstone its QSOs: doing so
// would be unrecoverable, because undeleting could no longer tell which QSOs
// the user had deleted individually beforehand from the ones the cascade
// took. The cost of that choice is that every cross-operation query has to
// join — a QSO is gone when its own flag says so OR when its operation's
// does. These tests pin both halves, since the failure mode is silent:
// contacts from a deleted operation quietly reappearing in call history.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async => db.close());

  test('deleting an operation leaves its QSOs alone, flags and all', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    final kept = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    final deletedByHand = await qsos.add(op.uuid, {
      'their': {'call': 'K2ABC'},
    });
    await qsos.softDelete(deletedByHand);

    await operations.softDelete(op.uuid);

    // The point of not cascading: the individually-deleted QSO is still
    // distinguishable from the one that was only caught by the operation.
    expect((await qsos.get(kept.uuid))!.deleted, isFalse);
    expect((await qsos.get(deletedByHand.uuid))!.deleted, isTrue);
  });

  test('call history skips QSOs whose operation is deleted', () async {
    final live = await operations.create(stationCall: 'N0DEV');
    final doomed = await operations.create(stationCall: 'N0DEV');
    await qsos.add(live.uuid, {
      'their': {'call': 'W1AW'},
    });
    await qsos.add(doomed.uuid, {
      'their': {'call': 'W1AW'},
    });

    expect((await qsos.historyForCall('W1AW')).length, 2);

    await operations.softDelete(doomed.uuid);

    final history = await qsos.historyForCall('W1AW');
    expect(history.length, 1);
    expect(history.single.operationUuid, live.uuid);
  });

  test('undeleting an operation brings its QSOs back, minus the ones deleted by hand', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    final byHand = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    await qsos.softDelete(byHand);
    // Undelete tells the two deletes apart by their stamps, which have
    // millisecond resolution: back to back, as only a test can do it, they tie.
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await operations.softDelete(op.uuid);
    expect(await qsos.historyForCall('W1AW'), isEmpty);

    // No cascade to undo: the tombstone's stamp matches no QSO here.
    await undeleteOperationWithQsos(db: db, operations: operations, qsos: qsos, uuid: op.uuid);

    final history = await qsos.historyForCall('W1AW');
    expect(history.length, 1, reason: 'the hand-deleted QSO stays deleted');
  });

  test('undelete re-stamps and unsyncs, or sync keeps the newer tombstone and re-deletes the operation', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await operations.softDelete(op.uuid);
    final tombstone = (await operations.get(op.uuid))!;
    await (db.update(db.operations)..where((o) => o.uuid.equals(op.uuid)))
        .write(const OperationsCompanion(synced: Value(true)));
    // The real clock has millisecond resolution; a restore landing in the
    // tombstone's own millisecond would tie with it rather than beat it.
    await Future<void>.delayed(const Duration(milliseconds: 2));

    expect(await operations.undelete(op.uuid), isTrue);

    final restored = (await operations.get(op.uuid))!;
    expect(restored.deleted, isFalse);
    expect(restored.synced, isFalse);
    expect(restored.data['updatedAtMillis'] as int, greaterThan(tombstone.data['updatedAtMillis'] as int));
    final row = await (db.select(db.operations)..where((o) => o.uuid.equals(op.uuid))).getSingle();
    expect(row.updatedAtMillis, restored.data['updatedAtMillis'], reason: 'the column mirrors the data stamp');
  });

  test('undelete leaves a purged operation alone — its QSOs are purged and peers may have hard-deleted it', () async {
    final op = await operations.create(stationCall: 'N0DEV/TEST');
    await operations.purge(op.uuid);

    expect(await operations.undelete(op.uuid), isFalse);
    expect((await operations.get(op.uuid))!.deleted, isTrue);
  });

  test('the deleted list offers what can be undeleted: soft-deleted operations, never purged ones', () async {
    final live = await operations.create(stationCall: 'N0DEV');
    final deleted = await operations.create(stationCall: 'N0DEV');
    final purged = await operations.create(stationCall: 'N0DEV/TEST');
    await operations.softDelete(deleted.uuid);
    await operations.purge(purged.uuid);

    expect((await operations.watchAll().first).map((o) => o.uuid), [live.uuid]);
    expect(
      (await operations.watchAll(includeDeleted: true).first).map((o) => o.uuid),
      unorderedEquals([live.uuid, deleted.uuid]),
    );
  });

  // app-polo's `deleteOperation` tombstones every QSO along with the
  // operation, writing ONE `Date.now()` to all of them, in its own dialect
  // (`deleted: 1`). That shared stamp is the only thing telling those QSOs
  // from the ones the operator deleted by hand, so it is what undelete keys on.
  test('undeleting an operation app-polo deleted restores the QSOs it took, not the ones deleted by hand', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    final taken = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    final byHand = await qsos.add(op.uuid, {
      'their': {'call': 'K2ABC'},
    });
    await qsos.softDelete(byHand);

    // Newer than every local stamp, so the merge takes it; barely, so the
    // restore below — stamped from the real clock — is newer still.
    final poloDeletedAt = realNowMillis() + 5;
    await operations.mergeFromSync([
      {...(await operations.get(op.uuid))!.data, 'uuid': op.uuid, 'deleted': 1, 'updatedAtMillis': poloDeletedAt},
    ]);
    await qsos.mergeFromSync([
      for (final qso in [taken, byHand])
        {
          ...(await qsos.get(qso.uuid))!.data,
          'uuid': qso.uuid,
          'operation': op.uuid,
          'deleted': 1,
          // The by-hand delete happened on the other device too, earlier.
          'updatedAtMillis': qso.uuid == taken.uuid ? poloDeletedAt : poloDeletedAt - 1,
        },
    ]);
    expect((await operations.get(op.uuid))!.deleted, isTrue);
    expect((await qsos.get(taken.uuid))!.deleted, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await undeleteOperationWithQsos(db: db, operations: operations, qsos: qsos, uuid: op.uuid);

    final restored = (await qsos.get(taken.uuid))!;
    expect(restored.deleted, isFalse);
    final restoredRow = await (db.select(db.qsos)..where((q) => q.uuid.equals(taken.uuid))).getSingle();
    expect(restoredRow.synced, isFalse, reason: 'unsynced, or the restore never leaves this device');
    // A column that drifts from the data's stamp fails `markSynced`'s
    // comparison forever, and the row re-pushes in a loop.
    expect(restoredRow.updatedAtMillis, restored.data['updatedAtMillis']);
    expect(restored.data['updatedAtMillis'] as int, greaterThan(poloDeletedAt));
    expect((await qsos.get(byHand.uuid))!.deleted, isTrue);
    expect((await operations.get(op.uuid))!.qsoCount, 1, reason: 'the cached count follows the restored QSO');
  });

  group('sync counts', () {
    test('totals hold what the device HAS: tombstones drop out', () async {
      final live = await operations.create(stationCall: 'N0DEV');
      final doomed = await operations.create(stationCall: 'N0DEV');
      await qsos.add(live.uuid, {
        'their': {'call': 'W1AW'},
      });
      await qsos.add(doomed.uuid, {
        'their': {'call': 'K2ABC'},
      });

      expect((await operations.syncCounts()).total, 2);
      expect((await qsos.syncCounts()).total, 2);

      await operations.softDelete(doomed.uuid);

      expect((await operations.syncCounts()).total, 1);
      // Its QSO is untouched on disk, but no longer counts as held.
      expect((await qsos.syncCounts()).total, 1);
    });

    test('pending still counts tombstones — a delete only travels by being pushed', () async {
      final op = await operations.create(stationCall: 'N0DEV');
      final qso = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'},
      });
      await operations.markSynced([op]);
      await qsos.markSynced([await qsos.get(qso.uuid) as Qso]);
      expect((await operations.syncCounts()).pending, 0);

      await operations.softDelete(op.uuid);

      expect((await operations.syncCounts()).pending, 1, reason: 'the tombstone still owes the server a push');
      expect((await operations.syncCounts()).total, 0);
    });

    // `band` is nullable, and `NOT (band = 'event')` is NULL — not true — for
    // a QSO logged without one. Written that way, the marker filter drops
    // those QSOs from `total` without putting them anywhere else: under a
    // naive negation they are neither a contact nor an event, and simply
    // vanish from every number the operator is shown.
    test('a QSO with no band is a contact, not an event, in both count methods', () async {
      final op = await operations.create(stationCall: 'N0DEV');
      await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'},
      });
      await qsos.add(op.uuid, {
        'their': {'call': 'K2ABC'},
        'band': '20m',
      });
      await qsos.addEvent(op.uuid, kind: 'start', atMillis: 1000);

      expect((await qsos.syncCounts()).total, 2);

      final perOperation = await qsos.syncCountsForOperation(op.uuid);
      expect(perOperation.total, 2, reason: 'the band-less QSO is a contact');
      expect(perOperation.pending, 2, reason: 'and it is one the export panel still owes a push');
      expect(perOperation.eventTotal, 1, reason: 'and it is not an event either');
    });

    test('per-operation counts split contacts from markers, pending included', () async {
      final op = await operations.create(stationCall: 'N0DEV');
      final contact = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'},
      });
      await qsos.addEvent(op.uuid, kind: 'start', atMillis: 1000);
      await qsos.markSynced([await qsos.get(contact.uuid) as Qso]);

      final counts = await qsos.syncCountsForOperation(op.uuid);
      expect(counts.total, 1);
      expect(counts.pending, 0, reason: 'the only contact is synced');
      expect(counts.eventTotal, 1);
      expect(counts.eventPending, 1, reason: 'the marker still owes a push');
    });
  });

  test('a QSO whose operation row is missing still counts — sync can deliver them out of order', () async {
    await qsos.add('an-operation-that-has-not-arrived-yet', {
      'their': {'call': 'W1AW'},
    });

    expect((await qsos.historyForCall('W1AW')).length, 1);
  });
}
