// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Panning the Activities results map fills the view the operator took it to.
// The traps: a view filled only around its centre, a card that reports
// distances from the map instead of from the operator, a camera that refits
// to every batch (or to a reference just added) and yanks the map back from
// where it was, and a query per frame of a drag.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_popup.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

const _home = {'type': 'pota', 'ref': 'US-0001', 'lat': 40.0, 'lon': -75.0};
const _far = {'type': 'pota', 'ref': 'US-0002', 'lat': 41.0, 'lon': -76.0};
const _farther = {'type': 'pota', 'ref': 'US-0003', 'lat': 42.0, 'lon': -77.0};
const _operationPark = {'type': 'potaActivation', 'ref': 'US-0009', 'lat': 40.5, 'lon': -75.5};

const MapViewBounds _view = (south: 40.5, west: -76.5, north: 41.5, east: -75.5);

const _potaControl = <String, dynamic>{
  'key': 'pota/activation',
  'label': 'Parks',
  'input': {'kind': 'refList', 'refType': 'potaActivation'},
};

/// Answers a search with [_home], and a pan with what [viewAnswers] holds —
/// recording each pan's view and scope, so a test can see what the pane asked.
class _PanningExtensions extends ExtensionServiceWithFakeHost {
  _PanningExtensions() : super(FakeExtensionHost({}));

