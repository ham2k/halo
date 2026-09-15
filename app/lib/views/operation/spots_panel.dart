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
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import '../../services/spots_service.dart';
import 'package:halo_i18n/halo_i18n.dart';

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

/// A spot map's fields come from a JS extension across the hook bridge,
/// which enforces nothing about their runtime type — every read below is a
/// probe (`asSpotString`/`asSpotNum`/`asSpotMap`, spots_service.dart — shared
/// with `callOfSpot`/`timeOfSpot` there, which describe this same wire
/// shape), not a trusted cast, so one hook shipping a wrong-typed field
/// degrades that single field to "absent" instead of throwing out of a
/// getter every other spot's build depends on. `getSpots` (extension_service.dart)
/// reports a wrong-typed field once, silently, per source; nothing here does.
String? _callOf(Map<String, dynamic> spot) => asSpotString(asSpotMap(spot['their'])?['call']);
/// The individual operator callsigns within a `their.call` — a comma-joined
/// compound for a multi-op spot (see `mergeSpotsByFreqAndRefs`), a single call
/// otherwise. Empty segments are dropped. Everything that keys off `_callNotes`
/// (per single call) must iterate these, not the raw compound string.
Iterable<String> _callsIn(String? call) => (call ?? '').split(',').where((c) => c.isNotEmpty);
double? _freqOf(Map<String, dynamic> spot) => asSpotNum(spot['freq'])?.toDouble();
String? _bandOf(Map<String, dynamic> spot) => asSpotString(spot['band']);
String? _modeOf(Map<String, dynamic> spot) => asSpotString(spot['mode']);
List<Map<String, dynamic>> _refsOf(Map<String, dynamic> spot) {
  final refs = spot['refs'];
  if (refs is! List) return const [];
  return [for (final ref in refs) if (ref is Map) ref.cast<String, dynamic>()];
}

int _timeOf(Map<String, dynamic> spot) => asSpotNum(asSpotMap(spot['spot'])?['timeInMillis'])?.toInt() ?? 0;
String? _iconOf(Map<String, dynamic> spot) =>
    asSpotString(spot['icon']) ?? asSpotString(asSpotMap(spot['spot'])?['icon']);
String? _labelOf(Map<String, dynamic> spot) => asSpotString(asSpotMap(spot['spot'])?['label']);
bool _isDigital(String? mode) => mode != null && _digitalModes.contains(mode.toUpperCase());

/// The three "super modes" ([superModeForMode]) the mode filter groups spots
/// by, in the order the dropdown offers them.
const _superModes = ['Phone', 'CW', 'Digital'];

/// The combined "Phone & CW" filter option: everything but Digital. A filter
/// value, not a super mode — [superModeForMode] never returns it, so it
/// needs its own branch wherever a filter value is resolved or counted.
const phoneCwModeFilter = 'phoneCw';

/// The super modes [phoneCwModeFilter] admits.
const _phoneCwSuperModes = {'Phone', 'CW'};

/// Migrates a persisted mode filter from the retired per-mode/`notDigital`
/// scheme to the super-mode scheme: 'auto'/'any', the super modes and
/// [phoneCwModeFilter] pass through, the retired 'notDigital' becomes
/// [phoneCwModeFilter] (the same intent), and anything else is read as an
/// individual mode ('SSB', 'FT8', …) and maps to its super mode — which,
/// as [superModeForMode] works, makes any unrecognised string 'Digital'.
/// Public for unit testing.
String normalizeModeFilter(String value) {
  if (value == 'auto' || value == 'any' || value == phoneCwModeFilter || _superModes.contains(value)) return value;
  if (value == 'notDigital') return phoneCwModeFilter;
  return superModeForMode(value) ?? 'auto';
}

