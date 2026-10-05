// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A POTA suggestion's dashed outline on the Activities results map comes from
// the outline bundles for the cells in view, not from the park's whole
// outline — a long trail's runs to megabytes. The bundle's areas are clipped
// to their cell, so their sides along a cell's edge are seams: only its lines
// are drawn, while a tap inside an area still finds the park.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/extensions/extension_ref_results.dart';
import 'package:ham2k_logger/services/outline_grid_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

import '../support/halo_test_support.dart';
import '../support/no_outline_grid.dart';

// Its point in a corner, out of reach of the tap below, so only its area
// can answer it.
const _park = {'type': 'potaActivation', 'ref': 'US-0001', 'shortLabel': 'POTA US-0001', 'lat': 0.095, 'lon': 0.005};

const _summit = {'type': 'sotaActivation', 'ref': 'W2/GC-001', 'shortLabel': 'SOTA W2/GC-001', 'lat': 0.02, 'lon': 0.02};

final _bundle = jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {'reference': 'US-0001', 'kind': 'area'},
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [0.0, 0.0],
            [0.1, 0.0],
            [0.1, 0.1],
            [0.0, 0.1],
            [0.0, 0.0],
          ],
        ],
      },
    },
    {
      'type': 'Feature',
      'properties': {'reference': 'US-0001', 'kind': 'edge'},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [0.0, 0.0],
          [0.0, 0.1],
        ],
      },
    },
  ],
});

class _Grid extends NoOutlineGrid {
  _Grid({this.bundle, this.settled = true, this.squaresKept = true});

  /// The bundle every cell answers with — null for one with no parks.
  final String? bundle;
  final bool settled;

  /// False, as offline at a park planned at home: the blocks are on the
  /// device, the detailed squares are not.
  final bool squaresKept;
  final cellsRead = <List<String>>[];

  @override
  Future<({Map<String, OutlinePieces> parks, bool settled})> piecesIn(List<String> cells) async {
    cellsRead.add(cells);
    final bundle = this.bundle;
    if (!squaresKept && !cells.first.contains('-')) return (parks: <String, OutlinePieces>{}, settled: false);
    return (parks: bundle == null ? <String, OutlinePieces>{} : OutlineGridService.parseBundle(bundle, cell: cells.first, url: 'bundle'), settled: settled);
  }
}

/// A park's whole outline, as its own document — what a map draws when the
/// bundles cannot say.
class _WholeOutlines implements GeoshapeService {
  /// What was asked for from the device alone, and what by download.
  final kept = <String>[];
  final asked = <String>[];

  @override
  Future<Geoshape> keptShapeFromSource(RefGeojsonAnswer answer) async {
    kept.add(answer.source!.url);
    return Geoshape(_bundle, resolved: true);
  }

  @override
  Future<List<RefGeojsonAnswer>> sourcesForRefs(List<Map<String, dynamic>> refs) async => [
    for (final ref in refs)
      (source: RefGeojson(url: 'whole/${ref['ref']}', maxAge: const Duration(days: 30), missMaxAge: const Duration(days: 1)), answered: true),
  ];

