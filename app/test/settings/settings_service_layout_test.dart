// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The layout-dimension store backs the resizable splits' persistence
// (docs/design/layouts.md): dotted keys under one JSON `layout` prefs key.
// Callers own the defaults, so an absent or corrupt store must read as
// "no preference" (null), never throw — a bad value would otherwise take
// down every root view at boot.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/rotator_panel_migration.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> makeSettings({Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    return SettingsService(await SharedPreferences.getInstance());
  }

  group('layoutDimension', () {
    test('round-trips per dotted key and notifies listeners', () async {
      final settings = await makeSettings();
      expect(settings.layoutDimension('home.leftColumn'), isNull);

      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setLayoutDimension('home.leftColumn', 512);
      await settings.setLayoutDimension('operation.leftColumn', 480.5);

      expect(settings.layoutDimension('home.leftColumn'), 512.0);
      expect(settings.layoutDimension('operation.leftColumn'), 480.5);
      expect(notified, 2);

      // Overwriting one key leaves the others alone.
      await settings.setLayoutDimension('home.leftColumn', 400);
      expect(settings.layoutDimension('home.leftColumn'), 400.0);
      expect(settings.layoutDimension('operation.leftColumn'), 480.5);
    });

    test('persists through the shared prefs store', () async {
      final settings = await makeSettings();
      await settings.setLayoutDimension('settings.leftColumn', 300);

      // A second service over the same store (≈ app relaunch) sees the value.
      final reloaded = SettingsService(await SharedPreferences.getInstance());
      expect(reloaded.layoutDimension('settings.leftColumn'), 300.0);
    });

    test('corrupt or non-numeric stored data reads as no preference', () async {
      final corrupt = await makeSettings(initial: {'layout': 'not json {'});
      expect(corrupt.layoutDimension('home.leftColumn'), isNull);
      // And the store self-heals on the next write.
      await corrupt.setLayoutDimension('home.leftColumn', 500);
      expect(corrupt.layoutDimension('home.leftColumn'), 500.0);

      final wrongType = await makeSettings(initial: {'layout': '{"home.leftColumn": "wide"}'});
      expect(wrongType.layoutDimension('home.leftColumn'), isNull);
    });
  });

  // The native Rotator panel is gone; a saved arrangement still naming it
  // would show the missing-panel tab where the operator's map was, and its
  // settings would start over.
  group('moveNativeRotatorPanels', () {
    test("moves every placement of the native Rotator panel, and its settings, onto ham2k-rotator's", () async {
      final settings = await makeSettings(
        initial: {
          'layout': jsonEncode({
            'operation.dock': {
              'tabs': ['logging', 'rotator#1', 'rotator#2', 'rotatorish'],
              'active': 'rotator#2',
            },
          }),
          'settingsPanel.rotator#1.rotator': jsonEncode('tower-uuid'),
          'settingsPanel.rotator#1.beamWidth': '45',
          'settingsPanel.rotator#1.theme': jsonEncode('gray'),
          'settingsPanel.rotator#2.rotator': jsonEncode('auto'),
          'settingsPanel.rotator#2.theme': jsonEncode('muted'),
        },
      );
      await moveNativeRotatorPanels(settings);

      expect(settings.layoutData('operation.dock'), {
        'tabs': ['logging', 'ext:ham2k-rotator:rotator#1', 'ext:ham2k-rotator:rotator#2', 'rotatorish'],
        'active': 'ext:ham2k-rotator:rotator#2',
      });
      final prefs = settings.prefs;
      expect(prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#1.rotator'), jsonEncode('tower-uuid'));
      // The extension keeps a width per antenna type, the native panel's being a beam's.
      expect(prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#1.beamWidth.beam'), '45');
      expect(prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#1.theme'), jsonEncode('gray'));
      // Automatic is the extension's own default.
      expect(prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#2.rotator'), isNull);
      expect(prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#2.theme'), jsonEncode('muted'));
    });

    test("a native placement whose number the extension's panel already holds takes the next free one", () async {
      final settings = await makeSettings(
        initial: {
          'layout': jsonEncode({
            'operation.dock': {
              'modules': ['rotator#1', 'ext:ham2k-rotator:rotator#1'],
            },
          }),
          'settingsPanel.rotator#1.theme': jsonEncode('gray'),
          'settingsPanel.ext:ham2k-rotator:rotator#1.theme': jsonEncode('teal'),
        },
      );
      await moveNativeRotatorPanels(settings);

      expect(settings.layoutData('operation.dock'), {
        'modules': ['ext:ham2k-rotator:rotator#2', 'ext:ham2k-rotator:rotator#1'],
      });
      expect(settings.prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#2.theme'), jsonEncode('gray'));
      expect(settings.prefs.getString('settingsPanel.ext:ham2k-rotator:rotator#1.theme'), jsonEncode('teal'));
    });
  });
}
