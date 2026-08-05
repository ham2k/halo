// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots Panel: fetches spots from every extension's
// `spots` hook, combines/dedupes across sources, groups by band, and lets
// the user filter by band/mode/age/source via a dialog opened from the
// spots-count row. Ported from app-polo's SpotsPanel.jsx, notably its
// two-pass combining algorithm (merge same call+freq's refs, then merge
// same freq+refs' calls) and its 0.5kHz/30min and 0.1kHz/10min tolerances.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../../services/spots_service.dart';
import '../../i18n/strings.g.dart';

/// Modes excluded from the callsign-merge pass (SpotsPanel.jsx: too many
/// simultaneous operators on one frequency to safely merge callsigns). A
/// narrower set than the "Digital" super mode ([superModeForMode]) — it's only
/// about which modes are unsafe to merge, not the mode filter's grouping.
const _digitalModes = {'FT8', 'FT4', 'RTTY', 'DATA'};

const _ageOptionsInMinutes = [15, 30, 60, 180];

/// Height of the initial-load progress bar above the spots list — reserved
/// whether or not a fetch is running, matching LinearProgressIndicator's own
/// default thickness. Same value/convention as activities_view.dart's
/// `_searchProgressHeight`.
const _spotsProgressHeight = 4.0;

String? _callOf(Map<String, dynamic> spot) => (spot['their'] as Map?)?['call'] as String?;
/// The individual operator callsigns within a `their.call` — a comma-joined
/// compound for a multi-op spot (see `mergeSpotsByFreqAndRefs`), a single call
/// otherwise. Empty segments are dropped. Everything that keys off `_callNotes`
/// (per single call) must iterate these, not the raw compound string.
Iterable<String> _callsIn(String? call) => (call ?? '').split(',').where((c) => c.isNotEmpty);
double? _freqOf(Map<String, dynamic> spot) => (spot['freq'] as num?)?.toDouble();
String? _bandOf(Map<String, dynamic> spot) => spot['band'] as String?;
String? _modeOf(Map<String, dynamic> spot) => spot['mode'] as String?;
List<Map<String, dynamic>> _refsOf(Map<String, dynamic> spot) =>
    (spot['refs'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
int _timeOf(Map<String, dynamic> spot) => ((spot['spot'] as Map?)?['timeInMillis'] as num?)?.toInt() ?? 0;
String? _iconOf(Map<String, dynamic> spot) =>
    spot['icon'] as String? ?? (spot['spot'] as Map?)?['icon'] as String?;
String? _labelOf(Map<String, dynamic> spot) => (spot['spot'] as Map?)?['label'] as String?;
bool _isDigital(String? mode) => mode != null && _digitalModes.contains(mode.toUpperCase());

/// The three "super modes" ([superModeForMode]) the mode filter groups spots
/// by, in the order the dropdown offers them.
const _superModes = ['Phone', 'CW', 'Digital'];

/// Migrates a persisted mode filter from the retired per-mode/`notDigital`
/// scheme to the super-mode scheme: 'auto'/'any' and the super modes pass
/// through, an old individual mode ('SSB', 'FT8', …) maps to its super mode,
/// and anything else — notably the retired 'notDigital', which spanned two
/// super modes — resets to 'auto'. Public for unit testing.
String normalizeModeFilter(String value) {
  if (value == 'auto' || value == 'any' || _superModes.contains(value)) return value;
  if (value == 'notDigital') return 'auto';
  return superModeForMode(value) ?? 'auto';
}

/// The `groupByBand` value to assume for a persisted filter map that
/// predates that setting — from when time-sorting alone implied a flat
/// list. Infers the grouping that old shape meant rather than defaulting
/// every such map straight to grouped. Public for unit testing.
bool defaultGroupByBand(String sortBy) => sortBy != 'time';

/// Pass 1: same callsign, close in frequency (0.5kHz) and time (30min) —
/// merge the second spot's refs into the first instead of listing it again.
/// Public (not `_`-prefixed) so `app/test/spots_panel_merge_test.dart` can
/// exercise this pure logic directly.
List<Map<String, dynamic>> mergeSpotsByCallAndFreq(List<Map<String, dynamic>> spots) {
  final sorted = [...spots]..sort((a, b) => _timeOf(b).compareTo(_timeOf(a)));
  final byCall = <String, Map<String, dynamic>>{};
  final merged = <Map<String, dynamic>>[];
  for (final spot in sorted) {
    final call = _callOf(spot);
    if (call == null) {
      // Copy, like the merged-copy branch below — `spot` is the same Map
      // instance held in `_spotsBySource`; if this object were later chosen
      // as a merge target in the second pass, mutating it in place would
      // corrupt the panel's persisted state across rebuilds.
      merged.add({...spot, 'refs': [..._refsOf(spot)]});
      continue;
    }
    final existing = byCall[call];
    final freq = _freqOf(spot);
    final existingFreq = existing == null ? null : _freqOf(existing);
    final closeEnough = existing != null &&
        freq != null &&
        existingFreq != null &&
        (freq - existingFreq).abs() <= 0.5 &&
        (_timeOf(spot) - _timeOf(existing)).abs() <= 30 * 60 * 1000;
    if (!closeEnough) {
      final copy = {...spot, 'refs': [..._refsOf(spot)]};
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

/// Pass 2: same frequency (0.1kHz) and time (10min), with an identical ref
/// set — merge the second spot's callsign into the first's (comma-joined)
/// instead of listing it again. Skips digital modes, where many operators
/// can share one frequency at once.
List<Map<String, dynamic>> mergeSpotsByFreqAndRefs(List<Map<String, dynamic>> spots) {
  final merged = <Map<String, dynamic>>[];
  for (final spot in spots) {
    Map<String, dynamic>? match;
    // A call-less spot (a malformed hook result — Spot.their.call is
    // required by the SDK type, but nothing enforces that across the JS
    // bridge at runtime) is never merged into another's call list, which
    // would otherwise produce a dangling "CALL," with an empty second call.
    if (!_isDigital(_modeOf(spot)) && (_callOf(spot)?.isNotEmpty ?? false)) {
      final freq = _freqOf(spot);
      final refs = _refsOf(spot);
      if (freq != null) {
        for (final other in merged) {
          final otherFreq = _freqOf(other);
          if (otherFreq == null) continue;
          if ((freq - otherFreq).abs() > 0.1) continue;
          if ((_timeOf(spot) - _timeOf(other)).abs() > 10 * 60 * 1000) continue;
          final otherRefs = _refsOf(other);
          if (refs.length != otherRefs.length) continue;
          if (!otherRefs.every((r) => refs.any((x) => x['ref'] == r['ref']))) continue;
          match = other;
          break;
        }
      }
    }
    if (match != null) {
      final existingCall = (match['their'] as Map)['call'] as String;
      final newCall = _callOf(spot) ?? '';
      match['their'] = {...match['their'] as Map, 'call': '$existingCall,$newCall'};
    } else {
      merged.add(spot);
    }
  }
  return merged;
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

/// Splits already-sorted `spots` into display sections, mirroring
/// app-polo's SpotsPanel.jsx: `callsWithNotes` spots get a leading
/// `'notes'`-keyed section (a pinned DUPLICATE — those spots still appear
/// again in their normal section below, never removed from it). Then, when
/// `groupByBand` is false, one flat `'spots'`-keyed section holding `spots`
/// in their incoming (already-sorted) order — band grouping would otherwise
/// re-order same-band spots ahead of a spot the caller's sort placed earlier
/// on another band, defeating that sort. Otherwise (the default), one
/// section per band the spots belong to, band-list-ordered with unmatched
/// spots keyed `'?'`; each band keeps `spots`' incoming order, so the
/// caller's sort still applies WITHIN each band. Empty sections are omitted.
/// Section `key` is a stable identifier, not a display label — the caller
/// maps it to translated text. Public for `spots_panel_merge_test.dart`.
List<({String key, List<Map<String, dynamic>> spots})> sectionSpots(
  List<Map<String, dynamic>> spots, {
  required Set<String> callsWithNotes,
  bool groupByBand = true,
}) {
  final sections = <({String key, List<Map<String, dynamic>> spots})>[];

  if (callsWithNotes.isNotEmpty) {
    // Pin a multi-op spot when ANY of its operators has a note — a
    // compound `their.call` never matches the per-call `callsWithNotes` set.
    final noted = spots.where((s) => _callsIn(_callOf(s)).any(callsWithNotes.contains)).toList();
    if (noted.isNotEmpty) sections.add((key: 'notes', spots: noted));
  }

  if (!groupByBand) {
    if (spots.isNotEmpty) sections.add((key: 'spots', spots: spots));
    return sections;
  }

  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final spot in spots) {
    grouped.putIfAbsent(_bandOf(spot) ?? '?', () => []).add(spot);
  }
  final orderedBands = [...bands.map((b) => b.name), '?'].where(grouped.containsKey);
  for (final band in orderedBands) {
    sections.add((key: band, spots: grouped[band]!));
  }
  return sections;
}

/// Builds a QSON-shaped "suggested QSO" from a spot — just the fields
/// relevant to prefill (their.call, freq, band, mode, refs). Deliberately
/// omits `our`/`startAtMillis`/RST (those belong to the current moment and
/// station, not the spot) and any spot-only metadata (`icon`, `spot.*`) —
/// `LoggingControls._applyFieldsFromData` copies every top-level key it
/// doesn't recognize into the eventually-logged QSO, so a raw spot map
/// would leak spot bookkeeping into a real QSO record. Public for
/// `spots_panel_merge_test.dart`.
Map<String, dynamic> suggestedQsoFromSpot(Map<String, dynamic> spot) => {
      'their': {'call': _callOf(spot) ?? ''},
      if (_freqOf(spot) != null) 'freq': _freqOf(spot),
      if (_bandOf(spot) != null) 'band': _bandOf(spot),
      if (_modeOf(spot) != null) 'mode': _modeOf(spot),
      'refs': _refsOf(spot),
    };

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
bool spotPassesContinentFilter(
  String? call,
  Set<String> disabledContinents,
  String? Function(String call) continentOf,
) {
  if (disabledContinents.isEmpty) return true;
  final calls = _callsIn(call);
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
List<Map<String, dynamic>> spotsOnEnabledBands(
  List<Map<String, dynamic>> spots,
  Set<String> enabledBands,
) {
  if (enabledBands.isEmpty) return spots;
  return spots.where((s) {
    final band = _bandOf(s);
    return band == null || enabledBands.contains(band);
  }).toList();
}

/// The bands the filter dropdown offers, in the canonical [bands] order and
/// without the leading `auto`/`any` entries.
///
/// The enabled bands are the point of the list, but two more earn a place:
/// a band that currently HAS spots (so nothing visible under `any` is
/// unfilterable), and the [selected] one (a filter persisted before its band
/// was disabled stays on screen instead of the dropdown disagreeing with what
/// is actually filtering). Public for `spots_panel_merge_test.dart`.
List<String> spotsFilterBandOptions({
  required Set<String> enabledBands,
  required Map<String, int> bandSpotCounts,
  required String selected,
}) =>
    [
      for (final band in bands.map((b) => b.name))
        if (enabledBands.isEmpty ||
            enabledBands.contains(band) ||
            (bandSpotCounts[band] ?? 0) > 0 ||
            band == selected)
          band,
    ];

String _timeAgo(int millis) {
  final seconds = (DateTime.now().millisecondsSinceEpoch - millis) ~/ 1000;
  if (seconds < 60) return '${seconds}s ago';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';
  return '${minutes ~/ 60}h${minutes % 60}m ago';
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

/// A spot's mode as a scorer will compare it. Scorers match a logged QSO's
/// `band|mode` as raw strings and logged modes are always uppercase, so a
/// source that passes its API's casing through — POTA hands back `spot.mode`
/// untouched — would otherwise never match a contact the operator has made.
String _spotModeFor(Map<String, dynamic> spot) => (_modeOf(spot) ?? '').toUpperCase();

/// The QSO a scorer judges when asked "what would working this spot be?".
///
/// `startAtMillis` is [now], not absent: activity scoring buckets a contact by
/// `floor(startAtMillis / day)`, so a candidate without one lands on the epoch
/// and every already-worked station reports `newDay` instead of `duplicate`.
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

/// How a spot should read: struck through when worked, tinted when it's our
/// own station, accented per the scoring notices its operators carry.
/// [scores] is keyed by [spotCandidateKey]; [ourCall] is the operation's
/// station callsign, uppercased.
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
  String? ourCall,
}) {
  final calls = _callsIn(_callOf(spot)).toList();
  if (calls.isEmpty) return (worked: false, isSelf: false, notices: const {});
  var worked = true;
  final notices = <String>{};
  for (final call in calls) {
    final score = scores[spotCandidateKey(call, spot)];
    if (score == null || !score.alerts.contains('duplicate')) worked = false;
    notices.addAll(score?.notices ?? const []);
  }
  return (
    worked: worked && notices.isEmpty,
    isSelf: ourCall != null && calls.any((c) => c.toUpperCase() == ourCall),
    notices: notices,
  );
}

class SpotsPanel extends StatefulWidget {
  final Operation operation;
  final HaLoServices services;
  final ValueChanged<Map<String, dynamic>>? onSuggestQso;

  /// Changes whenever the operation's log does. Spots are scored against that
  /// log, so working a station has to restrike its spot immediately — a plain
  /// QSO count would miss the edit that moves a contact to another band, which
  /// is exactly what flips a spot back from worked to new-band.
  ///
  /// Required rather than defaulted: a caller that forgets it gets a panel
  /// whose spots never restrike, and nothing about that looks broken.
  final String logRevision;

  /// The operation's log, for resolving its `break`/`start` segments — those
  /// ride event rows in the log, never [operation]'s own data. Read only when
  /// a scoring pass runs, not per build.
  final List<Qso> qsos;

  const SpotsPanel({
    super.key,
    required this.operation,
    required this.services,
    required this.logRevision,
    this.onSuggestQso,
    this.qsos = const [],
  });

  @override
  State<SpotsPanel> createState() => _SpotsPanelState();
}

class _SpotsPanelState extends State<SpotsPanel> {
  Map<String, String> _sourceNames = {};
  List<Map<String, dynamic>> _activityControls = [];
  VoidCallback? _unsubscribeSpots;
  bool _refreshing = false;

  SpotsService get _spots => widget.services.spots;
  Map<String, List<Map<String, dynamic>>> get _spotsBySource => _spots.spotsBySource;
  bool get _loading => !_spots.loaded;
  String? get _error => _spots.error?.toString();

  String _bandFilter = 'auto';
  String _modeFilter = 'auto';
  int? _ageMinutes;
  final Set<String> _disabledSources = {};
  final Set<String> _disabledContinents = {};
  String _sortBy = 'frequency';
  bool _groupByBand = true;
  bool _groupCallsWithNotes = false;
  final Map<String, ({bool hasNote, String? emoji, String? continent})> _callNotes = {};

  /// Scoring verdicts keyed by [spotCandidateKey] — what makes a spot show as
  /// worked, or accented for a new band/mode/day/reference/multiplier. Absent
  /// means "nothing to report" as well as "not scored yet"; the panel renders
  /// the same either way, so an unscored spot simply looks ordinary rather
  /// than wrong.
  Map<String, ({List<String> notices, List<String> alerts})> _spotScores = {};

  /// Guards against a second scoring pass while one is in flight (a spot
  /// refresh landing on a log edit) — the second would fold the same log again
  /// for the same answer. The trailing flag re-runs once, so the pass that was
  /// skipped isn't simply lost.
  bool _scoringSpots = false;
  bool _spotScoresStale = false;

  /// Coalesces bursts of triggers into one pass. A run of contacts logged in a
  /// pileup moves `logRevision` per QSO, and each pass is a whole-log fold per
  /// scorer on the same runtime that serves the logging panel's own
  /// call-info scoring — so scoring every intermediate state costs the operator
  /// the responsiveness of the field they are typing in. Longer than that
  /// panel's own 300ms: nothing here is per-keystroke.
  Timer? _scoreDebounce;

  /// The log this panel last kicked off a scoring pass for. A cached scoresheet
  /// (see `_refreshSpotScores`) is only usable while this still matches, since
  /// `ScoringService` writes that cache on its own debounce and it lags the log
  /// by exactly the window in which a just-worked spot must strike.
  String? _scoredLogRevision;

  String? _lastVfoBand;
  String? _lastVfoMode;
  /// Mirrors Settings › Logging › Bands, kept here rather than read per build
  /// so `_onSettingsChanged` can tell an edit to THIS list from the many other
  /// settings writes that notify — including this panel's own filter persist.
  late Set<String> _enabledBands;

  @override
  void initState() {
    super.initState();
    _loadPersistedFilters();
    _enabledBands = widget.services.settings.enabledBands.toSet();
    widget.services.settings.addListener(_onSettingsChanged);
    _lastVfoBand = widget.services.radio.vfoA.band;
    _lastVfoMode = widget.services.radio.vfoA.mode;
    widget.services.radio.addListener(_onVfoChanged);
    // The panel is a consumer, not the owner: the Operation View already
    // holds a subscription so the `spot-history` lookup has spots to mine
    // whether or not this panel was ever opened. Subscribing again is what
    // keeps the refresh running if that ever stops being true.
    _unsubscribeSpots = widget.services.spots.subscribe();
    widget.services.spots.addListener(_onSpotsChanged);
    if (widget.services.spots.loaded) {
      unawaited(_refreshCallInfo());
      unawaited(_refreshSpotScores());
    }
    // Fetched once, not on the 2-min spots refresh timer — a hook's
    // `sourceName` is a static field, not something that changes at runtime.
    widget.services.extensions.getSpotSourceNames().then((names) {
      if (mounted) setState(() => _sourceNames = names);
    });
    // Same activity ref-type -> icon source QsoList uses (via
    // iconForRefType) — unconditional per extension (POTA/SOTA's own
    // loggingControls always register their hunting ref type, regardless
    // of whether this operation has that activity added), not tied to the
    // operation's own configured activities, since a spot can be for any
    // hunted activity type.
    widget.services.extensions.loggingControls(widget.operation.data).then((controls) {
      if (mounted) setState(() => _activityControls = controls);
    });
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    widget.services.radio.removeListener(_onVfoChanged);
    widget.services.spots.removeListener(_onSpotsChanged);
    _scoreDebounce?.cancel();
    _unsubscribeSpots?.call();
    super.dispose();
  }

  /// Restores band/mode/age/sources/continents/sorting/grouping from the
  /// last session — synchronous, like `RadioService`'s own load, since
  /// `SharedPreferences.getInstance()` was already awaited before
  /// `HaLoServices` existed.
  void _loadPersistedFilters() {
    final decoded = widget.services.settings.spottingFilters;
    if (decoded.isEmpty) return;
    _bandFilter = decoded['bandFilter'] as String? ?? _bandFilter;
    _modeFilter = normalizeModeFilter(decoded['modeFilter'] as String? ?? _modeFilter);
    _ageMinutes = decoded['ageMinutes'] as int?;
    _disabledSources.addAll((decoded['disabledSources'] as List?)?.cast<String>() ?? const []);
    _disabledContinents.addAll((decoded['disabledContinents'] as List?)?.cast<String>() ?? const []);
    _sortBy = decoded['sortBy'] as String? ?? _sortBy;
    _groupByBand = decoded['groupByBand'] as bool? ?? defaultGroupByBand(_sortBy);
    _groupCallsWithNotes = decoded['groupCallsWithNotes'] as bool? ?? _groupCallsWithNotes;
  }

  Future<void> _persistFilters() => widget.services.settings.setSpottingFilters({
        'bandFilter': _bandFilter,
        'modeFilter': _modeFilter,
        'ageMinutes': _ageMinutes,
        'disabledSources': _disabledSources.toList(),
        'disabledContinents': _disabledContinents.toList(),
        'sortBy': _sortBy,
        'groupByBand': _groupByBand,
        'groupCallsWithNotes': _groupCallsWithNotes,
      });

  /// Only the VFO's band/mode feed the "auto" filter (see `_filteredSpots`)
  /// — skip the rebuild (and the merge/filter pipeline it triggers) when
  /// neither changed, so a live CAT-control feed updating freq alone
  /// doesn't force a recompute on every tick.
  void _onVfoChanged() {
    if (!mounted) return;
    final vfo = widget.services.radio.vfoA;
    if (vfo.band == _lastVfoBand && vfo.mode == _lastVfoMode) return;
    setState(() {
      _lastVfoBand = vfo.band;
      _lastVfoMode = vfo.mode;
    });
  }

  /// The operator changed a setting — only their band list reaches this
  /// panel, and only through `_filteredSpotsSummary`'s narrowing, so anything
  /// else notifying (this panel's own `_persistFilters` among them) must not
  /// cost a rebuild of the whole spot list.
  void _onSettingsChanged() {
    if (!mounted) return;
    final enabled = widget.services.settings.enabledBands.toSet();
    if (setEquals(enabled, _enabledBands)) return;
    setState(() => _enabledBands = enabled);
  }

  /// A fetch settled in the shared cache (the refresh timer, this panel's
  /// pull-to-refresh, or another subscriber's) — rebuild against it and
  /// annotate whatever callsigns are newly on the board.
  void _onSpotsChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_refreshCallInfo());
    _scheduleSpotScores();
  }

  @override
  void didUpdateWidget(SpotsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logRevision != oldWidget.logRevision) _scheduleSpotScores();
  }

  /// Debounced entry point to [_refreshSpotScores] — every trigger goes through
  /// here, so a burst (a run of QSOs, a spot fetch landing on a log edit) costs
  /// one pass rather than one per event.
  void _scheduleSpotScores() {
    _scoreDebounce?.cancel();
    _scoreDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) unawaited(_refreshSpotScores());
    });
  }

  /// Scores every spot on the board against the operation's log, so the list
  /// can strike the ones already worked and accent what is new.
  ///
  /// Scored per operator (a merged multi-op spot carries several), deduped by
  /// [spotCandidateKey], and asked in ONE call per scorer — the runtime folds
  /// the log once and judges every candidate against it.
  ///
  /// Scores the whole merged board rather than the filtered view: filtering is
  /// a display choice the operator changes constantly, and re-scoring on each
  /// change would refold the log to learn nothing new.
  ///
  /// Scored against the CURRENT segment, like the call-info pills
  /// (`logging_controls.dart`) and for the same reason: the spots and the entry
  /// row have to agree about which activities are running. A contest started at
  /// a `start` event is named by no ref on the base operation, so without this
  /// its scorer is never selected and no spot ever shows its multipliers; one
  /// ended at a break would keep accenting them. The timeline goes along too,
  /// so the log the candidates are judged against is folded per segment —
  /// otherwise a pre-contest contact makes a fresh station read as a duplicate.
  ///
  /// Resumes from `ScoringService`'s cached scoresheets when the log has not
  /// moved since this panel last scored, which is the case for every pass the
  /// 2-minute spot refresh drives — the expensive whole-log fold is skipped and
  /// only the candidates are scored. A pass triggered BY a log change runs cold
  /// instead: that cache is written on the rescore's own debounce, so at the one
  /// moment that matters — the second after working a station — it does not yet
  /// contain the contact, and resuming from it would leave the spot unstruck
  /// until some later pass.
  Future<void> _refreshSpotScores() async {
    if (_scoringSpots) {
      _spotScoresStale = true;
      return;
    }
    _scoringSpots = true;
    try {
      do {
        _spotScoresStale = false;
        final now = DateTime.now().millisecondsSinceEpoch;
        final candidates = <String, Map<String, dynamic>>{};
        for (final spot in _mergedRawSpots) {
          for (final call in _callsIn(_callOf(spot))) {
            candidates.putIfAbsent(
              spotCandidateKey(call, spot),
              () => spotCandidateQso(call, spot, now: now),
            );
          }
        }
        if (candidates.isEmpty) {
          if (mounted && _spotScores.isNotEmpty) setState(() => _spotScores = {});
          return;
        }

        final logMoved = _scoredLogRevision != widget.logRevision;
        _scoredLogRevision = widget.logRevision;

        final segmented = SegmentedOperation.from(operation: widget.operation.data, qsos: widget.qsos);
        final scored = await widget.services.extensions.scoreCandidates(
          operation: segmented.current,
          operationUuid: widget.operation.uuid,
          candidates: candidates,
          segments: segmented.isSegmented ? segmented.payload : null,
          scoresheets: logMoved ? null : _cachedScoresheets,
          huntedRefTypes: _huntedRefTypes,
        );
        if (!mounted) return;
        // A null result means no scorer ran at all (runtime not up yet, or none
        // applies) — leave the previous verdicts alone rather than un-striking
        // every worked spot on a transient miss.
        if (scored != null) {
          setState(() {
            _spotScores = {
              for (final entry in scored.entries)
                entry.key: (
                  notices: entry.value['notices'] ?? const [],
                  alerts: entry.value['alerts'] ?? const [],
                ),
            };
          });
        }
      } while (_spotScoresStale && mounted);
    } finally {
      _scoringSpots = false;
    }
  }

  /// `ScoringService`'s cached end-of-log scoresheets, keyed by scorer, or null
  /// before the first rescore of this operation has landed. Never synced —
  /// `local_data` is device-local (DESIGN.md §4).
  Map<String, dynamic>? get _cachedScoresheets {
    final scoring = widget.operation.localData['scoring'] as Map<String, dynamic>?;
    if (scoring == null) return null;
    final sheets = {
      for (final entry in scoring.entries) entry.key: ?(entry.value as Map?)?['scoresheet'],
    };
    return sheets.isEmpty ? null : sheets;
  }

  /// The activity types this operation has hunted, cached by `ScoringService`.
  /// What makes POTA's rules apply to a chaser's spots at all — an operation
  /// that activates nothing names no activity on its own refs.
  Set<String> get _huntedRefTypes =>
      ((widget.operation.localData['huntedRefTypes'] as List?) ?? const []).whereType<String>().toSet();

  /// This operation's own station callsign, uppercased — the spot to tint
  /// rather than offer as a contact.
  String? get _ourCall {
    final call = widget.operation.stationCall.trim().toUpperCase();
    return call.isEmpty ? null : call;
  }

  ({bool worked, bool isSelf, Set<String> notices}) _flagsFor(Map<String, dynamic> spot) =>
      spotDisplayFlags(spot, scores: _spotScores, ourCall: _ourCall);

  /// The filter-row refresh button's handler: drives a fetch while showing a
  /// spinner in place of the button's icon. Pull-to-refresh calls the cache
  /// directly — the RefreshIndicator draws its own spinner.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _spots.refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<Map<String, dynamic>> get _rawSpots => [
        for (final entry in _spotsBySource.entries)
          if (!_disabledSources.contains(entry.key)) ...entry.value,
      ];

  /// Looks up (and caches) each currently-fetched spot's callsign info —
  /// whether it has a note (the "Calls of Note" grouping,
  /// `_groupCallsWithNotes`), its marker emoji (shown next to the callsign
  /// on every tile regardless of that setting), and its continent (the
  /// Continent filter). Always runs — only already-cached calls are
  /// skipped — so this is available from the very first fetch, not just
  /// once grouping has been toggled on. `online: false` — call-notes' own
  /// data comes from an already-cached, periodically-refreshed data file,
  /// not a live per-call network request, so the offline pass alone is
  /// enough here; continent also resolves offline, from the bundled DXCC
  /// country file (see `annotateCallsign` in the lookups extension) — this
  /// also skips every OTHER registered lookup hook's live network fetch
  /// (QRZ, HamDB, ...) for fields this call doesn't use, since a spot list
  /// can easily have far more distinct callsigns than the logging call
  /// field ever looks up at once.
  Future<void> _refreshCallInfo() async {
    final calls = <String>{
      for (final list in _spotsBySource.values)
        for (final spot in list) ?_callOf(spot),
    }..removeWhere(_callNotes.containsKey);
    if (calls.isEmpty) return;

    final results = await Future.wait(calls.map((call) async {
      final result = await widget.services.extensions.lookupCall(
        call,
        qso: const {},
        operation: widget.operation.data,
        online: false,
      );
      final guess = result?['guess'] as Map?;
      final emoji = guess?['emoji'] as String?;
      final hasNote = guess != null && (emoji != null || guess['note'] != null);
      final continent = guess?['continent'] as String?;
      return MapEntry(call, (hasNote: hasNote, emoji: emoji, continent: continent));
    }));
    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        _callNotes[entry.key] = entry.value;
      }
    });
  }

  /// `total` is the merged spot count after source enable/disable and the
  /// operator's enabled bands, but BEFORE band/mode/age filtering — the
  /// "of 72" in "Showing 45 of 72 spots". Standing exclusions (a disabled
  /// source, a band the operator doesn't use) decide what counts as "all";
  /// band/mode/age, which narrow temporarily, don't. Explicitly choosing a
  /// band opts out of the enabled-bands narrowing, and then every fetched
  /// spot is back in play — so "all" is everything again.
  ({List<Map<String, dynamic>> filtered, int total}) get _filteredSpotsSummary {
    final vfo = widget.services.radio.vfoA;
    final band = _bandFilter == 'auto' ? vfo.band : _bandFilter;
    // The mode filter narrows by super mode (Phone/CW/Digital): 'auto' follows
    // the VFO's current super mode, 'any' doesn't narrow, otherwise it's the
    // chosen super mode itself.
    final superMode = _modeFilter == 'auto'
        ? superModeForMode(vfo.mode)
        : (_modeFilter == 'any' ? null : _modeFilter);

    final singleBand = band != null && band != 'any';
    var spots = singleBand ? _mergedRawSpots : spotsOnEnabledBands(_mergedRawSpots, _enabledBands);
    final total = spots.length;

    if (singleBand) {
      spots = spots.where((s) => _bandOf(s) == band).toList();
    }
    if (superMode != null) {
      spots = spots.where((s) => superModeForMode(_modeOf(s)) == superMode).toList();
    }
    if (_ageMinutes != null) {
      final cutoff = DateTime.now().millisecondsSinceEpoch - _ageMinutes! * 60000;
      spots = spots.where((s) => _timeOf(s) >= cutoff).toList();
    }
    if (_disabledContinents.isNotEmpty) {
      // Per-operator so multi-op spots narrow correctly; an unresolved
      // continent never hides a spot. See spotPassesContinentFilter.
      spots = spots
          .where((s) => spotPassesContinentFilter(_callOf(s), _disabledContinents, (c) => _callNotes[c]?.continent))
          .toList();
    }
    spots = sortSpots(spots, _sortBy);
    return (filtered: spots, total: total);
  }

  /// Spot counts per continent among every currently-fetched (source
  /// enable/disable applied, nothing else) spot — the Continent filter's
  /// "${count} spots" labels. A callsign with no resolved continent yet
  /// contributes to no bucket, same omission app-polo's own count map has.
  Map<String, int> get _continentSpotCounts {
    final counts = <String, int>{};
    for (final spot in _rawSpots) {
      final continent = _callNotes[_callOf(spot)]?.continent;
      if (continent != null) counts.update(continent, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// The note emoji to show on a spot's tile — the first of its operators
  /// that has one, so a multi-op spot still shows a marker when any op is
  /// noted (the compound `their.call` never matches `_callNotes`).
  String? _noteEmojiOf(Map<String, dynamic> spot) {
    for (final call in _callsIn(_callOf(spot))) {
      final emoji = _callNotes[call]?.emoji;
      if (emoji != null) return emoji;
    }
    return null;
  }

  /// Merged spots, same as `_filteredSpotsSummary`'s `total` stage — the
  /// baseline the band/mode/age dropdown option counts are drawn from
  /// (unaffected by the currently-selected band/mode/age/continent, same
  /// "of 72" semantics used elsewhere in this panel).
  List<Map<String, dynamic>> get _mergedRawSpots => mergeSpotsByFreqAndRefs(mergeSpotsByCallAndFreq(_rawSpots));

  Map<String, int> _bandSpotCountsOf(List<Map<String, dynamic>> merged) {
    final counts = <String, int>{};
    for (final spot in merged) {
      final band = _bandOf(spot);
      if (band != null) counts.update(band, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> _modeSpotCountsOf(List<Map<String, dynamic>> merged) {
    final counts = <String, int>{};
    for (final spot in merged) {
      final superMode = superModeForMode(_modeOf(spot));
      if (superMode == null) continue;
      counts.update(superMode, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<int, int> _ageSpotCountsOf(List<Map<String, dynamic>> merged) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      for (final minutes in _ageOptionsInMinutes)
        minutes: merged.where((s) => now - _timeOf(s) <= minutes * 60000).length,
    };
  }

  Future<void> _openFilterDialog() {
    // Computed once and shared — calling _mergedRawSpots independently for
    // each count map would re-run the merge pipeline from scratch 4x per
    // dialog open.
    final merged = _mergedRawSpots;
    // Every count except the per-band ones is drawn from the spots the panel
    // would actually show, so the "any (n)" entries agree with what picking
    // them does. Per-band counts stay drawn from the full merge: they are what
    // qualifies a non-enabled band for the list at all, and what tells the
    // operator there is something out there worth switching bands for.
    final onEnabledBands = spotsOnEnabledBands(merged, _enabledBands);
    return showHaloDialog<void>(
        context: context,
        builder: (context) => _SpotsFilterDialog(
          bandFilter: _bandFilter,
          modeFilter: _modeFilter,
          ageMinutes: _ageMinutes,
          autoBand: widget.services.radio.vfoA.band,
          autoMode: superModeForMode(widget.services.radio.vfoA.mode),
          enabledBands: _enabledBands,
          totalSpotCount: onEnabledBands.length,
          bandSpotCounts: _bandSpotCountsOf(merged),
          modeSpotCounts: _modeSpotCountsOf(onEnabledBands),
          ageSpotCounts: _ageSpotCountsOf(onEnabledBands),
          sortBy: _sortBy,
          groupByBand: _groupByBand,
          groupCallsWithNotes: _groupCallsWithNotes,
          sources: _spotsBySource.keys.toList()..sort(),
          sourceNames: _sourceNames,
          sourceSpotCounts: _spotsBySource.map((key, spots) => MapEntry(key, spots.length)),
          disabledSources: _disabledSources,
          continentSpotCounts: _continentSpotCounts,
          disabledContinents: _disabledContinents,
          onBandChanged: (v) {
            setState(() => _bandFilter = v);
            unawaited(_persistFilters());
          },
          onModeChanged: (v) {
            setState(() => _modeFilter = v);
            unawaited(_persistFilters());
          },
          onAgeChanged: (v) {
            setState(() => _ageMinutes = v);
            unawaited(_persistFilters());
          },
          onSortByChanged: (v) {
            setState(() => _sortBy = v);
            unawaited(_persistFilters());
          },
          onGroupByBandChanged: (v) {
            setState(() => _groupByBand = v);
            unawaited(_persistFilters());
          },
          onGroupCallsWithNotesChanged: (v) {
            setState(() => _groupCallsWithNotes = v);
            unawaited(_persistFilters());
          },
          onToggleSource: (key) {
            setState(
              () => _disabledSources.contains(key) ? _disabledSources.remove(key) : _disabledSources.add(key),
            );
            unawaited(_persistFilters());
          },
          onToggleContinent: (code) {
            setState(
              () => _disabledContinents.contains(code)
                  ? _disabledContinents.remove(code)
                  : _disabledContinents.add(code),
            );
            unawaited(_persistFilters());
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final vfo = widget.services.radio.vfoA;

    if (_error != null) {
      return Center(child: Text(t.operation.spots.error(error: _error!), style: theme.textTheme.bodyMedium));
    }

    final summary = _filteredSpotsSummary;

    return Column(
      children: [
        _SpotsFilterPill(
          bandLabel: spotsFilterBandPillLabel(t, _bandFilter, vfo.band),
          modeLabel: spotsFilterModePillLabel(t, _modeFilter, superModeForMode(vfo.mode)),
          ageMinutes: _ageMinutes,
          filteredCount: summary.filtered.length,
          totalCount: summary.total,
          onTap: _openFilterDialog,
          onRefresh: _refresh,
          refreshing: _refreshing,
          loading: _loading,
        ),
        // Clears the bottom safe area (home indicator) itself — the status
        // footer doesn't reserve it globally; the panel fills behind.
        Expanded(
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: _buildSpotsList(context, summary.filtered),
          ),
        ),
      ],
    );
  }

  /// Sections the already-filtered `filtered` spots per the current
  /// sort/group settings, then renders the scrollable list — split out of
  /// `build()` just for readability.
  ///
  /// `groupCallsWithNotes` prepends a "Calls of Note" section (spots whose
  /// callsign has a note, per `_callNotes`) ahead of everything else —
  /// those spots still also appear in their normal section below, same as
  /// app-polo's SpotsPanel.jsx (a pinned duplicate, not an exclusive move).
  /// `_groupByBand` then decides band sections vs. one flat section; either
  /// way `filtered` is already sorted per `_sortBy`, so that order is what
  /// shows within each band (or across the whole flat list).
  Widget _buildSpotsList(BuildContext context, List<Map<String, dynamic>> filtered) {
    final t = context.t;
    final theme = Theme.of(context);

    final callsWithNotes = _groupCallsWithNotes
        ? {
            for (final entry in _callNotes.entries)
              if (entry.value.hasNote) entry.key,
          }
        : const <String>{};
    final rawSections = sectionSpots(filtered, callsWithNotes: callsWithNotes, groupByBand: _groupByBand);
    final sections = [
      for (final section in rawSections)
        (
          label:
              '${_sectionLabel(t, section.key)} - ${t.operation.spots.spotsCount(count: section.spots.length)}',
          spots: section.spots,
        ),
    ];
    // Same adaptive Hz-digit rule as qso_list.dart's DayHeaderRow/QSO rows —
    // computed across every currently-visible spot, not per-tile, so every
    // tile's Hz segment (if any) lines up at the same width.
    final hzDigits = hzDigitsNeeded(filtered.map(_freqOf));
    // The left column is only as wide as the widest frequency (and mode)
    // actually on screen — HF-only spots pack tighter than the fixed width
    // the widest microwave frequency would need. Shared across tiles so their
    // right-aligned frequencies still line up.
    final leftWidth = _spotLeftColumnWidth(context, filtered, hzDigits);

    return RefreshIndicator(
      onRefresh: _spots.refresh,
      child: filtered.isEmpty
          // While the initial fetch is still in flight (see the progress bar
          // above), "no spots" would be misleading — none have loaded yet,
          // not necessarily none exist (matches activities_view.dart's
          // own loading/empty-message split).
          ? (_loading
              ? const SizedBox.shrink()
              : ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(Space.xxl),
                    child: Center(child: Text(t.operation.spots.empty, style: theme.textTheme.bodyMedium)),
                  ),
                ]))
          : ListView(
              children: [
                for (final section in sections) ...[
                  _SpotsSectionHeader(section.label),
                  for (final spot in section.spots)
                    if (_flagsFor(spot) case final flags)
                      _SpotTile(
                        spot: spot,
                        noteEmoji: _noteEmojiOf(spot),
                        hzDigits: hzDigits,
                        leftWidth: leftWidth,
                        sortByAge: _sortBy == 'time',
                        activityControls: _activityControls,
                        worked: flags.worked,
                        isSelf: flags.isSelf,
                        notices: flags.notices,
                        onTap: widget.onSuggestQso == null
                            ? null
                            : () => widget.onSuggestQso!(suggestedQsoFromSpot(spot)),
                      ),
                ],
              ],
            ),
    );
  }

  /// Maps a `sectionSpots` section key to its display label. The flat
  /// `'spots'` section reads as the actual band once the Band filter has
  /// narrowed to one — "All Spots" while filtered to a single band would
  /// misleadingly suggest the filter had no effect.
  String _sectionLabel(Translations t, String key) => switch (key) {
        'notes' => t.operation.spots.callsOfNote,
        'spots' => _isSingleBandFilter ? _bandFilter : t.operation.spots.allSpots,
        '?' => t.operation.spots.unknownBand,
        _ => key,
      };

  /// Whether the Band filter has narrowed to one specific band ('auto' and
  /// 'any' both leave multiple bands possible).
  bool get _isSingleBandFilter => _bandFilter != 'auto' && _bandFilter != 'any';
}

/// A section group row (a band or "Calls of Note"), styled to match
/// `qso_list.dart`'s `DayHeaderRow` (same height,
/// background, and bottom border) so the two lists read as the same kind
/// of grouping, not two different UI languages.
class _SpotsSectionHeader extends StatelessWidget {
  final String label;

  const _SpotsSectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      // As tall as a QSO list day header, read from the shared metric rather
      // than copied: the two read as one list, and a private constant here
      // went stale the moment either side moved.
      constraints: BoxConstraints(minHeight: LayoutDensity.metricsOf(context).sectionHeaderHeight),
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.surfaceContainerHighest,
      foregroundDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 3),
        ),
      ),
      // Background stays edge-to-edge; the label insets by the split's
      // grab-strip clearance and the real device inset, like the spot rows
      // below it.
      padding: PaneSafeArea.symmetricOf(
        context,
        horizontal: Space.lg,
        vertical: LayoutDensity.metricsOf(context).qsoRowPaddingV,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// The narrowest left-column width that fits every currently-visible spot's
/// frequency and mode without clipping — measured with the same text styles
/// [_SpotTile] renders (RobotoMono is tabular, so `'0'`s stand in for any
/// digits). HF-only lists come out much tighter than the fixed width the
/// widest microwave frequency would need, while every row's right-aligned
/// frequency still lines up. Shared across tiles, recomputed per rebuild.
double _spotLeftColumnWidth(BuildContext context, List<Map<String, dynamic>> spots, int hzDigits) {
  final mono = haloMonoStyle(context, fontSize: 14);
  final boldMono = haloMonoStyle(context, fontSize: 14, fontWeight: FontWeight.w700);
  final hzMono = haloMonoStyle(context, fontSize: 14 * 0.8);
  final modeStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();

  var maxMhzLen = 0;
  final modes = <String>{};
  for (final spot in spots) {
    final freq = _freqOf(spot);
    if (freq != null) {
      final len = freqDisplayParts(freq, hzDigits: hzDigits).mhz.length;
      if (len > maxMhzLen) maxMhzLen = len;
    }
    final mode = _modeOf(spot);
    if (mode != null && mode.isNotEmpty) modes.add(mode);
  }

  var width = 0.0;
  if (maxMhzLen > 0) {
    // Mirror _SpotTile's freqField piece by piece — a Row of separate Texts:
    // bold MHz, '.', a 3-digit kHz, and (when shown) '.' + a 0.8×-size Hz
    // segment — each measured the way a Text lays it out (see [textWidth], which
    // folds in the ambient DefaultTextStyle's letter-spacing and text scaler so
    // the cell isn't a hair too tight).
    width = textWidth(context, '0' * maxMhzLen, boldMono) +
        textWidth(context, '.', mono) +
        textWidth(context, '000', mono);
    if (hzDigits > 0) {
      width += textWidth(context, '.', mono) + textWidth(context, '0' * hzDigits, hzMono);
    }
  }
  // The mode sits below the frequency in the same column, so it can't clip either.
  for (final mode in modes) {
    final w = textWidth(context, mode, modeStyle);
    if (w > width) width = w;
  }
  return width.ceilToDouble();
}

/// Narrow freq/band/mode column on the left, wide call/notes/refs column on
/// the right — a deliberately different shape from `qso_list.dart`'s
/// column-per-field row (spots carry a variable-length reference label
/// that a fixed column grid can't accommodate), but reusing that row's
/// frequency styling (bold MHz, dot-separated kHz/Hz) so the two lists
/// still read as the same visual language.
class _SpotTile extends StatelessWidget {
  final Map<String, dynamic> spot;
  final String? noteEmoji;
  final int hzDigits;

  /// Width of the fixed left column (freq over mode), sized by the panel to
  /// the widest frequency/mode currently on screen and shared across tiles so
  /// their right-aligned frequencies line up.
  final double leftWidth;

  /// When sorting by age, the age (top-right of the row) is drawn bold so the
  /// value you're ordering by stands out.
  final bool sortByAge;
  final List<Map<String, dynamic>> activityControls;
  final VoidCallback? onTap;

  /// Every operator on this spot has already been worked on this band and mode
  /// — the `duplicate` alert from [SpotsPanel]'s candidate scoring. Struck
  /// through and dimmed, per app-polo's SpotItem `type: 'duplicate'`.
  final bool worked;

  /// This spot is OUR station's own — tinted and dimmed rather than struck,
  /// since it isn't a contact to make (app-polo's `type: 'self'`).
  final bool isSelf;

  /// Scoring notices for this spot's operators, merged across every scorer.
  /// Only `newBand`, `newMode`, `newDay`, `newRef` and `newMult` are drawn —
  /// each accents the field it speaks about (see `build`). The core scorer's
  /// `newDXCC`/`newState`/`newProvince` arrive here too and are deliberately
  /// ignored: they belong to the call you are typing, and on a whole board they
  /// would accent most rows most of the time.
  final Set<String> notices;

  const _SpotTile({
    required this.spot,
    this.noteEmoji,
    this.hzDigits = 0,
    this.leftWidth = 120,
    this.sortByAge = false,
    this.activityControls = const [],
    this.onTap,
    this.worked = false,
    this.isSelf = false,
    this.notices = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final haloColors = HaLoColors.of(context);

    // The row-wide accents, applied by folding them into the two base styles
    // every field below derives from. app-polo's SpotItem spreads a
    // `commonStyle` across each of its Texts for the same effect.
    // The dim is folded into every colour rather than wrapped around the row in
    // an `Opacity`: that widget forces a saveLayer per row, and on a board where
    // most spots are worked that is a compositing layer for every visible row on
    // every frame of a scroll.
    final dim = worked ? 0.6 : (isSelf ? 0.7 : 1.0);
    Color faded(Color color) => dim == 1.0 ? color : color.withValues(alpha: color.a * dim);

    final baseColor = faded(isSelf ? theme.colorScheme.tertiary : theme.colorScheme.onSurface);
    final decoration = worked ? TextDecoration.lineThrough : null;

    final mono = haloMonoStyle(context, fontSize: 14, color: baseColor)
        .copyWith(decoration: decoration, decorationColor: baseColor);
    // Band/mode and the reference label are names, not structured data —
    // proportional, like everywhere else names/labels appear (e.g. the DX
    // flag/state field in qso_list.dart), unlike the monospace fields
    // (freq, callsign) they sit next to.
    final outlineColor = faded(theme.colorScheme.outline);
    final proportional = theme.textTheme.bodySmall
        ?.copyWith(color: isSelf ? baseColor : outlineColor)
        .copyWith(decoration: decoration, decorationColor: baseColor);

    // Per-notice accents, ported from app-polo's SpotItem. Applied in its
    // order, so `newMult` wins the callsign and reference label from the
    // others — a fresh multiplier is the one worth breaking a run for.
    //
    // `newBand` accents the FREQUENCY rather than a band field: this row shows
    // the frequency and lets it imply the band, where app-polo's shows both.
    final important = faded(haloColors.important);
    final multiplier = faded(haloColors.spotMultiplier);
    final freqAccent = notices.contains('newBand') ? important : null;
    final modeAccent = notices.contains('newMode') ? important : null;
    final callAccent = notices.contains('newMult') ? multiplier : null;
    final refAccent = notices.contains('newMult')
        ? multiplier
        : (notices.contains('newDay') || notices.contains('newRef') ? important : null);
    // An accented field is bold as well as colored — color alone is not a
    // signal an operator can rely on (docs/design/user-interface.md), and at
    // spot-row size the weight is what actually catches the eye.
    TextStyle? accented(TextStyle? style, Color? accent) =>
        accent == null ? style : style?.copyWith(color: accent, fontWeight: FontWeight.w700);

    final freqKHz = _freqOf(spot);
    final Widget freqField;
    if (freqKHz == null) {
      // No frequency to show on the top line — the mode still shows below it.
      freqField = const SizedBox.shrink();
    } else {
      final parts = freqDisplayParts(freqKHz, hzDigits: hzDigits);
      final freqStyle = accented(mono, freqAccent) ?? mono;
      freqField = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(parts.mhz, style: freqStyle.copyWith(fontWeight: FontWeight.w700)),
          Text('.', style: freqStyle),
          Text(parts.khz, style: freqStyle),
          if (parts.hz != null) ...[
            Text('.', style: freqStyle),
            Text(parts.hz!, style: freqStyle.copyWith(fontSize: (freqStyle.fontSize ?? 14) * 0.8)),
          ],
        ],
      );
    }

    final refs = _refsOf(spot);
    final refType = refs.isEmpty ? null : refs.first['type'] as String?;
    final refIcon = iconForRefType(activityControls, refType) ?? _iconOf(spot) ?? 'radio-tower';

    // Age sits at the top-right of the row, right-aligned, bold when it's the
    // sort key. Re-derived once a second (scoped to this label via the shared
    // wall-clock heartbeat) so ages don't sit stale between spot refetches —
    // every visible row's label updates in the same frame.
    final ageField = OncePerSecond(builder: (_, _) => Text(
      _timeAgo(_timeOf(spot)),
      style: proportional?.copyWith(fontWeight: sortByAge ? FontWeight.w700 : null),
    ));

    // One row line: the fixed-width left column (right-aligned, sized by the
    // panel to the widest freq/mode on screen) beside the expanded right
    // column, baseline-aligned so the freq/mode text sits on the same baseline
    // as the call/label across the gap.
    Widget line(Widget left, Widget right) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: leftWidth,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [left]),
            ),
            const SizedBox(width: Space.xl),
            Expanded(child: right),
          ],
        );

    final callLine = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  _callOf(spot) ?? '?',
                  style: (accented(mono, callAccent) ?? mono).copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (noteEmoji != null) ...[
                const SizedBox(width: Space.xs),
                Text(noteEmoji!, style: emojiStyle()),
              ],
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        ageField,
      ],
    );

    final labelLine = _labelOf(spot) == null
        ? const SizedBox.shrink()
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(
                resolveIconName(refIcon),
                size: mono.fontSize,
                color: refAccent ?? (isSelf ? baseColor : theme.colorScheme.outline),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  _labelOf(spot)!,
                  style: (accented(proportional, refAccent) ?? proportional)?.copyWith(fontSize: mono.fontSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final tile = Padding(
      // Rows render edge-to-edge (the ink below spans the full width); the
      // content inset grows by the split's grab-strip clearance on the left
      // and the real device inset on both edges
      // so nothing interactive sits under the divider overlay or a cutout.
      padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(freqField, callLine),
          const SizedBox(height: Space.xxs),
          line(Text(_modeOf(spot) ?? '', style: accented(proportional, modeAccent) ?? proportional), labelLine),
        ],
      ),
    );

    // app-polo's SpotItem dims these two cases through its text styles; here
    // one layer covers the icon too, which carries the same accent.
    final dimmed = worked ? 0.6 : (isSelf ? 0.7 : null);
    final body = dimmed == null ? tile : Opacity(opacity: dimmed, child: tile);

    final row = onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: body),
          );
    // A hairline divider between rows, painted over the row's bottom edge
    // (foreground) so it adds no height — lighter than the section header's
    // 3px rule so rows read as subdivisions within a group.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: row,
    );
  }
}

