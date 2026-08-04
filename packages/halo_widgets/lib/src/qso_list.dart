// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list, styled after app-polo's log rows: Roboto Mono data
// columns, hairline dividers, newest QSO at the bottom edge next to the
// logging panel. Row layout follows ham2k/halo-dist#2's field list and
// order: Number (optional) | Time | Frequency (or Band, if no frequency) |
// Mode (only when the operation uses more than one) | Callsign |
// Emoji(s)/Name | References | RST.

import 'package:flutter/material.dart';
// `_revealSelected` measures the selected row against its viewport itself,
// rather than via Scrollable.ensureVisible, whose offsets don't survive this
// list's pinned headers — see there.
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import 'package:halo_core/halo_core.dart';

import 'activity_controls.dart';
import 'flags.dart';
import 'format_utils.dart';
import 'icon_resolver.dart';
import 'mdi_icons.g.dart';
import 'resizable_split_view.dart' show PaneSafeArea;
import 'semantic_id.dart';
import 'spacing.dart';
import 'theme.dart';

/// Horizontal gap between the row's fields (Number/Time/Frequency/Mode/
/// Callsign/Name/References/RST).
const double _columnGap = 12;

/// The list's UTC time-column label — `HH:MMz`, or a placeholder when the
/// record has no start time. Shared by the QSO, event, and annotation rows
/// so their time columns can never drift apart.
String _utcTimeLabel(DateTime? time) => time == null
    ? '--:--z'
    : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}z';

/// Every time label is the same six mono characters wide, so one measurement
/// stands in for the whole column.
const _timeLabelSample = '00:00z';

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

/// The signal-report column ("59 59").
const double _rstWidth = 68;

/// One ref badge's icon — the unknown-type avatar (radius 8) is the widest
/// of the two shapes, so it sets the column's per-type cost.
const double _refIconWidth = 16;

/// Trailing space after each ref badge.
const double _refIconGap = 6;

