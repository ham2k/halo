// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The home screen's quick search has no open operation, so an
// operation-scoped command typed there (SEED, NOTE, SPOT…) comes back from
// interpret as `{error: …}` — the bar must PRESENT that error, both while
// typing (debounced describe slot) and on Enter, and must leave the typed
// input in place instead of executing or clearing. Ordinary executable
// commands (DEVMODE) still clear the field and show their confirm text.

import 'dart:async';

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
import 'package:ham2k_logger/views/command_engine.dart';
import 'package:ham2k_logger/views/home_view.dart';

/// Canned command interpretations — the real runtime's contract, without
/// booting a JS engine inside a fake-async widget test.
class _CannedCommandExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  int interpretCalls = 0;

  /// Execute-time calls only — what a non-idempotent command actually runs.
  int executeCalls = 0;

  /// Held open by a test that needs to press Enter again mid-flight.
  Completer<void>? executeGate;

  @override
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    interpretCalls++;
    if (execute) {
      executeCalls++;
      if (executeGate != null) await executeGate!.future;
    }
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

  testWidgets('the field keeps focus after executing a command, so the next one can be typed right away', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final services = HaLoServices(db, settings, extensions: _CannedCommandExtensions());
    addTearDown(db.close);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(body: HomeQuickLookup(services: services)),
      ),
    ));

    // Checked on the field's own FocusNode, not FocusManager.primaryFocus:
    // unfocus() falls back to the enclosing FocusScopeNode, which then IS
    // primaryFocus and trivially reports hasFocus — that would make this
    // assertion pass even if the field itself lost focus.
    final focusNode = tester.widget<TextField>(find.byType(TextField)).focusNode!;

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), 'DEVMODE');
    await tester.pump(const Duration(milliseconds: 200));
    // The soft keyboard's "done"/"go"/"search" action would, by default,
    // unfocus the field before onSubmitted even runs — the field must not
    // rely on that path, or every executed command would dismiss the
    // keyboard and force a re-tap to type the next one.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(focusNode.hasFocus, isTrue);

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

    test('a second Enter during an execute in flight does not run it twice', () async {
      // A command's execute call can be a non-idempotent network write (REPORT
      // files a CaBo card), and nothing visible happens while it is in flight,
      // so an impatient second Enter is the expected human behaviour. Driven
      // against the engine directly: holding the first submit un-awaited is
      // the whole point, and a widget test forbids that.
      final services = await makeServices();
      final extensions = services.extensions as _CannedCommandExtensions;
      final engine = CommandEngine(
        services: services,
        operationContext: () => null,
        runAction: (_, _) async {},
      );
      addTearDown(engine.dispose);
      final controller = TextEditingController(text: 'DEVMODE');
      addTearDown(controller.dispose);
      engine.attach(controller);

      extensions.executeGate = Completer<void>();
      final first = engine.submit();
      final second = await engine.submit(); // impatient retry, while the first is in flight
      expect(second, isFalse);
      expect(extensions.executeCalls, 1);

      extensions.executeGate!.complete();
      expect(await first, isTrue);
      expect(extensions.executeCalls, 1);
    });

    testWidgets("a command's confirmation shows on the field, and only there", (tester) async {
      // A confirmation is a transient message on the field's own line and
      // nothing more — it self-clears after five seconds and leaves no notice
      // behind. Commands run from here are routine (band, mode, DEVMODE); a
      // durable post-it per command would stack over the footer and push real
      // notices out of the capped history.
      final services = await makeServices();
      await pumpLookup(tester, services);

      await tester.enterText(find.byType(TextField), 'DEVMODE');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Developer mode activated'), findsOneWidget);
      expect(services.statusBar.activeNotices, isEmpty);

      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Developer mode activated'), findsNothing);
      expect(services.statusBar.activeNotices, isEmpty);
    });

    test('a command that ran while the field moved on still says so', () async {
      // The staleness bail protects text the operator typed during the await —
      // it must not also swallow the outcome of a command that already RAN. For
      // REPORT the POST carries no idempotency key, so an operator who sees no
      // trace of the first submission presses Enter again and files a second
      // card, and the message line is the ONLY place they can learn otherwise.
      // Driven against the engine directly for the same reason as the
      // double-submit case above.
      final services = await makeServices();
      final extensions = services.extensions as _CannedCommandExtensions;
      final engine = CommandEngine(
        services: services,
        operationContext: () => null,
        runAction: (_, _) async {},
      );
      addTearDown(engine.dispose);
      final controller = TextEditingController(text: 'DEVMODE');
      addTearDown(controller.dispose);
      engine.attach(controller);

      extensions.executeGate = Completer<void>();
      final submitted = engine.submit();
      // Park on the GATED call, not the describe-time interpret before it —
      // editing the field earlier trips the first staleness bail instead, and
      // the command never runs, which is not the case under test.
      await pumpEventQueue();
      expect(extensions.executeCalls, 1);

      controller.text = 'DEVMODE!'; // the operator keeps typing while it flies
      extensions.executeGate!.complete();

      expect(await submitted, isFalse); // stale: the field is the operator's now
      expect(controller.text, 'DEVMODE!'); // ...so it is left exactly as typed
      expect(engine.message, 'Developer mode activated');
      expect(engine.isConfirmation, isTrue);
    });

    test('a description pasted onto a new line is still the same command', () async {
      // REPORT matches on `\s+` and exists to take pasted multi-line text, so
      // the command word cannot end at a literal space alone: reading
      // "NOTE\nhello" as the word "NOTE\nHELLO" makes it a DIFFERENT command
      // from the one retained, revokes mixedCase, and puts the uppercase
      // formatter back over prose the operator pasted verbatim.
      final services = await makeServices();
      final engine = CommandEngine(
        services: services,
        operationContext: () => null,
        runAction: (_, _) async {},
      );
      addTearDown(engine.dispose);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      engine.attach(controller);

      controller.text = 'NOTE';
      await Future.delayed(const Duration(milliseconds: 200)); // let the describe debounce retain it
      expect(engine.commandMixedCase, isTrue);

      controller.text = 'NOTE\nhello there';
      expect(engine.commandMixedCase, isTrue);
      controller.text = 'NOTE\thello there';
      expect(engine.commandMixedCase, isTrue);
    });

    test('a callsign replacing a command awaiting parameters loses its spaces', () async {
      // The other half of the same staleness trap, on the other flag reading
      // the same retained map: RELOAD's `expectsParams` keeps the space filter
      // off, and the debounce that would revise it never fires while someone
      // types steadily — so a call typed straight over it would keep a space.
      final services = await makeServices();
      final engine = CommandEngine(
        services: services,
        operationContext: () => null,
        runAction: (_, _) async {},
      );
      addTearDown(engine.dispose);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      engine.attach(controller);

      controller.text = 'RELOAD';
      await Future.delayed(const Duration(milliseconds: 200));
      expect(engine.commandExpectsParams, isTrue);

      controller.text = 'W1'; // selected all, typing a callsign over it
      expect(engine.commandExpectsParams, isFalse);
    });

    test('a dialog closed mid-flight resumes without touching the disposed field', () async {
      // The ⌘K route pops on Esc or a barrier tap, neither gated on a submit in
      // flight, and an execute-time interpret has 30 seconds to run. The engine
      // and the controller are both disposed on the way out, so resuming into
      // the field trips ChangeNotifier's use-after-dispose assert — which in a
      // test is a thrown error, and in a debug build a red screen over a
      // command that actually succeeded.
      final services = await makeServices();
      final extensions = services.extensions as _CannedCommandExtensions;
      final engine = CommandEngine(
        services: services,
        operationContext: () => null,
        runAction: (_, _) async {},
      );
      final controller = TextEditingController(text: 'DEVMODE');
      engine.attach(controller);

      extensions.executeGate = Completer<void>();
      final submitted = engine.submit();
      await pumpEventQueue();
      expect(extensions.executeCalls, 1);

      engine.dispose(); // the operator hits Esc while the write is in flight
      controller.dispose();
      extensions.executeGate!.complete();

      // Resolving at all is the assertion: without the guard this throws
      // "A TextEditingController was used after being disposed" out of the
      // resumed _submit, and `false` says nothing was written to the field.
      expect(await submitted, isFalse);
      expect(extensions.executeCalls, 1); // ...and the command still ran exactly once
    });

    testWidgets('a callsign typed in lower case is still uppercased', (tester) async {
      // The other direction of the mixedCase guard. Without a case that types
      // LOWER case, deleting the uppercase formatter outright leaves this file
      // green — every other callsign case here is already typed in capitals.
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'w1aw');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW');

      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a callsign typed straight after a mixedCase command is still uppercased', (tester) async {
      // The retained interpretation is only revised inside the describe
      // debounce, which restarts on every keystroke — so typing through
      // without a pause leaves `mixedCase` stale from the previous command.
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'NOTE hello');
      await tester.pump(const Duration(milliseconds: 200)); // retains mixedCase

      // Keystroke by keystroke, with no pause long enough to re-interpret —
      // the formatter sees the PREVIOUS text, so the guard has to notice the
      // command word changing rather than waiting for a fresh interpretation.
      for (final typed in ['w', 'w1', 'w1a', 'w1aw']) {
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
      }
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW');

      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a mixedCase command keeps every space in its free-text parameter', (tester) async {
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'NOTE');
      await tester.pump(const Duration(milliseconds: 200)); // retains mixedCase

      await tester.enterText(find.byType(TextField), 'NOTE hello there');
      await tester.pump();
      // Case as typed, not just the spaces: a mixedCase command's parameter is
      // the operator's own prose, and this bar files bug reports (REPORT) as
      // well as notes. Uppercasing it here reaches the filed card verbatim.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'NOTE hello there');

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

    /// The field publishes its numbers row rather than drawing it — the app's
    /// `StatusBarOverlay` draws it below the status footer and directly on the
    /// keyboard. The `ValueListenableBuilder` here stands in for the overlay so
    /// these tests still exercise the row end to end (publish → render → tap).
    Future<void> pumpHome(WidgetTester tester, HaLoServices services) => tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              // Matches the real Home Scaffold, so MediaQuery keeps the inset.
              home: Scaffold(
                resizeToAvoidBottomInset: false,
                body: Column(
                  children: [
                    Expanded(child: HomeQuickLookup(services: services)),
                    ValueListenableBuilder<KeyboardAccessorySpec?>(
                      valueListenable: services.keyboardAccessory,
                      builder: (context, spec, _) => spec == null
                          ? const SizedBox.shrink()
                          : NumberKeys(
                              onKey: spec.onKey,
                              extraKey: spec.extraKey,
                              vibrate: spec.vibrate,
                              backgroundColor: Color(spec.backgroundColor),
                              foregroundColor: Color(spec.foregroundColor),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    Finder keyInRow(String glyph) => find.descendant(of: find.byType(NumberKeys), matching: find.text(glyph));

    /// Publishing lands after the frame, so the row appears one frame after
    /// whatever changed it.
    Future<void> pumpRow(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets('appears above the keyboard only once the lookup field has focus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await pumpHome(tester, await makeServices(showNumbersRow: true));

        // The field doesn't autofocus, so nothing shows until it's tapped.
        expect(find.byType(NumberKeys), findsNothing);

        await tester.tap(find.byType(TextField));
        await pumpRow(tester);

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
        await pumpRow(tester);

        await tester.tap(keyInRow('7'));
        await tester.pump();
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '7');

        // A partial callsign (letters, not just digits) flips the extra key.
        await tester.enterText(find.byType(TextField), 'W1AW');
        await pumpRow(tester);
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
