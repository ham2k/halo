// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../../i18n/strings.g.dart';

class LoggingPanel extends StatefulWidget {
  final Operation operation;
  final HaLoServices services;
  final List<Qso> qsos;
  final List<Map<String, dynamic>> loggingControls;
  final CommandActionHandler onCommandAction;

  const LoggingPanel({
    super.key,
    required this.operation,
    required this.services,
    required this.qsos,
    required this.loggingControls,
    required this.onCommandAction,
  });

  @override
  State<LoggingPanel> createState() => _LoggingPanelState();
}

class _LoggingPanelState extends State<LoggingPanel> {
  String? _commandMarkdown;
  Qso? _selectedQso;
  late List<String> _controlOrder = widget.services.settings.secondaryControlsOrder;
  late Set<String> _hiddenControls = widget.services.settings.hiddenSecondaryControls;

  void _handleSelectQso(Qso qso) {
    setState(() {
      _selectedQso = _selectedQso?.uuid == qso.uuid ? null : qso;
    });
  }

  void _handleControlsSettingsChanged(List<String> order, Set<String> hidden) {
    setState(() {
      _controlOrder = order;
      _hiddenControls = hidden;
    });
    widget.services.settings.setSecondaryControlsOrder(order);
    widget.services.settings.setHiddenSecondaryControls(hidden);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final list = QsoList(
      qsos: widget.qsos,
      noQsosLabel: context.t.qsoList.empty,
      duplicateLabel: context.t.qsoList.duplicate,
      newEntityLabel: context.t.qsoList.newEntity,
      newBandOrModeLabel: context.t.qsoList.newBandOrMode,
      selectedUuid: _selectedQso?.uuid,
      onSelect: _handleSelectQso,
    );

    return Column(
      children: [
        Expanded(
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 2, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: InformationArea(
                        operation: widget.operation,
                        qsos: widget.qsos,
                        commandMarkdown: _commandMarkdown,
                      ),
                    ),
                  ],
                )
              : list,
        ),
        LoggingControls(
          operation: widget.operation,
          qsosRepository: widget.services.qsos,
          qsos: widget.qsos,
          settings: widget.services.settings,
          lookup: widget.services.extensions.lookupCall,
          activityControls: widget.loggingControls,
          decorateRef: widget.services.extensions.decorateRef,
          interpretCommand: widget.services.extensions.interpretCommand,
          onCommandMessageChanged: (message) {
            setState(() {
              _commandMarkdown = message;
            });
          },
          onCommandAction: widget.onCommandAction,
          editingQso: _selectedQso,
          onEditCanceled: () => setState(() => _selectedQso = null),
          onLogged: (_) => setState(() => _selectedQso = null),
          controlOrder: _controlOrder,
          hiddenControlKeys: _hiddenControls,
          onControlsSettingsChanged: _handleControlsSettingsChanged,
          timeControlLabel: context.t.loggingControls.timeControl,
          radioControlLabel: context.t.loggingControls.radioControl,
          controlSettingsTitle: context.t.loggingControls.controlSettings,
          saveLabel: context.t.common.save,
          cancelLabel: context.t.common.cancel,
          timeLabel: context.t.loggingControls.timeUtc,
          dateLabel: context.t.loggingControls.date,
          nowLabel: context.t.loggingControls.now,
          freqLabel: context.t.loggingControls.frequency,
          modeLabel: context.t.loggingControls.mode,
          dupeLabel: context.t.loggingControls.dupe,
          theirCallLabel: context.t.loggingControls.theirCall,
          sentLabel: context.t.loggingControls.sent,
          rcvdLabel: context.t.loggingControls.rcvd,
          moreLabel: context.t.loggingControls.more,
          revertLabel: context.t.loggingControls.revert,
          deleteLabel: context.t.common.delete,
          undoDeleteLabel: context.t.loggingControls.undoDelete,
          wipeLabel: context.t.loggingControls.wipe,
          undoLabel: context.t.loggingControls.undo,
          pendingDeleteWarning: context.t.loggingControls.pendingDeleteWarning,
          qsoEditFormTitle: context.t.qsoEditForm.title,
          theirNameLabel: context.t.qsoEditForm.theirName,
          theirGridLabel: context.t.qsoEditForm.theirGrid,
          notesLabel: context.t.qsoEditForm.notes,
          bandLabel: context.t.qsoEditForm.band,
        ),
      ],
    );
  }
}

class InformationArea extends StatelessWidget {
  final Operation operation;
  final List<Qso> qsos;
  final String? commandMarkdown;

  const InformationArea({
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
      byBand.update(qso.band ?? '?', (count) => count + 1, ifAbsent: () => 1);
      byMode.update(qso.mode ?? '?', (count) => count + 1, ifAbsent: () => 1);
    }

    // Cached by `ScoringService.rescoreOperation` into `Operations.localData`
    // (never synced — DESIGN.md §4) each time this operation is (re)scored;
    // absent until the first rescore completes.
    final scoring = operation.localData['scoring'] as Map<String, dynamic>?;
    final operationSummary = scoring?['operationSummary'] as Map<String, dynamic>?;
    final dxcc = operationSummary?['dxcc'] as Map<String, dynamic>?;
    final dxccCount = (dxcc?['entities'] as Map?)?.length ?? 0;
    final duplicateCount = ((operationSummary?['qsoCount'] as Map?)?['duplicates'] as num?)?.toInt() ?? 0;

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
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
        for (final entry in byBand.entries) Text('${entry.key}: ${entry.value}'),
        const SizedBox(height: 16),
        Text(context.t.loggingPanel.byMode, style: theme.textTheme.titleSmall),
        for (final entry in byMode.entries) Text('${entry.key}: ${entry.value}'),
        if (operationSummary != null) ...[
          const SizedBox(height: 16),
          Text(context.t.loggingPanel.scoring, style: theme.textTheme.titleSmall),
          Text('${context.t.loggingPanel.dxccEntities}: $dxccCount'),
          Text('${context.t.loggingPanel.duplicates}: $duplicateCount'),
        ],
      ],
    );
  }
}