/// The super modes a mode filter admits, or null for no narrowing: 'auto'
/// follows the VFO's current super mode (no narrowing while the VFO has no
/// mode), 'any' never narrows, [phoneCwModeFilter] admits Phone and CW,
/// and a super mode admits itself. Public for unit testing.
Set<String>? superModesForModeFilter(String filter, String? vfoMode) => switch (filter) {
      'auto' => switch (superModeForMode(vfoMode)) { final m? => {m}, null => null },
      'any' => null,
      phoneCwModeFilter => _phoneCwSuperModes,
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
    // bridge at runtime) is never merged into another's call list — checked
    // here for the spot BEING merged, and in the loop below for a call-less
    // spot already sitting in `merged` as a would-be TARGET — either
    // direction would otherwise produce a dangling ",CALL" or "CALL,".
    if (!_isDigital(_modeOf(spot)) && (_callOf(spot)?.isNotEmpty ?? false)) {
      final freq = _freqOf(spot);
      final refs = _refsOf(spot);
      if (freq != null) {
        for (final other in merged) {
          // The same guard as above, applied to the OTHER side of the merge:
          // a call-less spot already sitting in `merged` must never be a
          // match target either, or the appended call lands on an empty
          // existingCall and produces a dangling ",CALL".
          if (_callOf(other)?.isNotEmpty != true) continue;
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
      final existingCall = _callOf(match) ?? '';
      final newCall = _callOf(spot) ?? '';
      match['their'] = {...?asSpotMap(match['their']), 'call': '$existingCall,$newCall'};
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
/// app-polo's SpotsPanel.jsx: [selfSpots] — the operator's own station's
/// spots, which the caller supplies UNfiltered so a self-spot stays reachable
/// after the operator wanders to another band — get a `'self'`-keyed section
/// pinned above everything else. Then `callsWithNotes` spots get a leading
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
  List<Map<String, dynamic>> selfSpots = const [],
  required Set<String> callsWithNotes,
  bool groupByBand = true,
}) {
  final sections = <({String key, List<Map<String, dynamic>> spots})>[];

  if (selfSpots.isNotEmpty) sections.add((key: 'self', spots: selfSpots));

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
/// the logging panel's `QsoDraft.applyData` copies every top-level key it
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

/// Every source worth a row in the filter dialog, sorted: the ones that
/// offered spots, plus the ones that went quiet or answered with an error.
///
/// The union is the point. A source in trouble contributes no spots, so it
/// has no key in `spotsBySource` — listing only those keys drops it from the
/// filter entirely, and the operator cannot see that it was ever consulted.
///
/// A source still absent from this list answered without offering anything,
/// which is not always the same as having nothing to offer: a hook that opts
/// out by returning an empty list (WWFF with no API key) is indistinguishable
/// here from a quiet band. Public for `spots_panel_merge_test.dart`.
List<String> spotsFilterSourceList({
  required Iterable<String> withSpots,
  required Iterable<String> unavailable,
  required Iterable<String> failed,
}) =>
    {...withSpots, ...unavailable, ...failed}.toList()..sort();

String _timeAgo(int millis) {
  final seconds = (nowMillis() - millis) ~/ 1000;
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

/// Whether [spot] is for the callsign being logged right now — [currentCall],
/// already uppercased, like [spotDisplayFlags]'s `ourCall`. Any operator on a
/// merged multi-op spot counts, the same reading of `their.call` that flags
/// `isSelf`.
///
/// Exact: a portable or fixed suffix is a different station to work, so
/// W1AW/P must not light up while W1AW is being entered. Public for
/// `spots_panel_current_qso_test.dart`.
bool spotIsCurrentQso(Map<String, dynamic> spot, {String? currentCall}) {
  if (currentCall == null || currentCall.isEmpty) return false;
  return _callsIn(_callOf(spot)).any((c) => c.toUpperCase() == currentCall);
}

/// Whether every operator on [spot] is [ourCall] (already uppercased) — the
/// spot is ours ALONE. The self affordances key off this — the pinned
/// section, the tap-to-retune, the withheld slide-to-log — NOT
/// [spotDisplayFlags]'s any-of `isSelf` tint: a merged multi-op row that
/// merely includes us still carries another station worth working, and
/// stealing its tap or its log action would make that station unreachable
/// from the board. Public for `spots_panel_merge_test.dart`.
bool spotIsSelfOnly(Map<String, dynamic> spot, {String? ourCall}) {
  if (ourCall == null || ourCall.isEmpty) return false;
  final calls = _callsIn(_callOf(spot)).toList();
  return calls.isNotEmpty && calls.every((c) => c.toUpperCase() == ourCall);
}

/// The fill for the row of the QSO being logged: the logging panel's own
/// background — `tertiaryContainer` composing a new QSO, `secondaryContainer`
/// editing an existing one (`LoggingControls`' `accentTheme`) — blended
/// halfway into the surface the spots list sits on. The map says the same
/// thing in the same two hues but as a MARKER rather than a fill, so it reads
/// `tertiary`/`secondary` instead; new-vs-editing is what the three share, not
/// a colour token.
///
/// Blended toward the surface rather than lightened in HSL, in both
/// brightnesses: the row is an echo of the logging panel and must read weaker
/// than it, and in dark mode a literally lighter tint is the brighter of the
/// two. Public for `spots_panel_current_qso_test.dart`.
Color currentQsoHighlight(ColorScheme scheme, {required bool editing}) => Color.lerp(
      scheme.surface,
      editing ? scheme.secondaryContainer : scheme.tertiaryContainer,
      0.5,
    )!;

/// Everything a spot row is made of EXCEPT its density-driven spacing: the two
/// text lines [_SpotTile] paints, and the hairline divider (which is a
/// foreground decoration and so costs no height). The tile's padding and the
/// gap between the two lines both come off the ladder and are added on top.
///
/// Declared rather than measured, like `LayoutMetrics`' own row heights and
/// for the same reason: the reveal has to know where a row it cannot see would
/// be.
///
/// A BASELINE, not the final answer. The OS accessibility text-scale
/// preference composes on top of the app's own Font Scale
/// (docs/design/ui-scaling.md rule 3), and the text lines stretch with it while
/// the spacing around them does not — the `normal` rung's 50pt row becomes 61
/// at a text scale of 1.3. [_SpotsPanelState._rowHeightScale] measures that
/// stretch off a real row and applies it to every value here.
const _spotRowContentHeight = 36.0;

/// A reference label draws its line at the callsign's size rather than the
/// mode's, and a note emoji is taller than the callsign beside it. Both
/// measured; the emoji is worth barely a pixel because it stretches a line
/// that is already there, where the label adds one. Neither answers to
/// density — they are text, not spacing.
const _spotRowLabelHeight = 3.0;
const _spotRowEmojiHeight = 1.0;

/// The height [_SpotTile] paints for a row with these features, at [metrics].
/// Public for `spots_panel_current_qso_test.dart`.
///
/// [LayoutMetrics.spotTilePaddingV] is the tile's own padding, top and bottom,
/// and [LayoutMetrics.spotTileLineGap] the space between its two lines, so this
/// must stay the exact arithmetic the tile itself performs — every pixel of
/// disagreement is multiplied by the number of rows above the one being
/// revealed.
double spotRowHeightFor({
  required LayoutMetrics metrics,
  required bool hasLabel,
  required bool hasEmoji,
}) =>
    metrics.spotTilePaddingV * 2 +
    metrics.spotTileLineGap +
    _spotRowContentHeight +
    (hasLabel ? _spotRowLabelHeight : 0) +
    (hasEmoji ? _spotRowEmojiHeight : 0);

/// A row scale learned at [from], re-expressed for [to]. Public for
/// `spots_panel_current_qso_test.dart`.
///
/// The scale is a whole-row ratio (measured over declared), but the OS text
/// scale it stands for stretches only the row's TEXT — the tile's padding and
/// line gap are logical pixels and do not move with it. Those two are exactly
/// what the density ladder changes, so a scale learned at one rung is wrong at
/// the next, by more the further apart they are. Recovering the text's painted
/// height and re-dividing is what keeps it right.
///
/// Converted rather than reset to 1.0: the calibration row is only mounted near
/// the top of the list, so an operator scrolled deep into a board would keep a
/// scale of 1.0 — wrong by the whole text scale, which is far worse than the
/// rung-to-rung error this exists to remove.
double spotRowScaleFor(double scale, {required LayoutMetrics from, required LayoutMetrics to}) {
  double spacing(LayoutMetrics m) => m.spotTilePaddingV * 2 + m.spotTileLineGap;
  final text = (spacing(from) + _spotRowContentHeight) * scale - spacing(from);
  return (spacing(to) + text) / (spacing(to) + _spotRowContentHeight);
}

/// Where the row for [currentCall] sits in a sectioned spots list: the scroll
/// offset it begins at, and the height it paints. Null when no spot matches.
///
/// The first match wins, and the pinned duplicate in "Calls of Note" is a row
/// like any other: whichever copy comes first is the one nearest the top,
/// which is where the operator looks.
///
/// The offset is summed from what each row above ACTUALLY paints — [heightOf]
/// answers per spot — rather than multiplying a count by one representative
/// height. A single height is wrong by a few pixels on every labelled or noted
/// row, and on a board where most rows are both, that error reaches a row's
/// worth long before the target and puts it outside what the correction pass
/// can even measure.
///
/// Deliberately NOT derived from the list's scroll extent either: the list
/// lays its rows out lazily, so `maxScrollExtent` is itself an estimate
/// built from whichever rows happen to be laid out, and reading a row height
/// back out of it gives a different answer on two runs of the same code.
///
/// The row comes back as a `(section, index)` PAIR rather than the spot
/// object, because `sectionSpots` pins the very same `Map` instance in the
/// notes section and in its band section — identity names both copies, and a
/// caller keying rows by it would put one GlobalKey on two tiles. Public for
/// `spots_panel_current_qso_test.dart`.
({int section, int index, double top, double height})? locateCurrentSpotRow(
  List<List<Map<String, dynamic>>> sections, {
  String? currentCall,
  required double headerHeight,
  required double Function(Map<String, dynamic> spot) heightOf,
}) {
  var top = 0.0;
  for (final (sectionIndex, section) in sections.indexed) {
    // Its own section's header sits above it, so this one counts too.
    top += headerHeight;
    for (final (index, spot) in section.indexed) {
      final height = heightOf(spot);
      if (spotIsCurrentQso(spot, currentCall: currentCall)) {
        return (section: sectionIndex, index: index, top: top, height: height);
      }
      top += height;
    }
  }
  return null;
}

/// The offset to scroll to so the span [top]..[bottom] is fully on screen,
/// moving the LEAST that does it — or null when it already is, or when the
/// move would be under half a pixel.
///
/// Not moving an already-visible row is the contract: typing a call whose spot
/// happens to be on screen must not yank the list out from under the operator.
///
/// The leading edge is inset by [headerHeight], like the QSO list's
/// counterpart and for the same reason: section headers are **pinned**, so a
/// row flush against the top of the viewport sits underneath one and the
/// operator cannot see what was revealed. Public for
/// `spots_panel_current_qso_test.dart`.
double? spotScrollTarget({
  required double top,
  required double bottom,
  required double pixels,
  required double viewport,
  required double headerHeight,
  required double minExtent,
  required double maxExtent,
}) {
  final double target;
  if (top - headerHeight < pixels) {
    target = top - headerHeight;
  } else if (bottom > pixels + viewport) {
    target = bottom - viewport;
  } else {
    return null; // already fully visible
  }
  final clamped = target.clamp(minExtent, maxExtent);
  if ((clamped - pixels).abs() < 0.5) return null;
  return clamped;
}

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
  final void Function(Map<String, dynamic> qso, {bool reveal})? onSuggestQso;

  /// Take back the suggestion a slide made — the row it belonged to is no
  /// longer open, so the logging fields it filled are no longer anybody's
  /// choice of station. Every way a row stops being open comes through here:
  /// dragged back, set aside with the other action, closed by another row
  /// opening, scrolled away, or discarded outright.
  ///
  /// Carries the callsign it filled in, and takes back only that: a row
  /// discarded while open withdraws AFTER the frame, by which time another
  /// row's peek — made in the same frame, from input that ran before the
  /// build that discarded this one — may already own the fields.
  final ValueChanged<String?>? onWithdrawSuggestion;

  /// A slid row has come to rest open and the finger is off it. Anything the
  /// logging panel held back rather than raise mid-drag — the prompt over
  /// work a suggestion would overwrite — is put to the operator here.
  final VoidCallback? onSuggestionSettled;

  /// Bumped when the operator works the logging fields themselves — typing in
  /// the call field, or wiping it. An open row is an offer about which station
  /// to work, and they have just answered it from the other panel: leaving it
  /// armed leaves a gesture pointing at a spot they have moved past.
  final int closeSlidesSerial;

  /// Log this QSO outright — the spot row's slid-right action. Distinct from
  /// [onSuggestQso], which only fills the fields and leaves the operator to
  /// press Log: this one IS the press, so the row's gesture ends in a logged
  /// contact without the logging panel ever having to be looked at.
  final ValueChanged<Map<String, dynamic>>? onLogQso;

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

  /// The QSO being logged right now, pushed up from the logging panel — the
  /// same payload the map highlights from, so both panes agree on what "the
  /// current QSO" is and on the new-vs-editing accent that says so. Null when
  /// the logging panel isn't showing call-info: fewer than three alphanumeric
  /// characters typed, or a command message occupying the area.
  final CallInfoData? callInfo;

  /// Whether the TAB holding this panel is the selected one. Only half of
  /// whether the panel is on screen: in a dock arrangement the pane's own
  /// `DockPaneVisibility` is the other half, and the two are ANDed. A hidden
  /// panel is still built (it is kept alive behind its tab), so without both
  /// it would scroll itself off-screen and the operator would find the list
  /// moved when they came back.
  ///
  /// A listenable rather than a plain flag: the tab controller notifies on
  /// every frame of the tab-change animation, and rebuilding the spots list a
  /// dozen times to carry one boolean across is not worth it.
  ///
  /// Required, and not nullable: a caller that omitted it would get a panel
  /// that considers itself permanently hidden, so the tint would keep working
  /// while the reveal silently never fired again.
  final ValueListenable<bool> visible;

  const SpotsPanel({
    super.key,
    required this.operation,
    required this.services,
    required this.logRevision,
    required this.visible,
    this.onSuggestQso,
    this.onWithdrawSuggestion,
    this.onSuggestionSettled,
    this.closeSlidesSerial = 0,
    this.onLogQso,
    this.qsos = const [],
    this.callInfo,
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
  /// Never null and never wider than [_ageOptionsInMinutes]' last: the board
  /// is not open-ended, so there is no "any age" to fall back to.
  int _ageMinutes = _ageOptionsInMinutes.last;
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

  final _scrollController = ScrollController();

  /// The call whose row this panel has already scrolled to. Only ever set
  /// while the panel is visible, so a call typed behind a hidden tab is still
  /// pending when the tab comes back.
  String? _revealedCall;

  /// Where the current QSO's first row sits, as counts of the rows and section
  /// headers above it plus the totals for the whole list — the raw material
  /// for [_revealCurrent]'s arithmetic. Null when no spot matches. Written by
  /// `_buildSpotsList`, the only place the sectioned list exists.
  ({double top, double height})? _currentRowPosition;

  /// Identifies the current QSO's row to [_correctRevealFor]. Placed by
  /// `(section, index)` — the one spot pinned in "Calls of Note" is the same
  /// object as its copy in the band section, so keying by identity would put
  /// this key on two tiles at once and the tree would throw.
  final _currentRowKey = GlobalKey();
  ({int section, int index})? _currentRowAt;

  /// The call the latest build placed a keyed row for — a staleness guard, so
  /// a correction chained to one call's scroll can't measure a row the list has
  /// since given to another. It does NOT say the row was inflated: this list
  /// builds every child widget but the viewport only mounts the ones near it.
  /// Whether there is anything to measure is what [_currentRowKey]'s null
  /// `currentContext` answers.
  String? _keyedRowCall;

  /// The call [_correctRevealFor] has already straightened out, so one drifted
  /// landing costs one correction rather than a loop against a drift it can't
  /// close.
  String? _correctedRevealFor;

  /// How much taller a row actually paints than [spotRowHeightFor] declares.
  /// 1.0 until a row has been measured, which is exactly right at an OS text
  /// scale of 1.0 and wrong by a fifth at 1.3.
  ///
  /// Measured rather than computed from `MediaQuery.textScalerOf`: a tile is
  /// text lines inside constant padding, so it grows by LESS than the text
  /// scaler (1.22 at a scale of 1.3), and no arithmetic over the tile's font
  /// sizes would survive a change to what it paints. One reading covers every
  /// row shape — plain, labelled and noted rows stretch within about a percent
  /// of each other, which over a long board stays inside what
  /// [_correctRevealFor] can absorb.
  double _rowHeightScale = 1.0;

  /// The calibration row's key, and the height [spotRowHeightFor] declares for
  /// it. Null when this build placed no calibration row — an empty board, or
  /// one whose first row is the current QSO's and so already carries
  /// [_currentRowKey].
  final _calibrationKey = GlobalKey();
  double? _calibrationDeclared;

  /// Cached rather than read where it is used, like `qso_list.dart`'s own:
  /// [_revealCurrent] runs from a post-frame callback, outside build, where
  /// depending on an inherited widget is not allowed — and the cache is also
  /// what keeps the header height the scroll arithmetic uses identical to the
  /// one the headers paint with.
  late LayoutMetrics _metrics;

  /// Per-callsign overrides of what scoring says about a spot: true forces the
  /// row to read as worked (slid left to set it aside), false forces it to read
  /// as NOT worked — which is how a genuine duplicate is put back on the board,
  /// and how an ignore is taken back. Either way it moves only the row's dim:
  /// the strikethrough is scoring's alone (see [_SpotTile.logged]), so a
  /// restored duplicate comes back at full contrast still struck.
  ///
  /// An override never touches the log. Nothing here can un-work a contact;
  /// this only changes what the row says, which is the whole of what the
  /// operator asked for when they slid it.
  ///
  /// In memory deliberately: this is a "not this one, right now" about a board
  /// that turns over every few minutes, not a fact about the station worth
  /// outliving the app. Keyed by callsign alone, so the same operator
  /// re-spotted on another frequency keeps the verdict — which is the case the
  /// gesture exists for.
  final Map<String, bool> _workedOverride = {};

  /// Keeps one row's actions open at a time.
  final _SlideGroup _slideGroup = _SlideGroup();

  /// The call the open row's peek put in the logging fields, uppercased, or
  /// null when no peek is standing. Written by the same two callbacks that
  /// make and take back the fill, so it tracks the fill rather than the row:
  /// a peek the logging panel held back above work in progress never became
  /// the current call, and must not suppress that call's reveal.
  String? _peekedCall;

  /// Whether [_metrics] holds a reading yet — `late` cannot be asked. The
  /// FIRST `didChangeDependencies` has no previous rung to convert a scale
  /// from, and reading `_metrics` to find that out would throw.
  bool _metricsSet = false;

  /// The dock's half of [_onScreen], cached for the same reason as [_metrics]
  /// — the reveal runs from post-frame callbacks. True outside a dock, where
  /// a built pane is a visible one.
  bool _dockVisible = true;

  /// Whether this panel is really the pane on screen: its tab is selected AND
  /// its dock group is showing it. `DockPaneVisibility` comes from the
  /// `IndexedStack` that does the hiding, so unlike anything the operation
  /// view could mirror down it cannot go stale — notably across a
  /// `revealModule`, which surfaces another pane without telling that view.
  bool get _onScreen => widget.visible.value && _dockVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final metrics = LayoutDensity.metricsOf(context);
    // A density change moves the spacing [_rowHeightScale] was measured
    // against, so carry the learned text stretch across rather than leaving a
    // ratio that now belongs to the previous rung — see [spotRowScaleFor].
    if (_metricsSet && !identical(metrics, _metrics)) {
      _rowHeightScale = spotRowScaleFor(_rowHeightScale, from: _metrics, to: metrics);
    }
    _metrics = metrics;
    _metricsSet = true;
    // [_revealedCall] is deliberately left alone in both directions, matching
    // the tab half in `_onVisibilityChanged`: a call typed while this pane was
    // behind another is already pending, because [_armReveal] returns before
    // latching while off screen — and one already revealed stays revealed, so
    // flipping to another pane in the group and back does not yank the list
    // away from wherever the operator scrolled it.
    _dockVisible = DockPaneVisibility.of(context);
  }

  @override
  void initState() {
    super.initState();
    widget.visible.addListener(_onVisibilityChanged);
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
    unawaited(_loadActivityControls());
  }

  /// Fetched once, and nothing re-runs it: these decide every spot row's
  /// activity icon, so a failure leaves the panel rendering hunted activities
  /// with generic icons for the session. There is nothing on screen to keep
  /// at first load, so waiting out a booting runtime is the whole defence.
  Future<void> _loadActivityControls() async {
    await widget.services.extensions.start();
    if (!mounted) return;
    final result = await widget.services.extensions.loggingControls(widget.operation.data);
    if (!mounted) return;
    // Logged, not surfaced: what this costs is a generic icon on spot rows,
    // which is a degradation the operator can see for themselves — unlike a
    // ref wrongly marked as belonging to an uninstalled extension, which is
    // the claim the notices elsewhere exist to retract.
    if (result.loadFailed) debugPrint('[extensions] spots panel: activity controls unavailable');
    setState(() => _activityControls = result.controls);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettingsChanged);
    widget.services.radio.removeListener(_onVfoChanged);
    widget.services.spots.removeListener(_onSpotsChanged);
    widget.visible.removeListener(_onVisibilityChanged);
    _scoreDebounce?.cancel();
    _unsubscribeSpots?.call();
    _scrollController.dispose();
    _slideGroup.dispose();
    super.dispose();
  }

  /// Becoming the visible pane re-arms the reveal, so a call typed while this
  /// was behind another tab is scrolled to on arrival rather than left
  /// wherever the list happened to be.
  ///
  /// Deliberately not a reveal on the spot: the list may not have been rebuilt
  /// since, and [_currentRowPosition] would then place the row from a list
  /// that has moved on. Re-arming and letting the next build decide costs one
  /// rebuild per tab switch and cannot act on a stale position. The setState
  /// waits for the frame because the notifier fires from the operation view's
  /// own build.
  void _onVisibilityChanged() {
    if (!_onScreen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_onScreen) return;
      // A bare rebuild is the whole job. [_armReveal] returns before latching
      // while hidden, so a call entered behind another tab is still unequal to
      // the latch and arms itself the moment this build runs — and one that was
      // already revealed still matches, so coming back to the tab does not
      // yank the list to a row the operator last saw exactly where it is.
      setState(() {});
    });
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
    // A stored 'any' (null, from before the board was bounded) or anything
    // wider than the options now offered comes back as the widest one.
    final storedAge = decoded['ageMinutes'] as int?;
    _ageMinutes = _ageOptionsInMinutes.contains(storedAge) ? storedAge! : _ageOptionsInMinutes.last;
    // Through the typed accessor, not a second read of the raw map: the
    // status reporter subtracts the same set, and two hand-rolled decodings
    // of one key drift apart silently.
    _disabledSources.addAll(widget.services.settings.disabledSpotSources);
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
    if (widget.closeSlidesSerial != oldWidget.closeSlidesSerial) {
      // After the frame: this runs during a build, and closing a row rebuilds
      // it and reaches back up to the operation view to take its suggestion
      // back — neither of which may happen while the tree is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _slideGroup.closeAll();
      });
    }
    if (widget.visible != oldWidget.visible) {
      oldWidget.visible.removeListener(_onVisibilityChanged);
      widget.visible.addListener(_onVisibilityChanged);
    }
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
        final now = nowMillis();
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
        // every worked spot on a transient miss. A scorer that RAN and failed
        // is deliberately not that case: it comes back as the surviving
        // scorers' verdicts, empty if it was the only one, so a board never
        // keeps strikes put there by a scorer that is no longer answering.
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
  ///
  /// The FIRST of the operation's callsigns: the raw field holds all of them
  /// as one comma-separated string, which matches no spot at all, so a
  /// multi-call operation would tint none of its own spots and would offer
  /// itself as a contact to work. A spot of one of the OTHER calls still
  /// goes untinted — `spotDisplayFlags` and `spotIsSelfOnly` take one call.
  String? get _ourCall {
    final call = widget.operation.stationCalls.first.trim().toUpperCase();
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
      // A press that was skipped for being offline has to say so. The
      // status-bar offline icon is a passive state indicator somewhere else
      // on screen; it is not an answer to this button.
      if (_spots.lastRefreshWasSkipped && mounted) {
        widget.services.statusBar.setMessage(
          key: 'spots:not-refreshed',
          icon: 'cloud-off',
          text: context.t.spotting.notRefreshedOffline,
        );
      }
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
  ///
  /// `selfSpots` — the merged spots that are this operation's own station's
  /// alone ([spotIsSelfOnly]) — is drawn from BEFORE any of that narrowing,
  /// band list included: the pinned self section exists so the operator can
  /// get back to where they announced themselves, and the moment that matters
  /// is exactly when the filters (an 'auto' band following a wandering VFO
  /// most of all) would have hidden it. All of them, newest first, whatever
  /// `sortBy` says.
  ({List<Map<String, dynamic>> filtered, List<Map<String, dynamic>> selfSpots, int total})
      get _filteredSpotsSummary {
    final vfo = widget.services.radio.vfoA;
    final band = _bandFilter == 'auto' ? vfo.band : _bandFilter;
    final superModes = superModesForModeFilter(_modeFilter, vfo.mode);

    final merged = _mergedRawSpots;
    final selfSpots = sortSpots(
      [for (final spot in merged) if (spotIsSelfOnly(spot, ourCall: _ourCall)) spot],
      'time',
    );

    final singleBand = band != null && band != 'any';
    var spots = singleBand ? merged : spotsOnEnabledBands(merged, _enabledBands);
    final total = spots.length;

    if (singleBand) {
      spots = spots.where((s) => _bandOf(s) == band).toList();
    }
    if (superModes != null) {
      spots = spots.where((s) => superModes.contains(superModeForMode(_modeOf(s)))).toList();
    }
    final cutoff = nowMillis() - _ageMinutes * 60000;
    spots = spots.where((s) => _timeOf(s) >= cutoff).toList();
    if (_disabledContinents.isNotEmpty) {
      // Per-operator so multi-op spots narrow correctly; an unresolved
      // continent never hides a spot. See spotPassesContinentFilter.
      spots = spots
          .where((s) => spotPassesContinentFilter(_callOf(s), _disabledContinents, (c) => _callNotes[c]?.continent))
          .toList();
    }
    spots = sortSpots(spots, _sortBy);
    return (filtered: spots, selfSpots: selfSpots, total: total);
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
      if (_phoneCwSuperModes.contains(superMode)) counts.update(phoneCwModeFilter, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<int, int> _ageSpotCountsOf(List<Map<String, dynamic>> merged) {
    final now = nowMillis();
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
          sources: spotsFilterSourceList(
            withSpots: _spotsBySource.keys,
            unavailable: _spots.unavailableSources,
            failed: _spots.failedSources,
          ),
          sourceNames: _sourceNames,
          sourceSpotCounts: _spotsBySource.map((key, spots) => MapEntry(key, spots.length)),
          unavailableSources: _spots.unavailableSources.toSet(),
          failedSources: _spots.failedSources.toSet(),
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
      // There is no list while this shows, so nothing is revealed on it. Left
      // latched, the call being logged would be retired against a list the
      // operator never saw, and the rebuilt one would never scroll to it.
      _revealedCall = null;
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
            child: _buildSpotsList(context, summary.filtered, summary.selfSpots),
          ),
        ),
      ],
    );
  }

  /// Sections the already-filtered `filtered` spots per the current
  /// sort/group settings, then renders the scrollable list — split out of
  /// `build()` just for readability.
  ///
  /// `selfSpots` — our own station's spots, unfiltered (see
  /// `_filteredSpotsSummary`) — pin above everything as their own section.
  /// `groupCallsWithNotes` prepends a "Calls of Note" section (spots whose
  /// callsign has a note, per `_callNotes`) ahead of everything else —
  /// those spots still also appear in their normal section below, same as
  /// app-polo's SpotsPanel.jsx (a pinned duplicate, not an exclusive move).
  /// `_groupByBand` then decides band sections vs. one flat section; either
  /// way `filtered` is already sorted per `_sortBy`, so that order is what
  /// shows within each band (or across the whole flat list).
  Widget _buildSpotsList(
    BuildContext context,
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> selfSpots,
  ) {
    final t = context.t;
    final theme = Theme.of(context);

    final callsWithNotes = _groupCallsWithNotes
        ? {
            for (final entry in _callNotes.entries)
              if (entry.value.hasNote) entry.key,
          }
        : const <String>{};
    final rawSections =
        sectionSpots(filtered, selfSpots: selfSpots, callsWithNotes: callsWithNotes, groupByBand: _groupByBand);
    final sections = [
      for (final section in rawSections)
        (
          key: section.key,
          label:
              '${_sectionLabel(t, section.key)} - ${t.operation.spots.spotsCount(count: section.spots.length)}',
          spots: section.spots,
        ),
    ];
    // Same adaptive Hz-digit rule as qso_list.dart's DayHeaderRow/QSO rows —
    // computed across every currently-visible spot, not per-tile, so every
    // tile's Hz segment (if any) lines up at the same width. The pinned self
    // spots count too: they can sit outside `filtered`.
    final visibleSpots = [...selfSpots, ...filtered];
    final hzDigits = hzDigitsNeeded(visibleSpots.map(_freqOf));
    // The left column is only as wide as the widest frequency (and mode)
    // actually on screen — HF-only spots pack tighter than the fixed width
    // the widest microwave frequency would need. Shared across tiles so their
    // right-aligned frequencies still line up.
    final leftWidth = _spotLeftColumnWidth(context, visibleSpots, hzDigits);

    final currentCall = widget.callInfo?.call.toUpperCase();
    final highlight = widget.callInfo == null
        ? null
        : currentQsoHighlight(theme.colorScheme, editing: widget.callInfo!.isEditing);
    _locateCurrentRow(sections, currentCall);
    // The height every section header is FORCED into, and the same figure
    // [_locateCurrentRow] counts a header as — a pinned sliver states its
    // extent before its child is laid out, so the two cannot be allowed to
    // disagree.
    final headerExtent = _sectionHeaderExtent;
    // Registered before the reveal's own callback so it runs first: a reveal
    // armed this frame is then measured against a scale learned from this
    // frame, rather than spending its one arm on the previous one's.
    WidgetsBinding.instance.addPostFrameCallback((_) => _calibrateRowHeight());
    _armReveal(currentCall);

    return RefreshIndicator(
      // Explicit, unlike every other spinner in the app: RefreshIndicator
      // resolves `color ?? colorScheme.primary` directly and never consults
      // ProgressIndicatorTheme, so it is the one progress affordance the
      // theme cannot reach.
      color: HaLoColors.of(context).onSurfaceAccent,
      onRefresh: _spots.refresh,
      // `sections`, not `filtered`: a pinned self spot must survive filters
      // that empty the rest of the board — that is when it is needed.
      child: sections.isEmpty
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
          // Scrolling deliberately leaves an open row open: the operator
          // peeking at one spot's action while scanning the rest of the board
          // is reading, not abandoning the peek, and a row that snapped shut
          // under the scroll took its suggestion out of the logging fields
          // with it.
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Each section's header is grouped with its OWN rows, not
                // listed as a sibling sliver: pinning is coordinated within a
                // group, so a short section's header is pushed off by the next
                // section's instead of both staying stuck at the top at once.
                for (final (sectionIndex, section) in sections.indexed)
                  SliverMainAxisGroup(slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SpotsSectionHeaderDelegate(label: section.label, extent: headerExtent),
                    ),
                    SliverList.list(children: [
                      for (final (index, spot) in section.spots.indexed)
                        if (_flagsFor(spot) case final flags)
                          if (_isWorked(spot, scored: flags.worked) case final worked)
                          // The SAME predicate the pinned section is built from,
                          // so a row under "Your Spots" can never fall through to
                          // the suggest/log affordances — and vice versa.
                          if (spotIsSelfOnly(spot, ourCall: _ourCall) case final selfOnly)
                          // The slide wraps the tile rather than living inside it,
                          // and carries a key of its OWN that never changes. The
                          // tile's key does change — it takes `_currentRowKey` on
                          // becoming the current QSO, which is exactly what a
                          // slide causes — and a widget whose key changes has its
                          // subtree discarded. A gesture in there dies mid-drag.
                          _SlidableSpotRow(
                            // Keyed on the SECTION's key, not its label: the label
                            // carries the section's spot count, so keying on it
                            // would change every row's key on any poll that adds
                            // or drops one spot — discarding the slide State of
                            // every row in the section, which is the failure this
                            // wrapper exists to prevent. The spot's own time
                            // separates two rows for one call on one frequency,
                            // which the merge passes allow when they are more
                            // than 30 minutes apart.
                            key: ValueKey('${section.key}|${_callOf(spot)}|${_freqOf(spot)}|${_timeOf(spot)}'),
                            group: _slideGroup,
                            background: theme.colorScheme.surface,
                            // Our own station is not a contact to log — no
                            // slide-to-log on a row that is ours alone, same
                            // reasoning as the tap below.
                            leading: widget.onLogQso == null || selfOnly
                                ? null
                                : _SlideAction(
                                    icon: MdiIcons.upload,
                                    label: t.operation.spots.slideLogIt,
                                    // The logging panel's own submit accent and
                                    // glyph: the gesture ends in the act that
                                    // button performs, so it may not look like a
                                    // different one.
                                    background: theme.colorScheme.tertiary,
                                    foreground: theme.colorScheme.onTertiary,
                                    // The peek is SPENT here, not withdrawn (see
                                    // [_SlidableSpotRowState._fire]), so nothing
                                    // fires `onWithdrawn` on this path and the
                                    // call has to be given up by hand — otherwise
                                    // it stays this panel's peek for the session,
                                    // and meeting the same station again on
                                    // another band would silently reveal nothing.
                                    onPressed: () {
                                      _peekedCall = null;
                                      _logSpot(spot);
                                    },
                                    // Opening fills the logging fields with this
                                    // spot, so what the commit is about to log is
                                    // on screen before it is logged.
                                    onRevealed: widget.onSuggestQso == null
                                        ? null
                                        : () {
                                            _peekedCall = _callOf(spot)?.toUpperCase();
                                            widget.onSuggestQso!(suggestedQsoFromSpot(spot), reveal: false);
                                          },
                                    // The fill lasts as long as the row is open —
                                    // a spot the operator dragged back or set
                                    // aside is not the station they are working,
                                    // and leaving it in the fields makes the next
                                    // Log a contact with whoever was slid last.
                                    // Scrolling is not one of those: it leaves the
                                    // row open, and so leaves the fill alone.
                                    // Unconditional, unlike the suggestion it
                                    // reports: [_peekedCall] is this panel's own
                                    // state, and hanging its clearing off an
                                    // optional callback would leave the peek
                                    // standing for good wherever that callback is
                                    // absent.
                                    onWithdrawn: () {
                                      // Only its own: dragging out through the
                                      // middle and back out the other side
                                      // withdraws before the incoming side
                                      // reveals, and a blind clear there would
                                      // drop the new peek.
                                      if (_peekedCall == _callOf(spot)?.toUpperCase()) _peekedCall = null;
                                      widget.onWithdrawSuggestion?.call(_callOf(spot));
                                    },
                                    onSettled: widget.onSuggestionSettled,
                                  ),
                            // Always the reverse of what the row currently says, so
                            // the gesture reads the same whether the row was dimmed
                            // by scoring or by an earlier slide: undo puts a worked
                            // spot back on the board, backspace takes a live one off
                            // it.
                            trailing: _SlideAction(
                              icon: worked ? MdiIcons.undoVariant : MdiIcons.backspace,
                              label: worked
                                  ? t.operation.spots.slideRestore
                                  : t.operation.spots.slideIgnore,
                              background: theme.colorScheme.surfaceContainerHighest,
                              foreground: theme.colorScheme.onSurface,
                              onPressed: () => _toggleWorked(spot, worked: worked),
                            ),
                            child: _SpotTile(
                              key: _isCurrentRow(sectionIndex, index)
                                  ? _currentRowKey
                                  : (sectionIndex == 0 && index == 0 ? _calibrationKey : null),
                              spot: spot,
                              noteEmoji: _noteEmojiOf(spot),
                              hzDigits: hzDigits,
                              leftWidth: leftWidth,
                              sortByAge: _sortBy == 'time',
                              activityControls: _activityControls,
                              // A spot set aside by a slide dims like one scoring
                              // calls worked, and a slide can equally put a scored
                              // duplicate back on the board — but neither gesture
                              // touches the strikethrough, which answers only
                              // "is this call in the log" — see [_isWorked].
                              worked: worked,
                              logged: flags.worked,
                              isSelf: flags.isSelf,
                              notices: flags.notices,
                              highlight: spotIsCurrentQso(spot, currentCall: currentCall) ? highlight : null,
                              // A spot that is ours alone suggests no QSO — there
                              // is no one to work. Tapping it re-tunes instead:
                              // the VFO goes back to the spotted state, which is
                              // what the operator wants back after wandering off
                              // to hunt.
                              // Every tap closes whatever is open first: a tap is
                              // the operator choosing a station outright, which
                              // answers the question the open row was asking. The
                              // close runs BEFORE the suggestion so the row's own
                              // withdrawal cannot land on top of it.
                              onTap: selfOnly
                                  ? _closingFirst(_retuneActionFor(spot))
                                  : widget.onSuggestQso == null
                                      ? null
                                      : _closingFirst(() => widget.onSuggestQso!(suggestedQsoFromSpot(spot))),
                            ),
                          ),
                    ]),
                  ]),
              ],
            ),
    );
  }

  /// What [_SpotTile] paints for [spot], for the reveal's offset arithmetic.
  /// The note emoji is read from the same cache the tile draws it from, so a
  /// board whose note lookups have not landed yet is summed a few pixels short
  /// per noted row — which is what [_correctRevealFor] is left to close.
  double _spotRowHeightOf(Map<String, dynamic> spot) => spotRowHeightFor(
        metrics: _metrics,
        hasLabel: _labelOf(spot) != null,
        hasEmoji: _noteEmojiOf(spot) != null,
      );

  /// Whether [spot] reads as worked, [scored] being what candidate scoring
  /// says about it.
  ///
  /// An override only applies when EVERY operator on a merged multi-op spot
  /// carries the same one — the "all of them" rule scoring itself uses. One
  /// dismissed operator cannot hide a station still worth working, and one
  /// restored operator cannot un-dim the rest.
  bool _isWorked(Map<String, dynamic> spot, {required bool scored}) {
    final calls = _operatorCallsOf(spot);
    if (calls.isEmpty) return scored;
    final verdicts = calls.map((call) => _workedOverride[call]).toSet();
    final agreed = verdicts.length == 1 ? verdicts.first : null;
    return agreed ?? scored;
  }

  /// Slid left: flip what the row says about having been worked, for every
  /// operator on it. [worked] is what it says now, so this always reverses the
  /// thing the operator is looking at.
  void _toggleWorked(Map<String, dynamic> spot, {required bool worked}) {
    final calls = _operatorCallsOf(spot);
    if (calls.isEmpty) return;
    setState(() {
      for (final call in calls) {
        _workedOverride[call] = !worked;
      }
    });
  }

  /// Slid right past the commit point, or its button pressed: hand the spot
  /// to the logging panel as the QSO to log. The panel does the logging —
  /// re-deriving RST, `our`, timestamps and the command path here would be a
  /// second implementation of the thing the operator can already see.
  void _logSpot(Map<String, dynamic> spot) {
    widget.onLogQso?.call(suggestedQsoFromSpot(spot));
  }

  /// Wraps a row's tap handler so it closes whatever row is currently open
  /// before it runs — and returns null for a row that has no handler, so a
  /// dead row stays dead rather than becoming tappable just to close another.
  VoidCallback? _closingFirst(VoidCallback? onTap) {
    if (onTap == null) return null;
    return () {
      _slideGroup.closeAll();
      onTap();
    };
  }

  /// The tap for a row that is ours alone, or null when the spot carries
  /// nothing restorable at all — a row must not accept a tap it cannot honor.
  VoidCallback? _retuneActionFor(Map<String, dynamic> spot) {
    if (_freqOf(spot) == null && _bandOf(spot) == null && _modeOf(spot) == null) return null;
    return () => _retuneToSelfSpot(spot);
  }

  /// Tapped a self row: put the VFO back in the state the spot announced —
  /// frequency (band follows it) and mode, everything the VFO holds, but
  /// nothing QSO-shaped. Through [RadioService.setVfo] like the `setVfo`
  /// command action, so CAT re-tunes a connected radio. A freq-less spot
  /// still restores what it can: its band (which clears the frequency,
  /// per setVfo's convention) and/or mode.
  ///
  /// The mode is uppercased for the same reason as [_spotModeFor] (sources
  /// pass their API's casing through), and more than a display concern here:
  /// the VFO's mode persists and seeds every subsequently logged QSO. Not
  /// [_spotModeFor] itself — its `''` for an absent mode would clobber the
  /// VFO's mode where null leaves it alone.
  void _retuneToSelfSpot(Map<String, dynamic> spot) {
    final freq = _freqOf(spot);
    final mode = _modeOf(spot)?.toUpperCase();
    if (freq != null) {
      widget.services.radio.setVfo('vfoA', freq: freq, mode: mode);
    } else {
      widget.services.radio.setVfo('vfoA', band: _bandOf(spot), mode: mode);
    }
  }

  /// The individual operators on a spot. A merged multi-op spot carries them
  /// comma-joined in `their.call` (see `mergeSpotsByFreqAndRefs`), which is
  /// why this cannot just read that field as one key.
  List<String> _operatorCallsOf(Map<String, dynamic> spot) =>
      (_callOf(spot) ?? '').split(',').map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toList();

  /// Whether the tile at `(section, index)` is the current QSO's row, and so
  /// carries [_currentRowKey].
  bool _isCurrentRow(int section, int index) {
    final at = _currentRowAt;
    return at != null && at.section == section && at.index == index;
  }

  /// Runs [locateCurrentSpotRow] over this build's sections and keeps what it
  /// found, for [_revealCurrent] and for the row key.
  ///
  /// Every declared height goes through [_rowHeightScale], headers included:
  /// the headers are text in constant padding like the rows, and a sum that
  /// scaled only one of the two would drift by a header on every section.
  /// For the header that is not an estimate but the extent the sliver is
  /// pinned at — see [_sectionHeaderExtent].
  void _locateCurrentRow(
    List<({String key, String label, List<Map<String, dynamic>> spots})> sections,
    String? currentCall,
  ) {
    final found = locateCurrentSpotRow(
      [for (final section in sections) section.spots],
      currentCall: currentCall,
      headerHeight: _sectionHeaderExtent,
      heightOf: (spot) => _spotRowHeightOf(spot) * _rowHeightScale,
    );
    _currentRowAt = found == null ? null : (section: found.section, index: found.index);
    _currentRowPosition = found == null ? null : (top: found.top, height: found.height);
    _keyedRowCall = found == null ? null : currentCall;

    // The first row of the first section is the calibration row: it is the one
    // row that is certainly mounted on a panel that has just been built, which
    // is where the reading has to come from — a scale learned only after the
    // first reveal would be learned one reveal too late.
    final first = sections.isEmpty || sections.first.spots.isEmpty ? null : sections.first.spots.first;
    _calibrationDeclared = first == null || _isCurrentRow(0, 0) ? null : _spotRowHeightOf(first);
  }

  /// Learns [_rowHeightScale] from the calibration row, if this build placed
  /// one and the viewport mounted it. Silent when it did not: the row is only
  /// mounted near the top of the list, and a scale already learned holds until
  /// something moves that row back into view.
  void _calibrateRowHeight() {
    if (!mounted) return;
    final declared = _calibrationDeclared;
    if (declared == null || declared <= 0) return;
    final box = _calibrationKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || box.size.height <= 0) return;

    final scale = box.size.height / declared;
    // A reading this close changes no offset the correction couldn't absorb,
    // and settling for it is what stops a rebuild from re-triggering a rebuild.
    if ((scale - _rowHeightScale).abs() < 0.005) return;
    setState(() => _rowHeightScale = scale);
    // The geometry every pending reveal was armed against has just moved, so
    // let the next build arm again rather than leaving a call retired against
    // offsets that were wrong when they were summed.
    _revealedCall = null;
  }

  /// Schedules a scroll when the current QSO's call has changed since the last
  /// one this panel revealed. Skipped entirely while the panel is hidden, and
  /// [_revealedCall] is left alone there rather than cleared — that is what
  /// makes the call still pending when the tab comes back.
  void _armReveal(String? currentCall) {
    if (!_onScreen || currentCall == _revealedCall) return;
    // No row for it — on the board a call is typed against, or nothing typed
    // at all. Left un-latched in the first case, so the reveal still happens
    // when the spot for that call arrives on the next fetch.
    if (currentCall != null && _currentRowPosition == null) return;
    _revealedCall = currentCall;
    _correctedRevealFor = null;
    if (currentCall == null) return;
    // A slide put this call in the fields — the operator is looking straight
    // at its row and dragging it, so there is nothing to bring into view and
    // moving the list would pull the row out from under the finger. Latched
    // rather than skipped, so the scroll does not simply arrive late once the
    // row closes with the call still in the fields.
    //
    // The peeked call, not merely "some row is open": this is the one give-up
    // in this machine that a later frame does NOT recover from, so it may only
    // retire the call the slide itself put there. A call from anywhere else —
    // typed while a row sits open, or a peek held back above work in progress
    // — is nobody's peek and still reveals.
    if (currentCall == _peekedCall) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The latch moving between arming and here means something in the same
      // post-frame batch superseded this reveal — [_calibrateRowHeight] clears
      // it when the geometry it was armed against turns out to be wrong. Bail
      // without touching the latch: nulling it would retract whatever re-armed.
      if (_revealedCall != currentCall) return;
      // Un-latched whenever the reveal gave up, which is permission for the
      // next rebuild to try again rather than a retry in itself — deliberately,
      // since a reveal that cannot succeed (a pane collapsed to no height)
      // would otherwise rebuild the panel forever. Every reason it gives up is
      // one a later frame recovers from, and a latch left set would retire that
      // callsign for the rest of the session.
      if (!_revealCurrent(currentCall)) _revealedCall = null;
    });
  }

  /// Brings the current QSO's row into view, scrolling the least that does it
  /// — a row already fully visible doesn't move, so typing a call that happens
  /// to be on screen never yanks the list out from under the operator. Returns
  /// whether it got far enough to decide; already-visible counts as revealed.
  ///
  /// Works out where the row *is* arithmetically, like `qso_list.dart`'s
  /// `_revealSelected` and for the same reason: a row outside the viewport
  /// either isn't built or carries a paint transform from wherever it last
  /// sat, and both read as a confident, wrong position.
  ///
  /// [locateCurrentSpotRow] does the arithmetic and says what it is exact
  /// about; [_correctRevealFor] closes the rest — an emoji the note lookup had
  /// not yet reported when the offsets were summed.
  ///
  /// [call] is passed in rather than read back off [_revealedCall]: this runs a
  /// frame after it was scheduled, and reading the latch here means a reveal
  /// can find it moved and quietly scroll nothing while still reporting done.
  bool _revealCurrent(String call) {
    if (!mounted || !_scrollController.hasClients || !_onScreen) return false;
    final at = _currentRowPosition;
    if (at == null) return false;

    final scroll = _scrollTo(at.top, at.top + at.height);
    if (_correctedRevealFor != call) {
      // Chained to the scroll's completion, because measuring a row in flight
      // reads a position it is about to leave. Scheduled even when nothing
      // moved: "the estimate says it is already on screen" is exactly the claim
      // an accumulated drift makes wrongly, and it is the one case no later
      // step would otherwise check.
      if (scroll == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _correctRevealFor(call));
      } else {
        scroll.whenComplete(() => _correctRevealFor(call));
      }
    }
    return true;
  }

  /// One measured pass over whatever the summed offsets got wrong, once the
  /// row is close enough to measure honestly. That sum is exact for the row
  /// shapes [spotRowHeightFor] knows, so this is a safety net rather than the
  /// thing that lands the scroll: a note emoji the lookup had not reported when
  /// the offsets were summed, or a tile that grew without those constants
  /// growing with it. Not the headers — those are pinned at a stated extent,
  /// which is the same figure the sum counts.
  ///
  /// Latches [_correctedRevealFor] where it ACTS, not where it is scheduled:
  /// every return below is a reason it could not measure at all, and retiring
  /// the call on one of those would leave the estimate's drift standing with
  /// nothing left to close it. Latching here still can't loop — one correction
  /// is scheduled per arm, and this ignores its own scroll's future.
  void _correctRevealFor(String call) {
    if (!mounted || !_scrollController.hasClients || !_onScreen) return;
    if (_revealedCall != call || _keyedRowCall != call) return;
    // Null when the viewport never mounted this row — the list builds every
    // child widget but only inflates the ones within reach of where it landed.
    // Which is the case this correction exists for: the estimate was off by
    // more than that reach, so there is nothing here to measure.
    final box = _currentRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderBox || !viewport.attached) return;

    final position = _scrollController.position;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    // Beyond what the viewport plus its cache can hold is a stale transform,
    // not a row waiting to be nudged. Measured against the cache extent as well
    // as the viewport: a row laid out in the cache is honestly measurable, and
    // in a pane shorter than the cache the viewport alone would reject it.
    final reach = math.max(position.viewportDimension, RenderAbstractViewport.defaultCacheExtent);
    if (top < -reach || top > position.viewportDimension + reach) return;
    _correctedRevealFor = call;
    _scrollTo(position.pixels + top, position.pixels + top + box.size.height);
  }

  /// A section header's height: the extent every one of them is pinned at, and
  /// the figure both the reveal's arithmetic and its leading inset count with.
  /// Scaled like the rows for the reasons [_rowHeightScale] gives.
  double get _sectionHeaderExtent => _metrics.sectionHeaderHeight * _rowHeightScale;

  /// Scrolls to [spotScrollTarget]'s answer, or not at all when there is none.
  /// Returns the scroll's future, or null when nothing moved.
  Future<void>? _scrollTo(double top, double bottom) {
    final position = _scrollController.position;
    final target = spotScrollTarget(
      top: top,
      bottom: bottom,
      headerHeight: _sectionHeaderExtent,
      pixels: position.pixels,
      viewport: position.viewportDimension,
      minExtent: position.minScrollExtent,
      maxExtent: position.maxScrollExtent,
    );
    if (target == null) return null;
    return _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  /// Maps a `sectionSpots` section key to its display label. The flat
  /// `'spots'` section reads as the actual band once the Band filter has
  /// narrowed to one — "All Spots" while filtered to a single band would
  /// misleadingly suggest the filter had no effect.
  String _sectionLabel(Translations t, String key) => switch (key) {
        'self' => t.operation.spots.yourSpots,
        'notes' => t.operation.spots.callsOfNote,
        'spots' => _isSingleBandFilter ? _bandFilter : t.operation.spots.allSpots,
        '?' => t.operation.spots.unknownBand,
        _ => key,
      };

  /// Whether the Band filter has narrowed to one specific band ('auto' and
  /// 'any' both leave multiple bands possible).
  bool get _isSingleBandFilter => _bandFilter != 'auto' && _bandFilter != 'any';
}

