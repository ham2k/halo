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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout.dart';

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

  /// Same idea as [tertiaryLight] but derived from `secondary` — used when
  /// the logging panel switches to its "editing an existing QSO" accent
  /// (see `LoggingControls`'s `accentPoloColors`), so the chips keep the
  /// same amount of contrast against their container that they have in the
  /// tertiary ("new QSO") case, instead of blending into it.
  final Color secondaryLight;

  /// app-polo's `styles.colors.devMode` (`lightColors.json`/`darkColors.json`:
  /// `rgb(219,114,4)` light, `rgb(247,161,69)` dark) — the accent applied to
  /// icon/title/description of any dev-mode-only setting, matching that
  /// convention exactly rather than a badge or border.
  final Color devMode;

  /// The active-tab indicator on any TabBar (they all sit on the teal
  /// AppBar/pane color, both brightnesses — see theme.dart's tabBarTheme).
  /// Same value in both variants, like [bands]: unlike every ColorScheme
  /// role, this needs to read the same regardless of brightness, not invert
  /// (ham2k/app-halo-dist#272).
  final Color tabIndicator;

  /// The teal accent for text/icons sitting directly on a surface (a section
  /// title, a selected settings row) — as opposed to [ColorScheme.primary]
  /// itself, which this app uses as a FILL (the AppBar/FAB/status-bar/dock
  /// chrome) paired with the near-white `onPrimary`. `primary`'s dark-mode
  /// value (#006783) is identical to light mode's — ported byte-for-byte from
  /// app-polo's darkColors.json, which never defined a lighter dark-mode
  /// primary either (unlike `secondary`/`tertiary`, which do have real
  /// dark-mode tones) — so as a fill it's fine (still paired with light
  /// onPrimary text), but the same value read directly as foreground text on
  /// the dark surface (#191C1E) is only 2.67:1, well under WCAG AA's 4.5:1.
  /// Lightening `primary` itself would break that AppBar/FAB pairing app-wide,
  /// so this is a separate role instead: unchanged in light mode (already
  /// 6.26:1, no need to touch it), a lighter same-hue teal in dark mode
  /// (6.18:1, in line with `secondary`'s own dark-mode contrast).
  final Color onSurfaceAccent;

  final Map<String, Color> bands;

  const HaLoColors({
    required this.important,
    required this.notice,
    required this.onNotice,
    required this.tertiaryLight,
    required this.secondaryLight,
    required this.devMode,
    required this.tabIndicator,
    required this.onSurfaceAccent,
    required this.bands,
  });

  Color bandColor(String? band) => bands[band] ?? bands['other']!;

  static const light = HaLoColors(
    important: Color(0xFF1AA01A),
    notice: Color(0xFFFCF4A7),
    onNotice: Color(0xFF615C2F),
    tertiaryLight: Color(0xFFE6AB73),
    secondaryLight: Color(0xFF69A9DF),
    devMode: Color(0xFFDB7204),
    tabIndicator: _tabIndicatorBlue,
    onSurfaceAccent: Color(0xFF006783), // = colorScheme.primary; already reads fine here
    bands: _bandColors,
  );

  static const dark = HaLoColors(
    important: Color(0xFF1AC81A),
    notice: Color(0xFF615C2F),
    onNotice: Color(0xFFFCF4A7),
    tertiaryLight: Color(0xFF5D3918),
    secondaryLight: Color(0xFF244462),
    devMode: Color(0xFFF7A145),
    tabIndicator: _tabIndicatorBlue,
    onSurfaceAccent: Color(0xFF00A8D6), // same hue/saturation as primary, lightened
    bands: _bandColors,
  );

  static const _tabIndicatorBlue = Color(0xFFBCE9FF);

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
    Color? secondaryLight,
    Color? devMode,
    Color? tabIndicator,
    Color? onSurfaceAccent,
    Map<String, Color>? bands,
  }) {
    return HaLoColors(
      important: important ?? this.important,
      notice: notice ?? this.notice,
      onNotice: onNotice ?? this.onNotice,
      tertiaryLight: tertiaryLight ?? this.tertiaryLight,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      devMode: devMode ?? this.devMode,
      tabIndicator: tabIndicator ?? this.tabIndicator,
      onSurfaceAccent: onSurfaceAccent ?? this.onSurfaceAccent,
      bands: bands ?? this.bands,
    );
  }

  @override
  HaLoColors lerp(HaLoColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);

  static HaLoColors of(BuildContext context) =>
      Theme.of(context).extension<HaLoColors>() ?? light;
}

