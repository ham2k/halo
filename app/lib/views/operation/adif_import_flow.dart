// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking an ADIF file and importing it into an operation.
//
// Two ways in — the Operation Options menu and a file dropped on the operation
// window — and one path out, so the summary, the merge rules and the error
// handling cannot drift apart between them.
//
// The file is read as BYTES, never as a decoded string: ADIF declares its
// field lengths in bytes, and a string that has already been decoded has lost
// them (packages/halo_core/lib/src/adif/adif_parser.dart).

import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, visibleForTesting, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/adif_import_plan.dart';
import '../../services/adif_import_service.dart';
import '../../services/error_reporting_service.dart';
import '../../services/extensions/extension_service.dart' show ExtensionInfo;
import '../../services/hook_payloads.dart';
import '../../services/status_bar_service.dart';
import '../../tools/operation_title.dart';
import '../../services/halo_services.dart';

/// Extensions ADIF files are written with. `.adi` is the format this parses;
/// `.adif` appears in the wild for the same thing.
const _adifExtensions = ['adi', 'adif'];

bool looksLikeAdif(String filename) {
  final lower = filename.toLowerCase();
  return _adifExtensions.any((ext) => lower.endsWith('.$ext'));
}

/// One import at a time, across every entry point — this file's own two AND
/// `logs_view.dart`'s, which shares this same flag rather than keeping its
/// own.
///
/// The plan is computed from a snapshot of the log taken before the operator
/// confirms. A second import started while that dialog is open plans against
/// the same pre-write log, and whichever writes second overwrites the first's
/// merges with data computed from a log that no longer exists. Refusing is
/// right rather than queueing: a queued import would still be planning stale.
/// The Logs destination's own import plans across EVERY operation, so a
/// second import racing it is the same corruption with a wider blast radius,
/// not a smaller one.
bool adifImportInFlight = false;

/// The most records one file may bring into an operation.
///
/// Checked on the file's own record count, before the extension hooks, the
/// plan or the write see any of it: those are the passes a whole-log file
/// overwhelms, so a cap applied after them protects nothing. A whole log
/// belongs in the Logs destination's import, which this does not limit.
const maxOperationImportRecords = 1000;

/// The filter handed to the picker.
///
/// Android greys out anything outside the requested MIME types, and `.adi` /
/// `.adif` map to no MIME type at all (`file_selector_android` drops
/// extensions `MimeTypeMap` cannot convert), so a filtered group there offers
/// the operator a browser with nothing selectable in it. An empty group asks
/// for `*/*`; what the operator picks is filtered by [looksLikeAdif] and
/// [bytesLookLikeAdif] instead.
@visibleForTesting
List<XTypeGroup> adifTypeGroups() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return const [];
  return [
    XTypeGroup(
      label: 'ADIF',
      extensions: _adifExtensions,
      // iOS filters by UTI and THROWS for a group carrying none
      // (`file_selector_ios`), so extensions alone breaks the only route
      // mobile has to this feature. `public.data` because ADIF has no UTI
      // of its own; `looksLikeAdif` still does the real filtering.
      uniformTypeIdentifiers: const ['public.data'],
      mimeTypes: const ['text/plain'],
    ),
  ];
}

/// Enough of a file to find an ADIF marker in. A header is free text of any
/// length, but one that runs past this is not something a logger writes.
const _sniffBytes = 64 * 1024;

/// A field tag (`<CALL:5`) or a segment marker (`<EOH>`, `<EOR>`) — the two
/// shapes every ADIF file starts with, and neither of them something a text
/// file the operator picked by mistake carries in its first bytes.
final _adifMarker = RegExp(r'<(eoh>|eor>|[a-z_]+:\d)', caseSensitive: false);

/// Whether [head] — the first bytes of a file — reads as ADIF.
///
/// The NAME cannot answer this on Android: the picker hands back a COPY of
/// the chosen file whose extension the platform rewrote from the provider's
/// MIME type (`file_selector_android`'s `FileUtils.getFileExtension`), and
/// `.adi` has no MIME type of its own — so an ADIF file arrives named `.bin`
/// or `.txt` and [looksLikeAdif] alone would refuse what the operator picked
/// correctly, naming a file that exists nowhere on their device.
///
/// Latin-1 because this is a byte scan: any decoding that can throw would
/// turn an unusual encoding into a refusal, and the markers are ASCII.
bool bytesLookLikeAdif(Uint8List head) => _adifMarker.hasMatch(latin1.decode(head, allowInvalid: true));

