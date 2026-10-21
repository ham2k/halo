// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'spots_panel.dart';

/// The Spots panel's filters — band, mode, age, sources, continents, sorting
/// and grouping — restored from the last session and saved on every change,
/// plus what the panel shows through them.
///
/// Notifies for a filter the operator changed, and for the two outside inputs
/// the filters read: the VFO's band and mode (the "auto" filters follow them)
/// and Settings › Logging › Bands. Nothing else the radio or the settings
/// report costs a rebuild — a CAT feed updates the frequency many times a
/// second, and every settings write notifies, this one's own saves included.
class SpotsFilterState extends ChangeNotifier {
  SpotsFilterState({required SettingsService settings, required RadioService radio}) : _settings = settings, _radio = radio {
    _load();
    _enabledBands = settings.enabledBands.toSet();
    _vfoBand = radio.vfoA.band;
    _vfoMode = radio.vfoA.mode;
    settings.addListener(_onSettingsChanged);
    radio.addListener(_onVfoChanged);
  }

  final SettingsService _settings;
  final RadioService _radio;

  String get bandFilter => _bandFilter;
  String _bandFilter = 'auto';

  String get modeFilter => _modeFilter;
  String _modeFilter = 'auto';

  /// Never null and never wider than [spotAgeOptionsInMinutes]' last: the board
  /// is not open-ended, so there is no "any age" to fall back to.
  int get ageMinutes => _ageMinutes;
  int _ageMinutes = spotAgeOptionsInMinutes.last;

  Set<String> get disabledSources => _disabledSources;
  final Set<String> _disabledSources = {};

  Set<String> get disabledContinents => _disabledContinents;
  final Set<String> _disabledContinents = {};

  String get sortBy => _sortBy;
  String _sortBy = 'frequency';

  bool get groupByBand => _groupByBand;
  bool _groupByBand = true;

  bool get groupCallsWithNotes => _groupCallsWithNotes;
  bool _groupCallsWithNotes = false;

  /// Mirrors Settings › Logging › Bands, kept here rather than read per build
  /// so [_onSettingsChanged] can tell an edit to THIS list from the many other
  /// settings writes that notify — including this state's own saves.
  Set<String> get enabledBands => _enabledBands;
  late Set<String> _enabledBands;

  String? _vfoBand;
  String? _vfoMode;

  /// Restores band/mode/age/sources/continents/sorting/grouping from the
  /// last session — synchronous, like `RadioService`'s own load, since
  /// `SharedPreferences.getInstance()` was already awaited before
  /// `HaLoServices` existed.
  void _load() {
    final filters = SpotBoardFilters.fromSettings(_settings);
    _bandFilter = filters.bandFilter;
    _modeFilter = filters.modeFilter;
    _ageMinutes = filters.ageMinutes;
    _disabledSources.addAll(filters.disabledSources);
    _disabledContinents.addAll(filters.disabledContinents);
    _sortBy = filters.sortBy;
    _groupByBand = filters.groupByBand;
    _groupCallsWithNotes = filters.groupCallsWithNotes;
  }

  /// The filters as they stand on screen, in the shape [filterSpotBoard]
  /// reads — the same one an extension's `getSpots` decodes from settings.
  SpotBoardFilters get filters => SpotBoardFilters(
    bandFilter: _bandFilter,
    modeFilter: _modeFilter,
    ageMinutes: _ageMinutes,
    disabledSources: _disabledSources,
    disabledContinents: _disabledContinents,
    sortBy: _sortBy,
    groupByBand: _groupByBand,
    groupCallsWithNotes: _groupCallsWithNotes,
  );

  Future<void> _save() => _settings.setSpottingFilters({
    'bandFilter': _bandFilter,
    'modeFilter': _modeFilter,
    'ageMinutes': _ageMinutes,
    'disabledSources': _disabledSources.toList(),
    'disabledContinents': _disabledContinents.toList(),
    'sortBy': _sortBy,
    'groupByBand': _groupByBand,
    'groupCallsWithNotes': _groupCallsWithNotes,
  });

  void _change(void Function() change) {
    change();
    notifyListeners();
    unawaited(_save());
  }

  void setBandFilter(String value) => _change(() => _bandFilter = value);
  void setModeFilter(String value) => _change(() => _modeFilter = value);
  void setAgeMinutes(int value) => _change(() => _ageMinutes = value);
  void setSortBy(String value) => _change(() => _sortBy = value);
  void setGroupByBand(bool value) => _change(() => _groupByBand = value);
  void setGroupCallsWithNotes(bool value) => _change(() => _groupCallsWithNotes = value);
  void toggleSource(String key) => _change(() => _disabledSources.contains(key) ? _disabledSources.remove(key) : _disabledSources.add(key));
  void toggleContinent(String code) => _change(() => _disabledContinents.contains(code) ? _disabledContinents.remove(code) : _disabledContinents.add(code));

  /// Whether the Band filter has narrowed to one specific band ('auto' and
  /// 'any' both leave multiple bands possible).
  bool get isSingleBandFilter => _bandFilter != 'auto' && _bandFilter != 'any';

