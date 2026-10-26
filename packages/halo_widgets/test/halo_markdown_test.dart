// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

const _table = '''
| Band | QSOs |
|------|-----:|
| 20m  | 42   |
''';

Future<void> _pump(WidgetTester tester, {String data = _table, MarkdownStyleSheet Function(MarkdownStyleSheet base)? style}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: HaloMarkdown(data: data, style: style),
    ),
  ),
);

MarkdownStyleSheet _sheet(WidgetTester tester) => tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet!;

/// The alignment flutter_markdown gave the cell holding [text].
TextAlign? _cellAlign(WidgetTester tester, String text) {
  final cell = find.ancestor(of: find.text(text, findRichText: true), matching: find.byType(TableCell));
  return tester.widget<DefaultTextStyle>(find.descendant(of: cell, matching: find.byType(DefaultTextStyle)).first).textAlign;
}

void main() {
  group('tables', () {
    testWidgets('draw no border', (tester) async {
      await _pump(tester);
      final border = tester.widget<Table>(find.byType(Table)).border;
      // Null would not mean "no border": MarkdownBody merges the sheet onto
      // fromTheme's, so a null tableBorder brings the default grid back.
      expect(border, isNotNull);
      for (final side in [border!.top, border.right, border.bottom, border.left, border.horizontalInside, border.verticalInside]) {
        expect(side.style, BorderStyle.none);
      }
    });

    // A full-width table strands a short one's figures at the far edge of a
    // wide pane, away from the labels they belong to.
    testWidgets('take only the width their content needs', (tester) async {
      await _pump(tester);
      expect(tester.getSize(find.byType(Table)).width, lessThan(tester.getSize(find.byType(Scaffold)).width / 2));
    });

    // A table alone is the one block MarkdownBody hands its parent's width
    // unloosened, and a list — the Info and Summaries panes — hands down a
    // tight one, which a Table fills by stretching every column.
    testWidgets('take only the width their content needs under a parent that hands down its whole width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: const [HaloMarkdown(data: _table)]),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Table)).width, lessThan(tester.getSize(find.byType(Scaffold)).width / 2));
    });

    // flutter_markdown puts a table of IntrinsicColumnWidths in a sideways
    // scroll view, where nothing narrows it: the columns past a narrow pane's
    // edge would be out of sight instead of wrapped.
    testWidgets('wrap inside a pane they would overrun, rather than scroll past its edge', (tester) async {
      final long = List.filled(20, 'word').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 200, child: HaloMarkdown(data: '| Band | Note |\n| --- | --- |\n| 20m | $long |')),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.getSize(find.byType(Table)).width, lessThanOrEqualTo(200));
      expect(tester.getSize(find.text(long, findRichText: true)).height, greaterThan(tester.getSize(find.text('20m', findRichText: true)).height));
    });

    // A Table never takes a column below its minimum, and paints the columns
    // that do not fit past its own edge: on a phone-width pane, a band table's
    // last columns would be cut off.
    testWidgets('break their longest words rather than run past a pane too narrow for them', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: HaloMarkdown(data: '| Alphabet | Bravissimo | Charleston | Delectable |\n| --- | --- | --- | --- |\n| 1 | 2 | 3 | 4 |'),
              ),
            ),
          ),
        ),
      );
      expect(tester.getRect(find.text('Delectable', findRichText: true)).right, lessThanOrEqualTo(200));
    });

    testWidgets('pad cells thinly and align them to the top of a row that wraps', (tester) async {
      await _pump(tester);
      expect(tester.widget<Table>(find.byType(Table)).defaultVerticalAlignment, TableCellVerticalAlignment.top);
      final paddings = find.descendant(of: find.byType(TableCell), matching: find.byType(Padding));
      expect(tester.widget<Padding>(paddings.first).padding, const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs));
    });

    testWidgets('align a header left like its cells, unless its column says otherwise', (tester) async {
      await _pump(tester);
      // flutter_markdown centers an unaligned header over left-aligned cells.
      expect(_cellAlign(tester, 'Band'), TextAlign.left);
      expect(_cellAlign(tester, 'QSOs'), TextAlign.right);
    });

    // The reason the house style is the base `style` customises rather than a
    // pass applied after it: a call site that wants a bordered table can have one.
    testWidgets("take a call site's own style over the house one", (tester) async {
      await _pump(tester, style: (base) => base.copyWith(tableBorder: TableBorder.all()));
      expect(tester.widget<Table>(find.byType(Table)).border, TableBorder.all());
    });
  });

  group('the emoji font', () {
    // The test theme names no emoji fallback, unlike the app's, so whatever
    // carries one here got it from HaloMarkdown itself.
    testWidgets('reaches every block style, not just the paragraph', (tester) async {
      await _pump(tester);
      final sheet = _sheet(tester);
      for (final style in [sheet.p, sheet.h1, sheet.strong, sheet.code, sheet.listBullet, sheet.tableHead, sheet.tableBody]) {
        expect(style?.fontFamilyFallback, contains(emojiFontFamily));
      }
    });

    // A hand-built style replaces the theme's outright, fallback and all; the
    // font is added after `style` runs so that a call site cannot drop it.
    testWidgets('survives a style built from scratch', (tester) async {
      await _pump(
        tester,
        data: 'hi',
        style: (base) => base.copyWith(p: const TextStyle(fontSize: 14)),
      );
      expect(_sheet(tester).p?.fontFamilyFallback, contains(emojiFontFamily));
    });
  });
}
