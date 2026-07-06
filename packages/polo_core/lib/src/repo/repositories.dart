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

class OperationsRepository {
  final PoloDatabase db;

  OperationsRepository(this.db);

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
    return operation;
  }

  Stream<List<Operation>> watchAll() {
    // A brand-new operation has no QSOs yet, so startAtMillisMax is NULL.
    // SQLite sorts NULLs last in a DESC ordering by default, which would
    // bury new operations at the end of the list; NullsOrder.first keeps
    // them at the top instead, alongside the most recently active ones.
    final query = (db.select(db.operations)
      ..where((op) => op.deleted.equals(false))
      ..orderBy([
        (op) => OrderingTerm(expression: op.startAtMillisMax, mode: OrderingMode.desc, nulls: NullsOrder.first),
      ]));
    return query.watch().map((rows) => rows.map(_operationFromRow).toList());
  }

  Future<Operation?> get(String uuid) async {
    final row = await (db.select(db.operations)..where((op) => op.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _operationFromRow(row);
  }

  Future<void> saveData(Operation operation) async {
    await (db.update(db.operations)..where((op) => op.uuid.equals(operation.uuid))).write(
      OperationsCompanion(data: Value(jsonEncode(operation.data)), synced: const Value(false)),
    );
  }

  Future<void> softDelete(String uuid) async {
    await (db.update(db.operations)..where((op) => op.uuid.equals(uuid))).write(
      const OperationsCompanion(deleted: Value(true), synced: Value(false)),
    );
  }

  Operation _operationFromRow(OperationRow row) => Operation(
        uuid: row.uuid,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        qsoCount: row.qsoCount,
        startAtMillisMin: row.startAtMillisMin,
        startAtMillisMax: row.startAtMillisMax,
      );
}

class QsosRepository {
  final PoloDatabase db;

  QsosRepository(this.db);

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
    return qso;
  }

  Future<void> update(Qso qso) async {
    await db.transaction(() async {
      await (db.update(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).write(_companionFor(qso));
      await _refreshOperationCounters(qso.operationUuid);
    });
  }

  Future<void> softDelete(Qso qso) async {
    await db.transaction(() async {
      await (db.update(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).write(
        const QsosCompanion(deleted: Value(true), synced: Value(false)),
      );
      await _refreshOperationCounters(qso.operationUuid);
    });
  }

  Stream<List<Qso>> watchForOperation(String operationUuid) {
    final query = (db.select(db.qsos)
      ..where((q) => q.operation.equals(operationUuid) & q.deleted.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]));
    return query.watch().map((rows) => [
          for (final row in rows)
            Qso(
              uuid: row.uuid,
              operationUuid: row.operation,
              data: jsonDecode(row.data) as Map<String, dynamic>,
            ),
        ]);
  }

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
        synced: const Value(false),
      ),
    );
  }
}
