// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Cells and the grid layout node: pieces drawn at their own size in logical
// pixels, placed in slots that reflow with the pane instead of scaling.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/panel_content_budgets.dart';
import 'package:ham2k_logger/views/operation/panel_environment.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_grid.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

Map<String, dynamic> cell(String id, {double width = 100, double height = 48}) => {'id': id, 'width': width, 'height': height};

Map<String, dynamic> art(String id, String cell, {double width = 100, double height = 48}) => {
  'id': id,
  'cell': cell,
  'x': 0,
  'y': 0,
  'width': width,
  'height': height,
  'svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#336699"/></svg>',
};

Map<String, dynamic> scene({
  required List<Map<String, dynamic>> cells,
  required Map<String, dynamic> layout,
  List<Map<String, dynamic>>? layers,
  List<Map<String, dynamic>> controls = const [],
  Map<String, double> values = const {},
}) => {
  'version': 1,
  'width': 100,
  'height': 100,
  'values': values,
  'cells': cells,
  'layers': layers ?? [for (final c in cells) art('${c['id']}-art', c['id'] as String, width: c['width'] as double, height: c['height'] as double)],
  'controls': controls,
  'layout': layout,
};

Map<String, dynamic> grid(
  List<Object> children, {
  Object? unit = const [48, 48],
  Object? gap = 4,
  int? columns,
  Map<String, dynamic>? style,
  Object? padding,
}) => {
  'grid': [
    for (final c in children) c is String ? {'cell': c} : c,
  ],
  'unit': ?unit,
  'gap': ?gap,
  'columns': ?columns,
  'style': ?style,
  'padding': ?padding,
};

