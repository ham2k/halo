// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pointing the results map at one reference. A row above the map and that
// reference's own dot name the same object, so both move the camera the same
// way — and a SUGGESTION's dot must not, because flying away from the search
// results the operator is comparing answers a question they did not ask.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/map_tile_cache.dart';

const _summitRef = {'type': 'sotaActivation', 'ref': 'W2/GC-099', 'shortLabel': 'SOTA W2/GC-099', 'lat': 41.8867, 'lon': -74.9547};

const _parkSuggestion = {'type': 'pota', 'ref': 'US-0001', 'shortLabel': 'POTA US-0001', 'lat': 40.0, 'lon': -75.0};

Widget _harness(Widget child) => TranslationProvider(
  child: MaterialApp(home: Scaffold(body: child)),
);

/// Records what the pane asks the camera to do.
///
/// Overrides `moveTo` rather than assigning `onMoveTo`: the live backend
/// claims that field for itself when its State mounts, so a recorder written
/// as a handler is silently replaced and the test then passes on an empty
/// list forever. That claim is asserted separately below.
class _RecordingCamera extends MapZoomController {
  final moves = <(double, double, double)>[];

  @override
  void moveTo(double latitude, double longitude, {double zoom = MapZoomController.closeUpZoom}) => moves.add((latitude, longitude, zoom));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  group('refRowMapTarget', () {
    test('points at the reference while the map is showing', () {
      expect(refRowMapTarget(_summitRef, mapShowing: true), const GridLocation(41.8867, -74.9547));
    });

    test('points nowhere while the list is showing', () {
      // There is no camera mounted then, and a row that quietly did nothing
      // in one mode and something in the other reads as broken in whichever
      // the operator meets first.
      expect(refRowMapTarget(_summitRef, mapShowing: false), isNull);
    });

    test('points nowhere for a reference with no location', () {
      // A program whose codes carry no coordinate has no dot on the map
      // either, so there is nothing to center on.
      expect(refRowMapTarget(const {'type': 'x', 'ref': 'Y-1'}, mapShowing: true), isNull);
    });
  });

  testWidgets('tapping a reference dot centers the map on it, close in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final camera = _RecordingCamera();

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _harness(
          ActivitiesResultsMap(
            suggestions: const [_parkSuggestion],
            controls: const [],
            refs: const [_summitRef],
            settings: settings,
            camera: camera,
            onAdd: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Through the backend's own callback rather than a synthetic gesture:
      // the GL backends deliver a marker click as this id and nothing else,
      // so this is the whole of what the pane receives.
      tester.widget<OsmMapView>(find.byType(OsmMapView)).onMarkerTap!(selectedRefMarkerId(_summitRef));

      expect(camera.moves, [(41.8867, -74.9547, MapZoomController.closeUpZoom)]);
      // The backend claimed the camera when it mounted, so a real move
      // reaches a map rather than a controller nothing is listening to.
      expect(camera.onMoveTo, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tapping a suggestion dot leaves the camera alone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final camera = _RecordingCamera();

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        _harness(
          ActivitiesResultsMap(suggestions: const [_parkSuggestion], controls: const [], refs: const [], settings: settings, camera: camera, onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // A suggestion's id is its index into the results, not a `ref-` id —
      // and its card is the one offering Add, which is the whole reason the
      // map must stay put and keep the other candidates in frame.
      tester.widget<OsmMapView>(find.byType(OsmMapView)).onMarkerTap!('0');

      expect(camera.moves, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
