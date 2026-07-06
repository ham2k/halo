// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polo_core/polo_core.dart';
import 'package:polo_widgets/polo_widgets.dart';

void main() {
  late PoloDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() async {
    db = PoloDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('newest QSO renders at the bottom, next to the logging panel', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final second = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QsoList(qsos: [first, second], qsosRepository: qsos),
      ),
    ));

    // The newer QSO (K2HAM) must be visually BELOW the older one (W1AW) —
    // reverse:true plus oldest-first input previously put the oldest QSO
    // at the bottom, the opposite of the intended contest-logger layout.
    final firstY = tester.getCenter(find.text('W1AW')).dy;
    final secondY = tester.getCenter(find.text('K2HAM')).dy;
    expect(secondY, greaterThan(firstY));

    // Row numbers stay chronological (1 = first QSO logged) regardless of
    // where each row renders.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
