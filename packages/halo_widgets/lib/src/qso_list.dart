// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reactive QSO list, styled after app-polo's log rows: Roboto Mono data
// columns, hairline dividers, newest QSO at the bottom edge next to the
// logging panel. Row layout follows ham2k/app-halo-dist#2's field list and
// order: Number (optional) | Time | Frequency (or Band, if no frequency) |
// Mode (only when the operation uses more than one) | Callsign |
// Emoji(s)/Name | References | RST.

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';

import 'activity_controls.dart';
import 'icon_resolver.dart';
import 'theme.dart';

/// Horizontal gap between the row's fields (Number/Time/Frequency/Mode/
/// Callsign/Name/References/RST).
const double _columnGap = 12;

/// Measures how wide [text] renders in [style] — used to size the Number and
/// Callsign columns to the widest value in the list, per the issue's "wide
/// enough to fit the largest number/longest callsign" requirement. Merges
/// [style] onto the ambient `DefaultTextStyle` first, same as the real `Text`
/// widgets in the row do internally — measuring [style] alone undercounts
/// whenever the ambient style carries non-zero letter-spacing (Material 3's
/// default text theme sets `letterSpacing: 0.25`), which was previously
/// enough to wrap a long callsign onto a second line despite the SizedBox
/// supposedly being sized to fit it. Also applies the ambient text scaler
/// explicitly, matching how `Text` resolves its effective scaler by default —
/// `TextPainter` doesn't pick up `MediaQuery` on its own, so without this the
/// column would be sized for the unscaled text and wrap at any font-scale
/// setting above 1.0.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final merged = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(text: text, style: merged),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

/// The list's UTC time-column label — `HH:MMz`, or a placeholder when the
/// record has no start time. Shared by the QSO, event, and annotation rows
/// so their time columns can never drift apart.
String _utcTimeLabel(DateTime? time) => time == null
    ? '--:--z'
    : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}z';

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

  const QsoListLabels({
    required this.weekdayAbbrs,
    required this.monthAbbrs,
    required this.today,
    required this.yesterday,
    required this.tomorrow,
    required this.eventLabels,
  });

  static const english = QsoListLabels(
    weekdayAbbrs: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    monthAbbrs: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
    today: 'Today',
    yesterday: 'Yesterday',
    tomorrow: 'Tomorrow',
    eventLabels: {'start': 'Operation started', 'break': 'Break', 'end': 'Operation ended'},
  );
}

class QsoList extends StatefulWidget {
  final List<Qso> qsos;
  final String? noQsosLabel;

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

  /// Whether to show the RST column (ham2k/app-halo-dist#1's logging-view
  /// menu) — the underlying data always exists, this only hides the column.
  final bool showRSTFields;

  /// Whether to show the Number column (ham2k/app-halo-dist#2's logging-view
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

