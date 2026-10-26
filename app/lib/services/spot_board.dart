// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The spots board as data: how fetched spots are combined, filtered and
// judged, apart from any widget. The Spots Panel draws it, and the
// `getSpots` host call hands the same board to extensions — one copy of the
// rules, so an extension's panel and the operator's own can never disagree
// about which spots the operator's filters admit or which are worked.

import 'dart:math' as math;

import 'package:collection/collection.dart' show mergeSort;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show controlForRef, refCodeOf;

import 'settings_service.dart';
import 'spots_service.dart';

// Probes, not casts — see the note over spots_panel.dart's own readers.
String? _callOf(Map<String, dynamic> spot) => asSpotString(asSpotMap(spot['their'])?['call']);
double? _freqOf(Map<String, dynamic> spot) => asSpotNum(spot['freq'])?.toDouble();
String? _bandOf(Map<String, dynamic> spot) => asSpotString(spot['band']);
String? _modeOf(Map<String, dynamic> spot) => asSpotString(spot['mode']);
List<Map<String, dynamic>> _refsOf(Map<String, dynamic> spot) {
  final refs = spot['refs'];
  if (refs is! List) return const [];
  return [
    for (final ref in refs)
      if (ref is Map) ref.cast<String, dynamic>(),
  ];
}

int _timeOf(Map<String, dynamic> spot) => asSpotNum(asSpotMap(spot['spot'])?['timeInMillis'])?.toInt() ?? 0;

/// The individual operator callsigns within a `their.call`: a comma-joined
/// compound for a spot [mergeSpotsByFreqAndRefs] combined, a single call
/// otherwise — trimmed and uppercased, with empty segments dropped. The ONE
/// reading of that field: everything keyed per call (call info, scoring
/// candidates, continents, the panel's worked overrides) iterates these, and
/// a second splitter normalising differently would key the same operator two
/// ways.
Iterable<String> spotCallsIn(String? call) => (call ?? '').split(',').map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty);

/// [spotCallsIn] for [spot]'s `their.call`.
Iterable<String> spotOperatorCalls(Map<String, dynamic> spot) => spotCallsIn(_callOf(spot));

/// Modes excluded from the callsign-merge pass (SpotsPanel.jsx: too many
/// simultaneous operators on one frequency to safely merge callsigns). A
/// narrower set than the "Digital" super mode ([superModeForMode]) — it's only
/// about which modes are unsafe to merge, not the mode filter's grouping.
const _digitalModes = {'FT8', 'FT4', 'RTTY', 'DATA'};

/// The ages the Spots Panel's filter offers. The last is the widest the board
/// ever shows, and matches [SpotsService.maxSpotAge].
const spotAgeOptionsInMinutes = [15, 30, 60, _widestSpotAgeMinutes];
const _widestSpotAgeMinutes = 180;

bool _isDigital(String? mode) => mode != null && _digitalModes.contains(mode.toUpperCase());

/// The three "super modes" ([superModeForMode]) the mode filter groups spots
/// by, in the order the dropdown offers them.
const spotSuperModes = ['Phone', 'CW', 'Digital'];

/// The combined "Phone & CW" filter option: everything but Digital. A filter
/// value, not a super mode — [superModeForMode] never returns it, so it
/// needs its own branch wherever a filter value is resolved or counted.
const phoneCwModeFilter = 'phoneCw';

/// The super modes [phoneCwModeFilter] admits.
const phoneCwSuperModes = {'Phone', 'CW'};

/// Migrates a persisted mode filter from the retired per-mode/`notDigital`
/// scheme to the super-mode scheme: 'auto'/'any', the super modes and
/// [phoneCwModeFilter] pass through, the retired 'notDigital' becomes
/// [phoneCwModeFilter] (the same intent), and anything else is read as an
/// individual mode ('SSB', 'FT8', …) and maps to its super mode — which,
/// as [superModeForMode] works, makes any unrecognised string 'Digital'.
/// Public for unit testing.
String normalizeModeFilter(String value) {
  if (value == 'auto' || value == 'any' || value == phoneCwModeFilter || spotSuperModes.contains(value)) return value;
  if (value == 'notDigital') return phoneCwModeFilter;
  return superModeForMode(value) ?? 'auto';
}

