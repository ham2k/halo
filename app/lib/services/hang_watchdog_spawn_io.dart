// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The watchdog's isolate, and the one call in this app that ends the process
// on purpose.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'hang_watchdog.dart';

/// What the isolate is started with: everything it needs, since it can ask
/// nothing of the isolate it is watching.
class _WatchdogSetup {
  final SendPort ready;
  final Duration silence;
  final Duration grace;
  final int exitCode;

  const _WatchdogSetup(this.ready, this.silence, this.grace, this.exitCode);
}

/// How long the handshake may take before the watchdog is given up on.
///
/// Bounded for the same reason the watchdog itself exists. `Isolate.spawn` can
/// succeed while the isolate dies before its first statement, and a bare
/// `handshake.first` then waits for ever — on the boot path, awaited inside
/// `bootstrap`, which is a splash screen that never leaves. Introducing an
/// unbounded wait in the code written to end one is the specific mistake worth
/// spending a line to avoid.
const _handshakeBudget = Duration(seconds: 5);

/// Starts the watchdog isolate and answers with the way to talk to it, or null
/// if it could not be started.
///
/// The port comes back over a handshake rather than being created here,
/// because a `ReceivePort` belongs to the isolate that listens on it.
Future<void Function(Object message)?> spawnWatchdog({
  required Duration silence,
  required Duration grace,
  required int exitCode,
}) async {
  final handshake = ReceivePort();
  try {
    await Isolate.spawn(
      _watchdogMain,
      _WatchdogSetup(handshake.sendPort, silence, grace, exitCode),
      // The same port takes the exit notification, so an isolate that dies
      // before it introduces itself completes the wait below with a null
      // instead of leaving it pending.
      onExit: handshake.sendPort,
      // A watchdog that dies with the error it was watching for is no
      // watchdog: an uncaught error here must not take it down, and the
      // isolate that spawned it must not be told to die with it either.
      errorsAreFatal: false,
      debugName: 'ham2k-watchdog',
    );
    final first = await handshake.first.timeout(_handshakeBudget, onTimeout: () => null);
    if (first is! SendPort) {
      debugPrint('[watchdog] the isolate never introduced itself');
      return null;
    }
    return first.send;
  } catch (e) {
    debugPrint('[watchdog] could not start: $e');
    return null;
  } finally {
    handshake.close();
  }
}

void _watchdogMain(_WatchdogSetup setup) {
  final inbox = ReceivePort();
  setup.ready.send(inbox.sendPort);
  runWatchdog(
    inbox,
    silence: setup.silence,
    grace: setup.grace,
    onSilence: () {
      // To stderr rather than debugPrint: this runs microseconds before the
      // process stops existing, and debugPrint's own line-rate limiter can
      // hold a message back for later — and there is no later.
      try {
        stderr.writeln(
          '[watchdog] the main isolate has run nothing for ${setup.silence.inSeconds}s — ending the process',
        );
      } catch (_) {
        // Saying so is worth a try; it is not worth the exit that follows.
      }
      exit(setup.exitCode);
    },
  );
}
