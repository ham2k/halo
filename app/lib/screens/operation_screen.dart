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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final operation = await widget.services.operations.get(widget.operationUuid);
    setState(() => _operation = operation);
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

        return Scaffold(
          appBar: AppBar(
            title: Text([
              operation.title.isEmpty ? operation.stationCall : operation.title,
              '${qsos.length} QSOs',
            ].join(' — ')),
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
              lookup: widget.services.plugins.lookupCall,
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
