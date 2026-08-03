// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A DXCC entity's `flag` (guess['flag']/Qso.theirFlag, see theme.dart's
// emojiStyle doc) is a Unicode flag emoji — either a two-codepoint
// regional-indicator pair (🇺🇸) or, for England/Scotland/Wales/Northern
// Ireland, a black-flag-plus-tag-sequence (🏴󠁧󠁢󠁥󠁮󠁧󠁿). Flutter's Windows-desktop
// Skia text layout can't compose either form into a single glyph, no matter
// which font is bundled — swapping the bundled Noto Color Emoji build for a
// newer one does not fix it. It's a structural gap in Flutter's Windows text
// shaping, not a missing-glyph problem — so instead of relying on emoji
// composition on Windows, this renders a pre-composed image there instead.
//
// The images are flag-icons (github.com/lipis/flag-icons, MIT), vendored
// under app/assets/flags/ (app/assets/flag-icons-LICENSE.txt) — the full set
// (271 SVGs), not just the ~250 codes DXCC entities' flags decode to: the
// decoder below is general (pure Unicode math, not a per-entity lookup
// table), so it also resolves a flag emoji appearing anywhere in
// call-note/scoring-summary markdown, not just the dedicated flag field —
// and community-authored note text can reasonably reference a flag with no
// DXCC entity at all (e.g. Kosovo). Vendoring only the DXCC subset would
// decode those fine but fail to find an asset, silently rendering nothing.

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'platform_chrome.dart' show isWindowsPlatform;
import 'theme.dart' show emojiStyle;

/// Forces [flagEmojiNeedsImageFallback] on regardless of platform —
/// `--dart-define=FORCE_WINDOWS_FLAGS=true`, dev-only (never in a release
/// build, matching every other debug flag's safety net). For previewing the
/// Windows image fallback from a build that isn't actually Windows, e.g. a
/// web preview, when there's no Windows machine at hand to check on directly.
const bool _forceWindowsFlags = bool.fromEnvironment('FORCE_WINDOWS_FLAGS');

/// True where a flag emoji can't be trusted to render as a composed glyph —
/// see this file's header. The gate for every fallback below.
bool get flagEmojiNeedsImageFallback => isWindowsPlatform || (!kReleaseMode && _forceWindowsFlags);

/// Decodes a flag emoji into the lowercase code flag-icons uses for its SVG
/// filenames — `us` for a regional-indicator pair (🇺🇸), or `gb-eng` for a
/// tag-sequence subdivision flag (England's 🏴󠁧󠁢󠁥󠁮󠁧󠁿). Null for anything else: a
/// non-flag emoji, or a flag shape not in that vocabulary — callers fall
/// back to rendering the emoji text as-is, so an unrecognized shape never
/// just disappears.
String? flagIconCode(String flag) {
  final points = flag.runes.toList();
  if (points.length == 2 && points.every((c) => c >= 0x1F1E6 && c <= 0x1F1FF)) {
    return String.fromCharCodes(points.map((c) => c - 0x1F1E6 + 0x61));
  }
  if (points.length > 2 && points.first == 0x1F3F4 && points.last == 0xE007F) {
    final tag = String.fromCharCodes(points.sublist(1, points.length - 1).map((c) => c - 0xE0000));
    if (tag.length > 2 && tag.runes.every((c) => c >= 0x61 && c <= 0x7A)) {
      return '${tag.substring(0, 2)}-${tag.substring(2)}';
    }
  }
  return null;
}

/// Asset path for a [flagIconCode] result, as declared in app/pubspec.yaml.
String flagAssetPath(String code) => 'assets/flags/$code.svg';

/// [flagGlyph]'s default size — matches emojiStyle()'s own default of 16.
/// qso_list.dart's DX/state column reserves width for exactly this (its
/// flagGlyph call doesn't pass fontSize explicitly), so this constant, not a
/// bare `16` repeated at each call site, is what keeps that precompute from
/// silently drifting out of sync with the glyph it's sizing for.
const double flagGlyphDefaultFontSize = 16;

/// Renders [flag] at a size matching [fontSize]-emoji text: the glyph itself
/// everywhere Flutter can compose it, or the equivalent bundled SVG where
/// [flagEmojiNeedsImageFallback] — falling back to plain emoji text when
/// [flagIconCode] can't resolve one. [shadows] matches emojiStyle() callers
/// that glow the glyph against a tinted fill (e.g. the call-info flag).
Widget flagGlyph(String flag, {double fontSize = flagGlyphDefaultFontSize, List<Shadow>? shadows}) {
  final code = flagEmojiNeedsImageFallback ? flagIconCode(flag) : null;
  if (code == null) {
    return Text(flag, style: emojiStyle(fontSize: fontSize).copyWith(shadows: shadows));
  }
  return SvgPicture.asset(flagAssetPath(code), width: fontSize * 4 / 3, height: fontSize);
}

/// [flagGlyph] as an [InlineSpan], for embedding a flag inline with running
/// text in a `Text.rich` (e.g. the call-info header's "🇺🇸 United States").
InlineSpan flagSpan(String flag, {required TextStyle style}) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: flagGlyph(flag, fontSize: style.fontSize ?? flagGlyphDefaultFontSize),
    );

// Any flag emoji, anywhere in a run of text: a regional-indicator pair, or a
// black flag + Unicode tag sequence ending in the cancel tag. Deliberately
// not anchored to the string start, unlike logging_controls.dart's
// _leadingEmoji — a call note or scoring line can carry a flag mid-sentence.
final RegExp _flagEmojiPattern = RegExp(
  '[\u{1F1E6}-\u{1F1FF}]{2}|\u{1F3F4}[\u{E0020}-\u{E007E}]+\u{E007F}',
  unicode: true,
);

/// Rewrites every flag emoji in [markdown] into a `flag:` image reference
/// [flagMarkdownImageBuilder] renders, sized to [fontSize] — only when
/// [flagEmojiNeedsImageFallback], so every other platform gets [markdown]
/// back unchanged (flag emoji already render fine there today). Pair with
/// [flagMarkdownImageBuilder] at any site that renders call-note or
/// scoring-summary text — as `MarkdownBody(sizedImageBuilder: …)` for block
/// text, or `InlineMarkdownText(imageBuilder: …)` for a single line.
String flagsInMarkdown(String markdown, {double fontSize = flagGlyphDefaultFontSize}) {
  if (!flagEmojiNeedsImageFallback) return markdown;
  final w = (fontSize * 4 / 3).round();
  final h = fontSize.round();
  return markdown.replaceAllMapped(_flagEmojiPattern, (m) {
    final code = flagIconCode(m[0]!);
    return code == null ? m[0]! : '![flag](flag:$code#${w}x$h)';
  });
}

/// Image-builder counterpart to [flagsInMarkdown] — every renderer of
/// call-note or scoring-summary text should pass this (as
/// `MarkdownBody.sizedImageBuilder` or `InlineMarkdownText.imageBuilder`), even
/// where the surrounding platform never triggers the rewrite (it only ever sees
/// a `flag:` uri when [flagsInMarkdown] produced one).
Widget flagMarkdownImageBuilder(MarkdownImageConfig config) {
  if (config.uri.scheme != 'flag') return const SizedBox.shrink();
  return SvgPicture.asset(flagAssetPath(config.uri.path), width: config.width, height: config.height);
}
