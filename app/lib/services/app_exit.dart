// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Leaving: tell the radios, then close SQLite, each step bounded so one
// wedged device cannot hold the quit open with no window and no feedback.

import 'dart:async';

import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'app_storage.dart' show logBusyTimeout;
import 'error_policy.dart';
import 'hang_watchdog.dart';

import 'error_reporting_service.dart';
import 'unclean_quit.dart';

import 'halo_services.dart';

/// Kept alive for the process lifetime — an [AppLifecycleListener] stops
/// observing when it is garbage collected.
AppLifecycleListener? _shutdownLifecycle;

/// Say goodbye to connected equipment, and to SQLite, before the app stops
/// existing.
///
/// A session the radio is never told to end is one it keeps holding. The
/// IC-705 has a single remote-control slot and holds the login until it times
/// out on its own, so quitting without a disconnect is what makes the NEXT
/// connect fail — the "radio did not answer the login".
///
/// NOT the reason: "the radio streams ~95 packets/second at us and an
/// ungraceful exit leaves that flood pointed at a dead port" — measured
/// FALSE on hardware (see the CAT commit "the IC-705 sends us no audio");
/// the radio only streams audio to a client that has completed a session
/// handshake on port 50003, which we never do. The
/// reason above is the real one.
///
/// `onExitRequested` is the desktop hook that can actually *await* cleanup
/// before the process goes. `detached` is BEST EFFORT ONLY: onStateChange is
/// synchronous, so the work cannot be awaited, and on a dying isolate a
/// disconnect needing a 600ms ack will usually not complete. Deliberately NOT
/// `paused`: on Android that fires every time the operator switches away to
/// look something up. So an Android kill from the background still escapes
/// this — see docs/design/cat.md.
void shutdownOnExit(HaLoServices services) {
  _shutdownLifecycle ??= AppLifecycleListener(
    onExitRequested: () async {
      // Before any of the teardown below: from here on, a write that loses its
      // race with the database close is expected rather than a defect, and
      // ErrorPolicy's `database-closed-on-exit` rule reads this to tell the
      // two apart.
      ErrorPolicy.appIsExiting = true;
      // Under the watchdog for the whole of it. Every step of the teardown is
      // bounded, but only against an await — and the serial close inside
      // `shutdown()` is synchronous FFI, which a `timeout` cannot reach. A
      // quit that wedges there leaves a process that never dies and, on
      // Windows, a window that makes every later launch a silent no-op
      // (services/hang_watchdog.dart).
      return HangWatchdog.guard(() => tearDownForExit(services));
    },
    onStateChange: (state) {
      // Guarded like the exit hook: this reaches the same synchronous serial
      // close, and a wedge here leaves the same process that will not die.
      if (state == AppLifecycleState.detached) {
        unawaited(HangWatchdog.guard(() => services.cat.shutdown()));
      }
    },
  );
}

/// Says goodbye to the radios and then to SQLite, in that order, and answers
/// the framework's question.
///
/// Its own function so [shutdownOnExit] reads as what it is — one guarded
/// teardown — rather than as a block of steps wrapped in a closure.
@visibleForTesting
Future<AppExitResponse> tearDownForExit(HaLoServices services) async {
  // In FRONT of the radios: this is the step that can wedge rather than
  // fail, and a wedge here is invisible everywhere else — the process never
  // dies to be reported, and the next launch is a silent no-op rather than a
  // crash.
  await _markStage(services, QuitStage.cat);
  try {
    // Bounded. shutdown() awaits each node in turn, and while the Icom
    // path is bounded (600ms ack + 20ms), a serial port wedged mid-write
    // has no such guarantee. Without a ceiling one stuck radio hangs
    // Cmd-Q with no window and no feedback, and the force-quit that
    // follows skips the very disconnect this exists to send.
    await services.cat.shutdown().timeout(const Duration(seconds: 5));
  } catch (e, st) {
    // Never block the user's quit on a radio that will not let go.
    ErrorReportingService.report(e, st, context: 'cat:shutdown-on-exit');
  }
  // After CAT, whose disconnects are the last thing a hook may still react
  // to, and BEFORE the database, which hooks write through. The runtime has
  // to be gone before the VM's own teardown, or the process aborts on the way
  // out (ExtensionService.shutdownForExit says why). Bounded like the rest:
  // the dispose gives a wedged isolate a short grace and then kills it, and a
  // quit must not hang on an extension that will not let go either.
  try {
    await services.extensions.shutdownForExit().timeout(_extensionsBudget);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'extensions:shutdown-on-exit');
  }
  // After CAT, which writes through the same database on its way out.
  await closeDatabaseOnExit(services);
  _reportARefusedExit();
  return AppExitResponse.exit;
}

