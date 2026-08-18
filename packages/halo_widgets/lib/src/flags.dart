// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A DXCC entity's `flag` (guess['flag']/Qso.theirFlag, see theme.dart's
// emojiStyle doc) is a Unicode flag emoji — either a two-codepoint
// regional-indicator pair (🇺🇸) or, for England/Scotland/Wales/Northern
// Ireland, a black-flag-plus-tag-sequence (🏴󠁧󠁢󠁥󠁮󠁧󠁿). Both compose into a single
// glyph on every platform, Windows included, PROVIDED the bundled color-emoji
// font is the one asked for: a flag left to the ambient text style falls to
// Roboto, and from there to whatever the platform substitutes — Segoe UI
// Emoji on Windows, which ships no flag glyphs at all and draws the bare
// letters "US" instead, and nothing whatsoever on web, where CanvasKit does
// its own shaping and never reaches for an OS font.
//
// So every flag goes through [flagGlyph] or [flagSpan] rather than a plain
// `Text`. That is the whole mechanism — there is no image fallback and no
// platform branch.

import 'package:flutter/material.dart';

import 'theme.dart' show emojiStyle;

/// [flagGlyph]'s default size — matches emojiStyle()'s own default of 16.
/// qso_list.dart's DX/state column reserves width for exactly this (its
/// flagGlyph call doesn't pass fontSize explicitly), so this constant, not a
/// bare `16` repeated at each call site, is what keeps that precompute from
/// silently drifting out of sync with the glyph it's sizing for.
const double flagGlyphDefaultFontSize = 16;

/// Renders [flag] at a size matching [fontSize]-emoji text, in the bundled
/// color-emoji font. [shadows] glows the glyph against a tinted fill (e.g.
/// the call-info flag).
Widget flagGlyph(String flag, {double fontSize = flagGlyphDefaultFontSize, List<Shadow>? shadows}) =>
    Text(flag, style: emojiStyle(fontSize: fontSize).copyWith(shadows: shadows));

/// [flagGlyph] as an [InlineSpan], for embedding a flag inline with running
/// text in a `Text.rich` (e.g. the call-info header's "🇺🇸 United States").
InlineSpan flagSpan(String flag, {required TextStyle style}) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: flagGlyph(flag, fontSize: style.fontSize ?? flagGlyphDefaultFontSize),
    );
