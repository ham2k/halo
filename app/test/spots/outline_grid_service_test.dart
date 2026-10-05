// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Parks found by their outline rather than their point. A trail's POTA point
// can sit a state away from where it passes the operator, so a nearby list
// built from points alone never offers it; these pin down the cell names the
// bundles are fetched by, the distance to an outline, and how parks found
// that way join the suggestions.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/outline_grid_service.dart';

import '../support/fake_extension_host.dart';

/// The operator, inside US-0001.
const _here = GridLocation(0.05, 0.05);

Map<String, dynamic> _feature(String ref, String kind, Map<String, dynamic> geometry) => {
  'type': 'Feature',
  'id': ref,
  'properties': {'reference': ref, 'kind': kind},
  'geometry': geometry,
};

Map<String, dynamic> _square(double west, double south, double size) => {
  'type': 'Polygon',
  'coordinates': [
    [
      [west, south],
      [west + size, south],
      [west + size, south + size],
      [west, south + size],
      [west, south],
    ],
  ],
};

Map<String, dynamic> _trailAtLon(double lon) => {
  'type': 'LineString',
  'coordinates': [
    [lon, 0.0],
    [lon, 0.1],
  ],
};

/// The block bundle around [_here]: one park holding it, a trail about 3 km
/// east, another about 8 km east, and two parks POTA will not offer.
final _bundle = jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    _feature('US-0001', 'area', _square(0, 0, 0.1)),
    _feature('US-0001', 'edge', _trailAtLon(0)),
    _feature('US-0003', 'trail', _trailAtLon(0.08)),
    _feature('US-0002', 'trail', _trailAtLon(0.12)),
    _feature('US-0004', 'area', _square(0.04, 0.04, 0.02)),
    _feature('US-0005', 'area', _square(0.04, 0.04, 0.02)),
    _feature('US-0006', 'mystery', _square(0.04, 0.04, 0.02)),
  ],
});

class _Geoshapes implements GeoshapeService {
  _Geoshapes({this.offline = false});

  /// No copy kept, and nothing reachable: every read is unsettled.
  final bool offline;
  final requested = <String>[];

