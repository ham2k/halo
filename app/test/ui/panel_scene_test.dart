// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

Map<String, dynamic> document({double value = 0, bool local = false, bool pulse = false}) => {
  'version': 1,
  'width': 400,
  'height': 200,
  'values': {'v': value},
  'layers': [
    {
      'id': 'readout',
      'x': 0,
      'y': 0,
      'width': 200,
      'height': 50,
      'text': {'value': 'v', 'prefix': 'Value: '},
    },
    {
      'id': 'art',
      'x': 0,
      'y': 60,
      'width': 40,
      'height': 40,
      'svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><circle cx="20" cy="20" r="20" fill="#00ff00"/></svg>',
      if (pulse) 'pulse': {'periodMs': 1000, 'minOpacity': 0.3},
    },
  ],
  'controls': [
    {
      'id': 'slider',
      'label': 'Test slider',
      'kind': 'slider',
      'x': 0,
      'y': 100,
      'width': 400,
      'height': 50,
      'value': 'v',
      'min': 0,
      'max': 100,
      'step': 1,
      if (!local) 'event': 'set',
    },
  ],
};

Future<void> show(
  WidgetTester tester,
  Map<String, dynamic> doc, {
  SceneEventHandler? onEvent,
  double width = 400,
  bool visible = true,
  bool reduced = false,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: width / 2,
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: DockPaneVisibility(
                  visible: visible,
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

void main() {
  Future<FocusNode> showBesideCallsign(WidgetTester tester) async {
    final call = FocusNode(debugLabel: 'call');
    addTearDown(call.dispose);
    final doc = document();
    (doc['controls'] as List).add({'id': 'go', 'label': 'Go', 'kind': 'button', 'x': 300, 'y': 0, 'width': 100, 'height': 50, 'event': 'go'});
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: call),
                SizedBox(
                  width: 400,
                  height: 200,
                  child: DockPaneVisibility(
                    visible: true,
                    child: PanelSceneView(scene: PanelScene(doc), onEvent: (_) async => {'values': <String, num>{}}),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    call.requestFocus();
    await tester.pump();
    return call;
  }

  testWidgets('clicking a drawn button leaves focus where the operator had it', (tester) async {
    // A focus taken by the click would move the operator's next keystrokes
    // out of the callsign and into a panel control that does nothing with them.
    final call = await showBesideCallsign(tester);
    await tester.tap(find.bySemanticsLabel('Go'));
    await tester.pump();
    expect(call.hasFocus, isTrue);
  });

  testWidgets('a clicked slider keeps focus while it is being adjusted, then hands it back', (tester) async {
    // Kept for good, the operator's next callsign would be typed into a slider.
    // Dropped at once, the arrow keys could not fine-tune what was just clicked.
    final call = await showBesideCallsign(tester);
    await tester.tapAt(tester.getRect(find.bySemanticsLabel('Test slider')).center);
    await tester.pump();
    expect(call.hasFocus, isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    // The hold runs from the last adjustment, not the click.
    await tester.pump(const Duration(seconds: 2));
    expect(call.hasFocus, isFalse);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(call.hasFocus, isTrue);

    // A drag holds from its release: a long one must not lose focus mid-drag.
    final slider = tester.getRect(find.bySemanticsLabel('Test slider')).center;
    final gesture = await tester.startGesture(slider);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(seconds: 4));
    expect(call.hasFocus, isFalse);
    await gesture.up();
    await tester.pump(const Duration(seconds: 3));
    expect(call.hasFocus, isTrue);
  });

  testWidgets('a knob with a second axis takes sideways and up-and-down motion as two values', (tester) async {
    // One patch of artwork, two settings: a passband's shift across, its
    // width up and down. Merged into one value, either would drag the other.
    final doc = document();
    (doc['values'] as Map)['w'] = 100.0;
    doc['controls'] = [
      {
        'id': 'pb',
        'label': 'Filter',
        'kind': 'knob',
        'x': 0,
        'y': 100,
        'width': 400,
        'height': 50,
        'value': 'v',
        'min': 0,
        'max': 1000,
        'step': 10,
        'event': 'shift',
        'valueY': 'w',
        'eventY': 'width',
        'minY': 0,
        'maxY': 1000,
        'stepY': 50,
      },
    ];
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      doc,
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    final centre = tester.getCenter(find.bySemanticsLabel('Filter'));
    Future<void> scroll(Offset delta) async {
      await tester.sendEventToBinding(PointerScrollEvent(position: centre, scrollDelta: delta));
      await tester.pumpAndSettle();
    }

    await scroll(const Offset(0, -20));
    await scroll(const Offset(20, 0));
    expect(events.map((e) => (e['action'], e['value'])), [('width', 150.0), ('shift', 10.0)]);

    // A drag: across is the first value, up the second, each sent once at the end.
    events.clear();
    await tester.dragFrom(centre, const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(events.map((e) => e['action']), ['width']);

    // The axis that drag never moved was never committed: held as being edited, it would ignore
    // every document after — a shift the radio moved would never show.
    final next = document(value: 500);
    (next['values'] as Map)['w'] = 100.0;
    next['controls'] = doc['controls'];
    await show(tester, next, onEvent: (_) async => {});
    expect(find.text('Value: 500'), findsOneWidget);
  });

  testWidgets('a knob with a menu opens it on a click and still turns on a scroll', (tester) async {
    // Presets and fine adjustment on the same artwork: a click is a choice,
    // a scroll a nudge, and neither may swallow the other.
    final doc = document();
    doc['controls'] = [
      {
        'id': 'pb',
        'label': 'Filter',
        'kind': 'knob',
        'x': 0,
        'y': 100,
        'width': 400,
        'height': 50,
        'value': 'v',
        'min': 0,
        'max': 100,
        'step': 1,
        'event': 'turn',
        'menu': [
          {'label': '2.4K', 'event': 'width-2400'},
          {'label': '2.7K', 'event': 'width-2700'},
        ],
      },
    ];
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      doc,
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    final centre = tester.getCenter(find.bySemanticsLabel('Filter'));
    await tester.tapAt(centre);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2.7K'));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(PointerScrollEvent(position: centre, scrollDelta: const Offset(0, -20)));
    await tester.pumpAndSettle();
    expect(events.map((e) => (e['action'], e['phase'])), [('width-2700', 'activate'), ('turn', 'commit')]);
  });

  testWidgets('a text glow draws a halo of its colour around the letters', (tester) async {
    // Light text over a bar that may be any colour stays legible only with an edge of its own.
    final doc = document();
    ((doc['layers'] as List).first as Map)['text'] = {'literal': 'SWR 1.3', 'color': '#ffffff', 'glow': '#000000'};
    await show(tester, doc);
    final shadows = tester.widget<Text>(find.text('SWR 1.3')).style!.shadows!;
    expect(shadows.map((s) => s.color), everyElement(const Color(0xff000000)));
    expect(
      () => PanelScene(
        document()
          ..['layers'] = [
            {
              'id': 'x',
              'x': 0,
              'y': 0,
              'width': 10,
              'height': 10,
              'text': {'literal': 'a', 'glow': 'black'},
            },
          ],
      ),
      throwsFormatException,
    );
  });

  test('valueY is a knob\'s, must name a value, and sends an event of its own', () {
    Map<String, dynamic> withControl(Map<String, dynamic> control) => document()..['controls'] = [control];
    final base = {'id': 'k', 'label': 'K', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'value': 'v', 'event': 'e', 'eventY': 'f'};
    expect(PanelScene(withControl({...base, 'kind': 'knob', 'valueY': 'v'})).controls.single.yAxis?.event, 'f');
    expect(() => PanelScene(withControl({...base, 'kind': 'slider', 'valueY': 'v'})), throwsFormatException);
    expect(() => PanelScene(withControl({...base, 'kind': 'knob', 'valueY': 'missing'})), throwsFormatException);
    // Both axes under one action: a width of 150 and a shift of 150 would arrive as the same event.
    expect(() => PanelScene(withControl({...base, 'kind': 'knob', 'valueY': 'v', 'eventY': null})), throwsFormatException);
    expect(() => PanelScene(withControl({...base, 'kind': 'knob', 'valueY': 'v', 'eventY': 'e'})), throwsFormatException);
  });

  testWidgets('menu buttons send only the chosen action and can be dismissed', (tester) async {
    final doc = document();
    doc['controls'] = [
      {
        'id': 'mode',
        'label': 'Mode',
        'kind': 'button',
        'x': 0,
        'y': 100,
        'width': 100,
        'height': 40,
        'menu': [
          {'label': 'USB', 'event': 'mode-USB'},
          {'label': 'CW', 'event': 'mode-CW'},
        ],
      },
    ];
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      doc,
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
    await tester.tap(find.text('CW'));
    await tester.pumpAndSettle();
    expect(events.single['controlId'], 'mode');
    expect(events.single['action'], 'mode-CW');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(events, hasLength(1));
  });

  test('numeric bindings select LCD digits locally through carries', () {
    final hundreds = SceneBinding({
      'value': 'frequency',
      'scale': 10,
      'truncate': true,
      'modulo': 10,
      'input': [0, 9],
      'output': [0, 9],
    });
    expect(hundreds.evaluate({'frequency': 14109.7}), 7);
    expect(hundreds.evaluate({'frequency': 14110.0}), 0);
    final thousands = SceneBinding({
      'value': 'frequency',
      'truncate': true,
      'modulo': 10,
      'input': [0, 9],
      'output': [0, 9],
    });
    expect(thousands.evaluate({'frequency': 14109.7}), 9);
    expect(thousands.evaluate({'frequency': 14110.0}), 0);
  });
  test('sampled bindings follow non-linear data and clamp at either edge', () {
    final binding = SceneBinding({
      'value': 'hour',
      'input': [0, 2],
      'output': [10, 20],
      'samples': [10, 40, 20],
    });
    expect(binding.evaluate({'hour': -1}), 10);
    expect(binding.evaluate({'hour': 1}), 40);
    expect(binding.evaluate({'hour': 1.5}), 30);
    expect(binding.evaluate({'hour': 3}), 20);
    for (final samples in [
      [],
      [double.nan],
      ['bad'],
    ]) {
      expect(
        () => SceneBinding({
          'value': 'hour',
          'input': [0, 2],
          'output': [0, 1],
          'samples': samples,
        }),
        throwsFormatException,
      );
    }
  });
  test('malformed scenes fail at the document boundary', () {
    for (final bad in [
      {...document(), 'width': double.nan},
      {...document(), 'version': 9},
      {
        ...document(),
        'values': {'v': double.infinity},
      },
      {
        ...document(),
        'controls': [
          {'id': 'bad'},
        ],
      },
      {
        ...document(),
        'layers': [
          {'id': 'bad', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'svg': '<svg><image href="https://example.com/pixel"/></svg>'},
        ],
      },
    ]) {
      // Thrown, not null: the caller's render catch is what reports it, and a
      // null here reaches the author as "could not be displayed" with the
      // reason discarded.
      expect(() => PanelContent.fromJson({'kind': 'scene', 'scene': bad}), throwsFormatException);
    }
    expect(() => PanelContent.fromJson({'kind': 'scene'}), throwsFormatException);
    expect(PanelContent.fromJson({'kind': 'scene', 'scene': document()})?.scene, isNotNull);
  });

  // Published packages built against SDK 0.9 or earlier send the old name. Read as
  // anything but `scene`, their panes fall to "Unsupported panel content", and
  // every `kind == 'scene'` check in ExtensionPanel skips them.
  test('svgScene is read as the scene kind', () {
    final content = PanelContent.fromJson({'kind': 'svgScene', 'scene': document()})!;
    expect(content.kind, 'scene');
    expect(content.scene, isNotNull);
  });

  // A `tick:1` scene panel answers with the same document almost every second.
  test('an unchanged scene document keeps its validated scene; a changed one is validated again', () {
    final first = PanelContent.fromJson({'kind': 'scene', 'scene': document()})!;
    final repeat = PanelContent.fromJson({'kind': 'scene', 'scene': document()}, previous: first)!;
    expect(repeat.scene, same(first.scene));
    final changed = PanelContent.fromJson({'kind': 'scene', 'scene': document(value: 5)}, previous: first)!;
    expect(changed.scene, isNot(same(first.scene)));
    expect(changed.scene!.values['v'], 5);
    expect(
      () => PanelContent.fromJson({
        'kind': 'scene',
        'scene': {...document(), 'version': 9},
      }, previous: first),
      throwsFormatException,
    );
  });

  test('hover cannot dispatch events and labels/samples are bounded', () {
    for (final fields in [
      {'hover': true, 'event': 'set'},
      {'valueLabels': <String>[]},
      {
        'valueLabels': [false],
      },
    ]) {
      final doc = document(local: true);
      (doc['controls'] as List).first.addAll(fields);
      expect(() => PanelScene(doc), throwsA(isA<FormatException>()));
    }
    final doc = document();
    (doc['layers'] as List).first['text'] = {
      'value': 'v',
      'samples': ['missing', 0, double.nan],
    };
    expect(() => PanelScene(doc), throwsFormatException);
  });

  testWidgets('scaled dragging updates locally and sends exactly one final event', (tester) async {
    final events = <Map<String, dynamic>>[];
    final reply = Completer<Map<String, double>>();
    await show(
      tester,
      document(),
      width: 800,
      onEvent: (event) {
        events.add(event);
        return reply.future;
      },
    );
    final slider = find.bySemanticsLabel('Test slider');
    final box = tester.getRect(slider);
    final drag = await tester.startGesture(Offset(box.left + 10, box.center.dy));
    await drag.moveTo(Offset(box.left + box.width * .75, box.center.dy));
    await tester.pump();
    expect(find.text('Value: 75'), findsOneWidget);
    expect(events, isEmpty);
    await drag.up();
    await tester.pump();
    expect(events.single['value'], 75);
    expect(events.single['phase'], 'commit');
    reply.complete({'v': 74});
    await tester.pump();
    await tester.pump();
    expect(find.text('Value: 74'), findsOneWidget);
  });

  // The pane's handler may spend 5 s reading config and 5 s more in the hook.
  // A shorter timer in the view cannot stop that action — it can only show it
  // failing and snap the control back while the radio is still about to move.
  testWidgets('a slow action is waited for, not reported as failed while it is still running', (tester) async {
    final reply = Completer<Map<String, double>>();
    await show(tester, document(value: 10), onEvent: (_) => reply.future);
    await tester.tapAt(tester.getRect(find.bySemanticsLabel('Test slider')).center);
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    expect(find.text(t.operation.layout.panelActionFailed), findsNothing);
    expect(find.text('Value: 50'), findsOneWidget);
    reply.complete({'v': 49});
    await tester.pump();
    await tester.pump();
    expect(find.text('Value: 49'), findsOneWidget);
    expect(find.text(t.operation.layout.panelActionFailed), findsNothing);
  });

  // A knob accumulates its own drag value. Left unclamped, the overshoot past
  // an end stop is a dead zone: the way back moves nothing until it is repaid.
  testWidgets('a knob dragged past its end stop responds at once on the way back', (tester) async {
    final scene = document(value: 90, local: true);
    final control = (scene['controls'] as List).first as Map<String, dynamic>;
    control['kind'] = 'knob';
    control['sensitivity'] = 1;
    await show(tester, scene, width: 400);
    final box = tester.getRect(find.bySemanticsLabel('Test slider'));
    final drag = await tester.startGesture(box.center);
    // Past the touch slop first, so the pan is accepted before the distances
    // that matter are measured.
    await drag.moveBy(const Offset(30, 0));
    await drag.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(find.text('Value: 100'), findsOneWidget);
    await drag.moveBy(const Offset(-10, 0));
    await tester.pump();
    expect(find.text('Value: 90'), findsOneWidget);
    await drag.up();
  });

  testWidgets('continuous tuning sends before release, coalesces moves and preserves the final value', (tester) async {
    final scene = document();
    (scene['controls'] as List).first['continuous'] = true;
    (scene['layers'] as List).first['text'] = {'value': 'v', 'scale': .001, 'decimals': 3, 'suffix': ' MHz'};
    final events = <Map<String, dynamic>>[];
    final firstReply = Completer<Map<String, double>>();
    await show(
      tester,
      scene,
      onEvent: (event) {
        events.add(event);
        return events.length == 1 ? firstReply.future : Future.value({'v': event['value'] as double});
      },
    );
    final box = tester.getRect(find.bySemanticsLabel('Test slider'));
    final drag = await tester.startGesture(Offset(box.left + 10, box.center.dy));
    await drag.moveTo(Offset(box.left + box.width * .4, box.center.dy));
    await tester.pump();
    expect(events, hasLength(1));
    expect(events.first['phase'], 'change');
    await drag.moveTo(Offset(box.left + box.width * .6, box.center.dy));
    await drag.moveTo(Offset(box.left + box.width * .8, box.center.dy));
    await tester.pump();
    expect(find.text('0.080 MHz'), findsOneWidget);
    expect(events, hasLength(1));
    await drag.up();
    firstReply.complete({'v': 1});
    await tester.pump();
    await tester.pump();
    expect(events, hasLength(2));
    expect(events.last['phase'], 'commit');
    expect(events.last['value'], 80);
    expect(find.text('0.080 MHz'), findsOneWidget);
  });

  test('hoverSet belongs to a drawn control and names a scene number', () {
    for (final control in [
      // A native control is the app's widget, with hover states of its own.
      {
        'id': 'n',
        'label': 'N',
        'kind': 'nativeButton',
        'x': 0,
        'y': 0,
        'width': 10,
        'height': 10,
        'event': 'go',
        'hoverSet': {'value': 'v', 'to': 1},
      },
      {
        'id': 'b',
        'label': 'B',
        'kind': 'button',
        'x': 0,
        'y': 0,
        'width': 10,
        'height': 10,
        'hoverSet': {'value': 'missing', 'to': 1},
      },
      {'id': 'b', 'label': 'B', 'kind': 'button', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'hoverSet': 'v'},
    ]) {
      final doc = document(local: true);
      (doc['controls'] as List).add(control);
      expect(() => PanelScene(doc), throwsFormatException, reason: '$control');
    }
  });

  group('scrolling a knob', () {
    // A knob over the whole artwork that moves what it shows, with a button — a label — over part of it.
    Map<String, dynamic> scroller({bool invertDrag = false, bool scrollThrough = true}) => document()
      ..['controls'] = [
        {
          'id': 'pan',
          'label': 'Pan',
          'kind': 'knob',
          'x': 0,
          'y': 0,
          'width': 400,
          'height': 200,
          'value': 'v',
          'min': 0,
          'max': 100,
          'step': 5,
          'sensitivity': 1,
          'event': 'pan',
          'invertDrag': ?(invertDrag ? true : null),
          'scrollThrough': ?(scrollThrough ? true : null),
        },
        {'id': 'label', 'label': 'Label', 'kind': 'button', 'x': 300, 'y': 0, 'width': 100, 'height': 50, 'event': 'tune'},
      ];

    Future<List<(String?, Object?)>> scrolled(WidgetTester tester, Offset at, Offset delta, {Map<String, dynamic>? doc}) async {
      final events = <(String?, Object?)>[];
      await show(
        tester,
        doc ?? scroller()
          ..['values'] = {'v': 50},
        onEvent: (e) async {
          events.add((e['action'] as String?, e['value']));
          return {};
        },
      );
      final origin = tester.getTopLeft(find.byType(PanelSceneView));
      await tester.sendEventToBinding(PointerScrollEvent(position: origin + at, scrollDelta: delta));
      await tester.pumpAndSettle();
      return events;
    }

    // Labels cover much of a band map: a scroll stopped by each one would leave little to scroll on.
    testWidgets('a scroll on a button over it still reaches it, once', (tester) async {
      expect(await scrolled(tester, const Offset(350, 25), const Offset(0, -20)), [('pan', 55.0)]);
    });

    // A scene from before scrollThrough with a button over its tuning knob would start retuning the
    // radio on a scroll it never asked to pass on.
    testWidgets('a knob that did not ask for them leaves the scrolls on a button over it alone', (tester) async {
      expect(await scrolled(tester, const Offset(350, 25), const Offset(0, -20), doc: scroller(scrollThrough: false)), isEmpty);
    });

    // Measured by rect alone, a scroll would go through a native field, or a cover laid over the
    // knob to stop it, to reach the knob all the same.
    testWidgets('a native control or a blocking layer between the button and the knob keeps the scroll', (tester) async {
      final native = scroller();
      (native['controls'] as List).insert(1, {'id': 'n', 'label': 'N', 'kind': 'nativeButton', 'x': 300, 'y': 0, 'width': 100, 'height': 50, 'event': 'go'});
      final covered = scroller();
      (covered['controls'] as List).first['after'] = 'readout';
      (covered['layers'] as List).add({
        'id': 'cover',
        'x': 300,
        'y': 0,
        'width': 100,
        'height': 50,
        'blocksPointer': true,
        'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>',
      });
      for (final doc in [native, covered]) {
        expect(await scrolled(tester, const Offset(350, 25), const Offset(0, -20), doc: doc), isEmpty);
      }
    });

    testWidgets('a scroll on the knob itself moves it once', (tester) async {
      expect(await scrolled(tester, const Offset(100, 100), const Offset(0, 20)), [('pan', 45.0)]);
    });

    // Read as an upward one, a sideways swipe would move the same way whichever way it went.
    testWidgets('a sideways scroll moves a one-axis knob by its own direction', (tester) async {
      expect(await scrolled(tester, const Offset(100, 100), const Offset(20, 0)), [('pan', 55.0)]);
      expect(await scrolled(tester, const Offset(100, 100), const Offset(-20, 0)), [('pan', 45.0)]);
    });

    testWidgets('invertDrag moves the value the other way to a drag, as content held under it', (tester) async {
      for (final (invert, moved) in [(false, greaterThan(50.0)), (true, lessThan(50.0))]) {
        final events = <Object?>[];
        await show(
          tester,
          scroller(invertDrag: invert)..['values'] = {'v': 50},
          onEvent: (e) async {
            events.add(e['value']);
            return {};
          },
        );
        await tester.dragFrom(tester.getTopLeft(find.byType(PanelSceneView)) + const Offset(100, 150), const Offset(0, -60));
        await tester.pumpAndSettle();
        expect(events.last, moved, reason: 'dragged up, invertDrag: $invert');
      }
    });

    test('invertDrag is a knob\'s, and scrollThrough a slider\'s or knob\'s', () {
      final doc = document(local: true);
      (doc['controls'] as List).first['invertDrag'] = true;
      expect(() => PanelScene(doc), throwsFormatException);
      final button = document(local: true);
      (button['controls'] as List).add({'id': 'b', 'label': 'B', 'kind': 'button', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'scrollThrough': true});
      expect(() => PanelScene(button), throwsFormatException);
    });
  });

  group('a scrolling scene', () {
    // 400 wide like its panel, 800 tall: twice what the 400×200 panel shows. A label at 250 to read
    // where the view is, a fixed one at the panel's top, and a button to start a drag on.
    Map<String, dynamic> long({double at = 200, String? event = 'scrolled'}) => {
      'version': 1,
      'width': 400,
      'height': 800,
      'values': {'pos': at},
      'scroll': {'axis': 'y', 'value': 'pos', 'event': ?event},
      'layers': [
        {
          'id': 'mark',
          'x': 0,
          'y': 250,
          'width': 200,
          'height': 20,
          'text': {'literal': 'Mark'},
        },
        {
          'id': 'pinned',
          'x': 0,
          'y': 0,
          'width': 200,
          'height': 20,
          'fixed': true,
          'text': {'literal': 'Pinned'},
        },
      ],
      'controls': [
        {'id': 'b', 'label': 'Spot', 'kind': 'button', 'x': 0, 'y': 300, 'width': 400, 'height': 40, 'event': 'tune'},
      ],
    };

    double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy - tester.getTopLeft(find.byType(PanelSceneView)).dy;

    test('names a scene value, takes no layout, and keeps fixed and scrolling apart', () {
      final layout = long()..['layout'] = {'scene': true};
      final unknown = long()..['scroll'] = {'axis': 'y', 'value': 'nowhere'};
      final unplaced = long()
        ..['controls'] = [
          {'id': 'n', 'label': 'N', 'kind': 'nativeButton', 'event': 'go', 'fixed': true},
        ];
      final straddling = long()
        ..['controls'] = [
          {'id': 'b', 'label': 'B', 'kind': 'button', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'after': 'pinned'},
        ];
      for (final doc in [layout, unknown, unplaced, straddling]) {
        expect(() => PanelScene(doc), throwsFormatException);
      }
    });

    testWidgets('opens where its value says, with fixed layers over the panel', (tester) async {
      await show(tester, long());
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(50, 0.5));
      expect(top(tester, 'Pinned'), closeTo(0, 0.5));
    });

    // A band map's calls cover it: a drag that had to start between them would hardly ever start.
    testWidgets('scrolls natively under a drag begun on a button, telling the extension once it settles', (tester) async {
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        long(),
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      await tester.pump();
      await tester.dragFrom(tester.getCenter(find.bySemanticsLabel('Spot')), const Offset(0, -100));
      await tester.pumpAndSettle();
      // Told once the scroll has stayed put a moment.
      await tester.pump(const Duration(milliseconds: 400));
      expect(top(tester, 'Pinned'), closeTo(0, 0.5));
      final moved = 50 - top(tester, 'Mark');
      expect(moved, greaterThan(50));
      expect(events.map((e) => (e['action'], e['phase'])), [('scrolled', 'commit')]);
      expect(events.single['value'] as double, closeTo(200 + moved, 0.5));
    });

    // The scroll view moves the content itself; a readout of the position is drawn from the value,
    // and stays where the scroll began until something redraws it.
    testWidgets('artwork reading the scroll position follows the scroll', (tester) async {
      final doc = long(event: null);
      (doc['layers'] as List).add({
        'id': 'where',
        'x': 200,
        'y': 0,
        'width': 200,
        'height': 20,
        'fixed': true,
        'text': {'value': 'pos', 'prefix': 'At '},
      });
      await show(tester, doc);
      await tester.pump();
      expect(find.text('At 200'), findsOneWidget);
      await tester.drag(find.byType(PanelSceneView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(find.text('At 200'), findsNothing);
    });

    // Laid out at no width, the scene's scale is zero: its length infinite, its position not a number.
    testWidgets('a pane with no room draws nothing rather than failing', (tester) async {
      await show(tester, long(), width: 0);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // The purge after a refused value keeps an action from acting on what the extension refused; a
    // scroll refused leaves every value as it was, and the operator's tap must still go.
    testWidgets('a refused settle event does not cancel a tap queued behind it', (tester) async {
      final actions = <String?>[];
      final settle = Completer<Map<String, Object>>();
      await show(
        tester,
        long(),
        onEvent: (e) {
          actions.add(e['action'] as String?);
          return e['action'] == 'scrolled' ? settle.future : Future.value(const {});
        },
      );
      await tester.pump();
      await tester.drag(find.byType(PanelSceneView), const Offset(0, -60));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(actions, ['scrolled']);
      await tester.tap(find.bySemanticsLabel('Spot'));
      await tester.pump();
      settle.completeError(StateError('refused'));
      await tester.pumpAndSettle();
      expect(actions, ['scrolled', 'tune']);
    });

    // A zoom strip down the left 100 of the 400×200 pane, its middle at 100, with a button on it.
    Map<String, dynamic> zoomable() => long()
      ..['controls'] = [
        {'id': 'z', 'label': 'Zoom', 'kind': 'zoom', 'x': 0, 'y': 0, 'width': 100, 'height': 800, 'event': 'stretch', 'min': 0.25, 'max': 4},
        {'id': 'b', 'label': 'Spot', 'kind': 'button', 'x': 0, 'y': 300, 'width': 100, 'height': 40, 'event': 'tune'},
      ];

    test('a zoom strip is a scrolling scene\'s, and says the factors it allows', () {
      final unscrolled = zoomable()..remove('scroll');
      final unbounded = zoomable();
      (unbounded['controls'] as List).first.remove('max');
      // Placed among the layers it would be a drawn control, and a drag on it would set a value it has not got.
      final layered = zoomable();
      (layered['controls'] as List).first['after'] = 'mark';
      for (final doc in [unscrolled, unbounded, layered]) {
        expect(() => PanelScene(doc), throwsFormatException);
      }
    });

    Future<List<(String?, Object?)>> dragged(WidgetTester tester, Offset from, Offset by) async {
      final events = <(String?, Object?)>[];
      await show(
        tester,
        zoomable(),
        onEvent: (e) async {
          events.add((e['action'] as String?, e['value']));
          return {};
        },
      );
      await tester.pump();
      await tester.dragFrom(tester.getTopLeft(find.byType(PanelSceneView)) + from, by);
      await tester.pumpAndSettle();
      return events;
    }

    testWidgets('a drag on it away from the pane\'s middle zooms in, toward it zooms out, by the distance\'s ratio', (tester) async {
      final out = await dragged(tester, const Offset(50, 150), const Offset(0, 40));
      expect(out.single.$1, 'stretch');
      expect(out.single.$2 as double, closeTo(90 / 50, 0.15));
      final back = await dragged(tester, const Offset(50, 190), const Offset(0, -60));
      expect(back.single.$2 as double, closeTo(30 / 90, 0.1));
    });

    // A stretched picture stretches its text too; the zoom moves the pieces apart at their own sizes.
    testWidgets('while it is dragged, each piece moves to where the zoom puts it and keeps its size', (tester) async {
      await show(tester, zoomable(), onEvent: (_) async => {});
      await tester.pump();
      final origin = tester.getTopLeft(find.byType(PanelSceneView));
      final before = tester.getRect(find.text('Mark'));
      final gesture = await tester.startGesture(origin + const Offset(50, 150));
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final during = tester.getRect(find.text('Mark'));
      // 50 from the middle to 100 doubles the view about it: Mark's middle, 60 below the pane's at
      // 160, goes to 220; its height stays its own.
      expect(during.height, closeTo(before.height, 0.01));
      // Over the pane, not the content: the zoom has nothing to move it to.
      expect(top(tester, 'Pinned'), closeTo(0, 0.5));
      expect(during.center.dy - origin.dy, closeTo(before.center.dy - origin.dy + (before.center.dy - origin.dy - 100), 1));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    // An extension that clamps the zoom away, or refuses it, sends back the scene it had: the preview
    // must not go on showing a zoom the scene has not got.
    testWidgets('a zoom answered with no new scene lets go of its preview', (tester) async {
      await show(tester, zoomable(), onEvent: (_) async => {});
      await tester.pump();
      final before = top(tester, 'Mark');
      await tester.dragFrom(tester.getTopLeft(find.byType(PanelSceneView)) + const Offset(50, 150), const Offset(0, 40));
      await tester.pump();
      expect(top(tester, 'Mark'), isNot(closeTo(before, 1)));
      await tester.pump(const Duration(seconds: 3));
      expect(top(tester, 'Mark'), closeTo(before, 0.5));
    });

    // Spots move on while a zoom waits for its answer; dropping the preview for that render would
    // flick back to the old zoom, then on to the new one.
    testWidgets('a render while the zoom waits keeps its preview, and the one answering it lets go', (tester) async {
      final answer = Completer<Map<String, Object>>();
      Future<Map<String, Object>> onEvent(Map<String, dynamic> e) => answer.future;
      await show(tester, zoomable(), onEvent: onEvent);
      await tester.pump();
      final before = top(tester, 'Mark');
      await tester.dragFrom(tester.getTopLeft(find.byType(PanelSceneView)) + const Offset(50, 150), const Offset(0, 40));
      await tester.pump();
      final zoomed = top(tester, 'Mark');
      expect(zoomed, isNot(closeTo(before, 1)));
      await show(tester, zoomable(), onEvent: onEvent);
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(zoomed, 0.5));
      answer.complete(const {});
      await tester.pump();
      await show(tester, zoomable(), onEvent: onEvent);
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(before, 0.5));
      await tester.pump(const Duration(seconds: 3));
    });

    // The strip lies under the scale's buttons: a click on one must still tune, not zoom.
    testWidgets('a tap on it still reaches the button there, and a drag off it still scrolls', (tester) async {
      final events = <(String?, Object?)>[];
      await show(
        tester,
        zoomable(),
        onEvent: (e) async {
          events.add((e['action'] as String?, e['value']));
          return {};
        },
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Spot'));
      await tester.pumpAndSettle();
      final mark = top(tester, 'Mark');
      await tester.dragFrom(tester.getTopLeft(find.byType(PanelSceneView)) + const Offset(300, 150), const Offset(0, -60));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(events.map((e) => e.$1), ['tune', 'scrolled']);
      expect(top(tester, 'Mark'), lessThan(mark));
    });

    // The same scrolling sideways: 1600 across the 400×200 pane, Mark at 450, the strip along the bottom 50.
    Map<String, dynamic> zoomableAcross() {
      final doc = zoomable()
        ..['width'] = 1600
        ..['height'] = 200
        ..['scroll'] = {'axis': 'x', 'value': 'pos', 'event': 'scrolled'};
      (doc['layers'] as List).first
        ..['x'] = 450
        ..['y'] = 20;
      (doc['controls'] as List).first
        ..['y'] = 150
        ..['width'] = 1600
        ..['height'] = 50;
      return doc;
    }

    Future<void> trackpad(WidgetTester tester, Offset at, {Offset pan = Offset.zero, List<double> scales = const []}) async {
      final where = tester.getTopLeft(find.byType(PanelSceneView)) + at;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
      await gesture.panZoomStart(where);
      if (pan != Offset.zero) await gesture.panZoomUpdate(where, pan: pan);
      for (final scale in scales) {
        await gesture.panZoomUpdate(where, scale: scale);
      }
      await gesture.panZoomEnd();
      await tester.pumpAndSettle();
    }

    // A trackpad's two-finger swipe reaches recognizers as a pan-zoom, which the strip's own check
    // never sees: unless the zoom drag refuses it, it claims the swipe anywhere in the pane and
    // nothing scrolls.
    for (final vertical in [true, false]) {
      testWidgets('a trackpad swipe scrolls, on the strip and off it, and does not zoom (${vertical ? 'down' : 'across'})', (tester) async {
        final events = <String?>[];
        await show(
          tester,
          vertical ? zoomable() : zoomableAcross(),
          onEvent: (e) async {
            events.add(e['action'] as String?);
            return {};
          },
        );
        await tester.pump();
        double mark() => vertical ? top(tester, 'Mark') : tester.getTopLeft(find.text('Mark')).dx - tester.getTopLeft(find.byType(PanelSceneView)).dx;
        final spots = vertical ? const [Offset(300, 150), Offset(50, 150)] : const [Offset(200, 50), Offset(200, 175)];
        for (final at in spots) {
          final before = mark();
          await trackpad(tester, at, pan: vertical ? const Offset(0, -60) : const Offset(-60, 0));
          expect(mark(), lessThan(before), reason: 'swiped at $at');
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(events, contains('scrolled'));
        expect(events, isNot(contains('stretch')));
      });
    }

    // A trackpad has no drag to zoom with but a click held down: its own zoom is the pinch.
    testWidgets('a trackpad pinch on the strip zooms by its scale, and off it does nothing', (tester) async {
      final events = <(String?, Object?)>[];
      await show(
        tester,
        zoomable(),
        onEvent: (e) async {
          events.add((e['action'] as String?, e['value']));
          return {};
        },
      );
      await tester.pump();
      await trackpad(tester, const Offset(300, 150), scales: const [1.5, 2]);
      expect(events, isEmpty);
      await trackpad(tester, const Offset(50, 150), scales: const [1.5, 2]);
      expect(events.single.$1, 'stretch');
      expect(events.single.$2 as double, closeTo(2, 0.001));
    });

    // An extension keeps the position it hears and renders it back; by then the operator may have
    // scrolled on, and jumping to it would yank the view out from under them.
    testWidgets('a render carrying back a position the host sent does not move the view', (tester) async {
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        long(),
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      await tester.pump();
      await tester.drag(find.byType(PanelSceneView), const Offset(0, -60));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      final heard = events.single['value'] as double;
      await tester.drag(find.byType(PanelSceneView), const Offset(0, -60));
      await tester.pumpAndSettle();
      final scrolled = top(tester, 'Mark');
      await show(tester, long(at: heard));
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(scrolled, 0.5));
      await tester.pump(const Duration(milliseconds: 400));
    });

    // An echo is spent once heard: a later render asking for that same position — a band change back
    // to where the operator once rested — is a move, and dropping it would leave the view elsewhere.
    testWidgets('a render asking again for a position already heard back moves the view', (tester) async {
      final heard = <double>[];
      Future<Map<String, Object>> onEvent(Map<String, dynamic> e) async {
        heard.add(e['value'] as double);
        return const {};
      }

      await show(tester, long(), onEvent: onEvent);
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.drag(find.byType(PanelSceneView), const Offset(0, -60));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await show(tester, long(at: heard.last), onEvent: onEvent);
        await tester.pump();
      }
      await show(tester, long(at: heard.first), onEvent: onEvent);
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(250 - heard.first, 0.5));
      await tester.pump(const Duration(milliseconds: 400));
    });

    // A panel ticking once a second would otherwise snap the view back under the operator.
    testWidgets('keeps the operator\'s scroll through a render that leaves the value alone, and moves for one that changes it', (tester) async {
      await show(tester, long());
      await tester.pump();
      await tester.drag(find.byType(PanelSceneView), const Offset(0, -100));
      await tester.pumpAndSettle();
      final scrolled = top(tester, 'Mark');
      await show(tester, long());
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(scrolled, 0.5));
      await show(tester, long(at: 100));
      await tester.pump();
      expect(top(tester, 'Mark'), closeTo(150, 0.5));
    });
  });

  test('a layer is SVG, text or a named icon, exactly one of them', () {
    Map<String, dynamic> withLayer(Map<String, dynamic> layer) => document()
      ..['layers'] = [
        {'id': 'l', 'x': 0, 'y': 0, 'width': 20, 'height': 20, ...layer},
      ];
    expect(
      PanelScene(
        withLayer({
          'icon': {'name': 'pine-tree', 'color': '#2E7D32'},
        }),
      ).layers.single.icon?.name,
      'pine-tree',
    );
    for (final layer in [
      {
        'icon': {'name': 'pine-tree'},
        'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>',
      },
      {
        'icon': {'name': 'pine-tree', 'color': 'green'},
      },
      {'icon': 'pine-tree'},
    ]) {
      expect(() => PanelScene(withLayer(layer)), throwsFormatException, reason: '$layer');
    }
  });

  testWidgets('an icon layer draws the app\'s own icon for its name, in its colour', (tester) async {
    final doc = document()
      ..['layers'] = [
        {
          'id': 'l',
          'x': 0,
          'y': 0,
          'width': 20,
          'height': 20,
          'icon': {'name': 'pine-tree', 'color': '#2E7D32'},
        },
      ];
    await show(tester, doc);
    final icon = tester.widget<Icon>(find.byIcon(resolveIconName('pine-tree')));
    expect(icon.color, const Color(0xFF2E7D32));
  });

  // A band map gives every spot a label, a lit outline and a hover strip on
  // its scale: 128 layers and 64 controls would hold barely thirty spots.
  test('a scene holds 512 layers and 256 controls, and no more', () {
    Map<String, dynamic> sized({int layers = 1, int controls = 0}) => document()
      ..['layers'] = [
        for (var i = 0; i < layers; i++) {'id': 'l$i', 'x': 0, 'y': 0, 'width': 1, 'height': 1, 'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>'},
      ]
      ..['controls'] = [
        for (var i = 0; i < controls; i++) {'id': 'c$i', 'label': 'C', 'kind': 'button', 'x': 0, 'y': 0, 'width': 1, 'height': 1},
      ];
    expect(PanelScene(sized(layers: 512, controls: 256)).controls, hasLength(256));
    expect(() => PanelScene(sized(layers: 513)), throwsFormatException);
    expect(() => PanelScene(sized(controls: 257)), throwsFormatException);
  });

  group('tapAt', () {
    // A scale drawn as a tall button and as a wide one: a click says where along each it landed.
    Map<String, dynamic> scales() {
      final doc = document();
      (doc['controls'] as List).addAll(<Map<String, Object>>[
        {'id': 'tall', 'label': 'Tall', 'kind': 'button', 'x': 200, 'y': 0, 'width': 40, 'height': 100, 'event': 'tall', 'tapAt': true},
        {'id': 'wide', 'label': 'Wide', 'kind': 'button', 'x': 300, 'y': 0, 'width': 100, 'height': 40, 'event': 'wide', 'tapAt': true},
      ]);
      return doc;
    }

    testWidgets('a click sends where along the longer side it landed', (tester) async {
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        scales(),
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      final tall = tester.getRect(find.bySemanticsLabel('Tall')), wide = tester.getRect(find.bySemanticsLabel('Wide'));
      await tester.tapAt(Offset(tall.center.dx, tall.top + tall.height / 4));
      await tester.tapAt(Offset(wide.left + wide.width * 0.75, wide.center.dy));
      await tester.pump();
      expect([for (final e in events) (e['action'], e['phase'])], [('tall', 'activate'), ('wide', 'activate')]);
      expect(events[0]['value'], closeTo(0.25, 0.01));
      expect(events[1]['value'], closeTo(0.75, 0.01));
    });

    // A scale that lights itself with a bound value must not have that value read as a place.
    testWidgets('activated by a screen reader, it sends no place, even with a value bound', (tester) async {
      final semantics = tester.ensureSemantics();
      final doc = scales();
      ((doc['controls'] as List).last as Map<String, dynamic>)['value'] = 'v';
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        doc,
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      tester.semantics.tap(find.semantics.byLabel('Wide'));
      await tester.pump();
      expect([for (final e in events) (e['action'], e.containsKey('value'))], [('wide', false)]);
      semantics.dispose();
    });

    test('belongs to a button', () {
      final doc = document(local: true);
      (doc['controls'] as List).add({'id': 's', 'label': 'S', 'kind': 'slider', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'value': 'v', 'tapAt': true});
      expect(() => PanelScene(doc), throwsFormatException);
    });
  });

  group('hoverSet', () {
    // Two spots side by side, each lighting up its own number in one shared value. The slider
    // sends events, so nothing else keeps `v` across a render.
    Map<String, dynamic> spots({double value = 0}) {
      final doc = document(value: value);
      (doc['controls'] as List).addAll(<Map<String, Object>>[
        for (final (id, x, to) in [('a', 200, 7), ('b', 300, 9)])
          {
            'id': id,
            'label': 'Spot $id',
            'kind': 'button',
            'x': x,
            'y': 0,
            'width': 100,
            'height': 50,
            'event': 'tune',
            'hoverSet': {'value': 'v', 'to': to},
          },
      ]);
      return doc;
    }

    Future<TestGesture> mouse(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getRect(find.byType(PanelSceneView)).bottomRight - const Offset(1, 1));
      addTearDown(gesture.removePointer);
      return gesture;
    }

    testWidgets('lights up under the pointer with no bridge call, and goes out on leaving', (tester) async {
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        spots(),
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getRect(find.bySemanticsLabel('Spot a')).center);
      await tester.pump();
      expect(find.text('Value: 7'), findsOneWidget);
      // Straight onto the neighbour, with no empty space between to reset through.
      await gesture.moveTo(tester.getRect(find.bySemanticsLabel('Spot b')).center);
      await tester.pump();
      expect(find.text('Value: 9'), findsOneWidget);
      await gesture.moveTo(tester.getRect(find.byType(PanelSceneView)).bottomRight - const Offset(1, 1));
      await tester.pump();
      expect(find.text('Value: 0'), findsOneWidget);
      expect(events, isEmpty);
    });

    // An extension may set the value itself — the spot the radio is on — and must be heard when no
    // pointer holds it.
    testWidgets('follows the scene\'s renders while nothing is hovered', (tester) async {
      await show(tester, spots(), onEvent: (_) async => {});
      await show(tester, spots(value: 3), onEvent: (_) async => {});
      expect(find.text('Value: 3'), findsOneWidget);
    });

    testWidgets('holds through a render while the pointer stays, then gives back the new scene value', (tester) async {
      await show(tester, spots(), onEvent: (_) async => {});
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getRect(find.bySemanticsLabel('Spot a')).center);
      await tester.pump();
      // A panel ticking once a second would otherwise blink its highlight off under a still pointer.
      await show(tester, spots(value: 3), onEvent: (_) async => {});
      expect(find.text('Value: 7'), findsOneWidget);
      await gesture.moveTo(tester.getRect(find.byType(PanelSceneView)).bottomRight - const Offset(1, 1));
      await tester.pump();
      expect(find.text('Value: 3'), findsOneWidget);
    });

    testWidgets('a hovered button still sends its click', (tester) async {
      final events = <Map<String, dynamic>>[];
      await show(
        tester,
        spots(),
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getRect(find.bySemanticsLabel('Spot a')).center);
      await tester.pump();
      await gesture.down(tester.getRect(find.bySemanticsLabel('Spot a')).center);
      await gesture.up();
      await tester.pump();
      expect(events.map((e) => e['controlId']), ['a']);
    });
  });

  testWidgets('local chart inspection survives refresh and makes no bridge call', (tester) async {
    var calls = 0;
    Future<Map<String, double>> handler(Map<String, dynamic> _) async {
      calls++;
      return {};
    }

    await show(tester, document(local: true), onEvent: handler);
    await tester.tapAt(tester.getRect(find.bySemanticsLabel('Test slider')).center);
    await tester.pump();
    expect(find.text('Value: 50'), findsOneWidget);
    await show(tester, document(local: true, value: 2), onEvent: handler);
    expect(find.text('Value: 50'), findsOneWidget);
    expect(calls, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Value: 51'), findsOneWidget);
  });

  testWidgets('stale replies cannot rewind a newer gesture; final commit survives', (tester) async {
    final replies = <Completer<Map<String, double>>>[];
    final events = <Map<String, dynamic>>[];
    Future<Map<String, double>> handler(Map<String, dynamic> event) {
      events.add(event);
      final reply = Completer<Map<String, double>>();
      replies.add(reply);
      return reply.future;
    }

    await show(tester, document(), onEvent: handler);
    final rect = tester.getRect(find.bySemanticsLabel('Test slider'));
    await tester.tapAt(Offset(rect.left + 80, rect.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(rect.left + 160, rect.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(rect.left + 320, rect.center.dy));
    await tester.pump();
    expect(events.length, 1);
    expect(find.text('Value: 80'), findsOneWidget);
    await show(tester, document(value: 5), onEvent: handler);
    expect(find.text('Value: 80'), findsOneWidget);
    replies.first.complete({'v': 20});
    await tester.pump();
    expect(find.text('Value: 80'), findsOneWidget);
    expect(events.length, 2);
    expect(events.last['value'], 80);
    replies.last.complete({'v': 79});
    await tester.pump();
    await tester.pump();
    expect(find.text('Value: 79'), findsOneWidget);
  });

  testWidgets('coalescing preserves order across controls sharing a value', (tester) async {
    final doc = document();
    final controls = List<dynamic>.of(doc['controls'] as List<dynamic>);
    doc['controls'] = controls;
    controls.add({...controls.first as Map<String, dynamic>, 'id': 'second', 'label': 'Second slider', 'y': 150});
    final events = <Map<String, dynamic>>[];
    final replies = <Completer<Map<String, double>>>[];
    await show(
      tester,
      doc,
      onEvent: (event) {
        events.add(event);
        final reply = Completer<Map<String, double>>();
        replies.add(reply);
        return reply.future;
      },
    );
    Future<void> commit(String label, double fraction) async {
      final rect = tester.getRect(find.bySemanticsLabel(label));
      await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
      await tester.pump();
    }

    await commit('Test slider', .1); // In flight.
    await commit('Test slider', .2); // Queued, will be superseded.
    await commit('Second slider', .3);
    await commit('Test slider', .4); // Must go AFTER the second slider.
    replies[0].complete({});
    await tester.pump();
    expect(events[1]['value'], 30);
    replies[1].complete({});
    await tester.pump();
    expect(events[2]['value'], 40);
    replies[2].complete({'v': 40});
    await tester.pump();
    await tester.pump();
    expect(find.text('Value: 40'), findsOneWidget);
  });

  testWidgets('failed commands roll back and a later command can succeed', (tester) async {
    var fail = true;
    await show(
      tester,
      document(value: 10),
      onEvent: (event) async {
        if (fail) throw StateError('Disconnected');
        return {'v': (event['value'] as num).toDouble()};
      },
    );
    await tester.tapAt(tester.getRect(find.bySemanticsLabel('Test slider')).center);
    await tester.pump();
    expect(find.text('Value: 10'), findsOneWidget);
    expect(find.text(t.operation.layout.panelActionFailed), findsOneWidget);
    fail = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Value: 11'), findsOneWidget);
    expect(find.text(t.operation.layout.panelActionFailed), findsNothing);
  });

  testWidgets('animation frames do not call extensions and stop while hidden or reduced', (tester) async {
    var calls = 0;
    Future<Map<String, double>> handler(Map<String, dynamic> _) async {
      calls++;
      return {};
    }

    await show(tester, document(pulse: true), onEvent: handler);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(calls, 0);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await show(tester, document(pulse: true), onEvent: handler, visible: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, 0);
    await show(tester, document(pulse: true), onEvent: handler, reduced: true);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('late responses after disposal are harmless', (tester) async {
    final reply = Completer<Map<String, double>>();
    await show(tester, document(), onEvent: (_) => reply.future);
    await tester.tapAt(tester.getRect(find.bySemanticsLabel('Test slider')).center);
    await tester.pumpWidget(const SizedBox());
    reply.complete({'v': 20});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
