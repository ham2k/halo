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
import 'package:flutter_markdown/flutter_markdown.dart';

import 'density.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';

const _tabularFigures = [FontFeature.tabularFigures()];

/// Extra Ham2K colors that don't fit Material's ColorScheme, including the
/// band color map used to accent QSO rows and spots.
@immutable
class HaLoColors extends ThemeExtension<HaLoColors> {
  final Color important;

  /// The "post-it" notice card: app-polo's `eventRow` paper
  /// (`rgb(252, 244, 167)`) and its near-black `eventContent` ink
  /// (`rgb(21, 20, 10)`). Identical in both variants, like [tabIndicator] and
  /// [bands]: a post-it that inverts to yellow-on-olive at night stops reading
  /// as a note stuck to the screen and starts reading as an error banner.
  ///
  /// `AnnotationRow` starts from the same two app-polo colors but blends its
  /// paper into the surface (0.85 light, 0.65 dark), so an event row is a
  /// duller yellow than a notice — it tints a row inside a list, where this
  /// is a card overlaid on top of one.
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
  /// role, this needs to read the same regardless of brightness, not invert.
  final Color tabIndicator;

  /// The teal accent for anything that must read AGAINST the surface rather
  /// than be read UPON: text and icons (a section title, a selected settings
  /// row), strokes (the command bar's border), and low-alpha washes (a
  /// selected row's highlight) alike. All three fail on the same fact below,
  /// in both directions — a dark teal is illegible as foreground on a dark
  /// surface, and invisible as a 10%-alpha tint over one.
  ///
  /// As opposed to [ColorScheme.primary]
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

  /// The Spots Panel's "new multiplier" accent — the one flag worth breaking a
  /// run for, so it reads apart from [important]'s green rather than joining it.
  ///
  /// app-polo takes this from `styles.colors.bands['10m']`, which is a coupling
  /// rather than a decision: retuning a band swatch would silently retint an
  /// unrelated accent, and [bands] has no dark-mode variant, so 10m's orange
  /// runs under WCAG AA on the light surface at spot-row size. Same hue as
  /// app-polo, darkened for contrast in light mode and lightened in dark.
  final Color spotMultiplier;

  /// The backdrop a list of records is laid on — the operations list on Home
  /// today. A near-neutral one step off [ColorScheme.surface], not
  /// `surfaceContainerHighest`: that role is the app's dialog/pane BAND
  /// (#DCE4E9), a blue-grey heavy enough to read as chrome, and an empty list
  /// wearing it looks like a panel that failed to load rather than a surface
  /// waiting to be filled.
  ///
  /// Deliberately close to `surface` in both variants: the rows themselves are
  /// `surface`, and this only has to be distinguishable from them where it
  /// shows through below the last one.
  final Color listBackground;

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
    required this.spotMultiplier,
    required this.listBackground,
    required this.bands,
  });

  Color bandColor(String? band) => bands[band] ?? bands['other']!;

  static const light = HaLoColors(
    important: Color(0xFF1AA01A),
    notice: Color(0xFFFCF4A7),
    onNotice: Color(0xFF15140A),
    tertiaryLight: Color(0xFFE6AB73),
    secondaryLight: Color(0xFF69A9DF),
    devMode: Color(0xFFDB7204),
    tabIndicator: _tabIndicatorBlue,
    onSurfaceAccent: Color(0xFF006783), // = colorScheme.primary; already reads fine here
    spotMultiplier: Color(0xFFC2500F), // 10m's hue, darkened to 4.6:1 on the light surface
    listBackground: Color(0xFFF7F8FA), // a hair cooler and darker than surface (#FBFCFE)
    bands: _bandColors,
  );

  static const dark = HaLoColors(
    important: Color(0xFF1AC81A),
    notice: Color(0xFFFCF4A7),
    onNotice: Color(0xFF15140A),
    tertiaryLight: Color(0xFF5D3918),
    secondaryLight: Color(0xFF244462),
    devMode: Color(0xFFF7A145),
    tabIndicator: _tabIndicatorBlue,
    onSurfaceAccent: Color(0xFF00A8D6), // same hue/saturation as primary, lightened
    spotMultiplier: Color(0xFFFF8A4C), // 10m's hue, lightened to 7.3:1 on the dark surface
    listBackground: Color(0xFF1E2224), // the same one-step-off-surface relationship, inverted
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
    Color? spotMultiplier,
    Color? listBackground,
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
      spotMultiplier: spotMultiplier ?? this.spotMultiplier,
      listBackground: listBackground ?? this.listBackground,
      bands: bands ?? this.bands,
    );
  }

  @override
  HaLoColors lerp(HaLoColors? other, double t) => t < 0.5 ? this : (other ?? this);

  /// The fallback follows the ambient brightness rather than always being
  /// [light]: a subtree that loses the extension is exactly where a wrong
  /// answer is invisible, and `light`'s accent on a dark surface is the
  /// 2.67:1 illegibility [onSurfaceAccent] exists to prevent. Unreachable in
  /// the app today — every theme comes from [buildHaLoTheme] — but live in
  /// tests, which mostly pump a bare `MaterialApp`.
  static HaLoColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HaLoColors>() ?? (theme.brightness == Brightness.dark ? dark : light);
  }
}