  @override
  Future<Geoshape> shapeFromSource(RefGeojsonAnswer answer) async {
    final url = answer.source!.url;
    requested.add(url);
    if (offline) return Geoshape.unknown;
    return Geoshape(url.endsWith('/JJ00-11.geojson') ? _bundle : '{"type":"FeatureCollection","features":[]}', resolved: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Decorates as POTA does: every park it knows gets a label, a park it does
/// not know (US-0004) gets none, and US-0005 it has retired. With [failing],
/// the hook gives no answer at all — it threw, or ran out of time.
class _Pota extends ExtensionServiceWithFakeHost {
  _Pota({this.failing = false}) : super(FakeExtensionHost({}));

  final bool failing;
  final asked = <String>[];

  @override
  Future<List<RefHookAnswer>> refHookAnswers(List<Map<String, dynamic>> refs, RefMethod method, {Map<String, dynamic> extraArgs = const {}}) async {
    final answers = <RefHookAnswer>[];
    for (final ref in refs) {
      if (failing) {
        answers.add((asked: true, ok: false, noHandler: false, value: null));
        continue;
      }
      asked.add(ref['ref'] as String);
      final park = switch (ref['ref']) {
        'US-0004' => {...ref, 'name': 'Unknown park'},
        'US-0005' => {...ref, 'label': 'POTA US-0005: Gone', 'retired': true},
        _ => {...ref, 'label': 'POTA ${ref['ref']}', 'shortLabel': 'POTA ${ref['ref']}'},
      };
      answers.add((asked: true, ok: true, noHandler: false, value: park));
    }
    return answers;
  }
}

void main() {
  group('the cells a view reads', () {
    // Bear Mountain at zoom 12. The names are the server's: a block starts on
    // an even square, and a name it does not serve is a 400, not an outline.
    test('are named as services.ham2k.net names them', () {
      expect(OutlineGridService.cellsCovering(south: 41.25, west: -74.08, north: 41.37, east: -73.93, scale: OutlineGridScale.block), ['FN20-31']);
      expect(OutlineGridService.cellsCovering(south: 41.25, west: -74.08, north: 41.37, east: -73.93, scale: OutlineGridScale.square), ['FN21', 'FN31']);
    });

    test('include every cell a view straddles', () {
      expect(OutlineGridService.cellsCovering(south: 41.9, west: -76.1, north: 42.1, east: -75.9, scale: OutlineGridScale.block), [
        'FN00-11',
        'FN20-31',
        'FN02-13',
        'FN22-33',
      ]);
    });
  });

  group('a park\'s distance', () {
    final parks = OutlineGridService.parseBundle(_bundle, cell: 'JJ00-11', url: 'bundle');

    test('is nothing from inside it, wherever its edge is', () {
      expect(parks['US-0001']!.distanceKmFrom(_here), 0);
    });

    test('is to the nearest point of a trail, which has no inside', () {
      expect(parks['US-0003']!.distanceKmFrom(_here), closeTo(3.34, 0.05));
    });

    test('reads only the kinds a bundle draws a park with', () {
      expect(parks.containsKey('US-0006'), isFalse);
    });
  });

  group('the nearby suggestions', () {
    test('gain the parks whose outline is near, decorated by POTA, nearest first', () async {
      final geoshapes = _Geoshapes();
      final pota = _Pota();
      final service = OutlineGridService(geoshapes: geoshapes, extensions: pota);
      final suggestions = [
        {'type': 'potaActivation', 'ref': 'US-0003', 'label': 'POTA US-0003', 'distance': 40.0, 'relevance': 1},
        {'type': 'sotaActivation', 'ref': 'W2/GC-001', 'distance': 1.0, 'relevance': 1},
      ];

      final parks = await service.parksNear(_here, OutlineGridService.nearbyRadiusKm, measureFrom: _here, known: OutlineGridService.potaRefsIn(suggestions));
      final merged = OutlineGridService.withParks(suggestions, parks);

      expect(geoshapes.requested, ['https://services.ham2k.net/lookups/outlines/pota/grid/JJ00-11.geojson']);
      expect(parks.settled, isTrue);
      expect(pota.asked, isNot(contains('US-0003')), reason: 'a park already listed needs no second decoration');
      final byRef = {for (final suggestion in merged) suggestion['ref']: suggestion};
      // Inside it, the park is the nearest thing there is.
      expect(merged.first['ref'], 'US-0001');
      expect(byRef['US-0001']!['label'], 'POTA US-0001', reason: 'labelled by POTA, so it reads like the parks POTA suggested');
      // Found by its point 40 km off, and by its trail 3 km off: one entry, at
      // the trail's distance.
      expect(merged.where((suggestion) => suggestion['ref'] == 'US-0003'), hasLength(1));
      expect(byRef['US-0003']!['distance'], closeTo(3.34, 0.05));
      expect(byRef.containsKey('US-0002'), isFalse, reason: 'its trail is past the nearby radius');
      expect(byRef.containsKey('US-0004'), isFalse, reason: 'a park POTA does not know is not offered');
      expect(byRef.containsKey('US-0005'), isFalse, reason: 'nor one POTA has retired');
      expect(byRef.containsKey('W2/GC-001'), isTrue, reason: 'other programs\' suggestions are untouched');
    });

    test('a park POTA could not be asked about is unsettled, not unknown', () async {
      final service = OutlineGridService(geoshapes: _Geoshapes(), extensions: _Pota(failing: true));

      final parks = await service.parksNear(_here, OutlineGridService.nearbyRadiusKm, measureFrom: _here);

      // Settled, a pan would never ask about this view again, and its parks
      // would stay missing as if POTA had never heard of them.
      expect(parks.found, isEmpty);
      expect(parks.settled, isFalse);
    });

    test('a bundle that could not be read is unsettled, not empty', () async {
      final service = OutlineGridService(geoshapes: _Geoshapes(offline: true), extensions: _Pota());

      final parks = await service.parksNear(_here, OutlineGridService.nearbyRadiusKm, measureFrom: _here);

      // Offline is not "no parks here": settled, the view would never be
      // asked about again once the device is back online.
      expect(parks.found, isEmpty);
      expect(parks.settled, isFalse);
    });

    test('with no place to measure from, parks found by outline carry no distance', () async {
      final service = OutlineGridService(geoshapes: _Geoshapes(), extensions: _Pota());

      final parks = await service.parksNear(_here, OutlineGridService.nearbyRadiusKm);

      // A distance from a map view's centre would read as the operator's.
      expect(parks.found, isNotEmpty);
      expect(parks.found.every((park) => !park.containsKey('distance')), isTrue);
    });

    test('reach no further than a close view, however wide the one asked about', () async {
      final geoshapes = _Geoshapes();
      final service = OutlineGridService(geoshapes: geoshapes, extensions: _Pota());

      final parks = await service.parksNear(_here, OutlineGridService.maxRadiusKm + 1);

      // A zoomed-out view, or one across the antimeridian measured from the
      // wrong side of the planet, would otherwise read every bundle in reach.
      expect(geoshapes.requested, isEmpty);
      expect(parks.found, isEmpty);
    });

    test('a park the nearby list gains leaves what panning found, and nothing else does', () {
      const found = [
        {'type': 'potaActivation', 'ref': 'US-0001'},
        {'type': 'sotaActivation', 'ref': 'US-0002'},
        {'type': 'potaActivation', 'ref': 'US-0003'},
      ];
      const nearby = [
        {'type': 'potaActivation', 'ref': 'US-0001'},
        {'type': 'potaActivation', 'ref': 'US-0002'},
      ];

      // Left in both, the map would draw one park twice; left only on the map,
      // the list would miss a park the operator is standing in.
      expect(OutlineGridService.withoutParksIn(found, nearby).map((s) => s['ref']), ['US-0002', 'US-0003']);
      expect(identical(OutlineGridService.withoutParksIn(found, const []), found), isTrue);
    });

    test('merge into the list as it stands, leaving it as it was when nothing changes', () {
      const parks = (
        distances: <String, double?>{'US-0001': 0.0},
        found: [
          {'type': 'potaActivation', 'ref': 'US-0001', 'label': 'POTA US-0001', 'distance': 0.0},
        ],
        settled: true,
      );
      final listed = [
        {'type': 'potaActivation', 'ref': 'US-0001', 'distance': 0.0},
      ];

      // The view compares lists by identity to know whether to rebuild.
      expect(identical(OutlineGridService.withParks(listed, parks), listed), isTrue);
      expect(OutlineGridService.withParks(const [], parks, elsewhere: {'US-0001'}), isEmpty, reason: 'already in the other list the operator sees');
    });
  });

  group('a planned operation', () {
    test('keeps the bundles around its POTA parks on the device, once', () async {
      final geoshapes = _Geoshapes();
      final service = OutlineGridService(geoshapes: geoshapes, extensions: _Pota());
      const refs = [
        {'type': 'potaActivation', 'ref': 'US-0001', 'lat': 0.05, 'lon': 0.05},
        // Nothing to read for these: no place, or not a park.
        {'type': 'potaActivation', 'ref': 'US-0009'},
        {'type': 'sotaActivation', 'ref': 'W2/GC-001', 'lat': 41.0, 'lon': -74.0},
      ];

      service.prefetchFor(refs);
      service.prefetchFor(refs);
      await pumpEventQueue();

      // Set up at home, online, it is what answers at the park, offline.
      expect(geoshapes.requested, ['https://services.ham2k.net/lookups/outlines/pota/grid/JJ00-11.geojson']);
    });
  });
}