class _SpotsFilterPill extends StatelessWidget {
  final String bandLabel;
  final String modeLabel;
  final int? ageMinutes;
  final int filteredCount;
  final int totalCount;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  final bool refreshing;

  /// Whether the initial spots fetch is still in flight — shows the
  /// progress bar reserved at the bottom of this pill's own background.
  final bool loading;

  const _SpotsFilterPill({
    required this.bandLabel,
    required this.modeLabel,
    required this.ageMinutes,
    required this.filteredCount,
    required this.totalCount,
    required this.onTap,
    required this.onRefresh,
    required this.refreshing,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final countLabel = filteredCount == totalCount
        ? t.operation.spots.spotsCount(count: totalCount)
        : t.operation.spots.spotsCountFiltered(count: filteredCount, total: totalCount);

    return Container(
      // Same background as the main logging control area (logging_controls.dart's
      // outer `Material`), so this toggle row reads as the same kind of UI chrome.
      color: theme.colorScheme.tertiaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // Left/right clear the real device inset
            // — the row's own content is centered, but a wide enough pane on a
            // device with a landscape cutout could still push a pill under it.
            padding: PaneSafeArea.symmetricOf(context, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Extra breathing room above and below the pill row.
                Padding(
                  padding: EdgeInsets.symmetric(vertical: LayoutDensity.metricsOf(context).spotTilePaddingV),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Desktop-only manual refresh — mobile refreshes by
                      // pull-to-refresh instead (RefreshIndicator on the list below).
                      if (!isMobilePlatform) ...[
                        _FilterInfoPill(
                          icon: 'refresh',
                          loading: refreshing,
                          onTap: refreshing ? null : onRefresh,
                        ),
                        const SizedBox(width: Space.sm),
                      ],
                      // The only pill that can grow; flex it so it ellipsizes on a
                      // narrow panel rather than overflowing the row.
                      Flexible(child: _FilterInfoPill(icon: 'radio', label: '$bandLabel • $modeLabel', onTap: onTap)),
                      if (ageMinutes != null) ...[
                        const SizedBox(width: Space.sm),
                        _FilterInfoPill(icon: 'clock', label: '${ageMinutes}m', onTap: onTap),
                      ],
                      const SizedBox(width: Space.sm),
                      _FilterInfoPill(icon: 'tune', onTap: onTap),
                    ],
                  ),
                ),
                Text(
                  countLabel,
                  // Two points larger than the default caption so the spot count
                  // reads clearly under the pills.
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) + 2,
                  ),
                ),
              ],
            ),
          ),
          // Reserved whether or not the initial fetch is in flight —
          // lives at the bottom of THIS pill's own (salmon/tertiaryContainer)
          // background, flush with its lower edge, rather than floating on
          // the plain scaffold background below the whole filter area.
          SizedBox(
            height: _spotsProgressHeight,
            child: loading ? const LinearProgressIndicator(minHeight: _spotsProgressHeight) : null,
          ),
        ],
      ),
    );
  }
}

