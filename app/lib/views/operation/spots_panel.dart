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

import '../../services/chase_service.dart';
import '../../services/hook_payloads.dart';
import '../../services/radio_service.dart';
import '../../services/settings_service.dart';
import '../../services/halo_services.dart';
import '../../services/spot_board.dart';
import '../../services/spot_board_service.dart';
import '../../services/spots_service.dart';
import 'package:halo_i18n/halo_i18n.dart';

part 'spots_panel_filter_state.dart';
part 'spots_panel_filters.dart';
part 'spots_panel_list.dart';
part 'spots_panel_reveal_state.dart';
part 'spots_panel_slide.dart';
part 'spots_panel_tile.dart';

/// Height of the initial-load progress bar above the spots list — reserved
/// whether or not a fetch is running, matching LinearProgressIndicator's own
/// default thickness. Same value/convention as
/// activities_view_sections.dart's `_searchProgressHeight`.
const _spotsProgressHeight = 4.0;

/// A spot map's fields come from a JS extension across the hook bridge,
/// which enforces nothing about their runtime type — every read below is a
/// probe (`asSpotString`/`asSpotNum`/`asSpotMap`, spots_service.dart — shared
/// with `callOfSpot`/`timeOfSpot` there, which describe this same wire
/// shape), not a trusted cast, so one hook shipping a wrong-typed field
/// degrades that single field to "absent" instead of throwing out of a
/// getter every other spot's build depends on. `getSpots` (extension_hook_api.dart)
/// reports a wrong-typed field once, silently, per source; nothing here does.
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

String? _labelOf(Map<String, dynamic> spot) => asSpotString(asSpotMap(spot['spot'])?['label']);

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
    final noted = spots.where((s) => spotOperatorCalls(s).any(callsWithNotes.contains)).toList();
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

/// The bands the filter dropdown offers, in the canonical [bands] order and
/// without the leading `auto`/`any` entries.
///
/// The enabled bands are the point of the list, but two more earn a place:
/// a band that currently HAS spots (so nothing visible under `any` is
/// unfilterable), and the [selected] one (a filter persisted before its band
/// was disabled stays on screen instead of the dropdown disagreeing with what
/// is actually filtering). Public for `spots_panel_merge_test.dart`.
List<String> spotsFilterBandOptions({required Set<String> enabledBands, required Map<String, int> bandSpotCounts, required String selected}) => [
  for (final band in bands.map((b) => b.name))
    if (enabledBands.isEmpty || enabledBands.contains(band) || (bandSpotCounts[band] ?? 0) > 0 || band == selected) band,
];

/// Every source that gets a row in the filter dialog, sorted: every installed
/// source, plus any source that offered spots, went quiet or answered with
/// an error.
///
/// The union is the point. A source that offers no spots has no key in
/// `spotsBySource`, whether it is in trouble, idle (QSO Party Spots outside a
/// party weekend) or opted out (WWFF with no API key). Listing only those
/// keys would drop it from the filter, and the operator could not see that
/// it is installed, let alone turn it off ahead of time. `installed` alone is
/// not enough either: a source reporting spots or trouble is listed even if
/// the name lookup missed it. Public for `spots_panel_merge_test.dart`.
List<String> spotsFilterSourceList({
  required Iterable<String> installed,
  required Iterable<String> withSpots,
  required Iterable<String> unavailable,
  required Iterable<String> failed,
}) => {...installed, ...withSpots, ...unavailable, ...failed}.toList()..sort();

String _timeAgo(int millis) {
  final seconds = (nowMillis() - millis) ~/ 1000;
  if (seconds < 60) return '${seconds}s ago';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ago';
  return '${minutes ~/ 60}h${minutes % 60}m ago';
}

/// Whether [spot] is for the callsign being logged right now — [currentCall],
/// already uppercased. Any operator on a merged multi-op spot counts, the
/// same reading of `their.call` that flags `isSelf`.
///
/// Exact: a portable or fixed suffix is a different station to work, so
/// W1AW/P must not light up while W1AW is being entered. Public for
/// `spots_panel_current_qso_test.dart`.
bool spotIsCurrentQso(Map<String, dynamic> spot, {String? currentCall}) {
  if (currentCall == null || currentCall.isEmpty) return false;
  return spotOperatorCalls(spot).contains(currentCall);
}

