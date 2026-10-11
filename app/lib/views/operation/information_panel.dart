// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../tools/operation_stats.dart';
import '../../tools/scoring_summaries.dart';
import 'call_info_panel.dart';

/// The Operation View's "Info" pane on two-pane layouts (see
/// docs/design/layouts.md): basic operation statistics, then the score
/// summaries. When a call is being logged it becomes the Call Info detail.
class InformationPanel extends StatelessWidget {
  final Operation operation;
  final List<Qso> qsos;

  /// When set, the pane shows the Call Info detail instead of the operation
  /// stats — the current call being logged.
  final CallInfoData? callInfo;
  final HaLoServices? services;
  final String? ourEntityPrefix;

  /// The active extension logging controls (same list `QsoList` uses) — a
  /// scorer summary's tally icons are tinted with its own control's accent
  /// color, same as the QSO rows' ref icons would be if they used one.
  final List<Map<String, dynamic>> activityControls;

  /// The stats' heading, when the log is not an operation's — the Chasing
  /// view's names its period. Null reads "Operation Stats".
  final String? statsTitle;

  const InformationPanel({
    super.key,
    required this.operation,
    required this.qsos,
    this.callInfo,
    this.services,
    this.ourEntityPrefix,
    this.activityControls = const [],
    this.statsTitle,
  });

  @override
  Widget build(BuildContext context) {
    final info = callInfo;
    if (info != null && services != null) {
      return Padding(
        padding: PaneSafeArea.paddingOf(context),
        child: CallInfoPanel(
          operation: operation,
          services: services!,
          call: info.call,
          guess: info.guess,
          lookups: info.lookups,
          alertKeys: info.alertKeys,
          noticeKeys: info.noticeKeys,
          ourEntityPrefix: ourEntityPrefix,
        ),
      );
    }
    return _buildStats(context);
  }