/// The super modes a mode filter admits, or null for no narrowing: 'auto'
/// follows the VFO's current super mode (no narrowing while the VFO has no
/// mode), 'any' never narrows, [phoneCwModeFilter] admits Phone and CW,
/// and a super mode admits itself. Public for unit testing.
Set<String>? superModesForModeFilter(String filter, String? vfoMode) => switch (filter) {
  'auto' => switch (superModeForMode(vfoMode)) {
    final m? => {m},
    null => null,
  },
  'any' => null,
  phoneCwModeFilter => phoneCwSuperModes,
  final m => {m},
};

/// The `groupByBand` value to assume for a persisted filter map that
/// predates that setting — from when time-sorting alone implied a flat
/// list. Infers the grouping that old shape meant rather than defaulting
/// every such map straight to grouped. Public for unit testing.
bool defaultGroupByBand(String sortBy) => sortBy != 'time';

/// Pass 1: same callsign, close in frequency (0.5kHz) and time (30min) —
/// merge the second spot's refs into the first instead of listing it again.
/// Public (not `_`-prefixed) so `app/test/spots/spots_panel_merge_test.dart` can
/// exercise this pure logic directly.
List<Map<String, dynamic>> mergeSpotsByCallAndFreq(List<Map<String, dynamic>> spots) {
  final sorted = [...spots]..sort((a, b) => _timeOf(b).compareTo(_timeOf(a)));
  final byCall = <String, Map<String, dynamic>>{};
  final merged = <Map<String, dynamic>>[];
  for (final spot in sorted) {
    final call = _callOf(spot);
    if (call == null) {
      // Copy, like the merged-copy branch below — `spot` is the same Map
      // instance held in `SpotsService`'s lists; if this object were later chosen
      // as a merge target in the second pass, mutating it in place would
      // corrupt the shared cache every reader of it sees.
      merged.add({
        ...spot,
        'refs': [..._refsOf(spot)],
      });
      continue;
    }
    final existing = byCall[call];
    final freq = _freqOf(spot);
    final existingFreq = existing == null ? null : _freqOf(existing);
    final closeEnough =
        existing != null &&
        freq != null &&
        existingFreq != null &&
        (freq - existingFreq).abs() <= 0.5 &&
        (_timeOf(spot) - _timeOf(existing)).abs() <= 30 * 60 * 1000;
    if (!closeEnough) {
      final copy = {
        ...spot,
        'refs': [..._refsOf(spot)],
      };
      byCall[call] = copy;
      merged.add(copy);
    } else {
      final existingRefs = existing['refs'] as List<Map<String, dynamic>>;
      for (final ref in _refsOf(spot)) {
        final dup = existingRefs.any((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
        if (!dup) existingRefs.add(ref);
      }
    }
  }
  return merged;
}

/// The DXCC entity every operator on [spot] resolves to through [entityOf],
/// or null when any of them is unknown or they disagree.
String? _entityOfSpot(Map<String, dynamic> spot, String? Function(String call) entityOf) {
  String? entity;
  for (final call in spotOperatorCalls(spot)) {
    final e = entityOf(call);
    if (e == null || (entity != null && e != entity)) return null;
    entity = e;
  }
  return entity;
}

/// Pass 2: same frequency (0.1kHz) and time (10min), with an identical,
/// non-empty ref set and the same DXCC entity — merge the second spot's
/// callsign into the first's (comma-joined) instead of listing it again: a
/// multi-op activation of the same reference. Skips digital modes, where
/// many operators can share one frequency at once. A shared reference is the
/// only evidence two calls are one station, so ref-less spots (DX cluster,
/// RBN) never merge — PoLo merges two empty ref sets as "identical"; we
/// deliberately don't. Nor do two calls from different entities, or one
/// whose entity [entityOf] does not know yet: one activation is one
/// country, and a wrong merge hides a station where a missed one only
/// costs a row.
List<Map<String, dynamic>> mergeSpotsByFreqAndRefs(List<Map<String, dynamic>> spots, {required String? Function(String call) entityOf}) {
  final merged = <Map<String, dynamic>>[];
  for (final spot in spots) {
    Map<String, dynamic>? match;
    if (!_isDigital(_modeOf(spot))) {
      final freq = _freqOf(spot);
      final refs = _refsOf(spot);
      // A call-less spot (a malformed hook result — Spot.their.call is
      // required by the SDK type, but nothing enforces that across the JS
      // bridge at runtime) has no entity, so the entity checks keep it out
      // of a merge on either side, as the spot BEING merged and as a
      // would-be TARGET — either would otherwise produce a dangling ",CALL"
      // or "CALL,".
      final entity = _entityOfSpot(spot, entityOf);
      if (freq != null && refs.isNotEmpty && entity != null) {
        for (final other in merged) {
          final otherFreq = _freqOf(other);
          if (otherFreq == null) continue;
          if ((freq - otherFreq).abs() > 0.1) continue;
          if ((_timeOf(spot) - _timeOf(other)).abs() > 10 * 60 * 1000) continue;
          final otherRefs = _refsOf(other);
          if (refs.length != otherRefs.length) continue;
          if (!otherRefs.every((r) => refs.any((x) => x['ref'] == r['ref']))) continue;
          if (_entityOfSpot(other, entityOf) != entity) continue;
          match = other;
          break;
        }
      }
    }
    if (match != null) {
      final existingCall = _callOf(match) ?? '';
      final newCall = _callOf(spot) ?? '';
      match['their'] = {...?asSpotMap(match['their']), 'call': '$existingCall,$newCall'};
    } else {
      merged.add(spot);
    }
  }
  return merged;
}

typedef _Wanted = ({Map<String, dynamic> spot, bool worked, ({int rank, int goal})? rank});

/// (A copy of) [spots], most wanted first: by the rank [rankOf] gives each
/// — the better verdict, then the earlier goal giving it — and the newest
/// first among equals. [rankOf] answers null for a spot no goal judges,
/// which follows every judged one, and [worked] spots come last of all: a
/// station already worked this period is a duplicate, whatever the checklist
/// would still take from it.
List<Map<String, dynamic>> sortSpotsByWanted(
  List<Map<String, dynamic>> spots, {
  required ({int rank, int goal})? Function(Map<String, dynamic> spot) rankOf,
  required bool Function(Map<String, dynamic> spot) worked,
}) {
  final keyed = <_Wanted>[for (final spot in sortSpots(spots, 'time')) (spot: spot, worked: worked(spot), rank: rankOf(spot))];
  int compare(_Wanted a, _Wanted b) {
    if (a.worked != b.worked) return a.worked ? 1 : -1;
    final ar = a.rank, br = b.rank;
    if (ar == null || br == null) return ar == br ? 0 : (ar == null ? 1 : -1);
    if (ar.rank != br.rank) return br.rank.compareTo(ar.rank);
    return ar.goal.compareTo(br.goal);
  }

  mergeSort(keyed, compare: compare);
  return [for (final entry in keyed) entry.spot];
}

/// Sorts (a copy of) `spots` per `sortBy`: `'time'` most-recent-first,
/// anything else (`'frequency'`, the default) lowest-frequency-first —
/// missing frequencies sort as 0 (ahead of any real frequency). Public for
/// `spots_panel_merge_test.dart`.
List<Map<String, dynamic>> sortSpots(List<Map<String, dynamic>> spots, String sortBy) {
  final sorted = [...spots];
  if (sortBy == 'time') {
    sorted.sort((a, b) => _timeOf(b).compareTo(_timeOf(a)));
  } else {
    sorted.sort((a, b) => (_freqOf(a) ?? 0).compareTo(_freqOf(b) ?? 0));
  }
  return sorted;
}

/// Whether a spot survives the Continent filter. `call` is the spot's
/// `their.call`, which for a multi-op spot is the comma-joined compound of
/// every operator on that frequency (see `mergeSpotsByFreqAndRefs`);
/// `continentOf` resolves a SINGLE callsign to its continent (null when it
/// hasn't been looked up yet, or never resolves).
///
/// A spot passes if ANY of its operators is on a continent that isn't
/// disabled — or whose continent is still unknown. Reading the compound
/// `their.call` as one key would never match the
/// per-call `continentOf` map, so every multi-op spot would look
/// permanently-unresolved and slip through the filter untouched. Keeping
/// the "unknown continent never hides a spot" rule means we only hide a spot
/// when EVERY known operator is on a disabled continent. Public for
/// `spots_panel_merge_test.dart`.
bool spotPassesContinentFilter(String? call, Set<String> disabledContinents, String? Function(String call) continentOf) {
  if (disabledContinents.isEmpty) return true;
  final calls = spotCallsIn(call);
  if (calls.isEmpty) return true;
  return calls.any((c) {
    final continent = continentOf(c);
    return continent == null || !disabledContinents.contains(continent);
  });
}

/// The spots left once the operator's enabled bands (Settings › Logging ›
/// Bands) are applied — the narrowing that happens whenever no single band is
/// selected, so `auto` with no VFO band and `any` both mean "any of MY bands"
/// rather than every band on the air. An explicitly chosen band bypasses this
/// entirely (see `_filteredSpotsSummary`): picking a band you don't normally
/// use is a deliberate act, and must still show its spots.
///
/// Two fail-open rules keep the panel from going mysteriously blank: a spot
/// with no band at all is kept, since there is no band for the operator to
/// have disabled, and an empty [enabledBands] narrows nothing.
/// Public for `spots_panel_merge_test.dart`.
List<Map<String, dynamic>> spotsOnEnabledBands(List<Map<String, dynamic>> spots, Set<String> enabledBands) {
  if (enabledBands.isEmpty) return spots;
  return spots.where((s) {
    final band = _bandOf(s);
    return band == null || enabledBands.contains(band);
  }).toList();
}

/// A key for a spot's scoring candidate: the fields a scorer actually judges
/// on. Two spots for the same operator on the same band/mode/references are
/// the same question, asked once.
///
/// Per CALL, not per spot — a merged multi-op spot's `their.call` is a
/// comma-joined compound (see [mergeSpotsByFreqAndRefs]) that no scorer would
/// recognize.
String spotCandidateKey(String call, Map<String, dynamic> spot) {
  final refs = [for (final ref in _refsOf(spot)) '${ref['type']}:${ref['ref']}']..sort();
  return '${call.toUpperCase()}|${_bandOf(spot) ?? ''}|${_spotModeFor(spot)}|${refs.join(',')}';
}

/// A spot's mode as a scorer will compare it, uppercased: sources pass their
/// API's casing through — POTA hands back `spot.mode` untouched — and this is
/// also half of [spotCandidateKey], which must not ask the same question twice
/// because two sources spelled one mode differently. Scorers themselves fold
/// the spellings that name one emission (`modesMatchForDupe`), so the casing
/// is the only normalization owed to them.
String _spotModeFor(Map<String, dynamic> spot) => (_modeOf(spot) ?? '').toUpperCase();

/// The QSO a scorer judges when asked "what would working this spot be?".
///
/// `startAtMillis` is [now]: activity scoring buckets a contact by
/// `floor(startAtMillis / day)`, and a spot would be worked now, not when it
/// was posted. The scoring harness stamps a candidate that carries no time
/// with its own clock; stating it here keeps every spot on one board judged
/// at the same instant rather than at whenever each scorer got to it.
///
/// The callsign is uppercased for the same reason the mode is
/// ([_spotModeFor]): scorers key their worked-call tables on the raw string,
/// and POTA and SOTA both pass their API's callsign through as it arrives, so a
/// lower-cased spot would never match the log and never strike through.
/// Public for `spots_panel_scoring_test.dart`.
Map<String, dynamic> spotCandidateQso(String call, Map<String, dynamic> spot, {required int now}) => {
  'their': {'call': call.toUpperCase()},
  if (_freqOf(spot) != null) 'freq': _freqOf(spot),
  if (_bandOf(spot) != null) 'band': _bandOf(spot),
  if (_modeOf(spot) != null) 'mode': _spotModeFor(spot),
  'refs': _refsOf(spot),
  'startAtMillis': now,
};

/// Whether an operator [call] is our own station: its base call is one of
/// [ourBaseCalls] (see [baseCallOf]). Unlike [spotIsCurrentQso], a portable
/// or fixed suffix is still us — KI2D/P spotted while operating as KI2D is
/// our own signal, not a station to work. Stations that share a base call
/// share it here too: operating as W1AW/4, a spot of W1AW/7 counts as ours.
bool _isOurCall(String call, Set<String> ourBaseCalls) => ourBaseCalls.contains(baseCallOf(call));

/// Whether every operator on [spot] is one of our station's calls
/// ([ourBaseCalls], by base call) — the spot is ours ALONE. The self affordances key off this — the pinned
/// section, the tap-to-retune, the withheld slide-to-log — NOT
/// [spotDisplayFlags]'s any-of `isSelf` tint: a merged multi-op row that
/// merely includes us still carries another station worth working, and
/// stealing its tap or its log action would make that station unreachable
/// from the board. Public for `spots_panel_merge_test.dart`.
bool spotIsSelfOnly(Map<String, dynamic> spot, {Set<String> ourBaseCalls = const {}}) {
  if (ourBaseCalls.isEmpty) return false;
  final calls = spotOperatorCalls(spot).toList();
  return calls.isNotEmpty && calls.every((c) => _isOurCall(c, ourBaseCalls));
}

/// How a spot should read: struck through when worked, tinted when it's our
/// own station, accented per the scoring notices its operators carry.
/// [scores] is keyed by [spotCandidateKey]; [ourBaseCalls] are the base calls
/// of the operation's station callsigns.
///
/// `worked` needs EVERY operator on the spot to be a duplicate. A merged
/// multi-op spot is one row for several stations, and striking it because one
/// of them is worked would hide the others — the conservative direction, since
/// an un-struck worked spot costs a glance and a struck unworked one costs the
/// contact. Notices, which only ever add an accent, merge across operators
/// instead.
///
/// A notice alongside the alert un-strikes for the same reason. Alerts and
/// notices are unioned across every scorer, and a scorer only reports a QSO as
/// new on some axis when it is NOT that scorer's duplicate — so the two
/// together mean two scorers disagreed. app-polo resolves that the same way
/// (SpotItem's `type: 'scoring'` wins over `'duplicate'`): a POTA hunter who
/// worked a station at one park still wants them at their next one, and a row
/// that is struck through and reference-accented at once hides exactly the
/// contact worth making. Public for `spots_panel_scoring_test.dart`.
({bool worked, bool isSelf, Set<String> notices}) spotDisplayFlags(
  Map<String, dynamic> spot, {
  required Map<String, ({List<String> notices, List<String> alerts})> scores,
  Set<String> ourBaseCalls = const {},
}) {
  final calls = spotOperatorCalls(spot).toList();
  if (calls.isEmpty) return (worked: false, isSelf: false, notices: const {});
  var worked = true;
  final notices = <String>{};
  for (final call in calls) {
    final score = scores[spotCandidateKey(call, spot)];
    if (score == null || !score.alerts.contains('duplicate')) worked = false;
    notices.addAll(score?.notices ?? const []);
  }
  return (worked: worked && notices.isEmpty, isSelf: calls.any((c) => _isOurCall(c, ourBaseCalls)), notices: notices);
}

/// The operator's Spots Panel filters, decoded from Settings' persisted
/// `spottingFilters` — the one reading of that map, so the panel restoring
/// its state and an extension asking for the operator's view agree on it.
class SpotBoardFilters {
  final String bandFilter;
  final String modeFilter;

  /// Never wider than [spotAgeOptionsInMinutes]' last: the board is not
  /// open-ended, so there is no "any age" to fall back to.
  final int ageMinutes;
  final Set<String> disabledSources;
  final Set<String> disabledContinents;
  final String sortBy;
  final bool groupByBand;
  final bool groupCallsWithNotes;

  const SpotBoardFilters({
    this.bandFilter = 'auto',
    this.modeFilter = 'auto',
    this.ageMinutes = _widestSpotAgeMinutes,
    this.disabledSources = const {},
    this.disabledContinents = const {},
    this.sortBy = 'frequency',
    this.groupByBand = true,
    this.groupCallsWithNotes = false,
  });

  factory SpotBoardFilters.fromSettings(SettingsService settings) {
    final decoded = settings.spottingFilters;
    if (decoded.isEmpty) return const SpotBoardFilters();
    // A stored 'any' (null, from before the board was bounded) or anything
    // wider than the options now offered comes back as the widest one.
    final storedAge = decoded['ageMinutes'] as int?;
    final sortBy = decoded['sortBy'] as String? ?? 'frequency';
    return SpotBoardFilters(
      bandFilter: decoded['bandFilter'] as String? ?? 'auto',
      modeFilter: normalizeModeFilter(decoded['modeFilter'] as String? ?? 'auto'),
      ageMinutes: spotAgeOptionsInMinutes.contains(storedAge) ? storedAge! : _widestSpotAgeMinutes,
      // Through the typed accessor, not a second read of the raw map: the
      // status reporter subtracts the same set, and two hand-rolled decodings
      // of one key drift apart silently.
      disabledSources: settings.disabledSpotSources,
      disabledContinents: {...?(decoded['disabledContinents'] as List?)?.cast<String>()},
      sortBy: sortBy,
      groupByBand: decoded['groupByBand'] as bool? ?? defaultGroupByBand(sortBy),
      groupCallsWithNotes: decoded['groupCallsWithNotes'] as bool? ?? false,
    );
  }
}

/// Every held spot from a source the operator has not switched off, combined
/// by both merge passes — the board before any band/mode/age narrowing.
/// [entityOf] resolves a single callsign to its DXCC entity prefix, as
/// `SpotBoardService.callInfo` holds it.
List<Map<String, dynamic>> mergedSpotBoard(
  Map<String, List<Map<String, dynamic>>> spotsBySource,
  Set<String> disabledSources, {
  required String? Function(String call) entityOf,
}) => mergeSpotsByFreqAndRefs(
  mergeSpotsByCallAndFreq([
    for (final entry in spotsBySource.entries)
      if (!disabledSources.contains(entry.key)) ...entry.value,
  ]),
  entityOf: entityOf,
);

/// What [filters] admit of the [merged] board, sorted their way, and the
/// count that is "all" for it.
///
/// `total` counts the spots after the operator's enabled bands but BEFORE
/// band/mode/age/continent — the "of 72" in "Showing 45 of 72 spots".
/// Standing exclusions (a disabled source, a band the operator doesn't use)
/// decide what counts as "all"; band/mode/age, which narrow temporarily,
/// don't. Explicitly choosing a band opts out of the enabled-bands narrowing,
/// and then every fetched spot is back in play.
///
/// The 'auto' band and mode follow [vfoBand]/[vfoMode]. [continentOf]
/// resolves a single callsign's continent; without it, or for a call it
/// cannot answer, the continent filter hides nothing.
({List<Map<String, dynamic>> filtered, int total}) filterSpotBoard(
  List<Map<String, dynamic>> merged,
  SpotBoardFilters filters, {
  String? vfoBand,
  String? vfoMode,
  required Set<String> enabledBands,
  String? Function(String call)? continentOf,
}) {
  final band = filters.bandFilter == 'auto' ? vfoBand : filters.bandFilter;
  final superModes = superModesForModeFilter(filters.modeFilter, vfoMode);

  final singleBand = band != null && band != 'any';
  var spots = singleBand ? merged : spotsOnEnabledBands(merged, enabledBands);
  final total = spots.length;

  if (singleBand) {
    spots = spots.where((s) => _bandOf(s) == band).toList();
  }
  if (superModes != null) {
    spots = spots.where((s) => superModes.contains(superModeForMode(_modeOf(s)))).toList();
  }
  final cutoff = nowMillis() - filters.ageMinutes * 60000;
  spots = spots.where((s) => _timeOf(s) >= cutoff).toList();
  if (filters.disabledContinents.isNotEmpty && continentOf != null) {
    // Per-operator so multi-op spots narrow correctly; an unresolved
    // continent never hides a spot. See spotPassesContinentFilter.
    spots = spots.where((s) => spotPassesContinentFilter(_callOf(s), filters.disabledContinents, continentOf)).toList();
  }
  return (filtered: sortSpots(spots, filters.sortBy), total: total);
}

/// An icon a spot row shows: an MDI or `fa-` name, and the `#RRGGBB` accent
/// that tints it, null for the row's own untinted colour.
typedef SpotIcon = ({String icon, String? color});

/// [value] read as a [SpotIcon] — `{icon, color?}`, as a scorer's answer and
/// `getSpots`' `display` carry one — or null for anything else.
SpotIcon? spotIconFrom(dynamic value) => switch (value) {
  {'icon': final String icon} when icon.isNotEmpty => (icon: icon, color: asSpotString(value['color'])),
  _ => null,
};

/// The icons a spot row shows, by what put them there: the scorers'
/// ([spotScoreIcons]), the chasing programs' ([spotJudgementIcons]) and the
/// references' ([spotRefIcons]). No icon name appears twice, the earlier
/// kind keeping it.
typedef SpotIcons = ({List<SpotIcon> scores, List<SpotIcon> judgements, List<SpotIcon> refs});

/// Every icon [spot]'s row may show ([SpotIcons]). [scoreIcons] and
/// [judgements] are keyed by [spotCandidateKey]; [notices] are the spot's
/// own, as [spotDisplayFlags] unions them; [programs] name each program's
/// icon. [refIcons] is [spot]'s [spotRefIcons], where the caller has it.
SpotIcons spotIcons(
  Map<String, dynamic> spot, {
  required List<Map<String, dynamic>> controls,
  Map<String, List<SpotIcon>> scoreIcons = const {},
  Set<String> notices = const {},
  Map<String, List<ChaseJudgement>> judgements = const {},
  Map<String, ChasingProgram> programs = const {},
  List<SpotIcon>? refIcons,
}) {
  final seen = <String>{};
  List<SpotIcon> unseen(Iterable<SpotIcon> icons) => [
    for (final icon in icons)
      if (seen.add(icon.icon)) icon,
  ];
  return (
    scores: unseen(spotScoreIcons(spot, scoreIcons)),
    judgements: unseen(spotJudgementIcons(spot, notices: notices, judgements: judgements, programs: programs)),
    refs: unseen(refIcons ?? spotRefIcons(spot, controls)),
  );
}

/// At most [max] of [icons], in their order — scores, then judgements, then
/// references — with at least one of each kind there is, so a row full of
/// references still says why it matters, and one full of alerts still says
/// what it is. The slots left over go to the earlier kinds first.
List<SpotIcon> spotIconsWithin(SpotIcons icons, int max) {
  final groups = [icons.scores, icons.judgements, icons.refs];
  final counts = [for (final group in groups) group.isEmpty ? 0 : 1];
  var left = max - counts.fold<int>(0, (sum, count) => sum + count);
  for (var i = 0; i < groups.length && left > 0; i++) {
    final more = math.min(groups[i].length - counts[i], left);
    counts[i] += more;
    left -= more;
  }
  return [for (var i = 0; i < groups.length; i++) ...groups[i].take(counts[i])].take(max).toList();
}

/// The icons the scorers gave [spot]'s operators ([scoreIcons], keyed by
/// [spotCandidateKey]), in operator order, each name once.
List<SpotIcon> spotScoreIcons(Map<String, dynamic> spot, Map<String, List<SpotIcon>> scoreIcons) {
  final seen = <String>{};
  return [
    for (final call in spotOperatorCalls(spot))
      for (final icon in scoreIcons[spotCandidateKey(call, spot)] ?? const <SpotIcon>[])
        if (seen.add(icon.icon)) icon,
  ];
}

/// The icons of the chasing programs ([programs]) whose verdicts on
/// [spot]'s operators alert in [notices] ([ChaseNotice]), in goal order, each
/// name once: what an alert for "DXCC ATNO" puts on the row beside the
/// call's accent. A verdict that only shows, in the Chasing view, adds none,
/// as does a program declaring no icon.
List<SpotIcon> spotJudgementIcons(
  Map<String, dynamic> spot, {
  required Set<String> notices,
  required Map<String, List<ChaseJudgement>> judgements,
  required Map<String, ChasingProgram> programs,
}) {
  final alerting = {
    for (final key in notices)
      if (ChaseNotice.tryParse(key) case final notice? when notice.alerting) notice.program,
  };
  if (alerting.isEmpty) return const [];
  final seen = <String>{};
  return [
    for (final call in spotOperatorCalls(spot))
      for (final judgement in judgements[spotCandidateKey(call, spot)] ?? const <ChaseJudgement>[])
        if (alerting.contains(judgement.program))
          if (programs[judgement.program] case ChasingProgram(:final icon?, :final color) when seen.add(icon)) (icon: icon, color: color),
  ];
}

/// The icons [spot] opens its label with: one for each kind of reference it
/// carries, in the order it names them, so an activator on a park and a
/// summit at once shows both — each the icon of the activity in [controls]
/// that handles the reference, and the accent it declares. References no
/// activity handles share one icon, the spot's own top-level `icon` (the
/// SDK's `Spot` declares no other; a nested `spot.icon` is misplaced) else a
/// tower, as does a spot with none at all. An icon name appears once, with
/// the accent of its first reference.
List<SpotIcon> spotRefIcons(Map<String, dynamic> spot, List<Map<String, dynamic>> controls) {
  final fallback = asSpotString(spot['icon']) ?? 'radio-tower';
  final icons = <SpotIcon>[];
  for (final ref in _refsOf(spot)) {
    final control = controlForRef(controls, type: asSpotString(ref['type']), code: refCodeOf(ref));
    final icon = asSpotString(control?['icon']) ?? fallback;
    if (icons.every((seen) => seen.icon != icon)) icons.add((icon: icon, color: asSpotString(control?['color'])));
  }
  return icons.isEmpty ? [(icon: fallback, color: null)] : icons;
}

/// The references [spot]'s operators would be new for, under each program
/// whose new-reference verdict alerts in [notices] ([ChaseNotice]),
/// upper-cased: what the row's reference label is accented for. Only an
/// alerting verdict accents, as only an alerting one accents the call: the
/// Chasing view's notices carry every verdict, to order its list. A new DXCC
/// entity names no reference a row shows. [judgements] is keyed by
/// [spotCandidateKey].
Set<String> spotNewRefs(Map<String, dynamic> spot, {required Set<String> notices, required Map<String, List<ChaseJudgement>> judgements}) {
  final programs = {
    for (final key in notices)
      if (ChaseNotice.tryParse(key) case final notice? when notice.verdict == ChaseVerdict.newRef && notice.alerting) notice.program,
  };
  if (programs.isEmpty) return const {};
  return {
    for (final call in spotOperatorCalls(spot))
      for (final judgement in judgements[spotCandidateKey(call, spot)] ?? const <ChaseJudgement>[])
        if (programs.contains(judgement.program) && judgement.verdicts.contains(ChaseVerdict.newRef))
          for (final ref in judgement.refs) ref.toUpperCase(),
  };
}
