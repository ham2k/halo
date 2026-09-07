// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Runs one command action and makes sure its answer reaches someone: the bar
// that asked, or failing that the status bar. Two actions that need a
// confirmation dialog are intercepted here; the rest go through
// HaLoServices.handleCommandAction.

import 'dart:async';

import 'package:flutter/material.dart';

import '../views/operation_dialogs.dart';

import 'error_reporting_service.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'halo_services.dart';

/// Runs one command action through [HaLoServices.handleCommandAction] and
/// surfaces its returned message — so feedback that's only known app-side (a
/// toggled experiment's outcome, syncAll's status) isn't silently dropped.
/// Shared by home_view's, operation_view's and the ⌘K dialog's command
/// dispatch.
///
/// A command typed into one of the two command bars is answered THERE, on the
/// bar's own response line ([HaLoServices.commandResponseSink], which that bar
/// holds open only while its command is dispatching). Everything else — a
/// command typed into the call field — gets the status bar beside it.
///
/// The action's word is the LATER and more specific news than the hook's
/// optimistic `confirm` — it is usually the bad news — so it deliberately
/// replaces it rather than queueing behind it.
///
/// A non-null message ALWAYS reaches something. A bar that has closed is a
/// reason to say it somewhere else and never a reason to drop it: a rejected
/// write announced to nobody leaves the operator holding a confirmation for
/// something that did not happen, which is the failure this whole path exists
/// to prevent. The sink declining is what routes it onward, so a caller must
/// not second-guess that with a liveness test of its own — whether the widget
/// that dispatched the action is still mounted says nothing about whether the
/// bar waiting on the answer is.
///
/// Returns true when the action had something to say at all.
///
/// [context] is only needed for `purgeTests` (PURGETESTS) and `syncAll`
/// (SYNCALL): unlike every other action, which
/// [HaLoServices.handleCommandAction] can run with no UI at all, both have
/// to ask for confirmation before doing anything irreversible — so they're
/// intercepted here rather than reaching that switch. Every real call site
/// (home, ⌘K, the logging panel) has a BuildContext to pass; omitting it
/// only degrades those two commands.
Future<bool> runCommandAction(HaLoServices services, String action,
    [Map<String, dynamic>? params, BuildContext? context]) async {
  // A statement switch rather than an expression: only one arm runs, but the
  // analyzer reads an expression's arms in sequence and sees the second
  // arm's `context` as used after the first arm's await.
  final CommandActionOutcome? outcome;
  switch (action) {
    case 'purgeTests':
      outcome = await _runPurgeTests(services, context);
    case 'syncAll':
      outcome = await _runSyncAll(services, context);
    default:
      outcome = await services.handleCommandAction(action, params);
  }
  if (outcome == null) return false;
  final sink = services.commandResponseSink;
  if (sink == null || !sink(outcome.text, failed: outcome.failed)) {
    services.statusBar.setMessage(key: 'commandAction', text: outcome.text);
  }
  return true;
}