Future<Uint8List> _readHead(XFile file) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, _sniffBytes)) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Opens the file picker, then runs [importAdifFile] on what was chosen.
Future<void> pickAndImportAdif(BuildContext context, {required HaLoServices services, required Operation operation}) async {
  final XFile? file;
  try {
    file = await openFile(acceptedTypeGroups: adifTypeGroups());
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'adifImport:picker');
    if (context.mounted) {
      await _showNotice(context, context.t.adifImport.failed(filename: '', error: e.toString()));
    }
    return;
  }
  if (file == null || !context.mounted) return;
  await importAdifFile(context, services: services, operation: operation, file: file);
}

/// Reads [file], plans the import, shows the operator what would happen, and
/// writes only if they agree.
///
/// Nothing is written before the confirmation: merging rewrites contacts that
/// were already correct, which is materially harder to undo than an append.
Future<void> importAdifFile(BuildContext context, {required HaLoServices services, required Operation operation, required XFile file}) async {
  final t = context.t.adifImport;
  final statusBar = services.statusBar;
  final filename = file.name;

  if (adifImportInFlight) {
    await _showNotice(context, t.busy);
    return;
  }

  if (!looksLikeAdif(filename)) {
    // The name is only the first answer, and on Android it is a rewritten one
    // ([bytesLookLikeAdif]), so the bytes get the last word before a refusal.
    final Uint8List head;
    try {
      head = await _readHead(file);
    } catch (e, stack) {
      _reportFailure(services, 'adifImport:sniff', e, stack, t.failed(filename: filename, error: '$e'));
      if (context.mounted) {
        await _showNotice(context, t.failed(filename: filename, error: e.toString()));
      }
      return;
    }
    if (!context.mounted) return;
    if (!bytesLookLikeAdif(head)) {
      // A dialog, not the status bar. Dropping the wrong file is a mistake
      // made in the moment and the operator is watching the window, not the
      // status line — a refusal they can miss reads as the drop having done
      // nothing.
      await _showNotice(context, t.notAdif(filename: filename));
      return;
    }
  }

  adifImportInFlight = true;
  try {
    statusBar.setMessage(
      key: 'adifImport:status',
      text: t.reading(filename: filename),
    );
    final Uint8List bytes;
    final int recordCount;
    try {
      bytes = await file.readAsBytes();
      recordCount = countAdifRecords(bytes, upTo: maxOperationImportRecords + 1);
    } catch (e, stack) {
      _reportFailure(services, 'adifImport:read', e, stack, t.failed(filename: filename, error: '$e'));
      if (context.mounted) {
        await _showNotice(context, t.failed(filename: filename, error: e.toString()));
      }
      return;
    }
    if (recordCount > maxOperationImportRecords) {
      final message = t.tooMany(filename: filename, limit: formatNumber(maxOperationImportRecords));
      statusBar.clear('adifImport:status');
      // The files this refuses are the slowest to read, so the pane may be
      // gone by now — and then the notice is the only trace the drop left.
      if (context.mounted) {
        await _showNotice(context, message);
      } else {
        statusBar.showNotice(key: 'adifImport:tooMany', text: message);
      }
      return;
    }

    final AdifImportPlan plan;
    try {
      plan = await _planFor(services, operation, bytes, filename);
    } catch (e, stack) {
      _reportFailure(services, 'adifImport:plan', e, stack, t.failed(filename: filename, error: '$e'));
      if (context.mounted) {
        await _showNotice(context, t.failed(filename: filename, error: e.toString()));
      }
      return;
    }
    statusBar.clear('adifImport:status');
    if (!context.mounted) return;

    final decision = await _showSummary(context, plan, failedProgramNames(services.extensions.availableExtensions, plan.failedHooks));
    if (decision == null) return;

    statusBar.setProgress(
      key: 'adifImport:status',
      text: t.importing(filename: filename),
    );
    final int written;
    try {
      // ONLY the write is guarded. Everything after it is reporting, and
      // reporting must not be able to retract a committed fact — a telemetry
      // throw once turned a successful 3,000-contact import into "could not
      // import", whose rational answer is to import again.
      written = await services.qsos.writeBatch(operationUuid: operation.uuid, inserts: plan.additions, updates: plan.merges, updateBases: plan.mergeBases);
    } catch (e, stack) {
      _reportFailure(services, 'adifImport:write', e, stack, t.failed(filename: filename, error: '$e'));
      if (context.mounted) {
        await _showNotice(context, t.failed(filename: filename, error: e.toString()));
      }
      return;
    }

    // Guarded for the same reason the write is, from the other direction: the
    // contacts are committed, so a throw here must not look like a failed
    // import — but it must also not leave the indeterminate "Importing…"
    // progress item running forever with no result.
    try {
      if (decision.addActivation && plan.hoistedOperationRefs.isNotEmpty) {
        await addActivationToOperation(services, operation, plan.hoistedOperationRefs);
      }
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'adifImport:activation');
    }

    statusBar.setMessage(
      key: 'adifImport:status',
      text: t.imported(count: written, filename: filename, formatted: formatNumber(written)),
      dismissAfter: StatusBarService.completedDismissDelay,
    );
    // The repository counts rows actually affected, so a merge target deleted
    // while the dialog was open shows up here. Approving "70 new, 4 merging"
    // and being told "72 imported" with no explanation is the one thing the
    // honest count exists to prevent.
    if (written != plan.importCount) {
      statusBar.showNotice(
        key: 'adifImport:shortfall',
        text: t.shortfall(written: written, planned: plan.importCount),
      );
    }
    try {
      services.track('adif_imported', {'count': written, 'merged': plan.merges.length, 'planned': plan.importCount});
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'adifImport:telemetry');
    }
  } finally {
    adifImportInFlight = false;
  }
}

