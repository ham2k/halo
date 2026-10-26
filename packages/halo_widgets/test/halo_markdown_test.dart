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
