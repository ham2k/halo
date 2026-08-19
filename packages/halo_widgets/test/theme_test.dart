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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

// WCAG 2.1 relative luminance / contrast ratio (spec formula), so the color
// tests below pin an actual accessibility threshold, not just "some color".
double _linear(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _luminance(Color c) => 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

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
      // Names the emoji fallback ITSELF, which is redundant for a `Text` (the
      // ambient style supplies it) and load-bearing for a span: this is
      // InlineMarkdownText's codeStyle, and ParagraphBuilder.pushStyle builds
      // the family list from the span's own style, so naming a family replaces
      // the paragraph's list rather than extending it. Without this, an emoji
      // inside backticks in a spot note resolves to nothing on web — silently,
      // and only there. The markdown convention test cannot see this: it
      // resolves style names within a file, and this style lives here.
      expect(style.fontFamilyFallback, contains(emojiFontFamily));
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

    test('every text style falls back to the emoji font, in both brightnesses', () {
      // Roboto has no emoji at all. Without this fallback an emoji anywhere in
      // the app resolves to nothing on web — CanvasKit shapes text itself and
      // never reaches for an OS font — and on Windows to whatever Segoe UI
      // Emoji substitutes, which for a flag is the bare letters "US". The
      // failure is invisible: no error, no log, and correct-looking code.
      //
      // A fallback engages only where the primary font lacks the glyph, so
      // this costs nothing for text that has none.
      for (final brightness in Brightness.values) {
        final t = buildHaLoTheme(brightness).textTheme;
        // Spans the roles emoji actually turn up in: body copy, notice and
        // status titles, list labels, and the large styles an overlay uses.
        final styles = {
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'titleSmall': t.titleSmall,
          'titleMedium': t.titleMedium,
          'labelSmall': t.labelSmall,
          'headlineSmall': t.headlineSmall,
        };
        styles.forEach((name, style) {
          expect(
            style!.fontFamilyFallback,
            contains(emojiFontFamily),
            reason: '$name ($brightness) drops the emoji fallback',
          );
        });

        // AppBar and DefaultTextStyle REPLACE the ambient style rather than
        // merging with it, so this one does not inherit the fallback above —
        // and HaloDialog titles read from it, carrying extension- and
        // notice-authored text whose body markdown already resolves emoji.
        expect(
          buildHaLoTheme(brightness).appBarTheme.titleTextStyle?.fontFamilyFallback,
          contains(emojiFontFamily),
          reason: 'appBarTheme.titleTextStyle ($brightness) drops the emoji fallback',
        );
      }
    });

    // The theme's fallback is only as good as its reach. Every style in the app
    // that names a fontFamily of its own — haloMonoStyle above all, which the
    // QSO list's mono columns and the spots panel build from — depends on
    // `Text` merging onto the ambient DefaultTextStyle to keep it. Nothing in
    // the widget itself says so, so a change to how the theme supplies
    // DefaultTextStyle would drop the fallback from every one of them at once,
    // silently: the glyph just stops painting, on web with no error at all.
    testWidgets('a bare fontFamily style keeps the theme fallback, painted and measured', (tester) async {
      late double spaced;
      late double plain;

      await tester.pumpWidget(MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) => Text('K1ABC', style: haloMonoStyle(context, fontSize: 14)),
              ),
              // Measurement folds in the ambient style for the same reason
              // painting does, and letterSpacing is the probe for it:
              // haloMonoStyle never sets one, so a helper that ignored the
              // ambient style would measure these two identically. Glyph
              // COVERAGE cannot be asserted here at all — the test
              // environment's font maps every codepoint, so a flag measures
              // the same width with the fallback and without it.
              DefaultTextStyle.merge(
                style: const TextStyle(letterSpacing: 8),
                child: Builder(builder: (context) {
                  spaced = textWidth(context, 'K1ABC', haloMonoStyle(context, fontSize: 14));
                  return const SizedBox.shrink();
                }),
              ),
              Builder(builder: (context) {
                plain = textWidth(context, 'K1ABC', haloMonoStyle(context, fontSize: 14));
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ));

      final painted = tester.renderObject<RenderParagraph>(find.byType(RichText).first).text.style!;
      expect(painted.fontFamily, 'RobotoMono', reason: 'the mono family still wins');
      expect(
        painted.fontFamilyFallback,
        contains(emojiFontFamily),
        reason: 'a bare TextStyle lost the ambient emoji fallback — every mono column with it',
      );
      expect(
        spaced,
        greaterThan(plain),
        reason: 'textWidth ignored the ambient style, so it measures without the fallback that paints',
      );
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

    test('repeated calls return the identical cached instance (HALO-77)', () {
      // MaterialApp is rebuilt on every settings change (font scale steps
      // included). A freshly built ThemeData never compares equal to the
      // last one — closure-valued members like tabBarTheme.overlayColor have
      // fresh identity each call — so each rebuild would restart a 200ms
      // AnimatedTheme lerp, and mid-lerp AppBar action icons drop to the
      // default black87 (visible as a dark flicker on the teal header in
      // light mode).
      for (final brightness in Brightness.values) {
        expect(identical(buildHaLoTheme(brightness), buildHaLoTheme(brightness)), isTrue);
      }
    });

    test('app bar icon themes are explicit onPrimary, not the foregroundColor fallback', () {
      // During a genuine theme animation (light↔dark toggle) AppBarTheme.lerp
      // turns two null iconThemes into an empty non-null one, which shadows
      // foregroundColor in AppBar's resolution chain and drops header icons
      // to the default black87 mid-animation. Explicit endpoints lerp
      // onPrimary→onPrimary instead.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        expect(theme.appBarTheme.iconTheme?.color, theme.colorScheme.onPrimary);
        expect(theme.appBarTheme.actionsIconTheme?.color, theme.colorScheme.onPrimary);
      }
    });

    testWidgets('app bar action icons hold onPrimary through every frame of a theme animation (HALO-77)',
        (tester) async {
      final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, themeMode, _) => MaterialApp(
            theme: buildHaLoTheme(Brightness.light),
            darkTheme: buildHaLoTheme(Brightness.dark),
            themeMode: themeMode,
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Home'),
                actions: [
                  IconButton(key: const Key('gear'), icon: const Icon(MdiIcons.cog), onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      Color iconColor() => tester
          .widget<RichText>(find
              .descendant(of: find.byKey(const Key('gear')), matching: find.byType(RichText))
              .first)
          .text
          .style!
          .color!;

      // onPrimary is the same #F0F0F0 in both themes, so even mid-lerp the
      // icon must read as that color — anything darker means the empty
      // lerped iconTheme let the default black87 leak in.
      // ARGB32 comparison: mid-lerp colors are float-rebuilt instances that
      // fail exact Color equality while being the same on-screen color.
      final onPrimary = buildHaLoTheme(Brightness.light).colorScheme.onPrimary.toARGB32();
      expect(iconColor().toARGB32(), onPrimary);
      mode.value = ThemeMode.dark;
      await tester.pump();
      for (var elapsed = 0; elapsed <= 300; elapsed += 16) {
        expect(iconColor().toARGB32(), onPrimary, reason: 'at ${elapsed}ms into the theme animation');
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  });

  group('HaLoColors.notice (the post-it, identical in both brightnesses)', () {
    test('paper and ink are the same colors in light and dark', () {
      // A post-it is a physical metaphor: it does not invert at night.
      // Swapping fill and ink in the dark variant — yellow text on dark
      // olive — reads as an error banner, not a note stuck to the app.
      expect(HaLoColors.dark.notice, HaLoColors.light.notice);
      expect(HaLoColors.dark.onNotice, HaLoColors.light.onNotice);
    });

    test('paper and ink are app-polo\'s eventRow/eventContent pair', () {
      // Pins the ported values themselves — app-polo's eventRow and
      // eventContent, not a hue somebody liked. AnnotationRow starts from the
      // same two colors but blends its paper into the surface, so this is not
      // a claim that the two yellows render alike.
      expect(HaLoColors.light.notice, const Color(0xFFFCF4A7));
      expect(HaLoColors.light.onNotice, const Color(0xFF15140A));
    });

    test('ink on paper clears WCAG AAA (7:1) in both brightnesses', () {
      for (final colors in [HaLoColors.light, HaLoColors.dark]) {
        expect(_contrast(colors.onNotice, colors.notice), greaterThanOrEqualTo(7.0));
      }
    });

    test('the dark theme carries the light post-it, not a surface-derived one', () {
      // HaLoColors.of falls back to `light` when the extension is missing, so
      // asserting on the constants alone would pass even if buildHaLoTheme
      // stopped attaching the dark extension.
      final darkColors = buildHaLoTheme(Brightness.dark).extension<HaLoColors>()!;
      expect(darkColors.notice, const Color(0xFFFCF4A7));
      // The paper must stay far from the dark surface it sits on — a notice
      // that blends into the chrome is not a notice.
      expect(_contrast(darkColors.notice, buildHaLoTheme(Brightness.dark).colorScheme.surface),
          greaterThanOrEqualTo(7.0));
    });
  });

  group('HaLoColors.onSurfaceAccent (dark-mode contrast)', () {
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
      expect(_contrast(darkScheme.primary, darkScheme.surface), lessThan(3.0));
      // The fix must actually be lighter, not just a different hue.
      expect(HaLoColors.dark.onSurfaceAccent.computeLuminance(), greaterThan(darkScheme.primary.computeLuminance()));
    });

    test('dark mode meets WCAG AA text contrast (4.5:1) against the dark surface', () {
      final darkScheme = buildHaLoTheme(Brightness.dark).colorScheme;
      expect(_contrast(HaLoColors.dark.onSurfaceAccent, darkScheme.surface), greaterThanOrEqualTo(4.5));
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

  // Material 3 hands an unstyled TextButton, OutlinedButton,
  // progress indicator and text cursor `colorScheme.primary` as a FOREGROUND
  // on `surface` — a pairing this scheme's dark variant cannot support (see
  // the group above). Each test below pins the WCAG threshold for what the
  // widget actually is, so reverting a theme slot to `primary` fails on the
  // real number rather than merely looking wrong: text/foreground needs
  // 4.5:1, a stroke or an indicator is a non-text UI component at 3:1.
  group('primary-as-foreground on the dark surface (HALO-167)', () {
    // What the disabled/hovered-free resting button actually paints.
    Color? resolveForeground(ButtonStyle? style) =>
        style?.foregroundColor?.resolve(const <WidgetState>{});

    test('a bare TextButton clears AA text contrast in both brightnesses', () {
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final foreground = resolveForeground(theme.textButtonTheme.style);
        expect(foreground, theme.extension<HaLoColors>()!.onSurfaceAccent, reason: '$brightness');
        expect(_contrast(foreground!, theme.colorScheme.surface), greaterThanOrEqualTo(4.5),
            reason: '$brightness');
      }
    });

    test('a dialog footer Cancel is measured on the BAND it sits on, not on surface', () {
      // The motivating case of this whole change, and the one place the
      // obvious background is the wrong one: HaloDialog paints the footer in
      // `surfaceContainerHighest`, not `surface`, so a test that measures
      // `surface` reports 6.18:1 for a button that actually renders at 3.37:1.
      //
      // That is a 2.3x improvement on primary's 1.45:1 and the right direction,
      // but it does NOT reach AA, and this asserts the number that is true
      // rather than the one that flatters. Reaching 4.5:1 on the band needs a
      // lighter `onSurfaceAccent`, which is an app-wide colour decision.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final band = theme.colorScheme.surfaceContainerHighest;
        expect(_contrast(resolveForeground(theme.textButtonTheme.style)!, band),
            greaterThanOrEqualTo(3.0), reason: '$brightness');
      }

      // Light mode's footer already cleared AA and is deliberately untouched
      // (its accent IS primary), so only dark mode moves — and only this far.
      final dark = buildHaLoTheme(Brightness.dark);
      final band = dark.colorScheme.surfaceContainerHighest;
      expect(_contrast(dark.colorScheme.primary, band), lessThan(2.0));
      expect(_contrast(resolveForeground(dark.textButtonTheme.style)!, band), greaterThan(3.0));
      expect(_contrast(resolveForeground(buildHaLoTheme(Brightness.light).textButtonTheme.style)!,
          buildHaLoTheme(Brightness.light).colorScheme.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5));
    });

    test('a bare OutlinedButton clears AA, and its outline clears the 3:1 UI floor', () {
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final surface = theme.colorScheme.surface;
        expect(_contrast(resolveForeground(theme.outlinedButtonTheme.style)!, surface),
            greaterThanOrEqualTo(4.5), reason: '$brightness');

        // Focusing a button must not REDUCE the outline's contrast, which is
        // what M3's default does here: it swaps `outline` grey for `primary`.
        final side = theme.outlinedButtonTheme.style?.side;
        final resting = side!.resolve(const <WidgetState>{})!.color;
        final focused = side.resolve(const {WidgetState.focused})!.color;
        expect(_contrast(focused, surface), greaterThanOrEqualTo(3.0), reason: '$brightness');
        expect(_contrast(focused, surface), greaterThanOrEqualTo(_contrast(resting, surface)),
            reason: '$brightness: focus cue is weaker than the resting outline');

        // The other two states are Material's own, deliberately left alone —
        // overriding `side` at all means restating them.
        expect(resting, theme.colorScheme.outline, reason: '$brightness');
        expect(side.resolve(const {WidgetState.disabled})!.color,
            theme.colorScheme.onSurface.withValues(alpha: 0.12), reason: '$brightness');
      }
    });

    test('progress indicators clear the 3:1 UI floor', () {
      // A spinner is a non-text UI component, and there are ~30 unstyled ones
      // — every "loading" state in settings, sync, exports and the station
      // panel — so this is the difference between a visible spinner and a
      // screen that looks frozen.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        expect(_contrast(theme.progressIndicatorTheme.color!, theme.colorScheme.surface),
            greaterThanOrEqualTo(3.0), reason: '$brightness');
      }
    });

    test('the text cursor clears the 3:1 UI floor', () {
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        expect(_contrast(theme.textSelectionTheme.cursorColor!, theme.colorScheme.surface),
            greaterThanOrEqualTo(3.0), reason: '$brightness');
      }
    });

    test('the selection wash is left to Material, because a lighter one would hurt', () {
      // The trap: `selectionColor` looks like it belongs with the cursor, but
      // a wash is read THROUGH rather than ON, and every dark-mode surface
      // carrying a text field carries LIGHT text — so darkening under it
      // helps and lightening hurts. Moving this to the accent would drop the
      // logging panel's fields, where most of the app's typing happens, from
      // 5.63:1 to 4.05:1: under AA, caused by the "fix".
      final theme = buildHaLoTheme(Brightness.dark);
      expect(theme.textSelectionTheme.selectionColor, isNull);

      final scheme = theme.colorScheme;
      final accent = theme.extension<HaLoColors>()!.onSurfaceAccent;
      for (final background in [scheme.surface, scheme.tertiaryContainer, scheme.secondaryContainer]) {
        final materialWash = Color.alphaBlend(scheme.primary.withValues(alpha: 0.4), background);
        final accentWash = Color.alphaBlend(accent.withValues(alpha: 0.4), background);
        expect(_contrast(scheme.onSurface, materialWash),
            greaterThanOrEqualTo(_contrast(scheme.onSurface, accentWash)),
            reason: 'accent wash would read better than Material\'s on $background');
      }
      // …and Material's own clears AA on the tightest of them.
      expect(
        _contrast(scheme.onSurface,
            Color.alphaBlend(scheme.primary.withValues(alpha: 0.4), scheme.secondaryContainer)),
        greaterThanOrEqualTo(4.5),
      );
    });

    // The ThemeData assertions above can all pass while the theme never
    // reaches a button — these two pump the real widget instead. The pairing
    // is the point of the bug report: Cancel and Save sit side by side in
    // every dialog footer, and Save (a FilledButton, primary as a FILL) was
    // always fine, which is what made Cancel's 2.67:1 obvious in use.
    // The color a label ACTUALLY paints. Not `Text.style`, which is null here
    // — a button's foreground arrives through the DefaultTextStyle its
    // Material installs, so reading the widget's own style would assert
    // null == null and pass no matter what the theme said.
    Color? paintedColor(WidgetTester tester, String label) =>
        tester.renderObject<RenderParagraph>(find.text(label)).text.style?.color;

    testWidgets('a dialog footer\'s Cancel paints the accent, beside an unchanged Save', (tester) async {
      final theme = buildHaLoTheme(Brightness.dark);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: haloDialogFooterRow(
            cancel: TextButton(onPressed: () {}, child: const Text('Cancel')),
            actions: [FilledButton(onPressed: () {}, child: const Text('Save'))],
          ),
        ),
      ));

      expect(paintedColor(tester, 'Cancel'), theme.extension<HaLoColors>()!.onSurfaceAccent);
      // Save is untouched: it uses primary as a BACKGROUND under onPrimary, a
      // pairing with no contrast problem. This anchors the pairing rather than
      // the theme — nothing on this branch can move it, but a filledButtonTheme
      // added later could, and the two buttons sit side by side in every footer.
      expect(paintedColor(tester, 'Save'), theme.colorScheme.onPrimary);
    });

    testWidgets('a call site\'s own foregroundColor still wins over the theme', (tester) async {
      // ButtonStyle resolves widget.style before themeStyleOf, which is what
      // lets the deliberate exceptions survive this change — form_renderer's
      // `destructive` error red and status_bar's `onNotice` ink on the
      // post-it. A theme that overrode them would repaint a Remove button as
      // an ordinary Cancel.
      const destructive = Color(0xFFF79797);
      await tester.pumpWidget(MaterialApp(
        theme: buildHaLoTheme(Brightness.dark),
        home: Scaffold(
          body: TextButton(
            style: TextButton.styleFrom(foregroundColor: destructive),
            onPressed: () {},
            child: const Text('Remove'),
          ),
        ),
      ));

      expect(paintedColor(tester, 'Remove'), destructive);
    });
  });

  group('poloFieldDecoration focus underline (HALO-167)', () {
    testWidgets('is a high-contrast underline in BOTH brightnesses, not a fixed black', (tester) async {
      // A single hardcoded Colors.black satisfies the "plain, high-contrast
      // you-are-here cue" intent only in light mode: on the dark surface
      // (#191C1E) it is black-on-near-black and the focus cue disappears.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        late InputDecoration decoration;
        await tester.pumpWidget(MaterialApp(
          // Keyed per brightness so the second iteration builds a fresh tree.
          // Re-pumping the same one instead swaps the theme UNDER MaterialApp's
          // AnimatedTheme, and the first frame of that lerp still reports the
          // outgoing brightness while carrying the incoming surface — the
          // decoration would be read mid-transition against the wrong surface.
          key: ValueKey(brightness),
          theme: theme,
          home: Builder(builder: (context) {
            decoration = poloFieldDecoration(context, 'Call');
            return const SizedBox();
          }),
        ));

        final side = (decoration.focusedBorder as UnderlineInputBorder).borderSide;
        // BOTH backgrounds a field actually sits on, because the underline's
        // whole rationale is that it works on either: the plain surface, and
        // the tertiaryContainer tint under the logging panel's fields — the
        // one the comment names as the reason not to leave this to Material.
        for (final background in [theme.colorScheme.surface, theme.colorScheme.tertiaryContainer]) {
          expect(_contrast(side.color, background), greaterThanOrEqualTo(3.0),
              reason: '$brightness on $background');
        }
        // Not the theme's focus color either: primary would compete with that
        // tint, which is why this is spelled out rather than left to Material.
        expect(side.color, isNot(theme.colorScheme.primary), reason: '$brightness');
        // Material drops an overridden focusedBorder back to a plain
        // BorderSide's 1.0, so the 2.0 weight has to be restated explicitly.
        expect(side.width, 2.0, reason: '$brightness');
      }
    });

    test('the theme must NOT carry a focusedBorder — it reshapes fields, not just recolors them', () {
      // The tempting fix for the ~8 fields that build their own
      // InputDecoration, and a trap. `focusedBorder` is selected INSTEAD of
      // `border` while focused (`_InputDecoratorState.build`), and
      // `applyDefaults` fills it from the theme on every decoration that
      // didn't set one — so a theme-level underline turns each of those
      // OutlineInputBorder boxes into a bare line on focus, and gives the
      // command bar's `InputBorder.none` field a permanent one.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        expect(theme.inputDecorationTheme.focusedBorder, isNull, reason: '$brightness');

        // The mechanism itself, so this test explains WHY rather than just
        // pinning null: an outlined field must keep its shape when focused.
        const outlined = InputDecoration(labelText: 'Search', border: OutlineInputBorder());
        expect(outlined.applyDefaults(theme.inputDecorationTheme).focusedBorder,
            isNot(isA<UnderlineInputBorder>()), reason: '$brightness');
      }
    });

    test('the focused LABEL is corrected, without flattening disabled or error', () {
      // The label is safe to set at the theme where the border is not — it
      // carries no geometry. But WidgetStateTextStyle.resolveWith cannot
      // return null to defer to Material, so every state it does not name is
      // silently overridden: a disabled field whose label stayed full-strength
      // would no longer read as disabled.
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final scheme = theme.colorScheme;
        Color? at(Set<WidgetState> states) =>
            WidgetStateProperty.resolveAs<TextStyle?>(theme.inputDecorationTheme.floatingLabelStyle, states)?.color;

        expect(at({WidgetState.focused}), theme.extension<HaLoColors>()!.onSurfaceAccent, reason: '$brightness');
        expect(_contrast(at({WidgetState.focused})!, scheme.surface), greaterThanOrEqualTo(4.5),
            reason: '$brightness');
        expect(at({WidgetState.disabled}), scheme.onSurface.withValues(alpha: 0.38), reason: '$brightness');
        expect(at({WidgetState.error}), scheme.error, reason: '$brightness');
        expect(at({WidgetState.error, WidgetState.focused}), scheme.error, reason: '$brightness');
        expect(at(const {}), scheme.onSurfaceVariant, reason: '$brightness');
      }
    });
  });

  group('haloFocusedBorder (HALO-191)', () {
    // The escape hatch from the trap above: a field that builds its own
    // decoration can't take the fix from the theme, so it passes its own
    // border through this instead.

    /// The border the helper hands a field built under [appTheme], optionally
    /// with [pinned] wrapped around it the way an overlay pins its own Theme.
    /// Keyed per call: re-pumping the same MaterialApp swaps the theme under
    /// its AnimatedTheme, and the first lerp frame still reports the outgoing
    /// brightness (see the poloFieldDecoration test above).
    Future<InputBorder> resolve(
      WidgetTester tester,
      InputBorder base, {
      required ThemeData appTheme,
      ThemeData? pinned,
      required String key,
    }) async {
      late InputBorder result;
      Widget probe = Builder(builder: (context) {
        result = haloFocusedBorder(base, context);
        return const SizedBox();
      });
      if (pinned != null) probe = Theme(data: pinned, child: probe);
      await tester.pumpWidget(MaterialApp(key: ValueKey(key), theme: appTheme, home: probe));
      return result;
    }

    testWidgets('recolors without reshaping — the whole reason it takes the base border', (tester) async {
      // Returning haloFocusedInputBorder(...) here would satisfy every color
      // assertion below and still be wrong: a rounded search box would collapse
      // to a bare line the moment it took focus, which is exactly what stopped
      // this being a theme slot.
      final rounded = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
      final focused =
          await resolve(tester, rounded, appTheme: buildHaLoTheme(Brightness.dark), key: 'shape');

      expect(focused, isA<OutlineInputBorder>());
      expect((focused as OutlineInputBorder).borderRadius, rounded.borderRadius);
      // Everything about the shape survives, not just the two fields above.
      expect(focused.copyWith(borderSide: rounded.borderSide), rounded);
    });

    testWidgets('carries the same high-contrast invariant as poloFieldDecoration, in BOTH brightnesses',
        (tester) async {
      for (final brightness in Brightness.values) {
        final theme = buildHaLoTheme(brightness);
        final border =
            await resolve(tester, const OutlineInputBorder(), appTheme: theme, key: 'contrast-$brightness');
        final side = border.borderSide;

        // 3:1 is the non-text-contrast floor a focus indicator has to clear.
        // `primary` is 2.67:1 on the dark surface, which is the defect: a
        // field decorated by hand focused dark teal while the one beside it,
        // decorated by poloFieldDecoration, focused white.
        expect(_contrast(side.color, theme.colorScheme.surface), greaterThanOrEqualTo(3.0),
            reason: '$brightness');
        expect(side.color, isNot(theme.colorScheme.primary), reason: '$brightness');
        // Same restoration as haloFocusedInputBorder: overriding focusedBorder
        // at all drops Material's 2.0 back to a plain BorderSide's 1.0.
        expect(side.width, 2.0, reason: '$brightness');
      }
    });

    testWidgets('follows a PINNED theme, not the app\'s — why this takes a context, not a bool', (tester) async {
      // The onboarding overlay pins itself to the light theme while the app
      // around it may be dark. A brightness resolved above that pin yields
      // white, and a white 2px border on the overlay's white dialog is the
      // focus cue silently disappearing — nothing throws, nothing logs.
      final light = buildHaLoTheme(Brightness.light);
      final border = await resolve(
        tester,
        const OutlineInputBorder(),
        appTheme: buildHaLoTheme(Brightness.dark),
        pinned: light,
        key: 'pinned',
      );

      expect(_contrast(border.borderSide.color, light.colorScheme.surface), greaterThanOrEqualTo(3.0));
      expect(border.borderSide.color, isNot(Colors.white));
    });

    testWidgets('actually reaches the canvas — the slot is honored, not just set', (tester) async {
      // A focusedBorder Material declined to use would pass every assertion
      // above while the field on screen still focused teal. This decoration is
      // the app's search fields' shape exactly (rounded 8, no fill).
      final theme = buildHaLoTheme(Brightness.dark);
      final border = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextField(
              focusNode: node,
              decoration: InputDecoration(
                border: border,
                focusedBorder: haloFocusedBorder(border, context),
              ),
            );
          }),
        ),
      ));
      node.requestFocus();
      await tester.pumpAndSettle();

      // Rounded, so the border paints as an RRect — a plain rect here would
      // mean the shape was lost on the way to the canvas.
      expect(
        find.byType(InputDecorator),
        paints..rrect(color: Colors.white, strokeWidth: 2.0),
      );
      expect(find.byType(InputDecorator), isNot(paints..rrect(color: theme.colorScheme.primary)));
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
