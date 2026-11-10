// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `rotatorMap` control: the host draws the rotator on a map of the
// world and places the scene's decorations on it by bearing and distance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/equipment.dart' show EquipmentStatus;
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_rotator.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_rotator_frame.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

const _uuid = 'rot-1';

class _Source extends ChangeNotifier implements SceneRotatorSource {
  @override
  bool canTurn = false;
  SceneRotatorReading reading = const SceneRotatorReading(name: 'Beam', status: EquipmentStatus.connected, live: true, azimuth: 45);
  final turns = <double>[];

  void set(SceneRotatorReading next) {
    reading = next;
    notifyListeners();
  }

  @override
  String? resolve(String? rotator) => rotator == null || rotator == _uuid ? _uuid : null;
  @override
  SceneRotatorReading read(String uuid) => reading;
  @override
  Listenable get changes => this;
  @override
  bool turn(String uuid, double azimuth) {
    turns.add(azimuth);
    return canTurn;
  }

  @override
  void stop(String uuid) {}
  @override
  void connect(String uuid, {required bool on}) {}
  @override
  GridLocation? get home => null;
  @override
  GridLocation? get call => null;
}

Map<String, dynamic> _doc({Map<String, dynamic> map = const {}, Map<String, dynamic> values = const {}}) => {
  'version': 1,
  'width': 300,
  'height': 20,
  'values': {'heading': 0, 'target': 0, ...values},
  'strings': {'state': ''},
  'layers': [
    {
      'id': 'readout',
      'x': 0,
      'y': 0,
      'width': 300,
      'height': 20,
      'text': {'value': 'heading', 'decimals': 0},
    },
    {
      'id': 'status',
      'x': 0,
      'y': 0,
      'width': 300,
      'height': 20,
      'text': {'value': 'state'},
    },
  ],
  'controls': [
    {
      'id': 'map',
      'kind': 'rotatorMap',
      'label': 'Rotator',
      'event': 'turn',
      'headingDeg': 'heading',
      'targetDeg': 'target',
      'status': 'state',
      'map': {'world': false},
      'hud': false,
      'actions': false,
      ...map,
    },
  ],
  'layout': {
    'column': [
      {'control': 'map', 'flex': 1},
      {'scene': true, 'height': 20},
    ],
    'crossAxisAlignment': 'stretch',
  },
};

SceneRotatorSpec _spec(Map<String, dynamic> map) => PanelScene(_doc(map: map)).controlsById['map']!.rotatorMap!;

Map<String, dynamic> _line(String id, Map<String, dynamic> from, Map<String, dynamic> to) => {
  'id': id,
  'kind': 'line',
  'from': from,
  'to': to,
  'color': '#FFFFFF',
};

