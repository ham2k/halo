// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which scorers an operation gets, and how their per-QSO verdicts merge
// (docs/design/contests.md §5.1). Pure functions over the plain maps that
// cross the bridge, in the package both the app and `halo ext` depend on:
// the CLI is the tool an operator is pointed at when the app's scoring looks
// wrong, so a CLI that selects or merges differently answers a question about
// a program that isn't the one running.
//
// Deliberately free of `halo_core` types — this package's dependency on it is
// declared test-only (see the pubspec) — so segments arrive as the plain ref
// lists they resolve to rather than as a `SegmentedOperation`.

/// One scorer selected for an operation: its hook key, the operation ref that
/// selected it (null for a `fallback` scorer, and for a hunt-only selection),
/// and whether it is the DEFAULT rather than a scorer this operation asked for.
///
/// [fallback] is the priority: wherever another scorer has judged the same QSO
/// on the worked-before axis, a fallback scorer's own judgement of it yields
/// (see [judgesWorkedBefore]), so the entry row states the worked-before rules
/// of whatever the operator is actually doing. Its tallies are kept — they are
/// the operation's QSO count, DXCC and bands, which no contest reports.
typedef Scorer = ({String key, Map<String, dynamic>? ref, bool fallback});

/// The scoring vocabulary that is a judgement about a PRIOR contact — the one
/// axis on which two scorers contradict each other. A station worked at a
/// second park is `newRef` to POTA and `duplicate` to core's call+band+mode
/// rule, and one row cannot say both, so a fallback scorer drops these the
/// moment another scorer has judged the same QSO on this axis.
///
/// Everything else it says stands: `newDXCC`, `newState` and `newProvince` come
/// from core alone, no activity or contest emits them, and they contradict
/// nothing — an activation that silenced them would cost the operator the
/// entity and state pills for the whole operation.
///
/// Both lists state the keys that YIELD rather than the keys that survive: a
/// rule added to core later then keeps its notice by default, where a keep-list
/// would silently swallow it.
///
/// The notices are a VOCABULARY, not a survey of what ships: any scorer whose
/// verdict means "worked before, and this one counts anyway" has to say so in
/// one of these keys, or carry `dupe: false`. A contest that invents its own
/// spelling for it goes unrecognized here, and the row shows that contest's
/// credit beside core's `duplicate` — the contradiction this whole priority
/// exists to end. `newPark` is state-parks' spelling of `newRef`
/// (docs/extensions/hooks.md).
const kWorkedBeforeNotices = {'newBand', 'newMode', 'newDay', 'newRef', 'newPark'};
const kWorkedBeforeAlerts = {'duplicate'};

/// Whether [verdict] says anything about a PRIOR contact — the test that
/// decides whether a fallback scorer's own worked-before judgement yields to
/// it.
///
/// Answering at all is NOT the test, and the difference is a missed duplicate:
/// every contest scorer's validity checks return above its dupe test
/// (`invalidBand`, `invalidCategory`, a VHF test's `missingExchange` — which is
/// every spot candidate, since a spot carries no exchange), and an activity's
/// `judge` returns nothing about a station it has never seen. Each of those is
/// a scorer with no opinion on whether this station was worked before, and
/// core's is then the only one there is.
///
/// `dupe` present — `false` included — is the explicit form: the scorer ran its
/// duplicate test and is reporting what it concluded.
bool judgesWorkedBefore(Map<dynamic, dynamic> verdict) =>
    verdict.containsKey('dupe') ||
    _stringsIn(verdict['alerts']).any(kWorkedBeforeAlerts.contains) ||
    _stringsIn(verdict['notices']).any(kWorkedBeforeNotices.contains);

/// [verdict] with its worked-before judgement taken out: `dupe`, the alerts in
/// [kWorkedBeforeAlerts] and the notices in [kWorkedBeforeNotices]. Null when
/// nothing but empty lists is left, so the caller writes no entry at all rather
/// than an empty one.
///
/// Every OTHER key is copied through, `value` included — the verdict shape is
/// open, and a scorer's point contribution is its own bookkeeping, not a claim
/// about this QSO having been worked before.
Map<String, dynamic>? withoutWorkedBefore(Map<dynamic, dynamic> verdict) {
  final kept = <String, dynamic>{
    for (final entry in verdict.entries)
      if (entry.key is String && entry.key != 'dupe') entry.key as String: entry.value,
  };
  final notices = _stringsIn(verdict['notices']).where((n) => !kWorkedBeforeNotices.contains(n)).toList();
  final alerts = _stringsIn(verdict['alerts']).where((a) => !kWorkedBeforeAlerts.contains(a)).toList();
  notices.isEmpty ? kept.remove('notices') : kept['notices'] = notices;
  alerts.isEmpty ? kept.remove('alerts') : kept['alerts'] = alerts;
  return kept.isEmpty ? null : kept;
}