/// How long the database step may take, split so the part that must happen
/// still gets its turn if the part that merely should takes too long.
///
/// Both are bounded for the same reason CAT's shutdown is: a wedged write must
/// not leave Cmd-Q hanging with no window and no feedback. The steps are
/// serialized and what an operator experiences is the total, so neither is
/// longer than its job needs.
///
/// The drain's job is to outlast one write waiting on another process's lock,
/// which SQLite lets run for [logBusyTimeout]. Shorter, and a quit that meets
/// such a lock times out the drain and then the close — the connection is
/// still inside that write — so the write is lost AND the next launch reports
/// an unclean quit instead of the `database is locked` that names the cause.
final _drainBudget = logBusyTimeout + const Duration(seconds: 1);
const _closeBudget = Duration(seconds: 2);
const _markBudget = Duration(milliseconds: 500);

/// How long the extension runtime may take to go: its dispose is a 200ms
/// grace for the isolate to free the JS engine, then a kill, so anything
/// past a couple of seconds is a hang, not a slow machine. Counted in the
/// watchdog's silence budget (services/hang_watchdog.dart) with the rest.
const _extensionsBudget = Duration(seconds: 2);

/// Shuts the database down on the way out, as carefully as an exit allows —
/// the operator's log is the one thing in this app that cannot be recreated.
///
/// Three steps, in this order, each load-bearing:
///
/// 1. **Stop scheduling.** SyncEngine's loop is what starts new work on its
///    own; a round beginning between the drain and the close would be rolled
///    back by it, for the next launch to redo. PeerService is deliberately NOT
///    disposed here: it is a lazily-built ChangeNotifier that a session may
///    never have constructed, and building one at quit just to dispose it —
///    while widgets that listen to it are still mounted — costs more than the
///    inbound event it would prevent, which the peer resends anyway.
/// 2. **Drain.** drift's close is NOT a barrier: the background isolate acts
///    on the terminate request whenever it arrives and closes the connection
///    under whatever is still running, so a multi-statement transaction in
///    flight (an ADIF import, a sync round) is rolled back rather than
///    finished. An empty transaction queues behind any real one — drift
///    serializes them on a single lock — so awaiting it means the connection
///    is idle before the close begins.
/// 3. **Close**, so SQLite shuts down on a live isolate rather than during the
///    VM's teardown, where it aborts (see [shutdownOnExit]).
///
/// SQLite's own guarantees cover what none of this can: a transaction is
/// atomic, so even a process killed outright leaves a consistent file that
/// the next open recovers. What these steps buy is the write that would
/// otherwise be rolled back, and an exit that isn't a crash report.
///
/// The stage mark around it all is the only part that outlives the process:
/// the engine tears the app down the moment this returns, so a `report()` from
/// a failed close never reaches the backend. The next boot reports it instead
/// (`reportUncleanQuit`, wired into [bootstrap]), naming the step that was
/// still running — which is why each step marks itself rather than one mark
/// covering the lot.
@visibleForTesting
Future<void> closeDatabaseOnExit(HaLoServices services) async {
  final prefs = services.settings.prefs;
  await _markStage(services, QuitStage.databaseDrain);
  services.syncEngine.dispose();
  try {
    await services.db.transaction(() async {}).timeout(_drainBudget);
  } catch (e, st) {
    // Reported, not rethrown: a drain that cannot finish is a write about to
    // be lost, which is worth knowing — and the close still has to happen, or
    // the process aborts on the way out with that write lost anyway.
    ErrorReportingService.report(e, st, context: 'db:drain-on-exit');
  }
  await _markStage(services, QuitStage.databaseClose);
  try {
    await services.db.close().timeout(_closeBudget);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'db:close-on-exit');
    // The mark stays: a close that did not finish is exactly what the next
    // boot has to hear about.
    return;
  }
  try {
    await clearQuitStage(prefs).timeout(_markBudget);
  } catch (e, st) {
    // Its own guard, so a slow clear is not reported as a failed close — and
    // so a quit that went perfectly is not filed as an unclean one.
    ErrorReportingService.report(e, st, context: 'db:unmark-on-exit');
  }
}

