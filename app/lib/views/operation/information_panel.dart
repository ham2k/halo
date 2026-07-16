// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';

/// The Operation View's "Info" pane on two-pane layouts (issue #85):
/// operation statistics plus whatever the last logging command printed.
/// Formerly `InformationArea`, LoggingPanel's own >=900px side panel — it
/// moved here when the wide layout became the operation view's job
/// (docs/design/layouts.md).
class InformationPanel extends StatelessWidget {
  final Operation operation;
  final List<Qso> qsos;
  final String? commandMarkdown;

  const InformationPanel({
    super.key,
    required this.operation,
    required this.qsos,
    this.commandMarkdown,
  });

  @override
  Widget build(BuildContext context) {
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
    final operationSummary =
        scoring?['operationSummary'] as Map<String, dynamic>?;
    final dxcc = operationSummary?['dxcc'] as Map<String, dynamic>?;
    final dxccCount = (dxcc?['entities'] as Map?)?.length ?? 0;
    final duplicateCount =
        ((operationSummary?['qsoCount'] as Map?)?['duplicates'] as num?)
            ?.toInt() ??
        0;

    final theme = Theme.of(context);
    return ListView(
      // Extra left inset: the split's grab strip overlays this pane's edge.
      padding: EdgeInsets.all(16).add(EdgeInsets.only(left: PaneSafeArea.leftOf(context))),
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
        Text(operation.stationCall, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(context.t.loggingPanel.byBand, style: theme.textTheme.titleSmall),
        for (final entry in byBand.entries)
          Text('${entry.key}: ${entry.value}'),
        const SizedBox(height: 16),
        Text(context.t.loggingPanel.byMode, style: theme.textTheme.titleSmall),
        for (final entry in byMode.entries)
          Text('${entry.key}: ${entry.value}'),
        if (operationSummary != null) ...[
          const SizedBox(height: 16),
          Text(
            context.t.loggingPanel.scoring,
            style: theme.textTheme.titleSmall,
          ),
          Text('${context.t.loggingPanel.dxccEntities}: $dxccCount'),
          Text('${context.t.loggingPanel.duplicates}: $duplicateCount'),
        ],
      ],
    );
  }
}
