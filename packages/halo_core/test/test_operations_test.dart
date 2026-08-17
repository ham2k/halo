// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Test Operations (a station call ending `/T` or `/TEST`) are purged, not
// merely soft-deleted: `OperationsRepository.purge`/`QsosRepository.
// purgeForOperation` write the same `deleted: true` tombstone `softDelete`
// does, but also `purged: true`, so the row still pushes through the normal
// dirty-row sync pipeline before `hardDeletePurged` physically removes it —
// the deferred half `SyncEngine` runs once that push is acknowledged. These
// tests pin the two-step shape and the guard that keeps a still-dirty row
// from being purged out from under a concurrent edit.

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
    qsos = QsosRepository(db, sequences: SequencesRepository(db));
  });

  tearDown(() async => db.close());

  test('isTestOperation matches a /T or /TEST suffix on any comma-separated call, not other suffixes', () {
    expect(Operation(uuid: 'u', data: {'stationCall': 'KI2D/T'}).isTestOperation, isTrue);
    expect(Operation(uuid: 'u', data: {'stationCall': 'KI2D/TEST'}).isTestOperation, isTrue);
    expect(Operation(uuid: 'u', data: {'stationCall': 'KI2D, W1AW/T'}).isTestOperation, isTrue);
    expect(Operation(uuid: 'u', data: {'stationCall': 'KI2D'}).isTestOperation, isFalse);
    expect(Operation(uuid: 'u', data: {'stationCall': 'KI2D/P'}).isTestOperation, isFalse);
  });

  test('purge tombstones like softDelete but also sets purged, and re-dirties the row', () async {
    final op = await operations.create(stationCall: 'KI2D/T');
    await operations.markSynced([op]);
    expect((await operations.get(op.uuid))!.synced, isTrue);

    await operations.purge(op.uuid);

    final row = await operations.get(op.uuid);
    expect(row!.deleted, isTrue);
    expect(row.purged, isTrue);
    expect(row.synced, isFalse, reason: 'the tombstone must push before the row can be hard-deleted');
  });

  test('hardDeletePurged only removes rows that are purged AND synced', () async {
    final purged = await operations.create(stationCall: 'KI2D/T');
    final deletedOnly = await operations.create(stationCall: 'N0DEV');
    await operations.purge(purged.uuid);
    await operations.softDelete(deletedOnly.uuid);

    // Neither push has been acknowledged yet — hard-deleting now must no-op.
    expect(await operations.hardDeletePurged(), isEmpty);
    expect(await operations.get(purged.uuid), isNotNull);

    await operations.markSynced([(await operations.get(purged.uuid))!, (await operations.get(deletedOnly.uuid))!]);

    final removed = await operations.hardDeletePurged();
    expect(removed, [purged.uuid]);
    expect(await operations.get(purged.uuid), isNull, reason: 'purged AND synced — the row is gone for real');
    expect(await operations.get(deletedOnly.uuid), isNotNull,
        reason: 'a normal (non-purged) delete must never be hard-deleted');
  });

  test('hardDeletePurged sweeps every purged+synced row, not just a caller-scoped batch', () async {
    // Pins the crash-safety fix: a row that was already synced+purged before
    // this call (e.g. a previous round crashed right after markSynced, before
    // the sweep ran) must still be caught — a batch-scoped sweep would have
    // no way back to it once it stops being dirty.
    final op = await operations.create(stationCall: 'KI2D/T');
    await operations.purge(op.uuid);
    await operations.markSynced([(await operations.get(op.uuid))!]);

    expect(await operations.hardDeletePurged(), [op.uuid]);
    expect(await operations.get(op.uuid), isNull);
  });

  test('purgeForOperation tombstones every QSO regardless of its own prior deleted state', () async {
    final op = await operations.create(stationCall: 'KI2D/T');
    final kept = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    final alreadyDeleted = await qsos.add(op.uuid, {
      'their': {'call': 'K2ABC'},
    });
    await qsos.softDelete(alreadyDeleted);

    await qsos.purgeForOperation(op.uuid);

    for (final uuid in [kept.uuid, alreadyDeleted.uuid]) {
      final row = await qsos.get(uuid);
      expect(row!.deleted, isTrue);
      expect(row.purged, isTrue);
    }
  });

  test('hardDeletePurgedForOperation removes only that operation\'s purged+synced QSOs', () async {
    final op = await operations.create(stationCall: 'KI2D/T');
    final other = await operations.create(stationCall: 'N0DEV');
    final qso = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    final otherQso = await qsos.add(other.uuid, {
      'their': {'call': 'W1AW'},
    });
    await qsos.purgeForOperation(op.uuid);
    await qsos.markSynced([(await qsos.get(qso.uuid))!]);

    await qsos.hardDeletePurgedForOperation(op.uuid);

    expect(await qsos.get(qso.uuid), isNull);
    expect(await qsos.get(otherQso.uuid), isNotNull, reason: 'a purge scoped to one operation must not touch another');
  });

  test('mergeFromSync carries purged through without ever hard-deleting the local row', () async {
    await operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 1},
    ]);

    // The whole point of the receiving side: still just a tombstone.
    final row = await operations.get('remote-op');
    expect(row, isNotNull, reason: 'receiving a purged operation must never remove the row locally');
    expect(row!.deleted, isTrue);
  });
}
