// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two contracts the settings-panel rewrite rests on and nothing else
// checks: a section's heading STAYS while its own rows scroll under it, and
// its rule measures the content it heads rather than the pane.
//
// Both are invisible to a test that only asks whether a widget is present —
// which is what every other settings test does — so they are pinned here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host({required double width, required int sections, required int rowsPerSection}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 400,
            child: ListTileTheme.merge(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Builder(
                builder: (context) => CustomScrollView(
                  slivers: [
                    for (var s = 0; s < sections; s++)
                      SliverMainAxisGroup(slivers: [
                        SectionHeader.pinned(context, 'Section $s', width: width),
                        SliverList.list(children: [
                          for (var r = 0; r < rowsPerSection; r++)
                            ListTile(title: Text('Row $s-$r')),
                        ]),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a band holds the top while its own rows scroll under it', (tester) async {
    await tester.pumpWidget(host(width: 600, sections: 3, rowsPerSection: 8));
    await tester.pumpAndSettle();

    final bandTop = tester.getTopLeft(find.text('Section 0')).dy;
    final firstRowTop = tester.getTopLeft(find.text('Row 0-0')).dy;
    expect(firstRowTop, greaterThan(bandTop));

    // Scroll far enough that the section's first rows are past the top. The
    // band must not have moved: that is what "sticky" means, and a plain
    // SliverToBoxAdapter header would have scrolled away with them.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(find.text('Section 0'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Section 0')).dy, bandTop);
    expect(find.text('Row 0-0'), findsNothing, reason: 'the rows did not actually scroll under the band');
  });

  testWidgets('the next section pushes the previous band off', (tester) async {
    // The other half of the contract: pinned to the whole scroll view rather
    // than to its own group, every band would stack up at the top instead.
    await tester.pumpWidget(host(width: 600, sections: 3, rowsPerSection: 4));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Section 0'), findsNothing);
    expect(find.text('Section 1'), findsOneWidget);
  });

  testWidgets("the rule spans the content, with the title at the rows' own inset", (tester) async {
    await tester.pumpWidget(host(width: 600, sections: 1, rowsPerSection: 2));
    await tester.pumpAndSettle();

    // The heading carries no fill, so its rule is all there is to place: it
    // measures what it heads, ending at the inset the rows' text ends at
    // rather than running to the pane's edges.
    final ruled = find.ancestor(of: find.text('Section 0'), matching: find.byType(Container)).first;
    expect(tester.getSize(ruled).width, 600 - 24 * 2);

    // And its title lands where the rows' own text does — one inset, taken
    // from the ambient ListTileTheme by both.
    expect(
      tester.getTopLeft(find.text('Section 0')).dx,
      tester.getTopLeft(find.text('Row 0-0')).dx,
    );
  });

  testWidgets('a pinned band is measured, not assumed, so a large text scale still fits', (tester) async {
    // heightFor lays the title out rather than guessing: at a scale that wraps
    // it, an assumed extent would clip the second line or leave a gap.
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(host(width: 240, sections: 1, rowsPerSection: 2));
    await tester.pumpAndSettle();

    final ruled = find.ancestor(of: find.text('Section 0'), matching: find.byType(Container)).first;
    final titleHeight = tester.getSize(find.text('Section 0')).height;
    expect(tester.getSize(ruled).height, greaterThanOrEqualTo(titleHeight));
    expect(tester.takeException(), isNull);
  });
}
