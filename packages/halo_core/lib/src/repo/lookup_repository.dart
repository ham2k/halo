// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `lookups` table: extension-namespaced reference datasets, searched by
// name and by position. The contract every repository keeps is stated in
// repo_support.dart.

import 'package:drift/drift.dart';

import '../db/database.dart';

/// Escapes SQLite LIKE metacharacters (`%`, `_`) in [input] so a search term
/// containing either is matched literally rather than as a wildcard —
/// pass `escapeChar: r'\'` on every `.like()` built from the result.
String _escapeLikePattern(String input) => input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

class LookupRepository {
  final HaLoDatabase db;

  LookupRepository(this.db);

  /// Performs a bulk insert or replace of lookup rows inside a single transaction.
  Future<void> insertLookupBatch(List<LookupRow> rows) async {
    await db.transaction(() async {
      await db.batch((batch) {
        for (final row in rows) {
          batch.insert(db.lookups, row, mode: InsertMode.insertOrReplace);
        }
      });
    });
  }

  /// Deletes all lookups within a specific category.
  Future<void> deleteCategory(String category) async {
    await (db.delete(db.lookups)..where((l) => l.category.equals(category))).go();
  }

  /// Deletes all lookups in a category that do not have the specified updated flag value (stale data).
  Future<void> deleteCategoryStale(String category, int updatedValue) async {
    await (db.delete(db.lookups)..where((l) => l.category.equals(category) & l.updated.equals(updatedValue).not())).go();
  }

  /// Retrieves a single lookup row by category and key.
  Future<LookupRow?> getLookup(String category, String key) async {
    return await (db.select(db.lookups)..where((l) => l.category.equals(category) & l.key.equals(key))).getSingleOrNull();
  }

  /// A row this program has NOT retired: `flags` 0 is the one value that means
  /// retired, which every activity's data-file mapper writes for a reference
  /// its program has delisted.
  ///
  /// The null arm is load-bearing, not defensive. `flags` is nullable and most
  /// mappers never set it, and SQL's `flags != 0` is NULL — therefore false —
  /// for those rows, so the obvious predicate would silently hide every lookup
  /// row that simply never said. Unknown is not retired.
  Expression<bool> _notRetired($LookupsTable l) => l.flags.isNull() | l.flags.equals(0).not();

  /// Searches lookups in a category by matching query prefix on key or name.
  ///
  /// [subCategory], when given, filters IN THIS QUERY rather than left to the
  /// caller: a common word ("trail") can match thousands of rows worldwide,
  /// and this query only returns the first 100 it finds. A caller that
  /// narrows by country AFTER fetching (POTA's `suggest` hook, scoping to the
  /// operator's own DXCC entity) can end up filtering an already-truncated
  /// 100 down to nothing even though a real match exists — "Appalachian
  /// Trail National Scenic Trail" searched as "trail" is exactly this:
  /// plenty of non-US "trail" rows fill the cap before SQLite (with no ORDER
  /// BY) happens to reach it. Filtering here means the limit applies to the
  /// already-narrowed set instead. Exact-equals only — SOTA scopes by entity
  /// too but needs a prefix match, so it still filters after fetching and
  /// still has this bug (extensions/activities/sota/src/index.ts).
  ///
  /// Key-prefix and name-prefix hits are also ordered first, for the rest —
  /// the ones a [relevanceForMatch]-style ranking would call most relevant —
  /// so those are what a full 100 rows displaces last.
  ///
  /// [activeOnly] drops rows a program has RETIRED, and belongs in the query
  /// for the same reason [subCategory] does. POTA keeps a retired park in its
  /// parks file rather than dropping it, so retirements arrive in bulk and
  /// CLUSTER: a program delists a whole class of reference at once, and a
  /// search for a word those share ("Wildlife Management Area" in an entity
  /// whose WMAs were swept) can fill all 100 rows with retired ones. Filtered
  /// afterward, in the caller, that search returns almost nothing while the
  /// active matches sit just past the cap.
  ///
  /// [query] is escaped via [_escapeLikePattern] before it's built into any
  /// pattern — a literal `%` or `_` in a searched name (e.g. a park with one
  /// in its title) would otherwise be read as a SQL wildcard instead of the
  /// character it is.
  Future<List<LookupRow>> queryLookups(String category, String query, {String? subCategory, bool activeOnly = false}) async {
    final escaped = _escapeLikePattern(query);
    final keyPrefixMatch = db.lookups.key.like('$escaped%', escapeChar: r'\');
    final namePrefixMatch = db.lookups.name.like('$escaped%', escapeChar: r'\');
    return await (db.select(db.lookups)
          ..where(
            (l) =>
                l.category.equals(category) &
                (l.key.like('%$escaped%', escapeChar: r'\') | l.name.like('%$escaped%', escapeChar: r'\')) &
                (subCategory == null ? const Constant(true) : l.subCategory.equals(subCategory)) &
                (activeOnly ? _notRetired(l) : const Constant(true)),
          )
          ..orderBy([
            (l) => OrderingTerm(expression: keyPrefixMatch, mode: OrderingMode.desc),
            (l) => OrderingTerm(expression: namePrefixMatch, mode: OrderingMode.desc),
          ])
          ..limit(100))
        .get();
  }

  /// Searches lookups in a category by proximity to a lat/lon coordinate
  /// within a delta, closest first. Ordering (by squared distance, cheaper
  /// than a real Haversine and fine for ranking within this small bounding
  /// box) has to happen before the `limit` — otherwise the cap keeps
  /// whichever 100 rows the query planner happens to hit first rather than
  /// the 100 actually nearest to the caller, and a close-by entry can be
  /// dropped in favor of farther ones.
  ///
  /// [activeOnly] as in [queryLookups] — and for the same reason it precedes
  /// the `limit` here too, since a swept class of reference is as likely to
  /// be clustered in SPACE as in name.
  Future<List<LookupRow>> queryLookupsByLocation(String category, double lat, double lon, double delta, {bool activeOnly = false}) async {
    final latDelta = db.lookups.lat - Variable(lat);
    final lonDelta = db.lookups.lon - Variable(lon);
    final distanceSquared = latDelta * latDelta + lonDelta * lonDelta;
    return await (db.select(db.lookups)
          ..where(
            (l) =>
                l.category.equals(category) &
                l.lat.isBetweenValues(lat - delta, lat + delta) &
                l.lon.isBetweenValues(lon - delta, lon + delta) &
                (activeOnly ? _notRetired(l) : const Constant(true)),
          )
          ..orderBy([(l) => OrderingTerm.asc(distanceSquared)])
          ..limit(100))
        .get();
  }
}
