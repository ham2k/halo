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

    await operations.softDelete(op.uuid);
    expect(await qsos.historyForCall('W1AW'), isEmpty);

    // Restoring the operation is a plain data write — no cascade to undo.
    final restored = await operations.get(op.uuid);
    await operations.saveData(restored!);
    await (db.update(db.operations)..where((o) => o.uuid.equals(op.uuid)))
        .write(const OperationsCompanion(deleted: Value(false)));

    final history = await qsos.historyForCall('W1AW');
    expect(history.length, 1, reason: 'the hand-deleted QSO stays deleted');
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
  });

  test('a QSO whose operation row is missing still counts — sync can deliver them out of order', () async {
    await qsos.add('an-operation-that-has-not-arrived-yet', {
      'their': {'call': 'W1AW'},
    });

    expect((await qsos.historyForCall('W1AW')).length, 1);
  });
}
