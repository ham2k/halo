// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Ham2K PoLo visual language, ported from app-polo's style sources
// (src/styles/lightColors.json, darkColors.json, fonts.json, globalStyles.js):
//   • primary teal #006783, secondary blue #005FAF, tertiary orange #964900
//   • Roboto for body text, Roboto Slab (Black, per app-polo's
//     boldTitleFontFamily) for headers, Roboto Mono for QSO data
//   • per-band accent colors for log rows and spots
//
// Fonts are bundled as app assets (variable TTFs from the google/fonts repo,
// declared in app/pubspec.yaml under family names 'Roboto'/'RobotoSlab'/
// 'RobotoMono') rather than fetched via the google_fonts package at runtime —
// PoLo's core use case is a field operation with no connectivity, and a
// network-fetched font silently falling back to the system font on first
// launch would be a bad first impression.
//
// Tabular figures: inspecting the bundled TTFs (fontTools GSUB dump) shows
// Roboto ships both 'pnum' (proportional, its apparent default) and 'tnum'
// (tabular) figure variants, so counts/dates set in plain Roboto need
// `FontFeature.tabularFigures()` to keep digit columns aligned. RobotoMono
// has neither feature — a monospace face has no separate tabular variant to
// select, every glyph including digits is already fixed-width — so the
// feature is a documented no-op there, kept for explicitness in case the
// mono face ever changes.

import 'package:flutter/material.dart';

const _tabularFigures = [FontFeature.tabularFigures()];

/// Extra Ham2K colors that don't fit Material's ColorScheme, including the
/// band color map used to accent QSO rows and spots.
@immutable
class PoloColors extends ThemeExtension<PoloColors> {
  final Color important;
  final Color notice;
  final Color onNotice;
  final Map<String, Color> bands;

  const PoloColors({
    required this.important,
    required this.notice,
    required this.onNotice,
    required this.bands,
  });

  Color bandColor(String? band) => bands[band] ?? bands['other']!;

  static const light = PoloColors(
    important: Color(0xFF1AA01A),
    notice: Color(0xFFFCF4A7),
    onNotice: Color(0xFF615C2F),
    bands: _bandColors,
  );

  static const dark = PoloColors(
    important: Color(0xFF1AC81A),
    notice: Color(0xFF615C2F),
    onNotice: Color(0xFFFCF4A7),
    bands: _bandColors,
  );

  static const Map<String, Color> _bandColors = {
    '160m': Color(0xFFB402CC),
    '80m': Color(0xFF6E20F5),
    '60m': Color(0xFF1E3DEB),
    '40m': Color(0xFF1686F0),
    '30m': Color(0xFF15C2BC),
    '20m': Color(0xFF49C215),
    '17m': Color(0xFFB9D624),
    '15m': Color(0xFFF2F211),
    '12m': Color(0xFFE69119),
    '10m': Color(0xFFE66119),
    '6m': Color(0xFFEB1018),
    '2m': Color(0xFFEB1018),
    '70cm': Color(0xFF7E10EB),
    'other': Color(0xFF000000),
  };

  @override
  PoloColors copyWith({Color? important, Color? notice, Color? onNotice, Map<String, Color>? bands}) {
    return PoloColors(
      important: important ?? this.important,
      notice: notice ?? this.notice,
      onNotice: onNotice ?? this.onNotice,
      bands: bands ?? this.bands,
    );
  }

  @override
  PoloColors lerp(PoloColors? other, double t) => t < 0.5 ? this : (other ?? this);

  static PoloColors of(BuildContext context) =>
      Theme.of(context).extension<PoloColors>() ?? light;
}

TextStyle poloMonoStyle(BuildContext context, {double? fontSize, FontWeight? fontWeight, Color? color}) {
  return TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: _tabularFigures,
  );
}

/// Adds tabular figures to every style in a Roboto [TextTheme] so digit runs
/// (QSO counts, dates) stay aligned — `TextTheme.apply` has no fontFeatures
/// parameter, so each style needs it added explicitly.
TextTheme _withTabularFigures(TextTheme theme) {
  TextStyle? add(TextStyle? style) =>
      style?.copyWith(fontFeatures: [...?style.fontFeatures, ..._tabularFigures]);

  return theme.copyWith(
    displayLarge: add(theme.displayLarge),
    displayMedium: add(theme.displayMedium),
    displaySmall: add(theme.displaySmall),
    headlineLarge: add(theme.headlineLarge),
    headlineMedium: add(theme.headlineMedium),
    headlineSmall: add(theme.headlineSmall),
    titleLarge: add(theme.titleLarge),
    titleMedium: add(theme.titleMedium),
    titleSmall: add(theme.titleSmall),
    bodyLarge: add(theme.bodyLarge),
    bodyMedium: add(theme.bodyMedium),
    bodySmall: add(theme.bodySmall),
    labelLarge: add(theme.labelLarge),
    labelMedium: add(theme.labelMedium),
    labelSmall: add(theme.labelSmall),
  );
}

ThemeData buildPoloTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // Values from app-polo lightColors.json / darkColors.json.
  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: Color(0xFF006783),
          onPrimary: Color(0xFFF0F0F0),
          primaryContainer: Color(0xFF006783),
          onPrimaryContainer: Color(0xFFBCE9FF),
          secondary: Color(0xFF5B9EDE),
          onSecondary: Color(0xFF002B4C),
          tertiary: Color(0xFFD9904C),
          onTertiary: Color(0xFF4C2700),
          error: Color(0xFFF79797),
          onError: Color(0xFF680003),
          surface: Color(0xFF191C1E),
          onSurface: Color(0xFFE1E3E5),
          surfaceContainerHighest: Color(0xFF40484C),
          onSurfaceVariant: Color(0xFFC0C8CD),
          outline: Color(0xFF8A9296),
        )
      : const ColorScheme.light(
          primary: Color(0xFF006783),
          onPrimary: Color(0xFFF0F0F0),
          primaryContainer: Color(0xFFBCE9FF),
          onPrimaryContainer: Color(0xFF001F29),
          secondary: Color(0xFF005FAF),
          onSecondary: Color(0xFFF0F0F0),
          secondaryContainer: Color(0xFFD2E3FC),
          onSecondaryContainer: Color(0xFF001C3A),
          tertiary: Color(0xFF964900),
          onTertiary: Color(0xFFF0F0F0),
          tertiaryContainer: Color(0xFFFFDCC6),
          onTertiaryContainer: Color(0xFF311300),
          error: Color(0xFFFF1A1A),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFFFDAD6),
          onErrorContainer: Color(0xFF410002),
          surface: Color(0xFFFBFCFE),
          onSurface: Color(0xFF191C1E),
          surfaceContainerHighest: Color(0xFFDCE4E9),
          onSurfaceVariant: Color(0xFF40484C),
          outline: Color(0xFF70787D),
          outlineVariant: Color(0xFFDCE6E8),
        );

  final textTheme = _withTabularFigures(ThemeData(brightness: brightness).textTheme.apply(fontFamily: 'Roboto'));

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: [isDark ? PoloColors.dark : PoloColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'RobotoSlab',
        fontSize: 20,
        fontWeight: FontWeight.w900, // "Roboto Slab Black" in app-polo's globalStyles.js
        color: colorScheme.onPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 0.5,
      space: 0.5,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: UnderlineInputBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
