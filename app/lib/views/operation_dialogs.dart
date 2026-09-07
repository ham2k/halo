// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small dialogs shared between HomeView (the list, long-press to
// delete) and OperationView's Operation settings panel (same actions, reached via a
// list tile instead) — kept in one place so both stay in sync rather than
// carrying two copies of the same confirm-delete/edit-details prompt.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import '../services/error_reporting_service.dart';
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

/// What one pass through the Operation Details dialog decided.
class _DetailsResult {
  final String stationCall;
  final String operatorCall;
  final String userTitle;
  final String notes;
  final String multiIdentifier;

  /// Contacts the operator asked to restamp with the new operator call.
  /// Empty unless they asked; carried out of the dialog rather than
  /// re-queried, so the write targets exactly the records the count on the
  /// checkbox was computed from.
  ///
  /// There is no station-call equivalent: the station call is what a SEGMENT
  /// states, so its contacts follow it with nothing to ask
  /// (`QsosRepository.restampSegmentStationCall`, run from `onLocalSave`).
  /// An operator hands the key over mid-segment, which is why that one is
  /// still a judgment call.
  final List<Qso> restampOperator;

  const _DetailsResult({
    required this.stationCall,
    required this.operatorCall,
    required this.userTitle,
    required this.notes,
    required this.multiIdentifier,
    this.restampOperator = const [],
  });
}

/// [qso] with [fields] merged into its `our` block. Values are never empty:
/// a restamp is only ever offered for a callsign that was typed, so there is
/// no "clear this field on every contact" to express here (see
/// `adviceForCallChange`, which stays quiet for an empty field — that is also
/// every intermediate state of typing one).
Qso _qsoWithOur(Qso qso, Map<String, String> fields) {
  final our = {...(asQsonMap(qso.data['our']) ?? const <String, dynamic>{}), ...fields};
  return Qso(uuid: qso.uuid, operationUuid: qso.operationUuid, data: {...qso.data, 'our': our});
}