Future<void> _show(WidgetTester tester, _Source source, {SceneEventHandler? onEvent, Map<String, dynamic> map = const {}}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 320,
            child: PanelSceneView(
              scene: PanelScene(_doc(map: map)),
              onEvent: onEvent,
              rotator: source,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // The control writes its readings after the frame that read them.
  await tester.pump();
}

void main() {
  group('the document', () {
    test('a bearing is a reading, the call, or degrees, then degrees added; anything else is refused before it is drawn', () {
      final layers = _spec({
        'decorations': [
          {'id': 'beam', 'kind': 'wedge', 'az': 'heading-15deg', 'az2': 'heading+15deg+0.5deg', 'fill': '#40FFFFFF'},
          _line('aim', {'az': 'az:120', 'r': 'center'}, {'az': 120, 'r': 'rim'}),
        ],
      }).layers!;
      expect(layers[0].az!.base, SceneRotatorAngleBase.heading);
      expect(layers[0].az!.offset, -15);
      expect(layers[0].az2!.offset, 15.5);
      expect(layers[1].from!.az!.degrees!.literal, 120);
      for (final bad in ['north', 'heading+15', 'az:', 'heading-x deg']) {
        expect(
          () => _spec({
            'decorations': [
              _line('l', {'az': bad, 'r': 0}, {'az': 0, 'r': 'rim'}),
            ],
          }),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('a distance adds the rim, a share of the way to it, ground distance and pixels', () {
      final r = _spec({
        'decorations': [
          _line('l', {'az': 0, 'r': 'rim-8px'}, {'az': 0, 'r': '50%+1000km+2px'}),
        ],
      }).layers!.single;
      // A rim 100 px away, 0.01 px a km.
      expect(r.from!.r!.resolve(100, 0.01), 92);
      expect(r.to!.r!.resolve(100, 0.01), 50 + 10 + 2);
      expect(
        () => _spec({
          'decorations': [
            _line('l', {'az': 0, 'r': 'far'}, {'az': 0, 'r': 'rim'}),
          ],
        }),
        throwsFormatException,
      );
    });

    // A point naming two places would be drawn at whichever the painter read first.
    test('a point is exactly one of a bearing and distance, a place on Earth, the call, or a place along a line', () {
      for (final bad in <Map<String, dynamic>>[
        {'az': 0, 'r': 10, 'lat': 1, 'lon': 2},
        {'lat': 1},
        {'place': 'call', 'az': 0},
        {'az': 0, 'r': 10, 'along': 0.5},
        {},
      ]) {
        expect(
          () => _spec({
            'decorations': [
              {'id': 'dot', 'kind': 'circle', 'at': bad, 'fill': '#FF0000'},
            ],
          }),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    // A point along a line drawn after it would be placed from where the
    // line was a frame ago, or never.
    test('a point along another layer is along a line drawn before it, the defaults\' heading and target included', () {
      final along = {
        'id': 'tip',
        'kind': 'circle',
        'at': {'on': 'heading', 'along': 0.5},
        'fill': '#FF0000',
      };
      expect(
        _spec({
          'decorations': [
            {'id': 'mine', 'kind': 'defaults'},
            along,
          ],
        }).layers,
        hasLength(2),
      );
      expect(
        () => _spec({
          'decorations': [along],
        }),
        throwsFormatException,
      );
      expect(
        () => _spec({
          'decorations': [
            along,
            {'id': 'mine', 'kind': 'defaults'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('a refused decoration is named by its id', () {
      expect(
        () => _spec({
          'decorations': [
            {
              'id': 'marker',
              'kind': 'circle',
              'at': {'place': 'home'},
              'fill': '#FF0000',
            },
          ],
        }),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', endsWith(': marker'))),
      );
    });

    test('the defaults are drawn once, and nothing beside them takes their ids', () {
      expect(
        () => _spec({
          'decorations': [
            {'id': 'a', 'kind': 'defaults'},
            {'id': 'b', 'kind': 'defaults'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => _spec({
          'decorations': [
            {'id': 'a', 'kind': 'defaults'},
            _line('heading', {'az': 0, 'r': 0}, {'az': 0, 'r': 'rim'}),
          ],
        }),
        throwsFormatException,
      );
    });

    test('a value the control writes must be declared, and a zoom or pan is the host\'s or nobody\'s', () {
      expect(() => _spec({'hoverAz': 'undeclared'}), throwsFormatException);
      expect(
        () => _spec({
          'gestures': {'zoom': 'event'},
        }),
        throwsFormatException,
      );
      expect(
        _spec({
          'gestures': {'turn': 'event'},
        }).turn,
        'event',
      );
    });

    test('stops are bearings from north, whatever turn they are written in', () {
      expect(
        _spec({
          'stops': [45, -45, 405],
        }).stops,
        [45.0, 315.0, 45.0],
      );
    });
  });

  group('the frame', () {
    const size = Size(400, 300);

    test('all the way out the rim is the circle round the whole Earth, and the station cannot be moved off the middle', () {
      final frame = RotatorFrame(size, zoom: 1, pan: const Offset(100, 50));
      expect(frame.station, size.center(Offset.zero));
      for (final bearing in const <double>[0, 45, 90, 135, 200]) {
        expect(frame.rimAt(bearing), closeTo(frame.base, 1), reason: '$bearing');
      }
    });

    // Past 0.95·zoom − 1 base radii the disc's edge — the antipode — would come into view.
    test('zoomed in the station pans, only as far as keeps the far side of the Earth out of view', () {
      final frame = RotatorFrame(size, zoom: 1.5, pan: const Offset(1000, 0), panMargin: 0);
      expect(frame.pan.dx, closeTo(RotatorFrame.zoomPanLimit(1.5) * frame.base, 0.01));
      expect(frame.pan.dy, 0);
    });

    test('zoomed in the rim is a box with rounded corners, reaching further on a diagonal than a circle does', () {
      final frame = RotatorFrame(size, zoom: 10);
      expect(frame.rimAt(0), closeTo(frame.base, 1));
      expect(frame.rimAt(45), greaterThan(frame.base * 1.2));
    });
  });

  group('the control', () {
    testWidgets('a click on the map is the scene\'s turn where the panel cannot turn the rotator, with the bearing clicked', (tester) async {
      final source = _Source();
      final events = <Map<String, dynamic>>[];
      await _show(
        tester,
        source,
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      final box = tester.getRect(find.byType(SceneRotatorView));
      await tester.tapAt(box.center + const Offset(60, 0));
      await tester.pump();
      expect(source.turns, isEmpty);
      expect(events.single['action'], 'turn');
      expect(events.single['phase'], 'commit');
      expect(events.single['value'] as double, closeTo(90, 0.5));
    });

    testWidgets('where it may, the app turns the rotator itself, to the nearest of the scene\'s stops', (tester) async {
      final source = _Source()..canTurn = true;
      final events = <Map<String, dynamic>>[];
      await _show(
        tester,
        source,
        map: const {
          'stops': [45, 135, 225, 315],
        },
        onEvent: (e) async {
          events.add(e);
          return {};
        },
      );
      final box = tester.getRect(find.byType(SceneRotatorView));
      await tester.tapAt(box.center + const Offset(60, 10));
      await tester.pump();
      expect(source.turns, [135.0]);
      expect(events, isEmpty);
    });

    // The scene puts a value it drops and declares again back at its own
    // default; a control that still thought it had written the reading
    // would leave "B 0" showing until the rotator moved.
    testWidgets('a readout the scene drops and brings back is written again', (tester) async {
      final source = _Source();
      Map<String, dynamic> doc({required bool second}) {
        final d = _doc(
          values: {if (second) 'heading2': 0},
          map: {
            if (second)
              'rotators': [
                {'rotator': _uuid, 'headingDeg': 'heading2'},
              ],
          },
        );
        if (second) {
          (d['layers'] as List).add({
            'id': 'second',
            'x': 0,
            'y': 0,
            'width': 300,
            'height': 20,
            'text': {'value': 'heading2', 'prefix': 'B '},
          });
        }
        return d;
      }

      Future<void> show(Map<String, dynamic> d) async {
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 320,
                  child: PanelSceneView(scene: PanelScene(d), rotator: source),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await show(doc(second: true));
      expect(find.text('B 45'), findsOneWidget);
      await show(doc(second: false));
      await show(doc(second: true));
      expect(find.text('B 45'), findsOneWidget);
    });

    // A scene that names its rotator once in `sources`, for its own readouts,
    // names it the same way on the map rather than repeating the id.
    testWidgets("a map's rotator may be the name of a rotator source", (tester) async {
      final source = _Source();
      final doc = _doc(map: {'rotator': 'tower'});
      doc['sources'] = {
        'tower': {'rotator': _uuid},
      };
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 320,
                child: PanelSceneView(scene: PanelScene(doc), rotator: source),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('45'), findsOneWidget);
    });

    // A readout that blanked whenever the connection dropped would hide the
    // one fact the operator still has: where the antenna was left pointing.
    testWidgets('the heading written is the last one the rotator gave, and the status says whether it is current', (tester) async {
      final source = _Source();
      await _show(tester, source);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('connected'), findsOneWidget);
      source.set(const SceneRotatorReading(name: 'Beam', status: EquipmentStatus.connected, live: false, stale: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('45'), findsOneWidget);
      expect(find.text('stale'), findsOneWidget);
    });
  });
}
