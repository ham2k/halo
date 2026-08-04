// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small dialogs shared between HomeView (the list, long-press to
// delete) and OperationView's Operation settings panel (same actions, reached via a
// list tile instead) — kept in one place so both stay in sync rather than
// carrying two copies of the same confirm-delete/edit-details prompt.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import '../i18n/strings.g.dart';
import '../main.dart';
import '../tools/operation_title.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A short month-and-day label, e.g. `Jan 3`.
String formatShortDate(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}';

/// The span an operation covers: `Jan 3` for a single day, `Jan 3 – 5` within
/// one month, `Jan 3 – Feb 1` across months, and empty when it has no logged
/// times at all (a brand-new operation) — the caller drops the line entirely
/// rather than printing a dangling dash.
String formatOperationDateRange(DateTime? from, DateTime? to) {
  final start = from ?? to;
  final end = to ?? from;
  if (start == null || end == null) return '';
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return formatShortDate(start);
  }
  if (start.year == end.year && start.month == end.month) {
    return '${formatShortDate(start)} – ${end.day}';
  }
  return '${formatShortDate(start)} – ${formatShortDate(end)}';
}

/// Confirms deleting [operation], naming it in the body rather than in the
/// title: the title says what's about to happen, the body says to what, so a
/// long operation name can't push the action itself out of view.
/// Soft-deletes on confirmation; returns whether the operation was deleted.
Future<bool> confirmDeleteOperation(
  BuildContext context,
  HaLoServices services,
  Operation operation,
) async {
  final confirmed = await showHaloDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final dateRange = formatOperationDateRange(
        operation.startAtMillisMin == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(operation.startAtMillisMin!, isUtc: true),
        operation.startAtMax,
      );
      final details = [
        context.t.operation.tabs.qsos(count: formatNumber(operation.qsoCount)),
        if (dateRange.isNotEmpty) dateRange,
      ].join(' • ');

      return HaloDialog(
        title: Text(context.t.dialogs.deleteOperationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same name the user just saw on the row or header they're
            // deleting from, not the raw (usually empty) title field.
            Text(
              '${operation.stationCall} ${displayTitleFor(context, operation)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Space.xs),
            Text(details, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.common.delete)),
        ],
      );
    },
  );
  if (confirmed == true) {
    await services.operations.softDelete(operation.uuid);
    services.track('operation_deleted');
  }
  return confirmed == true;
}

/// Edits station callsign/title on an existing operation. Returns the
/// updated Operation, or null if cancelled.
Future<Operation?> editOperationDetails(
  BuildContext context,
  OperationsRepository operations,
  Operation operation, {
  bool save = true,
}) async {
  final result = await showHaloDialog<(String, String, String, String)>(
    context: context,
    builder: (context) => _OperationDetailsDialog(
      stationCall: operation.stationCall,
      operatorCall: (operation.data['operatorCall'] as String?) ?? '',
      userTitle: operation.userTitle,
      notes: (operation.data['notes'] as String?) ?? '',
    ),
  );
  if (result == null || result.$1.trim().isEmpty) return null;

  final updated = Operation(
    uuid: operation.uuid,
    data: {
      ...operation.data,
      'stationCall': result.$1.trim().toUpperCase(),
      'operatorCall': result.$2.trim().toUpperCase(),
      'userTitle': result.$3.trim(),
      'notes': result.$4.trim(),
    },
    qsoCount: operation.qsoCount,
    startAtMillisMin: operation.startAtMillisMin,
    startAtMillisMax: operation.startAtMillisMax,
    localData: operation.localData,
  );
  if (save) {
    await operations.saveData(updated);
  }
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
              selectAllOnFocus: false,
              controller: _timeController,
              style: haloMonoStyle(context, fontSize: 15),
              decoration: poloFieldDecoration(context, context.t.loggingControls.timeUtc),
            ),
          ),
          const SizedBox(width: Space.md),
          SizedBox(
            width: 120,
            child: TextField(
              selectAllOnFocus: false,
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
        selectAllOnFocus: false,
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
            selectAllOnFocus: false,
            controller: _controller1,
            autofocus: true,
            textCapitalization: widget.field1Capitalization,
            decoration: poloFieldDecoration(context, widget.field1Label),
          ),
          const SizedBox(height: Space.md),
          if (widget.field2Obscure)
            SecretTextField(
              controller: _controller2,
              decoration: poloFieldDecoration(context, widget.field2Label),
              onSubmitted: (_) => _save(),
            )
          else
            TextField(
              selectAllOnFocus: false,
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

class _OperationDetailsDialog extends StatefulWidget {
  final String stationCall;
  final String operatorCall;
  final String userTitle;
  final String notes;

  const _OperationDetailsDialog({
    required this.stationCall,
    required this.operatorCall,
    required this.userTitle,
    required this.notes,
  });

  @override
  State<_OperationDetailsDialog> createState() => _OperationDetailsDialogState();
}

class _OperationDetailsDialogState extends State<_OperationDetailsDialog> {
  late final _stationCallController = TextEditingController(text: widget.stationCall);
  late final _operatorCallController = TextEditingController(text: widget.operatorCall);
  late final _titleController = TextEditingController(text: widget.userTitle);
  late final _notesController = TextEditingController(text: widget.notes);

  @override
  void dispose() {
    _stationCallController.dispose();
    _operatorCallController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop((
      _stationCallController.text.trim().toUpperCase(),
      _operatorCallController.text.trim().toUpperCase(),
      _titleController.text.trim(),
      _notesController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return HaloDialog(
      title: Text(context.t.dialogs.operationDetails),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              selectAllOnFocus: false,
              controller: _stationCallController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'RobotoMono'),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              decoration: poloFieldDecoration(context, context.t.dialogs.stationCallsign),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Space.lg),
            TextField(
              selectAllOnFocus: false,
              controller: _operatorCallController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'RobotoMono'),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              decoration: poloFieldDecoration(context, context.t.settings.operatorCall),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Space.xxl),
            TextField(
              selectAllOnFocus: false,
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: poloFieldDecoration(context, context.t.home.titleOptional),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Space.lg),
            TextField(
              selectAllOnFocus: false,
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: poloFieldDecoration(context, context.t.dialogs.notes),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.t.common.save),
        ),
      ],
    );
  }
}
