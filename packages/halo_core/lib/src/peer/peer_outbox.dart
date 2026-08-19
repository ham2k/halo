// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The write side of the peer device sync outbox (HALO-310) — see
// `PeerEvents`' doc in database.dart for the table's shape and why a row is a
// full snapshot, not a diff.
//
// Scan-based, mirroring `SyncEngine.notifyChanged`/`unsyncedBatch`, not a
// call-site hook: [notifyChanged] (wired to the SAME `onChange` callback
// repositories already fire for LoFi sync) debounces a scan of whatever
// changed in [activeOperationUuid] since the last one, rather than requiring
// every write path to remember to call something. A write path added later
// that forgets to call a call-site hook silently never reaches a peer, with
// no signal anything is missing; a scan can't be forgotten the same way, and
// it only ever reads fully-committed rows, so there's no "insert raced the
// write's own transaction" class of bug to guard against either.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../app_clock.dart';
import '../db/database.dart';

class PeerOutbox {
  final HaLoDatabase db;

  /// Real time, like `SyncEngine`'s — a travelled clock must not warp how
  /// long a burst of edits waits to coalesce (docs/design/time.md).
  static const debounceDelay = Duration(milliseconds: 500);
  static const debounceMaxWait = Duration(seconds: 3);

  String? _activeOperationUuid;

  /// The highest `updatedAtMillis` already scanned for [activeOperationUuid],
  /// Reset whenever sharing (re)starts — see [activeOperationUuid]'s setter
  /// for why a reset rather than a value carried across.
  int _watermarkMillis = 0;

  /// Bumped on every [activeOperationUuid] switch, checked by [scanNow]
  /// after its transaction commits — a scan started against operation A
  /// that is still in flight when sharing switches to B must not overwrite
  /// B's freshly-reset `_watermarkMillis` with A's stale one. The rows A's
  /// scan already wrote to `PeerEvents` are harmless to keep either way.
  int _generation = 0;

  /// True while a scan's transaction is in flight — [scanNow] no-ops if
  /// called again before this clears, rather than reading the same
  /// watermark twice and writing duplicate `PeerEvents` rows for the same
  /// rows. Whatever triggered the re-entrant call is not lost: every local
  /// write fires [notifyChanged] again regardless, so the next debounced
  /// scan (or [notifyChanged]'s own maxWait fallback) picks it up.
  bool _scanning = false;

  Timer? _debounceTimer;
  DateTime? _debounceStartedAt;

  /// Called after a scan that actually recorded something.
  ///
  /// This is what turns a local write into a live push: the scan is
  /// debounced, so a caller cannot simply push on every write — it would run
  /// before the events it means to send exist. Hanging the push off the scan
  /// instead means it fires exactly once per batch of new events, with the
  /// debounce intact.
  void Function()? onScanned;

  /// Diagnostic sink, set by the app layer. halo_core has no Flutter and so
  /// no `debugPrint`; without this a caught prune failure would disappear,
  /// which is the opposite of the point of catching it.
  void Function(String message)? log;

  PeerOutbox(this.db);

  /// The one operation currently shared with any peer, or null if none is —
  /// same single-slot shape as `InboundQsoListenerService.receivingOperationUuid`,
  /// for the same reason: HALO-310 v1 scopes peer sync to whichever operation
  /// the operator has open, not the whole log.
  String? get activeOperationUuid => _activeOperationUuid;

  set activeOperationUuid(String? operationUuid) {
    if (_activeOperationUuid == operationUuid) return;
    _activeOperationUuid = operationUuid;
    // Reset, so the next scan re-reads the whole operation.
    //
    // Deriving this from the outbox instead (MAX of the recorded stamps)
    // looks like a free optimization and is not: a record can arrive from a
    // peer or from cloud sync carrying THAT device's stamp, which may sit
    // ahead of this device's clock. That would raise the watermark past local
    // writes made in the meantime, and they would never be emitted at all. A
    // reset is what heals it — the re-read finds them whatever their stamp —
    // and it is paid once per share, not per scan. Nothing is re-sent for it:
    // [_alreadyRecorded] filters out everything the outbox already holds.
    _watermarkMillis = 0;
    _generation++;
    _debounceTimer?.cancel();
    _debounceStartedAt = null;
  }

  void dispose() => _debounceTimer?.cancel();

