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

  test('update with basedOn keeps a concurrent sync revision where the edit did not touch it', () async {
    // The trap: an editor sitting open for minutes while a sync pull moves
    // the row. Saving the whole snapshot back — restamped newer — reverts
    // the pulled revision AND wins on every device at the next round.
    final op = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(op.uuid, {
      'our': {'call': 'KI2D'},
      'their': {'call': 'W1AW', 'sent': '59'},
      'band': '20m',
    });
    final snapshot = (await qsos.get(qso.uuid))!;

    await qsos.mergeFromSync([
      {
        ...snapshot.data,
        'operation': op.uuid,
        'their': <String, dynamic>{...snapshot.data['their'] as Map, 'name': 'Hiram'},
        'updatedAtMillis': (snapshot.data['updatedAtMillis'] as int) + 60000,
      },
    ]);

    // The operator's own edit, composed from the stale snapshot.
    await qsos.update(
      Qso(
        uuid: qso.uuid,
        operationUuid: op.uuid,
        data: {
          ...snapshot.data,
          'their': <String, dynamic>{...snapshot.data['their'] as Map, 'sent': '55'},
        },
      ),
      basedOn: snapshot,
    );

    final stored = (await qsos.get(qso.uuid))!;
    expect((stored.data['their'] as Map)['sent'], '55');
    expect((stored.data['their'] as Map)['name'], 'Hiram');
    // And the merged result is a fresh local revision that will push.
    expect(stored.data['updatedAtMillis'], isNot(snapshot.data['updatedAtMillis']));
  });

  group('writeBatch', () {
    Map<String, dynamic> qsoData(String call, {String? uuid}) => {
          if (uuid != null) 'uuid': uuid,
          'our': {'call': 'KI2D'},
          'their': {'call': call},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': DateTime.utc(2024, 7, 23, 12).millisecondsSinceEpoch,
        };

    test('inserts and updates together, refreshing counters once', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final existing = await qsos.add(op.uuid, qsoData('W1AW'));

      var changes = 0;
      final counting = QsosRepository(db, onChange: () => changes++);

      final written = await counting.writeBatch(
        operationUuid: op.uuid,
        inserts: [qsoData('K1ABC'), qsoData('K2DEF')],
        updates: [
          Qso(
            uuid: existing.uuid,
            operationUuid: op.uuid,
            data: {...existing.data, 'notes': 'merged'},
          ),
        ],
      );

      expect(written, 3);
      // One callback for the whole batch: per-QSO writes would rebuild the
      // QSO list once per contact while a large import ran.
      expect(changes, 1);

      final all = await qsos.watchForOperation(op.uuid).first;
      expect(all, hasLength(3));
      expect(all.firstWhere((q) => q.uuid == existing.uuid).notes, 'merged');

      // The counters are the reason the batch has to be one transaction.
      final reloaded = await operations.watchAll().first;
      expect(reloaded.single.qsoCount, 3);
    });

    test('a record carrying no uuid gets one, and it matches its QSON', () async {
      final op = await operations.create(stationCall: 'KI2D');

      await qsos.writeBatch(operationUuid: op.uuid, inserts: [qsoData('W1AW')]);

      final stored = (await qsos.watchForOperation(op.uuid).first).single;
      expect(stored.uuid, isNotEmpty);
      // Two identities for one record is what happens if the uuid is
      // generated separately for the row and for the data it carries.
      expect(stored.data['uuid'], stored.uuid);
    });

    test('an update whose row is gone is not counted as written', () async {
      // An import plan is built against a snapshot. If the target QSO is
      // deleted before the plan is applied, reporting "N imported" while N-1
      // landed hides a record that silently didn't make it.
      final op = await operations.create(stationCall: 'KI2D');

      final written = await qsos.writeBatch(
        operationUuid: op.uuid,
        updates: [
          Qso(uuid: 'not-in-the-table', operationUuid: op.uuid, data: qsoData('W1AW')),
        ],
      );

      expect(written, 0);
    });

    test('an update from another operation is refused, not silently applied', () async {
      // A row carries its own operationUuid, so writing one from elsewhere
      // would MOVE it — and only this batch's operation gets its counters
      // refreshed, leaving the one the row came from permanently wrong.
      final from = await operations.create(stationCall: 'KI2D', userTitle: 'From');
      final to = await operations.create(stationCall: 'KI2D', userTitle: 'To');
      final qso = await qsos.add(from.uuid, qsoData('W1AW'));

      expect(
        () => qsos.writeBatch(
          operationUuid: to.uuid,
          updates: [Qso(uuid: qso.uuid, operationUuid: from.uuid, data: qso.data)],
        ),
        throwsArgumentError,
      );

      expect((await operations.get(from.uuid))!.qsoCount, 1);
    });

    test('a uuid already in the table rolls the whole batch back', () async {
      // The method documents this loudly, and it holds only because the
      // primary key is uuid and inserts use the default mode. A later switch
      // to insertOrReplace would turn a collision into silent data loss with
      // the suite still green.
      final op = await operations.create(stationCall: 'KI2D');
      final existing = await qsos.add(op.uuid, qsoData('W1AW'));

      await expectLater(
        qsos.writeBatch(
          operationUuid: op.uuid,
          inserts: [qsoData('K1ABC'), qsoData('K2DEF', uuid: existing.uuid)],
        ),
        throwsA(anything),
      );

      // Half an import is worse than none: the good record must not have
      // landed either.
      expect(await qsos.watchForOperation(op.uuid).first, hasLength(1));
    });

    test('the same QSO twice in one batch is refused', () async {
      // Two updates for one row apply in order — the second discarding the
      // first's merge — and both would count as written.
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, qsoData('W1AW'));
      Qso copy() => Qso(uuid: qso.uuid, operationUuid: op.uuid, data: qso.data);

      expect(
        () => qsos.writeBatch(operationUuid: op.uuid, updates: [copy(), copy()]),
        throwsArgumentError,
      );
    });

    test("an update cannot give the row a uuid other than its own", () async {
      // A merged record takes the newer side's fields, uuid among them, so a
      // QSON import can hand back a map carrying the incoming file's uuid.
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, qsoData('W1AW'));

      await qsos.writeBatch(
        operationUuid: op.uuid,
        updates: [
          Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'uuid': 'from-the-file'}),
        ],
      );

      final stored = (await qsos.watchForOperation(op.uuid).first).single;
      expect(stored.uuid, qso.uuid);
      expect(stored.data['uuid'], qso.uuid);
    });

    test('a timestamp that arrived as a string is coerced, not thrown on', () async {
      // A file can carry "1721736000000". Drift's typed column would throw a
      // cast error partway through the batch rather than rejecting a record.
      final op = await operations.create(stationCall: 'KI2D');

      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [
          {...qsoData('W1AW'), 'startAtMillis': '1721736000000'},
        ],
      );

      final stored = (await qsos.watchForOperation(op.uuid).first).single;
      expect(stored.startAtMillis, 1721736000000);
    });

    test('an update whose row moved past its plan-time snapshot is re-merged, not clobbered', () async {
      // The trap: a sync pull landing while the import's confirm dialog sits
      // open. Writing the plan-time merge wholesale — restamped newer —
      // would revert the pulled revision on every device.
      final op = await operations.create(stationCall: 'KI2D');
      final target = await qsos.add(op.uuid, qsoData('W1AW'));
      final snapshot = (await qsos.get(target.uuid))!;

      // Concurrent remote revision: a name correction, strictly newer stamp.
      await qsos.mergeFromSync([
        {
          ...snapshot.data,
          'operation': op.uuid,
          'their': <String, dynamic>{...snapshot.data['their'] as Map, 'name': 'Hiram'},
          'updatedAtMillis': (snapshot.data['updatedAtMillis'] as int) + 60000,
        },
      ]);

      // The plan's merge, folded from the snapshot: the file adds a grid.
      final planned = Qso(
        uuid: target.uuid,
        operationUuid: op.uuid,
        data: {
          ...snapshot.data,
          'their': <String, dynamic>{...snapshot.data['their'] as Map, 'grid': 'FN31pr'},
        },
      );
      await qsos.writeBatch(
        operationUuid: op.uuid,
        updates: [planned],
        updateBases: {target.uuid: snapshot},
      );

      final stored = (await qsos.get(target.uuid))!;
      expect((stored.data['their'] as Map)['grid'], 'FN31pr', reason: "the file's own addition must land");
      expect((stored.data['their'] as Map)['name'], 'Hiram', reason: 'the pulled name correction must survive');
    });

    test('an empty batch writes nothing and fires no change', () async {
      final op = await operations.create(stationCall: 'KI2D');
      var changes = 0;
      final counting = QsosRepository(db, onChange: () => changes++);

      expect(await counting.writeBatch(operationUuid: op.uuid), 0);
      expect(changes, 0);
    });

    test('an update batch bigger than one existence-check chunk still counts every row', () async {
      // The existence check for updates is chunked the same way historyForCalls
      // chunks its own IN clause — a caller that hands a large re-import's
      // merges straight through in one call (adif_import_flow.dart does) would
      // otherwise build one IN clause with one bound variable per update, past
      // SQLite's limit on a big enough operation. This spans more than one
      // chunk to prove the counts still add up across the boundary.
      final op = await operations.create(stationCall: 'KI2D');
      const total = 1200;
      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [for (var i = 0; i < total; i++) qsoData('W1AW$i')],
      );
      final existing = await qsos.watchForOperation(op.uuid).first;

      final written = await qsos.writeBatch(
        operationUuid: op.uuid,
        updates: [
          for (final qso in existing) Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'updated'}),
        ],
      );

      expect(written, total);
      final updated = await qsos.watchForOperation(op.uuid).first;
      expect(updated.every((qso) => qso.notes == 'updated'), isTrue);
    });
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

  test('queryLookups treats a literal % or _ in the search term as text, not a SQL wildcard', () async {
    final lookupRepo = LookupRepository(db);
    await lookupRepo.insertLookupBatch([
      LookupRow(category: 'pota', key: 'US-0001', name: '100% Park', updated: 1),
      LookupRow(category: 'pota', key: 'US-0002', name: '100X Park', updated: 1),
      LookupRow(category: 'pota', key: 'US-0003', name: 'A_B Reserve', updated: 1),
      LookupRow(category: 'pota', key: 'US-0004', name: 'AZB Reserve', updated: 1),
    ]);

    // An unescaped '%' matches zero-or-more of anything, so 'Park' would
    // wrongly also match "100X Park" here — pinning that only the row with
    // the LITERAL '%' comes back.
    final percentMatch = await lookupRepo.queryLookups('pota', '100%');
    expect(percentMatch.map((r) => r.key), ['US-0001']);

    // An unescaped '_' matches exactly one of anything, so it would wrongly
    // also match "AZB Reserve" here.
    final underscoreMatch = await lookupRepo.queryLookups('pota', 'A_B');
    expect(underscoreMatch.map((r) => r.key), ['US-0003']);
  });
}
