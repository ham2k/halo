// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// APP-19's focus ladder, at the rung only this panel can wire up:
//
//     QSO list  ──▲──  secondary pills  ──▲──  main logging fields
//               ──▼──                   ──▼──
//
// LoggingControls owns the bottom two rungs (and tests them in halo_widgets);
// the list is a sibling widget whose selection this panel owns, so walking
// between the two is only ever exercised here. The point of the rung is that
// an operator can review and re-open earlier contacts without reaching for
// the mouse — and, crucially, that arrowing through the log does NOT drag the
// keyboard out of the list on every step: the row loads into the editor while
// focus stays put, so the next arrow keeps walking.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
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

  Future<void> pumpPanel(WidgetTester tester, List<Qso> qsos, {ValueChanged<String?>? onSelectionChanged}) async {
    await tester.pumpWidget(
      wrap(
        LoggingPanel(
          operation: operation,
          services: services,
          qsos: qsos,
          loggingControls: const [],
          onCommandAction: (action, [params]) async {},
          onSelectionChanged: onSelectionChanged,
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
  /// off the pills into the list — the way in for every test below.
  Future<void> enterList(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
  }

  testWidgets('Arrow Up from the pills selects the newest QSO without taking the keyboard into the fields', (tester) async {
    await pumpPanel(tester, [older, newer]);
    expect(loadedCall(tester), isEmpty);

    await enterList(tester);

    // The newest contact is loaded for editing…
    expect(loadedCall(tester), 'K1ABC');
    // …but the keyboard stayed in the list: the call field must NOT have
    // taken focus, or the next arrow would move a text cursor instead of
    // walking to the previous QSO.
    expect(callField(tester).focusNode?.hasFocus, isFalse);
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

  testWidgets('Up and Down walk the log; Down past the newest row hands the keyboard back to the pills, opening the '
      'remembered one, and deselects back to the new QSO being composed', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');

    // The oldest row is the end of the road — Up again stays put rather than
    // silently wrapping round to the newest.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');

    // Down off the newest row leaves the list entirely, mirroring the Up that
    // got here — but unlike a mid-list step, it undoes the selection too: the
    // walk started from a new QSO being composed, so leaving the list the
    // same way it was entered returns to that, not to whatever row the walk
    // happened to end on. It also opens the pill it lands on (Time — the one
    // `enterList`'s own Up remembered), the same way arriving via Up from a
    // main field does, rather than merely parking the keyboard on its chip.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);
    expect(loadedCall(tester), isEmpty);
    await drainLookupQueueTimer(tester);
  });

  testWidgets('a second Down landing before the deferred hand-off fires does not steal focus back to the pills', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    // Two Downs back-to-back with no pump in between — key-repeat can
    // deliver these faster than a frame. The first deselects and queues a
    // deferred hand-off to the pills; the second, seeing the selection
    // already cleared, re-selects the newest row before that hand-off ever
    // runs.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    // The list re-selected the newest row — the keyboard must stay there,
    // not jump to the pills (or a pill's own opened field) on the first
    // Down's now-stale callback.
    expect(loadedCall(tester), 'K1ABC');
    expect(focusedPill(tester), isNull);
    expect(find.widgetWithText(TextField, 'Time (UTC)'), findsNothing, reason: 'the stale callback must not have opened the remembered pill either');
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
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(loadedCall(tester), 'N0DRAFT', reason: 'the draft the operator was composing must come back, not a blank form');
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Shift and Ctrl leave the walk alone', (tester) async {
    // Shift+arrow is a range-selection gesture and Ctrl belongs to the
    // platform — neither has a meaning in this list, so both pass straight
    // through. (Cmd and Option DO mean something here; see below.)
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

    testWidgets('End and Home go to the newest and oldest contacts', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);
      expect(loadedCall(tester), 'K40HAM', reason: 'entering the list starts at the newest');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(loadedCall(tester), 'K1HAM');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(loadedCall(tester), 'K40HAM');

      // At the end already: End again is inert, and must NOT walk off the
      // list the way a plain Arrow Down does.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(loadedCall(tester), 'K40HAM');
      expect(focusedPill(tester), isNull, reason: 'End never leaves the list');
      await drainLookupQueueTimer(tester);
    });

    testWidgets('Cmd+Up and Cmd+Down are the same jump, as macOS spells it', (tester) async {
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
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(loadedCall(tester), 'K1HAM');

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(loadedCall(tester), isNot('K1HAM'));

      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();
      }
      expect(loadedCall(tester), 'K40HAM');
      expect(focusedPill(tester), isNull, reason: 'Page Down never walks off the end');
      await drainLookupQueueTimer(tester);
    });

    testWidgets('Alt+Up and Alt+Down page the same way', (tester) async {
      final list = await longLog();
      await pumpPanel(tester, list);
      await enterList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      final viaPageUp = loadedCall(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump();

      expect(loadedCall(tester), viaPageUp, reason: 'Alt+Up is Page Up');
      await drainLookupQueueTimer(tester);
    });
  });

  testWidgets('Enter moves the keyboard to the callsign field, keeping the row selected for editing', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Now editing for real: the cursor is in the form, still on that QSO.
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    expect(loadedCall(tester), 'W1AW');
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Rcvd')).controller?.text,
      '59',
      reason: 'the selected QSO is loaded, not just its callsign',
    );
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Enter on a row restores the field the operator was in before arrowing up, not always Call', (tester) async {
    // enterList always starts from Call, which happens to be Enter's own
    // fallback too — coincidentally passing even a hardcoded "always Call"
    // implementation. This starts from a different main field to actually
    // exercise the "resume where I left off" behavior.
    await pumpPanel(tester, [older, newer]);
    await tester.tap(find.widgetWithText(TextField, 'Sent'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'W1AW');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus,
      isTrue,
      reason: 'Enter is "resume editing where I left off", not "start fresh" — that\'s Escape\'s job',
    );
    expect(callField(tester).focusNode?.hasFocus, isFalse);
    expect(loadedCall(tester), 'W1AW');
    await drainLookupQueueTimer(tester);
  });

  testWidgets('Escape from the list drops the selection and puts the keyboard back on a fresh QSO', (tester) async {
    await pumpPanel(tester, [older, newer]);
    await enterList(tester);
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Deselected, back to composing, and the cursor is where the next
    // callsign goes — no mouse needed to get out of the log.
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

    // One press, one row — lands on the marker, not the older contact.
    expect(find.widgetWithText(TextField, 'Their call'), findsNothing);
    expect(find.text('BREAK'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(loadedCall(tester), 'W1AW');
    await drainLookupQueueTimer(tester);
  });
}

/// Selecting a QSO enqueues it for a background lookup, whose (stubbed,
/// instant) completion schedules a 5s status-bar auto-clear — drain it or the
/// framework flags a leaked pending timer. Same helper as the Escape tests'.
Future<void> drainLookupQueueTimer(WidgetTester tester) => tester.pump(const Duration(seconds: 5));
