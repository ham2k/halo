// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// APP-19's focus ladder, at the end only this panel can wire up:
//
//     QSO list  ──▲──  secondary pills  ──▲──  main logging fields
//               ──▼──                   ──▼──
//
// LoggingControls owns the pills and the fields (and tests them in
// halo_widgets); the list is a sibling widget whose selection this panel
// owns, so walking it is only ever exercised here. The point is that an
// operator can review and re-open earlier contacts without reaching for the
// mouse — and that walking the log never takes the keyboard out of the field
// it started in: each row loads into the editor with the keyboard still
// there, ready to type a correction, and the next arrow keeps walking.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show hardwareKeyboardAttached;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;
  late Qso older;
  late Qso newer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    // Same inert lookup queue the Escape tests use — the real one waits (in
    // real time) on an extension runtime that never starts here, leaving a
    // timer pending past teardown.
    services = HaLoServices(
      db,
      settings,
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, required online, recentContext = false}) async => null,
        qsos: QsosRepository(db),
        operations: OperationsRepository(db),
        statusBar: StatusBarService(settings.prefs),
        runtimeWaitBudget: Duration.zero,
      ),
    );
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    older = await services.qsos.add(operation.uuid, {
      'their': {'call': 'W1AW', 'sent': '59'},
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    newer = await services.qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC', 'sent': '55'},
      'mode': 'SSB',
      'startAtMillis': 2000,
    });
  });

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  Future<void> pumpPanel(
    WidgetTester tester,
    List<Qso> qsos, {
    ValueChanged<String?>? onSelectionChanged,
    bool controlsAboveLog = false,
    int focusRequest = 0,
  }) async {
    await tester.pumpWidget(
      wrap(
        LoggingPanel(
          operation: operation,
          services: services,
          qsos: qsos,
          loggingControls: const [],
          onCommandAction: (action, [params]) async {},
          onSelectionChanged: onSelectionChanged,
          controlsAboveLog: controlsAboveLog,
          focusRequest: focusRequest,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  TextField callField(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));

  /// The callsign the compose form is currently loaded with — which is how a
  /// selection shows up from the outside: arrowing onto a row populates the
  /// editor with it.
  String loadedCall(WidgetTester tester) => callField(tester).controller?.text ?? '';

  /// Which pill holds the keyboard, by control key (`pill:<key>` debug
  /// labels, set by `LoggingFocusLadder.pillFocusFor`), or null for none.
  String? focusedPill(WidgetTester tester) {
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      final node = chip.focusNode;
      if (node != null && node.hasFocus) return node.debugLabel?.replaceFirst('pill:', '');
    }
    return null;
  }

  /// Two Arrow Ups from the call field: out of the fields onto the pills, then
  /// off the pills into the list, which hands the keyboard back to the call
  /// field after a frame — the way in for every test below.
  Future<void> enterList(WidgetTester tester, {String field = 'Their call'}) async {
    await tester.tap(find.widgetWithText(TextField, field));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
  }

  Future<void> withModifier(WidgetTester tester, LogicalKeyboardKey modifier, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  testWidgets('Arrow Up from the pills loads the newest QSO with the keyboard back in the call field', (tester) async {
    await pumpPanel(tester, [older, newer]);
    expect(loadedCall(tester), isEmpty);

    await enterList(tester);

    expect(loadedCall(tester), 'K1ABC');
    // The keyboard is where the walk started, ready to type a correction to
    // the call it is looking at — not parked in the list, or on a pill.
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    expect(focusedPill(tester), isNull);
    await drainLookupQueueTimer(tester);
  });

  // The Map pane frames the QSO picked, and hears about it only through this:
  // a pick the host misses leaves the map on the last one.
  testWidgets('every change of pick reaches the host, putting it down included', (tester) async {
    final picks = <String?>[];
    await pumpPanel(tester, [older, newer], onSelectionChanged: picks.add);
    await enterList(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(picks, [newer.uuid, older.uuid, newer.uuid, null]);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Up and Down walk the log from the call field; Down past the newest row is back to composing, still in the call field', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    expect(callField(tester).focusNode?.hasFocus, isTrue);

    // The oldest row is the end of the road — Up again stays put rather than
    // silently wrapping round to the newest, or climbing to the pills.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    expect(callField(tester).focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');

    // Off the newest row the walk ends where it began: composing a new QSO,
    // typing in the call field.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    expect(focusedPill(tester), isNull);
    await drainLookupQueueTimer(tester);
  });

  // Above its list the panel is the other way up, and the list runs newest
  // first under it: every key that walks the log has to follow the screen,
  // or Down from the pills would load the OLDEST contact and Up would walk
  // the wrong way through rows the operator can see.
  testWidgets('with the controls above the log, the keys follow the screen: Down walks into the list and toward older contacts', (tester) async {
    await pumpPanel(tester, [older, newer], controlsAboveLog: true);
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC', reason: 'into the list at its top: the newest contact');
    expect(callField(tester).focusNode?.hasFocus, isTrue, reason: 'the keyboard is back in the call field');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW', reason: 'down the screen is back in time');

    await withModifier(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowUp);
    expect(loadedCall(tester), 'K1ABC', reason: 'the top of the list is the newest');
    await withModifier(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowDown);
    expect(loadedCall(tester), 'W1AW');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), isEmpty, reason: 'Up past the newest is back to composing');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await drainLookupQueueTimer(tester);
  });

  // A host that hides the panel and shows it again — the Chasing view,
  // kept mounted behind another destination — gets nothing back from the
  // call field's autofocus, which only ever fires once.
  testWidgets('a new focus request puts the keyboard back in the main field it was last in', (tester) async {
    // A keyboard attached: the test platform is a phone, where without one
    // the request is refused (below).
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await pumpPanel(tester, [older, newer]);
    await tester.tap(find.widgetWithText(TextField, 'Sent'));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isFalse);

    await pumpPanel(tester, [older, newer], focusRequest: 1);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus,
      isTrue,
      reason: 'the field the operator left, not always Call',
    );
    await drainLookupQueueTimer(tester);
  });

  // logging-fields.md: on a phone with no physical keyboard the view starts
  // with nothing focused. A return to the view that focused a field anyway
  // would raise the on-screen keyboard over it on every visit.
  testWidgets('on a phone with no physical keyboard a focus request leaves the keyboard down', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await tester.tap(find.widgetWithText(TextField, 'Sent'));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await pumpPanel(tester, [older, newer], focusRequest: 1);
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isFalse);
    expect(callField(tester).focusNode?.hasFocus, isFalse);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('a second Down past the newest does not walk back in', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    // Back-to-back, as key-repeat can deliver them faster than a frame. The
    // first ends the walk; with nothing loaded the second is the call
    // field's own, and must not start the walk over at the newest row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Down past the newest row restores the callsign typed before arrowing up, not a blank form', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N0DRAFT');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(loadedCall(tester), 'N0DRAFT', reason: 'the draft the operator was composing must come back, not a blank form');
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Shift and Ctrl leave the walk alone', (tester) async {
    // Shift+arrow selects text in the field the walk runs from, and Ctrl
    // belongs to the platform — both pass straight through. (Cmd and Option
    // DO mean something here; see below.)
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    for (final modifier in [LogicalKeyboardKey.shift, LogicalKeyboardKey.control]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(loadedCall(tester), 'K1ABC', reason: '$modifier must not move the selection');
    }

    // …and the bare key still works, so the guard isn't just disabling it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    await drainLookupQueueTimer(tester);
  });

  group('paging and jumping to the ends', () {
    // A log long enough that a page is a real jump and the ends are nowhere
    // near each other. Oldest is K1HAM, newest K40HAM.
    Future<List<Qso>> longLog() async {
      final list = <Qso>[];
      for (var i = 1; i <= 40; i++) {
        list.add(
          await services.qsos.add(operation.uuid, {
            'their': {'call': 'K${i}HAM', 'sent': '59'},
            'mode': 'SSB',
            'startAtMillis': 1000 + i * 60000,
          }),
        );
      }
      return list;
    }

    testWidgets('Home and End stay the field\'s, for its caret', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);
      expect(loadedCall(tester), 'K40HAM', reason: 'entering the list starts at the newest');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(loadedCall(tester), 'K40HAM');
      expect(callField(tester).controller?.selection.baseOffset, 0, reason: 'Home moved the caret, not the walk');
      await drainLookupQueueTimer(tester);
    });

    testWidgets('Cmd+Up and Cmd+Down go to the oldest and newest, as macOS spells it', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();
      expect(loadedCall(tester), 'K1HAM');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();
      expect(loadedCall(tester), 'K40HAM');

      // At the end already: again is inert, and must NOT end the walk the
      // way a plain Arrow Down does.
      await withModifier(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowDown);
      expect(loadedCall(tester), 'K40HAM');
      await drainLookupQueueTimer(tester);
    });

    testWidgets('Page Up moves a screenful, and stops at the oldest rather than wrapping', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);
      expect(loadedCall(tester), 'K40HAM');

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      final afterOnePage = loadedCall(tester);
      // A page is more than a row and less than the whole log — the exact
      // count depends on the viewport, which is the point of measuring it.
      expect(afterOnePage, isNot('K40HAM'), reason: 'Page Up moved');
      expect(afterOnePage, isNot('K39HAM'), reason: 'Page Up moved more than one row');
      expect(afterOnePage, isNot('K1HAM'), reason: 'Page Up is not Home');

      // Enough pages to run off the top: it lands on the oldest and stays.
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await tester.pump();
      }
      expect(loadedCall(tester), 'K1HAM');
      await drainLookupQueueTimer(tester);
    });

    testWidgets('Page Down comes back, and stops at the newest instead of leaving the list', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);
      await withModifier(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowUp);
      expect(loadedCall(tester), 'K1HAM');

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(loadedCall(tester), isNot('K1HAM'));

      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();
      }
      expect(loadedCall(tester), 'K40HAM', reason: 'Page Down never walks off the end');
      await drainLookupQueueTimer(tester);
    });

    testWidgets('Alt+Up and Alt+Down page the same way', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      final viaPageUp = loadedCall(tester);

      await withModifier(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump();

      expect(loadedCall(tester), viaPageUp, reason: 'Alt+Up is Page Up');
      await drainLookupQueueTimer(tester);
    });
  });

  testWidgets('the walk keeps the keyboard in the main field it started from, not always Call', (tester) async {
    // enterList usually starts from Call, which is also where a fallback
    // would land — this starts from Sent to tell the two apart.
    await pumpPanel(tester, [older, newer]);
    await enterList(tester, field: 'Sent');
    expect(loadedCall(tester), 'K1ABC');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isTrue);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Rcvd')).controller?.text,
      '59',
      reason: 'the walked-to QSO is loaded, not just its callsign',
    );
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Escape drops the selection and leaves the keyboard on a fresh QSO', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(loadedCall(tester), isEmpty);
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('walking the log lands on event markers too, loading the inline event editor', (tester) async {
    // A break marker between the two QSOs. Selecting it swaps the main
    // fields for the event editor (no callsign field) instead of skipping
    // straight to the next contact.
    final marker = await services.qsos.add(operation.uuid, {
      'band': 'event',
      'event': {'event': 'break'},
      'startAtMillis': 1500,
    });
    await pumpPanel(tester, [older, marker, newer]);

    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();

    // One press, one row — lands on the marker, not the older contact.
    expect(find.widgetWithText(TextField, 'Their call'), findsNothing);
    expect(find.text('BREAK'), findsOneWidget);

    // The marker's editor has no call field; the walk goes on from where the
    // keyboard went instead, rather than stranding it on the marker.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(loadedCall(tester), 'W1AW');
    await drainLookupQueueTimer(tester);
  });

  testWidgets('after a tap on a row, Up and Down in the call field walk the list and the keyboard stays there', (tester) async {
    // The operator pointed at a contact and is looking at its call: the
    // arrows step to its neighbours without dragging the keyboard out of the
    // field, so typing still corrects the call loaded there.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await pumpPanel(tester, [older, newer]);

    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    expect(callField(tester).focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    // Up walks back rather than climbing to the pills.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    expect(focusedPill(tester), isNull);
    expect(callField(tester).focusNode?.hasFocus, isTrue);

    // Down past the newest is back to composing — still typing in the call
    // field, not sent off to the pills.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    expect(focusedPill(tester), isNull);

    // And with nothing picked, Up climbs the ladder again: the keyboard
    // leaves the call field for the pill it opens.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(callField(tester).focusNode?.hasFocus, isFalse);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('on a phone with no keyboard a tapped row does not take the call field', (tester) async {
    // Focusing it would pop the on-screen keyboard over the contact the
    // operator just tapped to look at.
    await pumpPanel(tester, [older, newer]);
    await tester.tap(find.text('W1AW'));
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');
    expect(callField(tester).focusNode?.hasFocus, isFalse);
    await drainLookupQueueTimer(tester);
  });
}

/// Selecting a QSO enqueues it for a background lookup, whose (stubbed,
/// instant) completion schedules a 5s status-bar auto-clear — drain it or the
/// framework flags a leaked pending timer. Same helper as the Escape tests'.
Future<void> drainLookupQueueTimer(WidgetTester tester) => tester.pump(const Duration(seconds: 5));
