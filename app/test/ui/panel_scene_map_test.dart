// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `map` control: the host draws the world, the scene's markers and
// the great circles between them, and moves the view itself. What reaches
// the extension is a click on a marker or a line (by its id), a click on the
// map (by the place), and where a zoom or a pan settled — a place that is
// off by the projection's inverse sends the operator's click somewhere
// else. Every rule in the document is checked when the scene arrives, so a
// broken one is refused whole rather than drawn with a marker missing.

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerScaleEvent, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/panel_content_budgets.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_map.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_model.dart';
import 'package:ham2k_logger/views/operation/world_map/map_camera.dart';
import 'package:ham2k_logger/views/operation/world_map/map_projection.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_view.dart';

Map<String, dynamic> _doc({Map<String, dynamic> map = const {}, Map<String, dynamic> values = const {}, String kind = 'map'}) => {
  'version': 1,
  'width': 300,
  'height': 20,
  'values': {'zoom': 0, ...values},
  'layers': [],
  'controls': [
    {
      'id': 'map',
      'kind': kind,
      'label': 'Map',
      'event': 'map',
      'map': {'world': false},
      'home': {'lat': 0, 'lon': 0},
      'zoomValue': 'zoom',
      ...map,
    },
  ],
  'layout': {
    'column': [
      {'control': 'map', 'flex': 1},
    ],
    'crossAxisAlignment': 'stretch',
  },
};

SceneMapSpec _spec(Map<String, dynamic> map) => PanelScene(_doc(map: map)).controlsById['map']!.map!;

