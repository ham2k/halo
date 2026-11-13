// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's named sources (several radios, rotators and antenna switches fed
// live by the host), the reveal binding, and a binding's peak hold.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_spectrum.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

/// Two radios, a rotator and a switch, each by its own id.
class _Station extends ChangeNotifier implements SceneSpectrumSource {
  final radios = <String, Map<String, num>>{'rig-a': {}, 'rig-b': {}};
  final radioWords = <String, Map<String, String>>{'rig-a': {}, 'rig-b': {}};
  final devices = <String, ({Map<String, num> numbers, Map<String, String> words})>{};
  final kinds = {'rot-1': 'rotator', 'sw-1': 'antennaSwitch'};
  final named = <String?>[];

  void report() => notifyListeners();

  @override
  String? resolve(String? radio) {
    named.add(radio);
    final id = radio ?? 'rig-a';
    return radios.containsKey(id) ? id : null;
  }

  @override
  Map<String, num> readings(String uuid) => radios[uuid] ?? const {};
  @override
  Map<String, String> readingStrings(String uuid) => radioWords[uuid] ?? const {};
  @override
  Listenable get readingChanges => this;
  @override
  ({Map<String, num> numbers, Map<String, String> words}) equipment(String id, String kind) =>
      kinds[id] == kind ? devices[id] ?? (numbers: const {}, words: const {}) : (numbers: const {}, words: const {});
  @override
  Listenable get equipmentChanges => this;
  @override
  bool nativeGestures = true;
  @override
  int? maxWidthHz(String uuid) => null;
  @override
  int? minWidthHz(String uuid) => null;
  @override
  bool canTune(String uuid) => false;
  @override
  bool tune(String uuid, double hz, {bool dial = false, void Function()? refused}) => false;
  @override
  bool fitSpan(String uuid, int widthHz, {int? centerHz, int offCenterHz = 0}) => false;
  @override
  List<Object?> dialState() => const [];
  @override
  bool canRecenter(String uuid) => false;
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

Map<String, dynamic> text(String id, String value, {double y = 0}) => {
  'id': id,
  'x': 0,
  'y': y,
  'width': 400,
  'height': 20,
  'text': {'value': value},
};

const _sources = {
  'main': {'radio': 'rig-a'},
  'sub': {'radio': 'rig-b'},
  'rot': {'rotator': 'rot-1'},
  'ant': {'antennaSwitch': 'sw-1'},
};

Map<String, dynamic> scene({
  List<Map<String, dynamic>> layers = const [],
  List<Map<String, dynamic>> controls = const [],
  Map<String, Object?> sources = _sources,
  Map<String, double> values = const {},
  Map<String, dynamic>? layout,
}) => {'version': 1, 'width': 400, 'height': 200, 'values': values, 'sources': sources, 'layers': layers, 'controls': controls, 'layout': ?layout};

Future<void> show(WidgetTester tester, Map<String, dynamic> doc, SceneSpectrumSource station, {SceneEventHandler? onEvent}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 200,
              child: DockPaneVisibility(
                visible: true,
                child: PanelSceneView(scene: PanelScene(doc), spectrum: station, onEvent: onEvent),
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
  group('the model', () {
    void refused(Map<String, dynamic> doc, String why) => expect(() => PanelScene(doc), throwsA(isA<FormatException>()), reason: why);

    test('refuses a source it could not feed', () {
      refused(
        scene(
          sources: {
            'radio': {'radio': 'rig-a'},
          },
        ),
        "`radio` is the scene's own unnamed source",
      );
      refused(
        scene(
          sources: {
            '1st': {'radio': 'rig-a'},
          },
        ),
        'a name a value could not be written under',
      );
      refused(
        scene(
          sources: {
            'x': {'rotator': 'r', 'radio': 'a'},
          },
        ),
        'a source is one kind',
      );
      refused(
        scene(
          sources: {
            'x': {'rotator': null},
          },
        ),
        'only a radio may be the designated one',
      );
      refused(
        scene(
          sources: {
            for (var i = 0; i < 17; i++) 's$i': {'radio': 'rig-a'},
          },
        ),
        'at most 16',
      );
    });

    test('refuses a hold or a reveal it could not draw truthfully', () {
      Map<String, dynamic> layer(Map<String, dynamic> extra, {bool blocks = false}) => {
        'id': 'l',
        'x': 0,
        'y': 0,
        'width': 10,
        'height': 10,
        'blocksPointer': ?(blocks ? true : null),
        ...extra,
        'svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"/>',
      };
      Map<String, dynamic> held(Map<String, dynamic> binding) => {
        'value': 'main.signalDbm',
        'input': [-130, -10],
        'output': [0, 1],
        ...binding,
      };
      // Each with a fall rate of its own, so the scale is what refuses it, not a default rate it bends.
      for (final scale in [-1, 0]) {
        refused(
          scene(
            layers: [
              layer({
                'scaleX': held({
                  'scale': scale,
                  'hold': {'ms': 500, 'fallPerSecond': 50},
                }),
              }),
            ],
          ),
          'under a scale of $scale the peak is not the top of the ramp',
        );
      }
      refused(
        scene(
          layers: [
            layer({
              'scaleX': held({
                'modulo': 10,
                'hold': {'ms': 500},
              }),
            }),
          ],
        ),
        'under a modulo the peak wraps',
      );
      refused(
        scene(
          layers: [
            layer({
              'scaleX': held({
                'hold': {'ms': 500, 'fallPerSecond': 0.1},
              }),
            }),
          ],
        ),
        'a fall over 120 dB at 0.1 dB a second would keep a ticker running for 20 minutes',
      );
      expect(
        () => PanelScene(
          scene(
            layers: [
              layer({
                'scaleX': held({
                  'hold': {'ms': 500, 'fallPerSecond': 1},
                }),
              }),
            ],
          ),
        ),
        returnsNormally,
        reason: 'a slow meter, a dB a second, is a meter',
      );
      refused(
        scene(
          layers: [
            layer({
              'clipX': held({
                'output': [0, 100],
              }),
            }),
          ],
        ),
        'a reveal is a share, not a percentage',
      );
      refused(
        scene(
          layers: [
            layer({'clipX': held({})}, blocks: true),
          ],
        ),
        'a blocking layer would take clicks where nothing is drawn',
      );
      refused(
        scene(
          layers: [
            layer({
              'opacity': held({
                'hold': {'ms': 500},
              }),
            }, blocks: true),
          ],
        ),
        '...or after it has gone',
      );
      refused(
        scene(
          controls: [
            {'id': 'scope', 'kind': 'bandScope', 'label': 'Scope', 'radio': 'rot'},
          ],
          layout: {'control': 'scope'},
        ),
        'a band scope cannot show a rotator',
      );
    });

    test("refuses a scene value under a source's name, which the host writes", () {
      refused(scene(values: {'main.signalDbm': 0}), 'a scene of its own would be overwritten by every reading');
    });

    test('takes only the names a source gives', () {
      refused(scene(layers: [text('t', 'rot.speed')]), 'a rotator gives no speed');
      refused(scene(layers: [text('t', 'main.altitude')]), 'a radio gives no altitude');
      expect(
        () => PanelScene(scene(layers: [text('t', 'ant.B.antennaName'), text('u', 'ant.2.auto', y: 20)])),
        returnsNormally,
        reason: 'any port: switches name their own',
      );
    });

    test('refuses a held peak on a control, which would stay clickable while it lingers', () {
      refused(
        scene(
          controls: [
            {
              'id': 'go',
              'kind': 'button',
              'label': 'Go',
              'event': 'go',
              'x': 0,
              'y': 0,
              'width': 10,
              'height': 10,
              'opacity': {
                'value': 'main.signalDbm',
                'input': [-130, -10],
                'output': [0, 1],
                'hold': {'ms': 500},
              },
            },
          ],
        ),
        'hold',
      );
    });
  });

  group('named sources', () {
    testWidgets('feed two radios into one scene, each under its own name, with no render', (tester) async {
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -73};
      station.radios['rig-b'] = {'signalDbm': -101};
      station.radioWords['rig-b'] = {'mode': 'CW'};
      await show(tester, scene(layers: [text('a', 'main.signalDbm'), text('b', 'sub.signalDbm', y: 20), text('m', 'sub.mode', y: 40)]), station);
      expect(find.text('-73'), findsOneWidget);
      expect(find.text('-101'), findsOneWidget);
      expect(find.text('CW'), findsOneWidget);
      station.radios['rig-a'] = {'signalDbm': -60};
      station.report();
      await tester.pump();
      expect(find.text('-60'), findsOneWidget, reason: 'the reading arrives without the extension rendering');
    });

    testWidgets("follow a rotator as it turns, and a switch's ports by their own keys", (tester) async {
      final station = _Station();
      station.devices['rot-1'] = (numbers: {'azimuth': 120, 'moving': 1}, words: const {});
      station.devices['sw-1'] = (numbers: {'B.auto': 0}, words: {'B.antennaName': 'Yagi'});
      await show(
        tester,
        scene(layers: [text('az', 'rot.azimuth'), text('ant', 'ant.B.antennaName', y: 20), text('none', 'ant.C.antennaName', y: 40)]),
        station,
      );
      expect(find.text('120'), findsOneWidget);
      expect(find.text('Yagi'), findsOneWidget);
      station.devices['rot-1'] = (numbers: {'azimuth': 135, 'moving': 1}, words: const {});
      station.report();
      await tester.pump();
      expect(find.text('135'), findsOneWidget);
    });

    testWidgets("read as missing where the source names a device of another kind", (tester) async {
      final station = _Station();
      station.devices['sw-1'] = (numbers: {'connected': 1}, words: const {});
      await show(
        tester,
        scene(
          sources: {
            'rot': {'rotator': 'sw-1'},
          },
          layers: [text('c', 'rot.connected')],
        ),
        station,
      );
      expect(find.text('—'), findsOneWidget, reason: 'not a connected rotator that never turns');
    });

    testWidgets('re-read a transmission fade on time, though another source is missing', (tester) async {
      // Missing reads as negative infinity; taken as the soonest of the radios' "seconds since",
      // it would stop the re-read for the live radio too, and its fade would wait for the next report.
      final station = _Station();
      station.radios['rig-a'] = {'secondsSinceTransmit': 2};
      await show(
        tester,
        scene(
          sources: {
            'main': {'radio': 'rig-a'},
            'gone': {'radio': 'rig-z'},
          },
          layers: [text('a', 'main.secondsSinceTransmit'), text('b', 'gone.secondsSinceTransmit', y: 20)],
        ),
        station,
      );
      expect(find.text('2'), findsOneWidget);
      station.radios['rig-a'] = {'secondsSinceTransmit': 3};
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('3'), findsOneWidget, reason: 'read again with no report');
    });

    testWidgets('read as missing where the device is not there', (tester) async {
      final station = _Station();
      await show(
        tester,
        scene(
          sources: {
            'gone': {'radio': 'rig-z'},
          },
          layers: [text('a', 'gone.signalDbm')],
        ),
        station,
      );
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets("are the host's: an extension's patch cannot claim a reading", (tester) async {
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -73};
      final doc = scene(
        values: {'v': 0},
        layers: [text('a', 'main.signalDbm')],
        controls: [
          {'id': 'go', 'kind': 'button', 'label': 'Go', 'event': 'go', 'x': 0, 'y': 100, 'width': 100, 'height': 50},
        ],
      );
      await show(tester, doc, station, onEvent: (_) async => {'main.signalDbm': -1.0, 'v': 1.0});
      await tester.tap(find.bySemanticsLabel('Go'));
      await tester.pump();
      await tester.pump();
      expect(find.text('-73'), findsOneWidget);
    });

    testWidgets('can be named by a band scope as its radio', (tester) async {
      final station = _Station();
      final doc = scene(
        controls: [
          {'id': 'scope', 'kind': 'bandScope', 'label': 'Scope', 'radio': 'sub'},
        ],
        layout: {
          'column': [
            {'control': 'scope', 'flex': 1},
          ],
        },
      );
      await show(tester, doc, station);
      expect(station.named, contains('rig-b'), reason: "the source's radio, not a node called `sub`");
      expect(station.named, isNot(contains('sub')));
    });
  });

  group('a layer', () {
    Map<String, dynamic> bar(Map<String, dynamic> binding, {List<double> pivot = const [0, 0.5]}) => {
      'id': 'bar',
      'x': 0,
      'y': 0,
      'width': 400,
      'height': 20,
      'pivot': pivot,
      ...binding,
      'svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
    };
    Rect shown(WidgetTester tester) {
      final clip = tester.renderObject<RenderClipRect>(find.descendant(of: find.byKey(const ValueKey('bar')), matching: find.byType(ClipRect)).first);
      return clip.clipper!.getClip(clip.size);
    }

    testWidgets('reveals a share of its artwork from its pivot, keeping its shape, where a scale would squash it', (tester) async {
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -70};
      final reveal = {
        'clipX': {
          'value': 'main.signalDbm',
          'input': [-130, -10],
          'output': [0, 1],
        },
      };
      await show(tester, scene(layers: [bar(reveal)]), station);
      expect(shown(tester), const Rect.fromLTWH(0, 0, 200, 20), reason: 'half the range shows the left half');
      await show(
        tester,
        scene(
          layers: [
            bar(reveal, pivot: [1, 0.5]),
          ],
        ),
        station,
      );
      expect(shown(tester), const Rect.fromLTWH(200, 0, 200, 20), reason: 'pivoted right, the right half');
    });

    testWidgets('steps a whole segment at a time from its own bottom, with an offset', (tester) async {
      // Without the offset, -130 dBm in 10-dB segments counts its steps from zero and lights
      // part of a segment: floor(-7.3) is -8, two thirds of a segment off where it should be.
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -73};
      await show(
        tester,
        scene(
          layers: [
            bar({
              'clipX': {
                'value': 'main.signalDbm',
                'offset': 130,
                'scale': 0.1,
                'truncate': true,
                'input': [0, 12],
                'output': [0, 1],
              },
            }),
          ],
        ),
        station,
      );
      expect(shown(tester).width, closeTo(400 * 5 / 12, 0.01), reason: '57 dB above the bottom: five whole 10-dB segments');
    });

    Map<String, dynamic> held() => bar({
      'translateX': {
        'value': 'main.signalDbm',
        'input': [-130, -10],
        'output': [0, 120],
        'hold': {'ms': 1000, 'fallPerSecond': 60},
      },
    });
    double x(WidgetTester tester) => tester.getTopLeft(find.descendant(of: find.byKey(const ValueKey('bar')), matching: find.byType(RepaintBoundary)).first).dx;

    testWidgets('holds its peak, then lets it fall at its rate until it meets the reading, and stops', (tester) async {
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -20};
      await show(tester, scene(layers: [held()]), station);
      expect(x(tester), closeTo(110, 0.5));
      station.radios['rig-a'] = {'signalDbm': -80};
      station.report();
      await tester.pump();
      expect(x(tester), closeTo(110, 0.5), reason: 'the peak stands');
      await tester.pump(const Duration(milliseconds: 900));
      expect(x(tester), closeTo(110, 0.5), reason: 'still within the hold');
      await tester.pump(const Duration(milliseconds: 600));
      expect(x(tester), closeTo(80, 2), reason: 'half a second into the fall: 30 dB down from -20');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(x(tester), closeTo(50, 0.5), reason: 'it meets the reading and goes no lower');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing left to animate: no ticker runs on');
    });

