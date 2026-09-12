// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The awake hold is a battery decision the operator makes, so what these
// pin is when the OS wakelock is NOT taken: never without the setting, and
// never past fifteen idle minutes — the promise the setting's own
// description makes.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/wake_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late List<bool> applied;
  late WakeLockService wakeLock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    applied = [];
    wakeLock = WakeLockService(settings, apply: (enable) async => applied.add(enable));
  });

  tearDown(() => wakeLock.dispose());

  // Only the test that ELAPSES runs under fakeAsync; the rest assert the
  // state right after an action, on real timers, which is the safe direction
  // (docs/design/time.md §7) — and lets them await the settings store.

  test('with the setting off, activity never takes the wakelock', () {
    wakeLock.hold(WakeReason.logging).touch();
    wakeLock.hold(WakeReason.syncBackfill).touch();
    expect(applied, isEmpty);
    expect(wakeLock.held, isFalse);
  });

  test('a touch holds the device for fifteen idle minutes, and each touch starts that over', () async {
    await settings.setKeepDeviceAwake(true);
    fakeAsync((async) {
      final hold = wakeLock.hold(WakeReason.logging);
      hold.touch();
      expect(applied, [true]);

      // A second touch inside the window must RESTART it: a service that only
      // armed the first timer would let go at 15 minutes from the first
      // touch, mid-contact.
      async.elapse(const Duration(minutes: 10));
      hold.touch();
      async.elapse(const Duration(minutes: 10));
      expect(wakeLock.held, isTrue, reason: 'ten minutes after the LAST touch is inside the window');

      async.elapse(const Duration(minutes: 6));
      expect(wakeLock.held, isFalse, reason: 'sixteen minutes idle is past the window');
      expect(applied, [true, false]);
    });
  });

  test('one hold finishing does not drop the lock another hold still has', () async {
    await settings.setKeepDeviceAwake(true);
    final logging = wakeLock.hold(WakeReason.logging);
    final backfill = wakeLock.hold(WakeReason.syncBackfill);
    logging.touch();
    backfill.touch();
    backfill.release();
    expect(wakeLock.held, isTrue);
    expect(wakeLock.activeReasons, [WakeReason.logging]);

    logging.release();
    expect(wakeLock.held, isFalse);
    expect(applied, [true, false], reason: 'the lock toggles once per change, not once per call');
  });

  test('two holds for the same reason are two holds', () async {
    // A second OperationView pushed over a live one and popped again must
    // not take the lower view's hold with it — one slot per reason would.
    await settings.setKeepDeviceAwake(true);
    final lower = wakeLock.hold(WakeReason.logging);
    final upper = wakeLock.hold(WakeReason.logging);
    lower.touch();
    upper.touch();
    upper.release();
    expect(wakeLock.held, isTrue, reason: 'the lower view is still open');
    expect(lower.active, isTrue);
    lower.release();
    expect(wakeLock.held, isFalse);
  });

  test('turning the setting off releases at once; back on resumes the reasons still in their window', () async {
    await settings.setKeepDeviceAwake(true);
    wakeLock.hold(WakeReason.logging).touch();
    expect(wakeLock.held, isTrue);

    await settings.setKeepDeviceAwake(false);
    expect(wakeLock.held, isFalse);

    await settings.setKeepDeviceAwake(true);
    expect(wakeLock.held, isTrue, reason: 'the logging view is still open and inside its window');
    expect(applied, [true, false, true]);
  });

  test('a held lock is taken again on resume', () async {
    // A browser releases the lock when the tab is hidden and never gives it
    // back on its own; `_held` still says taken, so without this every touch
    // after a tab switch is a no-op and the screen sleeps mid-session.
    await settings.setKeepDeviceAwake(true);
    wakeLock.hold(WakeReason.logging).touch();
    wakeLock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    wakeLock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(applied, [true, true]);
  });

  test('resume with nothing held takes nothing', () async {
    await settings.setKeepDeviceAwake(true);
    wakeLock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(applied, isEmpty);
  });

  test('dispose lets go of an active hold', () async {
    await settings.setKeepDeviceAwake(true);
    wakeLock.hold(WakeReason.logging).touch();
    wakeLock.dispose();
    expect(applied, [true, false]);
    expect(wakeLock.held, isFalse);
  });
}
