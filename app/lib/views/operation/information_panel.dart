// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../main.dart';
import '../../tools/scoring_summaries.dart';
import 'call_info_panel.dart';

/// The Operation View's "Info" pane on two-pane layouts (issue #85):
/// operation statistics plus whatever the last logging command printed. When a
/// call is being logged it becomes the Call Info detail (issue #40).
/// Formerly `InformationArea`, LoggingPanel's own >=900px side panel — it
/// moved here when the wide layout became the operation view's job
/// (docs/design/layouts.md).
class InformationPanel extends StatelessWidget {
  final Operation operation;
  final List<Qso> qsos;
  final String? commandMarkdown;

  /// When set, the pane shows the Call Info detail instead of the operation
  /// stats — the current call being logged (issue #40).
  final CallInfoData? callInfo;
  final HaLoServices? services;
  final String? ourEntityPrefix;

  const InformationPanel({
    super.key,
    required this.operation,
    required this.qsos,
    this.commandMarkdown,
    this.callInfo,
    this.services,
    this.ourEntityPrefix,
  });

  @override
  Widget build(BuildContext context) {
    // A call being logged takes over the pane with its detail (issue #40).
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
    final byBand = <String, int>{};
    final byMode = <String, int>{};
    for (final qso in qsos) {
      if (!qso.isRealContact) continue;
      byBand.update(qso.band ?? '?', (count) => count + 1, ifAbsent: () => 1);
      byMode.update(qso.mode ?? '?', (count) => count + 1, ifAbsent: () => 1);
    }

    // Cached by `ScoringService.rescoreOperation` into `Operations.localData`
    // (never synced — DESIGN.md §4) each time this operation is (re)scored;
    // absent until the first rescore completes.
    final scoring = operation.localData['scoring'] as Map<String, dynamic>?;
    // Keyed by scorer since contest scoring landed; these two lines are core's
    // own tallies (see app/lib/tools/scoring_summaries.dart).
    final operationSummary = operationSummaryFor(scoring, 'core');
    final dxcc = operationSummary?['dxcc'] as Map<String, dynamic>?;
    final dxccCount = (dxcc?['entities'] as Map?)?.length ?? 0;
    final duplicateCount =
        ((operationSummary?['qsoCount'] as Map?)?['duplicates'] as num?)
            ?.toInt() ??
        0;

    final theme = Theme.of(context);
    return ListView(
      // Extra inset on every edge that's a divider grab strip or a real
      // device safe area (ham2k/app-halo-dist#205).
      padding: EdgeInsets.all(16).add(PaneSafeArea.paddingOf(context)),
      children: [
        if (commandMarkdown != null) ...[
          MarkdownBody(
            data: commandMarkdown!,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
        ],
        Text(context.t.loggingPanel.station, style: theme.textTheme.titleSmall),
        Text(operation.stationCall, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'RobotoMono')),
        const SizedBox(height: 16),
        Text(context.t.loggingPanel.byBand, style: theme.textTheme.titleSmall),
        for (final entry in byBand.entries)
          Text('${entry.key}: ${formatNumber(entry.value)}'),
        const SizedBox(height: 16),
        Text(context.t.loggingPanel.byMode, style: theme.textTheme.titleSmall),
        for (final entry in byMode.entries)
          Text('${entry.key}: ${formatNumber(entry.value)}'),
        if (operationSummary != null) ...[
          const SizedBox(height: 16),
          Text(
            context.t.loggingPanel.scoring,
            style: theme.textTheme.titleSmall,
          ),
          Text('${context.t.loggingPanel.dxccEntities}: ${formatNumber(dxccCount)}'),
          Text('${context.t.loggingPanel.duplicates}: ${formatNumber(duplicateCount)}'),
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
    final ref = operation.refs.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r?['type'] == scorerKey,
      orElse: () => null,
    );
    final heading = (ref?['shortLabel'] ?? ref?['label']) as String? ?? scorerKey;

    final widgets = <Widget>[const SizedBox(height: 16), Text(heading, style: theme.textTheme.titleSmall)];

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
              Icon(resolveIconName(tally['icon'] as String), size: 16, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(label)),
            if (score != null && score.isNotEmpty)
              Text(score, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono')),
          ],
        ));
      }

      if (detail != null && detail.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4),
          child: MarkdownBody(
            data: detail,
            // The per-band table separates rows with single newlines, which
            // Markdown would otherwise fold into one run-on paragraph.
            softLineBreak: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
                  .copyWith(fontFamily: 'RobotoMono', fontSize: 12),
            ),
          ),
        ));
      }
    }
    return widgets;
  }
}
