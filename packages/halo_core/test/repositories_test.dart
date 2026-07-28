// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

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

  tearDown(() async {
    await db.close();
  });

  test('create and watch operations', () async {
    final op = await operations.create(stationCall: 'ki2d', userTitle: 'Test op');
    expect(op.stationCall, 'KI2D');

    final all = await operations.watchAll().first;
    expect(all, hasLength(1));
    expect(all.first.userTitle, 'Test op');
    expect(all.first.qsoCount, 0);
  });

  test('adding QSOs updates counters and indexed columns', () async {
    final op = await operations.create(stationCall: 'KI2D');

    await qsos.add(op.uuid, {
      'our': {'call': 'KI2D', 'sent': '59'},
      'their': {'call': 'W1AW', 'sent': '57'},
      'freq': 14285.0,
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    await qsos.add(op.uuid, {
      'our': {'call': 'KI2D', 'sent': '599'},
      'their': {'call': 'EA4XYZ', 'sent': '579'},
      'freq': 7025.0,
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    final updated = await operations.get(op.uuid);
    expect(updated!.qsoCount, 2);
    expect(updated.startAtMillisMin, 1000);
    expect(updated.startAtMillisMax, 2000);

    final list = await qsos.watchForOperation(op.uuid).first;
    expect(list.map((q) => q.theirCall), ['W1AW', 'EA4XYZ']);
    expect(list.first.freq, 14285.0);
    expect(list.first.sentRST, '59');
    expect(list.first.receivedRST, '57');
  });

  test('watch stream emits on new QSOs', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final emissions = <int>[];
    final subscription = qsos.watchForOperation(op.uuid).listen((list) => emissions.add(list.length));

    await pumpEventQueue();
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
    });
    await pumpEventQueue();

    expect(emissions, containsAllInOrder([0, 1]));
    await subscription.cancel();
  });

  test('soft delete hides QSO and refreshes counters', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'CW',
    });

    await qsos.softDelete(qso);

    final list = await qsos.watchForOperation(op.uuid).first;
    expect(list, isEmpty);
    final updated = await operations.get(op.uuid);
    expect(updated!.qsoCount, 0);
  });

  test('soft deleted operations disappear from watchAll', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await operations.softDelete(op.uuid);
    expect(await operations.watchAll().first, isEmpty);
  });

  test('watchOperation emits counter refreshes and localData updates', () async {
    final op = await operations.create(stationCall: 'KI2D', userTitle: 'Reactive');
    final emissions = <Operation?>[];
    final sub = operations.watchOperation(op.uuid).listen(emissions.add);
    await pumpEventQueue();

    // A QSO add refreshes the operation's counters — the stream must see it
    // without any manual re-fetch.
    await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});
    await pumpEventQueue();

    // A localData write (the shape ScoringService uses for day/op summaries)
    // must flow through too — this is what keeps day-header badges fresh.
    await operations.updateLocalData(op.uuid, {'scoring': {'operationSummary': {'dupe': 0}}});
    await pumpEventQueue();

    expect(emissions.first?.userTitle, 'Reactive');
    expect(emissions.map((o) => o?.qsoCount), containsAllInOrder([0, 1]));
    expect(emissions.last?.localData['scoring'], isNotNull);
    await sub.cancel();
  });

  test('watchOperation emits null once the operation is hard-deleted', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final emissions = <Operation?>[];
    final sub = operations.watchOperation(op.uuid).listen(emissions.add);
    await pumpEventQueue();
    await operations.backupAndClearAll('backup-1');
    await pumpEventQueue();

    expect(emissions.last, isNull);
    await sub.cancel();
  });

  test('a brand-new operation with no QSOs sorts to the top, not the bottom', () async {
    final active = await operations.create(stationCall: 'KI2D', userTitle: 'Active op');
    await qsos.add(active.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});

    // New operation has a NULL startAtMillisMax; SQLite sorts NULLs last in
    // DESC by default, which would otherwise bury it at the end.
    final fresh = await operations.create(stationCall: 'KI2D', userTitle: 'Fresh op');

    final all = await operations.watchAll().first;
    expect(all.map((o) => o.userTitle), [fresh.userTitle, active.userTitle]);
  });

  test('multiple operations with no QSOs sort by createdAtMillis descending', () async {
    final op1 = await operations.create(stationCall: 'KI2D', userTitle: 'First created');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final op2 = await operations.create(stationCall: 'KI2D', userTitle: 'Second created');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final op3 = await operations.create(stationCall: 'KI2D', userTitle: 'Third created');

    final all = await operations.watchAll().first;
    expect(all.map((o) => o.userTitle).take(3), [
      op3.userTitle,
      op2.userTitle,
      op1.userTitle,
    ]);
  });

  group('sync revision stamps (updatedAtMillis)', () {
    test('markSynced only flips rows whose revision stamp still matches the sent copy', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final sent = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      // An edit lands while the sync round's network call is in flight: the
      // row is re-stamped after `sent` was snapshotted for the payload.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final edited = (await qsos.watchForOperation(op.uuid).first).single;
      await qsos.update(Qso(
        uuid: edited.uuid,
        operationUuid: edited.operationUuid,
        data: {...edited.data, 'notes': 'edited mid-flight'},
      ));

      await qsos.markSynced([sent]);
      // The edit survives as dirty — marking it synced here would silently
      // swallow it forever (the server only ever saw the pre-edit copy).
      expect(await qsos.hasUnsynced(), isTrue);

      // An untouched row does get marked.
      final current = (await qsos.watchForOperation(op.uuid).first).single;
      await qsos.markSynced([current]);
      expect(await qsos.hasUnsynced(), isFalse);
    });

    test('markSynced (operations) respects the revision stamp the same way', () async {
      final op = await operations.create(stationCall: 'KI2D');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'title': 'Renamed mid-flight'}));

      await operations.markSynced([op]);
      expect(await operations.hasUnsynced(), isTrue);

      final current = (await operations.byUuids([op.uuid])).single;
      await operations.markSynced([current]);
      expect(await operations.hasUnsynced(), isFalse);
    });

    test('mergeFromSync never overwrites a newer local revision', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'notes': 'local edit'});

      // An older copy coming back down — e.g. this device's own earlier
      // push returning during a "combine" backfill. It must not clobber
      // the newer local row nor mark it synced.
      await qsos.mergeFromSync([
        {
          'uuid': qso.uuid,
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'notes': 'stale server copy',
          'updatedAtMillis': qso.updatedAtMillis! - 1000,
          'syncedAtMillis': 1,
        },
      ]);
      expect((await qsos.watchForOperation(op.uuid).first).single.notes, 'local edit');
      expect(await qsos.hasUnsynced(), isTrue);

      // A genuinely newer inbound revision (another device's later edit)
      // does win.
      await qsos.mergeFromSync([
        {
          'uuid': qso.uuid,
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'notes': 'newer from another device',
          'updatedAtMillis': qso.updatedAtMillis! + 1000,
          'syncedAtMillis': 2,
        },
      ]);
      expect((await qsos.watchForOperation(op.uuid).first).single.notes, 'newer from another device');
      expect(await qsos.hasUnsynced(), isFalse);
    });

    test('mergeFromSync (operations) applies the same staleness rule', () async {
      final op = await operations.create(stationCall: 'KI2D', userTitle: 'Local title');

      await operations.mergeFromSync([
        {
          'uuid': op.uuid,
          'stationCall': 'KI2D',
          'userTitle': 'Stale server title',
          'updatedAtMillis': op.updatedAtMillis! - 1000,
          'syncedAtMillis': 1,
        },
      ]);
      expect((await operations.byUuids([op.uuid])).single.userTitle, 'Local title');
      expect(await operations.hasUnsynced(), isTrue);
    });

    test('an inbound record with no revision stamp only overwrites rows with nothing left to push', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'notes': 'unpushed edit'});

      // Dirty local row: protected from stampless (pre-stamp history) data.
      await qsos.mergeFromSync([
        {'uuid': qso.uuid, 'operation': op.uuid, 'their': {'call': 'W1AW'}, 'notes': 'stampless copy'},
      ]);
      expect((await qsos.watchForOperation(op.uuid).first).single.notes, 'unpushed edit');

      // Once pushed (clean), a stampless inbound record is accepted.
      await qsos.markSynced([qso]);
      await qsos.mergeFromSync([
        {'uuid': qso.uuid, 'operation': op.uuid, 'their': {'call': 'W1AW'}, 'notes': 'stampless copy'},
      ]);
      expect((await qsos.watchForOperation(op.uuid).first).single.notes, 'stampless copy');
    });

    test('softDelete re-stamps the record so the delete syncs as the newest revision', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await qsos.softDelete(qso);

      final deleted = (await qsos.watchForOperation(op.uuid, includeDeleted: true).first).single;
      expect(deleted.deleted, isTrue);
      expect(deleted.updatedAtMillis, greaterThan(qso.updatedAtMillis!));
    });

    test('undelete restores the QSO, refreshes counters, and re-stamps so it syncs newer than the tombstone', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}});
      await qsos.softDelete(qso);
      final tombstone = (await qsos.watchForOperation(op.uuid, includeDeleted: true).first).single;
      await qsos.markSynced([tombstone]);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await qsos.undelete(tombstone);

      final restored = (await qsos.watchForOperation(op.uuid).first).single;
      expect(restored.deleted, isFalse);
      expect(restored.updatedAtMillis, greaterThan(tombstone.updatedAtMillis!));
      expect(await qsos.hasUnsynced(), isTrue); // dirty again, so the undelete pushes
      expect((await operations.get(op.uuid))!.qsoCount, 1);
    });

    test('undelete flips the flag on the row\'s current data, not the caller\'s stale snapshot', () async {
      // The UI holds the QSO selected at tap time, and a deleted QSO can sit
      // on screen indefinitely; if sync merges a newer revision meanwhile,
      // restoring must not restamp the stale snapshot over it — that would
      // silently revert the other device's edits everywhere.
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'notes': 'original'});
      await qsos.softDelete(qso);
      final tombstone = (await qsos.watchForOperation(op.uuid, includeDeleted: true).first).single;
      await qsos.markSynced([tombstone]);

      // Another device restored and edited this QSO; the merge lands while
      // the stale tombstone snapshot is still selected on this one.
      await qsos.mergeFromSync([
        {
          'uuid': qso.uuid,
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'notes': 'edited remotely',
          'updatedAtMillis': tombstone.updatedAtMillis! + 1000,
        },
      ]);

      await qsos.undelete(tombstone);

      final restored = (await qsos.watchForOperation(op.uuid).first).single;
      expect(restored.deleted, isFalse);
      expect(restored.notes, 'edited remotely');
    });

    test('caching scores never bumps updatedAtMillis — the invariant live rescore depends on', () async {
      // OperationView drives live rescoring off a fingerprint built from
      // updatedAtMillis. A rescore writes score_cache and localData; if
      // either bumped updatedAtMillis the fingerprint would move and the
      // rescore would re-trigger itself forever. Guard that here.
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});
      final beforeQso = qso.updatedAtMillis;
      final beforeOp = (await operations.byUuids([op.uuid])).single.updatedAtMillis;

      await qsos.updateScoreCache({qso.uuid: '{"dupe":false}'});
      await operations.updateLocalData(op.uuid, {'scoring': {'operationSummary': {'dupe': 0}}});

      final afterQso = (await qsos.watchForOperation(op.uuid).first).single;
      final afterOp = (await operations.byUuids([op.uuid])).single;
      expect(afterQso.updatedAtMillis, beforeQso);
      expect(afterQso.scores, {'dupe': false}); // the cache did land
      expect(afterOp.updatedAtMillis, beforeOp);
      expect(afterOp.localData['scoring'], isNotNull); // localData did land
    });
  });

  test('LookupRepository: insert, query, geo-query, delete stale', () async {
    final lookupRepo = LookupRepository(db);

    // Insert lookup batch.
    await lookupRepo.insertLookupBatch([
      LookupRow(
        category: 'sota',
        key: 'G/LD-001',
        name: 'Scafell Pike',
        lat: 54.45426,
        lon: -3.211682,
        updated: 1,
      ),
      LookupRow(
        category: 'sota',
        key: 'G/LD-002',
        name: 'Helvellyn',
        lat: 54.52688,
        lon: -3.01725,
        updated: 2,
      ),
    ]);

    // Query single lookup by key.
    final single = await lookupRepo.getLookup('sota', 'G/LD-001');
    expect(single, isNotNull);
    expect(single!.name, 'Scafell Pike');

    // Query wildcards on name/key.
    final match = await lookupRepo.queryLookups('sota', 'Pike');
    expect(match, hasLength(1));
    expect(match.first.key, 'G/LD-001');

    // Proximity lookup, closest first — callers (e.g. activity suggestions)
    // truncate this list, so ordering has to happen in the query itself
    // rather than relying on the caller to re-sort an already-capped result.
    final near = await lookupRepo.queryLookupsByLocation('sota', 54.5, -3.1, 0.2);
    expect(near.map((r) => r.key), ['G/LD-002', 'G/LD-001']);

    // Stale delete deletes updated=1 when keeping updated=2.
    await lookupRepo.deleteCategoryStale('sota', 2);
    final lookup1 = await lookupRepo.getLookup('sota', 'G/LD-001');
    final lookup2 = await lookupRepo.getLookup('sota', 'G/LD-002');
    expect(lookup1, isNull);
    expect(lookup2, isNotNull);
  });
}
