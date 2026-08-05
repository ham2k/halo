// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-151: the last mile of SET/SHOW/HIDE — pressing Enter.
//
// Everything up to `handleCommandAction` is covered elsewhere: the hook
// resolves the setting (settings_command_test), the actions reach dispatch
// (logging_controls_test), and the dialog renders and commits
// (settings_target_dialog_test). This is the seam between them, where a
// command can interpret perfectly, describe perfectly, clear the field, print
// its confirmation — and do nothing at all.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/command_dialog.dart';
import 'package:ham2k_logger/views/home_view.dart';

/// Returns the settings-command interpretations for the two typed inputs this
/// file exercises — the real hook's shapes, without booting a JS engine.
class _SettingsCommandExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  @override
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    switch (input.trim().toUpperCase()) {
      // The bare verb, as the real hooks answer it: a prefix the operator is
      // still typing is recognized but not runnable, which is what keeps Enter
      // from logging the text as a callsign.
      case 'SET':
      case 'SHOW':
        return {'expectsParams': true, 'mixedCase': true};
      case 'SET RST':
        return {
          'mixedCase': true,
          'describe': 'Open Default Report…',
          'commands': [
            {
              'openSettings': {
                'keys': ['defaultReport'],
                'title': 'Default Report',
              },
            },
          ],
        };
      case 'SHOW GRID':
        return {
          'mixedCase': true,
          'describe': 'Change Show Grid Field to On?',
          'confirm': 'Show Grid Field set to On',
          'commands': [
            {
              'updateSetting': {'key': 'showGridField', 'value': true},
            },
          ],
        };
      default:
        return null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return HaLoServices(db, settings, extensions: _SettingsCommandExtensions());
  }

  /// The Home quick-lookup bar, inside a MaterialApp wired to the app's own
  /// [navigatorKey] — which `handleCommandAction`'s openSettings case needs a
  /// context from, exactly as the real app provides one.
  Future<void> pumpHomeBar(WidgetTester tester, HaLoServices services) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(body: HomeQuickLookup(services: services)),
      ),
    ));
  }

  /// Types [verb], lets it interpret, then appends the rest — the way an
  /// operator types, so the describe debounce sees each stage. The assertion
  /// on the field's contents afterwards is the guard: a formatter that ate the
  /// separator would leave the command matching nothing, which looks exactly
  /// like the bug being tested for rather than like a broken fixture.
  Future<void> submit(WidgetTester tester, String verb, String rest) async {
    final field = find.byType(TextField);
    await tester.enterText(field, verb);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(field, '$verb $rest');
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<TextField>(field).controller!.text,
      '$verb $rest',
      reason: 'the space must have survived the formatter, or this test is not exercising the command at all',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('Enter on a bare-name SET opens the settings dialog', (tester) async {
    final services = await buildServices();
    await pumpHomeBar(tester, services);

    await submit(tester, 'SET', 'RST');

    expect(find.text(t.settings.logging.defaultReport.title), findsWidgets,
        reason: 'the whole point of a bare SET is reaching that setting — describing it and then doing '
            'nothing on Enter is the same as having no command');
  });

  testWidgets('Enter on a SET with a value writes it', (tester) async {
    final services = await buildServices();
    await pumpHomeBar(tester, services);
    expect(services.settings.showGridField, isFalse);

    await submit(tester, 'SHOW', 'GRID');

    expect(services.settings.showGridField, isTrue,
        reason: 'the confirmation is printed by the hook regardless, so a write that never happens is invisible');
  });

  testWidgets('the settings dialog survives the ⌘K palette closing itself behind it', (tester) async {
    // The palette closes on execute with `Navigator.pop`, which removes the
    // TOP route — and by then the settings dialog this command opened IS the
    // top route. Nothing about the command looks wrong when this goes wrong:
    // the preview reads correctly, Enter is accepted, and the dialog that
    // opens is closed again in the same frame.
    final services = await buildServices();
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommandDialog(context, services),
              child: const Text('open palette'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open palette'));
    await tester.pumpAndSettle();

    await submit(tester, 'SET', 'RST');

    expect(find.text(t.settings.logging.defaultReport.title), findsWidgets,
        reason: 'the setting the command named must still be on screen after the palette closes');
    expect(find.byType(CommandDialog), findsNothing,
        reason: 'the palette must still dismiss itself — closing the right route, not simply failing to close');
  });
}
