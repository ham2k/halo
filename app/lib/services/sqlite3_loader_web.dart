// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:sqlite3/wasm.dart';

Future<WasmSqlite3>? _loaded;

/// The wasm build the app ships for drift (`web/sqlite3.wasm`), loaded on
/// the first `sqlite` data file and kept. A load that failed is not kept:
/// a network blip on the first sync must not fail every later one until
/// the page is reloaded.
Future<WasmSqlite3> _sqlite3() => _loaded ??= WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm')).catchError((Object e, StackTrace stack) {
  _loaded = null;
  Error.throwWithStackTrace(e, stack);
});

/// [readSqliteRows] with a wasm instance of the app's own. On web, where
/// there are no isolates to read on, the read runs on the page's thread and
/// gives it a frame every few thousand rows, so the page keeps painting.
Future<({List<R> rows, int read})> readSqliteFile<R extends Object>(
  Uint8List bytes,
  String query, {
  required String key,
  required R? Function(Map<String, Object?> row) map,
}) async => readSqliteRows(await _sqlite3(), bytes, query, key: key, map: map, pause: () => Future<void>.delayed(Duration.zero));
