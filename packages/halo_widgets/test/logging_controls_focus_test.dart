// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Moving between the panel's fields: Space and Tab advancing, the arrow keys
// at a value's edges, the entry row as a loop, where focus falls back to,
// the keyboard path across the secondary controls, and the widths the row
// gives each field.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('mobile "." to "/" autocorrect', () {
    // debugDefaultTargetPlatformOverride must be back to null before the
    // test body returns — the test framework's invariant check runs right
    // after, ahead of any tearDown/addTearDown callback — hence try/finally
    // around each test instead of a shared setUp/tearDown.
    testWidgets('on mobile, "." becomes "/" once the text looks like a callsign', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(host());

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC.P');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);

        final logged = await waitForQsos(tester, 1);
        expect(logged, hasLength(1));
        expect(logged.single.theirCall, 'K1ABC/P');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('on mobile, a digit-only prefix keeps its "." — frequency entry is unaffected', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(host());

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14.285');
        await tester.pump();

        final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
        expect(callField.controller!.text, '14.285');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a digit-then-letter prefix (e.g. a Japanese-style call) also converts', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(host());

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), '7K4ABC.QRP');
        await tester.pump();

        final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
        expect(callField.controller!.text, '7K4ABC/QRP');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('a leading "." converts only when a letter or another separator follows', () {
      // The mistyped "/" can open a call too — a suffix typed on its own, or
      // the "//" of a prefix not yet known. What must NOT move is a lone "."
      // or one before a digit: that is a frequency being typed, and rewriting
      // it to "/285" as the operator reaches for 14.285 is worse than the
      // suffix it would have fixed. The pairs below straddle exactly that line
      // — flipping the rule to "any leading dot" breaks the last two.
      String run(String text) => MobileDotToSlashFormatter()
          .formatEditUpdate(const TextEditingValue(text: ''), TextEditingValue(text: text))
          .text;

      expect(run('.P'), '/P');
      expect(run('..P'), '//P');
      expect(run('..'), '//');
      expect(run('.'), '.');
      expect(run('.285'), '.285');
      // The discriminator is the PREFIX, not where the period sits — a period
      // further in converts happily when a call opens the text ("K1ABC.P",
      // above). Read it as "a period is safe after a digit" and the guard
      // simplifies into a regression.
      expect(run('14.2P'), '14.2P');
      // The GHz band designations (radio-commands' parseGigBandCommand) ride on the
      // same rule, and match the dotted spelling only: rewrite these and "1.2G" reaches
      // the command as "1/2G" and is read as a callsign instead of the 23cm band.
      expect(run('1.2G'), '1.2G');
      expect(run('5.7GHZ'), '5.7GHZ');
    });

    test('a leading "/" keeps later periods converting', () {
      // Every keystroke re-runs this on text the PREVIOUS one already
      // rewrote, so a call that opens with a slash is this formatter's own
      // output: gate the prefix on "." alone and "//KI..KN" stops converting
      // the moment its leading ".." becomes "//".
      String run(String text) => MobileDotToSlashFormatter()
          .formatEditUpdate(const TextEditingValue(text: ''), TextEditingValue(text: text))
          .text;

      expect(run('//KI..KN'), '//KI//KN');
      expect(run('/P.QRP'), '/P/QRP');
      // A suffix-first call reaches "/P" one keystroke at a time too, so the
      // conversion has to survive its own output at every length.
      expect(run('/P'), '/P');
      expect(run('/P.'), '/P/');
      // The digit rule holds after a slash exactly as it does after a period
      // — the prefix decides, and it never reads a digit as a call. Pin it on
      // text that HOLDS a period, or the early "no period, nothing to do"
      // return answers and the prefix is never consulted.
      expect(run('/2.85'), '/2.85');
    });
  });

  testWidgets('off mobile, "." in the call field is left alone', (tester) async {
    // Under FLUTTER_TEST, defaultTargetPlatform defaults to android unless
    // overridden — force a desktop platform to exercise the non-mobile path.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC.P');
      await tester.pump();

      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.controller!.text, 'K1ABC.P');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // The panel publishes this row rather than drawing it (the app draws it below
  // the status footer, on top of the keyboard — see KeyboardAccessoryController),
  // and publishing lands after the frame so it cannot notify a listening
  // ancestor mid-build. So the row appears ONE FRAME after whatever changed it:
  // [pumpRow] is that frame, and any assertion about the row's contents needs it.
  group('mobile numbers row (issue #27)', () {
    Finder keyInRow(String glyph) =>
        find.descendant(of: find.byType(NumberKeys), matching: find.text(glyph));

    Future<void> pumpRow(WidgetTester tester) async {
      await tester.pump(); // runs the publish
      await tester.pump(); // renders what it published
    }

    testWidgets('shows above the keyboard on mobile when enabled and a field has focus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true)));
        // Focus is explicit: mobile without a hardware keyboard starts with
        // no field focused, and the row needs "a field has focus" to show.
        await tester.tap(find.widgetWithText(TextField, 'Their call'));
        await pumpRow(tester);
        expect(find.byType(NumberKeys), findsOneWidget);
        // The full digit set is there…
        for (final d in ['0', '1', '5', '9']) {
          expect(keyInRow(d), findsOneWidget);
        }
        // …and the empty call field reads as numeric, so the extra key is ".".
        expect(keyInRow('.'), findsOneWidget);
        expect(keyInRow('/'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('is hidden when the setting is off', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: false)));
        await tester.pump();
        expect(find.byType(NumberKeys), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('is hidden while the keyboard is down', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // No raiseKeyboard — the keyboard is down.
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true)));
        await tester.pump();
        expect(find.byType(NumberKeys), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('stays hidden for the hardware-keyboard accessory bar, not a full keyboard', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // iOS raises only a ~50px shortcuts bar when a hardware keyboard is
        // attached — that bumps viewInsets, but it isn't a virtual keyboard,
        // so the numbers row (redundant with physical number keys) stays away.
        raiseKeyboard(tester, logicalHeight: 50);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true)));
        await tester.pump();
        expect(find.byType(NumberKeys), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('never shows off mobile, even with the keyboard up', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true)));
        await tester.pump();
        expect(find.byType(NumberKeys), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping a digit inserts it at the focused field', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true)));
        await tester.tap(find.widgetWithText(TextField, 'Their call')); // mobile starts unfocused
        await pumpRow(tester);

        await tester.tap(keyInRow('5'));
        await tester.pump();
        await tester.tap(keyInRow('9'));
        await tester.pump();

        final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
        expect(callField.controller!.text, '59');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('extra key is "/" while composing a callsign, "." in a numeric field', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true)));

        // A partial callsign in the (focused) call field → "/".
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await pumpRow(tester);
        expect(keyInRow('/'), findsOneWidget);
        expect(keyInRow('.'), findsNothing);

        // Tapping it appends the slash the mobile keyboard buries a layer down.
        await tester.tap(keyInRow('/'));
        await tester.pump();
        final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
        expect(callField.controller!.text, 'W1AW/');

        // Moving focus to the numeric Sent field flips the extra key to ".".
        await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
        await pumpRow(tester);
        expect(keyInRow('.'), findsOneWidget);
        expect(keyInRow('/'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the extra key can be turned off', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(prefs: LoggingPreferences(showNumbersRow: true, showExtraInNumbersRow: false)));
        await tester.tap(find.widgetWithText(TextField, 'Their call')); // mobile starts unfocused
        await pumpRow(tester);
        expect(find.byType(NumberKeys), findsOneWidget);
        expect(keyInRow('.'), findsNothing);
        expect(keyInRow('/'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('space advances focus call → sent → rcvd → call', (tester) async {
    await tester.pumpWidget(host());

    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW', reason: 'space must not clear the call');
    expect(field('Sent').focusNode!.hasFocus, isTrue);
    // Cursor placed at the end on focus, not selecting the default RST.
    expect(field('Sent').controller!.selection.isCollapsed, isTrue);
    expect(field('Sent').controller!.selection.baseOffset, field('Sent').controller!.text.length);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue);
    // Cursor placed at the end on refocus, not selecting the call — a stray
    // keystroke right after cycling back shouldn't wipe out what's typed.
    expect(field('Their call').controller!.selection.isCollapsed, isTrue);
    expect(field('Their call').controller!.selection.baseOffset, field('Their call').controller!.text.length);
  });

  testWidgets('space cycles through contest exchange fields, not just the built-in ones', (tester) async {
    // A contest exchange is a PRIMARY field, so it takes its turn in the same
    // keyboard cycle as Sent/Rcvd — an operator running a contest never leaves
    // the keyboard, and a field that Tab reaches but Space skips strands them
    // mid-QSO. `_advancePrimaryFocus` listed these from the start; Space's own
    // caller had a separate hardcoded list that didn't, so they cycled on Tab
    // and sat inert on Space.
    const controls = [
      {
        'key': 'cqwpx/ourSerial',
        'label': 'Our #',
        'icon': 'flag-checkered',
        'input': {
          'kind': 'serial',
          'refType': 'cqwpx',
          'field': 'ourSerial',
          'sequence': {'key': 'serial'},
        },
      },
      {
        'key': 'cqwpx/theirSerial',
        'label': 'Their #',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'cqwpx', 'field': 'theirSerial', 'numeric': true},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: running(['cqwpx']),
            qsosRepository: qsos,
          ),
          radio: baseRadio(),
          activities: ActivityHooks(
            activityControls: controls,
          ),
        ),
      ),
    ));
    await tester.pump();

    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // Call → Sent → Rcvd, as before.
    for (final label in ['Sent', 'Rcvd']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field(label).focusNode!.hasFocus, isTrue, reason: 'space should reach $label');
    }

    // …then the exchanges, in declared order, before wrapping to Call.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Our #').focusNode!.hasFocus, isTrue, reason: 'space advances Rcvd → Our #');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their #').focusNode!.hasFocus, isTrue,
        reason: 'space advances Our # → Their # — a serial is not skipped');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'and wraps back to Call');
    // Space is the advance shortcut here, never a literal character.
    expect(field('Our #').controller!.text.contains(' '), isFalse);
    expect(field('Their #').controller!.text.contains(' '), isFalse);
  });

  testWidgets('tab reaches the contest exchange fields as well', (tester) async {
    const controls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: running(['c']),
            qsosRepository: qsos,
          ),
          radio: baseRadio(),
          activities: ActivityHooks(
            activityControls: controls,
          ),
        ),
      ),
    ));
    await tester.pump();

    tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.requestFocus();
    await tester.pump();

    var reached = false;
    for (var i = 0; i < 8 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      reached = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch')).focusNode!.hasFocus;
    }
    expect(reached, isTrue, reason: 'Tab traversal must reach a primary exchange field');
  });

  testWidgets('a space from an on-screen keyboard advances focus too, not just the hardware Space key', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    // A virtual keyboard delivers a space as a text edit, not a key event, so
    // the panel's Space shortcut never fires and the field's own filter would
    // otherwise strip the space silently. `enterText` goes through the input
    // connection and the field's formatters — exactly that soft-keyboard path,
    // where `sendKeyEvent` (the test above) is the hardware path.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW ');
    await tester.pump(); // let the interceptor's deferred handler run

    expect(field('Their call').controller!.text, 'W1AW', reason: 'the soft-keyboard space is consumed, not inserted');
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'a virtual-keyboard space must advance focus');

    // Sent's own filter also strips spaces — the interceptor has to run there
    // too, or Space would be a dead key in every field but Call.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), ' ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);
  });

  testWidgets('an exchange field refuses keyboard help like every other main field', (tester) async {
    // A county code is not prose. With only autocorrect off, Android keeps
    // its suggestion strip over the field and iOS turns a typed `-` into a
    // dash the formatters never undo.
    const controls = [
      {
        'key': 'qp/county',
        'label': 'County',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'qp', 'field': 'county'},
      },
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: running(['qp']),
            qsosRepository: qsos,
          ),
          radio: baseRadio(),
          activities: ActivityHooks(
            activityControls: controls,
          ),
        ),
      ),
    ));
    await tester.pump();
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'County'));
    // Sent is a fixed main field; the exchange refuses exactly what it does.
    final sent = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent'));
    expect(
      (field.autocorrect, field.enableSuggestions, field.smartDashesType, field.smartQuotesType),
      (sent.autocorrect, sent.enableSuggestions, sent.smartDashesType, sent.smartQuotesType),
    );
    expect(field.enableSuggestions, isFalse);
    expect(field.smartDashesType, SmartDashesType.disabled);
  });

  testWidgets('an on-screen-keyboard space advances out of a contest exchange too', (tester) async {
    // The soft-keyboard half of the same rule. Without the panel's Space
    // formatter installed FIRST on an `ExchangeField`, a phone — where there
    // IS no hardware Space — has no way out of an exchange field, however
    // well the hardware path is covered.
    const controls = [
      {
        'key': 'cqwpx/ourSerial',
        'label': 'Our #',
        'icon': 'flag-checkered',
        'input': {
          'kind': 'serial',
          'refType': 'cqwpx',
          'field': 'ourSerial',
          'sequence': {'key': 'serial'},
        },
      },
      {
        'key': 'cqwpx/theirSerial',
        'label': 'Their #',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'cqwpx', 'field': 'theirSerial', 'numeric': true},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: running(['cqwpx']),
            qsosRepository: qsos,
          ),
          radio: baseRadio(),
          activities: ActivityHooks(
            activityControls: controls,
          ),
        ),
      ),
    ));
    await tester.pump();

    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Our #').focusNode!.requestFocus();
    await tester.pump();

    // Both fields are numeric, so digitsOnly would silently eat the space if
    // the interceptor weren't ahead of it — the exact dead-key symptom.
    // Entered in two steps because the interceptor recognises the gesture by
    // diffing: a LONE space appended to what was already there, not a paste
    // that happens to contain one.
    await tester.enterText(find.widgetWithText(TextField, 'Our #'), '7');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Our #'), '7 ');
    await tester.pump(); // let the interceptor's deferred handler run
    expect(field('Our #').controller!.text, '7', reason: 'the space is consumed, not inserted');
    expect(field('Their #').focusNode!.hasFocus, isTrue, reason: 'and it advances to the next primary field');

    await tester.enterText(find.widgetWithText(TextField, 'Their #'), '12');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their #'), '12 ');
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'wrapping back to Call');
  });

  testWidgets('a pasted value containing a space is filtered normally, not treated as an advance', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    // Only a lone single-space insertion is the advance gesture. A multi-char
    // edit that merely contains a space (a paste) must fall through to the
    // callsign filter, which drops the space — focus stays put.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1 AW');
    await tester.pump();

    expect(field('Their call').controller!.text, 'W1AW', reason: 'the callsign filter strips the space');
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'a paste is not a Space-to-advance gesture');
  });

  testWidgets('a soft-keyboard space is a LITERAL character while a command awaits its parameter, not an advance', (tester) async {
    // Locks the observable virtual-path behavior in command free-text mode: a
    // soft-keyboard space must land in the field, not consume-and-advance. The
    // hardware test above uses sendKeyEvent, which bypasses formatters, so this
    // is the only coverage for the input-connection path here. (The interceptor
    // branches use the NARROWER interceptor, which stands aside for every space
    // but the double-space that exits the field — and even if it didn't,
    // _handleSpace re-inserts the literal space for those modes, a safety net
    // this test also exercises end to end. The exit itself is covered below.)
    Future<Map<String, dynamic>?> fakeReloadPrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() == 'RELOAD') return {'expectsParams': true};
      return null;
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeReloadPrefix)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
    await tester.pump(const Duration(milliseconds: 200)); // let the debounced interpret() switch modes

    // Typing a space via the input connection (soft keyboard) once RELOAD is
    // recognized: it must land in the field, not consume and advance focus.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD ');
    await tester.pump();

    expect(field('Their call').controller!.text, 'RELOAD ', reason: 'the space is a literal parameter character here');
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'focus must not advance mid-command');
  });

  group('the entry row is a loop, not a waypoint', () {
    // Tab used to fall through to Flutter's own traversal at both ends of the
    // row, which walks on into the secondary-control chips and the Log button.
    // An operator running a pileup tabs by feel: landing on a button (where the
    // next keystroke does nothing, or worse, logs) costs a QSO. The rules here
    // are specified in docs/design/logging-fields.md.
    TextField field(WidgetTester tester, String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label));

    testWidgets('Tab off the last main field returns to the call field', (tester) async {
      await tester.pumpWidget(host());

      field(tester, 'Rcvd').focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue,
          reason: 'Tab past the last field wraps to Call rather than leaving the row');
    });

    testWidgets('Shift-Tab off the call field goes to the last main field', (tester) async {
      await tester.pumpWidget(host());

      field(tester, 'Their call').focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(field(tester, 'Rcvd').focusNode!.hasFocus, isTrue,
          reason: 'Shift-Tab wraps backwards to the last field, not out of the row');
    });

    testWidgets('Tab in the MIDDLE of the row is left to the ordinary traversal', (tester) async {
      // The edges are the only thing worth intercepting. If this ever fails it
      // means the handler started claiming interior Tabs, at which point the
      // row's order lives in two places (here and Flutter's geometry sort) and
      // they will disagree the first time the layout changes.
      await tester.pumpWidget(host());

      field(tester, 'Their call').focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(field(tester, 'Sent').focusNode!.hasFocus, isTrue);
    });
  });

  group('arrow keys travel between fields at the value edges', () {
    // Reading back a logged exchange means walking the row with the arrows; the
    // caret stopping dead at a field boundary forces a reach for the mouse.
    TextField field(WidgetTester tester, String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label));

    testWidgets('right arrow at the end of a value moves to the START of the next field', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      // enterText leaves the caret at the end — the edge the rule is about.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(field(tester, 'Sent').focusNode!.hasFocus, isTrue);
      // Position 0, NOT the usual cursor-at-end: the caret keeps travelling in
      // the direction it was pushed. This is the one path that overrides the
      // end-of-value default every other kind of focus change wants.
      expect(field(tester, 'Sent').controller!.selection.baseOffset, 0);
    });

    testWidgets('left arrow at position 0 moves to the END of the previous field', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      field(tester, 'Sent').focusNode!.requestFocus();
      await tester.pump();
      final sent = field(tester, 'Sent').controller!;
      sent.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue);
      expect(field(tester, 'Their call').controller!.selection.baseOffset, 4, reason: 'lands at the end of "W1AW"');
    });

    testWidgets('the traversal wraps at both ends of the row', (tester) async {
      await tester.pumpWidget(host());

      field(tester, 'Rcvd').focusNode!.requestFocus();
      await tester.pump();
      field(tester, 'Rcvd').controller!.selection =
          TextSelection.collapsed(offset: field(tester, 'Rcvd').controller!.text.length);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue);
    });

    testWidgets('a modified arrow key is left to the platform', (tester) async {
      // Cmd/Option+arrow are line- and word-wise caret moves. Claiming them
      // would take a real editing gesture away and teleport the operator into
      // another field instead. Shift is the only modifier that means anything
      // here, and only because it reverses Tab.
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue,
          reason: 'Cmd+Right is a caret move, not a field change');
      expect(field(tester, 'Sent').focusNode!.hasFocus, isFalse);
    });

    testWidgets('a Tab that goes nowhere leaves no caret instruction behind', (tester) async {
      // With the call field the ONLY primary field, Tab wraps onto the node
      // that already has focus, so no focus listener runs. A caret instruction
      // written unconditionally by the move would sit there uncollected, and
      // the next field to focus — Frequency, which is not even a primary field
      // — would take it and put its caret at 0 instead of the end of "14285".
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            prefs: LoggingPreferences(
              showRSTFields: false,
            ),
          ),
        ),
      ));
      await tester.pump();

      // Give Frequency a value FIRST — it is the give-away field (it shares the
      // same focus listener but is a secondary-control field, so it must never
      // resolve one of these), and an empty one would swallow the stale
      // instruction harmlessly before the assertion could see it.
      await openControl(tester, MdiIcons.radio);
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
      await tester.pump();
      await openControl(tester, MdiIcons.radio); // collapse — focus returns to Call

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      // The no-op wrap: Call is the only primary field, so this lands on the
      // node that already has focus and no listener runs.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await openControl(tester, MdiIcons.radio);
      final freq = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));

      expect(freq.controller!.selection.baseOffset, 5,
          reason: 'Frequency keeps cursor-at-end; it must not inherit a stale instruction');
    });

    testWidgets('an arrow key INSIDE a value still just moves the caret', (tester) async {
      // The whole point is that this stays ordinary text editing. A handler that
      // grabbed every arrow key would make the fields unnavigable.
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      final call = field(tester, 'Their call').controller!;
      call.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue, reason: 'focus must not leave mid-value');
    });
  });

  group('double space exits a field that accepts spaces', () {
    // A command awaiting parameters turns the call field into free text, where
    // a space is a character rather than "next field". Without an exit gesture
    // the field is a keyboard dead end — the operator has to reach for the
    // mouse, mid-QSO, which is exactly what the entry row exists to avoid.
    Future<Map<String, dynamic>?> reloadPrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() == 'RELOAD') return {'expectsParams': true};
      return null;
    }

    TextField field(WidgetTester tester, String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label));

    testWidgets('a second hardware space removes both and advances', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: reloadPrefix)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
      await tester.pump(const Duration(milliseconds: 200)); // debounced interpret() switches modes

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field(tester, 'Their call').controller!.text, 'RELOAD ',
          reason: 'the first space is a literal parameter character');
      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field(tester, 'Their call').controller!.text, 'RELOAD',
          reason: 'both spaces come off — the value left behind carries neither');
      expect(field(tester, 'Sent').focusNode!.hasFocus, isTrue);
    });

    testWidgets('a second soft-keyboard space does the same', (tester) async {
      // The path that actually matters on a phone: there IS no hardware Space
      // there, and the command modes used to drop the interceptor entirely, so
      // the field had no keyboard exit at all.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: reloadPrefix)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD ');
      await tester.pump();
      expect(field(tester, 'Their call').controller!.text, 'RELOAD ');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD  ');
      await tester.pump(); // let the interceptor's deferred handler run

      expect(field(tester, 'Their call').controller!.text, 'RELOAD');
      expect(field(tester, 'Sent').focusNode!.hasFocus, isTrue);
    });

    testWidgets("iOS's \".\" shortcut is the exit gesture in disguise, not punctuation", (tester) async {
      // Found on the simulator: with a space already in the text, iOS turns the
      // second space-bar press into ONE edit replacing that space with ". ", so
      // it never looks like a space insertion and a period landed in the field.
      // It can only happen in a space-accepting field — everywhere else the
      // first space is consumed before it reaches the text, leaving iOS nothing
      // to convert.
      // The matcher is iOS-gated (an Android IME's smart punctuation could
      // produce the same shape and would swallow a deliberately typed "."), so
      // the platform has to be iOS or this passes for the wrong reason.
      // Restored in a finally: the framework's invariant check runs before any
      // tearDown.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: reloadPrefix)));

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD ');
        await tester.pump();

        // Exactly what iOS sends, traced on an iPhone 17 Pro simulator: TWO
      // edits, the first REPLACING the trailing space with a period at the
      // same length, the second re-adding the space.
      //
      // Sent back to back with NO pump between them, which is the whole point:
      // on the device both edits are applied synchronously before any
      // microtask runs. Pumping in between drains our deferred handler early
      // and the test then passes against code that leaves the period behind on
      // a real phone — which is exactly what happened.
      //
      // `updateEditingValue` rather than `enterText` so each edit goes to
      // whatever client is attached at the time, as the real ones do.
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'RELOAD.',
        selection: TextSelection.collapsed(offset: 7),
      ));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'RELOAD. ',
        selection: TextSelection.collapsed(offset: 8),
      ));
      await tester.pump();

      expect(field(tester, 'Their call').controller!.text, 'RELOAD',
          reason: 'the whole gesture comes off — no period, no spaces');
      expect(field(tester, 'Sent').focusNode!.hasFocus, isTrue);
        expect(field(tester, 'Rcvd').focusNode!.hasFocus, isFalse,
            reason: 'one gesture advances one field, not two');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('off iOS the same edit is left alone — a typed period survives', (tester) async {
      // The gate's reason for existing: the shape is generic enough that
      // another platform's IME could produce it, and there swallowing it would
      // silently eat a period the operator typed.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: reloadPrefix)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD ');
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'RELOAD.',
        selection: TextSelection.collapsed(offset: 7),
      ));
      await tester.pump();

      expect(field(tester, 'Their call').controller!.text, 'RELOAD.');
      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue);
    });

    testWidgets('a COMPLETE command exits too — the flags are not what makes a field space-accepting',
        (tester) async {
      // Third way into free-text mode, and the one the flags miss: once the
      // text holds a space, `_commandExpectsParams` latches on regardless of
      // what the interpretation says (see `_callsignModeSafeText`). A complete
      // command reached that way carries neither `expectsParams` nor
      // `mixedCase`, so keying the exit to those flags advanced focus while
      // leaving the trailing space sitting in the value.
      Future<Map<String, dynamic>?> completeAfterParam(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        final text = input.trim().toUpperCase();
        if (text == 'EXP') return {'expectsParams': true};
        if (text.startsWith('EXP ')) return {'describe': 'toggle experiment'}; // complete, no flags
        return null;
      }

      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: completeAfterParam)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP LA');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP LA ');
      await tester.pump(const Duration(milliseconds: 200));
      expect(field(tester, 'Their call').controller!.text, 'EXP LA ',
          reason: 'test setup: space is literal here');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(field(tester, 'Their call').controller!.text, 'EXP LA',
          reason: 'the trailing space comes off, whichever route put the field in free-text mode');
      expect(field(tester, 'Sent').focusNode!.hasFocus, isTrue);
    });

    testWidgets('a period typed deliberately is left alone', (tester) async {
      // The guard on the rule above: only the exact space→". " replacement is
      // claimed. A period typed by hand never follows a trailing space (it
      // lands after it, "RELOAD ." not "RELOAD. "), so it can't be mistaken
      // for the shortcut.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: reloadPrefix)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD A');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD A.');
      await tester.pump();

      expect(field(tester, 'Their call').controller!.text, 'RELOAD A.');
      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue);
    });

    testWidgets('a space in the MIDDLE of the parameter is still literal', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: reloadPrefix)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD A B');
      await tester.pump();

      expect(field(tester, 'Their call').controller!.text, 'RELOAD A B',
          reason: 'only a space landing after an existing trailing space is an exit');
      expect(field(tester, 'Their call').focusNode!.hasFocus, isTrue);
    });
  });

  testWidgets('a contest exchange also gets the cursor at the end on focus', (tester) async {
    // The fixed primary fields have done this since they were written; the
    // exchange fields only ever got `selectAllOnFocus: false`, which stops the
    // select-all but leaves the caret wherever it last sat. Tabbing back into a
    // filled exchange then put the caret mid-value, so the next digit typed
    // landed in the middle of the number.
    const controls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: running(['c']),
            qsosRepository: qsos,
          ),
          radio: baseRadio(),
          activities: ActivityHooks(
            activityControls: controls,
          ),
        ),
      ),
    ));
    await tester.pump();

    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), '1234');
    await tester.pump();
    // Leave the caret somewhere in the middle, then come back to the field.
    field('Exch').controller!.selection = const TextSelection.collapsed(offset: 1);
    field('Their call').focusNode!.requestFocus();
    await tester.pump();
    field('Exch').focusNode!.requestFocus();
    await tester.pump();

    expect(field('Exch').controller!.selection.isCollapsed, isTrue, reason: 'never select the whole value');
    expect(field('Exch').controller!.selection.baseOffset, 4, reason: 'caret at the end, ready for the next digit');
  });

  testWidgets('a soft-keyboard space advances through State and Grid too, not only Call and Sent', (tester) async {
    // State and Grid carry the interceptor (their formatter list changed from
    // `const [UpperCaseTextFormatter()]` to include it); the hardware test
    // bypasses formatters, so dropping `_virtualSpace` from either would go
    // unnoticed on the virtual path without this. `enterText`ing the field's
    // current text plus one space is a genuine single-space insertion.
    //
    // Freq is intentionally NOT covered here: it uses a numeric keyboard
    // (numberWithOptions), which has no space bar, so a soft-keyboard space
    // can't occur in it on a device — the interceptor there is only defensive.
    await tester.pumpWidget(host(prefs: LoggingPreferences(showStateField: true, showGridField: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW ');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), ' ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), ' ');
    await tester.pump();
    expect(field('State').focusNode!.hasFocus, isTrue, reason: 'space advances Rcvd → State');

    await tester.enterText(find.widgetWithText(TextField, 'State'), ' ');
    await tester.pump();
    expect(field('Grid').focusNode!.hasFocus, isTrue, reason: 'space advances State → Grid');

    await tester.enterText(find.widgetWithText(TextField, 'Grid'), ' ');
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'space wraps Grid → Call');
  });

  testWidgets('on iOS the numeric fields (RST and Freq) use the numbers-and-punctuation keyboard, not a pure number pad', (tester) async {
    // numberWithOptions(signed: true) is the TextInputType that maps to iOS's
    // NumbersAndPunctuation keyboard: numbers up front, but WITH the symbols
    // these fields use and a space bar — so Space still rotates focus and RST
    // digits aren't buried behind the default keyboard's "123" key.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio); // reveal the Frequency field
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      for (final label in ['Sent', 'Rcvd', 'Frequency']) {
        expect(
          field(label).keyboardType.signed,
          isTrue,
          reason: '$label should use the numbers-and-punctuation keyboard on iOS',
        );
      }
    } finally {
      // Reset before the body returns — the binding's platform-override
      // invariant is checked before tearDown runs.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the logging code fields disable autocorrect, suggestions, and smart punctuation', (tester) async {
    // Callsigns, RSTs, grids, states, frequencies are codes, not prose — the
    // soft keyboard must not autocorrect / spell-check / predict / smart-
    // punctuate them. (autocorrect:false also disables iOS spell check.)
    await tester.pumpWidget(host(prefs: LoggingPreferences(showStateField: true, showGridField: true)));
    await openControl(tester, MdiIcons.radio); // reveal the Frequency field
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    for (final label in ['Sent', 'Rcvd', 'State', 'Grid', 'Frequency']) {
      final f = field(label);
      expect(f.autocorrect, isFalse, reason: '$label must not autocorrect/spell-check');
      expect(f.enableSuggestions, isFalse, reason: '$label must not show predictive suggestions');
      expect(f.smartDashesType, SmartDashesType.disabled, reason: '$label must not smart-dash');
      expect(f.smartQuotesType, SmartQuotesType.disabled, reason: '$label must not smart-quote');
    }
  });

  testWidgets('off iOS the numeric fields keep their platform-default keyboard', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      // RST falls back to the default keyboard (letters + space) — TextField
      // resolves the null we pass to TextInputType.text for a single-line
      // field. Freq keeps the decimal pad it has always used off iOS.
      expect(field('Sent').keyboardType, TextInputType.text);
      expect(field('Rcvd').keyboardType, TextInputType.text);
      expect(field('Frequency').keyboardType.decimal, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Tab cycles focus only through the logging controls, never escaping to a sibling', (tester) async {
    final outside = FocusNode(debugLabel: 'outside');
    addTearDown(outside.dispose);
    // A focusable field sits below the panel, standing in for the QSO list.
    await tester.pumpWidget(host(
      trailing: TextField(focusNode: outside, decoration: const InputDecoration(labelText: 'Outside')),
    ));

    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();

    // Tab far more times than there are controls: focus must wrap within
    // the panel and never land on the sibling outside it.
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outside.hasFocus, isFalse, reason: 'Tab escaped the logging controls on press ${i + 1}');
    }

    // Shift+Tab (reverse) is confined too.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outside.hasFocus, isFalse, reason: 'Shift+Tab escaped the logging controls on press ${i + 1}');
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  group('HALO-182: the callsign field is the default focus', () {
    // Every case starts from focus falling to NOTHING — the thing a dialog
    // popping over an idle panel, a menu closing or a stray `unfocus()` leave
    // behind. The reclaim lands a frame later and the manager applies it on a
    // microtask, hence two pumps.
    Future<void> dropFocus(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();
    }

    bool callHasFocus(WidgetTester tester) =>
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus;

    testWidgets('focus that falls to nothing comes back to the callsign field', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(host());
        await tester.pump();
        // Autofocus fired once at mount and never again; without the
        // backstop, this leaves the operator typing into nothing.
        await dropFocus(tester);
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a field elsewhere keeps its claim', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        other.requestFocus();
        await tester.pump();
        await tester.pump();
        // Only NOTHING is reclaimed — a leaf node anywhere is somebody
        // typing, and stealing from it would be the bug in reverse.
        expect(other.hasFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a button that kept the focus of a click is not a claim', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final button = FocusNode(debugLabel: 'button');
      addTearDown(button.dispose);
      try {
        // Web hands a clicked button its focus, and a dialog closing over it
        // hands the focus straight back to the button — so "any leaf is a
        // claim" leaves the operator typing into a button after every dialog.
        await tester.pumpWidget(host(
          trailing: TextButton(focusNode: button, onPressed: () {}, child: const Text('b')),
        ));
        await tester.pump();
        button.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a key-handling surface and a dropdown elsewhere keep theirs', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final list = FocusNode(debugLabel: 'list');
      final dropdown = FocusNode(debugLabel: 'dropdown');
      addTearDown(list.dispose);
      addTearDown(dropdown.dispose);
      try {
        await tester.pumpWidget(host(
          trailing: Column(children: [
            // The QSO list's shape: a bare Focus steering rows with the keys.
            Focus(focusNode: list, onKeyEvent: (_, _) => KeyEventResult.ignored, child: const SizedBox(height: 10)),
            DropdownButton<String>(
              focusNode: dropdown,
              value: 'a',
              items: const [DropdownMenuItem(value: 'a', child: Text('a'))],
              onChanged: (_) {},
            ),
          ]),
        ));
        await tester.pump();
        list.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(list.hasFocus, isTrue, reason: 'arrow keys are steering the list');
        dropdown.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(dropdown.hasFocus, isTrue, reason: 'a dropdown is a field');
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an overlay with its own scope, on the same route, is never robbed either', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final overlay = FocusScopeNode(debugLabel: 'overlay');
      addTearDown(overlay.dispose);
      try {
        // A menu or in-route overlay takes focus into a scope of its own
        // with no field inside — a scope, but not on the panel's ancestry.
        // The route guard can't tell this apart: the route is still current.
        await tester.pumpWidget(host(trailing: FocusScope(node: overlay, child: const SizedBox.shrink())));
        await tester.pump();
        overlay.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(overlay.hasPrimaryFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a dialog is never robbed, and its closing hands focus to the callsign', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(host());
        await tester.pump();
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        // The panel had nothing focused when the dialog opened — the case a
        // per-caller assertion never covers, because no caller is involved.
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(navigator.push(DialogRoute<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        )));
        await tester.pumpAndSettle();
        // Primary focus is the dialog's own scope: not the panel's ancestry,
        // so not "nothing". Reclaiming here would type behind the dialog.
        expect(find.text('dialog'), findsOneWidget);
        expect(callHasFocus(tester), isFalse);

        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('switching apps and back leaves focus where it was', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      // The manager decides at construction whether to follow the lifecycle
      // — on the test binding's Android default, it doesn't; this re-asks
      // with the platform above in place, the way the framework's own tests
      // do. Without it the whole scenario is a no-op and proves nothing.
      FocusManager.instance.listenToApplicationLifecycleChangesIfSupported();
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        other.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(other.hasFocus, isTrue, reason: 'test setup');

        // Going inactive parks focus on the root scope — "nothing", by the
        // backstop's lights. Resume restores the parked node only if nothing
        // took focus in between; a reclaim here is that something.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(other.hasFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a focus request made earlier in the same post-frame phase wins', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        // The web view-focus guard's shape: focus falls to the root scope,
        // and an observer registered before the panel puts the field back
        // from a post-frame callback of its own — queued ahead of the
        // reclaim's, but applied only on a microtask after both. Read
        // naively, the reclaim sees "still nothing" and overrides it, landing
        // the caret in Callsign while someone is typing a note.
        WidgetsBinding.instance.addPostFrameCallback((_) => other.requestFocus());
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump();
        expect(other.hasFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a field disposed while the app was away is replaced on resume', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      FocusManager.instance.listenToApplicationLifecycleChangesIfSupported();
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        other.requestFocus();
        await tester.pump();
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        // The pane went away meanwhile: the manager has nothing to restore
        // and says nothing, so without a look on resume focus sits on the
        // root scope for good.
        await tester.pumpWidget(host());
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('editing an event row, the event text field is the default', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final event = Qso(
        uuid: 'event',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'lunch'},
        },
      );
      try {
        await tester.pumpWidget(host(session: LoggingSession(editingQso: event, onEditCanceled: () {})));
        await tester.pump();
        expect(find.widgetWithText(TextField, 'Their call'), findsNothing, reason: 'test setup: no callsign field');
        final text = find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'lunch');
        expect(text, findsOneWidget, reason: 'test setup');
        // With no callsign field in the tree there is nothing to reclaim —
        // unless the field standing in for it is the target.
        await dropFocus(tester);
        expect(tester.widget<TextField>(text).focusNode!.hasFocus, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a hardware keyboard on mobile: a dialog closing returns to the callsign', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      hardwareKeyboardAttached.value = true;
      try {
        await tester.pumpWidget(host());
        await tester.pump();
        expect(callHasFocus(tester), isTrue, reason: 'test setup: autofocus with a keyboard');
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(navigator.push(DialogRoute<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        )));
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        hardwareKeyboardAttached.value = false;
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a hardware keyboard on mobile does not override a dismissal', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      hardwareKeyboardAttached.value = true;
      addTearDown(tester.view.reset);
      try {
        // The simulator reports the Mac's keyboard as attached and shows the
        // on-screen one regardless; an iPad in a keyboard case can do the
        // same. The operator dismissed the keyboard: a dialog closing after
        // that must not bring it back on the strength of the flag.
        await tester.pumpWidget(TapToDismissEmptyField(child: host()));
        await tester.pump();
        expect(callHasFocus(tester), isTrue, reason: 'test setup: autofocus with a keyboard');
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        final gesture = await tester.startGesture(tester.getCenter(find.widgetWithText(TextField, 'Their call')));
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.up(timeStamp: const Duration(milliseconds: 120));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        expect(callHasFocus(tester), isFalse, reason: 'test setup: dismissed');

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(navigator.push(DialogRoute<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        )));
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
        expect(callHasFocus(tester), isFalse);
      } finally {
        hardwareKeyboardAttached.value = false;
        debugDefaultTargetPlatformOverride = null;
      }
    });

    group('mobile with no hardware keyboard', () {
      void setKeyboard(WidgetTester tester, {required bool up}) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = up ? const FakeViewPadding(bottom: 300) : FakeViewPadding.zero;
      }

      Future<void> openAndCloseDialog(WidgetTester tester) async {
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        // The way operation_view opens its sheet: an unfocus first, which
        // also throws away what Navigator would otherwise restore on pop.
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(navigator.push(DialogRoute<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        )));
        await tester.pumpAndSettle();
        expect(find.text('dialog'), findsOneWidget, reason: 'test setup');
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
      }

      testWidgets('with the keyboard down, nothing is reclaimed', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host());
          await tester.pump();
          setKeyboard(tester, up: false);
          // A dialog closing over an idle phone must not pop the keyboard the
          // operator never asked for (HALO-93's reason, one step later).
          await dropFocus(tester);
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('Done in a secondary field closes the keyboard, and it stays closed', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host());
          await openControl(tester, MdiIcons.clockOutline);
          final time = find.widgetWithText(TextField, 'Time (UTC)');
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(tester.widget<TextField>(time).focusNode!.hasFocus, isTrue, reason: 'test setup');

          // Secondary fields keep Flutter's default: Done (and Back, and the
          // iOS hide-keyboard key) blurs. Undoing that blur would put the
          // keyboard the operator just closed straight back up, on Callsign.
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(callHasFocus(tester), isFalse);
          // And the memory is gone with it: a dialog after that stays quiet.
          await openAndCloseDialog(tester);
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('a claim taken in another pane ends the panel\'s', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final other = FocusNode(debugLabel: 'other');
        addTearDown(other.dispose);
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(callHasFocus(tester), isTrue, reason: 'test setup');
          other.requestFocus();
          await tester.pump();
          await tester.pump();
          expect(other.hasFocus, isTrue, reason: 'test setup');
          // Done in that field blurs it; the operator was last THERE, not in
          // the panel, so the panel has no claim to press.
          other.unfocus();
          await tester.pump();
          await tester.pump();
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('a dialog closing returns to the callsign the operator was in', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host());
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(callHasFocus(tester), isTrue, reason: 'test setup');

          // The keyboard goes down with the dialog, so keyboard state at the
          // pop says "leave it" — what matters is where the operator was.
          setKeyboard(tester, up: false);
          await openAndCloseDialog(tester);
          expect(callHasFocus(tester), isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('a dialog closing after tap-to-dismiss leaves the keyboard down', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(TapToDismissEmptyField(child: host()));
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          final gesture = await tester.startGesture(tester.getCenter(find.widgetWithText(TextField, 'Their call')));
          await tester.pump(const Duration(milliseconds: 120));
          await gesture.up(timeStamp: const Duration(milliseconds: 120));
          await tester.pumpAndSettle();
          setKeyboard(tester, up: false);
          await tester.pump();
          expect(callHasFocus(tester), isFalse, reason: 'test setup: dismissed');

          // The operator asked for the keyboard to go; a dialog in between
          // does not un-ask it.
          await openAndCloseDialog(tester);
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('tap-to-dismiss is the operator asking for nothing focused, and gets it', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(TapToDismissEmptyField(child: host()));
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(callHasFocus(tester), isTrue, reason: 'test setup');

          // The gesture, at finger speed (see keyboard_dismiss_test.dart).
          final gesture = await tester.startGesture(tester.getCenter(find.widgetWithText(TextField, 'Their call')));
          await tester.pump(const Duration(milliseconds: 120));
          await gesture.up(timeStamp: const Duration(milliseconds: 120));
          await tester.pumpAndSettle();
          await tester.pump();
          // Indistinguishable from the side effect above by keyboard state
          // alone — the keyboard is still on screen when focus drops — so
          // the dismissal has to say what it is.
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });

  // ── The focus ladder: main fields ↔ secondary pills (APP-19) ─────────────
  //
  // The QSO-list rung sits in the app (LoggingPanel owns the list and the
  // selection), so it's exercised in app/test/logging_panel_keyboard_nav_test
  // — these cover everything the panel can answer on its own.
  group('keyboard navigation of the secondary controls', () {
    /// Which pill currently holds the keyboard, by control key — read off the
    /// chips' own focus nodes (`LoggingFocusLadder.pillFocusFor` labels them `pill:<key>`), so
    /// the assertions name a control rather than a widget index.
    String? focusedPill(WidgetTester tester) {
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
        final node = chip.focusNode;
        if (node != null && node.hasFocus) return node.debugLabel?.replaceFirst('pill:', '');
      }
      return null;
    }

    testWidgets('Arrow Up steps out of the main fields, opening the pill it lands on', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);

      // First time up, there's no remembered pill — the strip's first one —
      // and it opens immediately: no separate Enter needed, and the keyboard
      // moves straight into its own field rather than parking on the chip.
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isFalse);
    });

    testWidgets('Tab and Shift-Tab cross between pills, opening whichever one they land on', (tester) async {
      // Tab bypasses Flutter's own default traversal entirely now (it broke
      // once a field could auto-open under it — probed with a real test run,
      // `primaryFocus` came back null instead of the next chip) — this is a
      // panel-owned crossing, symmetric with Left/Right below.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);

      // Tab first walks Time's own second field (Date) — see the dedicated
      // multi-field test below — then crosses. Two Tabs clear Time entirely.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsNothing);
      expect(find.widgetWithText(TextField, 'Band'), findsOneWidget,
          reason: 'crossing in from Tab lands on the FIRST field, not the one a tap opens into (Frequency)');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode?.hasFocus, isTrue);

      // Two more Tabs step through Radio's remaining fields (Frequency,
      // Mode) — plain within-control moves, no control opens or closes —
      // and a third crosses off the end onto More, which pops a dialog
      // rather than expanding, so arriving there leaves the keyboard on its
      // bare chip.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      expect(find.widgetWithText(TextField, 'Band'), findsNothing);

      // Shift-Tab reverses: off the front of More (nothing to walk within
      // it) crosses back to Radio, landing on its LAST field (Mode).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Mode'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);
      // Band/Mode only accept keyboard focus on desktop (see the Radio spec's
      // own `typeable` gate) — same restriction every other Band/Mode
      // keyboard test in this file runs under.
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Tab steps through a control\'s own fields before crossing to the next pill', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);

      // Time has two fields (Time, Date) — Tab walks to the second before
      // it ever considers leaving for Radio.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget, reason: 'still on Time, its own 2nd field');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Date')).focusNode?.hasFocus, isTrue);

      // Off the end of Time's own fields, Tab crosses to Radio — its FIRST
      // field (Band), then walks Band → Frequency → Mode before crossing
      // onward again.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more', reason: 'off the end of Radio\'s own fields, More has none to walk into');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a cursor key crosses to the next control\'s own canonical field, once at the edge of the value',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14074');
      await tester.pump();
      final freqController = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!;

      // Caret in the middle of the typed value: Right is an ordinary caret
      // move, same as any text field — it must not cross to another control.
      freqController.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget, reason: 'still in Frequency, mid-value');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);

      // Caret at the end: Right now crosses out — straight to the next
      // pill, skipping any sibling field within Radio (Mode is Tab's stop,
      // not a cursor key's).
      freqController.selection = TextSelection.collapsed(offset: freqController.text.length);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);

      // Left from the bare chip is unconditional (nothing to be "at the
      // edge" of), wrapping back to Radio's own canonical field — Frequency
      // again, not Mode (which is where Shift-Tab would have landed).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);

      // And Left at the very START of Frequency's value crosses backward
      // past Radio entirely, landing on Time's own canonical field (Time),
      // not its last field (Date), which is where Shift-Tab would land.
      freqController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Arrow Up from inside an auto-opened control closes it and selects from the QSO list', (tester) async {
      // Up used to stop at the main field, same as Down/Enter/Escape — now it
      // keeps going, the same direction Up already takes from a bare pill.
      var handedOver = 0;
      await tester.pumpWidget(host(
        session: LoggingSession(onNavigateToQsoList: () {
        handedOver++;
        return true;
      }),
      ));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing, reason: 'the control closed');
      expect(handedOver, 1);
      // Landing in the list itself is the host's job (it owns the list and
      // its selection) — this only proves the control closed and asked.
    });

    testWidgets('Arrow Up from inside a control falls back to the main fields when nothing is navigable',
        (tester) async {
      // A brand-new operation, or a host with no list at all: the callback
      // reports it couldn't hand off, so this control's own field (which
      // just closed) doesn't leave the keyboard stranded on nothing.
      await tester.pumpWidget(host(session: LoggingSession(onNavigateToQsoList: () => false)));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue,
          reason: 'precondition: Up has to actually originate from inside the open control');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing, reason: 'the control still closed');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue,
          reason: 'falls back to a main field instead of leaving focus nowhere');
    });

    testWidgets('Down out of an open control closes it and returns to the main field', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // Down used to stop at the pill the control opened from; now there's no
      // pill stop on the way out either — Down goes straight back to the main
      // field the operator was in, same as Escape.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(focusedPill(tester), isNull, reason: 'no pill stop on the way out anymore');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Enter out of an open control closes it too, back to the main field', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // Enter no longer opens a control from inside its own field — only
      // arriving on the pill does that now — so here it's the other half of
      // the same close gesture Down and Escape are.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Escape in an open control closes it and goes back to the main fields', (tester) async {
      // Where Down and Enter used to stop at the pill, Escape has always been
      // the "out of here entirely" gesture — one press puts the operator back
      // where they were typing. It must not reach the layers below it either:
      // the composed callsign is still there afterwards, not wiped.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Sent'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isTrue);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('Escape after auto-opening a pill returns to the main fields without wiping the form', (tester) async {
      // Pills only became focusable with the ladder, so Escape had never had
      // to mean anything there — and the panel-wide handler would have read a
      // merely-parked keyboard as a cue to wipe a half-typed contact.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsNothing);
      expect(focusedPill(tester), isNull);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('Enter closes an activity ref control too, and logs nothing (APP-19)', (tester) async {
      // Every secondary control loses Enter-to-log, not just Radio — and the
      // ref controls got there by a different route (no `onSubmitted` of their
      // own; their Enter reached the panel's root shortcut and logged). This
      // is the POTA-shaped case: type a reference, press Enter, and the
      // control closes with the QSO still unlogged in the form.
      const potaControl = {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      };
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: baseRadio(),
            activities: ActivityHooks(
              activityControls: const [potaControl],
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'POTA'), findsNothing, reason: 'the control closed');
      expect(
        await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first),
        isEmpty,
        reason: 'Enter on the way out of a control must not log the QSO',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('a held modifier leaves an open control alone', (tester) async {
      // The ladder claims bare keys only. Cmd/Ctrl/Option combinations are
      // platform gestures (Cmd+Down is "caret to the end of the text" on
      // macOS) and Shift+arrow is a text selection — stealing either would
      // teleport the operator out of the field they are typing in. Same rule
      // the entry row's own handler applies; these two rungs must not differ.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // Inside the open control's own field: Cmd+Down must not close it,
      // and Cmd+Right must not cross fields either.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget,
          reason: 'Cmd+Down/Right are caret/platform gestures, not a way out of the control');

      // Shift+Down is a selection gesture, and must not close it either.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // On a bare, fieldless pill (More): Cmd+Left must not walk the strip
      // either. Two Tabs clear Radio's remaining fields (Frequency, Mode).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();
      expect(focusedPill(tester), 'more', reason: 'Cmd+Left belongs to the platform');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Arrow Down out of an auto-opened control returns to the field the operator was last in',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      // Sent, not Call — the point is that the ladder remembers where you
      // left, rather than always dropping you back at the start of the row.
      await tester.tap(find.widgetWithText(TextField, 'Sent'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Arrow Up from a bare pill hands the keyboard on to the QSO list', (tester) async {
      // More is the one pill that stays chip-focused rather than opening —
      // reachable via Tab/cursor-key crossing (see the tests above), and the
      // one place Up still means "leave the strip upward" in a single step,
      // the way it already did before any control could auto-open.
      var handedOver = 0;
      await tester.pumpWidget(host(
        session: LoggingSession(onNavigateToQsoList: () {
        handedOver++;
        return true;
      }),
      ));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      // Left won't reach More from here: Up landed the caret at the END of
      // Time's value (cursor-at-end-on-focus), not the start, so Left is
      // just an ordinary caret move. Shift-Tab crosses unconditionally,
      // off the front of Time's own fields, wrapping to More.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      expect(handedOver, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(handedOver, 1);
      // The panel doesn't move focus itself — the host owns the list, and
      // decides whether there is anything up there to walk onto at all.
      expect(focusedPill(tester), 'more');
    });
  });

  group('main field widths', () {
    /// The rendered width of one of the main logging fields, by its label.
    double widthOf(WidgetTester tester, String label) =>
        tester.getSize(find.widgetWithText(TextField, label)).width;

    /// The width [text] actually paints at in [label]'s own field, read off
    /// the `EditableText` in the tree rather than re-derived from the style
    /// constants the widget uses — a test that recomputed those couldn't fail
    /// when they change.
    double paintedWidth(WidgetTester tester, String label, String text) {
      final editable = tester.widget<EditableText>(
        find.descendant(of: find.widgetWithText(TextField, label), matching: find.byType(EditableText)),
      );
      return (TextPainter(
        text: TextSpan(text: text, style: editable.style),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;
    }

    /// The bare gap between two adjacent fields, and the padding between a
    /// field's own left edge and where its value starts — the two things the
    /// row gives up once the fields are at their floors.
    double gapBetween(WidgetTester tester, String left, String right) =>
        tester.getTopLeft(find.widgetWithText(TextField, right)).dx -
        tester.getTopRight(find.widgetWithText(TextField, left)).dx;

    double innerPadding(WidgetTester tester, String label) =>
        tester
            .getTopLeft(
              find.descendant(of: find.widgetWithText(TextField, label), matching: find.byType(EditableText)),
            )
            .dx -
        tester.getTopLeft(find.widgetWithText(TextField, label)).dx;

    /// Pins the panel to [width] logical pixels. 600 tall throughout: only the
    /// horizontal budget is under test.
    ///
    /// Three frames because the row reserves the log button's MEASURED width:
    /// the first resolves against the fallback, the second against the real
    /// thing once that measurement lands. (A change of available width is not
    /// animated — see `LoggingEntryRow`'s width duration — so no settling is needed on
    /// top of that.)
    Future<void> pumpAt(WidgetTester tester, double width, {Widget? at}) async {
      await tester.binding.setSurfaceSize(Size(width, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(at!);
      await tester.pump();
      await tester.pump();
    }

    /// Long enough for a field to finish animating to a new width. The first
    /// pump is the one that rebuilds with the new target (the focus listener
    /// defers its `setState` to the end of the frame in progress); the second
    /// runs the animation out. Not `pumpAndSettle`: the panel carries a 1Hz
    /// clock that never settles.
    Future<void> settleWidths(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Every field the panel can put in the row at once: the two RSTs, a
    // contest exchange, State and Grid. The exchange is the one that asks for
    // a DIFFERENT width than the rest (76 against 64), which is what makes
    // "evenly" below distinguishable from "in proportion".
    Widget crowded() => MaterialApp(
          home: Scaffold(
            body: Column(children: [
              const Expanded(child: SizedBox.shrink()),
              LoggingControls(
                log: LogHooks(
                  operation: running(['contest']),
                  qsosRepository: qsos,
                ),
                activities: ActivityHooks(
                  activityControls: const [
                    {
                      'key': 'contest/exchange',
                      'label': 'Exch',
                      'icon': 'flag-checkered',
                      'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
                    }
                  ],
                ),
                prefs: LoggingPreferences(
                  showStateField: true,
                  showGridField: true,
                ),
              ),
            ]),
          ),
        );

    const fixedLabels = ['Sent', 'Rcvd', 'State', 'Grid'];

    // The widths below are in TEST-font units, where every glyph is a square
    // of the font size — roughly 1.7x the real face's advance, so the panel
    // runs out of room sooner here than on screen. 900 is roomy for all five
    // fields, 540 squeezes them without reaching their floors, 400 is well
    // past those floors, and 330 is where there is nothing left to give.

    testWidgets('the callsign field always fits at least 6 characters', (tester) async {
      // Narrow enough that the other fields alone would have eaten the row:
      // Sent, Rcvd, Exch, State and Grid at their declared widths, plus the
      // gaps and the log button, is most of this.
      await pumpAt(tester, 540, at: crowded());

      // 6 characters is a full call with a portable suffix. Measured as the
      // field itself would paint it, so this fails if the minimum silently
      // stops covering the field's own padding or font.
      expect(
        widthOf(tester, 'Their call'),
        greaterThanOrEqualTo(paintedWidth(tester, 'Their call', 'W1AW/4')),
        reason: 'the callsign field is the one field always present — it never squeezes to nothing',
      );
    });

    testWidgets('with room to spare, every field keeps its declared width', (tester) async {
      await pumpAt(tester, 900, at: crowded());

      // The squeeze is not always on: a wide panel renders the fields at the
      // widths they ask for, and the callsign takes everything left over.
      for (final label in fixedLabels) {
        expect(widthOf(tester, label), 64, reason: '$label at its declared minimum');
      }
      expect(widthOf(tester, 'Exch'), 76, reason: 'an exchange asks for more than an RST');
      expect(widthOf(tester, 'Their call'), greaterThan(200));
    });

    testWidgets('when they do not all fit, the fields give up width evenly', (tester) async {
      await pumpAt(tester, 540, at: crowded());

      // Evenly means each field gives up the same NUMBER OF PIXELS, not the
      // same share of what it asked for — so the exchange, which is wider to
      // begin with, stays wider by exactly as much as it started. A
      // proportional split would have taken more from it.
      final givenUp = [
        for (final label in fixedLabels) 64 - widthOf(tester, label),
        76 - widthOf(tester, 'Exch'),
      ];
      expect(givenUp.first, greaterThan(1), reason: 'the row is genuinely short of space here');
      for (final amount in givenUp) {
        expect(amount, closeTo(givenUp.first, 0.5));
      }
    });

    testWidgets('the focused field takes its full width back, and its neighbours pay', (tester) async {
      await pumpAt(tester, 540, at: crowded());
      final unfocused = widthOf(tester, 'Rcvd');
      expect(unfocused, lessThan(64), reason: 'the row starts out squeezed');

      await tester.tap(find.widgetWithText(TextField, 'Sent'));
      await settleWidths(tester);

      // The field you are typing in is worth reading, whatever the row's
      // budget — the ones you are not carry its share.
      expect(widthOf(tester, 'Sent'), 64);
      expect(widthOf(tester, 'Rcvd'), lessThan(unfocused));

      // And it gives the width back on the way out.
      await tester.tap(find.widgetWithText(TextField, 'Exch'));
      await settleWidths(tester);
      expect(widthOf(tester, 'Exch'), 76);
      expect(widthOf(tester, 'Sent'), lessThan(64));
    });

    testWidgets('a field animates to a new width rather than jumping there', (tester) async {
      await pumpAt(tester, 540, at: crowded());
      final before = widthOf(tester, 'Sent');

      await tester.tap(find.widgetWithText(TextField, 'Sent'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Caught in flight: past where it started, not yet where it's going.
      // Widths change on every focus move once the row is squeezed, so the
      // row has to follow the keyboard rather than snap at it.
      final midway = widthOf(tester, 'Sent');
      expect(midway, greaterThan(before), reason: 'it has started moving');
      expect(midway, lessThan(64), reason: 'it has not arrived in one frame');

      await settleWidths(tester);
      expect(widthOf(tester, 'Sent'), 64, reason: 'and it does arrive');
    });

    testWidgets('no field is squeezed past two characters of its own value', (tester) async {
      // Narrower than the fields can honestly fit in, even at their floors.
      await pumpAt(tester, 400, at: crowded());

      final widths = [for (final label in [...fixedLabels, 'Exch']) widthOf(tester, label)];
      for (final (i, label) in [...fixedLabels, 'Exch'].indexed) {
        expect(
          widths[i],
          greaterThanOrEqualTo(paintedWidth(tester, label, 'WW')),
          reason: '$label still shows two characters',
        );
        // Two characters is two characters: the floor is the same for every
        // field, so down here the exchange — which asked for 76 against an
        // RST's 64 — is exactly as wide as one. Left to the even split alone
        // it would still be 12pt wider, having simply given up the same
        // amount from a bigger start.
        expect(widths[i], closeTo(widths.first, 0.5), reason: '$label is at the same floor as the rest');
      }
    });

    testWidgets('past the floors, the gaps and the fields\' own padding go next', (tester) async {
      await pumpAt(tester, 500, at: crowded());
      final roomyGap = gapBetween(tester, 'Sent', 'Rcvd');
      final roomyPadding = innerPadding(tester, 'Sent');
      expect(roomyGap, greaterThan(0));
      expect(roomyPadding, greaterThan(0));

      // Below the point where every field is already at two characters, the
      // only room left is between and inside them — and it goes gradually,
      // both together, rather than snapping off at a breakpoint.
      await pumpAt(tester, 440, at: crowded());
      final tightGap = gapBetween(tester, 'Sent', 'Rcvd');
      final tightPadding = innerPadding(tester, 'Sent');
      expect(tightGap, lessThan(roomyGap));
      expect(tightPadding, lessThan(roomyPadding));

      await pumpAt(tester, 400, at: crowded());
      expect(gapBetween(tester, 'Sent', 'Rcvd'), lessThan(tightGap), reason: 'gradually, not in one step');
      expect(innerPadding(tester, 'Sent'), lessThan(tightPadding));

      // The callsign is still holding its own six characters — it is the LAST
      // thing the row gives up, after the gaps and the padding.
      expect(
        widthOf(tester, 'Their call'),
        greaterThanOrEqualTo(paintedWidth(tester, 'Their call', 'W1AW/4')),
      );

      // And they go all the way to nothing, not to some residue. Material adds
      // 4pt a side to every `filled` field that no InputDecoration field
      // exposes (`_kInputExtraPadding`), so a value would otherwise stop 8pt
      // short of its own edge with no way to say otherwise; the row cancels it
      // with a negative content padding once it needs to.
      await pumpAt(tester, 330, at: crowded());
      expect(gapBetween(tester, 'Sent', 'Rcvd'), 0);
      expect(innerPadding(tester, 'Sent'), 0);
    });
  });
}
