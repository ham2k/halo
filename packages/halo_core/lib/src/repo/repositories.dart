// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Repositories are the only writers to the database. Every write keeps the
// indexed columns derived from the JSON `data`, marks rows dirty for sync
// (`synced = false`), and maintains the operation's cached counters. Reads
// for the UI are reactive drift streams — the database is the source of
// truth and, later, the multi-window bus (DESIGN.md §8).

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../models/models.dart';

const _uuidGenerator = Uuid();

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

  Future<Operation> create({required String stationCall, String title = ''}) async {
    final operation = Operation(
      uuid: _uuidGenerator.v4(),
      data: {
        'stationCall': stationCall.toUpperCase(),
        'title': title,
        'createdAtMillis': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
    );
    await db.into(db.operations).insert(OperationsCompanion.insert(
          uuid: operation.uuid,
          data: Value(jsonEncode(operation.data)),
        ));
    onChange?.call();
    return operation;
  }

  Stream<List<Operation>> watchAll() {
    // We select non-deleted operations. Since we want a robust sorting
    // that uses fields within the JSON data blob (like createdAtMillis)
    // as a fallback for operations with no QSOs, we perform the sort in Dart.
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

  Future<void> saveData(Operation operation) async {
    await (db.update(db.operations)..where((op) => op.uuid.equals(operation.uuid))).write(
      OperationsCompanion(data: Value(jsonEncode(operation.data)), synced: const Value(false)),
    );
    onChange?.call();
  }

  Future<void> softDelete(String uuid) async {
    await (db.update(db.operations)..where((op) => op.uuid.equals(uuid))).write(
      const OperationsCompanion(deleted: Value(true), synced: Value(false)),
    );
    onChange?.call();
  }

  /// Up to `limit` dirty operations, most-recently-active first — the same
  /// selection app-polo's sync loop uses for its "large batch" round
  /// (`sync.js`'s `queryOperations('WHERE synced IS false ...')`).
  Future<List<Operation>> unsyncedBatch(int limit) async {
    final query = (db.select(db.operations)
      ..where((op) => op.synced.equals(false))
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

  Future<void> markSynced(Iterable<String> uuids) async {
    if (uuids.isEmpty) return;
    await (db.update(db.operations)..where((op) => op.uuid.isIn(uuids))).write(
      const OperationsCompanion(synced: Value(true)),
    );
  }

  /// Total and pending-sync counts, reported in the sync payload's `meta`
  /// (mirrors `getSyncCounts()` in app-polo's `sync.js`).
  Future<({int total, int pending})> syncCounts() async {
    final total = db.operations.uuid.count();
    final query = db.selectOnly(db.operations)..addColumns([total]);
    final totalCount = (await query.getSingle()).read(total) ?? 0;
    final pendingCount = (await (db.selectOnly(db.operations)
              ..addColumns([total])
              ..where(db.operations.synced.equals(false)))
            .getSingle())
        .read(total) ?? 0;
    return (total: totalCount, pending: pendingCount);
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
    for (final incoming in operations) {
      final uuid = incoming['uuid'] as String?;
      if (uuid == null) continue;
      final data = Map<String, dynamic>.from(incoming)..remove('uuid');
      final deleted = data.remove('deleted') == true;
      watermark.include((data['syncedAtMillis'] as num?)?.toInt());
      await db.into(db.operations).insertOnConflictUpdate(OperationsCompanion(
            uuid: Value(uuid),
            data: Value(jsonEncode(data)),
            deleted: Value(deleted),
            synced: const Value(true),
          ));
    }
    // No onChange() here: everything just written is already marked
    // synced, so there's nothing new for the outbound side to react to.
    return watermark;
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
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
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

  Operation _operationFromRow(OperationRow row) => Operation(
        uuid: row.uuid,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        qsoCount: row.qsoCount,
        startAtMillisMin: row.startAtMillisMin,
        startAtMillisMax: row.startAtMillisMax,
        deleted: row.deleted,
      );
}

class QsosRepository {
  final HaLoDatabase db;

  /// See `OperationsRepository.onChange`.
  final void Function()? onChange;

  QsosRepository(this.db, {this.onChange});

  /// Inserts a QSO from QSON data, deriving the indexed columns and
  /// refreshing the operation's counters, all in one transaction.
  Future<Qso> add(String operationUuid, Map<String, dynamic> qsoData) async {
    final data = Map<String, dynamic>.from(qsoData);
    data['startAtMillis'] ??= DateTime.now().toUtc().millisecondsSinceEpoch;
    data['uuid'] ??= _uuidGenerator.v4();

    final qso = Qso(uuid: data['uuid'] as String, operationUuid: operationUuid, data: data);

    await db.transaction(() async {
      await db.into(db.qsos).insert(_companionFor(qso));
      await _refreshOperationCounters(operationUuid);
    });
    onChange?.call();
    return qso;
  }

  Future<void> update(Qso qso) async {
    await db.transaction(() async {
      await (db.update(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).write(_companionFor(qso));
      await _refreshOperationCounters(qso.operationUuid);
    });
    onChange?.call();
  }

  Future<void> softDelete(Qso qso) async {
    await db.transaction(() async {
      await (db.update(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).write(
        const QsosCompanion(deleted: Value(true), synced: Value(false)),
      );
      await _refreshOperationCounters(qso.operationUuid);
    });
    onChange?.call();
  }

  Stream<List<Qso>> watchForOperation(String operationUuid) {
    final query = (db.select(db.qsos)
      ..where((q) => q.operation.equals(operationUuid) & q.deleted.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]));
    return query.watch().map((rows) => rows.map(_qsoFromRow).toList());
  }

  /// Up to `limit` dirty QSOs, most recent first — mirrors `sync.js`'s
  /// `queryQSOs("WHERE synced IS false ... ORDER BY startAtMillis DESC")`.
  Future<List<Qso>> unsyncedBatch(int limit) async {
    final query = (db.select(db.qsos)
      ..where((q) => q.synced.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis, mode: OrderingMode.desc)])
      ..limit(limit));
    return (await query.get()).map(_qsoFromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row = await (db.select(db.qsos)..where((q) => q.synced.equals(false))..limit(1)).getSingleOrNull();
    return row != null;
  }

  Future<void> markSynced(Iterable<String> uuids) async {
    if (uuids.isEmpty) return;
    await (db.update(db.qsos)..where((q) => q.uuid.isIn(uuids))).write(const QsosCompanion(synced: Value(true)));
  }

  /// See `OperationsRepository.syncCounts`.
  Future<({int total, int pending})> syncCounts() async {
    final total = db.qsos.uuid.count();
    final totalCount = (await (db.selectOnly(db.qsos)..addColumns([total])).getSingle()).read(total) ?? 0;
    final pendingCount = (await (db.selectOnly(db.qsos)
              ..addColumns([total])
              ..where(db.qsos.synced.equals(false)))
            .getSingle())
        .read(total) ?? 0;
    return (total: totalCount, pending: pendingCount);
  }

  /// Upserts QSOs received from the sync server and refreshes the counters
  /// of every operation they belong to. See `OperationsRepository.mergeFromSync`
  /// for the returned watermark's purpose.
  Future<SyncWatermark> mergeFromSync(List<Map<String, dynamic>> qsos) async {
    final watermark = SyncWatermark();
    final affectedOperations = <String>{};
    await db.transaction(() async {
      for (final incoming in qsos) {
        final uuid = incoming['uuid'] as String?;
        final operationUuid = incoming['operation'] as String?;
        if (uuid == null || operationUuid == null) continue;

        final data = Map<String, dynamic>.from(incoming)..remove('operation');
        final deleted = data.remove('deleted') == true;
        watermark.include((data['syncedAtMillis'] as num?)?.toInt());
        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);

        await db.into(db.qsos).insertOnConflictUpdate(
              _companionFor(qso).copyWith(synced: const Value(true), deleted: Value(deleted)),
            );
        affectedOperations.add(operationUuid);
      }
      for (final operationUuid in affectedOperations) {
        await _refreshOperationCounters(operationUuid);
      }
    });
    // No onChange() here — see OperationsRepository.mergeFromSync.
    return watermark;
  }

  /// See `OperationsRepository.resetSyncedStatus`.
  Future<void> resetSyncedStatus() async {
    await db.update(db.qsos).write(const QsosCompanion(synced: Value(false)));
  }

  /// See `OperationsRepository.backupAndClearAll`.
  Future<void> backupAndClearAll(String backupId) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
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
  }

  Qso _qsoFromRow(QsoRow row) => Qso(
        uuid: row.uuid,
        operationUuid: row.operation,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        deleted: row.deleted,
      );

  QsosCompanion _companionFor(Qso qso) => QsosCompanion(
        uuid: Value(qso.uuid),
        operation: Value(qso.operationUuid),
        ourCall: Value(qso.ourCall),
        theirCall: Value(qso.theirCall),
        band: Value(qso.band),
        mode: Value(qso.mode),
        startAtMillis: Value(qso.startAtMillis),
        data: Value(jsonEncode(qso.data)),
        synced: const Value(false),
      );

  /// `qsoCount`/`startAtMillisMin/Max` are a locally derived cache — never
  /// part of the JSON payload sync sends (see `SyncEngine._buildPayload`) —
  /// so refreshing them must not flip `synced` back to false. Doing so
  /// would make an operation perpetually "dirty" any time its QSOs change,
  /// even after a round already sent its actual (unchanged) content.
  Future<void> _refreshOperationCounters(String operationUuid) async {
    final count = db.qsos.uuid.count();
    final minStart = db.qsos.startAtMillis.min();
    final maxStart = db.qsos.startAtMillis.max();
    final query = db.selectOnly(db.qsos)
      ..addColumns([count, minStart, maxStart])
      ..where(db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false));
    final row = await query.getSingle();

    await (db.update(db.operations)..where((op) => op.uuid.equals(operationUuid))).write(
      OperationsCompanion(
        qsoCount: Value(row.read(count) ?? 0),
        startAtMillisMin: Value(row.read(minStart)),
        startAtMillisMax: Value(row.read(maxStart)),
      ),
    );
  }
}
