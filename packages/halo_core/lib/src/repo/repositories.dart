// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Repositories are the only writers to the database. Every write keeps the
// indexed columns derived from the JSON `data`, marks rows dirty for sync
// (`synced = false`), and maintains the operation's cached counters. Reads
// for the UI are reactive drift streams — the database is the source of
// truth and, later, the multi-window bus (DESIGN.md §8).

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_clock.dart';
import '../db/database.dart';
import 'sequences.dart';
import '../dev_log.dart';
import '../models/models.dart';
import '../models/operation_operator.dart';
import '../models/qso_merge.dart';
import '../models/qson_values.dart';
import 'write_policy.dart';

const _uuidGenerator = Uuid();

/// Encodes a QSO's QSON for storage, normalizing wrong-typed fields on the
/// way — see [normalizeQsoQson]. Storage is the one chokepoint every write
/// path already passes through, and normalizing here is what lets a bad
/// value heal instead of being handed to the next reader: the getters coerce
/// on read, but only a write puts the corrected value back.
///
/// The indexed columns are derived from these same fields, so normalizing
/// here is also what keeps a record from aborting the transaction that
/// writes it: without it, a `bool` mode throws out of `_companionFor`,
/// rolls back the whole `mergeFromSync` round, and the server serves the
/// identical record again next round, forever.
String _encodeQsoData(Map<String, dynamic> data, String context) =>
    jsonEncode(_normalizedReporting(data, normalizeQsoQson, context));

/// [_encodeQsoData] for an operation.
String _encodeOperationData(Map<String, dynamic> data, String context) =>
    jsonEncode(_normalizedReporting(data, normalizeOperationQson, context));

Map<String, dynamic> _normalizedReporting(
  Map<String, dynamic> data,
  Map<String, dynamic> Function(Map<String, dynamic>, {List<QsonTypeViolation>? violations}) normalize,
  String context,
) {
  final violations = <QsonTypeViolation>[];
  final normalized = normalize(data, violations: violations);
  for (final violation in violations) {
    onQsonTypeViolation?.call(context, violation);
  }
  return normalized;
}

/// Whether an inbound sync record should be skipped in favor of the local
/// row it would overwrite. Both sides carry a revision stamp
/// (`updatedAtMillis`, written on every local edit and round-tripped through
/// the server inside the record's JSON): when both stamps exist, the inbound
/// record only wins if it is strictly newer — same rule as app-polo's
/// `mergeSyncQSOs`. Without unconditional-overwrite protection here, a pull
/// racing a local edit (or a "combine" backfill pulling this device's own
/// older copies back down) silently reverts local changes and marks them
/// synced. When the inbound record has no stamp (pre-stamp history), only
/// local rows with unpushed edits (`synced == false`) are protected; clean
/// rows accept it.
/// Rewrites app-polo's older `*OnMillis` spellings to the `*AtMillis` ones
/// this app reads, in place, the way polo's own `operationsDB.js` does on
/// read. Inbound sync can carry either, and the merge below compares
/// revisions BEFORE anything goes through the model's getters — so without
/// this a legacy record looks revision-less and loses every comparison.
void _normalizeLegacyStamps(Map<String, dynamic> data) {
  for (final (legacy, current) in const [
    ('createdOnMillis', 'createdAtMillis'),
    ('updatedOnMillis', 'updatedAtMillis'),
  ]) {
    final value = data.remove(legacy);
    if (value != null) data.putIfAbsent(current, () => value);
  }
}

