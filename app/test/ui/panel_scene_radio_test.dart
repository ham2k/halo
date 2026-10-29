// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `radio` values: the host writes the radio's live readings into
// the scene as they arrive, so a meter moves at the radio's rate without the
// extension rendering — which it could only do once a second.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

class _Radio extends ChangeNotifier implements SceneSpectrumSource {
  Map<String, num> live = {};
  Map<String, String> words = {};
  final named = <String?>[];

  void report(Map<String, num> next, [Map<String, String>? nextWords]) {
    live = next;
    if (nextWords != null) words = nextWords;
    notifyListeners();
  }

  @override
  String? resolve(String? radio) {
    named.add(radio);
    return radio ?? 'radio-1';
  }

  @override
  Map<String, num> readings(String uuid) => live;
  @override
  Map<String, String> readingStrings(String uuid) => words;
  @override
  List<Object?> dialState() => [live['frequencyHz'], words['mode']];
  @override
  Listenable get readingChanges => this;
  @override
  bool recenter(String uuid, int centerHz) => false;
  @override
  void showWidth(String uuid, Object owner, int? widthHz) {}
  @override
  Stream<SpectrumFrame> frames(String uuid) => const Stream.empty();
  @override
  String? problem(String uuid) => null;
  @override
  double? vfoHz(String uuid) => null;
  @override
  Listenable get changes => this;
  @override
  String get noRadio => 'no radio';
  @override
  String get waiting => 'waiting';
}

Map<String, dynamic> _doc({Map<String, dynamic>? radio = const {}, Map<String, double> values = const {}}) => {
  'version': 1,
  'width': 400,
  'height': 40,
  'values': values,
  'radio': ?radio,
  'layers': [
    {
      'id': 'level',
      'x': 0,
      'y': 0,
      'width': 200,
      'height': 20,
      'text': {'value': 'radio.signalDbm', 'suffix': ' dBm'},
    },
    {
      'id': 'fill',
      'x': 0,
      'y': 20,
      'width': 400,
      'height': 20,
      'pivot': [0, .5],
      'scaleX': {
        'value': 'radio.signalDbm',
        'input': [-130, -10],
        'output': [0, 1],
      },
      'svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 20"><rect width="400" height="20"/></svg>',
    },
    {
      'id': 'tx',
      'x': 200,
      'y': 0,
      'width': 200,
      'height': 20,
      'opacity': {
        'value': 'radio.transmitting',
        'input': [0, 1],
        'output': [0, 1],
      },
      'text': {'literal': 'TX'},
    },
  ],
};

Future<void> _show(WidgetTester tester, Map<String, dynamic> doc, SceneSpectrumSource? source, {SceneEventHandler? onEvent}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 40,
            child: DockPaneVisibility(
              visible: true,
              child: PanelSceneView(scene: PanelScene(doc), spectrum: source, onEvent: onEvent),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _fillScale(WidgetTester tester, [String id = 'fill']) {
  final transform = tester.widget<Transform>(find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(Transform)).last);
  return transform.transform.storage[0];
}

double _opacity(WidgetTester tester, String id) =>
    tester.widget<Opacity>(find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(Opacity)).first).opacity;

