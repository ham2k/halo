// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The answer to a process that stops existing without stopping.
//
// Two calls in this app reach hardware on the isolate that also pumps the UI,
// and neither is bounded by anything: the serial open at launch and the serial
// close at quit are synchronous FFI, and on Windows both block indefinitely
// against a driver that has wedged. A `timeout()` cannot help — it bounds an
// *await*, and there is no await to bound; the isolate is simply gone. What
// follows is worse than a crash. At quit the process never dies. At launch it
// never draws, and Flutter's Windows runner creates its window before the
// first frame, so the corpse owns a findable window that the single-instance
// guard hands every later launch to, silently. One stuck port becomes an app
// that will not start at all (HALO-525).
//
// Nothing running on that isolate can notice any of this, because noticing is
// itself something it would have to run. Another isolate can: it has its own
// thread, its own event loop, and `exit()` from it takes the whole process
// down. So a guarded call keeps a heartbeat going from the main isolate, and
// the watchdog ends the process if the heartbeat stops.
//
// A HEARTBEAT rather than a deadline on the call, and the distinction is the
// whole design. The question is never "is this call taking a long time" —
// plenty of honest ones do, a keychain that prompts most of all — it is "is
// this isolate still running anything at all". A `Timer` that fires answers
// exactly that, and answers it right through a connect that is merely slow.
//
// What this does NOT do is save the launch it kills: that one is lost either
// way. It converts a permanent, invisible brick into one failed start, which
// the next launch survives — the auto-connect breadcrumb
// (cat/auto_connect_guard.dart) is what stops it repeating the call that did
// the killing.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/dev_flags.dart';
import 'error_reporting_service.dart';
import 'hang_watchdog_spawn.dart';

/// How long the guarded isolate may say nothing at all before it is presumed
/// gone.
///
/// Generous on purpose. Everything guarded here already carries its own
/// budget — CAT's shutdown 5 s, the database close about 4 s between its
/// steps, a TCP connect 5 s — so this only ever fires past every one of them,
/// and it measures silence rather than slowness, which no honest wait
/// produces. The cost of firing early is an app killed under an operator who
/// was using it; the cost of firing late is a few more seconds of a launch
/// that was already lost.
const watchdogSilence = Duration(seconds: 20);

/// How often a guarded isolate proves it is still running things.
const watchdogHeartbeat = Duration(seconds: 1);

/// A second chance, given to every expired deadline before the process is
/// ended.
///
/// The one silence the heartbeat cannot tell from a wedge is a SUSPENDED
/// PROCESS. A machine that sleeps stops both isolates; on wake, the deadline
/// is already long past due and fires on its own event loop, racing the main
/// isolate's first heartbeat with no ordering between them — and losing that
/// race would end a perfectly healthy app. A resumed isolate is heard from
/// inside a heartbeat or two, so an expiry that survives this second window
/// as well is a wedge rather than a machine waking up.
const watchdogGrace = Duration(seconds: 5);

/// What the process exits with when the watchdog ends it — not that anyone
/// sees it, but it keeps this distinguishable from an ordinary `exit(0)` in a
/// terminal or a crash reporter.
const watchdogExitCode = 92;

/// This process is running without a watchdog.
///
/// Its own type rather than a StateError with a recognizable message, for the
/// reason [UncleanDatabaseQuit] gives: a rule that matches on message text
/// eventually claims a real error that merely reads the same.
class WatchdogUnavailable implements Exception {
  const WatchdogUnavailable();

  @override
  String toString() => 'WatchdogUnavailable: the watchdog isolate could not be started';
}

/// The two things the main isolate ever says.
const watchdogPing = 'ping';
const watchdogDisarm = 'disarm';