/// [context] is unused now but kept so every call site doesn't need editing
/// if a context-dependent tweak (e.g. platform-specific tracking) is needed
/// later.
///
/// Font size is deliberately left unscaled here — every `Text` widget this
/// style feeds into already applies the ambient `MediaQuery.textScalerOf`
/// once on its own (Flutter's default), same as every other text style in
/// the app (`buildHaLoTheme`'s `textTheme` is never manually pre-scaled
/// either). Pre-multiplying by the scaler here used to double-apply it —
/// once here, once again when `Text` resolved its effective scaler — so
/// mono text grew quadratically with the font-scale setting instead of
/// linearly like the rest of the UI.
TextStyle haloMonoStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: fontSize ?? 14.0,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: _tabularFigures,
  );
}

/// The rendered width of [text] in [style], measured the way a `Text` widget
/// actually lays it out: [style] merged onto the ambient `DefaultTextStyle`
/// and scaled by the current `textScaler`. Sizing a fixed column to this keeps
/// it matching what paints — and not clipping under OS/accessibility text
/// scaling. Shared by the QSO list and the spots panel so the two can't drift.
double textWidth(BuildContext context, String text, TextStyle style) =>
    spansWidth(context, [TextSpan(text: text)], style);

/// [textWidth] for a span tree — same ambient-style and text-scaler folding, so
/// a measurement of formatted text can't drift from the plain-text one.
///
/// Returns the intrinsic width: the widest line, as [textWidth] has always
/// measured. [placeholders] must give one entry per `WidgetSpan` in [spans], in
/// tree order — `TextPainter` asserts deep in the framework without them, so
/// the count is checked here where the message can name the caller's mistake.
double spansWidth(
  BuildContext context,
  List<InlineSpan> spans,
  TextStyle? style, {
  List<PlaceholderDimensions> placeholders = const [],
}) {
  assert(() {
    var count = 0;
    void countPlaceholders(InlineSpan span) {
      if (span is PlaceholderSpan) count++;
      span.visitDirectChildren((child) {
        countPlaceholders(child);
        return true;
      });
    }

    for (final span in spans) {
      countPlaceholders(span);
    }
    return count == placeholders.length;
  }(), 'spansWidth needs one PlaceholderDimensions per WidgetSpan, in tree order');

  final merged = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(children: spans, style: merged),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  );
  if (placeholders.isNotEmpty) painter.setPlaceholderDimensions(placeholders);
  try {
    painter.layout();
    return painter.width;
  } finally {
    // Frees the native paragraph rather than leaving it to a GC finalizer —
    // this runs a few times per build of the logging panel.
    painter.dispose();
  }
}

/// Google's Noto Color Emoji, bundled as an app asset (app/pubspec.yaml,
/// app/assets/fonts/NotoColorEmoji.ttf) specifically because Flutter's web
/// renderer (CanvasKit/Skia) does its own text shaping and doesn't fall back
/// to the browser/OS's color emoji font the way plain HTML does — emoji
/// glyphs render as nothing without an explicit bundled color-emoji font.
/// Named here, not just inline on whichever `Text` widget needs it, so the
/// next emoji use in the app (the issue's own "Emoji(s)" name column, still
/// unimplemented) doesn't have to rediscover this requirement from scratch.
const String emojiFontFamily = 'NotoColorEmoji';

/// The pubspec-declared asset path backing [emojiFontFamily], shared so
/// callers that need to load it explicitly (e.g. a boot-time preload)
/// don't duplicate the literal.
const String emojiFontAssetPath = 'assets/fonts/NotoColorEmoji.ttf';

/// A `TextStyle` for rendering a single emoji glyph (e.g. a DXCC entity's
/// flag) at [fontSize] — proportional, not `haloMonoStyle`'s monospace, per
/// the issue's "emoji and name...use a proportional font".
TextStyle emojiStyle({double fontSize = 16}) => TextStyle(fontSize: fontSize, fontFamily: emojiFontFamily);

/// Height cap for dropdown overlays — [DropdownMenu.menuHeight] /
/// [DropdownButton.menuMaxHeight]. Two limits, whichever is smaller: the
/// menu never spans past the app header nor closer to the bottom edge than
/// that same header height, and it never shows more than 10½ entries — the
/// half entry as a there's-more-to-scroll cue. Assumes stock entry rows
/// ([kMinInteractiveDimension] tall); plain logical pixels per
/// docs/design/ui-scaling.md (the `MediaQuery` size is already divided by
/// the UI scale).
double dropdownMenuMaxHeight(BuildContext context) {
  final headerHeight = Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
  final available = MediaQuery.sizeOf(context).height - 2 * headerHeight;
  return available.clamp(kMinInteractiveDimension, kMinInteractiveDimension * 10.5);
}

