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

    // A LATER sync round on this device must not auto-delete it either —
    // this device never confirmed a purge, it only received one.
    expect(await operations.hardDeletePurged(), isEmpty,
        reason: 'hardDeletePurged is for locally-confirmed purges only; purgedLocally is false on a merged row');
    expect(await operations.get('remote-op'), isNotNull);
  });

  test('receivedPurgesPending lists rows this device received but never purged itself', () async {
    await operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 1},
    ]);
    final localOp = await operations.create(stationCall: 'W1AW/T');
    await operations.purge(localOp.uuid);
    await operations.markSynced([(await operations.get(localOp.uuid))!]);

    final pending = await operations.watchReceivedPurgesPending().first;
    expect(pending.map((o) => o.uuid), ['remote-op'],
        reason: 'a locally-confirmed purge (purgedLocally: true) is not a received-purge candidate');
  });

  test('eligibleReceivedPurges lists only the still-valid rows, and hardDeleteOperation removes one for real', () async {
    await operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 1},
    ]);
    final eligible = await operations.eligibleReceivedPurges(['remote-op', 'never-existed']);
    expect(eligible, ['remote-op']);
    expect(await operations.get('remote-op'), isNotNull, reason: 'listing eligibility must not delete anything');

    await operations.hardDeleteOperation('remote-op');
    expect(await operations.get('remote-op'), isNull);
  });

  test(
      'confirming a received purge removes every QSO of the operation, even ones whose own purge tombstone '
      "hasn't arrived yet", () async {
    // Operations and QSOs sync in separate batches/watermarks — an operator
    // can confirm as soon as the OPERATION record lands, before this
    // operation's QSOs' own `purged` flags do. HaLoServices.
    // confirmReceivedTestOperationPurges must use hardDeleteAllForOperation
    // here, not hardDeletePurgedForOperation's `purged && synced` predicate,
    // or a QSO caught in that gap survives with no operation row left to
    // belong to — invisible in the operation list, but still live in call
    // history and dupe checks forever.
    await operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 1},
    ]);
    // A QSO synced normally, with no purged flag at all — the gap this pins.
    await qsos.mergeFromSync([
      {'uuid': 'remote-qso', 'operation': 'remote-op', 'their': {'call': 'W1AW'}, 'updatedAtMillis': 1},
    ]);

    await operations.eligibleReceivedPurges(['remote-op']);
    // Mirrors HaLoServices.confirmReceivedTestOperationPurges's order: QSOs
    // before the operation row, so a failure in between never strands one
    // with no way for the operation to be found again.
    await qsos.hardDeleteAllForOperation('remote-op');
    await operations.hardDeleteOperation('remote-op');

    expect(await qsos.get('remote-qso'), isNull);
  });

  test('eligibleReceivedPurges re-validates against the database, not the caller\'s stale list', () async {
    await operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 1},
    ]);

    // The escape hatch fired between listing and confirming (e.g. another
    // sync round brought in a fixed callsign) — the uuid must not be listed.
    await operations.saveData(Operation(uuid: 'remote-op', data: {'stationCall': 'KI2D'}));

    expect(await operations.eligibleReceivedPurges(['remote-op']), isEmpty);
    expect(await operations.get('remote-op'), isNotNull);
  });

  group('the callsign-edit escape hatch', () {
    test('saveData clears purged AND deleted when the edited call is no longer a Test Operation', () async {
      final op = await operations.create(stationCall: 'KI2D/T');
      await operations.purge(op.uuid);
      expect((await operations.get(op.uuid))!.purged, isTrue);

      // The operator fixes the misclassified callsign.
      await operations.saveData(Operation(uuid: op.uuid, data: {'stationCall': 'KI2D'}));

      final fixed = await operations.get(op.uuid);
      expect(fixed!.purged, isFalse, reason: 'no longer a Test Operation — the pending purge must not proceed');
      // purge() always tombstones (deleted: true) alongside purged: true, and
      // watchOperation doesn't filter on deleted — an operation view left
      // open on this uuid can still reach saveData. Leaving deleted: true
      // here would "fix" the purge while still losing the operation from
      // every list that DOES filter on it (watchAll, the home list), with
      // no path back to it.
      expect(fixed.deleted, isFalse, reason: 'a "fixed" operation must come back to life, not stay tombstoned');
      expect(fixed.isTestOperation, isFalse);
    });

    test('saveData leaves purged AND deleted alone when the edited call is still a Test Operation', () async {
      final op = await operations.create(stationCall: 'KI2D/T');
      await operations.purge(op.uuid);

      // Some other field changes; the call is still a test call.
      await operations.saveData(Operation(uuid: op.uuid, data: {'stationCall': 'KI2D/T', 'userTitle': 'renamed'}));

      final row = await operations.get(op.uuid);
      expect(row!.purged, isTrue);
      expect(row.deleted, isTrue, reason: 'still a Test Operation — the pending purge is still on');
    });

    test('saveData never sets purged true — it can only clear an existing one', () async {
      // A normal edit on a normal operation must never accidentally start
      // marking it purged just because the call happens to end in /T.
      final op = await operations.create(stationCall: 'KI2D');
      await operations.saveData(Operation(uuid: op.uuid, data: {'stationCall': 'KI2D/T'}));

      expect((await operations.get(op.uuid))!.purged, isFalse);
    });
  });

  // PURGETESTS purges every listed operation the same way a single delete
  // does (HaLoServices.purgeOperation -> OperationsRepository.purge) — there
  // is no special case anywhere for whether THIS device happened to be the
  // one an operation was originally created on. These tests pin that a
  // purge run on one device (via PURGETESTS or a single delete, same code
  // path either way) never removes another device's copy without an
  // explicit confirmation on that OTHER device too, regardless of which of
  // the two created the operation in the first place.
  group('a purge from one device never skips confirmation on another', () {
    test('an operation created on device B, purged on device A via PURGETESTS, still needs B\'s own confirmation',
        () async {
      // Device A never created this operation — it only has it because
      // device B synced it there first, then device A ran PURGETESTS.
      await operations.mergeFromSync([
        {'uuid': 'shared-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
      ]);
      final onDeviceA = await operations.get('shared-op');
      expect(onDeviceA!.isTestOperation, isTrue);

      await operations.purge('shared-op'); // what PURGETESTS calls, per operation
      await operations.markSynced([(await operations.get('shared-op'))!]);

      // Device A's own next sync round: fine to auto-remove, it confirmed.
      expect(await operations.hardDeletePurged(), ['shared-op']);
    });

    test('device B receiving that same purge does not remove its copy without asking, regardless of who purged it',
        () async {
      // Simulates device B pulling the record device A just pushed after
      // running PURGETESTS — the payload SyncEngine._buildPayload would
      // have sent for the purged row above.
      await operations.mergeFromSync([
        {'uuid': 'shared-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2},
      ]);

      // No auto-removal, no matter how many sync rounds run.
      expect(await operations.hardDeletePurged(), isEmpty);
      expect(await operations.get('shared-op'), isNotNull);

      // It DOES show up as something device B's operator needs to decide.
      expect((await operations.watchReceivedPurgesPending().first).map((o) => o.uuid), ['shared-op']);

      // Only once device B's own operator confirms does it actually go.
      expect(await operations.eligibleReceivedPurges(['shared-op']), ['shared-op']);
      await operations.hardDeleteOperation('shared-op');
      expect(await operations.get('shared-op'), isNull);
    });
  });
}