bool _inboundIsStale({
  required int? existingUpdatedAtMillis,
  required bool existingSynced,
  required int? incomingUpdatedAtMillis,
}) {
  if (existingUpdatedAtMillis != null && incomingUpdatedAtMillis != null) {
    return existingUpdatedAtMillis >= incomingUpdatedAtMillis;
  }
  return incomingUpdatedAtMillis == null && !existingSynced;
}

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

  OperationsRepository(this.db, {this.onChange});

  /// Creating is never refused while the clock is travelled — the station call
  /// is marked instead, by [markedForTravel]. A refusal here would be
  /// unescapable: an operation is judged test data by its stored callsign, and
  /// there is nothing stored yet to judge.
  Future<Operation> create({required String stationCall, String userTitle = ''}) async {
    final operation = Operation(
      uuid: _uuidGenerator.v4(),
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
          data: Value(_encodeOperationData(operation.data, 'operations:create')),
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
      data: Value(_encodeOperationData(data, 'operations:saveData')),
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
    onChange?.call();
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
          data: Value(_encodeOperationData({...operation.data, 'updatedAtMillis': now}, 'operations:delete')));
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
  /// what it sent, and `_inboundIsStale` drops it on arrival — the seat's own
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
        _normalizeLegacyStamps(data);
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
            _inboundIsStale(
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
              data: Value(_encodeOperationData(merged, 'operations:mergeFromSync')),
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
  /// caller of it: same uuid-keyed upsert and [_inboundIsStale] staleness
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
        _normalizeLegacyStamps(data);

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
            _inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: asQsonNum(data['updatedAtMillis'])?.toInt(),
            )) {
          continue;
        }

        // The row already goes out dirty on this path, but a DEFENDED seat
        // still needs its own revision stamp: left at the sender's, this
        // device's version compares equal everywhere it lands, and
        // `_inboundIsStale` (>=) drops it — the repair would never leave here.
        final merged = _keepingOwnSeatOperator(data, existing);
        if (!identical(merged, data)) {
          merged['updatedAtMillis'] = _repairedStamp(asQsonNum(data['updatedAtMillis'])?.toInt());
        }
        await db.into(db.operations).insertOnConflictUpdate(OperationsCompanion(
              uuid: Value(uuid),
              data: Value(_encodeOperationData(merged, 'operations:mergeFromPeer')),
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

  /// Normalizes on the way out as well as on the way in ([_encodeOperationData]):
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

/// Normalizing here, not only in [_encodeQsoData], is what reaches a record
/// that was already stored: the writers cannot heal a row nothing writes to.
/// It also settles what the rest of the app is handed, because `data` is the
/// map itself — `SyncEngine._buildPayload` and `ExportService` both spread
/// it, so without this an export's ADIF hook reads the raw wrong-typed value
/// while the QSO list beside it shows the coerced one, and a push carries
/// the bad value back out to every other device.
///
/// The scan costs about 2.5µs against `jsonDecode`'s 3.4µs on a typical QSO,
/// and returns the same map untouched when there is nothing to fix — which
/// is every row but the rare bad one.
///
/// Reporting what it heals is not optional here: healing a stored record
/// hands the write path a clean map, so an operator editing that record
/// would otherwise stop reporting it too — losing the signal rather than
/// merely declining to add one. [violations] carries what was found back to
/// a caller that can report it.
///
/// `jsonDecode(...) as Map` is deliberately still a cast: a blob that is not
/// a JSON object is a corrupt row, not a wrong-typed field, and coercing it
/// would swallow real database corruption.
Qso _qsoFromRow(QsoRow row, {List<QsonTypeViolation>? violations}) => Qso(
      uuid: row.uuid,
      operationUuid: row.operation,
      data: normalizeQsoQson(jsonDecode(row.data) as Map<String, dynamic>, violations: violations),
      deleted: row.deleted,
      purged: row.purged,
      scoreCache: row.scoreCache,
    );

/// How many violations one decode batch carries back. A log with thousands
/// of bad rows would otherwise build a list the size of the damage and hand
/// every entry to the reporter, when the question being answered — WHICH
/// fields arrive wrong-typed — is settled by the first few. Sampling here
/// rather than at the reporter keeps the cost off the isolate hop too.
const _readViolationSampleLimit = 16;

/// The rows plus what healing them found, because a violation cannot report
/// itself from inside an isolate: `onQsonTypeViolation` is a top-level
/// global, so it is null in a spawned isolate and a report there would
/// simply vanish. Carrying them back as DATA is what keeps coverage uniform
/// — reporting in place would fire for small batches and silently not for
/// large ones, which reads as sampling rather than as a hole.
class _DecodedQsos {
  const _DecodedQsos(this.qsos, this.violations);
  final List<Qso> qsos;
  final List<QsonTypeViolation> violations;
}

_DecodedQsos _decodeQsos(List<QsoRow> rows) {
  final violations = <QsonTypeViolation>[];
  final qsos = [
    for (final row in rows)
      _qsoFromRow(row, violations: violations.length < _readViolationSampleLimit ? violations : null),
  ];
  return _DecodedQsos(qsos, violations);
}

/// Below this, decoding inline is cheaper than an isolate's spawn cost;
/// above it, [_qsoFromRow]'s per-row `jsonDecode` is real enough CPU work
/// (not the framework's usual sub-millisecond synchronous calls) that
/// running it on the UI isolate blocks that isolate's frame pump for long
/// enough to read as a stall rather than a stutter — moving it off-isolate
/// trades a slightly later result for a UI thread that stays free to
/// animate the transition while it waits.
const _qsoRowDecodeIsolateThreshold = 200;

/// Reports on THIS isolate whatever the decode healed, wherever it ran —
/// see [_DecodedQsos] for why the violations travel as data.
List<Qso> _reportedQsos(_DecodedQsos decoded) {
  for (final violation in decoded.violations) {
    onQsonTypeViolation?.call('qsos:read', violation);
  }
  return decoded.qsos;
}

Future<List<Qso>> _qsosFromRows(List<QsoRow> rows) async {
  if (rows.length < _qsoRowDecodeIsolateThreshold) return _reportedQsos(_decodeQsos(rows));
  try {
    return _reportedQsos(await Isolate.run(() => _decodeQsos(rows)));
  } catch (_) {
    // Isolate.spawn doesn't exist on web (dart2js/DDC) — halo_core is pure
    // Dart with no Flutter dependency, so there's no `kIsWeb` to branch on
    // up front — and any other isolate-infrastructure failure (spawn
    // refused under memory pressure, etc.) deserves the same recovery:
    // `watchForOperation`'s callers `.listen()` this without an `onError`,
    // so an error here would otherwise silently kill live rescoring instead
    // of just costing a slower decode. A genuinely malformed row still
    // throws the same way it did before this existed — inline decoding
    // doesn't change what a bad row does, only where a healthy one runs.
    return _reportedQsos(_decodeQsos(rows));
  }
}

/// SQLite's default bound-variable limit is 999. [historyForCalls]'s query
/// binds a few more params alongside the `IN` clause itself (the `deleted`/
/// `uuid.isNull()` checks), so this stays under that with room to spare
/// rather than pushing all the way to 999. As large as it safely can,
/// though, not just "safe": each chunk is a full query+decode round trip,
/// and a re-import whose `theirCall`s mostly already exist pays for a much
/// bigger result set per chunk than a fresh one does, so fewer, larger
/// chunks matter more here than for a fresh import's near-empty results.
const _inClauseChunkSize = 900;

class QsosRepository {
  final HaLoDatabase db;

  /// See `OperationsRepository.onChange`.
  final void Function()? onChange;

  /// Serial-number allocation (docs/design/contests.md §5.8). Null outside the
  /// app, where nothing declares a sequence; `add` then allocates nothing,
  /// which keeps `halo_core` free of any extension knowledge.
  ///
  /// Allocation must be atomic with the insert, so it happens here — but WHICH
  /// sequences exist is extension-declared, so the caller passes the
  /// descriptors to `add` instead of this layer going looking for them.
  final SequencesRepository? sequences;

  QsosRepository(this.db, {this.onChange, this.sequences});

  /// Throws [WriteRefused] if a NEW contact in [operationUuid] may not be
  /// written right now — see [WritePolicy].
  ///
  /// [ourCall] is consulted only when [operationUuid] is empty: a contact
  /// inside an operation is made with that operation's station call, so the
  /// operation decides. For a contact with no operation the declared call is
  /// the only identity there is, exactly as a new operation's own callsign is
  /// (`markedForTravel`).
  ///
  /// Reads nothing at all unless the clock is travelled, so the ordinary
  /// logging path pays for this with one boolean.
  Future<void> _refuseNewQso(String operationUuid, {String ourCall = ''}) async {
    if (!AppClock.instance.isTravelling) return;
    final refusal = WritePolicy.forQso(
      operation: await _operationFor(operationUuid),
      ourCall: operationUuid.isEmpty ? ourCall : '',
    );
    if (refusal != null) throw refusal;
  }

  /// Throws [WriteRefused] if the STORED contact [uuid] may not be written.
  ///
  /// Judged on the row in the database, never on the caller's copy. The
  /// caller's is a selection-time snapshot — the same one [_writeDeleted]
  /// already refuses to trust for its own write — and an edit that declared
  /// `our.call` as a test call would otherwise be its own permission slip,
  /// admitting a rewrite of a real contact's times in a single step.
  ///
  /// A row that is gone is not refused: the write below finds nothing and
  /// does nothing, which is the same outcome by a quieter route.
  Future<void> _refuseStoredQso(String uuid) async {
    if (!AppClock.instance.isTravelling) return;
    final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
    if (row == null) return;
    final stored = _qsoFromRow(row);
    final refusal = WritePolicy.forQso(
      operation: await _operationFor(stored.operationUuid),
      ourCall: stored.operationUuid.isEmpty ? stored.ourCall : '',
    );
    if (refusal != null) throw refusal;
  }

  /// The stored operation [uuid] names, or null when it names none.
  ///
  /// Only the station call is read, so the row is decoded here rather than
  /// reaching for `OperationsRepository` — this repository holds none, and the
  /// derived columns play no part in the judgement.
  Future<Operation?> _operationFor(String uuid) async {
    if (uuid.isEmpty) return null;
    final row = await (db.select(db.operations)..where((op) => op.uuid.equals(uuid))).getSingleOrNull();
    if (row == null) return null;
    return Operation(uuid: row.uuid, data: jsonDecode(row.data) as Map<String, dynamic>);
  }

  /// Settles the serial on [qso]'s ref.
  ///
  /// A number already on the ref WINS — it is what the logging panel showed the
  /// operator, which is what they sent on the air, so the log has to agree with
  /// it. The sequence is then raised past it so it can never be issued again.
  /// This is the normal path for a QSO logged through the UI.
  ///
  /// Allocation is the fallback, for QSOs that arrive without a number: the
  /// second and later calls of a call list, an extension-driven `addQso`, or
  /// any headless caller. It happens here, inside the insert transaction, so
  /// two of them can't collide.
  ///
  /// Returns a QSO with a fresh data map rather than mutating: a call-list
  /// batch shares one `refs` list across every `add()`, so mutating in place
  /// would give every call in the batch the first one's number.
  Future<Qso> _withAllocatedSerial(String operationUuid, Qso qso, SequenceRequest request) async {
    final refs = [
      for (final ref in qso.refs) Map<String, dynamic>.from(ref),
    ];
    final index = refs.indexWhere((r) => r['type'] == request.refType);

    final existing = index < 0 ? null : refs[index][request.field];
    final sent = existing is int ? existing : int.tryParse('${existing ?? ''}'.trim());

    // Either way the field ends up an int, so exports and the derived
    // high-water mark never have to care which path a number came from.
    // A number the operator was shown is written even when the log already
    // holds it — it went on the air — but the record says so
    // (docs/design/contests.md §5.8.1): the alert is the honest outcome of two
    // positions sending one number, and a silently duplicated log is not.
    final duplicate = sent != null && await sequences!.isIssued(operationUuid, request, sent);
    final value = sent ?? await sequences!.allocate(operationUuid, request);
    if (sent != null) await sequences!.raiseTo(operationUuid, request, sent);
    // Keep the derived-mark memo exact rather than making the next insert
    // rescan the log — this is the hot path, once per QSO.
    sequences!.noteIssued(operationUuid, request, value);

    if (index < 0) {
      refs.add({'type': request.refType, request.field: value});
    } else {
      refs[index][request.field] = value;
    }
    return Qso(
      uuid: qso.uuid,
      operationUuid: qso.operationUuid,
      data: {...qso.data, 'refs': refs, if (duplicate) Qso.serialConflictKey: true},
      deleted: qso.deleted,
      scoreCache: qso.scoreCache,
    );
  }

  /// Inserts a QSO from QSON data, deriving the indexed columns and
  /// refreshing the operation's counters, all in one transaction.
  ///
  /// [serialSequences] are the sequences the operation's contests declared
  /// (docs/design/contests.md §5.8); each fills its field on the QSO's ref
  /// unless the operator typed a number themselves.
  Future<Qso> add(
    String operationUuid,
    Map<String, dynamic> qsoData, {
    List<SequenceDescriptor> serialSequences = const [],
  }) async {
    final data = Map<String, dynamic>.from(qsoData);
    data['startAtMillis'] ??= nowMillis();
    data['uuid'] ??= _uuidGenerator.v4();
    data['updatedAtMillis'] = realNowMillis();

    var qso = Qso(uuid: data['uuid'] as String, operationUuid: operationUuid, data: data);
    await _refuseNewQso(operationUuid, ourCall: qso.ourCall);

    await db.transaction(() async {
      // Serial numbers are allocated HERE — once, at commit, atomically with
      // the insert (docs/design/contests.md §5.8). Anywhere earlier is
      // app-polo's root defect: a number claimed while composing leaks when the
      // QSO is wiped, and tapping a spot mid-QSO gives two QSOs the same one.
      //
      // The label is resolved from the QSO as committed, not from whatever band
      // was selected when the descriptor was fetched — the operator can still
      // change band between the lookup and pressing Enter.
      //
      // Event rows never allocate. NOTE/TODO/SOLAR/WEATHER annotations reach
      // this same `add` from the extension runtime carrying `band: 'event'`,
      // and burning a serial on each would silently gap the contest log.
      if (!qso.isEvent && sequences != null) {
        for (final descriptor in serialSequences) {
          qso = await _withAllocatedSerial(operationUuid, qso, descriptor.requestFor(qso));
        }
        // A real contact inserted with NO declared sequences may still carry a
        // serial on a ref — an ADIF import, or an extension's `addQso` command.
        // We can't know which labels it touched, so drop the memo and let the
        // next peek re-derive rather than issue a number already in the log.
        if (serialSequences.isEmpty && qso.refs.isNotEmpty) sequences!.invalidate();
      }
      await db.into(db.qsos).insert(_companionFor(qso, 'qsos:add'));
      await refreshOperationCounters(operationUuid);
    });
    onChange?.call();
    // Structured dev event — real contacts only, not timeline markers.
    if (!qso.isEvent) {
      DevLog.instance.log('qso', {
        'uuid': qso.uuid,
        'op': operationUuid,
        'call': (data['their'] as Map?)?['call'],
        'band': data['band'],
        'mode': data['mode'],
      });
    }
    return qso;
  }

  /// Adds a start/break/end marker to the QSO timeline (see `Qso.isEvent`).
  /// [operation] makes this a SEGMENT boundary rather than a plain marker: a
  /// `break`/`start` carrying one states the operation for the stretch that
  /// follows — a second park, a rover's new grid (docs/design/contests.md
  /// §5.1.3). It is a complete statement, not a diff: attributes it omits fall
  /// back to the base operation, never to the previous segment, so whatever
  /// calls this is responsible for restating anything meant to persist.
  Future<Qso> addEvent(
    String operationUuid, {
    required String kind,
    required int atMillis,
    Map<String, dynamic>? operation,
  }) {
    return add(operationUuid, {
      'band': 'event',
      'startAtMillis': atMillis,
      'event': {'event': kind, if (operation != null) 'operation': operation},
    });
  }

  Future<Qso?> get(String uuid) async {
    final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _qsoFromRow(row);
  }

  /// Writes a whole batch — new contacts inserted, existing ones updated — in
  /// ONE transaction, refreshing the operation's counters once and firing
  /// [onChange] once. Returns the number of rows written.
  ///
  /// [add] and [update] each open their own transaction and each refresh the
  /// counters, which is right for logging a contact and wrong for importing a
  /// thousand: the per-QSO cost is small but the per-QSO `onChange` rebuilds
  /// the QSO list every time, so an import would redraw the log once per
  /// contact while it ran.
  ///
  /// **Allocates no serial numbers.** An import carries whatever numbers the
  /// file had; issuing new ones would renumber someone's contest log. The
  /// memoized high-water mark is invalidated instead, so the next contact
  /// logged by hand re-derives it from a log that now includes these — the
  /// same reasoning as [update]'s hand-edited serial.
  ///
  /// **A uuid already in the table throws and rolls the whole batch back** —
  /// half an import is worse than none, since the operator can retry a failure
  /// but cannot easily find what a partial one landed. `uuid` is the primary
  /// key ACROSS operations, not within one, so this fires both for a plan
  /// built against a log that has since changed AND for a record that already
  /// exists in a different operation. The second is a re-import rather than a
  /// stale plan, and a caller that wants to support it (importing a QSON
  /// export into a new operation) has to strip or remap the uuids first.
  ///
  /// **QSON values must already be well-typed.** `startAtMillis` is coerced
  /// because it is the one field this method sets itself, but `band`, `mode`
  /// and the rest reach drift's typed columns as they came, so a file that
  /// puts a number where a string belongs throws a cast error mid-batch.
  /// Validating a whole record is the parser's job, not this one's.
  Future<int> writeBatch({
    required String operationUuid,
    List<Map<String, dynamic>> inserts = const [],
    List<Qso> updates = const [],
    // The plan-time snapshots the updates were merged from, by uuid. Any
    // row that moved past its snapshot between planning and this write (a
    // sync pull landing while the import's confirm dialog sat open) gets
    // its update re-merged against the row as it is NOW
    // ([mergeConcurrentEdit]), so the concurrent revision's fields survive
    // wherever the file didn't touch them. An update without a snapshot
    // writes as given.
    Map<String, Qso> updateBases = const {},
    // `false` for a caller writing one operation across many chunked calls
    // (a large import) — the counters only need to be right after the LAST
    // chunk, so the intermediate ones pass `false` here and the caller runs
    // [refreshOperationCounters] itself, once, after the final chunk.
    bool refreshCounters = true,
  }) async {
    if (inserts.isEmpty && updates.isEmpty) return 0;
    // Judged on the operation alone, unlike [add] — a bulk write names one
    // operation, and letting individual test-called records through would
    // land them inside a real operation, where nothing can find them again:
    // every cleanup path this feature relies on works per operation.
    await _refuseNewQso(operationUuid);

    final toInsert = <Qso>[];
    for (final data in inserts) {
      // One uuid, used for both the row and the QSON it carries — generating
      // it twice would give the record two identities. Typed loosely because
      // this data came out of a file: `as String?` would throw on a numeric
      // uuid rather than falling back.
      final supplied = data['uuid'];
      final uuid = supplied is String && supplied.isNotEmpty ? supplied : _uuidGenerator.v4();
      toInsert.add(Qso(
        uuid: uuid,
        operationUuid: operationUuid,
        data: {
          ...data,
          'uuid': uuid,
          // Coerced, not passed through: a file can carry "1721736000000" as
          // a string, and drift's typed column would throw a cast error
          // partway through the batch rather than rejecting the record.
          'startAtMillis': _millisOf(data['startAtMillis']) ?? nowMillis(),
          'updatedAtMillis': realNowMillis(),
        },
      ));
    }

    // A row's own `operationUuid` is what gets written, so an update carrying a
    // different one would MOVE that row — and this method refreshes the
    // counters of the operation it was given, leaving the one the row came
    // from permanently stale, since nothing recomputes it until the next write
    // there. Moving a contact between operations is a different job with a
    // different name; refusing is louder than silently corrupting a count.
    final targeted = <String>{};
    for (final qso in updates) {
      if (qso.operationUuid != operationUuid) {
        throw ArgumentError.value(
          qso.operationUuid,
          'updates',
          'QSO ${qso.uuid} belongs to a different operation than this batch',
        );
      }
      // Two updates for one row would apply in order, the second discarding
      // the first's merge, and BOTH would count as written. A plan that
      // targets a record twice has not finished folding; combining them here
      // would hide that.
      if (!targeted.add(qso.uuid)) {
        throw ArgumentError.value(qso.uuid, 'updates', 'QSO appears twice in one batch');
      }
    }

    var written = 0;
    await db.transaction(() async {
      // `db.batch()`, not one `.insert()`/`.write()` call per row — a large
      // import (thousands of records) otherwise pays a separate
      // prepare/bind/execute round trip per row; batching compiles the whole
      // set into one statement, the same way `insertLookupBatch` already does
      // for lookup rows. Still inside `db.transaction()`, so a duplicate uuid
      // still throws and rolls the whole batch back (`batch.insert`'s default
      // conflict mode matches `.insert()`'s).
      if (toInsert.isNotEmpty) {
        await db.batch((batch) {
          for (final qso in toInsert) {
            batch.insert(db.qsos, _companionFor(qso, 'qsos:writeBatch'));
          }
        });
        written += toInsert.length;
      }
      if (updates.isNotEmpty) {
        // The row is keyed on `qso.uuid`, so the QSON must agree. A merged
        // record takes the newer side's fields — `uuid` among them — so a QSON
        // import can hand back a map carrying the INCOMING file's uuid, and
        // writing it verbatim would leave the row with two identities.
        // `deleted` and `scoreCache` are deliberately NOT carried:
        // `_companionFor` writes neither column, so passing them would suggest
        // an authority this path does not have. It follows that an update
        // against a soft-deleted row succeeds into a tombstone and counts as
        // written while staying invisible — callers build their plan from
        // `watchForOperation`, which excludes deleted rows, so a plan should
        // never target one.
        final stampedByUuid = <String, Qso>{
          for (final qso in updates)
            qso.uuid: _restamped(Qso(
              uuid: qso.uuid,
              operationUuid: qso.operationUuid,
              data: {...qso.data, 'uuid': qso.uuid},
            )),
        };
        // `batch.update` has no return value, unlike the row-by-row `.write()`
        // this replaces — so which uuids actually exist is checked up front,
        // inside the same transaction (so nothing else can change it
        // underneath this read). An update whose uuid is no longer in the
        // table affects no rows; counting it anyway would report an import as
        // complete while a record deleted since the plan was built silently
        // didn't land.
        //
        // Chunked at [_inClauseChunkSize], the same as [historyForCalls] — a
        // caller that hands a large re-import's merges straight through
        // (`adif_import_flow.dart` does not chunk its own `writeBatch` call)
        // would otherwise build one `IN` clause with one bound variable per
        // update, and a big enough operation exceeds SQLite's limit on a
        // record count this method used to have no such ceiling on at all.
        final updateUuids = stampedByUuid.keys.toList();
        final existingUuids = <String>{};
        for (var i = 0; i < updateUuids.length; i += _inClauseChunkSize) {
          final chunk = updateUuids.sublist(i, math.min(i + _inClauseChunkSize, updateUuids.length));
          if (updateBases.isEmpty) {
            // No snapshots to reconcile against: the uuid projection is all
            // the check needs. Selecting full rows here would jsonDecode
            // every target's blob inline, mid-transaction — the same decode
            // [historyForCalls] routes through an isolate above 200 rows —
            // and a single corrupt blob would abort a batch whose UPDATE
            // would have overwritten it anyway.
            final rows = await (db.selectOnly(db.qsos)
                  ..addColumns([db.qsos.uuid])
                  ..where(db.qsos.uuid.isIn(chunk)))
                .map((row) => row.read(db.qsos.uuid)!)
                .get();
            existingUuids.addAll(rows);
            continue;
          }
          // Re-merge any target that moved past its plan-time snapshot —
          // see [updateBases]. Inside the same transaction as the write, so
          // the row read here is the row the batch below overwrites.
          final rows = await (db.select(db.qsos)..where((q) => q.uuid.isIn(chunk))).get();
          for (final row in rows) {
            existingUuids.add(row.uuid);
            final base = updateBases[row.uuid];
            if (base == null) continue;
            // `edited` is the already-stamped planned update — byte-identical
            // to the caller's data apart from `updatedAtMillis`, which the
            // outer restamp below overwrites anyway.
            final planned = stampedByUuid[row.uuid]!;
            final Qso current;
            try {
              current = _qsoFromRow(row);
            } catch (_) {
              // A corrupt stored blob can't be merged with — write the
              // planned update as-is, which replaces the bad blob.
              continue;
            }
            if (current.data['updatedAtMillis'] == base.data['updatedAtMillis']) continue;
            stampedByUuid[row.uuid] = _restamped(Qso(
              uuid: row.uuid,
              operationUuid: planned.operationUuid,
              data: mergeConcurrentEdit(base: base.data, current: current.data, edited: planned.data),
            ));
          }
        }
        await db.batch((batch) {
          for (final uuid in existingUuids) {
            batch.update(db.qsos, _companionFor(stampedByUuid[uuid]!, 'qsos:writeBatch'),
                where: (q) => q.uuid.equals(uuid));
          }
        });
        written += existingUuids.length;
      }
      if (refreshCounters) await refreshOperationCounters(operationUuid);
    });

    sequences?.invalidate();
    onChange?.call();
    return written;
  }

  /// [basedOn] is the record the editor loaded — the snapshot [qso]'s data
  /// was composed from. When given, the row is re-read inside the
  /// transaction and, if something else (a sync pull, a peer merge, a
  /// background lookup) moved it past that snapshot while the editor sat
  /// open, the concurrent revision's fields survive wherever this edit
  /// didn't touch them ([mergeConcurrentEdit]). Without the re-read, the
  /// whole-record write reverts the concurrent revision — and, restamped
  /// newer, the reversion wins on every device at the next sync. Same
  /// reasoning as [_writeDeleted]'s re-read.
  Future<void> update(Qso qso, {Qso? basedOn}) async {
    await _refuseStoredQso(qso.uuid);
    var stamped = _restamped(qso);
    await db.transaction(() async {
      if (basedOn != null) {
        final current = await get(qso.uuid);
        if (current != null && current.data['updatedAtMillis'] != basedOn.data['updatedAtMillis']) {
          stamped = _restamped(Qso(
            uuid: qso.uuid,
            operationUuid: qso.operationUuid,
            data: mergeConcurrentEdit(base: basedOn.data, current: current.data, edited: qso.data),
          ));
        }
      }
      await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid)))
          .write(_companionFor(stamped, 'qsos:update'));
      await refreshOperationCounters(stamped.operationUuid);
    });
    // An edit can change a serial by hand, and never routes through the
    // allocator — so the memoized high-water mark can no longer be trusted.
    // AFTER the commit: invalidating first would let a scan started in between
    // read the pre-edit log and memoize that as current.
    sequences?.invalidate();
    onChange?.call();
  }

  /// Marks the QSO carrying [number] on [request]'s sequence as a serial
  /// another position also sent (docs/design/contests.md §5.8.1) — the
  /// write-back for a conflict that reaches this device after its own QSO
  /// was committed. A no-op when no such QSO is here, or it is marked already.
  Future<void> markSerialConflict(String operationUuid, SequenceRequest request, int number) async {
    final rows = await (db.select(db.qsos)..where((q) => q.operation.equals(operationUuid))).get();
    for (final row in rows) {
      final qso = Qso(
        uuid: row.uuid,
        operationUuid: row.operation,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        deleted: row.deleted,
      );
      if (qso.isEvent || qso.serialConflict || !request.includes(qso)) continue;
      if (request.serialOn(qso) != number) continue;
      await update(Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {...qso.data, Qso.serialConflictKey: true},
        deleted: qso.deleted,
        scoreCache: qso.scoreCache,
      ));
      return;
    }
  }

  Future<void> softDelete(Qso qso) => _writeDeleted(qso, deleted: true);

  /// Restores a soft-deleted QSO. Pushing sends
  /// `deleted` only when true (see `SyncEngine._buildPayload`), so the
  /// restored record's payload simply omits the key.
  Future<void> undelete(Qso qso) => _writeDeleted(qso, deleted: false);

  /// Flips the deleted flag, re-stamping `data.updatedAtMillis` (rewriting
  /// `data`, not just flags): the write must sync as a revision newer than
  /// the record it tombstones/restores, or other devices' merge comparison
  /// would discard it. Re-reads the row inside the transaction rather than
  /// trusting the caller's [qso] — that's a selection-time snapshot which
  /// can sit on screen indefinitely, and sync may have merged a newer
  /// revision since; restamping the snapshot would clobber those edits on
  /// every device.
  Future<void> _writeDeleted(Qso qso, {required bool deleted}) async {
    await _refuseStoredQso(qso.uuid);
    var changed = false;
    await db.transaction(() async {
      final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).getSingleOrNull();
      if (row == null) return; // hard-deleted since selection — nothing to flip
      final stamped = _restamped(_qsoFromRow(row));
      await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(
        QsosCompanion(
          deleted: Value(deleted),
          synced: const Value(false),
          data: Value(_encodeQsoData(stamped.data, 'qsos:writeDeleted')),
          updatedAtMillis: Value(stamped.updatedAtMillis),
        ),
      );
      await refreshOperationCounters(stamped.operationUuid);
      changed = true;
    });
    if (changed) onChange?.call();
  }

  /// Live test contacts that belong to no operation.
  ///
  /// Purging works per operation everywhere else — `purgeTestOperations` walks
  /// operations, and the received-purge prompt is keyed on operation uuids —
  /// so a contact with no operation is reachable by none of it. The travelled
  /// clock can author exactly these (a test call is the only thing identifying
  /// one), which is what makes the omission a leak rather than a corner.
  ///
  /// Filtered in Dart, not SQL: [isTestCall] matches `/`-separated SEGMENTS,
  /// which no LIKE pattern expresses, and the set being scanned is contacts
  /// with no operation at all — every loose contact on the account, since sync
  /// carries them between devices, but still not the size of the log.
  Future<List<Qso>> testQsosWithoutOperation() async {
    final rows = await (db.select(db.qsos)
          ..where((q) => q.operation.equals('') & q.purged.equals(false)))
        .get();
    return (await _qsosFromRows(rows)).where((qso) => isTestCall(qso.ourCall)).toList();
  }

  /// Tombstones [uuids] as purged, the same two-step [purgeForOperation]
  /// applies: the row stays until sync has carried the tombstone, and
  /// [hardDeletePurgedOrphans] removes it after that.
  ///
  /// Only ever called with contacts that have no operation, and only for TEST
  /// data — see `testQsosWithoutOperation`. A contact with no operation is
  /// ordinary data that happens to belong to nothing, and purging one is the
  /// operator's explicit act, never a consequence of having no operation.
  ///
  /// Removal is not prompt, and does not have to be: the row is `deleted` as
  /// well as `purged` from the moment this returns, so nothing shows it. The
  /// hard delete waits for a sync round that runs the gated sweep — in
  /// practice the first round of a later session — and on a device with sync
  /// switched off it never comes at all, since `synced` never becomes true.
  /// That is the same deal [purgeForOperation] and `hardDeletePurged` have
  /// always made for operations.
  Future<int> purgeQsos(Iterable<String> uuids) async {
    final ids = uuids.toList();
    if (ids.isEmpty) return 0;
    var purged = 0;
    await db.transaction(() async {
      for (final uuid in ids) {
        final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
        if (row == null) continue;
        // Re-checked inside the transaction, not trusted from the caller's
        // list: that list is built before a confirmation dialog the operator
        // may sit on indefinitely, and sync rounds run while travelling now,
        // so an inbound edit can give a row an operation — or a real call —
        // in between. A purge is unrecoverable and invisible once done.
        final stored = _qsoFromRow(row);
        if (stored.operationUuid.isNotEmpty || !isTestCall(stored.ourCall)) continue;
        final stamped = _restamped(_qsoFromRow(row));
        await (db.update(db.qsos)..where((q) => q.uuid.equals(uuid))).write(
          QsosCompanion(
            deleted: const Value(true),
            purged: const Value(true),
            synced: const Value(false),
            data: Value(_encodeQsoData(stamped.data, 'qsos:purge')),
            updatedAtMillis: Value(stamped.updatedAtMillis),
          ),
        );
        purged++;
      }
    });
    if (purged > 0) onChange?.call();
    return purged;
  }

  /// Soft-deletes with `purged: true` every QSO of [operationUuid],
  /// regardless of its current `deleted` state — the QSO-side half of
  /// `OperationsRepository.purge`. Unlike a normal operation delete (which
  /// deliberately leaves QSOs alone, see [historyForCall]'s doc), a purge is
  /// unrecoverable by design, so touching every QSO row directly is safe:
  /// there's no "undelete" state left to lose track of.
  Future<void> purgeForOperation(String operationUuid) async {
    await _refuseNewQso(operationUuid);
    await db.transaction(() async {
      final rows = await (db.select(db.qsos)..where((q) => q.operation.equals(operationUuid))).get();
      for (final row in rows) {
        // The mirrored column must match `stamped.data`'s own
        // `updatedAtMillis`, not a separately-captured timestamp — a
        // divergence here is exactly what makes `markSynced`'s stamp
        // comparison fail forever and the row re-push in a loop.
        final stamped = _restamped(_qsoFromRow(row));
        await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(
          QsosCompanion(
            deleted: const Value(true),
            purged: const Value(true),
            synced: const Value(false),
            data: Value(_encodeQsoData(stamped.data, 'qsos:purge')),
            updatedAtMillis: Value(stamped.updatedAtMillis),
          ),
        );
      }
    });
    onChange?.call();
  }

  /// See `OperationsRepository.hardDeletePurged` — the QSO-side half, run
  /// after a purged operation's row has already been hard-deleted so an
  /// orphaned QSO never outlives its operation.
  Future<void> hardDeletePurgedForOperation(String operationUuid) async {
    await (db.delete(db.qsos)
          ..where((q) => q.operation.equals(operationUuid) & q.purged.equals(true) & q.synced.equals(true)))
        .go();
  }

  /// Removes every QSO of [operationUuid], no flags checked — for a
  /// confirmed RECEIVED purge (`OperationsRepository.confirmReceivedPurges`),
  /// where [hardDeletePurgedForOperation]'s `purged && synced` predicate
  /// isn't reliable: operations and QSOs arrive in separate sync batches, so
  /// an operator can confirm as soon as the operation record lands, before
  /// this operation's QSOs' own purge tombstones have. A QSO left behind by
  /// that predicate would have no operation row to belong to any more, yet
  /// would keep surfacing in call history and dupe checks forever. Once the
  /// operator has agreed the whole operation goes, every QSO under it goes
  /// too — there is no partial-purge state left to preserve.
  Future<void> hardDeleteAllForOperation(String operationUuid) async {
    await (db.delete(db.qsos)..where((q) => q.operation.equals(operationUuid))).go();
  }

  /// Removes every purged QSO whose operation no longer exists on this
  /// device — QSOs whose own purge tombstone arrived after the operation
  /// they belong to was already gone (removed here through the
  /// received-purge confirmation, or hard-deleted by
  /// `OperationsRepository.hardDeletePurged` after this device's own purge
  /// synced). Nothing else can ever reach them: every other purge sweep is
  /// keyed by an operation uuid that has to still be there to be found, so
  /// without this they are unreclaimable — invisible (a purged QSO always
  /// carries `deleted: true`, which every read filters on) yet growing the
  /// database for the life of the install, with no operation left to name
  /// them in any future sweep.
  ///
  /// Safe precisely because a QSO is only ever purged as part of its whole
  /// operation ([purgeForOperation] is the only writer of `purged`): an
  /// orphaned purged QSO always belongs to an operation someone confirmed
  /// removing. Still gated on `synced`, so a local purge that hasn't
  /// reached the server yet keeps its tombstone to push.
  /// "Orphan" here means PURGED and already pushed — never merely
  /// operation-less. All three conditions are load-bearing, and the name
  /// invites dropping the first one: a contact with no operation, or one
  /// whose operation was deleted, is ordinary data and must survive this
  /// however long it sits there. Only an explicit purge marks a contact for
  /// removal, and `synced` is what proves the other devices have been told.
  Future<int> hardDeletePurgedOrphans() async {
    final liveOperations = db.selectOnly(db.operations)..addColumns([db.operations.uuid]);
    return (db.delete(db.qsos)
          ..where((q) => q.purged.equals(true) & q.synced.equals(true) & q.operation.isNotInQuery(liveOperations)))
        .go();
  }

  /// A copy of [qso] with a fresh revision stamp in its data — every local
  /// write goes through this so `data.updatedAtMillis` and the mirrored
  /// column never diverge (a divergent pair would make `markSynced`'s
  /// stamp comparison fail forever and the row re-push in a loop).
  Qso _restamped(Qso qso) => Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {...qso.data, 'updatedAtMillis': realNowMillis()},
        deleted: qso.deleted,
        purged: qso.purged,
        scoreCache: qso.scoreCache,
      );

  /// A timestamp as milliseconds, whatever shape it arrived in. Mirrors
  /// `qso_merge.dart`'s reader: if the two disagree about a string timestamp,
  /// a record matches nothing during planning and is then inserted anyway —
  /// a duplicate of a contact already in the log.
  static int? _millisOf(Object? value) {
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Stream<List<Qso>> watchForOperation(String operationUuid, {bool includeDeleted = false}) {
    final query = (db.select(db.qsos)
      ..where((q) => includeDeleted
          ? q.operation.equals(operationUuid)
          : q.operation.equals(operationUuid) & q.deleted.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]));
    return query.watch().asyncMap(_qsosFromRows);
  }

  /// Every non-deleted, non-event QSO with [call] across every operation, most
  /// recent first — for the call-info detail's QSO history. Matches the
  /// denormalized `theirCall` column (stored uppercase), so no JSON parsing.
  ///
  /// Deleting an operation deliberately does NOT tombstone its QSOs — that
  /// would be unrecoverable, since undeleting could no longer tell which of
  /// them the user had deleted individually beforehand. So a cross-operation
  /// query has to join: a QSO counts as gone when its own flag says so OR
  /// when the operation it belongs to is deleted. The join is a LEFT OUTER
  /// one because a QSO can outlive its operation row (an inbound sync batch
  /// can carry QSOs before the operation they belong to arrives) — those
  /// count as present, same as before.
  ///
  /// [limit], when given, bounds the SQL query itself (not a post-fetch
  /// truncation) — for a caller like `call-history`'s lookup source that
  /// only ever reads the most recent match or two: without it, a station
  /// worked hundreds of times ships its entire history across the extension
  /// bridge for an answer that only ever uses the first row. Applied before
  /// the event-marker filter below, so it is a headroom bound, not an exact
  /// result count.
  Future<List<Qso>> historyForCall(String call, {int? limit}) async {
    final normalized = call.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final query = db.select(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..where(db.qsos.theirCall.equals(normalized) &
          db.qsos.deleted.equals(false) &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis, mode: OrderingMode.desc)]);
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return [
      for (final row in rows.map((r) => _qsoFromRow(r.readTable(db.qsos))))
        if (!row.isEvent) row,
    ];
  }

  /// [historyForCall] for every one of [calls] in a single query — an ADIF
  /// import matching a large file's counterparties one callsign at a time
  /// turns into thousands of sequential round trips. Chunked at
  /// [_inClauseChunkSize] for SQLite's bound-variable limit; [watchForOurCalls]
  /// does not chunk its own `IN` list, since every caller today passes it a
  /// single callsign.
  ///
  /// [onChunk], when given, is called after every chunk with (calls looked
  /// up so far, total calls) — real progress for a caller that would
  /// otherwise have nothing but "still working" for however long the
  /// chunks take.
  Future<List<Qso>> historyForCalls(Iterable<String> calls, {void Function(int done, int total)? onChunk}) async {
    final normalized = calls.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
    if (normalized.isEmpty) return const [];
    final results = <Qso>[];
    for (var i = 0; i < normalized.length; i += _inClauseChunkSize) {
      final chunk = normalized.sublist(i, math.min(i + _inClauseChunkSize, normalized.length));
      final query = db.select(db.qsos).join([
        leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
      ])
        ..where(db.qsos.theirCall.isIn(chunk) &
            db.qsos.deleted.equals(false) &
            (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
      final rows = await query.get();
      // `_qsosFromRows`, not a bare `.map(_qsoFromRow)` — a chunk from an
      // established callsign can itself clear the isolate-offload
      // threshold, and this runs while the import's progress dialog is
      // animating.
      final decoded = await _qsosFromRows([for (final row in rows) row.readTable(db.qsos)]);
      results.addAll(decoded.where((qso) => !qso.isEvent));
      // A caller's progress UI throwing (a disposed notifier, a formatting
      // edge case) must not fail the lookup itself, or discard whatever
      // chunks already decoded cleanly.
      try {
        onChunk?.call(math.min(i + _inClauseChunkSize, normalized.length), normalized.length);
      } catch (e) {
        DevLog.instance.log('historyForCalls-onChunk-error', {'error': e.toString()});
      }
    }
    return results;
  }

  /// Every station callsign QSOs have been logged under, across every
  /// operation, with how many QSOs each has — the Logs experiment's
  /// callsign picker (docs card HALO-273), which shows the count as a pill
  /// next to each entry. Matches the denormalized `ourCall` column (stored
  /// uppercase), same join shape as [historyForCall]: a deleted operation's
  /// QSOs drop out even though deleting an operation does not tombstone
  /// them.
  Stream<Map<String, int>> watchDistinctOurCalls() {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([db.qsos.ourCall, count])
      ..where(db.qsos.ourCall.isNotNull() &
          db.qsos.ourCall.equals('').not() &
          db.qsos.deleted.equals(false) &
          // Event markers (start/break/end) carry no real callsign —
          // excluded the same way `historyForCall` excludes them from a
          // QSO list, or a callsign whose only rows are markers shows up
          // in this picker with nothing behind it. `_isContact`, not a
          // bare `band != 'event'`: that reads NULL — not true — for a
          // QSO logged without a band, silently dropping it too.
          _isContact &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..groupBy([db.qsos.ourCall]);
    return query.watch().map((rows) {
      final calls = <String, int>{};
      for (final row in rows) {
        final call = row.read(db.qsos.ourCall);
        if (call != null && call.isNotEmpty) calls[call] = row.read(count) ?? 0;
      }
      return calls;
    });
  }

  /// Every non-deleted QSO logged under any of [calls] (own station
  /// callsign), across every operation, oldest first — the Logs experiment's
  /// QSO table, scoped by its "log filter". Same join shape as
  /// [historyForCall], but on `ourCall` instead of `theirCall`, and live
  /// (the log filter's callsign selection can change under the caller).
  /// Unlike [historyForCalls], [calls] is not chunked — stay well under
  /// SQLite's bound-variable limit (~999) if the log filter ever grows past a
  /// single callsign.
  Stream<List<Qso>> watchForOurCalls(Iterable<String> calls) {
    final normalized = calls.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
    if (normalized.isEmpty) return Stream.value(const []);
    final query = db.select(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..where(db.qsos.ourCall.isIn(normalized) &
          db.qsos.deleted.equals(false) &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis)]);
    return query.watch().asyncMap((rows) async {
      final decoded = await _qsosFromRows([for (final row in rows) row.readTable(db.qsos)]);
      // Same exclusion `historyForCall` applies — an event marker is not a
      // QSO, and this view has no concept of one to render or edit.
      return decoded.where((qso) => !qso.isEvent).toList();
    });
  }

  /// Up to `limit` dirty QSOs, most recent first — mirrors `sync.js`'s
  /// `queryQSOs("WHERE synced IS false ... ORDER BY startAtMillis DESC")`.
  /// [excluding] holds records back WITHOUT marking them clean — the sync
  /// engine's refusal quarantine (see `SyncEngine.refusalQuarantine`). Skipped
  /// in the query rather than filtered after it: this is a `LIMIT`, so a
  /// refused record that sorts early would otherwise fill the batch every
  /// round and nothing behind it would ever be offered again.
  Future<List<Qso>> unsyncedBatch(int limit, {Set<String> excluding = const {}}) async {
    final query = (db.select(db.qsos)
      ..where((q) => excluding.isEmpty
          ? q.synced.equals(false)
          : q.synced.equals(false) & q.uuid.isNotIn(excluding.toList()))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis, mode: OrderingMode.desc)])
      ..limit(limit));
    return (await query.get()).map(_qsoFromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row = await (db.select(db.qsos)..where((q) => q.synced.equals(false))..limit(1)).getSingleOrNull();
    return row != null;
  }

  /// See `OperationsRepository.markSynced` — only rows whose revision stamp
  /// still matches the sent copy are marked, so an edit made while the
  /// round's network call was in flight stays dirty and re-pushes.
  Future<void> markSynced(Iterable<Qso> sent) async {
    final list = sent.toList();
    if (list.isEmpty) return;
    await db.transaction(() async {
      for (final q in list) {
        final stamp = q.updatedAtMillis;
        await (db.update(db.qsos)
              ..where((row) =>
                  row.uuid.equals(q.uuid) &
                  (stamp == null ? row.updatedAtMillis.isNull() : row.updatedAtMillis.equals(stamp))))
            .write(const QsosCompanion(synced: Value(true)));
      }
    });
  }

  /// See `OperationsRepository.syncCounts`. `total` applies the same rule
  /// `historyForCall` does — a QSO is gone when its own flag says so or when
  /// its operation's does — so deleting an operation drops its contacts from
  /// the count without touching a single QSO row.
  ///
  /// Event markers (start/break/end, `Qso.isEvent`) are not contacts and are
  /// excluded, the same way [syncCountsForOperation] excludes them: anything
  /// labelled "QSOs" to the operator must mean the number they logged. LoFi's
  /// `Account#stats` applies the same filter so the two sides stay comparable
  /// in the Sync panel's Synced Data row.
  /// A row of the qsos table that is a contact rather than a start/break/end
  /// marker. The ONE definition — every count the operator reads as "QSOs"
  /// uses it, and LoFi's `QSO.contacts` scope mirrors it so the Sync panel can
  /// put the two numbers side by side.
  ///
  /// `band` is nullable, and `NOT (band = 'event')` is NULL — not true — for a
  /// QSO logged without one, so the null case has to be spelled out or those
  /// QSOs silently leave the count.
  Expression<bool> get _isContact => db.qsos.band.equals('event').not() | db.qsos.band.isNull();

  Future<({int total, int pending})> syncCounts() async {
    final count = db.qsos.uuid.count();

    final totalQuery = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([count])
      ..where(db.qsos.deleted.equals(false) &
          _isContact &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
    final totalCount = (await totalQuery.getSingle()).read(count) ?? 0;

    final pendingQuery = db.selectOnly(db.qsos)
      ..addColumns([count])
      ..where(db.qsos.synced.equals(false));
    final pendingCount = (await pendingQuery.getSingle()).read(count) ?? 0;

    return (total: totalCount, pending: pendingCount);
  }

  /// How many CONTACTS the server has not received — [syncCounts]'s `total`
  /// rule with `synced == false` added. Distinct from `pending`, which
  /// counts every dirty ROW (tombstones and event markers included) because
  /// it answers the sync loop's "anything to push?"; this one gates
  /// destructive wipe flows, where the number shown to the operator must
  /// mean "logged QSOs that exist nowhere else". A dirty tombstone is
  /// un-pushed state too, but its loss direction is a resurrection, not a
  /// vanished contact — counting it would make the warning wrong in both
  /// magnitude and direction.
  Future<int> unsyncedContactCount() async {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([count])
      ..where(db.qsos.synced.equals(false) &
          db.qsos.deleted.equals(false) &
          _isContact &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Same as [syncCounts], but scoped to one operation's (non-deleted) rows,
  /// and split into real QSOs vs. event markers (start/break/end, see
  /// `Qso.isEvent`) — for the Exports Panel's per-operation sync summary,
  /// which exports only real QSOs (`ExportService._qsoListFor`) and would
  /// otherwise show a pending count inflated by markers that never export.
  Future<({int total, int pending, int eventTotal, int eventPending})> syncCountsForOperation(String operationUuid) async {
    final count = db.qsos.uuid.count();
    Future<int> countWhere(Expression<bool> where) async {
      final result = await (db.selectOnly(db.qsos)
            ..addColumns([count])
            ..where(where))
          .getSingle();
      return result.read(count) ?? 0;
    }

    final base = db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false);
    // Not `_isContact.not()`: a QSO with no band belongs to neither side under
    // a naive negation, and would vanish from the panel entirely.
    final isEvent = db.qsos.band.equals('event');

    final total = await countWhere(base & _isContact);
    final pending = await countWhere(base & _isContact & db.qsos.synced.equals(false));
    final eventTotal = await countWhere(base & isEvent);
    final eventPending = await countWhere(base & isEvent & db.qsos.synced.equals(false));

    return (total: total, pending: pending, eventTotal: eventTotal, eventPending: eventPending);
  }

  /// Upserts QSOs received from the sync server and refreshes the counters
  /// of every operation they belong to. See `OperationsRepository.mergeFromSync`
  /// for the returned watermark's purpose.
  Future<SyncWatermark> mergeFromSync(List<Map<String, dynamic>> qsos) async {
    final watermark = SyncWatermark();
    final affectedOperations = <String>{};
    final incomingUuids = [for (final m in qsos) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <QsoRow>[]
          : await (db.select(db.qsos)..where((q) => q.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in qsos) {
        final uuid = asQsonString(incoming['uuid']);
        // A null or absent operation is a contact that belongs to none — the
        // server's own shape for one (`QSO#sync_data_attributes` writes
        // `operation&.uuid`), and what it returns for every loose contact this
        // device pushes. It maps onto the local `''`. Skipping those records
        // makes the loose half of a log a one-way trip: it uploads, the server
        // stores it, and no device ever gets it back.
        //
        // A PRESENT operation of the wrong type is a different thing and still
        // fails closed: it names an operation whose uuid this cannot read, so
        // filing the record as loose would silently detach a contact from the
        // operation it belongs to.
        final rawOperation = incoming['operation'];
        final operationUuid = rawOperation == null ? '' : asQsonString(rawOperation);
        if (uuid == null || operationUuid == null) continue;

        final data = Map<String, dynamic>.from(incoming)..remove('operation');
        final deleted = data.remove('deleted') == true;
        // See OperationsRepository.mergeFromSync: carried through, never
        // acted on by a receiving device.
        final purged = data.remove('purged') == true;
        _normalizeLegacyStamps(data);
        watermark.include(asQsonNum(data['syncedAtMillis'])?.toInt());

        final existing = existingByUuid[uuid];
        // Never create a row from a purge tombstone — see
        // `OperationsRepository.mergeFromSync` for why re-delivery makes
        // this load-bearing. A tombstone for a QSO this device does not have
        // stands for nothing worth keeping, whichever writer produced it:
        // `purgeForOperation` when a whole operation goes, or `purgeQsos` for
        // a test contact belonging to no operation.
        if (existing == null && purged) continue;
        if (existing != null &&
            _inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: asQsonNum(data['updatedAtMillis'])?.toInt(),
            )) {
          continue;
        }

        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);

        await db.into(db.qsos).insertOnConflictUpdate(
              _companionFor(qso, 'qsos:mergeFromSync')
                  .copyWith(synced: const Value(true), deleted: Value(deleted), purged: Value(purged)),
            );
        // `''` names no operation, so there are no counters to refresh.
        if (operationUuid.isNotEmpty) affectedOperations.add(operationUuid);
        // The operation the record LEAVES, when the inbound copy moves it —
        // into another operation, or (now that a null operation is honoured)
        // out into the general log. Its cached `qsoCount` and start/end
        // bounds are columns, recomputed only by an explicit refresh, so
        // without this they keep counting a contact that is no longer there.
        if (existing != null && existing.operation != operationUuid && existing.operation.isNotEmpty) {
          affectedOperations.add(existing.operation);
        }
      }
      for (final operationUuid in affectedOperations) {
        await refreshOperationCounters(operationUuid);
      }
    });
    // Another device's numbers arrived without passing through the allocator,
    // so re-derive rather than hand out one already on the air. AFTER the
    // commit — see `update` above for why the ordering matters.
    sequences?.invalidate();
    // No onChange() here — see OperationsRepository.mergeFromSync.
    return watermark;
  }

  /// Applies QSOs received from a peer device (HALO-310) — see
  /// `OperationsRepository.mergeFromPeer`'s doc for why this is a sibling of
  /// [mergeFromSync] rather than a caller of it: same upsert/staleness shape,
  /// but left `synced: false` and fires [onChange] so this device still
  /// offers the record to LoFi cloud sync on its own next round.
  Future<void> mergeFromPeer(List<Map<String, dynamic>> qsos) async {
    final affectedOperations = <String>{};
    final incomingUuids = [for (final m in qsos) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <QsoRow>[]
          : await (db.select(db.qsos)..where((q) => q.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in qsos) {
        final uuid = asQsonString(incoming['uuid']);
        // Deliberately NOT [mergeFromSync]'s mapping of a null operation onto
        // the local `''`: peer sharing is scoped to one operation, and
        // `PeerOutbox` only ever emits rows carrying that uuid — so a peer
        // record naming no operation is a malformed frame, not a loose
        // contact, and belongs on the floor.
        final operationUuid = asQsonString(incoming['operation']);
        if (uuid == null || operationUuid == null) continue;

        final data = Map<String, dynamic>.from(incoming)..remove('operation');
        final deleted = data.remove('deleted') == true;
        final purged = data.remove('purged') == true;
        _normalizeLegacyStamps(data);

        final existing = existingByUuid[uuid];
        // See [mergeFromSync] and `OperationsRepository.mergeFromPeer`: a
        // tombstone for a QSO this device does not have stands for nothing
        // worth keeping.
        if (existing == null && purged) continue;
        if (existing != null &&
            _inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: asQsonNum(data['updatedAtMillis'])?.toInt(),
            )) {
          continue;
        }

        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);
        await db.into(db.qsos).insertOnConflictUpdate(
              _companionFor(qso, 'qsos:mergeFromPeer').copyWith(deleted: Value(deleted), purged: Value(purged)),
            );
        affectedOperations.add(operationUuid);
      }
      for (final operationUuid in affectedOperations) {
        await refreshOperationCounters(operationUuid);
      }
    });
    // A peer's QSO may carry a serial this device's allocator has never seen.
    sequences?.invalidate();
    onChange?.call();
  }

  /// See `OperationsRepository.resetSyncedStatus`.
  Future<void> resetSyncedStatus() async {
    await db.update(db.qsos).write(const QsosCompanion(synced: Value(false)));
  }

  /// See `OperationsRepository.backupAndClearAll`.
  Future<void> backupAndClearAll(String backupId) async {
    final now = nowMillis();
    await db.transaction(() async {
      final rows = await db.select(db.qsos).get();
      for (final row in rows) {
        await db.into(db.qsosBackup).insert(QsosBackupCompanion.insert(
              backupId: backupId,
              backupAtMillis: now,
              uuid: row.uuid,
              operation: row.operation,
              data: row.data,
              deleted: Value(row.deleted),
            ));
      }
      await db.delete(db.qsos).go();
    });
    sequences?.invalidate();
  }

  /// Batch-writes cached scoring results, one row update per QSO but all in
  /// a single transaction — the counterpart to the `scoring` hook's single
  /// coarse batched call (DESIGN.md §4). Score cache is locally derived, not
  /// synced content, so this never touches `synced` or fires [onChange];
  /// `watchForOperation` streams pick up the change on their own since it's
  /// still a write to the `qsos` table.
  Future<void> updateScoreCache(Map<String, String> scoreCacheByUuid) async {
    if (scoreCacheByUuid.isEmpty) return;
    await db.batch((batch) {
      for (final entry in scoreCacheByUuid.entries) {
        batch.update(
          db.qsos,
          QsosCompanion(scoreCache: Value(entry.value)),
          where: (q) => q.uuid.equals(entry.key),
        );
      }
    });
  }

  /// [context] names the write path for [_encodeQsoData]'s violation
  /// reports. Required rather than defaulted: a single shared label would
  /// make a wrong-typed field arriving from a peer indistinguishable from one
  /// our own importer wrote, which is the only question those reports exist
  /// to answer.
  QsosCompanion _companionFor(Qso qso, String context) => QsosCompanion(
        uuid: Value(qso.uuid),
        operation: Value(qso.operationUuid),
        ourCall: Value(qso.ourCall),
        theirCall: Value(qso.theirCall),
        band: Value(qso.band),
        mode: Value(qso.mode),
        startAtMillis: Value(qso.startAtMillis),
        data: Value(_encodeQsoData(qso.data, context)),
        synced: const Value(false),
        updatedAtMillis: Value(qso.updatedAtMillis),
      );

  /// `qsoCount`/`startAtMillisMin/Max` are a locally derived cache — never
  /// part of the JSON payload sync sends (see `SyncEngine._buildPayload`) —
  /// so refreshing them must not flip `synced` back to false. Doing so
  /// would make an operation perpetually "dirty" any time its QSOs change,
  /// even after a round already sent its actual (unchanged) content.
  ///
  /// Public (not called only from within this class) so a caller writing in
  /// many chunks — [writeBatch] with `refreshCounters: false` per chunk — can
  /// run this once after the last one, instead of once per chunk.
  Future<void> refreshOperationCounters(String operationUuid) async {
    // Self-transacting (drift nests a transaction() called from inside
    // another via a savepoint, so this stays cheap for the callers that
    // already wrap it in their own) — the SELECT and the UPDATE below have
    // to be atomic with respect to a concurrent write to the same
    // operation's QSOs, or the UPDATE can overwrite fresher counters with
    // the stale ones this SELECT computed. `refreshTouchedCounters` in
    // `logs_view.dart` is the one caller that has never had an outer
    // transaction of its own to rely on for that.
    await db.transaction(() async {
      final count = db.qsos.uuid.count();
      final minStart = db.qsos.startAtMillis.min();
      final maxStart = db.qsos.startAtMillis.max();
      // Event pseudo-QSOs (start/break/end markers) share the qsos table but
      // aren't real contacts — exclude them from the count and time range.
      final notEvent = db.qsos.band.isNull() | db.qsos.band.equals('event').not();
      final query = db.selectOnly(db.qsos)
        ..addColumns([count, minStart, maxStart])
        ..where(db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false) & notEvent);
      final row = await query.getSingle();

      await (db.update(db.operations)..where((op) => op.uuid.equals(operationUuid))).write(
        OperationsCompanion(
          qsoCount: Value(row.read(count) ?? 0),
          startAtMillisMin: Value(row.read(minStart)),
          startAtMillisMax: Value(row.read(maxStart)),
        ),
      );
    });
  }
}

