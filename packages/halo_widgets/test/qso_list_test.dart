// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
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

  group('score badges', () {
    /// Builds a QSO carrying the given cached `scoring` hook verdicts
    /// (`qso.scores`), without needing a real scoring pass through the JS
    /// runtime — these tests only care how QsoList renders whatever's
    /// cached.
    Qso qsoWithScores(String call, Map<String, dynamic> scores) => Qso(
          uuid: call,
          operationUuid: 'op-1',
          data: {'their': {'call': call}, 'band': '20m', 'mode': 'SSB', 'startAtMillis': 1000},
          scoreCache: jsonEncode(scores),
        );

    testWidgets('duplicate QSO shows a tooltip with the duplicate label', (tester) async {
      final qso = qsoWithScores('W1AW', {
        'dupe': {'value': 0, 'dupe': true, 'alerts': ['duplicate']},
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], qsosRepository: qsos, duplicateLabel: 'Duplicate contact'),
        ),
      ));

      expect(find.byTooltip('Duplicate contact'), findsOneWidget);
    });

    testWidgets('new DXCC entity shows a tooltip with the new-entity label', (tester) async {
      final qso = qsoWithScores('EA4XYZ', {
        'dupe': {'value': 1},
        'dxcc': {'value': 1, 'entityPrefix': 'EA'},
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], qsosRepository: qsos, newEntityLabel: 'New entity!'),
        ),
      ));

      expect(find.byTooltip('New entity!'), findsOneWidget);
    });

    testWidgets('new band/mode notice shows a tooltip with the new-band-or-mode label', (tester) async {
      final qso = qsoWithScores('K2HAM', {
        'dupe': {'value': 1, 'notices': ['newBand']},
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QsoList(qsos: [qso], qsosRepository: qsos, newBandOrModeLabel: 'New band!'),
        ),
      ));

      expect(find.byTooltip('New band!'), findsOneWidget);
    });

    testWidgets('unremarkable or unscored QSOs show no score tooltip', (tester) async {
      final unscored = Qso(
        uuid: 'unscored',
        operationUuid: 'op-1',
        data: {'their': {'call': 'N0CALL'}, 'band': '20m', 'mode': 'SSB', 'startAtMillis': 1000},
      );
      final unremarkable = qsoWithScores('K3XYZ', {
        'dupe': {'value': 1},
        'dxcc': {'value': 0, 'alerts': ['workedBefore']},
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QsoList(
            qsos: [unscored, unremarkable],
            qsosRepository: qsos,
            duplicateLabel: 'Duplicate',
            newEntityLabel: 'New entity',
            newBandOrModeLabel: 'New band or mode',
          ),
        ),
      ));

      expect(find.byTooltip('Duplicate'), findsNothing);
      expect(find.byTooltip('New entity'), findsNothing);
      expect(find.byTooltip('New band or mode'), findsNothing);
    });
  });
}
