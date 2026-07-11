// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  // A wide fixed-width host so each control's chip lands in a predictable
  // horizontal third regardless of chip content width.
  Widget host({
    required List<SecondaryControlSpec> controls,
    required String selectedKey,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SecondaryControlRow(
              controls: controls,
              selectedKey: selectedKey,
              onSelect: (_) {},
            ),
          ),
        ),
      );

  SecondaryControlSpec spec(String key) => SecondaryControlSpec(
        key: key,
        icon: Icons.circle,
        summary: key,
        expandedBuilder: (_) => Text('expanded-$key'),
      );

  // Pads with filler chips ahead of the target chip to push it further
  // right in the 800px-wide row, landing it in the left quarter (<200px),
  // middle half (200-600px), or right quarter (>600px) as needed. Filler
  // counts below are tuned to each zone's boundary for this chip's
  // rendered width.
  List<SecondaryControlSpec> controlsWithTargetAt(String targetKey, {required int fillersBefore}) => [
        for (var i = 0; i < fillersBefore; i++) spec('filler$i'),
        spec(targetKey),
      ];

  testWidgets('a chip in the left quarter aligns its expanded panel left', (tester) async {
    await tester.pumpWidget(host(
      controls: controlsWithTargetAt('target', fillersBefore: 0),
      selectedKey: 'target',
    ));
    await tester.pump();
    await tester.pump();

    final align = tester.widget<Align>(find.ancestor(
      of: find.text('expanded-target'),
      matching: find.byType(Align),
    ));
    expect(align.alignment, Alignment.centerLeft);
  });

  testWidgets('a chip in the middle half centers the expanded panel on the chip itself', (tester) async {
    await tester.pumpWidget(host(
      controls: controlsWithTargetAt('target', fillersBefore: 2),
      selectedKey: 'target',
    ));
    // The panel's own width is only known once it's rendered, so the
    // pill-relative alignment settles a frame later than the chip-height
    // and zone measurements — pump a few extra times for it to land.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    final chipCenter = tester.getCenter(find.widgetWithText(ChoiceChip, 'target')).dx;
    final panelCenter = tester.getCenter(find.text('expanded-target')).dx;
    // Not pixel-exact: the panel's own internal Text isn't necessarily
    // centered within the wider row it renders in, only the Align'd panel
    // container is — a loose tolerance confirms "roughly over the chip"
    // without coupling the test to that internal layout.
    expect(panelCenter, closeTo(chipCenter, 5));
  });

  testWidgets('a chip in the right quarter aligns its expanded panel right', (tester) async {
    await tester.pumpWidget(host(
      controls: controlsWithTargetAt('target', fillersBefore: 9),
      selectedKey: 'target',
    ));
    await tester.pump();
    await tester.pump();

    final align = tester.widget<Align>(find.ancestor(
      of: find.text('expanded-target'),
      matching: find.byType(Align),
    ));
    expect(align.alignment, Alignment.centerRight);
  });
}
