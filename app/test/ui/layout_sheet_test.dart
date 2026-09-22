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
import 'package:ham2k_logger/services/catalog_service.dart';
import 'package:ham2k_logger/services/extension_info.dart';
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
    //
    // The whole row, not just the plus at its end: the plus is a 24pt target
    // at the far edge of a row the operator is already pointing at.
    await tester.tap(find.text('Map'));
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

      // Without the canDraw check the row would still offer a preview
      // control, and tapping it would open an empty pane — worse than no
      // control at all. The placeholder holds the slot so the titles line up,
      // and a tap on it is a tap on the row.
      expect(find.byKey(LayoutSheet.previewPlaceholderKey), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('a tap on the placeholder adds rather than previews', (tester) async {
      final added = <String>[];
      await tester.pumpWidget(harness(const [LayoutPanelEntry(id: 'clock', title: 'Clock')], onAdd: added.add));

      await tester.tap(find.byKey(LayoutSheet.previewPlaceholderKey));
      await tester.pumpAndSettle();
      expect(added, ['clock']);
      // A preview pane would carry the panel's title a second time.
      expect(find.text('Clock'), findsOneWidget);
    });
  });

  group('extensions that would add panels', () {
    const scratchpad = ExtensionInfo(
      key: 'scratchpad',
      file: 'scratchpad.js',
      core: false,
      name: 'Scratchpad',
      keywords: ['notes'],
    );
    final almanac = CatalogEntry(
      key: 'almanac',
      name: 'Almanac',
      version: '1.0.0',
      sha256: 'a' * 64,
      bundleUrl: Uri.parse('https://catalog.example/almanac.js'),
      keywords: const ['sunrise'],
    );
    final t = AppLocale.en.buildSync();

    Widget offering({
      List<LayoutPanelEntry> available = const [],
      Future<bool> Function(ExtensionInfo)? onEnable,
      Future<bool> Function(CatalogEntry)? onInstall,
      VoidCallback? onSearch,
    }) =>
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: LayoutSheet(
                available: available,
                onAdd: (_) {},
                enableable: const [scratchpad],
                installable: [almanac],
                onSearch: onSearch,
                onEnableExtension: onEnable ?? (_) async => true,
                onInstallExtension: onInstall ?? (_) async => true,
              ),
            ),
          ),
        );

    testWidgets('are offered only for a search that matches them', (tester) async {
      var searches = 0;
      await tester.pumpWidget(offering(onSearch: () => searches++));

      // An unsearched sheet is the operator browsing what they HAVE; listing
      // everything they could enable or download there buries it.
      expect(find.text(t.activitiesView.enableExtension(name: 'Scratchpad')), findsNothing);
      expect(searches, 0, reason: 'opening the sheet asks the catalog nothing');

      await tester.enterText(find.byType(TextField), 'notes');
      await tester.pump();
      expect(find.text(t.activitiesView.enableExtension(name: 'Scratchpad')), findsOneWidget);
      expect(find.text(t.activitiesView.installExtension(name: 'Almanac')), findsNothing);
      expect(searches, greaterThan(0), reason: 'a search is what fetches the catalog');
      // "No panel matches" above an offer of one would contradict it.
      expect(find.text(t.operation.layout.noPanelsMatch), findsNothing);

      await tester.enterText(find.byType(TextField), 'sunrise');
      await tester.pump();
      expect(find.text(t.activitiesView.installExtension(name: 'Almanac')), findsOneWidget);
      expect(find.text(t.activitiesView.enableExtension(name: 'Scratchpad')), findsNothing);
    });

    testWidgets("gaining one lands the search on the extension's panels", (tester) async {
      final enabled = <String>[];
      await tester.pumpWidget(offering(
        // Already in the list, as the host's rebuild would put it: a panel
        // whose title says nothing about the word that found its extension.
        available: const [LayoutPanelEntry(id: 'ext:scratchpad:pad', title: 'Pad', extensionName: 'Scratchpad')],
        onEnable: (info) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          enabled.add(info.key);
          return true;
        },
      ));

      await tester.enterText(find.byType(TextField), 'notes');
      await tester.pump();
      expect(find.text('Pad'), findsNothing);

      await tester.tap(find.text(t.activitiesView.enableExtension(name: 'Scratchpad')));
      await tester.pump();
      // The enable is a runtime restart; rows that just stop answering for
      // those seconds read as a sheet that hung.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(enabled, ['scratchpad']);
      // Left on "notes", the operator would be looking at a list that still
      // does not show what they just enabled.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Scratchpad');
      expect(find.text('Pad'), findsOneWidget);
    });

    testWidgets('a failed or cancelled install leaves the search alone', (tester) async {
      await tester.pumpWidget(offering(onInstall: (_) async => false));

      await tester.enterText(find.byType(TextField), 'sunrise');
      await tester.pump();
      await tester.tap(find.text(t.activitiesView.installExtension(name: 'Almanac')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'sunrise');
    });
  });
}
