// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spots Panel (ham2k/app-halo-dist#9): fetches spots from every extension's
// `spots` hook, combines/dedupes across sources, groups by band, and lets
// the user filter by band/mode/age/source via a dialog opened from the
// spots-count row. Ported from app-polo's SpotsPanel.jsx, notably its
// two-pass combining algorithm (merge same call+freq's refs, then merge
// same freq+refs' calls) and its 0.5kHz/30min and 0.1kHz/10min tolerances.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../../i18n/strings.g.dart';

/// Modes excluded from the callsign-merge pass (SpotsPanel.jsx: too many
/// simultaneous operators on one frequency to safely merge callsigns). A
/// narrower set than the "Digital" super mode ([superModeForMode]) — it's only
/// about which modes are unsafe to merge, not the mode filter's grouping.
const _digitalModes = {'FT8', 'FT4', 'RTTY', 'DATA'};

const _ageOptionsInMinutes = [15, 30, 60, 180];

String? _callOf(Map<String, dynamic> spot) => (spot['their'] as Map?)?['call'] as String?;
/// The individual operator callsigns within a `their.call` — a comma-joined
/// compound for a multi-op spot (see `mergeSpotsByFreqAndRefs`), a single call
/// otherwise. Empty segments are dropped. Everything that keys off `_callNotes`
/// (per single call) must iterate these, not the raw compound string (#316).
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
/// again in their normal section below, never removed from it); then one
/// section per band the spots belong to, band-list-ordered with unmatched
/// spots keyed `'?'`. Each band keeps `spots`' incoming order, so whichever
/// sort the caller applied (frequency or most-recent-first) is preserved
/// WITHIN each band. Empty sections are omitted. Section `key` is a stable
/// identifier, not a display label — the caller maps it to translated text.
/// Public for `spots_panel_merge_test.dart`.
List<({String key, List<Map<String, dynamic>> spots})> sectionSpots(
  List<Map<String, dynamic>> spots, {
  required Set<String> callsWithNotes,
}) {
  final sections = <({String key, List<Map<String, dynamic>> spots})>[];

  if (callsWithNotes.isNotEmpty) {
    // Pin a multi-op spot when ANY of its operators has a note (#316) — a
    // compound `their.call` never matches the per-call `callsWithNotes` set.
    final noted = spots.where((s) => _callsIn(_callOf(s)).any(callsWithNotes.contains)).toList();
    if (noted.isNotEmpty) sections.add((key: 'notes', spots: noted));
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
/// `their.call` as one key was the bug behind #316: it never matched the
/// per-call `continentOf` map, so every multi-op spot looked
/// permanently-unresolved and slipped through the filter untouched. Keeping
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

String _timeAgo(int millis) {
  final seconds = (DateTime.now().millisecondsSinceEpoch - millis) ~/ 1000;
  if (seconds < 60) return '${seconds}s ago';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';
  return '${minutes ~/ 60}h${minutes % 60}m ago';
}

class SpotsPanel extends StatefulWidget {
  final Operation operation;
  final HaLoServices services;
  final ValueChanged<Map<String, dynamic>>? onSuggestQso;

  const SpotsPanel({super.key, required this.operation, required this.services, this.onSuggestQso});

  @override
  State<SpotsPanel> createState() => _SpotsPanelState();
}

class _SpotsPanelState extends State<SpotsPanel> {
  bool _loading = true;
  String? _error;
  final Map<String, List<Map<String, dynamic>>> _spotsBySource = {};
  Map<String, String> _sourceNames = {};
  List<Map<String, dynamic>> _activityControls = [];
  Timer? _timer;
  Future<void>? _inFlightFetch;
  bool _refreshing = false;

  String _bandFilter = 'auto';
  String _modeFilter = 'auto';
  int? _ageMinutes;
  final Set<String> _disabledSources = {};
  final Set<String> _disabledContinents = {};
  String _sortBy = 'frequency';
  bool _groupCallsWithNotes = false;
  final Map<String, ({bool hasNote, String? emoji, String? continent})> _callNotes = {};
  String? _lastVfoBand;
  String? _lastVfoMode;

  @override
  void initState() {
    super.initState();
    _loadPersistedFilters();
    _lastVfoBand = widget.services.radio.vfoA.band;
    _lastVfoMode = widget.services.radio.vfoA.mode;
    widget.services.radio.addListener(_onVfoChanged);
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _fetch());
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
    widget.services.radio.removeListener(_onVfoChanged);
    _timer?.cancel();
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
    _groupCallsWithNotes = decoded['groupCallsWithNotes'] as bool? ?? _groupCallsWithNotes;
  }

  Future<void> _persistFilters() => widget.services.settings.setSpottingFilters({
        'bandFilter': _bandFilter,
        'modeFilter': _modeFilter,
        'ageMinutes': _ageMinutes,
        'disabledSources': _disabledSources.toList(),
        'disabledContinents': _disabledContinents.toList(),
        'sortBy': _sortBy,
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

  /// Coalesces overlapping calls (the 2-minute timer tick and a manual
  /// pull-to-refresh) into the one in-flight request instead of doubling
  /// the fan-out to every spots-hook extension.
  Future<void> _fetch() => _inFlightFetch ??= _doFetch().whenComplete(() => _inFlightFetch = null);

  /// The filter-row refresh button's handler: drives a fetch while showing a
  /// spinner in place of the button's icon. Pull-to-refresh keeps using
  /// [_fetch] directly — the RefreshIndicator draws its own spinner.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _fetch();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _doFetch() async {
    try {
      final spots = await widget.services.extensions.getSpots();
      if (!mounted) return;
      setState(() {
        _spotsBySource.clear();
        for (final spot in spots) {
          final hookKey = spot['hookKey'] as String? ?? 'unknown';
          _spotsBySource.putIfAbsent(hookKey, () => []).add(spot);
        }
        _loading = false;
        _error = null;
      });
      unawaited(_refreshCallInfo());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  /// `total` is the merged spot count after source enable/disable but
  /// BEFORE band/mode/age filtering — the "of 72" in "Showing 45 of 72
  /// spots" — so toggling a source (an intentional exclusion) changes what
  /// counts as "all", while band/mode/age (temporary narrowing) don't.
  ({List<Map<String, dynamic>> filtered, int total}) get _filteredSpotsSummary {
    final vfo = widget.services.radio.vfoA;
    final band = _bandFilter == 'auto' ? vfo.band : _bandFilter;
    // The mode filter narrows by super mode (Phone/CW/Digital): 'auto' follows
    // the VFO's current super mode, 'any' doesn't narrow, otherwise it's the
    // chosen super mode itself.
    final superMode = _modeFilter == 'auto'
        ? superModeForMode(vfo.mode)
        : (_modeFilter == 'any' ? null : _modeFilter);

    var spots = _mergedRawSpots;
    final total = spots.length;

    if (band != null && band != 'any') {
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
      // Per-operator so multi-op spots narrow correctly (#316); an unresolved
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
  /// noted (#316; the compound `their.call` never matched `_callNotes`).
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
    // Computed once and shared — each of these used to independently call
    // _mergedRawSpots (re-running the merge pipeline from scratch every
    // time), so opening the dialog re-merged the same spot list 4x.
    final merged = _mergedRawSpots;
    return showHaloDialog<void>(
        context: context,
        builder: (context) => _SpotsFilterDialog(
          bandFilter: _bandFilter,
          modeFilter: _modeFilter,
          ageMinutes: _ageMinutes,
          autoBand: widget.services.radio.vfoA.band,
          autoMode: superModeForMode(widget.services.radio.vfoA.mode),
          totalSpotCount: merged.length,
          bandSpotCounts: _bandSpotCountsOf(merged),
          modeSpotCounts: _modeSpotCountsOf(merged),
          ageSpotCounts: _ageSpotCountsOf(merged),
          sortBy: _sortBy,
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

    if (_loading) return const Center(child: CircularProgressIndicator());
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
        ),
        // Clears the bottom safe area (home indicator) itself, now that the
        // status footer no longer reserves it globally; the panel fills behind.
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
  /// `sortBy == 'time'` then shows one flat, already time-sorted section;
  /// otherwise spots (already frequency-sorted) are grouped by band.
  Widget _buildSpotsList(BuildContext context, List<Map<String, dynamic>> filtered) {
    final t = context.t;
    final theme = Theme.of(context);

    final callsWithNotes = _groupCallsWithNotes
        ? {
            for (final entry in _callNotes.entries)
              if (entry.value.hasNote) entry.key,
          }
        : const <String>{};
    final rawSections = sectionSpots(filtered, callsWithNotes: callsWithNotes);
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
      onRefresh: _fetch,
      child: filtered.isEmpty
          ? ListView(children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(t.operation.spots.empty, style: theme.textTheme.bodyMedium)),
              ),
            ])
          : ListView(
              children: [
                for (final section in sections) ...[
                  _SpotsSectionHeader(section.label),
                  for (final spot in section.spots)
                    _SpotTile(
                      spot: spot,
                      noteEmoji: _noteEmojiOf(spot),
                      hzDigits: hzDigits,
                      leftWidth: leftWidth,
                      sortByAge: _sortBy == 'time',
                      activityControls: _activityControls,
                      onTap: widget.onSuggestQso == null
                          ? null
                          : () => widget.onSuggestQso!(suggestedQsoFromSpot(spot)),
                    ),
                ],
              ],
            ),
    );
  }

  /// Maps a `sectionSpots` section key to its display label.
  String _sectionLabel(Translations t, String key) => switch (key) {
        'notes' => t.operation.spots.callsOfNote,
        '?' => t.operation.spots.unknownBand,
        _ => key,
      };
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
      // As tall as a QSO row (qso_list's compact row/day-header height), with
      // the label vertically centered.
      constraints: const BoxConstraints(minHeight: _sectionHeaderHeight),
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.surfaceContainerHighest,
      foregroundDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 3),
        ),
      ),
      // Background stays edge-to-edge; the label insets by the split's
      // grab-strip clearance and the real device inset, like the spot rows
      // below it (ham2k/app-halo-dist#205).
      padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 4),
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

