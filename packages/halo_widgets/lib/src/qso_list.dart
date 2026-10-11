// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list, styled after app-polo's log rows: Roboto Mono data
// columns, hairline dividers, newest QSO at the edge next to the logging
// panel — the bottom, or the top when the panel sits above the list. Row layout follows ham2k/halo-dist#2's field list and
// order: Number (optional) | Time | Frequency (or Band, if no frequency) |
// Mode (only when the operation uses more than one) | Callsign |
// Emoji(s)/Name | References | RST.

import 'package:flutter/material.dart';
// `_revealSelected` measures the selected row against its viewport itself,
// rather than via Scrollable.ensureVisible, whose offsets don't survive this
// list's pinned headers — see there.
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:intl/intl.dart';

import 'call_info_summary.dart' show glyphGlow;
import 'density.dart';
import 'flags.dart';
import 'format_utils.dart';
import 'icon_resolver.dart';
import 'mdi_icons.g.dart';
import 'qso_row_badges.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'semantic_id.dart';
import 'spacing.dart';
import 'theme.dart';

/// Horizontal gap between the row's fields (Number/Time/Frequency/Mode/
/// Callsign/Name/References/RST).
const double _columnGap = 12;

/// The freq/band column when a QSO has neither — a visible placeholder
/// rather than a blank, so "we don't know where this was worked" reads as a
/// fact about the contact instead of an empty column.
const String _noBandLabel = '???';

/// The list's UTC time-column label — `HH:MMz`, or a placeholder when the
/// record has no start time. Shared by the QSO, event, and annotation rows
/// so their time columns can never drift apart.
String _utcTimeLabel(DateTime? time) => time == null ? '--:--z' : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}z';

/// Every time label is the same six mono characters wide, so one measurement
/// stands in for the whole column.
const _timeLabelSample = '00:00z';

/// The plain row's own mono font size — also [AnnotationRow]'s time label.
/// Named so [_QsoListState.didChangeDependencies]'s row-height measurement
/// can't silently drift from what the row it's sizing actually paints at.
const _rowMonoFontSize = 14.0;

/// A hair of headroom in the row's width budget, absorbing the difference
/// between what `textWidth` measures and what layout then rounds to. One
/// logical pixel: far more than the fractions actually observed, and not
/// enough for the eye to find.
const double _fitSlack = 1;

// The row's fixed-size columns. Named because the width budget below has to
// agree with the layout to the pixel — the budget decides a column fits and
// then the Row lays it out, so a literal repeated in both places is a bug
// waiting for someone to change one of them.

/// The Mode column, wide enough for the longest mode name shown.
const double _modeWidth = 42;

/// Which optional columns a row actually shows.
///
/// Widths (#354, ham2k/halo-dist#186) are list-wide and content-derived —
/// the longest callsign, the longest freq — so that every row lines up. What
/// none of them consult is the width the list is actually given: in a narrow
/// split, or at a large font scale, their sum can exceed the row. Name's
/// `Expanded` collapses to zero first and then the fixed columns simply
/// overflow — yellow stripes in debug, and in release a silent clip that hides
/// real logged data with no indication at all.
///
/// So an optional column earns its place by FIT as well as by content: they
/// are added while there is room, in descending order of what the row loses
/// without them. Time, freq and callsign are never dropped (the callsign still
/// never truncates), and Name keeps absorbing whatever is left over.
enum _Column { numbers, dxState, mode, rst, refs, exchange }

@immutable
class _ColumnPlan {
  final Set<_Column> _shown;

  const _ColumnPlan(this._shown);

  bool get showNumbers => _shown.contains(_Column.numbers);
  bool get showDxState => _shown.contains(_Column.dxState);
  bool get showMode => _shown.contains(_Column.mode);
  bool get showRst => _shown.contains(_Column.rst);
  bool get showRefs => _shown.contains(_Column.refs);
  bool get showExchange => _shown.contains(_Column.exchange);
}

/// Country flags on contacts: [dx] only (app-polo's default), [all]
/// contacts, or [none] at all. Stored by `SettingsService.dxFlags`; the rule
/// for what it *means* lives in [_dxStateContentFor], the one surface that
/// honours it (app-polo scopes it to the log row the same way — the call
/// info and information panels always show the entity's flag beside its
/// name).
enum DxFlags { dx, all, none }

/// The DX/State column's content for [qso], if any: a flag when
/// [dxFlags] calls for one — for [DxFlags.dx] that means positive evidence
/// of a DX contact (both sides resolved and different) — falling back to the
/// contact's state whenever there's no flag to show — not just when `!isDX`
/// — so a DX contact whose entity resolved but whose flag lookup came up
/// empty (e.g. a DXCC entity present in lib-country-files but missing from
/// lib-dxcc-data's table) still shows its state instead of going blank. Null
/// when neither is available. Shared by the list-wide column-width
/// precompute and the per-row builder in `_QsoListState.build`, so they can
/// never disagree about what a QSO shows there (ham2k/halo-dist#186).
({String text, bool isFlag, bool guessed})? _dxStateContentFor(Qso qso, String? ourEntityPrefix, DxFlags dxFlags) {
  final theirEntityPrefix = qso.theirEntityPrefix;
  final isDX = theirEntityPrefix != null && ourEntityPrefix != null && theirEntityPrefix != ourEntityPrefix;
  final wantsFlag = switch (dxFlags) {
    DxFlags.all => true,
    DxFlags.dx => isDX,
    DxFlags.none => false,
  };
  final flag = qso.theirFlag;
  final state = qso.theirState;
  if (wantsFlag && flag != null && flag.isNotEmpty) {
    return (text: flag, isFlag: true, guessed: qso.theirFieldIsGuessed('flag'));
  } else if (state != null && state.isNotEmpty) {
    return (text: state, isFlag: false, guessed: qso.theirFieldIsGuessed('state'));
  }
  return null;
}

/// One UTC calendar day in milliseconds — QSOs are grouped by truncating
/// `startAtMillis` to this boundary, matching the scoring extension's own
/// day-sectioning (`extensions/core/scoring/src/index.ts`'s `DAY_IN_MILLIS`),
/// so a day's pinned header lines up with the `daySections` scores cached
/// for that same boundary.
const int _dayInMillis = 1000 * 60 * 60 * 24;

/// The RST column's guaranteed minimum — CW/RTTY's 3-digit RS(T) on both
/// sides.
const String _rstMinSample = '599 599';

/// The list-wide numbering, column widths and day-grouping [_QsoListState]
/// computes with an O(qsos) pass — walking every QSO plus a handful of real
/// text-layout measurements. Cached against [_QsoListMetricsKey] so an
/// unrelated rebuild (a keystroke elsewhere in the operation view, a focus
/// change) reuses the last pass instead of redoing it: on a long log this is
/// the difference between a rebuild that's free and one that stutters.
class _QsoListMetrics {
  final List<int> numbers;
  final double numberWidth;
  final double callsignWidth;
  final double dxStateWidth;
  final double freqWidth;
  final double rstWidth;
  final double exchangeWidth;
  final double refsWidth;

  /// Whether notes markers are all the refs column holds — what lets the
  /// column plan rank it below the exchange.
  final bool refsAreNotesOnly;
  final int hzDigits;
  final bool usesMultipleModes;
  final List<int> dayKeys;
  final List<List<int>> dayGroups;

  const _QsoListMetrics({
    required this.numbers,
    required this.numberWidth,
    required this.callsignWidth,
    required this.dxStateWidth,
    required this.freqWidth,
    required this.rstWidth,
    required this.exchangeWidth,
    required this.refsWidth,
    required this.refsAreNotesOnly,
    required this.hzDigits,
    required this.usesMultipleModes,
    required this.dayKeys,
    required this.dayGroups,
  });
}

/// Everything [_QsoListMetrics] is derived from, besides `context`'s own
/// widget-tree dependencies (folded in separately as `theme`/`textScaler`
/// below since `Theme.of`/`MediaQuery.textScalerOf` aren't valid outside
/// build). Two keys are equal exactly when a recompute would produce the
/// same metrics, so `qsos`/`activityControls` compare by identity — the
/// list-wide passes only ever care about the actual objects a rebuild reused,
/// not about deep content equality, which would cost as much as the pass
/// it's meant to skip.
class _QsoListMetricsKey {
  final List<Qso> qsos;
  final List<Map<String, dynamic>> activityControls;
  final String? ourEntityPrefix;
  final DxFlags dxFlags;
  final bool showQsoNumbers;
  final ThemeData theme;
  final TextScaler textScaler;

  const _QsoListMetricsKey({
    required this.qsos,
    required this.activityControls,
    required this.ourEntityPrefix,
    required this.dxFlags,
    required this.showQsoNumbers,
    required this.theme,
    required this.textScaler,
  });

  bool matches(_QsoListMetricsKey other) =>
      identical(qsos, other.qsos) &&
      identical(activityControls, other.activityControls) &&
      ourEntityPrefix == other.ourEntityPrefix &&
      dxFlags == other.dxFlags &&
      showQsoNumbers == other.showQsoNumbers &&
      identical(theme, other.theme) &&
      textScaler == other.textScaler;
}

class QsoList extends StatefulWidget {
  /// An ordinary QSO row's height, divider included — what a caller divides
  /// its own viewport height by to size a Page Up/Down jump (APP-19; see
  /// `LoggingPanel._pageRows`).
  ///
  /// Plain logical pixels, and deliberately so: the Font Scale setting scales
  /// the whole interface from one root wrapper (see ui-scaling.md), so a row
  /// is this tall at every scale. Day headers and annotation rows are taller,
  /// which makes this an approximation for a mixed list — fine for a jump
  /// nobody counts the rows of, and never used for layout.
  static double rowHeightOf(BuildContext context) => LayoutDensity.metricsOf(context).qsoRowHeight;

  final List<Qso> qsos;
  final String? noQsosLabel;

  /// Whether the empty-state message should read as a warning to check the
  /// radio (HALO-24) rather than the ordinary "nothing here" text — the
  /// caller decides this from the device VFO, mirroring the same condition
  /// that opens the Radio control on mount: no band *and* no frequency, or
  /// no mode.
  final bool needsBandOrMode;

