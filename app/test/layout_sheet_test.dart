// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The layout setup sheet's contract: it lists the panes that are actually in
// the view, offers a settings control only where a pane has settings, and
// refuses to remove the last one — the dock has no tab left to drag a pane
// back with once it is empty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation/layout_sheet.dart';

void main() {
  Widget harness(
    List<LayoutPanelEntry> panels, {
    List<LayoutPanelEntry> available = const [],
    void Function(String)? onRemove,
    void Function(String)? onAdd,
  }) =>
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: LayoutSheet(panels: panels, available: available, onRemove: onRemove, onAdd: onAdd),
          ),
        ),
      );

  testWidgets('lists the panes in the view, with settings only where they exist', (tester) async {
    var openedFor = '';
    await tester.pumpWidget(harness([
      LayoutPanelEntry(id: 'logging', title: 'QSOs', openSettings: (_) => openedFor = 'logging'),
      const LayoutPanelEntry(id: 'map', title: 'Map'),
    ]));

    expect(find.text('QSOs'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    // One tune button, not two: a pane with nothing to configure shows no
    // control rather than one that opens an empty dialog.
    expect(find.widgetWithIcon(IconButton, MdiIcons.tune), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.tune));
    expect(openedFor, 'logging');
  });

  testWidgets('removing a pane reports which one', (tester) async {
    final removed = <String>[];
    await tester.pumpWidget(harness(
      const [LayoutPanelEntry(id: 'logging', title: 'QSOs'), LayoutPanelEntry(id: 'map', title: 'Map')],
      onRemove: removed.add,
    ));

    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.close).last);
    expect(removed, ['map']);
  });

  testWidgets('a removed pane is offered back under Available panels', (tester) async {
    final added = <String>[];
    await tester.pumpWidget(harness(
      const [LayoutPanelEntry(id: 'logging', title: 'QSOs')],
      available: const [LayoutPanelEntry(id: 'spots', title: 'Spots')],
      onAdd: added.add,
    ));

    // Without this section, Reset Layout is the only way back — it would
    // undo every other arrangement choice along with the removal.
    expect(find.text('Spots'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.plus));
    expect(added, ['spots']);
  });

  testWidgets('nothing removed, no Available section', (tester) async {
    await tester.pumpWidget(harness(
      const [LayoutPanelEntry(id: 'logging', title: 'QSOs'), LayoutPanelEntry(id: 'map', title: 'Map')],
      onAdd: (_) {},
    ));

    // An empty heading reads as a section that failed to load.
    expect(find.byKey(LayoutSheet.panelsSectionKey), findsOneWidget);
    expect(find.byKey(LayoutSheet.availableSectionKey), findsNothing);
    expect(find.widgetWithIcon(IconButton, MdiIcons.plus), findsNothing);
  });

  testWidgets('the only pane in the view offers no remove control', (tester) async {
    await tester.pumpWidget(harness(
      const [LayoutPanelEntry(id: 'logging', title: 'QSOs')],
      onRemove: (_) => fail('the last pane must not be removable'),
    ));

    // The row still renders — it is the view's contents — but without the
    // control that would empty the dock.
    expect(find.text('QSOs'), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, MdiIcons.close), findsNothing);
  });

  group('previews', () {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';

    testWidgets('the thumbnail opens the preview at pane scale', (tester) async {
      await tester.pumpWidget(harness(
        const [LayoutPanelEntry(id: 'wx', title: 'Weather', description: 'Today and tomorrow', preview: svg)],
      ));

      // 40pt says a panel HAS a preview; it does not say what the panel looks
      // like, which is the entire question when adding one from Available
      // Panels.
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
