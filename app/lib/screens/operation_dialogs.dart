// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small dialogs shared between OperationsScreen (the list, long-press to
// delete) and OperationScreen's Operation tab (same actions, reached via a
// list tile instead) — kept in one place so both stay in sync rather than
// carrying two copies of the same confirm-delete/edit-details prompt.

import 'package:flutter/material.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

/// Prompts to confirm, then soft-deletes on confirmation. Returns whether
/// the operation was deleted.
Future<bool> confirmDeleteOperation(
  BuildContext context,
  OperationsRepository operations,
  Operation operation,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete operation "${operation.title.isEmpty ? operation.stationCall : operation.title}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed == true) await operations.softDelete(operation.uuid);
  return confirmed == true;
}

/// Edits station callsign/title on an existing operation. Returns the
/// updated Operation, or null if cancelled.
Future<Operation?> editOperationDetails(
  BuildContext context,
  OperationsRepository operations,
  Operation operation,
) async {
  final callController = TextEditingController(text: operation.stationCall);
  final titleController = TextEditingController(text: operation.title);

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Operation details'),
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
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
      ],
    ),
  );

  if (saved != true || callController.text.trim().isEmpty) return null;
  final updated = Operation(
    uuid: operation.uuid,
    data: {
      ...operation.data,
      'stationCall': callController.text.trim().toUpperCase(),
      'title': titleController.text.trim(),
    },
    qsoCount: operation.qsoCount,
    startAtMillisMin: operation.startAtMillisMin,
    startAtMillisMax: operation.startAtMillisMax,
  );
  await operations.saveData(updated);
  return updated;
}