    testWidgets('holds a reading above its range at the top, so the fall starts where the layer is drawn', (tester) async {
      // Held from +100 on a ramp topped at -10, the peak would fall for two seconds with nothing
      // on screen moving before it came back into the range.
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': 100};
      await show(tester, scene(layers: [held()]), station);
      station.radios['rig-a'] = {'signalDbm': -80};
      station.report();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(x(tester), closeTo(90, 2), reason: 'half a second into the fall: 30 dB down from the top, -10');
    });

    testWidgets('lets go of a held peak when the binding moves to another reading', (tester) async {
      // Kept, the old reading's peak would stand on the new reading's ramp, and fall from there.
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -20};
      station.radios['rig-b'] = {'signalDbm': -80};
      await show(tester, scene(layers: [held()]), station);
      expect(x(tester), closeTo(110, 0.5));
      final rebound = held();
      (rebound['translateX'] as Map)['value'] = 'sub.signalDbm';
      await show(tester, scene(layers: [rebound]), station);
      expect(x(tester), closeTo(50, 0.5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('lets go of a held peak when only its offset moves the ramp', (tester) async {
      // A meter's range edited by its offset alone is another ramp: the old peak, on it, reads wrong.
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -20};
      await show(tester, scene(layers: [held()]), station);
      final shifted = held();
      (shifted['translateX'] as Map)['offset'] = 10;
      station.radios['rig-a'] = {'signalDbm': -80};
      await show(tester, scene(layers: [shifted]), station);
      expect(x(tester), closeTo(60, 0.5), reason: '-80 + 10 is -70 on the ramp, not the old peak');
    });

    testWidgets('a steady reading never holds, and a missing one lets the peak fall to the bottom and stop', (tester) async {
      final station = _Station();
      station.radios['rig-a'] = {'signalDbm': -40};
      await show(tester, scene(layers: [held()]), station);
      station.report();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'at its peak, nothing is held');
      station.radios['rig-a'] = {};
      station.report();
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(x(tester), closeTo(0, 0.5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
