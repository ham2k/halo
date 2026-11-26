// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two steps of DataFileManager.processDataFile that are particular to a
// `sqlite` data file (see halo_core's sqlite_data_file.dart): a SQLite
// database downloaded whole — Super Check Partial's SCP.DB is one — and read
// with the definition's `sqliteQuery`. Everything around them, the notices,
// the ETag kept or dropped, a restart cutting a mapper's import, is the
// manager's, as for any data file.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'data_file_manager.dart';
import 'error_reporting_service.dart';
import 'extensions/extension_requests.dart';
import 'sqlite3_loader.dart';

/// The database at [url], or null when the one held is current. The
/// definition is read first ([sqliteDefinition]): one that names no query
/// would otherwise fail every sync only after fetching the whole file.
/// Something other than a database answered 200 — an error page, a captive
/// portal's sign-in — fails the DOWNLOAD, the network's fault and not the
/// data's, and takes the ETag the download stored with it.
Future<Uint8List?> downloadSqliteFile(
  DataFileManager manager,
  String key,
  Map<String, dynamic> def,
  String url, {
  required bool force,
  ExtensionNetworkGrant? grant,
  String? userAgent,
}) async {
  sqliteDefinition(key, def);
  final bytes = await manager.downloadBytes(key, url, force: force, grant: grant, userAgent: userAgent);
  if (bytes == null || isSqliteFile(bytes)) return bytes;
  await manager.prefs.remove('data_file_etag_$key');
  throw DataFileNotADatabase(key, Uri.tryParse(url)?.host ?? url);
}

/// Each row as the query read it, for the extension's mapper. Top level, so
/// it can be sent to the isolate the file is read on.
Map<String, Object?>? _asIs(Map<String, Object?> row) => row;

/// Reads [bytes] with the definition's `sqliteQuery` into its category. With
/// `fields` the rows land as they name, built where the file is read (a
/// background isolate natively), and never reach the extension runtime;
/// without, each row goes to the extension's `jsonToLookupEntry` through
/// [mapRows], as a JSON file's entries do.
Future<void> processSqliteFile(
  DataFileManager manager,
  String key,
  Map<String, dynamic> def,
  Uint8List bytes, {
  required String label,
  required bool force,
  required bool showProgress,
  required Future<void> Function(String category, List<Map<String, Object?>> rows) mapRows,
}) async {
  final (:query, :fields) = sqliteDefinition(key, def);
  final category = def['category'] as String? ?? key;
  if (fields == null) {
    final read = await readSqliteFile(bytes, query, key: key, map: _asIs);
    return mapRows(category, read.rows);
  }

  final updated = nowMillis();
  final read = await readSqliteFile(
    bytes,
    query,
    key: key,
    map: sqliteLookupRow(fields, category: category, updated: updated),
  );
  final rows = read.rows;
  checkSqliteKeys(key, fields, read: read.read, kept: rows.length);
  final bar = showProgress ? manager.statusBar : null;
  final statusKey = 'dataFile:$key';
  final shrank = await replaceCategoryRows(
    manager.lookups,
    key,
    category,
    rows,
    updated: updated,
    force: force,
    onRows: (written) => bar?.setProgress(
      key: statusKey,
      title: label,
      text: t.dataFiles.recordsProgress(end: written, total: rows.length),
      value: rows.isEmpty ? 1.0 : written / rows.length,
    ),
  );
  if (shrank != null) ErrorReportingService.report(shrank, StackTrace.current, context: 'data-files:forced-shrink');
  bar?.setProgress(
    key: statusKey,
    title: label,
    text: t.dataFiles.importedRecords(count: rows.length, label: label),
    value: 1.0,
  );
}
