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
    // Chips play a brief entrance animation on first appearance — settle it
    // (and the post-frame alignment measurement it delays) before asserting
    // on layout.
    await tester.pumpAndSettle();

    // .first = the nearest Align ancestor (the panel's own alignment
    // wrapper) — SizeTransition, which now wraps the panel, contributes its
    // own internal Align further up.
    final align = tester.widget<Align>(find.ancestor(
      of: find.text('expanded-target'),
      matching: find.byType(Align),
    ).first);
    expect(align.alignment, Alignment.centerLeft);
  });

  testWidgets('a chip in the middle half centers the expanded panel on the chip itself', (tester) async {
    await tester.pumpWidget(host(
      controls: controlsWithTargetAt('target', fillersBefore: 2),
      selectedKey: 'target',
    ));
    // The panel's own width is only known once it's rendered, so the
    // pill-relative alignment settles a frame later than the chip-height
    // and zone measurements — pumpAndSettle also clears the chips'
    // entrance animation, which otherwise leaves them at zero width.
    await tester.pumpAndSettle();

    final chipCenter = tester.getCenter(find.widgetWithText(ChoiceChip, 'target')).dx;
    final panelCenter = tester.getCenter(find.text('expanded-target')).dx;
    // Not pixel-exact: the panel's own internal Text isn't necessarily
    // centered within the wider row it renders in, only the Align'd panel
    // container is — a loose tolerance confirms "roughly over the chip"
    // without coupling the test to that internal layout.
    expect(panelCenter, closeTo(chipCenter, 5));
  });

  testWidgets('a chip near the right edge snaps a too-wide panel to the pill\'s right edge', (tester) async {
    // A panel wide enough that centering it on this right-side (but still
    // fully visible) chip would overflow the row: it should snap so its
    // right edge meets the PILL's right edge, not slide all the way to the
    // row's own right edge.
    final controls = [
      for (var i = 0; i < 3; i++) spec('filler$i'),
      SecondaryControlSpec(
        key: 'target',
        icon: Icons.circle,
        summary: 'target',
        expandedBuilder: (_) => const SizedBox(width: 600, child: Text('expanded-target')),
      ),
    ];
    await tester.pumpWidget(host(controls: controls, selectedKey: 'target'));
    await tester.pumpAndSettle();

    final chipRight = tester.getTopRight(find.widgetWithText(ChoiceChip, 'target')).dx;
    // Preconditions for the scenario this test is about: the pill is fully
    // on screen, and a centered 600px panel would overflow the 800px row.
    expect(chipRight, lessThan(800));
    expect(chipRight - tester.getSize(find.widgetWithText(ChoiceChip, 'target')).width / 2 + 300,
        greaterThan(800));

    final panelRight = tester
        .getTopRight(find.ancestor(
          of: find.text('expanded-target'),
          matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 600),
        ))
        .dx;
    expect(panelRight, closeTo(chipRight, 1));
  });

  testWidgets('reordering the same set of controls is reflected in the chip order', (tester) async {
    await tester.pumpWidget(host(
      controls: [spec('a'), spec('b'), spec('c')],
      selectedKey: 'a',
    ));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('a')).dx, lessThan(tester.getCenter(find.text('b')).dx));
    expect(tester.getCenter(find.text('b')).dx, lessThan(tester.getCenter(find.text('c')).dx));

    // Same three keys, reordered — no addition/removal, just a shuffle
    // (e.g. via the settings dialog's drag-to-reorder list).
    await tester.pumpWidget(host(
      controls: [spec('c'), spec('a'), spec('b')],
      selectedKey: 'a',
    ));
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.text('c')).dx, lessThan(tester.getCenter(find.text('a')).dx));
    expect(tester.getCenter(find.text('a')).dx, lessThan(tester.getCenter(find.text('b')).dx));
  });

  testWidgets('a control that disappears and reappears within the fade window stays visible and tappable', (tester) async {
    String? selected;
    Widget hostWithCallback(List<SecondaryControlSpec> controls) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: SecondaryControlRow(
                controls: controls,
                selectedKey: 'a',
                onSelect: (key) => selected = key,
              ),
            ),
          ),
        );

    await tester.pumpWidget(hostWithCallback([spec('a'), spec('b')]));
    await tester.pumpAndSettle();

    // Drop 'b', then bring it back well before its fade-out would finish —
    // e.g. an activity control flickering off and back on across a couple
    // of rebuilds.
    await tester.pumpWidget(hostWithCallback([spec('a')]));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(hostWithCallback([spec('a'), spec('b')]));
    await tester.pumpAndSettle();

    // Still present (the stale-timer bug this guards against would have
    // force-removed it around the 200ms mark regardless) and tappable (not
    // left behind an `IgnorePointer` meant for a genuinely exiting chip).
    expect(find.text('b'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'b'));
    expect(selected, 'b');
  });

  testWidgets('removing the selected control closes its panel even with the selection left stale', (tester) async {
    // The caller (e.g. the settings dialog hiding a control, or an
    // activity control that stops applying) may drop the selected control
    // from the list WITHOUT clearing selectedKey — the panel must close
    // rather than stay stuck open showing a control that no longer exists.
    await tester.pumpWidget(host(
      controls: [spec('a'), spec('b')],
      selectedKey: 'b',
    ));
    await tester.pumpAndSettle();
    expect(find.text('expanded-b'), findsOneWidget);

    await tester.pumpWidget(host(
      controls: [spec('a')],
      selectedKey: 'b', // stale — still points at the removed control
    ));
    await tester.pumpAndSettle();

    expect(find.text('expanded-b'), findsNothing);
  });

  testWidgets('rapidly alternating between two controls does not crash the panel switcher', (tester) async {
    // Each switch re-enters a control whose outgoing panel may still be
    // mid cross-fade; the generation-stamped keys keep every incoming
    // child distinct from its retiring twin (this used to throw
    // "Duplicate keys found" / duplicate-GlobalKey errors).
    final controls = [spec('a'), spec('b')];
    for (final key in ['a', 'b', 'a', 'b', 'a']) {
      await tester.pumpWidget(host(controls: controls, selectedKey: key));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('expanded-a'), findsOneWidget);
  });

  testWidgets('chips are left-aligned on wider layouts and do not shift to the right when they fit completely', (tester) async {
    final controls = [spec('a'), spec('b')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          child: SecondaryControlRow(
            controls: controls,
            selectedKey: '',
            onSelect: (_) {},
            horizontalBleed: 12.0,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final chipAPosition = tester.getTopLeft(find.widgetWithText(ChoiceChip, 'a')).dx;
    expect(chipAPosition, closeTo(0.0, 1.0));
  });
}
