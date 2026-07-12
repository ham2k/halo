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
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          qsos: existing,
          interpretCommand: interpretCommand,
          onCommandMessageChanged: onCommandMessageChanged,
          onCommandAction: onCommandAction,
          radioService: radioService,
          editingQso: editingQso,
        ),
      ),
    );
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

  testWidgets('Escape wipes the entry', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    final callField = tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
    expect(callField.controller!.text, isEmpty);
    expect(await waitForQsos(tester, 1), isEmpty);
  });

  testWidgets('debounced lookup enriches the entry line and the logged QSO', (tester) async {
    var lookups = 0;
    Future<Map<String, dynamic>?> lookup(String call) async {
      lookups++;
      if (call != 'W1AW') return null;
      return {'name': 'ARRL HQ', 'city': 'Newington', 'state': 'CT', 'grid': 'FN31pr'};
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(operation: operation, qsosRepository: qsos, lookup: lookup),
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
    expect(lookups, 1);
    expect(find.textContaining('ARRL HQ'), findsOneWidget);
    expect(find.textContaining('Newington, CT'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.theirName, 'ARRL HQ');
    expect(logged.single.data['their']['grid'], 'FN31pr');

    // Wipe cleared the enrichment line.
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'US-1234'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.refs, [
      {'type': 'pota', 'ref': 'US-1234'},
    ]);

    // Wipe cleared the control's chips too.
    expect(find.byType(InputChip), findsNothing);
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

  testWidgets('call-field command awaiting params (expectsParams) allows space and lowercase, and Enter does not execute it', (tester) async {
    Future<Map<String, dynamic>?> fakeReloadPrefix(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
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

    // Lowercase text is preserved — no forced uppercasing while expectsParams.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD pota');
    await tester.pump();
    expect(field('Their call').controller!.text, 'RELOAD pota');

    // Enter doesn't execute or clear an incomplete command.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(field('Their call').controller!.text, 'RELOAD pota');
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
    ]) async {
      seenInputs.add(input);
      if (input.trim().toUpperCase() == 'NOTE') return {'expectsParams': true};
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
    // (setVfo/updateQso/addQso/updateSettings/syncAll/devNotice/devStatus/
    // devProgress/reloadDataFiles) — adding a new CommandAction field to the
    // SDK types without also adding its case here means the command
    // interprets fine but silently no-ops on execution, exactly what
    // happened when reloadDataFiles first shipped without this wiring.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeReloadCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
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

  testWidgets('shows DUPE chip for same call, band and mode', (tester) async {
    final dupe = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(existing: [dupe]));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    expect(find.text('DUPE'), findsOneWidget);
  });

  testWidgets('editing an existing QSO does not flag it as its own duplicate', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          operation: operation,
          qsosRepository: qsos,
          qsos: [existingQso],
          editingQso: existingQso,
        ),
      ),
    ));

    expect(find.text('DUPE'), findsNothing);
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
  void setVfo(String key, {double? freq, String? band, String? mode}) {
    if (key != 'vfoA') return;
    if (freq != null) {
      _vfoA = Vfo(freq: freq, band: bandForFrequency(freq), mode: mode ?? _vfoA.mode);
    } else if (band != null) {
      _vfoA = Vfo(freq: null, band: band, mode: mode ?? _vfoA.mode);
    } else {
      _vfoA = Vfo(freq: _vfoA.freq, band: _vfoA.band, mode: mode ?? _vfoA.mode);
    }
  }
}
