// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The accordion's disclosure caret: right when shut, down when open, and a
// continuous turn between the two.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/accordion_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap({required bool expanded}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: AccordionSection(
          title: const Text('Icom'),
          expanded: expanded,
          onToggle: () {},
          headerColor: const Color(0xFFEEEEEE),
          onHeaderColor: const Color(0xFF000000),
          child: const Text('rows'),
        ),
      ),
    ),
  );

  double turnsOf(WidgetTester tester) => tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

  testWidgets('points right when shut and down when open', (tester) async {
    // The signs are the trap: `chevronDown` rests pointing DOWN, so the open
    // state is zero turns and the shut one is a NEGATIVE quarter. The
    // positive quarter would point the caret left, at nothing.
    await tester.pumpWidget(wrap(expanded: false));
    expect(turnsOf(tester), -0.25);

    await tester.pumpWidget(wrap(expanded: true));
    expect(turnsOf(tester), 0);
  });

  testWidgets('turns between the two rather than swapping glyphs', (tester) async {
    // One rotated glyph, not two icons exchanged: mid-flight the caret has to
    // be somewhere BETWEEN the two angles. Swap the AnimatedRotation for a
    // conditional Icon and this is the assertion that notices.
    await tester.pumpWidget(wrap(expanded: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(expanded: true));
    await tester.pump(accordionDuration ~/ 2);

    final matrix = tester.widget<Transform>(find.byType(Transform).first).transform;
    // A quarter turn has a non-zero off-diagonal term; at rest both are zero.
    expect(matrix.entry(0, 1).abs(), greaterThan(0.01), reason: 'the caret is mid-turn, not parked at either end');
  });
}
