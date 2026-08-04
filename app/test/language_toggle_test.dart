// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ⌘⇧L language hotkey (main.dart) toggles the locale between English and Spanish.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

Future<HaLoServices> makeServices({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
  return HaLoServices(db, settings, extensions: extensions);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => setReleaseNotesForTesting(const []));

  testWidgets('pressing Cmd+Shift+L toggles the app language/locale', (tester) async {
    final services = await makeServices();
    
    // Initial locale should be 'en'
    expect(services.settings.locale, 'en');

    await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
    await tester.pumpAndSettle();

    expect(LocaleSettings.currentLocale, AppLocale.en);

    // Simulate Cmd + Shift + L
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(services.settings.locale, 'es');
    expect(LocaleSettings.currentLocale, AppLocale.es);

    // Simulate Cmd + Shift + L again
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(services.settings.locale, 'en');
    expect(LocaleSettings.currentLocale, AppLocale.en);

    // Drain pending timers to avoid test errors
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
