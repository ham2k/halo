// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of '../logs_view.dart';

/// The span of the log the Logs view shows. Calendar spans are UTC, like the
/// log's own days.
enum LogsPeriod {
  thisMonth,
  last3Months,
  thisYear,
  lastYear,
  allTime,
  custom;

  /// Where the span starts and where it stops (exclusive), as millis, for a
  /// clock reading [now] (UTC) — null for an open end. Every span is whole
  /// calendar months or years: [last3Months] is this month and the two
  /// before it, and [lastYear] the calendar year before this one. [custom]
  /// reads its days from [range], whose end day is included; with no range it
  /// is open at both ends.
  ({int? start, int? end}) bounds(DateTime now, {DateTimeRange? range}) {
    int ms(DateTime day) => day.millisecondsSinceEpoch;
    return switch (this) {
      LogsPeriod.thisMonth => (start: ms(DateTime.utc(now.year, now.month)), end: null),
      LogsPeriod.last3Months => (start: ms(DateTime.utc(now.year, now.month - 2)), end: null),
      LogsPeriod.thisYear => (start: ms(DateTime.utc(now.year)), end: null),
      LogsPeriod.lastYear => (start: ms(DateTime.utc(now.year - 1)), end: ms(DateTime.utc(now.year))),
      LogsPeriod.allTime => (start: null, end: null),
      LogsPeriod.custom when range != null => (
        start: ms(DateTime.utc(range.start.year, range.start.month, range.start.day)),
        end: ms(DateTime.utc(range.end.year, range.end.month, range.end.day + 1)),
      ),
      LogsPeriod.custom => (start: null, end: null),
    };
  }

  String label(BuildContext context) => switch (this) {
    LogsPeriod.thisMonth => context.t.home.logs.period.thisMonth,
    LogsPeriod.last3Months => context.t.home.logs.period.last3Months,
    LogsPeriod.thisYear => context.t.home.logs.period.thisYear,
    LogsPeriod.lastYear => context.t.home.logs.period.lastYear,
    LogsPeriod.allTime => context.t.home.logs.period.allTime,
    LogsPeriod.custom => context.t.home.logs.period.custom,
  };

  /// The period as the title names it — "October", "Aug–Oct", "2025" —
  /// or null for [allTime], which the title leaves unsaid. Months and years
  /// only: the subtitle carries the exact days (see [dateSpan]).
  String? titleLabel(BuildContext context, DateTime now) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return switch (this) {
      LogsPeriod.thisMonth => DateFormat.LLLL(locale).format(now),
      LogsPeriod.last3Months => '${DateFormat.LLL(locale).format(DateTime.utc(now.year, now.month - 2))}–${DateFormat.LLL(locale).format(now)}',
      LogsPeriod.thisYear => '${now.year}',
      LogsPeriod.lastYear => '${now.year - 1}',
      LogsPeriod.allTime => null,
      LogsPeriod.custom => context.t.home.logs.periodTitle.custom,
    };
  }

  /// The first and last day the period covers — today, for one still
  /// running. Null when it has no start: [allTime], or [custom] without
  /// its [range].
  String? dateSpan(DateTime now, {DateTimeRange? range}) {
    final (:start, :end) = bounds(now, range: range);
    if (start == null) return null;
    return _dateRangeLabel(start, end == null ? now.millisecondsSinceEpoch : end - _logsDayMillis);
  }
}

/// The Logs view's sheet: the station callsigns on the left, the time period
/// on the right. Every pick applies as it is made, so the sheet's OK only
/// closes it.
class _LogsSheet extends StatelessWidget {
  final Map<String, int> callsigns;
  final LogFilter filter;
  final LogsGrouping grouping;
  final LogsPeriod period;
  final DateTimeRange? customRange;
  final ValueChanged<LogFilter> onFilter;
  final ValueChanged<LogsGrouping> onGrouping;
  final ValueChanged<LogsPeriod> onPeriod;

  const _LogsSheet({
    required this.callsigns,
    required this.filter,
    required this.grouping,
    required this.period,
    required this.customRange,
    required this.onFilter,
    required this.onGrouping,
    required this.onPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.home.logs;
    final sortedCalls = callsigns.keys.toList()..sort();
    final total = callsigns.values.fold(0, (sum, count) => sum + count);
    return Material(
      color: haloSheetListBackground(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _LogsSheetColumn(
              sections: [
                (
                  t.sheet.callsigns,
                  [
                    _LogsSheetRow(selected: filter.allCalls, label: Text(t.allCallsigns), count: total, onTap: () => onFilter(const LogFilter.all())),
                    for (final call in sortedCalls)
                      _LogsSheetRow(
                        selected: filter.stationCall == call,
                        label: Text(
                          call,
                          style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700),
                        ),
                        count: callsigns[call] ?? 0,
                        onTap: () => onFilter(LogFilter(stationCall: call)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: _LogsSheetColumn(
              sections: [
                (
                  t.sheet.groupBy,
                  [for (final g in LogsGrouping.values) _LogsSheetRow(selected: grouping == g, label: Text(g.label(context)), onTap: () => onGrouping(g))],
                ),
                (
                  t.sheet.period,
                  [
                    for (final p in LogsPeriod.values)
                      _LogsSheetRow(
                        selected: period == p,
                        label: Text(p.label(context)),
                        detail: p == LogsPeriod.custom && customRange != null
                            ? '${_dateFormat.format(customRange!.start)} – ${_dateFormat.format(customRange!.end)}'
                            : null,
                        onTap: () => onPeriod(p),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of [_LogsSheet]: each section's title band, then its rows,
/// scrolling on their own.
class _LogsSheetColumn extends StatelessWidget {
  final List<(String title, List<Widget> rows)> sections;

  const _LogsSheetColumn({required this.sections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget band(String title) => Material(
      color: haloDialogBandColorAt(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.md),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ),
    );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final (title, rows) in sections) ...[band(title), ...rows],
      ],
    );
  }
}

class _LogsSheetRow extends StatelessWidget {
  final bool selected;
  final Widget label;

  /// A QSO count, drawn as the operation list's count pill.
  final int? count;

  /// A second line under [label].
  final String? detail;
  final VoidCallback onTap;

  const _LogsSheetRow({required this.selected, required this.label, this.count, this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: haloSheetRowColor(context),
      selected: selected,
      leading: Icon(selected ? MdiIcons.radioboxMarked : MdiIcons.radioboxBlank),
      title: label,
      subtitle: detail == null ? null : Text(detail!),
      trailing: count == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Text(formatNumber(count!), style: theme.textTheme.labelLarge),
            ),
      onTap: onTap,
    );
  }
}
