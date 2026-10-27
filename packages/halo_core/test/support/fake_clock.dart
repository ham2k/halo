// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A test on one fake clock (docs/design/time.md §7): a driver for an async
// body, and the follow for a test that elapses its own.

import 'package:fake_async/fake_async.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// Puts the current test on the fake clock: every app-clock read, real or
/// travelled, follows the one `elapse` advances, until the test ends.
///
/// The way back is registered as teardowns of the test this is called from —
/// its body or its `setUp` — so no site restores the follow by hand or
/// forgets the clock: the follow goes back to what it was, and the app clock
/// is `reset`. `reset`, never a cancelling delta: deltas are cumulative, so a
/// zero one is a no-op that reads like a reset and leaves this process-wide
/// singleton three days out for every test after it.
void followFakeClock() {
  final followed = AppClock.followZoneClock;
  AppClock.followZoneClock = true;
  addTearDown(() => AppClock.followZoneClock = followed);
  addTearDown(AppClock.instance.reset);
}

/// Runs [body] inside `fakeAsync` with the app clock following the fake one,
/// stepping that clock a millisecond at a time until [body] finishes. The
/// body awaits timers, in-memory database work and its own `Future.delayed`
/// waits as it would on the real clock, and each lands exactly.
///
/// Only for a body whose async work all happens in this isolate: real I/O
/// cannot progress while the steps run, so a body waiting on a socket or a
/// background isolate runs into [limit] instead.
void runOnFakeClock(Future<void> Function(FakeAsync async) body, {Duration limit = const Duration(minutes: 10)}) {
  final followed = AppClock.followZoneClock;
  AppClock.followZoneClock = true;
  try {
    fakeAsync((async) {
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
    AppClock.followZoneClock = followed;
  }
}
