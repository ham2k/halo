// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Ham2K HaLo visual language, ported from app-polo's style sources
// (src/styles/lightColors.json, darkColors.json, fonts.json, globalStyles.js):
//   • primary teal #006783, secondary blue #005FAF, tertiary orange #964900
//   • Roboto for body text, Roboto Slab (Black, per app-polo's
//     boldTitleFontFamily) for headers, Roboto Mono for QSO data
//   • per-band accent colors for log rows and spots
//
// Fonts are bundled as app assets (variable TTFs from the google/fonts repo,
// declared in app/pubspec.yaml under family names 'Roboto'/'RobotoSlab'/
// 'RobotoMono') rather than fetched via the google_fonts package at runtime —
// HaLo's core use case is a field operation with no connectivity, and a
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

import 'platform_chrome.dart';

const _tabularFigures = [FontFeature.tabularFigures()];

/// Extra Ham2K colors that don't fit Material's ColorScheme, including the
/// band color map used to accent QSO rows and spots.
@immutable
class HaLoColors extends ThemeExtension<HaLoColors> {
  final Color important;
  final Color notice;
  final Color onNotice;

  /// Unselected-chip fill for the secondary control row, matching
  /// app-polo's `LoggerChip` (`${themeColor}Light`, computed there as
  /// `Color(tertiary).lighten(1.3).desaturate(0.3)` in light mode / `.darken
  /// (0.6).desaturate(0.1)` in dark mode — hex values below were computed
  /// with that exact formula, not eyeballed).
  final Color tertiaryLight;

  final Map<String, Color> bands;

  const HaLoColors({
    required this.important,
    required this.notice,
    required this.onNotice,
    required this.tertiaryLight,
    required this.bands,
  });

  Color bandColor(String? band) => bands[band] ?? bands['other']!;

  static const light = HaLoColors(
    important: Color(0xFF1AA01A),
    notice: Color(0xFFFCF4A7),
    onNotice: Color(0xFF615C2F),
    tertiaryLight: Color(0xFFE6AB73),
    bands: _bandColors,
  );

  static const dark = HaLoColors(
    important: Color(0xFF1AC81A),
    notice: Color(0xFF615C2F),
    onNotice: Color(0xFFFCF4A7),
    tertiaryLight: Color(0xFF5D3918),
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
  HaLoColors copyWith({
    Color? important,
    Color? notice,
    Color? onNotice,
    Color? tertiaryLight,
    Map<String, Color>? bands,
  }) {
    return HaLoColors(
      important: important ?? this.important,
      notice: notice ?? this.notice,
      onNotice: onNotice ?? this.onNotice,
      tertiaryLight: tertiaryLight ?? this.tertiaryLight,
      bands: bands ?? this.bands,
    );
  }

  @override
  HaLoColors lerp(HaLoColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);

  static HaLoColors of(BuildContext context) =>
      Theme.of(context).extension<HaLoColors>() ?? light;
}

TextStyle haloMonoStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  final double baseSize = fontSize ?? 14.0;
  final double scaledSize = MediaQuery.textScalerOf(context).scale(baseSize);
  return TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: scaledSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: _tabularFigures,
  );
}

/// Ham2K's compact text-field decoration, used for every text field in the
/// app: the label always floating at the top-left corner (not Material's
/// "large placeholder until focused" default), and tight, consistent
/// padding. [labelColor] defaults to a plain-background-appropriate tone;
/// pass the surrounding container's "on" color explicitly when the field
/// sits on a tinted background (e.g. LoggingControls' tertiaryContainer) —
/// setting floatingLabelStyle at all replaces the ambient
/// InputDecorationTheme's rather than merging with it, so the color has to
/// come along with the rest of the style rather than being left to inherit.
InputDecoration poloFieldDecoration(
  BuildContext context,
  String label, {
  Color? labelColor,
  String? hintText,
  String? errorText,
}) {
  final theme = Theme.of(context);
  final color = labelColor ?? theme.colorScheme.onSurfaceVariant;
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    errorText: errorText,
    isDense: true,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    floatingLabelStyle: TextStyle(fontSize: 14, color: color),
    contentPadding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
  );
}

/// Adds tabular figures to every style in a Roboto [TextTheme] so digit runs
/// (QSO counts, dates) stay aligned — `TextTheme.apply` has no fontFeatures
/// parameter, so each style needs it added explicitly.
TextTheme _withTabularFigures(TextTheme theme) {
  TextStyle? add(TextStyle? style) => style?.copyWith(
    fontFeatures: [...?style.fontFeatures, ..._tabularFigures],
  );

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

ThemeData buildHaLoTheme(Brightness brightness) {
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
          tertiaryContainer: Color(0xFF8C4F20),
          onTertiaryContainer: Color(0xFFFFDCC6),
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

  final textTheme = _withTabularFigures(
    ThemeData(brightness: brightness).textTheme.apply(fontFamily: 'Roboto'),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: [isDark ? HaLoColors.dark : HaLoColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      // Windowed/desktop platforms read like a title bar (left-aligned next
      // to any leading content); mobile fullscreen centers per each
      // platform's own convention.
      centerTitle: !isWindowedPlatform,
      elevation: 0,
      toolbarHeight: 48.0,
      titleSpacing: 8.0,
      titleTextStyle: TextStyle(
        fontFamily: 'RobotoSlab',
        fontSize: 18,
        fontWeight: FontWeight
            .w900, // "Roboto Slab Black" in app-polo's globalStyles.js
        color: colorScheme.onPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
    ),
    // Material3's default TabBar theming assumes a surface-colored bar and
    // sets the selected label to colorScheme.primary — invisible when the
    // bar itself sits inside our teal (primary-colored) AppBar, as every
    // TabBar in this app does.
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.onPrimary,
      unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.7),
      indicatorColor: colorScheme.onPrimary,
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
