// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Fonts are bundled assets, not runtime-fetched (see theme.dart's comment on
// why), so these tests can't render real glyphs in a plain `flutter test`
// environment — they just verify the TextStyle wiring: family names, tabular
// figures on the numeric-heavy styles, and the app-bar title weight matching
// app-polo's "Roboto Slab Black".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polo_widgets/polo_widgets.dart';

void main() {
  group('poloMonoStyle', () {
    testWidgets('uses RobotoMono with tabular figures', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          style = poloMonoStyle(context, fontSize: 14, fontWeight: FontWeight.w500);
          return const SizedBox();
        }),
      ));

      expect(style.fontFamily, 'RobotoMono');
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('buildPoloTheme', () {
    test('body text styles use Roboto with tabular figures', () {
      final theme = buildPoloTheme(Brightness.light);
      final styles = [
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelLarge,
        theme.textTheme.titleMedium,
      ];
      for (final style in styles) {
        expect(style!.fontFamily, 'Roboto', reason: '$style');
        expect(style.fontFeatures, contains(const FontFeature.tabularFigures()), reason: '$style');
      }
    });

    test('app bar title uses Roboto Slab at Black (w900), matching app-polo', () {
      final theme = buildPoloTheme(Brightness.light);
      expect(theme.appBarTheme.titleTextStyle!.fontFamily, 'RobotoSlab');
      expect(theme.appBarTheme.titleTextStyle!.fontWeight, FontWeight.w900);
    });

    test('dark and light themes both carry the band color extension', () {
      for (final brightness in Brightness.values) {
        final theme = buildPoloTheme(brightness);
        final colors = theme.extension<PoloColors>();
        expect(colors, isNotNull);
        expect(colors!.bandColor('20m'), isNot(colors.bandColor('40m')));
      }
    });
  });
}
