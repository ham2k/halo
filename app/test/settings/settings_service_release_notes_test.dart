// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// lastSeenReleaseVersion gates the startup release overlay
// (main.dart's _ReleaseOverlayGate) — it must default to "" (not
// kPublicVersion) so a fresh install shows the overlay for the current
// release, not just for the next one.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> makeSettings({Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    return SettingsService(await SharedPreferences.getInstance());
  }

  test('defaults to empty (never matches a real version) and round-trips', () async {
    final settings = await makeSettings();
    expect(settings.lastSeenReleaseVersion, '');

    await settings.setLastSeenReleaseVersion('26.8.0');
    expect(settings.lastSeenReleaseVersion, '26.8.0');
  });
}
