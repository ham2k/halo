// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Fonts are bundled assets, not runtime-fetched (see theme.dart's comment on
// why), so these tests can't render real glyphs in a plain `flutter test`
// environment — they just verify the TextStyle wiring: family names, tabular
// figures on the numeric-heavy styles, and the app-bar title weight matching
// app-polo's "Roboto Slab Black".

import 'dart:math' as math;

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

    test('app bar title is left-aligned, not centered per platform (issue #182)', () {
      // Mobile used to center per each platform's own convention
      // (`!isWindowedPlatform`) — every header now reads like a windowed
      // title bar regardless of platform.
      expect(buildHaLoTheme(Brightness.light).appBarTheme.centerTitle, isFalse);
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
    });

    test('the active-tab indicator is HaLoColors.tabIndicator, the same in both themes (issue #272)', () {
      // Same near-white as the label text made the old onPrimary indicator
      // barely register as its own marker. HaLoColors.tabIndicator, not a
      // ColorScheme role, deliberately — colorScheme.onPrimaryContainer
      // would look right in dark mode (it's #BCE9FF there) but is a
      // near-black #001F29 in light mode, since that role's meaning flips
      // across brightness.
      expect(HaLoColors.light.tabIndicator, HaLoColors.dark.tabIndicator);
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final haloColors = theme.extension<HaLoColors>()!;
        expect(theme.tabBarTheme.indicatorColor, haloColors.tabIndicator);
        expect(theme.tabBarTheme.indicatorColor, isNot(theme.tabBarTheme.labelColor));
      }
    });

    test('tab bar has no built-in bottom divider (issue #272)', () {
      // M3's TabBar paints its own 1px divider below itself by default —
      // a stray hairline under a bar that otherwise sits flush against the
      // AppBar/pane color.
      final theme = buildHaLoTheme(Brightness.light);
      expect(theme.tabBarTheme.dividerHeight, 0);
    });

    test('tab hover/focus/pressed states get a visible overlay on the teal bar (issue #272)', () {
      final theme = buildHaLoTheme(Brightness.light);
      final overlay = theme.tabBarTheme.overlayColor;
      expect(overlay, isNotNull);
      expect(overlay!.resolve({WidgetState.hovered}), isNotNull);
      expect(overlay.resolve({WidgetState.pressed}), isNotNull);
      // Pressed/focused reads more contrasting (higher alpha) than a mere hover.
      expect(
        overlay.resolve({WidgetState.pressed})!.a,
        greaterThan(overlay.resolve({WidgetState.hovered})!.a),
      );
    });
  });

  group('HaLoColors.onSurfaceAccent (dark-mode contrast)', () {
    // WCAG 2.1 relative luminance / contrast ratio (spec formula), so these
    // tests pin an actual accessibility threshold, not just "some color".
    double linear(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    double luminance(Color c) =>
        0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
    double contrast(Color a, Color b) {
      final la = luminance(a), lb = luminance(b);
      final hi = math.max(la, lb), lo = math.min(la, lb);
      return (hi + 0.05) / (lo + 0.05);
    }

    test('light mode is unchanged — same value colorScheme.primary already had', () {
      // Light mode's contrast was already fine (colorScheme.primary vs its
      // surface is ~6.3:1) — no reason to touch what users see there.
      expect(HaLoColors.light.onSurfaceAccent, buildHaLoTheme(Brightness.light).colorScheme.primary);
    });

    test('dark mode is lighter than colorScheme.primary — the reported bug', () {
      final darkScheme = buildHaLoTheme(Brightness.dark).colorScheme;
      // The bug: dark mode's colorScheme.primary was identical to light
      // mode's (#006783), so as foreground text on the dark surface it had
      // only ~2.67:1 contrast — well under WCAG AA's 4.5:1 floor for text.
      expect(contrast(darkScheme.primary, darkScheme.surface), lessThan(3.0));
      // The fix must actually be lighter, not just a different hue.
      expect(HaLoColors.dark.onSurfaceAccent.computeLuminance(), greaterThan(darkScheme.primary.computeLuminance()));
    });

    test('dark mode meets WCAG AA text contrast (4.5:1) against the dark surface', () {
      final darkScheme = buildHaLoTheme(Brightness.dark).colorScheme;
      expect(contrast(HaLoColors.dark.onSurfaceAccent, darkScheme.surface), greaterThanOrEqualTo(4.5));
    });

    test('does not touch colorScheme.primary itself — the AppBar/FAB fill stays exactly as before', () {
      // primary is a FILL color app-wide (AppBar, FAB, status bar, dock
      // chrome), paired with the near-white onPrimary; lightening it directly
      // would've broken that pairing everywhere. onSurfaceAccent is a
      // separate role precisely to avoid that.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        expect(theme.appBarTheme.backgroundColor, theme.colorScheme.primary);
      }
      expect(buildHaLoTheme(Brightness.dark).colorScheme.primary, const Color(0xFF006783));
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
