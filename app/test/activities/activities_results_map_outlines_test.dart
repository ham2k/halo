// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Outlines on the Activities results map. The operation's own references and
// the one whose card is open are the subject, drawn solid; every other
// suggestion is only context, drawn dashed under them — and only once the map
// is close enough for a footprint to be more than a smudge, since a search
// answers with dozens of references and each outline is a fetch.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/map/ref_shapes.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

import '../support/error_reporting_fakes.dart';
import '../support/map_tile_cache.dart';

const _operationPark = {'type': 'potaActivation', 'ref': 'US-0001', 'lat': 40.0, 'lon': -75.0};
// Several degrees apart, so the map's own fit starts zoomed OUT: a cluster
// tight enough to fit at the cap is already past the threshold, and would have
// every outline fetched before a test moved the camera at all.
const _nearbyA = {'type': 'pota', 'ref': 'US-0002', 'lat': 41.0, 'lon': -76.0};
const _nearbyB = {'type': 'pota', 'ref': 'US-0003', 'lat': 44.0, 'lon': -79.0};

String _square(double lon, double lat) =>
    '{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[$lon,$lat],[${lon + 0.01},$lat],[${lon + 0.01},${lat + 0.01}],[$lon,$lat]]]}}';

/// Every reference has a square; what a test watches is which were asked for.
class _FakeGeoshapes extends GeoshapeService {
  _FakeGeoshapes({required super.lookups}) : super(extensions: ExtensionService());

  final asked = <String>[];

  @override
  Future<List<RefGeojsonAnswer>> sourcesForRefs(List<Map<String, dynamic>> refs) async => [
    for (final ref in refs)
      (
        source: RefGeojson(
          url: 'https://shapes.test/${ref['ref']}',
          maxAge: Duration.zero,
          missMaxAge: Duration.zero,
          sourceName: ref['type'] == 'potaActivation' ? 'OSM' : 'Survey',
        ),
        answered: true,
      ),
  ];