/// A failure the operator will see, plus the record they will not.
///
/// The dialog needs a live `BuildContext` and a long import can outlive one —
/// a failed write with the pane already closed would otherwise leave nothing
/// at all, and the operator's last sight was "Importing…". The notice persists
/// into history; the report carries the stack that a copied error string does
/// not.
void _reportFailure(HaLoServices services, String where, Object error, StackTrace stack, String message) {
  services.statusBar.clear('adifImport:status');
  services.statusBar.showNotice(key: 'adifImport:failed', text: message);
  ErrorReportingService.report(error, stack, context: where);
}

/// Adds the activation the file recorded to the operation, keeping whatever it
/// already carried.
///
/// Refs are DECORATED first, the same as every other path that adds one
/// (`activities_view.dart`): the hook hands back a bare `{type, ref}`, and
/// without the park's name and location the operation's activity row shows a
/// code where the same park added by hand shows "POTA K-0001: Acadia NP".
///
/// The operation is re-read rather than reusing the copy captured before the
/// dialog: `saveData` writes the whole `data` column, so a stale snapshot
/// would silently revert a sync round or an edit in another pane that landed
/// while the operator was deciding.
@visibleForTesting
Future<void> addActivationToOperation(HaLoServices services, Operation operation, List<Map<String, dynamic>> refs) async {
  final current = await services.operations.get(operation.uuid);
  if (current == null) return;

  final existing = current.refs;
  final have = {for (final ref in existing) '${ref['type']}|${ref['ref']}'};
  final added = await services.extensions.decorateRefs([
    for (final ref in refs)
      if (!have.contains('${ref['type']}|${ref['ref']}')) ref,
  ]);
  if (added.isEmpty) return;

  final withRefs = Operation(
    uuid: current.uuid,
    data: {
      ...current.data,
      'refs': [...existing, ...added],
    },
    qsoCount: current.qsoCount,
    startAtMillisMin: current.startAtMillisMin,
    startAtMillisMax: current.startAtMillisMax,
    localData: current.localData,
  );

  // The generated title is derived from the refs, so adding one without
  // rebuilding it leaves an operation activating a park and showing no sign of
  // it until someone opens the activities sheet and saves. Same degrade-quietly
  // rule as `saveAndClose`: a null means the runtime is not up, and the
  // title already on the operation is better than none.
  final fragments = await services.operationTitles.suggestFragments(withRefs);
  await services.operations.saveData(
    fragments == null
        ? withRefs
        : Operation(
            uuid: withRefs.uuid,
            data: {...withRefs.data, 'title': buildGeneratedTitle(t, fragments)},
            qsoCount: withRefs.qsoCount,
            startAtMillisMin: withRefs.startAtMillisMin,
            startAtMillisMax: withRefs.startAtMillisMax,
            localData: withRefs.localData,
          ),
  );
}

