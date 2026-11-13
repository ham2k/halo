// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `sqlite` data file: a SQLite database downloaded whole, read with one
// SELECT its definition names (`sqliteQuery`). The file comes from a third
// party, so it is opened read-only, from memory, in a file system holding
// nothing else, and the query must be one statement that writes nothing.

import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:sqlite3/common.dart';

import 'db/database.dart';
import 'ham2k_data_file.dart';

/// A file that is not a SQLite database, or a query it cannot answer.
class SqliteDataFileUnreadable implements Exception {
  final String key;
  final String reason;
  const SqliteDataFileUnreadable(this.key, this.reason);

  @override
  String toString() => 'SqliteDataFileUnreadable($key): $reason';
}

var _opened = 0;

/// Per process, not per isolate: SQLite's file systems are registered
/// process-wide, and natively each file is read on an isolate of its own, all
/// of which start [_opened] at 0. Two reads sharing a name would open through
/// each other's file system, and the first to finish would free it under the
/// other's open connection. A literal bound, not a shift: on the web build
/// `1 << 32` is 0, which `nextInt` refuses.
final _process = Random.secure().nextInt(0x7fffffff);

/// The header every SQLite database starts with.
const _sqliteHeader = 'SQLite format 3\u0000';

/// Whether [bytes] are a SQLite database — not an error page, or a captive
/// portal's sign-in, answered 200 in its place.
bool isSqliteFile(Uint8List bytes) => bytes.length >= _sqliteHeader.length && String.fromCharCodes(bytes.sublist(0, _sqliteHeader.length)) == _sqliteHeader;

/// The most rows one query may bring: several times any reference list a
/// data file holds, and a stop for a query that would bring rows without
/// end — a recursive one is read-only, and the extension's to write. It
/// counts rows brought, not time: a query that runs on without bringing
/// one is not stopped, and this SQLite binding offers no interrupt.
const maxSqliteRows = 2000000;

/// Rows read between [readSqliteRows]'s pauses.
const _rowsBetweenPauses = 2000;

/// [map] of each row [query] selects from the database in [bytes] — a map
/// from column name to value, an int, a double, a String or null — leaving
/// out the rows it maps to null, and how many rows were read. A blob, and a
/// number JSON cannot hold (an infinity), read as null: a lookup row's data
/// is JSON. [pause] runs every few thousand rows, for a caller on the UI's
/// own thread to let it paint.
///
/// [sqlite] is the platform's SQLite — the linked library natively, a
/// wasm instance on web.
Future<({List<R> rows, int read})> readSqliteRows<R extends Object>(
  CommonSqlite3 sqlite,
  Uint8List bytes,
  String query, {
  required String key,
  required R? Function(Map<String, Object?> row) map,
  Future<void> Function()? pause,
  int maxRows = maxSqliteRows,
}) async {
  final vfs = InMemoryFileSystem(name: 'ham2k-data-file-$_process-${++_opened}');
  sqlite.registerVirtualFileSystem(vfs);
  try {
    final file = vfs.xOpen(Sqlite3Filename('/data.db'), SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE).file;
    file.xWrite(_withoutWal(bytes), 0);
    file.xClose();
    final db = sqlite.open('/data.db', vfs: vfs.name, mode: OpenMode.readOnly);
    try {
      // SQLite's own advice for a database from somewhere it cannot trust
      // (sqlite.org/security.html): a corrupt page is caught where it is
      // read, and nothing the file's schema names runs.
      db
        ..execute('PRAGMA cell_size_check = ON')
        ..execute('PRAGMA trusted_schema = OFF');
      final CommonPreparedStatement statement;
      try {
        statement = db.prepare(query, checkNoTail: true);
      } on SqliteException catch (e) {
        throw _unreadable(key, e);
      } on ArgumentError catch (e) {
        throw SqliteDataFileUnreadable(key, 'sqliteQuery must be one statement: ${e.message}');
      }
      try {
        if (!statement.isReadOnly) throw SqliteDataFileUnreadable(key, 'sqliteQuery must only read');
        final cursor = statement.selectCursor();
        final columns = cursor.columnNames;
        final rows = <R>[];
        var read = 0;
        while (cursor.moveNext()) {
          if (++read > maxRows) throw SqliteDataFileUnreadable(key, 'sqliteQuery brought more than $maxRows rows');
          final row = cursor.current;
          final mapped = map({
            for (final column in columns)
              column: switch (row[column]) {
                final int value => value,
                final double value when value.isFinite => value,
                final String value => value,
                // Web's SQLite answers an integer JavaScript cannot hold
                // exactly as a BigInt: its digits, rather than nothing.
                final BigInt value => '$value',
                _ => null,
              },
          });
          if (mapped != null) rows.add(mapped);
          if (pause != null && read % _rowsBetweenPauses == 0) await pause();
        }
        return (rows: rows, read: read);
      } on SqliteException catch (e) {
        throw _unreadable(key, e);
      } finally {
        statement.dispose();
      }
    } finally {
      db.dispose();
    }
  } finally {
    sqlite.unregisterVirtualFileSystem(vfs);
  }
}

