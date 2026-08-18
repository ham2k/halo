// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('inlineMarkdownSpans', () {
    // Command hooks write markdown in their describe/confirm lines — the real
    // radio-commands hook says "Change band to **20m**?" — and a result row
    // rendered that as a literal asterisk soup before this.
    test('renders bold, italic, code and strikethrough', () {
      expect(_textsOf('Change band to **20m**?'), ['Change band to ', '20m', '?']);
      expect(_styleOf('a **b** c', 'b')?.fontWeight, FontWeight.w700);
      expect(_styleOf('a *b* c', 'b')?.fontStyle, FontStyle.italic);
      expect(_styleOf('a _b_ c', 'b')?.fontStyle, FontStyle.italic);
      expect(_styleOf('was ~~5NN~~ 599', '5NN')?.decoration, TextDecoration.lineThrough);

      final code = inlineMarkdownSpans('run `SEED`', codeStyle: const TextStyle(fontFamily: 'Mono'));
      expect(_flatten(code).firstWhere((s) => s.text == 'SEED').style?.fontFamily, 'Mono');
    });

    test('leaves a lone asterisk alone — punctuation is likelier than broken markup', () {
      expect(_textsOf('2 * 3 = 6'), ['2 * 3 = 6']);
      // Not just the single-asterisk case: a `*` used as a field separator is
      // the common shape in a call note, and consuming one deletes operator data.
      expect(_plainTextOf('Rig: FT-991A * Ant: EFHW * QTH: NY'), 'Rig: FT-991A * Ant: EFHW * QTH: NY');
      expect(_plainTextOf('2 * 3 * 4'), '2 * 3 * 4');
    });

    test('reads ** as bold, not as an empty italic wrapping another', () {
      expect(_styleOf('**x**', 'x')?.fontWeight, FontWeight.w700);
      expect(_styleOf('__x__', 'x')?.fontWeight, FontWeight.w700);
    });

    // Extension text is full of identifiers — config keys, field names — and
    // italicising the middle of one is never what the author meant.
    test('does not italicise an underscore inside a word', () {
      expect(_plainTextOf('set some_key_name now'), 'set some_key_name now');
      expect(_plainTextOf('a_b_c_d'), 'a_b_c_d');
      expect(_styleOf('use _this_ one', 'this')?.fontStyle, FontStyle.italic);
    });

    test('resolves backslash escapes instead of emphasising and leaking the backslash', () {
      expect(_plainTextOf(r'a \*not italic\* b'), 'a *not italic* b');
      expect(_styleOf(r'a \*not italic\* b', 'not italic'), isNull);
      expect(_plainTextOf(r'2 \* 3'), '2 * 3');
    });

    test('renders a link as its label, styled, dropping the url from the text', () {
      final spans = inlineMarkdownSpans(
        'see [the docs](https://ham2k.com/docs) first',
        linkStyle: const TextStyle(color: Color(0xFF0000FF)),
      );
      expect(_plainText(spans), 'see the docs first');
      expect(_styleIn(spans, 'the docs')?.color, const Color(0xFF0000FF));
    });

    test('keeps a link destination that contains balanced parens intact', () {
      const input = 'see [Wikipedia](https://en.wikipedia.org/wiki/Amateur_radio_(hobby)) now';
      expect(inlineMarkdownLinkUrls(input), ['https://en.wikipedia.org/wiki/Amateur_radio_(hobby)']);
      // ...and no stray `)` leaks into the rendered line.
      expect(_plainTextOf(input), 'see Wikipedia now');
    });

    test('autolinks a bare url and a bare email, as MarkdownBody did', () {
      const input = 'Friend, https://qrz.com/db/N0DEV and mail me at n0dev@example.com';
      expect(
        inlineMarkdownLinkUrls(input),
        ['https://qrz.com/db/N0DEV', 'mailto:n0dev@example.com'],
      );
      expect(_styleIn(inlineMarkdownSpans(input, linkStyle: const TextStyle(color: Color(0xFF00FF00))),
              'https://qrz.com/db/N0DEV')
          ?.color,
          const Color(0xFF00FF00));
    });

    test('leaves bracket text that is not a link literal', () {
      expect(_plainTextOf('worked [not a link] today'), 'worked [not a link] today');
    });

    test('parses markup nested both ways round, rather than leaking raw markup', () {
      // Bold inside a label: the label formats AND the whole label links.
      final label = inlineMarkdownSpans('[**bold** label](https://ham2k.com)');
      expect(_plainText(label), 'bold label');
      expect(_styleIn(label, 'bold')?.fontWeight, FontWeight.w700);
      expect(inlineMarkdownLinkUrls('[**bold** label](https://ham2k.com)'), ['https://ham2k.com']);

      // A link inside emphasis: the url must not become visible text.
      const wrapped = '**[QRZ](https://qrz.com/db/N0DEV)**';
      expect(_plainTextOf(wrapped), 'QRZ');
      expect(_styleOf(wrapped, 'QRZ')?.fontWeight, FontWeight.w700);
      expect(inlineMarkdownLinkUrls(wrapped), ['https://qrz.com/db/N0DEV']);
    });

    // `!` before a link IS an image in CommonMark, so `Careful![docs](url)`
    // losing its label is correct — MarkdownBody does the same. Pinned so
    // nobody "fixes" it into a divergence from the block renderer.
    test('treats ![label](url) as an image, matching MarkdownBody', () {
      const input = 'Careful![docs](https://x.example) here';
      expect(inlineMarkdownLinkUrls(input), isEmpty);
      // With a builder the image renders; without one it is dropped.
      final withBuilder = inlineMarkdownSpans(input, imageBuilder: (_) => const SizedBox.shrink());
      expect(_flattenAll(withBuilder).whereType<WidgetSpan>(), hasLength(1));
      expect(_plainTextOf(input), 'Careful here');
    });

    test('collects link urls in document order, deduplicated, images excluded', () {
      expect(
        inlineMarkdownLinkUrls('[a](https://a.example) then [b](https://b.example)'),
        ['https://a.example', 'https://b.example'],
      );
      expect(inlineMarkdownLinkUrls('![flag](flag:us#12x9) [b](https://b.example)'), ['https://b.example']);
      // One recognizer per url, even when the same link appears twice.
      expect(
        inlineMarkdownLinkUrls('[a](https://a.example) and again [a](https://a.example)'),
        ['https://a.example'],
      );
      expect(inlineMarkdownLinkUrls('no links here'), isEmpty);
    });

    // No call site passes an imageBuilder today, so nothing else exercises
    // this branch — but the `#WxH` sizing is the contract a future one would
    // rely on, and a renderer that dropped the span would lose the image
    // silently.
    test('renders an image through the builder, sized from its #WxH fragment', () {
      MarkdownImageConfig? seen;
      final spans = inlineMarkdownSpans(
        'from ![flag](flag:us#12x9) today',
        imageBuilder: (config) {
          seen = config;
          return const SizedBox.shrink();
        },
      );
      expect(_flattenAll(spans).whereType<WidgetSpan>(), hasLength(1));
      expect(seen?.uri.scheme, 'flag');
      expect(seen?.uri.path, 'us');
      expect(seen?.width, 12);
      expect(seen?.height, 9);
    });

    // An image inside a link label must stay ONE tappable link. Built WITH an
    // imageBuilder, or the image span the defect lives in never exists.
    test('handles an image nested inside a link label', () {
      const input = '[![flag](flag:us#19x14) QRZ](https://qrz.com/db/K1ABC)';
      expect(inlineMarkdownLinkUrls(input), ['https://qrz.com/db/K1ABC']);
      final spans = inlineMarkdownSpans(input, imageBuilder: (_) => const SizedBox.shrink());
      expect(_flattenAll(spans).whereType<WidgetSpan>(), hasLength(1));
      expect(_plainText(spans), contains('QRZ'));
      expect(_plainText(spans), isNot(contains('flag:us')));
    });

    // `MarkdownBody` builds its document with encodeHtml:false. The default is
    // true, which turns ordinary punctuation into visible HTML entities.
    test('leaves &, < and " as themselves rather than HTML entities', () {
      expect(_plainTextOf('Member of SKCC & FISTS, QRP < 5W'), 'Member of SKCC & FISTS, QRP < 5W');
      expect(_plainTextOf('Bob "Skip" Smith'), 'Bob "Skip" Smith');
      expect(_plainTextOf('R&D team'), 'R&D team');
    });

    test('keeps an autolinked url intact, query string and all', () {
      const input = 'spot https://pota.app/x?a=1&b=2 now';
      expect(inlineMarkdownLinkUrls(input), ['https://pota.app/x?a=1&b=2']);
      expect(_plainTextOf(input), input);
    });

    // Block syntax is deliberately OFF. On a one-line surface these markers are
    // content, not markup — a note opening "73." is far likelier than an
    // ordered list, and treating it as one silently ate the "73.".
    test('leaves block markers literal — on one line they are content', () {
      expect(_plainTextOf('73. tnx for the QSO'), '73. tnx for the QSO');
      expect(_plainTextOf('73) tnx'), '73) tnx');
      expect(_plainTextOf('2024. Field Day partner'), '2024. Field Day partner');
      // The checkbox is the only thing distinguishing these two.
      expect(_plainTextOf('- [x] QSL confirmed'), '- [x] QSL confirmed');
      expect(_plainTextOf('- [ ] QSL confirmed'), '- [ ] QSL confirmed');
      expect(_plainTextOf('- one\n- two'), '- one - two');
      expect(_plainTextOf('---'), '---');
    });

    // ATX headings are the one block marker kept — unambiguous with nothing
    // else this widget leaves literal, since "73." and "- [x]" don't start
    // with "#". Rendered inline (bold, sized) rather than on a block line of
    // their own.
    test('renders an ATX heading as bold text with a per-level size delta, marker stripped', () {
      // inlineMarkdownSpans carries no base style of its own (InlineMarkdownText
      // supplies one via Text.rich's outer style) — the delta lands on
      // flagGlyphDefaultFontSize (16) here, same fallback _headingFontSizeDelta
      // itself uses when a caller's style has no fontSize.
      TextStyle? styleOf(String input) => _styleIn(inlineMarkdownSpans(input), 'Heading');

      expect(_plainTextOf('# Heading'), 'Heading');
      expect(styleOf('# Heading')?.fontWeight, FontWeight.w700);
      expect(styleOf('# Heading')?.fontSize, 20); // 16 + 4

      expect(_plainTextOf('## Heading'), 'Heading');
      expect(styleOf('## Heading')?.fontSize, 18); // 16 + 2

      expect(_plainTextOf('### Heading'), 'Heading');
      expect(styleOf('### Heading')?.fontSize, 16); // 16 + 0

      expect(_plainTextOf('#### Heading'), 'Heading');
      expect(styleOf('#### Heading')?.fontSize, 14); // 16 - 2

      expect(_plainTextOf('##### Heading'), 'Heading');
      expect(styleOf('##### Heading')?.fontSize, 12); // 16 - 4

      expect(_plainTextOf('###### Heading'), 'Heading');
      expect(styleOf('###### Heading')?.fontSize, 10); // 16 - 6
    });

    test('a heading without a space after the marker stays literal, as CommonMark requires', () {
      expect(_plainTextOf('#nofollow'), '#nofollow');
    });

    // The delta is relative to the CALLER's actual font size, not a hardcoded
    // default — a note rendered at 12px must get a 16px heading (12+4), not
    // flagGlyphDefaultFontSize+4, or a heading in a small control would jump
    // to a fixed size unrelated to its surroundings.
    test('the heading size delta is relative to baseFontSize, not a hardcoded default', () {
      final spans = inlineMarkdownSpans('# Heading', baseFontSize: 12);
      expect(_styleIn(spans, 'Heading')?.fontSize, 16); // 12 + 4
    });

    test('nested inline markup inside a heading still parses, and inherits the heading style', () {
      // Italic, not bold: bold alone wouldn't distinguish "the heading forced
      // it" from "the emphasis did" — italic only appears if nested inline
      // parsing actually ran inside the heading's content.
      final spans = inlineMarkdownSpans('# Welcome *N0DEV*');
      expect(_plainText(spans), 'Welcome N0DEV');
      final style = _styleIn(spans, 'N0DEV');
      expect(style?.fontStyle, FontStyle.italic);
      expect(style?.fontWeight, FontWeight.w700); // inherited from the heading
    });

    test('a heading joins onto a preceding paragraph with a space, same as two paragraphs would', () {
      expect(_plainTextOf('Intro\n# Heading'), 'Intro Heading');
    });

    // The joining space is not itself heading content — sizing it like the
    // heading (+4px, bold) would make it a taller glyph than the space that
    // opens an ordinary two-paragraph join, inflating line height in a
    // single-line control for no visible reason (a space has no ink to show
    // the size at).
    test('the space joining onto a heading keeps the PRECEDING style, not the heading\'s bold/size', () {
      final spans = inlineMarkdownSpans('Intro\n# Heading', baseFontSize: 14);
      final joinSpace = _styleIn(spans, ' ');
      expect(joinSpace?.fontWeight, isNot(FontWeight.w700));
      expect(joinSpace?.fontSize, isNot(18)); // 14 + 4, the heading's own size
    });

    // A setext underline makes ParagraphSyntax discard the paragraph it had
    // already accumulated, and it asks every syntax in the list regardless of
    // order — so the catch-all does NOT mask it. Without
    // withDefaultBlockSyntaxes:false, `Nice op\n---` renders as just `---`.
    test('keeps a line that a setext underline would otherwise delete', () {
      expect(_plainTextOf('Nice op\n---'), 'Nice op ---');
      expect(_plainTextOf('Nice op\n==='), 'Nice op ===');
      expect(_plainTextOf('Worked him on 20m\n-'), 'Worked him on 20m -');
    });

    // Kept deliberately: this is the price of `[QRZ]` resolving against a later
    // `[QRZ]: https://…`. MarkdownBody does the same.
    test('a link reference definition is consumed, as MarkdownBody consumes it', () {
      expect(_plainTextOf('[QSL]: bureau'), '');
      // Two tokens is not a definition, so ordinary prose survives.
      expect(_plainTextOf('[QSL]: bureau only'), '[QSL]: bureau only');
    });

    test('flattens paragraphs onto one line, separated by a space, and trims', () {
      expect(_plainTextOf('first\n\nsecond'), 'first second');
      expect(_plainTextOf('  leading and trailing   '), 'leading and trailing');
    });

    // The separator check has to see the image: a link ending in a flag reports
    // a trailing space from the text BEFORE it unless placeholders count.
    test('separates paragraphs when the previous one ends in an image', () {
      final spans = inlineMarkdownSpans(
        '[QRZ ![f](flag:us#16x12)](https://x.example)\n\nsecond',
        imageBuilder: (_) => const SizedBox.shrink(),
      );
      // "QRZ " + <image> + " " + "second" — two spaces once the image is skipped.
      expect(_plainText(spans), 'QRZ  second');
    });

    test('collapses a soft line break to a space, but keeps a hard break', () {
      expect(_plainTextOf('one\ntwo'), 'one two');
      expect(_plainTextOf('one  \ntwo'), 'one\ntwo');
    });

    test('resolves a reference-style link and hides its definition', () {
      const input = '[ref][r]\n\n[r]: https://ref.example';
      expect(inlineMarkdownLinkUrls(input), ['https://ref.example']);
      expect(_plainTextOf(input), 'ref');
    });

    test('keeps an enclosing bold when a link is nested inside it', () {
      // Both nestings must agree — the author wrote the same thing either way.
      for (final input in ['**[QRZ](https://q.example)**', '[**QRZ**](https://q.example)']) {
        final spans = inlineMarkdownSpans(input, linkStyle: const TextStyle(color: Color(0xFF0000FF)));
        expect(_styleIn(spans, 'QRZ')?.fontWeight, FontWeight.w700, reason: input);
        expect(_styleIn(spans, 'QRZ')?.color, const Color(0xFF0000FF), reason: input);
      }
    });

    test('keeps the link styling on a code span inside a link label', () {
      final spans = inlineMarkdownSpans(
        'run [`SEED`](https://x.example)',
        linkStyle: const TextStyle(color: Color(0xFF0000FF)),
        codeStyle: const TextStyle(fontFamily: 'Mono'),
      );
      expect(_styleIn(spans, 'SEED')?.fontFamily, 'Mono');
      expect(_styleIn(spans, 'SEED')?.color, const Color(0xFF0000FF));
    });

    test('drops images when no builder is given, rather than showing the markup', () {
      expect(_plainTextOf('from ![flag](flag:us#12x9) today'), 'from  today');
    });

    test('attaches a recognizer per link url via recognizerFor', () {
      final first = TapGestureRecognizer();
      final second = TapGestureRecognizer();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final byUrl = {'https://a.example': first, 'https://b.example': second};

      final spans = inlineMarkdownSpans(
        '[a](https://a.example) and [b](https://b.example)',
        recognizerFor: (url) => byUrl[url],
      );
      final linked = _flattenAll(spans).whereType<TextSpan>().where((s) => s.recognizer != null).toList();
      expect(linked.map((s) => s.recognizer).toList(), [first, second]);
      expect(linked.first.mouseCursor, SystemMouseCursors.click);
    });

    test('renders links with no recognizer when recognizerFor gives none', () {
      final spans = inlineMarkdownSpans('[a](https://a.example)');
      for (final span in _flattenAll(spans).whereType<TextSpan>()) {
        expect(span.recognizer, isNull);
        expect(span.mouseCursor, MouseCursor.defer);
      }
    });
  });

  group('InlineMarkdownText', () {
    testWidgets('actually ellipsizes rather than wrapping — the reason this exists', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 120,
        child: InlineMarkdownText(
          'A **very** long description that cannot possibly fit on one line',
          maxLines: 1,
        ),
      )));

      final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
      expect(paragraph.didExceedMaxLines, isTrue, reason: 'should have been truncated, not wrapped');
      expect(paragraph.size.height, lessThan(30), reason: 'a single line');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a heading size delta is relative to the widget\'s own style, not a hardcoded default',
        (tester) async {
      // Regression: baseFontSize must reach _appendNode from widget.style —
      // without it, a heading in a small control (here 10px) would jump to
      // flagGlyphDefaultFontSize+4 (20px) instead of 10+4=14px.
      await tester.pumpWidget(_host(const InlineMarkdownText(
        '# Small heading',
        style: TextStyle(fontSize: 10),
      )));

      final richText = tester.widget<RichText>(find.byType(RichText));
      TextStyle? styleOf(InlineSpan span) {
        if (span is TextSpan && span.text == 'Small heading') return span.style;
        for (final child in (span is TextSpan ? span.children : null) ?? const <InlineSpan>[]) {
          final found = styleOf(child);
          if (found != null) return found;
        }
        return null;
      }

      expect(styleOf(richText.text)?.fontSize, 14); // 10 + 4, not 16 + 4
    });

    testWidgets('opens a tapped link through onOpenLink', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(_host(InlineMarkdownText(
        'see [the docs](https://ham2k.com/docs)',
        onOpenLink: opened.add,
      )));

      // Tapped on the label itself — a plain `tap` hits the RichText's centre,
      // which is not necessarily inside the link span.
      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(opened, ['https://ham2k.com/docs']);
    });

    // The whole point of leaving onOpenLink null: the row around the text owns
    // the tap. An inert link that still joins the gesture arena makes the row
    // un-clickable exactly where the link sits.
    testWidgets('with no onOpenLink, a tap on the link reaches the enclosing row', (tester) async {
      var rowTaps = 0;
      await tester.pumpWidget(_host(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => rowTaps++,
        child: const InlineMarkdownText('run [the thing](https://x.example) now'),
      )));

      await tester.tapOnText(find.textRange.ofSubstring('the thing'));
      await tester.pump();
      expect(rowTaps, 1, reason: 'the inert link must not swallow the row tap');

      await tester.tapOnText(find.textRange.ofSubstring('now'));
      await tester.pump();
      expect(rowTaps, 2);
    });

    testWidgets('a link keeps working across a text change, and retires urls that go away', (tester) async {
      final opened = <String>[];
      Widget at(String text) => _host(InlineMarkdownText(text, onOpenLink: opened.add));

      await tester.pumpWidget(at('go to [one](https://one.example)'));
      await tester.pumpWidget(at('go to [two](https://two.example)'));

      await tester.tapOnText(find.textRange.ofSubstring('two'));
      await tester.pump();
      expect(opened, ['https://two.example']);

      // A surviving url must keep the SAME recognizer object. Opening the right
      // url is not enough to prove that: an implementation that disposed and
      // recreated every recognizer on each text change would also pass, and
      // would drop a press already in flight.
      //
      // (That the RETIRED recognizer gets disposed is deliberately not asserted
      // — a disposed GestureRecognizer throws on neither double-dispose nor
      // use-after-dispose, so there is nothing observable to assert on.)
      final before = _recognizerFor(tester, 'two');
      expect(before, isNotNull);
      await tester.pumpWidget(at('go to [two](https://two.example) again'));
      expect(_recognizerFor(tester, 'two'), same(before));
    });

    // A WidgetSpan can't carry a recognizer, so the image needs its own
    // detector — without one the image half of a link is dead.
    testWidgets('an image inside a link opens it too, not just the text', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(_host(InlineMarkdownText(
        '[![flag](flag:us#19x14) QRZ](https://qrz.com/db/K1ABC)',
        onOpenLink: opened.add,
        imageBuilder: (config) => Container(width: config.width, height: config.height, color: const Color(0xFFFF0000)),
      )));

      await tester.tap(find.byType(Container));
      await tester.pump();
      expect(opened, ['https://qrz.com/db/K1ABC'], reason: 'tapping the flag should open the link');

      await tester.tapOnText(find.textRange.ofSubstring('QRZ'));
      await tester.pump();
      expect(opened, hasLength(2));
    });

    testWidgets('gains recognizers when onOpenLink arrives after the first build', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(_host(const InlineMarkdownText('see [docs](https://ham2k.com)')));
      await tester.pumpWidget(_host(InlineMarkdownText('see [docs](https://ham2k.com)', onOpenLink: opened.add)));

      await tester.tapOnText(find.textRange.ofSubstring('docs'));
      await tester.pump();

      expect(opened, ['https://ham2k.com']);
    });
  });
}