/// The operator's overrides of what scoring says about a spot row: worked
/// (slid left to set it aside), or NOT worked — which is how a genuine
/// duplicate is put back on the board, and how an ignore is taken back.
/// Either way it moves only the row's dim: the strikethrough is scoring's
/// alone (see [_SpotTile.logged]), so a restored duplicate comes back at full
/// contrast still struck. An override never touches the log; nothing here can
/// un-work a contact.
///
/// Keyed by the row's operators: one call for a plain spot, so the same
/// operator re-spotted on another frequency keeps the verdict — the case the
/// gesture exists for — and the sorted set of calls for a spot that merged
/// several. A merged row's verdict is its own: sliding it never rewrites one
/// the operator gave a member call by itself, so a merge the operator did not
/// cause cannot reverse a verdict they did give.
class SpotWorkedOverrides {
  final _verdicts = <String, bool>{};

  static String _rowKey(List<String> calls) => (calls..sort()).join(',');

  /// Whether [spot] reads as worked, [scored] being what candidate scoring
  /// says about it: the row's own verdict, else one EVERY operator on it
  /// carries — the "all of them" rule scoring itself uses, so one dismissed
  /// operator cannot hide a station still worth working, and one restored
  /// operator cannot un-dim the rest — else [scored].
  bool isWorked(Map<String, dynamic> spot, {required bool scored}) {
    final calls = spotOperatorCalls(spot).toList();
    if (calls.isEmpty) return scored;
    if (_verdicts[_rowKey(calls)] case final own?) return own;
    final verdicts = calls.map((call) => _verdicts[call]).toSet();
    final agreed = verdicts.length == 1 ? verdicts.first : null;
    return agreed ?? scored;
  }

  /// Slid left: flip what the row says about having been worked. [worked] is
  /// what it says now, so this always reverses the thing the operator is
  /// looking at.
  void toggle(Map<String, dynamic> spot, {required bool worked}) => _verdicts[_rowKey(spotOperatorCalls(spot).toList())] = !worked;
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
Color currentQsoHighlight(ColorScheme scheme, {required bool editing}) =>
    Color.lerp(scheme.surface, editing ? scheme.secondaryContainer : scheme.tertiaryContainer, 0.5)!;

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
/// at a text scale of 1.3. [SpotRevealState.rowHeightScale] measures that
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
double spotRowHeightFor({required LayoutMetrics metrics, required bool hasLabel, required bool hasEmoji}) =>
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
/// A call can match more than one row — "Calls of Note" pins a duplicate of a
/// spot that stays in its band section too. [scrollCostOf] prices bringing a
/// row's span into view, and the cheapest copy wins, ties going to the first:
/// picking a spot from its band row puts that call in the fields, and jumping
/// to its pinned copy at the top would pull the list out from under the row
/// the operator just tapped. Without [scrollCostOf] the first match wins.
/// [keep] names a copy chosen earlier; while it still matches, it wins
/// outright, whatever the costs say now.
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
  double Function(double top, double bottom)? scrollCostOf,
  ({int section, int index})? keep,
}) {
  ({int section, int index, double top, double height})? best;
  double? bestCost;
  var top = 0.0;
  for (final (sectionIndex, section) in sections.indexed) {
    // Its own section's header sits above it, so this one counts too.
    top += headerHeight;
    for (final (index, spot) in section.indexed) {
      final height = heightOf(spot);
      if (spotIsCurrentQso(spot, currentCall: currentCall)) {
        final found = (section: sectionIndex, index: index, top: top, height: height);
        if (scrollCostOf == null || keep == (section: sectionIndex, index: index)) return found;
        final cost = scrollCostOf(top, top + height);
        if (bestCost == null || cost < bestCost) (best, bestCost) = (found, cost);
      }
      top += height;
    }
  }
  return best;
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

  /// The Chasing view's panel: spots read chasing verdicts rather than the
  /// operation's scoring, and sort and filter by them as `ChaseService`'s
  /// options say.
  final bool chasing;

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
    this.chasing = false,
  });

  @override
  State<SpotsPanel> createState() => _SpotsPanelState();
}

