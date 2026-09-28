// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `native…` controls: Material widgets bound to scene values and
// strings, placed over the artwork or by a layout tree.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
// The backstop is internal to the logging panel; the contract it enforces
// reaches every pane, a scene's fields included.
// ignore: implementation_imports
import 'package:halo_widgets/src/logging_controls_focus.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

Map<String, dynamic> scene({
  List<Map<String, dynamic>> controls = const [],
  Map<String, dynamic>? layout,
  Map<String, double> values = const {'power': 50, 'qrp': 0},
  Map<String, String> strings = const {'call': '', 'band': '20m', 'mode': 'CW'},
  bool artwork = true,
}) => {
  'version': 1,
  'width': 400,
  'height': 100,
  'values': values,
  'strings': strings,
  'layers': [
    if (artwork)
      {
        'id': 'status',
        'x': 0,
        'y': 0,
        'width': 400,
        'height': 40,
        'text': {'value': 'band', 'prefix': 'Band '},
      },
  ],
  'controls': controls,
  'layout': ?layout,
};

Map<String, dynamic> column(List<String> ids) => {
  'column': [
    for (final id in ids) {'control': id},
  ],
  'crossAxisAlignment': 'stretch',
};

const callField = {'id': 'call', 'kind': 'nativeTextField', 'label': 'Callsign', 'value': 'call', 'event': 'set'};
const spotButton = {'id': 'spot', 'kind': 'nativeButton', 'label': 'Spot', 'event': 'spot'};

Future<void> show(WidgetTester tester, Map<String, dynamic> doc, {SceneEventHandler? onEvent, double width = 400, double height = 300}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
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
  );
  await tester.pump();
}

