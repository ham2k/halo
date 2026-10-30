// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OSM backend's half of the camera contract the Map tab's current QSO
// relies on (MapZoomController.fitTo / refit / lastFit): a QSO framed stays
// framed while the log changes around it, a backend made after the request
// frames it too, and a backend that goes away takes its handlers with it —
// the camera's timers fire after a pane's map can be gone.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';

import '../support/map_tile_cache.dart';

MapMarkerData _marker(String id, double latitude, double longitude, {bool highlight = false, double? fitLongitude}) => MapMarkerData(
  id: id,
  latitude: latitude,
  longitude: longitude,
  label: id,
  kind: MapMarkerKind.qso,
  color: Colors.red,
  strokeColor: Colors.black,
  popupTitle: id,
  highlight: highlight,
  fitLongitude: fitLongitude,
);

const _tokyo = [GridLocation(35.7, 139.7)];

void main() {
  useTempMapTileCache();

  Widget host(List<MapMarkerData> markers, MapZoomController controller) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: OsmMapView(markers: markers, isDark: false, zoomController: controller),
      ),
    ),
  );

  LatLngish center(WidgetTester tester) {
    final c = MapCamera.of(tester.element(find.byType(PolylineLayer).first)).center;
    return (c.latitude, c.longitude);
  }

  testWidgets('a framed QSO holds the camera while the log changes, until a refit', (tester) async {
    await tester.runAsync(() async {
      final controller = MapZoomController();
      final log = [_marker('a', 40, -74), _marker('b', 41, -73)];
      await tester.pumpWidget(host(log, controller));
      await tester.pump();
      controller.fitTo(_tokyo);
      await tester.pump();
      final framed = center(tester);
      expect(framed.$1, closeTo(35.7, 0.5), reason: 'the fixture must move the camera, or this test cannot fail');

      // A contact logged elsewhere: the markers' own fit would pull the
      // camera back across the Pacific.
      await tester.pumpWidget(host([...log, _marker('c', 51, 0)], controller));
      await tester.pump();
      expect(center(tester), framed);

      controller.refit();
      await tester.pump();
      expect(center(tester).$1, greaterThan(40), reason: 'the refit frames the log, new contact included');
    });
  });

  testWidgets('a backend made after the request frames it once it is up', (tester) async {
    await tester.runAsync(() async {
      final controller = MapZoomController()..fitTo(_tokyo);
      await tester.pumpWidget(host([_marker('a', 40, -74)], controller));
      // The map reports ready in its first frame and fits its markers after
      // that; the replay lands once that frame is over.
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      expect(center(tester).$1, closeTo(35.7, 0.5));
      expect(center(tester).$2, closeTo(139.7, 0.5));
    });
  });

  // Fiji and Samoa, a few degrees either side of 180°, as the Map pane hands
  // them over from a QTH in New York: the line to Fiji runs west across the
  // antimeridian, so Fiji counts a turn round (fitLongitude). Framed where
  // they are drawn, the camera sits over Africa and the line to Fiji runs
  // off one edge of the world and back in from the other.
  group('contacts whose lines cross the antimeridian frame the Pacific between them', () {
    final pacific = [_marker('fiji', -18, 178, fitLongitude: -182), _marker('samoa', -14, -172)];

    void expectPacific(WidgetTester tester) {
      expect(center(tester).$2.abs(), greaterThan(170));
      expect(MapCamera.of(tester.element(find.byType(PolylineLayer).first)).zoom, greaterThan(3), reason: 'ten degrees apart, not the world apart');
    }

    testWidgets('on a map coming up with them', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(host(pacific, MapZoomController()));
        await tester.pump();
        expectPacific(tester);
      });
    });

    // The QSO being worked is framed by MapZoomController.fitTo, not by the
    // log's fit — counted in, it would stretch the first frame to Europe.
    testWidgets('on a map coming up with the QSO being worked across the world', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(host([...pacific, _marker('current', 51, 0, highlight: true)], MapZoomController()));
        await tester.pump();
        expectPacific(tester);
      });
    });

    testWidgets('logged on a map already up', (tester) async {
      await tester.runAsync(() async {
        final controller = MapZoomController();
        await tester.pumpWidget(host([_marker('a', 40, -74)], controller));
        await tester.pump();
        await tester.pumpWidget(host(pacific, controller));
        await tester.pump();
        expectPacific(tester);
      });
    });
  });

  // With no line across it, the antimeridian stays at the edge of the frame,
  // as it always has: nothing is cut there.
  testWidgets('contacts either side of the antimeridian with no line across it frame as drawn', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host([_marker('fiji', -18, 178), _marker('samoa', -14, -172)], MapZoomController()));
      await tester.pump();
      expect(center(tester).$2.abs(), lessThan(10));
    });
  });

  // Nothing to fit is an empty log, or one with only the QSO being worked,
  // which the log's fit leaves to MapZoomController.fitTo. flutter_map fits
  // no points to a camera centred on NaN, and throws; and with no starting
  // camera of its own it opens on flutter_map's default, a city at street
  // level, rather than the world the GL map opens on.
  for (final (name, markers) in [
    ('an empty log', <MapMarkerData>[]),
    ('only the QSO being worked', [_marker('current', 51, 0, highlight: true)]),
  ]) {
    testWidgets('a map coming up with $name opens on the whole world', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(host(markers, MapZoomController()));
        await tester.pump();
        expect(center(tester), (0.0, 0.0));
        expect(MapCamera.of(tester.element(find.byType(PolylineLayer).first)).zoom, 2);
      });
    });
  }

  testWidgets('a backend that goes away takes its handlers with it', (tester) async {
    await tester.runAsync(() async {
      final controller = MapZoomController();
      await tester.pumpWidget(host([_marker('a', 40, -74)], controller));
      await tester.pump();
      expect(controller.onFitTo, isNotNull);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      expect(controller.onFitTo, isNull, reason: 'a timer would frame a disposed map');
      expect(controller.onRefit, isNull);
      expect(controller.onMoveTo, isNull);
      expect(controller.onZoomIn, isNull);
      expect(controller.onCamera, isNull);
      expect(controller.onResetNorth, isNull);
    });
  });

  group('the compass', () {
    MapController mapOf(WidgetTester tester) => MapController.of(tester.element(find.byType(PolylineLayer).first));

    testWidgets('a turn of the map is a turn of the compass, and resetNorth turns it back', (tester) async {
      await tester.runAsync(() async {
        final controller = MapZoomController();
        await tester.pumpWidget(host([_marker('a', 40, -74)], controller));
        await tester.pump();
        expect(controller.turned.value, isFalse);

        // flutter_map turns the map clockwise, which puts west at the top: a
        // sign slip would point the needle the wrong way round.
        mapOf(tester).rotate(90);
        await tester.pump();
        expect(controller.turned.value, isTrue);
        expect(controller.orientation.value.bearing, -90);

        controller.resetNorth();
        await tester.pump();
        expect(mapOf(tester).camera.rotation, 0);
        expect(controller.turned.value, isFalse, reason: 'the compass would stay up over a map already facing north');
      });
    });

    testWidgets('a map coming up says it faces north, whatever the one before it was left facing', (tester) async {
      await tester.runAsync(() async {
        final controller = MapZoomController()..reportOrientation(const MapOrientation(bearing: 45, pitch: 30));
        await tester.pumpWidget(host([_marker('a', 40, -74)], controller));
        await tester.pump();
        expect(controller.turned.value, isFalse, reason: 'a stale compass would stay up over a map facing north');
      });
    });
  });
}

typedef LatLngish = (double, double);