class _SpotsPanelState extends State<SpotsPanel> with _SpotsList {
  Map<String, String> _sourceNames = {};
  int _sourceNamesRequest = 0;
  List<Map<String, dynamic>> _activityControls = [];
  late final SpotBoardSubscription _boardView;
  bool _refreshing = false;

  @override
  SpotsService get _spots => widget.services.spots;
  Map<String, List<Map<String, dynamic>>> get _spotsBySource => _spots.spotsBySource;
  @override
  bool get _loading => !_spots.loaded;
  String? get _error => _spots.error?.toString();

  /// The filters the operator picked, and the VFO band/mode and band list
  /// they read.
  @override
  late final SpotsFilterState _filterState = SpotsFilterState(settings: widget.services.settings, radio: widget.services.radio);

  /// The board's call info and verdicts are SpotBoardService's, worked out
  /// once for this panel and every extension reading the board through
  /// `getSpots`.
  SpotBoardService get _board => widget.services.spotBoard;
  @override
  Map<String, SpotCallInfo> get _callNotes => _board.callInfo;
  String? _entityOf(String call) => _callNotes[call]?.entityPrefix;
  Map<String, SpotScore> get _spotScores => _board.scoresFor(widget.operation.uuid) ?? const {};

  @override
  final _scrollController = ScrollController();

  /// Identifies the current QSO's row, for the reveal's measured
  /// correction, and the calibration row, for its row-height reading — see
  /// [SpotRevealState].
  @override
  final _currentRowKey = GlobalKey();
  @override
  final _calibrationKey = GlobalKey();

  @override
  late final SpotRevealState _reveal = SpotRevealState(_SpotsListView(this, () => setState(() {})));

  /// Cached rather than read where it is used, like `qso_list.dart`'s own:
  /// [_revealCurrent] runs from a post-frame callback, outside build, where
  /// depending on an inherited widget is not allowed — and the cache is also
  /// what keeps the header height the scroll arithmetic uses identical to the
  /// one the headers paint with.
  @override
  late LayoutMetrics _metrics;

  /// What the operator's slides say about rows being worked — see
  /// [SpotWorkedOverrides]. In memory deliberately: this is a "not this one,
  /// right now" about a board that turns over every few minutes, not a fact
  /// about the station worth outliving the app.
  @override
  final _workedOverrides = SpotWorkedOverrides();

