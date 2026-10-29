// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The budgets a panel's content is held to (panel_content_budgets.dart). A
// document over one is refused whole: the pane names the budget, the console
// says what was sent, and nothing is reported — the budget is the
// extension's to keep, not a failure of the app's.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_content_budgets.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_panel_extensions.dart';
import '../support/image_headers.dart';

/// An SVG of exactly [elements] elements, the root included.
String flat(int elements, {String inside = ''}) => '<svg xmlns="http://www.w3.org/2000/svg">$inside${'<rect/>' * (elements - 1)}</svg>';

/// An SVG nested exactly [depth] deep, the root counted, with [leaf] at the bottom.
String nested(int depth, {String leaf = ''}) => '<svg>${'<g>' * (depth - 1)}$leaf${'</g>' * (depth - 1)}</svg>';

Map<String, dynamic> scene({
  required List<Map<String, dynamic>> layers,
  Map<String, double> values = const {},
  Map<String, String> strings = const {},
  List<Map<String, dynamic>> controls = const [],
  Map<String, dynamic>? layout,
}) => {'version': 1, 'width': 400, 'height': 100, 'values': values, 'strings': strings, 'layers': layers, 'controls': controls, 'layout': ?layout};

Map<String, dynamic> layer(String id, String svg, {Map<String, dynamic>? when}) => {
  'id': id,
  'x': 0,
  'y': 0,
  'width': 400,
  'height': 100,
  'svg': svg,
  'when': ?when,
};

Map<String, dynamic> button(String id, {List<Map<String, String>>? menu}) => {
  'id': id,
  'label': id,
  'kind': 'button',
  'x': 0,
  'y': 0,
  'width': 40,
  'height': 20,
  'event': 'go',
  'menu': ?menu,
};

/// A layout [depth] columns deep, the scene node at the bottom.
Map<String, dynamic> nestedLayout(int depth) => depth == 1
    ? {'scene': true}
    : {
        'column': [nestedLayout(depth - 1)],
      };

List<T> many<T>(int count, T Function(int) make) => [for (var i = 0; i < count; i++) make(i)];

/// A malformed scene is refused as what it is, never as a budget.
final malformed = throwsA(allOf(isA<FormatException>(), isNot(isA<PanelContentRefusal>())));

Matcher refusedFor(PanelBudget budget, {int? max}) =>
    throwsA(isA<PanelContentRefusal>().having((r) => r.budget, 'budget', budget).having((r) => r.max, 'max', max));

