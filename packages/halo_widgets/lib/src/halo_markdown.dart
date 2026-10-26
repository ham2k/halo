// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'spacing.dart';
import 'theme.dart';

/// Block markdown, the one way the app renders it: a [MarkdownBody] over the
/// house style sheet, with [style] applied on top and the emoji font added
/// last. Inline, single-line markdown is [InlineMarkdownText]'s job.
///
/// The house sheet is [MarkdownStyleSheet.fromTheme] plus the house table
/// style — no borders, thin cell padding, cells aligned to the top of a row
/// that wraps, and headers aligned left like their cells (a column's own
/// `:--:` alignment still wins). A bare `MarkdownBody` gets flutter_markdown's
/// bordered 16x8 grid instead, and can lose the emoji font;
/// `no_bare_markdown_body_test.dart` keeps every render coming through here.
class HaloMarkdown extends StatelessWidget {
  const HaloMarkdown({super.key, required this.data, this.style, this.selectable = false, this.softLineBreak = false, this.onTapLink});

  final String data;

  /// Customises the house sheet it is handed, with `copyWith`. Its values win,
  /// tables included. A hand-built `TextStyle` in it, rather than one from the
  /// theme, is fine: the emoji font is added after this runs.
  final MarkdownStyleSheet Function(MarkdownStyleSheet base)? style;

  final bool selectable;
  final bool softLineBreak;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final base = _houseStyleSheet(Theme.of(context));
    return MarkdownBody(
      data: data,
      styleSheet: _withEmojiFallback(style?.call(base) ?? base),
      selectable: selectable,
      softLineBreak: softLineBreak,
      onTapLink: onTapLink,
    );
  }
}

MarkdownStyleSheet _houseStyleSheet(ThemeData theme) => MarkdownStyleSheet.fromTheme(theme).copyWith(
  tableHeadAlign: TextAlign.left,
  tableVerticalAlignment: TableCellVerticalAlignment.top,
  tableBorder: const TableBorder(),
  tableCellsPadding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
);

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
/// The theme's text styles already carry the fallback, but a [HaloMarkdown.style]
/// that replaces one with a hand-built `TextStyle` drops it; applying this
/// LAST is what covers that.
///
/// Every style is listed individually on purpose: `copyWith(p:)` reaches `li`,
/// `pre` and `table`, which share the `p` style, and NOTHING else — so a flag
/// in a heading or a table cell goes missing while the paragraph beside it
/// renders.
MarkdownStyleSheet _withEmojiFallback(MarkdownStyleSheet base) {
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