  /// Called after every local write (wired via the repositories' `onChange`
  /// callback, exactly like `SyncEngine.notifyChanged`) — debounces a scan so
  /// a burst of edits (e.g. typing) coalesces into one, but never waits more
  /// than [debounceMaxWait] if edits keep arriving back-to-back.
  void notifyChanged() {
    if (_activeOperationUuid == null) return;
    final now = realNowUtc();
    _debounceStartedAt ??= now;
    _debounceTimer?.cancel();

    if (now.difference(_debounceStartedAt!) >= debounceMaxWait) {
      _debounceStartedAt = null;
      unawaited(scanNow());
      return;
    }
    _debounceTimer = Timer(debounceDelay, () {
      _debounceStartedAt = null;
      unawaited(scanNow());
    });
  }

  /// Runs the scan immediately, bypassing the debounce. [notifyChanged] is
  /// the real trigger; callers (and tests) that need the outbox caught up
  /// deterministically call this directly instead of waiting on a timer.
  ///
  /// Known gap, bounded rather than closed: within one share session a
  /// record whose stamp sits BELOW the running watermark is not re-read, so a
  /// record carrying a faster peer's stamp can gate local writes until that
  /// clock catches up. Sharing the boundary millisecond exactly IS handled —
  /// the filter is `>=`, and [_alreadyRecorded] suppresses the duplicates
  /// that admits. The miss is never permanent: the watermark resets whenever
  /// sharing restarts, and the record's next edit re-stamps it past the mark.
  ///
  /// The same applies to one record edited TWICE inside a single millisecond:
  /// the second edit's stamp equals the one already on its row, so it reads
  /// as already recorded and its content waits for the next edit or re-share.
  /// The `>=` filter covers a DIFFERENT record sharing that millisecond, not
  /// the same one changing twice within it.
  Future<void> scanNow() async {
    if (_scanning) return;
    final operationUuid = _activeOperationUuid;
    if (operationUuid == null) return;
    final generation = _generation;

    // Set BEFORE the first await, or two calls in one turn both pass the
    // check above and the guard protects nothing.
    _scanning = true;
    try {
      final since = _watermarkMillis;
      // `>=`, not `>`. Two records can share a millisecond — a batch import,
      // or simply two writes landing inside one tick — and a strict `>` drops
      // the second one silently, permanently: the watermark persists, so
      // nothing re-reads that millisecond and the record stays missing until
      // it is next edited. The cost of `>=` is re-reading the boundary
      // millisecond's rows, which [_alreadyRecorded] then filters out.
      final opQuery = db.select(db.operations)..where((o) => o.uuid.equals(operationUuid));
      if (since > 0) opQuery.where((o) => o.updatedAtMillis.isBiggerOrEqualValue(since));
      final opRows = await opQuery.get();

      final qsoQuery = db.select(db.qsos)..where((q) => q.operation.equals(operationUuid));
      if (since > 0) qsoQuery.where((q) => q.updatedAtMillis.isBiggerOrEqualValue(since));
      final qsoRows = await qsoQuery.get();

      if (opRows.isEmpty && qsoRows.isEmpty) return;

      // The outbox is its own record of what has been emitted, so a record
      // whose current stamp is already on a row needs no second one.
      //
      // A null stamp NEVER counts as a match. `recorded[uuid]` is null both
      // for "no row exists" and for "a row exists with no stamp", so a record
      // whose own stamp is also null compares equal to both — silently
      // dropping every pre-stamp record (the ones the v6 backfill migration
      // exists for) on every scan, including a first share. Re-emitting one
      // is merely noisy: the prune collapses it and the receiver's staleness
      // gate absorbs it.
      final recorded = await _alreadyRecorded(operationUuid, since);
      bool alreadyOut(String uuid, int? stamp) => stamp != null && recorded[uuid] == stamp;

      // From what the scan SAW, not from what it emits. A row that was
      // filtered out is one the outbox already holds, so the mark may pass
      // it — and if it may not, the watermark stays where a re-share left it
      // (0) and every later scan re-reads the whole operation from scratch.
      // `notifyChanged` fires on every write anywhere in the app, including
      // cloud sync applying records for other operations, so that repeats
      // indefinitely until something in THIS operation is edited.
      var newWatermark = since;
      void includeInWatermark(int? updatedAtMillis) {
        if (updatedAtMillis != null && updatedAtMillis > newWatermark) newWatermark = updatedAtMillis;
      }
      for (final row in opRows) {
        includeInWatermark(row.updatedAtMillis);
      }
      for (final row in qsoRows) {
        includeInWatermark(row.updatedAtMillis);
      }

      opRows.removeWhere((r) => alreadyOut(r.uuid, r.updatedAtMillis));
      qsoRows.removeWhere((r) => alreadyOut(r.uuid, r.updatedAtMillis));
      if (opRows.isEmpty && qsoRows.isEmpty) {
        if (_generation == generation) _watermarkMillis = newWatermark;
        return;
      }

      await db.batch((batch) {
        for (final row in opRows) {
          batch.insert(
            db.peerEvents,
            PeerEventsCompanion.insert(
              operationUuid: operationUuid,
              kind: 'operation',
              recordUuid: row.uuid,
              updatedAtMillis: Value(row.updatedAtMillis),
              data: jsonEncode({
                ...jsonDecode(row.data) as Map<String, dynamic>,
                'uuid': row.uuid,
                if (row.deleted) 'deleted': true,
                if (row.purged) 'purged': true,
              }),
            ),
          );
        }
        for (final row in qsoRows) {
          batch.insert(
            db.peerEvents,
            PeerEventsCompanion.insert(
              operationUuid: operationUuid,
              kind: 'qso',
              recordUuid: row.uuid,
              updatedAtMillis: Value(row.updatedAtMillis),
              data: jsonEncode({
                ...jsonDecode(row.data) as Map<String, dynamic>,
                'uuid': row.uuid,
                'operation': row.operation,
                if (row.deleted) 'deleted': true,
                if (row.purged) 'purged': true,
              }),
            ),
          );
        }
      });
      // Only if sharing is still on the same operation it was when this scan
      // started — see [_generation]'s doc.
      if (_generation == generation) _watermarkMillis = newWatermark;
      // AFTER the insert commits, never inside its transaction: the prune is
      // housekeeping, and a DELETE that throws (a concurrent writer holding
      // the table, a full disk) would otherwise roll back the snapshots it
      // was only meant to tidy up behind — losing a just-logged contact from
      // the outbox while `latestSeq` reports success. Failing to prune costs
      // unbounded growth, which is recoverable; failing to insert costs a QSO
      // that never reaches the other device.
      try {
        await _pruneSuperseded(
          operationUuid,
          {...opRows.map((r) => r.uuid), ...qsoRows.map((r) => r.uuid)},
        );
      } catch (e) {
        log?.call('outbox prune failed for $operationUuid (rows will accumulate): $e');
      }
      onScanned?.call();
    } finally {
      _scanning = false;
    }
  }

