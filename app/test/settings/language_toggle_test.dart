// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ⌘⇧L language hotkey (main.dart) toggles the locale between English and Spanish.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> makeServices({Map<String, Object> prefs = const {}}) async {
  return (await makeHaLoServices(prefs: prefs)).services;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setReleaseNotesForTesting(const []);
    setTesterNotesForTesting(const []);
  });

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
