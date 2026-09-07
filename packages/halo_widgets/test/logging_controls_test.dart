// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Widget tests drive the keyboard flows; database verification goes through
// tester.runAsync() because drift's futures/timers otherwise sit unresolved
// in testWidgets' FakeAsync zone. Interleaved pumps let widget-initiated
// writes (which start inside the fake zone) run to completion.

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

// WCAG 2.1 relative luminance / contrast ratio, so the focus-indicator test
// pins an actual accessibility threshold rather than "some color".
double _linear(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _luminance(Color c) => 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

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
    QsoDraftChanged? onQsoChanged,
    PeerDraftChanged? onPeerDraftChanged,
    VfoStore? radioService,
    Qso? editingQso,
    VoidCallback? onEditCanceled,
    bool Function()? onNavigateToQsoList,
    Map<String, dynamic>? suggestedQso,
    bool suggestedQsoIsTentative = false,
    int suggestionSettledSerial = 0,
    VoidCallback? onCallEdited,
    SuggestSpotSources? suggestSpotSources,
    SendSpot? sendSpot,
    bool showStateField = false,
    bool showGridField = false,
    String defaultOperatorCall = '',
    String defaultPosition = '',
    bool showPositionField = false,
    bool showNumbersRow = false,
    bool showExtraInNumbersRow = true,
    bool vibrateNumbersRow = true,
    bool leftieMode = false,
    List<String>? enabledBands,
    List<String>? enabledModes,
    bool hasConfiguredRadio = false,
    bool radioConnected = false,
    VoidCallback? onOpenStationConfig,
    String? radioName,
    void Function(Qso qso)? enqueueLookup,
    void Function(Iterable<Qso> qsos)? enqueueAllLookups,
    Widget? trailing,
    String? bandOrFreqRequiredLabel,
    QsosRepository? qsosRepository,
    void Function(Object error, StackTrace stackTrace)? onWriteError,
    int? ourItuRegion,
    String? ourCountryCode,
    String defaultReportCW = '',
    bool switchSentRcvd = false,
    bool jumpAfterRST = false,
    ThemeData? appTheme,
    ({int serial, Map<String, dynamic> qso})? logRequest,
    Future<bool> Function({required bool editing})? confirmLogOverwrite,
    List<String> controlOrder = const [],
    Set<String> hiddenControlKeys = const {},
    bool trackingPower = false,
  }) {
    final resolvedRadio = radioService ?? tunedRadio;
    final controls = LoggingControls(
      operation: operation,
      qsosRepository: qsosRepository ?? qsos,
      onWriteError: onWriteError,
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
      onQsoChanged: onQsoChanged,
      onPeerDraftChanged: onPeerDraftChanged,
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
      suggestedQsoIsTentative: suggestedQsoIsTentative,
      suggestionSettledSerial: suggestionSettledSerial,
      onCallEdited: onCallEdited,
      logRequest: logRequest,
      confirmLogOverwrite: confirmLogOverwrite,
      suggestSpotSources: suggestSpotSources,
      sendSpot: sendSpot,
      showStateField: showStateField,
      showGridField: showGridField,
      defaultOperatorCall: defaultOperatorCall,
      defaultPosition: defaultPosition,
      showPositionField: showPositionField,
      defaultReportCW: defaultReportCW,
      switchSentRcvd: switchSentRcvd,
      jumpAfterRST: jumpAfterRST,
      showNumbersRow: showNumbersRow,
      showExtraInNumbersRow: showExtraInNumbersRow,
      vibrateNumbersRow: vibrateNumbersRow,
      leftieMode: leftieMode,
      enabledBands: enabledBands,
      enabledModes: enabledModes,
      hasConfiguredRadio: hasConfiguredRadio,
      radioConnected: radioConnected,
      onOpenStationConfig: onOpenStationConfig,
      stationConfigLabel: 'Station Configuration',
      radioName: radioName,
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
      controlOrder: controlOrder,
      hiddenControlKeys: hiddenControlKeys,
      powerControlLabel: 'Power',
      powerLabel: 'Power',
      powerUnitLabel: 'W',
      trackingPower: trackingPower,
    );
    return MaterialApp(
      theme: appTheme,
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
            ?trailing,
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

  /// Starts a contact — the first character of a call is what takes a serial
  /// number (docs/design/contests.md §5.8.1); an idle panel shows none.
  Future<void> startContact(WidgetTester tester, [String call = 'W']) async {
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
    await tester.pump();
  }

  /// Pumps until a serial field has picked up its number. The claim is a
  /// drift query kicked off outside the frame, so it needs interleaved pumps
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

  testWidgets('the Radio control has no Station Configuration button when nothing can open one', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(find.byKey(const ValueKey('stationConfigButton')), findsNothing);
  });

  testWidgets('tapping the radio name opens Station Configuration too, unless there is none to show', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(find.text('Icom IC-705'), findsNothing);

    var opened = false;
    await tester.pumpWidget(host(
      hasConfiguredRadio: true,
      radioName: 'Icom IC-705',
      onOpenStationConfig: () => opened = true,
    ));
    expect(find.text('Icom IC-705'), findsOneWidget);
    await tester.tap(find.text('Icom IC-705'));
    expect(opened, isTrue);
  });

  testWidgets('a long radio name is capped at 3x the icon width and ellipsized, not wrapped', (tester) async {
    await tester.pumpWidget(host(
      hasConfiguredRadio: true,
      radioName: 'A Radio With A Genuinely Absurd Amount Of Name',
      onOpenStationConfig: () {},
    ));
    await openControl(tester, MdiIcons.cat);

    final icon = tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byIcon(MdiIcons.cat),
    ));
    final constrained = tester.widget<ConstrainedBox>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byType(ConstrainedBox),
    ));
    expect(constrained.constraints.maxWidth, icon.size! * 3);

    final text = tester.widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byType(Text),
    ));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('the Station Configuration button can never become a Tab stop', (tester) async {
    // It's a supplementary action, not one of Radio's Band/Frequency/Mode
    // fields (docs/design/logging-fields.md names exactly those three,
    // the full set _expandedFieldOrderFor('radio') knows about). If this
    // button could take keyboard focus (InkWell's own default), Tab
    // pressed from it would find no match in that list — currentIndex -1
    // — and _stepSecondaryField's `next = -1 + 1 = 0` would jump BACKWARD
    // to Band instead of leaving the control the way Tab is meant to once
    // its own fields are exhausted.
    await tester.pumpWidget(host(hasConfiguredRadio: true, onOpenStationConfig: () {}));
    await openControl(tester, MdiIcons.cat);

    final inkWell = tester.widget<InkWell>(find.byKey(const ValueKey('stationConfigButton')));
    expect(inkWell.canRequestFocus, isFalse);
  });

  Color stationConfigButtonColor(WidgetTester tester) {
    final icon = tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byIcon(MdiIcons.cat),
    ));
    return icon.color!;
  }

  testWidgets('Station Configuration button colors: unconfigured, configured, connected', (tester) async {
    final theme = ThemeData(useMaterial3: true);

    // No radio configured — a lighter tint of the row's own background,
    // barely there. The button still opens the dialog (that's where an
    // operator with nothing configured yet would go to add one).
    var opened = false;
    await tester.pumpWidget(host(appTheme: theme, onOpenStationConfig: () => opened = true));
    await openControl(tester, MdiIcons.radio);
    expect(stationConfigButtonColor(tester), Color.lerp(theme.colorScheme.tertiary, Colors.white, 0.4));
    await tester.tap(find.byKey(const ValueKey('stationConfigButton')));
    expect(opened, isTrue);

    // Still expanded — State survives a same-shaped pumpWidget. Configured
    // but not connected now reads red — lighter than the scheme's own error
    // color, which reads under 3:1 against this row's dark amber `tertiary`
    // fill (the accent color, not a pastel container).
    await tester.pumpWidget(host(appTheme: theme, hasConfiguredRadio: true, onOpenStationConfig: () {}));
    expect(stationConfigButtonColor(tester), const Color(0xFFFF8A80));

    // Connected — a lighter green than _noticePill's, same contrast reasoning.
    await tester.pumpWidget(
        host(appTheme: theme, hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}));
    expect(stationConfigButtonColor(tester), const Color(0xFF81C784));
  });

  // The same `iconColor` renders on two different fills (colorScheme
  // .tertiary when selected/expanded, the lighter HaLoColors.tertiaryLight
  // otherwise) — which one is actually darker flips between light and dark
  // mode, so the color has to flip with `selected`, not just with the theme.
  Color pillIconColor(WidgetTester tester) => (tester
          .widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.cat), matching: find.byType(ChoiceChip)))
          .avatar as Icon)
      .color!;

  testWidgets('the Radio pill icon color flips between selected and unselected: light mode', (tester) async {
    final theme = ThemeData(useMaterial3: true);
    await tester.pumpWidget(host(appTheme: theme, hasConfiguredRadio: true, onOpenStationConfig: () {}));
    expect(pillIconColor(tester), const Color(0xFFB71C1C)); // unselected: on the bright tan fill
    await openControl(tester, MdiIcons.cat);
    expect(pillIconColor(tester), const Color(0xFFFF8A80)); // selected: on the dark tertiary fill
  });

  testWidgets('the Radio pill icon color flips between selected and unselected: dark mode', (tester) async {
    final theme = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    await tester.pumpWidget(host(appTheme: theme, hasConfiguredRadio: true, onOpenStationConfig: () {}));
    expect(pillIconColor(tester), const Color(0xFFFF8A80)); // unselected: on the near-black fill
    await openControl(tester, MdiIcons.cat);
    // A LITERAL, deliberately, where the sibling states could each name a
    // scheme role: dark mode's own `colorScheme.error` is a pale #F79797 that
    // reads at 1.23:1 on the amber this branch actually paints on in the app,
    // so an assertion phrased as `theme.colorScheme.error` would follow the
    // scheme straight back to the invisible value this pins away from.
    expect(pillIconColor(tester), const Color(0xFFA00000)); // selected: on the light amber fill
  });

  testWidgets('a connected radio is its own color in dark mode, not the shared positiveGreen', (tester) async {
    final theme = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    await tester.pumpWidget(
        host(appTheme: theme, hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}));
    await openControl(tester, MdiIcons.cat);
    // The cell an operator actually sits in — rig connected, Radio control
    // open — and the one that reaches for a SHARED constant most naturally.
    // [positiveGreen] is tuned for its own dark fills and reads 1.97:1 on the
    // amber this cell paints on, so taking it here would be invisible and
    // would look like reuse rather than a mistake.
    expect(pillIconColor(tester), const Color(0xFF005A00));
  });

  testWidgets('the Station Configuration button is disabled while editing an existing QSO', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(
      hasConfiguredRadio: true,
      radioConnected: true,
      onOpenStationConfig: () {},
      editingQso: existingQso,
    ));
    await openControl(tester, MdiIcons.cat);

    final button = tester.widget<InkWell>(find.byKey(const ValueKey('stationConfigButton')));
    expect(button.onTap, isNull);
  });

  testWidgets('an operation run under several callsigns logs contacts under the first, not the field', (tester) async {
    // The several callsigns live in `stationCall` as ONE comma-separated
    // string, so stamping the field puts "KI2D,W1AW" — not a callsign — on
    // every contact and into the `our_call` column the cross-operation Logs
    // view groups by. A contact holds exactly one call, as it does in
    // app-polo, whose extra calls sit in a separate array entirely.
    operation = await operations.create(stationCall: 'KI2D, W1AW');
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.ourCall, 'KI2D');
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

    Future<double> gapWith(WidgetTester tester, {required bool keyboardUp, bool hostHoldsStrip = false}) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: 34 * dpr); // a home indicator
      // Set BOTH branches, never just one: leaving `viewInsets` alone on the
      // keyboard-down call made the result depend on which order the two calls
      // happened to run in — reversing them measured "keyboard down" under a
      // raised keyboard and reported a difference of 0.
      tester.view.viewInsets = keyboardUp ? FakeViewPadding(bottom: 300 * dpr) : FakeViewPadding.zero;
      // `padding` too, and by hand: the real engine derives it (viewPadding
      // less whatever the keyboard covers), but a TestFlutterView holds the
      // two independently, so a fake that sets only `viewPadding` leaves
      // MediaQuery — which is where the panel reads the strip from — saying
      // there is no home indicator at all.
      tester.view.padding = keyboardUp ? FakeViewPadding.zero : FakeViewPadding(bottom: 34 * dpr);
      addTearDown(() {
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
        tester.view.resetPadding();
      });
      // A host that draws its own chrome over the bottom edge — the app's
      // status footer — takes the strip out of the MediaQuery it hands down,
      // which is exactly how this panel is told not to hold it twice.
      await tester.pumpWidget(hostHoldsStrip
          ? Builder(
              builder: (context) => MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: host(),
              ),
            )
          : host());
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

    testWidgets('reserves nothing when the host already holds the strip', (tester) async {
      // The app's status footer spans the window below every route and covers
      // the indicator itself, so the panel reserving it as well opens a band
      // of panel background between the fields and the footer. The host says
      // so by taking the inset out of the MediaQuery — nothing tells this
      // panel directly, which is why reading the strip from the raw
      // `FlutterView` instead would be undetectable here and wrong there.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final held = await gapWith(tester, keyboardUp: false, hostHoldsStrip: true);
        final unheld = await gapWith(tester, keyboardUp: false);
        expect(unheld - held, moreOrLessEquals(34, epsilon: 1.0));
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

  // The traps these two exist to catch: _log() letting an insert failure
  // escape to the zone handler (the panel looks like it logged while the QSO
  // is gone, and the generic notice shows at most once per session), wiping
  // the typed fields anyway, or leaving already-committed calls in the field
  // so the retry logs them twice.
  testWidgets('a failed insert keeps the typed call, says so in the panel, and reports the error', (tester) async {
    final errors = <Object>[];
    await tester.pumpWidget(host(
      qsosRepository: _FailingQsosRepository(db),
      onWriteError: (e, _) => errors.add(e),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, isEmpty);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'W1AW');
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(errors, hasLength(1));
  });

  testWidgets('a mid-list insert failure keeps only the unlogged calls, so a retry cannot duplicate', (tester) async {
    await tester.pumpWidget(host(qsosRepository: _FailingQsosRepository(db, addsBeforeFailure: 1)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW, K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC,N2XYZ');
    expect(find.textContaining('Could not save'), findsOneWidget);
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

  testWidgets('call stacking: a leading "//" is a stack whose first segment is empty', (tester) async {
    // Nothing here carves a leading "//" out of stacking — what keeps a note
    // key from logging is _log running command interpretation FIRST, and no
    // interpretCommand is wired in this host. So the key falls through and
    // logs as the callsign it looks like, rather than the field being
    // neither syntax and doing nothing.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//W1AW');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, '');
  });

  testWidgets('call stacking: a key leading a stack picks the cursor segment, not the key', (tester) async {
    // The trap: exclude a leading "//" from stacking and "//KEY//CALL" is
    // neither syntax — not a stack, and not a whole-field command either,
    // since the key then reads as "KEY//CALL" and matches nothing. Enter
    // does nothing at all, and no assertion about a logged QSO catches it.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN//W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    // The key is left intact, still leading, ready for the next Enter to
    // expand it.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, '//DAN');
  });

  testWidgets('call stacking: a cursor at the very start is not a dead spot', (tester) async {
    // The empty first segment is where offset 0 lands, and it has nothing to
    // expand and nothing to log — so without treating the leading "//" as a
    // separator rather than a segment, Enter does nothing here while the same
    // Enter one character to the right works. An invisible cursor position
    // selecting between two outcomes is the worst shape this can take.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//W1AW//QQQ');
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    callField.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    expect(callField.controller!.text, '//QQQ');
  });

  testWidgets('call stacking: a stacked segment that is a comma list logs every call in it', (tester) async {
    // "W1AW//K1ABC,N2XYZ" splits into "W1AW" and "K1ABC,N2XYZ"; the cursor
    // sits in the second. That segment is the shape a mid-stack note
    // expansion leaves behind, so it has to log as a list rather than be
    // skipped for failing looksLikeCallsign whole — otherwise an operator
    // could expand a key and then never log what it expanded to.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//K1ABC,N2XYZ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 2);
    expect(logged.map((q) => q.theirCall).toList(), ['K1ABC', 'N2XYZ']);

    // Only the picked segment leaves the field; the rest of the stack stays.
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'W1AW');
  });

  testWidgets('call stacking: a stacked segment with any implausible entry is skipped, not logged', (tester) async {
    // The comma list a segment holds is all-or-nothing, same rule a
    // top-level list follows — a half-typed second call must not drag the
    // segment into logging, it must fall back to scanning left.
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW//K1ABC,QQQ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, 'K1ABC,QQQ');
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

    Widget withWorkedBefore({
      required WorkedBefore workedBefore,
      Qso? editingQso,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              radioService: tunedRadio,
              operation: operation,
              qsosRepository: qsos,
              editingQso: editingQso,
              lookup: guessLookup({'name': 'Hiram'}),
              workedBefore: workedBefore,
              workedBeforeLabel: (times) => '${times.length} before',
            ),
          ),
        );

    // The argument is the whole reason an edited QSO is not its own prior
    // contact; nothing else fails when it is dropped.
    testWidgets('worked-before: an edit asks with its own QSO excluded, and shows the answer', (tester) async {
      final existing = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
            'freq': 7100,
            'mode': 'SSB',
          })))!;
      final asked = <(String, String?)>[];
      await tester.pumpWidget(withWorkedBefore(
        editingQso: existing,
        workedBefore: (call, {excludingQsoUuid}) async {
          asked.add((call, excludingQsoUuid));
          return [500];
        },
      ));
      await tester.pump(const Duration(milliseconds: 400));

      expect(asked, contains(('W1AW', existing.uuid)));
      expect(asked.where((a) => a.$1 == 'W1AW').every((a) => a.$2 == existing.uuid), isTrue);
      expect(find.text('1 before'), findsOneWidget);
    });

    // The trap: the worked-before fetch used to hang off the lookup's own
    // scheduling, below its `_lookupFor == activeCall` early return. A typo
    // and the backspace correcting it leave `_lookupFor` still naming the
    // original call, so that return fires — and the pill, cleared for the
    // typo, was never fetched again for the rest of the call's life.
    testWidgets('worked-before: survives a typo corrected before the lookup debounce fires', (tester) async {
      final pending = <String, Completer<List<int>>>{};
      await tester.pumpWidget(withWorkedBefore(
        workedBefore: (call, {excludingQsoUuid}) => (pending[call] ??= Completer()).future,
      ));
      final field = find.widgetWithText(TextField, 'Their call');

      await tester.enterText(field, 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      pending['W1AW']!.complete([1, 2, 3]);
      await tester.pump();
      expect(find.text('3 before'), findsOneWidget);

      // The typo, and the correction before its 300ms lookup debounce fires.
      await tester.enterText(field, 'W1AX');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('3 before'), findsOneWidget);
    });

    testWidgets('worked-before: an answer for a call no longer at the cursor is dropped', (tester) async {
      final pending = <String, Completer<List<int>>>{};
      await tester.pumpWidget(withWorkedBefore(
        workedBefore: (call, {excludingQsoUuid}) => (pending[call] ??= Completer()).future,
      ));
      final field = find.widgetWithText(TextField, 'Their call');
      await tester.enterText(field, 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(field, 'K1ABC');
      await tester.pump(const Duration(milliseconds: 400));
      expect(pending.keys, containsAll(['W1AW', 'K1ABC']));

      // The first call's answer lands late, after the field moved on.
      pending['W1AW']!.complete([1, 2, 3]);
      await tester.pump();
      expect(find.text('3 before'), findsNothing);

      pending['K1ABC']!.complete([7]);
      await tester.pump();
      expect(find.text('1 before'), findsOneWidget);
    });

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

    testWidgets('a grid typed with no call shows its distance line in place of the stats', (tester) async {
      // A microwave operator lines a dish up on a square before the other
      // station is named — polo shows the distance for a grid alone, and so
      // must this. Nothing else of call-info applies: no lookup ran, so the
      // line is all that appears, and it goes back to the stats the moment
      // the grid stops being complete.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            showGridField: true,
            callLocationLine: (guess) => '${guess['grid']} is 42 km away',
            operationStatsLines: (_) => ['stats-line'],
          ),
        ),
      ));
      expect(find.text('stats-line'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300)); // let the info-area cross-fade settle
      expect(find.text('FN20aa is 42 km away'), findsOneWidget);
      expect(find.text('stats-line'), findsNothing);

      // Half a grid points nowhere.
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN2');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('km away'), findsNothing);
      expect(find.text('stats-line'), findsOneWidget);
    });

    testWidgets('a grid with nothing to say about it keeps the stats, rather than a blank info line', (tester) async {
      // The app answers null when the operation has no location of its own;
      // swapping the stats for an empty line would hide that the operator's
      // own grid is what's missing.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            showGridField: true,
            callLocationLine: (guess) => null,
            operationStatsLines: (_) => ['stats-line'],
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('stats-line'), findsOneWidget);
    });

    testWidgets("a contest's own grid exchange counts as the grid for the no-call distance line", (tester) async {
      // The 10 GHz events take the grid on their exchange field, not the core
      // Grid field — the descriptor names its ref field `grid`, and that is
      // what marks it.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['arrl-vhf-tests']),
            qsosRepository: qsos,
            activityControls: const [
              {
                'key': 'arrl-vhf-tests/grid',
                'label': 'Grid',
                'input': {'kind': 'text', 'refType': 'arrl-vhf-tests', 'field': 'grid', 'maxLength': 6},
              },
            ],
            callLocationLine: (guess) => '${guess['grid']} is 42 km away',
            operationStatsLines: (_) => ['stats-line'],
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN20aa');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300)); // let the info-area cross-fade settle
      expect(find.text('FN20aa is 42 km away'), findsOneWidget);
      expect(find.text('stats-line'), findsNothing);
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
      expect(fits.pill.dx, greaterThan(fits.note.dx), reason: 'a short note should lead, with the pills beside it');
      expect((fits.pill.dy - fits.note.dy).abs(), lessThan(8), reason: 'on the same line');
      // Next to the note, not at the far right: a note row that filled the
      // line would leave the pills fitting but stranded.
      expect(fits.pill.dx, lessThan(fits.note.dx + 400), reason: 'the pills should hug the note');

      // Long: note takes line 2 on its own and the pills stack below it, so the
      // note starts at the column's left edge rather than trailing the pills.
      final wraps = await layout('Very long note about this operator ' * 8);
      // The note starts at the column's left edge; the pill's label is inset by
      // its own 6px padding, so the note is very slightly left of it.
      expect(wraps.note.dx, lessThan(wraps.pill.dx),
          reason: 'a note too wide for the row should start where the pills do, not trail them');
      expect(wraps.note.dy, lessThan(wraps.pill.dy), reason: 'and sit above them');
    });

    // A flag in the middle of a note is rendered as text, not rewritten into
    // an image, so the note's style is the only thing that can resolve it —
    // and Roboto resolves no emoji on web at all. Asserting the fallback
    // rather than the glyph: a widget test cannot see which font painted.
    testWidgets('a note carrying a flag styles it in the bundled emoji font', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            key: const ValueKey('flag-note'),
            operation: operation,
            qsosRepository: qsos,
            lookup: guessLookup({'note': 'from 🇺🇸 with **love**'}),
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async =>
                {'notices': ['newDXCC'], 'alerts': <String>[]},
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'IK1ABC');
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      // The note paints as spans (InlineMarkdownText), so the style rides the
      // root TextSpan rather than a Text widget.
      final note = find.textContaining('love', findRichText: true);
      expect(note, findsOneWidget);
      expect(tester.widget<RichText>(note).text.style?.fontFamilyFallback, contains(emojiFontFamily));
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

    // New State is scored off `their.guess.state`, which the lookup resolves
    // AFTER the scoring debounce has already run against a QSO that had no
    // guess at all. Scoring once per call would show the pill only for a call
    // already in the lookup cache.
    testWidgets('a resolved lookup re-scores, so the guess it carries can be scored on', (tester) async {
      final scoredStates = <String?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            lookup: guessLookup({'state': 'CT'}),
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
              final their = qso['their'] as Map;
              scoredStates.add(((their['guess'] as Map?)?['state']) as String?);
              return {'notices': <String>[], 'alerts': <String>[]};
            },
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // The first pass runs before the lookup lands and legitimately has no
      // guess; what matters is that a later pass sees the resolved state.
      expect(scoredStates, contains('CT'));
    });

    // The operator typing a state is the other way it reaches the scorer.
    testWidgets('typing a state re-scores', (tester) async {
      final scoredStates = <String?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            showStateField: true,
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
              scoredStates.add(((qso['their'] as Map)['state']) as String?);
              return {'notices': <String>[], 'alerts': <String>[]};
            },
          ),
        ),
      ));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextField, 'State'), 'CT');
      await tester.pump(const Duration(milliseconds: 500));

      expect(scoredStates.last, 'CT');
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

  // Who was at the key rides on the CONTACT, stamped at save time from the
  // operation. The pane is how a contact gets one of its own — the operator
  // who worked a guest at their station, or a record being corrected long
  // after the fact.
  testWidgets('an operator typed into the More pane is logged onto the contact', (tester) async {
    await tester.pumpWidget(host(defaultOperatorCall: 'N0DEV'));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    // The field shows the operation's answer as a placeholder only, so what
    // is typed here is the operator's own statement about this contact.
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'w1abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect((logged.single.data['our'] as Map)['operatorCall'], 'W1ABC');
  });

  // A contact merely opened and saved must keep taking the operation's stamp
  // (`qsoWithOperator`, applied by the app after this widget hands the QSO
  // over). Writing the placeholder through as a value would freeze whoever
  // happened to be at the key onto every record anyone ever opens.
  testWidgets('the More pane records no operator when its field was not touched', (tester) async {
    await tester.pumpWidget(host(defaultOperatorCall: 'N0DEV'));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect((logged.single.data['our'] as Map).containsKey('operatorCall'), isFalse);
  });

  // Wipe-then-undo round-trips the draft through `_applyFieldsFromData`, the
  // same path that would otherwise drop a name set in the pane. Dropped here,
  // the restored contact silently goes back to taking the operation's stamp.
  testWidgets('an operator set in the More pane survives wipe-then-undo', (tester) async {
    await tester.pumpWidget(host(defaultOperatorCall: 'N0DEV'));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'W1ABC');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // wipes, offers undo
    await tester.pump();
    await tester.tap(find.byIcon(MdiIcons.undo));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect((logged.single.data['our'] as Map)['operatorCall'], 'W1ABC');
  });

  testWidgets('the Position field is offered only where the operation is run by positions', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Position'), findsNothing,
        reason: 'a single-operator station has no seats to choose between');
  });

  testWidgets('a position typed into the More pane is logged in its canonical form', (tester) async {
    await tester.pumpWidget(host(showPositionField: true, defaultPosition: '1'));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Leading zeros and stray characters are the same seat as plain digits —
    // `/OP02` is a callsign no hunter can use.
    await tester.enterText(find.widgetWithText(TextField, 'Position'), '0x2');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect((logged.single.data['our'] as Map)['multiIdentifier'], '2');
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

  testWidgets('the published QSO draft carries every field, not just the call', (tester) async {
    // Extension panels declaring the `qso` trigger render against this, and
    // the whole point of publishing the draft rather than reusing the
    // call-info summary is that a panel can see what is about to be logged —
    // band and mode included.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(onQsoChanged: drafts.add));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));

    expect(drafts, isNotEmpty);
    final draft = drafts.last;
    expect((draft['their'] as Map)['call'], 'W1AW');
    expect(draft['band'], isNotNull, reason: 'the radio is tuned; a panel can see the band');
    expect(draft['mode'], isNotNull);
    expect((draft['our'] as Map)['call'], operation.stationCall);
  });

  testWidgets('a rebuild that changes nothing publishes no draft', (tester) async {
    // This fires from a post-frame callback on EVERY build, and the panel it
    // wakes crosses the JS bridge. Without the dedupe, an unrelated rebuild
    // of the operation view — a spot refresh, a clock tick — would look to
    // every `qso` panel exactly like the operator typing.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(onQsoChanged: drafts.add));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    final settled = drafts.length;

    await tester.pumpWidget(host(onQsoChanged: drafts.add));
    // Past a second, because the draft must not carry a live clock: an
    // auto-timestamped QSO takes its startAtMillis at save, and a "now" in
    // here would republish on every heartbeat and wake every `qso` panel
    // forever, with nobody touching the keyboard.
    await tester.pump(const Duration(milliseconds: 2500));

    expect(drafts.length, settled, reason: 'nothing about the QSO changed');
  });

  testWidgets('editing a field other than the call still publishes', (tester) async {
    // The draft is the whole QSO, not the callsign summary the call-info
    // callback carries: a dedupe keyed on the call alone would go quiet for
    // every field beside it, and a panel would show a report the operator
    // has already changed.
    final drafts = <Map<String, dynamic>>[];
    await tester.pumpWidget(host(onQsoChanged: drafts.add));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 200));
    final before = drafts.length;

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '559');
    await tester.pump(const Duration(milliseconds: 200));

    expect(drafts.length, greaterThan(before));
    expect((drafts.last['their'] as Map)['sent'], '559');
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

    group('several values in one field — a county line', () {
      // A QSO party's station may be on a county line and send both counties as
      // one exchange. Every value is checked, and the suggestion line and Space
      // act on the one the cursor is in — accepting a suggestion for the second
      // county must never rewrite the first, which the operator typed.
      Widget lineHost() => host(extra: const {'multiValue': {'separator': '/'}});

      testWidgets('both values are checked, not just the last', (tester) async {
        await tester.pumpWidget(lineHost());
        InputDecoration decoration() =>
            tester.widget<TextField>(find.widgetWithText(TextField, 'County')).decoration!;

        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/WAS');
        await tester.pump();
        expect(decoration().enabledBorder, isNull, reason: 'both counties are in the set');

        // A typo in the FIRST value is the case a last-value-only check misses,
        // and it costs a multiplier just as surely.
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'ZZ/WAS');
        await tester.pump();
        final errorColor = Theme.of(tester.element(find.widgetWithText(TextField, 'County'))).colorScheme.error;
        expect((decoration().enabledBorder as UnderlineInputBorder).borderSide.color, errorColor);
      });

      testWidgets('the suggestion line answers for the value being typed', (tester) async {
        await tester.pumpWidget(lineHost());
        await tester.tap(find.widgetWithText(TextField, 'County'));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/AS');
        await tester.pump();

        // Matches for "AS", not for the whole string — which matches nothing at
        // all, so without this the menu simply never appears on a county line.
        expect(find.textContaining('Ashland'), findsWidgets);
      });

      testWidgets('Space completes the second county and leaves the first alone', (tester) async {
        await tester.pumpWidget(lineHost());
        await tester.tap(find.widgetWithText(TextField, 'County'));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/WA');
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
          'CUY/WAS',
        );
      });

      testWidgets('a borrowed prefix beats a same-named county in another state', (tester) async {
        // 7QP's `ORDES/JEF` means Oregon's Jefferson — the first county says
        // which state. But `JEF` matches `IDJEF`, `MTJEF`, `ORJEF` and `WAJEF`
        // by NAME, so the literal reading always matched and Space took the
        // first of them: Idaho's Jefferson, silently, for an unambiguous
        // shorthand.
        const jeffersons = [
          {'code': 'IDJEF', 'name': 'Jefferson ID'},
          {'code': 'MTJEF', 'name': 'Jefferson MT'},
          {'code': 'ORDES', 'name': 'Deschutes OR'},
          {'code': 'ORJEF', 'name': 'Jefferson OR'},
        ];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              radioService: tunedRadio,
              operation: running(['qp']),
              qsosRepository: qsos,
              activityControls: [
                {
                  'key': 'qp/county',
                  'label': 'County',
                  'input': {
                    'kind': 'options',
                    'refType': 'qp',
                    'field': 'county',
                    'options': jeffersons,
                    'multiValue': {'separator': '/', 'inheritPrefix': 2},
                  },
                },
              ],
            ),
          ),
        ));

        await tester.tap(find.widgetWithText(TextField, 'County'));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'ORDES/JEF');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(find.widgetWithText(TextField, 'County')).controller?.text,
          'ORDES/ORJEF',
          reason: 'the shorthand names Oregon, and no other Jefferson may be written for it',
        );
      });

      testWidgets('the whole line is what gets logged', (tester) async {
        await tester.pumpWidget(lineHost());
        await tester.enterText(find.widgetWithText(TextField, 'County'), 'CUY/WAS');
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);

        final logged = await waitForQsos(tester, 1);
        expect(logged.single.refs, [
          {'type': 'qp', 'county': 'CUY/WAS'},
        ]);
      });
    });
  });

  group('a refresh that could not fetch', () {
    // `refreshActivityControls` fires when a callsign lookup resolves, mid-QSO,
    // while the operator is typing. Its result is installed over
    // `activityControls` — so a fan-out that failed and answered with an empty
    // list would take every activity field off the panel with no message. Null
    // is how "I could not fetch them" is said; an empty list still means "no
    // controls for this QSO" and must keep working.
    const exchange = {
      'key': 'c/exchange',
      'label': 'Exch',
      'icon': 'flag-checkered',
      'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
    };

    Future<void> pumpTyping(
      WidgetTester tester,
      Future<List<Map<String, dynamic>>?> Function(Map<String, dynamic>) refresh, {
      List<Map<String, dynamic>> panelControls = const [],
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['c']),
            qsosRepository: qsos,
            activityControls: panelControls,
            lookup: (call, {required qso, required operation, required online, recentContext = false}) async =>
                {'guess': <String, dynamic>{}},
            refreshActivityControls: refresh,
          ),
        ),
      ));
    }

    testWidgets('a later failure keeps what an earlier refresh fetched', (tester) async {
      // The panel-level set is EMPTY here on purpose. Assigning null on
      // failure would look harmless — `_effectiveActivityControls` falls back
      // to `widget.activityControls` — which is exactly why the fallback must
      // not be the thing under test: with nothing to fall back to, dropping
      // the guard takes the field away and only this shape notices.
      var call = 0;
      await pumpTyping(tester, (_) async => call++ == 0 ? [exchange] : null);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the first refresh fetched it');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget,
          reason: 'a refresh that could not fetch must not blank the QSO in progress');
    });

    testWidgets('an empty answer still means the activities want no controls', (tester) async {
      // The mutation this catches: folding empty in with null would make a
      // control impossible to remove for a QSO once it had been shown.
      var call = 0;
      await pumpTyping(tester, (_) async => call++ == 0 ? [exchange] : const []);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing);
    });

    testWidgets('a ref added to the operation is not shadowed by an earlier empty refresh', (tester) async {
      // The scenario `_refreshedActivityControls` traps: a callsign lookup
      // resolved BEFORE the contest was added to the operation, caching an
      // empty per-QSO refresh. Adding the contest gives the operation a fresh
      // `activityControls` list — that has to win, not the stale cache, or
      // the exchange field stays invisible for the rest of the session.
      await pumpTyping(tester, (_) async => const []);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsNothing, reason: 'nothing configured yet');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['c']),
            qsosRepository: qsos,
            activityControls: const [exchange],
            lookup: (call, {required qso, required operation, required online, recentContext = false}) async =>
                {'guess': <String, dynamic>{}},
            // A real per-QSO refresh reads the same operation data the
            // operation-level one does, so it agrees once the ref exists —
            // this isn't the fixed-forever-empty callback pumpTyping's other
            // tests use, because a resolved lookup re-fires this on the ref
            // add (see the test below), and that has to see the new field
            // too rather than race the operation-level fetch to install it.
            refreshActivityControls: (_) async => const [exchange],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget,
          reason: "the operation's own refresh must not be shadowed by the stale per-QSO one");
    });

    testWidgets('a per-QSO refresh already in flight when a ref is added cannot reshadow it on return',
        (tester) async {
      // The race `_activityControlsGeneration` guards, distinct from the test
      // above: there the stale refresh had already LANDED before the ref was
      // added. Here it's still IN FLIGHT — issued before, resolving after —
      // so the generation it started against has to be checked on return, not
      // just cleared going in.
      final completers = <Completer<List<Map<String, dynamic>>?>>[];
      await pumpTyping(tester, (_) {
        final completer = Completer<List<Map<String, dynamic>>?>();
        completers.add(completer);
        return completer.future;
      });

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 300)); // past the lookup debounce
      await tester.pump(); // offline lookup resolves, _lookupFor is set, refresh #1 is issued
      expect(completers, hasLength(1));

      // The ref is added — a fresh `activityControls` identity — WHILE
      // refresh #1 is still pending. Per the fix above, that also re-issues
      // a refresh (#2) against the new activityControls, since a lookup is
      // already resolved for the active call.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['c']),
            qsosRepository: qsos,
            activityControls: const [exchange],
            lookup: (call, {required qso, required operation, required online, recentContext = false}) async =>
                {'guess': <String, dynamic>{}},
            refreshActivityControls: (_) {
              final completer = Completer<List<Map<String, dynamic>>?>();
              completers.add(completer);
              return completer.future;
            },
          ),
        ),
      ));
      await tester.pump();
      expect(completers, hasLength(2), reason: 'adding the ref re-issued a refresh for the resolved lookup');

      // Resolve #1 (the stale, pre-ref-add refresh) AFTER #2 (the fresh one)
      // — the actual race, not just two calls that happen to finish in
      // issue order.
      completers[1].complete(const [exchange]);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget, reason: 'the fresh refresh landed');

      completers[0].complete(const []);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Exch'), findsOneWidget,
          reason: 'the stale refresh landing late must not blank the field the fresh one just set');
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
      await startContact(tester);
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
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await waitForQsos(tester, 1, repository: repo);
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '2');
    });

    testWidgets('shows no number until the operator starts a contact', (tester) async {
      // A shown number is held against every other position from that moment
      // (docs/design/contests.md §5.8.1), so an idle panel holds nothing —
      // and a blank is the only honest display of nothing. The same on a
      // single device: one rule, not a peers-connected special case.
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');

      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '1');
    });

    testWidgets('a wipe lets go of the number and shows none again', (tester) async {
      final repo = allocating();
      final source = _RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['cqwpx']),
            qsosRepository: repo,
            serialNumbers: source,
            activityControls: controls,
          ),
        ),
      ));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      expect(source.claims, 1);

      await tester.tap(find.bySemanticsIdentifier('action.wipe'));
      await tester.pump();
      expect(source.releases, greaterThanOrEqualTo(1), reason: 'the hold goes with the draft');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
    });

    testWidgets('Enter inside the claim window waits for the number rather than logging a blank', (tester) async {
      // The commit-time allocator is blind to the peers' holds: a blank
      // serial field on Enter would be filled from the local counter, and
      // two positions would send one number with neither record marked.
      final repo = allocating();
      final source = _RecordingSerialSource(repo.sequences!, gate: Completer<void>());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['cqwpx']),
            qsosRepository: repo,
            serialNumbers: source,
            activityControls: controls,
          ),
        ),
      ));
      await startContact(tester, 'W1AW');
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '',
          reason: 'the claim is still settling');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 20));
      expect(await tester.runAsync(() => repo.watchForOperation(operation.uuid).first), isEmpty,
          reason: 'nothing committed while the number is unsettled');

      // The peers answer: the number lands in the field and the commit goes
      // through with it.
      source.gate!.complete();
      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ]);
    });

    testWidgets('backspacing the call to nothing lets the number go', (tester) async {
      // A hold with no draft behind it blocks the other positions for as
      // long as the operator leaves the panel — and shows a number nobody
      // is about to send.
      final repo = allocating();
      final source = _RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['cqwpx']),
            qsosRepository: repo,
            serialNumbers: source,
            activityControls: controls,
          ),
        ),
      ));
      await startContact(tester, 'W1');
      await pumpUntilSerial(tester, 'Our #');
      expect(source.releases, 0);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
      await tester.pump();
      expect(source.releases, 1);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Our #')).controller?.text, '');
    });

    testWidgets('leaving the panel mid-contact lets the number go', (tester) async {
      final repo = allocating();
      final source = _RecordingSerialSource(repo.sequences!);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['cqwpx']),
            qsosRepository: repo,
            serialNumbers: source,
            activityControls: controls,
          ),
        ),
      ));
      await startContact(tester);
      await pumpUntilSerial(tester, 'Our #');
      await tester.pumpWidget(const SizedBox());
      expect(source.releases, 1);
    });

    testWidgets('a number another position also showed is logged with the mark', (tester) async {
      // The number went on the air, so it is written as shown; the record
      // wearing the mark is what tells the operator two stations sent it.
      final repo = allocating();
      final source = _RecordingSerialSource(repo.sequences!, conflicted: {1});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: running(['cqwpx']),
            qsosRepository: repo,
            serialNumbers: source,
            activityControls: controls,
          ),
        ),
      ));
      await startContact(tester, 'W1AW');
      await pumpUntilSerial(tester, 'Our #');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1, repository: repo);
      expect(logged.single.refs, [
        {'type': 'cqwpx', 'ourSerial': 1},
      ]);
      expect(logged.single.serialConflict, isTrue);
      expect(source.committed.map((request, number) => MapEntry(request.label, number)), {'cqwpx/serial': 1},
          reason: 'the source is told what the log now holds');
    });

    testWidgets('a number the operator types over the preview is what gets logged', (tester) async {
      final repo = allocating();
      await tester.pumpWidget(hostWith(repo));
      await startContact(tester);
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
      await startContact(tester);
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
      await startContact(tester);
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
      await startContact(tester);
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

  group('HALO-158: the frequency field also takes a band', () {
    TextField field(WidgetTester tester, String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label));

    /// Types [text] into the Frequency field and leaves it with Space —
    /// which, from this field, hands focus back to the call field
    /// (`_handleSpace`) and so is the gesture that commits it.
    Future<void> typeFreqAndLeave(WidgetTester tester, String text) async {
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), text);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
    }

    // `host()` seeds a radio tuned to 14285 / 20m, so every band asserted here
    // is deliberately NOT 20m — otherwise the seed alone would satisfy it.

    testWidgets('a band with its unit lands in the Band dropdown and empties the field', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '40m');

      expect(field(tester, 'Band').controller!.text, '40m');
      expect(field(tester, 'Frequency').controller!.text, isEmpty,
          reason: 'the text that named the band is not a frequency, and must not read as one');
    });

    testWidgets('a bare number names a band too, since the iOS keyboard here has no letters', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '15');

      expect(field(tester, 'Band').controller!.text, '15m');
      expect(field(tester, 'Frequency').controller!.text, isEmpty);
    });

    testWidgets('a real frequency is left exactly as typed', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '7123');

      expect(field(tester, 'Frequency').controller!.text, '7123',
          reason: 'a frequency inside a band is never re-read as a band');
      expect(field(tester, 'Band').controller!.text, '40m');
    });

    testWidgets('nothing resolves until the operator leaves the field', (tester) async {
      // The reason resolution is on commit rather than per keystroke: "40" is
      // a prefix of "40 something" as often as it is a request for 40m. Moving
      // this into `_band` or `_onFreqChanged` makes every frequency typed by
      // hand flicker through a band on its way, and breaks here.
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '40');
      await tester.pump();

      expect(field(tester, 'Band').controller!.text, isNot('40m'));
      expect(field(tester, 'Frequency').controller!.text, '40');
    });

    testWidgets('text that names no band is left alone', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      // 14m is not a band; rounding it to the nearest one would log a contact
      // on a band the operator never named.
      await typeFreqAndLeave(tester, '14m');

      expect(field(tester, 'Frequency').controller!.text, '14m');
    });

    testWidgets('a frequency the operator never typed is left alone, band number or not', (tester) async {
      // A general-coverage rig parked on WWVB reports 60 kHz, which is in no
      // band and reads exactly like the bare form of 60m. Opening the Radio
      // control focuses this field, so without a "did they change it?" gate,
      // opening the control and leaving it would swallow the reading and push
      // 60m back at the rig — no keystroke involved.
      final seeded = _FakeVfoStore()..setVfo('vfoA', freq: 60, mode: 'SSB');
      await tester.pumpWidget(host(radioService: seeded));
      await openControl(tester, MdiIcons.radio);

      expect(field(tester, 'Frequency').controller!.text, '60', reason: 'the seed must reach the field');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(field(tester, 'Frequency').controller!.text, '60');
      expect(seeded.vfoA.freq, 60);
      expect(seeded.vfoA.band, isNot('60m'));
    });

    testWidgets('a band typed into the field logs a band-only QSO', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '40m');
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.band, '40m');
      expect(logged.single.freq, isNull,
          reason: 'the operator named a band, not a frequency — HALO-24 is satisfied by the band alone');
    });
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
    //
    // Both halves of the operator's scope, never just the country: a lone
    // country code is discarded (see radio.dart's `_bestSegmentFor`), and
    // the panel is fed both from one DXCC entity anyway — operation_view's
    // `ourGuess` sets `_ourItuRegion` and `_ourCountryCode` together.
    await tester.pumpWidget(host(ourItuRegion: 2, ourCountryCode: 'us')); // tunedRadio seeds Mode as SSB
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

  testWidgets('devHammer forwards to onCommandAction', (tester) async {
    // The same whitelist trap as the test above. A missing branch here is
    // especially quiet for DEVHAMMER: interpretation still matches and the
    // palette still prints the extension's confirmation, so the tester is
    // told the status bar is being hammered while nothing happens at all —
    // which reads as the churn no longer provoking the bug.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeHammerCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'DEVHAMMER') return null;
      return {
        'describe': 'Churn the status bar?',
        'confirm': 'Hammering the status bar',
        'commands': [
          {
            'devHammer': {'seconds': 5},
          },
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeHammerCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVHAMMER');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'devHammer');
    expect(dispatched.single.value, {'seconds': 5});
  });

  testWidgets('the settings-command actions (updateSetting/openSettings) forward to onCommandAction', (tester) async {
    // Same silent-no-op trap as the reloadDataFiles test above. SET/SHOW/HIDE
    // are especially prone to it: the describe preview is produced entirely by
    // the hook, so a missing branch here shows the operator "Change Zero Beat
    // to Off?", clears the field, prints the confirmation — and changes
    // nothing at all.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeSettingsCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      switch (input.trim().toUpperCase()) {
        case 'SETONE':
          return {
            'describe': 'Change Zero Beat to Off?',
            'confirm': 'Zero Beat set to Off',
            'commands': [
              {
                'updateSetting': {'key': 'avoidZeroBeat', 'value': false},
              },
            ],
          };
        case 'SETTWO':
          return {
            'describe': 'Open Bands…',
            'commands': [
              {
                'openSettings': {
                  'keys': ['bands'],
                  'title': 'Bands',
                },
              },
            ],
          };
        default:
          return null;
      }
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeSettingsCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    final field = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(field, 'SETONE');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(field, 'SETTWO');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(2));
    expect(dispatched[0].key, 'updateSetting');
    expect(dispatched[0].value, {'key': 'avoidZeroBeat', 'value': false});
    expect(dispatched[1].key, 'openSettings');
    expect(dispatched[1].value, {
      'keys': ['bands'],
      'title': 'Bands',
    });
  });

  testWidgets('setPower (the POWER command) forwards to onCommandAction, same whitelist trap as reloadDataFiles', (tester) async {
    // Unlike setVfo it has no QSO-scoped widget state of its own to update
    // here — a missing branch would still show "Change power to 5W?" /
    // "Power set to 5W" and silently do nothing.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakePowerCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != '5W') return null;
      return {
        'describe': 'Change power to **5W**?',
        'confirm': 'Power set to **5W**',
        'commands': [
          {
            'setPower': {'watts': 5},
          },
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakePowerCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    final field = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(field, '5W');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'setPower');
    expect(dispatched.single.value, {'watts': 5});
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

  testWidgets("a spot carries the operation's device-local data, where the multi-station identifier lives",
      (tester) async {
    // `ExtensionService.spotCallForSelfSpot` builds `KI2D/OP2` out of
    // `operation['local']`. Drop it from the payload and every device of a
    // multi-station operation self-spots as the same bare call — the exact
    // collision the identifier exists to prevent, and one nothing inside this
    // widget would report.
    await operations.updateLocalData(operation.uuid, {'multiIdentifier': '2'});
    operation = (await operations.get(operation.uuid))!;

    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeSpotCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'SPOT') return null;
      return {
        'describe': 'Self-spot?',
        'confirm': 'Spotting…',
        'commands': [
          {'sendSpots': <String, dynamic>{}},
        ],
      };
    }

    await tester.pumpWidget(host(
      interpretCommand: fakeSpotCommand,
      onCommandAction: (action, [params]) async {
        dispatched.add(MapEntry(action, params));
      },
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SPOT');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched.single.key, 'sendSpots');
    final spotted = (dispatched.single.value!['operation'] as Map).cast<String, dynamic>();
    expect((spotted['local'] as Map)['multiIdentifier'], '2');
    expect(spotted['stationCall'], 'KI2D', reason: 'the suffix is applied downstream, not here');
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

    // A leading "//" IS a stack (first segment empty), so the only thing
    // keeping this from logging DAN as a callsign is _log reaching command
    // interpretation first.
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

  group('note expansion inside a call stack', () {
    // A note key stacked alongside other calls ("KI2D//DAN") never reaches
    // command interpretation as a whole-field command — the field isn't
    // "//DAN", it's a stack. The panel asks the same hook about just the
    // segment under the cursor and splices the answer back into it, so
    // Enter expands and the NEXT Enter logs.
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

    TextField callField(WidgetTester tester) =>
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));

    testWidgets('Enter expands the segment under the cursor and logs nothing', (tester) async {
      await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // Only the one segment is replaced — the call already stacked ahead of
      // it survives untouched, which a whole-field setCallField would wipe.
      expect(callField(tester).controller!.text, 'KI2D//WD4DAN,WD4JMM');
      expect(await waitForQsos(tester, 1), isEmpty);

      // The cursor has to land back on the expanded segment: stacking picks
      // the segment the cursor is in, so anywhere else and the next Enter
      // would log KI2D instead of what was just expanded.
      expect(callField(tester).controller!.selection.baseOffset, 'KI2D//WD4DAN,WD4JMM'.length);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      expect(logged.map((q) => q.theirCall).toList(), ['WD4DAN', 'WD4JMM']);
      expect(callField(tester).controller!.text, 'KI2D');
    });

    testWidgets('a key LEADING the stack expands too, then the rest logs', (tester) async {
      // A leading key is a stack whose first segment is empty, so it takes
      // the same mid-stack path as any other. Disqualify a leading "//" from
      // stacking and this field is neither syntax — the whole-field key reads
      // as "DAN//W1AW" and matches nothing — so Enter does nothing at all.
      await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN//W1AW');
      // Cursor on the key, at the end of "//DAN".
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // The empty first segment survives the splice, so the call stacked
      // behind the key is untouched and the key's own "//" is still there.
      expect(callField(tester).controller!.text, '//WD4DAN,WD4JMM//W1AW');
      expect(await waitForQsos(tester, 1), isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((await waitForQsos(tester, 2)).map((q) => q.theirCall).toList(), ['WD4DAN', 'WD4JMM']);
      expect(callField(tester).controller!.text, '//W1AW');

      // And what is left is a bare "//W1AW" the hook declines — so it logs
      // as the callsign it looks like rather than stranding the operator.
      // Compared as a set: the comma list's own +5s stagger puts W1AW
      // between its two entries by start time, which says nothing here.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((await waitForQsos(tester, 3)).map((q) => q.theirCall).toSet(), {'WD4DAN', 'WD4JMM', 'W1AW'});
      expect(callField(tester).controller!.text, '');
    });

    testWidgets('a whole-field key that is itself a valid callsign expands, and logs nothing', (tester) async {
      // What stops "//W1AW" being logged as the callsign it looks like is
      // ORDER — _log interprets the whole field before stacking ever runs.
      // Nothing else guards it, so move the stacking path above the command
      // path and this logs a stray QSO for a station never worked. "//DAN"
      // cannot catch that: DAN has no digit, so looksLikeCallsign rejects it
      // and stacking would decline the segment anyway.
      Future<Map<String, dynamic>?> expandsW1AW(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        if (input.trim().toUpperCase() != '//W1AW') return null;
        return {
          'commands': [
            {
              'setCallField': {'text': 'W1AW,W1AX'},
            },
          ],
        };
      }

      await tester.pumpWidget(host(interpretCommand: expandsW1AW));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, 'W1AW,W1AX');
      expect(await waitForQsos(tester, 1), isEmpty);
    });

    testWidgets('a cursor at the very start still expands the key it precedes', (tester) async {
      // Offset 0 lands on the stack's empty first segment, which has nothing
      // to expand — so unless the leading "//" is treated as a separator
      // rather than a segment, Enter here does nothing while the same Enter
      // one character right expands normally.
      await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN//W1AW');
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, '//WD4DAN,WD4JMM//W1AW');
      expect(await waitForQsos(tester, 1), isEmpty);
    });

    testWidgets('a stacked segment with no note of its own logs the ordinary way', (tester) async {
      // The expansion probe runs on every stacked Enter; when the hook
      // declines, stacking has to proceed exactly as before rather than
      // swallowing the keypress.
      await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
      expect(callField(tester).controller!.text, 'KI2D');
    });

    testWidgets('the expansion is previewed while typing, before Enter', (tester) async {
      await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.textContaining('Expand to WD4DAN,WD4JMM?'), findsOneWidget);
    });

    testWidgets('the expanded field keeps focus, so the next Enter still knows which segment', (tester) async {
      // An unfocused field reports NO selection, and the no-selection
      // fallback is the last segment — in a three-segment stack that is a
      // different call than the one just expanded, so the second Enter would
      // log the wrong QSO entirely.
      await tester.pumpWidget(host(interpretCommand: fakeExpandCommand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN//W1AW');
      // Put the cursor in the middle segment, the one holding the key.
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 9);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, 'KI2D//WD4DAN,WD4JMM//W1AW');
      expect(callField(tester).focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      expect(logged.map((q) => q.theirCall).toList(), ['WD4DAN', 'WD4JMM']);
      expect(callField(tester).controller!.text, 'KI2D//W1AW');
    });

    testWidgets('nothing is asked to EXECUTE for a stacked call that expands to nothing', (tester) async {
      // The probe runs on every stacked Enter, ordinary calls included. An
      // execute-time interpretation is allowed side effects of its own (a
      // network fetch, a batch of generated QSOs), so a speculative one whose
      // answer is then thrown away is a real action nobody asked for.
      final executed = <String>[];
      Future<Map<String, dynamic>?> recording(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        if (execute) executed.add(input.trim().toUpperCase());
        return fakeExpandCommand(input, operation, qso, execute);
      }

      await tester.pumpWidget(host(interpretCommand: recording));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await waitForQsos(tester, 1);
      expect(executed, isEmpty);

      // ...but a segment that DOES expand still gets the executable
      // interpretation, whose `commands` are the real ones — a hook is free
      // to leave the preview's cheap.
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      expect(executed, ['//DAN']);
    });

    testWidgets('a cursor moved while the hook answers cannot make the splice land on another segment', (tester) async {
      // The probe is a JS runtime round trip; a click or arrow key during it
      // moves the cursor without touching the text, so a staleness guard that
      // only compares text would let the answer for one segment overwrite a
      // completely different call.
      final gate = Completer<void>();
      Future<Map<String, dynamic>?> slowExpand(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        if (input.trim().toUpperCase() == '//DAN') await gate.future;
        return fakeExpandCommand(input, operation, qso, execute);
      }

      await tester.pumpWidget(host(interpretCommand: slowExpand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DAN//W1AW');
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 3); // in "DAN"
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // The operator clicks into the other segment while the hook is thinking.
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 9);
      await tester.pump();
      gate.complete();
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, 'WD4DAN,WD4JMM//W1AW');
    });

    group('a key that is also a real callsign', () {
      // The escape hatch. A stacked segment's "//" is a separator, not the
      // operator asking to expand — so a note keyed on a real callsign would
      // otherwise capture that station forever: Enter expands, deleting what
      // the expansion added and pressing Enter expands again, and the call
      // can never be logged on its own.
      Future<Map<String, dynamic>?> expandsW1AW(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        if (input.trim().toUpperCase() != '//W1AW') return null;
        return {
          'describe': 'Expand to W1AW,W1AX?',
          'commands': [
            {
              'setCallField': {'text': 'W1AW,W1AX'},
            },
          ],
        };
      }

      testWidgets('taking the expansion back and pressing Enter again logs the call itself', (tester) async {
        await tester.pumpWidget(host(interpretCommand: expandsW1AW));

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));
        expect(callField(tester).controller!.text, 'K1ABC//W1AW,W1AX');

        // The operator deletes what the expansion added, putting the segment
        // back exactly as typed, and submits again.
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        // ...and is not offered the same expansion a second time, which
        // would contradict what Enter is now about to do.
        expect(find.textContaining('Expand to'), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = await waitForQsos(tester, 2);
        expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
        expect(callField(tester).controller!.text, 'K1ABC');
      });

      testWidgets('the hatch lasts only for the entry it was used on', (tester) async {
        // Spent state belongs to the draft, not the session — the next
        // contact typing the same key must get its expansion.
        await tester.pumpWidget(host(interpretCommand: expandsW1AW));

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await waitForQsos(tester, 1);

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N2XYZ//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));

        expect(callField(tester).controller!.text, 'N2XYZ//W1AW,W1AX');
      });
    });

    testWidgets('a repeated Enter racing the probe logs one QSO, not two', (tester) async {
      // Key auto-repeat fires well inside an extension round trip, and the
      // probe now sits between _log's entry guard and the point it commits to
      // logging — so both presses can be inside that window at once.
      final gate = Completer<void>();
      Future<Map<String, dynamic>?> slowExpand(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        if (input.trim().startsWith('//')) await gate.future;
        return null; // nothing expands — this Enter is an ordinary stacked log
      }

      await tester.pumpWidget(host(interpretCommand: slowExpand));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      gate.complete();
      await tester.pump(const Duration(milliseconds: 200));

      final logged = await waitForQsos(tester, 2);
      expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
    });
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

  testWidgets('HALO-143: jumpAfterRST moves on once a report is complete, and stays put until then', (tester) async {
    await tester.pumpWidget(host(jumpAfterRST: true));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();

    // One digit is not a report — jumping here would make a true 57
    // untypeable.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'two characters is a full report on phone');

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'the last report wraps on to the callsign');
  });

  testWidgets('HALO-143: jumpAfterRST waits for the tone digit on CW, so aurora reports stay typeable',
      (tester) async {
    // The trap a two-character threshold would set: on CW a `44` still owes
    // its `A` (or its tone), so jumping at two makes `44A` and `5NN`
    // unreachable — the operator is thrown into the next field mid-report.
    await tester.pumpWidget(host(jumpAfterRST: true, interpretCommand: fakeInterpretCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '44');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'two characters is not a full CW report');

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '44A');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);
    expect(field('Sent').controller!.text, '44A', reason: 'the aurora report survives intact');
  });

  testWidgets('HALO-143: jumpAfterRST does not fire while correcting an already-complete report', (tester) async {
    // PoLo tests `length >= full` on every keystroke, so editing a field that
    // already holds a full report throws focus away on the first character.
    // Firing on the upward crossing only is what makes a correction possible.
    await tester.pumpWidget(host(jumpAfterRST: true));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup: it jumped once');

    // Back to Sent to fix it. Every keystroke from here leaves the field at or
    // above the full length, and none of them may jump.
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '599');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5991');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: jumpAfterRST off leaves focus alone', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: jumpAfterRST does not apply on the FT modes, whose report has no fixed length',
      (tester) async {
    // -9, +05 and -12 are all real SNR reports, so no length means "done".
    // Any threshold here is wrong for some of them; the setting sits out.
    await tester.pumpWidget(host(jumpAfterRST: true, interpretCommand: fakeInterpretCommand));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'FT8');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '-12');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: switchSentRcvd swaps the row and the keyboard path through it together', (tester) async {
    // The pair that must not drift: the row's own order and the Space cycle's.
    // A swap applied to only one of them leaves Space skipping backwards
    // through fields the operator sees left to right.
    await tester.pumpWidget(host(switchSentRcvd: true));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    double left(String label) => tester.getTopLeft(find.widgetWithText(TextField, label)).dx;
    expect(left('Rcvd'), lessThan(left('Sent')), reason: 'Rcvd is drawn first');

    // Space walks Call → Rcvd → Sent, following what is on screen. Entered in
    // two steps because the interceptor only claims a genuine single-space
    // insertion at the end of the value, not a bulk replacement that happens
    // to end in one.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'Space reaches the leftmost report first');

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), ' ');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: focusing a complete report on a QSO opened for editing does not jump', (tester) async {
    // A QSO CONSTRUCTED already-editing is populated before the jump
    // listeners exist, so the baseline they compare against has to be seeded
    // from the fields rather than left at zero. Without it this needs no
    // typing at all to go wrong: gaining focus collapses the selection, which
    // is a value change, which reads as "0 -> 3" and jumps — and the next
    // field, equally unseeded, jumps again. Tapping Sent to fix a 599 walks
    // the operator straight past Rcvd and out of the reports entirely.
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'our': {'sent': '599'},
          'their': {'call': 'W1AW', 'sent': '599'},
          'startAtMillis': 1000000,
          'freq': 7020,
          'mode': 'CW',
        })))!;
    await tester.pumpWidget(host(editingQso: existingQso, jumpAfterRST: true));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, '599', reason: 'test setup');
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'merely arriving in a full field must not move on');

    // And a correcting keystroke on top of it stays put too.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5991');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: switchSentRcvd reaches the More pane, which is a separate order expression',
      (tester) async {
    // The pane round-trips through a Map of field keys, not through the
    // controllers the row shares, so its order is written out a second time —
    // and a second expression is a second chance to get the ternary backwards.
    // A pane contradicting the row that opened it is the whole failure.
    await tester.pumpWidget(host(switchSentRcvd: true));
    await openControl(tester, MdiIcons.pencil);
    await tester.pumpAndSettle();

    final sent = find.text('Sent');
    final rcvd = find.text('Rcvd');
    expect(sent, findsWidgets);
    expect(rcvd, findsWidgets);
    expect(
      tester.getTopLeft(rcvd.last).dy,
      lessThan(tester.getTopLeft(sent.last).dy),
      reason: 'the pane stacks its fields, so Rcvd first means Rcvd higher',
    );
  });

  testWidgets('HALO-143: switchSentRcvd keeps each value on its own field, it only moves them', (tester) async {
    // The failure a pure-display swap invites: reversing the widgets without
    // reversing what they are bound to silently logs the reports backwards.
    await tester.pumpWidget(host(switchSentRcvd: true));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '33');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '57');
    expect(logged.single.receivedRST, '33');
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

  // At EVERY density, not just the default. The dropdowns cannot use
  // poloFieldDecoration — DropdownMenu takes an inputDecorationTheme, not an
  // InputDecoration — so they restate its padding, and a const there froze
  // them at one height while the field beside them moved with the ladder.
  // Running this at `normal` alone is exactly what missed that.
  for (final density in LayoutDensity.values) {
    testWidgets('$density: Radio dropdowns render at the same height as the sibling text fields', (tester) async {
      await tester.pumpWidget(LayoutDensityScope(density: density, child: host()));
      await openControl(tester, MdiIcons.radio);

      // `suffixIconConstraints` in the decoration is what holds these level:
      // without it the trailing arrow's 48px minimum tap target makes the
      // dropdown taller than the Frequency field beside it.
      final freqHeight = tester.getSize(find.widgetWithText(TextField, 'Frequency')).height;
      final dropdowns = find.byType(DropdownMenu<String>);
      expect(dropdowns, findsNWidgets(2));
      expect(tester.getSize(dropdowns.at(0)).height, freqHeight);
      expect(tester.getSize(dropdowns.at(1)).height, freqHeight);
    });
  }

  // A DropdownMenu takes an inputDecorationTheme, and these two BUILD one
  // rather than copyWith-ing the app's — so every slot the app theme carries
  // is silently absent here unless restated. The focus indicator is one of
  // them, and unrestated it lands on `primary`: 2.67:1 on the dark surface,
  // beside a Frequency field focusing white.
  for (final brightness in Brightness.values) {
    testWidgets('$brightness: the Band and Mode dropdowns restate the focus indicator', (tester) async {
      final theme = buildHaLoTheme(brightness);
      await tester.pumpWidget(host(appTheme: theme));
      await openControl(tester, MdiIcons.radio);

      final dropdowns = tester.widgetList<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
      expect(dropdowns.length, 2);
      for (final dropdown in dropdowns) {
        final side = dropdown.inputDecorationTheme?.focusedBorder?.borderSide;
        expect(side, isNotNull, reason: '$brightness');
        // Not just "≠ primary": a fixed Colors.black satisfies that and is
        // black-on-near-black once the pane goes dark. The invariant is the
        // CONTRAST against the surface the field sits on, not the color.
        expect(_contrast(side!.color, theme.colorScheme.surface), greaterThanOrEqualTo(3.0),
            reason: '$brightness');
        // The same underline poloFieldDecoration gives the Frequency field
        // beside it — these must not diverge into two focus cues in one row.
        // (Both sides move together if the helper changes; what this catches is
        // the dropdowns drifting away from it, not the helper going wrong.)
        expect(side.color, haloFocusedInputBorder(brightness == Brightness.dark).borderSide.color,
            reason: '$brightness');
        // The focus indicator above is an UNDERLINE, which matches only while
        // these declare no shape of their own and Material's default applies.
        // Declaring an outline here without also reshaping the focused border
        // makes the field collapse to a bare line on focus — the exact trap
        // that keeps this out of the app theme (theme.dart).
        expect(dropdown.inputDecorationTheme?.border, isNull, reason: '$brightness');
        expect(dropdown.inputDecorationTheme?.enabledBorder, isNull, reason: '$brightness');
      }
    });
  }

  testWidgets('the radio row actually changes height across the density ladder', (tester) async {
    // The sibling check above passes trivially if NOTHING moves. This is the
    // other half: the row has to be genuinely shorter when dense.
    double heightAt(WidgetTester t) => t.getSize(find.widgetWithText(TextField, 'Frequency')).height;

    Future<double> measure(LayoutDensity density) async {
      // A full unmount between the two: re-pumping a different scope over the
      // same tree keeps the panel's State, and with it the closed radio
      // control, so the second measurement would find no Frequency field.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(LayoutDensityScope(density: density, child: host()));
      await openControl(tester, MdiIcons.radio);
      return heightAt(tester);
    }

    final densest = await measure(LayoutDensity.densest);
    final sparsest = await measure(LayoutDensity.sparsest);

    expect(sparsest - densest, greaterThanOrEqualTo(15.0));
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

  testWidgets('a mode picked from the menu is a selection, not a filter', (tester) async {
    // The trap: DropdownMenu writes the picked label into the controller
    // before `onSelected` runs, so the pick looks exactly like typed text.
    // Kept as a filter it narrows the menu to the one entry picked, and
    // DropdownMenu then refuses to sync the field to a changed
    // `initialSelection` it can't find among those entries — so the band
    // plan's next guess never reaches the field, and the commit on the way
    // out pushes the stale mode back over it.
    fakeRadio.setVfo('vfoA', freq: 7200, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7050');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT4');

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(MenuItemButton, 'CW').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(fakeRadio.vfoA.mode, 'CW');

    // Tuning on: the band plan's guess for 7200 has to reach the field.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7200');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    // …and the menu still offers every enabled mode, not just the one picked.
    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a band picked from the menu is a selection, not a filter', (tester) async {
    // Same trap as the Mode dropdown above, on the sibling that shares the
    // filter machinery.
    await tester.pumpWidget(host(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(MenuItemButton, '40m').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fakeRadio.vfoA.band, '40m');

    // A frequency names its own band, and the field has to follow it — which
    // it can't while the entries are narrowed to the band just picked.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '20m');

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(MenuItemButton, '80m').hitTestable(), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on a touch platform, where nothing else clears it, a mode pick still is not a filter', (tester) async {
    // The severe form: a dropdown field can't take focus on iOS/Android, so
    // neither the focus-gain clear nor the blur commit — the two paths that
    // paper over a stray filter on desktop — ever runs. A filter left by the
    // pick would pin the menu to that one entry for the rest of the session.
    fakeRadio.setVfo('vfoA', freq: 7200, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(MenuItemButton, 'CW').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7050');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT4');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a rig that moves the mode wins over half-typed text in the Mode field', (tester) async {
    // The trap: the operator starts typing a mode, the rig moves underneath
    // them, and the field keeps showing the keystrokes. `_mode` has already
    // followed the rig, so nothing on screen says the two disagree — and the
    // commit on the way out resolves 'F' to FT8 and pushes it, retuning a rig
    // that had just reported CW on the strength of a keystroke older than the
    // report.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    // Leaving the field must not resurrect the abandoned edit.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(fakeRadio.vfoA.mode, 'CW', reason: 'the rig keeps the mode it reported');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a spot arriving while the Mode field is being typed in replaces the half-typed text', (tester) async {
    // A spot tapped on another surface repopulates every field. The Mode
    // dropdown is the one field that could hold the operator's own unfinished
    // text at that moment, and it must not survive to commit over the mode
    // the spot brought.
    await tester.pumpWidget(host(enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'C');
    await tester.pump();

    await tester.pumpWidget(host(
      enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM'],
      suggestedQso: const {'their': {'call': 'W1AW'}, 'freq': 14074.0, 'mode': 'FT8'},
    ));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a rig restating the mode it is already on leaves the operator typing alone', (tester) async {
    // The other half of the contract, and the one a blunter fix breaks: a
    // connected radio notifies constantly. Only a mode that actually MOVED
    // may take the field back — a VFO update that changes nothing else must
    // not wipe a filter mid-word.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'F');
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);
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

  testWidgets('a suggestedQso carrying startAtMillis logs at that time, not at now', (tester) async {
    // A `/qso` deep link reports when a contact ACTUALLY happened — a WSJT-X
    // bridge hands over a QSO already made — so composing it at "now" files
    // it minutes late. The suggestion's time has to become the manual time,
    // exactly as if the operator had typed it.
    const madeAt = 1750000000000;
    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
      'startAtMillis': madeAt,
    }));
    await tester.pump();
    // The suggestion fills the field without focusing it, and Enter is
    // delivered to whatever has focus.
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.startAtMillis, madeAt);
  });

  testWidgets('a suggestedQso with no startAtMillis does not inherit the last one', (tester) async {
    // A spot says nothing about when a contact happens. Without the explicit
    // clear, a spot tapped after a deep link would log at the LINK's time.
    const madeAt = 1750000000000;
    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'W1AW'},
      'freq': 14074.0,
      'mode': 'FT8',
      'startAtMillis': madeAt,
    }));
    await tester.pump();
    await tester.pumpWidget(host(suggestedQso: {
      'their': {'call': 'K1ABC'},
      'freq': 14074.0,
      'mode': 'FT8',
    }));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirCall, 'K1ABC');
    expect(logged.single.startAtMillis, isNot(madeAt));
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

  group('Power control', () {
    // The whole feature's premise: power is optional, and the operator asks
    // for it. A control that shipped ON would put a watts field in front of
    // every operator who never logs power.
    testWidgets('is not in the row until the operator has asked for it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsNothing);
    });

    // The saved order is what records the operator's decision — the settings
    // dialog always writes every key it offered — so a control named there
    // and absent from the hidden set is one they kept.
    testWidgets('appears once the saved order names it', (tester) async {
      await tester.pumpWidget(host(controlOrder: const ['time', 'radio', 'power']));
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsOneWidget);
    });

    testWidgets('stays out when the operator turned it off', (tester) async {
      // Named in the order (so the decision was made) AND hidden — the
      // "decided against" state, which must not read as "never asked".
      await tester.pumpWidget(host(
        controlOrder: const ['time', 'radio', 'power'],
        hiddenControlKeys: const {'power'},
      ));
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsNothing);
    });

    testWidgets('a typed power reaches the VFO when the field loses focus', (tester) async {
      await tester.pumpWidget(host(controlOrder: const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      await tester.enterText(find.widgetWithText(TextField, 'Power'), '5');
      await tester.pump();
      expect(tunedRadio.vfoA.power, isNull, reason: 'mid-typing, "1" of "100" must not reach the radio');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(tunedRadio.vfoA.power, 5,
          reason: 'the VFO is the one home for power — CAT forwards it to the rig from there');
    });

    testWidgets('the field mirrors a power the VFO already carries', (tester) async {
      final radio = _FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      await tester.pumpWidget(host(radioService: radio, controlOrder: const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '100');
    });

    testWidgets('a logged QSO carries the power while the control is shown', (tester) async {
      await tester.pumpWidget(host(controlOrder: const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '5');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, 5,
          reason: 'showing the control is the operator asking for the power to be logged');
    });

    testWidgets('a QSO logged without the control carries no power', (tester) async {
      // The other half of the rule. Without it the stamp would be
      // unconditional, and every operator would silently start logging
      // whatever power the app last heard about.
      final radio = _FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      await tester.pumpWidget(host(radioService: radio));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, isNull);
    });

    testWidgets('the More pane offers a Power field, after Mode', (tester) async {
      await tester.pumpWidget(host(controlOrder: const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      final power = find.text('Power');
      expect(power, findsWidgets);
      // The pane stacks its fields, so "after Mode" is "lower than Mode" —
      // and above Date, which is what stops it landing at the end of the form
      // among the fields that describe something else.
      expect(tester.getTopLeft(power.last).dy, greaterThan(tester.getTopLeft(find.text('Mode').last).dy));
      expect(tester.getTopLeft(power.last).dy, lessThan(tester.getTopLeft(find.text('Date').last).dy));
    });

    testWidgets('the pane offers it while the app captures power, with the control out of the row', (tester) async {
      // Station Configuration's "Track Station Info" stamps the power on
      // every QSO. A value being logged that the entry cannot show is a value
      // nothing can correct.
      await tester.pumpWidget(host(trackingPower: true));
      await tester.pump();
      expect(find.byIcon(MdiIcons.flash), findsNothing, reason: 'tracking is not the control');

      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      expect(find.text('Power'), findsWidgets);
    });

    testWidgets('the pane offers it for a record that carries one, though nothing tracks power', (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(editingQso: existing));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      expect(find.text('Power'), findsWidgets);
    });

    testWidgets('the pane omits it when nothing tracks power and the QSO has none', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      expect(find.text('Power'), findsNothing);
    });

    testWidgets('a power typed into the pane reaches the logged QSO and the VFO', (tester) async {
      await tester.pumpWidget(host(controlOrder: const ['time', 'radio', 'power']));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '10');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tunedRadio.vfoA.power, 10, reason: 'a pane Save is a deliberate statement, like its frequency');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, 10);
    });

    testWidgets("a record's power survives a save that only corrected its RST", (tester) async {
      // The round-trip trap: with the control off, the field is the only
      // place the value lives while the record is open, so a gate that only
      // wrote power for a visible control would drop it here.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'sent': '55'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(editingQso: existing));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.receivedRST, '59', reason: 'the edit was saved at all');
      expect(logged.single.power, 5);
    });

    testWidgets('a power from an edited record does not leak onto the next QSO', (tester) async {
      // Nothing is tracking power here, so the field is never re-seeded — a
      // value left in it after the edit closes would go on stamping every
      // contact logged afterwards, frozen at whatever that one record said.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      final key = GlobalKey();
      Widget at({Qso? editing}) => KeyedSubtree(key: key, child: host(editingQso: editing));

      await tester.pumpWidget(at(editing: existing));
      await tester.pump();
      await tester.pumpWidget(at());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 2);
      expect(logged.firstWhere((q) => q.theirCall == 'K1ABC').power, isNull);
    });

    testWidgets('emptying the field clears a power off the record', (tester) async {
      // The map is merged over the stored QSO, so omitting the key when the
      // field is empty would leave the old value standing and a wrong power
      // could never be corrected — only overwritten.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 100,
      });
      await tester.pumpWidget(host(editingQso: existing));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // A second, visible edit, so the assertion below can't pass on a save
      // that never happened — an emptied field is not a value Enter can see.
      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.receivedRST, '59', reason: 'the edit was saved at all');
      expect(logged.single.power, isNull);
    });

    testWidgets('switching the control on fills the field from the VFO', (tester) async {
      // The field only follows the VFO while power is in play, so the build
      // that turns it on is the one chance to catch up — otherwise the chip
      // reads "—" and a QSO logged before the next VFO change carries none.
      final radio = _FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      final key = GlobalKey();
      Widget at(List<String> order) => KeyedSubtree(key: key, child: host(radioService: radio, controlOrder: order));

      await tester.pumpWidget(at(const []));
      await tester.pump();
      await tester.pumpWidget(at(const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '100');
    });

    testWidgets('is offered beside Radio, not last, to an operator with a saved order', (tester) async {
      // Every operator who has ever saved the settings dialog has a stored
      // order, and a key missing from it used to be appended — so the one
      // control that ships off would arrive at the very end of the row, past
      // More, however deliberately the descriptor list placed it. The dialog
      // is where it's first seen, and where saving records the placement.
      await tester.pumpWidget(host(controlOrder: const ['time', 'radio', 'more']));
      await tester.pump();
      await tester.tap(find.byIcon(MdiIcons.cog));
      await tester.pumpAndSettle();

      // Inside the dialog's list, where each row is a ListTile — the chip
      // strip behind it carries labels of its own.
      double rowY(String label) =>
          tester.getTopLeft(find.ancestor(of: find.text(label), matching: find.byType(ListTile)).first).dy;
      expect(rowY('Power'), greaterThan(rowY('Radio')));
      expect(rowY('Power'), lessThan(rowY('More')));
    });

    testWidgets("editing a QSO shows its own power, and does not retune the radio", (tester) async {
      final radio = _FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(
        radioService: radio,
        controlOrder: const ['time', 'radio', 'power'],
        editingQso: existing,
      ));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '5',
          reason: "a record's own power is what it was worked at, not what the rig is set to now");

      await tester.enterText(find.widgetWithText(TextField, 'Power'), '10');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(radio.vfoA.power, 100,
          reason: 'editing an existing QSO applies changes to the QSO, never the VFO');
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

    // A manual time that can never read as the wall clock: with a hard-coded
    // literal, `isNot(literal)` fails for the one minute a day when real UTC
    // happens to be exactly that, and enterText of the literal is a no-op
    // (no override fires) when the reseeded field already holds it.
    final manualDt = DateTime.now().toUtc().add(const Duration(hours: 6));
    final manualTime =
        '${manualDt.hour.toString().padLeft(2, '0')}:${manualDt.minute.toString().padLeft(2, '0')}';

    testWidgets('Time control sets a manual timestamp used at log time; Now resets it', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manualTime);
      await tester.enterText(find.widgetWithText(TextField, 'Date'), '2026-01-02');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(
        DateTime.fromMillisecondsSinceEpoch(logged.single.startAtMillis!, isUtc: true),
        DateTime.utc(2026, 1, 2, manualDt.hour, manualDt.minute),
      );

      // Wipe resets to automatic timestamping for the next QSO.
      await openControl(tester, MdiIcons.clockOutline);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot(manualTime));
    });

    testWidgets('Now button clears a manual time override', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manualTime);
      await tester.pump();
      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget); // chip still rendered

      await tester.tap(find.widgetWithText(TextButton, 'Now'));
      await tester.pump();

      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot(manualTime));
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

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manualTime);
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

    // A pill that looks exactly like every other one is how a contact gets
    // logged with no band at all. The error pair keeps the same
    // closed/open contrast the tertiary pair has, so the alert can't be
    // mistaken for the chip being expanded.
    testWidgets('the Radio chip fills with the error pair when there is no band', (tester) async {
      final untuned = _FakeVfoStore()..setVfo('vfoA', mode: 'SSB');
      final theme = buildHaLoTheme(Brightness.light);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: LoggingControls(radioService: untuned, operation: operation, qsosRepository: qsos),
        ),
      ));

      final chip = tester.widget<ChoiceChip>(find.ancestor(
        of: find.byIcon(MdiIcons.radio),
        matching: find.byType(ChoiceChip),
      ));
      expect(chip.backgroundColor, theme.colorScheme.errorContainer);
      expect(chip.selectedColor, theme.colorScheme.error);
    });

    testWidgets('a frequency outside every ham band alerts the Radio chip too', (tester) async {
      // Tuned, and to a real number — but 5000 kHz is WWV, not an amateur
      // allocation. A chip that only checks "is there a frequency" passes
      // this one straight through.
      expect(bandForFrequency(5000), isNull, reason: 'fixture assumes 5000 kHz is not a ham band');
      final offBand = _FakeVfoStore()..setVfo('vfoA', freq: 5000, mode: 'SSB');
      final theme = buildHaLoTheme(Brightness.light);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: LoggingControls(radioService: offBand, operation: operation, qsosRepository: qsos),
        ),
      ));

      final chip = tester.widget<ChoiceChip>(find.ancestor(
        of: find.byIcon(MdiIcons.radio),
        matching: find.byType(ChoiceChip),
      ));
      expect(chip.backgroundColor, theme.colorScheme.errorContainer);
    });

    testWidgets('a frequency the operator\'s own region does not allocate alerts and reads OOB', (tester) async {
      // 7250 kHz IS a band ('40m'), which is the whole trap: a check that
      // only asks "does this frequency name a band" waves through a Region
      // 1 operator transmitting where they legally cannot.
      expect(bandForFrequency(7250), '40m', reason: 'fixture assumes 7250 kHz names a band');
      final theme = buildHaLoTheme(Brightness.light);
      Widget panel(int ituRegion) => MaterialApp(
            theme: theme,
            home: Scaffold(
              body: LoggingControls(
                radioService: _FakeVfoStore()..setVfo('vfoA', freq: 7250, mode: 'SSB'),
                operation: operation,
                qsosRepository: qsos,
                ourItuRegion: ituRegion,
              ),
            ),
          );
      ChoiceChip radioChip() => tester.widget<ChoiceChip>(find.ancestor(
            of: find.byIcon(MdiIcons.radio),
            matching: find.byType(ChoiceChip),
          ));

      await tester.pumpWidget(panel(1));
      expect(radioChip().backgroundColor, theme.colorScheme.errorContainer);
      expect(find.text('${fmtFreq(7250)} • OOB'), findsOneWidget);

      // The same frequency for a Region 2 operator is an ordinary phone
      // QSO — the alert is about where the operator is, not the number.
      await tester.pumpWidget(panel(2));
      expect(radioChip().backgroundColor, HaLoColors.light.tertiaryLight);
      expect(find.text('${fmtFreq(7250)} • SSB'), findsOneWidget);
    });

    testWidgets('out of band shows in the pill only — never as the mode', (tester) async {
      // The pill's OOB is a warning, not a mode: it must not reach the Mode
      // field (which is what gets logged) nor the Mode menu's options.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: _FakeVfoStore()..setVfo('vfoA', freq: 14074, mode: 'SSB'),
            operation: operation,
            qsosRepository: qsos,
            ourItuRegion: 1,
          ),
        ),
      ));
      await openControl(tester, MdiIcons.radio);

      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7250');
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB',
          reason: 'the out-of-band marker is not a mode guess — the mode stays where it was');
      expect(find.text('${fmtFreq(7250)} • OOB'), findsOneWidget,
          reason: 'the warning lands on the keystroke — an out-of-band frequency guesses no mode, '
              'so nothing about the mode changes to trigger the rebuild that paints it');

      await tester.tap(find.widgetWithText(TextField, 'Mode'));
      await tester.pumpAndSettle();
      expect(find.text('OOB'), findsNothing, reason: 'the open Mode menu must not offer OOB as an option');
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

  group('editing an event/annotation row', () {
    IconButton secondButton(WidgetTester tester, IconData icon) => tester.widget<IconButton>(
          find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
        );

    testWidgets('a NOTE swaps the main fields for its label and text, and disables every pill but Time',
        (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );

      await tester.pumpWidget(host(editingQso: note));

      // No callsign field — this isn't a contact — and the kind is plain
      // text, not a field: only NOTE/TODO's actual value is editable.
      expect(find.widgetWithText(TextField, 'Their call'), findsNothing);
      expect(find.text('NOTE'), findsOneWidget);
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Note'));
      expect(noteField.controller!.text, 'check later');

      // Every pill still shows — Radio included — but only Time can be
      // opened; nothing else applies to a non-contact row.
      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.radio), findsOneWidget);
      ChoiceChip chipFor(IconData icon) => tester.widget<ChoiceChip>(
            find.ancestor(of: find.byIcon(icon), matching: find.byType(ChoiceChip)),
          );
      expect(chipFor(MdiIcons.clockOutline).onSelected, isNotNull);
      expect(chipFor(MdiIcons.radio).onSelected, isNull);
    });

    testWidgets('the Radio chip shows the current VFO, not the event\'s own sentinel freq/mode', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
      final marker = Qso(
        uuid: 'marker-uuid',
        operationUuid: operation.uuid,
        // freq: 0, mode: 'break' — meaningless for a Radio-control display,
        // unlike an ordinary QSO's own recorded freq/mode.
        data: {'band': 'event', 'freq': 0, 'mode': 'break', 'event': {'event': 'break'}},
      );

      await tester.pumpWidget(host(radioService: fakeRadio, editingQso: marker));

      expect(find.text('14,285 • CW'), findsOneWidget);

      // Keeps following, too — a rig retuned at its own front panel while
      // the event stays open should still show up here.
      fakeRadio.setVfo('vfoA', freq: 7100, mode: 'SSB');
      await tester.pump();
      expect(find.text('7,100 • SSB'), findsOneWidget);
    });

    testWidgets('a BREAK marker (no editable field) still fills the row to a text field\'s height', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      final marker = Qso(
        uuid: 'marker-uuid',
        operationUuid: operation.uuid,
        data: {'band': 'event', 'freq': 0, 'mode': 'break', 'event': {'event': 'break'}},
      );

      await tester.pumpWidget(host(editingQso: note));
      final noteButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      await tester.pumpWidget(host(editingQso: marker));
      await tester.pump();
      final markerButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      // A BREAK's row is just the kind label, plain text with nothing as
      // tall as a text field — the invisible InputDecorator floor
      // `_buildEventFields` wraps it in reserves that height anyway, or
      // IntrinsicHeight would shrink the submit button beside it.
      expect(markerButtonHeight, noteButtonHeight);
    });

    testWidgets('a SOLAR row (read-only description, no editable field) also matches that height', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      final solar = Qso(
        uuid: 'solar-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'solar',
          'our': {'call': 'EVENT'},
          'their': {'call': 'SOLAR'},
          'event': {'event': 'solar', 'description': 'SFI 120, A 5, K 2'},
        },
      );

      await tester.pumpWidget(host(editingQso: note));
      final noteButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      await tester.pumpWidget(host(editingQso: solar));
      await tester.pump();
      final solarButtonHeight = tester.getSize(find.byType(FilledButton)).height;

      // A real field's height comes from `poloFieldDecoration`'s own
      // explicit vertical content padding, which the app's ambient theme
      // never sets — a decorator that leaves contentPadding unset falls
      // back to the ambient default instead and drifts short.
      expect(solarButtonHeight, noteButtonHeight);
    });

    testWidgets('the pending-delete warning names the event kind, not "QSO"', (tester) async {
      final marker = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'band': 'event',
            'freq': 0,
            'mode': 'break',
            'event': {'event': 'break'},
          })))!;

      await tester.pumpWidget(host(editingQso: marker));
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();

      expect(find.textContaining('BREAK will be deleted'), findsOneWidget);
      expect(find.textContaining('QSO will be deleted'), findsNothing);
    });

    testWidgets('editing a NOTE and saving writes the new text back through the repository', (tester) async {
      final note = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'band': 'event',
            'freq': 0,
            'mode': 'note',
            'our': {'call': 'EVENT'},
            'their': {'call': 'NOTE'},
            'event': {'event': 'note', 'note': 'check later'},
          })))!;

      var canceled = false;
      await tester.pumpWidget(host(editingQso: note, onEditCanceled: () => canceled = true));

      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'call back tomorrow');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      for (var i = 0; i < 20 && !canceled; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(canceled, isTrue);
      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      expect(stored.event?['note'], 'call back tomorrow');
    });

    testWidgets("a TODO's checkbox and text both round-trip through save", (tester) async {
      final todo = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'band': 'event',
            'freq': 0,
            'mode': 'todo',
            'our': {'call': 'EVENT'},
            'their': {'call': 'TODO'},
            'event': {
              'event': 'todo',
              'note': 'check later',
              'data': {'done': false},
            },
          })))!;

      var canceled = false;
      await tester.pumpWidget(host(editingQso: todo, onEditCanceled: () => canceled = true));

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      for (var i = 0; i < 20 && !canceled; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      expect((stored.event?['data'] as Map?)?['done'], isTrue);
    });

    testWidgets('unchecking a legacy TODO (bare event.done, no event.data) actually sticks', (tester) async {
      final legacyTodo = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'band': 'event',
            'freq': 0,
            'mode': 'todo',
            'our': {'call': 'EVENT'},
            'their': {'call': 'TODO'},
            // Older synced logs store done as a bare field, not event.data.done
            // (see _applyEventFieldsFromData's fallback) — saving must clear
            // this one too, or the OR'd read-back keeps reviving `true`.
            'event': {'event': 'todo', 'note': 'check later', 'done': true},
          })))!;

      await tester.pumpWidget(host(editingQso: legacyTodo));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));

      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      expect((stored.event?['data'] as Map?)?['done'], isFalse);
      expect(stored.event?['done'], isNot(true));
    });

    testWidgets('editing a NOTE synced in under "description" (not "note") saves back to that key', (tester) async {
      final synced = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'band': 'event',
            'freq': 0,
            'mode': 'note',
            'our': {'call': 'EVENT'},
            'their': {'call': 'NOTE'},
            // AnnotationRow reads description before note (qso_list.dart)
            // — a row synced in under that key must keep agreeing with what
            // the log shows for it after an edit, not silently gain a
            // separate `note` nothing displays.
            'event': {'event': 'note', 'description': 'check later'},
          })))!;

      await tester.pumpWidget(host(editingQso: synced));
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Note'));
      expect(noteField.controller!.text, 'check later');

      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'call back tomorrow');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 100));

      final stored = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      expect(stored.event?['description'], 'call back tomorrow');
      expect(stored.event?['note'], isNull);
    });

    testWidgets('Enter from the QSO list focuses a NOTE\'s text field, not an unmounted callsign field',
        (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      final controller = LoggingControlsController();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            radioService: tunedRadio,
            operation: operation,
            qsosRepository: qsos,
            editingQso: note,
            controller: controller,
          ),
        ),
      ));
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Note'));

      // Simulates logging_panel.dart's own Enter handler, which hands the
      // keyboard back to the panel through this same imperative call
      // (`_loggingController.focusLastPrimaryField()`).
      controller.focusLastPrimaryField();
      await tester.pump();

      expect(noteField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('a NOTE synced in with incidental whitespace does not read as changed just from being selected',
        (tester) async {
      final untrimmed = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later '},
        },
      );

      await tester.pumpWidget(host(editingQso: untrimmed));

      // Nothing was typed — the second button must still read Delete, not
      // Revert (which comparing an untrimmed load against a trimmed save
      // candidate would wrongly report as "already changed").
      expect(find.byIcon(MdiIcons.trashCanOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.undo), findsNothing);
    });

    testWidgets("a TODO with a non-Map event.data degrades instead of crashing the panel", (tester) async {
      final malformed = Qso(
        uuid: 'todo-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'todo',
          'our': {'call': 'EVENT'},
          'their': {'call': 'TODO'},
          // A cross-client/malformed record: `data` isn't a Map.
          'event': {'event': 'todo', 'note': 'check later', 'data': 'oops'},
        },
      );

      await tester.pumpWidget(host(editingQso: malformed));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('an unmodified event offers Delete (not Revert); saving while pending soft-deletes it',
        (tester) async {
      final deleteIcon = MdiIcons.trashCanOutline;
      final undoIcon = MdiIcons.undo;
      final note = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'band': 'event',
            'freq': 0,
            'mode': 'note',
            'our': {'call': 'EVENT'},
            'their': {'call': 'NOTE'},
            'event': {'event': 'note', 'note': 'check later'},
          })))!;

      var deleted = false;
      await tester.pumpWidget(host(editingQso: note, onEditCanceled: () => deleted = true));

      // Nothing was touched, so the second button reads Delete, exactly as
      // it would for an unmodified QSO — not Revert, which comparing against
      // `_getCurrentQsoData()` (a QSO's own fields, all blank here) would
      // wrongly read as "always changed".
      expect(secondButton(tester, deleteIcon).onPressed, isNotNull);

      await tester.tap(find.byIcon(deleteIcon));
      await tester.pump();
      expect(find.byIcon(undoIcon), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      for (var i = 0; i < 20 && !deleted; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      final stored =
          (await tester.runAsync(() => qsos.watchForOperation(operation.uuid, includeDeleted: true).first))!.single;
      expect(stored.deleted, isTrue);
      expect(deleted, isTrue);
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

  // The write gate refuses at the repository, which tells the operator AFTER
  // they typed a contact that it did not land. Locking the form is what makes
  // it never typeable — the difference between a refusal and a lost contact.
  group('an unwritable operation locks the form', () {
    tearDown(AppClock.instance.reset);

    /// How many of the panel's entry fields accept input right now.
    ///
    /// Counted across every TextField rather than singling one out: "the
    /// fields are disabled" is the actual claim, and an assertion on one
    /// field would pass while the rest of the row stayed typeable.
    int enabledFields(WidgetTester tester) =>
        tester.widgetList<TextField>(find.byType(TextField)).where((f) => f.enabled ?? true).length;

    testWidgets('every entry field is disabled while the clock is travelled', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(enabledFields(tester), greaterThan(0),
          reason: 'sanity: a real operation is writable on a real clock');

      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();

      expect(enabledFields(tester), 0);
    });

    testWidgets('the panel says why, in the operator\'s words', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();

      expect(find.textContaining('only test operations and contacts can be changed'), findsOneWidget);
    });

    testWidgets('it unlocks again when the clock comes back', (tester) async {
      // The half a listener-less implementation gets wrong: locking on travel
      // is easy to notice, staying locked afterwards is not.
      await tester.pumpWidget(host());
      await tester.pump();
      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();
      expect(enabledFields(tester), 0);

      AppClock.instance.reset();
      await tester.pump();

      expect(enabledFields(tester), greaterThan(0));
    });

    testWidgets('a TEST operation stays typeable while travelled', (tester) async {
      // The gate is about which records may be written, not about travel
      // itself — a panel that locked regardless would make the feature
      // useless for the one thing it exists to allow.
      await operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'stationCall': 'KI2D/T'}));
      operation = (await operations.get(operation.uuid))!;

      await tester.pumpWidget(host());
      await tester.pump();
      AppClock.instance.travel(delta: const Duration(days: 3));
      await tester.pump();

      expect(enabledFields(tester), greaterThan(0));
    });
  });

  // A spot row slid open far enough to peek fills these fields, and the fill
  // is the OPEN ROW's: it goes back out when the row closes, and it is never
  // the "work in progress" that the next suggestion — or the log request that
  // ends the very same slide — has to ask the operator about.
  group('a tentative suggestion from a slid spot row', () {
    const spotA = {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'};
    const spotB = {'their': {'call': 'W2DEF'}, 'band': '20m', 'mode': 'SSB'};

    String callIn(WidgetTester tester) =>
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call').first).controller?.text ?? '';

    testWidgets('fills the fields, and withdrawing it empties them again', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true));
      await tester.pump();
      expect(callIn(tester), 'K1ABC');

      // The row closed — dragged back, scrolled away, set aside. The operator
      // is visibly done with that spot, and a call left behind here is what
      // the next Log would go out as.
      await tester.pumpWidget(host());
      await tester.pump();

      expect(callIn(tester), isEmpty);
    });

    testWidgets('the next spot replaces the last one without asking', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true));
      await tester.pump();
      // Sliding the next row: its withdrawal and its suggestion land in the
      // same widget update, so the panel never sees the fields empty. The
      // mutation this catches is counting the last peek's own fill as work —
      // which makes every spot after the first raise a prompt.
      await tester.pumpWidget(host(
        suggestedQso: spotB,
        suggestedQsoIsTentative: true,
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return false;
        },
      ));
      await tester.pump();

      expect(callIn(tester), 'W2DEF');
      expect(asked, 0, reason: 'the call it replaced was the previous peek\'s, not the operator\'s');
    });

    testWidgets('the operator working the call field says so; a suggestion filling it does not',
        (tester) async {
      // What the spots list closes an open row on. A suggestion arriving must
      // never look like this, or filling the fields would close the very row
      // that filled them — and take its own fill back out on the way.
      var edited = 0;

      await tester.pumpWidget(host(onCallEdited: () => edited++));
      await tester.pump();
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        onCallEdited: () => edited++,
      ));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'K1ABC');
      expect(edited, 0, reason: 'a spot arriving is not the operator composing anything');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();
      expect(edited, greaterThan(0), reason: 'typing is');

      // And the wipe button, which is the other way the operator empties it.
      final before = edited;
      await tester.pumpWidget(host(suggestedQso: spotA, onCallEdited: () => edited++));
      await tester.pumpAndSettle();
      expect(edited, before, reason: 'the suggestion that replaced it is still not an edit');
    });

    testWidgets('a call a TAP chose does not block the next slide either', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      // A tap: a station chosen outright, not a peek. The operator picked it,
      // but they did not COMPOSE an entry — so the next spot replaces it the
      // same way, without a prompt standing between the slide and the fields.
      await tester.pumpWidget(host(suggestedQso: spotA));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'K1ABC');

      await tester.pumpWidget(host(
        suggestedQso: spotB,
        suggestedQsoIsTentative: true,
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return false;
        },
      ));
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W2DEF');
      expect(asked, 0);
    });

    testWidgets('a callsign the field rewrites under the panel is still the suggestion\'s', (tester) async {
      // The call field's listener fires for programmatic writes exactly as it
      // does for typing, so "the operator has taken this over" cannot be
      // decided there. Whatever kicks the field — a command expansion, a pane
      // save, a formatter on a slashed call — the text is what says whose the
      // entry is. The mutation this catches is going back to a listener flag:
      // one spurious fire and every slide after it is refused in silence.
      var asked = 0;
      const slashed = {'their': {'call': 'EA3/KI2D'}, 'band': '20m', 'mode': 'SSB'};

      await tester.pumpWidget(host(suggestedQso: slashed, suggestedQsoIsTentative: true));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'EA3/KI2D');

      // Rewritten to the very same text, which is what a formatter or an
      // expansion that changes nothing does — and which fires the listener.
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Their call').first)
          .controller!
          .value = const TextEditingValue(
        text: 'EA3/KI2D',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(
        suggestedQso: spotB,
        suggestedQsoIsTentative: true,
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return false;
        },
      ));
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W2DEF', reason: 'the slide still hands the fields to the new spot');
      expect(asked, 0);
    });

    testWidgets('typing over the fill makes it the operator\'s, and it survives the row closing',
        (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC/P');
      await tester.pump();

      await tester.pumpWidget(host());
      await tester.pump();

      expect(callIn(tester), 'K1ABC/P', reason: 'a station the operator has worked on is theirs, not the row\'s');
    });

    testWidgets('is held over a part-typed call, and put to the operator when the gesture settles',
        (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return false;
        },
      ));
      await tester.pump();

      // Mid-drag. A dialog here takes the pointer while the drag runs on
      // underneath it, and the release still commits.
      expect(asked, 0, reason: 'the finger is still on the row');
      expect(callIn(tester), 'W9XYZ', reason: 'and the fields are still the operator\'s');

      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return false;
        },
      ));
      await tester.pumpAndSettle();

      expect(asked, 1, reason: 'the row came to rest, so the conflict can be put to them');
      expect(callIn(tester), 'W9XYZ', reason: 'they said go back — their entry stands');
    });

    testWidgets('the prompt is a real route, raised in a frame that can take one', (tester) async {
      // The harness callbacks elsewhere in this group return a Future without
      // ever pushing anything, which is precisely what let a Navigator assert
      // ("!navigator._debugLocked") reach the operator instead of a test: the
      // ask is made from didUpdateWidget, and a route pushed while the
      // framework is mid-flush trips over itself when its push animation
      // lands. Only a callback that pushes a real dialog exercises that.
      Future<bool> ask({required bool editing}) async {
        final context = tester.element(find.byType(LoggingControls));
        final answer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('Clear it?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Go back')),
            ],
          ),
        );
        return answer ?? false;
      }

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true, confirmLogOverwrite: ask));
      await tester.pump();
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        confirmLogOverwrite: ask,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'the dialog went up without the Navigator objecting');
      expect(find.text('Clear it?'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
    });

    testWidgets('clearing the way at the prompt hands the fields to the spot', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true));
      await tester.pump();
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        confirmLogOverwrite: ({required bool editing}) async => true,
      ));
      await tester.pumpAndSettle();

      expect(callIn(tester), 'K1ABC');
    });

    testWidgets('a peek held on the way in does not outlive the commit that follows it', (tester) async {
      // The whole slide is one gesture: the peek asks to take the fields, the
      // commit asks to log over them. Held past the commit, the peek's
      // question survives the log — and the next row the operator slides is
      // the one that pays. Its own peek fills the fields, then ITS settle
      // fires the stale question, which by then has nothing left to ask about
      // and so goes straight through: the station they just slid to is
      // replaced by the one they finished with, and the VFO follows it.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      // Slide row A: peek (held, a call is in progress)...
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        confirmLogOverwrite: ({required bool editing}) async => true,
      ));
      await tester.pump();
      // ...then the same drag carried through to the commit, which arrives
      // with a fresh suggestion of its own alongside the request.
      await tester.pumpWidget(host(
        suggestedQso: Map<String, dynamic>.from(spotA),
        suggestedQsoIsTentative: true,
        logRequest: (serial: 1, qso: spotA),
        confirmLogOverwrite: ({required bool editing}) async => true,
      ));
      await waitForQsos(tester, 1);

      // Slide row B: its peek lands in an empty panel, so it simply applies.
      await tester.pumpWidget(host(suggestedQso: spotB, suggestedQsoIsTentative: true));
      await tester.pumpAndSettle();
      expect(callIn(tester), 'W2DEF');

      // B's row comes to rest.
      await tester.pumpWidget(host(
        suggestedQso: spotB,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
      ));
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W2DEF', reason: 'the spent peek did not reach back in and replace it');
    });

    testWidgets('a held suggestion the row took back while the dialog was up is dropped', (tester) async {
      // The prompt is a wait, and the row that raised it can close or be
      // discarded while it is up — which takes the suggestion back. Applying
      // it on the way out fills the fields and retunes the radio for a row
      // that is gone, and the withdrawal that would have undone it has
      // already happened: nothing is left that can take it back.
      final completer = Completer<bool>();

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        confirmLogOverwrite: ({required bool editing}) => completer.future,
      ));
      await tester.pump();
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        confirmLogOverwrite: ({required bool editing}) => completer.future,
      ));
      await tester.pump();
      await tester.pump();

      // The row goes away while the operator is still looking at the dialog.
      await tester.pumpWidget(host(confirmLogOverwrite: ({required bool editing}) => completer.future));
      await tester.pump();

      // ...and only then do they answer it.
      completer.complete(true);
      await tester.pumpAndSettle();

      expect(callIn(tester), 'W1AW', reason: 'their own entry stands; the withdrawn spot never lands');
    });

    testWidgets('a suggestion parked behind an edit lands the moment the edit is cancelled', (tester) async {
      // Parked work drains from the branch that CLEARS the edit, not merely
      // from the bottom of didUpdateWidget — that branch returns before ever
      // reaching it. Draining only at the bottom leaves the suggestion sitting
      // there until some unrelated rebuild (a spot poll, a clock tick) happens
      // along, by which time it lands on top of whatever has been typed since,
      // and moves the VFO with it.
      final edited = Qso(uuid: 'q1', operationUuid: operation.uuid, data: const {'their': {'call': 'W1AW'}});
      var cancels = 0;

      await tester.pumpWidget(host(editingQso: edited));
      await tester.pump();
      await tester.pumpWidget(host(
        editingQso: edited,
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        onEditCanceled: () => cancels++,
        confirmLogOverwrite: ({required bool editing}) async => true,
      ));
      await tester.pumpAndSettle();
      expect(cancels, 1, reason: 'the operator cleared the way');

      // The edit going away IS the update that must apply it. Nothing else is
      // pumped here — no poll, no later rebuild to be rescued by.
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        onEditCanceled: () => cancels++,
        confirmLogOverwrite: ({required bool editing}) async => true,
      ));
      await tester.pump();

      expect(callIn(tester), 'K1ABC');
    });

    testWidgets('a held suggestion whose conflict is gone is applied, not put to the operator',
        (tester) async {
      // Held over a part-typed call; by the time the gesture settles the
      // operator has cleared it themselves. Asking anyway offers to overwrite
      // an empty panel, which teaches them the prompt means nothing.
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
      await tester.pump();

      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        suggestionSettledSerial: 1,
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return true;
        },
      ));
      await tester.pumpAndSettle();

      expect(asked, 0);
      expect(callIn(tester), 'K1ABC', reason: 'the spot takes the fields it no longer has to fight for');
    });

    testWidgets('the commit that ends the same slide does not ask about the peek\'s own fill',
        (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(suggestedQso: spotA, suggestedQsoIsTentative: true));
      await tester.pump();
      expect(callIn(tester), 'K1ABC');

      // Dragging on past the commit point: the panel is holding this very
      // spot's callsign, put there by this very gesture. Treating that as work
      // at risk puts a prompt in front of every slide-to-log there is.
      await tester.pumpWidget(host(
        suggestedQso: spotA,
        suggestedQsoIsTentative: true,
        logRequest: (serial: 1, qso: spotA),
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return false;
        },
      ));

      final logged = await waitForQsos(tester, 1);

      expect(asked, 0);
      expect(logged.single.data['their']['call'], 'K1ABC');
    });
  });

  // The slid-right spot action reaches this panel as `logRequest`. Its whole
  // promise is that a contact ends up in the log, made from a surface the
  // operator is NOT looking at — so every way it can quietly not happen is a
  // contact they believe they made and did not.
  group('a log request from the spots list', () {
    testWidgets('is not swallowed while a QSO is being edited', (tester) async {
      // The regression: `didUpdateWidget` returns early whenever `editingQso`
      // is set — an ordinary two-pane state with the spots list still on
      // screen — so the request was consumed and never retried. The gesture
      // had already fired its heavy haptic and closed the row.
      var asked = 0;
      bool? askedAboutEditing;
      final edited = Qso(uuid: 'q1', operationUuid: operation.uuid, data: const {'their': {'call': 'W1AW'}});

      await tester.pumpWidget(host(editingQso: edited));
      await tester.pump();
      await tester.pumpWidget(host(
        editingQso: edited,
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          askedAboutEditing = editing;
          return false;
        },
      ));
      await tester.pump();

      expect(asked, 1, reason: 'the request reached the panel instead of being dropped');
      expect(askedAboutEditing, isTrue, reason: 'and it knows an edit is what is at risk');
    });

    testWidgets('asks before overwriting a part-typed entry', (tester) async {
      var asked = 0;
      bool? askedAboutEditing;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(host(
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          askedAboutEditing = editing;
          return false;
        },
      ));
      await tester.pump();

      expect(asked, 1, reason: 'a half-typed contact is work too, and it is about to be wiped');
      expect(askedAboutEditing, isFalse, reason: 'nothing is being edited — this is a fresh entry');
    });

    testWidgets('a part-typed entry with no callsign is scaffolding, not work', (tester) async {
      // A grid, a frequency or a reference with no station attached is what
      // the operator left lying around, not a contact in progress — prompting
      // over it teaches them to dismiss the prompt. The mutation this catches
      // is widening the guard back to every composed field.
      var asked = 0;

      await tester.pumpWidget(host(showGridField: true));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'FN31pr');
      await tester.pump();

      await tester.pumpWidget(host(
        showGridField: true,
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return true;
        },
      ));

      final logged = await waitForQsos(tester, 1);

      expect(asked, 0, reason: 'no station was being composed, so there was nothing to ask about');
      expect(logged.single.data['their']['call'], 'K1ABC');
      expect(
        (logged.single.data['their'] as Map)['grid'],
        anyOf(isNull, ''),
        reason: 'the stray grid belonged to nobody — the spot replaces it rather than inheriting it',
      );
    });

    testWidgets('the prompt is a real route here too', (tester) async {
      // Same failure class as the peek's prompt: this ask is also made from
      // didUpdateWidget, so it also has to leave the frame before pushing.
      Future<bool> ask({required bool editing}) async {
        final context = tester.element(find.byType(LoggingControls));
        final answer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('Clear it?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Go back')),
            ],
          ),
        );
        return answer ?? false;
      }

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W9XYZ');
      await tester.pump();

      await tester.pumpWidget(host(
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
        confirmLogOverwrite: ask,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Clear it?'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
    });

    testWidgets('leaves the focus alone, so a phone does not raise its keyboard', (tester) async {
      // The wipe that follows a log focuses the call field — right when the
      // operator is typing here, wrong when the contact was logged by a
      // gesture made on another surface. On a phone that focus is a keyboard,
      // thrown up over the spots list they are still working.
      final field = find.widgetWithText(TextField, 'Their call').first;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
      ));
      await waitForQsos(tester, 1);
      await tester.pump();

      expect(tester.widget<TextField>(field).controller?.text, isEmpty, reason: 'logged and wiped');
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);
    });

    testWidgets('nor after clearing the way at the prompt, nor when it cannot log at all', (tester) async {
      // The other two ways this route ends. Both reach for the call field to
      // say something to an operator who is not standing in front of it.
      final field = find.widgetWithText(TextField, 'Their call').first;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(field, 'W9XYZ');
      await tester.pump();
      // Typing leaves the field focused; the operator then went to the spots
      // list, which is where the gesture below is made from. Without this the
      // test would be asserting about focus that was already theirs.
      tester.widget<TextField>(field).focusNode?.unfocus();
      await tester.pump();

      // Clear-and-log: the wipe that makes room for the spot.
      await tester.pumpWidget(host(
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
        confirmLogOverwrite: ({required bool editing}) async => true,
      ));
      await waitForQsos(tester, 1);
      await tester.pump();

      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse, reason: 'cleared and logged');

      // A spot carrying nothing loggable: `_log` bails, pointing at the field
      // that would have to be fixed — which on a phone is a keyboard over the
      // list, for a station the operator can do nothing about from there.
      await tester.pumpWidget(host(
        logRequest: (serial: 2, qso: const {'their': {'call': ''}, 'band': '20m', 'mode': 'SSB'}),
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse, reason: 'nothing to log, nothing to say here');
    });

    testWidgets('logs straight away when there is nothing to lose', (tester) async {
      var asked = 0;

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pumpWidget(host(
        logRequest: (serial: 1, qso: const {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB'}),
        confirmLogOverwrite: ({required bool editing}) async {
          asked++;
          return true;
        },
      ));

      final logged = await waitForQsos(tester, 1);

      expect(asked, 0, reason: 'an empty panel has nothing worth interrupting the operator over');
      expect(logged.single.data['their']['call'], 'K1ABC');
    });

  });

  group('the row a peer sees', () {
    // The producing half of HALO-395, against the real controls rather than a
    // hand-built payload: what a peer renders is only as honest as what this
    // publishes.

    testWidgets('a report the operator never touched travels as a hint, not a value', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(host(onPeerDraftChanged: (_, fields) => rows.add(fields)));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();

      final row = rows.last;
      final sent = row.firstWhere((f) => f.key == 'sent');
      // The trap: the DRAFT carries '59' here either way, because
      // `_rstOrDefault` folds the placeholder in. Only the empty value beside
      // a populated hint says the operator did not answer it.
      expect(sent.value, isEmpty);
      expect(sent.hint, isNotEmpty);
      expect(row.firstWhere((f) => f.key == 'call').value, 'KN2X');
    });

    testWidgets('a report typed over its own placeholder becomes the operator\'s answer', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(host(onPeerDraftChanged: (_, fields) => rows.add(fields)));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();
      final before = rows.last.firstWhere((f) => f.key == 'sent');

      // Typing exactly what the placeholder already showed. Nothing in the
      // draft moves; this must still be reported, or the panel can never show
      // a deliberate report as deliberate.
      await tester.enterText(find.byType(TextField).at(1), before.hint!);
      await tester.pump();

      expect(rows.last.firstWhere((f) => f.key == 'sent').value, before.hint);
    });

    testWidgets('the row is the operator\'s own order, so switchSentRcvd travels', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(host(switchSentRcvd: true, onPeerDraftChanged: (_, fields) => rows.add(fields)));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();

      expect(rows.last.map((f) => f.key).take(3), ['call', 'rcvd', 'sent']);
    });

    testWidgets('a field the operator switched on joins the row', (tester) async {
      final rows = <List<PeerDraftField>>[];
      await tester.pumpWidget(
          host(showStateField: true, onPeerDraftChanged: (_, fields) => rows.add(fields)));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();

      expect(rows.last.map((f) => f.key), contains('state'));
    });

    testWidgets('a host with nothing to tell is never asked', (tester) async {
      // The null gate is what keeps the whole path off the keystroke route.
      var built = 0;
      await tester.pumpWidget(host(onQsoChanged: (_) => built++));
      await tester.enterText(find.byType(TextField).first, 'KN2X');
      await tester.pump();
      expect(built, greaterThan(0), reason: 'the draft path itself still works');
    });
  });
}

