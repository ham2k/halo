// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Find bar over the logging panel's QSO list (logging-fields.md § Find in
// the log). What it is for: reaching one contact in a long log by the number
// or the call the operator has in front of them — so a filtered row must keep
// the number it has in the whole log (the number is what they are matching
// against), and landing on a row must leave the keyboard where the arrows
// carry on from it.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show CallInfoSummary, QsoList, hardwareKeyboardAttached;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/logging_scope.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/operation/log_find_bar.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

/// Answers `FIND <query>` the way operation-commands does, without booting a
/// JS engine; every other input is a callsign.
class _FindCommandExtensions extends ExtensionService {
  @override
  Future<Map<String, dynamic>?> interpretCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
    final match = RegExp(r'^FIND(?: (.*))?$').firstMatch(input.trim().toUpperCase());
    if (match == null) return null;
    final query = match[1] ?? '';
    return {
      'mixedCase': true,
      'describe': 'Find **$query**',
      'commands': [
        {
          'findInLog': {if (query.isNotEmpty) 'query': query},
        },
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;
  late List<Qso> qsos;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    // The inert lookup queue the keyboard-navigation tests use — the real
    // one waits, in real time, on an extension runtime that never starts.
    services = HaLoServices(
      db,
      settings,
      extensions: _FindCommandExtensions(),
      lookupQueue: LookupQueueService(
        lookup: (call, {required qso, required operation, required online, recentContext = false}) async => null,
        qsos: QsosRepository(db),
        operations: OperationsRepository(db),
        statusBar: StatusBarService(settings.prefs),
        runtimeWaitBudget: Duration.zero,
      ),
    );
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    qsos = [
      for (final (i, call) in ['W1AW', 'K1ABC', 'K1AB', 'N2XYZ'].indexed)
        await services.qsos.add(operation.uuid, {
          'their': {'call': call, 'sent': '59'},
          'mode': 'SSB',
          'startAtMillis': 1000 * (i + 1),
        }),
    ];
  });