  /// Shown instead of [noQsosLabel] when [needsBandOrMode] is true.
  final String? bandOrModeWarningLabel;

  /// The uuid of the QSO currently loaded for editing in the logging panel,
  /// if any — that row gets the secondary-colored selected treatment.
  final String? selectedUuid;

  /// Tap a row to select/edit it. The caller owns toggle-to-deselect
  /// semantics (tapping the already-selected row again). Deleting is
  /// handled entirely through selecting a row and using the logging
  /// panel's staged delete — there's no separate quick-delete on the row
  /// itself, so a single delete flow can't be bypassed mid-edit.
  final void Function(Qso qso) onSelect;

  /// Tap an event or annotation row (start/break/end, NOTE/TODO/SOLAR/
  /// WEATHER — see `Qso.isEvent`) to select it, distinctly from [onSelect]'s
  /// callsign-row taps. Falls back to [onSelect] when omitted — both load
  /// the same row into the editor either way.
  final void Function(Qso qso)? onSelectEvent;

  /// Tap a day header — the operation view opens the operation's own info
  /// (modal on narrow, the Info pane on wide), the counterpart to tapping a
  /// row for a contact. Null leaves the headers inert.
  final VoidCallback? onTapDayHeader;

  /// Whether to show the RST column (ham2k/halo-dist#1's logging-view
  /// menu) — the underlying data always exists, this only hides the column.
  final bool showRSTFields;

  /// Rcvd before Sent, matching the logging row's own order (`switchSentRcvd`).
  /// The cell has no labels, so the two are indistinguishable once swapped —
  /// which is precisely why it must follow the entry row rather than keep a
  /// fixed order the operator would read the wrong way round.
  final bool switchSentRcvd;

  /// Whether to show the Number column (ham2k/halo-dist#2's logging-view
  /// menu) — the underlying numbering always exists, this only hides it.
  final bool showQsoNumbers;

  /// The active extension logging controls (`operation.data`-scoped, same
  /// list `LoggingControls` uses) — resolved to icons for each ref's `type`
  /// via `iconForRefType`. Empty list falls back to a generic marker icon.
  final List<Map<String, dynamic>> activityControls;

  /// The station's own DXCC entity prefix (e.g. `'K'` for the US), resolved
  /// once per operation — see `OperationView._load`. The DX/State column
  /// only shows the DX flag when this AND the QSO's `theirEntityPrefix` are
  /// both known and differ — positive evidence required. Anything else
  /// (either side unresolved, e.g. this is still loading, or they match)
  /// falls back to the contact's state, same as a same-entity contact would
  /// show, rather than momentarily misflagging every QSO as DX before this
  /// lookup lands.
  final String? ourEntityPrefix;

  /// Which contacts get a country flag in the DX/State column
  /// (`SettingsService.dxFlags`) — see [DxFlags] and [_dxStateContentFor].
  final DxFlags dxFlags;

  /// Raw `daySections` from the scoring hook's last run (see
  /// `ScoringHook.scoreQsos`/`ScoringService.rescoreOperation`), cached in
  /// `Operation.localData['scoring']['daySections']` — each entry is
  /// `{day, count, scores}`, `day` truncated to the same UTC boundary as
  /// [_dayInMillis]. Matched against the locally-computed day groups below
  /// by that `day` key; empty (or a day with no matching entry, e.g. before
  /// the first rescore lands) just means that header shows no score badges.
  final List<Map<String, dynamic>> daySections;

  /// Newest first — days and the rows within them — for a list drawn BELOW
  /// its logging panel, so the live edge is still the one beside the panel.
  /// The list then rests at its top rather than its bottom.
  final bool newestFirst;

  const QsoList({
    super.key,
    required this.qsos,
    required this.onSelect,
    this.onSelectEvent,
    this.onTapDayHeader,
    this.selectedUuid,
    this.noQsosLabel,
    this.needsBandOrMode = false,
    this.bandOrModeWarningLabel,
    this.showRSTFields = true,
    this.switchSentRcvd = false,
    this.showQsoNumbers = true,
    this.activityControls = const [],
    this.ourEntityPrefix,
    this.dxFlags = DxFlags.dx,
    this.daySections = const [],
    this.newestFirst = false,
  });

  @override
  State<QsoList> createState() => _QsoListState();
}

class _QsoListState extends State<QsoList> {
  final _scrollController = ScrollController();
  int _lastQsoCount = 0;
  bool _wasNearLiveEdge = true;
  double? _lastMaxScrollExtent;

  /// Set when contacts arrived at the TOP of a newest-first list while the
  /// operator was reading further down it: everything below them moves down
  /// by what they added, so the next metrics change scrolls by the same
  /// amount and the rows under the pointer stay where they were.
  bool _holdForTopInsert = false;

  /// Attached to whichever row is currently selected, so a selection made
  /// from the keyboard (APP-19 walks the list with the arrow keys) can be
  /// scrolled into view. Only one row is ever selected, so one key is enough.
  final _selectedRowKey = GlobalKey();

  /// The uuid [_selectedRowKey] was actually attached to, recorded as the row
  /// is built and cleared at the start of every build.
  ///
  /// The key alone can't be trusted: when the selected row is far enough away
  /// not to be built, `currentContext` still resolves — to something that is
  /// NOT that row — and measuring it scrolls to the wrong place, or to nowhere
  /// at all. Whether this matches the current selection is the only reliable
  /// answer to "is there a row to measure?".
  String? _keyedRowUuid;

  /// The selection [_correctRevealFor] has already run for — one measured
  /// correction per selection, never a loop of them.
  String? _correctedRevealFor;

  /// The list-wide metrics computed by the last build whose inputs actually
  /// warranted it, and the key that produced them. Null until first build.
  _QsoListMetricsKey? _cachedMetricsKey;
  _QsoListMetrics? _cachedMetrics;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metrics = LayoutDensity.metricsOf(context);
    // The OS accessibility text-scale preference composes on top of the
    // app's own Font Scale (ui-scaling.md §3) and can be NON-linear — unlike
    // the app's own scale, which is one multiplier applied everywhere, the
    // OS curve can grow a 12px line by a different ratio than a 14px one.
    // Sampling it at an arbitrary reference size (the previous fix's
    // `scaler.scale(100) / 100`) reads whatever that curve does at 100px,
    // which nothing in this row paints at — a flat curve above the sizes
    // that actually appear reads as no growth at all while the row's real
    // text keeps growing. Every row/header sits in an exact box (HALO-258),
    // which also rules out `spots_panel`'s own fix (measure a real mounted
    // row's rendered size): `SliverFixedExtentList` forces that size to
    // equal whatever this value already is, so measuring it back would just
    // measure this line's own previous answer. Measuring the TEXT alone via
    // [spansHeight] sidesteps both — a `Text` inside `Row` gets loose
    // cross-axis constraints from `CrossAxisAlignment.center`, so its
    // rendered size is never clamped by the row's own fixed extent, and
    // measuring at the row's OWN font sizes reads the curve where it matters.
    //
    // The growth ratio is measured directly (scaled height ÷ unscaled
    // height for the SAME style), not reconstructed from `qsoRowHeight`'s
    // declared total: that total is "declared rather than measured" (see
    // [LayoutMetrics]'s own doc) and doesn't cleanly decompose into
    // `2×padding + line height + divider` — a style whose real unscaled
    // line height already runs under what that arithmetic would assume can
    // make the reconstructed baseline read too tall, understating growth
    // below 1.0 even while the OS scale is above it.
    //
    // A style's own line-height MULTIPLIER (`AnnotationRow`'s unmodified
    // `bodyMedium` carries Material 3's 1.43×, meant for prose; the plain
    // row's `haloMonoStyle` sets none) cancels out of this ratio — scaling
    // is a function of font SIZE, not of what multiplies it afterward. What
    // actually varies across the row kinds sharing one slot is size, and
    // every row kind now sets 14px (the plain row's mono, and the
    // `bodyMedium` `AnnotationRow` and `EventRow` share). The worst case is
    // what the ONE shared slot has to fit, and what the pinned header
    // (closer to the row's own convention, but not proven identical under
    // every curve) gets sized against too, rather than risk being the one
    // under-provisioned box left after guarding the rest.
    final theme = Theme.of(context);
    double growthOf(TextStyle? style) {
      // Not a "nothing to measure" skip: [_layoutSpans] resolves a null
      // style as `DefaultTextStyle.of(context).style.merge(null)` — the
      // ambient ancestor style, which is what actually paints (same
      // resolution `AnnotationRow`'s own `bodyMedium?.copyWith(...)` relies
      // on). Short-circuiting here would silently drop that style's growth
      // from the max instead of measuring it.
      const sample = [TextSpan(text: _timeLabelSample)];
      final scaled = spansHeight(context, sample, style);
      final unscaled = spansHeight(context, sample, style, textScaler: TextScaler.noScaling);
      assert(unscaled > 0, 'unscaled height measured non-positive for style: $style');
      // Never below 1.0: an OS scale at or under the app's own baseline
      // shouldn't shrink the row below its declared height.
      return unscaled <= 0 ? 1.0 : (scaled / unscaled).clamp(1.0, double.infinity);
    }

