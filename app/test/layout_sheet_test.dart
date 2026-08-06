// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The layout setup sheet's contract: it lists the panes that are actually in
// the view, offers a settings control only where a pane has settings, and
// refuses to remove the last one — the dock has no tab left to drag a pane
// back with once it is empty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
