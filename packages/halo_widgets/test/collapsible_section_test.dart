// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one folding section: its caret points right when shut and down when
// open, turning continuously, and every header role folds its body the same
// way — a section heading in a sectioned list included.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget body) => TranslationProvider(
    child: MaterialApp(home: Scaffold(body: body)),
  );

  Widget band({required bool expanded}) =>
      app(CollapsibleSection.band(title: const Text('Icom'), expanded: expanded, onToggle: () {}, child: const Text('rows')));

  double turnsOf(WidgetTester tester, [Finder? within]) => tester
      .widget<AnimatedRotation>(within == null ? find.byType(AnimatedRotation) : find.descendant(of: within, matching: find.byType(AnimatedRotation)))
      .turns;

  testWidgets('points right when shut and down when open', (tester) async {
    // The signs are the trap: `chevronDown` rests pointing DOWN, so the open
    // state is zero turns and the shut one is a NEGATIVE quarter. The
    // positive quarter would point the caret left, at nothing.
    await tester.pumpWidget(band(expanded: false));
    expect(turnsOf(tester), -0.25);

    await tester.pumpWidget(band(expanded: true));
    expect(turnsOf(tester), 0);
  });

  testWidgets('turns between the two rather than swapping glyphs', (tester) async {
    // One rotated glyph, not two icons exchanged: mid-flight the caret has to
    // be somewhere BETWEEN the two angles. Swap the AnimatedRotation for a
    // conditional Icon and this is the assertion that notices.
    await tester.pumpWidget(band(expanded: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(band(expanded: true));
    await tester.pump(collapseDuration ~/ 2);

    final matrix = tester.widget<Transform>(find.descendant(of: find.byType(AnimatedRotation), matching: find.byType(Transform)).first).transform;
    // A quarter turn has a non-zero off-diagonal term; at rest both are zero.
    expect(matrix.entry(0, 1).abs(), greaterThan(0.01), reason: 'the caret is mid-turn, not parked at either end');
  });

  testWidgets('a folding section heading folds the rows after it, and only those', (tester) async {
    // A sectioned list reads its bands out of a flat child list, so the rows
    // a heading folds are whatever follows it up to the next band. A fold
    // that swallowed the next section — or folded nothing — would still show
    // the right caret.
    Widget list({required bool expanded}) => app(
      SectionedListView(
        children: [
          SectionHeader('Radios', expanded: expanded, onTap: () {}),
          const ListTile(title: Text('FT-891')),
          const SectionHeader('Antennas'),
          const ListTile(title: Text('Dipole')),
        ],
      ),
    );

    await tester.pumpWidget(list(expanded: false));
    await tester.pumpAndSettle();
    expect(turnsOf(tester, find.byType(SectionHeader).first), -0.25);
    expect(find.text('FT-891').hitTestable(), findsNothing);
    expect(find.text('Dipole').hitTestable(), findsOneWidget, reason: 'the next section is not part of the fold');

    await tester.pumpWidget(list(expanded: true));
    await tester.pump(collapseDuration ~/ 2);
    final half = tester.getBottomLeft(find.text('Antennas')).dy;
    await tester.pumpAndSettle();
    final open = tester.getBottomLeft(find.text('Antennas')).dy;
    expect(half, lessThan(open), reason: 'the rows open over the fold, not in one frame');
    expect(find.text('FT-891').hitTestable(), findsOneWidget);
    expect(turnsOf(tester, find.byType(SectionHeader).first), 0);
  });
}