  /// The stamp already on record for each record touched at or after
  /// [since] — what lets the scan re-read the boundary millisecond without
  /// emitting a duplicate for anything it has already captured.
  ///
  /// Bounded by [_pruneSuperseded]: at most one row per record survives, so
  /// this is one small map, not the whole history.
  Future<Map<String, int?>> _alreadyRecorded(String operationUuid, int since) async {
    // selectOnly, not select: a full row drags its whole JSON snapshot into
    // memory, and with `since == 0` that is every snapshot in the operation —
    // to read two small columns.
    final recordUuid = db.peerEvents.recordUuid;
    final stamp = db.peerEvents.updatedAtMillis;
    final query = db.selectOnly(db.peerEvents)
      ..addColumns([recordUuid, stamp])
      ..where(db.peerEvents.operationUuid.equals(operationUuid))
      // Ordered so that where two rows exist for one record (an earlier prune
      // that failed), the NEWEST stamp is the one that survives into the map.
      ..orderBy([OrderingTerm(expression: db.peerEvents.seq)]);
    if (since > 0) query.where(db.peerEvents.updatedAtMillis.isBiggerOrEqualValue(since));
    return {for (final row in await query.get()) row.read(recordUuid)!: row.read(stamp)};
  }

  /// Drops every row for [operationUuid] that a later row has superseded,
  /// keeping the newest per `recordUuid`.
  ///
  /// Safe because a row is a full snapshot, not a diff: a peer only ever
  /// needs the newest state of each record, and the row that superseded a
  /// deleted one carries a HIGHER `seq`, so a catch-up from any cursor still
  /// delivers it. `seq` is `INTEGER PRIMARY KEY AUTOINCREMENT`, so SQLite
  /// never reuses an id — a cursor held by a peer stays meaningful across
  /// this, which is the property the whole scheme rests on.
  ///
  /// What this bounds: without it the table grows with edits and with every
  /// re-share (records × edits × restarts). With it, roughly one row per
  /// record of every operation ever shared.
  Future<void> _pruneSuperseded(String operationUuid, Set<String> recordUuids) async {
    // Scoped to the records this scan just wrote, because those are the only
    // ones that can have gained a superseding row. Grouping the WHOLE
    // operation instead cannot use the `(operation_uuid, seq)` index, so it
    // costs a scan-and-sort of every outbox row of that operation per logged
    // contact — on the same path that then pushes to peers.
    //
    // Chunked: each uuid is two bound variables here, and a first share of a
    // large operation would otherwise blow past SQLite's variable limit.
    const chunk = 300;
    final ids = recordUuids.toList();
    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.sublist(i, math.min(i + chunk, ids.length));
      final places = List.filled(slice.length, '?').join(',');
      await db.customStatement(
        'DELETE FROM peer_events WHERE operation_uuid = ? AND record_uuid IN ($places) '
        'AND seq NOT IN (SELECT MAX(seq) FROM peer_events '
        'WHERE operation_uuid = ? AND record_uuid IN ($places) GROUP BY record_uuid)',
        [operationUuid, ...slice, operationUuid, ...slice],
      );
    }
  }

  /// This device's outbox events for [operationUuid] with `seq` strictly
  /// after [sinceSeq] (0 catches up a peer that has never synced this
  /// operation before), oldest first. Each map is exactly the shape
  /// `OperationsRepository.mergeFromPeer`/`QsosRepository.mergeFromPeer`
  /// expect as one entry of their input list — a catch-up reply hands this
  /// straight to whichever repository [PeerEventRow.kind] names.
  Future<List<PeerEventRow>> eventsSince(String operationUuid, int sinceSeq, {int limit = 500}) {
    return (db.select(db.peerEvents)
          ..where((e) => e.operationUuid.equals(operationUuid) & e.seq.isBiggerThanValue(sinceSeq))
          ..orderBy([(e) => OrderingTerm(expression: e.seq)])
          ..limit(limit))
        .get();
  }

  /// The highest `seq` this device has ever recorded for [operationUuid], or
  /// 0 if none — what this device tells a peer to catch IT up from.
  Future<int> latestSeq(String operationUuid) async {
    final maxSeq = db.peerEvents.seq.max();
    final query = db.selectOnly(db.peerEvents)
      ..addColumns([maxSeq])
      ..where(db.peerEvents.operationUuid.equals(operationUuid));
    return (await query.getSingle()).read(maxSeq) ?? 0;
  }
}

