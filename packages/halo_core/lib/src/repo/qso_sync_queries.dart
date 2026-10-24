// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the sync loop and the Sync and Exports panels ask of the log: the
// dirty rows to push next, and the contact counts shown beside the server's.

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/models.dart';
import 'repo_support.dart';

/// Kept beside `QsosRepository`'s writers as a mixin, so the repository
/// stays one class with one `db`.
mixin QsoSyncQueries {
  HaLoDatabase get db;

  /// Up to `limit` dirty QSOs, most recent first — mirrors `sync.js`'s
  /// `queryQSOs("WHERE synced IS false ... ORDER BY startAtMillis DESC")`.
  /// [excluding] holds records back WITHOUT marking them clean — the sync
  /// engine's refusal quarantine (see `SyncEngine.refusalQuarantine`). Skipped
  /// in the query rather than filtered after it: this is a `LIMIT`, so a
  /// refused record that sorts early would otherwise fill the batch every
  /// round and nothing behind it would ever be offered again.
  Future<List<Qso>> unsyncedBatch(int limit, {Set<String> excluding = const {}}) async {
    final query = (db.select(db.qsos)
      ..where((q) => excluding.isEmpty ? q.synced.equals(false) : q.synced.equals(false) & q.uuid.isNotIn(excluding.toList()))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis, mode: OrderingMode.desc)])
      ..limit(limit));
    return (await query.get()).map(qsoFromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row =
        await (db.select(db.qsos)
              ..where((q) => q.synced.equals(false))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// See `QsoHistoryQueries.isContact`.
  Expression<bool> get isContact;

  /// See `OperationsRepository.syncCounts`. `total` applies the same rule
  /// `historyForCall` does — a QSO is gone when its own flag says so or when
  /// its operation's does — so deleting an operation drops its contacts from
  /// the count without touching a single QSO row.
  ///
  /// Event markers (start/break/end, `Qso.isEvent`) are not contacts and are
  /// excluded, the same way [syncCountsForOperation] excludes them: anything
  /// labelled "QSOs" to the operator must mean the number they logged. LoFi's
  /// `QSO.contacts` scope applies the same filter so the two sides stay comparable
  /// in the Sync panel's Synced Data row.
  Future<({int total, int pending})> syncCounts() async {
    final count = db.qsos.uuid.count();

    final totalQuery = db.selectOnly(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
      ..addColumns([count])
      ..where(db.qsos.deleted.equals(false) & isContact & (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
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
    final query = db.selectOnly(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
      ..addColumns([count])
      ..where(db.qsos.synced.equals(false) & db.qsos.deleted.equals(false) & isContact & (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
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
      final result =
          await (db.selectOnly(db.qsos)
                ..addColumns([count])
                ..where(where))
              .getSingle();
      return result.read(count) ?? 0;
    }

    final base = db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false);
    // Not `isContact.not()`: a QSO with no band belongs to neither side under
    // a naive negation, and would vanish from the panel entirely.
    final isEvent = db.qsos.band.equals('event');

    final total = await countWhere(base & isContact);
    final pending = await countWhere(base & isContact & db.qsos.synced.equals(false));
    final eventTotal = await countWhere(base & isEvent);
    final eventPending = await countWhere(base & isEvent & db.qsos.synced.equals(false));

    return (total: total, pending: pending, eventTotal: eventTotal, eventPending: eventPending);
  }
}