/// Records that [stage] is about to run, without ever being the reason it
/// does not.
///
/// Guarded and bounded, because the mark is worth less than the step it
/// describes: an unwritable prefs file or a wedged platform channel must not
/// throw or hang in FRONT of a teardown step — that would leave the process
/// to abort on the way out, which is the very failure the mark exists to
/// record. The `report` is inside a guard of its own for the same reason: it
/// reaches the backend synchronously, and a throw from there would skip the
/// radios' disconnect entirely.
///
/// A write that is REFUSED rather than failed takes the stale mark with it.
/// The previous stage is still sitting in the pref, and left there it would
/// have the next boot name the wrong step with full confidence — a quit that
/// wedged in the drain reported as one that wedged on a radio, sending
/// whoever reads it after a serial port. No mark at all says less and lies
/// less; the report below is what says a mark went missing.
///
/// Console-only, in practice. Everything reported from here runs in the last
/// moments of the process, which is the whole reason the mark exists, so
/// treat these as log lines rather than as backend coverage.
Future<void> _markStage(HaLoServices services, QuitStage stage) async {
  final prefs = services.settings.prefs;
  try {
    if (await markQuitStage(prefs, stage).timeout(_markBudget)) return;
    await clearQuitStage(prefs).timeout(_markBudget);
    _reportQuietly(StateError('the $stage quit mark was refused'), StackTrace.current);
  } catch (e, st) {
    _reportQuietly(e, st);
  }
}

/// [ErrorReportingService.report], for a caller that cannot afford a throw.
void _reportQuietly(Object error, StackTrace stackTrace) {
  try {
    ErrorReportingService.report(error, stackTrace, context: 'db:mark-on-exit');
  } catch (_) {
    // Nowhere left to report a reporting failure, and the teardown step this
    // sits in front of matters more than any record of it.
  }
}

/// Says so, loudly, if the app is still running after its database was closed.
///
/// The framework asks EVERY observer whether it may exit and takes a `cancel`
/// from any one of them, so our own `exit` answer does not decide the outcome:
/// a refusal anywhere leaves this app alive on a database drift cannot reopen.
/// Nothing here cancels one today — we are the only `onExitRequested` in the
/// app, and no plugin in the tree implements `didRequestAppExit` — which makes
/// this a guard against a future observer, not a live path.
///
/// Volume is the entire point. Every write from here on fails, and
/// `ErrorPolicy.appIsExiting` is what tells the policy those failures are
/// expected; left set on an app that did not exit, it would turn an operator
/// logging into nothing into the quietest tier we have.
void _reportARefusedExit() {
  Timer(const Duration(seconds: 2), () {
    ErrorPolicy.appIsExiting = false;
    ErrorReportingService.report(StateError('the app is still running after its database was closed to exit'), StackTrace.current, context: 'db:exit-refused');
  });
}