void main() {
  group('an SVG document', () {
    test('is counted at its bounds, elements and depth alike', () {
      expect(svgArtworkRefusal('svg content', flat(kSvgMaxElements)), isNull);
      expect(svgArtworkRefusal('svg content', flat(kSvgMaxElements + 1))?.budget, PanelBudget.elements);
      expect(svgArtworkRefusal('svg content', nested(kSvgMaxDepth)), isNull);
      expect(svgArtworkRefusal('svg content', nested(kSvgMaxDepth + 1))?.budget, PanelBudget.depth);
      // Siblings are not nesting: a closing tag counts the depth back down.
      expect(svgArtworkRefusal('svg content', '<svg>${'<g></g>' * (kSvgMaxDepth + 1)}</svg>'), isNull);
    });

    test('counts only elements: not comments, CDATA, processing instructions, or a > inside an attribute', () {
      // The trap: a scan that takes every `<` for a tag counts the rects in a
      // comment, nests the groups in a CDATA section, counts the XML
      // declaration, and reads a `>` inside an attribute value (legal in XML)
      // as the end of a self-closing tag — one more level of depth. Each
      // document here is exactly at its bound, so any of those refuses it.
      expect(svgArtworkRefusal('svg content', flat(kSvgMaxElements, inside: '<!-- <rect/><rect/> -->')), isNull);
      expect(svgArtworkRefusal('svg content', '<?xml version="1.0"?>${flat(kSvgMaxElements)}'), isNull);
      expect(svgArtworkRefusal('svg content', nested(kSvgMaxDepth, leaf: '<![CDATA[ <g><g> ]]>')), isNull);
      expect(svgArtworkRefusal('svg content', nested(kSvgMaxDepth, leaf: '<path d="M0 0" data-x="a>b"/>')), isNull);
      expect(svgArtworkRefusal('svg content', nested(kSvgMaxDepth, leaf: "<path data-x='a>b' />")), isNull);
      // A tag the document ends inside of is the parser's to refuse, not a walk past the end.
      expect(svgArtworkRefusal('svg content', '<svg><rect'), isNull);
      expect(svgArtworkRefusal('svg content', '<svg><!-- '), isNull);
    });

    test('refuses what is not self-contained artwork, whatever its case, by whole tag name', () {
      for (final tag in ['<image href="data:,x"/>', '<SCRIPT>', '<foreignObject>', '<!ENTITY x "y">']) {
        expect(svgArtworkRefusal('svg content', '<svg>$tag</svg>')?.budget, PanelBudget.artwork, reason: tag);
      }
      // `<images>` is not `<image>`.
      expect(svgArtworkRefusal('svg content', '<svg><images/><scripting/></svg>'), isNull);
    });

    test('a DOCTYPE passes as editors export it, and is refused with an internal subset', () {
      // The trap: refusing every DOCTYPE turns away the first line of every
      // exported drawing, while the only thing a DOCTYPE can carry that a
      // parser might act on is an entity declared between its brackets.
      const exported = '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">';
      expect(svgArtworkRefusal('svg content', '<?xml version="1.0"?>$exported${flat(kSvgMaxElements)}'), isNull, reason: 'not an element either');
      expect(svgArtworkRefusal('svg content', '<!DOCTYPE svg [ <!ENTITY x "y"> ]><svg>&x;</svg>')?.budget, PanelBudget.artwork);
      expect(svgArtworkRefusal('svg content', '<!DOCTYPE svg [\n<!ELEMENT svg ANY>\n]><svg/>')?.budget, PanelBudget.artwork);
    });

    test('reads a DOCTYPE, a declaration, a name and an end tag as the parser does, so nothing hides behind them', () {
      // The trap: the parser reads a DOCTYPE's literals and the declaration's
      // values quote-aware, so a `>` inside quotes ends neither for it — a
      // scan ending at the first `>` resumes inside the literal, takes the
      // `<!--` there for a comment, and skips the whole document the parser
      // then draws. Any Unicode whitespace ends a name for the parser, so
      // `image\u000Bhref` is an `<image>` with an href to it. And the painter
      // closes an element only by its own end tag, so `<g></x>` repeated is
      // a group nested as many times for it, not siblings.
      const literal = '<!DOCTYPE svg SYSTEM "><!--">';
      expect(svgArtworkRefusal('svg content', '$literal<svg>${'<rect/>' * kSvgMaxElements}</svg>')?.budget, PanelBudget.artwork);
      expect(svgArtworkRefusal('svg content', '$literal<svg><image href="data:,x"/></svg>')?.budget, PanelBudget.artwork);
      expect(svgArtworkRefusal('svg content', '<?xml version="?><!--"?><svg><image href="data:,x"/></svg>')?.budget, PanelBudget.artwork);
      // The other way round for a processing instruction, which the parser
      // ends at the first `?>`: read quote-aware, the scan would skip the
      // <image> the parser draws.
      expect(svgArtworkRefusal('svg content', '<?foo "?><image href="data:,x"/>"?><svg/>')?.budget, PanelBudget.artwork);
      for (final space in ['\u000B', '\u000C', '\u0085', '\u00A0', '\u2003', '\u3000']) {
        final hex = space.codeUnitAt(0).toRadixString(16);
        expect(svgArtworkRefusal('svg content', '<svg><image${space}href="data:,x"/></svg>')?.budget, PanelBudget.artwork, reason: 'U+$hex');
      }
      expect(svgArtworkRefusal('svg content', '<svg><path\u000Bd="M0 0"/>${'<rect/>' * kSvgMaxElements}</svg>')?.budget, PanelBudget.elements);
      expect(svgArtworkRefusal('svg content', '<svg>${'<g></x>' * (kSvgMaxDepth + 1)}</svg>')?.budget, PanelBudget.depth);
      expect(svgArtworkRefusal('svg content', '<svg>${'<g></G>' * (kSvgMaxDepth + 1)}</svg>')?.budget, PanelBudget.depth);
      expect(svgArtworkRefusal('svg content', '<svg>${'<g></x>' * (kSvgMaxDepth - 1)}</svg>'), isNull);
    });
  });

  group('a render result', () {
    test('is refused over its kind\'s characters, at that kind\'s own bound', () {
      expect(
        () => PanelContent.fromJson({'kind': 'markdown', 'content': 'a' * (kPanelDocumentMaxChars + 1)}),
        refusedFor(PanelBudget.characters, max: kPanelDocumentMaxChars),
      );
      expect(PanelContent.fromJson({'kind': 'markdown', 'content': 'a' * kPanelDocumentMaxChars})?.kind, 'markdown');
      expect(
        () => PanelContent.fromJson({'kind': 'svg', 'content': 'a' * (kPanelSvgMaxChars + 1)}),
        refusedFor(PanelBudget.characters, max: kPanelSvgMaxChars),
      );
      expect(PanelContent.fromJson({'kind': 'svg', 'content': 'a' * kPanelSvgMaxChars})?.kind, 'svg');
      expect(
        () => PanelContent.fromJson({'kind': 'html', 'content': 'a' * (kPanelHtmlMaxChars + 1)}),
        refusedFor(PanelBudget.characters, max: kPanelHtmlMaxChars),
      );
      expect(PanelContent.fromJson({'kind': 'html', 'content': 'a' * kPanelHtmlMaxChars})?.kind, 'html');
    });

    test('an svg is held to the artwork budget, and only an svg', () {
      expect(() => PanelContent.fromJson({'kind': 'svg', 'content': flat(kSvgMaxElements + 1)}), refusedFor(PanelBudget.elements, max: kSvgMaxElements));
      expect(() => PanelContent.fromJson({'kind': 'svg', 'content': '<svg><script/></svg>'}), refusedFor(PanelBudget.artwork));
      // Markdown may mention a script tag; only an svg is artwork.
      expect(PanelContent.fromJson({'kind': 'markdown', 'content': '<svg><script/></svg>'})?.kind, 'markdown');
      // An unknown kind is the view's to refuse, not a budget's.
      expect(PanelContent.fromJson({'kind': 'pdf', 'content': 'a' * (kPanelHtmlMaxChars + 1)})?.kind, 'pdf');
    });

    test('judges a document unlike the one before, and the same one not again', () {
      // The trap: a ticking panel sends the same document every tick, and
      // what the pane holds was judged when it arrived — rescanning a
      // megabyte of it once a second is work for nothing. A document that
      // differs from it in any character, or in kind, is judged afresh.
      final bad = flat(kSvgMaxElements + 1);
      expect(
        () => PanelContent.fromJson({'kind': 'svg', 'content': bad}, previous: const PanelContent(kind: 'svg', content: 'other')),
        refusedFor(PanelBudget.elements, max: kSvgMaxElements),
      );
      expect(
        () => PanelContent.fromJson({'kind': 'svg', 'content': bad}, previous: PanelContent(kind: 'markdown', content: bad)),
        refusedFor(PanelBudget.elements, max: kSvgMaxElements),
      );
      expect(PanelContent.fromJson({'kind': 'svg', 'content': bad}, previous: PanelContent(kind: 'svg', content: bad))?.kind, 'svg');
    });
  });

  group('a scene', () {
    test('holds each layer\'s artwork to the same budget', () {
      expect(() => PanelScene(scene(layers: [layer('a', flat(kSvgMaxElements + 1))])), refusedFor(PanelBudget.elements, max: kSvgMaxElements));
      expect(() => PanelScene(scene(layers: [layer('a', nested(kSvgMaxDepth + 1))])), refusedFor(PanelBudget.depth, max: kSvgMaxDepth));
      expect(() => PanelScene(scene(layers: [layer('a', '<svg><foreignObject/></svg>')])), refusedFor(PanelBudget.artwork));
      expect(PanelScene(scene(layers: [layer('a', flat(kSvgMaxElements)), layer('b', nested(kSvgMaxDepth))])).layers, hasLength(2));
    });

    test('is refused over its artwork and text in all', () {
      // A scene string is itself at most 262,144 characters, so the total takes several layers to reach.
      final quarter = '<svg>${'x' * (kSceneArtworkMaxChars ~/ 4 - 11)}</svg>';
      expect(quarter.length, kSceneArtworkMaxChars ~/ 4);
      List<Map<String, dynamic>> layers(int count) => [for (var i = 0; i < count; i++) layer('l$i', quarter)];
      expect(() => PanelScene(scene(layers: layers(5))), refusedFor(PanelBudget.characters, max: kSceneArtworkMaxChars));
      expect(PanelScene(scene(layers: layers(4))).layers, hasLength(4));
    });

    test('names each of its counts as the budget it is, at the bound', () {
      // The trap: a cap folded into the shape check ('Invalid scene items')
      // reports an extension's oversized scene as the app's failure and tells
      // its author nothing — the number is the point of a budget.
      final layers = many(512, (i) => layer('l$i', '<svg/>'));
      expect(PanelScene(scene(layers: layers)).layers, hasLength(512));
      expect(() => PanelScene(scene(layers: [...layers, layer('more', '<svg/>')])), refusedFor(PanelBudget.layers, max: 512));
      final controls = many(256, (i) => button('c$i'));
      expect(PanelScene(scene(layers: layers, controls: controls)).controls, hasLength(256));
      expect(() => PanelScene(scene(layers: layers, controls: [...controls, button('more')])), refusedFor(PanelBudget.controls, max: 256));
      final values = {for (var i = 0; i < 257; i++) 'v$i': 0.0};
      expect(() => PanelScene(scene(layers: layers, values: values)), refusedFor(PanelBudget.items, max: 256));
      expect(PanelScene(scene(layers: layers, values: {...values}..remove('v0'))).values, hasLength(256));
      expect(() => PanelScene(scene(layers: layers, strings: {for (var i = 0; i < 257; i++) 's$i': ''})), refusedFor(PanelBudget.items, max: 256));
      expect(
        () => PanelScene(
          scene(
            layers: layers,
            controls: [
              button('m', menu: many(33, (i) => {'label': 'a', 'event': 'e'})),
            ],
          ),
        ),
        refusedFor(PanelBudget.items, max: 32),
      );
      expect(
        () => PanelScene(
          scene(
            layers: layers,
            values: {'v': 1},
            controls: [],
            layout: {
              'column': many(129, (i) => {'spacer': 1}),
            },
          ),
        ),
        // The node count shares the budget and the bound; only the message says which was crossed.
        throwsA(isA<PanelContentRefusal>().having((r) => r.message, 'message', 'scene has 129 layout children, at most 128')),
      );
      expect(
        () => PanelScene(
          scene(
            layers: layers,
            layout: {
              'column': [
                {
                  'column': many(64, (i) => {'spacer': 1}),
                },
                {
                  'column': many(64, (i) => {'spacer': 1}),
                },
              ],
            },
          ),
        ),
        throwsA(isA<PanelContentRefusal>().having((r) => r.message, 'message', 'scene layout has more than 128 nodes')),
      );
      final conditioned = layer('w', '<svg/>', when: {'value': 'v', 'in': List.filled(257, 1)});
      expect(() => PanelScene(scene(layers: [conditioned], values: {'v': 1})), refusedFor(PanelBudget.items, max: 256));
      // What is malformed, not oversized, stays a malformed scene.
      expect(() => PanelScene({...scene(layers: layers), 'layers': 'nope'}), malformed);
      expect(
        () => PanelScene(
          scene(
            layers: [
              layer('w', '<svg/>', when: {'value': 'v', 'in': []}),
            ],
            values: {'v': 1},
          ),
        ),
        malformed,
      );
      expect(() => PanelScene({...scene(layers: layers), 'values': 7}), malformed);
    });

    test('names a string over its length, and a layout nested too deep', () {
      expect(() => PanelScene(scene(layers: [layer('a', '<svg/>')], strings: {'s': 'x' * 4097})), refusedFor(PanelBudget.stringLength, max: 4096));
      expect(PanelScene(scene(layers: [layer('a', '<svg/>')], strings: {'s': 'x' * 4096})).strings['s'], hasLength(4096));
      expect(() => PanelScene(scene(layers: [layer('a', 'x' * (sceneFieldMaxLength + 1))])), refusedFor(PanelBudget.stringLength, max: sceneFieldMaxLength));
      expect(
        () => PanelScene(
          scene(
            layers: [
              layer('a', '<svg/>', when: {'value': 'v', 'is': 'x' * 4097}),
            ],
            values: {'v': 1},
          ),
        ),
        refusedFor(PanelBudget.stringLength, max: 4096),
      );
      expect(() => PanelScene(scene(layers: [layer('a', '<svg/>')], layout: nestedLayout(9))), refusedFor(PanelBudget.layoutDepth, max: 8));
      expect(PanelScene(scene(layers: [layer('a', '<svg/>')], layout: nestedLayout(8))).layout, isNotNull);
    });

    test('holds its samples, value labels, annotations and waterfall colors to their bounds by name too', () {
      // The trap: a cap checked inside a shape check reads an oversized scene
      // as a malformed one — reported, and no number for the author.
      expect(
        () => SceneBinding({
          'value': 'v',
          'input': [0, 1],
          'output': [0, 1],
          'samples': List.filled(4097, 1),
        }),
        refusedFor(PanelBudget.items, max: 4096),
      );
      expect(
        SceneBinding({
          'value': 'v',
          'input': [0, 1],
          'output': [0, 1],
          'samples': List.filled(4096, 1),
        }).samples,
        hasLength(4096),
      );
      expect(
        () => SceneBinding({
          'value': 'v',
          'input': [0, 1],
          'output': [0, 1],
          'samples': <int>[],
        }),
        malformed,
      );
      final textLayer = {
        'id': 't',
        'x': 0,
        'y': 0,
        'width': 400,
        'height': 100,
        'text': {'value': 'v', 'samples': List.filled(4097, 'x')},
      };
      expect(() => PanelScene(scene(layers: [textLayer], values: {'v': 1})), refusedFor(PanelBudget.items, max: 4096));
      final slider = {
        'id': 's',
        'label': 's',
        'kind': 'slider',
        'x': 0,
        'y': 0,
        'width': 100,
        'height': 20,
        'value': 'v',
        'min': 0,
        'max': 1,
        'step': 1,
        'valueLabels': List.filled(4097, 'l'),
      };
      expect(() => PanelScene(scene(layers: [layer('a', '<svg/>')], values: {'v': 0}, controls: [slider])), refusedFor(PanelBudget.items, max: 4096));
      expect(() => SceneSpectrumAnnotation({'id': 'a', 'text': 'x' * 257, 'hz': 1}), refusedFor(PanelBudget.stringLength, max: 256));
      expect(SceneSpectrumAnnotation({'id': 'a', 'text': 'x' * 256, 'hz': 1}).text, hasLength(256));
      expect(() => SceneSpectrumSpec({'waterfallColors': List.filled(9, '#000000')}), refusedFor(PanelBudget.items, max: 8));
      expect(SceneSpectrumSpec({'waterfallColors': List.filled(8, '#000000')}).waterfallColors, hasLength(8));
      expect(
        () => SceneSpectrumSpec({
          'waterfallColors': ['#000000'],
        }),
        malformed,
      );
      final dropdown = {
        'id': 'd',
        'label': 'd',
        'kind': 'nativeDropdown',
        'value': 's',
        'options': many(65, (i) => {'label': 'o$i', 'value': 'v$i'}),
      };
      expect(() => PanelScene(scene(layers: [layer('a', '<svg/>')], strings: {'s': 'v0'}, controls: [dropdown])), refusedFor(PanelBudget.items, max: 64));
      expect(
        () => SceneSpectrumSpec({
          'annotations': many(65, (i) => {'id': 'a$i'}),
        }),
        refusedFor(PanelBudget.items, max: 64),
      );
      expect(
        () => SceneSpectrumSpec({
          'overlays': many(17, (i) => {'id': 'o$i'}),
        }),
        refusedFor(PanelBudget.items, max: 16),
      );
    });
  });

  group('a preview', () {
    final lines = <String>[];
    setUp(() {
      lines.clear();
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = previous);
    });

    PanelDefinition? definition(String preview) =>
        PanelDefinition.fromExtensionEntry({'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast', 'preview': preview});

    test('over budget is dropped with a line, and the row kept', () {
      final dropped = definition(flat(kSvgMaxElements + 1))!;
      expect(dropped.preview, isNull);
      expect(dropped.title, 'Forecast');
      expect(lines, ['[panels] "wx:forecast" preview dropped: preview has more than $kSvgMaxElements elements']);
      expect(definition('a' * (kPanelDocumentMaxChars + 1))!.preview, isNull);
      expect(definition(flat(kSvgMaxElements))!.preview, isNotNull);
    });

    test('that is not a string is told apart from one over budget', () {
      // An author who sends the wrong type is told, as one over budget is;
      // silently nulled, a `preview: {svg: …}` reads as a host that ignores
      // previews.
      final entry = <String, dynamic>{'hookKey': 'wx', 'key': 'forecast', 'title': 'Forecast', 'preview': 42};
      expect(PanelDefinition.fromExtensionEntry(entry)!.preview, isNull);
      expect(lines, ['[panels] "wx:forecast" preview ignored: not a string']);
    });

    test('is the SVG inside a data URI too; a payload that does not decode is the thumbnail\'s to refuse', () {
      String dataUri(String svg) => 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
      expect(definition(dataUri('<svg><script/></svg>'))!.preview, isNull);
      expect(lines.single, contains('preview is not self-contained vector artwork: it has a <script> element'));
      expect(definition(dataUri(flat(3)))!.preview, isNotNull);
      expect(definition('data:image/svg+xml;base64,@@@')!.preview, isNotNull);
      expect(definition('data:image/png;base64,@@@')!.preview, isNotNull);
      expect(definition('data:image/png;base64,${'A' * (kPanelDocumentMaxChars + 1)}')!.preview, isNull);
    });

    test('a raster is held to the pixels its header declares, whatever the URI calls it, and dropped with no header to read', () {
      // The trap: the character budget bounds the encoded bytes, and a flat
      // PNG compresses a thousand to one — so a few kilobytes can declare a
      // bitmap of hundreds of megabytes, decoded the moment the sheet opens.
      // The header says how large before anything decodes.
      String dataUri(String mime, Uint8List bytes) => 'data:image/$mime;base64,${base64Encode(bytes)}';
      expect(definition(dataUri('png', pngHeader(4096, 4096)))!.preview, isNotNull);
      expect(definition(dataUri('png', pngHeader(4096, 4097)))!.preview, isNull);
      expect(lines, ['[panels] "wx:forecast" preview dropped: preview image is 4096 × 4097 pixels, at most $kPreviewMaxPixels in all']);
      lines.clear();
      // Two 32-bit sides multiply past the integer's range and back under the bound.
      expect(definition(dataUri('png', pngHeader(0xFFFFFFFF, 0xFFFFFFFF)))!.preview, isNull);
      expect(definition(dataUri('png', pngHeader(1, kPreviewMaxPixels)))!.preview, isNotNull);
      lines.clear();
      expect(definition(dataUri('jpeg', jpegHeader(8192, 2048)))!.preview, isNotNull);
      expect(definition(dataUri('jpeg', jpegHeader(8192, 2049)))!.preview, isNull);
      expect(definition(dataUri('webp', webpExtendedHeader(5000, 5000)))!.preview, isNull);
      // The bytes decide the format, not the MIME type: a GIF called a PNG is the GIF it is.
      expect(definition(dataUri('png', gifHeader(5000, 5000)))!.preview, isNull);
      expect(lines.last, contains('preview image is 5000 × 5000 pixels'));
      // A GIF's screen says 1 × 1; its first frame, which the decoders grow the screen to, says otherwise.
      expect(definition(dataUri('gif', gifHeader(1, 1, frame: (left: 0, top: 0, width: 5000, height: 5000))))!.preview, isNull);
      expect(lines.last, contains('preview image is 5000 × 5000 pixels'));
      lines.clear();
      // A header this does not read, or one cut short, says nothing about the bitmap — so nothing decodes it.
      expect(definition(dataUri('png', Uint8List.sublistView(pngHeader(1, 1), 0, 8)))!.preview, isNull);
      expect(definition(dataUri('tiff', Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, ...List.filled(28, 0)])))!.preview, isNull);
      // The line names the format it did recognise: a cut-short PNG is not 'not a PNG'.
      expect(lines, [
        endsWith('preview image is a PNG whose header does not say its size, so it cannot be read'),
        endsWith('preview image is none of PNG, JPEG, GIF, WebP or BMP, so its size cannot be read'),
      ]);
    });
  });

  group('the pane', () {
    const definition = PanelDefinition(
      id: 'ext:wx:forecast',
      title: 'Forecast',
      source: PanelSource.extension,
      hookKey: 'wx',
      panelKey: 'forecast',
      triggers: ['qsoLogged'],
    );

    Widget harness(_Panels panels, {int qsoCount = 0}) => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: DockPaneVisibility(
            visible: true,
            child: ExtensionPanel(
              panel: definition,
              panels: panels,
              renderContext: PanelRenderContext(
                operation: Operation(uuid: 'op-1', data: const {'stationCall': 'N0DEV'}),
                qsoCount: qsoCount,
              ),
            ),
          ),
        ),
      ),
    );

    /// Never pumpAndSettle: an unanswered panel shows a progress indicator,
    /// which animates forever. Long enough for a render's throttle window.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }

    testWidgets('names the budget, says what was sent once per change, and reports nothing', (tester) async {
      final backend = FakeErrorReportingBackend();
      // Restored inside the test, not in a tearDown: the binding checks the
      // foundation's debug variables before the tearDowns run.
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      try {
        await withErrorHooks(() async {
          final panels = _Panels({'kind': 'svg', 'content': flat(kSvgMaxElements + 1)});
          await tester.pumpWidget(harness(panels));
          await settle(tester);
          expect(find.text('Forecast could not be displayed: its artwork has more than 16,384 elements'), findsOneWidget);
          expect(lines.where((l) => l.startsWith('[panels]')), ['[panels] "ext:wx:forecast" refused: svg content has more than $kSvgMaxElements elements']);
          // A budget is not a failure: nothing for the error policy.
          expect(backend.exceptions, isEmpty);

          // The same document again, on a trigger: the pane and the console
          // have already said so.
          await tester.pumpWidget(harness(panels, qsoCount: 1));
          await settle(tester);
          expect(panels.renders, 2);
          expect(lines.where((l) => l.startsWith('[panels]')), hasLength(1));

          // A new reason behind the same placeholder is news for the console:
          // four refusals share the `not self-contained` wording, and keyed on
          // it the console would still name the <image> an author has already
          // removed.
          panels.content = {'kind': 'svg', 'content': '<svg><image href="data:,x"/></svg>'};
          await tester.pumpWidget(harness(panels, qsoCount: 2));
          await settle(tester);
          expect(find.text('Forecast could not be displayed: its artwork is not self-contained'), findsOneWidget);
          panels.content = {'kind': 'svg', 'content': '<svg><script/></svg>'};
          await tester.pumpWidget(harness(panels, qsoCount: 3));
          await settle(tester);
          expect(find.text('Forecast could not be displayed: its artwork is not self-contained'), findsOneWidget);
          expect(lines.where((l) => l.startsWith('[panels]')).toList(), [
            '[panels] "ext:wx:forecast" refused: svg content has more than $kSvgMaxElements elements',
            '[panels] "ext:wx:forecast" refused: svg content is not self-contained vector artwork: it has a <image> element',
            '[panels] "ext:wx:forecast" refused: svg content is not self-contained vector artwork: it has a <script> element',
          ]);

          // A document within budget clears it.
          panels.content = {'kind': 'markdown', 'content': 'Sunny'};
          await tester.tap(find.text('Try again'));
          await settle(tester);
          expect(find.textContaining('could not be displayed'), findsNothing);
          expect(find.byType(HaloMarkdown), findsOneWidget);

          // And makes the same refusal news again.
          panels.content = {'kind': 'svg', 'content': '<svg><script/></svg>'};
          await tester.pumpWidget(harness(panels, qsoCount: 4));
          await settle(tester);
          expect(lines.where((l) => l.startsWith('[panels]')), hasLength(4));
        }, backend: backend);
      } finally {
        debugPrint = previous;
      }
    });

    testWidgets('names a scene\'s budget by its own number', (tester) async {
      // The trap: ten budgets share one switch; a case mapped to the wrong
      // string names a bound the author never crossed.
      final backend = FakeErrorReportingBackend();
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      try {
        await withErrorHooks(() async {
          final base = [layer('a', '<svg/>')];
          final cases = <(Map<String, dynamic>, String)>[
            (scene(layers: many(513, (i) => layer('l$i', '<svg/>'))), 'its scene has more than 512 layers'),
            (scene(layers: base, controls: many(257, (i) => button('c$i'))), 'its scene has more than 256 controls'),
            (scene(layers: base, values: {for (var i = 0; i < 257; i++) 'v$i': 0.0}), 'part of its scene has more than 256 entries'),
            (scene(layers: base, strings: {'s': 'x' * 4097}), 'a scene string is longer than 4,096 characters'),
            (scene(layers: base, layout: nestedLayout(9)), 'its layout nests more than 8 levels deep'),
          ];
          final panels = _Panels({'kind': 'scene', 'scene': cases.first.$1});
          for (final (i, (document, expected)) in cases.indexed) {
            panels.content = {'kind': 'scene', 'scene': document};
            await tester.pumpWidget(harness(panels, qsoCount: i));
            await settle(tester);
            expect(find.text('Forecast could not be displayed: $expected'), findsOneWidget);
          }
          expect(lines.where((l) => l.startsWith('[panels]')), hasLength(cases.length));
          expect(backend.exceptions, isEmpty);
        }, backend: backend);
      } finally {
        debugPrint = previous;
      }
    });

    testWidgets('an event answer over a budget goes to the console, not to a report', (tester) async {
      // The trap: the event path's catch reports every error, so an
      // extension's oversized answer to a tap — a budget, which the render
      // path keeps out of the reports — would upload as the app's failure.
      final backend = FakeErrorReportingBackend();
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      try {
        await withErrorHooks(() async {
          final document = scene(
            layers: [layer('a', '<svg/>')],
            controls: [
              {'id': 'go', 'label': 'Go', 'kind': 'nativeButton', 'event': 'go'},
            ],
            layout: {
              'column': [
                {'scene': true},
                {'control': 'go'},
              ],
            },
          );
          final panels = _Panels({'kind': 'scene', 'scene': document})
            ..eventResult = {
              'strings': {'s': 'x' * 4097},
            };
          await tester.pumpWidget(harness(panels));
          await settle(tester);
          await tester.tap(find.text('Go'));
          await settle(tester);
          expect(lines.where((l) => l.startsWith('[panels]')), ['[panels] "ext:wx:forecast" refused: scene string value is 4097 characters, at most 4096']);
          expect(find.text('That panel action failed. Try again.'), findsOneWidget);
          expect(backend.exceptions, isEmpty);
        }, backend: backend);
      } finally {
        debugPrint = previous;
      }
    });
  });
}

class _Panels extends PanelService {
  _Panels(this.content) : super(FakePanelExtensions());

  Map<String, dynamic> content;
  Map<String, dynamic>? eventResult;
  int renders = 0;

  @override
  Future<Map<String, dynamic>?> event(PanelDefinition panel, Map<String, dynamic> args) async => eventResult;

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders++;
    return content;
  }

  @override
  Future<Map<String, dynamic>> configFor(PanelDefinition panel) async => const {};
}