  List<Map<String, dynamic>> viewAnswers = const [];
  final pans = <({MapViewBounds view, List<String>? keys})>[];

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const [_potaControl], loadFailed: false);

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
    ({double south, double west, double north, double east})? searchWithin,
  }) async {
    if (searchWithin == null) return (suggestions: const [_home], allSourcesFailed: false);
    pans.add((view: searchWithin, keys: activityKeys));
    return (suggestions: viewAnswers, allSourcesFailed: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  group('suggestActivities within a view', () {
    test('asks for the whole view, centred on it, and measures each result from the operation', () async {
      Map? asked;
      final extensions = ExtensionServiceWithFakeHost(
        FakeExtensionHost({
          'activity:*:suggest': (Object? args) {
            asked = args! as Map;
            return [
              {
                'key': 'pota',
                'ok': true,
                // The extension measures from where it was asked: 0.1 km from
                // the view's centre, which is not where the operator is.
                'value': [
                  {..._far, 'distance': 0.1},
                ],
              },
            ];
          },
        }),
      );

      final result = await extensions.suggestActivities(const {'lat': 40.0, 'lon': -75.0}, searchWithin: _view);

      // Only the centre, an extension would fill a disc and leave the corners.
      expect(asked!['bounds'], {'south': 40.5, 'west': -76.5, 'north': 41.5, 'east': -75.5});
      expect(asked!['location'], {'lat': 41.0, 'lon': -76.0});
      final distance = result.suggestions.single['distance'] as num;
      expect(distance, closeTo(distanceOnEarthKm(const GridLocation(40, -75), const GridLocation(41, -76)), 0.01));
    });

    test('a malformed answer is read around, not cast, so the rest of the view still arrives', () async {
      final extensions = ExtensionServiceWithFakeHost(
        FakeExtensionHost({
          'activity:*:suggest': (Object? args) => [
            {
              'key': 'pota',
              'ok': true,
              'value': [
                {'type': 'pota', 'ref': 'US-0005', 'grid': 42},
                {..._far, 'distance': 0.1},
              ],
            },
          ],
        }),
      );

      final result = await extensions.suggestActivities(const {'lat': 40.0, 'lon': -75.0}, searchWithin: _view);
      expect(result.suggestions.map((s) => s['ref']), containsAll(['US-0005', 'US-0002']));
    });

    test('drops the distance when the operation has no place to measure from', () async {
      final extensions = ExtensionServiceWithFakeHost(
        FakeExtensionHost({
          'activity:*:suggest': (Object? args) => [
            {
              'key': 'pota',
              'ok': true,
              'value': [
                {..._far, 'distance': 0.1},
              ],
            },
          ],
        }),
      );

      final result = await extensions.suggestActivities(const {}, searchWithin: _view);

      // Kept, it would read as the operator's distance from the park.
      expect(result.suggestions.single.containsKey('distance'), isFalse);
    });
  });

  group('the Activities pane', () {
    Future<_PanningExtensions> pumpPane(WidgetTester tester) async {
      final extensions = _PanningExtensions();
      final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: OperationSheet(
                services: services,
                operation: Operation(uuid: 'op-1', data: const {'refs': []}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Show results on a map'));
      await tester.pumpAndSettle();
      return extensions;
    }

    ActivitiesResultsMap resultsMap(WidgetTester tester) => tester.widget<ActivitiesResultsMap>(find.byType(ActivitiesResultsMap));

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    Future<void> pan(WidgetTester tester, MapViewBounds to) async {
      await resultsMap(tester).onExplore!(to);
      await tester.pumpAndSettle();
    }

    testWidgets('panning adds what it finds to the map, once each, and a new search clears it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final extensions = await pumpPane(tester);
        // _home is already a search result; only _far is new.
        extensions.viewAnswers = const [_home, _far];
        await pan(tester, _view);
        expect(resultsMap(tester).exploredSuggestions.map((s) => s['ref']), ['US-0002']);

        extensions.viewAnswers = const [_far, _farther];
        await pan(tester, (south: 41.5, west: -77.5, north: 42.5, east: -76.5));
        expect(resultsMap(tester).exploredSuggestions.map((s) => s['ref']), ['US-0002', 'US-0003']);
        expect(resultsMap(tester).suggestions.map((s) => s['ref']), ['US-0001'], reason: 'the list keeps answering its own search');

        await type(tester, 'pota:');
        expect(resultsMap(tester).exploredSuggestions, isEmpty, reason: 'found for the last search, not this one');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a pan keeps the box\'s scope, and with text in the box asks nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final extensions = await pumpPane(tester);
        await type(tester, 'pota:');
        await pan(tester, _view);
        // The map also fills its own first view; this pan is the one sent.
        expect(extensions.pans.where((p) => p.view == _view).single.keys, ['pota']);

        // A typed search is answered by what it names, not by where the map is.
        await type(tester, 'bear mountain');
        final before = extensions.pans.length;
        await pan(tester, (south: 41.5, west: -77.5, north: 42.5, east: -76.5));
        expect(extensions.pans, hasLength(before));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the camera is keyed to the search: a new one moves it, a pan does not', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final extensions = await pumpPane(tester);
        final first = resultsMap(tester).fitKey;

        extensions.viewAnswers = const [_far];
        await pan(tester, _view);
        expect(resultsMap(tester).fitKey, first, reason: 'what panning found must not refit the map the operator is moving');

        await type(tester, 'pota:');
        expect(resultsMap(tester).fitKey, isNot(first));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('the results map', () {
    late List<MapViewBounds> explored;

    /// What the pane answers each pan with: whether every program answered.
    var answersWhole = true;
    late MapZoomController camera;

    Future<void> pump(
      WidgetTester tester, {
      List<Map<String, dynamic>> exploredSuggestions = const [],
      List<Map<String, dynamic>> refs = const [],
      String? fitKey = 'search-1',
      MapZoomController? withCamera,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      explored = [];
      answersWhole = true;
      camera = withCamera ?? _RecordingCamera();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ActivitiesResultsMap(
                suggestions: const [_home],
                controls: const [],
                refs: refs,
                settings: settings,
                camera: camera,
                onAdd: (_) {},
                exploredSuggestions: exploredSuggestions,
                onExplore: (bounds) async {
                  explored.add(bounds);
                  return answersWhole;
                },
                fitKey: fitKey,
                currentLocation: const GridLocation(40.2, -75.2),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    OsmMapView map(WidgetTester tester) => tester.widget<OsmMapView>(find.byType(OsmMapView));

    /// Through the backend's own callback, as a GL page's 'moveend' or
    /// flutter_map's position report delivers it.
    void settle(WidgetTester tester, MapViewBounds view, double zoom) => map(tester).onCameraChanged!((
      camera: MapCameraPosition(latitude: (view.south + view.north) / 2, longitude: (view.west + view.east) / 2, zoom: zoom),
      bounds: view,
    ));

    MapViewBounds shifted(double degrees) => (south: _view.south, west: _view.west - degrees, north: _view.north, east: _view.east - degrees);

    testWidgets('a pan past the minimum zoom asks for the view, once the camera stays put', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester);
        explored.clear(); // whatever the map's own fit reported
        // A drag: flutter_map reports every frame of it.
        for (var step = 1; step <= 5; step++) {
          settle(tester, shifted(step / 10), ActivitiesResultsMap.exploreFromZoom);
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(explored, isEmpty, reason: 'nothing is asked while the camera is still moving');

        await tester.pump(const Duration(milliseconds: 500));
        expect(explored.single.west, closeTo(-77.0, 0.001));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('below the minimum zoom, or inside a view already asked about, nothing is asked', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester);
        settle(tester, _view, ActivitiesResultsMap.exploreFromZoom);
        await tester.pump(const Duration(milliseconds: 500));
        explored.clear();

        settle(tester, shifted(3), ActivitiesResultsMap.exploreFromZoom - 1);
        await tester.pump(const Duration(milliseconds: 500));
        expect(explored, isEmpty, reason: 'zoomed out, a view is a region');

        // Nudged in, within the view already answered and not a whole level
        // closer: nothing new to find.
        settle(tester, (south: 40.8, west: -76.2, north: 41.2, east: -75.8), ActivitiesResultsMap.exploreFromZoom + 0.5);
        await tester.pump(const Duration(milliseconds: 500));
        expect(explored, isEmpty);

        // Half off it: the other half is unanswered.
        settle(tester, shifted(0.5), ActivitiesResultsMap.exploreFromZoom);
        await tester.pump(const Duration(milliseconds: 500));
        expect(explored, hasLength(1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('every marker carries the search\'s key, and what panning found is never fitted', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, exploredSuggestions: const [_far], refs: const [_operationPark]);

        final markers = map(tester).markers;
        // Keyed, the camera refits for a new search only — not for a reference
        // added from a card, whose suggestion dot turns into its marker.
        expect(markers.map((m) => m.fitKey).toSet(), {'search-1'});
        expect(markers.singleWhere((m) => m.id == '0').fitsCamera, isTrue);
        // Fitted, each batch would snap the map back from where the operator
        // had just dragged it.
        expect(markers.singleWhere((m) => m.id == '1').fitsCamera, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('zoomed out, suggestions are faded out and untappable, but still what a fit frames', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        // The real camera, not a faked report: flutter_map re-reports where it
        // actually is after every rebuild, and would undo a faked one.
        await pump(tester, exploredSuggestions: const [_far], refs: const [_operationPark], withCamera: MapZoomController());
        // flutter_map's own zoom is one above the GL scale.
        camera.moveTo(40.5, -75.5, zoom: ActivitiesResultsMap.suggestionMarkersFromZoom + 1 - 0.5);
        await tester.pumpAndSettle();
        // Still sent: left out, a search answered zoomed out would fit the
        // camera to everything but its own results.
        final dot = map(tester).markers.singleWhere((m) => m.id == '0');
        expect(dot.fadesWithZoom, isTrue);
        expect(dot.fitsCamera, isTrue);
        final opacity = tester
            .widget<Opacity>(find.ancestor(of: find.byWidgetPredicate((w) => w is MapCircleMarker && w.marker.id == '0'), matching: find.byType(Opacity)).first)
            .opacity;
        expect(opacity, 0);

        map(tester).onMarkerTap!('0');
        await tester.pumpAndSettle();
        expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RevealCard'), findsNothing, reason: 'a dot faded to nothing is not there to tap');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('suggestions fade in with the zoom; the operation\'s own, the chosen one and "you are here" never do', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, exploredSuggestions: const [_far], refs: const [_operationPark], withCamera: MapZoomController());
        map(tester).onMarkerTap!('1');
        await tester.pumpAndSettle();

        final byId = {for (final m in map(tester).markers) m.id: m};
        expect(byId['0']!.fadesWithZoom, isTrue);
        expect(byId['1']!.fadesWithZoom, isFalse, reason: 'its card is open; a faded dot would not say which');
        expect(byId['ref-potaActivation/US-0009']!.fadesWithZoom, isFalse);
        expect(byId['current-location']!.fadesWithZoom, isFalse);
        expect(map(tester).zoomFades, ActivitiesResultsMap.zoomFades);

        // Halfway through the band, on flutter_map's own scale (one above GL).
        const f = ActivitiesResultsMap.zoomFades;
        camera.moveTo(40.5, -75.5, zoom: (f.markers!.from + f.markers!.to) / 2 + 1);
        await tester.pumpAndSettle();
        final dot = find.byWidgetPredicate((w) => w is MapCircleMarker && w.marker.id == '0');
        final opacity = tester.widget<Opacity>(find.ancestor(of: dot, matching: find.byType(Opacity)).first).opacity;
        expect(opacity, closeTo(0.5, 0.01));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('zoomed out with no references of its own, the map stays a map', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, withCamera: MapZoomController());
        camera.moveTo(40.5, -75.5, zoom: ActivitiesResultsMap.suggestionMarkersFromZoom - 1);
        await tester.pumpAndSettle();
        // The "nothing found" hint would claim the search found nothing.
        expect(find.byType(OsmMapView), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the chosen marker is black inside a thick ring of its own colour', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, exploredSuggestions: const [_far], refs: const [_operationPark]);
        MapMarkerData marker(String id) => map(tester).markers.singleWhere((m) => m.id == id);
        final before = marker('0');

        map(tester).onMarkerTap!('0');
        await tester.pumpAndSettle();
        final chosen = marker('0');
        expect(chosen.color, Colors.black);
        // The program's colour moves to the ring, so the dot still says whose.
        expect(chosen.strokeColor, before.color);
        expect(chosen.strokeWidth, greaterThan(2));
        expect(marker('1').color, isNot(Colors.black), reason: 'only the chosen one');

        map(tester).onMarkerTap!('0');
        await tester.pumpAndSettle();
        expect(marker('0'), before, reason: 'closing its card puts it back as it was');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a view that came back short is asked about again; one a zoom level closer is too', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester);
        answersWhole = false;
        settle(tester, _view, ActivitiesResultsMap.exploreFromZoom);
        await tester.pump(const Duration(milliseconds: 500));
        settle(tester, _view, ActivitiesResultsMap.exploreFromZoom);
        await tester.pump(const Duration(milliseconds: 500));
        // Remembered as answered, a program that timed out would leave its
        // references out of this view for the rest of the search.
        expect(explored.where((v) => v == _view), hasLength(2));

        answersWhole = true;
        explored.clear();
        settle(tester, _view, ActivitiesResultsMap.exploreFromZoom);
        await tester.pump(const Duration(milliseconds: 500));
        // A corner, a whole level closer: each program answered the wider view
        // with its nearest few hundred, and a dense region's corners were cut.
        settle(tester, (south: 40.5, west: -76.5, north: 41.0, east: -76.0), ActivitiesResultsMap.exploreFromZoom + 1);
        await tester.pump(const Duration(milliseconds: 500));
        expect(explored, hasLength(2));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping "you are here" closes a card and marks nothing chosen', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester);
        final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RevealCard');
        map(tester).onMarkerTap!('0');
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);

        map(tester).onMarkerTap!('current-location');
        await tester.pumpAndSettle();
        expect(card, findsNothing);
        expect(map(tester).markers.singleWhere((m) => m.id == 'current-location').color, isNot(Colors.black));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping what is open closes it, and moves nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, refs: const [_operationPark]);
        final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RevealCard');

        map(tester).onMarkerTap!('0');
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        map(tester).onMarkerTap!('0');
        await tester.pumpAndSettle();
        expect(card, findsNothing);

        map(tester).onMarkerTap!('ref-potaActivation/US-0009');
        await tester.pumpAndSettle();
        final moves = (camera as _RecordingCamera).moves;
        expect(moves, hasLength(1));
        map(tester).onMarkerTap!('ref-potaActivation/US-0009');
        await tester.pumpAndSettle();
        expect(card, findsNothing);
        expect(moves, hasLength(1), reason: 'closing a card is not a request to fly anywhere');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

/// Records what the map asks the camera to do. Overrides `moveTo` rather than
/// assigning `onMoveTo`, which the live backend claims for itself.
class _RecordingCamera extends MapZoomController {
  final moves = <(double, double)>[];

  @override
  void moveTo(double latitude, double longitude, {double zoom = MapZoomController.closeUpZoom}) => moves.add((latitude, longitude));
}
