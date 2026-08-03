// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reading `operations.local_data.scoring`, which is keyed by SCORER
// (docs/design/contests.md §5.1):
//
//   {core: {daySections, operationSummary, scoresheet}, cqww: {…}}
//
// An older cached blob can still hold the flat pre-scorer-keyed shape
// (`{daySections, operationSummary}` at the top level), so a consumer that
// indexes directly reads null and silently renders nothing. These helpers
// are the one place that shape is understood.

/// Scorer keys in display order: `core` first (dupes/DXCC/bands are the
/// baseline every operation has), then the rest alphabetically. The scorers
/// themselves arrive via `invokeHookAll`, which guarantees no ordering, so
/// without this the badge order would drift between runs.
List<String> orderedScorerKeys(Map<String, dynamic>? scoring) {
  final keys = (scoring ?? const {}).keys.toList()..sort();
  keys.remove('core');
  return ['core', ...keys].where((k) => (scoring ?? const {}).containsKey(k)).toList();
}

/// One scorer's entry, or null if this key holds something else.
///
/// The `is Map` test rather than a cast is load-bearing: a device carrying a
/// cached blob from before the per-scorer nesting has `daySections` (a List)
/// sitting at the top level, and casting that to Map throws — taking the
/// logging panel down until the next rescore overwrites it. Scores are
/// regenerable, so the right behaviour is to render nothing and move on.
Map<String, dynamic>? _scorerEntry(Map<String, dynamic>? scoring, String scorerKey) {
  final entry = (scoring ?? const {})[scorerKey];
  return entry is Map ? entry.cast<String, dynamic>() : null;
}

/// One scorer's `operationSummary` — the tallies it wants shown for the whole
/// operation, keyed by that scorer's own tally keys.
Map<String, dynamic>? operationSummaryFor(Map<String, dynamic>? scoring, String scorerKey) {
  final summary = _scorerEntry(scoring, scorerKey)?['operationSummary'];
  return summary is Map ? summary.cast<String, dynamic>() : null;
}

/// Every scorer's day sections folded into the single day-keyed list `QsoList`
/// expects, so one day header can carry core's QSO count *and* a contest's
/// points.
///
/// Tally keys are namespaced `<scorerKey>.<tallyKey>`: two contests both
/// emitting a tally called `contest` (simple-contest does) would otherwise
/// silently overwrite each other. Consumers must therefore key off each
/// tally's own `key` field rather than its position in this map.
List<Map<String, dynamic>> mergedDaySections(Map<String, dynamic>? scoring) {
  final byDay = <int, Map<String, dynamic>>{};

  for (final scorerKey in orderedScorerKeys(scoring)) {
    final raw = _scorerEntry(scoring, scorerKey)?['daySections'];
    final sections = raw is List ? raw : const [];
    for (final section in sections.whereType<Map>()) {
      final day = (section['day'] as num?)?.toInt();
      if (day == null) continue;
      final bucket = byDay.putIfAbsent(day, () => {'day': day, 'scores': <String, dynamic>{}});
      final scores = bucket['scores'] as Map<String, dynamic>;
      for (final tally in ((section['scores'] as Map?) ?? const {}).entries) {
        scores['$scorerKey.${tally.key}'] = tally.value;
      }
    }
  }

  return byDay.values.toList()..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
}