/// The background for a modal's chrome — a dialog's header/footer bands and a
/// Modal Pane's header — framing the [ColorScheme.surface] content area.
///
/// Deliberately `surfaceContainerHighest`, NOT `surfaceContainerHigh`: this
/// scheme never sets the latter, so it falls back to `surface` itself
/// (#FBFCFE light / #191C1E dark) and banding with it would be invisible.
/// `surfaceContainerHighest` IS set (#DCE4E9 / #40484C) and is the same tone
/// the operation list and count pills already use.
Color haloDialogBandColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

/// The width a plain prompt or confirmation gets — a line or two of text and
/// a couple of buttons. They look stranded stretched to [maxDialogWidth], so
/// that width is opt-in ([HaloDialog.wide]) for dialogs that actually carry
/// content: forms, pickers, filter panels, prose.
const double compactDialogWidth = 400.0;

/// The widest a modal surface may get: a bit roomier than a pane
/// ([idealPaneWidth]) so dialogs with side-by-side fields don't feel cramped,
/// but still far short of a wide window's full width.
const double maxDialogWidth = idealPaneWidth * 1.3;

/// One box every modal surface is held to — plain dialogs ([showHaloDialog])
/// and Modal Panes alike — so they read as one family instead of each sizing
/// itself to its content. Capped at [maxDialogWidth] and at the window height
/// less one and a half header bars, leaving the header and the bottom edge
/// visibly clear. Never negative: a window shorter than that clearance (no
/// native min-size floor on web/Linux; a large font scale divides the logical
/// height further) would otherwise assert on invalid constraints.
BoxConstraints haloDialogConstraints(BuildContext context) {
  final headerHeight = Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
  final maxHeight = math.max(0.0, MediaQuery.sizeOf(context).height - headerHeight * 1.5);
  return BoxConstraints(maxWidth: maxDialogWidth, maxHeight: maxHeight);
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
  final double scale = MediaQuery.textScalerOf(context).scale(1.0);
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    // Much lighter than the label/value — a hint (e.g. a POTA "US-...")
    // must read as a faint format cue, not as if it were an actual value
    // already sitting in the field.
    hintStyle: TextStyle(fontSize: 14 * scale, color: color.withValues(alpha: 0.38)),
    errorText: errorText,
    isDense: true,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    floatingLabelStyle: TextStyle(fontSize: 14 * scale, color: color),
    contentPadding: EdgeInsets.fromLTRB(4 * scale, 6 * scale, 4 * scale, 8 * scale),
    // A focused field's underline reads as black regardless of theme/light
    // vs dark, rather than the default focus-color underline — a plain,
    // high-contrast "you are here" cue that doesn't compete with the
    // surrounding tertiaryContainer tint some fields sit on. Width matches
    // Material's own default focused-border weight (2.0) — overriding
    // focusedBorder at all drops that default back to a plain BorderSide's
    // 1.0, so it has to be restored explicitly here.
    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2.0)),
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
          secondaryContainer: Color(0xFF3E6096),
          onSecondaryContainer: Color(0xFFD4E3FF),
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
          outlineVariant: Color(0xFF283034),
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
      // Every AppBar reads like a windowed title bar, left-aligned next to
      // any leading content — including on mobile (issue #182), which
      // otherwise centers per each platform's own convention.
      centerTitle: false,
      elevation: 0,
      toolbarHeight: 48.0,
      titleSpacing: 4.0,
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
      // A light blue marker reads as a deliberate active-tab indicator
      // against the teal AppBar; the old onPrimary indicator was the same
      // near-white as the label text itself, so it barely registered as its
      // own element (issue #272). HaLoColors.tabIndicator, not a ColorScheme
      // role — onPrimaryContainer looked right in dark mode by coincidence
      // (it's #BCE9FF there) but is a near-black #001F29 in light mode,
      // since that role flips meaning across brightness; this exact blue
      // reads well in both, so it isn't tied to either.
      indicatorColor: (isDark ? HaLoColors.dark : HaLoColors.light).tabIndicator,
      // Default M3 hover/focus/pressed overlays are tuned for a
      // surface-colored bar and read as barely-there on this teal
      // background — a bit more opacity so hovering a tab is actually
      // visible (issue #272).
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
          return colorScheme.onPrimary.withValues(alpha: 0.20);
        }
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.onPrimary.withValues(alpha: 0.16);
        }
        return null;
      }),
      // M3's TabBar paints its own 1px divider below itself by default
      // (colorScheme.outlineVariant) — a stray hairline under a bar that
      // otherwise sits flush against the AppBar/pane color (issue #272).
      dividerHeight: 0,
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
