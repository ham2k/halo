// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';

class LoggingPanel extends StatelessWidget {
  final Operation operation;
  final HaLoServices services;
  final List<Qso> qsos;
  final List<Map<String, dynamic>> loggingControls;
  final Future<void> Function(String action) onCommandAction;

  const LoggingPanel({
    super.key,
    required this.operation,
    required this.services,
    required this.qsos,
    required this.loggingControls,
    required this.onCommandAction,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final list = QsoList(qsos: qsos, qsosRepository: services.qsos);

    return Column(
      children: [
        Expanded(
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 2, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(child: InformationArea(operation: operation, qsos: qsos)),
                  ],
                )
              : list,
        ),
        LoggingControls(
          operation: operation,
          qsosRepository: services.qsos,
          qsos: qsos,
          lookup: services.extensions.lookupCall,
          activityControls: loggingControls,
          decorateRef: services.extensions.decorateRef,
          tryCommand: services.extensions.tryCommand,
          onCommandAction: onCommandAction,
        ),
      ],
    );
  }
}

class InformationArea extends StatelessWidget {
  final Operation operation;
  final List<Qso> qsos;

  const InformationArea({super.key, required this.operation, required this.qsos});

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
