// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Widget tests drive the keyboard flows; database verification goes through
// tester.runAsync() because drift's futures/timers otherwise sit unresolved
// in testWidgets' FakeAsync zone. Interleaved pumps let widget-initiated
// writes (which start inside the fake zone) run to completion.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late Operation operation;
  late _FakeVfoStore fakeRadio;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    operation = await operations.create(stationCall: 'KI2D');
    fakeRadio = _FakeVfoStore();
  });

  tearDown(() async {
    await db.close();
  });

  Widget host({
    List<Qso> existing = const [],
    CommandInterpreter? interpretCommand,
    void Function(String? message)? onCommandMessageChanged,
    CommandActionHandler? onCommandAction,
    VfoStore? radioService,
    Qso? editingQso,
    Map<String, dynamic>? suggestedQso,
    SuggestSpotSources? suggestSpotSources,
    SendSpot? sendSpot,
    bool showStateField = false,
    bool showGridField = false,
    bool showNumbersRow = false,
    bool showExtraInNumbersRow = true,
    bool vibrateNumbersRow = true,
    List<String>? enabledBands,
    List<String>? enabledModes,
    void Function(Qso qso)? enqueueLookup,
    Widget? trailing,
  }) {
    final controls = LoggingControls(
      operation: operation,
      qsosRepository: qsos,
      qsos: existing,
      enqueueLookup: enqueueLookup,
      interpretCommand: interpretCommand,
      onCommandMessageChanged: onCommandMessageChanged,
      onCommandAction: onCommandAction,
      radioService: radioService,
      editingQso: editingQso,
      suggestedQso: suggestedQso,
      suggestSpotSources: suggestSpotSources,
      sendSpot: sendSpot,
      showStateField: showStateField,
      showGridField: showGridField,
      showNumbersRow: showNumbersRow,
      showExtraInNumbersRow: showExtraInNumbersRow,
      vibrateNumbersRow: vibrateNumbersRow,
      enabledBands: enabledBands,
      enabledModes: enabledModes,
      spottingControlLabel: 'Spotting',
      spottingLabel: 'Spotting',
      spottingSelfLabel: 'Self-spotting',
      spotSelfLabel: (freq) => 'Self-spot at $freq',
      spotOtherLabel: (call, freq) => 'Spot $call at $freq',
      spotTooLateLabel: (call) => 'Too late to spot $call',
      spotNoFreqLabel: 'First set a frequency to spot',
      // The dupe warning now renders as a line-3 pill in the info area
      // (issue #40); map its key to the same 'DUPE' text the old chip used so
      // the dupe-detection tests can keep asserting on it.
      scoreNoticeLabel: (key) => key == 'duplicate' ? 'DUPE' : key,
    );
    return MaterialApp(
      home: Scaffold(
        // Matches the operation view: the Scaffold doesn't resize for the
        // keyboard (LoggingControls reserves its own bottom spacer), and the
        // panel is bottom-anchored with the rest of the height above it (the
        // QsoList in the app). `trailing` stands in for that QSO list — a
        // focusable sibling OUTSIDE the controls, so a Tab-trap test can prove
        // focus never lands on it.
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            controls,
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // The on-screen keyboard, as the widget tree actually sees it: raise the
  // real FlutterView's bottom inset (Scaffold hides it from MediaQuery, so
  // that's the only faithful signal — the very thing `_keyboardIsUp` reads).
  // Insets are physical px, so scale by the pixel ratio pinned here;
  // `logicalHeight` stands in either a full keyboard (default) or the thin
  // ~50px shortcuts bar iOS shows when a HARDWARE keyboard is attached.
  void raiseKeyboard(WidgetTester tester, {double logicalHeight = 300}) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewInsets = FakeViewPadding(bottom: logicalHeight * 3.0);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Stand-in for the real `radio-commands` extension (see
  /// extensions/core/radio-commands), so this widget test can verify how
  /// LoggingControls applies a command result without booting a JS runtime.
  /// The extension itself is covered by an integration test in
  /// halo_extension_host against the real built bundle.
  Future<Map<String, dynamic>?> fakeInterpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    final band = RegExp(r'^(2200|630|160|80|60|40|30|20|17|15|12|10|6|4|2)M?$', caseSensitive: false).firstMatch(input);
    if (band != null) {
      final b = '${band.group(1)!.toLowerCase()}m';
      return {
        'describe': 'Change band to **$b**?',
        'confirm': 'Band set to **$b**',
        'commands': [
          {'setVfo': {'band': b}}
        ]
      };
    }

    final mode = modes.firstWhere((m) => m.toLowerCase() == input.toLowerCase(), orElse: () => '');
    if (mode.isNotEmpty) {
      return {
        'describe': 'Change mode to **$mode**?',
        'confirm': 'Mode set to **$mode**',
        'commands': [
          {'setVfo': {'mode': mode}}
        ]
      };
    }

    if (input.length >= 3) {
      final freq = parseFreq(input);
      if (freq != null && bandForFrequency(freq) != null) {
        return {
          'describe': 'Change frequency to **${(freq / 1000).toStringAsFixed(3)} MHz**?',
          'confirm': 'Frequency set to **${(freq / 1000).toStringAsFixed(3)} MHz**',
          'commands': [
            {'setVfo': {'freq': freq}}
          ]
        };
      }
    }
    return null;
  }

  /// Pumps until the operation's QSO list reaches [count] (or gives up).
  Future<List<Qso>> waitForQsos(WidgetTester tester, int count) async {
    var logged = <Qso>[];
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      logged = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
      if (logged.length >= count) break;
    }
    return logged;
  }

  /// Opens a secondary control by tapping its chip (found by icon, since a
  /// control's chip label is a dynamic summary — e.g. Radio's starts as
  /// "Band??? • SSB" — not a fixed string). Taps the ChoiceChip ancestor
  /// rather than the icon itself: the icon glyph's tight bounding box can
  /// sit a pixel or two outside the chip's actual hit-test area.
  Future<void> openControl(WidgetTester tester, IconData icon) async {
    await tester.tap(find.ancestor(of: find.byIcon(icon), matching: find.byType(ChoiceChip)));
    await tester.pump();
    // The panel slides into/out of place over SecondaryControlRow's fixed
    // 200ms animation — a bounded pump (rather than pumpAndSettle, which
    // would also chase the Time control's Timer.periodic clock tick and
    // never settle) gets it fully in view (or fully gone, when this
    // closes a panel) before callers interact with its fields. Slightly
    // over 200ms, plus a trailing zero-duration pump, so AnimatedSwitcher's
    // own post-animation cleanup (dropping the outgoing child) has
    // actually run rather than landing exactly on the animation's edge.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  testWidgets('Enter logs a QSO with mode, band and default RSTs', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    final qso = logged.single;
    expect(qso.theirCall, 'W1AW');
    expect(qso.ourCall, 'KI2D');
    expect(qso.freq, 14285);
    expect(qso.band, '20m');
    expect(qso.mode, 'SSB');
    expect(qso.sentRST, '59');
    expect(qso.receivedRST, '59');

    // Entry is wiped and ready for the next call.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
    expect(callField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('Enter with an implausible call logs nothing', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'QQQ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, isEmpty);
  });

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

  group('mobile numbers row (issue #27)', () {
    Finder keyInRow(String glyph) =>
        find.descendant(of: find.byType(NumberKeys), matching: find.text(glyph));

    testWidgets('shows above the keyboard on mobile when enabled and a field has focus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        raiseKeyboard(tester);
        await tester.pumpWidget(host(showNumbersRow: true));
        await tester.pump();
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
        await tester.pumpWidget(host(showNumbersRow: false));
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
        await tester.pumpWidget(host(showNumbersRow: true));
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
        await tester.pumpWidget(host(showNumbersRow: true));
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
        await tester.pumpWidget(host(showNumbersRow: true));
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
        await tester.pumpWidget(host(showNumbersRow: true));
        await tester.pump(); // let the call field autofocus

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
        await tester.pumpWidget(host(showNumbersRow: true));

        // A partial callsign in the (focused) call field → "/".
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump();
        expect(keyInRow('/'), findsOneWidget);
        expect(keyInRow('.'), findsNothing);

        // Tapping it appends the slash the mobile keyboard buries a layer down.
        await tester.tap(keyInRow('/'));
        await tester.pump();
        final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
        expect(callField.controller!.text, 'W1AW/');

        // Moving focus to the numeric Sent field flips the extra key to ".".
        await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
        await tester.pump();
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
        await tester.pumpWidget(host(showNumbersRow: true, showExtraInNumbersRow: false));
        await tester.pump();
        expect(find.byType(NumberKeys), findsOneWidget);
        expect(keyInRow('.'), findsNothing);
        expect(keyInRow('/'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('a comma-separated call list logs one QSO per call, 5 seconds apart', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 3);
    expect(logged, hasLength(3));
    logged.sort((a, b) => a.startAtMillis!.compareTo(b.startAtMillis!));
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC', 'N2XYZ']);
    expect(logged[1].startAtMillis! - logged[0].startAtMillis!, 5000);
    expect(logged[2].startAtMillis! - logged[1].startAtMillis!, 5000);

    // Entry is wiped, same as the single-call case.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
  });

  testWidgets('a call list with any implausible entry logs nothing', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, QQQ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, isEmpty);
  });

  testWidgets('call stacking: "//" logs the last stacked call and leaves the rest for the next QSO', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'W1AW');

    // The un-logged fragment stays in the field, ready for the next QSO —
    // not a full wipe.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC');
    expect(callField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('call stacking: picks the segment at the cursor, not always the last one', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    // Move the cursor into the first segment ("K1AB|C").
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    callField.controller!.selection = const TextSelection.collapsed(offset: 4);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'K1ABC');
    expect(callField.controller!.text, 'W1AW');
  });

  testWidgets('call stacking: scans left past invalid fragments to find a valid callsign', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//QQQ//RRR');
    await tester.pump(); // cursor defaults to the end, inside the invalid "RRR" segment
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'W1AW');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'QQQ//RRR');
  });

  testWidgets('call stacking: no valid callsign anywhere in the stack logs nothing', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'QQQ//RRR');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, isEmpty);
  });

  testWidgets('a field with both "//" and "," logs via stacking, not as a comma list — "//" takes priority', (tester) async {
    await tester.pumpWidget(host());

    // "W1AW//K1ABC,N2XYZ": _pickStackedCall only ever splits on "//", so
    // there are exactly two segments — "W1AW" and "K1ABC,N2XYZ" (the call
    // field's own formatter strips spaces, so no space survives after the
    // comma either way). Cursor at the end sits in the second segment,
    // which fails looksLikeCallsign whole (it's not a single callsign,
    // it's comma-joined text), so the scan falls back to "W1AW" — one QSO
    // logged via stacking, not a comma-list batch.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.theirCall, 'W1AW');

    // The remainder (the other stacked segment, still comma-joined) stays
    // in the field — comma-list logic never engaged for this Enter press.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC,N2XYZ');
  });

  testWidgets('editing a QSO with a comma-separated call list updates the original and adds new QSOs for the rest', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(editingQso: existingQso));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    logged.sort((a, b) => a.startAtMillis!.compareTo(b.startAtMillis!));
    // The original QSO is updated in place, keeping its own recorded time.
    expect(logged[0].uuid, existingQso.uuid);
    expect(logged[0].theirCall, 'W1AW');
    expect(logged[0].startAtMillis, 1000000);
    // The extra call becomes a new QSO, 5 seconds later.
    expect(logged[1].uuid, isNot(existingQso.uuid));
    expect(logged[1].theirCall, 'K1ABC');
    expect(logged[1].startAtMillis, 1005000);
  });

  testWidgets('lookup preview follows the cursor segment within a comma-separated call list', (tester) async {
    final lookups = <String>[];
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
    }) async {
      lookups.add(call);
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LoggingControls(operation: operation, qsosRepository: qsos, lookup: lookup)),
    ));

    // Cursor ends up at the end (last segment, "W1AW") after enterText.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC, W1AW');
    await tester.pump(const Duration(milliseconds: 400));

    expect(lookups, contains('W1AW'));
    expect(lookups, isNot(contains('K1ABC, W1AW')));
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
  });

  group('info area (issue #40)', () {
    Future<Map<String, dynamic>?> Function(String, {required Map<String, dynamic> qso, required Map<String, dynamic> operation, required bool online}) guessLookup(
      Map<String, dynamic> guess,
    ) {
      return (call, {required qso, required operation, required online}) async => {'guess': guess};
    }

    testWidgets('idle (no call): renders the operation statistics lines', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            operationStatsLines: (_) => ['12 QSOs in 1h 5m', '48 Q/h for last 10'],
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('12 QSOs in 1h 5m'), findsOneWidget);
      expect(find.text('48 Q/h for last 10'), findsOneWidget);
    });

    testWidgets('call entered: flag, location line and name replace the stats', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            lookup: guessLookup({'flag': '🇮🇹', 'name': 'Marco', 'entityPrefix': 'I', 'country': 'Italy'}),
            callLocationLine: (guess) => '5,000 mi to • ${guess['country']}',
            operationStatsLines: (_) => ['stats-line-should-be-hidden'],
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300)); // let the info-area cross-fade settle

      expect(find.text('🇮🇹'), findsOneWidget);
      expect(find.textContaining('5,000 mi to'), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);
      // Once a call of ≥3 chars is entered, the default stats give way to
      // the call-info panel.
      expect(find.text('stats-line-should-be-hidden'), findsNothing);
    });

    testWidgets('a lookup note takes line 2 over the name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            lookup: guessLookup({'name': 'Marco', 'note': 'Old friend, always on 20m'}),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Old friend, always on 20m'), findsOneWidget);
      expect(find.text('Marco'), findsNothing);
    });

    testWidgets('scoreQso notices render as line-3 pills', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            lookup: guessLookup({'name': 'Marco'}),
            scoreQso: ({required operation, required qso, excludeUuid}) async =>
                {'notices': ['newDXCC', 'newBand'], 'alerts': <String>[]},
            scoreNoticeLabel: (key) => const {'newDXCC': 'New DXCC', 'newBand': 'New Band'}[key] ?? key,
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('New DXCC'), findsOneWidget);
      expect(find.text('New Band'), findsOneWidget);
    });

    testWidgets("the hook's dupe alert shows as a pill — and no DUPE chip in the control row", (tester) async {
      // Dupe detection now lives in the scoreQso hook (which knows the
      // operation's activities), not a client-side check — the widget just
      // renders whatever the hook returns.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            scoreQso: ({required operation, required qso, excludeUuid}) async =>
                {'notices': <String>[], 'alerts': ['duplicate']},
            scoreNoticeLabel: (key) => key == 'duplicate' ? 'Dupe!' : key,
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));

      // The hook's dupe alert renders as a pill...
      expect(find.text('Dupe!'), findsOneWidget);
      // ...and never as a Chip in the secondary control row (issue #40).
      expect(find.widgetWithText(Chip, 'DUPE'), findsNothing);
    });

    testWidgets('scoreQso fires only for a plausible callsign, not junk input', (tester) async {
      final scored = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            scoreQso: ({required operation, required qso, excludeUuid}) async {
              scored.add(((qso['their'] as Map)['call']) as String);
              return {'notices': <String>[], 'alerts': <String>[]};
            },
          ),
        ),
      ));

      // "QQQ" is ≥3 chars but not a plausible callsign — no whole-log scoring
      // pass should fire (the same gate the lookup uses).
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'QQQ');
      await tester.pump(const Duration(milliseconds: 500));
      expect(scored, isEmpty);

      // A real callsign triggers exactly one debounced scoring pass.
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      expect(scored, ['W1AW']);
    });
  });

  testWidgets('logging a comma-separated call list saves immediately without inline lookups; each entry is enqueued for background lookup', (tester) async {
    // Saving a call list must never block on N network lookups (a stall
    // with no connectivity): the QSOs land bare and each is handed to the
    // caller's background queue, which enriches them after the fact.
    final lookedUp = <String>[];
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
    }) async {
      lookedUp.add(call);
      return {'guess': {'name': 'Should Not Be Saved Inline'}};
    }

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          lookup: lookup,
          enqueueLookup: enqueued.add,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    // Enter before the 300ms preview debounce fires — the save must not
    // depend on any lookup having started, let alone completed.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    // No lookup ran as part of the save, and nothing got attached inline...
    expect(lookedUp, isEmpty);
    expect(logged.every((q) => q.theirName == null), isTrue);
    // ...instead every new QSO was queued for background enrichment, in
    // logging order — a fresh, independent lookup per call, never one
    // cached result duplicated across different calls.
    expect(enqueued.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC']);
    expect(enqueued.map((q) => q.uuid).toSet(), logged.map((q) => q.uuid).toSet());
  });

  testWidgets('editing a QSO into a comma-separated list: the original record survives untouched; only the newly added call is enqueued for background lookup', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'name': 'Stale Cached Name', 'grid': 'FN31pr'},
          'startAtMillis': 1000000,
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          editingQso: existingQso,
          enqueueLookup: enqueued.add,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    final w1aw = logged.firstWhere((q) => q.theirCall == 'W1AW');
    final k1abc = logged.firstWhere((q) => q.theirCall == 'K1ABC');
    // The record being edited is untouched — not re-looked-up (inline or
    // via the queue), its own already-stored data survives exactly as
    // before: a background refresh would overwrite `guess` data the
    // operator may already be relying on.
    expect(w1aw.theirName, 'Stale Cached Name');
    expect(w1aw.theirGrid, 'FN31pr');
    // The newly added call is saved bare and queued for its own
    // independent background lookup, rather than inheriting anything
    // cached for the original call.
    expect(k1abc.theirName, isNull);
    expect(enqueued.map((q) => q.uuid).toList(), [k1abc.uuid]);
  });

  testWidgets('a single-call log keeps its debounced preview result and is still handed to the background queue', (tester) async {
    final enqueued = <Qso>[];
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
    }) async {
      return {'guess': {'name': 'ARRL HQ'}};
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          lookup: lookup,
          enqueueLookup: enqueued.add,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 400)); // let the preview lookup settle
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    // The cached preview result is written with the QSO...
    expect(logged.single.theirName, 'ARRL HQ');
    // ...and the saved record is still handed to the queue: the QUEUE
    // decides whether more lookup work is needed (it skips records that
    // already carry online data), so an Enter that beats the 300ms preview
    // debounce — leaving the record bare — still gets enriched.
    expect(enqueued.map((q) => q.uuid).toList(), [logged.single.uuid]);
  });

  testWidgets('command actions that add QSOs (e.g. SEED) enqueue each added QSO for background lookup', (tester) async {
    // The extension side only attaches fast offline guesses when seeding
    // (network lookups there would stall the whole command) — the full
    // online enrichment is the queue's job, after the QSOs are on screen.
    Future<Map<String, dynamic>?> interpret(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input != 'SEED') return null;
      return {
        'describe': 'Add seed QSOs?',
        'confirm': 'Added',
        'commands': [
          {'addQso': {'their': {'call': 'W1AW'}, 'startAtMillis': 1000000}},
          {'addQso': {'their': {'call': 'K1ABC'}, 'startAtMillis': 2000000}},
        ],
      };
    }

    final enqueued = <Qso>[];
    await tester.pumpWidget(host(interpretCommand: interpret, enqueueLookup: enqueued.add));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SEED');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    expect(enqueued.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC']);
    expect(enqueued.map((q) => q.uuid).toSet(), logged.map((q) => q.uuid).toSet());
  });

  testWidgets('a manually entered name override does not duplicate onto a newly added call, but a grid override does', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
        })))!;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          editingQso: existingQso,
          theirNameLabel: 'Name',
          theirGridLabel: 'Grid',
          saveLabel: 'Save',
        ),
      ),
    ));

    // Drive the "More" pane to set an explicit name+grid override. The
    // icon sits inside a horizontally-scrolling chip row — same harmless
    // "off the hit-test center" artifact as the DropdownMenu taps elsewhere
    // in this file. Grid is typed lowercase on purpose: the pane's Grid
    // field is `uppercase: true` (logging INPUT is uppercase unless
    // explicitly mixed-case), but the stored value gets the conventional
    // Maidenhead casing back via normalizeGrid — so it must land as FN99xx
    // below — while Name is an explicitly mixed-case field and survives
    // exactly as typed.
    await tester.tap(find.byIcon(resolveIconName('pencil')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Corrected Name');
    await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn99xx');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Extend the call field into a list — K1ABC is a newly added call.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    final w1aw = logged.firstWhere((q) => q.theirCall == 'W1AW');
    final k1abc = logged.firstWhere((q) => q.theirCall == 'K1ABC');
    // The record being edited keeps both — same as before this feature.
    expect(w1aw.theirName, 'Corrected Name');
    expect(w1aw.theirGrid, 'FN99xx');
    // The newly added call inherits the grid override, but not the name.
    expect(k1abc.theirGrid, 'FN99xx');
    expect(k1abc.theirName, isNot('Corrected Name'));
  });

  testWidgets('a name set via the More pane does not leak onto the next QSO after logging', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byIcon(resolveIconName('pencil')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Hiram');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 2);

    final w1aw = logged.firstWhere((q) => q.theirCall == 'W1AW');
    final k1abc = logged.firstWhere((q) => q.theirCall == 'K1ABC');
    expect(w1aw.theirName, 'Hiram');
    // The log-then-wipe must clear the override — K1ABC is a different human.
    expect(k1abc.theirName, isNull);
  });

  testWidgets('onCommandMessageChanged does not fire on every keystroke when the message is unchanged', (tester) async {
    final messages = <String?>[];
    await tester.pumpWidget(host(
      interpretCommand: fakeInterpretCommand,
      onCommandMessageChanged: messages.add,
    ));

    // Typing an ordinary callsign never produces a command message: the
    // callback must stay silent rather than firing null on every character
    // (which used to rebuild the whole QsoList per keystroke).
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1A');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));

    expect(messages, isEmpty);
  });

  testWidgets('onCallListLogged fires once after a comma-separated list logs, never for a single call', (tester) async {
    var callListLoggedCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          onCallListLogged: () => callListLoggedCount++,
        ),
      ),
    ));

    // Single call — must NOT fire.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 1);
    expect(callListLoggedCount, 0);

    // Comma-separated list — fires exactly once for the whole batch.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC, N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForQsos(tester, 3);
    expect(callListLoggedCount, 1);
  });

  testWidgets('call stacking: no information carries over between stacked calls — logging one wipes fully before restoring the rest', (tester) async {
    await tester.pumpWidget(host());

    // A touched Sent RST — state that should apply to the QSO being logged
    // but NOT carry over to whatever gets logged from the leftover stack.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirCall, 'W1AW');
    expect(logged.single.sentRST, '57'); // the touched RST applied to the logged QSO

    // The field now holds the remainder, but the touched RST is gone —
    // wiped back to the mode default, same as an ordinary log.
    final sentField = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent'));
    expect(sentField.controller!.text, '59');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC');
  });

  testWidgets('call stacking: lookup enrichment applies to the picked call and reaches the logged QSO', (tester) async {
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
    }) async {
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          lookup: lookup,
          enqueueLookup: enqueued.add,
        ),
      ),
    ));

    // Cursor ends up at the end (last segment, "W1AW") after enterText.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
    await tester.pump(const Duration(milliseconds: 400)); // let the debounced lookup resolve
    expect(find.textContaining('ARRL HQ'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirCall, 'W1AW');
    expect(logged.single.theirName, 'ARRL HQ');
    expect(logged.single.theirGrid, 'FN31pr');
    // The stacked save is handed to the background queue like any other new
    // QSO — had Enter beaten the preview debounce, the queue would still
    // enrich it (the queue skips records that already carry online data).
    expect(enqueued.map((q) => q.uuid).toList(), [logged.single.uuid]);
  });

  testWidgets('Escape wipes the entry and offers the same undo as the wipe button', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
    expect(await waitForQsos(tester, 1), isEmpty);

    // Esc goes through the wipe button's path, so the 5s undo offer applies.
    final undoIcon = resolveIconName('undo');
    expect(find.byIcon(undoIcon), findsOneWidget);
    await tester.tap(find.byIcon(undoIcon));
    await tester.pump();
    expect(callField.controller!.text, 'W1AW');
    expect(find.byIcon(undoIcon), findsNothing);

    // With nothing composed, Esc doesn't stash an empty entry as undoable.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byIcon(undoIcon), findsNothing);
  });

  testWidgets('debounced lookup enriches the entry line and the logged QSO', (tester) async {
    var lookups = 0;
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
    }) async {
      lookups++;
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          lookup: lookup,
          // The location line is formatted by the app layer (issue #40);
          // surface the guess's location so it can be asserted here.
          callLocationLine: (guess) => guess['location'] as String?,
        ),
      ),
    ));

    // Typing partial calls must not fire lookups until the debounce expires.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1A');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 100));
    expect(lookups, 0);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    // Two passes per resolved call: an offline pass, then an online pass.
    expect(lookups, 2);
    expect(find.textContaining('ARRL HQ'), findsOneWidget); // name, line 2
    expect(find.textContaining('Newington, CT'), findsOneWidget); // location, line 1

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirName, 'ARRL HQ');
    expect(logged.single.theirGrid, 'FN31pr');

    // Wipe cleared the enrichment line (after the info-area cross-fade settles).
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ARRL HQ'), findsNothing);
  });

  testWidgets('activity refList control folds refs into the logged QSO', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          activityControls: controls,
        ),
      ),
    ));
    await openControl(tester, MdiIcons.pineTree);

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
    ]);

    // Wipe cleared the control's field too.
    await openControl(tester, MdiIcons.pineTree);
    final potaField = tester.widget<TextField>(find.widgetWithText(TextField, 'POTA'));
    expect(potaField.controller?.text, '');
  });

  testWidgets('activity refList control accepts a comma-separated list of references', (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          activityControls: controls,
        ),
      ),
    ));
    await openControl(tester, MdiIcons.pineTree);

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
      {'type': 'pota', 'ref': 'US-5678'},
    ]);
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

  testWidgets('call-field commands: frequency, band, and mode via space', (tester) async {
    await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
    // Commands apply their changes without forcing the Radio control open
    // (see the dedicated test for that); open it manually here so the
    // assertions below can read its fields.
    await openControl(tester, MdiIcons.radio);

    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));
    Future<void> command(String text) async {
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), text);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // Wait for all command execution and state dispatching to finish
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Frequency command fills the freq field and derives the band.
    await command('14285');
    expect(field('Their call').controller!.text, isEmpty);
    expect(field('Their call').focusNode!.hasFocus, isTrue);
    expect(field('Frequency').controller!.text, '14285');
    expect(find.text('20m'), findsWidgets);

    // Mode command switches mode and resets untouched RSTs.
    await command('CW');
    expect(field('Sent').controller!.text, '599');

    // Band command overrides band and clears the frequency.
    await command('40M');
    expect(field('Frequency').controller!.text, isEmpty);
    expect(find.text('40m'), findsWidgets);

    // Log a QSO with the band-only state: band recorded, no frequency.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.band, '40m');
    expect(logged.single.freq, isNull);
    expect(logged.single.mode, 'CW');
  });

  testWidgets('clearing the frequency keeps the band it was last on', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    // A frequency derives its band.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.pump();
    expect(find.text('20m'), findsWidgets);

    // Clearing the frequency must NOT drop the band — it stays 20m.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '');
    await tester.pump();
    expect(find.text('20m'), findsWidgets);

    // Logging now records that retained band, with no frequency.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.band, '20m');
    expect(logged.single.freq, isNull);
  });

  testWidgets('call-field command awaiting params (expectsParams) allows space but stays uppercase, and Enter does not execute it', (tester) async {
    Future<Map<String, dynamic>?> fakeReloadPrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() == 'RELOAD') return {'expectsParams': true};
      return null;
    }

    await tester.pumpWidget(host(interpretCommand: fakeReloadPrefix));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
    await tester.pump(const Duration(milliseconds: 200)); // let the debounced interpret() resolve

    // Space is now a literal character, not the advance-focus shortcut.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'RELOAD ');
    expect(field('Their call').focusNode!.hasFocus, isTrue);

    // Typed lowercase is still uppercased: expectsParams alone lifts the
    // callsign character restriction (spaces), but only a command that
    // declares `mixedCase: true` lifts the uppercase-only rule — all
    // logging input is uppercase unless explicitly mixed-case.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD pota');
    await tester.pump();
    expect(field('Their call').controller!.text, 'RELOAD POTA');

    // Enter doesn't execute or clear an incomplete command.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(field('Their call').controller!.text, 'RELOAD POTA');
  });

  testWidgets('call-field command declaring mixedCase keeps lowercase, even once the command is complete', (tester) async {
    // Mirrors the real annotation-commands NOTE: `mixedCase: true` on BOTH
    // the bare-prefix result and the complete result. The second half is
    // what keeps "NOTE Called Bob," + more typing from being snapped back
    // to uppercase after the debounced interpret() sees a complete command.
    Future<Map<String, dynamic>?> fakeNoteCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      final match = RegExp(r'^NOTE(?:\s+(.*))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final text = match.group(1)?.trim();
      if (text == null || text.isEmpty) return {'expectsParams': true, 'mixedCase': true};
      return {
        'mixedCase': true,
        'describe': 'Add note "$text"?',
        'commands': [
          {'updateQso': {'notes': text}},
        ],
      };
    }

    await tester.pumpWidget(host(interpretCommand: fakeNoteCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE');
    await tester.pump(const Duration(milliseconds: 200));

    // Lowercase is preserved while the command awaits its parameter.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob');
    await tester.pump(const Duration(milliseconds: 200)); // interpret() now sees a COMPLETE command

    // Space stays literal and further lowercase still isn't uppercased —
    // the complete interpretation's mixedCase keeps the field free-text.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'NOTE Called Bob ');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob on the phone');
    await tester.pump();
    expect(field('Their call').controller!.text, 'NOTE Called Bob on the phone');
  });

  testWidgets('primary State and Grid fields uppercase typed input', (tester) async {
    // A formatter, not just TextCapitalization (a soft-keyboard hint that
    // does nothing for hardware keyboards): logging values are uppercase
    // unless explicitly mixed-case.
    await tester.pumpWidget(host(showStateField: true, showGridField: true));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'State'), 'fl');
    await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn31pr');
    await tester.pump();
    expect(field('State').controller!.text, 'FL');
    expect(field('Grid').controller!.text, 'FN31PR');
  });

  testWidgets('Sent/Rcvd accept letter RSTs and uppercase them', (tester) async {
    // Letters are legitimate in RSTs (CW's "5NN", aurora "59A"), and the
    // Edit QSO pane accepts them — a digits-only filter here would silently
    // strip a pane-saved letter on the next inline keystroke, because
    // filtering formatters re-run over the whole text.
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5nn');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59a');
    await tester.pump();
    expect(field('Sent').controller!.text, '5NN');
    expect(field('Rcvd').controller!.text, '59A');
  });

  testWidgets('abandoning a mixed-case command does not collapse the typed prose on the next keystroke', (tester) async {
    // Regression test: after "NOTE Called Bob" is edited into "NOT Called
    // Bob" (no longer a command), snapping the field straight back to
    // callsign mode would make the next keystroke re-run the callsign
    // character filter over the ENTIRE text — silently deleting every
    // space ("NOTCALLEDBOB…") with no undo. The retained free-text mode
    // must survive until the field is cleared instead.
    Future<Map<String, dynamic>?> fakeNoteCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      final match = RegExp(r'^NOTE(?:\s+(.*))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final text = match.group(1)?.trim();
      if (text == null || text.isEmpty) return {'expectsParams': true, 'mixedCase': true};
      return {
        'mixedCase': true,
        'describe': 'Add note "$text"?',
        'commands': [
          {'updateQso': {'notes': text}},
        ],
      };
    }

    await tester.pumpWidget(host(interpretCommand: fakeNoteCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob');
    await tester.pump(const Duration(milliseconds: 200));

    // Break the command prefix, let the debounced interpret() see it's no
    // longer a command, then keep typing.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOT Called Bob');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOT Called Bobs');
    await tester.pump();
    expect(field('Their call').controller!.text, 'NOT Called Bobs');

    // Clearing the field ends the retained free-text mode: a callsign typed
    // next is uppercased normally again.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'w1aw');
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW');
  });

  testWidgets('populating from a suggested QSO clears a lingering command state', (tester) async {
    // Regression test: type a complete NOTE command, then tap a spot — the
    // populate path runs under _populating, which suppresses
    // _onCallChanged's own per-keystroke reset, so without an explicit
    // reset the call field would show W1AW while still in the note's
    // free-prose mode, and the stale interpretation would make Space
    // insert a literal space instead of advancing focus.
    Future<Map<String, dynamic>?> fakeNoteCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      final match = RegExp(r'^NOTE(?:\s+(.*))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final text = match.group(1)?.trim();
      if (text == null || text.isEmpty) return {'expectsParams': true, 'mixedCase': true};
      return {
        'mixedCase': true,
        'describe': 'Add note "$text"?',
        'commands': [
          {'updateQso': {'notes': text}},
        ],
      };
    }

    await tester.pumpWidget(host(interpretCommand: fakeNoteCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE hi');
    await tester.pump(const Duration(milliseconds: 200)); // complete mixedCase interpretation stored

    // Tap a spot: didUpdateWidget applies the suggestion.
    await tester.pumpWidget(host(
      interpretCommand: fakeNoteCommand,
      suggestedQso: {
        'their': {'call': 'W1AW'},
      },
    ));
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW');

    // Space advances focus (no stale literal-space insertion)…
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW');
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    // …and the field is back in callsign mode: lowercase gets uppercased.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'w1aw/p');
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW/P');
  });

  testWidgets('call-field command awaiting params: space typed immediately (before the debounce resolves) is still recognized, not lost', (tester) async {
    // Regression test: _handleSpace must not trust a stale, debounce-lagged
    // _commandExpectsParams — it re-checks (or reuses an already-resolved)
    // interpretation synchronously before deciding, so a space typed right
    // after "RELOAD" in one fluent motion (no pause for the 150ms debounce)
    // still inserts a literal space instead of silently advancing focus.
    Future<Map<String, dynamic>?> fakeReloadPrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() == 'RELOAD') return {'expectsParams': true};
      return null;
    }

    await tester.pumpWidget(host(interpretCommand: fakeReloadPrefix));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
    // No pump/wait here — space arrives before the 150ms debounce could
    // possibly have resolved.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(field('Their call').controller!.text, 'RELOAD ');
    expect(field('Their call').focusNode!.hasFocus, isTrue);
  });

  testWidgets('call-field command parameters reach interpretCommand with their original case, not uppercased', (tester) async {
    // Regression test: the call field's own _call getter uppercases
    // everything (callsigns are case-insensitive), but that same value must
    // not leak into the argument passed to interpretCommand once a command
    // is capturing free text (e.g. NOTE's message) — otherwise lowercase
    // typed by the user is silently destroyed before the extension ever
    // sees it.
    final seenInputs = <String>[];
    Future<Map<String, dynamic>?> fakeNotePrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      seenInputs.add(input);
      // mixedCase, like the real NOTE command: without it the field's own
      // uppercase formatter would destroy the lowercase before
      // interpretCommand could ever see it.
      if (input.trim().toUpperCase() == 'NOTE') return {'expectsParams': true, 'mixedCase': true};
      return null;
    }

    await tester.pumpWidget(host(interpretCommand: fakeNotePrefix));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob, good signal');
    await tester.pump(const Duration(milliseconds: 200));

    expect(seenInputs, contains('NOTE Called Bob, good signal'));
  });

  testWidgets('a command action with no local widget effect (e.g. reloadDataFiles) still forwards to onCommandAction', (tester) async {
    // Regression test: _dispatchActions has an explicit per-action whitelist
    // (setVfo/updateQso/addQso/updateSettings/syncAll/setCallField/devNotice/
    // devStatus/devProgress/reloadDataFiles) — adding a new CommandAction field to the
    // SDK types without also adding its case here means the command
    // interprets fine but silently no-ops on execution, exactly what
    // happened when reloadDataFiles first shipped without this wiring.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeReloadCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'RELOADALL') return null;
      return {
        'describe': 'Reload all data files?',
        'confirm': 'Reloading all data files…',
        'commands': [
          {
            'reloadDataFiles': {'target': 'ALL'},
          },
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeReloadCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOADALL');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    // MapEntry has no value equality, so compare key/value separately
    // rather than the list of MapEntry objects directly.
    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'reloadDataFiles');
    expect(dispatched.single.value, {'target': 'ALL'});
  });

  testWidgets('devOnboard forwards to onCommandAction (same whitelist trap as reloadDataFiles)', (tester) async {
    // DEVONBOARD shipped interpreting fine but silently no-oping on
    // execution because _dispatchActions' whitelist lacked its branch —
    // the exact failure mode the test above documents.
    final dispatched = <String>[];
    Future<Map<String, dynamic>?> fakeDevOnboardCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'DEVONBOARD') return null;
      return {
        'describe': 'Show the onboarding overlay?',
        'confirm': 'Showing the onboarding overlay',
        'commands': [
          {'devOnboard': <String, dynamic>{}},
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeDevOnboardCommand,
      onCommandAction: (action, [params]) async => dispatched.add(action),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVONBOARD');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, ['devOnboard']);
  });

  testWidgets('SPOTLAST resolves to the last real QSO, skipping trailing event markers (ham2k/app-halo-dist#10)', (tester) async {
    // `qsos` is oldest-first (matches watchForOperation's ORDER BY
    // startAtMillis) — the event marker logged after both real QSOs must
    // NOT be picked just because it's last in the list.
    final firstQso = Qso(
      uuid: 'q1',
      operationUuid: operation.uuid,
      data: {'their': {'call': 'K1ABC'}, 'startAtMillis': 1000},
    );
    final lastRealQso = Qso(
      uuid: 'q2',
      operationUuid: operation.uuid,
      data: {'their': {'call': 'W1XYZ'}, 'startAtMillis': 2000},
    );
    final trailingEventMarker = Qso(
      uuid: 'evt',
      operationUuid: operation.uuid,
      data: {'band': 'event', 'startAtMillis': 3000},
    );

    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeSpotLastCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'SPOTLAST') return null;
      return {
        'describe': 'Spot the last logged QSO?',
        'confirm': 'Spotting last QSO…',
        'commands': [
          {'sendSpots': {'target': 'last'}},
        ],
      };
    }

    await tester.pumpWidget(host(
      existing: [firstQso, lastRealQso, trailingEventMarker],
      interpretCommand: fakeSpotLastCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SPOTLAST');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'sendSpots');
    final params = dispatched.single.value!;
    expect(params['target'], 'last');
    expect((params['qso'] as Map)['their'], {'call': 'W1XYZ'});
  });

  group('Spotting control pill label', () {
    // The collapsed pill is always one of the two short, fixed labels —
    // never the longer dynamic button text ("Self-spot at 7.200", "First
    // set a frequency to spot", "Spot KN2X at 7.200", "Too late to spot
    // KN2X"), which is reserved for the button inside the expanded panel.
    Future<List<Map<String, dynamic>>> noSources({required Map<String, dynamic> operation, Map<String, dynamic>? qso}) async => [];
    Future<Map<String, Map<String, dynamic>>> noopSend({
      required List<Map<String, dynamic>> sources,
      required Map<String, dynamic> operation,
      Map<String, dynamic>? qso,
      double? freq,
      String? mode,
      String? comment,
      String? spotterCall,
    }) async =>
        {};

    testWidgets('shows "Self-spotting" with no frequency set', (tester) async {
      await tester.pumpWidget(host(suggestSpotSources: noSources, sendSpot: noopSend));
      await tester.pump();
      expect(find.text('Self-spotting'), findsOneWidget);
      expect(find.text('First set a frequency to spot'), findsNothing);
    });

    testWidgets('shows "Self-spotting" (not "Self-spot at ...") once a frequency is set', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285);
      await tester.pumpWidget(host(radioService: fakeRadio, suggestSpotSources: noSources, sendSpot: noopSend));
      await tester.pump();
      expect(find.text('Self-spotting'), findsOneWidget);
      expect(find.textContaining('Self-spot at'), findsNothing);
    });

    testWidgets('shows "Spotting" (not "Spot ... at ..." or "Too late") while editing a recent QSO', (tester) async {
      final recentQso = Qso(
        uuid: 'recent',
        operationUuid: operation.uuid,
        data: {'their': {'call': 'KN2X'}, 'freq': 14285, 'startAtMillis': DateTime.now().millisecondsSinceEpoch},
      );
      await tester.pumpWidget(host(editingQso: recentQso, suggestSpotSources: noSources, sendSpot: noopSend));
      await tester.pump();
      expect(find.text('Spotting'), findsOneWidget);
      expect(find.textContaining('Spot KN2X'), findsNothing);
    });

    testWidgets('shows "Spotting" (not "Too late...") while editing a stale QSO', (tester) async {
      final staleQso = Qso(
        uuid: 'stale',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'KN2X'},
          'freq': 14285,
          'startAtMillis': DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
        },
      );
      await tester.pumpWidget(host(editingQso: staleQso, suggestSpotSources: noSources, sendSpot: noopSend));
      await tester.pump();
      expect(find.text('Spotting'), findsOneWidget);
      expect(find.textContaining('Too late'), findsNothing);
    });
  });

  testWidgets('note expansion: a setCallField command replaces the call field, and the result logs as a comma list', (tester) async {
    // `//KEY` (issue #17): the call-notes extension interprets "//DAN" into
    // a setCallField action carrying that entry's comma list of calls. The
    // replaced text must then behave exactly as if typed — Enter logs one
    // QSO per call (issue #7) — because expansion's entire purpose is
    // feeding the ordinary call-list path, not a parallel one.
    Future<Map<String, dynamic>?> fakeExpandCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != '//DAN') return null;
      return {
        'describe': 'Expand to WD4DAN,WD4JMM?',
        'commands': [
          {
            'setCallField': {'text': 'WD4DAN,WD4JMM'},
          },
        ],
      };
    }

    await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    // Leading "//" must reach command interpretation, not be mistaken for
    // call stacking (a stack's first segment would be empty, so Enter would
    // otherwise do nothing).
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(field('Their call').controller!.text, 'WD4DAN,WD4JMM');
    expect(field('Their call').controller!.selection.baseOffset, 'WD4DAN,WD4JMM'.length);
    expect(field('Their call').focusNode!.hasFocus, isTrue);
    expect(await waitForQsos(tester, 1), isEmpty); // expansion itself logs nothing

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 2);
    expect(logged.map((q) => q.theirCall).toSet(), {'WD4DAN', 'WD4JMM'});
  });

  testWidgets('a callsign note takes the name slot on the call-info line', (tester) async {
    // Issue #17: guess.note (from the call-notes lookup hook) usually
    // already names the operator, so it replaces guess.name on line 2
    // instead of joining it — same precedence app-polo gives notes.
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
    }) async {
      if (call != 'KI2D') return null;
      return {
        'guess': {'name': 'Sebastian', 'note': '🤩 Sebastián - Ham2K PoLo Creator', 'location': 'New York, NY'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          lookup: lookup,
          callLocationLine: (guess) => guess['location'] as String?,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    // The note's leading emoji is split into its own (glowed) widget; the
    // prose renders as markdown beside it.
    expect(find.text('🤩'), findsOneWidget); // leading emoji, glowed separately
    expect(find.textContaining('Sebastián - Ham2K PoLo Creator'), findsOneWidget); // note prose, line 2
    expect(find.textContaining('New York, NY'), findsOneWidget); // location, line 1
    expect(find.text('Sebastian'), findsNothing); // name is displaced by the note, not shown
  });

  testWidgets('seeds the Radio control from radioService.vfoA for a new QSO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '14285');
    expect(find.text('20m'), findsWidgets);
  });

  testWidgets('a brand new operation sees the same vfoA as any other — it is not per-operation', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final freshOperation = await operations.create(stationCall: 'KI2D');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: freshOperation,
          qsosRepository: qsos,
          radioService: fakeRadio,
        ),
      ),
    ));
    await openControl(tester, MdiIcons.radio);

    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '14285');
  });

  testWidgets('does not seed from radioService.vfoA while editing an existing QSO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
        'mode': 'SSB',
      },
    );
    await tester.pumpWidget(host(radioService: fakeRadio, editingQso: existingQso));
    await openControl(tester, MdiIcons.radio);

    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '7100');
  });

  testWidgets('Radio dropdowns offer the settings-enabled bands/modes, uncolored, plus the current value', (tester) async {
    await tester.pumpWidget(host(enabledBands: ['40m', '20m'], enabledModes: ['CW', 'FT8']));
    await openControl(tester, MdiIcons.radio);

    // Band menu: only the enabled bands — no colored entries (issue: band
    // colors made the dropdown hard to read).
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    // DropdownMenu instantiates each entry twice (one offstage copy for
    // width measurement), so "present" is findsWidgets, not findsOneWidget.
    expect(find.widgetWithText(MenuItemButton, '40m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '20m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '80m'), findsNothing);
    final bandItem = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, '40m').first);
    expect(bandItem.style?.foregroundColor, isNull);
    // Selecting an entry closes the menu.
    await tester.tap(find.widgetWithText(MenuItemButton, '40m').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    // Mode menu: the enabled modes plus the current mode (SSB, the compose
    // default), which stays pickable even though it's not in the enabled
    // list — same rule keeps a QSO on a since-disabled band/mode editable.
    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'CW'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, 'FT8'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, 'SSB'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, 'FM'), findsNothing);
  });

  testWidgets('empty enabled lists fall back to the common tier — deselecting every band must not empty the dropdown',
      (tester) async {
    await tester.pumpWidget(host(enabledBands: [], enabledModes: []));
    await openControl(tester, MdiIcons.radio);

    // popularBands, not the full catalog: 160m is common, 630m is not.
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, '80m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '160m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '630m'), findsNothing);
  });

  testWidgets('Radio dropdowns render at the same height as the sibling text fields', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    // The trailing arrow's default 48px min tap target used to make the
    // dropdowns a few pixels taller than the Frequency field beside them.
    final freqHeight = tester.getSize(find.widgetWithText(TextField, 'Frequency')).height;
    final dropdowns = find.byType(DropdownMenu<String>);
    expect(dropdowns, findsNWidgets(2));
    expect(tester.getSize(dropdowns.at(0)).height, freqHeight);
    expect(tester.getSize(dropdowns.at(1)).height, freqHeight);
  });

  testWidgets('typing in the Band dropdown filters the menu; focus-away selects the first match', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m', '17m']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '4');
    await tester.pump();
    // hitTestable: DropdownMenu keeps an offstage copy of the ORIGINAL
    // entries for width measurement — only the live menu reflects the
    // filter.
    expect(find.widgetWithText(MenuItemButton, '40m').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '20m').hitTestable(), findsNothing);

    // Moving focus away commits the first match as if it had been picked:
    // the field text resolves, the VFO hears about it, and the menu closes.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '40m');
    expect(fakeRadio.vfoA.band, '40m');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    // Type-to-filter is a desktop affordance — on touch platforms the
    // dropdown stays a pick-only button, so run these desktop-only.
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys step the Band selection while the menu is closed', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285);
    await tester.pumpWidget(host(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']));
    await openControl(tester, MdiIcons.radio);

    // Tabbing into the field focuses it WITHOUT opening the menu (a tap
    // always opens it) — the closed-menu arrow path is a keyboard flow.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(fakeRadio.vfoA.band, '40m');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '40m');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(fakeRadio.vfoA.band, '20m');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys walk the open Mode menu and blur commits the highlighted entry', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    // Two downs from the initial SSB: highlight SSB, then CW — walking
    // across a clock tick must not reset the highlight back to the top.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    // Blur commits the walked-to entry and hides the menu.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(fakeRadio.vfoA.mode, 'CW');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('typing a complete short band name narrows the menu instead of showing every band', (tester) async {
    // Regression: the filter used to switch OFF the moment the typed text
    // equalled a full option, so completing "2m" re-expanded the menu to
    // the whole catalog on the last keystroke.
    await tester.pumpWidget(host(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m', '2m']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '2m');
    await tester.pump();
    // "2m" matches only 2m (20m/80m/40m don't contain "2m"); the menu stays
    // narrowed rather than reverting to the full list.
    expect(find.widgetWithText(MenuItemButton, '2m').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '20m').hitTestable(), findsNothing);
    expect(find.widgetWithText(MenuItemButton, '80m').hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Enter from a focused Band dropdown commits the band and logs the QSO', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']));
    await openControl(tester, MdiIcons.radio);
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '40');
    await tester.pump();
    // Enter both commits the typed band and reaches the root log shortcut.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.first.band, '40m');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys keep a typed filter while walking the open menu', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();
    // Filtered to the F-modes; SSB/CW gone.
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);

    // Arrows walk WITHIN the filtered set, and the menu stays filtered —
    // the full-label writes the walk produces must not reset the filter,
    // not even across a clock tick. First down highlights FT8, second FT4.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);
    expect(find.widgetWithText(MenuItemButton, 'FT4').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT4');

    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(fakeRadio.vfoA.mode, 'FT4');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Enter commits the first matching mode; garbage text reverts', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'f');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(fakeRadio.vfoA.mode, 'FT8');

    // Text matching nothing must not change the selection — it reverts.
    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'zz');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(fakeRadio.vfoA.mode, 'FT8');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('an open Band menu holds its scroll position across the clock-tick rebuilds', (tester) async {
    // A selected band matters: the rebuild-time re-scroll only fires when
    // the field text matches an entry. Null enabled lists → the full
    // 19-band catalog, taller than the 10.5-entry menu cap, so it scrolls.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();

    final menuScrollable = find.ancestor(
      of: find.widgetWithText(MenuItemButton, '2190m').last,
      matching: find.byType(Scrollable),
    );
    final position = tester.widget<Scrollable>(menuScrollable.first).controller!.position;
    position.jumpTo(200);
    await tester.pump();
    expect(position.pixels, 200);

    // The Time chip's Timer.periodic setState rebuilds this widget every
    // second; with enableSearch on, each rebuild re-scrolled the menu back
    // to the selected entry, so the user could never scroll the list.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(position.pixels, 200);
  });

  testWidgets('a suggestedQso populates call/freq/band/mode for a new QSO', (tester) async {
    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(find.text('20m'), findsWidgets);
  });

  testWidgets('a suggestedQso is ignored while editingQso is set — it never clobbers an in-progress edit', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
      },
    );

    await tester.pumpWidget(host(editingQso: existingQso, suggestedQso: {
      'their': {'call': 'K1ABC'},
      'freq': 14074.0,
    }));

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
  });

  testWidgets('a new suggestedQso (different Map instance) re-applies over the previous one', (tester) async {
    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
    }));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'K1ABC'},
      'freq': 7100.0,
    }));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'K1ABC');
  });

  testWidgets('editing an existing QSO applies Radio control changes to the QSO, not the VFO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
        'mode': 'SSB',
      },
    );
    await tester.pumpWidget(host(radioService: fakeRadio, editingQso: existingQso));
    await openControl(tester, MdiIcons.radio);

    // Typing a frequency, past both the debounce and the blur flush...
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '21200');
    await tester.pump(const Duration(seconds: 6));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // ...picking a band...
    await tester.tap(find.widgetWithText(TextField, 'Band').first);
    await tester.pumpAndSettle();
    // DropdownMenu can leave a stale off-screen copy of a prior menu entry
    // around briefly — same harmless artifact as elsewhere in this file.
    await tester.tap(find.text('40m').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    // ...and picking a mode all leave the operation's VFO untouched.
    await tester.tap(find.widgetWithText(TextField, 'Mode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FT8').last);
    await tester.pumpAndSettle();

    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.mode, 'CW');
  });

  testWidgets('a command setVfo pushes to radioService immediately', (tester) async {
    await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand, radioService: fakeRadio));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14285');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.band, '20m');
  });

  testWidgets('manually typing a frequency pushes to radioService debounced, and flushes on blur', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.pump();
    // Not yet pushed — still within the debounce window.
    expect(fakeRadio.vfoA.freq, isNull);

    // Moving focus elsewhere flushes the pending push immediately, without
    // waiting out the rest of the 5s debounce.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.band, '20m');
  });

  testWidgets('a 3-digit or shorter frequency is not pushed to radioService', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '145');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    expect(fakeRadio.vfoA.freq, isNull);
  });

  testWidgets('picking a band from the dropdown pushes to radioService immediately', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('40m').last);
    await tester.pump();

    expect(fakeRadio.vfoA.band, '40m');
    expect(fakeRadio.vfoA.freq, isNull);
  });

  testWidgets('picking a mode from the dropdown pushes to radioService immediately', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CW').last);
    await tester.pump();

    expect(fakeRadio.vfoA.mode, 'CW');
  });

  testWidgets('a stale-but-unflushed typed frequency still lands on the logged QSO', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    // Typed, but Enter fires well within the 5s debounce window and
    // without blurring the field first.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.freq, 14285);
    expect(fakeRadio.vfoA.freq, 14285);
  });

  testWidgets('clearing the frequency field pushes the clear to radioService immediately, not debounced', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '');
    await tester.pump();

    // No 5s debounce wait, no blur — the clear takes effect right away.
    expect(fakeRadio.vfoA.freq, isNull);
  });

  testWidgets('ending an edit session re-seeds the Radio control from the VFO, not the just-edited QSO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
        'mode': 'SSB',
      },
    );

    final editing = ValueNotifier<Qso?>(existingQso);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<Qso?>(
          valueListenable: editing,
          builder: (context, editingQso, _) => LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            radioService: fakeRadio,
            editingQso: editingQso,
            onEditCanceled: () => editing.value = null,
          ),
        ),
      ),
    ));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7100');

    editing.value = null;
    await tester.pump();
    // Ending the edit collapses the secondary control row back to its
    // default (nothing expanded) — reopen it to read the re-seeded value.
    await openControl(tester, MdiIcons.radio);

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');
  });

  // Dupe detection (same call+band+mode, cursor segment within a call list,
  // stacked calls) moved to the scoreQso hook — see the extension's
  // scoreQso.test.ts. The widget's remaining responsibility is passing the
  // right candidate; the call-at-cursor selection is covered by the lookup
  // tests above, and excludeUuid by the test below.

  testWidgets('scoreQso excludes the QSO being edited (so it never self-dupes)', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
      },
    );

    String? excluded;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          qsos: [existingQso],
          editingQso: existingQso,
          scoreQso: ({required operation, required qso, excludeUuid}) async {
            excluded = excludeUuid;
            return {'notices': <String>[], 'alerts': <String>[]};
          },
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    // Editing populates the fields from the QSO, then scores it excluding
    // itself, so it can never flag itself as its own duplicate.
    expect(excluded, 'existing-uuid');
  });

  group('secondary control row', () {
    testWidgets('Time and Radio chips show by default; tapping expands, tapping again collapses', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byIcon(MdiIcons.clock), findsOneWidget);
      expect(find.byIcon(MdiIcons.radio), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);

      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
    });

    testWidgets('selecting a different control collapses the previous one', (tester) async {
      await tester.pumpWidget(host());

      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await openControl(tester, MdiIcons.clock);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
    });

    testWidgets('a successful command applies the change without opening the Radio control', (tester) async {
      await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14285');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // The command's frequency took effect (reflected in the still-closed
      // chip's summary text)...
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(find.text('14,285 • SSB'), findsOneWidget);

      // ...but the Radio control itself was not force-opened by it.
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text,
        '14285',
      );
    });

    testWidgets('Time control sets a manual timestamp used at log time; Now resets it', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clock);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '03:15');
      await tester.enterText(find.widgetWithText(TextField, 'Date'), '2026-01-02');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(
        DateTime.fromMillisecondsSinceEpoch(logged.single.startAtMillis!, isUtc: true),
        DateTime.utc(2026, 1, 2, 3, 15),
      );

      // Wipe resets to automatic timestamping for the next QSO.
      await openControl(tester, MdiIcons.clock);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot('03:15'));
    });

    testWidgets('Now button clears a manual time override', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clock);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '03:15');
      await tester.pump();
      expect(find.byIcon(MdiIcons.clock), findsOneWidget); // chip still rendered

      await tester.tap(find.widgetWithText(TextButton, 'Now'));
      await tester.pump();

      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot('03:15'));
    });

    testWidgets('Now actually restores automatic timestamping — the reseed must not re-freeze it', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clock);

      // A date that can never be "today", so Now's reseed always rewrites the
      // field text — which used to re-fire the manual-override listener and
      // silently re-freeze the clock the button had just released.
      await tester.enterText(find.widgetWithText(TextField, 'Date'), '2020-01-02');
      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '03:15');
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Now'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Now'));
      await tester.pump();

      // Now's visibility mirrors the override itself — gone means cleared.
      expect(find.widgetWithText(TextButton, 'Now'), findsNothing);
    });

    testWidgets('saving the More pane without editing date/time keeps automatic timestamping', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byIcon(resolveIconName('pencil')), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // The dialog merely displayed the live clock; saving it untouched must
      // not convert that snapshot into a manual override.
      await openControl(tester, MdiIcons.clock);
      expect(find.widgetWithText(TextButton, 'Now'), findsNothing);
    });

    ChoiceChip timeChip(WidgetTester tester) => tester.widget<ChoiceChip>(
          find.ancestor(of: find.byIcon(MdiIcons.clock), matching: find.byType(ChoiceChip)),
        );

    testWidgets('Time chip shows a live clock, not a static "now" label', (tester) async {
      await tester.pumpWidget(host());

      String summary() => (timeChip(tester).label as Text).data!;

      // HH:MM:SSz — a real clock, matching app-polo's "17:06:49z" reference.
      // (Not asserting the value changes across a pump: DateTime.now() reads
      // the real wall clock, which FakeAsync's virtual time in tests doesn't
      // advance — only Timer scheduling is virtualized. The Timer firing
      // safely, repeatedly, without error is what's actually verifiable
      // here; genuine tick-to-tick change is exercised by hand on-device.)
      expect(summary(), matches(RegExp(r'^\d{2}:\d{2}:\d{2}z$')));
      await tester.pump(const Duration(seconds: 2));
      expect(summary(), matches(RegExp(r'^\d{2}:\d{2}:\d{2}z$')));
    });

    testWidgets('Now button stays hidden until a manual time override is actually set', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clock);

      expect(find.widgetWithText(TextButton, 'Now'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '03:15');
      await tester.pump();

      expect(find.widgetWithText(TextButton, 'Now'), findsOneWidget);
    });

    testWidgets('editing an existing QSO shows its recorded time and never offers Now', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': DateTime.utc(2020, 3, 4, 12, 30).millisecondsSinceEpoch,
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(operation: operation, qsosRepository: qsos, editingQso: existingQso),
        ),
      ));

      // Shows the existing QSO's own time — static, not a live clock, with
      // an explicit :00 seconds since the stored value has none.
      expect((timeChip(tester).label as Text).data, '12:30:00z');
      await tester.pump(const Duration(seconds: 2));
      expect((timeChip(tester).label as Text).data, '12:30:00z');

      await openControl(tester, MdiIcons.clock);
      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, '12:30');
      expect(find.widgetWithText(TextButton, 'Now'), findsNothing);

      // Even after editing away from the original recorded time, Now never
      // appears — there's no "automatic" to reset a historical entry to.
      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '05:00');
      await tester.pump();
      expect(find.widgetWithText(TextButton, 'Now'), findsNothing);
    });

    testWidgets('activity control chip has no border, before or after a ref is entered', (tester) async {
      const controls = [
        {
          'key': 'pota/hunter',
          'label': 'POTA',
          'icon': 'pine-tree',
          'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
        },
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(operation: operation, qsosRepository: qsos, activityControls: controls),
        ),
      ));

      ChoiceChip potaChip() => tester.widget<ChoiceChip>(find.ancestor(
            of: find.byIcon(MdiIcons.pineTree),
            matching: find.byType(ChoiceChip),
          ));
      expect(potaChip().side, BorderSide.none);

      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(potaChip().side, BorderSide.none);
    });

    testWidgets('chips match app-polo LoggerChip styling: tertiary family, rounded rectangle', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: Scaffold(
          body: LoggingControls(operation: operation, qsosRepository: qsos),
        ),
      ));

      final chip = tester.widget<ChoiceChip>(find.ancestor(
        of: find.byIcon(MdiIcons.radio),
        matching: find.byType(ChoiceChip),
      ));
      expect(chip.backgroundColor, HaLoColors.light.tertiaryLight);
      expect(chip.selectedColor, const Color(0xFF964900)); // colorScheme.tertiary
      expect(chip.shape, isA<RoundedRectangleBorder>());
      expect((chip.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(8));

      // The whole panel — not just the chips — carries the tertiary tint.
      // (ChoiceChip has its own internal Material for ink effects, so we
      // match by fill color instead of "closest Material ancestor.")
      expect(
        find.byWidgetPredicate((w) => w is Material && w.color == const Color(0xFFFFDCC6)),
        findsOneWidget,
      );
    });
  });

  group('wipe/undo, delete/undo, revert-changes button', () {
    IconButton secondButton(WidgetTester tester, IconData icon) => tester.widget<IconButton>(
          find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
        );

    final wipeIcon = resolveIconName('backspace');
    final undoIcon = resolveIconName('undo');
    final deleteIcon = resolveIconName('trash-can-outline');

    testWidgets('wipe is disabled with nothing entered, enabled once a call is typed, and wiping offers a 5s undo', (tester) async {
      await tester.pumpWidget(host());

      expect(secondButton(tester, wipeIcon).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      expect(secondButton(tester, wipeIcon).onPressed, isNotNull);

      await tester.tap(find.byIcon(wipeIcon));
      await tester.pump();

      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.controller!.text, isEmpty);
      expect(find.byIcon(wipeIcon), findsNothing);
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      expect(callField.controller!.text, 'W1AW');
      expect(find.byIcon(undoIcon), findsNothing);
      expect(find.byIcon(wipeIcon), findsOneWidget);
    });

    testWidgets('wipe stays disabled for a fresh new QSO even though the Radio control shows the VFO frequency',
        (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
      await tester.pumpWidget(host(radioService: fakeRadio));
      await openControl(tester, MdiIcons.radio);

      final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
      expect(freqField.controller!.text, '14285');
      expect(secondButton(tester, wipeIcon).onPressed, isNull);
    });

    testWidgets('the wipe undo option expires after 5 seconds even if the user starts typing again', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.byIcon(wipeIcon));
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K2HAM');
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget); // still available mid-retype

      await tester.pump(const Duration(seconds: 5));
      expect(find.byIcon(undoIcon), findsNothing);
      expect(find.byIcon(wipeIcon), findsOneWidget);

      // Expiry only hides the undo option — it doesn't touch what's typed.
      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.controller!.text, 'K2HAM');
    });

    testWidgets('editing an unmodified QSO shows delete; tapping stages it and offers undo', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW', 'sent': ''},
          'our': {'sent': '59', 'call': 'KI2D'},
          'mode': 'SSB',
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(operation: operation, qsosRepository: qsos, editingQso: existingQso),
        ),
      ));

      expect(secondButton(tester, deleteIcon).onPressed, isNotNull);
      expect(find.byIcon(undoIcon), findsNothing);

      await tester.tap(find.byIcon(deleteIcon));
      await tester.pump();

      expect(find.textContaining('will be deleted'), findsOneWidget);
      expect(find.byIcon(deleteIcon), findsNothing);
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      expect(find.textContaining('will be deleted'), findsNothing);
      expect(find.byIcon(deleteIcon), findsOneWidget);
    });

    testWidgets('editing changes the second button to revert-changes; tapping restores the original values', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW', 'sent': '59'},
          'our': {'sent': '59', 'call': 'KI2D'},
          'mode': 'SSB',
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(operation: operation, qsosRepository: qsos, editingQso: existingQso),
        ),
      ));

      expect(find.byIcon(deleteIcon), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();

      expect(find.byIcon(deleteIcon), findsNothing);
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byIcon(undoIcon));
      await tester.pump();

      final sentField = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent'));
      expect(sentField.controller!.text, '59');
      expect(find.byIcon(deleteIcon), findsOneWidget);
      expect(find.byIcon(undoIcon), findsNothing);
    });

    testWidgets('viewing a deleted QSO locks the fields and offers restore; tapping it undeletes (issue #59)', (tester) async {
      final restoreIcon = resolveIconName('delete-restore');
      final deletedQso = (await tester.runAsync(() async {
        final qso = await qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': '59'},
          'mode': 'SSB',
        });
        await qsos.softDelete(qso);
        return (await qsos.watchForOperation(operation.uuid, includeDeleted: true).first).single;
      }))!;

      var editCanceled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            editingQso: deletedQso,
            onEditCanceled: () => editCanceled = true,
          ),
        ),
      ));

      // Restore replaces delete/revert entirely, the fields are read-only,
      // and both save paths (button and Enter) are inert until restored.
      expect(find.textContaining('Deleted QSO'), findsOneWidget);
      expect(find.byIcon(deleteIcon), findsNothing);
      expect(secondButton(tester, restoreIcon).onPressed, isNotNull);
      final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
      expect(callField.enabled, isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      var stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid, includeDeleted: true).first))!;
      expect(stored.single.deleted, isTrue);

      // Escape must not blank the locked view either — the fields are the
      // deleted record's only display and can't repopulate without
      // reselecting it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(callField.controller!.text, 'W1AW');

      await tester.tap(find.byIcon(restoreIcon));
      for (var i = 0; i < 20 && !editCanceled; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
      expect(stored.single.deleted, isFalse);
      expect(editCanceled, isTrue);
    });
  });
}

/// In-memory stand-in for the app's `RadioService` (which lives outside
/// this package, in the Flutter app rather than halo_widgets) — just
/// enough of `VfoStore` to verify LoggingControls seeds from and writes
/// back to it, without a real SharedPreferences-backed store.
class _FakeVfoStore implements VfoStore {
  Vfo _vfoA = const Vfo();

  @override
  Vfo get vfoA => _vfoA;

  @override
  void setVfo(String key, {double? freq, String? band, String? mode, bool clearFreq = false}) {
    if (key != 'vfoA') return;
    if (freq != null) {
      _vfoA = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? _vfoA.mode);
    } else if (band != null || clearFreq) {
      _vfoA = Vfo(freq: null, band: band ?? _vfoA.band, mode: mode ?? _vfoA.mode);
    } else {
      _vfoA = Vfo(freq: _vfoA.freq, band: _vfoA.band, mode: mode ?? _vfoA.mode);
    }
  }
}