  @override
  Future<Geoshape> shapeFromSource(RefGeojsonAnswer answer) async {
    final ref = answer.source!.url.substring('https://shapes.test/'.length);
    asked.add(ref);
    final at = [_operationPark, _nearbyA, _nearbyB].firstWhere((r) => r['ref'] == ref);
    return Geoshape(_square(at['lon']! as double, at['lat']! as double), resolved: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  late HaLoDatabase db;
  setUp(() => db = HaLoDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  late MapZoomController camera;

  Future<_FakeGeoshapes> pump(WidgetTester tester, {GridLocation? currentLocation, GridLocation? operationLocation, String? operationGrid}) async {
    camera = MapZoomController();
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final geoshapes = _FakeGeoshapes(lookups: LookupRepository(db));
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ActivitiesResultsMap(
              camera: camera,
              suggestions: const [_nearbyA, _nearbyB],
              controls: const [],
              refs: const [_operationPark],
              settings: settings,
              geoshapes: geoshapes,
              onAdd: (_) {},
              currentLocation: currentLocation,
              operationLocation: operationLocation,
              operationGrid: operationGrid,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return geoshapes;
  }

  OsmMapView map(WidgetTester tester) => tester.widget<OsmMapView>(find.byType(OsmMapView));

  /// Moves the real camera to GL [zoom] — flutter_map's own scale is one
  /// above. Not a faked camera report: flutter_map re-reports where it
  /// actually is whenever its markers change (a card opening restyles one),
  /// and would undo a faked zoom mid-test.
  Future<void> zoomTo(WidgetTester tester, double zoom) async {
    camera.moveTo(41, -76, zoom: zoom + 1);
    await tester.pumpAndSettle();
  }

  testWidgets('zoomed out, only the operation\'s own park is outlined — the suggestions cost no fetch', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final geoshapes = await pump(tester);
      expect(geoshapes.asked, ['US-0001'], reason: 'the first fit alone must not cross the threshold, or nothing below proves the gate');
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom - 0.5);

      expect(geoshapes.asked, ['US-0001']);
      expect(map(tester).shapes.map((s) => s.dashed), [false]);
      expect(find.text('Outlines are for reference only. Do your own research!'), findsOneWidget);
      expect(find.text('Source: OSM'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('zoomed in, the other suggestions are outlined dashed, under the solid one', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final geoshapes = await pump(tester);
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom);

      expect(geoshapes.asked, unorderedEquals(['US-0001', 'US-0002', 'US-0003']));
      final shapes = map(tester).shapes;
      // Dashed first: the OSM backend stacks by kind, but list order is what a
      // backend that stacks in order would use, and the operation's own park
      // must stay on top where the two overlap.
      expect(shapes.map((s) => s.dashed), [true, true, false]);
      expect(shapes.last.id, startsWith('ref-potaActivation/US-0001'));
      // Every source on screen, once each, dashed outlines included: they are
      // somebody's data too.
      expect(find.text('Source: OSM, Survey'), findsOneWidget);

      // Back out, and they go again: dashed outlines are for a close look.
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom - 1);
      expect(map(tester).shapes.map((s) => s.dashed), [false]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tapping inside a suggestion\'s dashed outline opens its card', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester);
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom + 1);
      expect(find.text('US-0003'), findsNothing);

      // Inside US-0003's square, well clear of its marker at the corner — the
      // tap reaches the map as a point, as it does from every backend.
      map(tester).onMapTap!(GridLocation(44.005, -78.995));
      await tester.pumpAndSettle();

      expect(map(tester).shapes.singleWhere((s) => s.id.startsWith('ref-pota/US-0003')).dashed, isFalse);
      expect(find.textContaining('US-0003'), findsWidgets, reason: 'the card a marker tap would open');
      // The card sits at the top: the bottom edge carries the outline notice
      // and the map's own credit.
      final card = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RevealCard');
      expect(tester.getRect(card).top, lessThan(tester.getRect(find.byType(OsmMapView)).center.dy));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a second tap inside the outline that is open closes it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester);
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom + 1);

      map(tester).onMapTap!(const GridLocation(44.005, -78.995));
      await tester.pumpAndSettle();
      map(tester).onMapTap!(const GridLocation(44.005, -78.995));
      await tester.pumpAndSettle();

      expect(map(tester).shapes.singleWhere((s) => s.id.startsWith('ref-pota/US-0003')).dashed, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a tap on bare map opens nothing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester);
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom + 1);

      map(tester).onMapTap!(const GridLocation(30, -90));
      await tester.pumpAndSettle();

      expect(map(tester).shapes.where((s) => !s.dashed), hasLength(1), reason: 'only the operation\'s own park stays solid');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('opening a suggestion\'s card turns its outline solid, without fetching it again', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final geoshapes = await pump(tester);
      await zoomTo(tester, ActivitiesResultsMap.suggestionOutlinesFromZoom + 1);
      final before = geoshapes.asked.length;

      map(tester).onMarkerTap!('0');
      await tester.pumpAndSettle();

      final shapes = map(tester).shapes;
      final opened = shapes.singleWhere((s) => s.id.startsWith('ref-pota/US-0002'));
      expect(opened.dashed, isFalse);
      expect(shapes.singleWhere((s) => s.id.startsWith('ref-pota/US-0003')).dashed, isTrue);
      expect(geoshapes.asked, hasLength(before), reason: 'the dashed and solid forms are one reference, one outline');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an outline report carries where the operation is, never the device\'s own fix', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final backend = FakeErrorReportingBackend();
    try {
      await withErrorHooks(backend: backend, () async {
        // The search band's dot is the device's GPS fix; the operation has
        // said nowhere.
        await pump(tester, currentLocation: const GridLocation(12.34567, -65.4321));
        await zoomTo(tester, outlineIssuesFromZoom + 0.5);
        tester.widget<MapOutlinesNotice>(find.byType(MapOutlinesNotice)).onReportIssue!();
        await tester.pumpAndSettle();

        final referenceField = find.descendant(of: find.byType(DropdownMenu<String>), matching: find.byType(TextField));
        await tester.tap(referenceField);
        await tester.pumpAndSettle();
        // The one outline in view at this zoom.
        await tester.tap(find.textContaining('US-0002').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Minor nit'));
        await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == "What's wrong with it?"), 'Off by a road.');
        await tester.pump();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();

        final body = backend.diagnostics.single.$2;
        // Sent, the operator's live position would leave the device on the
        // strength of a map they were looking around.
        expect(body, isNot(contains('12.34567')));
        expect(body, isNot(contains('Operator:')));
      });
    } finally {
      debugDefaultTargetPlatformOverride = null;
      ErrorReportingService.resetForTesting();
    }
  });
}
