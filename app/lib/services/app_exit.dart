// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Leaving: tell the radios, then close SQLite, each step bounded so one
// wedged device cannot hold the quit open with no window and no feedback.

import 'dart:async';

import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

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
/// not leave Cmd-Q hanging with no window and no feedback. Their sum is
/// deliberately well under CAT's own ceiling — the steps are serialized and
/// what an operator experiences is the total, so a matching 5s here would
/// allow the very windowless wait each ceiling exists to prevent.
const _drainBudget = Duration(milliseconds: 1500);
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
/// The breadcrumb around it all is the only part that outlives the process:
/// the engine tears the app down the moment this returns, so a `report()` from
/// a failed close never reaches the backend. The next boot reports it instead
/// (`reportUncleanQuit`, wired into [bootstrap]).
@visibleForTesting
Future<void> closeDatabaseOnExit(HaLoServices services) async {
  final prefs = services.settings.prefs;
  // Guarded and bounded like everything else on this path, and for a sharper
  // reason: the mark is worth less than the close it describes. An unwritable
  // prefs file or a wedged platform channel must not throw or hang in FRONT of
  // the close — that would leave the process to abort on the way out, which is
  // the very failure the mark exists to record.
  try {
    await markDatabaseClosing(prefs).timeout(_markBudget);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'db:mark-on-exit');
  }
  services.syncEngine.dispose();
  try {
    await services.db.transaction(() async {}).timeout(_drainBudget);
  } catch (e, st) {
    // Reported, not rethrown: a drain that cannot finish is a write about to
    // be lost, which is worth knowing — and the close still has to happen, or
    // the process aborts on the way out with that write lost anyway.
    ErrorReportingService.report(e, st, context: 'db:drain-on-exit');
  }
  try {
    await services.db.close().timeout(_closeBudget);
    await markDatabaseClosed(prefs).timeout(_markBudget);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'db:close-on-exit');
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
    ErrorReportingService.report(
      StateError('the app is still running after its database was closed to exit'),
      StackTrace.current,
      context: 'db:exit-refused',
    );
  });
}