/// Edits station callsign/title on an existing operation. Returns the
/// updated Operation, or null if cancelled — or if a restamp the operator
/// asked for could not be written, since nothing else is applied in that case.
///
/// Takes the whole [services] handle rather than the two repositories it
/// writes through: the dialog reads the operator's own callsign and their
/// settings, and a restamp that fails or comes up short has to reach the
/// status bar, which is the only place the operator would ever learn that the
/// callsign changed and the log did not.
Future<Operation?> editOperationDetails(
  BuildContext context,
  HaLoServices services,
  Operation operation, {
  bool save = true,
}) async {
  final operations = services.operations;
  final qsos = services.qsos;
  final settings = services.settings;
  final multiIdentifier = multiIdentifierFor(operation);
  final operatorCall = operatorCallFor(operation);
  // Read before the dialog: the notices below are posted after it closes, and
  // the status bar outlives the context they would otherwise come from.
  final t = context.t.dialogs.callChange;
  final result = await showHaloDialog<_DetailsResult>(
    context: context,
    builder: (context) => _OperationDetailsDialog(
      stationCall: operation.stationCall,
      operatorCall: operatorCall,
      userTitle: operation.userTitle,
      notes: asQsonString(operation.data['notes']) ?? '',
      multiIdentifier: multiIdentifier,
      showMultiIdentifier: settings.developerMode,
      ownCall: settings.activeProfile.operatorCall.trim().toUpperCase(),
      suggestDefaultOperator: settings.suggestDefaultOperator,
      operatorWasSet: operation.data.containsKey(operatorCallKeyFor(multiIdentifier)) ||
          operation.localData.containsKey(operatorCallKey),
      // Read once, when the dialog opens. A contact logged while it sits open
      // is not in the count and is not restamped — the alternative is a live
      // query behind a checkbox the operator already read a number off.
      loadContacts: () async =>
          (await qsos.forOperation(operation.uuid)).where((qso) => qso.isRealContact).toList(),
    ),
  );
  if (result == null || result.stationCall.trim().isEmpty) return null;

  final newMultiIdentifier = normalizedMultiIdentifier(result.multiIdentifier);
  final newOperatorCall = result.operatorCall.trim().toUpperCase();
  final newStationCall = result.stationCall.trim().toUpperCase();
  // The position is the only device-local field here, so it alone rides the
  // guarded `updateLocalData` write below; the operator is the operation's
  // shared data, stored in the slot of the position being SAVED.
  final localPatch = {
    if (newMultiIdentifier != multiIdentifier) multiIdentifierKey: newMultiIdentifier,
  };
  // The operator FOLLOWS the position: changing the seat number moves whoever
  // the field names into the new seat, because the person at this key is the
  // same person who was at it a moment ago — they have said which seat they
  // are now in, not who somebody else is. It overwrites an operator the new
  // seat already named, and that is the point: that name came from a device
  // that is not the one sitting here.
  //
  // A blank field carries nothing across. There is no operator to move, and
  // writing the empty string would erase the new seat's name on every device
  // on the strength of a field the operator never filled in.
  //
  // With the seat unchanged, the field is written whenever it was EDITED —
  // clearing included, which has to reach the slot or the legacy device-local
  // value keeps showing through — and when a named operator lands in a seat
  // that names nobody, which is what promotes that legacy value into the
  // operation's own data.
  final seatOperatorCall = (asQsonString(operation.data[operatorCallKeyFor(newMultiIdentifier)]) ?? '').trim();
  final writeOperator = newMultiIdentifier != multiIdentifier
      ? newOperatorCall.isNotEmpty
      : newOperatorCall != operatorCall || (newOperatorCall.isNotEmpty && seatOperatorCall.isEmpty);
  final updated = Operation(
    uuid: operation.uuid,
    data: {
      ...operation.data,
      'stationCall': newStationCall,
      'userTitle': result.userTitle.trim(),
      'notes': result.notes.trim(),
      if (writeOperator) operatorCallKeyFor(newMultiIdentifier): newOperatorCall,
    },
    qsoCount: operation.qsoCount,
    startAtMillisMin: operation.startAtMillisMin,
    startAtMillisMax: operation.startAtMillisMax,
    localData: localPatch.isEmpty ? operation.localData : {...operation.localData, ...localPatch},
  );
  final restamped = <String, Map<String, String>>{
    for (final qso in result.restampOperator) qso.uuid: {'operatorCall': newOperatorCall},
  };
  // BEFORE the operation is written, so a batch that throws leaves the whole
  // edit undone rather than a renamed operation over a log that still says
  // the old call — a half-applied rename the reopened dialog would describe
  // as though the operator had never asked.
  //
  // The `save: false` path stages the operation's shared data in the setup
  // sheet's draft, which always commits when the sheet closes; a discard path
  // added there would have to reach this write too.
  if (restamped.isNotEmpty) {
    final bases = {for (final qso in result.restampOperator) qso.uuid: qso};
    final int written;
    try {
      // ONLY the write is guarded, as `adif_import_flow.dart` guards its own:
      // everything after it is reporting, and reporting must never be able to
      // retract a committed fact.
      written = await qsos.writeBatch(
        operationUuid: operation.uuid,
        updates: [for (final entry in restamped.entries) _qsoWithOur(bases[entry.key]!, entry.value)],
        // Every target was read when the dialog opened; a sync pull or a peer
        // merge landing while it sat open must survive everywhere the restamp
        // didn't touch.
        updateBases: bases,
      );
    } catch (e, stack) {
      // Named, because the generic "Something went wrong" cannot say which
      // half landed — and here neither half has: the operation is written
      // below, and returning now leaves the whole edit undone.
      services.statusBar.showNotice(
        key: 'operationDetails:restampFailed',
        text: t.restampFailed(error: '$e'),
      );
      ErrorReportingService.report(e, stack, context: 'operationDetails:restamp');
      return null;
    }
    // The repository counts rows actually affected, so a contact deleted
    // while the dialog sat open shows up here. Agreeing to "40 contacts" and
    // having 39 change is exactly what the honest count exists to prevent.
    if (written != restamped.length) {
      services.statusBar.showNotice(
        key: 'operationDetails:restampShortfall',
        text: t.restampShortfall(written: written, planned: restamped.length),
      );
    }
  }
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

  /// The operator's own callsign, and whether they want it offered as the
  /// operator of an operation run under a different station call.
  final String ownCall;
  final bool suggestDefaultOperator;

  /// Whether this operation has ever named an operator — presence of the
  /// slot, not a non-empty value, exactly as `operatorCallFor` reads it. An
  /// operator who cleared the field meant it, and a suggestion that refills
  /// the next time the dialog opens undoes their edit on the following Save.
  final bool operatorWasSet;

  /// The operation's real contacts — what the dialog reads to say which calls
  /// are already in the log, and what it restamps when asked.
  final Future<List<Qso>> Function() loadContacts;

  const _OperationDetailsDialog({
    required this.stationCall,
    required this.operatorCall,
    required this.userTitle,
    required this.notes,
    required this.multiIdentifier,
    required this.showMultiIdentifier,
    required this.ownCall,
    required this.suggestDefaultOperator,
    required this.operatorWasSet,
    required this.loadContacts,
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

  /// Null until the contacts have been read. The dialog opens without them
  /// and grows the advice in when they arrive, rather than making the
  /// operator wait on a query to see the fields they came for.
  List<Qso>? _contacts;

  /// The read failed. Distinct from "not loaded yet", because the two look
  /// identical on screen and one of them is a lie: with no contacts read, the
  /// dialog cannot say what the log holds, and staying silent is exactly the
  /// trap this feature exists to close.
  bool _contactsFailed = false;

  bool _restampOperator = false;

  /// The operator field's value is the operator's own decision, and the
  /// suggestion must not touch it again. True from the start for an operation
  /// that has already named one (including naming nobody).
  late bool _operatorSettled = widget.operatorWasSet;

  @override
  void initState() {
    super.initState();
    _stationCallController.addListener(_onStationCallChanged);
    _operatorCallController.addListener(_onOperatorCallChanged);
    _multiIdentifierController.addListener(_onMultiIdentifierChanged);
    _suggestOperator();
    unawaited(_loadContacts());
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await widget.loadContacts();
      if (!mounted) return;
      setState(() => _contacts = contacts);
    } catch (_) {
      // Marked, then rethrown: the operator is told the dialog cannot speak
      // for the log, and the failure still reaches ErrorPolicy through the
      // zone rather than dying here.
      if (mounted) setState(() => _contactsFailed = true);
      rethrow;
    }
  }

  @override
  void dispose() {
    _stationCallController.dispose();
    _operatorCallController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _multiIdentifierController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // A restamp the operator ticked is an agreement to a COUNT, for one call, in
  // one scope. A tick is dropped when the thing it named changes — the call
  // in its own field, or the position that decides whose contacts are in
  // scope. It is NOT dropped here for the operator: widening the station call
  // takes the operator offer off the screen without touching what it named,
  // and `_restampTargets` refuses to act on a tick whose offer is no longer
  // standing, so narrowing back restores the same agreement rather than
  // making the operator re-tick a box they never untucked.
  void _onStationCallChanged() {
    _suggestOperator();
    _refresh();
  }

  void _onOperatorCallChanged() {
    // An emptied field is an answer, not an absence: from here on the
    // suggestion stays out, or editing the station call would put the name
    // back that the operator just took out.
    if (_operatorCallController.text.trim().isEmpty) _operatorSettled = true;
    _restampOperator = false;
    _refresh();
  }

  void _onMultiIdentifierChanged() {
    _restampOperator = false;
    _refresh();
  }

  /// The station callsigns as typed — one operation can be run under several
  /// (`Operation.stationCalls`), and every rule below turns on how many.
  List<String> get _stationCalls =>
      splitStationCalls(_stationCallController.text).where((call) => call.isNotEmpty).toList();

  /// With several station callsigns there is no one operator to name: each
  /// contact carries its own, whichever call it was made under.
  bool get _operatorApplies => _stationCalls.length < 2;

  /// Fill the Operator field with the operator's own callsign when the station
  /// is somebody else's, and take it back out when it stops meaning anything.
  ///
  /// Only ever touches a field that is empty or holds exactly the operator's
  /// own call — a name they typed is theirs, and no rule here may overwrite it.
  void _suggestOperator() {
    if (!widget.suggestDefaultOperator || widget.ownCall.isEmpty || _operatorSettled) return;
    final calls = _stationCalls;
    final redundant = calls.length > 1 || calls.contains(widget.ownCall);
    final current = _operatorCallController.text.trim().toUpperCase();
    if (redundant) {
      if (current == widget.ownCall) _operatorCallController.text = '';
    } else if (current.isEmpty && calls.isNotEmpty) {
      _operatorCallController.text = widget.ownCall;
    }
  }

  /// The contacts an operator restamp would rewrite. With operating positions
  /// in play the operation has an operator PER SEAT, and this dialog speaks
  /// for one seat only — restamping the whole log would relabel contacts made
  /// by everyone else at the station.
  List<Qso> get _operatorScope {
    final position = normalizedMultiIdentifier(_multiIdentifierController.text);
    return [
      for (final qso in _contacts ?? const <Qso>[])
        if (normalizedMultiIdentifier(qso.ourMultiIdentifier) == position) qso,
    ];
  }

  CallChangeAdvice get _operatorAdvice {
    if (_contacts == null || !_operatorApplies) return const CallChangeAdvice(CallChange.quiet);
    return adviceForCallChange(
      calls: _operatorScope.map((qso) => qso.ourOperatorCall),
      typed: _operatorCallController.text,
    );
  }

  /// Every typed callsign that doesn't parse — a warning, never a refusal: a
  /// special-event or portable form this regex doesn't know is still a
  /// callsign somebody worked, and must stay loggable.
  List<String> get _invalidStationCalls =>
      [for (final call in _stationCalls) if (!looksLikeCallsign(call)) call];

  /// The contacts a standing, ticked offer would rewrite — empty whenever the
  /// checkbox that set [ticked] is not on screen for the CURRENT field values.
  ///
  /// The tick alone is not authority to write. The offer names a call and a
  /// count, and both can go stale while the tick survives: type a second
  /// station call and the operator offer disappears from the dialog entirely,
  /// leaving a tick that would otherwise rewrite every contact in a scope
  /// nothing on screen still describes.
  List<Qso> _restampTargets({
    required bool ticked,
    required CallChangeAdvice advice,
    required List<Qso> scope,
    required String typed,
    required String Function(Qso) callOf,
  }) {
    if (!ticked || advice.change != CallChange.single) return const [];
    return [
      for (final qso in scope)
        if (callNeedsChange(callOf(qso), typed)) qso,
    ];
  }

  void _save() {
    if (_stationCalls.isEmpty) return;
    final stationCall = _stationCallController.text.trim().toUpperCase();
    // Cleared, not merely hidden, when several station calls are in play: the
    // dialog says each contact records its own operator, and a value left in
    // the operation's data would go on stamping every new contact behind that
    // statement, with no enabled field to take it out again (app-polo's
    // `handleChangeStation` clears it for the same reason).
    final operatorCall = _operatorApplies ? _operatorCallController.text.trim().toUpperCase() : '';
    Navigator.of(context).pop(_DetailsResult(
      stationCall: stationCall,
      operatorCall: operatorCall,
      userTitle: _titleController.text.trim(),
      notes: _notesController.text.trim(),
      // Hidden means untouched: the controller still holds what came in, so
      // the caller's change check sees no change and writes nothing.
      multiIdentifier: _multiIdentifierController.text.trim(),
      restampOperator: _restampTargets(
        ticked: _restampOperator,
        advice: _operatorAdvice,
        scope: _operatorScope,
        typed: operatorCall,
        callOf: (qso) => qso.ourOperatorCall,
      ),
    ));
  }

  List<String> get _invalidOperatorCall {
    final call = _operatorCallController.text.trim().toUpperCase();
    return call.isEmpty || looksLikeCallsign(call) ? const [] : [call];
  }

  String? _invalidCallsignsText(List<String> calls) {
    if (calls.isEmpty) return null;
    final t = context.t.dialogs.callChange;
    return calls.length == 1
        ? t.invalidCallsign(call: calls.single)
        : t.invalidCallsigns(calls: calls.join(', '));
  }

  /// A line of explanation under a field, in the dialog's quieter voice.
  Widget _adviceNote(String text) => Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  /// The message and, where there is something to offer, the restamp
  /// checkbox — see `CallChangeAdvice`. Empty for [CallChange.quiet] and
  /// [CallChange.agrees], which are the ordinary cases and must add nothing
  /// to a dialog the operator opened to change a title.
  List<Widget> _adviceFor({
    required CallChangeAdvice advice,
    required String typed,
    required String Function(String previous, String typed) soFar,
    required String Function(String typed) noneSoFar,
    required String Function(String calls, String typed) several,
    required String Function(int count, String typed) restamp,
    required bool checked,
    required void Function(bool value) onChanged,
  }) {
    switch (advice.change) {
      case CallChange.quiet:
      case CallChange.agrees:
        return const [];
      case CallChange.several:
        return [_adviceNote(several(advice.previous.join(', '), typed))];
      case CallChange.single:
        return [
          _adviceNote(advice.previous.isEmpty ? noneSoFar(typed) : soFar(advice.previous.single, typed)),
          Row(
            children: [
              Checkbox(value: checked, onChanged: (value) => onChanged(value == true)),
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(!checked),
                  child: Text(restamp(advice.count, typed), style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ],
          ),
        ];
    }
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
              decoration: poloFieldDecoration(
                context,
                context.t.dialogs.stationCallsign,
                errorText: _invalidCallsignsText(_invalidStationCalls),
              ),
              onSubmitted: (_) => _save(),
            ),
            // No station-call offer: the call is what a SEGMENT states, so
            // its contacts follow it with nothing to ask
            // (`QsosRepository.restampSegmentStationCall`).
            if (_contactsFailed) _adviceNote(context.t.dialogs.callChange.contactsUnreadable),
            const SizedBox(height: Space.lg),
            TextField(
              selectAllOnFocus: false,
              controller: _operatorCallController,
              enabled: _operatorApplies,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: 'RobotoMono'),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                ),
              ],
              decoration: poloFieldDecoration(
                context,
                context.t.settings.operatorCall,
                // The station calls themselves, so a disabled field still says
                // who the contacts will name — each its own station call.
                hintText: _operatorApplies ? null : _stationCalls.join(', '),
                errorText: _operatorApplies ? _invalidCallsignsText(_invalidOperatorCall) : null,
              ),
              onSubmitted: (_) => _save(),
            ),
            if (!_operatorApplies) _adviceNote(context.t.dialogs.callChange.operatorSeveralStations),
            ..._adviceFor(
              advice: _operatorAdvice,
              typed: _operatorCallController.text.trim().toUpperCase(),
              soFar: (previous, typed) => context.t.dialogs.callChange.operatorSoFar(previous: previous, typed: typed),
              noneSoFar: (typed) => context.t.dialogs.callChange.operatorNoneSoFar(typed: typed),
              several: (calls, typed) => context.t.dialogs.callChange.operatorSeveral(calls: calls, typed: typed),
              restamp: (count, typed) => context.t.dialogs.callChange.operatorRestamp(count: count, typed: typed),
              checked: _restampOperator,
              onChanged: (value) => setState(() => _restampOperator = value),
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
          // An operation with no station callsign is not saveable, and the
          // caller drops the whole edit when one arrives — title, notes and
          // any ticked restamp with it. Refusing here says so, instead of
          // making Save behave like Cancel. `_save` refuses too, because
          // every field submits on Enter and would otherwise walk straight
          // past this button.
          onPressed: _stationCalls.isEmpty ? null : _save,
          child: Text(context.t.common.save),
        ),
      ],
    );
  }
}
