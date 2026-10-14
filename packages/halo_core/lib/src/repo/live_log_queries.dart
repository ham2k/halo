// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The log as a pass over all of it reads it: the live contacts, a page at a
// time, and which contacts this device holds at all (docs/design/claims.md
// §6).

import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/models.dart';
import 'repo_support.dart';

/// Kept beside `QsosRepository`'s writers as a mixin, so the repository
/// stays one class with one `db`.
mixin LiveLogQueries {
  HaLoDatabase get db;

  /// What counts as the log for a pass over all of it: a contact not
  /// deleted, in no operation or in one that is not deleted. Deleting an
  /// operation leaves its contacts' rows as they were.
  Expression<bool> get _isLive => db.qsos.deleted.equals(false) & (db.operations.deleted.equals(false) | db.operations.uuid.isNull());
  List<Join<HasResultSet, dynamic>> get _withOperation => [leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))];

  /// The live contacts among [uuids] ([_isLive]). One [changes] names but
  /// this leaves out was deleted, or has left the log with its operation,
  /// and that is the change.
  Future<List<Qso>> liveAmong(Iterable<String> uuids) async {
    final list = uuids.toList();
    final rows = <QsoRow>[];
    for (var start = 0; start < list.length; start += inClauseChunkSize) {
      final chunk = list.sublist(start, math.min(start + inClauseChunkSize, list.length));
      final query = db.select(db.qsos).join(_withOperation)..where(_isLive & db.qsos.uuid.isIn(chunk));
      rows.addAll((await query.get()).map((row) => row.readTable(db.qsos)));
    }
    return qsosFromRows(rows);
  }

  /// Every contact [operationUuid] holds, deleted or not.
  Future<List<String>> uuidsInOperation(String operationUuid) async {
    final query = db.selectOnly(db.qsos)
      ..addColumns([db.qsos.uuid])
      ..where(db.qsos.operation.equals(operationUuid));
    return [for (final row in await query.get()) row.read(db.qsos.uuid)!];
  }

  /// Which of [uuids] this device holds a row for, deleted or not. A contact
  /// missing here has not reached this device yet, so nothing here can say
  /// what it claims.
  Future<Set<String>> knownAmong(Iterable<String> uuids) async {
    final list = uuids.toSet().toList();
    final known = <String>{};
    for (var start = 0; start < list.length; start += inClauseChunkSize) {
      final chunk = list.sublist(start, math.min(start + inClauseChunkSize, list.length));
      final query = db.selectOnly(db.qsos)
        ..addColumns([db.qsos.uuid])
        ..where(db.qsos.uuid.isIn(chunk));
      known.addAll([for (final row in await query.get()) row.read(db.qsos.uuid)!]);
    }
    return known;
  }

  /// One page of every live contact in the log ([_isLive]), in uuid order
  /// after [afterUuid] — for a pass over the whole log that must not hold it
  /// all in memory at once.
  Future<List<Qso>> livePage({String? afterUuid, int limit = 500}) async {
    final query = db.select(db.qsos).join(_withOperation)
      ..where(afterUuid == null ? _isLive : _isLive & db.qsos.uuid.isBiggerThanValue(afterUuid))
      ..orderBy([OrderingTerm(expression: db.qsos.uuid)])
      ..limit(limit);
    return qsosFromRows([for (final row in await query.get()) row.readTable(db.qsos)]);
  }

  /// How many contacts [livePage] walks through in all.
  Future<int> liveCount() async {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos).join(_withOperation)
      ..addColumns([count])
      ..where(_isLive);
    return (await query.getSingle()).read(count) ?? 0;
  }
}