    _rowHeightScale = [growthOf(haloMonoStyle(context, fontSize: _rowMonoFontSize)), growthOf(theme.textTheme.bodyMedium)].reduce((a, b) => a > b ? a : b);
  }

  /// The resolved dimensions, refreshed by [didChangeDependencies].
  ///
  /// Cached rather than read where it is used because [_estimatedTopOf] and
  /// [_scrollTo] run from key handlers and post-frame callbacks — outside
  /// build, where depending on an inherited widget is not allowed. The cache
  /// is also what keeps the row height the scroll math uses identical to the
  /// one the rows actually paint with, which is the whole contract — always
  /// read alongside [_rowHeightScale], never `qsoRowHeight`/`sectionHeaderHeight`
  /// alone.
  late LayoutMetrics _metrics;

  /// See [didChangeDependencies]'s doc — the row-height correction factor
  /// [_estimatedTopOf], [_scrollTo] and every fixed sliver extent below
  /// multiply a declared height by, so all four keep agreeing with what the
  /// rows actually paint.
  late double _rowHeightScale;

  @override
  void initState() {
    super.initState();
    _lastQsoCount = widget.qsos.length;
    _wasNearLiveEdge = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLiveEdge());
  }

  @override
  void didUpdateWidget(covariant QsoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final grew = widget.qsos.length > _lastQsoCount;
    _lastQsoCount = widget.qsos.length;
    // Only follow new QSOs when the user is already looking at the live
    // edge — someone scrolled away to review earlier contacts shouldn't get
    // yanked back by the next logged QSO.
    final atLiveEdge = _isNearLiveEdge();
    if (grew && atLiveEdge) {
      _wasNearLiveEdge = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLiveEdge());
    }
    _holdForTopInsert = grew && !atLiveEdge && widget.newestFirst;
    if (widget.selectedUuid != oldWidget.selectedUuid && widget.selectedUuid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  /// Brings the selected row into view, scrolling the least that does it — a
  /// row already fully visible doesn't move at all, so selecting one with the
  /// pointer never yanks the list out from under the operator, while walking
  /// the log with the arrow keys (APP-19) follows it, and a page or Home/End
  /// jump lands on it however far away it was.
  ///
  /// Works out where the row *is* arithmetically, from the fixed row and
  /// header heights, rather than measuring it. Measuring can't answer this:
  /// a row outside the viewport either isn't built, or is built with a stale
  /// paint transform from wherever it last sat — and both read as a confident,
  /// wrong position. (`Scrollable.ensureVisible`/`getOffsetToReveal` don't
  /// survive these slivers either: with a pinned day header above the row,
  /// revealing it at the trailing edge comes back one header-height short.)
  ///
  /// [_correctRevealFor] then fixes up whatever the arithmetic got wrong, once
  /// the row is close enough to measure honestly.
  void _revealSelected() {
    if (!mounted || !_scrollController.hasClients) return;
    final selectedUuid = widget.selectedUuid;
    if (selectedUuid == null) return;
    final index = widget.qsos.indexWhere((qso) => qso.uuid == selectedUuid);
    if (index < 0) return;

    final top = _estimatedTopOf(index);
    final scroll = _scrollTo(top, top + _metrics.qsoRowHeight * _rowHeightScale);
    if (scroll != null && _correctedRevealFor != selectedUuid) {
      // Landing is not arriving: annotation rows are taller than the nominal
      // height, so a long log can drift. One measured pass straightens it out
      // — chained to the scroll's own completion, because measuring a row
      // mid-flight reads a position it is about to leave, and only once, so a
      // drift the correction can't close can't become a loop.
      _correctedRevealFor = selectedUuid;
      scroll.whenComplete(() => _correctRevealFor(selectedUuid));
    }
  }

  /// The scroll offset at which the row for [index] begins: every entry above
  /// it counted as an ordinary row, plus a day header at each day boundary.
  ///
  /// Exact for a log of plain contacts, which is the overwhelming majority of
  /// one; annotation and event rows can be taller, and cost accuracy rather
  /// than correctness — see [_correctRevealFor].
  double _estimatedTopOf(int index) {
    var offset = 0.0;
    int? lastDay;
    // In display order: oldest down to [index], or newest up to it.
    final last = widget.qsos.length - 1;
    final steps = widget.newestFirst ? last - index : index;
    for (var step = 0; step <= steps; step++) {
      final i = widget.newestFirst ? last - step : step;
      final millis = widget.qsos[i].startAtMillis ?? 0;
      final day = millis - (millis % _dayInMillis);
      if (day != lastDay) {
        offset += _metrics.sectionHeaderHeight * _rowHeightScale;
        lastDay = day;
      }
      if (step < steps) offset += _metrics.qsoRowHeight * _rowHeightScale;
    }
    return offset;
  }

  /// Scrolls the least that puts the span [top]..[bottom] (in scroll offsets)
  /// fully on screen. Returns the scroll's future, or null when the span was
  /// already there and nothing moved.
  ///
  /// The leading edge is inset by a day header, because those headers are
  /// **pinned**: a row flush against the top of the viewport sits underneath
  /// one, which would leave the selection somewhere the operator can't see.
  Future<void>? _scrollTo(double top, double bottom) {
    final position = _scrollController.position;
    final headerHeight = _metrics.sectionHeaderHeight * _rowHeightScale;
    final double target;
    if (top - headerHeight < position.pixels) {
      target = top - headerHeight;
    } else if (bottom > position.pixels + position.viewportDimension) {
      target = bottom - position.viewportDimension;
    } else {
      return null; // already fully visible
    }
    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((clamped - position.pixels).abs() < 0.5) return null;
    return _scrollController.animateTo(clamped, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
  }

  /// One measured pass over what [_revealSelected]'s arithmetic left behind.
  ///
  /// Only runs against a row the list actually built this frame — that's what
  /// [_keyedRowUuid] answers, and the plausibility check below covers the rest:
  /// a built-but-not-laid-out row reports a position from wherever it last sat,
  /// which is worth ignoring rather than acting on.
  void _correctRevealFor(String selectedUuid) {
    if (!mounted || !_scrollController.hasClients) return;
    if (widget.selectedUuid != selectedUuid || _keyedRowUuid != selectedUuid) return;
    final box = _selectedRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final RenderObject? viewportObject = RenderAbstractViewport.maybeOf(box);
    if (viewportObject is! RenderBox || !viewportObject.attached) return;

    final position = _scrollController.position;
    final top = box.localToGlobal(Offset.zero, ancestor: viewportObject).dy;
    // A position further than a viewport outside the viewport is a stale
    // transform, not a row waiting to be nudged.
    if (top < -position.viewportDimension || top > position.viewportDimension * 2) return;
    _scrollTo(position.pixels + top, position.pixels + top + box.size.height);
  }

  /// Whether the newest QSO is in view, or nearly — the bottom of the list,
  /// or its top when it runs [QsoList.newestFirst].
  bool _isNearLiveEdge() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    if (widget.newestFirst) return position.pixels - position.minScrollExtent < 120;
    return position.maxScrollExtent - position.pixels < 120;
  }

  void _jumpToLiveEdge() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(widget.newestFirst ? position.minScrollExtent : position.maxScrollExtent);
    _wasNearLiveEdge = true;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0) {
      _wasNearLiveEdge = _isNearLiveEdge();
    }
    return false;
  }

  bool _onScrollMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      final metrics = notification.metrics;
      final previous = _lastMaxScrollExtent;
      if (_holdForTopInsert && previous != null && metrics.maxScrollExtent > previous) {
        _holdForTopInsert = false;
        final added = metrics.maxScrollExtent - previous;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.pixels + added);
        });
      } else if (previous != null && metrics.maxScrollExtent > previous) {
        // If maxScrollExtent increased (e.g. secondary controls expanded,
        // layout resized) and user was near the live edge, keep the newest
        // QSO in view.
        if (_wasNearLiveEdge) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLiveEdge());
        }
      }
      _lastMaxScrollExtent = metrics.maxScrollExtent;
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qsos = widget.qsos;
    final onSelect = widget.onSelect;
    final onSelectEvent = widget.onSelectEvent;
    final selectedUuid = widget.selectedUuid;
    final showRSTFields = widget.showRSTFields;
    final showQsoNumbers = widget.showQsoNumbers;
    final activityControls = widget.activityControls;
    final ourEntityPrefix = widget.ourEntityPrefix;
    final dxFlags = widget.dxFlags;

    // Cleared here and set again by `buildRow` if — and only if — the selected
    // row is among the ones layout actually builds this frame.
    _keyedRowUuid = null;

    final theme = Theme.of(context);
    if (qsos.isEmpty) {
      // The warning only fires while the VFO actually needs attention (the
      // same signal that opens the Radio control on mount) — a band picked
      // by hand with no frequency, or a frequency with no band, already
      // satisfies HALO-24, so it isn't something to warn about here either.
      // Red, unlike the app's other empty-list messages (spots, activities,
      // search), which stay in the dimmed `outline`: this one means "check
      // the radio before you start", because a contact logged on the wrong
      // band is only discovered long after the station is gone.
      final warn = widget.needsBandOrMode;
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            warn ? (widget.bandOrModeWarningLabel ?? 'Please make sure your band and mode are correct') : (widget.noQsosLabel ?? 'No QSOs yet — work someone!'),
            style: theme.textTheme.bodyLarge?.copyWith(color: warn ? theme.colorScheme.error : theme.colorScheme.outline),
          ),
        ),
      );
    }

    // The callsign and frequency — the two columns a row is scanned by —
    // paint past onSurface, halfway to pure black (white in dark mode), so
    // they stand clear of the dim columns beside them without the dim ones
    // dropping back to outline. Local to this list: the theme's onSurface
    // is untouched.
    final strong = Color.lerp(theme.colorScheme.onSurface, theme.brightness == Brightness.dark ? Colors.white : Colors.black, 0.5);
    final mono = haloMonoStyle(context, fontSize: _rowMonoFontSize, color: strong);
    // Halfway from `onSurfaceVariant` to `onSurface`: the
    // variant alone reads too faint for a column of data, while the full
    // onSurface would put the columns level with the callsign they sit
    // behind.
    final monoDim = mono.copyWith(color: Color.lerp(theme.colorScheme.onSurfaceVariant, theme.colorScheme.onSurface, 0.5));
    // Bold, but the same base size as every other field per the issue: "All
    // fields use the same base font size (except for frequency, see below)."
    final callStyle = mono.copyWith(fontWeight: FontWeight.w700);

    // The list-wide numbering, column widths and day-grouping below are an
    // O(qsos) pass with real text-layout measurements — expensive enough on
    // a long log to stutter if redone on every rebuild, including ones this
    // widget's own inputs didn't change (a keystroke elsewhere in the
    // operation view still rebuilds this StreamBuilder subtree). Reused
    // as-is whenever the last pass's inputs still match.
    final metricsKey = _QsoListMetricsKey(
      qsos: qsos,
      activityControls: activityControls,
      ourEntityPrefix: ourEntityPrefix,
      dxFlags: dxFlags,
      showQsoNumbers: showQsoNumbers,
      theme: theme,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final cachedKey = _cachedMetricsKey;
    final metrics = cachedKey != null && cachedKey.matches(metricsKey)
        ? _cachedMetrics!
        : (_cachedMetrics = _computeMetrics(
            context: context,
            qsos: qsos,
            activityControls: activityControls,
            ourEntityPrefix: ourEntityPrefix,
            dxFlags: dxFlags,
            showQsoNumbers: showQsoNumbers,
            mono: mono,
            monoDim: monoDim,
            callStyle: callStyle,
          ));
    _cachedMetricsKey = metricsKey;
    final numbers = metrics.numbers;
    final numberWidth = metrics.numberWidth;
    final callsignWidth = metrics.callsignWidth;
    final dxStateWidth = metrics.dxStateWidth;
    final freqWidth = metrics.freqWidth;
    final rstWidth = metrics.rstWidth;
    final exchangeWidth = metrics.exchangeWidth;
    final refsWidth = metrics.refsWidth;
    final refsAreNotesOnly = metrics.refsAreNotesOnly;
    final hzDigits = metrics.hzDigits;
    final usesMultipleModes = metrics.usesMultipleModes;
    final dayKeys = metrics.dayKeys;
    final dayGroups = metrics.dayGroups;

    // See [_rowHeightScale]'s doc — every row/header below is forced into an
    // exact box (HALO-258), so its extent has to grow with the OS text
    // scale the same way the scroll math using [_metrics] elsewhere does.
    final rowExtent = _metrics.qsoRowHeight * _rowHeightScale;
    final headerExtent = _metrics.sectionHeaderHeight * _rowHeightScale;

    // Matched against each local day bucket by the same UTC-day key the
    // scoring hook uses — see `_dayInMillis`'s doc comment. Absent (or a
    // bucket with no matching entry, e.g. before the first rescore lands
    // for QSOs just logged) just means that header shows no score badges.
    final scoresByDay = <int, Map<String, dynamic>?>{
      for (final section in widget.daySections)
        if (section['day'] is num) (section['day'] as num).toInt(): section['scores'] as Map<String, dynamic>?,
    };

    Widget buildRowContent(BuildContext context, int chronologicalIndex, _ColumnPlan plan) {
      final qso = qsos[chronologicalIndex];

      if (qso.isEvent) {
        // Operation segment markers keep their centered-label treatment;
        // every other event kind (note/todo/solar/weather — the annotation
        // commands, ham2k/halo-dist#64) renders as a yellow annotation
        // row in the timeline, following app-polo's QSOList dispatch.
        final kind = qso.eventKind;
        if (kind == 'start' || kind == 'break' || kind == 'end' || kind == 'stop') {
          return EventRow(
            qso: qso,
            selected: qso.uuid == selectedUuid,
            onTap: () => (onSelectEvent ?? onSelect)(qso),
            leadingWidth: plan.showNumbers ? numberWidth + _columnGap : 0,
          );
        }
        return AnnotationRow(
          qso: qso,
          selected: qso.uuid == selectedUuid,
          onTap: () => (onSelectEvent ?? onSelect)(qso),
          leadingWidth: plan.showNumbers ? numberWidth + _columnGap : 0,
        );
      }

      final number = numbers[chronologicalIndex];
      final timeLabel = _utcTimeLabel(qso.startAt);
      final selected = qso.uuid == selectedUuid;

      // Selected treatment matches app-polo's QSOList: secondaryContainer
      // fill with a secondary top/bottom border accent, text tinted
      // toward onSecondaryContainer so it doesn't wash out.
      var rowMono = selected ? mono.copyWith(color: theme.colorScheme.onSecondaryContainer) : mono;
      var rowMonoDim = selected ? monoDim.copyWith(color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.75)) : monoDim;
      var rowCall = selected ? callStyle.copyWith(color: theme.colorScheme.onSecondaryContainer) : callStyle;
      // Deleted QSOs only ever show up here when the "show deleted QSOs"
      // menu toggle is on — struck-through and faded so they read as
      // gone without disappearing from the timeline.
      if (qso.deleted) {
        rowMono = rowMono.copyWith(color: rowMono.color?.withValues(alpha: 0.5), decoration: TextDecoration.lineThrough);
        rowMonoDim = rowMonoDim.copyWith(color: rowMonoDim.color?.withValues(alpha: 0.5), decoration: TextDecoration.lineThrough);
        rowCall = rowCall.copyWith(color: rowCall.color?.withValues(alpha: 0.5), decoration: TextDecoration.lineThrough);
      }
      // The name is the one proportional column: Roboto rather than the
      // mono the data columns line up in, since it never needs to align
      // digit-for-digit with the row above, in the same dim gray as the
      // time and RST. Its size is the row's base size (never smaller): the
      // row height is measured against bodyMedium, so this stays inside it.
      final rowNameDim = theme.textTheme.bodyMedium!.copyWith(fontSize: _rowMonoFontSize, color: rowMonoDim.color, decoration: rowMonoDim.decoration);

      // DX/State column — see _dxStateContentFor's doc for the flag-vs-state
      // rule, shared with the list-wide width precompute above. Emoji use a
      // proportional font per the issue ("emoji and name...use a
      // proportional font"), so this deliberately doesn't use
      // rowMono/rowMonoDim for the flag case — see theme.dart's emojiStyle
      // for why it also needs an explicit fontFamily.
      final dxState = _dxStateContentFor(qso, ourEntityPrefix, dxFlags);
      Widget? dxStateField;
      if (dxState != null) {
        dxStateField = dxState.isFlag ? flagGlyph(dxState.text, shadows: glyphGlow(theme)) : Text(dxState.text, style: rowMonoDim);
        // Values coming from the callsign guess rather than an entered field
        // paint a touch fainter (80%) so guessed-but-unconfirmed reads as
        // such — the flag is an emoji, whose color the text style can't
        // fade, so the dimming is applied as an Opacity here instead of via
        // the text color.
        if (dxState.guessed) dxStateField = Opacity(opacity: 0.8, child: dxStateField);
      }

      // Frequency bolded-MHz/regular-kHz/smaller-Hz, dot-separated; falls
      // back to the band when the QSO has no frequency at all, and to
      // [_noBandLabel] when it has neither.
      final freqKHz = qso.freq;
      // Red whenever the contact has no band — nothing recorded at all, or a
      // frequency that falls outside every ham band. The stored band is not
      // consulted for a QSO that has a frequency: the frequency is what the
      // column shows, so a band field disagreeing with it must not vouch for
      // what's on screen.
      final bandKnown = freqKHz != null ? bandForFrequency(freqKHz) != null : qso.band != null;
      // Carries the row's own alpha across, so a deleted QSO's bad band
      // stays faded rather than snapping back to full strength.
      final freqStyle = bandKnown ? rowMono : rowMono.copyWith(color: theme.colorScheme.error.withValues(alpha: rowMono.color?.a ?? 1.0));
      final Widget freqField;
      // Right-aligned within the column's fixed width, so the kHz digits of
      // a 7 MHz row sit under those of a 14 MHz row, band-only rows included.
      if (freqKHz == null) {
        freqField = Text(qso.band ?? _noBandLabel, style: freqStyle, textAlign: TextAlign.right);
      } else {
        final parts = freqDisplayParts(freqKHz, hzDigits: hzDigits);
        freqField = Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Below 1 MHz there is no thousands group at all: 630m sits at
            // 472 kHz, and drawing the parts unconditionally would show
            // `0,472` — a reading that is not a number anyone writes.
            if (int.parse(parts.mhz) > 0) ...[
              Text(
                // Grouped itself, for the rare frequency past 1 GHz: this
                // part is whole MHz, so 1296 MHz is `1,296,000` kHz and would
                // read as `1296,000` without it.
                //
                // Grouped by hand rather than through `formatNumber`, the way
                // `fmtFreq` does: intl also translates the DIGITS into the
                // locale's own script, and the kHz and Hz parts beside this
                // one are plain ASCII — so on fa the reading would come out
                // half in Eastern Arabic numerals and half not.
                groupDigits(parts.mhz),
                style: freqStyle.copyWith(fontWeight: FontWeight.w700),
              ),
              // The row is a kHz reading, like the spots panel and the radio
              // controls — so this is a THOUSANDS mark and the one below is a
              // decimal point. They are different characters under comma
              // conventions (`7.200,5`), and using either for both would put
              // the reading off by three orders of magnitude to anyone
              // reading it as written.
              Text(NumberFormatting.instance.groupingSeparator, style: freqStyle),
              Text(parts.khz, style: freqStyle),
            ] else
              Text(
                // Unpadded: `khz` is zero-filled to three digits so it can
                // follow a thousands mark, and nothing precedes it here.
                int.parse(parts.khz).toString(),
                style: freqStyle.copyWith(fontWeight: FontWeight.w700),
              ),
            if (parts.hz != null) ...[
              Text(NumberFormatting.instance.decimalSeparator, style: freqStyle),
              Text(parts.hz!, style: freqStyle.copyWith(fontSize: (freqStyle.fontSize ?? 14) * 0.8)),
            ],
          ],
        );
      }

      // One icon per distinct ref type, "×N" appended when the QSO carries
      // more than one of that type — see [qsoRefCountsByType], which the width
      // budget uses to reserve this column.
      final refCountsByType = qsoRefCountsByType(qso, activityControls);

      // #236: stable id for agent/browser tooling — per-callsign so a specific
      // logged QSO's row is targetable.
      return semanticId(
        'qso.row.${qso.theirCall}',
        Container(
          // foregroundDecoration paints over the already-laid-out child
          // instead of insetting it (unlike Container's `decoration`,
          // which turns a BoxDecoration's border into padding) — the
          // selected-row accent border can't add any height on top of the
          // hairline row/divider spacing the issue calls for.
          foregroundDecoration: BoxDecoration(
            border: selected ? Border.symmetric(horizontal: BorderSide(color: theme.colorScheme.secondary, width: 3)) : null,
          ),
          child: Material(
            color: selected ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface,
            child: InkWell(
              onTap: () => onSelect(qso),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: PaneSafeArea.symmetricOf(context, horizontal: Space.lg, vertical: LayoutDensity.metricsOf(context).qsoRowPaddingV),
                child: Row(
                  children: [
                    if (plan.showNumbers) ...[
                      SizedBox(
                        width: numberWidth,
                        child: Text(
                          qso.deleted ? '' : formatNumber(number),
                          style: rowMonoDim,
                          textAlign: TextAlign.right,
                          // [numberWidth] is measured to fit exactly, but every
                          // row sits in a fixed-height sliver slot (HALO-258),
                          // which can't grow to absorb a wrapped second line —
                          // forcing one line trades a rounding-error's worth of
                          // horizontal clipping for that, which is far less
                          // visible.
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                      const SizedBox(width: _columnGap),
                    ],
                    Text(timeLabel, style: rowMonoDim),
                    const SizedBox(width: _columnGap),
                    // Fixed width so an empty freq/band still holds the column
                    // open and the columns after it stay aligned (#354).
                    SizedBox(width: freqWidth, child: freqField),
                    const SizedBox(width: _columnGap),
                    if (plan.showMode) ...[
                      SizedBox(
                        width: _modeWidth,
                        child: Text(
                          displayMode(qso.mode, freqKHz: freqKHz, band: qso.band) ?? '',
                          // Same alpha-preserving error color as the frequency
                          // above: a sideband the band doesn't run is the one
                          // thing [displayMode] spells out, and it is spelled
                          // out to be noticed.
                          style: isUnexpectedSideband(qso.mode, freqKHz: freqKHz, band: qso.band)
                              ? rowMonoDim.copyWith(color: theme.colorScheme.error.withValues(alpha: rowMonoDim.color?.a ?? 1.0))
                              : rowMonoDim,
                        ),
                      ),
                      const SizedBox(width: _columnGap),
                    ],
                    // The callsign never truncates; the name absorbs the squeeze.
                    SizedBox(
                      width: callsignWidth,
                      child: Text(qso.theirCall, style: rowCall),
                    ),
                    const SizedBox(width: _columnGap),
                    // Fixed-width, like callsign/number above — reserved
                    // whenever ANY row in the list has a flag/state to show,
                    // even on rows with neither, so Name always starts at the
                    // same x position (ham2k/halo-dist#186).
                    if (plan.showDxState) ...[SizedBox(width: dxStateWidth, child: dxStateField), const SizedBox(width: _columnGap)],
                    Expanded(
                      // A guessed name paints at 80% too (see the DX/state note).
                      child: Opacity(
                        opacity: qso.theirFieldIsGuessed('name') ? 0.8 : 1.0,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              // A noted station leads with its marker.
                              if (qso.theirNoteEmoji case final emoji? when emoji.isNotEmpty) ...[
                                flagSpan(emoji, style: rowNameDim, shadows: glyphGlow(theme)),
                                const TextSpan(text: ' '),
                              ],
                              TextSpan(text: qso.theirName ?? ''),
                            ],
                          ),
                          style: rowNameDim,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (plan.showRefs && (refCountsByType.isNotEmpty || qso.serialConflict || qso.hasNotes)) ...[
                      const SizedBox(width: _columnGap),
                      QsoRowBadges(qso: qso, refCounts: refCountsByType, activityControls: activityControls, dimStyle: rowMonoDim),
                    ],
                    if (plan.showRst)
                      SizedBox(
                        width: rstWidth,
                        child: Text(
                          widget.switchSentRcvd ? '${qso.receivedRST ?? ''} ${qso.sentRST ?? ''}' : '${qso.sentRST ?? ''} ${qso.receivedRST ?? ''}',
                          style: rowMonoDim,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    // The exchange, after the signal reports (#354): ours then
                    // theirs in the RST cell's order, so a serial contest shows
                    // the number that went out next to the one that came back.
                    // Reserved list-wide only when some QSO carries one, so it
                    // costs no space in the common (RST-only) case.
                    if (plan.showExchange) ...[
                      const SizedBox(width: _columnGap),
                      SizedBox(
                        width: exchangeWidth,
                        child: Opacity(
                          opacity: qso.theirFieldIsGuessed('exchange') ? 0.8 : 1.0,
                          child: Text(
                            _exchangePair(qso, switchSentRcvd: widget.switchSentRcvd),
                            style: rowMonoDim,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// The selected row carries [_selectedRowKey], so [_revealSelected] has
    /// something to measure; every other row is built exactly as before.
    ///
    /// Rows are built lazily, during layout rather than here, so attaching the
    /// key is also the moment we learn the row exists at all — recorded in
    /// [_keyedRowUuid], which `build` cleared on the way past.
    Widget buildRow(BuildContext context, int chronologicalIndex, _ColumnPlan plan) {
      final row = buildRowContent(context, chronologicalIndex, plan);
      if (qsos[chronologicalIndex].uuid != selectedUuid) return row;
      _keyedRowUuid = selectedUuid;
      return KeyedSubtree(key: _selectedRowKey, child: row);
    }

    // Time, freq and callsign, with the gaps they carry — the columns a row
    // is not allowed to drop, so the narrowest a row can honestly be. The
    // list refuses to lay out below this (see the LayoutBuilder), which is
    // what keeps a Row from ever being handed less than it needs.
    //
    // Carries [_fitSlack]: every width here is a text MEASUREMENT, and the
    // layout that follows it rounds independently, so the two need not agree
    // to the pixel. Budgeting to the exact measurement leaves a row one
    // rounding difference away from overflowing by a fraction of a pixel —
    // still a logged error.
    final mandatoryWidth = textWidth(context, _timeLabelSample, monoDim) + _columnGap + freqWidth + _columnGap + callsignWidth + _columnGap + _fitSlack;

    // What each optional column costs, INCLUDING the [_columnGap] it brings
    // with it, and whether it has earned its place on content at all (#354,
    // ham2k/halo-dist#186 decide that part).
    //
    // ORDER IS THE PRIORITY: the first entry is the last column given up.
    // It is a list, not the argument order of a constructor, precisely so
    // that reordering it is a deliberate act rather than something a tidy-up
    // can do by accident.
    final columns = <({_Column id, bool earned, double width})>[
      (id: _Column.numbers, earned: showQsoNumbers, width: numberWidth + _columnGap),
      (id: _Column.dxState, earned: dxStateWidth > 0, width: dxStateWidth + _columnGap),
      (id: _Column.mode, earned: usesMultipleModes, width: _modeWidth + _columnGap),
      (id: _Column.rst, earned: showRSTFields, width: rstWidth),
      // A reference or a duplicate serial is logged data and outranks the
      // exchange; a notes marker only says the edit pane holds more, so a
      // column of nothing else yields to it. Without the split, one note in
      // a contest log costs every row its exchange in a narrow pane.
      if (!refsAreNotesOnly) (id: _Column.refs, earned: refsWidth > 0, width: refsWidth),
      (id: _Column.exchange, earned: exchangeWidth > 0, width: exchangeWidth + _columnGap),
      if (refsAreNotesOnly) (id: _Column.refs, earned: refsWidth > 0, width: refsWidth),
    ];

    /// Keeps the optional columns that still fit, best-earned first. The
    /// running total is what the [Row] will actually lay out, so a column
    /// that survives here is one the row has room to draw.
    _ColumnPlan planFor(double available) {
      var used = mandatoryWidth;
      final shown = <_Column>{};
      for (final column in columns) {
        if (!column.earned) continue;
        if (used + column.width > available) continue;
        used += column.width;
        shown.add(column.id);
      }
      return _ColumnPlan(shown);
    }

    return ClipRect(
      // Rows lay out fixed-width columns sized from the longest value seen
      // across the whole list, not from the pane's actual width, so a narrow
      // split or a long callsign/exchange can overflow a row horizontally.
      // The CustomScrollView's own viewport only clips when it judges itself
      // to have vertical overflow, so a short list with room to spare lets
      // that horizontal overflow paint straight past the pane into whatever
      // sits next to it — this ClipRect contains it unconditionally instead.
      // [planFor] keeps rows inside the pane in the first place; this stays
      // as the backstop for the residue (a ref badge wider than its estimate)
      // and for a pane narrower than [minWidth] below.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = PaneSafeArea.symmetricOf(context, horizontal: 12);
          // Below this the list has nothing left to drop — time, freq and
          // callsign are what a log row means. So it stops shrinking and lays
          // out at its minimum instead, letting the ClipRect above trim the
          // right edge: rows that are cut off but internally consistent, rather
          // than rows whose columns overflow and land on top of each other.
          final minWidth = mandatoryWidth + padding.horizontal;
          final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
          final plan = planFor(width - padding.horizontal);
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width,
            maxWidth: width,
            child: Container(
              // Shows through wherever the list doesn't reach (e.g. below the
              // newest row when there are few QSOs) — rows themselves stay opaque
              // on the normal surface color below.
              color: theme.colorScheme.surfaceContainerHighest,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: _onScrollMetricsNotification,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      for (final g in widget.newestFirst ? [for (var d = dayGroups.length - 1; d >= 0; d--) d] : [for (var d = 0; d < dayGroups.length; d++) d])
                        // Groups each day's header with its own rows so Flutter's sliver
                        // protocol coordinates pinning *between* groups — without this,
                        // sibling `SliverPersistentHeader`s pin independently of each
                        // other and a short day's header never gets pushed off by the
                        // next day's, so both stay stuck on screen at once instead of
                        // only the current day's header showing.
                        SliverMainAxisGroup(
                          slivers: [
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _DayHeaderDelegate(
                                extent: headerExtent,
                                child: DayHeaderRow(
                                  dayMillis: dayKeys[g],
                                  count: dayGroups[g].where((i) => qsos[i].isRealContact).length,
                                  scores: scoresByDay[dayKeys[g]],
                                  onTap: widget.onTapDayHeader,
                                ),
                              ),
                            ),
                            // Fixed extent, not a plain SliverList: it gives
                            // RenderSliverFixedExtentList's maxScrollExtent as
                            // itemExtent * childCount, an O(1) computation —
                            // instead of the O(n) layout walk a variable-extent
                            // sliver needs to find where the list ends, which is
                            // what made jumping to the newest QSO in a large
                            // operation block the UI thread for up to 1.5s
                            // (HALO-258). Every row is forced into this exact
                            // height regardless of kind — see EventRow's and
                            // AnnotationRow's padding, matched to the ordinary
                            // row's for exactly this reason.
                            SliverFixedExtentList(
                              itemExtent: rowExtent,
                              delegate: SliverChildBuilderDelegate((context, i) {
                                final group = dayGroups[g];
                                final index = group[widget.newestFirst ? group.length - 1 - i : i];
                                return _RowDivider(
                                  // The last row of a day already meets the
                                  // next day's pinned header — a divider there
                                  // would just be a hairline under the header,
                                  // not between two rows. A selected row paints
                                  // its own accent border on the same edge
                                  // (buildRow, above) — the divider would paint
                                  // over it, since foreground decorations paint
                                  // in child-to-ancestor order.
                                  draw: i < group.length - 1 && qsos[index].uuid != selectedUuid,
                                  child: buildRow(context, index, plan),
                                );
                              }, childCount: dayGroups[g].length),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The exchange column's text: what we sent, then what they sent — or just
/// theirs, for a contest whose sent exchange is fixed and so lives on the
/// operation rather than on each QSO. Ours-then-theirs unless the row order
/// is switched, exactly as the RST cell does.
String _exchangePair(Qso qso, {required bool switchSentRcvd}) {
  final ours = qso.ourExchange ?? '';
  final theirs = qso.theirExchange ?? '';
  // Joined, not interpolated: a lone half must not carry a stray space that
  // would misalign the right-aligned cell and be measured into the column.
  final parts = switchSentRcvd ? [theirs, ours] : [ours, theirs];
  return parts.where((p) => p.isNotEmpty).join(' ');
}

/// The O(qsos) numbering/column-width/day-grouping pass — real text-layout
/// measurements, expensive enough on a long log to stutter if redone on
/// every rebuild. Called only on a cache miss; see `_QsoListState.build`'s
/// `_cachedMetrics`/`_cachedMetricsKey`.
_QsoListMetrics _computeMetrics({
  required BuildContext context,
  required List<Qso> qsos,
  required List<Map<String, dynamic>> activityControls,
  required String? ourEntityPrefix,
  required DxFlags dxFlags,
  required bool showQsoNumbers,
  required TextStyle mono,
  required TextStyle monoDim,
  required TextStyle callStyle,
}) {
  // QSO numbers count only real contacts — event markers interspersed in
  // the timeline don't consume a number.
  final numbers = List<int>.filled(qsos.length, 0);
  var runningNumber = 0;
  for (var i = 0; i < qsos.length; i++) {
    if (qsos[i].isRealContact) runningNumber++;
    numbers[i] = runningNumber;
  }
  // `numbers` only ever increases, so its last value is its max — no need
  // to fold over it separately.
  final maxNumber = runningNumber;

  // Column-sizing must cover every QSO that can actually render a row —
  // including deleted ones, which still show (struck-through) whenever the
  // "show deleted QSOs" menu toggle is on — not just `isRealContact` ones,
  // or a deleted QSO's callsign/frequency/mode can exceed what the columns
  // were sized for and wrap/truncate. One pass instead of separate
  // fold/map/toSet passes per column — cheap on its own (int/string
  // comparisons, not text layout), but there's no reason to walk the list
  // four times when once covers every column that needs a list-wide value.
  var longestCall = '';
  final freqsInKHz = <double?>[];
  final modesUsed = <String>{};
  var anyUnexpectedSideband = false;
  // Widest band shown in the freq/band column (only null-freq rows fall back
  // to the band) and widest exchange pair, so both columns reserve a
  // list-wide width and stay aligned even on rows that lack them (#354).
  var longestBand = '';
  var longestExchange = '';
  // Seeded at the floor, then widened for anything longer a QSO actually holds.
  var longestRst = _rstMinSample;
  // Only the single longest flag and longest state ever matter for
  // dxStateWidth below — tracking them here costs the same cheap
  // length comparison as longestCall, deferring the two (not N) actual
  // text-layout measurements to after this loop.
  var longestFlag = '';
  var longestState = '';
  // The refs column is per-row content, so what it reserves is the widest
  // any ONE row needs: per distinct type an icon plus its gap, and the "×N"
  // on the types that repeat. Tracked as a count of icons and the largest
  // repeat-count seen, so the two text measurements happen once after the
  // loop rather than per row.
  var mostRefIcons = 0;
  var largestRefCount = 0;
  // The duplicate-serial mark (docs/design/contests.md §5.8.1) and the notes
  // marker are badges in the same column, so they count toward the same
  // widest-row total instead of each holding a slot of its own list-wide.
  var mostBadges = 0;
  var anyRefOrConflict = false;
  for (final q in qsos) {
    if (q.isEvent) continue;
    final refCounts = qsoRefCountsByType(q, activityControls);
    if (refCounts.length > mostRefIcons) mostRefIcons = refCounts.length;
    final badges = refCounts.length + (q.serialConflict ? 1 : 0) + (q.hasNotes ? 1 : 0);
    if (badges > mostBadges) mostBadges = badges;
    if (refCounts.isNotEmpty || q.serialConflict) anyRefOrConflict = true;
    for (final entry in refCounts.values) {
      if (entry.count > largestRefCount) largestRefCount = entry.count;
    }
    if (q.theirCall.length > longestCall.length) longestCall = q.theirCall;
    freqsInKHz.add(q.freq);
    // Band only renders when the QSO has no frequency (freqField below), and
    // a QSO with neither shows [_noBandLabel] there — which still has to be
    // measured, or the column collapses on a list made only of those.
    if (q.freq == null) {
      final label = q.band ?? _noBandLabel;
      if (label.length > longestBand.length) longestBand = label;
    }
    final exchange = _exchangePair(q, switchSentRcvd: false);
    if (exchange.length > longestExchange.length) longestExchange = exchange;
    final rstPair = '${q.sentRST ?? ''} ${q.receivedRST ?? ''}';
    if (rstPair.length > longestRst.length) longestRst = rstPair;
    // The DISPLAYED mode, so an operation that worked USB on 20m and LSB on
    // 40m counts as one mode and doesn't grow a Mode column repeating "SSB".
    final mode = displayMode(q.mode, freqKHz: q.freq, band: q.band);
    if (mode != null) modesUsed.add(mode);
    if (isUnexpectedSideband(q.mode, freqKHz: q.freq, band: q.band)) anyUnexpectedSideband = true;
    final dxState = _dxStateContentFor(q, ourEntityPrefix, dxFlags);
    if (dxState == null) {
      // no-op — nothing to measure for this row
    } else if (dxState.isFlag) {
      if (dxState.text.length > longestFlag.length) longestFlag = dxState.text;
    } else if (dxState.text.length > longestState.length) {
      longestState = dxState.text;
    }
  }

  // Column widths are computed once for the whole list so every row lines
  // up, per the issue: "wide enough to fit the largest number"/"longest
  // callsign in all qsos" — DX/State and the Name column right after it
  // are no exception (ham2k/halo-dist#186): a QSO with neither a flag
  // nor a state must still reserve that column's width, or Name starts at
  // a different x position on every row depending on its neighbors.
  // `formatNumber` adds locale thousands separators ("1,252"), wider
  // than the bare digits — measuring those instead of the string that
  // actually renders is what let a 4-digit count wrap onto a second
  // line (HALO-258).
  final numberWidth = showQsoNumbers ? textWidth(context, formatNumber(maxNumber), mono) : 0.0;
  final callsignWidth = longestCall.isEmpty ? 0.0 : textWidth(context, longestCall, callStyle);
  // Names the size the glyph actually paints at — qso_list's flagGlyph call
  // takes the default, so measuring emojiStyle()'s own default instead would
  // agree only by coincidence.
  final flagWidth = longestFlag.isEmpty ? 0.0 : textWidth(context, longestFlag, emojiStyle(fontSize: flagGlyphDefaultFontSize));
  final stateWidth = longestState.isEmpty ? 0.0 : textWidth(context, longestState, monoDim);
  final dxStateWidth = flagWidth > stateWidth ? flagWidth : stateWidth;

  // "decide how many digits to display based on all the qsos in the
  // operation" — one Hz precision for the whole list, not per row.
  final hzDigits = hzDigitsNeeded(freqsInKHz);
  // The Mode column only earns its place when the operation actually mixes
  // modes — otherwise every row would repeat the same value.
  //
  // A sideband this place does not run earns it on its own, whatever the count.
  // The whole-operation case is the one worth catching — a rig left in LSB on
  // 20m, or an import that put USB on every 40m contact — and it is exactly
  // the case a count cannot see: every row displays that one sideband, so the
  // column would be dropped and the warning with it.
  final usesMultipleModes = modesUsed.length > 1 || anyUnexpectedSideband;

  // Reserve the freq/band column at a fixed list-wide width so a QSO with
  // neither still holds it open and Mode/Callsign line up on every row
  // (#354). Freq strings depend on hzDigits, so measure after it's known;
  // mono means string length tracks width, and measuring the full string in
  // regular `mono` (the Hz part actually renders smaller) only over-reserves
  // a hair, which is safe. Bands (null-freq rows) compete for the same width.
  var longestFreqOrBand = longestBand;
  for (final f in freqsInKHz) {
    if (f == null) continue;
    final parts = freqDisplayParts(f, hzDigits: hzDigits);
    // Exactly what the row draws, grouping and the sub-MHz case included —
    // this measures the column, so anything narrower here under-reserves it.
    final decimal = NumberFormatting.instance.decimalSeparator;
    final mhzValue = int.parse(parts.mhz);
    final whole = mhzValue > 0 ? '${groupDigits(parts.mhz)}${NumberFormatting.instance.groupingSeparator}${parts.khz}' : int.parse(parts.khz).toString();
    final s = parts.hz != null ? '$whole$decimal${parts.hz}' : whole;
    if (s.length > longestFreqOrBand.length) longestFreqOrBand = s;
  }
  final freqWidth = longestFreqOrBand.isEmpty ? 0.0 : textWidth(context, longestFreqOrBand, mono);
  final rstWidth = textWidth(context, longestRst, monoDim);
  // The exchange column (after the signal reports) reserves width only
  // when some QSO actually carries an exchange, like DX/State above (#354).
  final exchangeWidth = longestExchange.isEmpty ? 0.0 : textWidth(context, longestExchange, monoDim);
  // Measured from the largest count actually present, so a three-figure
  // repeat is budgeted at its real width rather than a two-digit sample.
  // Reserved for EVERY icon on the widest row rather than only the ones
  // that repeat: over-reserving costs the exchange column a few pixels,
  // under-reserving costs a row that overflows.
  final refCountWidth = largestRefCount > 1 ? textWidth(context, '×$largestRefCount', mono.copyWith(fontSize: 11)) : 0.0;
  // The "×N" is reserved per REF icon on the row with the most of those,
  // which need not be the row with the most badges: the sum bounds both.
  final refsWidth = mostBadges == 0 ? 0.0 : _columnGap + mostBadges * (qsoRefIconWidth + qsoRefIconGap) + mostRefIcons * refCountWidth;

  // `qsos` arrives oldest-first (QsosRepository.watchForOperation orders
  // by startAtMillis) — bucket it into consecutive UTC-day runs so each
  // bucket becomes one pinned header + its own sliver of rows. A plain
  // linear scan works because same-day QSOs are already contiguous; no
  // need to build then sort a day->indices map.
  final dayKeys = <int>[];
  final dayGroups = <List<int>>[];
  for (var i = 0; i < qsos.length; i++) {
    final millis = qsos[i].startAtMillis ?? 0;
    final dayKey = millis - (millis % _dayInMillis);
    if (dayKeys.isEmpty || dayKeys.last != dayKey) {
      dayKeys.add(dayKey);
      dayGroups.add([]);
    }
    dayGroups.last.add(i);
  }

  return _QsoListMetrics(
    numbers: numbers,
    numberWidth: numberWidth,
    callsignWidth: callsignWidth,
    dxStateWidth: dxStateWidth,
    freqWidth: freqWidth,
    rstWidth: rstWidth,
    exchangeWidth: exchangeWidth,
    refsWidth: refsWidth,
    refsAreNotesOnly: !anyRefOrConflict,
    hzDigits: hzDigits,
    usesMultipleModes: usesMultipleModes,
    dayKeys: dayKeys,
    dayGroups: dayGroups,
  );
}

/// Draws the hairline between [QsoList] rows as [child]'s own bottom edge
/// instead of a separate list item — every row sits in a fixed-height sliver
/// slot (HALO-258), which can't alternate a shorter divider slot in between
/// the way `ListView.separated` does.
class _RowDivider extends StatelessWidget {
  final Widget child;

  /// False for the last row of a day (meets the pinned header, not another
  /// row) and for the selected row (its own accent border, painted by
  /// [buildRow], already marks that edge — this would paint over it, since
  /// foreground decorations paint in child-to-ancestor order).
  final bool draw;

  const _RowDivider({required this.child, required this.draw});

  @override
  Widget build(BuildContext context) {
    if (!draw) return child;
    return DecoratedBox(
      // foreground: the row's own Material background is opaque and fills
      // this whole box, so a background-position border would paint
      // underneath it and never show.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        // What a plain `Divider` resolves its own color to — matching it
        // here since this replaces one (see class doc).
        border: Border(bottom: BorderSide(width: 1, color: DividerTheme.of(context).color ?? Theme.of(context).dividerColor)),
      ),
      child: child,
    );
  }
}

/// Pins [DayHeaderRow] to the top of [QsoList]'s `CustomScrollView` while its
/// day's QSOs are in view, per issue #62 ("pinned headers that show the day
/// and scoring summaries").
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  /// Resolved by the caller, not read from context here: `build` below is not
  /// the only place the extent is needed — `minExtent`/`maxExtent` are asked
  /// for outside it, with no context to read.
  final double extent;

  const _DayHeaderDelegate({required this.child, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Forces the child to exactly [extent] regardless of its own intrinsic
    // size — a pinned sliver header's declared extent must match what it
    // actually paints, or Flutter throws a "layoutExtent exceeds
    // paintExtent" assertion the instant [child]'s content (font size,
    // padding, border width) doesn't add up to precisely that.
    return SizedBox(height: extent, child: child);
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) => oldDelegate.child != child || oldDelegate.extent != extent;
}

/// One UTC-day divider in [QsoList]: the day's date, its real-contact count,
/// and (once scored) score badges for that day — see `DayScoreSummary` and
/// `ScoreTally` in the extension SDK. `qsoCount` is skipped among the score
/// badges since [count] already shows it as a label.
class DayHeaderRow extends StatelessWidget {
  /// The extent this header pins at — an ordinary QSO row's own height (4px
  /// vertical padding either side of a 14px line at its natural, un-inflated
  /// line height, see `build`'s `rowStyle`) plus a little headroom.
  ///
  /// Public so tests can assert that a row revealed by
  /// `_QsoListState._revealSelected` clears the header pinned above it.
  static double pinnedHeightOf(BuildContext context) => LayoutDensity.metricsOf(context).sectionHeaderHeight;

  final int dayMillis;
  final int count;
  final Map<String, dynamic>? scores;

  /// Tapping the header opens the operation's own info — the day divider is
  /// the list's stand-in for "this operation", the way a QSO row is for a
  /// contact. Null leaves the header inert.
  final VoidCallback? onTap;

  /// Overrides "now" for the relative-date label below — tests only; a real
  /// header always compares against the current moment.
  final DateTime? now;

  const DayHeaderRow({super.key, required this.dayMillis, required this.count, this.scores, this.now, this.onTap});

  /// Same tiering as app-polo/web-lofi's `fmtDateDynamicZulu(compact: true)`
  /// (lib-format-tools' `fmtDateDynamic`): "Today"/"Yesterday" for the
  /// obvious cases, weekday+day within the last week, month+day within the
  /// last 9 months, and month+day+year beyond that — so a long-running log
  /// still reads as calendar dates instead of an ever-scrolling "N days ago".
  /// The weekday and month abbreviations come from `intl` for the widget's
  /// locale, the relative words from `t` — both follow the app's language.
  static String _dayLabel(BuildContext context, int dayMillis, DateTime now) {
    final d = DateTime.fromMillisecondsSinceEpoch(dayMillis, isUtc: true);
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    String weekday() => DateFormat.E(locale).format(d);
    String month() => DateFormat.MMM(locale).format(d);
    final diffInDays = now.difference(d).inMilliseconds / _dayInMillis;
    final absDiffInDays = diffInDays.abs();

    // Order matters: a day two-plus in the future has diffInDays <= -1, which
    // must NOT fall through to the "Yesterday" (diffInDays <= 2) branch —
    // future days get their calendar-date label like any other non-adjacent
    // day, so a date typo or clock-skewed device reads "Jul 20", not
    // "Yesterday".
    if (diffInDays > -1 && diffInDays <= 0) return t.qsoList.tomorrow;
    if (diffInDays > 0 && diffInDays <= 1) return t.qsoList.today;
    if (diffInDays > 1 && diffInDays <= 2) return t.qsoList.yesterday;
    if (absDiffInDays <= 7) return '${weekday()} ${d.day}';
    if (absDiffInDays <= 274) return '${month()} ${d.day}';
    return '${month()} ${d.day} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Same base size as the QSO rows below it (app-polo's QSOHeader reuses
    // its row font wholesale, just bolding the date) — labelLarge/labelMedium
    // read visibly larger than the row text and make the header feel like a
    // different, heavier UI element instead of a divider within the list.
    // `height: 1.0` overrides bodyMedium's Material 3 line-height multiplier
    // (1.43, meant for prose) back down to the font's natural metric — same
    // as the row's own `haloMonoStyle`, which never sets an explicit
    // `height` either — so the header doesn't come out visibly taller than
    // an ordinary QSO row despite using the same 14px font size.
    final rowStyle = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.0);

    final badges = <Widget>[];
    for (final entry in (scores ?? const <String, dynamic>{}).entries) {
      final tally = entry.value;
      if (tally is! Map) continue;
      // Key off the tally's own `key`, not the map key: with several scorers
      // active the caller namespaces those (`core.qsoCount`), and the count is
      // already shown by the header itself.
      if (tally['key'] == 'qsoCount') continue;
      final icon = tally['icon'] as String?;
      final summary = tally['summary'] as String?;
      if (icon == null || summary == null || summary.isEmpty) continue;
      // An activity tally reports `activated: true` once every reference it
      // covers has cleared its threshold — the badge goes green to say the
      // goal for this day (or the operation) is already met.
      final activated = tally['activated'] == true;
      badges.add(
        Padding(
          padding: const EdgeInsets.only(left: Space.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(resolveIconName(icon), size: 14, color: activated ? HaLoColors.of(context).important : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: Space.xs),
              Text(summary, style: rowStyle),
            ],
          ),
        ),
      );
    }

    return Material(
      // `surfaceContainerHigh` isn't one of the tones `buildHaLoTheme`
      // overrides (theme.dart), so it falls back to Flutter's default — an
      // almost-white tint that doesn't read as "gray" against the QSO
      // rows' plain `surface`. `surfaceContainerHighest` is an
      // explicitly-set, visibly gray tone (already used to fill the list's
      // own empty space above/below its rows), so it actually shows up as
      // a distinct header background. It sits on the Material, not on the
      // Container below, so the InkWell's splash isn't painted over.
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: Container(
          // `foregroundDecoration`, not `decoration` — same reason the row's own
          // selected-treatment border below uses it: `Container` auto-insets
          // its child by a `BoxDecoration`'s border width when the border lives
          // in `decoration`, which would make the header taller than a plain
          // QSO row for the same padding. Painting over the already-laid-out
          // box instead keeps the header exactly row-height while still
          // reading as a stronger break than the 1px hairline between ordinary
          // QSO rows — matching app-polo's QSOHeader (`headerRow`'s
          // `borderBottomWidth: 2`) — using `outline`, not `outlineVariant`,
          // since `outlineVariant` is nearly the same color as the header's own
          // background and the border all but disappears against it.
          foregroundDecoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 3)),
          ),
          child: Padding(
            // Same vertical padding as a QSO row (see `buildRow`'s own
            // `Padding` above) so the header comes out exactly row-height.
            padding: PaneSafeArea.symmetricOf(context, horizontal: Space.lg, vertical: LayoutDensity.metricsOf(context).qsoRowPaddingV),
            child: Row(
              children: [
                // The header lives inside the same minimum width the QSO rows do,
                // so at that minimum the date and count have to give rather than
                // overflow. `Expanded` pushes the badges right (what a bare
                // `Spacer` would do) while also capping the pair.
                //
                // That makes the score badges the one thing here that never
                // yields, which is deliberate: they are fixed-size chips with
                // nothing to ellipsize into, while a shortened date still reads.
                // Within the pair the date gives first and the count second, so
                // the day stays identifiable for as long as there is room for it.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _dayLabel(context, dayMillis, now ?? nowUtc()),
                          style: rowStyle?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      // Deliberately NOT Flexible. Two loose Flexibles in one Row
                      // split the space proportionally and never hand back what
                      // they don't use, so the date would ellipsize at half the
                      // header even when the count is short. Non-flex, the count
                      // takes its natural width and the date gets the rest —
                      // which is the behaviour we want everywhere except a count
                      // label wider than the list's whole minimum width, and that
                      // needs ~25 characters of "N QSOs".
                      // Same "1 QSO"/"N QSOs" vocabulary the info area's stats line uses.
                      Text(count == 1 ? t.loggingControls.info.qsoCountOne : t.loggingControls.info.qsoCountOther(count: count), style: rowStyle),
                    ],
                  ),
                ),
                ...badges,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A start/break/end marker row in [QsoList], visually distinct from a QSO
/// row (centered label instead of data columns) since it isn't a contact —
/// tapping it loads `LoggingControls`' inline event editor, same as an
/// [AnnotationRow] (`Qso.isEvent`), just with a centered summary here
/// instead of the timeline layout below.
class EventRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final VoidCallback onTap;

  /// Width of the (optional) QSO-number column plus its gap, so the time
  /// column lines up with the QSO rows around it — same as [AnnotationRow].
  final double leadingWidth;

  const EventRow({super.key, required this.qso, required this.onTap, this.selected = false, this.leadingWidth = 0});

  static const _icons = {'start': MdiIcons.playBox, 'break': MdiIcons.slashForwardBox, 'end': MdiIcons.stopCircle, 'stop': MdiIcons.stopCircle};

  /// The rule the top border takes out of the row's vertical padding, so the
  /// row keeps [QsoList]'s fixed per-row height (HALO-258).
  static const _topBorder = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = qso.eventKind;
    final timeLabel = _utcTimeLabel(qso.startAt);
    // The row reads as a timeline entry, like polo's: the time in the QSO
    // rows' column, the segment's mark, then what the segment says about
    // the operation ("for ARRL 10G Sep • at FN20rm"), stored on the row by
    // whatever wrote it (naming a reference needs an async extension hook,
    // which a list row can't make — polo recomposes per frame instead).
    //
    // Without one — an older row, or one written while the extension host
    // was down — the override's own square is still on the row and says
    // more than nothing. Bare, since this package has no locale to put an
    // "at" in. A segment with neither shows its mark alone: naming the kind
    // ("Break") would say nothing the icon doesn't.
    final stored = (qso.event?['description'] as String?)?.trim() ?? '';
    final override = qso.event?['operation'];
    final description = stored.isNotEmpty ? stored : (override is Map ? (override['grid'] as String?)?.trim() ?? '' : '');
    final ink = selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant;
    // polo's `primaryLighter` segment row: a wash of the primary over the
    // surface, so a blue theme reads blue-gray, and the dark theme gets the
    // same wash rather than a full-strength container. The rule along the
    // top is the same wash, deeper.
    final isDark = theme.brightness == Brightness.dark;
    Color wash(double alpha) => Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: alpha), theme.colorScheme.surface);
    final background = selected ? theme.colorScheme.secondaryContainer : wash(isDark ? 0.22 : 0.14);
    final rule = wash(isDark ? 0.5 : 0.35);
    // Matches the ordinary QSO row's own padding exactly (not a hardcoded
    // value) — [QsoList] forces every row into the same fixed
    // [LayoutMetrics.qsoRowHeight] box (HALO-258, avoids a per-row layout
    // walk on `jumpTo`), so a row whose natural height doesn't match that
    // box overflows or leaves a gap. The border comes out of the top
    // padding for the same reason.
    final padding = PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: LayoutDensity.metricsOf(context).qsoRowPaddingV);

    // The border is part of the row's height, so it comes OUT of the
    // padding — off the top first, and off the bottom for whatever the top
    // couldn't give. At the densest layout the vertical padding is 1px
    // against a 2px rule, and a bare clamp at the top would leave the row a
    // pixel taller than the box [QsoList] forces it into.
    final borderTop = padding.top.clamp(0.0, _topBorder);
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: rule, width: _topBorder),
            ),
          ),
          padding: padding.copyWith(top: padding.top - borderTop, bottom: (padding.bottom - (_topBorder - borderTop)).clamp(0.0, double.infinity)),
          child: Row(
            children: [
              SizedBox(width: leadingWidth),
              Text(
                timeLabel,
                style: haloMonoStyle(context, fontSize: _rowMonoFontSize, color: ink),
              ),
              const SizedBox(width: _columnGap),
              Icon(_icons[kind] ?? MdiIcons.timelapse, size: 16, color: ink),
              const SizedBox(width: _columnGap),
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A note/todo/solar/weather annotation row in [QsoList] — an event
/// pseudo-QSO added by the annotation commands (ham2k/halo-dist#64,
/// `extensions/core/annotation-commands`). Unlike [EventRow]'s centered
/// segment markers, annotations are timeline entries: they keep the QSO
/// rows' time column (left-aligned, [leadingWidth] preserving the Number
/// column's indent), followed by the event's icon and its text. The yellow
/// "sticky note" treatment is ported from app-polo's QSOList `eventRow`/
/// `eventContent` styles.
class AnnotationRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final VoidCallback onTap;

  /// Width of the (optional) QSO-number column plus its gap, so the time
  /// column lines up with the QSO rows around it.
  final double leadingWidth;

  const AnnotationRow({super.key, required this.qso, required this.onTap, this.selected = false, this.leadingWidth = 0});

  /// app-polo's `eventRow` background, `rgb(252, 244, 167)` — blended over
  /// the surface at app-polo's row opacity (0.85 light / 0.65 dark) so the
  /// dark theme gets the same muted yellow instead of a full-brightness slab.
  static const _yellow = Color(0xFFFCF4A7);

  /// app-polo's `eventContent` text color, `rgb(21, 20, 10)` — near-black
  /// ink that stays readable on the yellow in both themes.
  static const _ink = Color(0xFF15140A);

  /// A to-do's icon tracks its state (same logic as app-polo's
  /// EventNoteItem): done shows a check, deleted hollows out. Everything
  /// else uses the icon the command stored on the event. The done flag is
  /// read from `data.done` with a fallback to a bare `done` — app-polo
  /// reads both, and synced logs contain the older bare shape.
  String get _iconName {
    final event = qso.event;
    if (qso.eventKind == 'todo') {
      if (qso.deleted) return 'sticker-outline';
      return eventTodoDone(event) ? 'sticker-check-outline' : 'sticker';
    }
    return asQsonString(event?['icon']) ?? 'information';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final event = qso.event;
    final timeLabel = _utcTimeLabel(qso.startAt);
    final text = asQsonString(event?['description']) ?? asQsonString(event?['note']) ?? qso.eventKind?.toUpperCase() ?? 'Event';

    final background = selected
        ? theme.colorScheme.secondaryContainer
        : Color.alphaBlend(_yellow.withValues(alpha: isDark ? 0.65 : 0.85), theme.colorScheme.surface);
    var ink = selected ? theme.colorScheme.onSecondaryContainer : _ink;
    // SOLAR/WEATHER descriptions mix emoji into the text, so the style
    // needs the bundled color-emoji font as an explicit fallback — the web
    // renderer never falls back to an OS emoji font on its own (see
    // theme.dart's `emojiFontFamily`).
    var textStyle = theme.textTheme.bodyMedium?.copyWith(color: ink, fontFamilyFallback: const [emojiFontFamily]);
    var timeStyle = haloMonoStyle(context, fontSize: _rowMonoFontSize, color: ink);
    // Deleted annotations follow the QSO rows' "show deleted" treatment:
    // struck-through and faded, still in the timeline.
    if (qso.deleted) {
      ink = ink.withValues(alpha: 0.5);
      textStyle = textStyle?.copyWith(color: ink, decoration: TextDecoration.lineThrough);
      timeStyle = timeStyle.copyWith(color: ink, decoration: TextDecoration.lineThrough);
    }

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          // See EventRow's identical note: matches the ordinary row's own
          // padding so this row's natural height fits [QsoList]'s fixed
          // per-row box exactly (HALO-258).
          padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: LayoutDensity.metricsOf(context).qsoRowPaddingV),
          child: Row(
            children: [
              SizedBox(width: leadingWidth),
              Text(timeLabel, style: timeStyle),
              const SizedBox(width: _columnGap),
              Icon(resolveIconName(_iconName), size: 16, color: ink),
              const SizedBox(width: _columnGap),
              Expanded(
                child: Text(text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