  Widget _buildStats(BuildContext context) {
    // Cached by `ScoringService.rescoreOperation` into `Operations.localData`
    // (never synced — DESIGN.md §4) each time this operation is (re)scored;
    // absent until the first rescore completes.
    final scoring = operation.localData['scoring'] as Map<String, dynamic>?;
    final scorerKeys = orderedScorerKeys(scoring);
    final duplicateCount = ((operationSummaryFor(scoring, 'core')?['qsoCount'] as Map?)?['duplicates'] as num?)?.toInt() ?? 0;
    // A single-day operation's per-day breakdown would just restate the
    // totals below it — the split only earns its place once there's more
    // than one day to tell apart.
    final daySections = mergedDaySections(scoring);
    // Contests first, then activities (parks and the like), then core's own
    // DXCC/states/bands bookkeeping last — the order `orderedScorerKeys`
    // returns. Each tally's own label is its section's title; there is no
    // per-scorer heading on top of it. Built eagerly (not `if
    // scorerKeys.isNotEmpty`) so a legacy pre-scorer-keyed cached blob —
    // `orderedScorerKeys` sees keys but no scorer actually resolves — shows
    // no "Scoring" heading over an empty section instead of an orphaned one.
    final scoringWidgets = [for (final scorerKey in scorerKeys) ..._scorerSummary(context, scorerKey, scoring)];

    final theme = Theme.of(context);
    return ListView(
      // Extra inset on every edge that's a divider grab strip or a real
      // device safe area.
      padding: EdgeInsets.all(Space.xl).add(PaneSafeArea.paddingOf(context)),
      children: [
        Text(statsTitle ?? context.t.loggingPanel.stats, style: theme.textTheme.titleSmall),
        // The stats' "since last" segment is now-relative — re-derive once a
        // second (scoped to these lines) so it doesn't sit stale between QSO
        // stream updates.
        OncePerSecond(
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final line in operationStatsLines(context, qsos)) Text(line, style: theme.textTheme.bodyMedium)],
          ),
        ),
        if (daySections.length > 1) ..._daySummaries(context, daySections),
        if (scoringWidgets.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Text(context.t.loggingPanel.scoring, style: theme.textTheme.titleSmall),
          ...scoringWidgets,
          if (duplicateCount > 0) Text('${context.t.loggingPanel.duplicates}: ${formatNumber(duplicateCount)}'),
        ],
      ],
    );
  }

  /// One block per calendar day the operation spans: the date, that day's QSO
  /// count, then each scorer's DAY-scoped tallies (`for: 'day'`) — an
  /// activity's activation progress resets with the day it's scoped to, while
  /// carry-over tallies like DXCC or bands/modes stay in the operation totals
  /// below rather than repeating unchanged under every day.
  List<Widget> _daySummaries(BuildContext context, List<Map<String, dynamic>> daySections) {
    final theme = Theme.of(context);
    final t = context.t.loggingControls.info;
    // Per-locale, not a bare `DateFormat(...)`: weekday/month names are
    // locale text (halo_widgets' DayHeaderRow localizes the same day-header
    // vocabulary the same way).
    final dayFormat = DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag());
    final widgets = <Widget>[];
    for (final section in daySections) {
      final dayMillis = (section['day'] as num).toInt();
      final scores = (section['scores'] as Map?)?.cast<String, dynamic>() ?? const {};
      final count = ((scores['core.qsoCount'] as Map?)?['count'] as num?)?.toInt() ?? 0;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '${dayFormat.format(DateTime.fromMillisecondsSinceEpoch(dayMillis, isUtc: true))}: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: count == 1 ? t.qsoCountOne : t.qsoCountOther(count: count)),
              ],
            ),
          ),
        ),
      );

      final dayTallies = Map<String, dynamic>.fromEntries(
        scores.entries.where((entry) {
          final tally = entry.value;
          return tally is Map && tally['key'] != 'qsoCount' && tally['for'] == 'day';
        }),
      );
      widgets.addAll(_tallyRows(context, dayTallies, theme.colorScheme.onSurfaceVariant));
    }
    return widgets;
  }

  /// One scorer's tallies — no heading of its own; each tally's `label` IS
  /// its section's title (`_tallyRows`), so a scorer with several tallies
  /// (core's DXCC/states/bands) reads as several titled sections in a row
  /// rather than one heading followed by an undifferentiated list.
  List<Widget> _scorerSummary(BuildContext context, String scorerKey, Map<String, dynamic>? scoring) {
    final summary = operationSummaryFor(scoring, scorerKey);
    if (summary == null || summary.isEmpty) return const [];
    final theme = Theme.of(context);

    final iconColor = scorerIconColor(operation, scorerKey, activityControls) ?? theme.colorScheme.onSurfaceVariant;

    return _tallyRows(context, summary, iconColor);
  }

  /// One titled section per tally: its icon, label (as the section's own
  /// heading) and score, then its `longSummary` markdown in full underneath
  /// — shared by core's own operation and per-day summaries (plain
  /// `onSurfaceVariant` icons) and every other scorer's (`_scorerSummary`,
  /// tinted with its own accent color). `qsoCount` is always skipped: its
  /// count is already the "N QSOs" line in the stats block above.
  List<Widget> _tallyRows(BuildContext context, Map<String, dynamic> summary, Color iconColor) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    for (final entry in summary.entries) {
      if (entry.key == 'qsoCount') continue;
      final tally = entry.value;
      if (tally is! Map) continue;
      final label = tally['label'] as String?;
      final detail = tally['longSummary'] as String?;
      // `summary` is a short number restating what `longSummary` already
      // says in full ("5" beside "5 DXCC Entities" whose flags list is right
      // below it) — only worth its own column when there's no detail to
      // carry it instead.
      final score = (detail == null || detail.isEmpty) ? tally['summary'] as String? : null;

      if (label == null || label.isEmpty) continue;

      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tally['icon'] is String) ...[
              // `titleSmall`'s cap-height sits a couple of pixels below the
              // icon's own top edge — nudged down so the icon's optical center
              // lines up with the title's baseline instead of its bounding box.
              Padding(
                padding: const EdgeInsets.only(top: Space.xxs),
                child: Icon(resolveIconName(tally['icon'] as String), size: 16, color: iconColor),
              ),
              const SizedBox(width: Space.sm),
            ],
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            if (score != null && score.isNotEmpty) Text(score, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono')),
          ],
        ),
      );

      if (detail != null && detail.isNotEmpty) {
        widgets.add(_tallyDetail(context, detail, isGrid: tally['grid'] == true));
      }
      // Breathing room after the section, not just before the next one's
      // title — otherwise the last section in a list runs straight into
      // whatever follows it (the duplicates line, the next day, the end of
      // the pane).
      widgets.add(const SizedBox(height: Space.xl));
    }
    return widgets;
  }

  /// A tally's `longSummary` markdown — a DXCC entities list or a band
  /// breakdown reads as prose, in the pane's ordinary proportional font. A
  /// tally that opts in with `grid: true` (any scorer's own fixed-set
  /// checklist — states/provinces today, a contest's multiplier list or an
  /// activity's award grid tomorrow) gets the monospace checklist treatment
  /// instead. Rows are separated by single newlines, which Markdown would
  /// otherwise fold into one run-on paragraph.
  Widget _tallyDetail(BuildContext context, String detail, {required bool isGrid}) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final styleSheet = withEmojiFallback(
      MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: isGrid
            ? bodyStyle.copyWith(
                fontFamily: 'RobotoMono',
                fontSize: 12,
                // Dimmer than onSurfaceVariant alone — a code still open should
                // all but recede next to a worked one's full-strength strikethrough.
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              )
            : bodyStyle,
        // The codes still open are the default paragraph color, dimmed above;
        // a worked one is struck through AND set back to full strength, so the
        // grid reads at a glance as done versus still needed rather than
        // everything competing at the same weight. `null` when not a grid
        // leaves the theme's own `del` style alone (`copyWith`'s `del ?? this.del`).
        del: isGrid
            ? bodyStyle.copyWith(
                fontFamily: 'RobotoMono',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: MarkdownBody(data: detail, softLineBreak: true, styleSheet: styleSheet),
    );
  }
}