/// The section header's minimum height, matching a QSO row (qso_list.dart's
/// compact row/day-header height of 28) so the group separators read as a
/// tidy band break, not a full spot-row-tall block.
const double _sectionHeaderHeight = 28;

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

  const _SpotTile({
    required this.spot,
    this.noteEmoji,
    this.hzDigits = 0,
    this.leftWidth = 120,
    this.sortByAge = false,
    this.activityControls = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = haloMonoStyle(context, fontSize: 14, color: theme.colorScheme.onSurface);
    // Band/mode and the reference label are names, not structured data —
    // proportional, like everywhere else names/labels appear (e.g. the DX
    // flag/state field in qso_list.dart), unlike the monospace fields
    // (freq, callsign) they sit next to.
    final proportional = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);

    final freqKHz = _freqOf(spot);
    final Widget freqField;
    if (freqKHz == null) {
      // No frequency to show on the top line — the mode still shows below it.
      freqField = const SizedBox.shrink();
    } else {
      final parts = freqDisplayParts(freqKHz, hzDigits: hzDigits);
      freqField = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(parts.mhz, style: mono.copyWith(fontWeight: FontWeight.w700)),
          Text('.', style: mono),
          Text(parts.khz, style: mono),
          if (parts.hz != null) ...[
            Text('.', style: mono),
            Text(parts.hz!, style: mono.copyWith(fontSize: (mono.fontSize ?? 14) * 0.8)),
          ],
        ],
      );
    }

    final refs = _refsOf(spot);
    final refType = refs.isEmpty ? null : refs.first['type'] as String?;
    final refIcon = iconForRefType(activityControls, refType) ?? _iconOf(spot) ?? 'radio-tower';

    // Age sits at the top-right of the row, right-aligned, bold when it's the
    // sort key.
    final ageField = Text(
      _timeAgo(_timeOf(spot)),
      style: proportional?.copyWith(fontWeight: sortByAge ? FontWeight.w700 : null),
    );

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
            const SizedBox(width: 16),
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
                  style: mono.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (noteEmoji != null) ...[
                const SizedBox(width: 4),
                Text(noteEmoji!, style: emojiStyle()),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ageField,
      ],
    );

    final labelLine = _labelOf(spot) == null
        ? const SizedBox.shrink()
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Icon(resolveIconName(refIcon), size: mono.fontSize, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _labelOf(spot)!,
                  style: proportional?.copyWith(fontSize: mono.fontSize),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final tile = Padding(
      // Rows render edge-to-edge (the ink below spans the full width); the
      // content inset grows by the split's grab-strip clearance on the left
      // and the real device inset on both edges (ham2k/app-halo-dist#205)
      // so nothing interactive sits under the divider overlay or a cutout.
      padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(freqField, callLine),
          const SizedBox(height: 2),
          line(Text(_modeOf(spot) ?? '', style: proportional), labelLine),
        ],
      ),
    );

    final row = onTap == null
        ? tile
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: tile),
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

  const _SpotsFilterPill({
    required this.bandLabel,
    required this.modeLabel,
    required this.ageMinutes,
    required this.filteredCount,
    required this.totalCount,
    required this.onTap,
    required this.onRefresh,
    required this.refreshing,
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
      child: Padding(
        // Left/right clear the real device inset (ham2k/app-halo-dist#205)
        // — the row's own content is centered, but a wide enough pane on a
        // device with a landscape cutout could still push a pill under it.
        padding: PaneSafeArea.symmetricOf(context, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Extra breathing room above and below the pill row.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Desktop-only manual refresh — mobile refreshes by
                  // pull-to-refresh instead (RefreshIndicator on the list below).
                  if (!isMobilePlatform) ...[
                    _FilterInfoPill(
                      icon: 'refresh',
                      color: Colors.black,
                      loading: refreshing,
                      onTap: refreshing ? null : onRefresh,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // The only pill that can grow; flex it so it ellipsizes on a
                  // narrow panel rather than overflowing the row.
                  Flexible(child: _FilterInfoPill(icon: 'radio', label: '$bandLabel • $modeLabel', onTap: onTap)),
                  if (ageMinutes != null) ...[
                    const SizedBox(width: 6),
                    _FilterInfoPill(icon: 'clock', label: '${ageMinutes}m', onTap: onTap),
                  ],
                  const SizedBox(width: 6),
                  _FilterInfoPill(icon: 'tune', color: Colors.black, onTap: onTap),
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
    );
  }
}

/// A small icon (+ optional text) pill — the band/mode/age filter summaries
/// shown next to the tune button, and (icon-only, tappable) the tune button
/// itself.
class _FilterInfoPill extends StatelessWidget {
  final String icon;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;

  /// Swaps the icon for a spinner (same footprint) — used by the refresh
  /// button while a fetch is in flight.
  final bool loading;

  const _FilterInfoPill({required this.icon, this.label, this.color, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final effectiveColor = color ?? theme.colorScheme.onTertiaryContainer;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              const SizedBox(width: 4),
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
  final int totalSpotCount;
  final Map<String, int> bandSpotCounts;
  final Map<String, int> modeSpotCounts;
  final Map<int, int> ageSpotCounts;
  final String sortBy;
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
  final ValueChanged<bool> onGroupCallsWithNotesChanged;
  final ValueChanged<String> onToggleSource;
  final ValueChanged<String> onToggleContinent;

  const _SpotsFilterDialog({
    required this.bandFilter,
    required this.modeFilter,
    required this.ageMinutes,
    required this.autoBand,
    required this.autoMode,
    required this.totalSpotCount,
    required this.bandSpotCounts,
    required this.modeSpotCounts,
    required this.ageSpotCounts,
    required this.sortBy,
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
  late bool _groupCallsWithNotes = widget.groupCallsWithNotes;
  late final Set<String> _disabledSources = {...widget.disabledSources};
  late final Set<String> _disabledContinents = {...widget.disabledContinents};

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // 'auto' first (it's the default and tracks the live VFO), then 'any'.
    final bandOptions = ['auto', 'any', ...bands.map((b) => b.name)];
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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownMenu<String>(
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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownMenu<String>(
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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownMenu<int?>(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SegmentedButton<String>(
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      widget.sourceNames[source] ?? source,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.operation.spots.spotsCount(count: widget.sourceSpotCounts[source] ?? 0)),
                        const SizedBox(width: 8),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    _continentLabel(t, code),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.operation.spots.spotsCount(count: widget.continentSpotCounts[code] ?? 0)),
                      const SizedBox(width: 8),
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