Future<void> show(
  WidgetTester tester,
  Map<String, dynamic> doc, {
  double width = 400,
  double height = 300,
  TextDirection direction = TextDirection.ltr,
  SceneEventHandler? onEvent,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: direction,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: DockPaneVisibility(
                  visible: true,
                  child: PanelSceneView(scene: PanelScene(doc), onEvent: onEvent),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder cellBox(String id) => find.byKey(ValueKey('cell:$id'));

void main() {
  group('the model refuses', () {
    void refused(Map<String, dynamic> doc, String why) => expect(() => PanelScene(doc), throwsA(isA<FormatException>()), reason: why);

    test('cells that would be silently missing or drawn twice', () {
      refused(scene(cells: [cell('a'), cell('b')], layout: grid(['a'])), 'a cell the layout never places is never drawn');
      refused(scene(cells: [cell('a')], layout: grid(['a', 'a'])), 'one cell in two places would be two widgets sharing one state');
      refused(scene(cells: [cell('a')], layout: grid(['a', 'b'])), 'the layout names a cell nobody declared');
      final noLayout = scene(cells: [cell('a')], layout: grid(['a']))..remove('layout');
      refused(noLayout, 'only a layout places a cell');
    });

    test('pieces that name a cell they cannot be drawn in', () {
      refused(scene(cells: [cell('a')], layout: grid(['a']), layers: [art('x', 'nope')]), 'an unknown cell');
      refused(scene(cells: [cell('a')], layout: grid(['a']), layers: [art('x', 'a')..['fixed'] = true]), 'a cell neither scrolls nor stays put over a scroll');
      refused(
        scene(
          cells: [cell('a')],
          layout: grid(['a']),
          controls: [
            {'id': 'go', 'label': 'Go', 'kind': 'nativeButton', 'event': 'go', 'cell': 'a'},
          ],
        ),
        'a control in a cell is placed by its rect in the cell, or nowhere',
      );
      refused(
        scene(
          cells: [cell('a'), cell('b')],
          layout: grid(['a', 'b']),
          controls: [
            {'id': 'go', 'label': 'Go', 'kind': 'button', 'event': 'go', 'cell': 'b', 'after': 'a-art', 'x': 0, 'y': 0, 'width': 10, 'height': 10},
          ],
        ),
        'a control can only paint among the layers of the cell it is in',
      );
    });

    test('grid fields where they mean nothing', () {
      refused(scene(cells: [cell('a')], layout: grid(['a'], unit: null)), 'the outermost grid has no parent to take a unit from');
      refused(
        scene(
          cells: [cell('a')],
          layout: {
            'column': [
              {
                'cell': 'a',
                'span': [2, 1],
              },
            ],
          },
        ),
        'a span outside a grid has no slots to count',
      );
      refused(
        scene(
          cells: [cell('a')],
          layout: grid([
            {
              ...grid(['a']),
              'span': [2, 2],
            },
          ]),
        ),
        'a nested grid takes the slots its content needs; a span would contradict it',
      );
      refused(
        scene(
          cells: [cell('a')],
          layout: {
            'column': [
              {'cell': 'a'},
            ],
            'columns': 3,
          },
        ),
        'columns on a column',
      );
      refused(
        scene(
          cells: [cell('a')],
          layout: grid(['a'], style: {'background': 'chartreuse'}),
        ),
        'not a role and not a color',
      );
    });

    test('a layout that would cut a cell short or spill it over its neighbors', () {
      refused(scene(cells: [cell('wide', width: 152)], layout: grid(['wide'], columns: 2)), "a cell wider than its grid's columns");
      refused(
        scene(
          cells: [cell('a')],
          layout: grid([
            {
              'cell': 'a',
              'span': [4, 1],
            },
          ], columns: 3),
        ),
        "a span wider than the grid's columns",
      );
      refused(
        scene(
          cells: [cell('tall', height: 100)],
          layout: grid([
            {
              'cell': 'tall',
              'span': [2, 1],
            },
          ]),
        ),
        'a span shorter than its cell',
      );
      refused(
        scene(
          cells: [cell('a')],
          layout: grid([
            {'cell': 'a', 'padding': 8},
          ]),
        ),
        "padding comes out of the cell's slots",
      );
      refused(
        scene(
          cells: [cell('a')],
          layout: {
            'column': [
              {'cell': 'a', 'width': 40},
            ],
          },
        ),
        'a width narrower than the cell crops it',
      );
      refused(
        scene(
          cells: [cell('a'), cell('b')],
          layout: grid([
            'a',
            {'control': 'go', 'width': 30},
          ]),
          controls: [
            {'id': 'go', 'kind': 'nativeButton', 'label': 'Go', 'event': 'go'},
          ],
        )..['cells'] = [cell('a')],
        'a grid gives its child its slots: a width there means nothing',
      );
      refused(
        scene(
          cells: [cell('a')],
          layout: grid([
            {
              'row': [
                grid(['a'], unit: null, gap: null),
              ],
            },
          ]),
        ),
        'a grid in a row in a grid has neither the room nor the scroll of a grid child',
      );
      refused(
        scene(
          cells: [cell('wide', width: 152)],
          layout: grid([
            {
              'row': [
                {'cell': 'wide'},
              ],
            },
          ]),
        ),
        'a cell in a row in a grid would get one slot, whatever its size',
      );
      refused(
        scene(
          cells: [cell('a'), cell('b'), cell('c')],
          layout: grid([
            grid(['a', 'b', 'c'], unit: null, gap: null),
          ], columns: 1),
        ),
        "a wrapping grid wider than its parent's columns",
      );
      refused(
        scene(
          cells: [cell('huge', width: 8192)],
          layout: grid(['huge'], unit: [1, 1], gap: 0),
        ),
        'more than 256 slots across',
      );
    });

    test('grids covering more slots than layout can afford to walk at every resize', () {
      // 200 cells of 10 by 10 slots: 20,000, within every other budget.
      final ids = [for (var i = 0; i < 200; i++) 'c$i'];
      expect(
        () => PanelScene(
          scene(
            cells: [for (final id in ids) cell(id, width: 480, height: 480)],
            layers: const [],
            layout: grid(ids, unit: [48, 48], gap: 0),
          ),
        ),
        throwsA(isA<PanelContentRefusal>().having((r) => r.max, 'max', sceneGridMaxSlots)),
      );
    });

    test('a refusal names the grid field it is about', () {
      expect(
        () => PanelScene(
          scene(
            cells: [cell('a')],
            layout: grid(['a'], unit: [48]),
          ),
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('unit'))),
      );
    });

    test('a scene drawn entirely in cells needs no artwork node', () {
      expect(() => PanelScene(scene(cells: [cell('a')], layout: grid(['a']))), returnsNormally);
    });
  });

  group('cells', () {
    testWidgets('keep their size in logical pixels whatever the pane, and the grid reflows around them', (tester) async {
      final doc = scene(cells: [for (final id in 'abcdef'.split('')) cell(id)], layout: grid('abcdef'.split('')));
      // 2 slots of 48 with a 4 gap is 100 wide: 7 slots fit in 400, so three cells to a row.
      await show(tester, doc, width: 400);
      expect(tester.getSize(cellBox('a')), const Size(100, 48));
      expect(tester.getTopLeft(cellBox('d')).dy, 52, reason: 'the fourth cell starts the second row');
      // 4 slots fit in 220: two cells to a row, at the same size rather than shrunk to fit three.
      await show(tester, doc, width: 220);
      expect(tester.getSize(cellBox('a')), const Size(100, 48));
      expect(tester.getTopLeft(cellBox('c')).dy, 52, reason: 'the third cell wraps to the second row');
      expect(tester.getTopLeft(cellBox('e')).dy, 104);
    });

    testWidgets('go on screen in the order written, never back-filled', (tester) async {
      // Three wide, three wide, one wide in four columns: the second does not fit beside the first,
      // and the third goes after the second rather than into the hole left on the first row.
      final doc = scene(cells: [cell('wide1', width: 152), cell('wide2', width: 152), cell('small', width: 48)], layout: grid(['wide1', 'wide2', 'small']));
      await show(tester, doc, width: 204);
      expect(tester.getTopLeft(cellBox('wide2')), const Offset(0, 52));
      expect(tester.getTopLeft(cellBox('small')), const Offset(156, 52));
    });

    testWidgets('flow around a tall one, each to the first place it fits from the last', (tester) async {
      // Four columns: a tall cell down the first, two wide ones beside it, and a small one that
      // goes on below the second wide one, beside the tall cell's foot.
      final doc = scene(
        cells: [cell('tall', width: 48, height: 152), cell('w1', width: 152), cell('w2', width: 152), cell('s', width: 48)],
        layout: grid(['tall', 'w1', 'w2', 's']),
      );
      await show(tester, doc, width: 204);
      expect(tester.getTopLeft(cellBox('w1')), const Offset(52, 0));
      expect(tester.getTopLeft(cellBox('w2')), const Offset(52, 52));
      expect(tester.getTopLeft(cellBox('s')), const Offset(52, 104));
    });

    testWidgets('a grid with a huge unit inside one with a tiny unit lays out without walking every slot', (tester) async {
      // Measured in its parent's 1px slots, the inner grid covers millions of them; bookkeeping by
      // slot would hang here.
      final doc = scene(
        cells: [cell('a', width: 100, height: 100)],
        layout: grid(
          [
            grid(['a'], unit: [2000, 2000], gap: 0),
          ],
          unit: [1, 1],
          gap: 0,
        ),
      );
      await show(tester, doc, width: 400);
      expect(tester.getSize(cellBox('a')), const Size(100, 100));
    });

    testWidgets('start from the right in a right-to-left pane', (tester) async {
      // 220 wide holds four slots and 16 to spare: the spare goes at the end of the line, the left.
      await show(
        tester,
        scene(cells: [cell('a'), cell('b')], layout: grid(['a', 'b'])),
        width: 220,
        direction: TextDirection.rtl,
      );
      expect(tester.getTopRight(cellBox('a')).dx, 220);
      expect(tester.getTopRight(cellBox('b')).dx, 116);
    });

    testWidgets("take a click at the cell's own coordinates", (tester) async {
      final events = <Map<String, dynamic>>[];
      final doc = scene(
        cells: [cell('a'), cell('b')],
        layout: grid(['a', 'b']),
        controls: [
          {'id': 'go', 'label': 'Go', 'kind': 'button', 'event': 'go', 'cell': 'b', 'x': 50, 'y': 0, 'width': 50, 'height': 48},
        ],
      );
      await show(
        tester,
        doc,
        width: 400,
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      // Inside cell b's right half: in the artwork's coordinates that point is nowhere near x 50.
      await tester.tapAt(tester.getTopLeft(cellBox('b')) + const Offset(75, 24));
      await tester.pump();
      expect(events.single['controlId'], 'go');
      await tester.tapAt(tester.getTopLeft(cellBox('b')) + const Offset(25, 24));
      await tester.pump();
      expect(events, hasLength(1), reason: "the cell's left half has no button");
    });
  });

  testWidgets("a bar dragged by itself: a slider over its art takes the value under the pointer, in the cell's own units", (tester) async {
    // The slider spans the bar at 1:1; in the artwork's scaled coordinates the same drag would land
    // at a different value, and the bar's fill would part from the pointer.
    final doc = scene(
      cells: [cell('spacer', width: 152), cell('bar', width: 100)],
      layout: grid(['spacer', 'bar']),
      values: {'drive': 0},
      layers: [
        art('spacer-art', 'spacer', width: 152),
        art('bar-art', 'bar'),
        {
          'id': 'readout',
          'cell': 'bar',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 20,
          'text': {'value': 'drive'},
        },
      ],
      controls: [
        {
          'id': 'drive',
          'kind': 'slider',
          'label': 'Drive',
          'cell': 'bar',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 48,
          'value': 'drive',
          'min': 0,
          'max': 100,
          'step': 1,
        },
      ],
    );
    await show(tester, doc, width: 400);
    final bar = tester.getTopLeft(cellBox('bar'));
    await tester.dragFrom(bar + const Offset(10, 24), const Offset(65, 0));
    await tester.pumpAndSettle();
    expect(find.text('75'), findsOneWidget);
  });

  group('nested grids', () {
    testWidgets('a wrapping grid takes a whole row of its parent and wraps within it', (tester) async {
      final doc = scene(
        cells: [cell('a', width: 48), cell('b'), cell('c'), cell('d')],
        layout: grid([
          'a',
          grid(['b', 'c', 'd']),
        ]),
      );
      await show(tester, doc, width: 204);
      expect(tester.getTopLeft(cellBox('b')), const Offset(0, 52), reason: 'beside a, there is room, but the group starts its own row');
      expect(tester.getTopLeft(cellBox('d')), const Offset(0, 104), reason: 'two to a row in four slots');
    });

    testWidgets('one with columns scrolls sideways on its own, and the board around it stays in the pane', (tester) async {
      final doc = scene(
        cells: [for (final id in 'abcde'.split('')) cell(id), cell('after', width: 48)],
        layout: grid([grid('abcde'.split(''), columns: 10), 'after']),
      );
      await show(tester, doc, width: 220);
      expect(tester.getTopLeft(cellBox('e')).dx, greaterThan(220), reason: 'the row runs past the pane');
      expect(tester.getTopLeft(cellBox('after')).dx, lessThan(220), reason: 'what follows is on the board, not pushed off it');
      await tester.dragFrom(tester.getTopLeft(cellBox('b')) + const Offset(10, 24), const Offset(-300, 0));
      await tester.pump();
      expect(tester.getTopLeft(cellBox('e')).dx, lessThan(220), reason: 'the row scrolls');
      expect(tester.getTopLeft(cellBox('after')).dx, 0, reason: 'the rest of the board does not');
    });

    testWidgets('inherit unit and gap unless they name their own', (tester) async {
      final doc = scene(
        cells: [cell('a', width: 24, height: 24), cell('b', width: 24, height: 24)],
        layout: grid(
          [
            grid(['a', 'b'], unit: null, gap: null, columns: 2),
          ],
          unit: [24, 24],
          gap: 10,
        ),
      );
      await show(tester, doc, width: 400);
      expect(tester.getTopLeft(cellBox('b')).dx - tester.getTopLeft(cellBox('a')).dx, 34);
    });
  });

  group('scrolling', () {
    Map<String, dynamic> row({List<Map<String, dynamic>> controls = const [], Map<String, double> values = const {}}) =>
        scene(cells: [for (final id in 'abcde'.split('')) cell(id)], layout: grid([grid('abcde'.split(''), columns: 10)]), controls: controls, values: values);

    testWidgets('a mouse drag scrolls a grid, as a finger does', (tester) async {
      await show(tester, row(), width: 220);
      final before = tester.getTopLeft(cellBox('e')).dx;
      await tester.dragFrom(tester.getTopLeft(cellBox('b')) + const Offset(10, 24), const Offset(-150, 0), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(cellBox('e')).dx, lessThan(before));
    });

    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      testWidgets('a drag begun on a slider in a cell is the slider\'s, not the grid\'s (${kind.name})', (tester) async {
        // A plain pan waits for twice a scroll's distance before it claims a drag, so without the
        // cell's own recognizer the row would scroll out from under the operator's hand.
        final doc = row(
          values: {'drive': 0},
          controls: [
            {
              'id': 'drive',
              'kind': 'slider',
              'label': 'Drive',
              'cell': 'b',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 48,
              'value': 'drive',
              'min': 0,
              'max': 100,
              'step': 1,
            },
          ],
        );
        (doc['layers'] as List).add({
          'id': 'readout',
          'cell': 'a',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 20,
          'text': {'value': 'drive'},
        });
        await show(tester, doc, width: 220);
        final b = tester.getTopLeft(cellBox('b'));
        // In small steps, as a hand moves: one long jump would pass every slop at once.
        final drag = await tester.startGesture(b + const Offset(90, 24), kind: kind);
        for (var i = 0; i < 40; i++) {
          await drag.moveBy(const Offset(-1.5, 0));
          await tester.pump();
        }
        await drag.up();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(cellBox('b')), b, reason: 'the row stayed put');
        expect(find.text('30'), findsOneWidget, reason: 'the slider followed the pointer back to 30');
      });
    }

    Map<String, dynamic> tallBoard({required Map<String, dynamic> control}) {
      final ids = [for (var i = 0; i < 12; i++) 'c$i'];
      return scene(cells: [for (final id in ids) cell(id)], layout: grid(ids), controls: [control], values: {'drive': 50});
    }

    testWidgets("a swipe down the board that starts on a slider scrolls the board and leaves the slider alone", (tester) async {
      final doc = tallBoard(
        control: {
          'id': 'drive',
          'kind': 'slider',
          'label': 'Drive',
          'cell': 'c0',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 48,
          'value': 'drive',
          'min': 0,
          'max': 100,
          'step': 1,
          'event': 'set',
        },
      );
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        doc,
        width: 204,
        height: 120,
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      final before = tester.getTopLeft(cellBox('c0')).dy;
      final drag = await tester.startGesture(tester.getTopLeft(cellBox('c0')) + const Offset(80, 30));
      for (var i = 0; i < 40; i++) {
        await drag.moveBy(const Offset(0.3, -2));
        await tester.pump();
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(cellBox('c0')).dy, lessThan(before), reason: 'the board scrolled');
      expect(events, isEmpty, reason: 'and the slider was never set to where the finger landed');
    });

    testWidgets('a disabled slider in a cell leaves its drag to the grid', (tester) async {
      final doc = row(
        values: {'drive': 50},
        controls: [
          {
            'id': 'drive',
            'kind': 'slider',
            'label': 'Drive',
            'cell': 'b',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 48,
            'value': 'drive',
            'min': 0,
            'max': 100,
            'step': 1,
            'disabled': true,
          },
        ],
      );
      await show(tester, doc, width: 220);
      final before = tester.getTopLeft(cellBox('e')).dx;
      await tester.dragFrom(tester.getTopLeft(cellBox('b')) + const Offset(90, 24), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(cellBox('e')).dx, lessThan(before));
    });

    testWidgets("a knob in a cell keeps its drag at the device's own slop, smaller than the default", (tester) async {
      // With the default 18px slop on the knob's recognizer and the device's 8px on the scroll's,
      // the board would take every vertical drag before the knob had moved enough to claim it.
      final doc = tallBoard(
        control: {
          'id': 'drive',
          'kind': 'knob',
          'label': 'Drive',
          'cell': 'c0',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 48,
          'value': 'drive',
          'min': 0,
          'max': 100,
          'step': 1,
        },
      );
      (doc['layers'] as List).add({
        'id': 'readout',
        'cell': 'c1',
        'x': 0,
        'y': 0,
        'width': 100,
        'height': 20,
        'text': {'value': 'drive'},
      });
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 204,
                  height: 120,
                  child: Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(gestureSettings: const DeviceGestureSettings(touchSlop: 8)),
                      child: DockPaneVisibility(visible: true, child: PanelSceneView(scene: PanelScene(doc))),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final before = tester.getTopLeft(cellBox('c0'));
      final drag = await tester.startGesture(before + const Offset(50, 24));
      for (var i = 0; i < 20; i++) {
        await drag.moveBy(const Offset(0, -1));
        await tester.pump();
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(cellBox('c0')), before, reason: 'the board stayed put');
      expect(find.text('50'), findsNothing, reason: 'the knob turned');
    });

    testWidgets('right to left, the fades are on the edges the content is hidden past', (tester) async {
      await show(tester, row(), width: 220, direction: TextDirection.rtl);
      await tester.pumpAndSettle();
      // The row starts at the right: what is hidden is past the left edge.
      expect(tester.state<SceneGridScrollState>(find.byType(SceneGridScroll).last).fades, (start: 1.0, end: 0.0));
    });

    testWidgets('a grid with nothing hidden draws no mask, which would be a layer redrawn every frame', (tester) async {
      await show(tester, scene(cells: [cell('a')], layout: grid(['a'])));
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);
    });

    for (final inverted in [false, true]) {
      testWidgets('a scroll over a bar ${inverted ? 'with' : 'without'} invertScroll moves it ${inverted ? 'up' : 'down'}', (tester) async {
        final doc = row(
          values: {'drive': 50},
          controls: [
            {
              'id': 'drive',
              'kind': 'slider',
              'label': 'Drive',
              'cell': 'a',
              'x': 0,
              'y': 0,
              'width': 100,
              'height': 48,
              'value': 'drive',
              'min': 0,
              'max': 100,
              'step': 1,
              'invertScroll': ?(inverted ? true : null),
            },
          ],
        );
        (doc['layers'] as List).add({
          'id': 'readout',
          'cell': 'b',
          'x': 0,
          'y': 0,
          'width': 100,
          'height': 20,
          'text': {'value': 'drive'},
        });
        await show(tester, doc, width: 220);
        final at = tester.getTopLeft(cellBox('a')) + const Offset(50, 24);
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(mouse.hover(at));
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
        await tester.pump();
        expect(find.text(inverted ? '51' : '49'), findsOneWidget);
      });
    }

    testWidgets('a board control worked mid-QSO leaves the focus in the logging fields', (tester) async {
      final call = FocusNode(debugLabel: 'call');
      addTearDown(call.dispose);
      final doc = row(
        values: {'drive': 0},
        controls: [
          {
            'id': 'drive',
            'kind': 'slider',
            'label': 'Drive',
            'cell': 'a',
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 48,
            'value': 'drive',
            'min': 0,
            'max': 100,
            'step': 1,
          },
        ],
      );
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextField(focusNode: call),
                  SizedBox(
                    width: 220,
                    height: 200,
                    child: DockPaneVisibility(visible: true, child: PanelSceneView(scene: PanelScene(doc))),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      call.requestFocus();
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(cellBox('a')) + const Offset(50, 24));
      await tester.pump();
      expect(call.hasFocus, isTrue, reason: 'a click on a board slider takes no focus');
      await tester.dragFrom(tester.getTopLeft(cellBox('a')) + const Offset(20, 24), const Offset(40, 0));
      await tester.pump();
      expect(call.hasFocus, isTrue, reason: 'nor does a drag');
    });

    testWidgets('an edge fades while content is hidden past it, and the fade thins away as that content runs out', (tester) async {
      await show(tester, row(), width: 220);
      await tester.pumpAndSettle();
      final scroller = find.byType(SceneGridScroll).last;
      ({double start, double end}) fades() => tester.state<SceneGridScrollState>(scroller).fades;
      expect(fades(), (start: 0.0, end: 1.0), reason: 'at the start: the far edge fades, the near one shows whole');
      // 516 wide in 204: 312 hidden. Scrolled to 12 short of the end, the far fade is half gone.
      await tester.dragFrom(tester.getTopLeft(cellBox('a')) + const Offset(10, 24), const Offset(-300, 0), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final position = Scrollable.of(tester.element(cellBox('a'))).position;
      position.jumpTo(position.maxScrollExtent - SceneGridScroll.fade / 2);
      await tester.pumpAndSettle();
      expect(fades().start, 1.0);
      expect(fades().end, closeTo(0.5, 0.02));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(fades(), (start: 1.0, end: 0.0), reason: 'at the end: nothing past it, so no fade');
    });
  });

  group('the outermost grid', () {
    testWidgets('scrolls the pane down when its rows run past the bottom', (tester) async {
      final ids = [for (var i = 0; i < 20; i++) 'c$i'];
      await show(tester, scene(cells: [for (final id in ids) cell(id)], layout: grid(ids)), width: 204, height: 120);
      final before = tester.getTopLeft(cellBox('c0')).dy;
      await tester.drag(cellBox('c2'), const Offset(0, -100));
      await tester.pump();
      expect(tester.getTopLeft(cellBox('c0')).dy, lessThan(before));
    });

    testWidgets('scrolls the pane across when its widest piece is wider than the pane', (tester) async {
      await show(tester, scene(cells: [cell('wide', width: 412)], layout: grid(['wide'])), width: 200);
      expect(tester.getSize(cellBox('wide')).width, 412, reason: 'cut to the pane, it would be scaled or clipped instead of whole');
      await tester.dragFrom(const Offset(100, 24), const Offset(-150, 0));
      await tester.pump();
      expect(tester.getTopLeft(cellBox('wide')).dx, lessThan(0));
    });
  });

  testWidgets("a grid's box is the app's: a theme role behind it and its title in the label type", (tester) async {
    final doc = scene(
      cells: [cell('a')],
      layout: grid(['a'], padding: 8, style: {'background': 'surfaceContainer', 'title': 'Main radio', 'radius': 8}),
    );
    await show(tester, doc);
    expect(find.text('Main radio'), findsOneWidget);
    final context = tester.element(find.text('Main radio'));
    final decorated = find.ancestor(of: find.text('Main radio'), matching: find.byType(DecoratedBox)).first;
    expect((tester.widget<DecoratedBox>(decorated).decoration as BoxDecoration).color, panelColorRole(context, 'surfaceContainer'));
    expect(tester.getSize(decorated), const Size(400, 300), reason: "the outermost grid's box fills the pane, not just its rows");
    expect(tester.getTopLeft(cellBox('a')).dy, greaterThan(tester.getBottomLeft(find.text('Main radio')).dy), reason: 'the title sits above the slots');
  });
}
