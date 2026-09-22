// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Backfill holds the device awake only while it MOVES. The server re-serves
// a stuck cursor with the same counts every loop delay, and a hold refreshed
// by every report would never let the device sleep — the fifteen-minute
// promise the setting makes would be broken by exactly the sync that takes
// longest.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/wake_lock_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a backfill report with the same counts as the last is not progress', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final wakeLock = WakeLockService(settings, apply: (_) async {});
    addTearDown(wakeLock.dispose);

    fakeAsync((async) {
      wakeLock.onBackfillProgress(const SyncProgress(backfilling: true, qsosTotal: 42, qsosLeft: 30));
      expect(wakeLock.activeReasons, contains(WakeReason.syncBackfill));

      // Past the idle window with the cursor stuck: the repeated report must
      // not start the window over.
      async.elapse(const Duration(minutes: 16));
      expect(wakeLock.activeReasons, isNot(contains(WakeReason.syncBackfill)));
      wakeLock.onBackfillProgress(const SyncProgress(backfilling: true, qsosTotal: 42, qsosLeft: 30));
      expect(wakeLock.activeReasons, isNot(contains(WakeReason.syncBackfill)), reason: 'the same counts again are repetition, not progress');

      wakeLock.onBackfillProgress(const SyncProgress(backfilling: true, qsosTotal: 42, qsosLeft: 20));
      expect(wakeLock.activeReasons, contains(WakeReason.syncBackfill));

      wakeLock.onBackfillProgress(const SyncProgress(backfilling: false, qsosTotal: 42, qsosLeft: 0));
      expect(wakeLock.activeReasons, isNot(contains(WakeReason.syncBackfill)), reason: 'backfill is over');
    });
  });

  test('the engine\'s progress reports reach the hold', () async {
    // The surface the status bar reads is also where the hold learns of
    // progress; a progress callback rewired to the status bar alone would
    // leave the device sleeping through a backfill.
    final HaLoHarness(:services) = await makeHaLoServices();
    addTearDown(services.wakeLock.dispose);

    services.syncEngine.onProgress!(const SyncProgress(backfilling: true, qsosTotal: 42, qsosLeft: 30));
    expect(services.wakeLock.activeReasons, contains(WakeReason.syncBackfill));
  });
}
