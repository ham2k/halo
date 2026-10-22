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
import 'package:halo_i18n/halo_i18n.dart';

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

  /// The scorers behind each alert/notice key, by short name — present only
  /// when scorers disagree about the QSO, so each pill can say whose rule it
  /// is ("PAQP: Dupe!" beside "POTA: New Day"). A key with no entry is one
  /// pill with no name.
  final Map<String, List<String>> scoreSources;

  /// Whether this call-info is for an existing QSO being edited (vs a new one
  /// being composed) — the map uses it to pick the highlight colour (blue
  /// editing, orange composing), the same new-vs-editing accent the logging
  /// panel itself uses.
  final bool isEditing;

  /// When the log's earlier contacts with this station started, epoch
  /// millis, every operation, minus the QSO being edited when there is one.
  /// Null while unknown (not yet fetched, or a host that does not fetch),
  /// empty for a first contact — both paint nothing. Times rather than a
  /// count because the pill says "3 today + 48 QSOs", and only the app layer
  /// can bucket them: it owns the clock and the locale.
  final List<int>? workedBefore;

  const CallInfoData({
    required this.call,
    this.guess,
    this.lookups = const [],
    this.alertKeys = const [],
    this.noticeKeys = const [],
    this.scoreSources = const {},
    this.isEditing = false,
    this.workedBefore,
  });
}

/// The app's positive green — matching app-polo's red/green pill convention,
/// [CallInfoSummary]'s notice pill pairs this with `theme.colorScheme.error`
/// for alert/notice, and the Radio control's status color pairs it the same
/// way for connected/configured-but-disconnected. One constant so the two
/// "things are good" indicators can't drift apart.
const positiveGreen = Color(0xFF2E7D32);

/// The third pill colour: app-polo's `info` level — neither a verdict on the
/// QSO nor an alert, just a fact about the station (how often it was worked).
const infoGrey = Color(0xFF666666);

enum NoticeLevel { alert, notice, info }

/// The scoring key every scorer reports a duplicate contact under.
const duplicateNoticeKey = 'duplicate';

/// One pill: its label, its colour, and whether a tap on it finds the call
/// in the log ([CallInfoSummary.onFindCall]).
typedef _Notice = ({String label, NoticeLevel level, bool findsCall});

/// The pills for [keys], one per key, naming the scorers [sources] lists for
/// it: "PAQP: Dupe!", "CQWW, PAQP: New Mult". Shared by every pill row, so the
/// compact line and the detail panel name scorers alike.
List<String> scorePillLabels(List<String> keys, Map<String, List<String>> sources, String Function(String key) labelOf) => [
  for (final key in keys)
    if (sources[key] case final scorers? when scorers.isNotEmpty)
      t.loggingControls.info.noticeFromScorer(scorer: scorers.join(', '), notice: labelOf(key))
    else
      labelOf(key),
];

/// One scoring pill. Top-level so the logging panel can paint the same pill
/// outside a call-info line — its missing-band/mode warning is not a scoring
/// verdict, but the operator reads a red pill in that area as one thing.
///
/// Alerts are the error color; notices a positive green; the worked-before
/// count app-polo's neutral grey (matching its red/green/grey pill
/// convention) — the logging panel's own tertiaryContainer fill rules out
/// relying on the neutral scheme containers for contrast.
Widget noticePill(ThemeData theme, String label, {required NoticeLevel level}) {
  final background = switch (level) {
    NoticeLevel.alert => theme.colorScheme.error,
    NoticeLevel.notice => positiveGreen,
    NoticeLevel.info => infoGrey,
  };
  final foreground = level == NoticeLevel.alert ? theme.colorScheme.onError : Colors.white;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(3)),
    child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: foreground)),
  );
}

/// The leading emoji cluster of a call note — call notes always prefix their
/// emoji (see the call-notes extension's `combineNotes`), so isolating this
/// run lets the glow ride only the emoji, not the note's prose. The same
/// ranges as the extension's `LEADING_EMOJI`, exactly: a marker the
/// extension reports for the QSO row must be found here too, or the row
/// shows one and the note line shows none.
final _leadingEmoji = RegExp(r'^[\u{1F000}-\u{1FFFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{200D}\u{FE0F}]+', unicode: true);

/// A call note split into its marker run and the prose after it — the
/// marker null when the note has none. Every place that paints a note's
/// marker as its own glowed glyph splits it here, so all of them agree on
/// what counts as one.
({String? marker, String rest}) splitNoteMarker(String text) {
  final match = _leadingEmoji.firstMatch(text);
  return (marker: match?.group(0), rest: match == null ? text : text.substring(match.end).trimLeft());
}