  /// Only the VFO's band/mode feed the "auto" filters — skip the notify (and
  /// the merge/filter pipeline it triggers) when neither changed, so a live
  /// CAT-control feed updating freq alone doesn't force a recompute on every
  /// tick.
  void _onVfoChanged() {
    final vfo = _radio.vfoA;
    if (vfo.band == _vfoBand && vfo.mode == _vfoMode) return;
    _vfoBand = vfo.band;
    _vfoMode = vfo.mode;
    notifyListeners();
  }

  /// The operator changed a setting — only their band list reaches the
  /// filters, so anything else notifying (this state's own saves among them)
  /// must not cost a rebuild of the whole spot list.
  void _onSettingsChanged() {
    final enabled = _settings.enabledBands.toSet();
    if (setEquals(enabled, _enabledBands)) return;
    _enabledBands = enabled;
    notifyListeners();
  }

  /// Every fetched spot from a source not switched off, unmerged.
  List<Map<String, dynamic>> rawSpots(Map<String, List<Map<String, dynamic>>> spotsBySource) => [
    for (final entry in spotsBySource.entries)
      if (!_disabledSources.contains(entry.key)) ...entry.value,
  ];

  /// Merged spots, same as [summarize]'s `total` stage — the baseline the
  /// band/mode/age dropdown option counts are drawn from (unaffected by the
  /// currently-selected band/mode/age/continent, same "of 72" semantics used
  /// elsewhere in the panel). [entityOf] as [mergedSpotBoard] takes it.
  List<Map<String, dynamic>> mergedSpots(Map<String, List<Map<String, dynamic>>> spotsBySource, {required String? Function(String call) entityOf}) =>
      mergedSpotBoard(spotsBySource, _disabledSources, entityOf: entityOf);

  /// `filtered` and `total` are [filterSpotBoard]'s.
  ///
  /// `selfSpots` — the merged spots that are this operation's own station's
  /// alone ([spotIsSelfOnly]) — is drawn from BEFORE any of that narrowing,
  /// band list included: the pinned self section exists so the operator can
  /// get back to where they announced themselves, and the moment that matters
  /// is exactly when the filters (an 'auto' band following a wandering VFO
  /// most of all) would have hidden it. All of them, newest first, whatever
  /// `sortBy` says.
  ({List<Map<String, dynamic>> filtered, List<Map<String, dynamic>> selfSpots, int total}) summarize(
    List<Map<String, dynamic>> merged, {
    required Set<String> ourBaseCalls,
    required String? Function(String call) continentOf,
  }) {
    final vfo = _radio.vfoA;
    final selfSpots = sortSpots([
      for (final spot in merged)
        if (spotIsSelfOnly(spot, ourBaseCalls: ourBaseCalls)) spot,
    ], 'time');
    final board = filterSpotBoard(merged, filters, vfoBand: vfo.band, vfoMode: vfo.mode, enabledBands: _enabledBands, continentOf: continentOf);
    return (filtered: board.filtered, selfSpots: selfSpots, total: board.total);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _radio.removeListener(_onVfoChanged);
    super.dispose();
  }
}

/// Spot counts per continent among [spots] — the Continent filter's
/// "${count} spots" labels. A callsign with no resolved continent yet
/// contributes to no bucket, same omission app-polo's own count map has.
///
/// Read through [spotOperatorCalls], the same calls the filter itself tests
/// and call info is keyed by — a raw `their.call` misses the lookup for any
/// source that does not uppercase its calls. A spot with operators on two
/// continents counts once toward each, as the filter keeps it for either.
Map<String, int> spotContinentCounts(List<Map<String, dynamic>> spots, String? Function(String call) continentOf) {
  final counts = <String, int>{};
  for (final spot in spots) {
    for (final continent in {for (final call in spotOperatorCalls(spot)) ?continentOf(call)}) {
      counts.update(continent, (c) => c + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

Map<String, int> spotBandCounts(List<Map<String, dynamic>> spots) {
  final counts = <String, int>{};
  for (final spot in spots) {
    final band = _bandOf(spot);
    if (band != null) counts.update(band, (c) => c + 1, ifAbsent: () => 1);
  }
  return counts;
}

Map<String, int> spotModeCounts(List<Map<String, dynamic>> spots) {
  final counts = <String, int>{};
  for (final spot in spots) {
    final superMode = superModeForMode(_modeOf(spot));
    if (superMode == null) continue;
    counts.update(superMode, (c) => c + 1, ifAbsent: () => 1);
    if (phoneCwSuperModes.contains(superMode)) counts.update(phoneCwModeFilter, (c) => c + 1, ifAbsent: () => 1);
  }
  return counts;
}

Map<int, int> spotAgeCounts(List<Map<String, dynamic>> spots) {
  final now = nowMillis();
  return {for (final minutes in spotAgeOptionsInMinutes) minutes: spots.where((s) => now - _timeOf(s) <= minutes * 60000).length};
}
