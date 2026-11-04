// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operator control: who is at the key, and which of several station
// calls are on the air. While composing it speaks for the OPERATION — what
// the next contacts are stamped with — and while a saved contact is open it
// speaks for THAT contact only. A control that wrote the operation from an
// open contact would move every contact logged after it; one that wrote the
// contact while composing would leave the next contacts stamped wrong.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  Future<Operation> saved(WidgetTester tester, Map<String, dynamic> data) async {
    final updated = Operation(uuid: operation.uuid, data: {...operation.data, ...data});
    await tester.runAsync(() => operations.saveData(updated));
    return operation = updated;
  }

  Future<Operation?> current(WidgetTester tester) => tester.runAsync<Operation?>(() => operations.get(operation.uuid));

  LogHooks log() => LogHooks(operation: operation, qsosRepository: qsos, operationsRepository: operations);

  Future<Operation> stored(WidgetTester tester, bool Function(Operation op) until) async {
    Operation? op;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      op = await current(tester);
      if (op != null && until(op)) return op;
    }
    fail('the operation never reached the expected state: ${op?.data}');
  }

  Finder chip(String label) => find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

  testWidgets('is left out of a plain one-call operation', (tester) async {
    // KI2D logging as KI2D: there is nothing for the control to say, and a
    // chip naming the operator's own call on every log would be noise.
    await tester.pumpWidget(host(log: log()));
    await tester.pump();

    expect(find.byIcon(MdiIcons.account), findsNothing);
  });

  testWidgets('a guest operator shows on the chip and is written to the operation when the field is left', (tester) async {
    await saved(tester, {'operatorCall': 'N0DEV'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    expect(chip('N0DEV'), findsOneWidget);

    await openControl(tester, MdiIcons.account);
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'k1abc');
    await tester.pump();
    expect(operatorCallFor((await current(tester))!), 'N0DEV', reason: 'mid-typing: every letter would sync');

    FocusManager.instance.primaryFocus?.unfocus();
    final op = await stored(tester, (op) => operatorCallFor(op) == 'K1ABC');
    expect(op.data['operatorCall'], 'K1ABC');
    expect(find.byIcon(MdiIcons.playlistEdit), findsNothing, reason: 'one call has no list to edit; a second is added in Operation Details');
  });

  testWidgets('a contact logged right after the operator is typed carries the new operator', (tester) async {
    // Enter closes the control, which writes the operation, and a second
    // Enter logs — before the panel is handed the operation that write
    // stored. The stamp reads the operation the panel holds, so the contact
    // has to carry the typed operator itself, or it is stamped with the one
    // who just handed over the key. (The harness never hands the panel the
    // stored operation at all, which is that window held open.)
    await saved(tester, {'operatorCall': 'N0DEV'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'K1ABC');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleControl(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.ourOperatorCall, 'K1ABC');
  });

  testWidgets("leaving the field after the open contact goes puts back the operation's operator, never the contact's", (tester) async {
    // The contact is saved or closed with the field still focused, which
    // keeps showing the contact's W2XYZ; written on the way out, that would
    // stamp W2XYZ on every contact logged afterwards.
    await saved(tester, {'operatorCall': 'N0DEV'});
    final existing = await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'our': {'call': 'KI2D', 'operatorCall': 'N0DEV'},
        'band': '20m',
        'startAtMillis': 1000,
      }),
    );
    var session = LoggingSession(editingQso: existing);
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return host(log: log(), session: session);
        },
      ),
    );
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'W2XYZ');
    await tester.pump();

    rebuild(() => session = const LoggingSession());
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));

    expect(operatorCallFor((await current(tester))!), 'N0DEV');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Operator')).controller!.text, 'N0DEV');
  });

  testWidgets("a tap changes one call over the stored list, keeping another device's", (tester) async {
    // Another device took KI2D off the air; this panel has not been handed
    // that yet. Writing the off-list as this panel sees it would put KI2D
    // back on.
    await saved(tester, {'stationCall': 'KI2D, N0DEV, K1ABC'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await tester.runAsync(
      () => operations.saveData(
        Operation(
          uuid: operation.uuid,
          data: {
            ...operation.data,
            stationCallsOffKey: ['KI2D'],
          },
        ),
      ),
    );

    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);
    final op = await stored(tester, (op) => onAirStationCalls(op).length == 1);
    expect(onAirStationCalls(op), ['K1ABC']);
  });

  testWidgets('without an operations repository a tap changes nothing on screen', (tester) async {
    // A tap that showed a call off while nothing stored it would disagree with
    // every contact logged afterwards.
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    await tester.pumpWidget(
      host(
        log: LogHooks(operation: operation, qsosRepository: qsos),
      ),
    );
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);
    await tester.pump();

    expect(chip('2 calls'), findsOneWidget);
    expect(find.byIcon(MdiIcons.playlistEdit), findsNothing, reason: 'an Edit list with nowhere to store the list would take one and drop it');
  });

  testWidgets("an open contact listing no calls shows its segment's, not the operation's", (tester) async {
    // A break changed the calls; a contact made before it and listing none
    // was made under W1AW and K1ABC. Shown the current calls, one tap would
    // file it under calls that were not on the air for it.
    await saved(tester, {'stationCall': 'N0DEV, KI2D'});
    final rows = (await tester.runAsync(() async {
      await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 500, operation: {...segmentOverrideOf(operation.data), 'stationCall': 'W1AW, K1ABC'});
      final early = await qsos.add(operation.uuid, {
        'their': {'call': 'DL1ABC'},
        'our': {'call': 'W1AW'},
        'band': '20m',
        'startAtMillis': 1000,
      });
      await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 2000, operation: segmentOverrideOf(operation.data));
      return (early, await qsos.forOperation(operation.uuid));
    }))!;
    await tester.pumpWidget(
      host(
        log: LogHooks(operation: operation, qsosRepository: qsos, operationsRepository: operations, qsos: rows.$2),
        session: LoggingSession(editingQso: rows.$1),
      ),
    );
    await tester.pump();

    expect(chip('2 calls'), findsOneWidget);
    await openControl(tester, MdiIcons.account);
    Checkbox box(String call) => tester.widget<Checkbox>(
      find.descendant(
        of: find.ancestor(of: find.text(call).last, matching: find.byType(Row)).first,
        matching: find.byType(Checkbox),
      ),
    );
    expect(box('W1AW').value, isTrue);
    expect(box('K1ABC').value, isTrue);
    expect(box('N0DEV').value, isFalse);
  });

  testWidgets('several calls show how many are on the air, and unchecking one marks it off without touching the log', (tester) async {
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    final logged = await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'our': {'call': 'KI2D'},
        'band': '20m',
        'startAtMillis': 1000,
      }),
    );
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    expect(chip('2 calls'), findsOneWidget);

    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);
    final op = await stored(tester, (op) => op.data[stationCallsOffKey] != null);

    expect(onAirStationCalls(op), ['KI2D']);
    final contact = (await tester.runAsync(() => qsos.get(logged!.uuid)))!;
    expect(stationCallsOfOur(asQsonMap(contact.data['our'])), isNull, reason: 'a contact already logged keeps following what was true when it was made');
  });

  testWidgets('a second tap before the first write lands keeps both', (tester) async {
    // The panel is handed the operation again only once the first write
    // comes back; a second tap reading the operation it still holds would
    // put N0DEV back on the air.
    await saved(tester, {'stationCall': 'KI2D, N0DEV, K1ABC'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await openControl(tester, MdiIcons.account);

    await tester.tap(find.text('N0DEV').last);
    await tester.pump();
    expect(chip('2 calls'), findsOneWidget, reason: 'the chip shows the tap at once, not when the write lands');
    await tester.tap(find.text('K1ABC').last);
    await tester.pump();

    final op = await stored(tester, (op) => onAirStationCalls(op).length == 1);
    expect(onAirStationCalls(op), ['KI2D']);
  });

  testWidgets('the last call on the air cannot be unchecked', (tester) async {
    // A contact made under no call belongs in no submission at all.
    await saved(tester, {
      'stationCall': 'KI2D, N0DEV',
      stationCallsOffKey: ['N0DEV'],
    });
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    expect(chip('KI2D'), findsOneWidget, reason: 'one call on the air shows the call itself');

    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('KI2D').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(onAirStationCalls((await current(tester))!), ['KI2D']);
  });

  testWidgets('on an open contact it edits that contact and leaves the operation alone', (tester) async {
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    final existing = await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'our': {'call': 'KI2D'},
        'band': '20m',
        'startAtMillis': 1000,
      }),
    );
    await tester.pumpWidget(
      host(
        log: log(),
        session: LoggingSession(editingQso: existing),
      ),
    );
    await tester.pump();

    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('KI2D').last);
    await tester.pump();
    await tester.showKeyboard(find.widgetWithText(TextField, 'Their call'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final contacts = await waitForQsosWhere(
      tester,
      'the contact listing only N0DEV',
      (logged) => stationCallsOfOur(asQsonMap(logged.single.data['our']))?.join() == 'N0DEV',
    );
    expect(contacts.single.ourCall, 'N0DEV', reason: 'our.call follows the calls the contact lists');
    final op = (await current(tester))!;
    expect(onAirStationCalls(op), ['KI2D', 'N0DEV'], reason: "fixing one contact must not take a call off the air for the next");
  });

  testWidgets('Edit list adds a call from the next contact on', (tester) async {
    // The trap: the contact below has no list of its own, so it follows the
    // operation — and would be claimed by the new call unless it is pinned
    // to the calls it was made under BEFORE the list changes.
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    final logged = await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'our': {'call': 'KI2D'},
        'band': '20m',
        'startAtMillis': 1000,
      }),
    );
    await tester.pumpWidget(host(log: log()));
    await tester.pump();

    await openControl(tester, MdiIcons.account);
    await tester.tap(find.byIcon(MdiIcons.playlistEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Add a callsign'), 'k3c');
    await tester.tap(find.text('Save'));
    await tester.pump();

    final op = await stored(tester, (op) => op.stationCalls.length == 3);
    expect(op.stationCalls, ['KI2D', 'N0DEV', 'K3C']);
    final contact = (await tester.runAsync(() => qsos.get(logged!.uuid)))!;
    expect(stationCallsOfOur(asQsonMap(contact.data['our'])), ['KI2D', 'N0DEV']);
  });

  testWidgets('a contact logged right after a tap carries the calls the chip shows', (tester) async {
    // The tap's write has not reached the operation the panel holds (the
    // harness never hands it back), so a stamp read off that operation would
    // file the contact under N0DEV, which the screen says is off the air.
    await saved(tester, {'stationCall': 'KI2D, N0DEV, K1ABC'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.showKeyboard(find.widgetWithText(TextField, 'Their call'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(stationCallsOfOur(asQsonMap(logged.single.data['our'])), ['KI2D', 'K1ABC']);
    expect(logged.single.ourCall, 'KI2D');
  });

  testWidgets('an operator typed while composing is stored even when a saved contact opens before the field is left', (tester) async {
    // Left by opening a contact, the field would otherwise drop the typed
    // operator on the floor — while the chip and every new contact go on
    // using it, and no other device ever learns it.
    await saved(tester, {'operatorCall': 'N0DEV'});
    final existing = await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'our': {'call': 'KI2D', 'operatorCall': 'N0DEV'},
        'band': '20m',
        'startAtMillis': 1000,
      }),
    );
    var session = const LoggingSession();
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return host(log: log(), session: session);
        },
      ),
    );
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'K1ABC');
    await tester.pump();

    rebuild(() => session = LoggingSession(editingQso: existing));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();

    final op = await stored(tester, (op) => operatorCallFor(op) == 'K1ABC');
    expect(op.data['operatorCall'], 'K1ABC');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Operator')).controller!.text, 'N0DEV', reason: 'the field now speaks for the open contact');
  });

  testWidgets('a write that fails is reported as the Operator control\'s, and the control shows what is stored', (tester) async {
    // Swallowed, the operator would see a call off the air that the
    // operation never stored; filed as a contact-log failure, it would be
    // found under the wrong cause.
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    final reports = <({String context, bool told})>[];
    await tester.pumpWidget(
      host(
        log: LogHooks(
          operation: operation,
          qsosRepository: qsos,
          operationsRepository: _FailingOperations(db),
          onWriteError: (e, _, {required context, required told}) => reports.add((context: context, told: told)),
        ),
      ),
    );
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);
    for (var i = 0; i < 20 && reports.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    expect(reports, [(context: 'loggingControls:operator', told: true)]);
    await tester.pump();
    expect(
      find.textContaining('Could not change the operator or station calls', findRichText: true),
      findsOneWidget,
      reason: '"Could not save" would read as the contact not logged',
    );
    expect(chip('2 calls'), findsOneWidget, reason: 'back to what the operation says');
  });

  testWidgets('a tap changes only the off-list, never the station call as stored', (tester) async {
    // Respaced from "KI2D,N0DEV", the save would read a changed segment and
    // restamp our.call on the log behind it.
    await saved(tester, {'stationCall': 'KI2D,N0DEV'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);

    final op = await stored(tester, (op) => op.data[stationCallsOffKey] != null);
    expect(op.data['stationCall'], 'KI2D,N0DEV');
  });

  testWidgets('a tap the stored state refuses goes back to what the operation says', (tester) async {
    // Another device took KI2D off a moment ago; this panel has not seen it.
    // Taking N0DEV off too would leave no call on the air, so the write is
    // refused — and the control must not go on showing it as done.
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await tester.runAsync(
      () => operations.saveData(
        Operation(
          uuid: operation.uuid,
          data: {
            ...operation.data,
            stationCallsOffKey: ['KI2D'],
          },
        ),
      ),
    );
    await openControl(tester, MdiIcons.account);
    await tester.tap(find.text('N0DEV').last);
    await tester.pump();
    for (var i = 0; i < 20 && chip('2 calls').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    expect(chip('2 calls'), findsOneWidget, reason: 'back to the operation the panel holds once the write is refused');
    expect(onAirStationCalls((await current(tester))!), ['N0DEV']);
  });

  testWidgets("Edit list applies its changes over the stored list, keeping another device's", (tester) async {
    await saved(tester, {'stationCall': 'KI2D, N0DEV'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    // Added on another device; this panel still holds KI2D, N0DEV.
    await tester.runAsync(() => operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'stationCall': 'KI2D, N0DEV, K9XX'})));
    await openControl(tester, MdiIcons.account);
    await tester.tap(find.byIcon(MdiIcons.playlistEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Add a callsign'), 'k3c');
    await tester.tap(find.text('Save'));
    await tester.pump();

    final op = await stored(tester, (op) => op.stationCalls.contains('K3C'));
    expect(op.stationCalls, ['KI2D', 'N0DEV', 'K9XX', 'K3C']);
  });

  testWidgets('an operator typed into the field is stored when the panel goes away before the field is left', (tester) async {
    await saved(tester, {'operatorCall': 'N0DEV'});
    await tester.pumpWidget(host(log: log()));
    await tester.pump();
    await openControl(tester, MdiIcons.account);
    await tester.enterText(find.widgetWithText(TextField, 'Operator'), 'K1ABC');
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    final op = await stored(tester, (op) => operatorCallFor(op) == 'K1ABC');
    expect(op.data['operatorCall'], 'K1ABC');
  });
}

class _FailingOperations extends OperationsRepository {
  _FailingOperations(super.db);

  @override
  Future<void> saveData(Operation operation, {bool followRefs = true, bool lifecycleOnly = false}) => Future.error(StateError('disk full'));
}