/// [context] is unused but kept so every call site doesn't need editing
/// if a context-dependent tweak (e.g. platform-specific tracking) is needed
/// later.
///
/// Font size is deliberately left unscaled here — every `Text` widget this
/// style feeds into already applies the ambient `MediaQuery.textScalerOf`
/// once on its own (Flutter's default), same as every other text style in
/// the app (`buildHaLoTheme`'s `textTheme` is never manually pre-scaled
/// either). Pre-multiplying by the scaler here double-applies it —
/// once here, once again when `Text` resolves its effective scaler — so
/// mono text would grow quadratically with the font-scale setting instead
/// of linearly like the rest of the UI.
TextStyle haloMonoStyle(BuildContext context, {double? fontSize, FontWeight? fontWeight, Color? color}) {
  return TextStyle(
    fontFamily: 'RobotoMono',
    // Named here rather than left to the ambient style, because this is used
    // as a SPAN style too (InlineMarkdownText's codeStyle). A span style that
    // names a font family tells the engine it specifies the whole list —
    // ParagraphBuilder.pushStyle builds it from that style alone — so the
    // paragraph's [Roboto, NotoColorEmoji] is replaced by [RobotoMono], and an
    // emoji inside backticks resolves to nothing. As a `Text` style it merges
    // with the ambient one and this is redundant; as a span it is the only
    // thing standing between a flag in a note and a blank.
    fontFamilyFallback: const [emojiFontFamily],
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
double textWidth(BuildContext context, String text, TextStyle style) => spansWidth(context, [TextSpan(text: text)], style);

/// [textWidth] for a span tree — same ambient-style and text-scaler folding, so
/// a measurement of formatted text can't drift from the plain-text one.
///
/// Returns the intrinsic width: the widest line, as [textWidth] has always
/// measured. [placeholders] must give one entry per `WidgetSpan` in [spans], in
/// tree order — `TextPainter` asserts deep in the framework without them, so
/// the count is checked here where the message can name the caller's mistake.
double spansWidth(BuildContext context, List<InlineSpan> spans, TextStyle? style, {List<PlaceholderDimensions> placeholders = const []}) =>
    _layoutSpans(context, spans, style, placeholders: placeholders).width;

/// The rendered height of one line of [spans] in [style] — see [spansWidth]'s
/// doc for the shared ambient-style/text-scaler/placeholder contract.
///
/// [textScaler] overrides the ambient one when given — for a caller that
/// needs the UNSCALED height as a baseline to compare a real measurement
/// against (HALO-209's row-height correction: how much a style's line height
/// actually grows under the current scaler isn't derivable from its
/// unscaled height alone, so both ends of that ratio have to be measured).
double spansHeight(
  BuildContext context,
  List<InlineSpan> spans,
  TextStyle? style, {
  List<PlaceholderDimensions> placeholders = const [],
  TextScaler? textScaler,
}) => _layoutSpans(context, spans, style, placeholders: placeholders, textScaler: textScaler).height;

Size _layoutSpans(
  BuildContext context,
  List<InlineSpan> spans,
  TextStyle? style, {
  List<PlaceholderDimensions> placeholders = const [],
  TextScaler? textScaler,
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
  }(), 'spansWidth/spansHeight need one PlaceholderDimensions per WidgetSpan, in tree order');

  final merged = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: TextSpan(children: spans, style: merged),
    textDirection: TextDirection.ltr,
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
  );
  if (placeholders.isNotEmpty) painter.setPlaceholderDimensions(placeholders);
  try {
    painter.layout();
    return painter.size;
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
/// next emoji use in the app doesn't have to rediscover this requirement
/// from scratch.
const String emojiFontFamily = 'NotoColorEmoji';

/// The pubspec-declared asset path backing [emojiFontFamily], shared so
/// callers that need to load it explicitly (e.g. a boot-time preload)
/// don't duplicate the literal.
const String emojiFontAssetPath = 'assets/fonts/NotoColorEmoji.ttf';

/// A `TextStyle` for rendering a single emoji glyph (e.g. a DXCC entity's
/// flag) at [fontSize] — proportional, not `haloMonoStyle`'s monospace.
TextStyle emojiStyle({double fontSize = 16}) => TextStyle(fontSize: fontSize, fontFamily: emojiFontFamily);

/// [base] with [emojiFontFamily] added as a fallback to every style that can
/// carry running text.
///
/// Any markdown a user or an extension wrote can name a country with its flag,
/// or open with a pictograph. Body text is Roboto, which resolves no emoji at
/// all on web — CanvasKit shapes text itself and never reaches for an OS font
/// — so without the fallback those glyphs are simply absent, with no error and
/// nothing in the log. On Windows the platform substitutes Segoe UI Emoji,
/// which has no flag glyphs and draws the letters "US".
///
/// Takes a whole sheet rather than building one, so it composes with the call
/// sites that style more than paragraphs: applying this LAST is what covers a
/// bespoke `strong` or `listBullet` too.
///
/// Every style is listed individually on purpose: `copyWith(p:)` reaches `li`,
/// `pre` and `table`, which share the `p` style, and NOTHING else — so a flag
/// in a heading or a table cell goes missing while the paragraph beside it
/// renders. `markdown_emoji_font_test.dart` is what keeps a new renderer from
/// skipping this.
MarkdownStyleSheet withEmojiFallback(MarkdownStyleSheet base) {
  // Appends, like _withTabularFigures does with fontFeatures: a style that
  // already names a fallback keeps it, and the emoji font goes last.
  TextStyle? f(TextStyle? style) => style?.copyWith(fontFamilyFallback: [...?style.fontFamilyFallback, emojiFontFamily]);
  return base.copyWith(
    p: f(base.p),
    a: f(base.a),
    code: f(base.code),
    h1: f(base.h1),
    h2: f(base.h2),
    h3: f(base.h3),
    h4: f(base.h4),
    h5: f(base.h5),
    h6: f(base.h6),
    em: f(base.em),
    strong: f(base.strong),
    del: f(base.del),
    blockquote: f(base.blockquote),
    listBullet: f(base.listBullet),
    tableHead: f(base.tableHead),
    tableBody: f(base.tableBody),
  );
}

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

/// The MDI dropdown arrows every [DropdownMenu] (`trailingIcon:` /
/// `selectedTrailingIcon:`) and [DropdownButtonFormField] (`icon:`) must be
/// given — the framework's Icons.arrow_drop_down/up defaults are Material
/// glyphs in an MDI app, and neither widget has a theme slot for the icon,
/// so per-site is the only depth available. Shared here so the glyph choice
/// lives in one place.
const dropdownTrailingIcon = Icon(MdiIcons.menuDown);
const dropdownSelectedTrailingIcon = Icon(MdiIcons.menuUp);

/// The background for a modal's chrome — a dialog's header/footer bands and a
/// Modal Pane's header — framing the [ColorScheme.surface] content area.
///
/// Deliberately `surfaceContainerHighest`, NOT `surfaceContainerHigh`: this
/// scheme never sets the latter, so it falls back to `surface` itself
/// (#FBFCFE light / #191C1E dark) and banding with it would be invisible.
/// `surfaceContainerHighest` IS set (#DCE4E9 / #40484C) and is the same tone
/// the operation list and count pills already use.
Color haloDialogBandColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

/// The modal barrier behind a dialog. In dark mode a black scrim sits on top
/// of an already-dark backdrop, so it barely separates the backdrop from the
/// dialog's own dark surface — a light veil gives the same separation dark
/// mode's raised surfaces already rely on instead. [lightColor] lets each
/// call site keep its own existing light-mode barrier.
Color haloBarrierColor(BuildContext context, {Color lightColor = Colors.black54}) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.30) : lightColor;

/// The drop shadow every modal surface (dialog card, Modal Pane, sheet) casts
/// — same in both brightnesses. `shadowColor` defaults to transparent on both
/// Flutter's own Material 3 [Dialog] and this app's modal surfaces, so none
/// of them casts a shadow without this.
const Color haloDialogShadowColor = Color(0x4D000000);

/// The elevation every modal surface (dialog card, Modal Pane) is raised to.
/// Content that has to match a pane's own banding from the inside must tint
/// itself to the same elevation — see [haloDialogBandColorAt].
const double modalSurfaceElevation = 6.0;

/// [haloDialogBandColor] as it actually PAINTS inside a modal surface: a
/// Material at [modalSurfaceElevation] tints its color by that elevation, so
/// content drawing its own band inside a pane has to apply the same tint or
/// it lands a shade off the pane's own header.
Color haloDialogBandColorAt(BuildContext context) {
  final theme = Theme.of(context);
  return ElevationOverlay.applySurfaceTint(
    theme.dialogTheme.backgroundColor ?? haloDialogBandColor(context),
    theme.colorScheme.surfaceTint,
    modalSurfaceElevation,
  );
}

/// The two tones a sheet that presents a LIST inside a Modal Pane paints
/// with: [haloSheetListBackground] behind everything, [haloSheetRowColor] on
/// each row. Rows have to be opaque — the background shows straight through
/// wherever a section has no row to draw — and both are named here rather
/// than inlined per sheet so two list sheets can't drift a shade apart.
/// Deliberately fixed values, not scheme roles: no role in this scheme sits
/// between `surface` and the band color with enough contrast to separate a
/// row from the space around it.
Color haloSheetListBackground(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141618) : const Color(0xFFF3F4F6);

Color haloSheetRowColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF212426) : Colors.white;

