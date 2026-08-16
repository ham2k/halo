// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

const _hamDbInfo = ExtensionInfo(key: 'hamdb', file: 'hamdb.js', core: false, name: 'HamDB', category: 'lookup');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> buildSettings(Map<String, Object> initial) async {
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

  group('SettingsService.consumeHamDbDisabledForLookupServiceMigration', () {
    test('an existing install is told to disable HamDB, once', () async {
      final settings = await buildSettings(profiledPrefs('KI2D'));
      expect(await settings.consumeHamDbDisabledForLookupServiceMigration(), isTrue);
      expect(await settings.consumeHamDbDisabledForLookupServiceMigration(), isFalse,
          reason: 'the decision is consumed — a second boot must not re-migrate');
    });

    test('a fresh install (never onboarded) is left alone', () async {
      final settings = await buildSettings({});
      expect(await settings.consumeHamDbDisabledForLookupServiceMigration(), isFalse);
    });

    test('is consumed even for a fresh install, so onboarding later cannot trigger a late migration', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
      expect(await settings.consumeHamDbDisabledForLookupServiceMigration(), isFalse);
      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');

      final reloaded = SettingsService(prefs, secureStorage: FakeSecureStorage());
      expect(await reloaded.consumeHamDbDisabledForLookupServiceMigration(), isFalse);
    });

    test('does not touch extensionOverrides itself', () async {
      final settings = await buildSettings(profiledPrefs('KI2D'));
      await settings.consumeHamDbDisabledForLookupServiceMigration();
      expect(settings.extensionOverrides, isEmpty, reason: 'applying the decision is ExtensionService\'s job');
    });
  });

  group('ExtensionService.migrateHamDbDisabledForLookupService', () {
    Future<ExtensionService> buildExtensions(SettingsService settings) async {
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions(const [_hamDbInfo]);
      HaLoServices(db, settings, extensions: extensions);
      return extensions;
    }

    test('an existing install gets HamDB switched off through the normal enable/disable path', () async {
      final settings = await buildSettings(profiledPrefs('KI2D'));
      final extensions = await buildExtensions(settings);

      await extensions.migrateHamDbDisabledForLookupService();

      expect(settings.extensionOverrides['hamdb'], isFalse);
      expect(settings.extensionDisabledSince.keys, contains('hamdb'),
          reason: 'going through ExtensionService must stamp the data-purge grace clock, not just the override');
    });

    test('a fresh install is left at its manifest default', () async {
      final settings = await buildSettings({});
      final extensions = await buildExtensions(settings);

      await extensions.migrateHamDbDisabledForLookupService();

      expect(settings.extensionOverrides.containsKey('hamdb'), isFalse);
      expect(settings.extensionDisabledSince.keys, isNot(contains('hamdb')));
    });

    test('a user who re-enables HamDB afterward keeps that choice on a later boot', () async {
      SharedPreferences.setMockInitialValues(profiledPrefs('KI2D'));
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
      final extensions = await buildExtensions(settings);
      await extensions.migrateHamDbDisabledForLookupService();
      expect(settings.extensionOverrides['hamdb'], isFalse);

      await extensions.setExtensionEnabled('hamdb', true);
      final reloadedSettings = SettingsService(prefs, secureStorage: FakeSecureStorage());
      final reloadedExtensions = await buildExtensions(reloadedSettings);

      await reloadedExtensions.migrateHamDbDisabledForLookupService();

      expect(reloadedSettings.extensionOverrides['hamdb'], isTrue,
          reason: 'migration must not re-run and clobber the choice');
    });

    test('preserves other extension overrides already on file', () async {
      final settings = await buildSettings({
        ...profiledPrefs('KI2D'),
        'extensionOverrides': jsonEncode({'qrz': false}),
      });
      final extensions = await buildExtensions(settings);

      await extensions.migrateHamDbDisabledForLookupService();

      expect(settings.extensionOverrides, {'qrz': false, 'hamdb': false});
    });
  });
}
