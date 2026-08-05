// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../main.dart';
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

  const InformationPanel({
    super.key,
    required this.operation,
    required this.qsos,
    this.callInfo,
    this.services,
    this.ourEntityPrefix,
    this.activityControls = const [],
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
    // Keyed by scorer; these two lines are core's own tallies (see
    // app/lib/tools/scoring_summaries.dart).
    final operationSummary = operationSummaryFor(scoring, 'core');
    final dxcc = operationSummary?['dxcc'] as Map<String, dynamic>?;
    final dxccCount = (dxcc?['entities'] as Map?)?.length ?? 0;
    // Places, not contacts: the scorer's maps count QSOs per state, while what
    // belongs on this line is how many distinct ones have been worked. Absent
    // entirely for an operator outside North America, who tracks neither.
    final places = operationSummary?['statesAndProvinces'] as Map<String, dynamic>?;
    final stateCount = (places?['states'] as Map?)?.length ?? 0;
    final provinceCount = (places?['provinces'] as Map?)?.length ?? 0;
    // Core is rendered by hand here rather than through `_scorerSummary`, so
    // its per-band breakdown has to be picked out explicitly — a tally the
    // generic loop would have shown.
    final bandsAndModes = operationSummary?['bandsAndModes'] as Map<String, dynamic>?;
    final bandBreakdown = bandsAndModes?['longSummary'] as String?;
    final duplicateCount =
        ((operationSummary?['qsoCount'] as Map?)?['duplicates'] as num?)
            ?.toInt() ??
        0;

    final theme = Theme.of(context);
    return ListView(
      // Extra inset on every edge that's a divider grab strip or a real
      // device safe area.
      padding: EdgeInsets.all(Space.xl).add(PaneSafeArea.paddingOf(context)),
      children: [
        Text(context.t.loggingPanel.stats, style: theme.textTheme.titleSmall),
        // The stats' "since last" segment is now-relative — re-derive once a
        // second (scoped to these lines) so it doesn't sit stale between QSO
        // stream updates.
        OncePerSecond(builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in operationStatsLines(context, qsos)) Text(line, style: theme.textTheme.bodyMedium),
          ],
        )),
        if (operationSummary != null) ...[
          const SizedBox(height: Space.xl),
          Text(
            context.t.loggingPanel.scoring,
            style: theme.textTheme.titleSmall,
          ),
          Text('${context.t.loggingPanel.dxccEntities}: ${formatNumber(dxccCount)}'),
          if (stateCount > 0) Text('${context.t.loggingPanel.statesWorked}: ${formatNumber(stateCount)}'),
          if (provinceCount > 0) Text('${context.t.loggingPanel.provincesWorked}: ${formatNumber(provinceCount)}'),
          Text('${context.t.loggingPanel.duplicates}: ${formatNumber(duplicateCount)}'),
          if (bandBreakdown != null && bandBreakdown.isNotEmpty) _tallyDetail(context, bandBreakdown),
        ],
        // Every non-core scorer's own summary, in full. Core keeps the curated
        // two lines above (its duplicate count lives in a tally field rather
        // than a label, so a generic render would drop it); a contest instead
        // says what it wants said, since only it knows whether its score is
        // points, points x mults, or something else again.
        for (final scorerKey in orderedScorerKeys(scoring))
          if (scorerKey != 'core') ..._scorerSummary(context, scorerKey, scoring),
      ],
    );
  }

  /// One contest's operation summary: its heading, each tally's label and
  /// score, and the tally's own `longSummary` markdown (typically a per-band
  /// breakdown) rendered in full — this pane scrolls, and a contester wants
  /// the whole table visible rather than behind a tap.
  List<Widget> _scorerSummary(BuildContext context, String scorerKey, Map<String, dynamic>? scoring) {
    final summary = operationSummaryFor(scoring, scorerKey);
    if (summary == null || summary.isEmpty) return const [];
    final theme = Theme.of(context);

    // The contest's own name, as its `decorateRef` labelled it ("CQ WW CW") —
    // better than the bare extension key, and it already reflects the mode the
    // operator chose at setup.
    //
    // A contest's ref type IS its scorer key, but an activity's is the key plus
    // a suffix (`pota` scores an operation whose ref type is `potaActivation`),
    // so an exact match alone would leave every activity headed by its bare key.
    // Ref types are namespaced by extension key, which is what makes the prefix
    // fallback safe.
    //
    // An operation that only HUNTS a program carries no ref for it at all
    // (docs/design/activities.md §4) and still scores, so fall back to the
    // hunting control's own label — "POTA", not the bare key "pota".
    final refs = operation.refs.cast<Map<String, dynamic>?>();
    final ref = refs.firstWhere((r) => r?['type'] == scorerKey, orElse: () => null) ??
        refs.firstWhere(
          (r) => (r?['type'] as String?)?.startsWith(scorerKey) ?? false,
          orElse: () => null,
        );
    final heading = (ref?['shortLabel'] ?? ref?['label']) as String? ??
        controlForRefType(activityControls, scorerKey)?['label'] as String? ??
        scorerKey;
    // Each extension's own declared accent (same color `activityRefIcon`
    // tints its icon with) rather than one shared tertiary for every
    // scorer — falls back to a plain grey when the extension declares none.
    // Falling back to the scorer key whenever the ref's own type misses, not
    // only when there is no ref: a control declares the HUNTING type
    // ('pota'), while an activating operation's ref carries the activation one
    // ('potaActivation'), so the commoner case would otherwise be the grey one.
    final iconColor = colorForRefType(activityControls, ref?['type'] as String?) ??
        colorForRefType(activityControls, scorerKey) ??
        theme.colorScheme.onSurfaceVariant;

    final widgets = <Widget>[const SizedBox(height: Space.xl), Text(heading, style: theme.textTheme.titleSmall)];

    for (final entry in summary.entries) {
      final tally = entry.value;
      if (tally is! Map) continue;
      final label = tally['label'] as String?;
      final score = tally['summary'] as String?;
      final detail = tally['longSummary'] as String?;

      if (label != null && label.isNotEmpty) {
        widgets.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tally['icon'] is String) ...[
              Icon(resolveIconName(tally['icon'] as String), size: 16, color: iconColor),
              const SizedBox(width: Space.sm),
            ],
            Expanded(child: Text(label)),
            if (score != null && score.isNotEmpty)
              Text(score, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono')),
          ],
        ));
      }

      if (detail != null && detail.isNotEmpty) widgets.add(_tallyDetail(context, detail));
    }
    return widgets;
  }

  /// A tally's `longSummary` markdown — typically a per-band breakdown, which
  /// separates its rows with single newlines that Markdown would otherwise fold
  /// into one run-on paragraph. Monospace so the columns line up.
  Widget _tallyDetail(BuildContext context, String detail) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: MarkdownBody(
        data: detail,
        softLineBreak: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
              .copyWith(fontFamily: 'RobotoMono', fontSize: 12),
        ),
      ),
    );
  }
}
