// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operations: the only writer to the `operations` table, and the sync
// watermark it hands the sync engine. The contract every repository keeps is
// stated in repo_support.dart.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_clock.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../models/operation_operator.dart';
import '../models/qson_values.dart';
import 'write_policy.dart';

import 'repo_support.dart';

/// Tracks the min/max `syncedAtMillis` seen while merging one inbound sync
/// batch — see `OperationsRepository.mergeFromSync`.
class SyncWatermark {
  int? earliestSyncedAtMillis;
  int? latestSyncedAtMillis;

  void include(int? syncedAtMillis) {
    if (syncedAtMillis == null) return;
    if (earliestSyncedAtMillis == null || syncedAtMillis < earliestSyncedAtMillis!) {
      earliestSyncedAtMillis = syncedAtMillis;
    }
    if (latestSyncedAtMillis == null || syncedAtMillis > latestSyncedAtMillis!) {
      latestSyncedAtMillis = syncedAtMillis;
    }
  }
}

class OperationsRepository {
  final HaLoDatabase db;

  /// Notified after every local write so the sync engine can debounce a
  /// small-batch round (DESIGN.md §4) — kept as a plain callback rather than
  /// a direct dependency so this repository doesn't need to know the sync
  /// engine's type.
  final void Function()? onChange;

  /// Runs after every LOCAL data write ([saveData]) with the stored row as
  /// it was and the operation as saved. The segments model needs it: a
  /// `break`/`start` override replaces the base rather than tracking it, so
  /// an edit to what the latest segment restates (refs, location) has to be
  /// written onto that segment too, or the current stretch keeps the values
  /// from before the edit. Sync-received revisions go through
  /// `mergeFromSync` and never reach this — they carry their own event rows.
  final Future<void> Function(Operation? before, Operation after)? onLocalSave;

  OperationsRepository(this.db, {this.onChange, this.onLocalSave});

  /// Creating is never refused while the clock is travelled — the station call
  /// is marked instead, by [markedForTravel]. A refusal here would be
  /// unescapable: an operation is judged test data by its stored callsign, and
  /// there is nothing stored yet to judge.
  Future<Operation> create({required String stationCall, String userTitle = ''}) async {
    final operation = Operation(
      uuid: uuidGenerator.v4(),
      data: {
        'stationCall': markedForTravel(stationCall.toUpperCase()),
        'userTitle': userTitle,
        // The creation DATE is what the operator reads, so it travels; the
        // revision stamp is what another device compares against, so it does
        // not (realNowMillis's doc comment, docs/design/time.md §1).
        'createdAtMillis': nowMillis(),
        'updatedAtMillis': realNowMillis(),
      },
    );
    await db.into(db.operations).insert(OperationsCompanion.insert(
          uuid: operation.uuid,
          data: Value(encodeOperationData(operation.data, 'operations:create')),
          // The column mirrors the revision stamp inside `data`, so it reads
          // the same real clock.
          updatedAtMillis: Value(asQsonNum(operation.data['updatedAtMillis'])!.toInt()),
        ));
    onChange?.call();
    return operation;
  }

  Stream<List<Operation>> watchAll() {
    // Sorting falls back to fields within the JSON data blob (like
    // createdAtMillis) for operations with no QSOs, so the sort happens
    // in Dart rather than SQL.
    final query = (db.select(db.operations)
      ..where((op) => op.deleted.equals(false)));
    return query.watch().map((rows) {
      final list = rows.map(_operationFromRow).toList();
      list.sort((a, b) {
        final aTime = a.startAtMillisMax ?? a.createdAtMillis ?? 0;
        final bTime = b.startAtMillisMax ?? b.createdAtMillis ?? 0;
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;

        // Tie-breaker: createdAtMillis DESC (most recently created first)
        final aCreated = a.createdAtMillis ?? 0;
        final bCreated = b.createdAtMillis ?? 0;
        return bCreated.compareTo(aCreated);
      });
      return list;
    });
  }