/// A verdict's `notices`/`alerts`, defensively: a scorer that puts something
/// other than a list of strings there must not take an operation's whole
/// rescore down with a cast error.
List<String> _stringsIn(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

/// The scoring hook keys relevant to an operation, paired with the ref that
/// selected each. An `'always'` scorer maps to a null ref and is flagged
/// [Scorer.fallback]; a ref-gated one is listed once per matching ref TYPE —
/// two refs of one type are ONE invocation, carrying the first, so an operation
/// running two events of the same contest scores only one of them.
///
/// [segmentRefs] is the ref list of each of the operation's segments, resolved
/// from its `break`/`start` overrides. Selection spans EVERY segment: a contest
/// that only covers the back half of a log would never be invoked if this read
/// the base operation alone (docs/design/contests.md §5.1.3). The ref handed
/// back is the first occurrence — the harness re-resolves it per QSO from the
/// segment-effective operation, so a segment that restates its setup still
/// wins. Null means an unsegmented operation, whose own `refs` are read
/// instead.
///
/// [alsoRefTypes] selects a ref-gated scorer the operation itself doesn't name
/// — the ref types found in the LOG and in whatever is being scored. Without it
/// an operation that only HUNTS references (the ordinary POTA chaser, no
/// activation ref) selects no activity scorer at all, so nothing but the core
/// call/band/mode dupe rule applies to it: a station worked at one park reads
/// as a duplicate when spotted at another (docs/design/activities.md §4).
///
/// Matched against the scope's `huntingRefTypes` ONLY, never its `refTypes`. A
/// contest's ref type also rides its QSOs — as exchange data (`{type: 'cqww',
/// theirZone}`) — so matching `refTypes` here would re-select a contest that a
/// `break` has already ended, or one removed from the operation outright, which
/// is precisely what segments exist to prevent.
///
/// Such a scorer is paired with a null ref, like an `'always'` one. There is no
/// operation ref to hand it and none is invented: an activity reads the
/// references it is ACTIVATING off the operation, not off this ref
/// (`activityScoring.ts`'s `activationRefsOf`), so a hunt-only operation
/// correctly earns no activation credit.
///
/// app-polo instead gives every activity a `generalHuntingType` and runs all of
/// them on every operation. That is affordable in-process and is not here: each
/// scorer is a bridge crossing carrying the log. Matching on ref types actually
/// present adds at most one scorer per type hunted, rather than one per
/// installed activity.
List<Scorer> scorersFor(
  Map<String, dynamic> operation,
  Map<String, dynamic> scopes, {
  List<List<Map<String, dynamic>>>? segmentRefs,
  Set<String> alsoRefTypes = const {},
}) {
  final refs = [
    for (final segment in segmentRefs ?? const <List<Map<String, dynamic>>>[]) ...segment,
    if (segmentRefs == null)
      ...((operation['refs'] as List?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((r) => r.cast<String, dynamic>()),
  ];

  final selected = <Scorer>[];
  // Collected apart and appended last so the returned order reads as the
  // priority it is. The merge sites decide on the flag alone — `Future.wait`
  // gives no completion ordering, so position cannot be load-bearing.
  final fallback = <Scorer>[];
  for (final entry in scopes.entries) {
    final scope = entry.value;
    if (scope == 'always') {
      fallback.add((key: entry.key, ref: null, fallback: true));
      continue;
    }
    final refTypes = ((scope is Map ? scope['refTypes'] : null) as List?)?.whereType<String>().toSet();
    if (refTypes == null || refTypes.isEmpty) continue;
    final seen = <String>{};
    for (final ref in refs) {
      final type = ref['type'];
      if (type is! String || !refTypes.contains(type)) continue;
      // One selection per type, however many segments carry it.
      if (seen.add(type)) selected.add((key: entry.key, ref: ref, fallback: false));
    }
    // A scorer the operation names is already selected, with the ref that named
    // it — this only reaches the ones it doesn't, so a hunt-only selection can
    // never displace an activation's own ref.
    final huntingTypes =
        ((scope is Map ? scope['huntingRefTypes'] : null) as List?)?.whereType<String>() ?? const <String>[];
    if (seen.isEmpty && huntingTypes.any(alsoRefTypes.contains)) {
      selected.add((key: entry.key, ref: null, fallback: false));
    }
  }
  return [...selected, ...fallback];
}

/// The reference types on one QSO-shaped map — a candidate being scored, which
/// is not a logged QSO yet (the callsign being typed, a spot).
Set<String> refTypesOf(Map<String, dynamic> qso) => {
      for (final ref in (qso['refs'] as List?) ?? const [])
        if (ref is Map)
          if (ref['type'] case final String type) type,
    };
