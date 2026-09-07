// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The half of the preferences repair the operator can see. A launch that
// quarantined their settings file and started from defaults looks exactly
// like a launch that went fine — the app comes up, and every setting they
// ever chose is simply gone. The notice is the only thing that says so, and
// it is posted a hundred-odd boot steps after the repair decided it, so it
// is worth proving the value actually survives the trip.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/app_storage.dart';
import '../support/halo_test_support.dart';

Future<HaLoServices> _services() async => (await makeHaLoServices()).services;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a launch that repaired nothing says nothing', () async {
    final services = await _services();
    showPreferencesRecoveryNotice(services, PreferencesRecovery.none);
    expect(services.statusBar.activeNotices, isEmpty);
  });

  test('a restore and a reset are told apart, because what was lost differs', () async {
    final services = await _services();

    showPreferencesRecoveryNotice(services, PreferencesRecovery.restoredFromBackup);
    expect(services.statusBar.activeNotices.single.title, t.notices.preferencesRestoredTitle);

    showPreferencesRecoveryNotice(services, PreferencesRecovery.reset);
    // One notice for both would be the easy mistake, and the wrong one: a
    // restore costs the operator their last session, a reset costs them
    // everything, and only the second is worth going and checking on.
    expect(services.statusBar.activeNotices.single.title, t.notices.preferencesResetTitle);
  });
}
