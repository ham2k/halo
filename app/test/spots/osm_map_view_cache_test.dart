// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OSM backend is rebuilt on every emission of the log and every settings
// notification. What this pins is that a rebuild with the same lines hands
// the layer the same Polyline objects — not new ones built from thousands of
// LatLng lists — and that a line that changed, or went, is the only thing
// that moves.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';

import '../support/map_tile_cache.dart';

MapLineData _line(String id, {double lat = 40}) => MapLineData(id: id, points: [GridLocation(lat, -74), GridLocation(41, -73)], color: Colors.black);

MapMarkerData _marker(String id, {String title = 'W1AW'}) => MapMarkerData(
  id: id,
  latitude: 40,
  longitude: -74,
  label: 'W1AW',
  kind: MapMarkerKind.qso,
  color: Colors.red,
  strokeColor: Colors.black,
  popupTitle: title,
);

void main() {
  useTempMapTileCache();

  Widget host(List<MapLineData> lines, List<MapMarkerData> markers) => MaterialApp(
    home: Scaffold(
      body: OsmMapView(markers: markers, lines: lines, isDark: false),
    ),
  );

  List<Polyline> polylines(WidgetTester tester) => tester.widgetList<PolylineLayer>(find.byType(PolylineLayer)).first.polylines.cast<Polyline>();
  List<Marker> markerWidgets(WidgetTester tester) => tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).first.markers;

  testWidgets('a rebuild with equal data reuses the layer objects; a changed or dropped entry is the only difference', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host([_line('a/0'), _line('b/0')], [_marker('q1'), _marker('q2')]));
      await tester.pump();
      final before = polylines(tester);
      final markersBefore = markerWidgets(tester);
      expect(before, hasLength(2));

      // A new list instance with the same contents: every emission looks like this.
      await tester.pumpWidget(host([_line('a/0'), _line('b/0')], [_marker('q1'), _marker('q2')]));
      await tester.pump();
      final same = polylines(tester);
      expect(identical(same[0], before[0]) && identical(same[1], before[1]), isTrue, reason: 'nothing changed: nothing rebuilt');
      final sameMarkers = markerWidgets(tester);
      expect(identical(sameMarkers[0], markersBefore[0]) && identical(sameMarkers[1], markersBefore[1]), isTrue);

      // One line moved, one marker's popup changed, and one of each is gone.
      await tester.pumpWidget(host([_line('a/0', lat: 45)], [_marker('q1', title: 'W1AW • 120 km')]));
      await tester.pump();
      final after = polylines(tester);
      expect(after, hasLength(1));
      expect(identical(after[0], before[0]), isFalse, reason: 'the moved line is rebuilt');
      final markersAfter = markerWidgets(tester);
      expect(markersAfter, hasLength(1));
      expect(identical(markersAfter[0], markersBefore[0]), isFalse, reason: 'the re-worded marker is rebuilt');

      // The dropped entries do not linger in the cache: bringing 'b/0' back builds it anew.
      await tester.pumpWidget(host([_line('a/0', lat: 45), _line('b/0')], [_marker('q1', title: 'W1AW • 120 km')]));
      await tester.pump();
      final restored = polylines(tester);
      expect(identical(restored[1], before[1]), isFalse, reason: 'a pruned entry is not served from the cache');
    });
  });
}