  Future<Operation?> get(String uuid) async {
    final row = await (db.select(db.operations)..where((op) => op.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _operationFromRow(row);
  }

  /// Reactive single-operation query — emits the current row and every later
  /// version (counter refreshes, detail/activity/location edits, and the
  /// `localData` scoring summary a rescore writes). Lets views bind the
  /// operation instead of manually re-fetching after each mutating action, so
  /// there's no stale copy or hand-rolled `localData` merge to keep in sync.
  /// Emits null if the operation doesn't exist (or is hard-deleted).
  Stream<Operation?> watchOperation(String uuid) {
    return (db.select(db.operations)..where((op) => op.uuid.equals(uuid)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _operationFromRow(row));
  }

  /// Throws [WriteRefused] while the clock is travelled unless BOTH the stored
  /// operation and the edit are test data — see [WritePolicy].
  Future<void> saveData(Operation operation) async {
    final now = realNowMillis();
    final data = {...operation.data, 'updatedAtMillis': now};
    // Read before anything is written, and judged on the STORED row: an edit
    // that adds /TEST to a real operation must not be the thing that lets
    // itself through.
    final existing = await get(operation.uuid);
    final refusal = WritePolicy.forOperation(existing) ??
        WritePolicy.forOperationStayingTest(Operation(uuid: operation.uuid, data: data));
    if (refusal != null) throw refusal;
    var companion = OperationsCompanion(
      data: Value(encodeOperationData(data, 'operations:saveData')),
      synced: const Value(false),
      updatedAtMillis: Value(now),
    );
    // A pending purge only makes sense while the operation still reads as a
    // Test Operation. If the station call was just edited away from /T or
    // /TEST — fixing a misclassification, or received an update via sync
    // that no longer flags it — cancel the purge rather than let a now-real
    // operation's QSOs get hard-deleted out from under the edit. Checked
    // against the row rather than the in-memory [operation] snapshot: this
    // must key off whatever `purged` state the DATABASE currently holds.
    //
    // Clears `deleted` too, not just `purged`/`purgedLocally`: a purged row
    // is always also tombstoned (`_writeDeleted`, `mergeFromSync`), and
    // `watchOperation` doesn't filter on `deleted` — an operation view left
    // open on this uuid can still reach this save. Leaving `deleted: true`
    // here would "fix" the misclassification while still losing the
    // operation from every list that DOES filter on it, with no path back.
    if (existing != null && existing.purged && !Operation(uuid: operation.uuid, data: data).isTestOperation) {
      companion = companion.copyWith(
        deleted: const Value(false),
        purged: const Value(false),
        purgedLocally: const Value(false),
      );
    }
    await (db.update(db.operations)..where((op) => op.uuid.equals(operation.uuid))).write(companion);
    // The row is already committed, so the change HAS to be announced —
    // without this, a throw out of the callback leaves the edit saved and
    // both the sync engine and the peer outbox unaware of it until some
    // later, unrelated write happens to wake them.
    try {
      await onLocalSave?.call(existing, Operation(uuid: operation.uuid, data: data));
    } finally {
      onChange?.call();
    }
  }

  Future<void> softDelete(String uuid) => _writeDeleted(uuid, purged: false);

  /// Deletes a Test Operation for real: soft-deletes with `purged: true`
  /// and `purgedLocally: true` (same tombstone `softDelete` writes, so it
  /// disappears from every `deleted.equals(false)` query immediately), which
  /// then pushes through the normal dirty-row sync pipeline. Once that push
  /// is acknowledged, [SyncEngine] hard-deletes the row (and its QSOs, via
  /// `QsosRepository.purgeForOperation`) — see `Operations.purged`/
  /// `purgedLocally`'s docs. Deliberately not offered for a non-test
  /// operation: an unrecoverable delete is the whole point of a Test
  /// Operation existing, not a general replacement for [softDelete].
  ///
  /// The caller (the delete-confirmation dialog, or PURGETESTS) is what
  /// makes this "confirmed" — `purgedLocally: true` records that a human
  /// said yes to it ON THIS DEVICE, which is what lets [hardDeletePurged]
  /// act on it without asking again.
  Future<void> purge(String uuid) => _writeDeleted(uuid, purged: true);

  /// Shared by [softDelete] and [purge]. Re-stamps `data.updatedAtMillis`
  /// too (not just the flags): the delete must sync as a revision newer than
  /// the record it tombstones, or other devices' merge comparison would
  /// discard it as stale.
  Future<void> _writeDeleted(String uuid, {required bool purged}) async {
    final now = realNowMillis();
    final operation = await get(uuid);
    // Deleting a real operation is a write to real data like any other, so it
    // is refused while travelling. The Test Operation purge flow is unaffected
    // — everything it touches is test data by definition.
    final refusal = WritePolicy.forOperation(operation);
    if (refusal != null) throw refusal;
    var companion = OperationsCompanion(
      deleted: const Value(true),
      purged: Value(purged),
      purgedLocally: Value(purged),
      synced: const Value(false),
      updatedAtMillis: Value(now),
    );
    if (operation != null) {
      companion = companion.copyWith(
          data: Value(encodeOperationData({...operation.data, 'updatedAtMillis': now}, 'operations:delete')));
    }
    await (db.update(db.operations)..where((op) => op.uuid.equals(uuid))).write(companion);
    onChange?.call();
  }

  /// The deferred half of a locally-confirmed [purge]: physically removes
  /// every row that is `purged`, `synced`, AND `purgedLocally` — called by
  /// [SyncEngine] after every successful round, not scoped to whatever that
  /// round just pushed. Scoping it to the round's own batch would leave a
  /// row stranded forever the moment the app dies between `markSynced`
  /// committing `synced: true` and this running: a row that isn't dirty
  /// never appears in a future batch again, so a batch-scoped sweep would
  /// have no path back to it. An unconditional sweep instead catches it on
  /// the very next round that succeeds at all.
  ///
  /// `purgedLocally` is the whole reason this can run with no further
  /// confirmation: it's only ever set by [purge] on THIS device, which
  /// already went through the delete-confirmation dialog or PURGETESTS. A
  /// row this device only received via `mergeFromSync` has `purgedLocally:
  /// false` and is never touched here — see [watchReceivedPurgesPending].
  Future<List<String>> hardDeletePurged() async {
    final rows = await (db.select(db.operations)
          ..where((op) => op.purged.equals(true) & op.synced.equals(true) & op.purgedLocally.equals(true)))
        .get();
    if (rows.isEmpty) return const [];
    final purgedUuids = rows.map((r) => r.uuid).toList();
    await (db.delete(db.operations)..where((op) => op.uuid.isIn(purgedUuids))).go();
    return purgedUuids;
  }

  /// Operations flagged `purged` that arrived via sync rather than being
  /// purged on this device (`purgedLocally: false`) — candidates for the
  /// "these were removed elsewhere" confirmation prompt, never acted on
  /// without the operator saying so here too. Row-shaped like every other
  /// read: `deleted` stays true on these (a purged operation is tombstoned
  /// like any other delete on receipt), so this deliberately does NOT filter
  /// on `deleted` the way [watchAll] does.
  Stream<List<Operation>> watchReceivedPurgesPending() {
    final query = (db.select(db.operations)
      ..where((op) => op.purged.equals(true) & op.synced.equals(true) & op.purgedLocally.equals(false)));
    return query.watch().map((rows) => rows.map(_operationFromRow).toList());
  }

  /// Received purges with nothing left for the operator to decide about:
  /// this device holds no QSO of the operation, and the operation row
  /// itself is a tombstone nothing displays, so confirming the prompt
  /// would delete nothing anyone can see. Removing the row silently is what
  /// keeps a purge for an operation this device never really had from
  /// raising the "removed on another device" notice on every sync round,
  /// forever. [mergeFromSync] and [mergeFromPeer]'s create guards keep new
  /// ones from appearing; this clears whatever a build without them left
  /// behind.
  ///
  /// `deleted` and `isTestOperation` are checked even though [purge] never
  /// writes `purged` without both: on the inbound paths the two flags are
  /// independent fields off the wire, so a record carrying `purged: true`
  /// with no `deleted` — an older build, a peer on another dialect — leaves
  /// a row `watchAll` still SHOWS. This is the one purge path with no human
  /// in front of it, so it refuses anything that is visible or is not test
  /// data rather than hard-deleting on a flag a peer controls.
  ///
  /// Counts EVERY QSO row of the operation, tombstones included: a purge is
  /// what `confirmReceivedTestOperationPurges` would hard-delete, and a
  /// device still holding rows of any kind has something real to be asked
  /// about. Transactional, unlike [hardDeletePurged] — that one is followed
  /// straight away by `hardDeletePurgedForOperation`, so a QSO written into
  /// its window is still reclaimable, while a QSO written into this one is
  /// not `purged` and [QsosRepository.hardDeletePurgedOrphans] can never
  /// reach it again.
  ///
  /// Returns the uuids removed, which the caller logs: this is the only
  /// irreversible delete in a sync round that no operator confirmed.
  Future<List<String>> hardDeleteEmptyReceivedPurges() async {
    return db.transaction(() async {
      final rows = await (db.select(db.operations)
            ..where((op) =>
                op.purged.equals(true) &
                op.synced.equals(true) &
                op.purgedLocally.equals(false) &
                op.deleted.equals(true)))
          .get();
      if (rows.isEmpty) return const <String>[];
      final uuids = [for (final r in rows) if (_operationFromRow(r).isTestOperation) r.uuid];
      if (uuids.isEmpty) return const <String>[];
      final held = await (db.selectOnly(db.qsos)
            ..addColumns([db.qsos.operation])
            ..where(db.qsos.operation.isIn(uuids))
            ..groupBy([db.qsos.operation]))
          .get();
      final withQsos = {for (final r in held) r.read(db.qsos.operation)};
      final empty = [for (final uuid in uuids) if (!withQsos.contains(uuid)) uuid];
      if (empty.isEmpty) return const <String>[];
      await (db.delete(db.operations)..where((op) => op.uuid.isIn(empty))).go();
      return empty;
    });
  }

  /// The operator confirmed removing [uuids] after seeing them in the
  /// "removed elsewhere" prompt — which of them are still real candidates.
  /// Re-checks `purged`/`synced`/`purgedLocally` against the database rather
  /// than trusting the caller's list: a row [saveData] un-marked in the
  /// meantime (the callsign-edit escape hatch) must not be deleted just
  /// because it was still on screen when the operator tapped confirm.
  ///
  /// Read-only, deliberately: it does NOT delete anything itself. The
  /// caller (`HaLoServices.confirmReceivedTestOperationPurges`) deletes each
  /// operation's QSOs first, then its row, one uuid at a time — if this
  /// method deleted every row up front instead, a QSO-deletion failure for
  /// ANY uuid would stand its operation row already gone while its QSOs
  /// stayed behind, with no operation left for `watchReceivedPurgesPending`
  /// to ever surface again. [hardDeleteOperation] is the second half.
  Future<List<String>> eligibleReceivedPurges(Iterable<String> uuids) async {
    final list = uuids.toList();
    if (list.isEmpty) return const [];
    final rows = await (db.select(db.operations)
          ..where((op) =>
              op.uuid.isIn(list) & op.purged.equals(true) & op.synced.equals(true) & op.purgedLocally.equals(false)))
        .get();
    return rows.map((r) => r.uuid).toList();
  }

  /// Physically removes operation [uuid] — see [eligibleReceivedPurges]'s
  /// doc for why the caller must delete this operation's QSOs BEFORE
  /// calling this, never after.
  Future<void> hardDeleteOperation(String uuid) async {
    await (db.delete(db.operations)..where((op) => op.uuid.equals(uuid))).go();
  }

  /// Up to `limit` dirty operations, most-recently-active first — the same
  /// selection app-polo's sync loop uses for its "large batch" round
  /// (`sync.js`'s `queryOperations('WHERE synced IS false ...')`).
  Future<List<Operation>> unsyncedBatch(int limit, {Set<String> excluding = const {}}) async {
    final query = (db.select(db.operations)
      ..where((op) => excluding.isEmpty
          ? op.synced.equals(false)
          : op.synced.equals(false) & op.uuid.isNotIn(excluding.toList()))
      ..orderBy([
        (op) => OrderingTerm(expression: op.startAtMillisMax, mode: OrderingMode.desc, nulls: NullsOrder.first),
      ])
      ..limit(limit));
    return (await query.get()).map(_operationFromRow).toList();
  }

  /// Fetches specific operations by uuid (e.g. the parents of a QSO batch),
  /// optionally narrowed to ones still unsynced.
  Future<List<Operation>> byUuids(List<String> uuids, {bool onlyUnsynced = false}) async {
    if (uuids.isEmpty) return const [];
    final query = db.select(db.operations)..where((op) => op.uuid.isIn(uuids));
    if (onlyUnsynced) query.where((op) => op.synced.equals(false));
    return (await query.get()).map(_operationFromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row =
        await (db.select(db.operations)..where((op) => op.synced.equals(false))..limit(1)).getSingleOrNull();
    return row != null;
  }

  /// Flips the sent rows to `synced = true` — but only those whose revision
  /// stamp still matches what was actually sent. A row edited while the
  /// sync round's network call was in flight has a newer stamp (and
  /// `synced = false` again); marking it unconditionally would silently
  /// swallow that edit forever.
  Future<void> markSynced(Iterable<Operation> sent) async {
    final list = sent.toList();
    if (list.isEmpty) return;
    await db.transaction(() async {
      for (final o in list) {
        final stamp = o.updatedAtMillis;
        await (db.update(db.operations)
              ..where((op) =>
                  op.uuid.equals(o.uuid) &
                  (stamp == null ? op.updatedAtMillis.isNull() : op.updatedAtMillis.equals(stamp))))
            .write(const OperationsCompanion(synced: Value(true)));
      }
    });
  }

  /// Total and pending-sync counts, reported in the sync payload's `meta`
  /// (mirrors `getSyncCounts()` in app-polo's `sync.js`).
  ///
  /// `total` is what this device HOLDS, so tombstones don't count — they're
  /// records that no longer exist as far as the user is concerned. `pending`
  /// is what it still owes the server, so tombstones DO count: a delete only
  /// reaches other devices by being pushed.
  Future<({int total, int pending})> syncCounts() async {
    final count = db.operations.uuid.count();
    Future<int> countWhere(Expression<bool> predicate) async {
      final query = db.selectOnly(db.operations)
        ..addColumns([count])
        ..where(predicate);
      return (await query.getSingle()).read(count) ?? 0;
    }

    return (
      total: await countWhere(db.operations.deleted.equals(false)),
      pending: await countWhere(db.operations.synced.equals(false)),
    );
  }

  /// The operations side of `QsosRepository.unsyncedContactCount` — what this
  /// device still owes the server, counting only operations it still HOLDS.
  ///
  /// Distinct from [syncCounts]'s `pending`, which counts every dirty row
  /// including tombstones because it answers the sync loop's "anything to
  /// push?". An operator reading "N operations waiting to upload" beside a
  /// total that excludes deleted ones would see the pending figure overtake
  /// the total after a few offline deletions, which is not a thing that can
  /// be true.
  Future<int> unsyncedOperationCount() async {
    final count = db.operations.uuid.count();
    final query = db.selectOnly(db.operations)
      ..addColumns([count])
      ..where(db.operations.synced.equals(false) & db.operations.deleted.equals(false));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// The revision stamp a repaired record goes back out under: this device's
  /// real clock, but never below the stamp it is rejecting. A sender whose
  /// clock runs ahead would otherwise get a repair that compares OLDER than
  /// what it sent, and `inboundIsStale` drops it on arrival — the seat's own
  /// operator would be corrected here and nowhere else. Real clock, not the
  /// app's: a revision stamp persists, so it must not travel (time.md §1).
  int _repairedStamp(int? incomingUpdatedAtMillis) {
    final now = realNowMillis();
    if (incomingUpdatedAtMillis == null || incomingUpdatedAtMillis < now) return now;
    return incomingUpdatedAtMillis + 1;
  }

  /// [data] with this device's own operator restored, when the device sits in
  /// an operating position and [existing] already names somebody in it.
  ///
  /// An operation's `data` merges whole-blob, last writer wins: two seats that
  /// name their operators inside one sync window each push a full copy built
  /// from their own snapshot, and the later push carries the other seat's slot
  /// as it was BEFORE that seat was filled. Whoever loses that race would find
  /// their own seat empty again, and every contact logged afterwards stamped
  /// with nobody. Who is at THIS key is the one thing this device knows better
  /// than any record arriving from elsewhere, so it survives the merge.
  ///
  /// Only the seat this device occupies, and only where the stored row HAS
  /// that slot — presence, not a non-empty value, exactly as `operatorCallFor`
  /// reads it. Every other seat is somebody else's to state, a device that has
  /// never named its own has nothing to defend and takes what the record
  /// brings, and a seat deliberately emptied here stays empty rather than
  /// having the name it just removed pushed back onto it.
  ///
  /// Returns the same map, unchanged and identical, when nothing was defended
  /// — the callers compare by identity to decide whether the row now differs
  /// from what the sender has.
  Map<String, dynamic> _keepingOwnSeatOperator(Map<String, dynamic> data, OperationRow? existing) {
    if (existing == null || existing.localData == null) return data;
    final Object? localData;
    try {
      localData = jsonDecode(existing.localData!);
    } catch (_) {
      return data;
    }
    if (localData is! Map) return data;
    final position = normalizedMultiIdentifier(asQsonString(localData['multiIdentifier']) ?? '');
    if (position.isEmpty) return data;
    final key = operatorCallKeyFor(position);
    final existingData = jsonDecode(existing.data);
    if (existingData is! Map || !existingData.containsKey(key)) return data;
    final ours = existingData[key];
    if (data.containsKey(key) && data[key] == ours) return data;
    return {...data, key: ours};
  }

  /// Upserts operations received from the sync server. Leaves the locally
  /// derived counters (`qsoCount`, `startAtMillisMin/Max`) alone — they get
  /// recomputed from this device's own QSOs once any of this operation's
  /// QSOs are merged in too, and shouldn't be clobbered by the server's view
  /// of them in the meantime.
  ///
  /// Returns the min/max `syncedAtMillis` seen in this batch — a server-side
  /// watermark distinct from `startAtMillis`, carried on every inbound
  /// record — so `SyncEngine` can track "synced since" for the next pull,
  /// mirroring app-polo's `mergeSyncOperations`.
  Future<SyncWatermark> mergeFromSync(List<Map<String, dynamic>> operations) async {
    final watermark = SyncWatermark();
    // Whether anything in this batch came out of the merge differing from
    // what the sender sent — see the seat-operator splice below.
    var repaired = false;
    final incomingUuids = [for (final m in operations) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <OperationRow>[]
          : await (db.select(db.operations)..where((op) => op.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in operations) {
        final uuid = asQsonString(incoming['uuid']);
        if (uuid == null) continue;
        final data = Map<String, dynamic>.from(incoming)..remove('uuid');
        final deleted = data.remove('deleted') == true;
        // Carried through for informational parity with the sending
        // device's row, but never acted on here: this device never
        // hard-deletes on receipt of a sync record, purged or not — only
        // the device that itself purged the operation ever removes the row
        // (`SyncEngine`, after its own push is acknowledged).
        final purged = data.remove('purged') == true;
        normalizeLegacyStamps(data);
        watermark.include(asQsonNum(data['syncedAtMillis'])?.toInt());

        final existing = existingByUuid[uuid];
        // A purge tombstone for an operation this device doesn't have
        // describes nothing to remove, so it must never CREATE a row. The
        // server keeps a purged record for good and re-delivers it (its
        // `syncedAtMillis` lands within a millisecond of the watermark
        // tracked for the next pull), so inserting one resurrects the very
        // operation whose removal the operator just confirmed here — a
        // notice that comes back every sync round, forever. It would also
        // ask a device that never had the operation to confirm removing
        // it. Updating an EXISTING row is still right: that is what raises
        // the prompt in the first place.
        if (existing == null && purged) continue;
        if (existing != null &&
            inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: asQsonNum(data['updatedAtMillis'])?.toInt(),
            )) {
          continue;
        }

        // A defended seat operator is a CHANGE this device is making to the
        // record the sender holds, not a copy of it: written `synced: true`
        // it would never reach `pendingOperations`, so the server and every
        // other device would keep naming the operator this device just
        // rejected — for good, and into their exports. It goes out as this
        // device's own newer revision instead, which is what the stamp bump
        // says (a revision stamp reads the real clock — time.md §1).
        final merged = _keepingOwnSeatOperator(data, existing);
        final defended = !identical(merged, data);
        if (defended) merged['updatedAtMillis'] = _repairedStamp(asQsonNum(data['updatedAtMillis'])?.toInt());
        repaired = repaired || defended;
        await db.into(db.operations).insertOnConflictUpdate(OperationsCompanion(
              uuid: Value(uuid),
              data: Value(encodeOperationData(merged, 'operations:mergeFromSync')),
              deleted: Value(deleted),
              purged: Value(purged),
              synced: Value(!defended),
              updatedAtMillis: Value(asQsonNum(merged['updatedAtMillis'])?.toInt()),
            ));
      }
    });
    // Only when a row came out dirty: everything merged untouched is already
    // marked synced, and there is nothing new for the outbound side to react
    // to (which is why this path stays silent in the ordinary case).
    if (repaired) onChange?.call();
    return watermark;
  }

  /// Applies operation records received from a peer device over the direct
  /// LAN/BLE/relay channel (HALO-310) — sibling to [mergeFromSync], NOT a
  /// caller of it: same uuid-keyed upsert and [inboundIsStale] staleness
  /// gate, but left `synced: false` and DOES fire [onChange]. A record a
  /// peer originated has not reached the LoFi server from ANY device yet —
  /// the device that logged it may never regain internet access itself, so
  /// this device must still offer to push it once its own turn to sync
  /// comes, which is exactly what LoFi cloud sync's dirty-flag machinery
  /// already does for free once `synced` is false here too.
  Future<void> mergeFromPeer(List<Map<String, dynamic>> operations) async {
    final incomingUuids = [for (final m in operations) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <OperationRow>[]
          : await (db.select(db.operations)..where((op) => op.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in operations) {
        final uuid = asQsonString(incoming['uuid']);
        if (uuid == null) continue;
        final data = Map<String, dynamic>.from(incoming)..remove('uuid');
        final deleted = data.remove('deleted') == true;
        // Same as mergeFromSync: informational only, never acted on by a
        // receiving device — only the device that itself purged the
        // operation ever removes the row.
        final purged = data.remove('purged') == true;
        normalizeLegacyStamps(data);

        final existing = existingByUuid[uuid];
        // Never create a row from a purge tombstone, same as [mergeFromSync]
        // — and load-bearing here for a reason of its own: a row this path
        // creates starts `synced: false`, so it is invisible to
        // [watchReceivedPurgesPending] until this device's own next push
        // flips it true, and only THEN does an operation this device never
        // had start asking the operator to confirm removing it, every round,
        // forever.
        if (existing == null && purged) continue;
        if (existing != null &&
            inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: asQsonNum(data['updatedAtMillis'])?.toInt(),
            )) {
          continue;
        }

        // The row already goes out dirty on this path, but a DEFENDED seat
        // still needs its own revision stamp: left at the sender's, this
        // device's version compares equal everywhere it lands, and
        // `inboundIsStale` (>=) drops it — the repair would never leave here.
        final merged = _keepingOwnSeatOperator(data, existing);
        if (!identical(merged, data)) {
          merged['updatedAtMillis'] = _repairedStamp(asQsonNum(data['updatedAtMillis'])?.toInt());
        }
        await db.into(db.operations).insertOnConflictUpdate(OperationsCompanion(
              uuid: Value(uuid),
              data: Value(encodeOperationData(merged, 'operations:mergeFromPeer')),
              deleted: Value(deleted),
              purged: Value(purged),
              synced: const Value(false),
              updatedAtMillis: Value(asQsonNum(merged['updatedAtMillis'])?.toInt()),
            ));
      }
    });
    onChange?.call();
  }

  /// Marks every operation dirty, deleted ones included — used when
  /// "combining" local data into a newly linked account (DESIGN.md's sync
  /// reconciliation flow): the account has no idea this device's data
  /// exists yet, so all of it needs to go out, not just whatever changed
  /// since the last (different-account) sync. Mirrors app-polo's
  /// `resetSyncedStatus`.
  Future<void> resetSyncedStatus() async {
    await db.update(db.operations).write(const OperationsCompanion(synced: Value(false)));
  }

  /// Copies every operation (deleted ones included) into `OperationsBackup`
  /// under `backupId`, then deletes all of them from the live table — used
  /// when "replacing" local data with a different account's, or by the
  /// `SYNCALL` command. Mirrors app-polo's `clearAllOperationData`, but as a
  /// portable copy-then-delete instead of its SQLite-specific `ALTER TABLE
  /// RENAME` trick.
  Future<void> backupAndClearAll(String backupId) async {
    final now = nowMillis();
    await db.transaction(() async {
      final rows = await db.select(db.operations).get();
      for (final row in rows) {
        await db.into(db.operationsBackup).insert(OperationsBackupCompanion.insert(
              backupId: backupId,
              backupAtMillis: now,
              uuid: row.uuid,
              data: row.data,
              startAtMillisMin: Value(row.startAtMillisMin),
              startAtMillisMax: Value(row.startAtMillisMax),
              qsoCount: Value(row.qsoCount),
              deleted: Value(row.deleted),
            ));
      }
      await db.delete(db.operations).go();
    });
  }

  /// Normalizes on the way out as well as on the way in ([encodeOperationData]):
  /// a row stored before the writers coerced anything still holds whatever
  /// type it was given, and the writers cannot reach a row nothing writes to.
  ///
  /// NOT every reader comes through here — `_operationFor`, `sequences.dart`
  /// and `peer_outbox.dart` each decode the same blob raw, so a record can
  /// still be seen un-normalized by those. They survive on the model's
  /// probing getters rather than on this.
  ///
  /// `localData` is device-local rather than QSON, so it is decoded as-is.
  Operation _operationFromRow(OperationRow row) {
    // Never off-isolate, unlike the QSO decoder, so it reports in place.
    final violations = <QsonTypeViolation>[];
    final operation = _operationRowToModel(row, violations);
    for (final violation in violations) {
      onQsonTypeViolation?.call('operations:read', violation);
    }
    return operation;
  }

  Operation _operationRowToModel(OperationRow row, List<QsonTypeViolation> violations) => Operation(
        uuid: row.uuid,
        data: normalizeOperationQson(jsonDecode(row.data) as Map<String, dynamic>, violations: violations),
        qsoCount: row.qsoCount,
        startAtMillisMin: row.startAtMillisMin,
        startAtMillisMax: row.startAtMillisMax,
        deleted: row.deleted,
        synced: row.synced,
        purged: row.purged,
        localData: row.localData == null ? const {} : jsonDecode(row.localData!) as Map<String, dynamic>,
      );

  /// Merges [patch] into this operation's device-local, never-synced state
  /// (e.g. `ScoringService` writing its `scoring` summary blob under that
  /// key). Never touches `synced` — `localData` isn't part of what syncs.
  Future<void> updateLocalData(String uuid, Map<String, dynamic> patch) async {
    await db.transaction(() async {
      final operation = await get(uuid);
      if (operation == null) return;
      final merged = {...operation.localData, ...patch};
      await (db.update(db.operations)..where((op) => op.uuid.equals(uuid))).write(
        OperationsCompanion(localData: Value(jsonEncode(merged))),
      );
    });
  }
}
