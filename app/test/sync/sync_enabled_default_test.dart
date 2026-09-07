// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/dev_flags.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> build(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
  }

  /// What an install that has already been through onboarding looks like:
  /// the default profile carries an `operatorCall` key (even a blank one,
  /// from skipping onboarding).
  Map<String, Object> profiledPrefs(String call) => {
        'profiles': jsonEncode({
          'default': {'operatorCall': call},
        }),
      };

  group('seedSyncEnabledDefault', () {
    test('a new install starts with sync on', () async {
      final settings = await build({});
      await settings.seedSyncEnabledDefault();
      expect(settings.syncEnabled, isTrue);
    });

    test('a dev data sandbox keeps sync off, however empty its log looks', () async {
      // The trap this exists for: a sandbox has empty preferences, so it
      // reads as a brand-new install and would default to sync ON — while
      // the KEYCHAIN is keyed by bundle id and is not sandboxed at all, so
      // the launch is holding the developer's real device key. Sync on would
      // point an empty log at their actual account, with two processes
      // claiming one device key.
      addTearDown(() => debugDataDirectoryOverride = null);
      debugDataDirectoryOverride = '/tmp/halo-dev-data-test';

      final settings = await build({});
      await settings.seedSyncEnabledDefault();

      expect(settings.syncEnabled, isFalse);
    });

    test('an install that predates this default keeps sync off', () async {
      // The one that matters: their toggle was never written, and flipping
      // the bare default would start uploading their log on an app update
      // without anyone choosing it.
      final settings = await build(profiledPrefs('KI2D'));
      await settings.seedSyncEnabledDefault();
      expect(settings.syncEnabled, isFalse);
    });

    test('skipping onboarding still counts as having onboarded', () async {
      // An explicit empty callsign is a decision, not an absent key.
      final settings = await build(profiledPrefs(''));
      await settings.seedSyncEnabledDefault();
      expect(settings.syncEnabled, isFalse);
    });

    test('a deliberate choice survives, in either direction', () async {
      final off = await build({'syncEnabled': false});
      await off.seedSyncEnabledDefault();
      expect(off.syncEnabled, isFalse);

      final on = await build({...profiledPrefs('KI2D'), 'syncEnabled': true});
      await on.seedSyncEnabledDefault();
      expect(on.syncEnabled, isTrue);
    });

    test('seeding is idempotent, so turning sync off then relaunching keeps it off', () async {
      // It runs on every boot; a second pass must not re-apply the default
      // over the answer the first one recorded.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
      await settings.seedSyncEnabledDefault();
      await settings.setSyncEnabled(false);

      await SettingsService(prefs, secureStorage: FakeSecureStorage()).seedSyncEnabledDefault();
      expect(settings.syncEnabled, isFalse);
    });
  });
}
