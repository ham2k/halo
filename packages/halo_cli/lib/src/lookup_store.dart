// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The offline reference data (park lists, summit lists, callsign notes) that
// backs the `dbLookupSelect*` host calls.
//
// This is halo_core's own database and LookupRepository, not a CLI-shaped
// re-implementation: the schema, the LIKE-based search and the
// squared-distance proximity ordering all decide what an extension sees, and
// a second copy of them would answer differently from the app while looking
// like it agreed.
//
// It is also the one piece of state a halo-ext invocation keeps. Downloading
// 181k summits per run is not an option, so the DATA persists while the
// invocation stays stateless — the same split the app makes.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';

class LookupStore {
  final HaLoDatabase db;
  final LookupRepository repository;
  final File file;

  LookupStore._(this.db, this.repository, this.file);

  /// Opens (creating if needed) the lookup database under [directory].
  ///
  /// [readOnly] callers still get a writable handle — sqlite needs one to
  /// apply the schema — but nothing outside `data-files` writes rows.
  static LookupStore open(String directory) {
    final file = File('$directory/lookups.sqlite');
    file.parent.createSync(recursive: true);
    final db = HaLoDatabase(NativeDatabase(file));
    return LookupStore._(db, LookupRepository(db), file);
  }

  /// True once at least one row exists — the difference between "this
  /// category has nothing matching" and "you have never run `data-files
  /// sync`", which is the mistake every empty POTA result comes from.
  Future<bool> get hasAnyData async {
    final row = await db.customSelect('SELECT EXISTS(SELECT 1 FROM lookups) AS present').getSingle();
    return row.read<int>('present') == 1;
  }

  Future<Map<String, Object?>?> selectOne(String category, String key) async => _toJson(await repository.getLookup(category, key));

  Future<List<Map<String, Object?>>> selectAll(String category, String query, {bool activeOnly = false}) async => [
    for (final row in await repository.queryLookups(category, query, activeOnly: activeOnly)) _toJson(row)!,
  ];

  Future<List<Map<String, Object?>>> selectByLocation(String category, double lat, double lon, double delta, {bool activeOnly = false}) async => [
    for (final row in await repository.queryLookupsByLocation(category, lat, lon, delta, activeOnly: activeOnly)) _toJson(row)!,
  ];

  /// Row counts per category, for `data-files list`.
  Future<Map<String, int>> counts() async {
    final rows = await db.customSelect('SELECT category, COUNT(*) AS n FROM lookups GROUP BY category ORDER BY category').get();
    return {for (final row in rows) row.read<String>('category'): row.read<int>('n')};
  }

  Future<void> close() => db.close();

  /// The wire shape the app's dbLookupSelect* cases produce — `data` decoded
  /// from its stored JSON, everything else verbatim.
  static Map<String, Object?>? _toJson(LookupRow? row) => row == null
      ? null
      : {
          'category': row.category,
          'subCategory': row.subCategory,
          'key': row.key,
          'name': row.name,
          'data': row.data != null ? jsonDecode(row.data!) : null,
          'lat': row.lat,
          'lon': row.lon,
          'flags': row.flags,
        };
}
