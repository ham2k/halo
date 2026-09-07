// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Add a Panel sheet's contract: it lists what could go in the view and
// nothing else, says so when there is nothing left to add, and lets an
// operator see what a panel looks like before choosing it. What is already
// in the view is deliberately absent — a pane comes out by being dragged
// onto the delete target, and a second list would be a second place to
// disagree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/operation/layout_sheet.dart';

void main() {
  Widget harness(List<LayoutPanelEntry> available, {void Function(String)? onAdd}) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: LayoutSheet(available: available, onAdd: onAdd)),
        ),
      );

  testWidgets('adding a panel reports which one', (tester) async {
    final added = <String>[];
    await tester.pumpWidget(harness(
      const [LayoutPanelEntry(id: 'spots', title: 'Spots'), LayoutPanelEntry(id: 'map', title: 'Map')],
      onAdd: added.add,
    ));

    expect(find.text('Spots'), findsOneWidget);
    // Without this sheet, Reset Layout is the only way back from a removal —
    // it would undo every other arrangement choice along with it.
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.plus).last);
    expect(added, ['map']);
  });

  testWidgets('search narrows by name AND by description', (tester) async {
    await tester.pumpWidget(harness(
      const [
        LayoutPanelEntry(id: 'wx', title: 'Weather', description: "Conditions where you're operating"),
        LayoutPanelEntry(id: 'clock', title: 'Clock', description: 'UTC and a zone or two'),
      ],
      onAdd: (_) {},
    ));

    await tester.enterText(find.byType(TextField), 'clo');
    await tester.pump();
    expect(find.text('Clock'), findsOneWidget);
    expect(find.text('Weather'), findsNothing);

    // A panel is often easier to describe than to name: an operator hunting
    // for the weather may well type what it shows rather than what it is
    // called, and its own author already wrote that line.
    await tester.enterText(find.byType(TextField), 'conditions');
    await tester.pump();
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Clock'), findsNothing);

    // Two different nothings — a search that matched none of the panels there
    // ARE, and a view that already holds all of them.
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    final t = AppLocale.en.buildSync().operation.layout;
    expect(find.text(t.noPanelsMatch), findsOneWidget);
    expect(find.text(t.nothingToAdd), findsNothing);
  });

  testWidgets('with nothing left to add, it says so', (tester) async {
    await tester.pumpWidget(harness(const [], onAdd: (_) {}));

    // Reachable in the ordinary case — every panel placed, none of them
    // instanceable — and a sheet that drew nothing at all would read as one
    // that failed to load.
    expect(find.byKey(LayoutSheet.availableSectionKey), findsOneWidget);
    expect(find.text(AppLocale.en.buildSync().operation.layout.nothingToAdd), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, MdiIcons.plus), findsNothing);
  });

  group('previews', () {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';

    testWidgets('the thumbnail opens the preview at pane scale', (tester) async {
      await tester.pumpWidget(harness(
        const [LayoutPanelEntry(id: 'wx', title: 'Weather', description: 'Today and tomorrow', preview: svg)],
      ));

      // 40pt says a panel HAS a preview; it does not say what the panel looks
      // like, which is the entire question when choosing one to add.
      final thumbnail = tester.getSize(find.byType(SvgPicture));
      expect(thumbnail.width, 40);

      await tester.tap(find.byType(SvgPicture));
      await tester.pumpAndSettle();

      final opened = tester.getSize(find.byType(SvgPicture).last);
      expect(opened.width, greaterThan(thumbnail.width * 4));
      // The author's own line, shown where the operator is deciding — not
      // just truncated into a subtitle.
      expect(find.text('Today and tomorrow'), findsWidgets);
    });

    testWidgets('a preview that draws nothing offers no tap', (tester) async {
      await tester.pumpWidget(harness(
        // A remote URL: refused outright, since this sheet renders offline
        // and fetching one would beacon on merely opening the panel list.
        const [LayoutPanelEntry(id: 'wx', title: 'Weather', preview: 'https://example.com/wx.png')],
      ));

      // Without the canDraw check the row would still offer a control, and
      // tapping it would open an empty pane — worse than no control at all.
      // Asserted on the slot rather than on an InkWell, which ListTile
      // builds for the row itself regardless.
      expect(tester.widget<ListTile>(find.byType(ListTile)).leading, isNull);
      expect(find.byType(SvgPicture), findsNothing);
    });
  });
}
