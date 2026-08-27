// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO row's frequency is a kHz reading, like the spots panel and the
// radio controls: `7,200.5` for 7200.5 kHz, `7,200` for a whole 7.2 MHz.
//
// It is drawn as adjacent Text widgets so the MHz group can be bold and the
// Hz digits smaller, which is exactly what makes it easy to get wrong — the
// marks between those parts are an ordinary thousands separator and an
// ordinary decimal point, and nothing about three separate Texts says so. Use
// one character for both and `7,200.5` becomes `7,200,5` or `7.200.5`, which
// a reader takes for a different frequency entirely.
//
// So these assemble the parts back into the string a person actually sees,
// rather than asserting on any one of them.

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
    // Process-wide — a leak retunes every later suite in this isolate.
    NumberFormatting.instance.reset();
  });

  /// The frequency as one string, reassembled from the Texts the row draws.
  ///
  /// Identified by shape rather than by key: the frequency is the only Row
  /// built entirely of Texts whose joined content is digits and separators.
  String freqAsShown(WidgetTester tester) {
    for (final row in tester.widgetList<Row>(find.byType(Row))) {
      final children = row.children;
      if (children.isEmpty || children.any((c) => c is! Text)) continue;
      final joined = children.cast<Text>().map((t) => t.data ?? '').join();
      if (joined.length >= 4 && RegExp(r'^[0-9.,  ]+$').hasMatch(joined)) return joined;
    }
    fail('no frequency row found');
  }

  Future<void> pumpWithFreq(WidgetTester tester, double freqKHz) async {
    final operation = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
      'freq': freqKHz,
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildHaLoTheme(Brightness.light),
      home: Scaffold(body: QsoList(qsos: [qso], onSelect: (_) {})),
    ));
    await tester.pumpAndSettle();
  }

  group('under period conventions', () {
    testWidgets('a fractional kHz reads as thousands-then-decimal', (tester) async {
      await pumpWithFreq(tester, 7200.5);
      expect(freqAsShown(tester), '7,200.5');
    });

    testWidgets('a whole kHz shows no decimal at all', (tester) async {
      // 7,200,000 Hz. The Hz segment is dropped when no QSO in the operation
      // needs it, so this must not render a trailing separator either.
      await pumpWithFreq(tester, 7200.0);
      expect(freqAsShown(tester), '7,200');
    });

    testWidgets('below a MHz there is no thousands group to show', (tester) async {
      // 630m. `0,472` is not a reading anyone writes, and the kHz part is
      // zero-filled to three digits precisely because it normally follows a
      // thousands mark.
      await pumpWithFreq(tester, 472.5);
      expect(freqAsShown(tester), '472.5');
    });

    testWidgets('past a GHz, the MHz part is grouped too', (tester) async {
      // 1296 MHz is 1,296,000 kHz — the part carrying whole MHz needs its own
      // separator, or it reads `1296,000`.
      await pumpWithFreq(tester, 1296000.0);
      expect(freqAsShown(tester), '1,296,000');
    });
  });

  group('under comma conventions', () {
    testWidgets('both marks swap, and stay different from each other', (tester) async {
      NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
      await pumpWithFreq(tester, 7200.5);
      expect(freqAsShown(tester), '7.200,5');
    });

    testWidgets('a whole kHz keeps its thousands mark', (tester) async {
      NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');
      await pumpWithFreq(tester, 14285.0);
      expect(freqAsShown(tester), '14.285');
    });
  });
}
