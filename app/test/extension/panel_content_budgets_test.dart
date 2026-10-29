// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The budgets a panel's content is held to (panel_content_budgets.dart). A
// document over one is refused whole: the pane names the budget, the console
// says what was sent, and nothing is reported — the budget is the
// extension's to keep, not a failure of the app's.

import 'dart:convert';

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

/// An SVG of exactly [elements] elements, the root included.
String flat(int elements, {String inside = ''}) => '<svg xmlns="http://www.w3.org/2000/svg">$inside${'<rect/>' * (elements - 1)}</svg>';

/// An SVG nested exactly [depth] deep, the root counted, with [leaf] at the bottom.
String nested(int depth, {String leaf = ''}) => '<svg>${'<g>' * (depth - 1)}$leaf${'</g>' * (depth - 1)}</svg>';

Map<String, dynamic> scene({required List<Map<String, dynamic>> layers}) => {
  'version': 1,
  'width': 400,
  'height': 100,
  'values': <String, double>{},
  'strings': <String, String>{},
  'layers': layers,
  'controls': <Map<String, dynamic>>[],
};

Map<String, dynamic> layer(String id, String svg) => {'id': id, 'x': 0, 'y': 0, 'width': 400, 'height': 100, 'svg': svg};

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
      // A raster says nothing about elements; only its size is held.
      expect(definition('data:image/png;base64,iVBORw0KGgo=')!.preview, isNotNull);
      expect(definition('data:image/png;base64,${'A' * (kPanelDocumentMaxChars + 1)}')!.preview, isNull);
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
  });
}

class _Panels extends PanelService {
  _Panels(this.content) : super(FakePanelExtensions());

  Map<String, dynamic> content;
  int renders = 0;

  @override
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) async {
    renders++;
    return content;
  }

  @override
  Future<Map<String, dynamic>> configFor(PanelDefinition panel) async => const {};
}