  Widget panel({int findRequest = 0, List<Qso>? log, bool controlsAboveLog = false, LoggingScope scope = LoggingScope.operation, Operation? op}) =>
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: LoggingPanel(
              operation: op ?? operation,
              services: services,
              qsos: log ?? qsos,
              loggingControls: const [],
              onCommandAction: (action, [params]) async {},
              findRequest: findRequest,
              controlsAboveLog: controlsAboveLog,
              scope: scope,
            ),
          ),
        ),
      );

  /// Pumps the panel, then bumps its find request the way a host's ⌘F does.
  Future<void> openFind(
    WidgetTester tester, {
    List<Qso>? log,
    bool controlsAboveLog = false,
    LoggingScope scope = LoggingScope.operation,
    Operation? op,
  }) async {
    await tester.pumpWidget(panel(log: log, controlsAboveLog: controlsAboveLog, scope: scope, op: op));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(panel(findRequest: 1, log: log, controlsAboveLog: controlsAboveLog, scope: scope, op: op));
    await tester.pump();
    await tester.pump();
  }

  final findField = find.widgetWithText(TextField, 'QSO number or callsign');
  TextField callField(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));
  String loadedCall(WidgetTester tester) => callField(tester).controller?.text ?? '';

  /// A list row by its callsign — the InkWell every contact row is.
  Finder row(String call) => find.ancestor(of: find.text(call), matching: find.byType(InkWell)).first;

  /// Types into the Find field and lets a callsign's debounce run out.
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(findField, text);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a find request opens the bar with the keyboard in it', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));
    expect(findField, findsNothing);

    await openFind(tester);
    expect(findField, findsOneWidget);
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
  });

  testWidgets('a find request on an open bar puts the caret after what it holds, selecting nothing', (tester) async {
    // ⌘F again from the call field, to go on narrowing what is there: a
    // selection would have the next key wipe the query out.
    await openFind(tester);
    await type(tester, 'K1A');
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    await tester.pump();
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isFalse);

    await tester.pumpWidget(panel(findRequest: 2));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
    expect(tester.widget<TextField>(findField).controller?.selection, const TextSelection.collapsed(offset: 3));
  });

  testWidgets('a partial call filters the list, and each match keeps its number in the whole log', (tester) async {
    await openFind(tester);
    await type(tester, 'K1A');

    expect(find.text('W1AW'), findsNothing);
    expect(find.text('N2XYZ'), findsNothing);
    expect(find.text('K1ABC'), findsOneWidget);
    expect(find.text('K1AB'), findsOneWidget);
    // Renumbered from the matches, K1AB would read 2 — and an operator
    // looking for contact 3 would never find it.
    expect(find.descendant(of: row('K1ABC'), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: row('K1AB'), matching: find.text('3')), findsOneWidget);
  });

  testWidgets('narrowing the list keeps the whole log\'s column widths', (tester) async {
    // Sized from the matches alone, the call column would shrink to fit K1AB
    // and every column after it would jump left as the operator types.
    final log = [
      ...qsos,
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'VE3/K1ABCDE', 'sent': '59'},
        'mode': 'SSB',
        'startAtMillis': 9000,
      }),
    ];
    double callColumn(String call) => tester.getSize(find.ancestor(of: find.text(call), matching: find.byType(SizedBox)).first).width;

    await openFind(tester, log: log);
    final before = callColumn('K1AB');
    await type(tester, 'K1AB.');
    expect(find.text('VE3/K1ABCDE'), findsNothing);
    expect(callColumn('K1AB'), before);
  });

  testWidgets('a trailing period narrows the filter to the exact callsign', (tester) async {
    await openFind(tester);
    await type(tester, 'K1AB.');

    expect(find.text('K1AB'), findsOneWidget);
    expect(find.text('K1ABC'), findsNothing);
  });

  // An exact call asks about one station, and its contacts elsewhere are the
  // rest of the answer. A partial call is a search of this log, which every
  // other operation's matches would bury. This log's own contact must not
  // come back a second time among the others.
  testWidgets('an exact call also shows the station\'s contacts from other operations, under their own header', (tester) async {
    await tester.runAsync(() async {
      final other = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Other Op');
      for (final call in ['K1AB', 'K1ABC']) {
        await services.qsos.add(other.uuid, {
          'their': {'call': call},
          'mode': 'CW',
          'startAtMillis': DateTime.utc(2025, 3, 14, 12).millisecondsSinceEpoch,
        });
      }
    });
    const header = '1 QSO outside of this operation';
    Finder inList(String text) => find.descendant(of: find.byType(QsoList), matching: find.text(text));
    await openFind(tester);

    await type(tester, 'K1AB');
    expect(find.text(header), findsNothing);

    await type(tester, 'K1AB.');
    await tester.pump();
    expect(find.text(header), findsOneWidget);
    expect(inList('K1AB'), findsNWidgets(2), reason: 'this log\'s contact, and the other operation\'s');
    expect(inList('2025-03-14'), findsOneWidget);
    expect(inList('K1ABC'), findsNothing);
    expect(
      find.descendant(of: find.byType(LogFindBar), matching: find.text('1 QSO')),
      findsOneWidget,
      reason: 'the bar still counts this log\'s matches',
    );

    await tester.tap(inList('2025-03-14'));
    await tester.pump();
    expect(loadedCall(tester), isEmpty, reason: 'another operation\'s contact is not this log\'s to edit');
  });

  // "No match" over a list of the station's contacts contradicts the rows
  // under it; the line has to say where there are none.
  testWidgets('an exact call worked only elsewhere says this operation has none, above the others', (tester) async {
    await tester.runAsync(() async {
      final other = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Other Op');
      await services.qsos.add(other.uuid, {
        'their': {'call': 'W7ZZZ'},
        'mode': 'CW',
        'startAtMillis': DateTime.utc(2025, 3, 14, 12).millisecondsSinceEpoch,
      });
    });
    await openFind(tester);
    await type(tester, 'W7ZZZ.');
    await tester.pump();
    Finder inList(String text) => find.descendant(of: find.byType(QsoList), matching: find.text(text));
    final none = inList('No QSOs in this operation');
    expect(none, findsOneWidget);
    expect(inList('No match'), findsNothing);
    expect(tester.getTopLeft(none).dy, lessThan(tester.getTopLeft(find.text('1 QSO outside of this operation')).dy));

    await type(tester, 'W6ZZZ.');
    await tester.pump();
    expect(inList('No match'), findsOneWidget, reason: 'with nothing elsewhere either, the empty message stays');
  });

  // Chasing logs against a stand-in with no uuid, so every chase — this
  // period's and every earlier one — is a loose contact with the same empty
  // operation. Telling "past" apart by operation finds none of them; what the
  // log on screen holds is the only line between the two. And the chasing log
  // is not an operation, so "outside of this operation" names nothing.
  testWidgets('chasing, earlier chases show as past QSOs', (tester) async {
    late List<Qso> period;
    await tester.runAsync(() async {
      Future<Qso> chase(DateTime at) => services.qsos.add('', {
        'their': {'call': 'W9XYZ'},
        'our': {'call': 'N0CALL'},
        'mode': 'CW',
        'startAtMillis': at.millisecondsSinceEpoch,
      });
      await chase(DateTime.utc(2025, 3, 14, 12));
      period = [await chase(DateTime.utc(2026, 10, 22, 12))];
    });
    const chasing = Operation(uuid: '', data: {'stationCall': 'N0CALL'});
    await openFind(tester, scope: LoggingScope.chase, op: chasing, log: period);
    await type(tester, 'W9XYZ.');
    await tester.pump();
    expect(find.text('1 past QSO'), findsOneWidget);
    expect(find.descendant(of: find.byType(QsoList), matching: find.text('2025-03-14')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(QsoList), matching: find.text('W9XYZ')),
      findsNWidgets(2),
      reason: 'this period\'s chase, and the earlier one',
    );
    expect(find.textContaining('outside of this operation'), findsNothing);
  });

  testWidgets('Enter on a number loads that contact, closes the bar, and puts the keyboard in the call field', (tester) async {
    await openFind(tester);
    await type(tester, '2');
    // A number points; it does not load until Enter.
    expect(loadedCall(tester), isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    expect(findField, findsNothing);
    // Ready to correct the contact found, and to walk on from it.
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Enter on a callsign loads the newest match into the call field and keeps the filter up', (tester) async {
    await openFind(tester);
    await type(tester, 'K1A');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    expect(findField, findsOneWidget);
    expect(find.text('W1AW'), findsNothing);
    expect(callField(tester).focusNode?.hasFocus, isTrue);

    // The walk covers the matches only: up from the newest is K1ABC, and up
    // again leaves the list for the bar rather than reaching the W1AW the
    // filter hides.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Down from the field loads the row nearest the bar into the call field, and the walk goes on from there', (tester) async {
    // No Enter between finding a contact and correcting it: Down lands in
    // the call field, the same as arriving in the list from the pills.
    await openFind(tester);
    await type(tester, 'K1A');

    // The row nearest the bar — the oldest, in a list drawn oldest first.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    expect(findField, findsOneWidget, reason: 'the filter stays up while walking its matches');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Up off the top row goes back to the end of the Find field, with nothing loaded', (tester) async {
    // The bar is what sits above the list, so Up off its top row lands there,
    // ready to change the search. Without this the walk clamps at the top and
    // the only way back to the search is the mouse. Nothing stays loaded, so
    // Down from the bar comes back onto the same row rather than the next.
    await openFind(tester);
    await type(tester, 'K1A');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    final field = tester.widget<TextField>(findField);
    expect(field.focusNode?.hasFocus, isTrue);
    expect(field.controller?.selection, const TextSelection.collapsed(offset: 3), reason: 'the caret at the end, to go on typing');
    expect(loadedCall(tester), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with the newest drawn at the top, Up off it goes to the Find field too', (tester) async {
    // Controls above the log draw the list newest first, so the top row is
    // also the one a step past would drop the selection from, leaving the
    // keyboard in the call field. With the bar open the bar is what is above.
    await openFind(tester, controlsAboveLog: true);
    await type(tester, 'K1A');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1AB', reason: 'the row nearest the bar is the newest match here');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
    expect(loadedCall(tester), isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Down on a number loads that contact into the call field', (tester) async {
    await openFind(tester);
    await type(tester, '3');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with nothing loaded, Up in the field is the field\'s own', (tester) async {
    await openFind(tester);
    await type(tester, 'K1A');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
  });

  testWidgets('after a tap on a filtered row, the call field walks the matches only', (tester) async {
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await openFind(tester);
    await type(tester, 'K1A');

    await tester.tap(find.text('K1ABC'));
    await tester.pump();
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    // Up past K1ABC would be W1AW in the whole log; the filter hides it, so
    // the step after K1ABC is the bar.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a number beyond the log says nothing matched, and Enter selects nothing', (tester) async {
    await openFind(tester);
    await type(tester, '9');
    expect(find.text('No match'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(loadedCall(tester), isEmpty);
    expect(findField, findsOneWidget);
  });

  testWidgets('Escape clears the filter, hides the bar and returns the keyboard to the call field', (tester) async {
    // A keyboard to type with — the test platform is a phone.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await openFind(tester);
    await type(tester, 'K1A');
    expect(find.text('W1AW'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(findField, findsNothing);
    expect(find.text('W1AW'), findsOneWidget);
    expect(callField(tester).focusNode?.hasFocus, isTrue);

    // Reopened, the bar starts empty: the find was cleared, not just hidden.
    await tester.pumpWidget(panel(findRequest: 2));
    await tester.pump();
    expect(tester.widget<TextField>(findField).controller?.text, isEmpty);
  });

  testWidgets('closing the bar on a phone with no keyboard leaves the call field alone', (tester) async {
    // Focusing it would pop the on-screen keyboard over the log the operator
    // just closed a find on (logging-fields.md § Which field has focus).
    await openFind(tester);
    await tester.tap(find.descendant(of: findField, matching: find.byType(IconButton)));
    await tester.pump();
    await tester.pump();
    expect(findField, findsNothing);
    expect(callField(tester).focusNode?.hasFocus, isFalse);
  });

  testWidgets('a FIND command opens the bar on its query, with the keyboard in it', (tester) async {
    // The action a typed "FIND K1A" (or SEARCH, JUMP, GOTO) dispatches, sent
    // the way the ⌘K dialog sends it: through the panel's own dispatcher.
    final context = services.openOperationContext(operation.uuid);
    addTearDown(() => services.closeOperationContext(context));
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));

    await services.currentCommandDispatch!([
      {
        'findInLog': {'query': 'K1A'},
      },
    ]);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(findField).controller?.text, 'K1A');
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
    // Selected, the query would be replaced by the first key typed to refine it.
    expect(tester.widget<TextField>(findField).controller?.selection, const TextSelection.collapsed(offset: 3));
    expect(find.text('W1AW'), findsNothing, reason: 'the query applies at once, without waiting on a pause in typing');
    expect(find.text('K1ABC'), findsOneWidget);
  });

  testWidgets('FIND typed in the call field and entered leaves the keyboard in the bar', (tester) async {
    // The path an operator takes, not the dispatcher alone: the command runs
    // from inside the call field's submit, which clears that field and
    // reports a message on the way, and the bar has to end up with the
    // keyboard all the same. The browser's half of this (the accessibility
    // input re-taking focus) has no test platform; it is the `kIsWeb` branch
    // in `_openFind`.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(TextField, 'Their call'));
    // In two steps, as typed: Space is literal only once FIND is recognized.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'FIND');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'FIND K1A');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.widget<TextField>(findField).controller?.text, 'K1A');
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
    expect(callField(tester).focusNode?.hasFocus, isFalse);
    expect(loadedCall(tester), isEmpty, reason: 'the command is gone from the call field once it runs');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a bare FIND opens an empty bar', (tester) async {
    final context = services.openOperationContext(operation.uuid);
    addTearDown(() => services.closeOperationContext(context));
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));

    await services.currentCommandDispatch!([
      {'findInLog': <String, dynamic>{}},
    ]);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(findField).controller?.text, isEmpty);
    expect(find.text('W1AW'), findsOneWidget);
  });

  testWidgets('a tap on the worked-before pill finds that exact call, leaving the keyboard in the call field', (tester) async {
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1AB');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final pill = find.descendant(of: find.byType(CallInfoSummary), matching: find.textContaining('QSO'));
    expect(pill, findsOneWidget, reason: 'K1AB is in the log, so its history pill shows');

    await tester.tap(pill);
    await tester.pump();
    // Exact: K1AB's history, without K1ABC's contacts mixed in.
    expect(tester.widget<TextField>(findField).controller?.text, 'K1AB.');
    expect(find.descendant(of: find.byType(QsoList), matching: find.text('K1ABC')), findsNothing);
    expect(find.descendant(of: find.byType(QsoList), matching: find.text('K1AB')), findsOneWidget);
    // Mid-contact: the operator is still typing the call they were typing.
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    expect(callField(tester).controller?.text, 'K1AB');
    await tester.pump(const Duration(seconds: 5));
  });

  /// Loads [call] with a tap, then opens Find over it — the bar on top of a
  /// contact already being looked at.
  Future<void> openFindOverLoaded(WidgetTester tester, String call) async {
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    await tester.pumpWidget(panel());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(call));
    await tester.pump();
    expect(loadedCall(tester), call);
    await tester.pumpWidget(panel(findRequest: 1));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Enter on a number typed over a loaded contact loads the number', (tester) async {
    // The loaded row is where the operator was; the number is where they
    // asked to go. Taking the row would make the number do nothing at all.
    await openFindOverLoaded(tester, 'W1AW');
    await type(tester, '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Down on a number typed over a loaded contact loads the number', (tester) async {
    await openFindOverLoaded(tester, 'W1AW');
    await type(tester, '3');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1AB', reason: 'not K1ABC, the step on from W1AW');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('walking on from a number\'s contact scrolls the list with the walk', (tester) async {
    // The number's highlight stays up with the bar. If the list kept it in
    // view instead of the row being edited, Cmd+Down would load the newest
    // contact somewhere off screen.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    final long = [
      for (var i = 0; i < 120; i++)
        await services.qsos.add(operation.uuid, {
          'their': {'call': 'K${i + 1}XX', 'sent': '59'},
          'mode': 'SSB',
          'startAtMillis': 10000 + i,
        }),
    ];
    // In the list, not the call field the walk loads it into.
    final newestRow = find.descendant(of: find.byType(QsoList), matching: find.text('K120XX'));
    await openFind(tester, log: long);
    await type(tester, '3');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(loadedCall(tester), 'K3XX');
    expect(newestRow, findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(loadedCall(tester), 'K120XX');
    expect(newestRow, findsOneWidget);
  });

  testWidgets('a walk onto a deleted contact keeps the keyboard, and goes on past it', (tester) async {
    // A deleted contact's fields take no focus. Without something else to
    // hold the keyboard, focus falls out as the walk lands on one, and the
    // next arrow goes nowhere.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    final deleted = Qso(uuid: qsos[1].uuid, operationUuid: qsos[1].operationUuid, data: qsos[1].data, deleted: true);
    final log = [qsos[0], deleted, qsos[2], qsos[3]];
    await tester.pumpWidget(panel(log: log));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('W1AW'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');
    expect(callField(tester).focusNode?.hasFocus, isFalse, reason: 'the locked field cannot hold it');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1AB');
    expect(callField(tester).focusNode?.hasFocus, isTrue, reason: 'off the deleted row, the keyboard is back in the fields');
    await tester.pump(const Duration(seconds: 5));
  });

  /// The icon button whose glyph carries [label] — the info row's Restore.
  Finder iconButton(String label) => find.ancestor(of: find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == label), matching: find.byType(IconButton));

  testWidgets('a tap from a deleted contact onto a live one puts the keyboard in its call field', (tester) async {
    // At the tap, the fields are still the deleted contact's, disabled: a
    // focus request then goes nowhere, and the keyboard stays on the list
    // with nothing to type into.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    final deleted = Qso(uuid: qsos[1].uuid, operationUuid: qsos[1].operationUuid, data: qsos[1].data, deleted: true);
    await tester.pumpWidget(panel(log: [qsos[0], deleted, qsos[2], qsos[3]]));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('K1ABC'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('N2XYZ'));
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'N2XYZ');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Restore on a deleted contact walked onto puts the keyboard back in the fields', (tester) async {
    // The row unloads on Restore. Left on the list, the keyboard has nothing
    // loaded to walk from and nothing to type into.
    hardwareKeyboardAttached.value = true;
    addTearDown(() => hardwareKeyboardAttached.value = false);
    final deleted = Qso(uuid: qsos[1].uuid, operationUuid: qsos[1].operationUuid, data: qsos[1].data, deleted: true);
    await tester.pumpWidget(panel(log: [qsos[0], deleted, qsos[2], qsos[3]]));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('W1AW'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(loadedCall(tester), 'K1ABC');

    await tester.tap(iconButton('Restore'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(loadedCall(tester), isEmpty, reason: 'Restore unloads the row');
    expect(callField(tester).focusNode?.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a number far from the live edge scrolls the list to that contact', (tester) async {
    final long = [
      for (var i = 0; i < 120; i++)
        await services.qsos.add(operation.uuid, {
          'their': {'call': 'K${i + 1}XX', 'sent': '59'},
          'mode': 'SSB',
          'startAtMillis': 10000 + i,
        }),
    ];
    await openFind(tester, log: long);
    // The list rests at the newest contact; the oldest is far off screen.
    expect(find.text('K3XX'), findsNothing);

    // Typed straight after ⌘F, while the controls are still animating their
    // height around the focus move — the list's live-edge follow must not
    // take the jump back.
    await type(tester, '3');
    await tester.pumpAndSettle();
    expect(find.text('K3XX'), findsOneWidget);
  });
}