/// A failure the operator caused in the moment — a wrong file, an unreadable
/// one, a write that did not land. They are looking at the window they just
/// acted on, not at the status line, so a refusal that only appears down
/// there reads as the action having quietly done nothing.
///
/// Success stays in the status bar on purpose: "imported 72 contacts" is a
/// result to notice, not a question to answer.
Future<void> _showNotice(BuildContext context, String message) => showHaloDialog<void>(
  context: context,
  builder: (dialogContext) => HaloDialog(
    title: Text(context.t.adifImport.title),
    content: Text(message),
    cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.done)),
  ),
);

/// The failed hooks as the operator names them — 'POTA', not 'pota'.
///
/// The `'*'` sentinel is dropped rather than translated: it means no hook ran
/// at all, which is a different sentence and is reported separately. An
/// unrecognised key falls back to itself, since a key the registry has never
/// heard of still tells the operator more than nothing does.
///
/// Sorted, because the set arrives in the order the hooks happened to reply
/// across batches and `invokeHookAll` guarantees none. (Dart's default `Set`
/// is insertion-ordered, so the instability is the replies, not the container.)
///
/// Shared with `logs_view.dart`'s own import summary, not just this file's —
/// both surface the same `AdifImportOutcome.failedHooks` set.
List<String> failedProgramNames(Iterable<ExtensionInfo> available, Set<String> failedHooks) {
  final byKey = {for (final info in available) info.key: info.effectiveShortName};
  return [
    for (final key in failedHooks)
      if (key != '*') byKey[key] ?? key,
  ]..sort();
}

Future<AdifImportPlan> _planFor(HaLoServices services, Operation operation, Uint8List bytes, String filename) async {
  final stacking = await _stackingRefTypes(services, operation);
  final log = parseAdifLogBytes(bytes);
  final outcome = await AdifImportService(services.extensions.host).applyHooks(log.qsos);

  return planAdifImport(
    filename: filename,
    records: outcome.records,
    // Live contacts only. A merge into a soft-deleted row would count as
    // written and stay invisible.
    existing: await services.qsos.forOperation(operation.uuid),
    multiRefTypes: stacking.types,
    stackingTypesUnknown: stacking.unknown,
    unusable: log.errors,
    failedHooks: outcome.failedHooks,
    recordsUnreachable: outcome.recordsUnreachable,
    recordsWithFailedHooks: outcome.recordsWithFailedHooks,
    // Contacts imported into an operation belong to the station that operation
    // runs as, whatever the file recorded — otherwise the operation's own
    // export would claim a station it never was. An operation with no station
    // call yet leaves the file's own calls alone.
    //
    // `stationCall` is ONE comma-separated field; `stationCalls` is what splits
    // it. Passing it raw would write "N0DEV, W1AW" as a callsign onto every
    // imported contact, and flag every record in the file as foreign because
    // no real call equals the joined string. A multi-operator operation has no
    // single answer to "whose contact is this", so impose nothing.
    stationCall: operation.stationCalls.length == 1 && operation.stationCalls.first.isNotEmpty ? operation.stationCalls.first : null,
  );
}

