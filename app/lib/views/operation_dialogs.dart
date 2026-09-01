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
    // A Test Operation is purged (hard-deleted, QSOs included) rather than
    // soft-deleted — see `HaLoServices.purgeOperation`.
    if (operation.isTestOperation) {
      await services.purgeOperation(operation.uuid);
    } else {
      await services.operations.softDelete(operation.uuid);
    }
    services.track('operation_deleted');
  }
  return confirmed == true;
}

/// Confirms the PURGETESTS command: lists every Test Operation this device
/// holds and asks once for all of them, rather than one dialog per
/// operation — the point of the command is bulk cleanup. Purging itself is
/// the caller's job (`runCommandAction` in `main.dart`); this only asks.
Future<bool> confirmPurgeTestOperations(
  BuildContext context,
  List<Operation> testOperations, {
  int looseQsoCount = 0,
}) async {
  final confirmed = await showHaloDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return HaloDialog(
        title: Text(context.t.dialogs.purgeTestsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.dialogs.purgeTestsBody),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final operation in testOperations)
                      Text(
                        '${operation.stationCall} — ${displayTitleFor(context, operation)} '
                        '(${context.t.operation.tabs.qsos(count: formatNumber(operation.qsoCount))})',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
            // Named separately rather than folded into the list above: these
            // belong to no operation, so there is no row they could sit under,
            // and the operator is agreeing to delete them too.
            if (looseQsoCount > 0) ...[
              const SizedBox(height: Space.sm),
              Text(context.t.dialogs.purgeTestsLooseQsos(count: looseQsoCount)),
            ],
          ],
        ),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.dialogs.purgeTestsAction)),
        ],
      );
    },
  );
  return confirmed == true;
}

/// SYNCALL's gate. Distinct from the Sync panel's "Replace" dialog in what
/// it emphasizes: the backfill can only return what the server holds, so
/// the unsynced count — rows the server never received, which will NOT come
/// back — is called out explicitly in error color rather than folded into
/// the total.
Future<bool> confirmFullResyncDialog(BuildContext context, {required int qsoCount, required int unsyncedCount}) async {
  final confirmed = await showHaloDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return HaloDialog(
        title: Text(context.t.dialogs.syncAllTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.dialogs.syncAllBody(
              qsos: context.t.settings.syncPanel.countQsos(count: qsoCount, n: formatNumber(qsoCount)),
            )),
            if (unsyncedCount > 0) ...[
              const SizedBox(height: Space.sm),
              Text(
                context.t.dialogs.syncAllUnsynced(count: unsyncedCount, n: formatNumber(unsyncedCount)),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.dialogs.syncAllAction)),
        ],
      );
    },
  );
  return confirmed == true;
}

/// Confirms hard-deleting Test Operations that were purged on ANOTHER
/// device (`OperationsRepository.watchReceivedPurgesPending`) — distinct
/// from [confirmPurgeTestOperations], which is for ones purged right here.
/// Receiving a `purged` flag via sync only ever tombstones the operation
/// (`mergeFromSync`); it never removes rows on its own, precisely so an
/// operator gets a chance to say no — e.g. if `isTestOperation`'s /T
/// heuristic misclassified a real operation on the OTHER device, this is
/// the one remaining chance to notice before it's gone here too.
Future<bool> confirmReceivedTestOperationPurgesDialog(BuildContext context, List<Operation> pendingOperations) async {
  final confirmed = await showHaloDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return HaloDialog(
        title: Text(context.t.dialogs.receivedPurgesTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.dialogs.receivedPurgesBody),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final operation in pendingOperations)
                      Text(
                        '${operation.stationCall} — ${displayTitleFor(context, operation)} '
                        '(${context.t.operation.tabs.qsos(count: formatNumber(operation.qsoCount))})',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.dialogs.receivedPurgesAction)),
        ],
      );
    },
  );
  return confirmed == true;
}

