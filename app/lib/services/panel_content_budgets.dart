// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a panel's content is held to before the app parses or paints any of it.
// A render's `svg` and `markdown`, a descriptor's `preview` and a scene's
// layers are drawn by the app's own renderers, on the UI thread and outside
// the engine's memory ceiling; its `html` is the web view's to parse, and what
// crosses the bridge to it is memory still. So their size — and for SVG, how
// much there is to draw and what it may contain — is bounded here, where the
// document arrives. A document over a budget is refused whole: the pane shows
// a placeholder naming the budget and the console says what was sent. Nothing
// is trimmed or drawn in part.

import 'dart:convert';

/// The most characters of `markdown` content a render may answer, and of a
/// `preview`.
const kPanelDocumentMaxChars = 262144;

/// The most characters of `svg` content a render may answer: what a scene's
/// layers may hold in all, so one document carries what a scene would — a
/// dense chart, a map.
const kPanelSvgMaxChars = 1048576;

/// The most characters of `html` content a render may answer. Larger than the
/// others because the document carries its own images and styles as `data:`
/// URIs — there is no network to fetch them from — and because the web view,
/// not the app, parses it: the app's cost is the copy across the bridge.
const kPanelHtmlMaxChars = 4194304;

/// The most characters of artwork and text a scene's layers may hold in all.
const kSceneArtworkMaxChars = 1048576;

/// The most elements one SVG document may have, and how deeply they may nest.
const kSvgMaxElements = 16384;
const kSvgMaxDepth = 32;

/// Which bound a document broke.
enum PanelBudget {
  /// Longer than its kind allows ([PanelContentRefusal.max] characters).
  characters,

  /// An SVG with more than [PanelContentRefusal.max] elements.
  elements,

  /// An SVG nesting elements more than [PanelContentRefusal.max] deep.
  depth,

  /// An SVG that is not self-contained vector artwork.
  artwork,
}

/// A document a panel may not show. A [FormatException], so a caller that
/// treats a malformed document generically still does; one that can name the
/// budget to the operator reads [budget] and [max], and [message] says what
/// was sent for the console.
class PanelContentRefusal extends FormatException {
  final PanelBudget budget;

  /// The bound, for the three counted budgets; null for [PanelBudget.artwork].
  final int? max;

  PanelContentRefusal(this.budget, this.max, String message) : super(message);
}

/// The reason a render's `content` of [kind] may not be shown, or null when it
/// may — or when [kind] is not a document kind, whose handling is the view's.
PanelContentRefusal? panelDocumentRefusal(String kind, String content) {
  final maxChars = switch (kind) {
    'markdown' => kPanelDocumentMaxChars,
    'svg' => kPanelSvgMaxChars,
    'html' => kPanelHtmlMaxChars,
    _ => null,
  };
  if (maxChars == null) return null;
  final what = '$kind content';
  if (content.length > maxChars) return _overLength(what, content.length, maxChars);
  return kind == 'svg' ? svgArtworkRefusal(what, content) : null;
}

/// The reason a descriptor's `preview` may not be shown, or null: longer than
/// [kPanelDocumentMaxChars], or an SVG — a document, or the payload of a
/// `data:image/svg+xml` URI — that [svgArtworkRefusal] refuses. A `data:`
/// payload that does not decode breaks no budget: null here, and the thumbnail
/// says why where it fails to draw.
PanelContentRefusal? panelPreviewRefusal(String preview) {
  if (preview.length > kPanelDocumentMaxChars) return _overLength('preview', preview.length, kPanelDocumentMaxChars);
  final trimmed = preview.trimLeft();
  if (trimmed.startsWith('<svg') || trimmed.startsWith('<?xml')) return svgArtworkRefusal('preview', preview);
  if (!trimmed.startsWith('data:image/svg+xml')) return null;
  final String decoded;
  try {
    decoded = utf8.decode(UriData.fromUri(Uri.parse(trimmed)).contentAsBytes());
  } on Exception {
    return null;
  }
  return svgArtworkRefusal('preview', decoded);
}

PanelContentRefusal _overLength(String what, int length, int max) =>
    PanelContentRefusal(PanelBudget.characters, max, '$what is $length characters, at most $max');

