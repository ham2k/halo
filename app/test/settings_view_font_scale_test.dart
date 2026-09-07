// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the Common Settings category reflects a font scale change made outside the panel (e.g. the keyboard shortcut in main.dart)',
    (tester) async {
      // The keyboard shortcut handler in main.dart calls
      // SettingsService.increaseFontScale() directly — it never goes
      // through the panel's own autosave path. Without a listener on
      // SettingsService, _SettingsGroupForm's cached elements (built once)
      // would never reflect that external change.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
      final services = HaLoServices(db, settings, extensions: extensions);

      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
      await tester.pumpAndSettle();

      // The registry's select fields render as icon-row list rows whose
      // subtitle is the current value's own name; the fontScale row reads
      // 'Normal' / 'Larger'.
      //
      // `.hitTestable()`: the same field is mounted twice — once in the open
      // Common Settings category, once in its own collapsed group's, which
      // stays in the tree (see _settingsSection).
      expect(find.text('Normal').hitTestable(), findsOneWidget);

      // Simulate the keyboard shortcut: it never touches the panel widget.
      await settings.increaseFontScale();
      await tester.pumpAndSettle();

      expect(find.text('Larger').hitTestable(), findsOneWidget);
      expect(find.text('Normal').hitTestable(), findsNothing);
    },
  );
}