/// Edits station callsign/title on an existing operation. Returns the
/// updated Operation, or null if cancelled.
Future<Operation?> editOperationDetails(
  BuildContext context,
  OperationsRepository operations,
  Operation operation, {
  bool save = true,
  bool developerMode = false,
}) async {
  final multiIdentifier = multiIdentifierFor(operation);
  final operatorCall = operatorCallFor(operation);
  final result = await showHaloDialog<(String, String, String, String, String)>(
    context: context,
    builder: (context) => _OperationDetailsDialog(
      stationCall: operation.stationCall,
      operatorCall: operatorCall,
      userTitle: operation.userTitle,
      notes: asQsonString(operation.data['notes']) ?? '',
      multiIdentifier: multiIdentifier,
      showMultiIdentifier: developerMode,
    ),
  );
  if (result == null || result.$1.trim().isEmpty) return null;

  final newMultiIdentifier = normalizedMultiIdentifier(result.$5);
  final newOperatorCall = result.$2.trim().toUpperCase();
  // The position is the only device-local field here, so it alone rides the
  // guarded `updateLocalData` write below; the operator is the operation's
  // shared data, stored in the slot of the position being SAVED.
  final localPatch = {
    if (newMultiIdentifier != multiIdentifier) multiIdentifierKey: newMultiIdentifier,
  };
  // Where the seat is unchanged, written whenever the operator EDITED the
  // field — clearing included, which has to reach the slot or the legacy
  // device-local value keeps showing through.
  //
  // A seat CHANGE is different: the field was showing the OLD seat's
  // operator, so nothing typed there is a statement about the new one. Only a
  // named operator moving into a seat that names nobody is written, and never
  // a blank — the field the operator emptied belongs to the seat they left,
  // and carrying that erasure across would wipe somebody else's operator off
  // every device.
  final seatOperatorCall = (asQsonString(operation.data[operatorCallKeyFor(newMultiIdentifier)]) ?? '').trim();
  final movedIntoEmptySeat = newOperatorCall.isNotEmpty && seatOperatorCall.isEmpty;
  final writeOperator =
      newMultiIdentifier != multiIdentifier ? movedIntoEmptySeat : newOperatorCall != operatorCall || movedIntoEmptySeat;
  final updated = Operation(
    uuid: operation.uuid,
    data: {
      ...operation.data,
      'stationCall': result.$1.trim().toUpperCase(),
      'userTitle': result.$3.trim(),
      'notes': result.$4.trim(),
      if (writeOperator) operatorCallKeyFor(newMultiIdentifier): newOperatorCall,
    },
    qsoCount: operation.qsoCount,
    startAtMillisMin: operation.startAtMillisMin,
    startAtMillisMax: operation.startAtMillisMax,
    localData: localPatch.isEmpty ? operation.localData : {...operation.localData, ...localPatch},
  );
  if (save) await operations.saveData(updated);
  // Written whatever `save` says: `save: false` stages the operation's SHARED
  // data in the sheet's draft until it closes, and the position is not that
  // — it is device-local, and the row already exists (the sheet only ever
  // opens on a created operation). Guarded on the change, because a
  // local_data write is a UI event: it rebuilds the Operation View.
  if (localPatch.isNotEmpty) {
    await operations.updateLocalData(operation.uuid, localPatch);
  }
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

  /// This device's number within a multi-station operation — several
  /// operators logging the same operation under one station call, each
  /// device self-spotting as `KI2D/OP1`, `KI2D/OP2` and so on (see
  /// `ExtensionService.sendSpot`). Empty means a plain single-station
  /// operation and no suffix at all.
  final String multiIdentifier;
  final bool showMultiIdentifier;

  const _OperationDetailsDialog({
    required this.stationCall,
    required this.operatorCall,
    required this.userTitle,
    required this.notes,
    required this.multiIdentifier,
    required this.showMultiIdentifier,
  });

  @override
  State<_OperationDetailsDialog> createState() => _OperationDetailsDialogState();
}

class _OperationDetailsDialogState extends State<_OperationDetailsDialog> {
  late final _stationCallController = TextEditingController(text: widget.stationCall);
  late final _operatorCallController = TextEditingController(text: widget.operatorCall);
  late final _titleController = TextEditingController(text: widget.userTitle);
  late final _notesController = TextEditingController(text: widget.notes);
  late final _multiIdentifierController = TextEditingController(text: widget.multiIdentifier);

  @override
  void dispose() {
    _stationCallController.dispose();
    _operatorCallController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _multiIdentifierController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop((
      _stationCallController.text.trim().toUpperCase(),
      _operatorCallController.text.trim().toUpperCase(),
      _titleController.text.trim(),
      _notesController.text.trim(),
      // Hidden means untouched: the controller still holds what came in, so
      // the caller's change check sees no change and writes nothing.
      _multiIdentifierController.text.trim(),
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
            if (widget.showMultiIdentifier) ...[
              const SizedBox(height: Space.lg),
              TextField(
                selectAllOnFocus: false,
                controller: _multiIdentifierController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'RobotoMono'),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  // Same ceiling the POSITION command enforces: a station has
                  // operators, not thousands of them.
                  LengthLimitingTextInputFormatter(2),
                ],
                // Label only, matching FormRenderer's treatment of a
                // `devMode: true` text field — the value itself stays in the
                // ordinary field colour.
                decoration: poloFieldDecoration(
                  context,
                  context.t.dialogs.multiStationIdentifier,
                  labelColor: HaLoColors.of(context).devMode,
                ),
                onSubmitted: (_) => _save(),
              ),
            ],
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
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.t.common.cancel),
      ),
      actions: [
        FilledButton(
          onPressed: _save,
          child: Text(context.t.common.save),
        ),
      ],
    );
  }
}
