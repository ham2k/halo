// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Runs one command action and makes sure its answer reaches someone: the bar
// that asked, or failing that the status bar. The actions that need the UI —
// two that confirm in a dialog, GO's navigation, and UPDATE's app and
// extension checks, which open a store page or a dialog — are intercepted here,
// with UPDATE's data files kept beside those two;
// the rest go through HaLoServices.handleCommandAction.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo_core/halo_core.dart' show asQsonString;

import '../config/navigation.dart';
import '../settings/cluster_console.dart';
import '../views/app_shell/home_rail_state.dart';
import '../views/operation_dialogs.dart';

import 'error_reporting_service.dart';
import 'update_check_service.dart';
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
Future<bool> runCommandAction(HaLoServices services, String action, [Map<String, dynamic>? params, BuildContext? context]) async {
  // A statement switch rather than an expression: only one arm runs, but the
  // analyzer reads an expression's arms in sequence and sees the second
  // arm's `context` as used after the first arm's await.
  final CommandActionOutcome? outcome;
  switch (action) {
    case 'purgeTests':
      outcome = await _runPurgeTests(services, context);
    case 'syncAll':
      outcome = await _runSyncAll(services, context);
    case 'navigate':
      outcome = await _runNavigate(services, asQsonString(params?['to']) ?? '');
    case 'updateDataFiles':
      outcome = await _runUpdateDataFiles(services, [for (final word in (params?['matching'] as List?) ?? const []) '$word']);
    case 'updateApp':
      outcome = await _runUpdateApp(services);
    case 'updateExtensions':
      outcome = await _runUpdateExtensions(services);
    // DEVSUGGEST: the stand-in for a draft-suggestions extension
    // (logging-fields.md § Draft suggestions), which each logging panel runs.
    case 'devSuggest':
      services.extensions.draftSuggestions.devStandIn.value = params?['on'] != false;
      outcome = null;
    default:
      outcome = await services.handleCommandAction(action, params);
  }
  if (outcome == null) return false;
  services.reportCommandOutcome(outcome);
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

/// UPDATE and its data-file words (`update-commands`): every file the
/// [words] name, or every file without any, whatever its age but past the
/// ETag check, so only what the server changed is fetched. The names are
/// settled before anything runs, so a word that names nothing is refused on
/// the bar that typed it; the files then report their own progress, as
/// RELOAD's do.
Future<CommandActionOutcome?> _runUpdateDataFiles(HaLoServices services, List<String> words) async {
  // Bypasses handleCommandAction's switch, so it fires the same usage event.
  services.track('command_executed', {'command': 'updateDataFiles'});
  final dataFiles = services.dataFiles;
  // Without a runtime the pass below finds no definitions and does nothing.
  if (services.extensions.host == null) return (text: t.extensionService.runtimeNotReady, failed: true);
  List<String>? names;
  if (words.isNotEmpty) {
    names = await dataFiles.dataFilesAnswering(words);
    if (names == null) return (text: t.extensionService.runtimeNotReady, failed: true);
    if (names.isEmpty) return (text: t.commands.noDataFilesMatched(target: words.join(' ')), failed: true);
  }
  unawaited(
    dataFiles
        .syncAllDataFiles(ignoreAge: true, matching: words.isEmpty ? null : words)
        .then((matched) {
          // The pass waits its turn behind any other and asks the runtime
          // again, which by then may be restarting: without this, the bar's
          // "Updating…" would be the last word on a pass that did nothing.
          if (matched > 0) return;
          services.statusBar.setProgress(
            key: 'command:updateDataFiles',
            text: services.extensions.host == null
                ? t.extensionService.runtimeNotReady
                : t.commands.noDataFilesMatched(target: words.isEmpty ? 'DATA' : words.join(' ')),
            value: 1.0,
          );
        })
        .catchError((Object e, StackTrace st) {
          // syncAllDataFiles isolates and reports each file's own failure; this
          // is anything that slips past those.
          ErrorReportingService.report(
            e,
            st,
            context: 'command:updateDataFiles',
            notice: ErrorNotice(
              services.statusBar,
              key: 'command:updateDataFiles',
              text: t.commands.updateDataFilesFailed(error: ErrorReportingService.messageOf(e)),
            ),
          );
        }),
  );
  return (text: names == null ? t.commands.updatingAllDataFiles : t.commands.updatingDataFiles(names: names.join(', ')), failed: false);
}

/// UPDATE APP (`update-commands`): the About panel's Check for Updates, with
/// its answer said here. Where the check leaves somewhere to go (a store
/// page) it goes there; Sparkle and WinSparkle put up their own prompt.
Future<CommandActionOutcome?> _runUpdateApp(HaLoServices services) async {
  // Bypasses handleCommandAction's switch, so it fires the same usage event.
  services.track('command_executed', {'command': 'updateApp'});
  final check = services.updateCheck;
  if (!check.isApplicable(updates: services.updates)) return (text: t.commands.appUpdatesNotChecked, failed: true);
  // The check and the store lookup behind updateDestination reach
  // distribution-specific APIs and can throw; launchUrl has a try of its own,
  // as in UpdateCheckRow, so a store that will not open is not a failed check.
  try {
    switch (await check.check(updates: services.updates, statusBar: services.statusBar)) {
      case UpdateCheckOutcome.upToDate:
        return (text: t.commands.appUpToDate, failed: false);
      case UpdateCheckOutcome.restartToApply:
        return (text: t.updates.restartToApply, failed: false);
      case UpdateCheckOutcome.reloadToUpdate:
        return (text: t.updates.reloadToUpdate, failed: false);
      case UpdateCheckOutcome.checkFailed:
        return (text: t.commands.appUpdateCheckFailed, failed: true);
      case UpdateCheckOutcome.updateAvailable:
        // Launched directly for the reason UpdateCheckRow gives: this URL is the
        // check's own, not one openExternalUrl's allowlist fences.
        if (await check.updateDestination() case final destination?) {
          try {
            if (!await launchUrl(destination, mode: LaunchMode.externalApplication)) {
              return (text: t.commands.appUpdateNotOpened, failed: true);
            }
          } catch (e, st) {
            ErrorReportingService.report(e, st, context: 'command:updateApp:open', told: true);
            return (text: t.commands.appUpdateNotOpened, failed: true);
          }
        }
        return (text: t.updates.updateAvailable, failed: false);
    }
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'command:updateApp', told: true);
    return (text: t.commands.appUpdateCheckFailed, failed: true);
  }
}

