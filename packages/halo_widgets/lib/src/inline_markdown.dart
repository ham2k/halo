// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'form_renderer.dart' show FormOpenLink;
import 'theme.dart' show HaLoColors;

/// Opens a link tapped in an [InlineMarkdownText] — the same contract as
/// [FormOpenLink], reused rather than duplicated so a call site that already has
/// an opener can pass it to either widget.
typedef InlineMarkdownOpenLink = FormOpenLink;

/// A single line (or a few) of inline markdown — bold, italic, code,
/// strikethrough, links and images — that can ellipsize.
///
/// `MarkdownBody` is a BLOCK renderer: it builds a Column and supports neither
/// `maxLines` nor `overflow`, so in a fixed-height row a long description wraps
/// and gets clipped mid-line instead of ellipsizing. This renders the inline
/// half of the same document into spans of one [Text.rich], which ellipsizes
/// properly.
///
/// **Inline** syntax is `MarkdownBody`'s exactly — gitHubFlavored, with
/// `encodeHtml: false` — so the two agree: emphasis nests, backslash escapes
/// resolve, `&` and `<` stay themselves, bare URLs autolink, and a link
/// destination may contain balanced parens.
///
/// **Block** syntax is deliberately almost entirely off, because this renders
/// one line of prose rather than a document. `73. tnx`, `- [x] QSL`, `---` and
/// `# Heading` are content here, not markup, and stay literal; consecutive
/// paragraphs are joined with a space. See [_parseDocument] for what is kept
/// and why.
///
/// Use it where the text is one tidy line; keep `MarkdownBody` wherever block
/// structure actually matters.
///
/// Only parse text an extension or a data file authored. An operation title, or
/// something the operator typed, is user data where a `*` is punctuation rather
/// than markup — render that with a plain [Text].
class InlineMarkdownText extends StatefulWidget {
  const InlineMarkdownText(
    this.text, {
    super.key,
    this.style,
    this.codeStyle,
    this.linkStyle,
    this.onOpenLink,
    this.imageBuilder,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
  });

  /// The markdown to render. Inline markup is rendered; block markers stay
  /// literal (see [_parseDocument]).
  final String text;

  /// The base style every span inherits.
  final TextStyle? style;

  /// Distinct style for `` `code` `` spans — typically [haloMonoStyle].
  final TextStyle? codeStyle;

  /// Style for link spans. Defaults to the theme's primary colour, semibold, so
  /// a link reads as one without a launcher being wired up.
  final TextStyle? linkStyle;

  /// Called with the url when a link is tapped. When null, links render in
  /// [linkStyle] but carry no recognizer at all — so a tap falls through to an
  /// enclosing row instead of being swallowed by an inert link.
  final InlineMarkdownOpenLink? onOpenLink;

  /// Renders `![alt](uri)` images as inline spans. Pass
  /// [flagMarkdownImageBuilder] at any site showing call-note or
  /// scoring-summary text, which [flagsInMarkdown] may have rewritten into
  /// `flag:` image references. Images are dropped when this is null.
  final Widget Function(MarkdownImageConfig config)? imageBuilder;

  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;

  @override
  State<InlineMarkdownText> createState() => _InlineMarkdownTextState();
}

class _InlineMarkdownTextState extends State<InlineMarkdownText> {
  /// One recognizer per link url, keyed by url so a rebuild reuses the live
  /// object instead of retiring one mid-gesture. Empty while
  /// [InlineMarkdownText.onOpenLink] is null — an inert link must not join the
  /// gesture arena, or it steals the tap from the row around it.
  Map<String, TapGestureRecognizer> _recognizers = const {};

  @override
  void initState() {
    super.initState();
    _syncRecognizers();
  }