/// A soft halo behind small glyphs (the call-info flag/note emoji, the
/// spotting control's source-status icons) so they stay legible against a
/// tinted fill — dark on light themes, light on dark themes. Contrasting
/// with the fill, not matching it: a white halo on a light fill is invisible
/// and the glyph reads as having none.
List<Shadow> glyphGlow(ThemeData theme) => [Shadow(color: glyphGlowColor(theme), blurRadius: 6)];

/// [glyphGlow]'s halo color, for a glow drawn at another strength.
Color glyphGlowColor(ThemeData theme) {
  // Black carries further than white at the same alpha, so light mode
  // takes a fainter halo to read as the same weight.
  final dark = theme.brightness == Brightness.dark;
  return (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.4 : 0.25);
}

/// Shared layout for every state of an info area: a top-aligned leading icon
/// with a column of lines to its right, which naturally indents lines 2+ past
/// the icon.
///
/// No [Align]: the logging panel's info-area container top-left-aligns and
/// animates this, and an Align here would fight that.
Widget infoIconRows(ThemeData theme, {required IconData icon, required Color iconColor, required List<Widget> children}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: Space.xxs),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: Space.sm),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
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

  /// Turns [CallInfoData.workedBefore] into the worked-before pill's text —
  /// app-polo's "3 today + 48 QSOs" — or null for no pill. Without it there
  /// is no pill at all: the widget has no clock to bucket the times by.
  final String? Function(List<int> startTimes)? workedBeforeLabel;

  /// The colour the text paints in — the logging panel sits on its own
  /// tertiaryContainer fill, the Quick Lookup bar on the app-bar fill, and
  /// neither can be derived from the ambient scheme alone.
  final Color foregroundColor;

  /// The leading icon's colour: the same accent as the host's main buttons.
  final Color iconColor;

  /// Opens a link tapped inside a note's markdown.
  final void Function(String url)? onOpenLink;

  /// Tapping the duplicate pill or the worked-before pill: both are about
  /// this station's other contacts, and the host shows them — its log,
  /// filtered to this exact call. Null leaves every pill part of whatever
  /// tap target the host wraps the summary in.
  final VoidCallback? onFindCall;

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
    this.workedBeforeLabel,
    this.onOpenLink,
    this.linkColor,
    this.onFindCall,
  });

  List<_Notice> get _notices {
    final labelOf = noticeLabel ?? (String key) => key;
    final worked = _workedBeforeText;
    final alertLabels = scorePillLabels(data.alertKeys, data.scoreSources, labelOf);
    return [
      for (var i = 0; i < alertLabels.length; i++) (label: alertLabels[i], level: NoticeLevel.alert, findsCall: data.alertKeys[i] == duplicateNoticeKey),
      for (final label in scorePillLabels(data.noticeKeys, data.scoreSources, labelOf)) (label: label, level: NoticeLevel.notice, findsCall: false),
      if (worked != null) (label: worked, level: NoticeLevel.info, findsCall: true),
    ];
  }

  /// The worked-before pill's text, or null for none. It stays beside a
  /// duplicate alert, where app-polo drops it: for a call that is not held
  /// (a spot, an opened QSO) the count can land before the verdict, and a
  /// pill that vanishes when the dupe lands reads as the history being
  /// withdrawn.
  String? get _workedBeforeText {
    final times = data.workedBefore;
    if (times == null || times.isEmpty || workedBeforeLabel == null) return null;
    return workedBeforeLabel!(times);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guess = data.guess;
    final flag = asQsonString(guess?['flag']);
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
        // Line 2 (+ 3 when they don't fit): the note/name and the scoring pills.
        if (nameInfo != null || notices.isNotEmpty) _buildNoticesAndNote(context, theme, notices, nameInfo),
      ],
    );
  }

  /// Line 2 (and, when it doesn't fit, line 3): the note/name and the scoring
  /// pills. When note + pills fit the available width, the note leads and the
  /// pills trail it on one line; otherwise the note takes line 2 and the pills
  /// move to line 3, left-aligned under it (measured with a TextPainter — the
  /// app scales at the root, so logical-pixel measurements match what's
  /// painted). Pills on a line of their own wrap rather than run off the edge:
  /// a pill naming its scorer ("PAQP: Dupe!") is twice the width of a bare one.
  Widget _buildNoticesAndNote(BuildContext context, ThemeData theme, List<_Notice> notices, ({String text, bool isNote})? nameInfo) {
    final pillsRow = <Widget>[
      for (var i = 0; i < notices.length; i++) ...[if (i > 0) const SizedBox(width: Space.xs), _pill(theme, notices[i])],
    ];
    final pillsWrap = Wrap(spacing: Space.xs, runSpacing: Space.xxs, children: [for (final notice in notices) _pill(theme, notice)]);
    final note = nameInfo == null ? null : _buildNoteOrName(context, theme, nameInfo);

    if (notices.isEmpty) return note ?? const SizedBox.shrink();
    if (note == null) return pillsWrap;

    // Measured outside the LayoutBuilder: none of it reads `constraints`, and
    // leaving it inside re-parses the note's markdown on every frame of a
    // window resize or pane-divider drag.
    final pillStyle = theme.textTheme.labelSmall;
    final noteStyle = _noteTextStyle(theme);
    var pillsWidth = 0.0;
    for (var i = 0; i < notices.length; i++) {
      // Both halves of each pair must name the same constant the widget does:
      // a hand-copied number here measures a pill that is no longer that wide
      // the moment the spacing rung moves, and the row silently mis-wraps.
      pillsWidth += _measureTextWidth(context, notices[i].label, pillStyle) + Space.sm * 2; // noticePill's padding
      if (i > 0) pillsWidth += Space.xs; // the inter-pill SizedBox in pillsRow
    }
    final noteWidth = nameInfo!.isNote ? _measureNoteWidth(context, theme, nameInfo.text, noteStyle) : _measureTextWidth(context, nameInfo.text, noteStyle);
    const gap = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (pillsWidth + gap + noteWidth <= constraints.maxWidth) {
          // Fits: note leads, pills trail.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: note),
              const SizedBox(width: gap),
              ...pillsRow,
            ],
          );
        }
        // Doesn't fit: note on its own line, pills stacked below.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            note,
            const SizedBox(height: Space.xxs),
            pillsWrap,
          ],
        );
      },
    );
  }

  /// A pill, taking its own tap when it finds the call — ahead of the host's
  /// tap on the whole summary, which the rest of the pills stay part of.
  Widget _pill(ThemeData theme, _Notice notice) {
    final pill = noticePill(theme, notice.label, level: notice.level);
    final onFindCall = this.onFindCall;
    if (!notice.findsCall || onFindCall == null) return pill;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onFindCall, child: pill),
    );
  }

  double _measureTextWidth(BuildContext context, String text, TextStyle? style) => spansWidth(context, [TextSpan(text: text)], style);

  /// The note's width, built from exactly what [_buildNoteOrName] paints: the
  /// same [_noteParts] split and the same styles.
  ///
  /// The leading glyph is an approximation: it paints as an emoji-font glyph
  /// and is measured here as text at the same size.
  double _measureNoteWidth(BuildContext context, ThemeData theme, String text, TextStyle? noteStyle) {
    final parts = _noteParts(text);
    final fontSize = noteStyle?.fontSize ?? flagGlyphDefaultFontSize;
    final spans = inlineMarkdownSpans(parts.markdown, baseFontSize: fontSize, linkStyle: _noteLinkStyle(theme), codeStyle: _noteCodeStyle(context, fontSize));
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
    final parts = splitNoteMarker(text);
    // The marker run paints last-emoji-first, so the FIRST note's marker —
    // the one the QSO row shows — sits nearest the prose it belongs to.
    // Reversed by grapheme, so a ZWJ sequence or a flag pair stays whole.
    final lead = parts.marker?.characters.toList().reversed.join();
    return (lead: lead, markdown: parts.rest);
  }

  /// `code` in a note, matching MarkdownStyleSheet.fromTheme's own code style
  /// — without this, backticks vanish and the run reads as ordinary prose.
  TextStyle _noteCodeStyle(BuildContext context, double fontSize) => haloMonoStyle(context, fontSize: fontSize * 0.85);

  /// A link blue tuned per theme so the note's socials/URLs read clearly on the
  /// area's fill — darker on light, lighter on dark. Shared with
  /// [_measureNoteWidth], so the measurement styles links the way they paint.
  TextStyle _noteLinkStyle(ThemeData theme) =>
      TextStyle(color: linkColor ?? (theme.brightness == Brightness.dark ? Colors.blue.shade200 : Colors.blue.shade800), fontWeight: FontWeight.w600);

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
    // Sized to its content: a Row that took the whole line would push the
    // pills that trail the note to the far right of the area.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Any pictographic emoji, flag or not, needs emojiFontFamily rather
        // than textStyle's Roboto, or it renders as nothing at all — same as
        // call_info_panel.dart's flag Text.
        flagGlyph(parts.lead!, fontSize: textStyle?.fontSize ?? 14, shadows: glyphGlow(theme)),
        if (markdown != null) ...[const SizedBox(width: Space.xs), Flexible(child: markdown)],
      ],
    );
  }
}