/// The accent a scorer's tallies wear: its extension's own declared color,
/// the same one its references' icons are tinted with — or null when it
/// declares none. Shared with the Operation Postcard's summary pages.
Color? scorerIconColor(Operation operation, String scorerKey, List<Map<String, dynamic>> activityControls) {
  // A contest's ref type IS its scorer key, but an activity's is the key plus
  // a suffix (`pota` scores an operation whose ref type is `potaActivation`),
  // so an exact match alone would leave every activity's icons uncolored.
  // Ref types are namespaced by extension key, which is what makes the prefix
  // fallback safe.
  //
  // An operation that only HUNTS a program carries no ref for it at all
  // (docs/design/activities.md §4) and still scores, so fall back to the
  // hunting control's own accent.
  final refs = operation.refs.cast<Map<String, dynamic>?>();
  final ref =
      refs.firstWhere((r) => r?['type'] == scorerKey, orElse: () => null) ??
      refs.firstWhere((r) => (r?['type'] as String?)?.startsWith(scorerKey) ?? false, orElse: () => null);
  // Each extension's own declared accent (same color `activityRefIcon`
  // tints its icon with) rather than one shared tertiary for every
  // scorer.
  // Falling back to the scorer key whenever the ref's own type misses, not
  // only when there is no ref: a control declares the HUNTING type
  // ('pota'), while an activating operation's ref carries the activation one
  // ('potaActivation'), so the commoner case would otherwise be the grey one.
  return colorForRefType(activityControls, ref?['type'] as String?, code: ref == null ? null : refCodeOf(ref)) ?? colorForRefType(activityControls, scorerKey);
}