  /// Keeps one row's actions open at a time.
  @override
  final _SlideGroup _slideGroup = _SlideGroup();

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
    if (_metricsSet && !identical(metrics, _metrics)) _reveal.densityChanged(_metrics, metrics);
    _metrics = metrics;
    _metricsSet = true;
    // The revealed call is deliberately left alone in both directions, matching
    // the tab half in `_onVisibilityChanged`: a call typed while this pane was
    // behind another is already pending, because [SpotRevealState.arm] returns before
    // latching while off screen — and one already revealed stays revealed, so
    // flipping to another pane in the group and back does not yank the list
    // away from wherever the operator scrolled it.
    _dockVisible = DockPaneVisibility.of(context);
  }

  @override
  void initState() {
    super.initState();
    widget.visible.addListener(_onVisibilityChanged);
    _filterState.addListener(_onFiltersChanged);
    // The panel is a consumer, not the owner: the Operation View already
    // holds the board — and through it the spots — so the `spot-history`
    // lookup and extension panels have them whether or not this panel was
    // ever opened. Subscribing again, and showing it this panel's operation,
    // is what keeps the board worked out if that ever stops being true — as
    // a follower, so a covered view's panel, mounting late, cannot take the
    // board from the view in front.
    _boardView = _board.subscribe(follower: true);
    _board.addListener(_onBoardChanged);
    _boardView.show(widget.operation, widget.qsos, logRevision: widget.logRevision, chasing: widget.chasing);
    // Not on the 2-min spots refresh timer — a hook's `sourceName` is static —
    // but on every runtime start: these keys decide which sources the filter
    // lists, and an install, removal or late activation changes the set.
    unawaited(_loadSourceNames());
    widget.services.extensions.runtimeGeneration.addListener(_loadSourceNames);
    // Same activity ref-type -> icon source QsoList uses (via
    // iconForRefType) — unconditional per extension (POTA/SOTA's own
    // loggingControls always register their hunting ref type, regardless
    // of whether this operation has that activity added), not tied to the
    // operation's own configured activities, since a spot can be for any
    // hunted activity type.
    unawaited(_loadActivityControls());
  }

  /// Through `whenSettled`: a booting or replaced runtime answers with no
  /// sources at all, which would leave every idle source out of the filter.
  /// Only the latest request lands, since generations can follow each other
  /// faster than a load settles.
  Future<void> _loadSourceNames() async {
    final request = ++_sourceNamesRequest;
    final names = await widget.services.extensions.whenSettled(widget.services.extensions.getSpotSourceNames);
    if (mounted && request == _sourceNamesRequest) setState(() => _sourceNames = names);
  }

  /// Fetched once, and nothing re-runs it: these decide every spot row's
  /// activity icon, so a failure leaves the panel rendering hunted activities
  /// with generic icons for the session. There is nothing on screen to keep
  /// at first load, so waiting out a booting runtime is the whole defence.
  Future<void> _loadActivityControls() async {
    await widget.services.extensions.start();
    if (!mounted) return;
    final result = await widget.services.extensions.loggingControls(operationPayloadFor(widget.operation));
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
    widget.services.extensions.runtimeGeneration.removeListener(_loadSourceNames);
    _filterState.dispose();
    _board.removeListener(_onBoardChanged);
    widget.visible.removeListener(_onVisibilityChanged);
    _boardView.cancel();
    _scrollController.dispose();
    _slideGroup.dispose();
    super.dispose();
  }

  /// Becoming the visible pane re-arms the reveal, so a call typed while this
  /// was behind another tab is scrolled to on arrival rather than left
  /// wherever the list happened to be.
  ///
  /// Deliberately not a reveal on the spot: the list may not have been rebuilt
  /// since, and [SpotRevealState.locate]'s position would place the row from a list
  /// that has moved on. Re-arming and letting the next build decide costs one
  /// rebuild per tab switch and cannot act on a stale position. The setState
  /// waits for the frame because the notifier fires from the operation view's
  /// own build.
  void _onVisibilityChanged() {
    if (!_onScreen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_onScreen) return;
      // A bare rebuild is the whole job. [SpotRevealState.arm] returns before latching
      // while hidden, so a call entered behind another tab is still unequal to
      // the latch and arms itself the moment this build runs — and one that was
      // already revealed still matches, so coming back to the tab does not
      // yank the list to a row the operator last saw exactly where it is.
      setState(() {});
    });
  }

  void _onFiltersChanged() {
    if (mounted) setState(() {});
  }

  /// The board moved — a fetch settled, verdicts or call info arrived — so
  /// rebuild against it.
  void _onBoardChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SpotsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logRevision != oldWidget.logRevision || !identical(widget.operation, oldWidget.operation)) {
      _boardView.show(widget.operation, widget.qsos, logRevision: widget.logRevision, chasing: widget.chasing);
    }
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

  /// The base calls of every one of this operation's station callsigns —
  /// the spots to tint rather than offer as a contact. Every call, split out
  /// of the raw comma-separated field, which as one string matches no spot.
  /// Kept per raw field, because every spot row asks on every build.
  @override
  Set<String> get _ourBaseCalls {
    final raw = widget.operation.stationCall;
    if (raw != _ourBaseCallsFor) {
      _ourBaseCallsFor = raw;
      _ourBaseCallsCache = {
        for (final call in widget.operation.stationCalls)
          if (baseCallOf(call) case final base when base.isNotEmpty) base,
      };
    }
    return _ourBaseCallsCache;
  }

  String? _ourBaseCallsFor;
  Set<String> _ourBaseCallsCache = const {};

  @override
  ({bool worked, bool isSelf, Set<String> notices}) _flagsFor(Map<String, dynamic> spot) =>
      spotDisplayFlags(spot, scores: _spotScores, ourBaseCalls: _ourBaseCalls);

  @override
  Set<String> _newRefsFor(Map<String, dynamic> spot, Set<String> notices) => spotNewRefs(spot, notices: notices, judgements: _board.judgements);

  /// The most icons a row draws. A spot can carry many more — several
  /// scorers, programs and merged sources' references — and every icon is a
  /// fixed width the label gives up.
  static const _maxSpotIcons = 3;

  @override
  List<SpotIcon> _iconsFor(Map<String, dynamic> spot, Set<String> notices) => spotIconsWithin(
    spotIcons(
      spot,
      controls: _activityControls,
      scoreIcons: _board.scoreIconsFor(widget.operation.uuid) ?? const {},
      notices: notices,
      judgements: _board.judgements,
      programs: widget.services.chase.programs,
    ),
    _maxSpotIcons,
  );

  /// The sort the list follows: the Chasing view keeps its own.
  @override
  String get _sortBy => widget.chasing ? widget.services.chase.spotsSortBy : _filterState.sortBy;

  /// [spots] as the Chasing view shows them: only those alerting when the
  /// operator asked for that, in its own sort. Elsewhere they are already as
  /// the board's filters left them.
  List<Map<String, dynamic>> _chaseOrder(List<Map<String, dynamic>> spots) {
    if (!widget.chasing) return spots;
    final chase = widget.services.chase;
    final shown = chase.alertingOnly
        ? spots.where((spot) => _flagsFor(spot).notices.any((key) => ChaseNotice.tryParse(key)?.alerting ?? false)).toList()
        : spots;
    if (_sortBy != kChaseSortWanted) return sortSpots(shown, _sortBy);
    return sortSpotsByWanted(shown, rankOf: _rankOf, worked: (spot) => _flagsFor(spot).worked);
  }

  /// The best rank among [spot]'s operators ([ChaseService.rankOf]).
  ChaseRank? _rankOf(Map<String, dynamic> spot) {
    final chase = widget.services.chase;
    ChaseRank? best;
    for (final call in spotOperatorCalls(spot)) {
      final rank = chase.rankOf(_board.judgements[spotCandidateKey(call, spot)] ?? const []);
      if (rank != null && (best == null || rank.rank > best.rank || (rank.rank == best.rank && rank.goal < best.goal))) best = rank;
    }
    return best;
  }

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
        widget.services.statusBar.setMessage(key: 'spots:not-refreshed', icon: 'cloud-off', text: context.t.spotting.notRefreshedOffline);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// The note emoji to show on a spot's tile — the first of its operators
  /// that has one, so a multi-op spot still shows a marker when any op is
  /// noted (the compound `their.call` never matches `_callNotes`).
  @override
  String? _noteEmojiOf(Map<String, dynamic> spot) {
    for (final call in spotOperatorCalls(spot)) {
      final emoji = _callNotes[call]?.emoji;
      if (emoji != null) return emoji;
    }
    return null;
  }

  Future<void> _openFilterDialog() {
    // Computed once and shared — merging independently for each count map
    // would re-run the merge pipeline from scratch 4x per dialog open.
    final filters = _filterState;
    final merged = filters.mergedSpots(_spotsBySource, entityOf: _entityOf);
    // Every count except the per-band ones is drawn from the spots the panel
    // would actually show, so the "any (n)" entries agree with what picking
    // them does. Per-band counts stay drawn from the full merge: they are what
    // qualifies a non-enabled band for the list at all, and what tells the
    // operator there is something out there worth switching bands for.
    final onEnabledBands = spotsOnEnabledBands(merged, filters.enabledBands);
    return showHaloDialog<void>(
      context: context,
      builder: (context) => _SpotsFilterDialog(
        bandFilter: filters.bandFilter,
        modeFilter: filters.modeFilter,
        ageMinutes: filters.ageMinutes,
        autoBand: widget.services.radio.vfoA.band,
        autoMode: superModeForMode(widget.services.radio.vfoA.mode),
        enabledBands: filters.enabledBands,
        totalSpotCount: onEnabledBands.length,
        bandSpotCounts: spotBandCounts(merged),
        modeSpotCounts: spotModeCounts(onEnabledBands),
        ageSpotCounts: spotAgeCounts(onEnabledBands),
        sortBy: _sortBy,
        offersWanted: widget.chasing,
        alertingOnly: widget.chasing ? widget.services.chase.alertingOnly : null,
        onAlertingOnlyChanged: widget.chasing ? widget.services.chase.setAlertingOnly : null,
        groupByBand: filters.groupByBand,
        groupCallsWithNotes: filters.groupCallsWithNotes,
        sources: spotsFilterSourceList(
          installed: _sourceNames.keys,
          withSpots: _spotsBySource.keys,
          unavailable: _spots.unavailableSources,
          failed: _spots.failedSources,
        ),
        sourceNames: _sourceNames,
        sourceSpotCounts: _spotsBySource.map((key, spots) => MapEntry(key, spots.length)),
        unavailableSources: _spots.unavailableSources.toSet(),
        failedSources: _spots.failedSources.toSet(),
        disabledSources: filters.disabledSources,
        continentSpotCounts: spotContinentCounts(filters.rawSpots(_spotsBySource), (call) => _callNotes[call]?.continent),
        disabledContinents: filters.disabledContinents,
        onBandChanged: filters.setBandFilter,
        onModeChanged: filters.setModeFilter,
        onAgeChanged: filters.setAgeMinutes,
        onSortByChanged: widget.chasing ? widget.services.chase.setSpotsSortBy : filters.setSortBy,
        onGroupByBandChanged: filters.setGroupByBand,
        onGroupCallsWithNotesChanged: filters.setGroupCallsWithNotes,
        onToggleSource: filters.toggleSource,
        onToggleContinent: filters.toggleContinent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final vfo = widget.services.radio.vfoA;

    // The board asks no spot source for this operation (see
    // `SpotBoardService.spotsAllowed`), and what it still holds came from
    // another one — so no list at all, rather than those spots.
    if (!widget.operation.assistance) {
      _reveal.forget();
      return Column(
        children: [
          _SpotsFilterPill(
            bandLabel: spotsFilterBandPillLabel(t, _filterState.bandFilter, vfo.band),
            modeLabel: spotsFilterModePillLabel(t, _filterState.modeFilter, superModeForMode(vfo.mode)),
            ageMinutes: _filterState.ageMinutes,
            filteredCount: 0,
            totalCount: 0,
            onTap: _openFilterDialog,
            onRefresh: _refresh,
            refreshing: false,
            loading: false,
            disabled: true,
          ),
          const Spacer(),
        ],
      );
    }

    if (_error != null) {
      // There is no list while this shows, so nothing is revealed on it.
      _reveal.forget();
      return Center(
        child: Text(t.operation.spots.error(error: _error!), style: theme.textTheme.bodyMedium),
      );
    }

    final summary = _filterState.summarize(
      _filterState.mergedSpots(_spotsBySource, entityOf: _entityOf),
      ourBaseCalls: _ourBaseCalls,
      continentOf: (c) => _callNotes[c]?.continent,
    );
    final filtered = _chaseOrder(summary.filtered);

    return Column(
      children: [
        _SpotsFilterPill(
          bandLabel: spotsFilterBandPillLabel(t, _filterState.bandFilter, vfo.band),
          modeLabel: spotsFilterModePillLabel(t, _filterState.modeFilter, superModeForMode(vfo.mode)),
          ageMinutes: _filterState.ageMinutes,
          filteredCount: filtered.length,
          totalCount: summary.total,
          onTap: _openFilterDialog,
          onRefresh: _refresh,
          refreshing: _refreshing,
          loading: _loading,
        ),
        // Clears the bottom safe area (home indicator) itself — the status
        // footer doesn't reserve it globally; the panel fills behind.
        Expanded(child: SafeArea(top: false, left: false, right: false, child: _buildSpotsList(context, filtered, summary.selfSpots))),
      ],
    );
  }
}
