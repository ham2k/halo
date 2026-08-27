// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The compact call-info area: what is known about the callsign in hand, in two
// or three lines. The logging panel's info area is one instance of it; Home's
// Quick Lookup bar is another, and the two must not drift — a tweak here is
// meant to land on both at once, which is why this is a widget and not a
// method on either host's State.
//
// It renders what it is given and computes nothing: the distance line, the
// notice labels and the i18n behind them are the app layer's, since only the
// app knows the operation's own location, the operator's units and the
// current locale. A host with no operation (Quick Lookup) simply passes no
// location line and no scoring keys, and those parts are absent rather than
// faked.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';

import 'flags.dart';
import 'inline_markdown.dart';
import 'mdi_icons.g.dart';
import 'spacing.dart';
import 'theme.dart';

/// A snapshot of the current call-info — the same data the compact call-info
/// area renders, and what the richer detail panel (the Info tab on wide
/// layouts, a modal on narrow) is handed so it can present more of it.
/// Immutable value.
class CallInfoData {
  final String call;
  final Map<String, dynamic>? guess;
  final List<Map<String, dynamic>> lookups;
  final List<String> alertKeys;
  final List<String> noticeKeys;

  /// Whether this call-info is for an existing QSO being edited (vs a new one
  /// being composed) — the map uses it to pick the highlight colour (blue
  /// editing, orange composing), the same new-vs-editing accent the logging
  /// panel itself uses.
  final bool isEditing;

  const CallInfoData({
    required this.call,
    this.guess,
    this.lookups = const [],
    this.alertKeys = const [],
    this.noticeKeys = const [],
    this.isEditing = false,
  });
}

/// The app's positive green — matching app-polo's red/green pill convention,
/// [CallInfoSummary]'s notice pill pairs this with `theme.colorScheme.error`
/// for alert/notice, and the Radio control's status color pairs it the same
/// way for connected/configured-but-disconnected. One constant so the two
/// "things are good" indicators can't drift apart.
const positiveGreen = Color(0xFF2E7D32);

/// A soft halo behind small glyphs (the call-info flag/note emoji, the
/// spotting control's source-status icons) so they stay legible against a
/// tinted fill — white on light themes, dark on dark themes.
List<Shadow> glyphGlow(ThemeData theme) {
  final color = theme.brightness == Brightness.dark ? Colors.black : Colors.white;
  return [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)];
}

/// Shared layout for every state of an info area: a top-aligned leading icon
/// with a column of lines to its right, which naturally indents lines 2+ past
/// the icon.
///
/// No [Align]: the logging panel's info-area container top-left-aligns and
/// animates this, and an Align here would fight that.
Widget infoIconRows(
  ThemeData theme, {
  required IconData icon,
  required Color iconColor,
  required List<Widget> children,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: Space.xxs),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: Space.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    ],
  );
}

/// Line 2's content: a callsign note, which takes the slot outright and
/// renders as markdown, else the plain name. Null when the guess has neither.
({String text, bool isNote})? _stationNameOrNote(Map<String, dynamic>? guess) {
  if (guess == null) return null;
  final note = asQsonString(guess['note']);
  if (note != null && note.isNotEmpty) return (text: note, isNote: true);
  final name = asQsonString(guess['name']);
  if (name != null && name.isNotEmpty) return (text: name, isNote: false);
  return null;
}

/// Call-info state: line 1 flag + location, line 2 note/name, line 3 scoring
/// notices — all in a column aligned past the leading person icon.
class CallInfoSummary extends StatelessWidget {
  /// The call and its lookup results. Scoring keys empty means no pills, which
  /// is the normal state anywhere there is no operation to score against.
  final CallInfoData data;

  /// Line 1's location text, already formatted by the app layer — the
  /// distance/bearing phrase where an operation supplies a reference point,
  /// or a plain location label where none does. Null or empty leaves the slot
  /// blank, which is deliberate: the line still occupies its height, so the
  /// area does not change size as the lookup resolves under the operator.
  final String? locationLine;

  /// Turns a scoring key into its display label. Keys render raw without it.
  final String Function(String key)? noticeLabel;

  /// The colour the text paints in — the logging panel sits on its own
  /// tertiaryContainer fill, the Quick Lookup bar on the app-bar fill, and
  /// neither can be derived from the ambient scheme alone.
  final Color foregroundColor;

  /// The leading icon's colour: the same accent as the host's main buttons.
  final Color iconColor;

  /// Opens a link tapped inside a note's markdown.
  final void Function(String url)? onOpenLink;

  /// The colour a link inside a note paints in. Defaults to a theme-tuned
  /// blue, which reads on the logging panel's own fill — a host painting on
  /// something else must say so, for the same reason [foregroundColor]
  /// exists: the fill is not derivable from the ambient scheme.
  final Color? linkColor;

