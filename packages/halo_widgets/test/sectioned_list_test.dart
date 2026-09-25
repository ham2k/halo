// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The cut: a flat list of rows with bands among them becomes one pinned
// group per band. What this file exists to catch is the band the cutter
// CANNOT see — buried inside a row-building widget, it leaves its rows under
// the band above, which then pins over content it does not name.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host(List<Widget> children) => MaterialApp(
    home: Scaffold(
      body: SizedBox(height: 400, child: SectionedListView(children: children)),
    ),
  );

  List<Widget> rows(String prefix, int count) => [for (var i = 0; i < count; i++) SizedBox(height: 80, child: Text('$prefix $i'))];

  testWidgets('a band holds the top while the rows that follow it scroll under', (tester) async {
    await tester.pumpWidget(host([const SectionHeader('First'), ...rows('one', 4), const SectionHeader('Second'), ...rows('two', 4)]));
    await tester.pumpAndSettle();

    final firstBand = tester.getTopLeft(find.text('First')).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('First')).dy, firstBand, reason: 'the band held');
    expect(find.text('one 0'), findsNothing, reason: 'while its own rows went under it');
  });

  testWidgets('a band buried inside a row fails loudly rather than pinning over rows it does not name', (tester) async {
    // The trap this list is most likely to be walked into: a panel hands it a
    // widget that carries a heading of its own, the cutter sees one opaque
    // row, and the rows under that heading silently join the section above.
    await tester.pumpWidget(
      host([
        const SectionHeader('First'),
        const Column(children: [SectionHeader('Buried'), SizedBox(height: 80)]),
      ]),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('a widget that must carry its own bands returns SectionedSlivers, and they pin', (tester) async {
    await tester.pumpWidget(
      host([
        const SectionHeader('First'),
        ...rows('one', 2),
        const SectionedSlivers(slivers: [_OwnSections()]),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Pinned at the top of the pane, over its own rows — the band the host
    // never saw, doing what a band the host DID see does.
    expect(tester.getTopLeft(find.text('Own')).dy, lessThan(tester.getTopLeft(find.text('own 4')).dy));
    expect(find.text('First'), findsNothing, reason: 'the section above has been pushed off by this one');
    expect(find.text('own 0'), findsNothing, reason: 'and its own rows scroll under its own band');
  });

  testWidgets('a folding section heading is one control: the title opens it, and the chevron leads the title', (tester) async {
    // The trap: a heading whose only tap target is the chevron makes the
    // operator hunt for a small glyph when the title beside it is the
    // obvious thing to press.
    var taps = 0;
    await tester.pumpWidget(host([SectionHeader('Transceivers', leading: const Icon(Icons.chevron_right), onTap: () => taps++), ...rows('row', 2)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transceivers'));
    expect(taps, 1);
    expect(tester.getTopLeft(find.byIcon(Icons.chevron_right)).dx, lessThan(tester.getTopLeft(find.text('Transceivers')).dx));
  });

  testWidgets('a category band carries its row below the title and pins it with the band', (tester) async {
    // The Station panel's current transceiver rides in its band so it stays
    // in view while the rest scrolls; a row that scrolled away under its own
    // band would defeat the point of putting it there.
    await tester.pumpWidget(host([const CategoryBand('Current', below: SizedBox(height: 40, child: Text('the rig'))), ...rows('row', 8)]));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('the rig')).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('the rig')).dy, before, reason: 'pinned with its band');
    expect(find.text('row 0'), findsNothing, reason: 'while the rows under it scrolled away');
  });
}

/// A row-building widget that cuts its own sections — what the peers panel's
/// device list does with the bands it builds from a stream.
class _OwnSections extends StatelessWidget {
  const _OwnSections();

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: sectionSlivers(context, [const SectionHeader('Own'), for (var i = 0; i < 8; i++) SizedBox(height: 80, child: Text('own $i'))]),
  );
}
