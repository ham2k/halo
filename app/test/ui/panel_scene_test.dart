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