/// [e] blamed where it belongs: a file that is no database, or a damaged
/// one, is the download's fault and not the query's. SQLite reads the header
/// lazily and a page only when the query reaches it, so either can fail at
/// the prepare or partway through the rows, never at the open.
SqliteDataFileUnreadable _unreadable(String key, SqliteException e) => switch (e.resultCode) {
  SqlError.SQLITE_NOTADB => SqliteDataFileUnreadable(key, 'not a SQLite database'),
  SqlError.SQLITE_CORRUPT => SqliteDataFileUnreadable(key, 'the file is damaged: ${e.message}'),
  _ => SqliteDataFileUnreadable(key, 'sqliteQuery: ${e.message}'),
};

/// What makes a row of [category] from a row a `sqlite` file's query read,
/// by [fields] — for [readSqliteRows]'s `map`. A key column of numbers
/// reads as their text. Built at the top level, so the function it answers
/// captures only these and may be sent to another isolate.
LookupRow? Function(Map<String, Object?> row) sqliteLookupRow(Ham2kFields fields, {required String category, required int updated}) =>
    (record) => fields.row(record[fields.key] is num ? {...record, fields.key: '${record[fields.key]}'} : record, category: category, updated: updated);

/// Throws when rows were read and none of them had a key: a `fields.key`
/// naming the wrong column, which imported as nothing would stamp the file
/// fresh with its category empty.
void checkSqliteKeys(String key, Ham2kFields fields, {required int read, required int kept}) {
  if (read > 0 && kept == 0) throw SqliteDataFileUnreadable(key, 'no row has a ${fields.key} to key it by');
}

/// The definition's `sqliteQuery` and `fields`, read before anything is
/// downloaded: a definition that names no query, or `fields` without a key,
/// would otherwise fail every sync only after fetching the whole file.
({String query, Ham2kFields? fields}) sqliteDefinition(String key, Map<String, Object?> def) {
  final query = def['sqliteQuery'];
  if (query is! String) throw FormatException('$key: a sqlite data file needs a sqliteQuery');
  final fields = Ham2kFields.fromDefinition(def['fields']);
  if (def['fields'] != null && fields == null) throw FormatException("$key: a sqlite data file's fields need a key column");
  return (query: query, fields: fields);
}

/// [bytes] with the header's journal mode set to a rollback journal when it
/// says write-ahead log: the in-memory file system has none of the shared
/// memory WAL needs, and SQLite would refuse to open the file at all. Only
/// the mode changes; a file read once and thrown away has no log to keep.
Uint8List _withoutWal(Uint8List bytes) {
  if (bytes.length < 20 || (bytes[18] != 2 && bytes[19] != 2)) return bytes;
  return Uint8List.fromList(bytes)
    ..[18] = 1
    ..[19] = 1;
}