/// Pins a [_SpotsSectionHeader] to the top of the spots list while its own
/// section's rows scroll under it, the way `qso_list.dart` pins its day
/// headers.
class _SpotsSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;

  /// Resolved by the caller: `minExtent`/`maxExtent` are asked for outside
  /// [build], where there is no context to read a metric from.
  final double extent;

  const _SpotsSectionHeaderDelegate({required this.label, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      // Forced to exactly [extent]: a pinned header that paints taller than it
      // declared trips Flutter's "layoutExtent exceeds paintExtent" assertion.
      SizedBox(height: extent, child: _SpotsSectionHeader(label));

  @override
  bool shouldRebuild(_SpotsSectionHeaderDelegate old) => old.label != label || old.extent != extent;
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
      // No height of its own: [_SpotsSectionHeaderDelegate] imposes the one it
      // declared to the sliver protocol, which is a QSO list day header's.
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
        // The band is what the operator is looking for, and the row is exactly
        // one line tall: a label too long for a narrow pane gives up its spot
        // count rather than wrapping into a second line the pinned extent
        // would clip off.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    // The DISPLAYED mode — measuring the stored `LSB` for a row that renders
    // `SSB` reserves a width no row uses.
    final mode = displayMode(_modeOf(spot), freqKHz: freq, band: _bandOf(spot));
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

  /// This spot reads as worked: either every operator on it has already been
  /// worked on this band and mode — the `duplicate` alert from [SpotsPanel]'s
  /// candidate scoring — or the operator slid it aside. Dimmed, per app-polo's
  /// SpotItem `type: 'duplicate'`.
  final bool worked;

  /// [spotDisplayFlags]'s `worked`: every operator on this spot is already in
  /// the log for this band and mode and no scorer raised a notice about it —
  /// a notice deliberately un-strikes a duplicate, since it says there is
  /// something here worth working anyway. Struck through, and NOTHING else
  /// strikes a row: the strikethrough answers "have I worked this call", so a
  /// spot merely set aside must not borrow it, and a slide that puts a
  /// duplicate back on the board must not take it away.
  final bool logged;

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

  /// Fill for the row of the QSO being logged right now
  /// ([currentQsoHighlight]), null for every other row. Painted behind the
  /// content rather than folded into the text styles like [worked] and
  /// [isSelf]: those say something about the spot, this says which row the
  /// operator's own attention is on.
  final Color? highlight;

  const _SpotTile({
    super.key,
    required this.spot,
    this.noteEmoji,
    this.hzDigits = 0,
    this.leftWidth = 120,
    this.sortByAge = false,
    this.activityControls = const [],
    this.onTap,
    this.worked = false,
    this.logged = false,
    this.isSelf = false,
    this.notices = const {},
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final haloColors = HaLoColors.of(context);
    final metrics = LayoutDensity.metricsOf(context);

    // The row-wide accents, applied by folding them into the two base styles
    // every field below derives from. app-polo's SpotItem spreads a
    // `commonStyle` across each of its Texts for the same effect.
    // The dim is folded into every colour rather than wrapped around the row in
    // an `Opacity`: that widget forces a saveLayer per row, and on a board where
    // most spots are worked that is a compositing layer for every visible row on
    // every frame of a scroll. EVERY colour the row paints has to go through
    // [faded] for that to hold — one that skips it is a part of the row that
    // does not dim, and wrapping the row to catch it dims everything twice.
    final dim = worked ? 0.6 : (isSelf ? 0.7 : 1.0);
    Color faded(Color color) => dim == 1.0 ? color : color.withValues(alpha: color.a * dim);

    final baseColor = faded(isSelf ? theme.colorScheme.tertiary : theme.colorScheme.onSurface);
    final decoration = logged ? TextDecoration.lineThrough : null;

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
    final spotBand = _bandOf(spot);
    final spotMode = _modeOf(spot);
    final modeUnexpected = isUnexpectedSideband(spotMode, freqKHz: freqKHz, band: spotBand);
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
          // A kHz reading, the same as the QSO list's — thousands mark
          // between MHz and kHz, decimal point before the Hz digits, both in
          // the operator's own conventions. Below 1 MHz (630m, 2200m) there
          // is no thousands group at all, and `0,472` is not a reading anyone
          // writes.
          if (int.parse(parts.mhz) > 0) ...[
            Text(groupDigits(parts.mhz), style: freqStyle.copyWith(fontWeight: FontWeight.w700)),
            Text(NumberFormatting.instance.groupingSeparator, style: freqStyle),
            Text(parts.khz, style: freqStyle),
          ] else
            Text(int.parse(parts.khz).toString(), style: freqStyle.copyWith(fontWeight: FontWeight.w700)),
          if (parts.hz != null) ...[
            Text(NumberFormatting.instance.decimalSeparator, style: freqStyle),
            Text(parts.hz!, style: freqStyle.copyWith(fontSize: (freqStyle.fontSize ?? 14) * 0.8)),
          ],
        ],
      );
    }

    final refs = _refsOf(spot);
    final refType = refs.isEmpty ? null : asSpotString(refs.first['type']);
    final refIcon = iconForRefType(activityControls, refType) ?? _iconOf(spot) ?? 'radio-tower';
    // The extension's declared accent tints its icon (the same tint the
    // Activities picker and the logging pills use), so a POTA row reads as
    // POTA at a glance. The notice accents stay on the label text: the icon
    // says WHAT the ref is, the text says why this row matters.
    final extensionColor = colorForRefType(activityControls, refType);
    final refIconColor = extensionColor != null ? faded(extensionColor) : (refAccent ?? (isSelf ? baseColor : outlineColor));

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
                // The one thing on the row a colour cannot dim: an emoji is
                // painted by the font, not by its style. So it gets the layer
                // the rest of the row deliberately avoids — and only rows that
                // actually carry a note pay for it, which is a small minority
                // rather than every visible row of a scroll.
                dim == 1.0
                    ? flagGlyph(noteEmoji!, shadows: glyphGlow(theme))
                    : Opacity(opacity: dim, child: flagGlyph(noteEmoji!, shadows: glyphGlow(theme))),
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
                color: refIconColor,
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
      padding: PaneSafeArea.symmetricOf(
        context,
        horizontal: 12,
        vertical: metrics.spotTilePaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(freqField, callLine),
          SizedBox(height: metrics.spotTileLineGap),
          line(
            Text(
              displayMode(spotMode, freqKHz: freqKHz, band: spotBand) ?? '',
              // The error color outranks the `newMode` accent: a sideband this
              // band doesn't run is a reason not to tap the spot, where a new
              // mode is a reason to.
              style: accented(proportional, modeUnexpected ? faded(theme.colorScheme.error) : modeAccent) ??
                  proportional,
            ),
            labelLine,
          ),
        ],
      ),
    );

    final row = onTap == null
        ? tile
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: tile),
          );
    // The divider and the slide both live in the panel's `_SlidableSpotRow`
    // wrapper, not here: a tile's KEY changes as it becomes the current row,
    // which discards this subtree, and a gesture cannot survive inside
    // something that gets discarded mid-drag.
    return highlight == null ? row : ColoredBox(color: highlight!, child: row);
  }
}

