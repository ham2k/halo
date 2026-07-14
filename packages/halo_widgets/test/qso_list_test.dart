// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

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
        body: QsoList(qsos: [first, second], onSelect: (_) {}),
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

  testWidgets('the divider between rows is a hairline, not Material\'s default 16px-tall spacer', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final second = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'mode': 'SSB',
      'startAtMillis': 2000,
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QsoList(qsos: [first, second], onSelect: (_) {})),
    ));

    expect(tester.getSize(find.byType(Divider)).height, 1);
  });

  testWidgets('event markers render distinctly and are excluded from QSO numbering', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final start = await qsos.addEvent(operation.uuid, kind: 'start', atMillis: 500);
    final first = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    final brk = await qsos.addEvent(operation.uuid, kind: 'break', atMillis: 1500);
    final second = await qsos.add(operation.uuid, {
      'their': {'call': 'K2HAM'},
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    Qso? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QsoList(
          qsos: [start, first, brk, second],
          onSelect: (_) {},
          onSelectEvent: (qso) => tapped = qso,
        ),
      ),
    ));

    expect(find.text('Operation started'), findsOneWidget);
    expect(find.text('Break'), findsOneWidget);
    // Real QSOs still number 1 and 2 — events don't consume a number.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Break'));
    expect(tapped?.uuid, brk.uuid);
  });

  group('frequency', () {
    testWidgets('splits MHz (bold) / kHz, with no Hz segment for a whole-kHz frequency', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074,
        'mode': 'FT8',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {})),
      ));

      expect(find.text('14'), findsOneWidget);
      expect(find.text('074'), findsOneWidget);
      // MHz/kHz separated by exactly one period; no fractional-kHz precision
      // anywhere in the list, so there's no second period for an Hz segment.
      expect(find.text('.'), findsOneWidget);
    });

    testWidgets('shows the mode instead when the QSO has no frequency', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'CW',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {})),
      ));

      expect(find.text('CW'), findsOneWidget);
    });
  });

  group('mode column', () {
    testWidgets('hidden when every QSO uses the same mode', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      // A frequency on both QSOs keeps 'SSB' from also appearing via the
      // no-frequency mode fallback, isolating what's under test here.
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074,
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'freq': 14200,
        'mode': 'SSB',
        'startAtMillis': 2000,
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [first, second], onSelect: (_) {})),
      ));

      // 'SSB' would otherwise render twice (once per row) if the column showed.
      expect(find.text('SSB'), findsNothing);
    });

    testWidgets('shown when the operation mixes modes', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'freq': 14074,
        'mode': 'SSB',
        'startAtMillis': 1000,
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K2HAM'},
        'freq': 7074,
        'mode': 'CW',
        'startAtMillis': 2000,
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [first, second], onSelect: (_) {})),
      ));

      expect(find.text('SSB'), findsOneWidget);
      expect(find.text('CW'), findsOneWidget);
    });
  });

  group('DX/State column', () {
    testWidgets('shows a flag when both entities are known and differ', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G0ABC', 'entityPrefix': 'G', 'flag': '🇬🇧', 'state': 'ignored-when-dx'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K')),
      ));

      expect(find.text('🇬🇧'), findsOneWidget);
      expect(find.text('ignored-when-dx'), findsNothing);
    });

    testWidgets('shows the state when both entities match', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'K2HAM', 'entityPrefix': 'K', 'flag': '🇺🇸', 'state': 'NY'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K')),
      ));

      expect(find.text('NY'), findsOneWidget);
      expect(find.text('🇺🇸'), findsNothing);
    });

    testWidgets('falls back to the state, not a flag, while our own entity is still unresolved', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'G0ABC', 'entityPrefix': 'G', 'flag': '🇬🇧', 'state': 'shown-until-resolved'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(MaterialApp(
        // ourEntityPrefix omitted — mirrors OperationView before its
        // lookupCall(online: false) resolution lands.
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {})),
      ));

      expect(find.text('shown-until-resolved'), findsOneWidget);
      expect(find.text('🇬🇧'), findsNothing);
    });

    testWidgets('a DX contact with a resolved entity but no flag falls back to state instead of going blank', (tester) async {
      // A resolvable entity with no matching flag data (e.g. an edge-case
      // DXCC entity present in lib-country-files but missing from
      // lib-dxcc-data's table) must not be treated the same as "no entity
      // resolved at all" — it's still a known-DX contact, just without a
      // flag glyph, so the row should still show something rather than
      // nothing.
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'XX1ABC', 'entityPrefix': 'XX', 'state': 'fallback-state'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K')),
      ));

      expect(find.text('fallback-state'), findsOneWidget);
    });

    testWidgets('shows nothing when neither a flag nor a state is available', (tester) async {
      final qso = Qso(
        uuid: 'q',
        operationUuid: 'op-1',
        data: {
          'their': {'call': 'N0CALL'},
          'mode': 'SSB',
          'startAtMillis': 1000,
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {}, ourEntityPrefix: 'K')),
      ));

      // Nothing to assert findsOneWidget on — just confirm it doesn't crash
      // and the row still renders the callsign.
      expect(find.text('N0CALL'), findsOneWidget);
    });
  });

  testWidgets('callsign column is sized to fit a deleted QSO\'s callsign too, not just active ones', (tester) async {
    final short = Qso(
      uuid: 'short',
      operationUuid: 'op-1',
      data: {'their': {'call': 'W1AW'}, 'mode': 'SSB', 'startAtMillis': 1000},
    );
    final long = Qso(
      uuid: 'long',
      operationUuid: 'op-1',
      data: {'their': {'call': 'VP8/VERYLONGCALL'}, 'mode': 'SSB', 'startAtMillis': 2000},
      deleted: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QsoList(qsos: [short, long], onSelect: (_) {})),
    ));

    // If the callsign column were sized only from active QSOs (excluding the
    // deleted one), the long deleted callsign would wrap onto a second line,
    // making its Text taller than the short active callsign's.
    final shortHeight = tester.getSize(find.text('W1AW')).height;
    final longHeight = tester.getSize(find.text('VP8/VERYLONGCALL')).height;
    expect(longHeight, shortHeight);
  });

  testWidgets('callsign column stays sized to fit at a larger font-scale setting', (tester) async {
    final qso = Qso(
      uuid: 'q',
      operationUuid: 'op-1',
      data: {'their': {'call': 'VP8/VERYLONGCALL'}, 'mode': 'SSB', 'startAtMillis': 1000},
    );

    // A font-scale setting above 1x (accessibility or the app's own "Larger"
    // preference) must still fit the callsign on one line — the column-width
    // measurement has to apply the same ambient scaling the real Text gets.
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {})),
      ),
    ));

    // A single-line callsign at fontSize 15 * 1.5 scale has a known height
    // ceiling well under two wrapped lines' worth.
    expect(tester.getSize(find.text('VP8/VERYLONGCALL')).height, lessThan(40));
  });

  testWidgets('references show one icon per type, with ×N for repeats of the same type', (tester) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
      'startAtMillis': 1000,
      'refs': [
        {'type': 'pota', 'ref': 'US-1234'},
        {'type': 'pota', 'ref': 'US-5678'},
        {'type': 'sota', 'ref': 'W1/AA-001'},
      ],
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QsoList(
          qsos: [qso],
          onSelect: (_) {},
          activityControls: [
            {'icon': 'pine-tree', 'input': {'refType': 'pota'}},
            {'icon': 'image-filter-hdr', 'input': {'refType': 'sota'}},
          ],
        ),
      ),
    ));

    expect(find.byIcon(resolveIconName('pine-tree')), findsOneWidget);
    expect(find.byIcon(resolveIconName('image-filter-hdr')), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });

  group('show QSO numbers', () {
    testWidgets('hides the number column when disabled', (tester) async {
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {}, showQsoNumbers: false)),
      ));

      expect(find.text('1'), findsNothing);
    });
  });
}
