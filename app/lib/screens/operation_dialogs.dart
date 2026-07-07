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
  final result = await editTwoFieldDialog(
    context,
    title: 'Operation details',
    field1Label: 'Station callsign',
    field1Initial: operation.stationCall,
    field1Capitalization: TextCapitalization.characters,
    field2Label: 'Title (optional)',
    field2Initial: operation.title,
  );
  if (result == null || result.$1.trim().isEmpty) return null;

  final updated = Operation(
    uuid: operation.uuid,
    data: {
      ...operation.data,
      'stationCall': result.$1.trim().toUpperCase(),
      'title': result.$2.trim(),
    },
    qsoCount: operation.qsoCount,
    startAtMillisMin: operation.startAtMillisMin,
    startAtMillisMax: operation.startAtMillisMax,
  );
  await operations.saveData(updated);
  return updated;
}

/// Shared skeleton for a two-field edit dialog (operation details, QRZ
/// credentials): title, two TextFields with poloFieldDecoration, Cancel/Save
/// actions, Enter-to-save on the second field. Returns the two raw
/// (untrimmed) field values, or null if cancelled.
Future<(String, String)?> editTwoFieldDialog(
  BuildContext context, {
  required String title,
  required String field1Label,
  required String field1Initial,
  required String field2Label,
  required String field2Initial,
  TextCapitalization field1Capitalization = TextCapitalization.none,
  bool field2Obscure = false,
}) {
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => _TwoFieldDialog(
      title: title,
      field1Label: field1Label,
      field1Initial: field1Initial,
      field2Label: field2Label,
      field2Initial: field2Initial,
      field1Capitalization: field1Capitalization,
      field2Obscure: field2Obscure,
    ),
  );
}

/// Single-field variant of `editTwoFieldDialog` (operator callsign, link-by-
/// email) — same disposal-safety shape (see `_TwoFieldDialogState`'s note).
/// Returns the raw (untrimmed) field value, or null if cancelled.
Future<String?> editOneFieldDialog(
  BuildContext context, {
  required String title,
  required String fieldLabel,
  required String fieldInitial,
  TextCapitalization fieldCapitalization = TextCapitalization.none,
  String saveLabel = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _OneFieldDialog(
      title: title,
      fieldLabel: fieldLabel,
      fieldInitial: fieldInitial,
      fieldCapitalization: fieldCapitalization,
      saveLabel: saveLabel,
    ),
  );
}

class _OneFieldDialog extends StatefulWidget {
  final String title;
  final String fieldLabel;
  final String fieldInitial;
  final TextCapitalization fieldCapitalization;
  final String saveLabel;

  const _OneFieldDialog({
    required this.title,
    required this.fieldLabel,
    required this.fieldInitial,
    required this.fieldCapitalization,
    required this.saveLabel,
  });

  @override
  State<_OneFieldDialog> createState() => _OneFieldDialogState();
}

class _OneFieldDialogState extends State<_OneFieldDialog> {
  late final _controller = TextEditingController(text: widget.fieldInitial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.fieldCapitalization,
        decoration: poloFieldDecoration(context, widget.fieldLabel),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
      ],
    );
  }
}

class _TwoFieldDialog extends StatefulWidget {
  final String title;
  final String field1Label;
  final String field1Initial;
  final String field2Label;
  final String field2Initial;
  final TextCapitalization field1Capitalization;
  final bool field2Obscure;

  const _TwoFieldDialog({
    required this.title,
    required this.field1Label,
    required this.field1Initial,
    required this.field2Label,
    required this.field2Initial,
    required this.field1Capitalization,
    required this.field2Obscure,
  });

  @override
  State<_TwoFieldDialog> createState() => _TwoFieldDialogState();
}

// A dedicated State (rather than creating controllers in the showDialog
// builder/caller and disposing them once the awaited Future resolves) so
// dispose() fires when this element is actually removed from the tree,
// after the dialog's closing transition finishes — disposing right after
// the Future completes races that transition and throws "TextEditingController
// used after being disposed" while the dialog fades out.
class _TwoFieldDialogState extends State<_TwoFieldDialog> {
  late final _controller1 = TextEditingController(text: widget.field1Initial);
  late final _controller2 = TextEditingController(text: widget.field2Initial);

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop((_controller1.text, _controller2.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller1,
            autofocus: true,
            textCapitalization: widget.field1Capitalization,
            decoration: poloFieldDecoration(context, widget.field1Label),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller2,
            obscureText: widget.field2Obscure,
            decoration: poloFieldDecoration(context, widget.field2Label),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