  @override
  Future<Geoshape> shapeFromSource(RefGeojsonAnswer answer) async {
    asked.add(answer.source!.url);
    return Geoshape(_bundle, resolved: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The map over [suggestions], its camera reported at rest over the park
/// close enough for dashed outlines.
Future<OsmMapView Function()> _pumpMap(
  WidgetTester tester, {
  required List<Map<String, dynamic>> suggestions,
  required OutlineGridService grid,
  GeoshapeService? geoshapes,
  double zoom = ActivitiesResultsMap.suggestionOutlinesFromZoom + 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: ActivitiesResultsMap(
            suggestions: suggestions,
            controls: const [],
            refs: const [],
            settings: settings,
            onAdd: (_) {},
            outlineGrid: grid,
            geoshapes: geoshapes,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  OsmMapView map() => tester.widget<OsmMapView>(find.byType(OsmMapView));
  map().onCameraChanged!((camera: MapCameraPosition(latitude: 0.05, longitude: 0.05, zoom: zoom), bounds: (south: 0.0, west: 0.0, north: 0.1, east: 0.1)));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  return map;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  testWidgets('a POTA suggestion draws its bundle lines dashed, and a tap inside its area finds it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final grid = _Grid(bundle: _bundle);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ActivitiesResultsMap(suggestions: const [_park], controls: const [], refs: const [], settings: settings, onAdd: (_) {}, outlineGrid: grid),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      OsmMapView map() => tester.widget<OsmMapView>(find.byType(OsmMapView));
      // Close enough for dashed outlines, as a backend reports it.
      map().onCameraChanged!((
        camera: const MapCameraPosition(latitude: 0.05, longitude: 0.05, zoom: ActivitiesResultsMap.suggestionOutlinesFromZoom + 1),
        bounds: (south: 0.0, west: 0.0, north: 0.1, east: 0.1),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(grid.cellsRead.expand((cells) => cells), contains('JJ00-11'));
      final outline = map().shapes.where((shape) => shape.id.startsWith('ref-potaActivation/US-0001/')).toList();
      expect(outline, isNotEmpty);
      // Drawn, an area would stroke its cell's edge as if the park ended there.
      expect(outline.every((shape) => shape.isLine && shape.dashed), isTrue);

      map().onMapTap!(const GridLocation(0.05, 0.08));
      await tester.pumpAndSettle();
      expect(find.text('POTA US-0001'), findsOneWidget, reason: 'the area is still what a tap inside the park lands on');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a POTA suggestion that arrives with the camera at rest still gets its outline', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final grid = _Grid(bundle: _bundle);
      Widget sheet(List<Map<String, dynamic>> suggestions) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ActivitiesResultsMap(suggestions: suggestions, controls: const [], refs: const [], settings: settings, onAdd: (_) {}, outlineGrid: grid),
          ),
        ),
      );
      // The map opens on a list with no POTA park in it, reports where it is,
      // and then stays put: a camera fitted to "you are here" does not refit.
      await tester.pumpWidget(sheet(const [_summit]));
      await tester.pumpAndSettle();
      final map = tester.widget<OsmMapView>(find.byType(OsmMapView));
      map.onCameraChanged!((
        camera: const MapCameraPosition(latitude: 0.05, longitude: 0.05, zoom: ActivitiesResultsMap.suggestionOutlinesFromZoom + 1),
        bounds: (south: 0.0, west: 0.0, north: 0.1, east: 0.1),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(sheet(const [_summit, _park]));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final outline = tester.widget<OsmMapView>(find.byType(OsmMapView)).shapes.where((shape) => shape.id.startsWith('ref-potaActivation/US-0001/'));
      expect(outline, isNotEmpty, reason: 'drawn from neither the bundles nor whole, a park found by its outline shows none');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('offline with no bundle kept, a POTA suggestion is drawn from the whole outline the device holds, never downloaded', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final whole = _WholeOutlines();
      final map = await _pumpMap(tester, suggestions: const [_park], grid: _Grid(settled: false), geoshapes: whole);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Which the device may still hold from before the bundles were drawn
      // from; without it, an operator offline at the park sees no outline.
      expect(whole.kept, ['whole/US-0001']);
      expect(map().shapes.where((shape) => shape.id.startsWith('ref-potaActivation/US-0001/') && shape.dashed), isNotEmpty);
      // Downloaded instead, the fallback would be the very fetch the bundles
      // exist to avoid — 14.8 MB for a long trail — the moment the device is
      // back online.
      expect(whole.asked, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('read whole, the bundles are the only source: a park they lack never fetches its whole outline', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final whole = _WholeOutlines();
      await _pumpMap(tester, suggestions: const [_park], grid: _Grid(), geoshapes: whole);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // A long trail's whole outline runs to megabytes; it is the download
      // the bundles exist to avoid.
      expect(whole.asked, isEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('offline at a planned park, the map draws from the blocks kept there when the squares are not', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final grid = _Grid(bundle: _bundle, squaresKept: false);
      // Opened close in, where the map reads the detailed squares.
      final map = await _pumpMap(tester, suggestions: const [_park], grid: grid, zoom: 10.5);

      expect(grid.cellsRead.expand((cells) => cells), containsAll(['JJ00', 'JJ00-11']));
      expect(map().shapes.where((shape) => shape.id.startsWith('ref-potaActivation/US-0001/') && shape.dashed), isNotEmpty);

      // Back online, the next camera report over the same view asks for the
      // squares again; taken as read, the coarse blocks would stay until the
      // operator panned to other cells.
      final readsBefore = grid.cellsRead.length;
      map().onCameraChanged!((
        camera: const MapCameraPosition(latitude: 0.05, longitude: 0.05, zoom: 10.5),
        bounds: (south: 0.0, west: 0.0, north: 0.1, east: 0.1),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(grid.cellsRead.skip(readsBefore).expand((cells) => cells), contains('JJ00'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
