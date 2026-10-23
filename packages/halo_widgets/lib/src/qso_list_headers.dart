// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO list's pinned section headers: a day's, and the one over the
// contacts from outside the log.

part of 'qso_list.dart';

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

  /// Null leaves the count out, for a day that holds none of the list's rows.
  final int? count;
  final Map<String, dynamic>? scores;

  /// Tapping the header opens the operation's own info — the day divider is
  /// the list's stand-in for "this operation", the way a QSO row is for a
  /// contact. Null leaves the header inert.
  final VoidCallback? onTap;

  /// Overrides "now" for the relative-date label below — tests only; a real
  /// header always compares against the current moment.
  final DateTime? now;

  const DayHeaderRow({super.key, required this.dayMillis, this.count, this.scores, this.now, this.onTap});

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
    final rowStyle = _headerRowStyle(theme);

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

    return _HeaderFrame(
      onTap: onTap,
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
                if (count case final count?) ...[
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
              ],
            ),
          ),
          ...badges,
        ],
      ),
    );
  }
}

/// [DayHeaderRow]'s style, shared with [_OtherQsosHeaderRow]: the same base
/// size as the QSO rows below it (app-polo's QSOHeader reuses its row font
/// wholesale, just bolding the date) — labelLarge/labelMedium read visibly
/// larger than the row text and make the header feel like a different,
/// heavier UI element instead of a divider within the list. `height: 1.0`
/// overrides bodyMedium's Material 3 line-height multiplier (1.43, meant for
/// prose) back down to the font's natural metric — same as the row's own
/// `haloMonoStyle`, which never sets an explicit `height` either — so the
/// header doesn't come out visibly taller than an ordinary QSO row despite
/// using the same 14px font size.
TextStyle? _headerRowStyle(ThemeData theme) => theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.0);

/// The band every [QsoList] header is drawn in — [DayHeaderRow]'s, and
/// [_OtherQsosHeaderRow]'s, which reads as one of them.
class _HeaderFrame extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _HeaderFrame({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The pinned header over [QsoList.otherQsos], drawn as a day header is,
/// with its label — the count already in it — where the date goes. Inert,
/// like the rows under it.
class _OtherQsosHeaderRow extends StatelessWidget {
  final String label;

  const _OtherQsosHeaderRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HeaderFrame(
      // A Row, as the day header's is, so the label sits on the same line.
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: _headerRowStyle(theme)?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