void main() {
  group('the document is refused', () {
    void refused(Map<String, dynamic> doc, String why) => expect(() => PanelScene(doc), throwsFormatException, reason: why);

    test('where a control could not be placed or bound', () {
      refused(scene(controls: [callField]), 'no rect and no layout: it would be silently missing');
      refused(
        scene(
          controls: [callField],
          layout: {
            'row': [
              {'control': 'call'},
              {'control': 'call'},
            ],
          },
        ),
        'placed twice: two widgets would share one control state',
      );
      refused(
        scene(
          controls: [
            {'id': 'drawn', 'kind': 'button', 'label': 'Drawn', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'event': 'e'},
          ],
          layout: {
            'row': [
              {'control': 'drawn'},
              {'scene': true},
            ],
          },
        ),
        'a drawn control is a hit area over artwork, and has no widget to lay out',
      );
      refused(
        scene(
          controls: [
            {...callField, 'value': 'power'},
          ],
          layout: column(['call']),
        ),
        'a text field bound to a number would send text the extension reads as a value',
      );
      refused(scene(values: {'band': 1}, controls: [callField], layout: column(['call'])), 'a key in both maps is ambiguous in a patch');
      refused(scene(controls: [callField], layout: column(['call'])), 'layers with no scene node would never be drawn');
    });

    test('where Flutter itself would throw in layout', () {
      refused(
        scene(
          artwork: false,
          controls: [callField],
          layout: {
            'wrap': [
              {'control': 'call', 'flex': 1},
            ],
          },
        ),
        'Flexible under a Wrap is a parent-data assertion',
      );
      Map<String, dynamic> nested(int depth) => depth == 0
          ? {'control': 'call'}
          : {
              'column': [nested(depth - 1)],
            };
      expect(() => PanelScene(scene(artwork: false, controls: [callField], layout: nested(7))), returnsNormally);
      refused(scene(artwork: false, controls: [callField], layout: nested(8)), 'layout depth is capped');
    });

    test('with a FormatException naming the control, not a crash', () {
      // `multi` is checked before the options it joins: on a kind without
      // options, the other order is a null check the author never sees named.
      expect(
        () => PanelScene(
          scene(
            artwork: false,
            controls: [
              {'id': 'qrp', 'kind': 'nativeSwitch', 'label': 'QRP', 'value': 'qrp', 'event': 'set', 'multi': true},
            ],
            layout: column(['qrp']),
          ),
        ),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('qrp'))),
      );
    });

    test('where a choice holds a value it does not offer', () {
      Map<String, dynamic> choice(String current, {bool multi = false}) => scene(
        artwork: false,
        strings: {'call': '', 'band': current, 'mode': 'CW'},
        controls: [
          {
            'id': 'band',
            'kind': multi ? 'nativeSegmented' : 'nativeDropdown',
            'label': 'Band',
            'value': 'band',
            'event': 'set',
            'multi': ?(multi ? true : null),
            'options': [
              {'label': '20', 'value': '20m'},
              {'label': '40', 'value': '40m'},
            ],
          },
        ],
        layout: column(['band']),
      );
      expect(() => PanelScene(choice('')), returnsNormally, reason: 'nothing chosen is a choice');
      expect(() => PanelScene(choice('20m,40m', multi: true)), returnsNormally);
      refused(choice('60m'), 'shown as nothing chosen, the value the extension holds is invisible');
      refused(choice('20m,60m', multi: true), "the operator's next tap would silently drop 60m");
    });

    test('where a wrap is asked to stretch', () {
      refused(
        scene(
          artwork: false,
          controls: [callField],
          layout: {
            'wrap': [
              {'control': 'call'},
            ],
            'crossAxisAlignment': 'stretch',
          },
        ),
        'Wrap has no stretch: taken as start, the author never learns why',
      );
    });

    test('where a choice or an action could not work', () {
      Map<String, dynamic> choice(Map<String, dynamic> extra) => scene(
        artwork: false,
        controls: [
          {'id': 'mode', 'kind': 'nativeSegmented', 'label': 'Mode', 'value': 'mode', 'event': 'set', ...extra},
        ],
        layout: column(['mode']),
      );
      refused(choice({}), 'a choice with no options');
      refused(
        choice({
          'options': [
            {'label': 'CW', 'value': 'CW'},
            {'label': 'Also CW', 'value': 'CW'},
          ],
        }),
        'duplicate values cannot be told apart once chosen',
      );
      refused(
        choice({
          'multi': true,
          'options': [
            {'label': 'A,B', 'value': 'A,B'},
          ],
        }),
        'a multi-select is sent comma-joined',
      );
      refused(
        scene(
          artwork: false,
          controls: [
            {...spotButton}..remove('event'),
          ],
          layout: column(['spot']),
        ),
        'a button that sends nothing does nothing',
      );
    });
  });

  testWidgets('a refresh while typing keeps the typing, and nothing is sent before Enter', (tester) async {
    final events = <Map<String, dynamic>>[];
    Future<Map<String, Object>> handler(Map<String, dynamic> event) async {
      events.add(event);
      return {};
    }

    Map<String, dynamic> doc(String band) => scene(
      strings: {'call': '', 'band': band, 'mode': 'CW'},
      controls: [callField],
      layout: {
        'column': [
          {'control': 'call'},
          {'scene': true, 'flex': 1},
        ],
      },
    );
    await show(tester, doc('20m'), onEvent: handler);
    await tester.enterText(find.byType(TextField), 'K2HR');
    await tester.pump();
    // Not continuous: a keystroke is not a commit.
    expect(events, isEmpty);

    // A render lands mid-typing, still reporting the empty callsign. Taking
    // it would wipe what the operator has typed.
    await show(tester, doc('40m'), onEvent: handler);
    expect(find.text('Band 40m'), findsOneWidget, reason: 'the refresh did land');
    expect(find.text('K2HR'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'K2HRC');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(events.single, containsPair('text', 'K2HRC'));
  });

  testWidgets('Enter sends `text`, not `value`, and the reply patches strings the scene shows', (tester) async {
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      scene(
        controls: [callField],
        layout: {
          'column': [
            {'control': 'call'},
            {'scene': true, 'flex': 1},
          ],
        },
      ),
      onEvent: (event) async {
        events.add(event);
        return {'call': 'K2HRC', 'band': '40m'};
      },
    );
    await tester.enterText(find.byType(TextField), 'k2hrc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(events.single, containsPair('text', 'k2hrc'));
    expect(events.single, isNot(contains('value')));
    expect(events.single['phase'], 'commit');
    // The extension's normalized answer replaces what was typed, and a text
    // layer bound to a string follows its patch.
    expect(find.text('K2HRC'), findsOneWidget);
    expect(find.text('Band 40m'), findsOneWidget);
  });

  testWidgets('leaving a field commits only what was typed', (tester) async {
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      scene(artwork: false, controls: [callField, spotButton], layout: column(['call', 'spot'])),
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // Clicking into a field and out again is not an edit; committing it
    // would send the extension a change that never happened.
    expect(events, isEmpty);

    await tester.enterText(find.byType(TextField), 'N0DEV');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(events.single, containsPair('text', 'N0DEV'));
  });

  testWidgets('choices send the chosen string; a multi-select joins in option order', (tester) async {
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      scene(
        artwork: false,
        strings: {'band': '20m', 'mode': 'CW', 'modes': ''},
        controls: [
          {
            'id': 'band',
            'kind': 'nativeDropdown',
            'label': 'Band',
            'value': 'band',
            'event': 'set',
            'options': [
              {'label': '40 meters', 'value': '40m'},
              {'label': '20 meters', 'value': '20m'},
            ],
          },
          {
            'id': 'modes',
            'kind': 'nativeSegmented',
            'label': 'Modes',
            'value': 'modes',
            'event': 'set',
            'multi': true,
            'options': [
              {'label': 'CW', 'value': 'CW'},
              {'label': 'SSB', 'value': 'SSB'},
              {'label': 'FT8', 'value': 'FT8'},
            ],
          },
        ],
        layout: column(['band', 'modes']),
      ),
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    await tester.tap(find.text('20 meters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('40 meters').last);
    await tester.pumpAndSettle();
    expect(events.last, containsPair('text', '40m'));

    await tester.tap(find.text('FT8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CW'));
    await tester.pumpAndSettle();
    // Tapped FT8 first; sent as the options list them, so the extension can
    // compare strings rather than parse sets.
    expect(events.last, containsPair('text', 'CW,FT8'));
  });

  testWidgets('toggles send 1 and 0; one with no event stays local across a refresh', (tester) async {
    final events = <Map<String, dynamic>>[];
    final controls = [
      {'id': 'qrp', 'kind': 'nativeSwitch', 'label': 'QRP', 'value': 'qrp', 'event': 'set'},
      {'id': 'cw', 'kind': 'nativeChip', 'label': 'CW only', 'value': 'cwOnly'},
    ];
    Map<String, dynamic> doc() => scene(artwork: false, values: {'qrp': 0, 'cwOnly': 0}, controls: controls, layout: column(['qrp', 'cw']));
    Future<Map<String, Object>> handler(Map<String, dynamic> event) async {
      events.add(event);
      return {};
    }

    await show(tester, doc(), onEvent: handler);
    // The caption is part of the control: tapping the word toggles it.
    await tester.tap(find.text('QRP'));
    await tester.pumpAndSettle();
    expect(events.single, containsPair('value', 1.0));
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(events, hasLength(1), reason: 'a chip with no event sends nothing');
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);

    // The document still says 0: a local-only toggle is the panel's own state
    // and must not snap back on every render.
    await show(tester, doc(), onEvent: handler);
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
  });

  testWidgets('an action button waits out the action it started, and a failure rolls strings back', (tester) async {
    final events = <Map<String, dynamic>>[];
    final reply = Completer<Map<String, Object>>();
    await show(
      tester,
      scene(artwork: false, controls: [callField, spotButton], layout: column(['call', 'spot'])),
      onEvent: (event) {
        events.add(event);
        return event['action'] == 'spot' ? reply.future : Future.error(StateError('rejected'));
      },
    );
    await tester.tap(find.text('Spot'));
    await tester.pump();
    expect(events.single['phase'], 'activate');
    // A second press while the first is outstanding would send the spot twice.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    reply.complete({});
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'BAD');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Rejected: the field shows the reported string again, not text the
    // extension refused.
    expect(find.text('BAD'), findsNothing);
    expect(find.text(t.operation.layout.panelActionFailed), findsOneWidget);
  });

  testWidgets('a row lays out fields that have no width of their own, and stretch survives an unbounded axis', (tester) async {
    await show(
      tester,
      scene(
        artwork: false,
        controls: [
          callField,
          spotButton,
          {'id': 'label', 'kind': 'nativeText', 'label': 'Ready', 'style': 'title'},
        ],
        layout: {
          'column': [
            {
              // Neither the text field nor the row has a width: without the
              // fallback, InputDecorator throws on the unbounded row.
              'row': [
                {'control': 'call'},
                {'control': 'spot'},
              ],
              'crossAxisAlignment': 'stretch',
            },
            {'spacer': 1},
            {'control': 'label'},
          ],
        },
      ),
      width: 600,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TextField)).width, 200);
    expect(find.text('Ready'), findsOneWidget);
    // The spacer took the free space: the label sits at the bottom.
    expect(tester.getBottomLeft(find.text('Ready')).dy, closeTo(tester.getBottomLeft(find.byType(PanelSceneView)).dy, 1));
  });

  testWidgets('a native control over the artwork keeps its rect', (tester) async {
    await show(
      tester,
      scene(
        controls: [
          {...spotButton, 'x': 200, 'y': 50, 'width': 200, 'height': 50},
        ],
      ),
      width: 400,
      height: 100,
    );
    final button = tester.getRect(find.byType(FilledButton));
    final pane = tester.getRect(find.byType(PanelSceneView));
    expect(button.left - pane.left, closeTo(200, 1));
    expect(button.width, closeTo(200, 1));
  });

  testWidgets('an action sends the typing it acts on first', (tester) async {
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      scene(artwork: false, controls: [callField, spotButton], layout: column(['call', 'spot'])),
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    await tester.enterText(find.byType(TextField), 'K2HRC');
    // No Enter, and on touch the tap does not blur the field. Sent in tap
    // order, Spot reaches the extension before the callsign it spots.
    await tester.tap(find.text('Spot'));
    await tester.pumpAndSettle();
    expect([for (final e in events) e['controlId']], ['call', 'spot']);
    expect(events.first, containsPair('text', 'K2HRC'));
  });

  testWidgets('a refused callsign stops the Spot queued behind it, and says so', (tester) async {
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      scene(artwork: false, controls: [callField, spotButton], layout: column(['call', 'spot'])),
      onEvent: (event) {
        events.add(event);
        return event['controlId'] == 'call' ? Future.error(StateError('not a callsign')) : Future.value(<String, Object>{});
      },
    );
    await tester.enterText(find.byType(TextField), 'K2HRC?');
    // The tap commits the typing first, and the Spot waits behind it. The
    // commit is no longer the newest event when it fails; judged as stale,
    // its failure went unsaid and Spot went out with the old callsign.
    await tester.tap(find.text('Spot'));
    await tester.pumpAndSettle();
    expect([for (final e in events) e['controlId']], ['call']);
    expect(find.text(t.operation.layout.panelActionFailed), findsOneWidget);
  });

  testWidgets('a disabled drawn knob ignores drags, the wheel and screen-reader adjustment', (tester) async {
    final events = <Map<String, dynamic>>[];
    await show(
      tester,
      scene(
        values: {'power': 50, 'qrp': 0},
        controls: [
          {
            'id': 'knob',
            'kind': 'knob',
            'label': 'Tuning',
            'value': 'power',
            'event': 'tune',
            'min': 0,
            'max': 100,
            'x': 0,
            'y': 0,
            'width': 100,
            'height': 100,
            'disabled': true,
          },
        ],
      ),
      onEvent: (event) async {
        events.add(event);
        return {};
      },
    );
    final knob = find.bySemanticsLabel('Tuning');
    await tester.drag(knob, const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(PointerScrollEvent(position: tester.getCenter(knob), scrollDelta: const Offset(0, -20)));
    await tester.pumpAndSettle();
    // A panel marks its knob disabled while the radio is away; any path
    // still live would tune a radio the panel says it cannot.
    expect(events, isEmpty);
    expect(tester.getSemantics(knob).getSemanticsData().hasAction(SemanticsAction.increase), isFalse);
  });

  testWidgets('a control that becomes a text field works as one', (tester) async {
    final events = <Map<String, dynamic>>[];
    Map<String, dynamic> doc(String kind) => scene(
      artwork: false,
      controls: [
        {
          ...callField,
          'kind': kind,
          if (kind == 'nativeDropdown')
            'options': [
              {'label': 'A', 'value': 'A'},
            ],
        },
      ],
      layout: column(['call']),
    );
    Future<Map<String, Object>> handler(Map<String, dynamic> event) async {
      events.add(event);
      return {};
    }

    await show(tester, doc('nativeDropdown'), onEvent: handler);
    // Same id, new kind: a State kept from the dropdown has no controller,
    // and Enter would crash on it.
    await show(tester, doc('nativeTextField'), onEvent: handler);
    await tester.enterText(find.byType(TextField), 'K2HRC');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(events.single, containsPair('text', 'K2HRC'));
  });

  testWidgets('a field removed mid-typing lets its value follow the document again', (tester) async {
    Map<String, dynamic> doc(String call, {bool field = true}) => scene(
      artwork: false,
      strings: {'call': call, 'band': '20m', 'mode': 'CW'},
      controls: [
        if (field) callField,
        {'id': 'shown', 'kind': 'nativeText', 'label': 'Call', 'value': 'call'},
      ],
      layout: column([if (field) 'call', 'shown']),
    );
    await show(tester, doc(''), onEvent: (_) async => {});
    await tester.enterText(find.byType(TextField), 'AB');
    await show(tester, doc('', field: false), onEvent: (_) async => {});
    // Left claimed by the disposed field, 'call' would be frozen at what it
    // was: this render's K2HRC would never show.
    await show(tester, doc('K2HRC', field: false), onEvent: (_) async => {});
    expect(find.text('K2HRC'), findsOneWidget);
  });

  testWidgets('a flex with no room to share lays out unflexed rather than throwing', (tester) async {
    await show(
      tester,
      scene(
        artwork: false,
        controls: [callField, spotButton],
        layout: {
          'row': [
            // An unflexed row inside a row has an unbounded width; a Flexible
            // under it is a Flutter assertion the parser cannot see coming.
            {
              'row': [
                {'control': 'call', 'flex': 1},
                {'spacer': 1},
                {'control': 'spot'},
              ],
            },
          ],
        },
      ),
      width: 600,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Spot'), findsOneWidget);
  });

  test("a drawn button's value is not checked", () {
    // Published scenes name anything there; refusing one now would blank a
    // panel that rendered on every earlier host.
    expect(
      () => PanelScene(
        scene(
          controls: [
            {'id': 'b', 'kind': 'button', 'label': 'B', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'event': 'e', 'value': 'nowhere'},
          ],
        ),
      ),
      returnsNormally,
    );
  });

  testWidgets('a value commit awaiting its answer does not disable an action', (tester) async {
    final events = <Map<String, dynamic>>[];
    final callReply = Completer<Map<String, Object>>();
    await show(
      tester,
      scene(artwork: false, controls: [callField, spotButton], layout: column(['call', 'spot'])),
      onEvent: (event) {
        events.add(event);
        return event['controlId'] == 'call' ? callReply.future : Future.value({});
      },
    );
    await tester.enterText(find.byType(TextField), 'K2HRC');
    // On desktop, pressing Spot blurs the field before the press completes,
    // and the field sends its callsign. Were every event in flight to
    // disable action buttons, Spot would be disabled before the click
    // landed, and the click would vanish.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect([for (final e in events) e['controlId']], ['call']);
    await tester.tap(find.text('Spot'));
    await tester.pump();
    callReply.complete({});
    await tester.pumpAndSettle();
    expect([for (final e in events) e['controlId']], ['call', 'spot']);
  });

  testWidgets('a slider removed mid-drag lets its value follow the document again', (tester) async {
    Map<String, dynamic> doc(double power, {bool slider = true}) => scene(
      artwork: false,
      values: {'power': power, 'qrp': 0},
      controls: [
        if (slider) {'id': 'power', 'kind': 'nativeSlider', 'label': 'Power', 'value': 'power', 'event': 'set', 'min': 0, 'max': 100, 'step': 1},
        {'id': 'shown', 'kind': 'nativeText', 'label': 'Power', 'value': 'power'},
      ],
      layout: column([if (slider) 'power', 'shown']),
    );
    await show(tester, doc(50), onEvent: (_) async => {});
    final drag = await tester.startGesture(tester.getCenter(find.byType(Slider)));
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    // Flutter sends no onChangeEnd to a slider unmounted mid-drag, so the
    // claim on `power` has to go with it, or 20 would never show.
    await show(tester, doc(50, slider: false), onEvent: (_) async => {});
    await show(tester, doc(20, slider: false), onEvent: (_) async => {});
    expect(find.text('20'), findsOneWidget);
    await drag.up();
  });

  testWidgets('a slider shows ticks only where its steps land', (tester) async {
    Future<int?> divisions(double step) async {
      await show(
        tester,
        scene(
          artwork: false,
          controls: [
            {'id': 'p', 'kind': 'nativeSlider', 'label': 'P', 'value': 'power', 'event': 'set', 'min': 0, 'max': 1, 'step': step},
          ],
          layout: column(['p']),
        ),
      );
      return tester.widget<Slider>(find.byType(Slider)).divisions;
    }

    expect(await divisions(0.25), 4);
    // 0.3 does not divide 1: ticks at thirds would disagree with the 0.3
    // snapping, and the thumb would jump back after every move.
    expect(await divisions(0.3), isNull);
  });

  group('over the artwork', () {
    const box = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#335577"/></svg>';
    const bound = {
      'value': 'vis',
      'input': [0, 1],
      'output': [0, 1],
    };
    Map<String, dynamic> layered({bool blocks = false, double? opacity, Object? controlOpacity, Object? glassOpacity}) => {
      ...scene(artwork: false, values: {'vis': opacity ?? 1}),
      'layers': [
        {'id': 'under', 'x': 0, 'y': 0, 'width': 400, 'height': 100, 'svg': box},
        {'id': 'glass', 'x': 0, 'y': 0, 'width': 400, 'height': 100, 'svg': box, 'blocksPointer': blocks, 'opacity': ?glassOpacity},
      ],
      'controls': [
        {...spotButton, 'x': 100, 'y': 25, 'width': 200, 'height': 50, 'after': 'under', 'opacity': ?controlOpacity},
      ],
    };

    List<String> paintOrder(WidgetTester tester) => [
      for (final child in tester.widget<Stack>(find.descendant(of: find.byType(PanelSceneView), matching: find.byType(Stack)).first).children)
        (child.key! as ValueKey<String>).value,
    ];

    testWidgets('a control placed after a layer paints there, under what follows it', (tester) async {
      await show(tester, layered(), height: 100);
      expect(paintOrder(tester), ['layer:under', 'control:spot', 'layer:glass']);
    });

    testWidgets('artwork over a control passes clicks through, unless it blocks them', (tester) async {
      final events = <Map<String, dynamic>>[];
      Future<Map<String, Object>> handler(Map<String, dynamic> event) async {
        events.add(event);
        return {};
      }

      await show(tester, layered(), onEvent: handler, height: 100);
      // warnIfMissed off: the glass is on top, which is the point.
      await tester.tap(find.text('Spot'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Without click-through, a highlight or a frame drawn over a button
      // would silently make it dead.
      expect(events, hasLength(1));

      await show(tester, layered(blocks: true), onEvent: handler, height: 100);
      await tester.tap(find.text('Spot'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(events, hasLength(1), reason: 'a blocking layer covers the control');

      // Faded out, the cover is gone: still blocking, it would leave a
      // control that looks live and does nothing.
      await show(tester, layered(blocks: true, opacity: 0, glassOpacity: bound), onEvent: handler, height: 100);
      await tester.tap(find.text('Spot'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(events, hasLength(2));
    });

    testWidgets('a control at opacity 0 is gone; a faded one still works', (tester) async {
      final events = <Map<String, dynamic>>[];
      Future<Map<String, Object>> handler(Map<String, dynamic> event) async {
        events.add(event);
        return {};
      }

      await show(tester, layered(opacity: 0, controlOpacity: bound), onEvent: handler, height: 100);
      await tester.tap(find.text('Spot'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Unseen but clickable would be a trap: the operator clicks the
      // artwork and a hidden button acts.
      expect(events, isEmpty);
      expect(find.bySemanticsLabel('Spot'), findsNothing);

      await show(tester, layered(opacity: 0.5, controlOpacity: bound), onEvent: handler, height: 100);
      expect(tester.widget<Opacity>(find.ancestor(of: find.byType(FilledButton), matching: find.byType(Opacity)).first).opacity, 0.5);
      await tester.tap(find.text('Spot'));
      await tester.pumpAndSettle();
      expect(events, hasLength(1));
    });

    testWidgets('fading a text field does not drop its typing', (tester) async {
      Map<String, dynamic> doc(double opacity) => {
        ...scene(artwork: false, values: {'vis': opacity}),
        'layers': [
          {'id': 'glass', 'x': 0, 'y': 0, 'width': 400, 'height': 100, 'svg': box},
        ],
        'controls': [
          {
            ...callField,
            'x': 0,
            'y': 0,
            'width': 400,
            'height': 100,
            'opacity': {
              'value': 'vis',
              'input': [0, 1],
              'output': [0, 1],
            },
          },
        ],
      };
      await show(tester, doc(1), height: 100);
      await tester.enterText(find.byType(TextField), 'K2H');
      // A wrapper added only below full opacity would remount the field here.
      await show(tester, doc(0.5), height: 100);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'K2H');
    });

    testWidgets('a layer added before a text field does not drop its typing', (tester) async {
      Map<String, dynamic> doc({required bool highlight}) => {
        ...scene(artwork: false),
        'layers': [
          if (highlight) {'id': 'highlight', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'svg': box},
          {'id': 'base', 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'svg': box},
        ],
        'controls': [
          {...callField, 'x': 0, 'y': 0, 'width': 400, 'height': 100, 'after': 'base'},
        ],
      };
      await show(tester, doc(highlight: false), height: 100);
      await tester.enterText(find.byType(TextField), 'K2H');
      // A render that adds a highlight under the field shifts every child
      // after it; matched by position, the field would remount empty.
      await show(tester, doc(highlight: true), height: 100);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'K2H');
    });

    test('`after` names a layer, for a control with a rect', () {
      void refused(Map<String, dynamic> doc, String why) => expect(() => PanelScene(doc), throwsFormatException, reason: why);
      refused({
        ...layered(),
        'controls': [
          {...spotButton, 'x': 0, 'y': 0, 'width': 10, 'height': 10, 'after': 'nope'},
        ],
      }, 'an unknown layer would silently paint the control nowhere');
      refused({
        ...scene(),
        'controls': [
          {...callField, 'after': 'status'},
        ],
        'layout': {
          'column': [
            {'control': 'call'},
            {'scene': true},
          ],
        },
      }, 'a layout-placed control is not over the artwork');
    });
  });

  testWidgets('a scene text field keeps focus; a scene button hands it back to the callsign', (tester) async {
    final call = FocusNode(debugLabel: 'call');
    final backstop = DefaultFocusBackstop(target: () => call, routeIsCurrent: () => true);
    addTearDown(() {
      backstop.dispose();
      call.dispose();
    });
    backstop.attach();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FocusScope(
                  node: backstop.panelScope,
                  child: TextField(focusNode: call, key: const ValueKey('call')),
                ),
                Expanded(
                  child: DockPaneVisibility(
                    visible: true,
                    child: PanelSceneView(
                      scene: PanelScene(scene(artwork: false, controls: [callField, spotButton], layout: column(['call', 'spot']))),
                      onEvent: (_) async => {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final sceneField = find.descendant(of: find.byType(PanelSceneView), matching: find.byType(TextField));
    await tester.tap(sceneField);
    await tester.pump();
    await tester.pump();
    // Reclaimed, the operator's typing would land in the logging panel's
    // callsign instead of the extension's field.
    expect(call.hasFocus, isFalse);
    expect(tester.widget<TextField>(sceneField).focusNode!.hasFocus, isTrue);

    // A button is not a place to type: the focus of its click goes back to
    // the callsign, as it does for every other pane's buttons.
    await tester.tap(find.text('Spot'));
    await tester.pump();
    await tester.pump();
    expect(call.hasFocus, isTrue);
    // Desktop: on mobile the backstop reclaims only for a panel that held
    // focus, which this bare harness never does.
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
