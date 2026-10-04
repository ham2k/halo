// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab draws the operation's own reference outlines — a summit's SOTA
// activation zone — alongside its QSOs. The same summit is drawn by the
// Activities pane's map too, and the two must agree: one publishing an outline
// while the other silently doesn't would read as a bug in whichever pane the
// operator looked at second.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/map/ref_shapes.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';
import 'package:ham2k_logger/views/operation/operation_location_pin.dart';

import '../support/map_tile_cache.dart';

const _zone = '''
{"type":"FeatureCollection","features":[
  {"type":"Feature","geometry":{"type":"Polygon","coordinates":
    [[[-74.4,41.9],[-74.3,41.9],[-74.3,41.8],[-74.4,41.9]]]}}]}''';

// `refType` lives on the control's `input`, not at the top level — see
// halo_widgets' controlForRefType. A control shaped otherwise simply never
// matches, and the outline quietly takes the fallback color.
const _summitControl = {
  'key': 'sota/activation',
  'color': '#1B5E20',
  'input': {'refType': 'sotaActivation'},
};

/// Answers from a table rather than the network. Subclasses the real service
/// because that is what the panel holds — a loader taking some narrower
/// interface would be a seam this code doesn't have.
class _FakeGeoshapes extends GeoshapeService {
  _FakeGeoshapes(this.answers, {required super.lookups}) : super(extensions: ExtensionService());

  final Map<String, Geoshape> answers;
  final asked = <String>[];

  /// Each `sourcesForRefs` call, so a test can count crossings.
  final batches = <List<String>>[];

  @override
  Future<List<RefGeojsonAnswer>> sourcesForRefs(List<Map<String, dynamic>> refs) async {
    final keys = [for (final ref in refs) '${ref['ref']}'];
    batches.add(keys);
    asked.addAll(keys);
    return [for (final key in keys) (source: RefGeojson(url: 'https://shapes.test/$key', maxAge: Duration.zero, missMaxAge: Duration.zero), answered: true)];
  }

  @override
  Future<Geoshape> shapeFromSource(RefGeojsonAnswer answer) async => answers[answer.source?.url.substring('https://shapes.test/'.length)] ?? Geoshape.none;
}