/// The refs a QSO shows as badges, by type, with how many of each — the
/// "×N" suffix. Contest refs carry an exchange rather than a place, so they
/// get no icon: every row in a contest log would otherwise wear the same
/// badge, which says nothing while crowding the columns that do.
///
/// Shared by the per-row builder and the list-wide width budget, which have
/// to agree about what a row draws or the budget reserves the wrong space.
Map<String, int> _refCountsByType(Qso qso, List<Map<String, dynamic>> controls) {
  final counts = <String, int>{};
  for (final ref in qso.refs) {
    final type = ref['type'] as String?;
    if (type == null) continue;
    if (_isContestRef(ref, controls)) continue;
    counts.update(type, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

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

/// The DX/State column's content for [qso], if any: a flag when we have
/// positive evidence of a DX contact (both sides resolved and different),
/// falling back to the contact's state whenever there's no flag to show —
/// not just when `!isDX` — so a DX contact whose entity resolved but whose
/// flag lookup came up empty (e.g. a DXCC entity present in
/// lib-country-files but missing from lib-dxcc-data's table) still shows
/// its state instead of going blank. Null when neither is available. Shared
/// by the list-wide column-width precompute and the per-row builder in
/// `_QsoListState.build`, so they can never disagree about what a QSO shows
/// there (ham2k/halo-dist#186).
({String text, bool isFlag, bool guessed})? _dxStateContentFor(Qso qso, String? ourEntityPrefix) {
  final theirEntityPrefix = qso.theirEntityPrefix;
  final isDX = theirEntityPrefix != null && ourEntityPrefix != null && theirEntityPrefix != ourEntityPrefix;
  final flag = qso.theirFlag;
  final state = qso.theirState;
  if (isDX && flag != null && flag.isNotEmpty) {
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

/// The localizable vocabulary the QSO list needs for day headers and event
/// rows — the tiering/formatting logic stays in the widget (it's display
/// logic, tested here), but the words come from the app's locale. Defaults
/// to English so the widget package stays usable standalone (and tests read
/// naturally); the app injects a locale-aware instance (see
/// `logging_panel.dart`, which fills the month/weekday names from `intl`'s
/// `DateFormat`).
class QsoListLabels {
  /// Monday-first, 7 entries: Mon…Sun.
  final List<String> weekdayAbbrs;

  /// 12 entries: Jan…Dec.
  final List<String> monthAbbrs;

  final String today;
  final String yesterday;
  final String tomorrow;

  /// Keyed by `Qso.eventKind` (`start`/`break`/`end`).
  final Map<String, String> eventLabels;

  /// The day header's QSO count ("1 QSO" / "12 QSOs"). Nullable function
  /// (same convention as LoggingControls' parameterized labels) so the
  /// class stays const-constructible — null falls back to the English
  /// composition.
  final String Function(int count)? qsoCount;

  const QsoListLabels({
    required this.weekdayAbbrs,
    required this.monthAbbrs,
    required this.today,
    required this.yesterday,
    required this.tomorrow,
    required this.eventLabels,
    this.qsoCount,
  });

  String qsoCountLabel(int count) => qsoCount?.call(count) ?? (count == 1 ? '1 QSO' : '$count QSOs');

  static const english = QsoListLabels(
    weekdayAbbrs: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    monthAbbrs: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    today: 'Today',
    yesterday: 'Yesterday',
    tomorrow: 'Tomorrow',
    eventLabels: {'start': 'Operation started', 'break': 'Break', 'end': 'Operation ended'},
  );
}

/// Whether a ref is contest metadata rather than an activity reference.
///
/// Two independent signals, because either can be missing: the ref's own
/// `program` (set by a contest's `decorateRef`, so it survives the extension
/// being switched off), and the shape of the control that owns its type — a
/// contest writes its exchange through a primary field, while an activity
/// reference comes from a `refList`.
///
/// "Primary field" must mean the same set here as in the logging panel's
/// `_textControls`, i.e. `text`, `serial` AND `options`: `controlForRefType`
/// returns the FIRST control for a type, and CQ WPX declares its serial before
/// its text exchange, so dropping `serial` here makes every WPX QSO read as an
/// activity reference and wear an icon. `options` — the searchable exchange —
/// belongs here for as long as it is in `_textControls`: the core writes only
/// `{type, field}` onto the ref an exchange field fills, so a state-park QSO
/// carries nothing else to say it is a contest contact.
bool _isContestRef(Map<String, dynamic> ref, List<Map<String, dynamic>> controls) {
  if (ref['program'] == 'Contest') return true;
  final control = controlForRefType(controls, ref['type'] as String?);
  final kind = (control?['input'] as Map?)?['kind'];
  return kind == 'text' || kind == 'serial' || kind == 'options' || kind == 'form';
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
  static const double rowHeight = 29;

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

  /// Tap an event marker row (start/break/end — see `Qso.isEvent`) to edit
  /// its time. Falls back to [onSelect] when omitted.
  final void Function(Qso qso)? onSelectEvent;

  /// Whether to show the RST column (ham2k/halo-dist#1's logging-view
  /// menu) — the underlying data always exists, this only hides the column.
  final bool showRSTFields;

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

  /// Raw `daySections` from the scoring hook's last run (see
  /// `ScoringHook.scoreQsos`/`ScoringService.rescoreOperation`), cached in
  /// `Operation.localData['scoring']['daySections']` — each entry is
  /// `{day, count, scores}`, `day` truncated to the same UTC boundary as
  /// [_dayInMillis]. Matched against the locally-computed day groups below
  /// by that `day` key; empty (or a day with no matching entry, e.g. before
  /// the first rescore lands) just means that header shows no score badges.
  final List<Map<String, dynamic>> daySections;

  /// Localized vocabulary for day headers and event rows — defaults to
  /// English; the app passes a locale-aware instance.
  final QsoListLabels labels;

  const QsoList({
    super.key,
    required this.qsos,
    required this.onSelect,
    this.onSelectEvent,
    this.selectedUuid,
    this.noQsosLabel,
    this.needsBandOrMode = false,
    this.bandOrModeWarningLabel,
    this.showRSTFields = true,
    this.showQsoNumbers = true,
    this.activityControls = const [],
    this.ourEntityPrefix,
    this.daySections = const [],
    this.labels = QsoListLabels.english,
  });

  @override
  State<QsoList> createState() => _QsoListState();
}

class _QsoListState extends State<QsoList> {
  final _scrollController = ScrollController();
  int _lastQsoCount = 0;
  bool _wasNearBottom = true;
  double? _lastMaxScrollExtent;

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

  @override
  void initState() {
    super.initState();
    _lastQsoCount = widget.qsos.length;
    _wasNearBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void didUpdateWidget(covariant QsoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final grew = widget.qsos.length > _lastQsoCount;
    _lastQsoCount = widget.qsos.length;
    // Only follow new QSOs down when the user is already looking at the
    // live edge — someone scrolled up to review earlier contacts shouldn't
    // get yanked back to the bottom by the next logged QSO.
    if (grew && _isNearBottom()) {
      _wasNearBottom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
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
    final scroll = _scrollTo(top, top + QsoList.rowHeight);
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
    for (var i = 0; i <= index; i++) {
      final millis = widget.qsos[i].startAtMillis ?? 0;
      final day = millis - (millis % _dayInMillis);
      if (day != lastDay) {
        offset += DayHeaderRow.pinnedHeight;
        lastDay = day;
      }
      if (i < index) offset += QsoList.rowHeight;
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
    final double target;
    if (top - DayHeaderRow.pinnedHeight < position.pixels) {
      target = top - DayHeaderRow.pinnedHeight;
    } else if (bottom > position.pixels + position.viewportDimension) {
      target = bottom - position.viewportDimension;
    } else {
      return null; // already fully visible
    }
    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((clamped - position.pixels).abs() < 0.5) return null;
    return _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
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

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 120;
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    _wasNearBottom = true;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0) {
      _wasNearBottom = _isNearBottom();
    }
    return false;
  }

  bool _onScrollMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      final metrics = notification.metrics;
      if (_lastMaxScrollExtent != null &&
          metrics.maxScrollExtent > _lastMaxScrollExtent!) {
        // If maxScrollExtent increased (e.g. secondary controls expanded,
        // layout resized) and user was near bottom, keep bottom QSO in view.
        if (_wasNearBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
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
            warn
                ? (widget.bandOrModeWarningLabel ?? 'Please make sure your band and mode are correct')
                : (widget.noQsosLabel ?? 'No QSOs yet — work someone!'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: warn ? theme.colorScheme.error : theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final mono = haloMonoStyle(
      context,
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );
    final monoDim = mono.copyWith(color: theme.colorScheme.outline);
    // Bold, but the same base size as every other field per the issue: "All
    // fields use the same base font size (except for frequency, see below)."
    final callStyle = mono.copyWith(fontWeight: FontWeight.w700);

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
    // Widest band shown in the freq/band column (only null-freq rows fall back
    // to the band) and widest their-exchange, so both columns reserve a
    // list-wide width and stay aligned even on rows that lack them (#354).
    var longestBand = '';
    var longestExchange = '';
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
    for (final q in qsos) {
      if (q.isEvent) continue;
      final refCounts = _refCountsByType(q, activityControls);
      if (refCounts.length > mostRefIcons) mostRefIcons = refCounts.length;
      for (final count in refCounts.values) {
        if (count > largestRefCount) largestRefCount = count;
      }
      if (q.theirCall.length > longestCall.length) longestCall = q.theirCall;
      freqsInKHz.add(q.freq);
      // Band only renders when the QSO has no frequency (freqField below).
      if (q.freq == null && (q.band?.length ?? 0) > longestBand.length) longestBand = q.band!;
      final exchange = q.theirExchange;
      if (exchange != null && exchange.length > longestExchange.length) longestExchange = exchange;
      final mode = q.mode;
      if (mode != null) modesUsed.add(mode);
      final dxState = _dxStateContentFor(q, ourEntityPrefix);
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
    final numberWidth = showQsoNumbers
        ? textWidth(context, '$maxNumber', mono)
        : 0.0;
    final callsignWidth = longestCall.isEmpty
        ? 0.0
        : textWidth(context, longestCall, callStyle);
    // On the image fallback (flagEmojiNeedsImageFallback), every flag renders
    // at the same fixed SVG size regardless of which entity it is, so that's
    // the width to reserve instead of measuring emoji glyph text.
    final flagWidth = longestFlag.isEmpty
        ? 0.0
        : flagEmojiNeedsImageFallback
            ? flagGlyphDefaultFontSize * 4 / 3
            : textWidth(context, longestFlag, emojiStyle());
    final stateWidth = longestState.isEmpty ? 0.0 : textWidth(context, longestState, monoDim);
    final dxStateWidth = flagWidth > stateWidth ? flagWidth : stateWidth;

    // "decide how many digits to display based on all the qsos in the
    // operation" — one Hz precision for the whole list, not per row.
    final hzDigits = hzDigitsNeeded(freqsInKHz);
    // The Mode column only earns its place when the operation actually mixes
    // modes — otherwise every row would repeat the same value.
    final usesMultipleModes = modesUsed.length > 1;

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
      final s = parts.hz != null ? '${parts.mhz}.${parts.khz}.${parts.hz}' : '${parts.mhz}.${parts.khz}';
      if (s.length > longestFreqOrBand.length) longestFreqOrBand = s;
    }
    final freqWidth = longestFreqOrBand.isEmpty ? 0.0 : textWidth(context, longestFreqOrBand, mono);
    // The their-exchange column (after the signal reports) reserves width only
    // when some QSO actually carries an exchange, like DX/State above (#354).
    final exchangeWidth = longestExchange.isEmpty ? 0.0 : textWidth(context, longestExchange, monoDim);
    // Measured from the largest count actually present, so a three-figure
    // repeat is budgeted at its real width rather than a two-digit sample.
    // Reserved for EVERY icon on the widest row rather than only the ones
    // that repeat: over-reserving costs the exchange column a few pixels,
    // under-reserving costs a row that overflows.
    final refCountWidth =
        largestRefCount > 1 ? textWidth(context, '×$largestRefCount', mono.copyWith(fontSize: 11)) : 0.0;
    final refsWidth =
        mostRefIcons == 0 ? 0.0 : _columnGap + mostRefIcons * (_refIconWidth + _refIconGap + refCountWidth);

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

    // Matched against each local day bucket by the same UTC-day key the
    // scoring hook uses — see `_dayInMillis`'s doc comment. Absent (or a
    // bucket with no matching entry, e.g. before the first rescore lands
    // for QSOs just logged) just means that header shows no score badges.
    final scoresByDay = <int, Map<String, dynamic>?>{
      for (final section in widget.daySections)
        if (section['day'] is num)
          (section['day'] as num).toInt():
              section['scores'] as Map<String, dynamic>?,
    };

    Widget buildRowContent(BuildContext context, int chronologicalIndex, _ColumnPlan plan) {
      final qso = qsos[chronologicalIndex];

      if (qso.isEvent) {
        // Operation segment markers keep their centered-label treatment;
        // every other event kind (note/todo/solar/weather — the annotation
        // commands, ham2k/halo-dist#64) renders as a yellow annotation
        // row in the timeline, following app-polo's QSOList dispatch.
        final kind = qso.eventKind;
        if (kind == 'start' || kind == 'break' || kind == 'end') {
          return EventRow(
            qso: qso,
            selected: qso.uuid == selectedUuid,
            onTap: () => (onSelectEvent ?? onSelect)(qso),
            labels: widget.labels,
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
      var rowMono = selected
          ? mono.copyWith(color: theme.colorScheme.onSecondaryContainer)
          : mono;
      var rowMonoDim = selected
          ? monoDim.copyWith(
              color: theme.colorScheme.onSecondaryContainer.withValues(
                alpha: 0.75,
              ),
            )
          : monoDim;
      var rowCall = selected
          ? callStyle.copyWith(color: theme.colorScheme.onSecondaryContainer)
          : callStyle;
      // Deleted QSOs only ever show up here when the "show deleted QSOs"
      // menu toggle is on — struck-through and faded so they read as
      // gone without disappearing from the timeline.
      if (qso.deleted) {
        rowMono = rowMono.copyWith(
          color: rowMono.color?.withValues(alpha: 0.5),
          decoration: TextDecoration.lineThrough,
        );
        rowMonoDim = rowMonoDim.copyWith(
          color: rowMonoDim.color?.withValues(alpha: 0.5),
          decoration: TextDecoration.lineThrough,
        );
        rowCall = rowCall.copyWith(
          color: rowCall.color?.withValues(alpha: 0.5),
          decoration: TextDecoration.lineThrough,
        );
      }

      // DX/State column — see _dxStateContentFor's doc for the flag-vs-state
      // rule, shared with the list-wide width precompute above. Emoji use a
      // proportional font per the issue ("emoji and name...use a
      // proportional font"), so this deliberately doesn't use
      // rowMono/rowMonoDim for the flag case — see theme.dart's emojiStyle
      // for why it also needs an explicit fontFamily.
      final dxState = _dxStateContentFor(qso, ourEntityPrefix);
      Widget? dxStateField;
      if (dxState != null) {
        dxStateField = dxState.isFlag ? flagGlyph(dxState.text) : Text(dxState.text, style: rowMonoDim);
        // Values coming from the callsign guess rather than an entered field
        // paint a touch fainter (80%) so guessed-but-unconfirmed reads as
        // such — the flag is an emoji, whose color the text style can't
        // fade, so the dimming is applied as an Opacity here instead of via
        // the text color.
        if (dxState.guessed) dxStateField = Opacity(opacity: 0.8, child: dxStateField);
      }

      // Frequency bolded-MHz/regular-kHz/smaller-Hz, dot-separated; falls
      // back to the band when the QSO has no frequency at all.
      final freqKHz = qso.freq;
      final Widget freqField;
      if (freqKHz == null) {
        freqField = Text(qso.band ?? '', style: rowMono);
      } else {
        final parts = freqDisplayParts(freqKHz, hzDigits: hzDigits);
        freqField = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              parts.mhz,
              style: rowMono.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('.', style: rowMono),
            Text(parts.khz, style: rowMono),
            if (parts.hz != null) ...[
              Text('.', style: rowMono),
              Text(
                parts.hz!,
                style: rowMono.copyWith(
                  fontSize: (rowMono.fontSize ?? 14) * 0.8,
                ),
              ),
            ],
          ],
        );
      }

      // One icon per distinct ref type, "×N" appended when the QSO carries
      // more than one of that type — see [_refCountsByType], which the width
      // budget uses to reserve this column.
      final refCountsByType = _refCountsByType(qso, activityControls);

      // #236: stable id for agent/browser tooling — per-callsign so a specific
      // logged QSO's row is targetable.
      return semanticId('qso.row.${qso.theirCall}', Container(
        // foregroundDecoration paints over the already-laid-out child
        // instead of insetting it (unlike Container's `decoration`,
        // which turns a BoxDecoration's border into padding) — the
        // selected-row accent border can't add any height on top of the
        // hairline row/divider spacing the issue calls for.
        foregroundDecoration: BoxDecoration(
          border: selected
              ? Border.symmetric(
                  horizontal: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Material(
          color: selected
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surface,
          child: InkWell(
            onTap: () => onSelect(qso),
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  if (plan.showNumbers) ...[
                    SizedBox(
                      width: numberWidth,
                      child: Text(
                        qso.deleted ? '' : formatNumber(number),
                        style: rowMonoDim,
                        textAlign: TextAlign.right,
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
                      child: Text(qso.mode ?? '', style: rowMono),
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
                  if (plan.showDxState) ...[
                    SizedBox(width: dxStateWidth, child: dxStateField),
                    const SizedBox(width: _columnGap),
                  ],
                  Expanded(
                    // A guessed name paints at 80% too (see the DX/state note).
                    child: Opacity(
                      opacity: qso.theirFieldIsGuessed('name') ? 0.8 : 1.0,
                      child: Text(
                        qso.theirName ?? '',
                        style: rowMonoDim.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (plan.showRefs && refCountsByType.isNotEmpty) ...[
                    const SizedBox(width: _columnGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in refCountsByType.entries) ...[
                          // An unrecognized type (its extension isn't
                          // installed/loaded right now) gets a small
                          // pale-red question-mark marker instead of the
                          // usual themed icon (ham2k/halo-dist#261) —
                          // via the shared activityRefIcon, sized down for
                          // this compact inline usage; the known-type icon
                          // stays bespoke, using the row's neutral
                          // foreground rather than a per-control accent
                          // (#354).
                          if (isUnknownRefType(activityControls, entry.key))
                            activityRefIcon(activityControls, entry.key,
                                iconSize: 10, avatarRadius: _refIconWidth / 2)
                          else
                            Icon(
                              resolveIconName(
                                iconForRefType(activityControls, entry.key),
                              ),
                              size: 14,
                              // Neutral row foreground ("black" in the light
                              // theme), not the tertiary accent (#354).
                              color: theme.colorScheme.onSurface,
                            ),
                          if (entry.value > 1)
                            Text(
                              '×${entry.value}',
                              style: rowMono.copyWith(fontSize: 11),
                            ),
                          const SizedBox(width: _refIconGap),
                        ],
                      ],
                    ),
                  ],
                  if (plan.showRst)
                    SizedBox(
                      width: _rstWidth,
                      child: Text(
                        '${qso.sentRST ?? ''} ${qso.receivedRST ?? ''}',
                        style: rowMonoDim,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  // Their exchange, after the signal reports (#354). Reserved
                  // list-wide only when some QSO carries one, so it costs no
                  // space in the common (RST-only) case.
                  if (plan.showExchange) ...[
                    const SizedBox(width: _columnGap),
                    SizedBox(
                      width: exchangeWidth,
                      child: Opacity(
                        opacity: qso.theirFieldIsGuessed('exchange') ? 0.8 : 1.0,
                        child: Text(
                          qso.theirExchange ?? '',
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
      ));
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
    final mandatoryWidth = textWidth(context, _timeLabelSample, monoDim) +
        _columnGap +
        freqWidth +
        _columnGap +
        callsignWidth +
        _columnGap +
        _fitSlack;

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
      (id: _Column.rst, earned: showRSTFields, width: _rstWidth),
      (id: _Column.refs, earned: refsWidth > 0, width: refsWidth),
      (id: _Column.exchange, earned: exchangeWidth > 0, width: exchangeWidth + _columnGap),
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
      child: LayoutBuilder(builder: (context, constraints) {
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
                    for (var g = 0; g < dayGroups.length; g++)
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
                              child: DayHeaderRow(
                                dayMillis: dayKeys[g],
                                count: dayGroups[g]
                                    .where((i) => qsos[i].isRealContact)
                                    .length,
                                scores: scoresByDay[dayKeys[g]],
                                labels: widget.labels,
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate((context, i) {
                              // Divider's own `height` (the space it reserves, not the
                              // visible line) defaults to 16 regardless of the
                              // app-wide dividerTheme's `space` unless given
                              // explicitly — measured at 16px in practice, way more
                              // than the issue's "one pixel divider ... no further
                              // margins" calls for. Same odd-index-is-a-separator
                              // trick `ListView.separated` uses internally, since
                              // `SliverList` has no `.separated` ctor.
                              if (i.isOdd) {
                                return const Divider(height: 1, thickness: 1);
                              }
                              return buildRow(context, dayGroups[g][i ~/ 2], plan);
                            }, childCount: dayGroups[g].length * 2 - 1),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Pins [DayHeaderRow] to the top of [QsoList]'s `CustomScrollView` while its
/// day's QSOs are in view, per issue #62 ("pinned headers that show the day
/// and scoring summaries").
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _DayHeaderDelegate({required this.child});

  @override
  double get minExtent => DayHeaderRow.pinnedHeight;

  @override
  double get maxExtent => DayHeaderRow.pinnedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Forces the child to exactly [DayHeaderRow.pinnedHeight] regardless of its own intrinsic
    // size — a pinned sliver header's declared extent must match what it
    // actually paints, or Flutter throws a "layoutExtent exceeds
    // paintExtent" assertion the instant [child]'s content (font size,
    // padding, border width) doesn't add up to precisely that.
    return SizedBox(height: DayHeaderRow.pinnedHeight, child: child);
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
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
  static const double pinnedHeight = 28;

  final int dayMillis;
  final int count;
  final Map<String, dynamic>? scores;
  final QsoListLabels labels;

  /// Overrides "now" for the relative-date label below — tests only; a real
  /// header always compares against the current moment.
  final DateTime? now;

  const DayHeaderRow({
    super.key,
    required this.dayMillis,
    required this.count,
    this.scores,
    this.labels = QsoListLabels.english,
    this.now,
  });

  /// Same tiering as app-polo/web-lofi's `fmtDateDynamicZulu(compact: true)`
  /// (lib-format-tools' `fmtDateDynamic`): "Today"/"Yesterday" for the
  /// obvious cases, weekday+day within the last week, month+day within the
  /// last 9 months, and month+day+year beyond that — so a long-running log
  /// still reads as calendar dates instead of an ever-scrolling "N days ago".
  static String _dayLabel(int dayMillis, DateTime now, QsoListLabels labels) {
    final d = DateTime.fromMillisecondsSinceEpoch(dayMillis, isUtc: true);
    final diffInDays = now.difference(d).inMilliseconds / _dayInMillis;
    final absDiffInDays = diffInDays.abs();

    // Order matters: a day two-plus in the future has diffInDays <= -1, which
    // must NOT fall through to the "Yesterday" (diffInDays <= 2) branch —
    // future days get their calendar-date label like any other non-adjacent
    // day, so a date typo or clock-skewed device reads "Jul 20", not
    // "Yesterday".
    if (diffInDays > -1 && diffInDays <= 0) return labels.tomorrow;
    if (diffInDays > 0 && diffInDays <= 1) return labels.today;
    if (diffInDays > 1 && diffInDays <= 2) return labels.yesterday;
    if (absDiffInDays <= 7) return '${labels.weekdayAbbrs[d.weekday - 1]} ${d.day}';
    if (absDiffInDays <= 274) return '${labels.monthAbbrs[d.month - 1]} ${d.day}';
    return '${labels.monthAbbrs[d.month - 1]} ${d.day} ${d.year}';
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
    final rowStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.0,
    );

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
      badges.add(
        Padding(
          padding: const EdgeInsets.only(left: Space.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resolveIconName(icon),
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Space.xs),
              Text(summary, style: rowStyle),
            ],
          ),
        ),
      );
    }

    return Container(
      // `surfaceContainerHigh` isn't one of the tones `buildHaLoTheme`
      // overrides (theme.dart), so it falls back to Flutter's default — an
      // almost-white tint that doesn't read as "gray" against the QSO
      // rows' plain `surface`. `surfaceContainerHighest` is an
      // explicitly-set, visibly gray tone (already used to fill the list's
      // own empty space above/below its rows), so it actually shows up as
      // a distinct header background.
      color: theme.colorScheme.surfaceContainerHighest,
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
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 3),
        ),
      ),
      child: Padding(
        // Same vertical padding as a QSO row (see `buildRow`'s own
        // `Padding` above) so the header comes out exactly row-height.
        padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 4),
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
                      _dayLabel(dayMillis, now ?? DateTime.now().toUtc(), labels),
                      style: rowStyle?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
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
                  Text(labels.qsoCountLabel(count), style: rowStyle),
                ],
              ),
            ),
            ...badges,
          ],
        ),
      ),
    );
  }
}

/// A start/break/end marker row in [QsoList], visually distinct from a QSO
/// row (centered label instead of data columns) since it isn't a contact —
/// tapping it opens time editing rather than the logging panel.
class EventRow extends StatelessWidget {
  final Qso qso;
  final bool selected;
  final VoidCallback onTap;
  final QsoListLabels labels;

  const EventRow({
    super.key,
    required this.qso,
    required this.onTap,
    this.selected = false,
    this.labels = QsoListLabels.english,
  });

  static const _icons = {
    'start': MdiIcons.flag,
    'break': MdiIcons.pauseCircle,
    'end': MdiIcons.flag,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = qso.eventKind;
    final timeLabel = _utcTimeLabel(qso.startAt);

    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icons[kind] ?? MdiIcons.timelapse,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: Space.md),
              // The only thing in this row that can give: the icon and the
              // time are fixed, and the label ("Operation started") is long
              // enough to overflow the list's minimum width on its own. One
              // Flexible among non-flex children takes what is left after
              // them, so it only shortens once there is nothing else.
              Flexible(
                child: Text(
                  (kind == null ? null : labels.eventLabels[kind]) ?? kind ?? 'Event',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                timeLabel,
                style: haloMonoStyle(
                  context,
                  fontSize: 12,
                  color: theme.colorScheme.outline,
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

  const AnnotationRow({
    super.key,
    required this.qso,
    required this.onTap,
    this.selected = false,
    this.leadingWidth = 0,
  });

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
      final data = event?['data'];
      final done = (data is Map && data['done'] == true) || event?['done'] == true;
      if (qso.deleted) return 'sticker-outline';
      return done ? 'sticker-check-outline' : 'sticker';
    }
    return (event?['icon'] as String?) ?? 'information';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final event = qso.event;
    final timeLabel = _utcTimeLabel(qso.startAt);
    final text = (event?['description'] as String?) ??
        (event?['note'] as String?) ??
        qso.eventKind?.toUpperCase() ??
        'Event';

    final background = selected
        ? theme.colorScheme.secondaryContainer
        : Color.alphaBlend(
            _yellow.withValues(alpha: isDark ? 0.65 : 0.85),
            theme.colorScheme.surface,
          );
    var ink = selected ? theme.colorScheme.onSecondaryContainer : _ink;
    // SOLAR/WEATHER descriptions mix emoji into the text, so the style
    // needs the bundled color-emoji font as an explicit fallback — the web
    // renderer never falls back to an OS emoji font on its own (see
    // theme.dart's `emojiFontFamily`).
    var textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: ink,
      fontFamilyFallback: const [emojiFontFamily],
    );
    var timeStyle = haloMonoStyle(context, fontSize: 14, color: ink);
    // Deleted annotations follow the QSO rows' "show deleted" treatment:
    // struck-through and faded, still in the timeline.
    if (qso.deleted) {
      ink = ink.withValues(alpha: 0.5);
      textStyle = textStyle?.copyWith(
        color: ink,
        decoration: TextDecoration.lineThrough,
      );
      timeStyle = timeStyle.copyWith(
        color: ink,
        decoration: TextDecoration.lineThrough,
      );
    }

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: PaneSafeArea.symmetricOf(context, horizontal: 12, vertical: 4),
          child: Row(
            children: [
              SizedBox(width: leadingWidth),
              Text(timeLabel, style: timeStyle),
              const SizedBox(width: _columnGap),
              Icon(resolveIconName(_iconName), size: 16, color: ink),
              const SizedBox(width: _columnGap),
              Expanded(
                child: Text(
                  text,
                  style: textStyle,
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
