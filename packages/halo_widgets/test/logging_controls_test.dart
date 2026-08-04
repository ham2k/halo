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
  late KeyboardAccessoryController keyboardAccessory;
  late _FakeVfoStore tunedRadio;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    operation = await operations.create(stationCall: 'KI2D');
    fakeRadio = _FakeVfoStore();
    keyboardAccessory = KeyboardAccessoryController();
    // A mode as well as a frequency: a station on the air has both, and an
    // unset mode is one of the things that pops the Radio control open on
    // mount (see `_vfoIsUnset`), which would steal focus in every test here.
    tunedRadio = _FakeVfoStore()..setVfo('vfoA', freq: 14285, mode: 'SSB');
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
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? decorateQsoBeforeSave,
    Stream<Map<String, dynamic>>? interpretationUpdates,
    void Function(String? message)? onCommandMessageChanged,
    CommandActionHandler? onCommandAction,
    CallInfoChanged? onCallInfoChanged,
    VfoStore? radioService,
    Qso? editingQso,
    VoidCallback? onEditCanceled,
    bool Function()? onNavigateToQsoList,
    Map<String, dynamic>? suggestedQso,
    SuggestSpotSources? suggestSpotSources,
    SendSpot? sendSpot,
    bool showStateField = false,
    bool showGridField = false,
    bool showNumbersRow = false,
    bool showExtraInNumbersRow = true,
    bool vibrateNumbersRow = true,
    bool leftieMode = false,
    List<String>? enabledBands,
    List<String>? enabledModes,
    void Function(Qso qso)? enqueueLookup,
    void Function(Iterable<Qso> qsos)? enqueueAllLookups,
    Widget? trailing,
    String? bandOrFreqRequiredLabel,
    int? ourItuRegion,
    String? ourCountryCode,
    String defaultReportCW = '',
  }) {
    final resolvedRadio = radioService ?? tunedRadio;
    final controls = LoggingControls(
      operation: operation,
      qsosRepository: qsos,
      keyboardAccessory: keyboardAccessory,
      qsos: existing,
      enqueueLookup: enqueueLookup,
      enqueueAllLookups: enqueueAllLookups,
      decorateQsoBeforeSave: decorateQsoBeforeSave,
      interpretCommand: interpretCommand,
      interpretationUpdates: interpretationUpdates,
      onCommandMessageChanged: onCommandMessageChanged,
      onCommandAction: onCommandAction,
      onCallInfoChanged: onCallInfoChanged,
      // Defaults to a radio already tuned to a band, because that is the
      // ordinary state of a station on the air — and because logging refuses
      // a contact carrying neither band nor frequency (HALO-24), so a test
      // that logs anything needs one. Tests about the untuned, fresh-install
      // state pass `fakeRadio` (or their own store) explicitly.
      bandOrFreqRequiredLabel: bandOrFreqRequiredLabel,
      radioService: resolvedRadio,
      // The app passes the same object twice — RadioService is both the
      // store and the Listenable. See LoggingControls.radioUpdates.
      radioUpdates: resolvedRadio is Listenable ? resolvedRadio as Listenable : null,
      editingQso: editingQso,
      onEditCanceled: onEditCanceled,
      onNavigateToQsoList: onNavigateToQsoList,
      suggestedQso: suggestedQso,
      suggestSpotSources: suggestSpotSources,
      sendSpot: sendSpot,
      showStateField: showStateField,
      showGridField: showGridField,
      defaultReportCW: defaultReportCW,
      showNumbersRow: showNumbersRow,
      showExtraInNumbersRow: showExtraInNumbersRow,
      vibrateNumbersRow: vibrateNumbersRow,
      leftieMode: leftieMode,
      enabledBands: enabledBands,
      enabledModes: enabledModes,
      ourItuRegion: ourItuRegion,
      ourCountryCode: ourCountryCode,
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
            // The panel no longer draws the numbers row — it publishes it, and
            // the app's StatusBarOverlay draws it below the status footer and
            // directly on the keyboard. This stands in for that, so the tests
            // still exercise the row end to end (publish → render → tap)
            // rather than asserting on the spec and calling it covered.
            ValueListenableBuilder<KeyboardAccessorySpec?>(
              valueListenable: keyboardAccessory,
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

  /// Settles SecondaryControlRow's 200ms expand/collapse slide — same shape
  /// as [openControl]'s trailing pumps, for callers that trigger the
  /// animation via a key event instead of a tap.
  Future<void> settleControl(WidgetTester tester) async {
    await tester.pump();
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

  testWidgets('leftieMode renders the submit button and wipe button on the left of the main logging fields', (tester) async {
    await tester.pumpWidget(host(leftieMode: false));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    final logBtnXRight = tester.getTopLeft(find.bySemanticsIdentifier('action.log')).dx;
    final wipeBtnXRight = tester.getTopLeft(find.bySemanticsIdentifier('action.wipe')).dx;
    final callFieldXRight = tester.getTopLeft(find.bySemanticsIdentifier('field.call')).dx;
    expect(logBtnXRight, greaterThan(callFieldXRight));
    expect(wipeBtnXRight, greaterThan(callFieldXRight));

    await tester.pumpWidget(host(leftieMode: true));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    final logBtnXLeft = tester.getTopLeft(find.bySemanticsIdentifier('action.log')).dx;
    final wipeBtnXLeft = tester.getTopLeft(find.bySemanticsIdentifier('action.wipe')).dx;
    final callFieldXLeft = tester.getTopLeft(find.bySemanticsIdentifier('field.call')).dx;
    expect(logBtnXLeft, lessThan(callFieldXLeft));
    expect(wipeBtnXLeft, lessThan(callFieldXLeft));
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

  // The panel reserves the home indicator below its fields, but NOT while the
  // on-screen keyboard is up — the keyboard covers the indicator, and
  // StatusBarOverlay is already holding back that whole strip so the status
  // footer can ride above the keyboard. Reserving it here as well put a dead
  // gap between the numbers row and the footer (caught on a simulator, not by
  // the tests, which is why this one exists).
  //
  // Measured as the space below the fields rather than by reading the private
  // getter, so it stays a statement about what the operator sees.
  group('the panel does not reserve the home indicator under the keyboard', () {
    double gapBelowFields(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(LoggingControls)).dy -
        tester.getBottomLeft(find.widgetWithText(TextField, 'Their call')).dy;

    Future<double> gapWith(WidgetTester tester, {required bool keyboardUp}) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: 34 * dpr); // a home indicator
      // Set BOTH branches, never just one: leaving `viewInsets` alone on the
      // keyboard-down call made the result depend on which order the two calls
      // happened to run in — reversing them measured "keyboard down" under a
      // raised keyboard and reported a difference of 0.
      tester.view.viewInsets = keyboardUp ? FakeViewPadding(bottom: 300 * dpr) : FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
      });
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      return gapBelowFields(tester);
    }

    testWidgets('reserves it with the keyboard down, and nothing with it up', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // Keyboard UP first, deliberately: taken in the other order this passed
        // even when `gapWith` never cleared the inset, because the down case
        // happened to run before anything set it.
        final up = await gapWith(tester, keyboardUp: true);
        final down = await gapWith(tester, keyboardUp: false);
        // The indicator's 34pt is held back only when it is actually exposed.
        expect(down - up, moreOrLessEquals(34, epsilon: 1.0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
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
        await tester.pumpWidget(host(showNumbersRow: true));
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
        await tester.pumpWidget(host(showNumbersRow: true));

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
        await tester.pumpWidget(host(showNumbersRow: true, showExtraInNumbersRow: false));
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
      bool recentContext = false,
    }) async {
      lookups.add(call);
      if (call != 'W1AW') return null;
      return {
        'guess': {'name': 'ARRL HQ', 'location': 'Newington, CT', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, lookup: lookup)),
    ));

    // Cursor ends up at the end (last segment, "W1AW") after enterText.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC, W1AW');
    await tester.pump(const Duration(milliseconds: 400));

    expect(lookups, contains('W1AW'));
    expect(lookups, isNot(contains('K1ABC, W1AW')));
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
  });

  group('info area (issue #40)', () {
    Future<Map<String, dynamic>?> Function(String,
            {required Map<String, dynamic> qso,
            required Map<String, dynamic> operation,
            required bool online,
            bool recentContext}) guessLookup(
      Map<String, dynamic> guess,
    ) {
      return (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': guess};
    }

    testWidgets('idle (no call): renders the operation statistics lines', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
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
            radioService: tunedRadio,
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
            radioService: tunedRadio,
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

    // The panel has always styled a note's links in its own tuned blue, but
    // MarkdownBody left them inert — the operator could read a note's QRZ or
    // socials link and not follow it.
    testWidgets('a link in a note opens through onOpenLink', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            onOpenLink: opened.add,
            lookup: guessLookup({'note': 'QSL via [the club](https://example.org/qsl)'}),
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      // The url itself never renders — only the label.
      expect(find.textContaining('https://example.org/qsl'), findsNothing);

      await tester.tapOnText(find.textRange.ofSubstring('the club'));
      await tester.pump();

      expect(opened, ['https://example.org/qsl']);
    });

    // The note-width measurement decides ONE thing: whether the note shares
    // line 2 with the pills or takes its own line above them. Asserting that
    // choice is the only way this test can fail if the measurement breaks —
    // an earlier version asserted only "no exception", which both branches
    // satisfy.
    testWidgets('the measured note shares line 2 when it fits, and takes its own line when it does not',
        (tester) async {
      Future<({Offset pill, Offset note})> layout(String note) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            // 700px wide on purpose. The note below measures 342 as spans and
            // 627 as raw markdown, and the fit test is
            // `pills(92.5) + gap(8) + note <= maxWidth`, so at this width the
            // span measurement fits and the raw one does not. At the default
            // 800 there is ~400px of slack and BOTH fit, which is why an
            // earlier version of this test could not fail.
            body: SizedBox(
              width: 700,
              // Keyed per note: without it the second pump reuses the same
              // State, whose guess is already cached for this callsign, and
              // the note never changes.
              child: LoggingControls(
                radioService: tunedRadio,
                key: ValueKey(note),
                operation: operation,
                qsosRepository: qsos,
                lookup: guessLookup({'note': note}),
                scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                    {'notices': ['newDXCC'], 'alerts': <String>[]},
              ),
            ),
          ),
        ));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        return (
          pill: tester.getTopLeft(find.text('newDXCC')),
          note: tester.getTopLeft(find.byType(InlineMarkdownText)),
        );
      }

      // Heavily marked up on purpose: 342 as spans, 627 as raw markdown. Only
      // a measurement that parses the note fits it beside the pills here.
      final fits = await layout('**Great** **op** **and** **good** **friend**');
      expect(fits.note.dx, greaterThan(fits.pill.dx), reason: 'a short note should sit beside the pills');

      // Long: note takes line 2 on its own and the pills stack below it, so the
      // note starts at the column's left edge rather than trailing the pills.
      final wraps = await layout('Very long note about this operator ' * 8);
      // The note starts at the column's left edge; the pill's label is inset by
      // its own 6px padding, so the note is very slightly left of it.
      expect(wraps.note.dx, lessThan(wraps.pill.dx),
          reason: 'a note too wide for the row should start where the pills do, not trail them');
      expect(wraps.note.dy, lessThan(wraps.pill.dy), reason: 'and sit above them');
    });

    // The imageSizes/placeholders pairing in _measureNoteWidth is unreachable
    // on CI through flagsInMarkdown — it is a no-op unless the platform needs
    // the flag fallback — so this note carries the image markup explicitly. A
    // placeholder count that disagrees with the WidgetSpan count asserts inside
    // TextPainter, and that assert is in the logging panel's build path.
    testWidgets('a note carrying an image measures without a placeholder assert', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            key: const ValueKey('image-note'),
            operation: operation,
            qsosRepository: qsos,
            lookup: guessLookup({'note': 'from ![flag](flag:us#19x14) with **love**'}),
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                {'notices': ['newDXCC'], 'alerts': <String>[]},
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('love', findRichText: true), findsOneWidget);
    });

    testWidgets('scoreQso notices render as line-3 pills', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
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
            radioService: tunedRadio,
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
            radioService: tunedRadio,
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
      bool recentContext = false,
    }) async {
      lookedUp.add(call);
      return {'guess': {'name': 'Should Not Be Saved Inline'}};
    }

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          radioService: tunedRadio,
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
          // A real logged contact carries a frequency; editing one that has
          // neither band nor frequency is refused (HALO-24), which would stop
          // this test's save before it reached what it's actually about.
          'freq': 14285.0,
        })))!;

    final enqueued = <Qso>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          radioService: tunedRadio,
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

  testWidgets('constructed already editing a QSO enqueues it for a background lookup (ham2k/halo-dist#279 follow-up)',
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
      bool recentContext = false,
    }) async {
      return {'guess': {'name': 'ARRL HQ'}};
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          radioService: tunedRadio,
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

  testWidgets('command actions that add QSOs enqueue the whole batch for background lookup at once', (tester) async {
    // A command whose interpretation does not set `skipOnlineLookup` (e.g.
    // annotation-commands' WX/SOLAR event rows) gets its added QSOs batched
    // through enqueueAllLookups (not the per-QSO enqueueLookup), reusing the
    // same "Lookup all QSOs" bulk mechanism and progress reporting, fired
    // once the whole command has finished adding QSOs rather than QSO-by-QSO.
    Future<Map<String, dynamic>?> interpret(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input != 'ADDCMD') return null;
      return {
        'describe': 'Add QSOs?',
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

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'ADDCMD');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final logged = await waitForQsos(tester, 2);
    expect(logged, hasLength(2));
    expect(enqueuedSingly, isEmpty, reason: 'batches through enqueueAllLookups, not per-QSO enqueueLookup');
    expect(enqueuedBatches, hasLength(1), reason: 'one batch for the whole command, not one call per QSO');
    expect(enqueuedBatches.single.map((q) => q.theirCall).toList(), ['W1AW', 'K1ABC']);
    expect(enqueuedBatches.single.map((q) => q.uuid).toSet(), logged.map((q) => q.uuid).toSet());
  });

  testWidgets('a command interpretation with skipOnlineLookup (e.g. SEED) never enqueues its added QSOs for online lookup', (tester) async {
    // SEED's fabricated calls only ever carry the offline guess the
    // extension attached itself — there's no real online data to fetch, so
    // SEED sets `skipOnlineLookup` and the batch never reaches the queue.
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
        'skipOnlineLookup': true,
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
    expect(enqueuedSingly, isEmpty);
    expect(enqueuedBatches, isEmpty, reason: 'skipOnlineLookup must suppress the background lookup queue entirely');
  });

  testWidgets('a manually entered name override does not duplicate onto a newly added call, but a grid override does', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          // See the note on the same fixture above: saving an edit is refused
          // when the contact would carry neither band nor frequency.
          'freq': 14285.0,
        })))!;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          radioService: tunedRadio,
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
    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
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

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
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
          radioService: tunedRadio,
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
    // wiped back to blank-means-the-default, same as an ordinary log.
    final sentField = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent'));
    expect(sentField.controller!.text, isEmpty);
    expect(sentField.decoration!.hintText, '59');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC');
  });

  testWidgets('call stacking: lookup enrichment applies to the picked call and reaches the logged QSO', (tester) async {
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
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
          radioService: tunedRadio,
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
    final undoIcon = MdiIcons.undo;
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
    expect(find.byIcon(MdiIcons.undo), findsNothing);
  });

  testWidgets('Escape on an already-empty form is an inert no-op', (tester) async {
    // It used to ask the caller whether *it* had a QSO to undo-deselect, which
    // made Escape walk back into a selection it had just left. APP-19's ladder
    // makes Escape uniformly the way out, so the bottom of the stack is simply
    // a wipe of an already-empty form: nothing to restore, nothing to break.
    await tester.pumpWidget(host());

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, isEmpty);
    expect(find.byIcon(MdiIcons.undo), findsNothing);
  });

  testWidgets('debounced lookup enriches the entry line and the logged QSO', (tester) async {
    var lookups = 0;
    Future<Map<String, dynamic>?> lookup(
      String call, {
      required Map<String, dynamic> qso,
      required Map<String, dynamic> operation,
      required bool online,
      bool recentContext = false,
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
          radioService: tunedRadio,
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
      bool recentContext = false,
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
          radioService: tunedRadio,
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

    await tester.tap(find.byIcon(MdiIcons.undo));
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
          radioService: tunedRadio,
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

    await tester.tap(find.byIcon(MdiIcons.undo));
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
            body: LoggingControls(radioService: tunedRadio, operation: op, qsosRepository: repo ?? qsos, activityControls: controls),
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
      expect(find.byIcon(MdiIcons.pineTree), findsOneWidget);
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
            radioService: tunedRadio,
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
              radioService: tunedRadio,
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
        home: Scaffold(body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos)),
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
        body: LoggingControls(radioService: tunedRadio, operation: running(['simple-contest']), qsosRepository: qsos, activityControls: controls),
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
              radioService: tunedRadio,
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

    testWidgets('Arrow Up walks the open menu rather than stepping out to the pills (APP-19)', (tester) async {
      // Up and Down belong to the suggestion menu for as long as it is
      // showing. The focus ladder's Arrow Up (main field → pill strip) has to
      // stand aside for it, or the menu becomes unusable from the keyboard on
      // exactly the fields that offer one.
      await tester.pumpWidget(host());
      await tester.tap(find.widgetWithText(TextField, 'County'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'County'), 'AS');
      await tester.pump();
      expect(find.textContaining('Ashland'), findsWidgets, reason: 'the menu is up');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      // Still in the field with the menu still up — not parked on a pill.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'County')).focusNode?.hasFocus, isTrue);
      expect(find.textContaining('Ashland'), findsWidgets);
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
        expect(chip.focusNode?.hasFocus ?? false, isFalse);
      }
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
            radioService: tunedRadio,
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
              radioService: tunedRadio,
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
            body: LoggingControls(radioService: tunedRadio, operation: running(['cqwpx']), qsosRepository: repo, activityControls: controls),
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
            radioService: tunedRadio,
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
            radioService: tunedRadio,
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
            radioService: tunedRadio,
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
              body: LoggingControls(radioService: tunedRadio, operation: running(['cqwpx']), qsosRepository: repo, activityControls: active),
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
          body: LoggingControls(radioService: tunedRadio, operation: running(['cqwpx']), qsosRepository: qsos, activityControls: controls),
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
      home: Scaffold(body: LoggingControls(radioService: tunedRadio, operation: running(['c']), qsosRepository: qsos, activityControls: controls)),
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
          radioService: tunedRadio,
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
        body: LoggingControls(radioService: tunedRadio, operation: running(['simple-contest']), qsosRepository: qsos, activityControls: controls),
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
          radioService: tunedRadio,
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
              radioService: tunedRadio,
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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, activityControls: controls),
        ),
      ));

      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.pump();

      await openControl(tester, MdiIcons.summit);
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
          radioService: tunedRadio,
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
    expect(find.text('✓ POTA'), findsOneWidget);

    await openControl(tester, MdiIcons.pineTree); // close the panel

    // Closed: the accent stays.
    expect(iconColor(), const Color(0xFF068541));
    expect(find.text('✓ POTA'), findsOneWidget);
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
          radioService: tunedRadio,
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
    expect(find.text('✓✓ POTA'), findsOneWidget);

    // A third reference collapses to a single check plus the total count,
    // so the label doesn't grow one glyph per park on a bigger rove.
    await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234, US-5678, US-9012');
    await tester.pump();
    expect(find.text('✓×3 POTA'), findsOneWidget);
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
          radioService: tunedRadio,
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
          radioService: tunedRadio,
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
        body: LoggingControls(radioService: tunedRadio, operation: running(['c']), qsosRepository: qsos, activityControls: controls),
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
          radioService: tunedRadio,
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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, showRSTFields: false),
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
        body: LoggingControls(radioService: tunedRadio, operation: running(['c']), qsosRepository: qsos, activityControls: controls),
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
    // NOT the focus-after-submit guard — `command()` uses sendKeyEvent, which
    // never finalizes the editing session, so this passes even when Enter blurs
    // the field. That case belongs to the "Enter keeps focus in the field that
    // submitted (real submit path)" group below; this only pins that a command
    // doesn't wander off with the focus while the shortcut path runs.
    expect(field('Their call').focusNode!.hasFocus, isTrue);
    expect(field('Frequency').controller!.text, '14285');
    expect(find.text('20m'), findsWidgets);

    // Mode command switches mode, and the RST placeholder follows it.
    await command('CW');
    expect(field('Sent').decoration!.hintText, '599');

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

  testWidgets('HALO-32: a frequency command with no mode of its own guesses one from the band plan',
      (tester) async {
    await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
    await openControl(tester, MdiIcons.radio);

    // The fake frequency command mirrors the real radio-commands extension:
    // {setVfo: {freq}}, no mode — same as typing straight into the
    // Frequency field, this must fall back to guessing one from the band
    // plan (14074 kHz is FT8 territory) rather than leaving the prior mode.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14074');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '+0',
        reason: 'FT8 exchanges a signal-to-noise figure, not an RST');
  });

  // Enter must never cost the operator the field they were typing in. The
  // entry row is a loop the keyboard stays inside (docs/design/logging-fields.md
  // § "Moving between the main fields"), so Enter means "log", not "done
  // editing" — but `EditableText`'s default finalization unfocuses the field
  // BEFORE it calls `onSubmitted`, which made every Enter blur. The entry row
  // only looked intact because the two ordinary paths re-focus afterwards
  // (`_wipe` after a logged QSO, the `!_canLog` guard otherwise); every path
  // that didn't — running a command, saving an edit, a second Enter while one
  // was in flight — left nothing focused. `_finishEditingWithoutBlur` suppresses
  // the blur at the field, so all of them are covered at once.
  //
  // These drive the submit the way the ENGINE does, via
  // `receiveAction(TextInputAction.done)`. That distinction is the whole point:
  // `sendKeyEvent(enter)` reaches `_log` through the panel's CallbackShortcuts
  // without ever finalizing the editing session, so it never blurs the field
  // and a test written that way passes against the broken code. Anything here
  // that switches back to sendKeyEvent stops testing this.
  //
  // The last three cases are the ones a re-focus inside `_log` could not pass,
  // and they are why the fix lives at the field: they submit from somewhere
  // other than the call field, or never reach the command branch at all.
  group('Enter keeps focus in the field that submitted (real submit path)', () {
    Future<void> submit(WidgetTester tester, Finder field, String input) async {
      await tester.enterText(field, input);
      await tester.pump(const Duration(milliseconds: 200)); // past the describe debounce
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400)); // command execution + dispatch
    }

    Finder callField() => find.widgetWithText(TextField, 'Their call');
    bool hasFocus(WidgetTester tester, Finder field) =>
        tester.widget<TextField>(field).focusNode!.hasFocus;

    testWidgets('after an everyday frequency command', (tester) async {
      await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
      await submit(tester, callField(), '14285');
      expect(hasFocus(tester, callField()), isTrue);
      // …and the command really did run, so this isn't passing on a no-op.
      expect(tester.widget<TextField>(callField()).controller!.text, isEmpty);
    });

    // DEVPROGRESS was the reported case and DEVNOTICE the follow-up, but at this
    // layer they are one path — `_log` never inspects the action name, it just
    // hands it to `onCommandAction`. One case covers both; what actually differs
    // between them is downstream, in the status bar.
    testWidgets('after a command that only posts to the status bar', (tester) async {
      final dispatched = <String>[];
      Future<Map<String, dynamic>?> interpretDevProgress(String input,
          [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().toUpperCase() != 'DEVPROGRESS') return null;
        return {
          'describe': 'Show an indeterminate dev progress bar?',
          'confirm': 'Added an indeterminate progress bar',
          'commands': [
            {'devProgress': {'icon': 'progress-clock', 'title': 'Dev progress'}}
          ],
        };
      }

      await tester.pumpWidget(host(
        interpretCommand: interpretDevProgress,
        onCommandAction: (a, [params]) async => dispatched.add(a),
      ));
      await submit(tester, callField(), 'DEVPROGRESS');
      expect(hasFocus(tester, callField()), isTrue);
      expect(dispatched, ['devProgress']);
    });

    testWidgets('and a plain QSO still does too, so the fix did not trade one for the other', (tester) async {
      await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
      await submit(tester, callField(), 'W1AW');
      expect(hasFocus(tester, callField()), isTrue);
      // Anchored: this case passes under every mutation of the fix (by design —
      // `_wipe` re-focuses either way), so without pinning that a contact was
      // actually logged it would also survive Enter becoming a no-op, where
      // focus simply never moves.
      expect((await waitForQsos(tester, 1)).single.theirCall, 'W1AW');
    });

    // The other half of `_finishEditingWithoutBlur`. Supplying `onEditingComplete`
    // replaces the branch that ALSO cleared the composing region, so the helper
    // reinstates it — and that half is invisible to every other test here,
    // because `enterText` never produces a composing range. `updateEditingValue`
    // does, which is what makes this checkable at all.
    testWidgets('submitting clears the composing region the default would have', (tester) async {
      await tester.pumpWidget(host());
      final node = tester.widget<TextField>(callField()).focusNode!;
      node.requestFocus();
      await tester.pump();

      final state = tester.state<EditableTextState>(find.descendant(
        of: callField(),
        matching: find.byType(EditableText),
      ));
      state.updateEditingValue(const TextEditingValue(
        text: 'W1A',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ));
      await tester.pump();
      expect(state.textEditingValue.composing.isValid, isTrue, reason: 'the IME state must be set up first');

      // Assert immediately — do NOT pump first. `_finalizeEditing`'s trailing
      // `_scheduleRestartConnection()` re-attaches the input connection a frame
      // later and clears the composing run on its own, so a settle pump here
      // makes this pass even with the helper emptied out. Verified: with a
      // pump, the no-op mutant survives; without one, it fails.
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(state.textEditingValue.composing.isValid, isFalse,
          reason: 'a live composing run must not survive the submit');
    });

    // Submitting from a field other than the callsign must leave focus THERE.
    // Re-focusing the call field inside `_log` looks equivalent until you try
    // this: it yanks the caret out of the field mid-entry, and rewrites
    // `_lastPrimaryFocus` with it, so collapsing a secondary control later
    // returns to the wrong field.
    //
    // `Sent` is an RST field, built by `_fixedField` — one of the three build
    // sites, and NOT the exchange-field builder, which the next test covers.
    testWidgets('a command submitted from an RST field leaves focus in that field', (tester) async {
      await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
      final sent = find.widgetWithText(TextField, 'Sent');

      await tester.enterText(callField(), '14285');
      await tester.pump(const Duration(milliseconds: 200));
      tester.widget<TextField>(sent).focusNode!.requestFocus();
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasFocus(tester, sent), isTrue, reason: 'Enter from Sent must not move the caret to the call field');
      expect(hasFocus(tester, callField()), isFalse);
    });

    // The exchange-field builder is the third site, and the only one whose
    // `onSubmitted` is `_handleEnter()` rather than `_log()` — so it owns a
    // branch (accept a highlighted suggestion, then return without logging)
    // that neither other site has. Without this, deleting its
    // `onEditingComplete` passed all 245 tests.
    testWidgets('a command submitted from a contest exchange field leaves focus in that field', (tester) async {
      const theirSerial = {
        'key': 'cqwpx/theirSerial',
        'label': 'Their #',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'cqwpx', 'field': 'theirSerial', 'numeric': true},
      };
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['cqwpx']),
            qsosRepository: qsos,
            activityControls: const [theirSerial],
            interpretCommand: fakeInterpretCommand,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final exchange = find.widgetWithText(TextField, 'Their #');
      expect(exchange, findsOneWidget, reason: 'the contest exchange field must actually be on screen');

      await tester.enterText(callField(), '14285');
      await tester.pump(const Duration(milliseconds: 200));
      tester.widget<TextField>(exchange).focusNode!.requestFocus();
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasFocus(tester, exchange), isTrue,
          reason: 'Enter from a contest exchange must not move the caret to the call field');
      expect(hasFocus(tester, callField()), isFalse);
    });

    // Saving an edit returns through `onEditCanceled`, which never touched
    // focus — a path no amount of re-focusing inside the command branch reaches.
    testWidgets('saving an edited QSO with Enter keeps focus', (tester) async {
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
            'freq': 7100,
            'mode': 'SSB',
          })))!;
      var canceled = false;
      await tester.pumpWidget(host(editingQso: existingQso, onEditCanceled: () => canceled = true));

      await submit(tester, callField(), 'W1AWX');
      expect(canceled, isTrue, reason: 'the edit should have been saved, not ignored');
      expect(hasFocus(tester, callField()), isTrue);
    });

    // A second Enter while the first command is still in flight. This one
    // reaches `_log`'s `_isLogging` guard and returns there — but only because
    // `SLOW` is a RECOGNIZED command, so the describe debounce has already
    // cached an interpretation and the await below it is skipped. A plain
    // callsign never caches one, which is the case the next test covers; do not
    // read this one as proving the guard holds generally.
    testWidgets('a second Enter while a slow command is in flight keeps focus', (tester) async {
      final release = Completer<void>();
      Future<Map<String, dynamic>?> slowCommand(String input,
          [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().toUpperCase() != 'SLOW') return null;
        if (execute) await release.future;
        return {
          'describe': 'Run the slow one?',
          'confirm': 'Ran it',
          'commands': [
            {'devStatus': {'text': 'done'}}
          ],
        };
      }

      await tester.pumpWidget(host(interpretCommand: slowCommand, onCommandAction: (a, [p]) async {}));
      await tester.enterText(callField(), 'SLOW');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.testTextInput.receiveAction(TextInputAction.done); // starts executing, awaits release
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done); // returns at the _isLogging guard
      await tester.pump();

      release.complete();
      await tester.pump(const Duration(milliseconds: 400));
      expect(hasFocus(tester, callField()), isTrue);
    });

    // The same QSO must never be logged twice. `_log`'s `_isLogging` guard runs
    // at entry, but the flag isn't set until a branch commits to logging — and
    // in between sits an `await interpretCommand(...)`. A plain callsign
    // interprets to null, so nothing is ever cached and EVERY logging Enter
    // goes through that await: a second Enter arriving inside it passed the
    // entry guard too, and both go on to write the contact.
    //
    // Keeping focus is what makes this reachable from the on-screen keyboard,
    // so it belongs to this group — but the window is not specific to a
    // command, and the case above cannot catch it (it types a recognized
    // command, which caches an interpretation and skips the await, and it
    // asserts focus rather than how many QSOs exist).
    //
    // The latency here stands in for the real thing: `interpretCommand` and the
    // decorate-before-save hook are both JS-runtime round-trips, and key
    // auto-repeat (~33-90ms on macOS) fires well inside them.
    testWidgets('a second Enter during the interpret round-trip does not log the QSO twice', (tester) async {
      var interpretCalls = 0;
      Future<Map<String, dynamic>?> slowNullInterpret(String input,
          [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        interpretCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return null; // a callsign is not a command — the ordinary logging path
      }

      // Latency on the save path too, and this half is essential: without it
      // the first Enter finishes and `_wipe`s the field before the second
      // resumes, so the `_call != call` staleness check catches the duplicate
      // by accident and the test passes against the bug.
      await tester.pumpWidget(host(
        interpretCommand: slowNullInterpret,
        decorateQsoBeforeSave: (data) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return data;
        },
      ));
      await tester.enterText(callField(), 'W1AW');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 30)); // inside the 50ms await
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // Read the SETTLED state, not the first sighting: `waitForQsos` stops as
      // soon as it sees one, which would miss a duplicate written moments later
      // — the very thing under test.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final logged = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!;
      expect(logged, hasLength(1), reason: 'the second Enter must not log a duplicate contact');
      // One call from the describe debounce during the pump above, then one per
      // Enter — so this pins that BOTH Enters really entered `_log` and reached
      // the await. Without it the test could pass on a second Enter that never
      // arrived, which proves nothing.
      expect(interpretCalls, 3, reason: 'both Enters must reach _log for this to be testing anything');
    });
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

  testWidgets('HALO-32: a repeated mode guess does not reset the Sent/Rcvd cursor', (tester) async {
    // Regression test: the guess used to reapply unconditionally whenever
    // it was non-null, even when it equaled the current mode — and
    // TextEditingController.text's setter always collapses the selection,
    // so it force-moved the cursor in Sent/Rcvd on every such keystroke.
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    // Land on FT8 first (14074 kHz).
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14074');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');

    // Operator repositions the cursor in Sent without typing (so _rstsTouched
    // stays false) — e.g. clicking partway into the default RST.
    final sent = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!;
    sent.selection = const TextSelection.collapsed(offset: 0);

    // Another keystroke whose frequency is still inside the same FT8
    // segment (14074-14077) — the guess is unchanged.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14075');
    await tester.pump();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(sent.selection, const TextSelection.collapsed(offset: 0),
        reason: 'the guess did not change, so the RSTs must not have been rewritten out from under the cursor');
  });

  testWidgets('HALO-32: typing a frequency guesses its mode from the band plan', (tester) async {
    await tester.pumpWidget(host()); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    // 14074 kHz is FT8 territory in the band plan.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14074');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '+0',
        reason: 'the mode guess refreshes the default report placeholder too');

    // 5332 kHz (a 60m channel) is a frequency the band plan has no single
    // mode for. Both edits happen inside the same continuous session (the
    // field never settles/blurs between them), so a null guess here falls
    // back to `_modeBeforeFreqEdit` — the mode as it stood before this
    // session started (SSB) — rather than leaving it stuck on the earlier
    // FT8 guess, which would otherwise survive purely because it happened
    // to be the last edit that DID match something.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '5332');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('HALO-52: knowing the operator\'s country scopes the band-plan mode guess', (tester) async {
    // 7100 kHz is US-only Data/RTTY territory (7080-7125 kHz), narrower than
    // but overlapping the generic, unscoped 40m Phone/SSB segment
    // (7060-7300 kHz) that wins when the operator's country isn't known —
    // see the un-scoped assertion below, which pins that as the pre-existing
    // (if not quite right for a US station) default.
    await tester.pumpWidget(host(ourCountryCode: 'us')); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7100');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'RTTY');
  });

  testWidgets('HALO-52: without a country, the same frequency falls back to the generic unscoped segment', (tester) async {
    await tester.pumpWidget(host()); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7100');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('HALO-32: a transient mid-typing match does not strand the mode when the finished frequency has none',
      (tester) async {
    // Typing "18001" character by character passes through "1800" (a real
    // 160m match, guesses RTTY) before landing on "18001" itself, which
    // falls in the real gap between 160m (ends 2000) and 17m (starts
    // 18068) — modeForFrequency returns null there. The transient RTTY
    // guess must not survive; the mode must end back where it started.
    await tester.pumpWidget(host()); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    for (final prefix in ['1', '18', '180', '1800', '18001']) {
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), prefix);
      await tester.pump();
    }

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '18001');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
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

  testWidgets('a paramless overlay action (devTester) forwards to onCommandAction', (tester) async {
    // Same silent-no-op trap as the reloadDataFiles test above, for the
    // paramless `{devTester: {}}` shape: without its _dispatchActions
    // branch, DEVTESTER interprets fine but submitting it does nothing.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeTesterCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'DEVTESTER') return null;
      return {
        'describe': 'Show the tester-notes overlay?',
        'confirm': 'Showing the tester-notes overlay',
        'commands': [
          {'devTester': <String, dynamic>{}},
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeTesterCommand,
      onCommandAction: (action, [params]) async => dispatched.add(MapEntry(action, params)),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVTESTER');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'devTester');
    expect(dispatched.single.value, isNull);
  });

  // The round submit button is the primary submit affordance on mobile (no
  // hardware keyboard). It calls the same _log() as Enter, but was gated on
  // _canLog — false for a command, which isn't a callsign — so a command could
  // previously only be run from Enter / the on-screen keyboard's return key,
  // never this button. Its icon carries no text, so it's found by its icon.
  Finder submitButton() => find.widgetWithIcon(FilledButton, MdiIcons.upload);

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

  testWidgets('SPOTLAST resolves to the last real QSO, skipping trailing event markers (ham2k/halo-dist#10)', (tester) async {
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
      bool recentContext = false,
    }) async {
      if (call != 'KI2D') return null;
      return {
        'guess': {'name': 'Sebastian', 'note': '🤩 Sebastián - Ham2K PoLo Creator', 'location': 'New York, NY'},
      };
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          radioService: tunedRadio,
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

  // ---- A contact needs a band or a frequency (HALO-24).
  //
  // On a fresh install nothing has ever set either, so the stored VFO is
  // empty — `fakeRadio` here, as opposed to the `tunedRadio` the rest of this
  // file gets by default. Submitting then used to write a QSO with both null,
  // which the ADIF exporter emits carrying neither BAND nor FREQ, and LoTW,
  // QRZ and POTA all reject.
  //
  // Each of these asserts the QSO count, not just the message: an assertion
  // on the message alone passes against the bug, because the bug is that the
  // contact gets *written*.
  group('logging requires a band or a frequency', () {
    /// Types [call] and submits it through the path the engine actually uses
    /// (see the "real submit path" group — `sendKeyEvent` bypasses the
    /// editing session, and here that difference doesn't matter, but staying
    /// on the real path keeps these honest).
    Future<void> submit(WidgetTester tester, String call) async {
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// An unset VFO pops the Radio control open on mount (asserted below), and
    /// Enter inside an open control closes it instead of logging. So every
    /// test of the *log-time* guard has to collapse it first — otherwise the
    /// submit is swallowed by the control, no contact is written for a reason
    /// that has nothing to do with the guard, and the test passes against
    /// code with the guard removed.
    Future<void> dismissRadioControl(WidgetTester tester) async {
      // The auto-open runs in a post-frame callback, so it takes one more
      // frame than `pumpWidget` alone gives it.
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget,
          reason: 'an unset VFO should have opened the Radio control on mount');
      await openControl(tester, MdiIcons.radio); // same chip again — collapse
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
    }

    // The proactive half: the operator is shown the fields that need
    // answering, rather than finding out at log time.
    testWidgets('an unset VFO opens the Radio control on its own, without being asked', (tester) async {
      await tester.pumpWidget(host(radioService: fakeRadio));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    testWidgets('a VFO that already has a band and mode is left alone', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
      await tester.pumpWidget(host(radioService: fakeRadio));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing,
          reason: 'nothing is missing, so nothing should pop open');
    });

    testWidgets('refuses the contact, says so, and opens the Radio control to ask', (tester) async {
      final messages = <String?>[];
      await tester.pumpWidget(host(
        radioService: fakeRadio,
        onCommandMessageChanged: messages.add,
        bandOrFreqRequiredLabel: 'Set a frequency or band before logging',
      ));
      await dismissRadioControl(tester);

      await submit(tester, 'W1AW');

      expect(await waitForQsos(tester, 1), isEmpty, reason: 'the contact must not be written');
      expect(messages.last, 'Set a frequency or band before logging');
      // …and it is actually on screen, in the information area where a
      // command's error goes — not merely handed to a callback nobody has to
      // wire up (nothing in the app passes `onCommandMessageChanged` today).
      expect(find.textContaining('Set a frequency or band before logging'), findsOneWidget);
      // The Radio control is open on its frequency field — the operator can
      // answer the question without reaching for the pointer.
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus,
        isTrue,
      );
      // The typed callsign survives, so answering and logging is one step.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('a frequency lets the same contact through', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
      await tester.pumpWidget(host(radioService: fakeRadio));

      await submit(tester, 'W1AW');

      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1));
      expect(logged.single.freq, 14285);
      expect(logged.single.band, '20m');
    });

    // Band-OR-frequency, not frequency-only: a band picked by hand (or by a
    // "40M" command, which clears the frequency) is a complete answer.
    testWidgets('a band with no frequency lets it through too', (tester) async {
      fakeRadio.setVfo('vfoA', band: '40m', mode: 'SSB');
      await tester.pumpWidget(host(radioService: fakeRadio));

      await submit(tester, 'W1AW');

      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1));
      expect(logged.single.band, '40m');
      expect(logged.single.freq, isNull);
    });

    // The guard sits above the stacked-call branch, which commits a QSO of
    // its own without ever reaching the ordinary path below it.
    testWidgets('call stacking is covered too, not just the ordinary path', (tester) async {
      await tester.pumpWidget(host(radioService: fakeRadio));
      await dismissRadioControl(tester);

      await submit(tester, 'K1ABC//W1AW');

      expect(await waitForQsos(tester, 1), isEmpty);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    // …and a comma-separated list, which commits several at once.
    testWidgets('a comma-separated list is covered too', (tester) async {
      await tester.pumpWidget(host(radioService: fakeRadio));
      await dismissRadioControl(tester);

      await submit(tester, 'K1ABC, W1AW');

      expect(await waitForQsos(tester, 1), isEmpty);
    });

    testWidgets('saving an edit of a bandless contact is refused as well', (tester) async {
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
          })))!;
      await tester.pumpWidget(host(radioService: fakeRadio, editingQso: existingQso));
      await tester.pump();

      await submit(tester, 'W1AWX');

      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1), reason: 'still just the original record');
      expect(
        logged.single.theirCall,
        'W1AW',
        reason: 'the edit must not be saved while the contact has neither band nor frequency',
      );
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    // Being asked for a band must not trap a contact that the operator is
    // trying to get rid of — the guard sits below the delete branch.
    testWidgets('a bandless contact can still be deleted without first being repaired', (tester) async {
      // Shaped like the records the wipe/delete group uses: the second button
      // only offers *delete* while the loaded QSO still matches the fields, so
      // the fixture has to carry what the controls populate from it.
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW', 'sent': ''},
            'our': {'call': 'KI2D', 'sent': '59'},
            'mode': 'SSB',
            'startAtMillis': 1000000,
          })))!;
      await tester.pumpWidget(host(
        radioService: fakeRadio,
        editingQso: existingQso,
        onEditCanceled: () {},
      ));
      await tester.pump();

      // Stage the delete (the second button becomes "delete" for an
      // unmodified QSO), then confirm it with the submit button, which turns
      // into a solid trash can while a delete is staged. The button rather
      // than Enter: tapping the staging button took the text field's input
      // connection with it, and this test is about the guard's placement.
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();
      expect(find.textContaining('will be deleted'), findsOneWidget, reason: 'the delete is staged');
      await tester.tap(find.byIcon(MdiIcons.trashCan));
      await tester.pump(const Duration(milliseconds: 400));

      // `watchForOperation` excludes soft-deleted records, so an empty list is
      // the delete having gone through rather than the guard blocking it.
      expect(await waitForQsos(tester, 1), isEmpty, reason: 'the delete went through');
    });
  });

  // ---- Live follow: a connected radio (CAT) moving the VFO underneath us.
  // The panel only ever read vfoA when it seeded, so a CAT push was
  // invisible; these cover following it without ever overwriting the
  // operator. See docs/design/cat.md.

  testWidgets('follows the VFO when a connected radio is tuned', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');

    // The operator turns the knob on the radio.
    fakeRadio.setVfo('vfoA', freq: 7123.45, mode: 'LSB');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7123.45');
    expect(find.text('40m'), findsWidgets, reason: 'the band follows the frequency');
  });

  testWidgets('HALO-32: a radio-driven frequency change never runs the band-plan mode guess', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 7100, mode: 'CW');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    // The operator retunes to 14074 kHz (FT8 territory per the band plan)
    // but leaves the rig on CW — its own reported mode must win, never a
    // band-plan re-guess from the new frequency.
    fakeRadio.setVfo('vfoA', freq: 14074, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
  });

  testWidgets(
      'HALO-32: a radio-driven frequency-only update (no mode of its own) never runs the band-plan mode guess',
      (tester) async {
    // The test above can't actually tell a broken `_populating` guard from a
    // working one: _seedFromRadioService's own `if (vfo.mode != null) _mode
    // = vfo.mode!` unconditionally overwrites any stray guess right after,
    // as long as the radio reports SOME mode. Here `fakeRadio` never has a
    // mode set (`_FakeVfoStore`'s Vfo starts with mode: null, and this test
    // never passes one), so that overwrite never fires — a stray guess, if
    // the guard were broken, would go unmasked. This is the actually
    // guard-sensitive version.
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    // The radio reports a frequency-only change — 14074 kHz is FT8
    // territory per the band plan, but nothing here should guess it.
    fakeRadio.setVfo('vfoA', freq: 14074);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('a radio update does not overwrite a frequency the operator is part-way through typing',
      (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    // Two digits: too short to arm the push debounce, so the debounce alone
    // is not what protects this — the dirty flag is.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '71');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 21000, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '71',
        reason: 'the operator was mid-entry — their intent is newer than the radio');
  });

  testWidgets('following resumes once the operator edit has reached the VFO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7100');
    await tester.pump();
    // The 5s debounce fires and the edit reaches the VFO.
    await tester.pump(const Duration(seconds: 6));
    expect(fakeRadio.vfoA.freq, 7100);

    // Now the panel and the VFO agree again, so a radio move is followed.
    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('a pending frequency edit holds off the frequency, not the mode', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    // Mid-entry: the operator's frequency is newer than the radio's.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '71');
    await tester.pump();

    // The rig is switched to CW at its own front panel meanwhile.
    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '71',
        reason: 'their entry is newer');
    // The whole seed used to be suppressed, so the mode was dropped — and
    // the pending push then sent the panel's stale SSB back at the rig,
    // taking it out of CW and logging the QSO as USB at 59.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');

    await tester.pump(const Duration(seconds: 6));
    expect(fakeRadio.vfoA.mode, 'CW', reason: 'the push must not undo the mode change');
  });

  testWidgets('a live radio band change rescores the dupe and New Band pills', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    final scoredBands = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          radioService: fakeRadio,
          radioUpdates: fakeRadio,
          scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
            scoredBands.add(qso['band'] as String?);
            return {'notices': <String>[], 'alerts': <String>[]};
          },
          scoreNoticeLabel: (key) => key,
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 500));
    expect(scoredBands, ['20m']);

    // The rig moves to another band on its own. The pills are scored
    // against band and mode, and the seed runs under `_populating` — which
    // suppressed the rescore, leaving them describing a band the operator
    // has left.
    fakeRadio.setVfo('vfoA', freq: 7040, mode: 'CW');
    await tester.pump(const Duration(milliseconds: 500));
    expect(scoredBands.last, '40m');
  });

  testWidgets('a partial frequency entry does not switch live follow off for good', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    // Three characters or fewer arms no debounce, so nothing ever cleared
    // the pending-edit flag: the Radio control stopped following the rig
    // for the rest of the session, and every QSO after it logged the stale
    // frequency.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '145');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The wipe collapses the Radio control along with everything else.
    await openControl(tester, MdiIcons.radio);
    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('the VFO notifier can be swapped while a QSO is being edited', (tester) async {
    // `radioService` (the store the fields are seeded FROM) and
    // `radioUpdates` (the Listenable that says when) are separate, so a
    // second store stands in as the notifier here.
    final notifierA = _FakeVfoStore();
    final notifierB = _FakeVfoStore();
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7040,
        'mode': 'CW',
      },
    );

    Widget hostWith({required Listenable updates, Qso? editing}) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              operation: operation,
              qsosRepository: qsos,
              radioService: fakeRadio,
              radioUpdates: updates,
              editingQso: editing,
            ),
          ),
        );

    await tester.pumpWidget(hostWith(updates: notifierA, editing: existingQso));
    await tester.pumpAndSettle();

    // The swap lands mid-edit. Re-subscribing used to sit below
    // `didUpdateWidget`'s editingQso guards, so it simply never ran here:
    // the listener stayed on A, `dispose` then removed it from B, and A
    // kept this State alive with nothing following it.
    await tester.pumpWidget(hostWith(updates: notifierB, editing: existingQso));
    await tester.pumpAndSettle();

    await tester.pumpWidget(hostWith(updates: notifierB));
    await tester.pumpAndSettle();
    await openControl(tester, MdiIcons.radio);

    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    notifierB.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('a radio update never touches the fields while editing an existing QSO', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7040,
        'mode': 'CW',
      },
    );
    await tester.pumpWidget(host(radioService: fakeRadio, editingQso: existingQso));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7040');

    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpAndSettle();

    // A logged QSO records where it actually happened; ambient radio state
    // must not rewrite it.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7040');
  });

  testWidgets('a radio mode change refreshes the default RST placeholder', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '59');

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    // A seed that sets the mode without rebuilding the fields leaves 59
    // standing in for a CW report — and 59 is what then gets logged.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');
  });

  testWidgets('a radio mode change leaves an RST the operator edited alone', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!.text, '57');
  });

  // The default report is a placeholder, never real text: an operator reaching
  // for Sent to give a true 57 must be able to type it, not clear a pre-filled
  // 59 first. What gets LOGGED is unchanged — the default becomes real on the
  // way out, so nothing downstream (export, scoring, LoTW) ever sees a blank
  // report.
  testWidgets('HALO-83: a blank RST shows the mode default as a placeholder and logs it as a real value',
      (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, isEmpty, reason: 'the default must not be pre-filled');
    expect(field('Rcvd').controller!.text, isEmpty);
    expect(field('Sent').decoration!.hintText, '59');
    expect(field('Rcvd').decoration!.hintText, '59');

    // One keystroke replaces the default outright — the thing a pre-filled
    // "59" costs you.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '57', reason: 'a typed report wins over the default');
    expect(logged.single.receivedRST, '59', reason: 'the untouched placeholder is what gets stored');
  });

  testWidgets('HALO-83: a shorthand report is completed when focus leaves the field', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5');
    await tester.pump();
    expect(field('Sent').controller!.text, '5', reason: 'never mid-keystroke — 5 could still be becoming 57');

    // Space is the ordinary way out of a report field.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5 ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');
    expect(field('Sent').controller!.text, '55');
  });

  testWidgets('HALO-83: the report the operator logs from is completed too, though Enter never blurs it',
      (tester) async {
    // The trap: expanding only on blur (which is all PoLo does, where Enter
    // DOES blur) leaves the very field the operator submitted from carrying a
    // bare "5" into the record — and it is the last field they touch, so it is
    // the commonest one.
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '4');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.receivedRST, '44');
  });

  testWidgets('HALO-83: on CW a shorthand report gains its tone digit', (tester) async {
    await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '5');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.mode, 'CW', reason: 'test setup');
    expect(logged.single.sentRST, '579');
    expect(logged.single.receivedRST, '559');
  });

  testWidgets('HALO-83: the operator\'s own default report replaces the standard one', (tester) async {
    // A CW operator sending "5NN" wants that in the log, not 599 — and the
    // placeholder has to show what will actually be stored, or the setting is
    // invisible until the QSO is already logged.
    await tester.pumpWidget(host(interpretCommand: fakeInterpretCommand, defaultReportCW: '5NN'));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').decoration!.hintText, '59', reason: 'test setup: still on phone');

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(field('Sent').decoration!.hintText, '5NN');

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '5NN');
    expect(logged.single.receivedRST, '5NN');
  });

  testWidgets('HALO-83: editing a saved QSO with no RST does not invent one', (tester) async {
    // A blank field on a saved record is stored data, not a stand-in — filling
    // it in would rewrite a QSO the operator only opened to look at, and the
    // hint has to stay away for the same reason (it would promise a value the
    // save never writes).
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(editingQso: existingQso));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, isEmpty);
    expect(field('Sent').decoration!.hintText, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, anyOf(isNull, isEmpty));
    expect(logged.single.receivedRST, anyOf(isNull, isEmpty));
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

    // Band is deliberately out of the panel's own Tab/cursor-key cycle (it's
    // a mouse/type-to-filter control, not a keyboard-traversal stop), so
    // this focuses it directly rather than tabbing in — a tap would open
    // the menu, which the closed-menu arrow path here needs to avoid.
    tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode!.requestFocus();
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

  testWidgets('Enter from a focused Band dropdown commits the band and closes the control (APP-19)', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']));
    await openControl(tester, MdiIcons.radio);
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '40');
    await tester.pump();
    // Enter commits the typed band and then closes the control. It
    // deliberately does NOT log any more (it used to reach the panel's root
    // log shortcut): under APP-19's ladder Enter is what closes a secondary
    // control, and logging is one rung down, from a main field. The
    // operator's callsign is still sitting in the form, unlogged.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Same pump shape as `openControl`, for the same reason — the close
    // slide's ticker doesn't start counting until the frame after it's
    // asked to run, so a bare pump(250ms) would leave it at zero elapsed.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(fakeRadio.vfoA.band, '40m');
    expect(find.widgetWithText(TextField, 'Band'), findsNothing);
    expect(await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first), isEmpty);
    // …and the keyboard goes straight back to the main field the operator
    // was in — there's no pill stop on the way out anymore.
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus,
      isTrue,
    );
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

  testWidgets('HALO-32: applying a suggestedQso with no mode of its own never runs the band-plan guess',
      (tester) async {
    // tunedRadio (host()'s default) seeds Mode as SSB; 14074 kHz is FT8
    // territory per the band plan, but this suggestion carries no mode of
    // its own — applying it must leave the mode exactly as-is, not guess
    // FT8 from the frequency. This is the cold-start (initState) path,
    // where `_applySuggestedQso` runs before `_onFreqChanged`'s listener is
    // even attached — so on its own this only proves the guess doesn't fire
    // when it structurally can't. The next test below covers the path where
    // it structurally could.
    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
    }));
    await tester.pump();

    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets(
      'HALO-32: a second suggestedQso (didUpdateWidget, listener already attached) still never guesses the mode',
      (tester) async {
    // Unlike the cold-start case above, a suggestedQso arriving via
    // didUpdateWidget (a second spot tapped on an already-mounted widget,
    // line ~1807) runs AFTER `_onFreqChanged`'s listener is attached — the
    // one path where a broken `_populating` guard would actually let a
    // stray band-plan guess through. Build with no suggestion first so the
    // widget is fully mounted (Mode defaults to SSB, per tunedRadio), then
    // apply a suggestion with a frequency but no mode.
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0, // FT8 territory per the band plan
    }));
    await tester.pump();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('a suggestedQso moves the VFO, so a connected radio follows the spot', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 7200, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio, suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));
    await tester.pump();

    // Tapping a spot is specific intent — "work THIS station" — so it takes
    // the radio there, rather than only filling in the form.
    expect(fakeRadio.vfoA.freq, 14074.0);
    expect(fakeRadio.vfoA.mode, 'FT8');
    expect(fakeRadio.vfoA.band, '20m');
  });

  testWidgets('tapping a second spot moves the VFO again', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));
    await tester.pump();
    expect(fakeRadio.vfoA.freq, 14074.0);

    await tester.pumpWidget(host(radioService: fakeRadio, suggestedQso: {
      'their': {'call': 'K1ABC'},
      'freq': 7035.0,
      'mode': 'CW',
    }));
    await tester.pump();

    expect(fakeRadio.vfoA.freq, 7035.0);
    expect(fakeRadio.vfoA.mode, 'CW');
  });

  testWidgets('HALO-58: a spot tap focuses the callsign field, so Enter can log the suggested QSO', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(host());
      // The tap that produces a suggestion lands in the Spots pane, outside
      // the logging fields — without this unfocus, the call field's own
      // autofocus keeps the assertion green with the fix deleted.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.pumpWidget(host(suggestedQso: {
        'their': {'call': 'W1AW'},
        'freq': 14074.0,
        'mode': 'FT8',
      }));
      await tester.pump();

      final callField = find.widgetWithText(TextField, 'Their call');
      expect(tester.widget<TextField>(callField).focusNode!.hasFocus, isTrue);

      // The point of the focus: Enter, with nothing else touched, logs the
      // suggested contact. Driven the way the engine submits (receiveAction),
      // which needs the field's input connection — absent when nothing holds
      // focus.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(callField).controller!.text, isEmpty); // wiped: the QSO was logged
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-58: on mobile a spot tap leaves focus alone (no uninvited virtual keyboard)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(host());
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.pumpWidget(host(suggestedQso: {
        'their': {'call': 'W1AW'},
        'freq': 14074.0,
        'mode': 'FT8',
      }));
      await tester.pump();

      // The suggestion still filled the field — it just didn't grab focus,
      // which on a phone would pop the keyboard over the call info the tap
      // surfaced (docs/design/logging-fields.md's mobile carve-out).
      final callField = find.widgetWithText(TextField, 'Their call');
      expect(tester.widget<TextField>(callField).controller!.text, 'W1AW');
      expect(tester.widget<TextField>(callField).focusNode!.hasFocus, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-93: mobile with no hardware keyboard starts with no field focused', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      // The carve-out itself: an unconditional autofocus here means every
      // phone opens the operation view with the virtual keyboard already up.
      await tester.pumpWidget(host());
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-93: a hardware keyboard restores the callsign autofocus on mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    hardwareKeyboardAttached.value = true;
    try {
      // With a physical keyboard there is no virtual keyboard to pop, so the
      // desktop rule applies: the callsign field is the default focus.
      await tester.pumpWidget(host());
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus, isTrue);
    } finally {
      hardwareKeyboardAttached.value = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('HALO-93: with a hardware keyboard, a spot tap focuses the callsign on mobile too', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    hardwareKeyboardAttached.value = true;
    try {
      await tester.pumpWidget(host());
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.pumpWidget(host(suggestedQso: {
        'their': {'call': 'W1AW'},
        'freq': 14074.0,
        'mode': 'FT8',
      }));
      await tester.pump();

      // The keyboard clause, not the platform clause: dropping
      // `hardwareKeyboardAttached` from the spot-tap guard leaves an iPad
      // keyboard user unable to press Enter after tapping a spot.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus, isTrue);
    } finally {
      hardwareKeyboardAttached.value = false;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('clicking into the frequency field after a spot does not switch live follow off', (tester) async {
    await tester.pumpWidget(host(radioService: fakeRadio, suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));
    await tester.pump();
    await openControl(tester, MdiIcons.radio);

    // The suggestion wrote the field under `_populating`. If that write
    // didn't move the edit baseline, this bare cursor placement reads as an
    // edit and live follow silently stops.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pumpAndSettle();

    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('the suggestion push does not notify listeners during the build phase', (tester) async {
    // Reproduces what the real app hit: SpotsPanel listens to the VFO and
    // calls setState when it changes. `_applySuggestedQso` runs from
    // initState and didUpdateWidget — both inside the build phase — so
    // pushing synchronously made that setState land mid-build, which
    // Flutter refuses. It surfaced only in the log, because ErrorPolicy
    // classes it logOnly.
    Widget tree(Map<String, dynamic> suggestion) => MaterialApp(
          home: Scaffold(
            body: Column(children: [
              _VfoWatcher(store: fakeRadio),
              Expanded(
                child: LoggingControls(
                  operation: operation,
                  qsosRepository: qsos,
                  radioService: fakeRadio,
                  radioUpdates: fakeRadio,
                  suggestedQso: suggestion,
                ),
              ),
            ]),
          ),
        );

    await tester.pumpWidget(tree({
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));
    await tester.pumpAndSettle();

    // A second spot, which is what drives didUpdateWidget.
    await tester.pumpWidget(tree({
      'their': {'call': 'K1ABC'},
      'freq': 7035.0,
      'mode': 'CW',
    }));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fakeRadio.vfoA.freq, 7035.0, reason: 'deferred, but it still lands');
  });

  testWidgets('a suggestion carrying no radio state leaves the VFO alone', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio, suggestedQso: {
      'their': {'call': 'W1AW'},
    }));
    await tester.pump();

    // A bare callsign — a deeplink, say — says nothing about where to tune,
    // and must not retune a connected radio to nowhere.
    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.mode, 'SSB');
  });

  testWidgets('a suggestion while editing an existing QSO does not move the VFO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
      },
    );

    await tester.pumpWidget(host(radioService: fakeRadio, editingQso: existingQso, suggestedQso: {
      'their': {'call': 'K1ABC'},
      'freq': 21000.0,
      'mode': 'CW',
    }));
    await tester.pump();

    expect(fakeRadio.vfoA.freq, 14285, reason: 'the suggestion was ignored, so the VFO is too');
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
      bool recentContext = false,
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
              radioService: tunedRadio,
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
          radioService: tunedRadio,
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
            radioService: tunedRadio,
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

      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
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

      // A live label is wrapped in OncePerSecond (the shared wall-clock
      // heartbeat) instead of being a plain static Text — that wrapper is
      // what makes it a clock rather than a snapshot.
      expect(timeChip(tester).label, isA<OncePerSecond>());

      String summary() => tester
          .widget<Text>(find.descendant(
            of: find.byWidget(timeChip(tester).label),
            matching: find.byType(Text),
          ))
          .data!;

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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, editingQso: existingQso),
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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, activityControls: controls),
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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos),
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

    final wipeIcon = MdiIcons.backspaceOutline;
    final undoIcon = MdiIcons.undo;
    final deleteIcon = MdiIcons.trashCanOutline;

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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, editingQso: existingQso),
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
          body: LoggingControls(radioService: tunedRadio, operation: operation, qsosRepository: qsos, editingQso: existingQso),
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
            radioService: tunedRadio,
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
      final restoreIcon = MdiIcons.deleteRestore;
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
            radioService: tunedRadio,
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

  group('the composing draft survives a detour through an earlier QSO', () {
    // `editingQso` going non-null and back to null is exactly what Up into
    // the list, a list click, and Down back out all drive from the app (see
    // LoggingPanel) — exercising it directly here covers all three at once.
    testWidgets('Escape after browsing to an earlier QSO restores the draft, not a blank form', (tester) async {
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW', 'sent': '59'},
            'mode': 'SSB',
            'freq': 14285.0,
          })))!;

      var editCanceled = false;
      await tester.pumpWidget(host(onEditCanceled: () => editCanceled = true));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0CALL');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
      await tester.pump();

      await tester.pumpWidget(host(editingQso: existingQso, onEditCanceled: () => editCanceled = true));
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(editCanceled, isTrue);

      // The parent responds to onEditCanceled by clearing editingQso — same
      // as LoggingPanel's own wiring.
      await tester.pumpWidget(host(onEditCanceled: () => editCanceled = true));

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'N0CALL',
          reason: 'the draft the operator was composing comes back, not a blank form');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!.text, '57');
    });

    testWidgets('the draft comes back after saving the edit too, not just after canceling it', (tester) async {
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW', 'sent': '59'},
            'mode': 'SSB',
            'freq': 14285.0,
          })))!;

      await tester.pumpWidget(host());
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0CALL');
      await tester.pump();

      await tester.pumpWidget(host(editingQso: existingQso));
      // 'Rcvd' (their.sent), not 'Sent' (our.sent) — matches the assertion
      // below on data['their']['sent'].
      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '57');
      await tester.pump();
      // The FilledButton, not Enter: Rcvd's own onSubmitted doesn't reach
      // _log() the way the callsign field's does.
      await tester.tap(find.byType(FilledButton));

      // waitForQsos' count is already satisfied by existingQso itself, so
      // this polls for the actual write instead — the count alone can't
      // tell "saved" from "not yet".
      Qso stored = existingQso;
      for (var i = 0; i < 20 && stored.data['their']['sent'] != '57'; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(stored.data['their']['sent'], '57', reason: 'the edit really did save');

      // The parent responds to onLogged by clearing editingQso too.
      await tester.pumpWidget(host());
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'N0CALL',
          reason: 'saving an earlier edit must not lose the QSO being composed');
    });

    testWidgets('switching directly between two earlier QSOs keeps the original draft, not the first one\'s',
        (tester) async {
      final first = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW', 'sent': '59'},
            'mode': 'SSB',
            'freq': 14285.0,
          })))!;
      final second = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'K1ABC', 'sent': '59'},
            'mode': 'SSB',
            'freq': 14285.0,
          })))!;

      var editCanceled = false;
      await tester.pumpWidget(host(onEditCanceled: () => editCanceled = true));
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0CALL');
      await tester.pump();

      // Into the first, then straight across to the second — the way arrow
      // keys walk the list without ever passing back through null.
      await tester.pumpWidget(host(editingQso: first, onEditCanceled: () => editCanceled = true));
      await tester.pumpWidget(host(editingQso: second, onEditCanceled: () => editCanceled = true));
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'K1ABC');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(editCanceled, isTrue);
      await tester.pumpWidget(host(onEditCanceled: () => editCanceled = true));

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'N0CALL',
          reason: 'the snapshot taken on the way into "first" must survive the trip through "second" too');
    });
  });

  // ── The focus ladder: main fields ↔ secondary pills (APP-19) ─────────────
  //
  // The QSO-list rung sits in the app (LoggingPanel owns the list and the
  // selection), so it's exercised in app/test/logging_panel_keyboard_nav_test
  // — these cover everything the panel can answer on its own.
  group('keyboard navigation of the secondary controls', () {
    /// Which pill currently holds the keyboard, by control key — read off the
    /// chips' own focus nodes (`_pillFocusFor` labels them `pill:<key>`), so
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
      await tester.pumpWidget(host(onNavigateToQsoList: () {
        handedOver++;
        return true;
      }));
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
      await tester.pumpWidget(host(onNavigateToQsoList: () => false));
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
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [potaControl],
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
      await tester.pumpWidget(host(onNavigateToQsoList: () {
        handedOver++;
        return true;
      }));
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
    /// animated — see `_mainFieldWidthDuration` — so no settling is needed on
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
                operation: running(['contest']),
                qsosRepository: qsos,
                activityControls: const [
                  {
                    'key': 'contest/exchange',
                    'label': 'Exch',
                    'icon': 'flag-checkered',
                    'input': {'kind': 'text', 'refType': 'contest', 'field': 'exchange'},
                  }
                ],
                showStateField: true,
                showGridField: true,
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

  group('references proposed by a lookup', () {
    // What `spot-history` returns: a park it found on a recent spot for the
    // call being typed. The QSO must end up carrying it without the operator
    // touching the POTA chip (HALO-80).
    const hunter = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'potaHunter'},
    };

    /// A lookup returning [refs] on the guess, counting its own calls so a
    /// re-lookup loop shows up as an ever-growing number rather than a hang.
    ({
      Future<Map<String, dynamic>?> Function(String, {
        required Map<String, dynamic> qso,
        required Map<String, dynamic> operation,
        required bool online,
        bool recentContext,
      }) fn,
      List<Map<String, dynamic>> seenQsos,
      List<bool> seenRecentContext,
    }) refLookup(List<Map<String, dynamic>> refs, {String forCall = 'W1AW'}) {
      final seenQsos = <Map<String, dynamic>>[];
      final seenRecentContext = <bool>[];
      Future<Map<String, dynamic>?> fn(
        String call, {
        required Map<String, dynamic> qso,
        required Map<String, dynamic> operation,
        required bool online,
        bool recentContext = false,
      }) async {
        seenQsos.add(qso);
        seenRecentContext.add(recentContext);
        if (call != forCall) return null;
        return {
          'guess': {'name': 'ARRL HQ', 'refs': refs},
        };
      }

      return (fn: fn, seenQsos: seenQsos, seenRecentContext: seenRecentContext);
    }

    Future<void> typeCall(WidgetTester tester, String call) async {
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
      await tester.pump(const Duration(milliseconds: 350)); // past the lookup debounce
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a park from the guess is logged on the QSO', (tester) async {
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-1234'}
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
          ),
        ),
      ));

      await typeCall(tester, 'W1AW');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      expect(
        (logged.single.data['refs'] as List).cast<Map>(),
        contains(containsPair('ref', 'US-1234')),
      );
    });

    testWidgets('composing a contact asks for recent context; editing a logged one does not', (tester) async {
      // `recentContextLookup` hooks answer "what is this station doing right
      // now". That is a question about a contact in progress — asked while
      // editing a QSO logged an hour ago, a current spot describes a park the
      // station may have reached long after the contact ended. The gate lives
      // here, at the request, so those hooks are never even consulted rather
      // than each having to recognize a context it cannot see.
      final composing = refLookup(const []);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: composing.fn,
          ),
        ),
      ));
      await typeCall(tester, 'W1AW');
      expect(composing.seenRecentContext, isNotEmpty);
      expect(composing.seenRecentContext, everyElement(isTrue));

      // A different call from the one typed below, so the edit genuinely
      // changes it — retyping the record's own call is an early return in
      // `_scheduleLookup` and no lookup would fire at all.
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'K1ABC'},
            'startAtMillis': 1000000,
            'freq': 14285.0,
          })))!;
      final editing = refLookup(const []);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: editing.fn,
            editingQso: existingQso,
          ),
        ),
      ));
      await typeCall(tester, 'W1AW');
      expect(editing.seenRecentContext, isNotEmpty, reason: 'the lookup still runs when editing');
      expect(editing.seenRecentContext, everyElement(isFalse));
    });

    testWidgets('a ref the operator already entered is never replaced by the guess', (tester) async {
      // The operator's own park outranks one mined from a spot: a spot can be
      // stale, or for the wrong one of two parks, and silently rewriting what
      // was typed would put the wrong reference in the log.
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-9999'}
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
            // Shaped like a real spot tap — band and mode included, since a
            // suggestedQso replaces the radio-seeded ones and a QSO carrying
            // neither refuses to log (HALO-24).
            suggestedQso: const {
              'band': '20m',
              'mode': 'SSB',
              'refs': [
                {'type': 'potaHunter', 'ref': 'US-0001'}
              ],
            },
          ),
        ),
      ));
      await tester.pump();

      await typeCall(tester, 'W1AW');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      final refs = (logged.single.data['refs'] as List).cast<Map>();
      expect(refs, contains(containsPair('ref', 'US-0001')));
      expect(refs, isNot(contains(containsPair('ref', 'US-9999'))));
      // And exactly one potaHunter ref — not the operator's plus the guess's.
      expect(refs.where((r) => r['type'] == 'potaHunter'), hasLength(1));
    });

    testWidgets('correcting the callsign takes back the ref guessed for the old one', (tester) async {
      // KI2D is spotted at US-2080, so typing it brings the park in. Fixing
      // the call to KI2E must not log KI2E at KI2D's park — the ref answered
      // a question about a station that is no longer the one being worked.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
          ),
        ),
      ));

      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'the park was picked up');

      // Backspace, then a different suffix — the ref must be gone at the
      // intermediate step, not merely replaced once KI2E resolves.
      await typeCall(tester, 'KI2');
      expect(find.text('✓ POTA'), findsNothing);
      expect(find.text('POTA'), findsOneWidget, reason: 'the chip stays, without a reference');

      await typeCall(tester, 'KI2E');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      expect(logged.single.theirCall, 'KI2E');
      expect(
        (logged.single.data['refs'] as List?) ?? const [],
        isNot(contains(containsPair('ref', 'US-2080'))),
      );
    });

    testWidgets('taking back a guessed ref leaves the operator\'s own alone', (tester) async {
      // The mirror of the test above: removal must be targeted at the refs
      // this widget inserted, not a blanket wipe. Silently deleting the
      // operator's own park because they fixed a typo in the call would be
      // worse than the bug being fixed. Both kinds are present here at once —
      // the guessed summit must go, the typed park must stay.
      final lookup = refLookup(const [
        {'type': 'sotaHunter', 'ref': 'W2/GC-001'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
            suggestedQso: const {
              'band': '20m',
              'mode': 'SSB',
              'refs': [
                {'type': 'potaHunter', 'ref': 'US-0001'}
              ],
            },
          ),
        ),
      ));
      await tester.pump();

      await typeCall(tester, 'KI2D');
      await typeCall(tester, 'KI2E');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);

      final refs = (logged.single.data['refs'] as List).cast<Map>();
      expect(refs, contains(containsPair('ref', 'US-0001')), reason: "the operator's park");
      expect(refs, isNot(contains(containsPair('ref', 'W2/GC-001'))), reason: "KI2D's summit");
    });

    testWidgets('stacking a second call keeps the ref the first one earned', (tester) async {
      // "KI2D,W1AW" logs one QSO per call and they share the ref list, so a
      // park one of them was spotted at is carried by both — two operators
      // activating together is exactly what produces a call list. Typing the
      // comma moves the cursor off KI2D without correcting it, which is the
      // distinction the clearing has to draw: the call left the CURSOR, not
      // the field.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
          ),
        ),
      ));

      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget);

      await typeCall(tester, 'KI2D,W1AW');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'KI2D is still in the field');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      for (final qso in logged) {
        expect(
          (qso.data['refs'] as List).cast<Map>(),
          contains(containsPair('ref', 'US-2080')),
          reason: '${qso.theirCall} shares the stack\'s park',
        );
      }
    });

    testWidgets('correcting the callsign back again brings its ref along', (tester) async {
      // The lookup is cached per call, so re-typing KI2D reaches it only
      // through that cache hit — a path that skips the fetch and everything
      // hung off it. Without applying refs there too, the info panel would
      // show KI2D's guess while the park it names is missing from the QSO.
      // Only reachable once guessed refs are cleared on a call change, which
      // is what makes this a pair with the test above.
      final lookup = refLookup(const [
        {'type': 'potaHunter', 'ref': 'US-2080'}
      ], forCall: 'KI2D');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
          ),
        ),
      ));
      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget, reason: 'picked up the first time');
      await typeCall(tester, 'KI2E');
      expect(find.text('✓ POTA'), findsNothing, reason: 'taken back for KI2E');
      await typeCall(tester, 'KI2D');
      expect(find.text('✓ POTA'), findsOneWidget, reason: "back on KI2D, so the park is KI2D's again");
    });

    testWidgets('applying a ref settles instead of re-triggering itself forever', (tester) async {
      // Applying a ref re-runs the lookup (the POTA hook needs to see the
      // park to resolve its grid), and the lookup proposes refs — the exact
      // shape of an endless loop if an already-applied ref were re-applied.
      final lookup = refLookup([
        {'type': 'potaHunter', 'ref': 'US-1234'}
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            activityControls: const [hunter],
            lookup: lookup.fn,
          ),
        ),
      ));

      await typeCall(tester, 'W1AW');
      // Let any re-lookup rounds play out.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
      }
      final settled = lookup.seenQsos.length;
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(lookup.seenQsos.length, settled, reason: 'the lookup stopped re-firing');

      // And the park did reach the hooks: some pass saw it on the QSO it was
      // handed, which is the whole reason for the re-lookup.
      expect(
        lookup.seenQsos.any((qso) =>
            (qso['refs'] as List?)?.any((ref) => (ref as Map)['ref'] == 'US-1234') ?? false),
        isTrue,
      );
    });
  });
}

/// In-memory stand-in for the app's `RadioService` (which lives outside
/// this package, in the Flutter app rather than halo_widgets) — just
/// enough of `VfoStore` to verify LoggingControls seeds from and writes
/// back to it, without a real SharedPreferences-backed store.
class _FakeVfoStore extends ChangeNotifier implements VfoStore {
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
    // The real RadioService is a ChangeNotifier; without this the panel's
    // live-follow listener never fires and its tests pass vacuously.
    notifyListeners();
  }
}

/// Stands in for SpotsPanel: something else in the tree that listens to the
/// VFO and rebuilds when it changes.
class _VfoWatcher extends StatefulWidget {
  final Listenable store;

  const _VfoWatcher({required this.store});

  @override
  State<_VfoWatcher> createState() => _VfoWatcherState();
}

class _VfoWatcherState extends State<_VfoWatcher> {
  int _changes = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() => _changes++);

  @override
  Widget build(BuildContext context) => Text('vfo changes: $_changes');
}