/// The reason [svg] may not be drawn, or null when it may: it is not
/// self-contained vector artwork — an `<image>`, `<script>` or
/// `<foreignObject>` element, or an entity declaration — has more than
/// [kSvgMaxElements] elements, or nests them deeper than [kSvgMaxDepth]. A
/// DOCTYPE with no internal subset, as editors export, declares nothing and
/// passes; the painter's parser expands no declared entity either way, so
/// the refusal is of a document shaped to make some parser do so.
///
/// One pass over the text, not a parse: this runs before the painter's parser
/// does, on documents that parser is being kept from, and reads only tag
/// boundaries. It has to see every tag that parser sees, so it reads each
/// boundary as the parser does, and where the two could differ the document
/// is refused rather than read either way. A comment, a CDATA section and a
/// processing instruction are skipped whole. A `>` inside a quoted attribute
/// value, which XML allows, ends no tag — and a DOCTYPE or declaration holding
/// a `>` inside its quotes is refused, since resuming at the first `>` would
/// read the rest of the document from inside the literal. A tag name ends at
/// any of the whitespace the parser accepts, the Unicode set and not only
/// XML's four. An element is closed only by an end tag of its own name, exactly
/// as the painter closes a group. A tag name is compared whole and without
/// regard to case, so `<images>` is not `<image>` and `<IMAGE>` is.
PanelContentRefusal? svgArtworkRefusal(String what, String svg) {
  var elements = 0, i = 0;
  final open = <String>[]; // The elements not yet closed, outermost first: the depth.
  final n = svg.length;
  PanelContentRefusal notArtwork(String why) => PanelContentRefusal(PanelBudget.artwork, null, '$what is not self-contained vector artwork: $why');
  while (i < n) {
    i = svg.indexOf('<', i) + 1;
    if (i <= 0 || i >= n) break;
    switch (svg.codeUnitAt(i)) {
      case 0x21: // !
        if (svg.startsWith('--', i + 1)) {
          i = _past(svg, '-->', i + 3);
        } else if (svg.startsWith('[CDATA[', i + 1)) {
          i = _past(svg, ']]>', i + 8);
        } else if (svg.startsWith('DOCTYPE', i + 1)) {
          final end = _pastQuoted(svg, '>', i + 8);
          if (end != _past(svg, '>', i + 8)) return notArtwork('its DOCTYPE holds a > inside quotes');
          // A DOCTYPE's internal subset (`[ … ]`) is where entities are declared.
          if (svg.substring(i, end).contains('[')) return notArtwork('it declares entities');
          i = end;
        } else {
          // A bare `<!ENTITY`, or any other declaration.
          return notArtwork('it declares entities');
        }
      case 0x3F: // ? — the declaration, or a processing instruction
        final declarationEnd = _pastQuoted(svg, '?>', i + 1);
        // The declaration's values are read quote-aware and a processing
        // instruction ends at the first `?>`: the two readings have to agree.
        if (declarationEnd != _past(svg, '?>', i + 1)) return notArtwork('its declaration or a processing instruction holds a ?> inside quotes');
        i = declarationEnd;
      case 0x2F: // /
        final closeStart = ++i;
        while (i < n && !_endsName(svg.codeUnitAt(i))) {
          i++;
        }
        // The painter closes an element only by its own name: after `<g>`, a
        // `</x>` leaves the group open and the next `<g>` nests inside it.
        if (open.isNotEmpty && open.last == svg.substring(closeStart, i)) open.removeLast();
        i = _past(svg, '>', i);
      default:
        final nameStart = i;
        while (i < n && !_endsName(svg.codeUnitAt(i))) {
          i++;
        }
        if (i == nameStart) continue; // A stray `<`: the parser's to refuse.
        final name = svg.substring(nameStart, i);
        final lower = name.toLowerCase();
        if (lower == 'image' || lower == 'script' || lower == 'foreignobject') return notArtwork('it has a <$name> element');
        if (++elements > kSvgMaxElements) {
          return PanelContentRefusal(PanelBudget.elements, kSvgMaxElements, '$what has more than $kSvgMaxElements elements');
        }
        final tagEnd = _pastQuoted(svg, '>', i);
        // Self-closing when `/` is the last character before the `>`.
        final selfClosing = svg.codeUnitAt(tagEnd - 2) == 0x2F;
        if (!selfClosing) {
          open.add(name);
          if (open.length > kSvgMaxDepth) {
            return PanelContentRefusal(PanelBudget.depth, kSvgMaxDepth, '$what nests elements more than $kSvgMaxDepth deep');
          }
        }
        i = tagEnd;
    }
  }
  return null;
}

/// The index just past the next [marker] at or after [from], or the end.
int _past(String s, String marker, int from) {
  final at = s.indexOf(marker, from);
  return at < 0 ? s.length : at + marker.length;
}

/// The index just past the next [marker] at or after [from] that is outside
/// quotes, or the end: how the parser reads a tag's attribute values, and a
/// DOCTYPE's and a declaration's quoted literals.
int _pastQuoted(String s, String marker, int from) {
  var quote = 0;
  for (var i = from; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (quote != 0) {
      if (c == quote) quote = 0;
    } else if (c == 0x22 || c == 0x27) {
      quote = c;
    } else if (s.startsWith(marker, i)) {
      return i + marker.length;
    }
  }
  return s.length;
}

/// Whether [c] ends a tag name: `/`, `>`, or whitespace — every character the
/// parser accepts as whitespace between a name and its attributes, which is
/// the Unicode set and not XML's four, so that `<image\u000Bhref="…"/>` is an
/// `<image>` here as it is there.
bool _endsName(int c) =>
    c == 0x2F ||
    c == 0x3E ||
    c == 0x20 ||
    (c >= 0x09 && c <= 0x0D) ||
    c == 0x85 ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFEFF;
