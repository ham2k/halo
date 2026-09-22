// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The compact call-info's worked-before pill, app-polo's way: a grey pill in
// the scoring-pill row saying how often the station was worked. Its absence
// is as much the contract as its presence — nothing for a first contact,
// nothing beside a DUPE (which already says it, and louder), and never a pill
// the widget worded itself, since it has no clock to bucket the times by.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host({required CallInfoData data, bool label = true}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: CallInfoSummary(
          data: data,
          foregroundColor: Colors.black,
          iconColor: Colors.black,
          noticeLabel: (key) => key.toUpperCase(),
          workedBeforeLabel: label ? (times) => '${times.length} QSOs' : null,
        ),
      ),
    ),
  );

  Container pillOf(WidgetTester tester, String text) => tester.widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)).first);

  testWidgets('a grey pill in the scoring row, after the notices', (tester) async {
    await tester.pumpWidget(
      host(
        data: const CallInfoData(call: 'W1AW', guess: {'name': 'Hiram Percy'}, noticeKeys: ['newBand'], workedBefore: [1000, 2000, 3000]),
      ),
    );
    expect(find.text('3 QSOs'), findsOneWidget);
    expect((pillOf(tester, '3 QSOs').decoration as BoxDecoration).color, infoGrey);
    expect((pillOf(tester, 'NEWBAND').decoration as BoxDecoration).color, positiveGreen);
    // Name first, then the notice, then the count — all on one line.
    final notice = tester.getTopLeft(find.text('NEWBAND'));
    final pill = tester.getTopLeft(find.text('3 QSOs'));
    final name = tester.getTopLeft(find.text('Hiram Percy'));
    expect(notice.dx, greaterThan(name.dx));
    expect(pill.dx, greaterThan(notice.dx));
    expect((pill.dy - notice.dy).abs(), lessThan(4));
  });

  testWidgets('no pill for a first contact, while unknown, or without a labeller', (tester) async {
    await tester.pumpWidget(
      host(
        data: const CallInfoData(call: 'W1AW', workedBefore: []),
      ),
    );
    expect(find.textContaining('QSO'), findsNothing);

    await tester.pumpWidget(host(data: const CallInfoData(call: 'W1AW')));
    expect(find.textContaining('QSO'), findsNothing);

    await tester.pumpWidget(
      host(
        data: const CallInfoData(call: 'W1AW', workedBefore: [1000]),
        label: false,
      ),
    );
    expect(find.textContaining('QSO'), findsNothing);
  });

  testWidgets('a duplicate alert takes the pill\'s place', (tester) async {
    await tester.pumpWidget(
      host(
        data: const CallInfoData(call: 'W1AW', alertKeys: ['duplicate'], workedBefore: [1000]),
      ),
    );
    expect(find.text('DUPLICATE'), findsOneWidget);
    expect(find.text('1 QSOs'), findsNothing);

    // Any other alert leaves it be.
    await tester.pumpWidget(
      host(
        data: const CallInfoData(call: 'W1AW', alertKeys: ['notInLog'], workedBefore: [1000]),
      ),
    );
    expect(find.text('1 QSOs'), findsOneWidget);
  });

  group('the note\'s marker run', () {
    testWidgets('paints last-emoji-first, split by grapheme, in the emoji font', (tester) async {
      // A ZWJ sequence first: a reversal by code point would tear it apart.
      await tester.pumpWidget(
        host(
          data: const CallInfoData(call: 'W1AW', guess: {'note': '🧑‍💻🍻 Alan - Dev Team'}),
        ),
      );
      expect(find.text('🍻🧑‍💻'), findsOneWidget);
      expect(tester.widget<Text>(find.text('🍻🧑‍💻')).style?.fontFamily, emojiFontFamily);
      expect(find.textContaining('Alan - Dev Team'), findsOneWidget);
    });

    testWidgets('finds every marker the extension reports, the U+23xx block included', (tester) async {
      // ⏰ sits in U+2300–23FF, which the extension's LEADING_EMOJI covers: a
      // narrower range here leaves the QSO row showing a marker this line
      // folds into Roboto prose, where the web renderer paints nothing.
      await tester.pumpWidget(
        host(
          data: const CallInfoData(call: 'W1AW', guess: {'note': '⏰ slow op'}),
        ),
      );
      expect(find.text('⏰'), findsOneWidget);
      expect(find.textContaining('slow op'), findsOneWidget);
    });
  });
}
