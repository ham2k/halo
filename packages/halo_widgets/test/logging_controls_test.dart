// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Widget tests drive the keyboard flows; database verification goes through
// tester.runAsync() because drift's futures/timers otherwise sit unresolved
// in testWidgets' FakeAsync zone. Interleaved pumps let widget-initiated
// writes (which start inside the fake zone) run to completion.

import 'dart:async';

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

  /// The same operation, but running the given activities.
  ///
  /// Primary fields are gated on this: a control only reaches the entry row if
  /// the operation carries a ref of the type it writes to. Tests that exercise
  /// a contest exchange have to say which contest is being run, exactly as the
  /// operator has to add the activity before the field appears.
  Operation running(List<String> refTypes) => Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [for (final type in refTypes) {'type': type}],
        },
      );

  Widget host({
    List<Qso> existing = const [],
    CommandInterpreter? interpretCommand,
    Stream<Map<String, dynamic>>? interpretationUpdates,
    void Function(String? message)? onCommandMessageChanged,
    CommandActionHandler? onCommandAction,
    CallInfoChanged? onCallInfoChanged,
    VfoStore? radioService,
    Qso? editingQso,
    VoidCallback? onEditCanceled,
    VoidCallback? onEscapeDeselect,
    bool Function()? onUndoDeselect,
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
    void Function(Iterable<Qso> qsos)? enqueueAllLookups,
    Widget? trailing,
  }) {
    final controls = LoggingControls(
      operation: operation,
      qsosRepository: qsos,
      qsos: existing,
      enqueueLookup: enqueueLookup,
      enqueueAllLookups: enqueueAllLookups,
      interpretCommand: interpretCommand,
      interpretationUpdates: interpretationUpdates,
      onCommandMessageChanged: onCommandMessageChanged,
      onCommandAction: onCommandAction,
      onCallInfoChanged: onCallInfoChanged,
      radioService: radioService,
      editingQso: editingQso,
      onEditCanceled: onEditCanceled,
      onEscapeDeselect: onEscapeDeselect,
      onUndoDeselect: onUndoDeselect,
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

  /// Pumps until a serial field has picked up its previewed number. The peek is
  /// a drift query kicked off outside the frame, so it needs interleaved pumps
  /// to resolve — same reasoning as waitForQsos below.
  Future<void> pumpUntilSerial(WidgetTester tester, String label) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      final text = tester.widget<TextField>(find.widgetWithText(TextField, label)).controller?.text ?? '';
      if (text.isNotEmpty) return;
    }
  }

  /// Pumps until the operation's QSO list reaches [count] (or gives up).
  Future<List<Qso>> waitForQsos(WidgetTester tester, int count, {QsosRepository? repository}) async {
    final repo = repository ?? qsos;
    var logged = <Qso>[];
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      logged = (await tester.runAsync(() => repo.watchForOperation(operation.uuid).first))!;
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

  testWidgets('the call field and Log/Wipe buttons carry stable semantics identifiers (#236)', (tester) async {
    // Translation-independent hooks for agent/browser tooling — a rename or a
    // dropped wrapper must fail here, not silently strip the targets.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.bySemanticsIdentifier('field.call'), findsOneWidget);
    expect(find.bySemanticsIdentifier('action.log'), findsOneWidget);
    expect(find.bySemanticsIdentifier('action.wipe'), findsOneWidget);
    handle.dispose();
  });

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
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
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
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
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
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
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

  testWidgets(
      'editing a QSO into a comma-separated list: the original record survives untouched; saving only enqueues the newly added call, not the original again',
      (tester) async {
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
    // Opening it for editing enqueues it once, on its own (it never had an
    // online lookup) — asserted here so the rest of this test can focus on
    // what SAVING does, without that opening-time enqueue muddying it.
    expect(enqueued.map((q) => q.uuid).toList(), [existingQso.uuid]);

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
    // cached for the original call — and saving doesn't enqueue the
    // original record a second time.
    expect(k1abc.theirName, isNull);
    expect(enqueued.map((q) => q.uuid).toList(), [existingQso.uuid, k1abc.uuid]);
  });

  testWidgets('constructed already editing a QSO enqueues it for a background lookup (ham2k/app-halo-dist#279 follow-up)',
      (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(host(editingQso: existingQso, enqueueLookup: enqueued.add));

    // enqueueLookup itself decides (via LookupQueueService, tested
    // separately) whether the record actually needs a fresh lookup —
    // LoggingControls' job is just to always offer it up on open.
    expect(enqueued.map((q) => q.uuid).toList(), [existingQso.uuid]);
  });

  testWidgets('selecting a different QSO to edit (not constructing already editing one) also enqueues it',
      (tester) async {
    final first = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
        })))!;
    final second = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'K1ABC'},
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(host(editingQso: first, enqueueLookup: enqueued.add));
    expect(enqueued.map((q) => q.uuid).toList(), [first.uuid]);

    // Same widget, editingQso transitions via didUpdateWidget — not a fresh
    // construction, the other code path that also has to enqueue.
    await tester.pumpWidget(host(editingQso: second, enqueueLookup: enqueued.add));
    expect(enqueued.map((q) => q.uuid).toList(), [first.uuid, second.uuid]);
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

  testWidgets('command actions that add QSOs (e.g. SEED) enqueue the whole batch for background lookup at once', (tester) async {
    // The extension side only attaches fast offline guesses when seeding
    // (network lookups there would stall the whole command) — the full
    // online enrichment is the queue's job, after the QSOs are on screen.
    // The batch goes through enqueueAllLookups (not the per-QSO
    // enqueueLookup) so it reuses the same "Lookup all QSOs" bulk mechanism
    // and progress reporting, fired once the whole command has finished
    // adding QSOs rather than QSO-by-QSO.
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

    final enqueuedSingly = <Qso>[];
    final enqueuedBatches = <List<Qso>>[];
    await tester.pumpWidget(host(
      interpretCommand: interpret,
      enqueueLookup: enqueuedSingly.add,
      enqueueAllLookups: (qsos) => enqueuedBatches.add(qsos.toList()),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SEED');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    expect(enqueuedSingly, isEmpty, reason: 'SEED batches through enqueueAllLookups, not per-QSO enqueueLookup');
    expect(enqueuedBatches, hasLength(1), reason: 'one batch for the whole command, not one call per QSO');
    expect(enqueuedBatches.single.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC']);
    expect(enqueuedBatches.single.map((q) => q.uuid).toSet(), logged.map((q) => q.uuid).toSet());
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

  testWidgets('call-info reports isEditing so the map can colour the current QSO (orange composing, blue editing)', (tester) async {
    // The map reads CallInfoData.isEditing to pick the highlight colour.
    final infos = <CallInfoData>[];
    void capture(CallInfoData? info) {
      if (info != null) infos.add(info);
    }

    // Composing a new QSO → isEditing false.
    await tester.pumpWidget(host(onCallInfoChanged: capture));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    expect(infos, isNotEmpty, reason: 'a real callsign produces call-info');
    expect(infos.last.isEditing, isFalse, reason: 'composing a new QSO');

    // Editing an existing QSO → isEditing true (its call auto-populates the field).
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'K1ABC'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        })))!;
    infos.clear();
    await tester.pumpWidget(host(editingQso: existingQso, onCallInfoChanged: capture));
    await tester.pump(const Duration(milliseconds: 200));
    expect(infos, isNotEmpty);
    expect(infos.last.isEditing, isTrue, reason: 'editing an existing QSO');
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

  testWidgets('a second Escape restores an Escape-wiped entry, same as tapping Undo (issue #199 follow-up)',
      (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // wipes, offers undo
    await tester.pump();

    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // restores instead of re-wiping an empty form
    await tester.pump();

    expect(callField.controller!.text, 'W1AW');
    expect(find.byIcon(resolveIconName('undo')), findsNothing);
  });

  testWidgets('with nothing composed and no wipe to undo, Escape asks the caller if it has something to undo instead',
      (tester) async {
    var undoAttempts = 0;
    var undone = false;
    await tester.pumpWidget(host(onUndoDeselect: () {
      undoAttempts++;
      return undone;
    }));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(undoAttempts, 1);

    // When the caller says there was nothing to undo, Escape still falls
    // through to its normal (here, no-op) empty-form wipe — no exception,
    // no dead end.
    undone = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(undoAttempts, 2);
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

  testWidgets('restoring a wiped entry re-runs the lookup, not just its stale cached result', (tester) async {
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
          callLocationLine: (guess) => guess['location'] as String?,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 2); // offline + online pass
    expect(find.textContaining('ARRL HQ'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // wipes, offers undo
    await tester.pump();
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);

    await tester.tap(find.byIcon(resolveIconName('undo')));
    await tester.pump();
    expect(callField.controller!.text, 'W1AW');

    // The wipe cleared the lookup cache along with the fields — restoring
    // must schedule a fresh lookup, not leave the entry unlooked-up until
    // the user edits the field themselves.
    expect(lookups, 2); // unchanged immediately — the lookup is debounced
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 4);
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
  });

  testWidgets('restoring a wiped entry also re-runs scoring, not just the lookup', (tester) async {
    // Same wipe-then-undo flow as the lookup regression above, but for the
    // dupe/New-* score pill: _wipe() clears score notices along with the
    // lookup cache, so restoring must re-trigger scoring too, or the pill
    // stays gone until the user edits the field themselves.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
              {'notices': <String>[], 'alerts': ['duplicate']},
          scoreNoticeLabel: (key) => key == 'duplicate' ? 'Dupe!' : key,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Dupe!'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // wipes, offers undo
    await tester.pump();
    expect(find.text('Dupe!'), findsNothing);

    await tester.tap(find.byIcon(resolveIconName('undo')));
    await tester.pump();
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'W1AW');

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Dupe!'), findsOneWidget);
  });

  group('only a running activity gets the entry row', () {
    // The entry row is the scarcest space in the app, and EVERY enabled
    // extension is asked for logging controls on every operation. So the core
    // decides who gets in: a primary field only if the operation carries a ref
    // of the type it writes to. Extensions may short-circuit for their own
    // efficiency, but they are not what enforces this — an extension that
    // forgets must not be able to put its exchange in front of someone logging
    // an ordinary QSO, and a stray `serial` field would be worse still,
    // handing out numbers from a series nobody is keeping.
    const exchange = {
      'key': 'contest/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
    };
    const serial = {
      'key': 'contest/ourSerial',
      'label': 'Our #',
      'icon': 'flag-checkered',
      'input': {
        'kind': 'serial',
        'refType': 'contest',
        'field': 'ourSerial',
        'sequence': {'key': 'serial'},
      },
    };
    // POTA's hunter chip is the reason secondary controls are NOT gated: you
    // chase a park from whatever operation you happen to be running.
    const hunter = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'potaHunter'},
    };

    Widget hostFor(Operation op, List<Map<String, dynamic>> controls, {QsosRepository? repo}) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(operation: op, qsosRepository: repo ?? qsos, activityControls: controls),
          ),
        );

    testWidgets('an exchange field is hidden when the operation is not running that contest', (tester) async {
      await tester.pumpWidget(hostFor(operation, const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('the same field appears once the activity is added', (tester) async {
      await tester.pumpWidget(hostFor(running(['contest']), const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget);
    });

    testWidgets('another contest running does not let this one in', (tester) async {
      // The gate is per ref type, not "is any contest active" — two contests
      // can be set up at once and only one may own a given field.
      await tester.pumpWidget(hostFor(running(['other-contest']), const [exchange]));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('a secondary chip is still offered from an operation running nothing', (tester) async {
      await tester.pumpWidget(hostFor(operation, const [hunter]));
      await tester.pump();
      expect(find.byIcon(resolveIconName('pine-tree')), findsOneWidget);
    });

    testWidgets('a serial from a contest that is not running allocates no number', (tester) async {
      // The severe case. A number issued here is spent forever — the counter
      // never rolls back — so a log for a contest the operator never entered
      // would silently consume the series.
      final repo = QsosRepository(db, sequences: SequencesRepository(db));
      await tester.pumpWidget(hostFor(operation, const [serial], repo: repo));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Our #'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, isEmpty, reason: 'no contest ref, and no number spent');
    });

    testWidgets("an inactive contest's exchange survives editing a QSO that carries it", (tester) async {
      // Removing the activity must not destroy what already went out on the
      // air. The field is hidden, so nothing can edit it — and it has to
      // round-trip untouched rather than being dropped on the next save.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
        'refs': [
          {'type': 'contest', 'exchange': 'MA 042'},
        ],
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [exchange],
            editingQso: existing,
          ),
        ),
      ));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'contest', 'exchange': 'MA 042'},
      ]);
    });
  });

  group('decorateQsoBeforeSave', () {
    // An activity's last chance to project data it owns into generic QSON
    // fields. It has to run on EVERY save path — a QSO decorated only when
    // logged one way would export differently depending on how it was typed.
    Widget hostWith(
      Future<Map<String, dynamic>> Function(Map<String, dynamic>) decorate, {
      Qso? editing,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              operation: operation,
              qsosRepository: qsos,
              decorateQsoBeforeSave: decorate,
              editingQso: editing,
            ),
          ),
        );

    Future<Map<String, dynamic>> addExchange(Map<String, dynamic> qso) async => {
          ...qso,
          'their': {...(qso['their'] as Map?)?.cast<String, dynamic>() ?? {}, 'exchange': 'ZN5'},
        };

    testWidgets('decorates a single logged QSO', (tester) async {
      await tester.pumpWidget(hostWith(addExchange));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirExchange, 'ZN5');
      expect(logged.single.theirCall, 'W1AW', reason: 'the patch must not clobber the callsign');
    });

    testWidgets('decorates every call of a call list, not just the first', (tester) async {
      await tester.pumpWidget(hostWith(addExchange));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW,K1ABC,N1XYZ');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 3);
      expect(logged, hasLength(3));
      expect(logged.map((q) => q.theirExchange), everyElement('ZN5'));
    });

    testWidgets('decorates an edited QSO too', (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
      });
      await tester.pumpWidget(hostWith(addExchange, editing: existing));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirExchange, 'ZN5');
    });

    testWidgets('a QSO still saves when no decorator is wired', (tester) async {
      // Every test and tooling path leaves it null; saving must not depend on it.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LoggingControls(operation: operation, qsosRepository: qsos)),
      ));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.theirCall, 'W1AW');
      expect(logged.single.theirExchange, isNull);
    });
  });

  testWidgets('activity text control folds a contest exchange into the logged QSO', (tester) async {
    // The on-air exchange is the whole point of a contest control: whatever the
    // operator types must reach the QSO's contest ref, or the log is unusable
    // for submission.
    const controls = [
      {
        'key': 'simple-contest/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'exchange', 'placeholder': '59 001'},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(operation: running(['simple-contest']), qsosRepository: qsos, activityControls: controls),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA 042');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'simple-contest', 'exchange': 'MA 042'},
    ]);

    // Logging wiped the field, so the next QSO starts clean rather than
    // silently repeating the previous station's exchange.
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
    expect(field.controller?.text, '');
  });

  group('searchable options exchange', () {
    // A `kind: 'options'` field is a text field that searches a known set. It
    // joins the same pipeline as `text`, so save, restore, focus cycling and
    // the blank rule are inherited rather than reimplemented — these cover what
    // is genuinely new: validation against the set, the suggestion line, and
    // Space accepting the top hit BEFORE it advances.
    const counties = [
      {'code': 'ASD', 'name': 'Ashland'},
      {'code': 'CUY', 'name': 'Cuyahoga'},
      {'code': 'WAS', 'name': 'Washington'},
    ];

    List<Map<String, dynamic>> controlsWith(Map<String, dynamic> extra) => [
          {
            'key': 'qp/county',
            'label': 'County',
            'icon': 'flag-checkered',
            'input': {
              'kind': 'options',
              'refType': 'qp',
              'field': 'county',
              'options': counties,
              ...extra,
            },
          },
        ];

    Widget host({Map<String, dynamic> extra = const {}}) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              operation: running(['qp']),
              qsosRepository: qsos,
              activityControls: controlsWith(extra),
            ),
          ),
        );

    testWidgets('is a primary field, so it saves onto the ref like any exchange', (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'qp', 'county': 'CUY'},
      ]);
    });

    testWidgets('suggests matches for what is typed, best first', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      // ASD by code prefix, then WAS by code substring. The line shows names
      // too, since a name is often what the operator actually remembers.
      expect(find.textContaining('ASD'), findsWidgets);
      expect(find.textContaining('Ashland'), findsWidgets);
      expect(find.textContaining('WAS'), findsWidgets);
    });

    testWidgets('Space accepts the top suggestion AND still advances', (tester) async {
      // The advance is what an operator's hands expect on every field; losing
      // it to a searchable one would be worse than never suggesting at all.
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'CUY',
        reason: 'the partial "CU" was completed from the set',
      );
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus,
        isFalse,
        reason: 'and focus moved on, as Space always does',
      );
    });

    testWidgets('Space with no match just advances, changing nothing', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'ZZ',
        reason: 'nothing matched, so nothing was rewritten under the operator',
      );
    });

    testWidgets('a value outside the set is flagged, because it is a lost multiplier', (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ');
      await tester.pump();

      InputDecoration decoration() =>
          tester.widget<TextField>(find.widgetWithText(TextField, 'County')).decoration!;
      final errorColor = Theme.of(tester.element(find.widgetWithText(TextField, 'County'))).colorScheme.error;

      // The field's own underline carries the tint. NOT `errorText`: a decorator
      // with an error reserves its error slot even when the text is empty and
      // styled to zero height, which made the field taller and pushed every
      // primary control down as the operator typed — see the layout test below.
      expect(decoration().errorText, isNull, reason: 'no error slot, so no resize');
      expect((decoration().enabledBorder as UnderlineInputBorder).borderSide.color, errorColor);
      expect((decoration().focusedBorder as UnderlineInputBorder).borderSide.color, errorColor);

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'WAS');
      await tester.pump();
      expect(decoration().enabledBorder, isNull, reason: 'a recognized value gets the ordinary border back');
      expect((decoration().focusedBorder as UnderlineInputBorder).borderSide.color, isNot(errorColor));
    });

    testWidgets('allowFreeform accepts a value the set does not know', (tester) async {
      // Some exchanges are genuinely open-ended; the set is then a shortcut,
      // not a constraint.
      await tester.pumpWidget(host(extra: const {'allowFreeform': true}));
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ');
      await tester.pump();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).decoration?.errorText,
        isNull,
      );
    });

    testWidgets('minCharsForSuggestions holds the line back until it is useful', (tester) async {
      await tester.pumpWidget(host(extra: const {'minCharsForSuggestions': 2}));
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'A');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsWidgets);
    });

    testWidgets('Space on an EMPTY field writes nothing — it is just "next field"', (tester) async {
      // An empty query's suggestion list is the whole SET, so accepting the top
      // hit logged whichever option happened to be declared first — for an
      // operator who simply hadn't been given the exchange yet and was moving on.
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        '',
        reason: 'ASD is first in the set and must not have been written',
      );
    });

    testWidgets('Space refuses a suggestion the typed text does not START', (tester) async {
      // A substring hit is worth SHOWING — it is how you find a county from the
      // middle of its name — but swapping it in replaces what the operator typed
      // with a code their own text isn't a prefix of.
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'SH');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsWidgets, reason: 'matched by name substring');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'SH',
        reason: 'shown, not accepted',
      );
    });

    testWidgets('the offers float over the fields as a menu, the best row nearest the field', (tester) async {
      // They started as a line in the info area, which cost the call-info panel
      // — the DUPE warning with it — its space for as long as an exchange field
      // had focus. As a floating menu they cover that area instead: nothing in
      // the layout moves as the operator types, and the panel keeps saying what
      // it said.
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      final menu = find.byKey(exchangeSuggestionsKey);
      expect(menu, findsOneWidget);
      Finder inMenu(String text) => find.descendant(of: menu, matching: find.text(text));

      // ASD matches by code prefix, WAS only by code substring.
      expect(inMenu('ASD'), findsOneWidget);
      expect(inMenu('Ashland'), findsOneWidget, reason: 'the name reads beside the code');
      expect(inMenu('WAS'), findsOneWidget);

      // BOTTOM is best: the eye is already at the field, and Space takes this one.
      expect(
        tester.getCenter(inMenu('ASD')).dy,
        greaterThan(tester.getCenter(inMenu('WAS')).dy),
        reason: 'the best match sits nearest the field, at the bottom of the menu',
      );
      // ...and it is the only one in bold.
      expect(tester.widget<Text>(inMenu('ASD')).style?.fontWeight, FontWeight.w700);
      expect(tester.widget<Text>(inMenu('WAS')).style?.fontWeight, FontWeight.w400);

      // One rectangle with a shadow, not a stack of chips, and in the DIALOG
      // colours rather than the panel's accent — it floats over the panel.
      final material = tester.widget<Material>(find.descendant(of: menu, matching: find.byType(Material)).first);
      expect(material.elevation, greaterThan(0));
      expect(material.color, Theme.of(tester.element(menu)).colorScheme.surface);

      // Monospace codes: log data, read as a column and compared character by
      // character against what is in the field.
      expect(tester.widget<Text>(inMenu('ASD')).style?.fontFamily, 'RobotoMono');

      // The codes line up in a column of one width, whatever their names measure:
      // a ragged column reads as unrelated chips, and the code is what the
      // operator is scanning for because it is what lands in the log.
      expect(tester.getSize(inMenu('ASD')).width, tester.getSize(inMenu('WAS')).width);
      expect(tester.getTopLeft(inMenu('ASD')).dx, tester.getTopLeft(inMenu('WAS')).dx);

      // Hung off THIS field: the menu's bottom-LEFT against the field's top-left,
      // then shifted left by exactly the name column — which puts the CODE
      // column's left edge on the field's own left edge. Asserted through the link
      // and the offset rather than by measuring, because a follower's offset is
      // applied when its layer paints and the render box still reports
      // unpositioned geometry here.
      final follower = tester.widget<CompositedTransformFollower>(menu);
      final target = tester.widget<CompositedTransformTarget>(find.ancestor(
        of: find.widgetWithText(TextField, 'County'),
        matching: find.byType(CompositedTransformTarget),
      ));
      expect(follower.link, same(target.link), reason: 'anchored to the exchange field, not the panel');
      expect(follower.targetAnchor, Alignment.topLeft);
      expect(follower.followerAnchor, Alignment.bottomLeft);
      final rowWidth = tester.getSize(find.descendant(of: menu, matching: find.byType(InkWell)).first).width;
      final codeCell = find.ancestor(of: inMenu('ASD'), matching: find.byType(Container)).first;
      expect(
        follower.offset.dx,
        -(rowWidth - tester.getSize(codeCell).width),
        reason: 'shifted left by the name column, so the code column starts at the field',
      );

      // And the info area still has its own content.
      expect(find.textContaining('W1AW'), findsWidgets);
    });

    testWidgets('tapping a row takes that value, even one Space would not', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      // WAS is a substring hit, which Space deliberately refuses — a tap is not a
      // guess, it is the operator pointing at the row they want.
      //
      // The row's own callback rather than `tester.tap`: a follower's offset is
      // applied when its layer paints, so the geometry `tap()` derives is the
      // menu's unpositioned layout box and the tap lands nowhere near the row
      // (it warns about exactly that). Whether a painted follower hit-tests
      // correctly is `RenderFollowerLayer`'s business; what this pins is that a
      // row's tap writes the value.
      final row = find.ancestor(
        of: find.descendant(of: find.byKey(exchangeSuggestionsKey), matching: find.text('WAS')),
        matching: find.byType(InkWell),
      );
      tester.widget<InkWell>(row.first).onTap!();
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'WAS');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus,
        isTrue,
        reason: 'the field keeps focus: a menu row is a value, not somewhere to land',
      );
    });

    testWidgets('Escape closes the menu and nothing else — the QSO survives it', (tester) async {
      // Everything else Escape does in this panel throws away work: it wipes a
      // composed QSO, discards an edit, or deselects. With a menu up, Escape
      // means "not that" — and losing a half-typed contact to a keystroke aimed
      // at a dropdown is not a recoverable mistake. It takes the menu whether or
      // not the highlight was ever touched.
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(exchangeSuggestionsKey), findsNothing, reason: 'the menu is gone');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller?.text,
        'W1AW',
        reason: 'and the contact being typed is untouched',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'AS');

      // A further keystroke is a new question, so the offer comes back.
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ASD');
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);

      // And with no menu open, Escape does what it always did.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // closes the menu
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // now wipes
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller?.text, '');
    });

    testWidgets('Tab takes the offer on the way out, like Space — Shift+Tab does not', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'CUY',
        reason: 'leaving the field forward is the same statement Space makes',
      );
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus,
        isFalse,
        reason: 'and Tab still traverses',
      );

      // Shift+Tab is stepping BACK to a field the operator may return to, so it
      // leaves the partial value alone.
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'CU');
    });

    testWidgets('Enter takes a highlighted suggestion instead of logging the QSO', (tester) async {
      // A highlight the operator walked to is a pending choice. Logging on that
      // Enter would commit a QSO whose exchange they were still picking, and
      // unlike a wrong exchange, a sent QSO can't be undone with another Enter.
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // onto WAS
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'WAS');
      expect(
        (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!,
        isEmpty,
        reason: 'that Enter chose a value; it did not send the contact',
      );

      // And the next one logs, because accepting cleared the highlight: pick,
      // then send, which is the sequence the hands were making anyway.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'qp', 'county': 'WAS'},
      ]);
    });

    testWidgets('Enter with the highlight untouched logs, as it does everywhere else', (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      // A PREFIX, not the whole code: an exact match would make `_acceptOptionSuggestion`
      // bail on `typed == chosen.code` and this test would pass even if Enter
      // stopped checking whether anything was pending at all.
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'CU');
      await tester.pump();

      // The menu is open and CUY is the top hit, but nothing is PENDING — the
      // operator hasn't chosen anything, so Enter has to mean send.
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'qp', 'county': 'CU'},
      ], reason: 'logged as typed — Enter did not quietly complete it first');
    });

    testWidgets('the arrow keys walk the highlight, and Space takes what is highlighted', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();

      // The menu reads (top to bottom) WAS, ASD — so Up moves off the best match
      // and onto the row above it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      Finder inMenu(String text) => find.descendant(of: find.byKey(exchangeSuggestionsKey), matching: find.text(text));
      expect(tester.widget<Text>(inMenu('WAS')).style?.fontWeight, FontWeight.w700, reason: 'the highlight moved up');
      expect(tester.widget<Text>(inMenu('ASD')).style?.fontWeight, FontWeight.w400);

      // Space now takes the highlighted one rather than the best one — having
      // moved the highlight IS the choice, so the prefix rule doesn't apply.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text, 'WAS');
    });

    testWidgets('opening the menu moves nothing: the fields stay exactly where they were', (tester) async {
      // The jump this pins was NOT the menu — it was the invalid-value tint. An
      // `errorText`, even an empty one styled to zero height, still makes the
      // decorator reserve its error slot, and through the row's IntrinsicHeight
      // that pushed every primary control and the submit button down 5px. A
      // contest exchange is invalid for most of the keystrokes it takes to type,
      // so it happened on every QSO.
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();

      Rect callField() => tester.getRect(find.widgetWithText(TextField, 'Their call'));
      final before = callField();

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS'); // invalid + menu open
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsOneWidget);
      expect(callField(), before, reason: 'a partial value is invalid, and must not resize the row');

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ASD'); // valid, menu still open
      await tester.pump();
      expect(callField(), before);

      await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ'); // invalid, no menu
      await tester.pump();
      expect(find.byKey(exchangeSuggestionsKey), findsNothing);
      expect(callField(), before, reason: 'and neither must an unrecognized one');
    });

    testWidgets('an arrow that cannot move the highlight is not a choice', (tester) async {
      // The menu is drawn best-at-the-bottom, so ↓ from an untouched selection has
      // nowhere to go — and neither arrow moves anything on a one-row menu. Those
      // keystrokes used to arm "the operator chose this" anyway, which took the
      // prefix guard off the NEXT Space: `SH` matches Ashland and Washington by
      // name substring only, and Space turned the field into `ASD`, a county
      // nobody worked.
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'SH');
      await tester.pump();
      String text() => tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text ?? '';

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // already at the bottom
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(text(), 'SH', reason: 'nothing moved, so nothing was chosen, so the guard still applies');

      // Enter is the other reader of the same flag: with nothing chosen it has to
      // mean "log", not "pick".
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'SH');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1), reason: 'that Enter had no pending choice to take, so it sent the contact');
      expect(text(), '', reason: 'and the field was not rewritten under the operator');
    });

    testWidgets('editing a QSO restores the exchange, and focus alone paints the offer', (tester) async {
      // On an existing QSO nothing else is repainting the panel — the callsign
      // isn't being typed — so without a focus listener the offer never appeared
      // while Space would still have rewritten the field.
      final existing = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
            'freq': 7100,
            'mode': 'SSB',
            'refs': [
              {'type': 'qp', 'county': 'CUY'},
            ],
          })))!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: running(['qp']),
            qsosRepository: qsos,
            activityControls: controlsWith(const {}),
            editingQso: existing,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
        'CUY',
        reason: 'the saved exchange comes back into the field',
      );

      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cuyahoga'), findsWidgets, reason: 'focus alone paints the offer');
    });
  });

  group('clearing an exchange', () {
    // An empty field means two different things and a contest has to tell them
    // apart: never filled in, or emptied on purpose. Only the latter is
    // recorded, as `field: ''`, and that record is the only thing stopping
    // `processQsoBeforeSave` from guessing the value straight back.
    const clearingControls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    Widget clearingHost({Qso? editing}) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              operation: running(['c']),
              qsosRepository: qsos,
              activityControls: clearingControls,
              editingQso: editing,
              qsos: editing == null ? const [] : [editing],
            ),
          ),
        );

    testWidgets('a field never filled in leaves no trace on the ref', (tester) async {
      await tester.pumpWidget(clearingHost());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, isEmpty, reason: 'an untouched empty field is not a decision');
    });

    testWidgets('a field the operator empties is recorded as an explicit blank', (tester) async {
      await tester.pumpWidget(clearingHost());
      await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA');
      await tester.pump();
      // …thought better of it.
      await tester.enterText(find.widgetWithText(TextField, 'Exch'), '');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'c', 'exchange': ''},
      ]);
    });

    testWidgets('reopening a QSO with a blanked exchange restores it as blank', (tester) async {
      // The other half: an explicit blank comes back as operator input, so a
      // lookup resolving after the record opens cannot helpfully fill it.
      final existing = Qso(
        uuid: 'existing',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
          'refs': [
            {'type': 'c', 'exchange': ''},
          ],
        },
      );
      await tester.pumpWidget(clearingHost(editing: existing));
      await tester.pump(const Duration(milliseconds: 500));

      final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Exch'));
      expect(field.controller?.text, '');
    });
  });

  group('serial controls', () {
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
    ];

    /// A repository wired for allocation, as the app builds it.
    QsosRepository allocating() => QsosRepository(db, sequences: SequencesRepository(db));

    Widget hostWith(QsosRepository repo) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(operation: running(['cqwpx']), qsosRepository: repo, activityControls: controls),
          ),
        );

    testWidgets('shows the number the sequence will issue, and logs it', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');

      // The operator has to be able to read the number they're about to send
      // while they're still typing the callsign.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ]);
    });

    testWidgets('advances after each QSO instead of repeating the last number', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await waitForQsos(tester, 1, repository: repo);
      await pumpUntilSerial(tester, 'Our #');

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '2');
    });

    testWidgets('a number the operator types over the preview is what gets logged', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');

      // "I've been logging on paper, I'm actually on 57."
      await tester.enterText(find.widgetWithText(TextField, 'Our #'), '57');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 57},
      ]);
    });

    testWidgets('a serial takes digits only, and is never uppercased into nonsense', (tester) async {
      await tester.pumpWidget(hostWith(allocating()));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Our #'), '1a2b');
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '12');
    });

    testWidgets('a call list numbers each call in turn, not all under the displayed one', (tester) async {
      // The displayed number is what the operator read out — but only to the
      // first station. The rest of a pileup got the next numbers in the series.
      // Writing the displayed number through (rather than treating it as a
      // guess) makes this the one place it must NOT be copied.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW,K1ABC,N1XYZ');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 3, repository: repo);
      expect(logged, hasLength(3));
      final serials = [
        for (final qso in logged)
          (qso.refs.firstWhere((r) => r['type'] == 'cqwpx')['ourSerial'] as num).toInt(),
      ]..sort();
      expect(serials, [1, 2, 3], reason: 'three stations worked, three numbers sent');
    });

    const descriptor = SequenceDescriptor(refType: 'cqwpx', field: 'ourSerial', key: 'cqwpx/serial');

    testWidgets('logs the number that was displayed, even once the sequence has moved on', (tester) async {
      // THE reason the displayed number is written through instead of being
      // re-allocated at commit. The operator read "1" off the screen and said
      // it into the microphone. If something else consumes 1 in the meantime
      // (another window on the same log), allocating at commit would file this
      // QSO under 2 — and the log would disagree with what went out on the air.
      // A duplicate is the honest outcome here; a silently wrong number is not.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');

      // A second writer on the same operation takes 1 while this QSO is being
      // composed. `peek` is deliberately not a reservation.
      await tester.runAsync(() => repo.add(
            operation.uuid,
            {'their': {'call': 'DL1ABC'}, 'band': '20m', 'mode': 'CW'},
            serialSequences: const [descriptor],
          ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 2, repository: repo);
      final ours = logged.firstWhere((q) => q.theirCall == 'W1AW');
      expect(
        ours.refs.single['ourSerial'],
        1,
        reason: 'what the operator was shown and sent — not the next free number',
      );
    });

    testWidgets('editing a logged QSO shows ITS number, not the next one', (tester) async {
      // The number on a logged QSO is what that station was actually sent.
      // Opening the record to fix a busted call must show 1, not whatever the
      // sequence is up to — and saving must leave 1 on the record. Writing the
      // displayed number through is exactly what makes this dangerous: a
      // preview leaking into this field silently rewrites history.
      final repo = allocating();
      final first = await repo.add(
        operation.uuid,
        {'their': {'call': 'W1AW'}, 'band': '20m', 'mode': 'CW'},
        serialSequences: const [descriptor],
      );
      await repo.add(
        operation.uuid,
        {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'CW'},
        serialSequences: const [descriptor],
      );
      expect((first.refs.single['ourSerial'] as num).toInt(), 1);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: running(['cqwpx']),
            qsosRepository: repo,
            activityControls: controls,
            editingQso: first,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text,
        '1',
        reason: "the number this QSO sent, not the sequence's next",
      );

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 2, repository: repo);
      final edited = logged.firstWhere((q) => q.uuid == first.uuid);
      expect(edited.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ], reason: 'still an int, still the number that went on the air');
    });

    testWidgets('editing a QSO with no contest ref does not invent a serial for it', (tester) async {
      // An ordinary QSO logged before the contest was set up. Correcting it
      // must not attach a number the station was never sent.
      final repo = allocating();
      final plain = await repo.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: running(['cqwpx']),
            qsosRepository: repo,
            activityControls: controls,
            editingQso: plain,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, isEmpty);
    });

    testWidgets('a sibling exchange field on the same ref survives editing', (tester) async {
      // cqwpx declares `ourSerial` before `theirSerial`, both on the cqwpx ref.
      // Restoring only the first and bailing out leaves the second empty — and
      // an empty primary field is an active clear on save, so the received
      // number would be wiped by opening the record and saving it.
      const both = [
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

      final repo = allocating();
      final qso = await repo.add(
        operation.uuid,
        {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'CW',
          'refs': [
            {'type': 'cqwpx', 'theirSerial': '101'},
          ],
        },
        serialSequences: const [descriptor],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: running(['cqwpx']),
            qsosRepository: repo,
            activityControls: both,
            editingQso: qso,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their #')).controller?.text, '101');

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '579');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'theirSerial': '101', 'ourSerial': 1},
      ]);
    });

    testWidgets('picks up a serial control that arrives after the first build', (tester) async {
      // How it actually happens in the app: the panel builds, THEN the
      // extension runtime answers with the operation's controls. Seeding the
      // preview only from initState left the field blank in the running app
      // while every construct-with-controls test here still passed.
      final repo = allocating();
      Widget hostControls(List<Map<String, dynamic>> active) => MaterialApp(
            home: Scaffold(
              body: LoggingControls(operation: running(['cqwpx']), qsosRepository: repo, activityControls: active),
            ),
          );

      await tester.pumpWidget(hostControls(const []));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Our #'), findsNothing);

      await tester.pumpWidget(hostControls(List<Map<String, dynamic>>.from(controls)));
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
    });

    testWidgets('with no sequences wired up, the field stays empty rather than showing a fake number', (tester) async {
      // A bare repository (tests, tooling, an import path) allocates nothing.
      // Showing "1" there would be a number that never reaches the log.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(operation: running(['cqwpx']), qsosRepository: qsos, activityControls: controls),
        ),
      ));
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
    });
  });

  testWidgets('a text control uppercases by default, and honours uppercase:false', (tester) async {
    // Contest exchanges are conventionally uppercase, and every other logging
    // field forces it — a lowercase state would also fail a case-sensitive
    // pattern. Names are the exception, hence the opt-out.
    const controls = [
      {
        'key': 'c/state',
        'label': 'St',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'state'},
      },
      {
        'key': 'c/name',
        'label': 'Name',
        'icon': 'pound',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'name', 'uppercase': false},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LoggingControls(operation: running(['c']), qsosRepository: qsos, activityControls: controls)),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'St'), 'ma');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Steve');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs.single['state'], 'MA');
    expect(logged.single.refs.single['name'], 'Steve');
  });

  testWidgets('clearing a text control blanks the field on the ref', (tester) async {
    // Blanking an exchange while editing has to actually blank it — otherwise
    // the old value silently stays in the log and gets exported.
    //
    // It is recorded as `exchange: ''` rather than dropped, which is a change
    // from simply removing it: a contest guesses an exchange onto an ABSENT
    // field at save (docs/design/contests.md §8), so a removed field would be
    // indistinguishable from one never filled in, and the value the operator
    // just deleted would come straight back.
    const controls = [
      {
        'key': 'c/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
      },
    ];

    final existing = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'c', 'exchange': 'MA'},
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: running(['c']),
          qsosRepository: qsos,
          activityControls: controls,
          editingQso: existing,
        ),
      ),
    ));
    await tester.pump();

    // The saved value is restored into the field...
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Exch')).controller?.text, 'MA');

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), '');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    // Reading the repo has to go through runAsync — a drift stream can't
    // resolve inside testWidgets' fake async (see waitForQsos above).
    final stored = (await waitForQsos(tester, 1)).single;
    final ref = stored.refs.firstWhere((r) => r['type'] == 'c');
    expect(ref['exchange'], '', reason: 'the old value must not survive, and the blank must be recorded');
  });

  testWidgets('two text controls sharing a ref type merge into one ref', (tester) async {
    // A contest's setup writes several fields of the SAME ref, so they must
    // merge rather than the last one winning.
    const controls = [
      {
        'key': 'simple-contest/exchange',
        'label': 'Exch',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'exchange'},
      },
      {
        'key': 'simple-contest/serial',
        'label': 'Nr',
        'icon': 'pound',
        'input': {'kind': 'text', 'refType': 'simple-contest', 'field': 'serial', 'numeric': true},
      },
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(operation: running(['simple-contest']), qsosRepository: qsos, activityControls: controls),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Exch'), 'MA');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Nr'), '042');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'simple-contest', 'exchange': 'MA', 'serial': '042'},
    ]);
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

  group('expanding a secondary control moves the cursor into it', () {
    // Expanding a control is a statement of intent — the operator opened it to
    // type into it. Leaving focus back in the callsign field means every
    // expand costs an extra tap, and on a phone the keyboard points at the
    // wrong field. Collapsing hands the cursor back so logging continues.
    const potaControl = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
    };

    Widget hostWithPota() => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              operation: operation,
              qsosRepository: qsos,
              activityControls: const [potaControl],
            ),
          ),
        );

    testWidgets('an activity ref field takes focus when its chip is tapped', (tester) async {
      await tester.pumpWidget(hostWithPota());
      await openControl(tester, MdiIcons.pineTree);

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'POTA')).focusNode?.hasFocus,
        isTrue,
        reason: 'the ref field is what the operator opened the control to fill in',
      );
    });

    testWidgets('the Radio control focuses Frequency, not the Band dropdown', (tester) async {
      // Band and Mode are dropdowns — Frequency is the one you type into, and
      // on touch platforms the dropdowns refuse focus outright.
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus,
        isTrue,
      );
    });

    testWidgets('the Time control focuses the time field', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus,
        isTrue,
      );
    });

    testWidgets('collapsing returns the cursor to the primary field it came from', (tester) async {
      await tester.pumpWidget(host());
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      // Land on Rcvd rather than Call, so "went back where it came from" is
      // distinguishable from "always goes to Call".
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');

      await openControl(tester, MdiIcons.radio);
      expect(field('Frequency').focusNode!.hasFocus, isTrue);

      await openControl(tester, MdiIcons.radio); // same chip again — collapse
      expect(
        field('Rcvd').focusNode!.hasFocus,
        isTrue,
        reason: 'collapsing must resume where logging left off, not jump to Call',
      );
    });

    testWidgets('collapsing returns to the last primary field even if the tap blurred it first', (tester) async {
      // The real failure this guards: in the app the root TapToDismissEmptyField
      // drops focus on any tap outside a field, so by the time the chip's
      // handler runs NOTHING is focused — sampling "what has focus now" read as
      // none and every collapse fell back to Call. The field the operator was
      // last in is what has to be remembered, not what happens to hold focus
      // at the moment of the tap.
      await tester.pumpWidget(host());
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'test setup');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(field('Sent').focusNode!.hasFocus, isFalse, reason: 'test setup: the tap blurred it');

      await openControl(tester, MdiIcons.radio);
      await openControl(tester, MdiIcons.radio); // collapse

      expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'must resume at Sent, not Call');
    });

    testWidgets('collapsing falls back to the call field when nothing was focused', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      // Nothing focused yet: the panel is fresh and untouched.
      await openControl(tester, MdiIcons.radio);
      await openControl(tester, MdiIcons.radio);

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus,
        isTrue,
      );
    });

    testWidgets('switching between two activity controls keeps each ref field working', (tester) async {
      // The expanded panel is ONE widget position, so switching chips rebuilds
      // RefTextInput with a different caller-owned focus node against a REUSED
      // State. If the field kept listening to the old node, the cursor-at-end
      // behavior would silently attach to the wrong control — and the stale
      // listener would outlive the controller it touches.
      const controls = [
        {
          'key': 'pota/hunter',
          'label': 'POTA',
          'icon': 'pine-tree',
          'input': {'kind': 'refList', 'refType': 'pota', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
        },
        {
          'key': 'sota/chaser',
          'label': 'SOTA',
          'icon': 'summit',
          'input': {'kind': 'refList', 'refType': 'sota', 'pattern': r'[A-Z0-9/]+-[0-9]{3}'},
        },
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(operation: operation, qsosRepository: qsos, activityControls: controls),
        ),
      ));

      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.pump();

      await openControl(tester, resolveIconName('summit'));
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'SOTA')).focusNode?.hasFocus,
        isTrue,
        reason: 'the second control gets focus on its own node',
      );
      await tester.enterText(find.widgetWithText(TextField, 'SOTA'), 'W1/AM-001');
      await tester.pump();

      // Back to the first: its value survived and it takes focus again.
      await openControl(tester, MdiIcons.pineTree);
      final pota = tester.widget<TextField>(find.widgetWithText(TextField, 'POTA'));
      expect(pota.controller?.text, 'US-1234');
      expect(pota.focusNode?.hasFocus, isTrue);
    });

    testWidgets('hopping between controls keeps the ORIGINAL primary field for the way back', (tester) async {
      // The second expand happens while focus is inside the first control's
      // panel — recording "nothing was focused" there would lose Rcvd.
      await tester.pumpWidget(hostWithPota());
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');

      await openControl(tester, MdiIcons.radio);
      await openControl(tester, MdiIcons.pineTree);
      expect(field('POTA').focusNode!.hasFocus, isTrue);

      await openControl(tester, MdiIcons.pineTree); // collapse
      expect(field('Rcvd').focusNode!.hasFocus, isTrue);
    });
  });

  testWidgets("activity control's chip icon accents to the extension's color once a reference is entered (issue #187)",
      (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#068541',
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

    // No reference yet: the icon stays the default theme color, not the
    // extension's accent — the accent marks a filled-in field.
    Color? iconColor() => tester.widget<Icon>(find.byIcon(MdiIcons.pineTree)).color;
    expect(iconColor(), isNot(const Color(0xFF068541)));

    await openControl(tester, MdiIcons.pineTree);

    // Still open, no reference yet: no accent.
    expect(iconColor(), isNot(const Color(0xFF068541)));

    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
    await tester.pump();

    // Still open, but the entered text now matches the control's own
    // pattern and has been accepted as a reference: the accent shows even
    // while the panel is expanded (issue #187 follow-up).
    expect(iconColor(), const Color(0xFF068541));
    // A single reference gets a single check ahead of the label.
    expect(find.text('✔️ POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree); // close the panel

    // Closed: the accent stays.
    expect(iconColor(), const Color(0xFF068541));
    expect(find.text('✔️ POTA'), findsOneWidget);
  });

  testWidgets('activity control chip label gets a check per reference, or a check plus count past two (issue #187 follow-up)',
      (tester) async {
    const controls = [
      {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'color': '#068541',
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

    // No reference yet: plain label.
    expect(find.text('POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree);

    // A twofer (two parks activated together) gets two checks, not "×2" —
    // it's the common case worth spelling out rather than abbreviating.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678');
    await tester.pump();
    expect(find.text('✔️✔️ POTA'), findsOneWidget);

    // A third reference collapses to a single check plus the total count,
    // so the label doesn't grow one glyph per park on a bigger rove.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678, US-9012');
    await tester.pump();
    expect(find.text('✔️×3 POTA'), findsOneWidget);
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
          operation: running(['cqwpx']),
          qsosRepository: qsos,
          activityControls: controls,
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
        body: LoggingControls(operation: running(['c']), qsosRepository: qsos, activityControls: controls),
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
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59 ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);
  });

  testWidgets('an on-screen-keyboard space advances out of a contest exchange too', (tester) async {
    // The soft-keyboard half of the same rule. `_exchangeField` was the one
    // primary field that never installed `_virtualSpace`, so on a phone —
    // where there IS no hardware Space — the exchange fields were dead ends,
    // even though the hardware path had been fixed and tested.
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
          operation: running(['cqwpx']),
          qsosRepository: qsos,
          activityControls: controls,
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

    await tester.pumpWidget(host(interpretCommand: fakeReloadPrefix));
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
          body: LoggingControls(operation: operation, qsosRepository: qsos, showRSTFields: false),
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
      await tester.pumpWidget(host(interpretCommand: reloadPrefix));

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
      await tester.pumpWidget(host(interpretCommand: reloadPrefix));

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
        await tester.pumpWidget(host(interpretCommand: reloadPrefix));

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
      await tester.pumpWidget(host(interpretCommand: reloadPrefix));

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

      await tester.pumpWidget(host(interpretCommand: completeAfterParam));

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
      await tester.pumpWidget(host(interpretCommand: reloadPrefix));

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
      await tester.pumpWidget(host(interpretCommand: reloadPrefix));

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
        body: LoggingControls(operation: running(['c']), qsosRepository: qsos, activityControls: controls),
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
    await tester.pumpWidget(host(showStateField: true, showGridField: true));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW ');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59 ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59 ');
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
    await tester.pumpWidget(host(showStateField: true, showGridField: true));
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

  testWidgets('an async interpretation push updates the message but never dispatches commands (issue #189)', (tester) async {
    final updates = StreamController<Map<String, dynamic>>();
    addTearDown(updates.close);
    Future<Map<String, dynamic>?> interpret(String input, [operation, qso, execute = false]) async {
      return {'describe': 'Fetching…'};
    }

    String? lastMessage;
    await tester.pumpWidget(host(
      interpretCommand: interpret,
      interpretationUpdates: updates.stream,
      onCommandMessageChanged: (message) => lastMessage = message,
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SOLAR');
    await tester.pump(const Duration(milliseconds: 200)); // past the 150ms describe debounce
    expect(lastMessage, 'Fetching…');

    // The command hook's background fetch resolves and pushes the real
    // reading — same shape `host.updateInterpretation` sends across the
    // bridge (see extension_host_test.dart for that half of the contract).
    updates.add({
      'input': 'SOLAR',
      'interpretation': {'describe': 'Solar flux: 120'},
    });
    await tester.pump();
    expect(lastMessage, 'Solar flux: 120');

    // Crucially: the push only ever updates what's displayed. Only Enter
    // (interpretCommand's execute:true call) may log anything — proven here
    // by the call field still holding its typed text, since _log() is what
    // clears it.
    expect(find.widgetWithText(TextField, 'Their call'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'SOLAR');
  });

  testWidgets('a push for an input the user has since typed past is dropped, not applied stale (issue #189)', (tester) async {
    final updates = StreamController<Map<String, dynamic>>();
    addTearDown(updates.close);
    Future<Map<String, dynamic>?> interpret(String input, [operation, qso, execute = false]) async {
      return {'describe': 'Fetching…'};
    }

    String? lastMessage;
    await tester.pumpWidget(host(
      interpretCommand: interpret,
      interpretationUpdates: updates.stream,
      onCommandMessageChanged: (message) => lastMessage = message,
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SOLAR');
    await tester.pump(const Duration(milliseconds: 200));
    expect(lastMessage, 'Fetching…');

    // The user typed past SOLAR before its fetch resolved.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SOLARX');
    await tester.pump(const Duration(milliseconds: 200));

    // A late push for the abandoned "SOLAR" input must not resurrect it.
    updates.add({
      'input': 'SOLAR',
      'interpretation': {'describe': 'Solar flux: 120'},
    });
    await tester.pump();
    expect(lastMessage, isNot('Solar flux: 120'));
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

  // The round submit button is the primary submit affordance on mobile (no
  // hardware keyboard). It calls the same _log() as Enter, but was gated on
  // _canLog — false for a command, which isn't a callsign — so a command could
  // previously only be run from Enter / the on-screen keyboard's return key,
  // never this button. Its icon carries no text, so it's found by its icon.
  Finder submitButton() => find.widgetWithIcon(FilledButton, Icons.upload);

  testWidgets('tapping the submit button accepts a recognized command, the same as Enter', (tester) async {
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
      onCommandAction: (action, [params]) async => dispatched.add(MapEntry(action, params)),
    ));

    // A plain empty field: nothing to submit, button disabled.
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOADALL');
    // Let the 150ms describe debounce retain the interpretation and rebuild.
    await tester.pump(const Duration(milliseconds: 200));

    // The fix: a recognized command enables the button even though it isn't a
    // callsign (so _canLog is false).
    expect(
      tester.widget<FilledButton>(submitButton()).onPressed,
      isNotNull,
      reason: 'a complete command must enable the submit button, not just Enter',
    );

    // Tapping the BUTTON (not Enter) runs the command.
    await tester.tap(submitButton());
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'reloadDataFiles');
    expect(dispatched.single.value, {'target': 'ALL'});
  });

  testWidgets('the submit button stays disabled while a command still awaits its parameters', (tester) async {
    // A bare command prefix (EXP before its token) is incomplete — Enter falls
    // through and logs nothing, and the button must not offer to submit it.
    Future<Map<String, dynamic>?> fakeExpPrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      final match = RegExp(r'^EXP(?:\s+(\S+))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      if (match.group(1) == null) return {'expectsParams': true};
      return {
        'describe': 'Toggle experiment ${match.group(1)}?',
        'commands': const [],
      };
    }

    await tester.pumpWidget(host(interpretCommand: fakeExpPrefix));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<FilledButton>(submitButton()).onPressed,
      isNull,
      reason: 'a bare EXP still awaiting its token has nothing to submit',
    );

    // Completing it (a token) enables the button.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP FOO');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
  });

  testWidgets('a COMPLETE interpretation mid-parameter keeps spaces intact (EXP LA must not snap to EXPLA)', (tester) async {
    // Regression test: pausing after "EXP L" lets the debounce retain a
    // complete interpretation (token "L") — which used to drop the field
    // out of free-text mode, so the callsign filter rewrote the whole
    // field on the next keystroke and "EXP LA" became "EXPLA".
    Future<Map<String, dynamic>?> fakeExpCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      final match = RegExp(r'^EXP(?:\s+(\S+))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final token = match.group(1);
      if (token == null) return {'expectsParams': true};
      return {
        'describe': 'Toggle experiment $token?',
        'commands': [
          {
            'toggleExperiment': {'token': token},
          },
        ],
      };
    }

    await tester.pumpWidget(host(interpretCommand: fakeExpCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP L');
    // The pause: debounce fires and retains the COMPLETE interpretation.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP LA');
    await tester.pump(const Duration(milliseconds: 200));

    expect(field('Their call').controller!.text, 'EXP LA');
  });

  testWidgets('toggleExperiment forwards to onCommandAction (same whitelist trap as reloadDataFiles)', (tester) async {
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeExpCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      // Like the real EXP hook: bare prefix asks for the parameter (which
      // also switches the field into space-allowed free-text mode).
      if (input.trim().toUpperCase() == 'EXP') return {'expectsParams': true};
      if (input.trim().toUpperCase() != 'EXP LAYOUTS') return null;
      return {
        'describe': 'Toggle experiment LAYOUTS?',
        'commands': [
          {
            'toggleExperiment': {'token': 'LAYOUTS'},
          },
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeExpCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP LAYOUTS');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'toggleExperiment');
    expect(dispatched.single.value, {'token': 'LAYOUTS'});
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

  testWidgets('selecting a suggestedQso (spot/deeplink) triggers a lookup, not just population (#315)', (tester) async {
    // #315: tapping a spot populates the call field but must also run a
    // callsign lookup — the same as if the operator had typed the call.
    // Regressed because _applySuggestedQso populated under `_populating`,
    // which suppresses _onCallChanged's own lookup, and never scheduled one.
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

    Widget build({Map<String, dynamic>? suggestedQso}) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              operation: operation,
              qsosRepository: qsos,
              lookup: lookup,
              callLocationLine: (guess) => guess['location'] as String?,
              suggestedQso: suggestedQso,
            ),
          ),
        );

    // A live logging panel with nothing entered yet — no call, no lookup.
    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 0);

    // A spot is tapped, delivering a suggestedQso (a new Map instance, as the
    // real spot flow does — didUpdateWidget → _applySuggestedQso).
    await tester.pumpWidget(build(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

    // The populated call must be looked up, exactly as typing it would.
    expect(lookups, 0); // debounced — nothing yet
    await tester.pump(const Duration(milliseconds: 350));
    expect(lookups, 2); // offline + online pass
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
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
          scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
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

  group('scoreQso and segments', () {
    // The scoring pills and the entry row's primary fields both have to follow
    // the CURRENT segment, or the operator sees a contest's exchange field
    // while the dupe check still belongs to the activity it replaced.
    late Qso editing;

    Qso segmentBreak(List<String> refTypes) => Qso(
          uuid: 'break-1',
          operationUuid: operation.uuid,
          data: {
            'startAtMillis': 1000,
            'band': 'event',
            'event': {
              'event': 'break',
              'operation': {
                'refs': [for (final type in refTypes) {'type': type}],
              },
            },
          },
        );

    setUp(() {
      editing = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
        },
      );
    });

    Future<({Map<String, dynamic>? operation, List<Map<String, dynamic>>? segments})> scored(
      WidgetTester tester, {
      required List<Qso> log,
    }) async {
      Map<String, dynamic>? sentOperation;
      List<Map<String, dynamic>>? sentSegments;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: running(['pota']),
            qsosRepository: qsos,
            qsos: log,
            editingQso: editing,
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
              sentOperation = operation;
              sentSegments = segments;
              return {'notices': <String>[], 'alerts': <String>[]};
            },
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      return (operation: sentOperation, segments: sentSegments);
    }

    testWidgets('sends the current segment, not the base operation', (tester) async {
      final sent = await scored(tester, log: [segmentBreak(['cqww']), editing]);

      // The operation is a park activation; a break turned it into a contest.
      // Scoring must follow, or the contest's dupe rules never apply.
      expect([for (final ref in (sent.operation!['refs'] as List)) ref['type']], ['cqww']);
      // The hook reads the log through this uuid — dropping it would silently
      // score the candidate against an empty log.
      expect(sent.operation!['uuid'], operation.uuid);
      expect(sent.segments, hasLength(2), reason: 'base plus the break');
    });

    testWidgets('sends no timeline for an unsegmented operation', (tester) async {
      final sent = await scored(tester, log: [editing]);

      expect([for (final ref in (sent.operation!['refs'] as List)) ref['type']], ['pota']);
      expect(sent.segments, isNull, reason: 'one segment is not a timeline; sending it is pure payload');
    });
  });

  group('secondary control row', () {
    testWidgets('Time and Radio chips show by default; tapping expands, tapping again collapses', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);
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

      await openControl(tester, MdiIcons.clockOutline);
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
      await openControl(tester, MdiIcons.clockOutline);

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
      await openControl(tester, MdiIcons.clockOutline);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot('03:15'));
    });

    testWidgets('Now button clears a manual time override', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '03:15');
      await tester.pump();
      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget); // chip still rendered

      await tester.tap(find.widgetWithText(TextButton, 'Now'));
      await tester.pump();

      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot('03:15'));
    });

    testWidgets('Now actually restores automatic timestamping — the reseed must not re-freeze it', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

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
      await openControl(tester, MdiIcons.clockOutline);
      expect(find.widgetWithText(TextButton, 'Now'), findsNothing);
    });

    ChoiceChip timeChip(WidgetTester tester) => tester.widget<ChoiceChip>(
          find.ancestor(of: find.byIcon(MdiIcons.clockOutline), matching: find.byType(ChoiceChip)),
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
      await openControl(tester, MdiIcons.clockOutline);

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

      await openControl(tester, MdiIcons.clockOutline);
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

    final wipeIcon = resolveIconName('backspace-outline');
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

    testWidgets('Escape while editing discards changes and ends the editing session, unlike Revert (issue #199)', (tester) async {
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW', 'sent': '59'},
            'our': {'sent': '59', 'call': 'KI2D'},
            'mode': 'SSB',
          })))!;

      var editCanceled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            operation: operation,
            qsosRepository: qsos,
            editingQso: existingQso,
            onEditCanceled: () => editCanceled = true,
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget); // a change is pending, same as the Revert test above

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Revert (the button above) only discards the typed change and stays
      // in edit mode — Escape closes the editing session entirely.
      expect(editCanceled, isTrue);

      // Nothing was saved: the typed '57' never reached the stored record.
      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
      expect(stored.single.data['their']['sent'], '59');
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
