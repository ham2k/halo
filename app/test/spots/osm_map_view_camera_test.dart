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
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';

import '../support/map_tile_cache.dart';

MapMarkerData _marker(String id, double latitude, double longitude) => MapMarkerData(
  id: id,
  latitude: latitude,
  longitude: longitude,
  label: id,
  kind: MapMarkerKind.qso,
  color: Colors.red,
  strokeColor: Colors.black,
  popupTitle: id,
);

const _tokyo = [GridLocation(35.7, 139.7)];

void main() {
  useTempMapTileCache();

  Widget host(List<MapMarkerData> markers, MapZoomController controller) => MaterialApp(
    home: Scaffold(
      body: OsmMapView(markers: markers, isDark: false, zoomController: controller),
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
    });
  });
}

typedef LatLngish = (double, double);