  @override
  void initState() {
    super.initState();
    _lastQsoCount = widget.qsos.length;
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 120;
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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

    final theme = Theme.of(context);
    if (qsos.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            widget.noQsosLabel ?? 'No QSOs yet — work someone!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
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
    for (final q in qsos) {
      if (q.isEvent) continue;
      if (q.theirCall.length > longestCall.length) longestCall = q.theirCall;
      freqsInKHz.add(q.freq);
      final mode = q.mode;
      if (mode != null) modesUsed.add(mode);
    }

    // Column widths are computed once for the whole list so every row lines
    // up, per the issue: "wide enough to fit the largest number"/"longest
    // callsign in all qsos".
    final numberWidth = showQsoNumbers
        ? _textWidth(context, '$maxNumber', mono)
        : 0.0;
    final callsignWidth = longestCall.isEmpty
        ? 0.0
        : _textWidth(context, longestCall, callStyle);

    // "decide how many digits to display based on all the qsos in the
    // operation" — one Hz precision for the whole list, not per row.
    final hzDigits = hzDigitsNeeded(freqsInKHz);
    // The Mode column only earns its place when the operation actually mixes
    // modes — otherwise every row would repeat the same value.
    final usesMultipleModes = modesUsed.length > 1;

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

    Widget buildRow(BuildContext context, int chronologicalIndex) {
      final qso = qsos[chronologicalIndex];

      if (qso.isEvent) {
        // Operation segment markers keep their centered-label treatment;
        // every other event kind (note/todo/solar/weather — the annotation
        // commands, ham2k/app-halo-dist#64) renders as a yellow annotation
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
          leadingWidth: showQsoNumbers ? numberWidth + _columnGap : 0,
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

      // DX/State column: a flag only when we have positive evidence the
      // contact is outside our own DXCC entity (both sides resolved and
      // different) — otherwise falls back to the contact's state, same
      // as a same-entity contact. Emoji use a proportional font per the
      // issue ("emoji and name...use a proportional font"), so this
      // deliberately doesn't use rowMono/rowMonoDim for the flag case —
      // see theme.dart's emojiStyle for why it also needs an explicit
      // fontFamily.
      final theirEntityPrefix = qso.theirEntityPrefix;
      final isDX =
          theirEntityPrefix != null &&
          ourEntityPrefix != null &&
          theirEntityPrefix != ourEntityPrefix;
      final flag = qso.theirFlag;
      final state = qso.theirState;
      Widget? dxStateField;
      if (isDX && flag != null) {
        dxStateField = Text(flag, style: emojiStyle());
      } else if (state != null && state.isNotEmpty) {
        // Falls back to state whenever there's no flag to show — not just
        // when `!isDX` — so a DX contact whose entity resolved but whose
        // flag lookup came up empty (e.g. a DXCC entity present in
        // lib-country-files but missing from lib-dxcc-data's table)
        // still shows its state instead of going blank.
        dxStateField = Text(state, style: rowMonoDim);
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

      // One icon per distinct ref type, "×N" appended when the QSO
      // carries more than one ref of that type.
      final refCountsByType = <String, int>{};
      for (final ref in qso.refs) {
        final type = ref['type'] as String?;
        if (type == null) continue;
        refCountsByType.update(type, (count) => count + 1, ifAbsent: () => 1);
      }

      return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  if (showQsoNumbers) ...[
                    SizedBox(
                      width: numberWidth,
                      child: Text(
                        qso.deleted ? '' : '$number',
                        style: rowMonoDim,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: _columnGap),
                  ],
                  Text(timeLabel, style: rowMonoDim),
                  const SizedBox(width: _columnGap),
                  freqField,
                  const SizedBox(width: _columnGap),
                  if (usesMultipleModes) ...[
                    SizedBox(
                      width: 42,
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
                  if (dxStateField != null) ...[
                    dxStateField,
                    const SizedBox(width: _columnGap),
                  ],
                  Expanded(
                    child: Text(
                      qso.theirName ?? '',
                      style: rowMonoDim.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (refCountsByType.isNotEmpty) ...[
                    const SizedBox(width: _columnGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in refCountsByType.entries) ...[
                          Icon(
                            resolveIconName(
                              iconForRefType(activityControls, entry.key),
                            ),
                            size: 14,
                            color: theme.colorScheme.tertiary,
                          ),
                          if (entry.value > 1)
                            Text(
                              '×${entry.value}',
                              style: rowMono.copyWith(fontSize: 11),
                            ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                  if (showRSTFields)
                    SizedBox(
                      width: 68,
                      child: Text(
                        '${qso.sentRST ?? ''} ${qso.receivedRST ?? ''}',
                        style: rowMonoDim,
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      // Shows through wherever the list doesn't reach (e.g. below the
      // newest row when there are few QSOs) — rows themselves stay opaque
      // on the normal surface color below.
      color: theme.colorScheme.surfaceContainerHighest,
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
                    return buildRow(context, dayGroups[g][i ~/ 2]);
                  }, childCount: dayGroups[g].length * 2 - 1),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Pins [DayHeaderRow] to the top of [QsoList]'s `CustomScrollView` while its
/// day's QSOs are in view, per issue #62 ("pinned headers that show the day
/// and scoring summaries").
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  // Matches an ordinary QSO row's own height (4px vertical padding either
  // side of a 14px line at its natural, un-inflated line height — see
  // `DayHeaderRow.build`'s `rowStyle`) plus a little headroom so [child]'s
  // forced `SizedBox(height: _height)` below never clips/overflows it. The
  // border lives in `foregroundDecoration`, not `decoration`, specifically
  // so it doesn't add to this the way `Container` would otherwise
  // auto-inset for a `decoration`'s border.
  static const double _height = 28;

  const _DayHeaderDelegate({required this.child});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Forces the child to exactly [_height] regardless of its own intrinsic
    // size — a pinned sliver header's declared extent must match what it
    // actually paints, or Flutter throws a "layoutExtent exceeds
    // paintExtent" assertion the instant [child]'s content (font size,
    // padding, border width) doesn't add up to precisely [_height].
    return SizedBox(height: _height, child: child);
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
    // read visibly larger than the row text and made the header feel like a
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
      if (entry.key == 'qsoCount') continue;
      final tally = entry.value;
      if (tally is! Map) continue;
      final icon = tally['icon'] as String?;
      final summary = tally['summary'] as String?;
      if (icon == null || summary == null || summary.isEmpty) continue;
      badges.add(
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resolveIconName(icon),
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
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
      // background and the border all but disappeared against it.
      foregroundDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 3),
        ),
      ),
      child: Padding(
        // Same vertical padding as a QSO row (see `buildRow`'s own
        // `Padding` above) so the header comes out exactly row-height.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Text(
              _dayLabel(dayMillis, now ?? DateTime.now().toUtc(), labels),
              style: rowStyle?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 10),
            Text(count == 1 ? '1 QSO' : '$count QSOs', style: rowStyle),
            const Spacer(),
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
    'start': Icons.flag,
    'break': Icons.pause_circle,
    'end': Icons.flag,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icons[kind] ?? Icons.timelapse,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                (kind == null ? null : labels.eventLabels[kind]) ?? kind ?? 'Event',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
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
/// pseudo-QSO added by the annotation commands (ham2k/app-halo-dist#64,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
