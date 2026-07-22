// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The home screen's quick search has no open operation, so an
// operation-scoped command typed there (SEED, NOTE, SPOT…) comes back from
// interpret as `{error: …}` — the bar must PRESENT that error, both while
// typing (debounced describe slot) and on Enter, and must leave the typed
// input in place instead of executing or clearing. Ordinary executable
// commands (DEVMODE) still clear the field and show their confirm text.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_view.dart';

/// Canned command interpretations — the real runtime's contract, without
/// booting a JS engine inside a fake-async widget test.
class _CannedCommandExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  int interpretCalls = 0;

  @override
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    interpretCalls++;
    final trimmed = input.trim().toUpperCase();
    // What the real SEED hook returns when interpret gets no operation.
    if (trimmed.startsWith('SEED')) return {'error': 'SEED needs an open operation'};
    if (trimmed == 'DEVMODE') {
      return {
        'describe': 'Activate developer mode?',
        'confirm': 'Developer mode activated',
        'commands': [
          {'updateSettings': {'developerMode': true}},
        ],
      };
    }
    // A recognized prefix still awaiting its (free-text) parameter — same
    // shape as the real RELOAD hook.
    if (trimmed == 'RELOAD') return {'describe': 'reload what?', 'expectsParams': true};
    // A command whose parameter is free prose, case and all — same shape
    // as the real NOTE hook.
    if (trimmed.startsWith('NOTE')) return {'describe': 'add a note', 'mixedCase': true};
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an operation-scoped command shows its error and keeps the input; executable ones still run', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = _CannedCommandExtensions();
    final services = HaLoServices(db, settings, extensions: extensions);
    addTearDown(db.close);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(body: HomeQuickLookup(services: services)),
      ),
    ));

    // Typing "SEED" surfaces the error through the debounced describe slot.
    await tester.enterText(find.byType(TextField), 'SEED');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('SEED needs an open operation'), findsOneWidget);

    // Enter must NOT clear the input (there's nothing to execute) and the
    // error stays up.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'SEED');
    expect(find.text('SEED needs an open operation'), findsOneWidget);

    // A context-independent command still executes: field cleared, confirm
    // text shown, and the action actually dispatched.
    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Activate developer mode?'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Developer mode activated'), findsOneWidget);
    expect(settings.developerMode, isTrue);

    // _submit() re-interprets with execute:true right before dispatching
    // (instead of trusting the debounce-time preview's `commands`), so
    // DEVMODE's execution should be the SEED preview call, the DEVMODE
    // preview call, and the DEVMODE execute call — three total, not two.
    expect(extensions.interpretCalls, 3);

    // Drain the confirm message's 5s auto-clear timer for the binding's
    // pending-timer invariant.
    await tester.pump(const Duration(seconds: 5));
  });

  group('hardening the field against stray spaces (issue #190)', () {
    Future<HaLoServices> makeServices() async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      return HaLoServices(db, settings, extensions: _CannedCommandExtensions());
    }

    Future<void> pumpLookup(WidgetTester tester, HaLoServices services) => tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(home: Scaffold(body: HomeQuickLookup(services: services))),
          ),
        );

    testWidgets('a plain space (no command in progress) is stripped, not inserted', (tester) async {
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'W1 AW');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW');
    });

    testWidgets('a command still awaiting its parameter keeps the separating space', (tester) async {
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'RELOAD');
      await tester.pump(const Duration(milliseconds: 200)); // retains expectsParams

      await tester.enterText(find.byType(TextField), 'RELOAD PARAM');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'RELOAD PARAM');

      await tester.pump(const Duration(milliseconds: 200)); // drain the next describe debounce
    });

    testWidgets('a mixedCase command keeps every space in its free-text parameter', (tester) async {
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'NOTE');
      await tester.pump(const Duration(milliseconds: 200)); // retains mixedCase

      await tester.enterText(find.byType(TextField), 'NOTE hello there');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'NOTE HELLO THERE');

      await tester.pump(const Duration(milliseconds: 200)); // drain the next describe debounce
    });
  });

  group('mobile numbers row on the quick lookup (issue #27)', () {
    Future<HaLoServices> makeServices({bool showNumbersRow = false}) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      if (showNumbersRow) {
        await settings.setSettingValue(SettingsService.loggingGroup, 'showNumbersRow', true);
      }
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      return HaLoServices(db, settings, extensions: _CannedCommandExtensions());
    }

    // The numbers row keys off the raw FlutterView inset (the Home Scaffold
    // doesn't resize, so MediaQuery keeps it); insets are physical px, so
    // scale by the pixel ratio pinned here. 300 logical px is a full keyboard.
    void raiseKeyboard(WidgetTester tester, {double logicalHeight = 300}) {
      tester.view.devicePixelRatio = 3.0;
      tester.view.viewInsets = FakeViewPadding(bottom: logicalHeight * 3.0);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> pumpHome(WidgetTester tester, HaLoServices services) => tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              // Matches the real Home Scaffold, so MediaQuery keeps the inset.
              home: Scaffold(resizeToAvoidBottomInset: false, body: HomeQuickLookup(services: services)),
            ),
          ),
        );

    Finder keyInRow(String glyph) => find.descendant(of: find.byType(NumberKeys), matching: find.text(glyph));

    testWidgets('appears above the keyboard only once the lookup field has focus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await pumpHome(tester, await makeServices(showNumbersRow: true));

        // The field doesn't autofocus, so nothing shows until it's tapped.
        expect(find.byType(NumberKeys), findsNothing);

        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(find.byType(NumberKeys), findsOneWidget);
        for (final d in ['0', '1', '9']) {
          expect(keyInRow(d), findsOneWidget);
        }
        // The empty field reads as numeric, so the extra key is ".".
        expect(keyInRow('.'), findsOneWidget);
        expect(keyInRow('/'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('stays hidden when the setting is off', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await pumpHome(tester, await makeServices(showNumbersRow: false));
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(find.byType(NumberKeys), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping a digit inserts it; the extra key becomes "/" for a callsign', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await pumpHome(tester, await makeServices(showNumbersRow: true));
        await tester.tap(find.byType(TextField));
        await tester.pump();

        await tester.tap(keyInRow('7'));
        await tester.pump();
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '7');

        // A partial callsign (letters, not just digits) flips the extra key.
        await tester.enterText(find.byType(TextField), 'W1AW');
        await tester.pump();
        expect(keyInRow('/'), findsOneWidget);
        expect(keyInRow('.'), findsNothing);

        await tester.tap(keyInRow('/'));
        await tester.pump();
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW/');

        // Drain the describe/lookup debounce timers the edits scheduled.
        await tester.pump(const Duration(milliseconds: 500));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
