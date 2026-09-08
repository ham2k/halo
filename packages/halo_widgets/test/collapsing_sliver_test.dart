// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The sliver accordion body. What it exists to do that `AnimatedCrossFade`
// cannot: hold SLIVERS — a pinned band among them — while still opening and
// shutting, and keep the State of what it hides.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget host({required bool expanded, ScrollController? controller}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                const PinnedHeaderSliver(child: SizedBox(height: 40, child: Text('Band'))),
                CollapsingSliver(
                  expanded: expanded,
                  child: SliverList.list(
                    children: [for (var i = 0; i < 4; i++) SizedBox(height: 100, child: Text('Row $i'))],
                  ),
                ),
                SliverList.list(children: const [SizedBox(height: 100, child: Text('After'))]),
              ],
            ),
          ),
        ),
      );

  testWidgets('shut, it claims no room — and the rows below sit under the band', (tester) async {
    await tester.pumpWidget(host(expanded: false));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('After')).dy, tester.getBottomLeft(find.text('Band')).dy,
        reason: 'a shut body takes no extent at all');
    // Mounted, though — a category's forms own the FocusNodes and
    // TextEditingControllers the operator is typing into, and unmounting
    // them takes the focus with them.
    expect(find.text('Row 0', skipOffstage: false), findsOneWidget);
  });

  testWidgets('open, it is the sum of its rows', (tester) async {
    await tester.pumpWidget(host(expanded: true));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('After')).dy - tester.getBottomLeft(find.text('Band')).dy, 400);
  });

  testWidgets('it opens over time rather than jumping', (tester) async {
    await tester.pumpWidget(host(expanded: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(expanded: true));

    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getTopLeft(find.text('After')).dy;
    expect(midway, greaterThan(40), reason: 'it has started');
    expect(midway, lessThan(440), reason: 'and has not finished');

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('After')).dy, 440);
  });

  testWidgets('a half-open body clips rather than reflowing what it hides', (tester) async {
    await tester.pumpWidget(host(expanded: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(expanded: true));
    await tester.pump(const Duration(milliseconds: 100));

    // The rows keep their own geometry throughout: the wipe is a clip, so a
    // row that is half out of view is still 100 tall and still starts where
    // it will end up. Laying the child out against the shrinking extent
    // instead would reflow every row on every frame of the animation.
    expect(tester.getSize(find.text('Row 0')).height, 100);
    expect(tester.getTopLeft(find.text('Row 0')).dy, 40);
    expect(tester.getTopLeft(find.text('Row 3')).dy, 340);
  });

  testWidgets('what the wipe has not reached yet does not answer a tap', (tester) async {
    var tapped = <String>[];
    Widget hostWithTaps({required bool expanded}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: CustomScrollView(
                slivers: [
                  CollapsingSliver(
                    expanded: expanded,
                    child: SliverList.list(
                      children: [
                        for (var i = 0; i < 4; i++)
                          GestureDetector(
                            onTap: () => tapped.add('Row $i'),
                            child: SizedBox(height: 100, child: Text('Row $i')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(hostWithTaps(expanded: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(hostWithTaps(expanded: true));
    await tester.pump(const Duration(milliseconds: 60));

    // Below the clip, so off screen — and a row nobody can see must not be
    // reachable, however much of it the child still lays out.
    await tester.tapAt(const Offset(200, 380));
    expect(tapped, isEmpty);

    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 380));
    expect(tapped, ['Row 3']);
  });
}