/// UPDATE EXT (`update-commands`): asks the catalog now rather than when the
/// daily check is due, then offers every update it names through the update
/// notice's own Update all — whose dialog lists them before anything installs.
Future<CommandActionOutcome?> _runUpdateExtensions(HaLoServices services) async {
  // Bypasses handleCommandAction's switch, so it fires the same usage event.
  services.track('command_executed', {'command': 'updateExtensions'});
  if (!services.extensions.availableExtensions.any((info) => info.isInstalled)) {
    return (text: t.commands.noCatalogExtensions, failed: false);
  }
  final check = services.catalogUpdateCheck;
  // A check already running makes this one return false at once; that is no
  // network failure.
  if (check.isChecking) return (text: t.commands.extensionCheckUnderWay, failed: false);
  // Announced: the bar is not the Extensions panel these notices point at,
  // and a replacement (which Update all never takes) has nowhere else to be
  // said. The updates notice also outlives a Cancel in the dialog below.
  if (!await check.check(force: true)) return (text: t.commands.extensionCheckFailed, failed: true);
  final pending = check.pendingUpdates.values.toList();
  if (pending.isEmpty) {
    final replaced = check.pendingRedirects.length;
    return (text: replaced > 0 ? t.commands.extensionsReplaced(count: replaced) : t.commands.extensionsUpToDate, failed: false);
  }
  // Not awaited: the installs outlast the command bar that asked, and the
  // dialog and the installs report for themselves.
  unawaited(check.updateAll?.call(pending, const {}));
  return (text: t.commands.extensionUpdatesFound(count: pending.length), failed: false);
}

/// The Settings panels GO can open — the keys `SettingsView` selects by.
const _goPanels = {'settings', 'profiles', 'station', 'sync', 'peers', 'accounts', 'extensions', 'developer', 'help', 'about'};

/// GO (`navigation-commands`). Home's destinations leave any open operation
/// and move the rail, through its leave guards like a press on the rail
/// would; a Settings panel opens OVER what is on screen, the way every other
/// entry point outside the rail reaches Settings.
///
/// A destination turned off here is an error, never a fallback: the rail
/// would put Logs back to Operations and `SettingsView` would show its first
/// panel instead of Peers, and either reads as GO going to the wrong place.
Future<CommandActionOutcome?> _runNavigate(HaLoServices services, String to) async {
  // Bypasses handleCommandAction's switch, so it fires the same usage event.
  services.track('command_executed', {'command': 'navigate'});
  final settings = services.settings;
  CommandActionOutcome unavailable(String place) => (text: t.commands.goUnavailable(place: place), failed: true);
  final home = switch (to) {
    'operations' => HomeDestination.operations,
    'maps' => HomeDestination.maps,
    'logs' => HomeDestination.logs,
    'chase' => HomeDestination.chase,
    _ => null,
  };
  if (home != null) {
    final offered = homeDestinationOffered(
      home,
      showLogs: settings.experimentEnabled('logs') /* stored key, see experiments.yaml */,
      showChase: settings.experimentEnabled('chase') /* stored key, see experiments.yaml */,
    );
    if (!offered) return unavailable(home == HomeDestination.logs ? t.home.nav.logs : t.home.nav.chase);
    // A dialog that refuses to close (an import in progress) stops the walk:
    // `popUntil` does not ask PopScope, and a dialog popped out from under
    // the code driving it has that code pop whatever is on top when it ends.
    var blocked = false;
    navigatorKey.currentState?.popUntil((route) {
      if (route.isFirst) return true;
      if (route.popDisposition == RoutePopDisposition.doNotPop) return blocked = true;
      return false;
    });
    if (blocked) return (text: t.commands.goBlocked, failed: true);
    await homeRail.leaveTo(home);
    return null;
  }
  if (to == 'cluster') {
    // CLUSTER (`spot-commands`): the console opens over what is on screen.
    // Only where an extension uses the cluster, as the DX Cluster settings: a
    // session there would have no Settings to pick its node or turn it off.
    final calls = services.extensions.clusterCalls;
    final cluster = calls.offered ? calls.cluster?.call() : null;
    final context = navigatorKey.currentContext;
    if (cluster == null || context == null) return unavailable(t.settings.cluster.consoleTitle);
    unawaited(showClusterConsole(context, cluster));
    return null;
  }
  if (!_goPanels.contains(to)) return (text: t.commands.goUnknown(to: to), failed: true);
  if (to == 'peers' && !settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ) return unavailable(t.settings.panels.peers);
  if (to == 'developer' && !settings.developerMode) return unavailable(t.settings.panels.developerSettings);
  services.openSettingsPanel(to);
  return null;
}
