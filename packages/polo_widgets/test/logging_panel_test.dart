// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Widget tests drive the keyboard flows; database verification goes through
// tester.runAsync() because drift's futures/timers otherwise sit unresolved
// in testWidgets' FakeAsync zone. Interleaved pumps let widget-initiated
// writes (which start inside the fake zone) run to completion.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

void main() {
  late PoloDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late Operation operation;

  setUp(() async {
    db = PoloDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    operation = await operations.create(stationCall: 'KI2D');
  });

  tearDown(() async {
    await db.close();
  });

  Widget host({List<Qso> existing = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: LoggingPanel(operation: operation, qsosRepository: qsos, qsos: existing),
      ),
    );
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

  testWidgets('Enter logs a QSO with mode, band and default RSTs', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(find.widgetWithText(TextField, 'Freq kHz'), '14285');
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

  testWidgets('shows DUPE chip for same call, band and mode', (tester) async {
    final dupe = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(existing: [dupe]));

    await tester.enterText(find.widgetWithText(TextField, 'Freq kHz'), '14285');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    expect(find.text('DUPE'), findsOneWidget);
  });
}