/// One of the two actions a spot row slides to reveal.
class _SlideAction {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  /// Fired once when this side first comes into view during a drag — before
  /// anything is committed. What separates "showing you what this would do"
  /// from doing it.
  final VoidCallback? onRevealed;

  /// The counterpart to [onRevealed]: the peek was given up without this
  /// action ever firing — dragged back, closed by another row, scrolled away.
  /// Whatever [onRevealed] put on screen belongs to the open row and may not
  /// outlive it.
  final VoidCallback? onWithdrawn;

  /// The row has come to rest open on this side and the finger is off it.
  /// Anything that has to face the operator waits for this: a dialog raised
  /// mid-drag takes the pointer while the drag runs on underneath it, and the
  /// release still commits.
  final VoidCallback? onSettled;

  const _SlideAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.onRevealed,
    this.onWithdrawn,
    this.onSettled,
  });
}

/// How much of a row an action panel occupies when the row rests open. Sized
/// for a tap target around a bare icon — the actions carry no label, so this
/// is a button's width rather than a word's, and the row's own height (which
/// shrinks with the density) never enters into it.
const _slideActionWidth = 72.0;

/// How far a drag must travel before the row will rest open on release —
/// and, on the way past it, the point at which the spot becomes the suggested
/// QSO. Both meanings are the same moment on purpose: it is where the gesture
/// stops being a twitch and starts being a choice of station.
const _slidePeekThreshold = _slideActionWidth / 2;

