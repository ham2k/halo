// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ranking the "add activity" search results.
//
// A pure function, deliberately separate from `ExtensionService`: this is the
// contract extensions are ranked by, and it needs exercising against the shapes
// a hook can return without standing up the JS runtime. Same reasoning as
// `qso_patch.dart`.

/// Whether every hook in [entries] came back with an ERROR — the difference
/// between "nobody had a match" and "nobody could answer", which are the same
/// empty list of suggestions and mean opposite things to the operator.
///
/// False when [entries] is empty: nobody was asked, and a runtime still
/// starting has not failed.
///
/// Answering `null` is NOT failing, and this is the trap. An `activity` hook
/// is free to have no `suggest` method at all — every contest registers one
/// for its setup control and none of them suggests anything — and the kernel
/// reports a missing method as a successful `null`. Requiring a list here
/// would tell an operator running only contests that their search is down, on
/// every keystroke, forever.
bool allActivitySourcesFailed(List<Map<String, dynamic>> entries) => entries.isNotEmpty && entries.every((entry) => entry['ok'] != true);

/// The suggestions carried by [entries] — one `{key, ok, value}` per activity
/// hook, the shape `invokeHookAll` returns — in the order the picker should
/// show them.
///
/// The [preferredKeys] hooks' own suggestions form a band ahead of everyone
/// else's, each band ranked among itself by [rankActivitySuggestions]. Naming
/// a type in the search box says WHICH extensions hold the answer, so a
/// nearer hit from another one must not push their results down the list.
///
/// An entry that failed, or answered with anything but a list, contributes
/// nothing: one broken hook never costs the others their results.
List<Map<String, dynamic>> mergeActivitySuggestions(List<Map<String, dynamic>> entries, {Set<String> preferredKeys = const {}}) {
  final preferred = <Map<String, dynamic>>[];
  final others = <Map<String, dynamic>>[];
  for (final entry in entries) {
    if (entry['ok'] != true || entry['value'] is! List) continue;
    final band = preferredKeys.contains(entry['key']) ? preferred : others;
    band.addAll((entry['value'] as List).cast<Map<dynamic, dynamic>>().map((s) => s.cast<String, dynamic>()));
  }
  return [...rankActivitySuggestions(preferred), ...rankActivitySuggestions(others)];
}

/// [suggestions] in the order the activity picker should show them.
///
/// TWO BANDS. Anything carrying a `distance` sorts first, by
/// `distance / relevance` — a more relevant hit counts as closer, so it doesn't
/// lose to a nearer but less relevant one. Everything else sorts after, by
/// DESCENDING `relevance`.
///
/// The second band is the part worth explaining. Ranking every distance-less
/// suggestion equal — e.g. returning `infinity` for all of them — throws away
/// `relevance`, which for those results is the ONLY ranking signal there is.
/// Not hypothetical: POTA always sets `relevance` and sets `distance`
/// only when a location is known, so a park search run with no operation grid
/// and no GPS would discard `relevanceForMatch` entirely and return rows in raw
/// database order — an exact code match no more likely to be first than a
/// substring hit.
///
/// And past a point it is worse than unordered. With every comparison returning
/// 0, `List.sort` stops preserving input order once it leaves insertion sort,
/// measured at exactly 34 entries; POTA and SOTA only escape by capping at 30.
/// Ties therefore break on emission order EXPLICITLY, rather than trusting the
/// sort to be stable, so an extension's own ordering survives.
///
/// Neither the input list nor its maps are mutated.
List<Map<String, dynamic>> rankActivitySuggestions(List<Map<String, dynamic>> suggestions) {
  final ordered = [for (var i = 0; i < suggestions.length; i++) (index: i, suggestion: suggestions[i])];

  ordered.sort((a, b) {
    final ka = _distanceKey(a.suggestion);
    final kb = _distanceKey(b.suggestion);
    if (ka != null && kb != null) {
      final byKey = ka.compareTo(kb);
      if (byKey != 0) return byKey;
    } else if (ka != null || kb != null) {
      // A located suggestion always outranks one with no location at all.
      return ka != null ? -1 : 1;
    } else {
      final ra = (a.suggestion['relevance'] as num?) ?? 0;
      final rb = (b.suggestion['relevance'] as num?) ?? 0;
      final byRelevance = rb.compareTo(ra);
      if (byRelevance != 0) return byRelevance;
    }
    return a.index.compareTo(b.index);
  });

  return [for (final entry in ordered) entry.suggestion];
}

/// The first band's sort key, or null when this suggestion has no distance.
double? _distanceKey(Map<String, dynamic> suggestion) {
  final distance = suggestion['distance'] as num?;
  if (distance == null) return null;
  final relevance = suggestion['relevance'] as num?;
  // A missing or non-positive relevance is the absence of a signal, not a
  // demotion — distance alone still orders it.
  return relevance != null && relevance > 0 ? distance / relevance : distance.toDouble();
}
