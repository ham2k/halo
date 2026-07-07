// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

import '../main.dart';
import 'operation_dialogs.dart';
import 'operation_screen.dart';
import 'settings_screen.dart';

/// PoLo home-screen style row: bold "CALL title" line with count pill,
/// subtitle line with refs/description and right-aligned date.
class _OperationRow extends StatelessWidget {
  final PoloServices services;
  final Operation operation;

  const _OperationRow({required this.services, required this.operation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = operation.startAtMax;
    final dateLabel = when == null ? '' : '${_monthName(when.month)} ${when.day}';
    final subtitle = operation.refs.map((r) => r['name']).whereType<String>().join(' • ');

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OperationScreen(services: services, operationUuid: operation.uuid),
      )),
      onLongPress: () => confirmDeleteOperation(context, services.operations, operation),
      child: Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: operation.stationCall,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (operation.title.isNotEmpty)
                    TextSpan(
                      text: ' ${operation.title}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${operation.qsoCount}', style: theme.textTheme.labelLarge),
            ),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Text(dateLabel, style: theme.textTheme.bodyMedium),
          ]),
        ]),
      ),
    );
  }

  String _monthName(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}

class OperationsScreen extends StatelessWidget {
  final PoloServices services;

  const OperationsScreen({super.key, required this.services});

  Future<void> _newOperation(BuildContext context) async {
    final callController = TextEditingController();
    final titleController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New operation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: callController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: poloFieldDecoration(context, 'Station callsign'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: poloFieldDecoration(context, 'Title (optional)'),
              onSubmitted: (_) => Navigator.of(context).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
        ],
      ),
    );

    if (created != true || callController.text.trim().isEmpty) return;
    final operation = await services.operations.create(
      stationCall: callController.text.trim(),
      title: titleController.text.trim(),
    );
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OperationScreen(services: services, operationUuid: operation.uuid),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset + macOSTrafficLightGap : null,
        leading: Padding(
          padding: EdgeInsets.fromLTRB(
            8 + (isMacOSChromelessWindow ? macOSTrafficLightInset + macOSTrafficLightGap : 0),
            8,
            8,
            8,
          ),
          child: Image.asset('assets/images/ham2k-logo.png'),
        ),
        // "Desktop Logger" / "Portable Logger" is the in-app main-screen
        // title — independent of the OS-level app name ("Ham2K Logger" on
        // desktop, "PoLo" on mobile; see macos/Runner/Configs/AppInfo.xcconfig,
        // ios/Runner/Info.plist, android's AndroidManifest.xml).
        title: Text(isWindowedPlatform ? 'Desktop Logger' : 'Portable Logger'),
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Icon(MdiIcons.cog),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(services: services)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newOperation(context),
        icon: Icon(MdiIcons.plus),
        label: const Text('New operation'),
      ),
      body: StreamBuilder<List<Operation>>(
        stream: services.operations.watchAll(),
        builder: (context, snapshot) {
          final operations = snapshot.data ?? const <Operation>[];
          if (operations.isEmpty) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Text('No operations yet. Create one to start logging.')),
            );
          }
          return Container(
            // Shows through below the last row when there aren't enough
            // operations to fill the screen.
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListView.separated(
              itemCount: operations.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) => _OperationRow(services: services, operation: operations[index]),
            ),
          );
        },
      ),
    );
  }
}
