// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Core settings live in per-group JSON maps (`settings.general`,
// `settings.logging`, `settings.privacy`) that back the declarative
// settings registry. The migration from the original scalar prefs must be
// loss-free — a user's theme or logging toggles surviving an upgrade is
// the whole point — and unset values must fall back to the documented
// defaults (app-polo parity for the new logging/privacy keys).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('group storage', () {
    test('setSettingValue round-trips through the group map and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setSettingValue(SettingsService.loggingGroup, 'leftieMode', true);
      expect(settings.leftieMode, isTrue);
      expect(settings.settingValue(SettingsService.loggingGroup, 'leftieMode'), isTrue);
      expect(notified, 1);

      // Writing one key leaves the group's other keys alone.
      await settings.setSettingValue(SettingsService.loggingGroup, 'dxFlags', 'none');
      expect(settings.leftieMode, isTrue);
      expect(settings.dxFlags, DxFlags.none);
    });

    test('typed wrappers write to group storage', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());

      await settings.setThemeMode(ThemeMode.dark);
      await settings.setShowRSTFields(false);

      expect(settings.settingValue(SettingsService.generalGroup, 'themeMode'), 'dark');
      expect(settings.settingValue(SettingsService.loggingGroup, 'showRSTFields'), isFalse);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.showRSTFields, isFalse);
    });

    test('unset values fall back to defaults (app-polo parity)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.showRSTFields, isTrue);
      expect(settings.showQsoNumbers, isTrue);
      expect(settings.leftieMode, isFalse);
      expect(settings.fieldsOnTop, isFalse);
      expect(settings.dxFlags, DxFlags.dx);
      expect(settings.showBearing, isFalse);
      expect(settings.switchSentRcvd, isFalse);
      expect(settings.jumpAfterRST, isFalse);
      expect(settings.enabledBands, SettingsService.defaultBands);
      expect(settings.enabledModes, SettingsService.defaultModes);
      expect(settings.consentAppData, isFalse);
      expect(settings.consentOpData, isFalse);
    });

    test('updateSettingsGroup batches writes and extension groups enumerate', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      var notified = 0;
      settings.addListener(() => notified++);

      // One notify for the whole batch — the extension bridge's setSettings
      // writes many keys at once.
      await settings.updateSettingsGroup('extension_myext', {'foo': 1, 'bar': 'two'});
      expect(notified, 1);
      expect(settings.settingValue('extension_myext', 'foo'), 1);
      expect(settings.settingValue('extension_myext', 'bar'), 'two');

      // Merges over existing values instead of replacing the group.
      await settings.updateSettingsGroup('extension_myext', {'foo': 3});
      expect(settings.settingValue('extension_myext', 'foo'), 3);
      expect(settings.settingValue('extension_myext', 'bar'), 'two');

      // Extension groups enumerate for getSettings' read view; core groups
      // stay out of that map.
      await settings.setSettingValue(SettingsService.loggingGroup, 'leftieMode', true);
      expect(settings.extensionSettingsGroups(), {
        'extension_myext': {'foo': 3, 'bar': 'two'},
      });
    });

    test('corrupt group JSON reads as defaults, never throws', () async {
      SharedPreferences.setMockInitialValues({'settings.logging': 'not json {'});
      final settings = SettingsService(await SharedPreferences.getInstance());
      expect(settings.showRSTFields, isTrue);
      expect(settings.enabledBands, SettingsService.defaultBands);
      // Self-heals on the next write.
      await settings.setShowRSTFields(false);
      expect(settings.showRSTFields, isFalse);
    });
  });

  group('scalar-to-group migration', () {
    test('load() moves legacy scalar prefs into their groups and removes them', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'dark',
        'locale': 'es',
        'fontScale': 'larger',
        'distanceUnits': 'kilometers',
        'showRSTFields': false,
        'showQsoNumbers': false,
      });
      final settings = await SettingsService.load();

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.locale, 'es');
      expect(settings.fontScale, FontScale.larger);
      expect(settings.distanceUnits, DistanceUnits.kilometers);
      expect(settings.showRSTFields, isFalse);
      expect(settings.showQsoNumbers, isFalse);
      for (final legacy in ['themeMode', 'locale', 'fontScale', 'distanceUnits', 'showRSTFields', 'showQsoNumbers']) {
        expect(settings.prefs.containsKey(legacy), isFalse, reason: '$legacy should be removed');
      }
    });

    test('existing group values win over legacy scalars', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'light',
        'settings.general': '{"themeMode": "dark"}',
      });
      final settings = await SettingsService.load();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.prefs.containsKey('themeMode'), isFalse);
    });

    test('migration is a no-op on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      expect(settings.prefs.getString('settings.general'), isNull);
      expect(settings.prefs.getString('settings.logging'), isNull);
    });
  });
}