/// The share of the row's WIDTH a drag must pass for release to fire the
/// action outright rather than resting open. Two fifths is the point where
/// the gesture stops reading as "show me the button" and starts reading as
/// "do it" — and it is far enough from [_slidePeekThreshold] that settling
/// open is never a near-miss of firing.
const _slideCommitFraction = 0.4;

/// How much more horizontal than vertical a touch must be before it is taken
/// as a slide rather than a scroll — see
/// [_AxisLockedHorizontalDragGestureRecognizer].
const _slideAxisDominance = 1.0;

/// Wins the arena only for a drag that is going SIDEWAYS, not merely one that
/// has drifted the touch slop sideways on its way down the list.
///
/// A plain horizontal recognizer accumulates the horizontal component alone
/// and claims the pointer the moment it passes the slop, no matter how much
/// further the finger travelled vertically in the same span: a thumb scroll
/// arcs, so the arc opens a row. It bites hardest where the slop is widest —
/// iOS reports no device slop and so uses the 18px default, roughly twice
/// what Android's devices report, which leaves the arena unresolved over more
/// of the arc.
class _AxisLockedHorizontalDragGestureRecognizer extends HorizontalDragGestureRecognizer {
  _AxisLockedHorizontalDragGestureRecognizer({super.debugOwner});

