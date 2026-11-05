// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Dev-only: what the dev bridge's settings() and sql() calls read from a
// running build. Wired in main.dart, and only there.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/common.dart' show SqliteException;

/// Rows past this are left out of a [devSql] answer, which says so: an
/// unbounded SELECT over the QSO table would otherwise travel whole.
const devSqlRowLimit = 1000;

/// The stored preferences whose key contains [match] (case-insensitively;
/// all of them when it is empty), by key. A value stored as JSON text comes
/// back decoded, so a caller reads one JSON document rather than JSON quoted
/// inside JSON.
Future<Map<String, Object?>> devSettings(String match) async {
  final prefs = await SharedPreferences.getInstance();
  final needle = match.toLowerCase();
  final keys = prefs.getKeys().where((key) => key.toLowerCase().contains(needle)).toList()..sort();
  return {
    'settings': {for (final key in keys) key: _decoded(prefs.get(key))},
  };
}

Object? _decoded(Object? value) {
  if (value is! String || !(value.startsWith('{') || value.startsWith('['))) return value;
  try {
    return jsonDecode(value);
  } on FormatException {
    return value;
  }
}

/// A PRAGMA that sets something — `PRAGMA name = value`, `PRAGMA
/// name(value)`. Its setting lives on the connection, outside any
/// transaction: neither `query_only` nor the rollback undoes it, so the app
/// would run on with it until it restarts.
final _settingPragma = RegExp(r'^\s*PRAGMA\b[^;]*[=(]', caseSensitive: false);

/// A statement that can sit inside `SELECT * FROM (…)`.
final _selecting = RegExp(r'^\s*(SELECT|WITH|VALUES)\b', caseSensitive: false);

/// The `;` that may end a statement, with any `--` comments after it: inside
/// the wrapper it would end the statement before the closing parenthesis.
final _closingSemicolon = RegExp(r';\s*(--[^\n]*\s*)*$');

/// Runs one SQL statement against [db] and answers `{columns, rows,
/// rowCount, truncated}`, or `{error}` when SQLite refuses it. Anything
/// else — a closed database, a dead background isolate — is thrown, for
/// the bridge to log with its stack rather than pass off as bad SQL.
///
/// Read-only twice over: the connection is `query_only` while it runs, so a
/// write fails with SQLite's own "readonly database" error instead of
/// appearing to work, and the transaction around it is always rolled back,
/// so a statement that slips past the pragma still leaves nothing in the
/// file. A PRAGMA that sets something is refused before it runs (see
/// [_settingPragma]). The transaction also holds the app's own queries off
/// the connection while the pragma is on — outside one, a save racing the
/// query would fail.
///
/// A SELECT runs wrapped in `SELECT * FROM (…)`: drift answers each row as a
/// map by column name, which keeps only the last of two columns sharing one
/// (a join's two `uuid`s), while the wrapper makes SQLite name the second
/// `uuid:1`. The closing parenthesis sits on a line of its own so a trailing
/// `--` comment cannot swallow it.
Future<Map<String, Object?>> devSql(GeneratedDatabase db, String query) async {
  if (_settingPragma.hasMatch(query)) {
    return {
      'error':
          "a PRAGMA that sets something stays set on the app's connection after the call, so it is not run. "
          "Read one as `PRAGMA name`, or one that takes an argument as `SELECT * FROM pragma_table_info('qsos')`.",
    };
  }
  final statement = _selecting.hasMatch(query) ? 'SELECT * FROM (\n${query.replaceFirst(_closingSemicolon, '')}\n)' : query;
  late List<QueryRow> rows;
  try {
    await db.transaction(() async {
      await db.customStatement('PRAGMA query_only = ON');
      try {
        rows = await db.customSelect(statement).get();
      } finally {
        await db.customStatement('PRAGMA query_only = OFF');
      }
      throw const _RollBack();
    });
  } on _RollBack {
    // The answer is in hand; the rollback is the point.
  } catch (error) {
    final refused = _sqliteErrorIn(error);
    if (refused == null) rethrow;
    return {'error': '$refused'};
  }
  return {
    'columns': rows.isEmpty ? const <String>[] : rows.first.data.keys.toList(),
    'rows': [
      for (final row in rows.take(devSqlRowLimit)) [for (final value in row.data.values) value is Uint8List ? '<blob, ${value.length} bytes>' : value],
    ],
    'rowCount': rows.length,
    'truncated': rows.length > devSqlRowLimit,
  };
}

/// SQLite's refusal, wherever drift carried it: over the app's background
/// isolate it arrives wrapped, possibly more than once (as in
/// `LogFromNewerBuild.within`).
SqliteException? _sqliteErrorIn(Object error) {
  Object? current = error;
  while (current is DriftRemoteException) {
    current = current.remoteCause;
  }
  return current is SqliteException ? current : null;
}

class _RollBack implements Exception {
  const _RollBack();
}
