// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging screen: QSO list above, logging panel docked at the bottom.
// On wide layouts (desktop, tablet landscape) an info side panel appears —
// the first step toward the module-docking layout of DESIGN.md §7.

import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

import '../main.dart';

class OperationScreen extends StatefulWidget {
  final PoloServices services;
  final String operationUuid;

  const OperationScreen({super.key, required this.services, required this.operationUuid});

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  Operation? _operation;
  List<Map<String, dynamic>> _loggingControls = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final operation = await widget.services.operations.get(widget.operationUuid);
    setState(() => _operation = operation);
    if (operation != null) {
      // Extension runtime may still be booting; controls appear when it answers.
      await widget.services.extensions.start();
      final controls = await widget.services.extensions.loggingControls(operation.data);
      if (mounted) setState(() => _loggingControls = controls);
    }
  }

  Future<void> _editActivities(Operation operation) async {
    final controls = await widget.services.extensions.operationControls(operation.data);
    if (!mounted) return;
    if (controls.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No activities available (extension runtime still starting?)')));
      return;
    }

    var refs = operation.refs;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Activities'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final control in controls)
                  if ((control['input'] as Map?)?['kind'] == 'refList')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RefChipsInput(
                        refType: (control['input'] as Map)['refType'] as String,
                        label: (control['label'] as String?) ?? '',
                        placeholder: (control['input'] as Map)['placeholder'] as String?,
                        pattern: (control['input'] as Map)['pattern'] as String?,
                        refs: refs
                            .where((r) => r['type'] == (control['input'] as Map)['refType'])
                            .toList(),
                        onChanged: (updated) => setDialogState(() {
                          final refType = (control['input'] as Map)['refType'];
                          refs = [
                            ...refs.where((r) => r['type'] != refType),
                            ...updated,
                          ];
                        }),
                        decorate: widget.services.extensions.decorateRef,
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final updated = Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'refs': refs},
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
      );
      await widget.services.operations.saveData(updated);
      if (mounted) setState(() => _operation = updated);
    }
  }

  Future<void> _export(Operation operation) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await widget.services.exports.exportOperation(operation);
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text('Exported to $path')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final operation = _operation;
    if (operation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Qso>>(
      stream: widget.services.qsos.watchForOperation(operation.uuid),
      builder: (context, snapshot) {
        final qsos = snapshot.data ?? const <Qso>[];
        final wide = MediaQuery.sizeOf(context).width >= 900;

        final list = QsoList(qsos: qsos, qsosRepository: widget.services.qsos);

        final refsLine = operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • ');

        return Scaffold(
          appBar: AppBar(
            leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset : null,
            leading: isMacOSChromelessWindow
                ? const Padding(
                    padding: EdgeInsets.only(left: macOSTrafficLightInset),
                    child: BackButton(),
                  )
                : null,
            title: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                operation.title.isEmpty ? operation.stationCall : '${operation.stationCall} ${operation.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                [if (refsLine.isNotEmpty) refsLine, '${qsos.length} QSOs'].join(' • '),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                    ),
              ),
            ]),
            actions: [
              IconButton(
                tooltip: 'Activities',
                icon: Icon(MdiIcons.pineTree),
                onPressed: () => _editActivities(operation),
              ),
              IconButton(
                tooltip: 'Export ADIF',
                icon: Icon(MdiIcons.fileExportOutline),
                onPressed: qsos.isEmpty ? null : () => _export(operation),
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: wide
                  ? Row(children: [
                      Expanded(flex: 2, child: list),
                      const VerticalDivider(width: 1),
                      Expanded(child: _InfoPanel(operation: operation, qsos: qsos)),
                    ])
                  : list,
            ),
            LoggingPanel(
              operation: operation,
              qsosRepository: widget.services.qsos,
              qsos: qsos,
              lookup: widget.services.extensions.lookupCall,
              activityControls: _loggingControls,
              decorateRef: widget.services.extensions.decorateRef,
              tryCommand: widget.services.extensions.tryCommand,
            ),
          ]),
        );
      },
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final Operation operation;
  final List<Qso> qsos;

  const _InfoPanel({required this.operation, required this.qsos});

  @override
  Widget build(BuildContext context) {
    final byBand = <String, int>{};
    final byMode = <String, int>{};
    for (final qso in qsos) {
      byBand.update(qso.band ?? '?', (count) => count + 1, ifAbsent: () => 1);
      byMode.update(qso.mode ?? '?', (count) => count + 1, ifAbsent: () => 1);
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Station', style: theme.textTheme.titleSmall),
        Text(operation.stationCall, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text('By band', style: theme.textTheme.titleSmall),
        for (final entry in byBand.entries) Text('${entry.key}: ${entry.value}'),
        const SizedBox(height: 16),
        Text('By mode', style: theme.textTheme.titleSmall),
        for (final entry in byMode.entries) Text('${entry.key}: ${entry.value}'),
      ],
    );
  }
}