  const CallInfoSummary({
    super.key,
    required this.data,
    required this.foregroundColor,
    required this.iconColor,
    this.locationLine,
    this.noticeLabel,
    this.onOpenLink,
    this.linkColor,
  });

  /// The leading emoji cluster of a call note — call notes always prefix their
  /// emoji (see the call-notes extension's `combineNotes`), so isolating this
  /// run lets the glow ride only the emoji, not the note's prose. Covers the
  /// common pictographic ranges plus ZWJ / variation-selector / keycap /
  /// regional-indicator (flag) code points; deliberately not exhaustive.
  static final _leadingEmoji = RegExp(
    r'^[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{1F1E6}-\u{1F1FF}\u{200D}\u{FE0F}\u{20E3}]+',
    unicode: true,
  );

  List<({String label, bool alert})> get _notices {
    final labelOf = noticeLabel ?? (String key) => key;
    return [
      for (final key in data.alertKeys) (label: labelOf(key), alert: true),
      for (final key in data.noticeKeys) (label: labelOf(key), alert: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guess = data.guess;
    final flag = guess?['flag'] as String?;
    final nameInfo = _stationNameOrNote(guess);
    final notices = _notices;

    // Line 1: optional flag, then the location slot — which is always present
    // (a blank space when there's no location) so the line keeps a consistent
    // height whether or not a location resolved.
    final firstLine = <Widget>[
      if (flag != null && flag.isNotEmpty) ...[
        flagGlyph(flag, fontSize: theme.textTheme.bodyMedium?.fontSize ?? 14, shadows: glyphGlow(theme)),
        const SizedBox(width: Space.sm),
      ],
      Expanded(
        child: Text(
          (locationLine != null && locationLine!.isNotEmpty) ? locationLine! : ' ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
        ),
      ),
    ];

    // Always render the area (at least the person icon + the reserved first
    // line) once a call is active, so the lookup and score data fill it in
    // place rather than it flashing between empty and full.
    return infoIconRows(
      theme,
      icon: MdiIcons.account,
      iconColor: iconColor,
      children: [
        // Line 1 — flag + distance/location (blank until the lookup resolves),
        // keeping the pills and note on the second line even before it appears.
        Row(children: firstLine),
        // Line 2 (+ 3 when they don't fit): scoring pills and the note/name.
        if (nameInfo != null || notices.isNotEmpty) _buildNoticesAndNote(context, theme, notices, nameInfo),
      ],
    );
  }

  /// Line 2 (and, when it doesn't fit, line 3): the scoring pills and the
  /// note/name. When pills + note fit the available width, the pills lead and
  /// the note trails on one line; otherwise the note takes line 2 and the pills
  /// stack below on line 3 (measured with a TextPainter — the app scales at the
  /// root, so logical-pixel measurements match what's painted).
  Widget _buildNoticesAndNote(
    BuildContext context,
    ThemeData theme,
    List<({String label, bool alert})> notices,
    ({String text, bool isNote})? nameInfo,
  ) {
    final pillsRow = <Widget>[
      for (var i = 0; i < notices.length; i++) ...[
        if (i > 0) const SizedBox(width: Space.xs),
        _noticePill(theme, notices[i].label, alert: notices[i].alert),
      ],
    ];
    final note = nameInfo == null ? null : _buildNoteOrName(context, theme, nameInfo);

    if (notices.isEmpty) return note ?? const SizedBox.shrink();
    if (note == null) return Row(children: pillsRow);

    // Measured outside the LayoutBuilder: none of it reads `constraints`, and
    // leaving it inside re-parses the note's markdown on every frame of a
    // window resize or pane-divider drag.
    final pillStyle = theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);
    final noteStyle = _noteTextStyle(theme);
    var pillsWidth = 0.0;
    for (var i = 0; i < notices.length; i++) {
      // Both halves of each pair must name the same constant the widget does:
      // a hand-copied number here measures a pill that is no longer that wide
      // the moment the spacing rung moves, and the row silently mis-wraps.
      pillsWidth += _measureTextWidth(context, notices[i].label, pillStyle) + Space.sm * 2; // _noticePill's padding
      if (i > 0) pillsWidth += Space.xs; // the inter-pill SizedBox in pillsRow
    }
    final noteWidth = nameInfo!.isNote
        ? _measureNoteWidth(context, theme, nameInfo.text, noteStyle)
        : _measureTextWidth(context, nameInfo.text, noteStyle);
    const gap = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (pillsWidth + gap + noteWidth <= constraints.maxWidth) {
          // Fits: pills lead, note trails.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [...pillsRow, const SizedBox(width: gap), Flexible(child: note)],
          );
        }
        // Doesn't fit: note on its own line, pills stacked below.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [note, const SizedBox(height: Space.xxs), Row(children: pillsRow)],
        );
      },
    );
  }

  double _measureTextWidth(BuildContext context, String text, TextStyle? style) =>
      spansWidth(context, [TextSpan(text: text)], style);

  /// The note's width, built from exactly what [_buildNoteOrName] paints: the
  /// same [_noteParts] split and the same styles.
  ///
  /// The leading glyph is an approximation: it paints as an emoji-font glyph
  /// and is measured here as text at the same size.
  double _measureNoteWidth(BuildContext context, ThemeData theme, String text, TextStyle? noteStyle) {
    final parts = _noteParts(text);
    final fontSize = noteStyle?.fontSize ?? flagGlyphDefaultFontSize;
    final spans = inlineMarkdownSpans(
      parts.markdown,
      baseFontSize: fontSize,
      linkStyle: _noteLinkStyle(theme),
      codeStyle: _noteCodeStyle(context, fontSize),
    );
    var width = spansWidth(context, spans, noteStyle);
    // Names the same rung the rendered gap does — see the pill measurement above.
    if (parts.lead != null) {
      width += _measureTextWidth(context, parts.lead!, noteStyle) + Space.xs; // the SizedBox beside the glyph
    }
    return width;
  }

  /// The style line 2 paints its note in, and the one [_measureNoteWidth] is
  /// handed. ONE definition, because the two must not diverge: a measurement
  /// style without [emojiFontFamily] resolves an emoji to no glyph at all and
  /// under-measures the note by a glyph per flag, and the row then picks the
  /// wrong wrap branch — while looking correct in every note that has none.
  TextStyle? _noteTextStyle(ThemeData theme) => theme.textTheme.bodyMedium?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w600,
        // A note carries emoji past its leading cluster — a flag naming a
        // country mid-sentence. Roboto resolves none of them on web
        // (theme.dart's emojiFontFamily).
        fontFamilyFallback: const [emojiFontFamily],
      );

  /// The note split the way it paints: the leading emoji cluster, which gets its
  /// own glowed glyph, and the markdown for everything after it.
  ({String? lead, String markdown}) _noteParts(String text) {
    final leadMatch = _leadingEmoji.firstMatch(text);
    final rest = leadMatch == null ? text : text.substring(leadMatch.end).trimLeft();
    return (lead: leadMatch?.group(0), markdown: rest);
  }

  /// `code` in a note, matching MarkdownStyleSheet.fromTheme's own code style
  /// — without this, backticks vanish and the run reads as ordinary prose.
  TextStyle _noteCodeStyle(BuildContext context, double fontSize) =>
      haloMonoStyle(context, fontSize: fontSize * 0.85);

  /// A link blue tuned per theme so the note's socials/URLs read clearly on the
  /// area's fill — darker on light, lighter on dark. Shared with
  /// [_measureNoteWidth], so the measurement styles links the way they paint.
  TextStyle _noteLinkStyle(ThemeData theme) => TextStyle(
        color: linkColor ?? (theme.brightness == Brightness.dark ? Colors.blue.shade200 : Colors.blue.shade800),
        fontWeight: FontWeight.w600,
      );

  /// Line 2: the plain name, or the note rendered as markdown with its leading
  /// emoji cluster glowed (emoji only, not the prose).
  Widget _buildNoteOrName(BuildContext context, ThemeData theme, ({String text, bool isNote}) info) {
    final textStyle = _noteTextStyle(theme);
    if (!info.isNote) {
      return Text(info.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle);
    }

    final parts = _noteParts(info.text);
    final markdown = parts.markdown.isEmpty
        ? null
        : InlineMarkdownText(
            parts.markdown,
            style: textStyle,
            linkStyle: _noteLinkStyle(theme),
            codeStyle: _noteCodeStyle(context, textStyle?.fontSize ?? flagGlyphDefaultFontSize),
            onOpenLink: onOpenLink,
            // Deliberately no maxLines: a long note still wraps onto a third
            // line, which this area has always allowed. Spans buy the note
            // tappable links, not an ellipsis.
            overflow: TextOverflow.clip,
          );

    if (parts.lead == null) return markdown ?? const SizedBox.shrink();

    // Leading emoji (glowed) + the rest of the note (markdown, no glow).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Any pictographic emoji, flag or not, needs emojiFontFamily rather
        // than textStyle's Roboto, or it renders as nothing at all — same as
        // call_info_panel.dart's flag Text.
        flagGlyph(parts.lead!, fontSize: textStyle?.fontSize ?? 14, shadows: glyphGlow(theme)),
        if (markdown != null) ...[
          const SizedBox(width: Space.xs),
          Flexible(child: markdown),
        ],
      ],
    );
  }

  Widget _noticePill(ThemeData theme, String label, {required bool alert}) {
    // Alerts are the error color; notices a positive green (matching app-polo's
    // red/green pill convention) — the logging panel's own tertiaryContainer
    // fill rules out relying on the neutral scheme containers for contrast.
    final background = alert ? theme.colorScheme.error : positiveGreen;
    final foreground = alert ? theme.colorScheme.onError : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(3)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