/// The watchdog's entire behaviour, as a function of what it hears — kept
/// here, apart from the isolate that runs it, so it can be driven by a test
/// without spawning anything or exiting anything.
///
/// The first ping arms it; every later one pushes the deadline out; a disarm
/// puts it away. Nothing distinguishes "armed" from "pinged", because a ping
/// that arrives when nothing is armed can only be the start of a guarded call.
///
/// An expired deadline asks the question again over [grace] before answering
/// it — see [watchdogGrace] for the case that makes the second look necessary.
void runWatchdog(
  Stream<Object?> messages, {
  required Duration silence,
  required Duration grace,
  required void Function() onSilence,
}) {
  Timer? deadline;
  var confirming = false;
  late void Function() expire;
  expire = () {
    if (!confirming) {
      confirming = true;
      deadline = Timer(grace, expire);
      return;
    }
    onSilence();
  };
  messages.listen((message) {
    deadline?.cancel();
    confirming = false;
    deadline = message == watchdogDisarm ? null : Timer(silence, expire);
  });
}

/// Guards the calls that can take the process with them.
///
/// One watchdog isolate per process, started at boot and kept for the life of
/// it: spawning one at the moment of need would mean spawning it on the quit
/// path, from an engine already tearing down, which is the least reliable
/// moment there is.
class HangWatchdog {
  @visibleForTesting
  HangWatchdog(this._send);

  final void Function(Object message) _send;

  /// Guards can nest and overlap — two radios reconnect at once — and the
  /// heartbeat belongs to the isolate, not to any one of them.
  int _guards = 0;
  Timer? _heartbeat;

  static HangWatchdog? _instance;

  /// Release and profile only, unless asked for by name.
  ///
  /// A debug build is one with a debugger attached, where a breakpoint is
  /// precisely "the UI isolate is running nothing" — held for as long as the
  /// developer is reading. Killing the process there would make the debugger
  /// useless, and `flutter test` runs in debug too, where an armed watchdog
  /// would end the test runner rather than fail a test.
  static bool get _wanted =>
      kReleaseMode ||
      kProfileMode ||
      debugEnvFlag(const String.fromEnvironment('HANG_WATCHDOG'), 'HANG_WATCHDOG').isNotEmpty;

  /// Starts the watchdog for this process, once. Safe to call when it cannot
  /// run at all — on web there is no isolate to spawn and no process to end.
  static Future<void> start() async {
    if (_instance != null || kIsWeb || !_wanted) return;
    final send = await spawnWatchdog(
      silence: watchdogSilence,
      grace: watchdogGrace,
      exitCode: watchdogExitCode,
    );
    if (send == null) {
      // Reported, not merely printed. This runs in release and profile builds,
      // where nobody is reading a console — so without this, a population of
      // installs loses the only protection against the bug this exists for and
      // nothing anywhere says so. The same argument the held auto-connect makes
      // for its own telemetry: a process ended by a wedge files no crash report
      // either.
      ErrorReportingService.report(const WatchdogUnavailable(), StackTrace.current,
          context: 'watchdog:spawn');
      return;
    }
    _instance = HangWatchdog(send);
    debugPrint('[watchdog] armed for calls that can wedge the UI isolate');
  }

  /// Runs [body] with the watchdog watching. Plain passthrough when no
  /// watchdog is running, so a caller never has to ask whether there is one.
  static Future<T> guard<T>(Future<T> Function() body) {
    final watchdog = _instance;
    return watchdog == null ? body() : watchdog._guard(body);
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance?._heartbeat?.cancel();
    _instance = null;
  }

  @visibleForTesting
  static void installForTesting(HangWatchdog watchdog) => _instance = watchdog;

  Future<T> _guard<T>(Future<T> Function() body) async {
    _enter();
    try {
      return await body();
    } finally {
      _leave();
    }
  }

  void _enter() {
    _guards += 1;
    if (_heartbeat != null) return;
    // Immediately, not on the first tick: the call being guarded may be the
    // very next statement, and a watchdog armed a second later would not be
    // watching for the one moment it exists for.
    _send(watchdogPing);
    _heartbeat = Timer.periodic(watchdogHeartbeat, (_) => _send(watchdogPing));
  }

  void _leave() {
    _guards -= 1;
    if (_guards > 0) return;
    _heartbeat?.cancel();
    _heartbeat = null;
    _send(watchdogDisarm);
  }
}