  /// Where each tracked finger landed. Per pointer, because a drag can be
  /// tracking several: a palm or a second thumb landing across the row would
  /// otherwise become the origin the FIRST finger's travel is measured from,
  /// which reads as a long sideways move and lets through exactly the scroll
  /// this class exists to refuse.
  final Map<int, Offset> _origins = <int, Offset>{};

  /// How far the finger being judged has travelled since it landed, or null
  /// when there is nothing to judge by — a trackpad pan, which arrives with no
  /// down event and so no origin, leaves the base recognizer's own test to
  /// decide rather than being measured against a touch that has since lifted.
  Offset? _travel;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origins[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    // BEFORE super, which is what asks the question below — and about THIS
    // event's pointer, not whichever one moved last.
    final origin = event is PointerMoveEvent ? _origins[event.pointer] : null;
    _travel = origin == null ? null : event.position - origin;
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) _origins.remove(event.pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _origins.clear();
    _travel = null;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    if (!super.hasSufficientGlobalDistanceToAccept(pointerDeviceKind, deviceTouchSlop)) return false;
    final travel = _travel;
    if (travel == null) return true;
    // Measured from where the finger landed rather than from the recognizer's
    // own signed accumulation, so a there-and-back wobble counts as the small
    // horizontal travel it is. Losing here is not final: the finger can turn
    // and win later, for as long as the list has not claimed the pointer.
    return travel.dx.abs() > travel.dy.abs() * _slideAxisDominance;
  }
}

/// Declares the row's slide to assistive technology, which a `RawGestureDetector`
/// otherwise cannot here: the default delegate finds the drag by looking the
/// EXACT [HorizontalDragGestureRecognizer] type up in the gesture map, and this
/// row registers a subclass under its own type — a map that cannot be keyed by
/// the base type either, since `RawGestureDetector` asserts the two match. With
/// no delegate the scroll-left/right actions disappear, and with them the only
/// route a screen-reader user has to the actions: the buttons exist on screen
/// only while the row is displaced.
///
/// One synthesised drag, start to end, exactly as the default delegate makes
/// one — a whole gesture rather than a fragment, because the row acts on
/// release and would otherwise be left sitting open.
class _SlideSemanticsDelegate extends SemanticsGestureDelegate {
  const _SlideSemanticsDelegate({required this.onStart, required this.onUpdate, required this.onEnd});

  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject.onHorizontalDragUpdate = (details) {
      onStart(DragStartDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ));
      onUpdate(details);
      onEnd(DragEndDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ));
    };
  }
}

/// Which rows are open, so only ever one is. A row registers itself as it
/// opens and the previous one closes; a tap on any row, and any edit to the
/// call being logged, clear the group outright. Scrolling deliberately does
/// not — see the list in `_SpotsPanelState.build`.
class _SlideGroup extends ChangeNotifier {
  /// Every row that is open, not just the latest one — because a row can
  /// REFUSE to close, which it does while a finger is still on it (see
  /// [_SlidableSpotRowState.close]). A group that tracked one row would have
  /// to forget a refuser to make room for the next, and a forgotten row is
  /// open with nothing able to close it: every later slide then leaves another
  /// beside it, until the list is a column of open rows. The refusal is not a
  /// rare path — crossing the peek suggests the QSO, which edits the call being
  /// logged, whose `closeSlidesSerial` lands here mid-drag.
  ///
  /// One row is still all the operator ever sees open: every row opening
  /// closes the others, and a refuser is closed at the next opportunity
  /// instead of being abandoned.
  final _open = <_SlidableSpotRowState>{};

