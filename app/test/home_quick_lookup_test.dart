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

  group('spaces and case in the command field (HALO-156)', () {
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

    /// Types [text] the way a fast operator does — one character at a time,
    /// with only a frame between them. No pump here may reach 150ms: the
    /// describe debounce restarts on every keystroke, so a test that pauses
    /// is testing the one case that always worked.
    Future<void> typeThrough(WidgetTester tester, String text) async {
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(find.byType(TextField), text.substring(0, i));
        await tester.pump();
      }
    }

    testWidgets('a command typed at speed keeps the space before its parameter', (tester) async {
      // The bug this group is named for. Nothing about a space may wait on
      // `interpret`: its answer lands 150ms after the keystroke at best, and
      // while someone types steadily the debounce that would ask restarts
      // every time and so never fires at all. A pause anywhere in the typing
      // hides it, which is what makes it read as intermittent — so this case
      // must never grow one.
      await pumpLookup(tester, await makeServices());

      await typeThrough(tester, 'RELOAD PARAM');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'RELOAD PARAM');

      await tester.pump(const Duration(milliseconds: 200)); // drain the describe debounce
    });

    testWidgets("a command's prose parameter typed at speed is not shouted", (tester) async {
      // Case rides on the same stale answer as the space, so fixing only the
      // space would leave REPORT filing "CRASH ON SAVE" as its description —
      // the text goes to a CaBo card verbatim, where nobody can unshout it.
      // Only the command word is uppercased, and that happens by position,
      // with nothing to wait for.
      await pumpLookup(tester, await makeServices());

      await typeThrough(tester, 'report crash on save');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'REPORT crash on save',
      );

      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a callsign is still uppercased, whole', (tester) async {
      // What the uppercase rule is FOR. A callsign holds no whitespace, so
      // "up to the first space" still covers all of it — including the
      // portable suffix past the slash. Typed in LOWER case deliberately:
      // every other callsign in this file is typed in capitals, so without
      // this one, deleting the uppercase formatter outright leaves the file
      // green.
      await pumpLookup(tester, await makeServices());

      await typeThrough(tester, 'w1aw/4');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW/4');

      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a space with nothing to separate is dropped, and a run of them collapses', (tester) async {
      // Not the interpretation talking — these two are true of the text
      // itself. A leading space separates nothing, and a doubled one is
      // invisible in a field this size, so it would leave a search failing
      // for a reason the operator cannot see.
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), ' ');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      await tester.enterText(find.byType(TextField), 'NOTE  hello   there');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'NOTE hello there',
      );

      await tester.pump(const Duration(milliseconds: 200));
    });

    test('a trailing space still finds the callsign', () async {
      // Why no formatter needs to strip a trailing space: the engine reads
      // the field through `trimmedText`, so one costs nothing — and one gets
      // typed, because Space advances focus in the logging panel and the
      // hand does it after a call out of muscle memory. Asserted on the
      // engine's input rather than the field's text: the trim is the whole
      // guarantee, and a formatter-level assertion would not see it.
      final services = await makeServices();
      final engine = CommandEngine(services: services, operationContext: () => null, runAction: (_, _) async {});
      addTearDown(engine.dispose);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      engine.attach(controller);

      controller.text = 'W1AW ';
      expect(engine.trimmedText, 'W1AW');
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

    testWidgets('whitespace that is not the space key still reaches the field', (tester) async {
      // The premise the collapse rule rests on. A single-line TextField
      // filters `\n` and NOTHING else, so a tab, a CR from a Windows paste
      // and macOS's Option-Space non-breaking space all arrive — and each
      // reads as a space to the eye while matching nothing.
      //
      // Asserted on a BARE field, deliberately: this is Flutter's behavior,
      // not ours, and the rule is wrong if it ever changes.
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TextField(controller: controller))));

      for (final probe in ['a\tb', 'a\rb', 'a b']) {
        await tester.enterText(find.byType(TextField), probe);
        await tester.pump();
        expect(controller.text, probe, reason: 'the field passes ${probe.codeUnits} through');
      }
      await tester.enterText(find.byType(TextField), 'a\nb');
      await tester.pump();
      expect(controller.text, 'ab', reason: 'the newline is the one it does filter');
    });

    test('every kind of whitespace collapses to one plain space', () {
      // Without this, a tab or a non-breaking space survives into the value:
      // invisible, matching no command pattern, and — sitting at index 0 —
      // making CommandWordCaseFormatter stop before it uppercases anything,
      // so a pasted "\tw1aw" stays lower case.
      String runThrough(String text) {
        var value = TextEditingValue(text: text);
        for (final formatter in commandFieldFormatters) {
          // Chained, as the framework chains them — each output is the next
          // one's input.
          value = formatter.formatEditUpdate(const TextEditingValue(text: ''), value);
        }
        return value.text;
      }

      expect(runThrough('\tw1aw'), 'W1AW');
      expect(runThrough(' report crash'), 'REPORT crash');
      expect(runThrough('report crashes\r\n\twhen I save'), 'REPORT crashes when I save');
      expect(runThrough('note\thi'), 'NOTE hi');
    });

    testWidgets("on mobile, a full stop in a command's parameter stays a full stop", (tester) async {
      // MobileDotToSlashFormatter rewrites "." to "/" whenever the text STARTS
      // callsign-shaped, which "REPORT …" and "NOTE …" both do — so on a phone
      // a filed report read "it crashes/ every time". It is bounded to the
      // first word now: a callsign holds no whitespace, so past that there is
      // nothing it could be correcting.
      //
      // These two bars are where that bites. The logging panel's call field
      // drops this formatter entirely once it accepts spaces (see its
      // `inputFormatters`), so the parameter never reaches it there.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpLookup(tester, await makeServices());

        await tester.enterText(find.byType(TextField), 'report it crashes. every time');
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'REPORT it crashes. every time',
        );

        // The correction the formatter exists for still happens, on the call.
        await tester.enterText(find.byType(TextField), 'K1ABC.P');
        await tester.pump();
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'K1ABC/P');

        await tester.pump(const Duration(milliseconds: 200));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('a leading space does not hide the callsign from the mobile "." rule', () {
      // Order, not behavior: MobileDotToSlashFormatter tests the START of the
      // value, so a leading space it has not seen dropped yet makes the text
      // read as not-a-callsign and the dot survives — after which the space
      // is stripped anyway and the operator is left holding "K1ABC.P". The
      // collapse pass has to run first.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        var value = const TextEditingValue(text: ' k1abc.p');
        for (final formatter in commandFieldFormatters) {
          value = formatter.formatEditUpdate(const TextEditingValue(text: ''), value);
        }
        expect(value.text, 'K1ABC/P');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('collapsing a space moves the caret with the text', () {
      // Dropping a character shifts every offset after it. Typing alone would
      // never catch this — the caret is at the end there, and the arithmetic
      // is only visible when the edit lands mid-value, which is what a paste
      // does. Get it wrong and the next keystroke is inserted in the wrong
      // place, or the framework asserts on an offset past the end.
      const formatter = CollapseWhitespaceFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: 'NOTE the  end'),
        // Two runs collapse, one before the caret and one after it.
        const TextEditingValue(
          text: 'NOTE  the  end',
          selection: TextSelection.collapsed(offset: 9), // right after "the"
        ),
      );
      expect(result.text, 'NOTE the end');
      expect(result.selection.baseOffset, 8);
    });

    testWidgets('a callsign typed over a command it does not know about is uppercased', (tester) async {
      // Select-all and type a call straight over a NOTE. A rule that
      // remembers the last interpretation keeps `mixedCase` alive past the
      // command it came from and leaves the call lowercase, with no pass left
      // to fix it; a positional rule cannot go stale, having nothing to
      // remember.
      await pumpLookup(tester, await makeServices());

      await tester.enterText(find.byType(TextField), 'NOTE hello');
      await tester.pump(const Duration(milliseconds: 200)); // long enough for an interpretation to land

      await typeThrough(tester, 'w1aw');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'W1AW');

      await tester.pump(const Duration(milliseconds: 200));
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
