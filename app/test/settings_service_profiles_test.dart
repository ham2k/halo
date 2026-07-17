// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Callsign profiles back the app's operator identity: everything reads
// `activeProfile.operatorCall`, and until multi-profile support lands the
// active profile is always the `default` one. The legacy scalar
// `operatorCall` pref must migrate into the default profile at load so an
// upgrade never loses the user's callsign (sync registers the device's
// account under it).

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> makeSettings({Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    return SettingsService(await SharedPreferences.getInstance());
  }

  group('profiles', () {
    test('the default profile is active until multi-profile support exists', () async {
      final settings = await makeSettings();
      expect(settings.activeProfileId, SettingsService.defaultProfileId);
      expect(settings.activeProfile.id, SettingsService.defaultProfileId);
      expect(settings.activeProfile.operatorCall, '');
    });

    test('setProfileOperatorCall normalizes, notifies, and persists', () async {
      final settings = await makeSettings();
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, ' ki2d ');
      expect(settings.activeProfile.operatorCall, 'KI2D');
      expect(notified, 1);

      // A second service over the same store (≈ app relaunch) sees the value.
      final reloaded = SettingsService(await SharedPreferences.getInstance());
      expect(reloaded.activeProfile.operatorCall, 'KI2D');
    });

    test('writing one profile leaves other profile data alone', () async {
      final settings = await makeSettings(initial: {'profiles': '{"club": {"operatorCall": "W1AW"}}'});
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');

      expect(settings.activeProfile.operatorCall, 'KI2D');
      final reloaded = SettingsService(await SharedPreferences.getInstance());
      expect(reloaded.prefs.getString('profiles'), contains('W1AW'));
    });

    test('corrupt profiles data reads as an empty profile, never throws', () async {
      final settings = await makeSettings(initial: {'profiles': 'not json {'});
      expect(settings.activeProfile.operatorCall, '');
      // And the store self-heals on the next write.
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
      expect(settings.activeProfile.operatorCall, 'KI2D');
    });
  });

  group('legacy operatorCall migration', () {
    test('load() moves the scalar pref into the default profile', () async {
      SharedPreferences.setMockInitialValues({'operatorCall': 'KI2D'});
      final settings = await SettingsService.load();

      expect(settings.activeProfile.operatorCall, 'KI2D');
      expect(settings.prefs.getString('operatorCall'), isNull);
    });

    test('an already-populated profile wins over the legacy pref', () async {
      SharedPreferences.setMockInitialValues({
        'operatorCall': 'OLD1AA',
        'profiles': '{"default": {"operatorCall": "KI2D"}}',
      });
      final settings = await SettingsService.load();

      expect(settings.activeProfile.operatorCall, 'KI2D');
      expect(settings.prefs.getString('operatorCall'), isNull);
    });

    test('an empty legacy pref is just cleaned up', () async {
      SharedPreferences.setMockInitialValues({'operatorCall': ''});
      final settings = await SettingsService.load();

      expect(settings.activeProfile.operatorCall, '');
      expect(settings.prefs.getString('operatorCall'), isNull);
    });
  });
}