Operation _operationWith({String? grid, List<Map<String, dynamic>> refs = const []}) => Operation(uuid: 'op-shapes', data: {'grid': ?grid, 'refs': refs});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  late HaLoDatabase db;
  setUp(() => db = HaLoDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<_FakeGeoshapes> pump(
    WidgetTester tester, {
    required Operation operation,
    required Map<String, Geoshape> answers,
    List<Map<String, dynamic>> controls = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final geoshapes = _FakeGeoshapes(answers, lookups: LookupRepository(db));

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: MapPanel(operation: operation, qsos: const [], settings: settings, geoshapes: geoshapes, activityControls: controls),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return geoshapes;
  }

  testWidgets('the operation\'s summit is outlined, in its activity color', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        // A grid is what puts a marker on the map; with none the panel shows
        // its empty state and never reaches a backend at all.
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            {'type': 'sotaActivation', 'ref': 'W2/GC-099'},
          ],
        ),
        answers: const {'W2/GC-099': Geoshape(_zone, resolved: true)},
        controls: const [_summitControl],
      );
      await tester.pumpAndSettle();

      final shapes = tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes;
      expect(shapes, hasLength(1));
      expect(shapes.single.rings.first, hasLength(4));
      // The color its own row and its Activities-map dot wear — not a wash
      // invented here, or the same summit reads as two different things.
      expect(shapes.single.color, const Color(0xFF1B5E20));
      expect(find.text('Outlines are for reference only. Do your own research!'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a park that is a trail is stroked on the map, not filled', (tester) async {
    const park = '''
{"type":"FeatureCollection","features":[
  {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-74.4,41.9],[-74.3,41.9],[-74.3,41.8],[-74.4,41.9]]]}},
  {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-74.5,41.7],[-74.45,41.75],[-74.4,41.7]]}}]}''';
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            {'type': 'potaActivation', 'ref': 'US-1234'},
          ],
        ),
        answers: const {'US-1234': Geoshape(park, resolved: true)},
      );
      await tester.pumpAndSettle();

      final polygons = tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons;
      expect(polygons, hasLength(1), reason: 'a trail in the fill layer would be closed end to end and paint the land between');
      final strokes = [for (final layer in tester.widgetList<PolylineLayer>(find.byType(PolylineLayer))) ...layer.polylines];
      expect(strokes.where((line) => line.points.length == 3), hasLength(1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('every reference a map draws is asked about in ONE crossing', (tester) async {
    // The map asks for each reference's outline as it builds that reference's
    // marker; asked separately, a multi-reference operation crosses the bridge
    // once per reference on every map it opens.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final geoshapes = await pump(
        tester,
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            {'type': 'sotaActivation', 'ref': 'W2/GC-099'},
            {'type': 'potaActivation', 'ref': 'US-0001'},
            {'type': 'potaActivation', 'ref': 'US-0002'},
          ],
        ),
        answers: const {'W2/GC-099': Geoshape(_zone, resolved: true)},
        controls: const [_summitControl],
      );
      await tester.pumpAndSettle();

      expect(geoshapes.batches, [
        ['W2/GC-099', 'US-0001', 'US-0002'],
      ]);
      expect(tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes, hasLength(1));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a reference whose program publishes no outline draws nothing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            {'type': 'potaActivation', 'ref': 'US-0001'},
          ],
        ),
        answers: const {},
      );
      await tester.pumpAndSettle();

      expect(tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes, isEmpty);
      // The notice is about outlines; with none drawn it would only be noise.
      expect(find.text('Outlines are for reference only. Do your own research!'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a reference with an activation radius is circled around its own coordinate, with no outline credits', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            // Stored the way an added suggestion is: verbatim, radius and all.
            {'type': 'sotaActivation', 'ref': 'W2/GC-099', 'lat': 41.85, 'lon': -74.35, 'activationRadiusInMeters': 1000},
            // A square's centre can sit further from the reference than the
            // whole radius: no circle without a coordinate.
            {'type': 'potaActivation', 'ref': 'US-0001', 'grid': 'FN31', 'activationRadiusInMeters': 1000},
          ],
        ),
        answers: const {},
        controls: const [_summitControl],
      );
      await tester.pumpAndSettle();

      final shapes = tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes;
      expect(shapes, hasLength(1));
      expect(shapes.single.isActivationRadius, isTrue);
      expect(shapes.single.color, const Color(0xFF1B5E20));
      expect(distanceOnEarthKm(const GridLocation(41.85, -74.35), shapes.single.rings.single.first), closeTo(1.0, 0.001));
      // The credits name who drew an outline and offer to report a wrong
      // one; a circle has neither a source nor a document to correct.
      expect(find.text('Outlines are for reference only. Do your own research!'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an operation with nothing to draw asks for no outlines at all', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      // No grid and no QSOs: the panel renders its empty state instead of a
      // map. Asking anyway would spend an activator's data on an outline
      // nothing is going to render.
      final geoshapes = await pump(
        tester,
        operation: _operationWith(
          refs: const [
            {'type': 'sotaActivation', 'ref': 'W2/GC-099'},
          ],
        ),
        answers: const {'W2/GC-099': Geoshape(_zone, resolved: true)},
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsmMapView), findsNothing);
      expect(geoshapes.asked, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('zoomed out past the outline threshold, the Map tab outlines nothing and asks for nothing', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final geoshapes = await pump(
        tester,
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            {'type': 'sotaActivation', 'ref': 'W2/GC-099'},
          ],
        ),
        answers: const {'W2/GC-099': Geoshape(_zone, resolved: true)},
        controls: const [_summitControl],
      );
      OsmMapView map() => tester.widget<OsmMapView>(find.byType(OsmMapView));
      // One operation's worth of markers fits close in, past the threshold.
      expect(map().shapes, hasLength(1));
      expect(map().zoomFades?.solidShapes, (
        from: refOutlinesFromZoom,
        to: refOutlinesOpaqueAtZoom,
      ), reason: 'faded in over the same band as the Activities map');

      // Out past the threshold by the pane's own zoom buttons, which move the
      // real camera: flutter_map re-reports where it actually is.
      final asked = geoshapes.asked.length;
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.bySemanticsLabel('Zoom out'));
        await tester.pumpAndSettle();
      }
      expect(map().shapes, isEmpty);
      expect(geoshapes.asked, hasLength(asked), reason: 'zoomed out, an outline is a fetch for a smudge');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the Map tab marks each reference in its own icon and colour, and the operation\'s location on top', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(
        tester,
        operation: _operationWith(
          grid: 'FN31pr',
          refs: const [
            {'type': 'sotaActivation', 'ref': 'W2/GC-099', 'lat': 41.9, 'lon': -74.3},
          ],
        ),
        answers: const {},
        controls: const [_summitControl],
      );
      final markers = tester.widget<OsmMapView>(find.byType(OsmMapView)).markers;

      final ref = markers.singleWhere((m) => m.id == 'ref-sotaActivation/W2/GC-099');
      // The colour its row wears — found by the ACTIVATION type, which only
      // the operation's own controls declare.
      expect(ref.color, const Color(0xFF1B5E20));
      // Last, so both backends draw it over the references.
      expect(markers.last.id, 'qth-FN31PR');
      expect(markers.last.color, operationLocationPin(_operationWith(grid: 'FN31pr')).color, reason: 'the pin the setup sheet\'s location button wears');
      expect(markers.where((m) => m.id.startsWith('qth-')), hasLength(1), reason: 'the plain QTH circle it replaces is gone');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  /// The Map tab as [pump] builds it, but under the caller's own geoshapes and
  /// settings — so a test can pump it again and have the pane rebuild, as a
  /// logged contact or a keystroke's highlight does.
  Widget panel(Operation operation, _FakeGeoshapes geoshapes, SettingsService settings) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: MapPanel(operation: operation, qsos: const [], settings: settings, geoshapes: geoshapes, activityControls: const [_summitControl]),
      ),
    ),
  );

  final summitOperation = _operationWith(
    grid: 'FN31pr',
    refs: const [
      {'type': 'sotaActivation', 'ref': 'W2/GC-099'},
    ],
  );

  testWidgets('an outline layer survives a camera move and a rebuild as the same layer', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final geoshapes = _FakeGeoshapes(const {'W2/GC-099': Geoshape(_zone, resolved: true)}, lookups: LookupRepository(db));
      await tester.pumpWidget(panel(summitOperation, geoshapes, settings));
      await tester.pumpAndSettle();
      final before = tester.widget<PolygonLayer>(find.byType(PolygonLayer));

      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(panel(summitOperation, geoshapes, settings));
      await tester.pumpAndSettle();
      // A new layer would have flutter_map re-project every point of the
      // outline — on every frame of a drag, or on every rebuild of the pane.
      expect(identical(tester.widget<PolygonLayer>(find.byType(PolygonLayer)), before), isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an outline that cannot be read is not asked for again on the next rebuild', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final geoshapes = _FakeGeoshapes(const {'W2/GC-099': Geoshape('{not json', resolved: true)}, lookups: LookupRepository(db));
      await tester.pumpWidget(panel(summitOperation, geoshapes, settings));
      await tester.pumpAndSettle();
      final asked = geoshapes.asked.length;
      expect(asked, greaterThan(0));

      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(panel(summitOperation, geoshapes, settings));
        await tester.pumpAndSettle();
      }
      expect(geoshapes.asked, hasLength(asked), reason: 'each ask re-downloads the document and re-sends the report');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
