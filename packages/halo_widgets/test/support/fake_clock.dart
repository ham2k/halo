// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A test on one fake clock (docs/design/time.md §7).

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

/// Puts the current test on the fake clock: every app-clock read, real or
/// travelled, follows the one `pump(duration)` and `elapse` advance, until
/// the test ends.
///
/// The way back is registered as teardowns of the test this is called from —
/// its body or its `setUp` — so no site restores the follow by hand or
/// forgets the clock: the follow goes back to what it was, and the app clock
/// is `reset`. `reset`, never a cancelling delta: deltas are cumulative, so a
/// zero one is a no-op that reads like a reset and leaves this process-wide
/// singleton three days out for every test after it. Never alongside
/// `tester.runAsync`, whose body reads the wall clock.
void followFakeClock() {
  final followed = AppClock.followZoneClock;
  AppClock.followZoneClock = true;
  addTearDown(() => AppClock.followZoneClock = followed);
  addTearDown(AppClock.instance.reset);
}