  @override
  void didUpdateWidget(InlineMarkdownText old) {
    super.didUpdateWidget(old);
    // Whether there is a handler at all decides whether recognizers exist, so
    // it matters as much as the text does.
    if (old.text != widget.text || (old.onOpenLink == null) != (widget.onOpenLink == null)) {
      _syncRecognizers();
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  /// Rebuilds the recognizer map, keeping any recognizer whose url survives the
  /// text change and disposing only those that no longer appear — so a tap in
  /// flight on a surviving link still completes.
  void _syncRecognizers() {
    final wanted = widget.onOpenLink == null ? const <String>{} : inlineMarkdownLinkUrls(widget.text).toSet();
    final next = <String, TapGestureRecognizer>{};
    for (final url in wanted) {
      next[url] = _recognizers[url] ?? (TapGestureRecognizer()..onTap = () => widget.onOpenLink?.call(url));
    }
    for (final entry in _recognizers.entries) {
      if (!next.containsKey(entry.key)) entry.value.dispose();
    }
    _recognizers = next;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: inlineMarkdownSpans(
          widget.text,
          codeStyle: widget.codeStyle,
          // onSurfaceAccent, not colorScheme.primary: a link is text read ON
          // the surface, and this widget's whole point is being embedded in a
          // row of body text rather than on a fill.
          linkStyle:
              widget.linkStyle ??
              TextStyle(color: HaLoColors.of(context).onSurfaceAccent, fontWeight: FontWeight.w600),
          recognizerFor: (url) => _recognizers[url],
          imageBuilder: widget.imageBuilder,
          onOpenLink: widget.onOpenLink,
        ),
      ),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}

/// Renders the inline markdown in [text] as spans.
///
/// Parses with the `markdown` package under [md.ExtensionSet.gitHubFlavored] —
/// the same syntax and the same `encodeHtml: false` `MarkdownBody` uses — then
/// flattens the block tree onto one line. Emphasis nests, escapes resolve, `&`
/// and `<` stay themselves, and bare URLs autolink.
///
/// [recognizerFor] supplies the tap recognizer for a link url, or null to leave
/// the link inert. Prefer [InlineMarkdownText], which owns that lifecycle.
List<InlineSpan> inlineMarkdownSpans(
  String text, {
  TextStyle? codeStyle,
  TextStyle? linkStyle,
  GestureRecognizer? Function(String url)? recognizerFor,
  Widget Function(MarkdownImageConfig config)? imageBuilder,
  InlineMarkdownOpenLink? onOpenLink,
}) {
  final spans = <InlineSpan>[];
  for (final node in _parseDocument(text)) {
    _appendNode(
      node,
      spans,
      codeStyle: codeStyle,
      linkStyle: linkStyle,
      recognizerFor: recognizerFor,
      imageBuilder: imageBuilder,
      onOpenLink: onOpenLink,
    );
  }
  return spans;
}

/// Every link url in [text], in document order, deduplicated — what
/// [InlineMarkdownText] builds its tap recognizers from.
///
/// Skips the same subtrees [_appendNode] does (never inside `img` or `code`), so
/// the recognizer map matches the links that actually render.
List<String> inlineMarkdownLinkUrls(String text) {
  final urls = <String>[];
  void walk(md.Node node) {
    if (node is! md.Element) return;
    if (node.tag == 'img' || node.tag == 'code') return;
    if (node.tag == 'a') {
      final href = node.attributes['href'];
      if (href != null && !urls.contains(href)) urls.add(href);
    }
    for (final child in node.children ?? const <md.Node>[]) {
      walk(child);
    }
  }

  for (final node in _parseDocument(text)) {
    walk(node);
  }
  return urls;
}

/// Parses [text] as inline markdown in one or more plain paragraphs.
///
/// The **block** syntaxes are deliberately narrowed to three. Running the full
/// GFM block set over a call note or a command description does real damage:
/// `73. tnx for the QSO` reads as an ordered-list marker, so the `73.` is
/// eaten; `- [x] QSL` loses the checkbox that carries its meaning; `---`
/// becomes a thematic break and renders as nothing at all; a fenced block
/// injects hard newlines into a widget built to paint one line. None of that is
/// markup the author meant — in a logger, a note opening `73.` is far likelier
/// than an ordered list. (PoLo's renderer parses blocks the same way, but it
/// paints a block surface where a list is a reasonable thing to become. This is
/// one line.)
///
/// [md.LinkReferenceDefinitionSyntax] stays, because reference-style links are
/// real markup and their definitions are only collected by the block layer;
/// [md.EmptyBlockSyntax] keeps a blank line from joining two paragraphs.
///
/// Both of these matter, and neither is decoration:
///
/// - [md.ParagraphSyntax] must stay LAST. Its catch-all `canParse` is what
///   keeps a `73.` out of an ordered list.
/// - `withDefaultBlockSyntaxes: false` is **load-bearing**, despite the
///   catch-all. `ParagraphSyntax.parse` asks `interruptedBy(parser)`, which
///   scans the whole syntax list regardless of order, and a setext underline
///   makes it discard the paragraph it had accumulated. With the defaults on,
///   `Nice op\n---` renders as `---` — "Nice op" is deleted outright.
///
/// One shape is still swallowed, deliberately: `[QSL]: bureau` is a link
/// reference definition and renders as nothing, because keeping
/// [md.LinkReferenceDefinitionSyntax] is what makes `[QRZ]` resolve against a
/// later `[QRZ]: https://…`. `MarkdownBody` does the same, and the live
/// hams-of-note corpus has no `[label]:` line, so the trade is worth it — but
/// it is a trade, not a free win.
///
/// Inline syntax is still `MarkdownBody`'s exactly, and so is
/// `encodeHtml: false` — the default `true` turns every `&`, `<`, `>` and `"`
/// into an HTML entity on screen, and escapes the hrefs autolinking synthesizes
/// into broken URLs.
///
/// [text] is trimmed first: `MarkdownBody` drops a block's leading spaces in its
/// builder rather than its parser, and for a one-line render trimming the whole
/// string is the same thing.
List<md.Node> _parseDocument(String text) => md.Document(
      blockSyntaxes: const [
        md.EmptyBlockSyntax(),
        md.LinkReferenceDefinitionSyntax(),
        md.ParagraphSyntax(),
      ],
      inlineSyntaxes: md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
      withDefaultBlockSyntaxes: false,
      // withDefaultInlineSyntaxes stays TRUE: the CommonMark defaults are the
      // base inline set (emphasis, escapes, code, links), not an extra layer.
      // Turning it off leaves `**bold**` and `\*` unparsed. The only cost is a
      // duplicate InlineHtmlSyntax appended after gitHubFlavored's, which is
      // inert — first match wins.
      encodeHtml: false,
    ).parse(text.trim());

/// A soft line break inside a paragraph is a space, not a break — the same
/// normalization `MarkdownBody` applies. A real `<br>` still breaks.
final _softLineBreak = RegExp(r' ?\n *');

/// Walks one inline node into [spans], carrying [style] down so nested markup
/// (bold inside a link, a link inside emphasis) accumulates rather than
/// replacing what its parent set.
void _appendNode(
  md.Node node,
  List<InlineSpan> spans, {
  TextStyle? style,
  TextStyle? codeStyle,
  TextStyle? linkStyle,
  GestureRecognizer? Function(String url)? recognizerFor,
  Widget Function(MarkdownImageConfig config)? imageBuilder,
  InlineMarkdownOpenLink? onOpenLink,
  GestureRecognizer? recognizer,
  String? href,
}) {
  // Recognizers ride the LEAF spans: RenderParagraph resolves a tap through
  // InlineSpan.getSpanForPosition, which descends past any span carrying
  // children instead of text — so one on a wrapper span is never found.
  TextSpan leaf(String text, TextStyle? leafStyle) => TextSpan(
        text: text,
        style: leafStyle,
        recognizer: recognizer,
        mouseCursor: recognizer == null ? null : SystemMouseCursors.click,
      );

  if (node is md.Text) {
    spans.add(leaf(node.text.replaceAll(_softLineBreak, ' '), style));
    return;
  }
  if (node is! md.Element) return;

  switch (node.tag) {
    case 'img':
      final image = imageBuilder == null ? null : _imageSpan(node, imageBuilder, onOpenLink, href);
      if (image != null) spans.add(image);
      return;
    case 'br':
      spans.add(leaf('\n', style));
      return;
    // The only block element the narrowed syntax set can produce. Paragraphs
    // are flattened onto one line, separated by a space so "a\n\nb" reads
    // "a b" rather than "ab".
    case 'p':
      if (spans.isNotEmpty && !spans.last.toPlainText().endsWith(' ')) {
        spans.add(leaf(' ', style));
      }
      for (final child in node.children ?? const <md.Node>[]) {
        _appendNode(child, spans,
            style: style,
            codeStyle: codeStyle,
            linkStyle: linkStyle,
            recognizerFor: recognizerFor,
            imageBuilder: imageBuilder,
            onOpenLink: onOpenLink,
            recognizer: recognizer,
            href: href);
      }
      return;
    // `code` holds its content literally — never re-parsed — but the mono style
    // merges onto the inherited one, so code inside a link keeps the link's
    // colour instead of reading as ordinary text.
    case 'code':
      spans.add(leaf(node.textContent, (style ?? const TextStyle()).merge(codeStyle)));
      return;
  }

  final childStyle = switch (node.tag) {
    'strong' => (style ?? const TextStyle()).merge(const TextStyle(fontWeight: FontWeight.w700)),
    'em' => (style ?? const TextStyle()).merge(const TextStyle(fontStyle: FontStyle.italic)),
    'del' => (style ?? const TextStyle()).merge(const TextStyle(decoration: TextDecoration.lineThrough)),
    // linkStyle UNDER the inherited style, not over it: an enclosing `**bold**`
    // must survive, or `**[x](u)**` and `[**x**](u)` render differently.
    'a' => (linkStyle ?? const TextStyle()).merge(style),
    _ => style,
  };

  final ownHref = node.tag == 'a' ? node.attributes['href'] : null;
  // An enclosing link stays in force through nested emphasis, so a label that
  // is partly bold — or that is an image — is tappable across the whole label.
  final childRecognizer = ownHref == null ? recognizer : recognizerFor?.call(ownHref) ?? recognizer;
  final childHref = ownHref ?? href;

  final children = <InlineSpan>[];
  for (final child in node.children ?? const <md.Node>[]) {
    _appendNode(
      child,
      children,
      style: childStyle,
      codeStyle: codeStyle,
      linkStyle: linkStyle,
      recognizerFor: recognizerFor,
      imageBuilder: imageBuilder,
      onOpenLink: onOpenLink,
      recognizer: childRecognizer,
      href: childHref,
    );
  }
  if (children.isEmpty) return;

  spans.add(TextSpan(children: children));
}

/// An `![alt](uri)` image, sized from a `#WxH` fragment when there is one (which
/// is how [flagsInMarkdown] carries the glyph size through).
///
/// A `WidgetSpan` cannot carry a [GestureRecognizer] the way a [TextSpan] can,
/// so an image inside a link gets its own detector — otherwise the image half
/// of `[![flag](…) QRZ](url)` is dead and leaks the tap to the row behind it.
WidgetSpan? _imageSpan(
  md.Element node,
  Widget Function(MarkdownImageConfig) imageBuilder,
  InlineMarkdownOpenLink? onOpenLink,
  String? href,
) {
  final src = node.attributes['src'];
  final parsed = src == null ? null : Uri.tryParse(src);
  if (parsed == null) return null;
  final size = _sizeFragment.firstMatch(parsed.fragment);
  final image = imageBuilder(MarkdownImageConfig(
    uri: parsed,
    alt: node.attributes['alt'],
    title: node.attributes['title'],
    width: size == null ? null : double.tryParse(size[1]!),
    height: size == null ? null : double.tryParse(size[2]!),
  ));
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: (href == null || onOpenLink == null)
        ? image
        // Labelled and marked a link: a bare GestureDetector contributes an
        // unlabeled tappable node that a screen reader announces as an
        // anonymous button, out of order with the text beside it.
        : Semantics(
            link: true,
            label: node.attributes['alt'],
            child: GestureDetector(onTap: () => onOpenLink(href), child: image),
          ),
  );
}

final _sizeFragment = RegExp(r'^(\d+)x(\d+)$');