/// PURGETESTS: lists every Test Operation this device holds, asks once for
/// all of them (`confirmPurgeTestOperations`), then purges each — see
/// `HaLoServices.purgeOperation`. Returns null (no message at all) when the
/// user cancels, same as any other dismissed dialog.
///
/// Test contacts belonging to NO operation go too. Nothing else can reach
/// them: this command walks operations and the received-purge prompt is keyed
/// on operation uuids, so without this they accumulate and sync forever. A
/// travelled clock can author exactly these — a test call is the only thing
/// identifying a contact with no operation to belong to.
Future<CommandActionOutcome?> _runPurgeTests(HaLoServices services, BuildContext? context) async {
  // Bypasses handleCommandAction's switch (see runCommandAction's doc), so
  // it has to fire the same usage event that switch's callers get for free.
  services.track('command_executed', {'command': 'purgeTests'});

  final testOperations = (await services.operations.watchAll().first).where((op) => op.isTestOperation).toList();
  final looseQsos = await services.qsos.testQsosWithoutOperation();
  if (testOperations.isEmpty && looseQsos.isEmpty) return (text: t.commands.noTestOperations, failed: false);
  if (context == null) return (text: t.commands.purgeTestsUnavailable, failed: true);
  // The await above is a real gap: the widget that owns `context` (the
  // command dialog, home view, or logging panel) can be gone by the time it
  // resolves — e.g. the operator closed ⌘K while this was still listing.
  if (!context.mounted) return (text: t.commands.purgeTestsUnavailable, failed: true);
  if (!await confirmPurgeTestOperations(context, testOperations, looseQsoCount: looseQsos.length)) return null;

  // Isolated per operation: one purge throwing must not strand the rest
  // half-purged with no report of how far it got.
  var purgedCount = 0;
  for (final operation in testOperations) {
    try {
      await services.purgeOperation(operation.uuid);
      purgedCount++;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'purgeTests:${operation.uuid}');
    }
  }
  // Isolated from the loop above for the same reason, and counted separately:
  // the two are different things to the operator, and one number cannot stand
  // for both. `purgeQsos` reports what it actually wrote, not what was asked.
  var purgedContacts = 0;
  var contactsFailed = false;
  if (looseQsos.isNotEmpty) {
    try {
      purgedContacts = await services.qsos.purgeQsos(looseQsos.map((qso) => qso.uuid));
    } catch (e, st) {
      contactsFailed = true;
      ErrorReportingService.report(e, st, context: 'purgeTests:looseQsos');
    }
  }
  services.track('test_operations_purged', {'count': purgedCount, 'contacts': purgedContacts});

  // Every branch names what it actually did. Reporting only the operations —
  // "Purged 0 Test Operations" after tombstoning five contacts the operator
  // just confirmed — reads as a command that silently failed.
  final parts = <String>[
    if (purgedCount > 0) t.commands.testOperationsPurged(count: purgedCount),
    if (purgedContacts > 0) t.commands.testContactsPurged(count: purgedContacts),
  ];
  if (purgedCount < testOperations.length) {
    return (text: t.commands.purgeTestsSomeFailed(purged: purgedCount, total: testOperations.length), failed: true);
  }
  if (contactsFailed) return (text: t.commands.purgeTestsContactsFailed, failed: true);
  if (parts.isEmpty) return (text: t.commands.purgeTestsNothingToDo, failed: false);
  return (text: parts.join(' · '), failed: false);
}

/// SYNCALL: backs up and WIPES the local log, then refills it from the
/// server (`SyncEngine.forceFullResync`) — intercepted like PURGETESTS
/// because it must confirm before doing anything irreversible. The backfill
/// can only return what the server holds: any row it never received (a
/// failed push, a long-offline device) does NOT come back, and the operator
/// most likely to type SYNCALL — "sync looks stuck, force it" — is exactly
/// the one most likely to be holding such rows, so the dialog names the
/// unsynced count outright. Returns null when the user cancels, same as any
/// other dismissed dialog.
Future<CommandActionOutcome?> _runSyncAll(HaLoServices services, BuildContext? context) async {
  // Bypasses handleCommandAction's switch, so it fires the same usage event.
  services.track('command_executed', {'command': 'syncAll'});
  if (!services.settings.syncEnabled) return (text: t.commands.enableSyncFirst, failed: true);
  if (context == null) return (text: t.commands.syncAllUnavailable, failed: true);
  final counts = await services.qsos.syncCounts();
  // NOT `counts.pending`: that number counts every dirty row — tombstones
  // and event markers included — and a dialog warning "N QSOs will not come
  // back" with a number the operator can see is wrong teaches them to
  // distrust the one gate on this wipe.
  final unsynced = await services.qsos.unsyncedContactCount();
  // The awaits above are a real gap — same reasoning as _runPurgeTests.
  if (!context.mounted) return (text: t.commands.syncAllUnavailable, failed: true);
  if (!await confirmFullResyncDialog(context, qsoCount: counts.total, unsyncedCount: unsynced)) return null;

  // A refusal has to be reported: this command backs up and WIPES the
  // local log before refilling it from the server, so "started" against a
  // clock that bars sync would be the operator watching their log vanish
  // with nothing that would refill it (docs/design/time.md §4).
  if (!await services.syncEngine.forceFullResync()) {
    return (text: 'A full resync needs the real clock — run DEVTT first', failed: true);
  }
  return (text: t.commands.fullResyncStarted, failed: false);
}