  void opened(_SlidableSpotRowState row) {
    _closeAllExcept(row);
    _open.add(row);
  }

  void closed(_SlidableSpotRowState row) => _open.remove(row);

  void closeAll() => _closeAllExcept(null);

  void _closeAllExcept(_SlidableSpotRowState? keep) {
    for (final row in _open.toList()) {
      if (identical(row, keep)) continue;
      // A row that actually moves deregisters through [closed] on its way to
      // rest. The other two answers leave it here, and both are fine: a
      // refusal (a finger still on it) is closed the next time something asks,
      // and a row already at zero displacement — registered on drag start,
      // not yet moved — is deregistered by its own drag ending.
      row.close();
    }
  }
}

/// A spot row that slides horizontally to reveal one action on each side.
///
/// Wraps only the row's CONTENT: the divider and the row's outer box stay
/// still, so a sliding row moves within a list whose ruling does not. The
/// action layer is `Positioned.fill` inside a `Stack` sized by the content,
/// and the content moves by a `Transform` — neither changes the row's height,
/// which `spotRowHeightFor` declares and the reveal's scroll arithmetic sums
/// for rows it cannot see.
///
/// The content carries its own opaque background because the actions sit
/// BEHIND it; a transparent row would show the action it has not uncovered.
class _SlidableSpotRow extends StatefulWidget {
  /// Revealed by dragging right (sits against the leading edge), and by
  /// dragging left respectively. A null side does not drag.
  final _SlideAction? leading;
  final _SlideAction? trailing;

  /// Painted behind the row's content WHILE IT IS DISPLACED, so the action
  /// layer only shows where the content has actually moved off it. A row at
  /// rest paints no fill of its own, exactly as it did before it could slide.
  final Color background;

  final _SlideGroup group;
  final Widget child;

  const _SlidableSpotRow({
    super.key,
    required this.group,
    required this.background,
    required this.child,
    this.leading,
    this.trailing,
  });

  @override
  State<_SlidableSpotRow> createState() => _SlidableSpotRowState();
}

class _SlidableSpotRowState extends State<_SlidableSpotRow> {
  /// How far the content is currently displaced. Positive reveals [leading].
  double _dx = 0;

  /// Whether the drag is currently past the commit threshold. Kept so the
  /// haptic fires on the CROSSING rather than per drag frame, in both
  /// directions: reversing back under the threshold is a promise that release
  /// will no longer fire, and it deserves the same tick that promised it would.
  bool _pastCommit = false;

  /// Which side has passed the peek threshold, so [_SlideAction.onRevealed]
  /// and its tick fire once per open rather than on every drag frame.
  int _revealedSign = 0;

  /// Whether a finger is down. The displacement follows the finger exactly
  /// while it is, and eases to its resting place once it lifts — one value,
  /// two durations, rather than a controller this row would have to own and
  /// tear down as the list recycles it.
  bool _dragging = false;

  /// The pointers currently down on this row, and whether the one that ended
  /// the gesture was taken away rather than lifted. Both are written from the
  /// `Listener` below, which sees each event BEFORE the gesture recognizer
  /// does: render objects on the hit-test path are dispatched to ahead of
  /// `GestureBinding`, which is what routes the event on to the recognizer
  /// that then reports the end.
  ///
  /// Counted rather than a bare flag because a cancel is only this gesture's
  /// end when it is the LAST pointer to go: a palm or second thumb the system
  /// takes away mid-drag must not disarm the release the operator still
  /// makes, which would swallow the contact with no trace anywhere.
  final Set<int> _downPointers = <int>{};
  bool _cancelled = false;

