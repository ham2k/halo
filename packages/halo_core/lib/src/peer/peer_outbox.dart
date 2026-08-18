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

  /// The highest `updatedAtMillis` already scanned for [activeOperationUuid].
  /// Reset to 0 whenever sharing (re)starts — see [activeOperationUuid]'s
  /// setter — so the next scan captures the operation's ENTIRE current state
  /// as a fresh snapshot rather than only what changes from here.
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

  PeerOutbox(this.db);

  /// The one operation currently shared with any peer, or null if none is —
  /// same single-slot shape as `InboundQsoListenerService.receivingOperationUuid`,
  /// for the same reason: HALO-310 v1 scopes peer sync to whichever operation
  /// the operator has open, not the whole log.
  String? get activeOperationUuid => _activeOperationUuid;

  set activeOperationUuid(String? operationUuid) {
    if (_activeOperationUuid == operationUuid) return;
    _activeOperationUuid = operationUuid;
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
  /// Known gap, accepted rather than engineered around: two rows sharing the
  /// EXACT same millisecond, split across two different scans (the first
  /// scan's watermark lands exactly on the second row's stamp), would miss
  /// the second until it's next edited. Realistically unreachable within one
  /// debounce window (a single scan sees everything committed so far in one
  /// query, ties included) — only a burst spanning the 3s `debounceMaxWait`
  /// boundary could split one. And the miss is bounded, not silent-forever:
  /// the row's next edit re-stamps it past the watermark, and turning
  /// sharing off and back on re-snapshots everything from scratch.
  Future<void> scanNow() async {
    if (_scanning) return;
    final operationUuid = _activeOperationUuid;
    if (operationUuid == null) return;
    final generation = _generation;
    final since = _watermarkMillis;

    _scanning = true;
    try {
      final opQuery = db.select(db.operations)..where((o) => o.uuid.equals(operationUuid));
      if (since > 0) opQuery.where((o) => o.updatedAtMillis.isBiggerThanValue(since));
      final opRows = await opQuery.get();

      final qsoQuery = db.select(db.qsos)..where((q) => q.operation.equals(operationUuid));
      if (since > 0) qsoQuery.where((q) => q.updatedAtMillis.isBiggerThanValue(since));
      final qsoRows = await qsoQuery.get();

      if (opRows.isEmpty && qsoRows.isEmpty) return;

      var newWatermark = since;
      void includeInWatermark(int? updatedAtMillis) {
        if (updatedAtMillis != null && updatedAtMillis > newWatermark) newWatermark = updatedAtMillis;
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
          includeInWatermark(row.updatedAtMillis);
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
          includeInWatermark(row.updatedAtMillis);
        }
      });
      // Only if sharing is still on the same operation it was when this scan
      // started — see [_generation]'s doc.
      if (_generation == generation) _watermarkMillis = newWatermark;
      onScanned?.call();
    } finally {
      _scanning = false;
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