Future<List<Map<String, dynamic>>> _show(WidgetTester tester, {Map<String, dynamic> map = const {}}) async {
  final events = <Map<String, dynamic>>[];
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: PanelSceneView(
              scene: PanelScene(_doc(map: map)),
              home: const GridLocation(40, -100),
              onEvent: (e) async {
                events.add(e);
                return {};
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return events;
}

void main() {
  group('the document', () {
    test('a marker or line takes its style\'s look, and its own fields over it', () {
      final spec = _spec({
        'styles': {
          'qso': {'fill': '#FF0000', 'color': '#FFFFFF', 'radius': 5},
        },
        'markers': [
          {'id': 'a', 'lat': 10, 'lon': 10, 'style': 'qso', 'fill': '#00FF00'},
        ],
      });
      final look = spec.lookOf(spec.markers.single);
      expect(look.fill, const Color(0xFF00FF00));
      expect(look.color, const Color(0xFFFFFFFF));
      expect(look.radius!.at(3), 5);
    });

    test('a radius by zoom is read between its stops as a straight line and held past either end', () {
      final radius = _spec({
        'markers': [
          {
            'id': 'a',
            'lat': 0,
            'lon': 0,
            'radius': [
              [2, 4],
              [6, 12],
            ],
          },
        ],
      }).markers.single.own.radius!;
      expect(radius.at(0), 4);
      expect(radius.at(4), 8);
      expect(radius.at(6), 12);
      expect(radius.at(9), 12);
    });

    test('a line ends at a marker or a place; anything it cannot draw is refused before it is drawn', () {
      Map<String, dynamic> marker(String id) => {'id': id, 'lat': 1, 'lon': 2};
      expect(
        _spec({
          'markers': [marker('a')],
          'lines': [
            {
              'id': 'l',
              'from': 'a',
              'to': {'lat': 50, 'lon': 10},
            },
          ],
        }).lines.single.to,
        (lat: 50.0, lon: 10.0),
      );
      for (final (why, map) in <(String, Map<String, dynamic>)>[
        (
          'a line to a marker the map does not have',
          {
            'lines': [
              {'id': 'l', 'from': 'a', 'to': 'b'},
            ],
          },
        ),
        (
          'a style the map does not have',
          {
            'markers': [
              {...marker('a'), 'style': 'nope'},
            ],
          },
        ),
        (
          'two items with one id: an event could not say which was clicked',
          {
            'markers': [marker('a')],
            'lines': [
              {'id': 'a', 'from': 'a', 'to': 'a'},
            ],
          },
        ),
        (
          'zoom stops that do not rise',
          {
            'markers': [
              {
                ...marker('a'),
                'radius': [
                  [4, 2],
                  [2, 6],
                ],
              },
            ],
          },
        ),
        (
          'a circle round a marker the map does not have',
          {
            'circles': [
              {'id': 'c', 'at': 'nope', 'km': 1000},
            ],
          },
        ),
        (
          'a circle wider than half the way round the Earth',
          {
            'circles': [
              {
                'id': 'c',
                'at': {'lat': 0, 'lon': 0},
                'km': 20100,
              },
            ],
          },
        ),
        (
          'a circle of no size',
          {
            'circles': [
              {
                'id': 'c',
                'at': {'lat': 0, 'lon': 0},
                'km': 0,
              },
            ],
          },
        ),
        (
          'a circle with a marker\'s id: an event could not say which was clicked',
          {
            'markers': [marker('a')],
            'circles': [
              {'id': 'a', 'at': 'a', 'km': 100},
            ],
          },
        ),
        ('a projection it does not draw', {'projection': 'orthographic'}),
        (
          'a zoom min past its max',
          {
            'zoom': {'min': 6, 'max': 2},
          },
        ),
        (
          'bounds whose south is past their north',
          {
            'pan': {
              'bounds': {'north': 10, 'south': 20, 'west': 0, 'east': 10},
            },
          },
        ),
      ]) {
        expect(() => _spec(map), throwsFormatException, reason: why);
      }
    });

    test('more markers than the budget is refused as a budget, naming the bound', () {
      final markers = [
        for (var i = 0; i <= SceneMapSpec.maxMarkers; i++) {'id': 'm$i', 'lat': 0, 'lon': 0},
      ];
      expect(() => _spec({'markers': markers}), throwsA(isA<PanelContentRefusal>()));
    });

    test('the map\'s own fields belong to it: on another kind they are refused, the ones it shares with the rotator map are not', () {
      expect(() => PanelScene(_doc(kind: 'nativeButton', map: {'markers': [], 'map': null, 'home': null, 'zoomValue': null})), throwsFormatException);
      expect(
        _spec({
          'actions': false,
          'gestures': {'zoom': 'off'},
        }).zoomGesture,
        'off',
      );
    });
  });

  group('the control', () {
    testWidgets('a click on a marker with an event sends it, with the marker\'s id and place', (tester) async {
      final events = await _show(
        tester,
        map: {
          'markers': [
            {'id': 'home', 'lat': 0, 'lon': 0, 'event': 'open'},
          ],
        },
      );
      final box = tester.getRect(find.byType(SceneMapView));
      await tester.tapAt(box.center + const Offset(3, 2));
      await tester.pump();
      expect(events.single['phase'], 'activate');
      expect(events.single['action'], 'open');
      expect(events.single['layer'], 'home');
      expect((events.single['at'] as Map)['lat'], 0);
    });

    testWidgets('a click off every marker that acts is the scene\'s, at the place clicked', (tester) async {
      final events = await _show(
        tester,
        map: {
          'markers': [
            {'id': 'quiet', 'lat': 0, 'lon': 0},
          ],
        },
      );
      final box = tester.getRect(find.byType(SceneMapView));
      // Web Mercator at zoom 0 fits 2π in the pane's 396 drawn pixels, home in the middle: 99 pixels east is 90°.
      await tester.tapAt(box.center + const Offset(99, 0));
      await tester.pump();
      final at = events.single['at'] as Map;
      expect(events.single['phase'], 'commit');
      expect(events.single['layer'], isNull, reason: 'a marker with no event is not a target');
      expect(at['lon'] as double, closeTo(90, 0.5));
      expect(at['lat'] as double, closeTo(0, 0.5));
    });

    testWidgets('a wheel zooms, sends where it settled, and the button takes the view back to the scene\'s', (tester) async {
      final events = await _show(tester);
      final box = tester.getRect(find.byType(SceneMapView));
      tester.binding.handlePointerEvent(PointerScrollEvent(position: box.center, scrollDelta: const Offset(0, -400)));
      await tester.pump(const Duration(milliseconds: 400));
      final zoom = events.firstWhere((e) => e['gesture'] == 'zoom');
      expect(zoom['value'] as double, closeTo(2, 1e-9));
      final pan = events.firstWhere((e) => e['gesture'] == 'pan');
      expect((pan['at'] as Map)['lon'] as double, closeTo(0, 1e-6), reason: 'zoomed about the middle, the middle stays put');
      expect(find.byType(IconButton), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(events.last['gesture'], 'reset');
      expect(find.byType(IconButton), findsNothing);
    });

    // A browser hands a trackpad's pinch over as a scale signal, which the
    // scale gesture never sees: unheard, pinching the map does nothing.
    testWidgets('a pinch the browser sends as a scale zooms by it, about the pointer', (tester) async {
      final events = await _show(tester);
      final box = tester.getRect(find.byType(SceneMapView));
      tester.binding.handlePointerEvent(PointerScaleEvent(position: box.center, scale: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(events.lastWhere((e) => e['gesture'] == 'zoom')['value'] as double, closeTo(2, 1e-9));
    });

    // A panel that keeps the operator's view hands back where a gesture
    // settled as its own `home` and zoom, a render later. Taken as the scene
    // moving the view, that echo lets go of the operator's: a scroll already
    // under way when it lands jumps back to where the last one ended.
    testWidgets('a render that hands back where the view settled leaves the operator\'s view alone', (tester) async {
      final events = <Map<String, dynamic>>[];
      Future<void> show(Map<String, dynamic> map) => tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: PanelSceneView(
                  scene: PanelScene(_doc(map: map)),
                  onEvent: (e) async {
                    events.add(e);
                    return {};
                  },
                ),
              ),
            ),
          ),
        ),
      );
      void wheel(Offset at) => tester.binding.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: const Offset(0, -200)));

      await show({});
      final box = tester.getRect(find.byType(SceneMapView));
      wheel(box.center);
      await tester.pump(const Duration(milliseconds: 400));
      final settled = events.lastWhere((e) => e['gesture'] == 'zoom')['value'] as double;
      expect(settled, closeTo(1, 1e-9));
      wheel(box.center);
      await tester.pump(const Duration(milliseconds: 10));
      await show({
        'zoom': {'initial': settled},
      });
      wheel(box.center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(events.lastWhere((e) => e['gesture'] == 'zoom')['value'] as double, closeTo(3, 1e-9), reason: 'the scroll between the two goes on counting');
    });

    // Without the wrap the whole world at zoom 0 cannot be panned at all,
    // and a Robinson map stops where its curved edge comes into view.
    testWidgets('a drag east-west goes on round the world, past the antimeridian, in every projection but the azimuthal', (tester) async {
      for (final projection in ['mercator', 'equirectangular', 'miller', 'patterson', 'robinson']) {
        final events = await _show(
          tester,
          map: {
            'projection': projection,
            'home': {'lat': 0, 'lon': 150},
          },
        );
        final box = tester.getRect(find.byType(SceneMapView));
        // Three quarters of the world's breadth west, less the touch slop: the view goes some 250° east.
        await tester.dragFrom(box.center, const Offset(-297, 0));
        await tester.pump();
        final pan = events.lastWhere((e) => e['gesture'] == 'pan');
        expect((pan['at'] as Map)['lon'] as double, closeTo(60, 25), reason: projection);
        await tester.pumpWidget(const SizedBox());
      }
    });

    // The floor follows the pane's shape, worked out at layout: a wheel that
    // stops at the scene's own min of 0 leaves sea-less bands above and
    // below a plate carrée world in a square pane.
    testWidgets('a map that covers zooms out no further than fills the pane, and says so', (tester) async {
      final events = await _show(
        tester,
        map: {
          'projection': 'equirectangular',
          'pan': {'cover': true},
          'zoom': {'initial': 3},
        },
      );
      final box = tester.getRect(find.byType(SceneMapView));
      tester.binding.handlePointerEvent(PointerScrollEvent(position: box.center, scrollDelta: const Offset(0, 2000)));
      await tester.pump(const Duration(milliseconds: 400));
      // 396 pixels fit 2π across at zoom 0; the pane's 400 pixels down take π.
      expect(events.lastWhere((e) => e['gesture'] == 'zoom')['value'] as double, closeTo(math.log(800 / 396) / math.ln2, 1e-9));
    });

    // Each copy of the world is cut at the world's edge, which zoomed in lies
    // far outside the pane; without a cut at the pane the map paints over
    // the controls beside it.
    testWidgets('zoomed in, the map paints inside its own box', (tester) async {
      await _show(
        tester,
        map: {
          'zoom': {'initial': 6},
          'markers': [
            {'id': 'a', 'lat': 0, 'lon': 0},
          ],
        },
      );
      final painter = find.descendant(of: find.byType(SceneMapView), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter != null)).first;
      expect(tester.renderObject(painter), paints..clipRect(rect: Offset.zero & tester.getSize(painter)));
    });

    // A panel that keeps the operator's view renders on every pan; with the
    // stress panel's thousand lines, making every great circle again on each
    // render is most of the cost of one, though the lines have not moved.
    testWidgets('a render makes again only the great circles whose ends moved', (tester) async {
      Map<String, dynamic> map(double tokyoLat) => {
        'markers': [
          {'id': 'ny', 'lat': 40.7, 'lon': -74},
          {'id': 'tokyo', 'lat': tokyoLat, 'lon': 139.7},
          {'id': 'rio', 'lat': -22.9, 'lon': -43.2},
        ],
        'lines': [
          {'id': 'a', 'from': 'ny', 'to': 'tokyo'},
          {'id': 'b', 'from': 'ny', 'to': 'rio'},
          {
            'id': 'c',
            'from': 'rio',
            'to': {'lat': 51.5, 'lon': 0},
          },
        ],
      };
      await _show(tester, map: map(35.7));
      final first = mapGreatCirclesMade;
      await _show(
        tester,
        map: {
          ...map(35.7),
          'zoom': {'initial': 2},
        },
      );
      expect(mapGreatCirclesMade, first, reason: 'the same lines in a new scene');
      await _show(tester, map: map(36));
      expect(mapGreatCirclesMade, first + 1, reason: 'Tokyo moved: its line alone');
    });

    /// The place a click in the pane's middle reports, plus [offset].
    Future<(double, double)> placeAt(WidgetTester tester, Future<List<Map<String, dynamic>>> Function() show, [Offset offset = Offset.zero]) async {
      final events = await show();
      await tester.tapAt(tester.getRect(find.byType(SceneMapView)).center + offset);
      await tester.pump();
      final at = events.lastWhere((e) => e['phase'] == 'commit' && e['gesture'] == null)['at'] as Map;
      return (at['lat'] as double, at['lon'] as double);
    }

    // With no `origin`, the azimuthal map's middle is the scene's view. A
    // panel that keeps the operator's view hands back where the pan settled
    // as its `home`; re-centred on that, the map would also keep the pan,
    // and move the view as far again past it.
    testWidgets('a pan handed back as the azimuthal map\'s home leaves the view where it settled', (tester) async {
      final map = {
        'projection': 'azimuthal',
        'home': {'lat': 40, 'lon': -74},
        'zoom': {'initial': 2},
      };
      final events = await _show(tester, map: map);
      await tester.dragFrom(tester.getRect(find.byType(SceneMapView)).center, const Offset(-120, 40));
      await tester.pump();
      final settled = events.lastWhere((e) => e['gesture'] == 'pan')['at'] as Map;
      final (lat, lon) = await placeAt(
        tester,
        () => _show(
          tester,
          map: {
            ...map,
            'home': {'lat': settled['lat'], 'lon': settled['lon']},
          },
        ),
      );
      expect(lat, closeTo(settled['lat'] as double, 0.05));
      expect(lon, closeTo(settled['lon'] as double, 0.05));
    });

    // The operator's view is a point in the projection's own units; kept
    // across a change of projection, it stands for another place.
    testWidgets('a change of projection keeps the place in the view\'s middle', (tester) async {
      Map<String, dynamic> map(String projection) => {
        'projection': projection,
        'home': {'lat': 0, 'lon': 0},
        'zoom': {'initial': 2},
      };
      final events = await _show(tester, map: map('mercator'));
      await tester.dragFrom(tester.getRect(find.byType(SceneMapView)).center, const Offset(-150, 120));
      await tester.pump();
      final settled = events.lastWhere((e) => e['gesture'] == 'pan')['at'] as Map;
      for (final projection in ['equirectangular', 'azimuthal', 'robinson', 'mercator']) {
        final (lat, lon) = await placeAt(tester, () => _show(tester, map: map(projection)));
        expect(lat, closeTo(settled['lat'] as double, 0.1), reason: projection);
        expect(lon, closeTo(settled['lon'] as double, 0.1), reason: projection);
      }
    });

    // A Robinson pan turns the world; turned at the equator's rate, the land
    // under the finger at 60°N slides a fifth of the way back from it.
    testWidgets('a Robinson drag away from the equator keeps the place under the pointer', (tester) async {
      final map = {
        'projection': 'robinson',
        'home': {'lat': 60, 'lon': 0},
        'zoom': {'initial': 2},
      };
      final (_, before) = await placeAt(tester, () => _show(tester, map: map), const Offset(57, 0));
      final center = tester.getRect(find.byType(SceneMapView)).center;
      // The drag starts where the pointer is once it has moved far enough to be one.
      final mouse = await tester.startGesture(center + const Offset(60, 0), kind: PointerDeviceKind.mouse);
      await mouse.moveBy(const Offset(-3, 0));
      await tester.pump();
      for (var i = 0; i < 15; i++) {
        await mouse.moveBy(const Offset(-10, 0));
        await tester.pump();
      }
      await mouse.up();
      await tester.pump();
      final (_, after) = await placeAt(tester, () => _show(tester, map: map), const Offset(-93, 0));
      expect(after, closeTo(before, 0.5));
    });

    // Looking only at the copies of the world whose own breadth is in view,
    // a marker just across the antimeridian, its circle reaching into the
    // pane, is neither drawn nor clickable.
    testWidgets('a marker just past the antimeridian reaches into the pane from the next copy', (tester) async {
      // Zoom 3 puts 8.8 pixels in a degree and 22.7° either side of the middle: the pane's west edge sits half a degree east of the seam.
      final events = await _show(
        tester,
        map: {
          'home': {'lat': 0, 'lon': -180 + 22.7 + 0.5},
          'zoom': {'initial': 3},
          'markers': [
            {'id': 'm', 'lat': 0, 'lon': 179.9, 'radius': 8, 'event': 'open'},
          ],
        },
      );
      final box = tester.getRect(find.byType(SceneMapView));
      await tester.tapAt(Offset(box.left + 1, box.center.dy));
      await tester.pump();
      expect(events.last['layer'], 'm');
    });

    // A circle is the places a distance away on the Earth, the one a
    // contact's distance is measured on; and it takes a click on its edge
    // alone, or a range ring round the station would take every click on
    // the map inside it.
    testWidgets('a circle is drawn the distance away, and a click on its edge is its own', (tester) async {
      // 1,000 km along the equator is 8.993°; zoom 6 puts 70 pixels in a degree, so a sphere a few percent off misses by dozens.
      final events = await _show(
        tester,
        map: {
          'home': {'lat': 0, 'lon': 8.993},
          'zoom': {'initial': 6},
          'markers': [
            {'id': 'here', 'lat': 0, 'lon': 0},
          ],
          'circles': [
            {'id': 'ring', 'at': 'here', 'km': 1000, 'event': 'range'},
          ],
        },
      );
      final box = tester.getRect(find.byType(SceneMapView));
      await tester.tapAt(box.center);
      await tester.pump();
      expect(events.last['layer'], 'ring');
      await tester.tapAt(box.center - const Offset(40, 0));
      await tester.pump();
      expect(events.last['layer'], isNull, reason: 'inside it, the click is the map\'s');
      expect(events.last['phase'], 'commit');
    });

    // Web Mercator draws nothing past 85.05°; dropped there, a station at
    // the South Pole has its line drawn to the edge and no marker to click.
    testWidgets('on Web Mercator, a marker past the cut sits on the edge, where its line ends, and takes a click', (tester) async {
      final events = await _show(
        tester,
        map: {
          'home': {'lat': -84.9, 'lon': 0},
          'zoom': {'initial': 6},
          'markers': [
            {'id': 'pole', 'lat': -89.99, 'lon': 0, 'event': 'open'},
          ],
        },
      );
      const mercator = MercatorProjection(0);
      final box = tester.getRect(find.byType(SceneMapView));
      final camera = MapCamera(box.size, mercator, zoom: 6, center: mercator.toMap(-84.9, 0)!, wraps: true);
      await tester.tapAt(box.topLeft + camera.toScreen(mercator.toMap(-MercatorProjection.cutLatitude, 0)!) - const Offset(0, 2));
      await tester.pump();
      expect(events.last['layer'], 'pole');
    });

    // The wheel's settle comes 300 ms after the last turn; left to fire
    // after the reset, it holds the view the wheel left and sends it, and a
    // panel that keeps the view stores it again.
    testWidgets('the reset button straight after a wheel zoom stays reset', (tester) async {
      final events = await _show(tester);
      final box = tester.getRect(find.byType(SceneMapView));
      tester.binding.handlePointerEvent(PointerScrollEvent(position: box.center, scrollDelta: const Offset(0, -200)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(events.last['gesture'], 'reset');
      expect(find.byType(IconButton), findsNothing);
    });

    // A pan settles without sending a zoom; the last zoom sent, kept, would
    // be taken for an echo when the scene later goes back to it on its own.
    testWidgets('a zoom the scene sets is not taken for an echo of one sent before it moved the zoom itself', (tester) async {
      await _show(tester);
      final box = tester.getRect(find.byType(SceneMapView));
      void wheel() => tester.binding.handlePointerEvent(PointerScrollEvent(position: box.center, scrollDelta: const Offset(0, -200)));
      wheel();
      await tester.pump(const Duration(milliseconds: 400)); // sent: zoom 1
      await _show(
        tester,
        map: {
          'zoom': {'initial': 4},
        },
      );
      await tester.dragFrom(box.center, const Offset(-60, 0));
      await tester.pump();
      final events = await _show(
        tester,
        map: {
          'zoom': {'initial': 1},
        },
      );
      wheel();
      await tester.pump(const Duration(milliseconds: 400));
      expect(events.lastWhere((e) => e['gesture'] == 'zoom')['value'] as double, closeTo(2, 1e-9), reason: 'from the scene\'s 1, not the 4 before it');
    });

    // A marker sized 0 at this zoom is not drawn; still taking clicks, it
    // would answer for empty map, its event sent in place of the map's.
    testWidgets('a marker not drawn at this zoom takes no click', (tester) async {
      final events = await _show(
        tester,
        map: {
          'markers': [
            {
              'id': 'small',
              'lat': 0,
              'lon': 0,
              'event': 'open',
              'radius': [
                [0, 0],
                [4, 5],
              ],
            },
          ],
        },
      );
      await tester.tapAt(tester.getRect(find.byType(SceneMapView)).center);
      await tester.pump();
      expect(events.single['layer'], isNull);
      expect(events.single['phase'], 'commit');
    });

    // The disc fills its box only in part; held to the box, a pan into a
    // corner leaves the view's middle off the Earth, and the place it sends
    // has no latitude for a panel to keep.
    testWidgets('an azimuthal pan into a corner of its box stays on the disc and says where', (tester) async {
      final events = await _show(
        tester,
        map: {
          'projection': 'azimuthal',
          'zoom': {'initial': 3},
        },
      );
      // Zoom 3 puts 1,584 pixels in the disc's radius: 15 steps of 100 take the view into the box's corner.
      final finger = await tester.startGesture(tester.getRect(find.byType(SceneMapView)).center);
      for (var i = 0; i < 15; i++) {
        await finger.moveBy(const Offset(-100, -100));
        await tester.pump();
      }
      await finger.up();
      await tester.pump();
      final at = events.lastWhere((e) => e['gesture'] == 'pan')['at'] as Map;
      expect(at['lat'], isA<double>());
      expect(at['lon'], isA<double>());
    });

    testWidgets('with no home of its own, the map centers on the operation\'s location', (tester) async {
      // Zoomed in: at zoom 0 the whole world fills the pane, and a view as wide as its bounds sits at their middle.
      final events = await _show(
        tester,
        map: {
          'home': null,
          'zoom': {'initial': 3},
        },
      );
      final box = tester.getRect(find.byType(SceneMapView));
      await tester.tapAt(box.center);
      await tester.pump();
      final at = events.single['at'] as Map;
      expect(at['lat'] as double, closeTo(40, 0.5));
      expect(at['lon'] as double, closeTo(-100, 0.5));
    });
  });
}