/// Per-peer, per-operation receive-side cursor — see `PeerCursors`' doc in
/// database.dart.
class PeerCursorStore {
  final HaLoDatabase db;

  PeerCursorStore(this.db);

  /// How far into [peerDeviceId]'s outbox for [operationUuid] this device has
  /// already applied — 0 if the pair has never synced this operation, which
  /// is also the right "since" value to request a full catch-up.
  Future<int> lastAppliedSeq(String peerDeviceId, String operationUuid) async {
    final row = await (db.select(db.peerCursors)
          ..where((c) => c.peerDeviceId.equals(peerDeviceId) & c.operationUuid.equals(operationUuid)))
        .getSingleOrNull();
    return row?.lastAppliedSeq ?? 0;
  }

  /// Advances the cursor to [seq] — never backwards, so an out-of-order
  /// delivery (a retransmit racing a newer live push) can't rewind a peer
  /// that's already caught up past it. Read-then-write, but inside one
  /// `transaction()` so two concurrent calls for the same pair (a live push
  /// racing a catch-up batch) can't both read the same starting point and
  /// have the smaller `seq` win by committing last.
  Future<void> advanceTo(String peerDeviceId, String operationUuid, int seq) async {
    await db.transaction(() async {
      final current = await lastAppliedSeq(peerDeviceId, operationUuid);
      if (seq <= current) return;
      await db.into(db.peerCursors).insertOnConflictUpdate(PeerCursorsCompanion.insert(
            peerDeviceId: peerDeviceId,
            operationUuid: operationUuid,
            lastAppliedSeq: Value(seq),
          ));
    });
  }
}