/// A small icon (+ optional text) pill — the band/mode/age filter summaries
/// shown next to the tune button, and (icon-only, tappable) the tune button
/// itself.
class _FilterInfoPill extends StatelessWidget {
  final String icon;
  final String? label;
  final VoidCallback? onTap;

  /// Swaps the icon for a spinner (same footprint) — used by the refresh
  /// button while a fetch is in flight.
  final bool loading;

  const _FilterInfoPill({required this.icon, this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final effectiveColor = theme.colorScheme.onTertiaryContainer;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: poloColors.tertiaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      // Fixed height regardless of whether `label` is present, so the
      // icon-only tune pill matches the icon+text filter-summary pills
      // instead of coming out shorter.
      child: SizedBox(
        height: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: effectiveColor),
              )
            else
              Icon(resolveIconName(icon), size: 14, color: effectiveColor),
            if (label != null) ...[
              const SizedBox(width: Space.xs),
              // Same size as the secondary logging controls' own pills
              // (SecondaryControlRow's Chip, which uses the ambient
              // ChipTheme's default labelLarge — no explicit style of its
              // own to match against). Flexible + ellipsis so a long label
              // (e.g. "All Bands • All Modes") shrinks instead of overflowing
              // when the pill is width-constrained on a narrow panel.
              Flexible(
                child: Text(
                  label!,
                  style: theme.textTheme.labelLarge?.copyWith(color: effectiveColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: pill,
      ),
    );
  }
}

/// Continent codes in the order they're offered — @ham2k/lib-dxcc-data's
/// `CONTINENTS` insertion order, ported by hand since that table lives in
/// the JS extension runtime, not halo_core.
const _continentCodes = ['AF', 'AS', 'EU', 'NA', 'OC', 'SA', 'AN'];

/// Top-level (not a `_SpotsFilterDialogState` method) so `_SpotsFilterPill` can
/// use the exact same wording for its collapsed summary — "Auto (20m)"/"All
/// Bands", never a bare "auto"/"any".
String _bandOptionLabel(Translations t, String option, String? autoBand) => switch (option) {
      'auto' => autoBand != null ? t.operation.spots.autoValue(value: autoBand) : t.operation.spots.auto,
      'any' => t.operation.spots.allBands,
      _ => option,
    };

/// `autoMode` is the VFO's current *super* mode (Phone/CW/Digital), so "Auto"
/// reads "Auto (Phone)" — the running band/super-mode the filter follows.
String _modeOptionLabel(Translations t, String option, String? autoMode) => switch (option) {
      'auto' => autoMode != null ? t.operation.spots.autoValue(value: autoMode) : t.operation.spots.auto,
      'any' => t.operation.spots.allModes,
      _ => option,
    };

/// The band/mode summary for the collapsed filter pill: the RESOLVED value
/// only (e.g. "20m", "SSB"), never "Auto (20m)" — on the compact status pill
/// the "Auto" prefix is just noise. (The filter dialog's dropdowns keep the
/// "Auto (…)" wording via [_bandOptionLabel]/[_modeOptionLabel], where it's
/// meaningful.) 'auto' with no resolved band/mode falls back to the all-bands/
/// all-modes label rather than reintroducing "Auto". Public for unit testing.
String spotsFilterBandPillLabel(Translations t, String option, String? autoBand) => switch (option) {
      'auto' => autoBand ?? t.operation.spots.allBands,
      'any' => t.operation.spots.allBands,
      _ => option,
    };

String spotsFilterModePillLabel(Translations t, String option, String? autoMode) => switch (option) {
      'auto' => autoMode ?? t.operation.spots.allModes,
      'any' => t.operation.spots.allModes,
      _ => option,
    };

/// Shared width for the band/mode/age dropdowns so all three line up — 2/3
/// of the dialog's own content width (400), unlike the sorting
/// SegmentedButton which spans it fully.
const double _dropdownWidth = 400 * 2 / 3;

/// The spots filter dialog. Keeps its own local copy of the filter values so
/// widgets that don't self-manage their displayed state (`Switch`) still
/// update live while the dialog is open — a dialog route's content lives in
/// the Navigator's overlay, not as a descendant of `SpotsPanel`, so
/// `_SpotsPanelState.setState` alone wouldn't rebuild it. Every local change
/// is also immediately forwarded to the corresponding `on*Changed` callback
/// so `SpotsPanel`'s own filtering stays in sync without waiting for the
/// dialog to close.
class _SpotsFilterDialog extends StatefulWidget {
  final String bandFilter;
  final String modeFilter;
  final int? ageMinutes;
  final String? autoBand;
  final String? autoMode;
  /// The operator's enabled bands, which decide the Band dropdown's entries
  /// (see [spotsFilterBandOptions]).
  final Set<String> enabledBands;
  final int totalSpotCount;
  final Map<String, int> bandSpotCounts;
  final Map<String, int> modeSpotCounts;
  final Map<int, int> ageSpotCounts;
  final String sortBy;
  final bool groupByBand;
  final bool groupCallsWithNotes;
  final List<String> sources;
  final Map<String, String> sourceNames;
  final Map<String, int> sourceSpotCounts;
  final Set<String> disabledSources;
  final Map<String, int> continentSpotCounts;
  final Set<String> disabledContinents;
  final ValueChanged<String> onBandChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<int?> onAgeChanged;
  final ValueChanged<String> onSortByChanged;
  final ValueChanged<bool> onGroupByBandChanged;
  final ValueChanged<bool> onGroupCallsWithNotesChanged;
  final ValueChanged<String> onToggleSource;
  final ValueChanged<String> onToggleContinent;

  const _SpotsFilterDialog({
    required this.bandFilter,
    required this.modeFilter,
    required this.ageMinutes,
    required this.autoBand,
    required this.autoMode,
    required this.enabledBands,
    required this.totalSpotCount,
    required this.bandSpotCounts,
    required this.modeSpotCounts,
    required this.ageSpotCounts,
    required this.sortBy,
    required this.groupByBand,
    required this.groupCallsWithNotes,
    required this.sources,
    required this.sourceNames,
    required this.sourceSpotCounts,
    required this.disabledSources,
    required this.continentSpotCounts,
    required this.disabledContinents,
    required this.onBandChanged,
    required this.onModeChanged,
    required this.onAgeChanged,
    required this.onSortByChanged,
    required this.onGroupByBandChanged,
    required this.onGroupCallsWithNotesChanged,
    required this.onToggleSource,
    required this.onToggleContinent,
  });

  @override
  State<_SpotsFilterDialog> createState() => _SpotsFilterDialogState();
}

class _SpotsFilterDialogState extends State<_SpotsFilterDialog> {
  late String _bandFilter = widget.bandFilter;
  late String _modeFilter = widget.modeFilter;
  late int? _ageMinutes = widget.ageMinutes;
  late String _sortBy = widget.sortBy;
  late bool _groupByBand = widget.groupByBand;
  late bool _groupCallsWithNotes = widget.groupCallsWithNotes;
  late final Set<String> _disabledSources = {...widget.disabledSources};
  late final Set<String> _disabledContinents = {...widget.disabledContinents};

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // 'auto' first (it's the default and tracks the live VFO), then 'any'.
    final bandOptions = [
      'auto',
      'any',
      ...spotsFilterBandOptions(
        enabledBands: widget.enabledBands,
        bandSpotCounts: widget.bandSpotCounts,
        selected: _bandFilter,
      ),
    ];
    final modeOptions = ['auto', 'any', ..._superModes];

    return HaloDialog(
      wide: true,
      title: Text(t.operation.spots.filters.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: DropdownMenu<String>(
                  trailingIcon: dropdownTrailingIcon,
                  selectedTrailingIcon: dropdownSelectedTrailingIcon,
                  initialSelection: _bandFilter,
                  width: _dropdownWidth,
                  menuHeight: dropdownMenuMaxHeight(context),
                  // Pick-only; search's rebuild-time scrollToHighlight would snap
                  // the open menu back to the selection whenever spots stream in.
                  enableSearch: false,
                  label: Text(t.operation.spots.filters.band),
                  dropdownMenuEntries: [
                    for (final option in bandOptions)
                      DropdownMenuEntry(value: option, label: _bandEntryLabel(t, option)),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      setState(() => _bandFilter = value);
                      widget.onBandChanged(value);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: DropdownMenu<String>(
                  trailingIcon: dropdownTrailingIcon,
                  selectedTrailingIcon: dropdownSelectedTrailingIcon,
                  initialSelection: _modeFilter,
                  width: _dropdownWidth,
                  menuHeight: dropdownMenuMaxHeight(context),
                  enableSearch: false,
                  label: Text(t.operation.spots.filters.mode),
                  dropdownMenuEntries: [
                    for (final option in modeOptions)
                      DropdownMenuEntry(value: option, label: _modeEntryLabel(t, option)),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      setState(() => _modeFilter = value);
                      widget.onModeChanged(value);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: DropdownMenu<int?>(
                  trailingIcon: dropdownTrailingIcon,
                  selectedTrailingIcon: dropdownSelectedTrailingIcon,
                  initialSelection: _ageMinutes,
                  width: _dropdownWidth,
                  menuHeight: dropdownMenuMaxHeight(context),
                  enableSearch: false,
                  label: Text(t.operation.spots.filters.age),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(value: null, label: '${t.operation.spots.any} (${widget.totalSpotCount})'),
                    for (final minutes in _ageOptionsInMinutes)
                      DropdownMenuEntry(
                        value: minutes,
                        label:
                            '${t.operation.spots.ageMinutes(minutes: minutes)} (${widget.ageSpotCounts[minutes] ?? 0})',
                      ),
                  ],
                  onSelected: (value) {
                    setState(() => _ageMinutes = value);
                    widget.onAgeChanged(value);
                  },
                ),
              ),
              SectionHeader(t.operation.spots.filters.sorting),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
                child: SegmentedButton<String>(
                  // MDI-only UI: skip the framework's Material check on the
                  // selected segment (same as settings_view).
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'frequency', label: Text(t.operation.spots.filters.sortByFrequency)),
                    ButtonSegment(value: 'time', label: Text(t.operation.spots.filters.sortByTime)),
                  ],
                  selected: {_sortBy},
                  onSelectionChanged: (selection) {
                    setState(() => _sortBy = selection.first);
                    widget.onSortByChanged(selection.first);
                  },
                ),
              ),
              ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -4),
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
                // Grouping by band is meaningless once the Band filter has
                // already narrowed to one band — every spot would land in
                // the same single section anyway.
                enabled: !_isSingleBandFilter,
                title: Text(t.operation.spots.filters.groupByBand),
                trailing: Switch(
                  value: _groupByBand,
                  onChanged: _isSingleBandFilter
                      ? null
                      : (value) {
                          setState(() => _groupByBand = value);
                          widget.onGroupByBandChanged(value);
                        },
                ),
              ),
              ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -4),
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
                title: Text(t.operation.spots.filters.groupCallsWithNotes),
                trailing: Switch(
                  value: _groupCallsWithNotes,
                  onChanged: (value) {
                    setState(() => _groupCallsWithNotes = value);
                    widget.onGroupCallsWithNotesChanged(value);
                  },
                ),
              ),
              if (widget.sources.isNotEmpty) ...[
                SectionHeader(t.operation.spots.filters.sources),
                for (final source in widget.sources)
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    title: Text(
                      widget.sourceNames[source] ?? source,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.operation.spots.spotsCount(count: widget.sourceSpotCounts[source] ?? 0)),
                        const SizedBox(width: Space.md),
                        Switch(
                          value: !_disabledSources.contains(source),
                          onChanged: (_) {
                            setState(
                              () => _disabledSources.contains(source)
                                  ? _disabledSources.remove(source)
                                  : _disabledSources.add(source),
                            );
                            widget.onToggleSource(source);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
              SectionHeader(t.operation.spots.filters.continent),
              for (final code in _continentCodes)
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -4),
                  contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
                  title: Text(
                    _continentLabel(t, code),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.operation.spots.spotsCount(count: widget.continentSpotCounts[code] ?? 0)),
                      const SizedBox(width: Space.md),
                      Switch(
                        value: !_disabledContinents.contains(code),
                        onChanged: (_) {
                          setState(
                            () => _disabledContinents.contains(code)
                                ? _disabledContinents.remove(code)
                                : _disabledContinents.add(code),
                          );
                          widget.onToggleContinent(code);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.apply)),
      ],
    );
  }

  /// Whether the Band filter has narrowed to one specific band ('auto' and
  /// 'any' both leave multiple bands possible).
  bool get _isSingleBandFilter => _bandFilter != 'auto' && _bandFilter != 'any';

  /// `_bandOptionLabel` plus a "(N)" spot count — every option except
  /// "auto", which has no fixed count to show (it tracks the live VFO).
  String _bandEntryLabel(Translations t, String option) {
    final label = _bandOptionLabel(t, option, widget.autoBand);
    if (option == 'auto') return label;
    final count = option == 'any' ? widget.totalSpotCount : (widget.bandSpotCounts[option] ?? 0);
    return '$label ($count)';
  }

  String _modeEntryLabel(Translations t, String option) {
    final label = _modeOptionLabel(t, option, widget.autoMode);
    if (option == 'auto') return label;
    final count = option == 'any' ? widget.totalSpotCount : (widget.modeSpotCounts[option] ?? 0);
    return '$label ($count)';
  }

  String _continentLabel(Translations t, String code) => switch (code) {
        'AF' => t.operation.spots.continents.af,
        'AS' => t.operation.spots.continents.as,
        'EU' => t.operation.spots.continents.eu,
        'NA' => t.operation.spots.continents.na,
        'OC' => t.operation.spots.continents.oc,
        'SA' => t.operation.spots.continents.sa,
        'AN' => t.operation.spots.continents.an,
        _ => code,
      };
}