void main() {
  testWidgets('a reading reaches the scene as it arrives, with no new document', (tester) async {
    final radio = _Radio()..live = {'signalDbm': -70, 'transmitting': 0};
    addTearDown(radio.dispose);
    await _show(tester, _doc(), radio);
    expect(find.text('-70 dBm'), findsOneWidget);
    expect(_fillScale(tester), closeTo(.5, 1e-9));
    expect(_opacity(tester, 'tx'), 0);

    radio.report({'signalDbm': -40, 'transmitting': 1});
    await tester.pump();
    expect(find.text('-40 dBm'), findsOneWidget);
    expect(_fillScale(tester), closeTo(.75, 1e-9));
    expect(_opacity(tester, 'tx'), 1);
  });

  testWidgets('no reading shows as a dash and an empty bar, not as a number nobody measured', (tester) async {
    final radio = _Radio();
    addTearDown(radio.dispose);
    final doc = _doc(radio: {'node': 'rig-b'});
    // Negated, the missing reading's negative infinity would become positive and pin a bar full.
    (doc['layers'] as List).add({
      'id': 'negated',
      'x': 0,
      'y': 20,
      'width': 400,
      'height': 20,
      'pivot': [0, .5],
      'scaleX': {
        'value': 'radio.signalDbm',
        'scale': -1,
        'input': [10, 130],
        'output': [0, 1],
      },
      'svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 20"><rect width="400" height="20"/></svg>',
    });
    await _show(tester, doc, radio);
    expect(find.text('— dBm'), findsOneWidget);
    expect(_fillScale(tester), 0);
    expect(_fillScale(tester, 'negated'), 0);
    expect(radio.named, contains('rig-b'));

    // A panel that may not read the radio gets no source at all: the same
    // dash, never an error.
    await _show(tester, _doc(), null);
    expect(find.text('— dBm'), findsOneWidget);
  });

  testWidgets('just after a transmission the scene reads the radio again on its own, so a hold ends on time', (tester) async {
    // Nothing notifies as time passes: without its own re-read, a hold bound to the seconds since
    // the transmission would stay up until the next meter reading happened to arrive.
    final radio = _Radio()..live = {'secondsSinceTransmit': 1, 'transmitting': 0};
    addTearDown(radio.dispose);
    final doc = _doc();
    (doc['layers'] as List).add({
      'id': 'hold',
      'x': 0,
      'y': 0,
      'width': 100,
      'height': 20,
      'opacity': {
        'value': 'radio.secondsSinceTransmit',
        'input': [3, 3.01],
        'output': [1, 0],
      },
      'text': {'literal': 'SWR'},
    });
    await _show(tester, doc, radio);
    expect(_opacity(tester, 'hold'), 1);
    radio.live = {'secondsSinceTransmit': 4, 'transmitting': 0};
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester, 'hold'), 0);
    // Long after, it stops asking.
    radio.live = {'secondsSinceTransmit': 1e9, 'transmitting': 0};
    await tester.pump(const Duration(milliseconds: 300));
    radio.live = {'secondsSinceTransmit': 1, 'transmitting': 0};
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester, 'hold'), 0);
  });

  testWidgets('a reading not yet taken shows as a dash under every number format, never as a failed build', (tester) async {
    // A missing reading is negative infinity, which floor() and round() throw on: truncating or
    // sampling it would break the whole scene while the radio receives or is disconnected.
    final radio = _Radio();
    addTearDown(radio.dispose);
    final doc = _doc();
    (doc['layers'] as List).addAll(<Map<String, Object>>[
      {
        'id': 'watts',
        'x': 0,
        'y': 0,
        'width': 100,
        'height': 20,
        'text': {'value': 'radio.powerOut', 'truncate': true, 'modulo': 1000, 'suffix': ' W'},
      },
      {
        'id': 'band',
        'x': 100,
        'y': 0,
        'width': 100,
        'height': 20,
        'text': {
          'value': 'radio.swr',
          'samples': ['low', 'high'],
        },
      },
    ]);
    await _show(tester, doc, radio);
    expect(tester.takeException(), isNull);
    expect(find.text('— W'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    radio.report({'powerOut': 87.6, 'swr': 1});
    await tester.pump();
    expect(find.text('87 W'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);
  });

  test('the radio names are the host\'s: unavailable without `radio`, and never declared by the scene', () {
    expect(() => PanelScene(_doc(radio: null)), throwsFormatException);
    expect(() => PanelScene(_doc(values: {'radio.signalDbm': -50})), throwsFormatException);
    expect(PanelScene(_doc()).hasRadio, isTrue);
    expect(sceneRadioValues, contains('radio.transmitting'));
  });

  group('the dial', () {
    Map<String, dynamic> dialDoc({Map<String, dynamic>? radio = const {}, List<Map<String, dynamic>> extra = const []}) => {
      'version': 1,
      'width': 400,
      'height': 40,
      'values': <String, double>{},
      'radio': ?radio,
      'layers': [
        {
          'id': 'khz',
          'x': 0,
          'y': 0,
          'width': 200,
          'height': 20,
          'text': {'value': 'radio.frequencyHz', 'scale': .001, 'truncate': true},
        },
        {
          'id': 'mode',
          'x': 200,
          'y': 0,
          'width': 200,
          'height': 20,
          'text': {'value': 'radio.mode'},
        },
        ...extra,
      ],
    };

    testWidgets('a VFO move reaches the readout with no render: frequency and mode both', (tester) async {
      // A readout that waits for a render trails the dial by up to a second, while the panadapter
      // beside it follows at once.
      final radio = _Radio()
        ..live = {'frequencyHz': 14074000}
        ..words = {'mode': 'USB'};
      addTearDown(radio.dispose);
      await _show(tester, dialDoc(), radio);
      expect(find.text('14074'), findsOneWidget);
      expect(find.text('USB'), findsOneWidget);

      radio.report({'frequencyHz': 7030500}, {'mode': 'CW'});
      await tester.pump();
      expect(find.text('7030'), findsOneWidget);
      expect(find.text('CW'), findsOneWidget);

      // A mode the radio has not given is empty, never the last one it gave.
      radio.report({'frequencyHz': 7030500}, {});
      await tester.pump();
      expect(find.text('CW'), findsNothing);
    });

    testWidgets('`when` shows a layer only for the modes it names, and a hidden control takes no clicks', (tester) async {
      final radio = _Radio()..words = {'mode': 'USB'};
      addTearDown(radio.dispose);
      final events = <Map<String, dynamic>>[];
      final doc = dialDoc(
        extra: [
          {
            'id': 'phone',
            'x': 0,
            'y': 20,
            'width': 100,
            'height': 20,
            'when': {
              'value': 'radio.mode',
              'in': ['USB', 'LSB'],
            },
            'text': {'literal': 'PHONE'},
          },
          {
            'id': 'not-cw',
            'x': 100,
            'y': 20,
            'width': 100,
            'height': 20,
            'when': {'value': 'radio.mode', 'is': 'CW', 'not': true},
            'text': {'literal': 'NOT CW'},
          },
        ],
      );
      doc['controls'] = [
        {
          'id': 'keyer',
          'kind': 'button',
          'label': 'Keyer',
          'event': 'keyer',
          'x': 300,
          'y': 20,
          'width': 100,
          'height': 20,
          'when': {'value': 'radio.mode', 'is': 'CW'},
        },
      ];
      await _show(
        tester,
        doc,
        radio,
        onEvent: (event) async {
          events.add(event);
          return const {};
        },
      );
      expect(_opacity(tester, 'phone'), 1);
      expect(_opacity(tester, 'not-cw'), 1);
      await tester.tapAt(const Offset(350, 30));
      await tester.pump();
      expect(events, isEmpty, reason: 'hidden: a click on where it would be must not act');

      radio.report({}, {'mode': 'CW'});
      await tester.pump();
      expect(_opacity(tester, 'phone'), 0);
      expect(_opacity(tester, 'not-cw'), 0);
      await tester.tapAt(const Offset(350, 30));
      await tester.pump();
      expect(events.map((e) => e['action']), ['keyer']);
    });

    testWidgets('a reading the radio has not given fails every `when`, even a `max` it would sit below', (tester) async {
      // Negative infinity is below any max: without the guard a "low power" badge would show for a
      // radio that has reported no power at all.
      final radio = _Radio();
      addTearDown(radio.dispose);
      final doc = dialDoc(
        extra: [
          {
            'id': 'qrp',
            'x': 0,
            'y': 20,
            'width': 100,
            'height': 20,
            'when': {'value': 'radio.powerWatts', 'max': 10},
            'text': {'literal': 'QRP'},
          },
        ],
      );
      await _show(tester, doc, radio);
      expect(_opacity(tester, 'qrp'), 0);
      radio.report({'powerWatts': 5});
      await tester.pump();
      expect(_opacity(tester, 'qrp'), 1);
      radio.report({'powerWatts': 100});
      await tester.pump();
      expect(_opacity(tester, 'qrp'), 0);
    });

    testWidgets("an event's answer cannot set the dial: only the radio can", (tester) async {
      // Patched, the readout would show a frequency the radio is not on until its next reading.
      final radio = _Radio()
        ..live = {'frequencyHz': 14074000}
        ..words = {'mode': 'USB'};
      addTearDown(radio.dispose);
      final doc = dialDoc();
      doc['controls'] = [
        {'id': 'go', 'kind': 'button', 'label': 'Go', 'event': 'go', 'x': 0, 'y': 20, 'width': 100, 'height': 20},
      ];
      await _show(tester, doc, radio, onEvent: (_) async => {'radio.frequencyHz': 1000.0, 'radio.mode': 'AM'});
      await tester.tapAt(const Offset(50, 30));
      await tester.pump();
      await tester.pump();
      expect(find.text('14074'), findsOneWidget);
      expect(find.text('USB'), findsOneWidget);
    });

    test('`when` is checked against what its value is, and the words are reserved like the numbers', () {
      Map<String, dynamic> withWhen(Map<String, dynamic> when, {Map<String, dynamic>? radio = const {}}) => dialDoc(
        radio: radio,
        extra: [
          {
            'id': 'w',
            'x': 0,
            'y': 0,
            'width': 10,
            'height': 10,
            'when': when,
            'text': {'literal': 'x'},
          },
        ],
      );
      expect(PanelScene(withWhen({'value': 'radio.mode', 'is': 'USB'})).layers.last.when, isNotNull);
      expect(PanelScene(withWhen({'value': 'radio.frequencyHz', 'min': 14e6, 'max': 14.35e6})).layers.last.when, isNotNull);
      // A test of the wrong kind could never pass, hiding its layer for good: refused instead.
      expect(() => PanelScene(withWhen({'value': 'radio.mode', 'min': 1})), throwsFormatException);
      expect(() => PanelScene(withWhen({'value': 'radio.frequencyHz', 'is': 'USB'})), throwsFormatException);
      expect(
        () => PanelScene(
          withWhen({
            'value': 'radio.mode',
            'in': ['USB', 1],
          }),
        ),
        throwsFormatException,
      );
      // One test, and a value that exists.
      expect(() => PanelScene(withWhen({'value': 'radio.mode'})), throwsFormatException);
      expect(() => PanelScene(withWhen({'value': 'radio.mode', 'is': 'USB', 'min': 1})), throwsFormatException);
      expect(() => PanelScene(withWhen({'value': 'nothing', 'is': 1})), throwsFormatException);
      expect(() => PanelScene(withWhen({'value': 'radio.mode', 'is': 'USB'}, radio: null)), throwsFormatException);
      // The host's words are its own.
      expect(
        () => PanelScene({
          ...dialDoc(),
          'strings': {'radio.mode': 'USB'},
        }),
        throwsFormatException,
      );
    });
  });
}