/// A vivid cyan-leaning version of colorScheme.primary (#006783, same hue,
/// lightness pushed up) — the fill for the app's standout action buttons
/// (the home screen's New Operation FAB, the operation sheet's accept
/// button), paired with onPrimary content. Deliberately NOT a ColorScheme
/// role: it must pop against primary-colored chrome and surfaces alike, in
/// both brightnesses.
const Color fabAccentColor = Color(0xFF00B4E6);

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

/// The style a [poloFieldDecoration] label paints at. The label always floats,
/// so there is one style rather than Material's resting/floating pair.
///
/// Public because a field narrow enough to clip its own label has to MEASURE it
/// to decide whether it fits (`mainFieldLabel`), and a measurement taken in a
/// different style than the one that paints is a measurement of nothing.
///
/// Built on the text theme's `bodyLarge`, which is what `InputDecorator`
/// builds a floating label on before merging this over it, so paint and
/// measurement share one base. Without it the measurement inherits the
/// caller's ambient `DefaultTextStyle` instead — `bodyMedium` under a
/// Scaffold, a quarter point of letter spacing tighter per glyph — and every label
/// measures narrower than it paints, and a field sized to the measurement clips
/// it.
TextStyle poloFieldLabelStyle(BuildContext context, {Color? labelColor}) {
  final theme = Theme.of(context);
  return (theme.textTheme.bodyLarge ?? const TextStyle()).merge(
    TextStyle(fontSize: 14 * MediaQuery.textScalerOf(context).scale(1.0), color: labelColor ?? theme.colorScheme.onSurfaceVariant),
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
/// [labelMaxLines] caps the label at that many lines, ellipsizing the rest.
/// Worth setting for any field that can be laid out narrower than its own
/// label: `labelText` renders through a `Text` with **no `maxLines`**, which
/// wraps rather than ellipsizes, and a label on three lines makes the whole
/// decorator that much taller — which for a field in a row means every control
/// beside it moves too. Off by default, so fields with room keep Material's
/// behavior exactly.
InputDecoration poloFieldDecoration(
  BuildContext context,
  String label, {
  Color? labelColor,
  String? hintText,
  String? errorText,
  int? labelMaxLines,

  /// Drops the label slot entirely, for a field whose own surface already
  /// names it (a settings editor dialog, whose title is the field's label).
  ///
  /// Not the same as passing an empty label: an empty one still builds a
  /// label of no text, which keeps its line and the height that comes with
  /// it — which is exactly what the logging row's invisible spacer field
  /// wants, and exactly what a dialog does not.
  bool showLabel = true,
}) {
  final theme = Theme.of(context);
  final color = labelColor ?? theme.colorScheme.onSurfaceVariant;
  final isDarkTheme = theme.brightness == Brightness.dark;
  final double scale = MediaQuery.textScalerOf(context).scale(1.0);
  final labelStyle = poloFieldLabelStyle(context, labelColor: labelColor);
  final metrics = LayoutDensity.metricsOf(context);
  return InputDecoration(
    // Exactly one of these two: InputDecoration asserts on both being set.
    // The style comes from the decorator's own AnimatedDefaultTextStyle either
    // way, so the widget form looks identical to the plain text one.
    labelText: !showLabel || labelMaxLines != null ? null : label,
    label: !showLabel || labelMaxLines == null ? null : Text(label, maxLines: labelMaxLines, overflow: TextOverflow.ellipsis),
    hintText: hintText,
    // Much lighter than the label/value — a hint (e.g. a POTA "US-...")
    // must read as a faint format cue, not as if it were an actual value
    // already sitting in the field.
    hintStyle: TextStyle(fontSize: 14 * scale, color: color.withValues(alpha: 0.38)),
    errorText: errorText,
    isDense: true,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    floatingLabelStyle: labelStyle,
    // Vertical padding is density-resolved; horizontal is not. This pair sets
    // the field's height, and through the fields row's IntrinsicHeight it also
    // sets the submit button's diameter and the information area's minimum
    // height — the single largest term in the logging panel's own height. The
    // horizontal side belongs to the width-concession ladder instead
    // (docs/design/logging-fields.md), which must not gain a second, competing
    // squeeze. The `* scale` is the OS accessibility text scaler, not the app
    // font scale (UiScale already handles that one): padding around text the
    // OS enlarged legitimately grows with it, so density scales the base and
    // the OS scales the result.
    contentPadding: EdgeInsets.fromLTRB(4 * scale, metrics.fieldPaddingTop * scale, 4 * scale, metrics.fieldPaddingBottom * scale),
    focusedBorder: haloFocusedInputBorder(isDarkTheme),
  );
}

/// The focused-field underline: a plain, high-contrast "you are here" cue
/// rather than Material's default focus-color (primary) one, which would
/// compete with the `tertiaryContainer` tint some fields sit on and is barely
/// visible on the dark surface besides. The invariant is the CONTRAST, not the
/// color — near-black in light, near-white in dark. A single fixed black
/// satisfies it only in light mode; on the dark surface (#191C1E) a black
/// underline is the focus cue disappearing.
///
/// Deliberately NOT installed on `inputDecorationTheme` — see the comment
/// there. A theme-level `focusedBorder` reshapes every field that didn't set
/// one, so this can only be applied by a decoration that knows its own border
/// shape. A decoration that builds its own border must therefore pass its own
/// through [haloFocusedBorder]; one that doesn't keeps Material's `primary`
/// indicator, which on the dark surface is 2.67:1.
///
/// Width matches Material's own default focused-border weight (2.0) —
/// overriding `focusedBorder` at all drops that default back to a plain
/// BorderSide's 1.0, so it has to be restored explicitly.
UnderlineInputBorder haloFocusedInputBorder(bool isDark) => UnderlineInputBorder(borderSide: _haloFocusedSide(isDark));

/// [base] recolored to the focus indicator and left otherwise untouched, for
/// the `focusedBorder` of a decoration that builds its own [border].
///
/// Pass the field's own border rather than restating its shape: `focusedBorder`
/// replaces `border` outright while focused (`_InputDecoratorState.build`), so
/// any divergence between the two is the field visibly changing shape as it
/// takes focus. Copying is what makes that impossible.
///
/// Takes a [context] rather than a brightness for the same reason
/// [poloFieldDecoration] does — but note what that does and does not buy. A
/// subtree can pin its own [Theme] (the onboarding overlay pins light), and a
/// context from ABOVE that pin resolves the app's ambient brightness instead:
/// in dark mode that is a white border on a white dialog, invisible, and
/// nothing throws. Passing a context makes the correct thing the natural thing
/// to type; it does not make the incorrect thing impossible. In a method that
/// receives no context of its own, the state's `context` is exactly the
/// ancestor that gets this wrong.
///
/// Only a field with a **visible** border needs this. Material recolors a
/// focused border by copying the field's own shape too, but returns early when
/// `borderSide == BorderSide.none` (`_getDefaultBorder`) — so a border-less
/// field paints no focus indicator at all, in any color, and has nothing here
/// to correct.
InputBorder haloFocusedBorder(InputBorder base, BuildContext context) =>
    base.copyWith(borderSide: _haloFocusedSide(Theme.of(context).brightness == Brightness.dark));

BorderSide _haloFocusedSide(bool isDark) => BorderSide(color: isDark ? Colors.white : Colors.black, width: 2.0);

/// The underline a field wears while its value isn't one its own rules
/// recognize — a contest exchange the rules don't know, a reference that
/// fails its program's pattern.
///
/// A tint rather than an `errorText`: a decorator with an error — even an
/// empty one styled to zero height — still reserves its error slot, making
/// the field 5px taller and, through the logging row's IntrinsicHeight,
/// moving every control and the submit button DOWN as the operator types.
/// A value is invalid for most of the keystrokes it takes to type it, so
/// that would be a jump per QSO.
///
/// [width] takes the same weights as the normal borders — 1 idle, 2 focused,
/// matching Material's own focused default — so the tint costs no layout.
UnderlineInputBorder haloInvalidInputBorder(BuildContext context, {required double width}) => UnderlineInputBorder(
  borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: width),
);

/// Adds tabular figures to every style in a Roboto [TextTheme] so digit runs
/// (QSO counts, dates) stay aligned — `TextTheme.apply` has no fontFeatures
/// parameter, so each style needs it added explicitly.
TextTheme _withTabularFigures(TextTheme theme) {
  TextStyle? add(TextStyle? style) => style?.copyWith(fontFeatures: [...?style.fontFeatures, ..._tabularFigures]);

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

// One cached instance per brightness. MaterialApp rebuilds on every settings
// change (font scale, etc.); handing it a freshly built ThemeData each time
// would start a 200ms AnimatedTheme lerp between two same-valued themes
// (closure-valued members like tabBarTheme.overlayColor never compare equal),
// and mid-lerp AppBarTheme.lerp materializes an empty iconTheme that drops
// AppBar action icons to the default black87 — a visible dark flicker on the
// teal header in light mode (HALO-77). Identical instances make those
// rebuilds theme-animation-free. The cache survives hot reload, so edits to
// this file need a hot restart to show up.
final Map<Brightness, ThemeData> _haloThemeCache = {};

ThemeData buildHaLoTheme(Brightness brightness) => _haloThemeCache[brightness] ??= _buildHaLoTheme(brightness);

ThemeData _buildHaLoTheme(Brightness brightness) {
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

  // Every theme-derived style names the bundled color-emoji font as a
  // fallback, so an emoji anywhere in the app resolves to a glyph.
  //
  // This is NOT invisible to text that already rendered. The bundled Roboto is
  // a 927-codepoint subset, and NotoColorEmoji covers 168 BMP codepoints it
  // lacks — ⌚ ▶ ☀ ⚠ ✅ ✈ ❌ ➡ ⬅ ⭐ among them. Those used to fall through to
  // whatever the platform served, monochrome and in text metrics; this entry
  // jumps that queue, so they now paint as colour bitmaps with emoji metrics,
  // taller and wider on the line. A variation selector does not opt out: VS15
  // asks for text presentation, and a font that only has the colour glyph
  // still wins the fallback. So a symbol used as decoration renders
  // differently, which is why the app uses MDI icons for that job.
  //
  // It reaches further than the styles built from here. `Text` merges its own
  // style onto the ambient DefaultTextStyle, so a bare `TextStyle` that names a
  // fontFamily and leaves fontFamilyFallback null KEEPS this one — haloMonoStyle
  // included, which is why the QSO list's mono columns resolve emoji without
  // naming the font. _layoutSpans folds in the same ambient style, so
  // textWidth/spansWidth measure with the fallback that paints. Only
  // `inherit: false`, which nothing here uses, opts out.
  //
  // Two things escape it. A TextPainter built directly has no widget tree to
  // merge from, so it gets exactly the style it is handed: the emoji-font
  // preload passes emojiStyle deliberately, and the logo title and caution-tape
  // label measure fixed app-authored strings. shrinkToFitText looks like one
  // and is not — it merges the ambient style itself before measuring, which is
  // what keeps the operation titles and extension panel titles it sizes
  // correct, so that merge is load-bearing rather than incidental.
  //
  // The other is a SPAN style that names a font family. ParagraphBuilder
  // .pushStyle builds the family list from that style alone, so naming a
  // family replaces the paragraph's list rather than extending it, and the
  // widget-level merge never enters into it. haloMonoStyle names the fallback
  // itself for exactly this reason.
  //
  // withEmojiFallback is the other half, for markdown: flutter_markdown builds
  // its stylesheet from `theme.textTheme` and inherits this, but a call site
  // that overrides a block style with a hand-built TextStyle replaces it
  // outright. markdown_emoji_font_test.dart is what keeps those covered.
  final textTheme = _withTabularFigures(
    ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: 'Roboto',
      // Replacing rather than appending would silently drop a fallback added
      // later — a CJK face, say — from every style at once.
      fontFamilyFallback: const [emojiFontFamily],
    ),
  );

  final haloColors = isDark ? HaLoColors.dark : HaLoColors.light;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: [haloColors],
    // The app's icon language is MDI; framework widgets default to built-in
    // Icons.* glyphs in a different visual style. These builders re-point
    // the framework's own buttons (including the BackButton an AppBar
    // auto-injects) at MDI. A newly adopted Material widget with a built-in
    // glyph gets the same treatment: an explicit MDI icon, here if it
    // themes, per-site if not — see docs/design/user-interface.md §Icons
    // for the canonical list of widgets needing per-site overrides.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(MdiIcons.arrowLeft),
      closeButtonIconBuilder: (_) => const Icon(MdiIcons.close),
      drawerButtonIconBuilder: (_) => const Icon(MdiIcons.menu),
      endDrawerButtonIconBuilder: (_) => const Icon(MdiIcons.menu),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      // Explicit, not left to the foregroundColor fallback: during a genuine
      // theme animation (light↔dark toggle) AppBarTheme.lerp turns two null
      // iconThemes into an empty non-null one, which shadows foregroundColor
      // in AppBar's resolution chain and drops header icons to the default
      // black87 mid-animation. Real endpoints lerp onPrimary→onPrimary.
      iconTheme: IconThemeData(color: colorScheme.onPrimary),
      actionsIconTheme: IconThemeData(color: colorScheme.onPrimary),
      // Explicit, not left to the foregroundColor fallback: during a genuine
      // theme animation (light↔dark toggle) AppBarTheme.lerp turns two null
      // iconThemes into an empty non-null one, which shadows foregroundColor
      // in AppBar's resolution chain and drops header icons to the default
      // black87 mid-animation. Real endpoints lerp onPrimary→onPrimary.
      // Every AppBar reads like a windowed title bar, left-aligned next to
      // any leading content — including on mobile, which otherwise centers
      // per each platform's own convention.
      centerTitle: false,
      elevation: 0,
      toolbarHeight: 48.0,
      titleSpacing: 4.0,
      titleTextStyle: TextStyle(
        // HaloDialog titles read from here, and they carry extension- and
        // notice-authored text — a notice titled "🇺🇸 US operators" would
        // otherwise render its body's flag and not its title's. AppBar and
        // DefaultTextStyle REPLACE rather than merge, so the textTheme
        // fallback above does not reach this.
        fontFamilyFallback: const [emojiFontFamily],
        fontFamily: 'RobotoSlab',
        fontSize: 18,
        fontWeight: FontWeight.w900, // "Roboto Slab Black" in app-polo's globalStyles.js
        color: colorScheme.onPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: colorScheme.primaryContainer, foregroundColor: colorScheme.onPrimaryContainer),
    // The next four themes all correct the same Material 3 default: an
    // unstyled TextButton, OutlinedButton, progress indicator and text cursor
    // each paint `colorScheme.primary` DIRECTLY ON `surface`, which this
    // scheme's dark variant cannot support — see [HaLoColors.onSurfaceAccent]
    // for why `primary` is a fill color here and what replaces it. Set at the
    // theme rather than per call site because the failing widgets are the ones
    // nobody styled: `FilledButton` (Save) is unaffected, so a dialog's Cancel
    // sitting beside a perfectly legible Save is what makes it obvious.
    //
    // A call site's own `styleFrom` still wins over these PROPERTY BY
    // PROPERTY, not style by style — ButtonStyle resolves widget.style before
    // themeStyleOf, one property at a time. So the deliberate exceptions keep
    // their colors (form_renderer's `destructive` error red, status_bar's
    // `onNotice` ink on the post-it), but a call site that passes a style
    // setting only padding or a background still takes the foreground below.
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: haloColors.onSurfaceAccent)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      // copyWith rather than styleFrom's own `side:`, which takes a single
      // BorderSide for every state — the point here is to change exactly one
      // state and leave the other two as Material has them.
      style: OutlinedButton.styleFrom(foregroundColor: haloColors.onSurfaceAccent).copyWith(
        // Restating `_OutlinedButtonDefaultsM3.side` (Flutter 3.44.6) with
        // only the focused color changed: ButtonStyle resolves a property as
        // a whole, so overriding one state means supplying the other two.
        // Without this, focusing an outlined button in dark mode swaps a
        // clearly visible `outline` grey for a dark teal — a focus cue with
        // LESS contrast than the resting state, which is backwards.
        //
        // Being a copy, it goes stale silently if a future SDK adds a state
        // (the framework already resolves `WidgetState.error` on other
        // properties); the SDK version above is what it was checked against.
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12));
          }
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: haloColors.onSurfaceAccent);
          }
          return BorderSide(color: colorScheme.outline);
        }),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: haloColors.onSurfaceAccent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: haloColors.onSurfaceAccent,
      selectionHandleColor: haloColors.onSurfaceAccent,
      // `selectionColor` is deliberately NOT moved to the accent, and it is
      // the one member of this group where `primary`'s darkness is an asset.
      // A selection wash is read THROUGH: what matters is the selected text's
      // contrast against the composite, and every surface carrying a text
      // field in dark mode carries LIGHT text. Darkening the background under
      // it helps; lightening it hurts. Against `tertiaryContainer` — the
      // logging panel's fields, where most of the app's typing happens —
      // `onSurface` reads at 5.63:1 through primary's wash and only 4.05:1
      // through the accent's, i.e. under AA. Material's default is what this
      // wants, so it goes unset.
      //
      // The cursor and handles above are the opposite case: they are read ON
      // the surface, not through, so they take the accent like everything else.
    ),
    // Material3's default TabBar theming assumes a surface-colored bar and
    // sets the selected label to colorScheme.primary — invisible when the
    // bar itself sits inside our teal (primary-colored) AppBar, as every
    // TabBar in this app does.
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.onPrimary,
      unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.7),
      // A light blue marker reads as a deliberate active-tab indicator
      // against the teal AppBar; an onPrimary indicator would be the same
      // near-white as the label text itself and barely register as its
      // own element. HaLoColors.tabIndicator, not a ColorScheme
      // role — onPrimaryContainer looks right in dark mode by coincidence
      // (it's #BCE9FF there) but is a near-black #001F29 in light mode,
      // since that role flips meaning across brightness; this exact blue
      // reads well in both, so it isn't tied to either.
      indicatorColor: haloColors.tabIndicator,
      // Default M3 hover/focus/pressed overlays are tuned for a
      // surface-colored bar and read as barely-there on this teal
      // background — a bit more opacity so hovering a tab is actually
      // visible.
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
      // otherwise sits flush against the AppBar/pane color.
      dividerHeight: 0,
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 0.5, space: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: const UnderlineInputBorder(),
      // The focused LABEL is corrected here; the focused BORDER deliberately
      // is not, and must not be. `focusedBorder` replaces a field's border
      // outright rather than recoloring it (`_InputDecoratorState.build`
      // selects it INSTEAD of `border` while focused), and it reaches every
      // decoration that didn't set its own. The hand-built decorations in this
      // app use `OutlineInputBorder`, so a theme-level underline turns each
      // rounded box into a bare line the moment it takes focus — and gives the
      // command bar's deliberately border-less field a permanent one, since
      // that field is focused for the dialog's whole life. There is no theme
      // slot that recolors a focused border without also reshaping it, so the
      // color fix stays in [poloFieldDecoration] and, for a decoration that
      // builds its own border, in [haloFocusedBorder]. `theme_test.dart` holds
      // this line.
      //
      // Every state here is respecified, not just the focused one:
      // `WidgetStateTextStyle.resolveWith` cannot return null to defer, so
      // omitting a state overrides it with the fallback — which would leave a
      // disabled field's label at full strength, no longer reading as
      // disabled, and an errored one no longer reading as an error.
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.error)) {
          return TextStyle(color: states.contains(WidgetState.hovered) ? colorScheme.onErrorContainer : colorScheme.error);
        }
        if (states.contains(WidgetState.focused)) {
          return TextStyle(color: haloColors.onSurfaceAccent);
        }
        return TextStyle(color: colorScheme.onSurfaceVariant);
      }),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
