// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Claim records: the claims a chasing program read from an imported file,
// kept in the log as event rows so they sync with it (docs/design/claims.md
// §9).

import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/claims.dart' show claimEventOf;
import '../models/models.dart';
import 'repo_support.dart';

mixin ClaimRecordQueries {
  HaLoDatabase get db;
  Future<int> writeBatch({
    required String operationUuid,
    List<Map<String, dynamic>> inserts,
    List<Qso> updates,
    Map<String, Qso> updateBases,
    bool refreshCounters,
  });
  Future<void> softDelete(Qso qso);
  Future<void> undelete(Qso qso);

  /// [program]'s claim records ([claimEventQson]) read by [importer],
  /// deleted ones included: what a new file of that kind replaces.
  Future<List<Qso>> claimEvents(String program, String importer) async {
    final rows = await (db.select(db.qsos)..where((q) => q.operation.equals('') & q.band.equals('event'))).get();
    return [
      for (final qso in await qsosFromRows(rows))
        if (claimEventOf(qso.data) case final event? when event.program == program && event.importer == importer) qso,
    ];
  }

  /// Makes [records] — the claim records ([claimEventQson]) one file of
  /// [program]'s [importer] makes — the whole of that importer's in the log:
  /// new ones added, changed or deleted ones written again, and those the
  /// file no longer lists deleted. One already as the file says is left
  /// alone, so importing the same file twice syncs nothing. Returns the rows
  /// written.
  Future<int> replaceClaimEvents(String program, String importer, List<Map<String, dynamic>> records) async {
    final held = {for (final qso in await claimEvents(program, importer)) qso.uuid: qso};
    final listed = {for (final record in records) record['uuid'] as String: record};
    String content(Map<String, dynamic> data) => jsonEncode(_sortedKeys({'startAtMillis': data['startAtMillis'], 'event': data['event']}));
    final inserts = <Map<String, dynamic>>[];
    final updates = <Qso>[];
    var written = 0;
    for (final MapEntry(key: uuid, value: record) in listed.entries) {
      final qso = held[uuid];
      if (qso == null) {
        inserts.add(record);
        continue;
      }
      if (qso.deleted) {
        await undelete(qso);
        written++;
      }
      if (content(qso.data) != content(record)) updates.add(Qso(uuid: uuid, operationUuid: '', data: {...qso.data, ...record}));
    }
    written += await writeBatch(operationUuid: '', inserts: inserts, updates: updates);
    for (final qso in held.values) {
      if (qso.deleted || listed.containsKey(qso.uuid)) continue;
      await softDelete(qso);
      written++;
    }
    return written;
  }

  /// [value] with every map's keys in order: a row that came back through a
  /// server can hold the same data in another order.
  static Object? _sortedKeys(Object? value) => switch (value) {
    Map() => {for (final key in value.keys.map((k) => '$k').toList()..sort()) key: _sortedKeys(value[key])},
    List() => [for (final item in value) _sortedKeys(item)],
    _ => value,
  };
}
