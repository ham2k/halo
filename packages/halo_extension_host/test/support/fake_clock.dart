// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An async test body on one fake clock (docs/design/time.md §7).

import 'package:fake_async/fake_async.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/src/engine_runtime_io.dart' show extensionTimerClock;

/// Runs [body] inside `fakeAsync`, stepping the clock a millisecond at a time
/// until [body] finishes, with everything that reads a time on the one fake
/// clock: the host's own timers, the app clock, and — for an in-process host
/// started inside [body] — the kernel's extension timers. The body awaits
/// hooks, timers and its own `Future.delayed` waits as it would on the real
/// clock, and each lands exactly.
///
/// Only for a body whose async work all happens in this isolate: real I/O
/// cannot progress while the steps run, so a body waiting on a socket or a
/// background isolate runs into [limit] instead.
void runOnFakeClock(Future<void> Function(FakeAsync async) body, {Duration limit = const Duration(minutes: 10)}) {
  final followed = AppClock.followZoneClock;
  AppClock.followZoneClock = true;
  try {
    fakeAsync((async) {
      // Fake time stands still while zero-delay timers run, so an extension
      // timer chain its budget fails to stop would spin inside one `elapse`
      // and hang the suite. Past this many reads the clock throws instead:
      // the host's retry backs off a second, time moves again, and the test
      // fails on its own expectations. A chain the budget does stop takes a
      // few thousand.
      var reads = 0;
      extensionTimerClock = () {
        if (++reads > 100000) throw StateError('the extension timer clock was read $reads times: a timer chain is running away');
        return async.elapsed.inMicroseconds / 1000;
      };
      var done = false;
      Object? error;
      StackTrace? stack;
      body(async).then(
        (_) => done = true,
        onError: (Object e, StackTrace s) {
          error = e;
          stack = s;
          done = true;
        },
      );
      while (!done) {
        if (async.elapsed > limit) throw StateError('still running after $limit of fake time');
        async.elapse(const Duration(milliseconds: 1));
      }
      if (error != null) Error.throwWithStackTrace(error!, stack!);
    });
  } finally {
    extensionTimerClock = null;
    AppClock.followZoneClock = followed;
  }
}