  @override
  void dispose() {
    widget.group.closed(this);
    // A row can be DISCARDED while open, without ever closing: its key carries
    // the spot's own timestamp, so an ordinary poll that re-spots the station
    // rebuilds it as a different row and this State goes away mid-peek. What
    // the peek filled would otherwise sit in the logging fields with no open
    // row left to take it back — the very leftover this whole gesture is
    // careful about everywhere else.
    //
    // After the frame: dispose runs inside `finalizeTree`, where reaching up
    // to set state on the operation view is illegal.
    final action = _revealedSign > 0 ? widget.leading : (_revealedSign < 0 ? widget.trailing : null);
    final withdrawn = action?.onWithdrawn;
    if (withdrawn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => withdrawn());
    }
    super.dispose();
  }

  /// Slides shut without firing anything — what the group calls on the row
  /// that was open when another one opens. Returns whether it actually did:
  /// a row refuses while a finger is on it, and the group has to keep
  /// tracking one that refused.
  bool close() {
    if (!mounted) return true;
    if (_dx == 0) return true;
    // Never while the finger is down. Crossing the peek suggests the QSO,
    // which edits the call being logged, whose `closeSlidesSerial` closes open
    // rows — including this one. Zeroing the displacement there
    // would restart the drag from nothing under a finger that never lifted:
    // the row jumps back, can no longer reach the commit point, and re-crossing
    // the peek suggests a second time. It also deregisters the row, so it can
    // come to rest open with the group believing nothing is.
    if (_dragging) return false;
    _animateTo(0);
    return true;
  }

  void _animateTo(double target) {
    setState(() {
      _dragging = false;
      _dx = target;
    });
    if (target == 0) {
      widget.group.closed(this);
      _pastCommit = false;
      _withdraw();
    }
  }

  /// Gives up the peek without firing its action. Everything [_SlideAction
  /// .onRevealed] put on screen is undone here, so a spot's hold on the
  /// logging fields lasts exactly as long as its row stays open.
  void _withdraw() {
    final sign = _revealedSign;
    _revealedSign = 0;
    if (sign == 0) return;
    (sign > 0 ? widget.leading : widget.trailing)?.onWithdrawn?.call();
  }

  /// Runs an action and closes the row. The peek is SPENT rather than
  /// withdrawn: what it revealed is what the action is about to act on, and
  /// withdrawing it here would take the suggested QSO out of the logging
  /// fields the log is made from.
  void _fire(_SlideAction action) {
    _revealedSign = 0;
    _animateTo(0);
    action.onPressed();
  }

  void _onDragStart(DragStartDetails details) {
    _cancelled = false;

    setState(() => _dragging = true);
    widget.group.opened(this);
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    final max = widget.leading == null ? 0.0 : width;
    final min = widget.trailing == null ? 0.0 : -width;
    final next = (_dx + (details.primaryDelta ?? 0)).clamp(min, max);
    // Two thresholds, two different weights of feedback, so the hand can tell
    // them apart without looking: a medium tap where the station is picked up,
    // a heavier one where releasing would act on it. Both are impacts rather
    // than selection ticks — the gesture is made without looking, often on a
    // phone in a pocket-sized grip, so the feedback has to carry.
    final sign = next.abs() < _slidePeekThreshold ? 0 : (next > 0 ? 1 : -1);
    if (sign != _revealedSign) {
      // Withdraw first, then reveal: dragging back through the middle and out
      // the other side is one gesture, and the incoming side's suggestion must
      // land AFTER the outgoing side has taken its own back.
      _withdraw();
      if (sign != 0) {
        _revealedSign = sign;
        HapticFeedback.mediumImpact();
        (sign > 0 ? widget.leading : widget.trailing)?.onRevealed?.call();
      }
    }
    final past = next.abs() >= width * _slideCommitFraction;
    if (past != _pastCommit) {
      // On the way out this says "release now and it happens"; on the way back
      // it says it no longer will. Both deserve saying, and both are the
      // heavier of the two so neither is mistaken for the peek.
      HapticFeedback.heavyImpact();
      _pastCommit = past;
    }
    setState(() => _dx = next);
  }

  void _onDragEnd(DragEndDetails details, double width) {
    // Act only on evidence that the operator actually let go. An ACCEPTED drag
    // reports a cancelled pointer as an ordinary end — and `onHorizontalDrag
    // Cancel` only ever fires BEFORE acceptance, where no row has been touched
    // — so without this a system gesture claiming the touch, or the app going
    // to the background, LOGS A CONTACT nobody released. A pointer still down
    // at the end means the same thing by another route: the recognizer also
    // ends a drag whose buttons change mid-gesture, with no cancel to see.
    //
    // Shutting the row rather than resting it open takes the peek back with
    // it — [_animateTo] withdraws at zero — which is what keeps a station the
    // operator never chose out of the logging fields.
    if (_cancelled || _downPointers.isNotEmpty) {
      _animateTo(0);
      return;
    }
    final action = _dx > 0 ? widget.leading : widget.trailing;
    if (_pastCommit && action != null) {
      // Fire on release, then slide shut — the row has done its job and
      // leaving the button sitting there invites a second press.
      _fire(action);
      return;
    }
    // Far enough to mean it: rest open with the button exposed to tap.
    // Anything shorter was a stray horizontal wobble during a scroll.
    if (_dx.abs() >= _slidePeekThreshold) {
      _animateTo(_dx > 0 ? _slideActionWidth : -_slideActionWidth);
      action?.onSettled?.call();
    } else {
      _animateTo(0);
    }
  }

  Widget _actionPanel(
    _SlideAction action, {
    required bool leading,
    required double width,
    required double revealed,
  }) {
    // Grows with the drag, so past the commit threshold the action fills the
    // row and reads as the thing about to happen rather than as a button
    // waiting to be pressed.
    revealed = revealed.clamp(0.0, width);
    final past = revealed >= width * _slideCommitFraction;
    // Past the commit point the icon crosses its well to sit against the row
    // it will act on — the same edge the row is being dragged by. Before it,
    // the icon centres in whatever width is revealed, so it arrives with the
    // well and sits centred in it once the row rests open, like the button it
    // still is. The move is the visible half of what the heavy tick says:
    // this is armed now.
    final alignment = past
        ? (leading ? Alignment.centerRight : Alignment.centerLeft)
        : Alignment.center;
    return Align(
      alignment: leading ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: revealed,
        child: Material(
          color: action.background,
          child: InkWell(
            onTap: () => _fire(action),
            // The label is a screen-reader one only: these are bare icons, and
            // this repo has no tooltips (a `tooltip:` anywhere in lib fails a
            // source-scanning test), so Semantics is where the word lives.
            child: Semantics(
              label: action.label,
              button: true,
              child: ClipRect(
                child: AnimatedAlign(
                  alignment: alignment,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Icon(action.icon, color: action.foreground, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A hairline divider between rows, painted over the row's bottom edge
    // (foreground) so it adds no height — lighter than the section header's
    // 3px rule so rows read as subdivisions within a group. OUTSIDE the
    // slide, so the ruling between rows stays put while a row moves under it.
    Widget ruled(Widget child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: child,
        );

    if (widget.leading == null && widget.trailing == null) return ruled(widget.child);
    return ruled(LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Listener(
          // The only place a cancelled touch can be told apart from a lifted
          // one — see [_downPointers]. Behaviour left at the default,
          // `deferToChild`, so this listens over exactly the region the
          // gesture below it drags on, and widens nothing.
          onPointerDown: (event) => _downPointers.add(event.pointer),
          onPointerUp: (event) => _downPointers.remove(event.pointer),
          onPointerCancel: (event) {
            _downPointers.remove(event.pointer);
            if (_downPointers.isEmpty) _cancelled = true;
          },
          child: RawGestureDetector(
            // Horizontal only — the enclosing scroll view keeps the vertical
            // axis, and the narrow layout's TabBarView has page-swiping
            // disabled, so nothing else is competing for this drag. Raw rather
            // than a `GestureDetector` for the sake of the recognizer, which is
            // the one thing keeping a scroll from opening a row.
            gestures: <Type, GestureRecognizerFactory>{
              _AxisLockedHorizontalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<_AxisLockedHorizontalDragGestureRecognizer>(
                () => _AxisLockedHorizontalDragGestureRecognizer(debugOwner: this),
                (instance) {
                  instance
                    ..onStart = _onDragStart
                    ..onUpdate = ((d) => _onDragUpdate(d, width))
                    ..onEnd = ((d) => _onDragEnd(d, width))
                    // The device's own slop, as a `GestureDetector` would have
                    // set it — the enclosing list reads the same one.
                    ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
                },
              ),
            },
            semantics: _SlideSemanticsDelegate(
              onStart: _onDragStart,
              onUpdate: (d) => _onDragUpdate(d, width),
              onEnd: (d) => _onDragEnd(d, width),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _dx),
              // Zero while the finger is down, so the row tracks it exactly
              // rather than lagging behind its own gesture.
              duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              // The panel behind is sized from the SAME animating value as the
              // row in front, so the two stay edge to edge through a snap
              // instead of the panel jumping to its target while the row eases.
              builder: (context, dx, child) {
                final stack = Stack(
                  children: [
                    // Only while there is something to see: an idle row pays for
                    // no extra layer, which matters on a board scrolled fast.
                    if (dx != 0)
                      Positioned.fill(
                        child: dx > 0
                            ? _actionPanel(widget.leading!, leading: true, width: width, revealed: dx)
                            : _actionPanel(widget.trailing!, leading: false, width: width, revealed: -dx),
                      ),
                    Transform.translate(
                      offset: Offset(dx, 0),
                      // Opaque ONLY while displaced: the actions sit behind the
                      // row, so a transparent row would show the one it has not
                      // uncovered — but a row at rest must paint exactly what it
                      // painted before it could slide, down to having no fill.
                      child: dx == 0 ? child! : ColoredBox(color: widget.background, child: child!),
                    ),
                  ],
                );
                // The displaced content is clipped to the row's box — the width
                // of the list itself — so a row dragged to the edge stops at it
                // instead of painting over whatever sits beside the spot list.
                // `Clip.none` rather than dropping the widget while the row
                // rests: it allocates no layer either, and keeping the widget
                // type stable across that boundary keeps the row's subtree —
                // global keys, ink splashes and all — from being re-inflated at
                // the frame a slide starts and again at the one it ends.
                return ClipRect(
                  clipBehavior: dx == 0 ? Clip.none : Clip.hardEdge,
                  child: stack,
                );
              },
              child: widget.child,
            ),
          ),
        );
      },
    ));
  }
}

class _SpotsFilterPill extends StatelessWidget {
  final String bandLabel;
  final String modeLabel;
  final int ageMinutes;
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
                      const SizedBox(width: Space.sm),
                      _FilterInfoPill(icon: 'clock', label: '${ageMinutes}m', onTap: onTap),
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
      phoneCwModeFilter => t.operation.spots.phoneAndCw,
      _ => option,
    };

/// The band/mode summary for the collapsed filter pill: the RESOLVED value
/// first, tagged as followed (e.g. "20m (Auto)", "Phone (Auto)") — the
/// value is what the operator scans for, the tag says it will move with the
/// VFO. (The filter dialog's dropdowns spell it out the other way round via
/// [_bandOptionLabel]/[_modeOptionLabel].) 'auto' with no resolved band/mode
/// falls back to the all-bands/all-modes label. Public for unit testing.
String spotsFilterBandPillLabel(Translations t, String option, String? autoBand) => switch (option) {
      'auto' => autoBand != null ? t.operation.spots.valueAuto(value: autoBand) : t.operation.spots.allBands,
      'any' => t.operation.spots.allBands,
      _ => option,
    };

String spotsFilterModePillLabel(Translations t, String option, String? autoMode) => switch (option) {
      'auto' => autoMode != null ? t.operation.spots.valueAuto(value: autoMode) : t.operation.spots.allModes,
      'any' => t.operation.spots.allModes,
      phoneCwModeFilter => t.operation.spots.phoneAndCw,
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
  final int ageMinutes;
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

  /// Sources that never answered the last fetch, and those that answered with
  /// an error. Both show in place of a spot count, which for either of them
  /// would read "0 spots" — indistinguishable from a quiet band.
  final Set<String> unavailableSources;
  final Set<String> failedSources;
  final Set<String> disabledSources;
  final Map<String, int> continentSpotCounts;
  final Set<String> disabledContinents;
  final ValueChanged<String> onBandChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<int> onAgeChanged;
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
    required this.unavailableSources,
    required this.failedSources,
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
  late int _ageMinutes = widget.ageMinutes;
  late String _sortBy = widget.sortBy;
  late bool _groupByBand = widget.groupByBand;
  late bool _groupCallsWithNotes = widget.groupCallsWithNotes;
  late final Set<String> _disabledSources = {...widget.disabledSources};
  late final Set<String> _disabledContinents = {...widget.disabledContinents};

  /// A source row's trailing label: its spot count, or why it hasn't got one.
  /// A source in trouble contributes no spots at all, so the plain count
  /// would say "0 spots" — the same thing a healthy source on a dead band
  /// says, and the confusion this whole distinction exists to end.
  Widget _sourceStatus(String source) {
    final t = context.t;
    final theme = Theme.of(context);
    final trouble = widget.unavailableSources.contains(source) || widget.failedSources.contains(source);
    return Text(
      widget.unavailableSources.contains(source)
          ? t.operation.spots.filters.sourceNoReply
          : widget.failedSources.contains(source)
              ? t.operation.spots.filters.sourceError
              : t.operation.spots.spotsCount(count: widget.sourceSpotCounts[source] ?? 0),
      style: trouble ? TextStyle(color: theme.colorScheme.error) : null,
    );
  }

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
    final modeOptions = ['auto', 'any', phoneCwModeFilter, ..._superModes];

    return HaloDialog(
      wide: true,
      // A list of filters, not a form: rows and section bands run to the
      // card's edges and inset their contents instead (SettingsList).
      list: true,
      // The body scrolls ITSELF, because its bands pin — a section band that
      // holds the top while its own rows scroll under it needs a sliver
      // viewport, which the shell's plain scroll view is not.
      scrollable: false,
      title: Text(t.operation.spots.filters.title),
      content: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterDropdown(
                  label: t.operation.spots.filters.band,
                  initialSelection: _bandFilter,
                  entries: [
                    for (final option in bandOptions)
                      DropdownMenuEntry(value: option, label: _bandEntryLabel(t, option)),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _bandFilter = value);
                    widget.onBandChanged(value);
                  },
                ),
                _filterDropdown(
                  label: t.operation.spots.filters.mode,
                  initialSelection: _modeFilter,
                  entries: [
                    for (final option in modeOptions)
                      DropdownMenuEntry(value: option, label: _modeEntryLabel(t, option)),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _modeFilter = value);
                    widget.onModeChanged(value);
                  },
                ),
                _filterDropdown<int>(
                  label: t.operation.spots.filters.age,
                  initialSelection: _ageMinutes,
                  entries: [
                    for (final minutes in _ageOptionsInMinutes)
                      DropdownMenuEntry(
                        value: minutes,
                        label:
                            '${t.operation.spots.ageMinutes(minutes: minutes)} (${widget.ageSpotCounts[minutes] ?? 0})',
                      ),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() => _ageMinutes = value);
                    widget.onAgeChanged(value);
                  },
                ),
              ],
            ),
          ),
          SectionHeader.section(context, t.operation.spots.filters.sorting, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: settingsRowInset, vertical: Space.sm),
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
            _toggleRow(
              title: t.operation.spots.filters.groupByBand,
              value: _groupByBand,
              // Grouping by band is meaningless once the Band filter has
              // already narrowed to one band — every spot would land in
              // the same single section anyway.
              onChanged: _isSingleBandFilter
                  ? null
                  : (value) {
                      setState(() => _groupByBand = value);
                      widget.onGroupByBandChanged(value);
                    },
            ),
            _toggleRow(
              title: t.operation.spots.filters.groupCallsWithNotes,
              value: _groupCallsWithNotes,
              onChanged: (value) {
                setState(() => _groupCallsWithNotes = value);
                widget.onGroupCallsWithNotesChanged(value);
              },
            ),
          ]),
          if (widget.sources.isNotEmpty)
            SectionHeader.section(context, t.operation.spots.filters.sources, children: [
              for (final source in widget.sources)
                _toggleRow(
                  title: widget.sourceNames[source] ?? source,
                  value: !_disabledSources.contains(source),
                  trailing: _sourceStatus(source),
                  onChanged: (_) {
                    setState(
                      () => _disabledSources.contains(source)
                          ? _disabledSources.remove(source)
                          : _disabledSources.add(source),
                    );
                    widget.onToggleSource(source);
                  },
                ),
            ]),
          SectionHeader.section(context, t.operation.spots.filters.continent, children: [
            for (final code in _continentCodes)
              _toggleRow(
                title: _continentLabel(t, code),
                value: !_disabledContinents.contains(code),
                trailing: Text(t.operation.spots.spotsCount(count: widget.continentSpotCounts[code] ?? 0)),
                onChanged: (_) {
                  setState(
                    () => _disabledContinents.contains(code)
                        ? _disabledContinents.remove(code)
                        : _disabledContinents.add(code),
                  );
                  widget.onToggleContinent(code);
                },
              ),
          ]),
        ],
      ),

      // Done, not Apply: every toggle above has already taken effect on the
      // spots list behind this dialog, so there is nothing left for a button
      // to apply. In the `cancel` slot rather than `actions` because it is a
      // way out, not a confirm — see user-interface.md §Dialogs.
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.done)),
    );
  }

  /// A filter row, in the shape every settings row in the app takes: bold
  /// title, whatever the row has to report about itself, and a switch the
  /// WHOLE row works — a title that looks like the rest of the list and does
  /// nothing reads as a broken row.
  Widget _toggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing, const SizedBox(width: Space.md)],
          Switch(value: value, onChanged: onChanged),
        ],
      ),
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged(!value),
      mouseCursor: onChanged == null ? null : SystemMouseCursors.click,
    );
  }

  /// One of the three pickers above the sections. Fixed-width and centred:
  /// a dropdown stretched to a wide dialog's full width would put its label
  /// and its value at opposite ends of the card.
  Widget _filterDropdown<T>({
    required String label,
    required T? initialSelection,
    required List<DropdownMenuEntry<T>> entries,
    required ValueChanged<T?> onSelected,
  }) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: DropdownMenu<T>(
          trailingIcon: dropdownTrailingIcon,
          selectedTrailingIcon: dropdownSelectedTrailingIcon,
          initialSelection: initialSelection,
          width: _dropdownWidth,
          menuHeight: dropdownMenuMaxHeight(context),
          // Pick-only; search's rebuild-time scrollToHighlight would snap the
          // open menu back to the selection whenever spots stream in.
          enableSearch: false,
          label: Text(label),
          dropdownMenuEntries: entries,
          onSelected: onSelected,
        ),
      );

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
