// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:isolate';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// [readSqliteRows] on a background isolate, with the library linked into
/// the app. [map] crosses to it with the file, so it must be sendable: build
/// it at the top level ([sqliteLookupRow]), never as a closure over a
/// caller's state.
Future<({List<R> rows, int read})> readSqliteFile<R extends Object>(
  Uint8List bytes,
  String query, {
  required String key,
  required R? Function(Map<String, Object?> row) map,
}) => Isolate.run(() => readSqliteRows(sqlite3, bytes, query, key: key, map: map));