// ---- helpers ----

/// Every TextSpan in the tree, depth-first — spans nest now that markup nests.
Iterable<TextSpan> _flatten(List<InlineSpan> spans) => _flattenAll(spans).whereType<TextSpan>();

Iterable<InlineSpan> _flattenAll(List<InlineSpan> spans) sync* {
  for (final span in spans) {
    yield span;
    if (span is TextSpan) yield* _flattenAll(span.children ?? const []);
  }
}

/// The leaf text runs, in order — what the operator actually reads.
List<String?> _textsOf(String input) => _flatten(inlineMarkdownSpans(input))
    .where((s) => s.text != null)
    .map((s) => s.text)
    .toList();

String _plainTextOf(String input) => _plainText(inlineMarkdownSpans(input));

String _plainText(List<InlineSpan> spans) =>
    _flatten(spans).map((s) => s.text ?? '').join();

/// The resolved style of the leaf run whose text is [text].
TextStyle? _styleOf(String input, String text) => _styleIn(inlineMarkdownSpans(input), text);

TextStyle? _styleIn(List<InlineSpan> spans, String text) {
  for (final span in _flatten(spans)) {
    if (span.text == text) return span.style;
  }
  return null;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

/// The recognizer attached to the rendered leaf whose text is [text].
GestureRecognizer? _recognizerFor(WidgetTester tester, String text) {
  GestureRecognizer? found;
  void walk(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text == text) found ??= span.recognizer;
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child);
    }
  }

  walk(tester.widget<RichText>(find.byType(RichText)).text);
  return found;
}
