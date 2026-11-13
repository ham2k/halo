// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading a `sqlite` data file. The file is a third party's and the query an
// extension's, so the traps are a query that writes, a second statement
// riding behind the first, and a file that is no database at all — each must
// be refused, never run.

import 'dart:io';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// The rows [query] reads, unmapped.
Future<List<Map<String, Object?>>> _rows(Uint8List bytes, String query) async =>
    (await readSqliteRows(sqlite3, bytes, query, key: 'scp', map: (row) => row)).rows;

void main() {
  late Uint8List bytes;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('scp');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/SCP.DB';
    sqlite3.open(path)
      ..execute('CREATE TABLE callsigns (callsign TEXT PRIMARY KEY, annual_rate INTEGER, modes INTEGER, note BLOB, ratio REAL)')
      ..execute("INSERT INTO callsigns VALUES ('K1AB', 807, 5, x'00ff', 0.5), ('W1AW', 12, 1, NULL, NULL)")
      ..dispose();
    bytes = File(path).readAsBytesSync();
  });

  test('reads what the query selects, by column name, a blob as null', () async {
    final rows = await _rows(bytes, 'SELECT callsign, annual_rate AS rate, note, ratio FROM callsigns ORDER BY callsign');
    expect(rows, [
      {'callsign': 'K1AB', 'rate': 807, 'note': null, 'ratio': 0.5},
      {'callsign': 'W1AW', 'rate': 12, 'note': null, 'ratio': null},
    ]);
  });

  test('refuses a query that writes, a second statement, and a file that is no database', () async {
    await expectLater(_rows(bytes, 'DELETE FROM callsigns'), throwsA(isA<SqliteDataFileUnreadable>()));
    await expectLater(_rows(bytes, 'SELECT callsign FROM callsigns; DELETE FROM callsigns'), throwsA(isA<SqliteDataFileUnreadable>()));
    await expectLater(
      _rows(Uint8List.fromList('MASTER.SCP is text, and so is an error page'.codeUnits), 'SELECT 1'),
      throwsA(isA<SqliteDataFileUnreadable>().having((e) => e.reason, 'reason', 'not a SQLite database')),
      reason: "the download's fault, not the query's",
    );
    await expectLater(_rows(bytes, 'SELECT nothing FROM nowhere'), throwsA(isA<SqliteDataFileUnreadable>()));
  });

  // A publisher that builds its file in WAL mode leaves that in the header,
  // and the in-memory file system has no shared memory for WAL: unpatched,
  // every sync of the file fails on every platform.
  test('reads a file whose header says write-ahead log', () async {
    final dir = Directory.systemTemp.createTempSync('scp-wal');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/SCP.DB';
    sqlite3.open(path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('CREATE TABLE callsigns (callsign TEXT PRIMARY KEY)')
      ..execute("INSERT INTO callsigns VALUES ('K1AB')")
      ..execute('PRAGMA wal_checkpoint(TRUNCATE)')
      ..dispose();
    final wal = File(path).readAsBytesSync();
    expect([wal[18], wal[19]], [2, 2], reason: 'the fixture must be what it claims');
    expect(await _rows(wal, 'SELECT callsign FROM callsigns'), [
      {'callsign': 'K1AB'},
    ]);
  });

  test('an infinity reads as null, since a lookup row\'s data is JSON', () async {
    final dir = Directory.systemTemp.createTempSync('scp-inf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/SCP.DB';
    sqlite3.open(path)
      ..execute('CREATE TABLE t (x REAL)')
      ..execute('INSERT INTO t VALUES (9e999)')
      ..dispose();
    expect(await _rows(File(path).readAsBytesSync(), 'SELECT x FROM t'), [
      {'x': null},
    ]);
  });

  // A download cut short or mangled keeps a good header. Blamed on the query,
  // the extension's author goes looking for a bug in a SELECT that is fine.
  test('a damaged file is blamed on the file, not the query', () async {
    final pageSize = bytes[16] << 8 | bytes[17];
    final damaged = Uint8List.fromList(bytes)..fillRange(pageSize, bytes.length, 0xff);
    await expectLater(
      _rows(damaged, 'SELECT callsign FROM callsigns'),
      throwsA(isA<SqliteDataFileUnreadable>().having((e) => e.reason, 'reason', startsWith('the file is damaged'))),
    );
  });

  test('a database is told from a page answered in its place by its header', () {
    expect(isSqliteFile(bytes), isTrue);
    expect(isSqliteFile(Uint8List.fromList('<html>Sign in to the hotel Wi-Fi</html>'.codeUnits)), isFalse);
  });

  // A recursive query only reads, so nothing else stops one that brings rows
  // without end: natively it would fill memory on an isolate nobody can
  // cancel, and on web it would hold the page.
  test('a query that brings more rows than any reference list stops, refused', () async {
    await expectLater(
      readSqliteRows(
        sqlite3,
        bytes,
        'WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c) SELECT x FROM c',
        key: 'scp',
        map: (row) => row,
        maxRows: 1000,
      ),
      throwsA(isA<SqliteDataFileUnreadable>()),
    );
  });
}
