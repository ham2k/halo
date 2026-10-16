// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import '../db/database.dart';
import '../models/location_repair.dart';
import '../models/models.dart';
import '../models/qson_values.dart';
import 'operations_repository.dart';
import 'qsos_repository.dart';
import 'repo_support.dart';

/// Why a file is not a QSON operation — what the operator is told, in their
/// language, by the app.
enum QsonImportProblem { notUtf8, notJson, notOperation }

/// A QSON file that does not hold an operation.
class QsonImportException implements Exception {
  final QsonImportProblem problem;

  /// For a log, never for the operator: it is English, and may quote the
  /// parser.
  final String detail;

  const QsonImportException(this.problem, this.detail);

  @override
  String toString() => 'QsonImportException(${problem.name}): $detail';
}

/// Keys a record carries for the device or the server it came from, which
/// say nothing true about a new record on this one.
const _carriedOnlyBySource = {'uuid', 'deleted', 'purged', 'syncedAtMillis'};

/// An operation row's columns and app-polo's in-memory flags, which its dump
/// writes into the operation itself and its own storage strips again
/// (`rowFromOperation`). The counters are recomputed from the contacts this
/// import writes; any of them left in `data` would sync, and outlive the
/// first edit to the log.
const _operationColumns = {'startAtMillisMin', 'startAtMillisMax', 'qsoCount', 'synced', '_useTemplates'};

/// Imports [bytes] — a QSON export, `{operation, qsos}`, as this app's
/// developer export and app-polo's both write it — as a NEW operation, and
/// returns it.
///
/// Everything gets a fresh uuid, the contacts included. A QSO's uuid is the
/// primary key across every operation, so keeping the file's would refuse
/// the whole import whenever the original is on this device — the usual case
/// for a file exported here — and, if it is not, would make the copy the
/// same record as the original the moment sync brought that one in.
///
/// Deleted and purged records are left out: they are tombstones of contacts
/// the original no longer holds.
///
/// One transaction: an operation without its contacts reads as an empty log,
/// and nothing would come back to fill it.
Future<Operation> importQsonOperation({
  required HaLoDatabase db,
  required OperationsRepository operations,
  required QsosRepository qsos,
  required List<int> bytes,
}) async {
  final String text;
  try {
    // Strict: both writers write UTF-8, and a lenient decode would store every
    // accented name in a file saved in another encoding as U+FFFD.
    text = utf8.decode(bytes).replaceFirst(RegExp('^\uFEFF'), '');
  } on FormatException {
    throw const QsonImportException(QsonImportProblem.notUtf8, 'Not UTF-8 text');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw QsonImportException(QsonImportProblem.notJson, 'Not JSON: ${e.message}');
  }
  final operation = decoded is Map ? asQsonMap(decoded['operation']) : null;
  final records = decoded is Map ? decoded['qsos'] : null;
  // Both writers always write `qsos`: a file without it is not an empty
  // operation but a broken one.
  if (operation == null || records is! List) {
    throw const QsonImportException(QsonImportProblem.notOperation, 'Not a QSON operation: expected {operation, qsos}');
  }

  final data = Map<String, dynamic>.from(operation)..removeWhere((key, _) => _carriedOnlyBySource.contains(key) || _operationColumns.contains(key));
  normalizeLegacyStamps(data);
  // A record this app did not write, brought into its shape — the same
  // boundary `mergeFromSync` repairs at (docs/design/locations.md).
  repairStatedLocation(data);
  // `local` is the source device's own, but its operator is what an export
  // names: this app's writes it at the top level as well, app-polo's only
  // here.
  final local = asQsonMap(data.remove('local'));
  final localOperator = asQsonString(local?['operatorCall']);
  // An empty slot is no operator, as app-polo reads it
  // (`local?.operatorCall || operatorCall`).
  if (localOperator != null && localOperator.isNotEmpty && (asQsonString(data['operatorCall']) ?? '').isEmpty) data['operatorCall'] = localOperator;

  final inserts = <Map<String, dynamic>>[];
  for (final record in records) {
    final qso = asQsonMap(record);
    if (qso == null || asQsonBool(qso['deleted']) || qso['purged'] == true) continue;
    final copy = Map<String, dynamic>.from(qso)
      ..removeWhere((key, _) => _carriedOnlyBySource.contains(key))
      ..remove('operation');
    normalizeLegacyStamps(copy);
    // Not normalized here: storage's own normalizer reports a wrong-typed
    // field (`malformed-qson-data`), which is what names a defective writer.
    inserts.add(copy);
  }

  return db.transaction(() async {
    final created = await operations.createFromData(data);
    await qsos.writeBatch(operationUuid: created.uuid, inserts: inserts);
    return (await operations.get(created.uuid))!;
  });
}