/// In-memory stand-in for the app's `RadioService` (which lives outside
/// this package, in the Flutter app rather than halo_widgets) — just
/// enough of `VfoStore` to verify LoggingControls seeds from and writes
/// back to it, without a real SharedPreferences-backed store.
/// [add] starts throwing after [addsBeforeFailure] successful inserts — the
/// disk-full / closed-database stand-in for the write-failure tests.
class _FailingQsosRepository extends QsosRepository {
  _FailingQsosRepository(super.db, {this.addsBeforeFailure = 0});
  final int addsBeforeFailure;
  int _adds = 0;

  @override
  Future<Qso> add(
    String operationUuid,
    Map<String, dynamic> qsoData, {
    List<SequenceDescriptor> serialSequences = const [],
  }) {
    if (_adds >= addsBeforeFailure) throw StateError('disk full');
    _adds++;
    return super.add(operationUuid, qsoData, serialSequences: serialSequences);
  }
}

class _FakeVfoStore extends ChangeNotifier implements VfoStore {
  Vfo _vfoA = const Vfo();

  @override
  Vfo get vfoA => _vfoA;

  @override
  void setVfo(String key,
      {double? freq,
      String? band,
      String? mode,
      num? power,
      bool clearFreq = false,
      bool clearPower = false}) {
    if (key != 'vfoA') return;
    final newPower = clearPower ? null : (power ?? _vfoA.power);
    if (freq != null) {
      _vfoA = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? _vfoA.mode, power: newPower);
    } else if (band != null || clearFreq) {
      _vfoA = Vfo(freq: null, band: band ?? _vfoA.band, mode: mode ?? _vfoA.mode, power: newPower);
    } else {
      _vfoA = Vfo(freq: _vfoA.freq, band: _vfoA.band, mode: mode ?? _vfoA.mode, power: newPower);
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

/// A number source that answers from the sequence and records what the panel
/// asked of it — the seam the peer claims plug into in the app.
class _RecordingSerialSource implements SerialNumberSource {
  _RecordingSerialSource(this.sequences, {this.conflicted = const {}, this.gate});

  final SequencesRepository sequences;
  final Set<int> conflicted;

  /// When set, a claim does not resolve until this completes — the peers'
  /// acks still in flight.
  final Completer<void>? gate;
  int claims = 0;
  int releases = 0;
  Map<SequenceRequest, int> committed = const {};

  @override
  Future<int> claim(String operationUuid, SequenceRequest request) async {
    claims++;
    if (gate case final gate?) await gate.future;
    return sequences.peek(operationUuid, request);
  }

  @override
  void release(String operationUuid, {Map<SequenceRequest, int> committed = const {}, Set<String>? labels}) {
    releases++;
    if (committed.isNotEmpty) this.committed = committed;
  }

  @override
  bool isConflicted(String operationUuid, SequenceRequest request, int number) => conflicted.contains(number);
}
