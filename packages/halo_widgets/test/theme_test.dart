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
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('haloMonoStyle', () {
    testWidgets('uses RobotoMono with tabular figures', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          style = haloMonoStyle(context, fontSize: 14, fontWeight: FontWeight.w500);
          return const SizedBox();
        }),
      ));

      expect(style.fontFamily, 'RobotoMono');
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('does not pre-scale fontSize by the ambient text scaler', (tester) async {
      // Every `Text` widget resolves and applies `MediaQuery.textScalerOf`
      // itself by default — pre-multiplying fontSize here as well double-
      // applied the scale factor (mono text grew quadratically with the
      // app's font-scale setting instead of linearly, like the rest of the
      // UI's un-pre-scaled text styles).
      late TextStyle style;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Builder(builder: (context) {
            style = haloMonoStyle(context, fontSize: 14);
            return const SizedBox();
          }),
        ),
      ));

      expect(style.fontSize, 14.0);
    });
  });

  group('buildHaLoTheme', () {
    test('body text styles use Roboto with tabular figures', () {
      final theme = buildHaLoTheme(Brightness.light);
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
      final theme = buildHaLoTheme(Brightness.light);
      expect(theme.appBarTheme.titleTextStyle!.fontFamily, 'RobotoSlab');
      expect(theme.appBarTheme.titleTextStyle!.fontWeight, FontWeight.w900);
    });

    test('dark and light themes both carry the band color extension', () {
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final colors = theme.extension<HaLoColors>();
        expect(colors, isNotNull);
        expect(colors!.bandColor('20m'), isNot(colors.bandColor('40m')));
      }
    });

    test('secondary control row uses the tertiary family, matching app-polo\'s LoggerChip', () {
      // Values computed from app-polo's own formula (lightColors/darkColors
      // tertiary run through Color(...).lighten(1.3).desaturate(0.3) in
      // light mode, .darken(0.6).desaturate(0.1) in dark mode) — see
      // theme.dart's HaLoColors.tertiaryLight doc comment.
      expect(HaLoColors.light.tertiaryLight, const Color(0xFFE6AB73));
      expect(HaLoColors.dark.tertiaryLight, const Color(0xFF5D3918));

      // Dark mode previously had no tertiaryContainer/onTertiaryContainer at
      // all, silently falling back to Material's unrelated default — the
      // whole secondary-control-row background depends on this being set.
      final darkScheme = buildHaLoTheme(Brightness.dark).colorScheme;
      expect(darkScheme.tertiaryContainer, const Color(0xFF8C4F20));
      expect(darkScheme.onTertiaryContainer, const Color(0xFFFFDCC6));
    });

    test('tab bar labels use onPrimary, not Material3\'s primary-on-primary default', () {
      // A TabBar's default M3 selected-label color is colorScheme.primary,
      // which is invisible against this app's teal (primary-colored) AppBar
      // — every TabBar in the app sits inside one.
      final theme = buildHaLoTheme(Brightness.light);
      expect(theme.tabBarTheme.labelColor, theme.colorScheme.onPrimary);
      expect(theme.tabBarTheme.indicatorColor, theme.colorScheme.onPrimary);
    });
  });

  group('haloDialogConstraints', () {
    // Captures the constraints plus the screen/header heights the helper saw,
    // so expectations derive from the same MediaQuery rather than hardcoded
    // numbers. [size] overrides the window via MediaQuery directly.
    Future<(BoxConstraints, double, double)> measure(WidgetTester tester, {Size? size}) async {
      late BoxConstraints constraints;
      late double screenHeight;
      late double headerHeight;
      Widget probe = Builder(builder: (context) {
        constraints = haloDialogConstraints(context);
        screenHeight = MediaQuery.sizeOf(context).height;
        headerHeight = Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
        return const SizedBox.shrink();
      });
      if (size != null) {
        probe = MediaQuery(data: MediaQueryData(size: size), child: probe);
      }
      await tester.pumpWidget(MaterialApp(theme: buildHaLoTheme(Brightness.light), home: probe));
      return (constraints, screenHeight, headerHeight);
    }

    testWidgets('caps width at 30% over a pane and leaves 1.5 header bars of height', (tester) async {
      final (constraints, screenHeight, headerHeight) = await measure(tester);

      expect(constraints.maxWidth, maxDialogWidth);
      expect(maxDialogWidth, idealPaneWidth * 1.3);
      expect(constraints.maxHeight, screenHeight - headerHeight * 1.5);
    });

    testWidgets('never goes negative on a window shorter than the header clearance', (tester) async {
      // No native min-size floor on web/Linux, and a large font scale divides
      // the logical height further — negative constraints would assert.
      final (constraints, _, _) = await measure(tester, size: const Size(400, 40));
      expect(constraints.maxHeight, 0.0);
    });
  });
}
