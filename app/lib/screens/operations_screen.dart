// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';

import '../main.dart';
import '../spike_screen.dart';
import 'operation_screen.dart';

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
              decoration: const InputDecoration(labelText: 'Station callsign'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
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
        title: const Text('PoLo Next — Operations'),
        actions: [
          IconButton(
            tooltip: 'Plugin bridge spike',
            icon: const Icon(Icons.science_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpikeScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newOperation(context),
        icon: const Icon(Icons.add),
        label: const Text('New operation'),
      ),
      body: StreamBuilder<List<Operation>>(
        stream: services.operations.watchAll(),
        builder: (context, snapshot) {
          final operations = snapshot.data ?? const <Operation>[];
          if (operations.isEmpty) {
            return const Center(child: Text('No operations yet. Create one to start logging.'));
          }
          return ListView.builder(
            itemCount: operations.length,
            itemBuilder: (context, index) {
              final operation = operations[index];
              final when = operation.startAtMax;
              return ListTile(
                leading: CircleAvatar(child: Text(operation.qsoCount.toString())),
                title: Text(operation.title.isEmpty ? operation.stationCall : operation.title),
                subtitle: Text([
                  operation.stationCall,
                  if (when != null) '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}',
                ].join(' • ')),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OperationScreen(services: services, operationUuid: operation.uuid),
                )),
                trailing: PopupMenuButton<String>(
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete operation')),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') services.operations.softDelete(operation.uuid);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