/// The ref types the extensions declare as stacking.
///
/// From **loggingControls**, the per-QSO set. `operationControls` declares the
/// ACTIVATION type, and this governs the references that stay on a contact —
/// reading the operation set yields only activation types, which
/// `hoistOperationRefs` has already lifted off before any merge sees them. The
/// set would be empty exactly where it matters, and merging a park-to-park
/// contact would drop one of its parks.
Future<({Set<String> types, bool unknown})> _stackingRefTypes(HaLoServices services, Operation operation) async {
  final result = await services.extensions.loggingControls(operationPayloadFor(operation));
  // A fan-out that failed yields the same empty-ish set as an operation whose
  // activities simply don't stack, and only one of them costs the operator a
  // reference. The caller has to be able to tell them apart.
  return (
    unknown: result.loadFailed,
    types: {
      for (final control in result.controls)
        // `refType` lives on the control's `input`, not at the top level —
        // reading it from the wrong place yields an empty set and merges that
        // quietly refuse to stack.
        if (control['allowsMultiple'] == true && (control['input'] as Map?)?['refType'] is String) (control['input'] as Map)['refType'] as String,
    },
  );
}

/// Accepts a log file dropped anywhere on its [child].
///
/// `desktop_drop` is a no-op on iOS and Android — there is no file-drag
/// gesture there — so this is inert on mobile rather than conditional, and
/// those platforms reach the same import through the Options menu.
class AdifDropTarget extends StatefulWidget {
  final Widget child;
  final Future<void> Function(XFile file) onFile;

  const AdifDropTarget({super.key, required this.child, required this.onFile});

  @override
  State<AdifDropTarget> createState() => _AdifDropTargetState();
}