/// Escapes SQLite LIKE metacharacters (`%`, `_`) in [input] so a search term
/// containing either is matched literally rather than as a wildcard —
/// pass `escapeChar: r'\'` on every `.like()` built from the result.
String _escapeLikePattern(String input) => input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

class LookupRepository {
  final HaLoDatabase db;

  LookupRepository(this.db);

  /// Performs a bulk insert or replace of lookup rows inside a single transaction.
  Future<void> insertLookupBatch(List<LookupRow> rows) async {
    await db.transaction(() async {
      await db.batch((batch) {
        for (final row in rows) {
          batch.insert(
            db.lookups,
            row,
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  /// Deletes all lookups within a specific category.
  Future<void> deleteCategory(String category) async {
    await (db.delete(db.lookups)..where((l) => l.category.equals(category))).go();
  }

  /// Deletes all lookups in a category that do not have the specified updated flag value (stale data).
  Future<void> deleteCategoryStale(String category, int updatedValue) async {
    await (db.delete(db.lookups)
          ..where((l) => l.category.equals(category) & l.updated.equals(updatedValue).not()))
        .go();
  }

  /// Retrieves a single lookup row by category and key.
  Future<LookupRow?> getLookup(String category, String key) async {
    return await (db.select(db.lookups)
          ..where((l) => l.category.equals(category) & l.key.equals(key)))
        .getSingleOrNull();
  }

  /// A row this program has NOT retired: `flags` 0 is the one value that means
  /// retired, which every activity's data-file mapper writes for a reference
  /// its program has delisted.
  ///
  /// The null arm is load-bearing, not defensive. `flags` is nullable and most
  /// mappers never set it, and SQL's `flags != 0` is NULL — therefore false —
  /// for those rows, so the obvious predicate would silently hide every lookup
  /// row that simply never said. Unknown is not retired.
  Expression<bool> _notRetired($LookupsTable l) => l.flags.isNull() | l.flags.equals(0).not();

  /// Searches lookups in a category by matching query prefix on key or name.
  ///
  /// [subCategory], when given, filters IN THIS QUERY rather than left to the
  /// caller: a common word ("trail") can match thousands of rows worldwide,
  /// and this query only returns the first 100 it finds. A caller that
  /// narrows by country AFTER fetching (POTA's `suggest` hook, scoping to the
  /// operator's own DXCC entity) can end up filtering an already-truncated
  /// 100 down to nothing even though a real match exists — "Appalachian
  /// Trail National Scenic Trail" searched as "trail" is exactly this:
  /// plenty of non-US "trail" rows fill the cap before SQLite (with no ORDER
  /// BY) happens to reach it. Filtering here means the limit applies to the
  /// already-narrowed set instead. Exact-equals only — SOTA scopes by entity
  /// too but needs a prefix match, so it still filters after fetching and
  /// still has this bug (extensions/activities/sota/src/index.ts).
  ///
  /// Key-prefix and name-prefix hits are also ordered first, for the rest —
  /// the ones a [relevanceForMatch]-style ranking would call most relevant —
  /// so those are what a full 100 rows displaces last.
  ///
  /// [activeOnly] drops rows a program has RETIRED, and belongs in the query
  /// for the same reason [subCategory] does. POTA keeps a retired park in its
  /// parks file rather than dropping it, so retirements arrive in bulk and
  /// CLUSTER: a program delists a whole class of reference at once, and a
  /// search for a word those share ("Wildlife Management Area" in an entity
  /// whose WMAs were swept) can fill all 100 rows with retired ones. Filtered
  /// afterward, in the caller, that search returns almost nothing while the
  /// active matches sit just past the cap.
  ///
  /// [query] is escaped via [_escapeLikePattern] before it's built into any
  /// pattern — a literal `%` or `_` in a searched name (e.g. a park with one
  /// in its title) would otherwise be read as a SQL wildcard instead of the
  /// character it is.
  Future<List<LookupRow>> queryLookups(
    String category,
    String query, {
    String? subCategory,
    bool activeOnly = false,
  }) async {
    final escaped = _escapeLikePattern(query);
    final keyPrefixMatch = db.lookups.key.like('$escaped%', escapeChar: r'\');
    final namePrefixMatch = db.lookups.name.like('$escaped%', escapeChar: r'\');
    return await (db.select(db.lookups)
          ..where((l) =>
              l.category.equals(category) &
              (l.key.like('%$escaped%', escapeChar: r'\') | l.name.like('%$escaped%', escapeChar: r'\')) &
              (subCategory == null ? const Constant(true) : l.subCategory.equals(subCategory)) &
              (activeOnly ? _notRetired(l) : const Constant(true)))
          ..orderBy([
            (l) => OrderingTerm(expression: keyPrefixMatch, mode: OrderingMode.desc),
            (l) => OrderingTerm(expression: namePrefixMatch, mode: OrderingMode.desc),
          ])
          ..limit(100))
        .get();
  }

  /// Searches lookups in a category by proximity to a lat/lon coordinate
  /// within a delta, closest first. Ordering (by squared distance, cheaper
  /// than a real Haversine and fine for ranking within this small bounding
  /// box) has to happen before the `limit` — otherwise the cap keeps
  /// whichever 100 rows the query planner happens to hit first rather than
  /// the 100 actually nearest to the caller, and a close-by entry can be
  /// dropped in favor of farther ones.
  ///
  /// [activeOnly] as in [queryLookups] — and for the same reason it precedes
  /// the `limit` here too, since a swept class of reference is as likely to
  /// be clustered in SPACE as in name.
  Future<List<LookupRow>> queryLookupsByLocation(
    String category,
    double lat,
    double lon,
    double delta, {
    bool activeOnly = false,
  }) async {
    final latDelta = db.lookups.lat - Variable(lat);
    final lonDelta = db.lookups.lon - Variable(lon);
    final distanceSquared = latDelta * latDelta + lonDelta * lonDelta;
    return await (db.select(db.lookups)
          ..where((l) =>
              l.category.equals(category) &
              l.lat.isBetweenValues(lat - delta, lat + delta) &
              l.lon.isBetweenValues(lon - delta, lon + delta) &
              (activeOnly ? _notRetired(l) : const Constant(true)))
          ..orderBy([(l) => OrderingTerm.asc(distanceSquared)])
          ..limit(100))
        .get();
  }
}

/// The QSON [row] carried, decoded from its stored blob. See `InboundCaptures`.
extension InboundCaptureRowQson on InboundCaptureRow {
  Map<String, dynamic> get qso => (jsonDecode(data) as Map).cast<String, dynamic>();
}

/// See `InboundCaptures` — QSOs captured from another logging program
/// ("Listen for other apps"), buffered until the operator decides whether to
/// add them to an operation's log.
class InboundCaptureRepository {
  final HaLoDatabase db;
  final void Function()? onChange;

  InboundCaptureRepository(this.db, {this.onChange});

  /// Records a capture, unless [dedupeKey] already exists — a program that
  /// broadcasts the same contact twice (a resend, a second listener sharing
  /// the port) must not queue it twice. Returns the stored row either way,
  /// so the caller doesn't need to care which happened.
  ///
  /// `insertOrIgnore` against the table's unique `dedupeKey` index, not a
  /// preceding `SELECT`: two datagrams for the same contact land through two
  /// independent socket callbacks (`InboundQsoListenerService`'s handlers
  /// fire-and-forget via `unawaited`), so a check-then-insert has a real race
  /// window between them — the index is what actually makes this atomic.
  Future<InboundCaptureRow> capture({
    required String source,
    required String dedupeKey,
    required Map<String, dynamic> qsoData,
  }) async {
    final uuid = _uuidGenerator.v4();
    await db.into(db.inboundCaptures).insert(
          InboundCapturesCompanion.insert(
            uuid: uuid,
            source: source,
            dedupeKey: dedupeKey,
            // Deliberately NOT normalized (unlike every other QSON write
            // here): this table stages what a peer app actually sent, and
            // repairing it in place would destroy the evidence of what
            // arrived. Normalization happens when a capture is promoted into
            // a real QSO.
            data: jsonEncode(qsoData),
            receivedAtMillis: nowMillis(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    // By dedupeKey, not [uuid]: a conflict means [uuid] was never written,
    // and the winner (whichever insert the unique index actually accepted)
    // is what the caller needs back either way. Whether OUR insert was the
    // winner is decided by comparing uuids, not `insert()`'s return value —
    // that's `sqlite3`'s `last_insert_rowid()`, which only changes on a
    // successful insert ANYWHERE on the connection, so it stays nonzero
    // (and useless as a "did this call insert anything" signal) the moment
    // any row has ever been inserted at all.
    final row = await (db.select(db.inboundCaptures)..where((c) => c.dedupeKey.equals(dedupeKey))).getSingle();
    if (row.uuid == uuid) onChange?.call();
    return row;
  }

  /// Every capture not yet added to any operation, oldest first — across all
  /// sources: "Listen for other apps" is one feature to the operator, not
  /// one per protocol, so its pending list is one list, not one per source.
  /// [source] survives on the row (and the dedupe key) purely as metadata.
  Stream<List<InboundCaptureRow>> watchPending() => (db.select(db.inboundCaptures)
        ..where((c) => c.addedToOperation.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.receivedAtMillis)]))
      .watch();

  /// Marks [uuids] as added to [operationUuid]. Kept rather than deleted, so
  /// a re-arriving duplicate broadcast is still recognized by its dedupe key
  /// instead of being queued a second time.
  Future<void> markAdded(Iterable<String> uuids, String operationUuid) async {
    if (uuids.isEmpty) return;
    await (db.update(db.inboundCaptures)..where((c) => c.uuid.isIn(uuids)))
        .write(InboundCapturesCompanion(addedToOperation: Value(operationUuid)));
    onChange?.call();
  }

  /// Discards [uuids] without adding them — the operator dismissing a bad
  /// capture (wrong station, a garbled datagram).
  Future<void> discard(Iterable<String> uuids) async {
    if (uuids.isEmpty) return;
    await (db.delete(db.inboundCaptures)..where((c) => c.uuid.isIn(uuids))).go();
    onChange?.call();
  }
}
