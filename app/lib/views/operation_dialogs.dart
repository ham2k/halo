// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small dialogs shared between HomeView (the list, long-press to
// delete) and OperationView's Operation settings panel (same actions, reached via a
// list tile instead) — kept in one place so both stay in sync rather than
// carrying two copies of the same confirm-delete/edit-details prompt.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import '../i18n/strings.g.dart';

/// Prompts to confirm, then soft-deletes on confirmation. Returns whether
/// the operation was deleted.
Future<bool> confirmDeleteOperation(
  BuildContext context,
  OperationsRepository operations,
  Operation operation,
) async {
  final confirmed = await showHaloDialog<bool>(
    context: context,
    builder: (context) => HaloDialog(
      title: Text(context.t.dialogs.deleteOperationConfirm(title: operation.title.isEmpty ? operation.stationCall : operation.title)),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.common.delete)),
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
    title: context.t.dialogs.operationDetails,
    field1Label: context.t.home.stationCallsign,
    field1Initial: operation.stationCall,
    field1Capitalization: TextCapitalization.characters,
    field2Label: context.t.home.titleOptional,
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
    localData: operation.localData,
  );
  await operations.saveData(updated);
  return updated;
}

/// Edits a UTC timestamp via HH:MM/YYYY-MM-DD text fields — same format as
/// the logging panel's Time control. Returns the new millis, or null if
/// cancelled.
Future<int?> editTimeDialog(
  BuildContext context, {
  required String title,
  required int initialMillis,
}) {
  return showHaloDialog<int>(
    context: context,
    builder: (context) => _TimeDialog(title: title, initialMillis: initialMillis),
  );
}

class _TimeDialog extends StatefulWidget {
  final String title;
  final int initialMillis;

  const _TimeDialog({required this.title, required this.initialMillis});

  @override
  State<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends State<_TimeDialog> {
  late final DateTime _initial = DateTime.fromMillisecondsSinceEpoch(widget.initialMillis, isUtc: true);
  late final _timeController = TextEditingController(text: _fmtTime(_initial));
  late final _dateController = TextEditingController(text: _fmtDate(_initial));

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  static String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timeController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _save() {
    final time = _timeController.text.split(':');
    final date = _dateController.text.split('-');
    if (time.length != 2 || date.length != 3) return;
    final hour = int.tryParse(time[0]);
    final minute = int.tryParse(time[1]);
    final year = int.tryParse(date[0]);
    final month = int.tryParse(date[1]);
    final day = int.tryParse(date[2]);
    if (hour == null || minute == null || year == null || month == null || day == null) return;
    Navigator.of(context).pop(DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    return HaloDialog(
      wide: true,
      title: Text(widget.title),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: TextField(
              controller: _timeController,
              style: haloMonoStyle(context, fontSize: 15),
              decoration: poloFieldDecoration(context, context.t.loggingControls.timeUtc),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _dateController,
              style: haloMonoStyle(context, fontSize: 15),
              decoration: poloFieldDecoration(context, context.t.loggingControls.date),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
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
  return showHaloDialog<(String, String)>(
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
  return showHaloDialog<String>(
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
    return HaloDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.fieldCapitalization,
        decoration: poloFieldDecoration(context, widget.fieldLabel),
        onSubmitted: (_) => _save(),
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
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
    return HaloDialog(
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
          if (widget.field2Obscure)
            SecretTextField(
              controller: _controller2,
              decoration: poloFieldDecoration(context, widget.field2Label),
              onSubmitted: (_) => _save(),
            )
          else
            TextField(
              controller: _controller2,
              decoration: poloFieldDecoration(context, widget.field2Label),
              onSubmitted: (_) => _save(),
            ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}
