// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Callsign profiles back the app's operator identity: everything reads
// `activeProfile.operatorCall`, and until multi-profile support lands the
// active profile is always the `default` one (sync registers the device's
// account under that callsign).

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

    test('personal-info fields trim, notify, persist, and default to empty', () async {
      final settings = await makeSettings();
      var notified = 0;
      settings.addListener(() => notified++);

      expect(settings.activeProfile.operatorName, '');
      expect(settings.activeProfile.operatorEmail, '');
      expect(settings.activeProfile.operatorClub, '');
      expect(settings.activeProfile.operatorSection, '');

      await settings.setProfileFields(SettingsService.defaultProfileId, {
        'operatorName': '  Sebastian  ',
        'operatorEmail': 'sd@ham2k.com',
        'operatorClub': 'Ham2K Radio Club',
        'operatorSection': 'ENY',
      });
      // One notification for the whole dialog, not one per field — the panel
      // rebuilds once however many values the operator changed.
      expect(notified, 1);

      final reloaded = SettingsService(await SharedPreferences.getInstance());
      expect(reloaded.activeProfile.operatorName, 'Sebastian');
      expect(reloaded.activeProfile.operatorEmail, 'sd@ham2k.com');
      expect(reloaded.activeProfile.operatorClub, 'Ham2K Radio Club');
      expect(reloaded.activeProfile.operatorSection, 'ENY');
    });

    // The callsign and the personal-info fields share one JSON blob, so a
    // write through either setter must merge rather than replace.
    test('personal-info writes and the callsign do not clobber each other', () async {
      final settings = await makeSettings();
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
      await settings.setProfileFields(SettingsService.defaultProfileId, {'operatorName': 'Sebastian'});
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'W1AW');

      expect(settings.activeProfile.operatorCall, 'W1AW');
      expect(settings.activeProfile.operatorName, 'Sebastian');
    });

    // setProfileFields does NOT uppercase: the section's case is normalized at
    // the call site, alongside the keyboard hint that promises it.
    test('setProfileFields preserves case', () async {
      final settings = await makeSettings();
      await settings.setProfileFields(SettingsService.defaultProfileId, {'operatorName': 'de Kock'});
      expect(settings.activeProfile.operatorName, 'de Kock');
    });

    // The dialog omits the section row for a non-US/CA callsign, so its result
    // has no such key — that must carry the stored value through, not clear it.
    test('a field the dialog left out keeps its stored value', () async {
      final settings = await makeSettings();
      await settings.setProfileFields(SettingsService.defaultProfileId, {'operatorSection': 'ENY'});
      await settings.setProfileFields(SettingsService.defaultProfileId, {'operatorName': 'Sebastian'});
      expect(settings.activeProfile.operatorSection, 'ENY');
    });
  });
}