class _AdifDropTargetState extends State<AdifDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      // `desktop_drop` dispatches to EVERY listener whose box contains the
      // point — there is no topmost-wins hit test — so a target under a pushed
      // route still fires. Without this a drop while the summary dialog is
      // open starts a second import, and with two operation views open one
      // file imports into both.
      enable: ModalRoute.of(context)?.isCurrent ?? true,
      // Highlights for any drag, not only an ADIF one: what a drag actually
      // carries is not reliably known until it lands, so promising nothing
      // until then would mean no feedback at all on the common case.
      onDragEntered: (details) => setState(() => _hovering = true),
      onDragExited: (details) => setState(() => _hovering = false),
      onDragDone: (details) async {
        setState(() => _hovering = false);
        // Order decides precedence when two records merge, and a multi-file
        // drop has no meaningful order — so refuse rather than pick one and
        // drop the rest on the floor without saying so.
        if (details.files.length > 1) {
          if (mounted) await _showNotice(context, context.t.adifImport.oneFileOnly);
          return;
        }
        final file = details.files.firstOrNull;
        if (file != null) await widget.onFile(file);
      },
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Text(context.t.adifImport.dropHint, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the operator agreed to. Null when they cancelled.
class _ImportDecision {
  final bool addActivation;
  const _ImportDecision({required this.addActivation});
}

Future<_ImportDecision?> _showSummary(BuildContext context, AdifImportPlan plan, List<String> failedPrograms) {
  return showHaloDialog<_ImportDecision>(
    context: context,
    builder: (dialogContext) => _SummaryContent(plan: plan, failedPrograms: failedPrograms),
  );
}

class _SummaryContent extends StatefulWidget {
  final AdifImportPlan plan;

  /// Resolved outside, because the registry that names them lives on the
  /// services and this dialog is handed only the plan.
  final List<String> failedPrograms;

  const _SummaryContent({required this.plan, required this.failedPrograms});
  @override
  State<_SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends State<_SummaryContent> {
  bool _addActivation = false;

  @override
  Widget build(BuildContext dialogContext) {
    final plan = widget.plan;
    final context = dialogContext;
    final t = context.t.adifImport;
    final theme = Theme.of(context);

    Widget stat(String text, {bool muted = false}) => Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Text(text, style: muted ? theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor) : null),
    );

    return HaloDialog(
      // The title names the ACTION; the file is content, not chrome. A long
      // filename in a title truncates, and the one thing the operator most
      // needs to confirm is which file they are about to import.
      title: Text(t.title),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(plan.filename, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Space.sm),
          if (plan.additions.isNotEmpty) stat(t.newContacts(count: plan.additions.length, formatted: formatNumber(plan.additions.length))),
          if (plan.merges.isNotEmpty) stat(t.merging(count: plan.merges.length, formatted: formatNumber(plan.merges.length))),
          // Counts every match, including ones `merges` leaves out because
          // folding the file's data in changed nothing — a re-import of an
          // unchanged file otherwise shows neither line above and reads as
          // though nothing in it was recognized, rather than as already logged.
          if (plan.alreadyLoggedCount > 0) stat(t.alreadyLogged(count: plan.alreadyLoggedCount, formatted: formatNumber(plan.alreadyLoggedCount)), muted: true),
          if (plan.unusable.isNotEmpty) stat(t.unusable(count: plan.unusable.length, formatted: formatNumber(plan.unusable.length)), muted: true),
          if (plan.undated.isNotEmpty) stat(t.noDate(count: plan.undated.length, formatted: formatNumber(plan.undated.length)), muted: true),
          if (plan.hoistedOperationRefs.isNotEmpty && !plan.isEmpty) ...[
            const SizedBox(height: Space.sm),
            // Named, not silently dropped. Stripping an activation off every
            // contact and putting it nowhere would leave the operator with a
            // log that is no longer an activation and nothing that said so.
            stat(t.activationFound(refs: plan.hoistedOperationRefs.map((r) => r['ref']).join(', '))),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _addActivation,
              // Off by default: the operator chose what this operation is, and
              // a file dropped in later does not get to redefine it unasked.
              onChanged: (value) => setState(() => _addActivation = value ?? false),
              title: Text(t.addActivation),
            ),
          ],
          if (plan.flagged.isNotEmpty) stat(t.flagged(count: plan.flagged.length, formatted: formatNumber(plan.flagged.length)), muted: true),
          // Two sentences and two counts, because the two failures are not the
          // same claim about the same records. Nothing reaching the runtime
          // means no references were recovered, full stop; one program's hook
          // failing means every other hook still ran, so the most that can
          // honestly be said is "may be".
          //
          // A long file can hit both in different batches, and then sharing one
          // total would put the unhedged sentence over records whose other
          // hooks answered in full. Each line counts only its own kind, so the
          // conflation is not expressible here.
          if (plan.recordsUnreachable > 0) stat(t.missingRefs(count: plan.recordsUnreachable, formatted: formatNumber(plan.recordsUnreachable)), muted: true),
          if (widget.failedPrograms.isNotEmpty)
            stat(
              t.partialRefs(
                programs: widget.failedPrograms.join(', '),
                count: plan.recordsWithFailedHooks,
                formatted: formatNumber(plan.recordsWithFailedHooks),
              ),
              muted: true,
            ),
          // The plan already answers whether a reference can actually be
          // lost — unknown types AND a fold that will run. Re-deriving that
          // here is how the addition-fold path got missed.
          if (plan.mayDropReferences) stat(t.stackingTypesUnknown, muted: true),
          if (plan.isEmpty && plan.refusedCount == 0) stat(t.nothingToImport),
          if (plan.foreignStations.isNotEmpty && plan.stationCall != null) _StationWarning(calls: plan.foreignStations, station: plan.stationCall!),
        ],
      ),
      actions: [
        if (!plan.isEmpty)
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_ImportDecision(addActivation: _addActivation)),
            child: Text(t.confirm),
          ),
      ],
      cancel: TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        // Done when there is nothing to import and so nothing to abandon,
        // Cancel when the plan would otherwise be applied.
        child: Text(plan.isEmpty ? context.t.common.done : context.t.common.cancel),
      ),
    );
  }
}

/// The file's contacts were logged under a different station, and importing
/// rewrites them.
///
/// Loud on purpose. Every other line in this dialog is a count the operator
/// can shrug at; this one says their log is about to claim contacts it did not
/// make, and it is the only thing here that cannot be undone by deleting a few
/// QSOs afterwards.
class _StationWarning extends StatelessWidget {
  final List<String> calls;
  final String station;

  const _StationWarning({required this.calls, required this.station});

  @override
  Widget build(BuildContext context) {
    final t = context.t.adifImport;
    final theme = Theme.of(context);
    final joined = calls.length < 2 ? calls.join() : '${calls.take(calls.length - 1).join(', ')}${t.stationCallJoin}${calls.last}';

    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(Space.xs)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(MdiIcons.alert, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                t.stationWarning(calls: joined, station: station),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
