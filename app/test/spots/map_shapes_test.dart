// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the app accepts as a reference's outline. Every rejection here is a
// document fetched from a program's own server — nothing in the app controls
// what comes back, so the parser must be total: a malformed shape draws
// nothing, and never takes the map down with it.

import 'dart:convert';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:ham2k_logger/views/map/map_marker_data.dart';

List<MapShapeData> parse(String json) => mapShapesFromGeojson(jsonDecode(json), idPrefix: 'ref-sotaActivation/W2/GC-116', color: Colors.green);

void main() {
  test('a FeatureCollection of one polygon reads as one shape', () {
    final shapes = parse('''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":{"type":"Polygon","coordinates":
          [[[-74.4,41.9],[-74.3,41.9],[-74.3,41.8],[-74.4,41.9]]]}}]}''');

    expect(shapes, hasLength(1));
    expect(shapes.first.id, 'ref-sotaActivation/W2/GC-116/0');
    // GeoJSON orders each point [longitude, latitude]; read the other way
    // round, an activation zone in New York lands in the Indian Ocean.
    expect(shapes.first.rings.first.first.latitude, 41.9);
    expect(shapes.first.rings.first.first.longitude, -74.4);
  });

  test('the rings after the first are holes, in order', () {
    final shapes = parse('''
      {"type":"Feature","geometry":{"type":"Polygon","coordinates":[
        [[0,0],[2,0],[2,2],[0,2],[0,0]],
        [[0.5,0.5],[1,0.5],[1,1],[0.5,0.5]]]}}''');

    expect(shapes.single.rings, hasLength(2));
    expect(shapes.single.rings.last.first.longitude, 0.5);
  });

  test('a MultiPolygon becomes one shape per polygon', () {
    final shapes = parse('''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":{"type":"MultiPolygon","coordinates":[
          [[[0,0],[1,0],[1,1],[0,0]]],
          [[[5,5],[6,5],[6,6],[5,5]]]]}}]}''');

    expect(shapes.map((s) => s.id), ['ref-sotaActivation/W2/GC-116/0', 'ref-sotaActivation/W2/GC-116/1']);
  });

  test('a point contributes nothing — a footprint is an area or a path, never a spot', () {
    expect(parse('{"type":"Feature","geometry":{"type":"Point","coordinates":[-74.4,41.9]}}'), isEmpty);
  });

  test('a trail is a line shape, one per path, and never an area', () {
    // A park that is a trail or a river is published as its lines. Read as a
    // polygon, a trail would be closed end to end and fill the country between.
    final shapes = parse('''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}},
        {"type":"Feature","geometry":{"type":"LineString","coordinates":[[2,2],[3,3],[4,3]]}},
        {"type":"Feature","geometry":{"type":"MultiLineString","coordinates":[[[5,5],[6,6]],[[7,7],[8,8]]]}}]}''');

    expect([for (final s in shapes) s.isLine], [false, true, true, true]);
    expect(shapes.map((s) => s.id).toSet(), hasLength(4), reason: 'areas and lines share one index, so no two shapes of a reference share an id');
    expect(shapes[1].rings.single, hasLength(3));
    expect(shapes[1].rings.single.first.longitude, 2);
  });

  test('a line of fewer than two points is dropped, not drawn', () {
    expect(parse('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0]]}}'), isEmpty);
    expect(parse('{"type":"Feature","geometry":{"type":"MultiLineString","coordinates":[[[0,0]],"x"]}}'), isEmpty);
  });

  test('a ring of fewer than three points is dropped, not drawn', () {
    // A degenerate OUTER ring is the dangerous one: kept, it would paint
    // nothing while still claiming the holes that belong to a real shape.
    expect(parse('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,1]]]}}'), isEmpty);
  });

  test('a point with a third element keeps its longitude and latitude', () {
    // Elevation is a legal third element, and several programs publish it.
    final shapes = parse('''
      {"type":"Feature","geometry":{"type":"Polygon","coordinates":
        [[[-74.4,41.9,1200],[-74.3,41.9,1210],[-74.3,41.8,1190],[-74.4,41.9,1200]]]}}''');

    expect(shapes.single.rings.first, hasLength(4));
    expect(shapes.single.rings.first.first.latitude, 41.9);
  });

  test('a document that is not GeoJSON at all reads as no shapes', () {
    expect(mapShapesFromGeojson(jsonDecode('{"error":"not found"}'), idPrefix: 'x', color: Colors.green), isEmpty);
    expect(mapShapesFromGeojson(jsonDecode('[1,2,3]'), idPrefix: 'x', color: Colors.green), isEmpty);
    expect(mapShapesFromGeojson(null, idPrefix: 'x', color: Colors.green), isEmpty);
  });

  test('the GL payload keeps every ring of every shape', () {
    final shapes = parse('''
      {"type":"Feature","geometry":{"type":"Polygon","coordinates":[
        [[0,0],[2,0],[2,2],[0,0]],
        [[0.5,0.5],[1,0.5],[1,1],[0.5,0.5]]]}}''');

    final payload = mapShapesPayload(shapes);
    final feature = (payload['features'] as List).single as Map;
    expect((feature['geometry'] as Map)['coordinates'], hasLength(2));
    // Longitude first on the way out too, or MapLibre draws the same shape in
    // the wrong hemisphere from a payload the Dart side thought was right.
    expect(((feature['geometry'] as Map)['coordinates'] as List).first.first, [0, 0]);
  });

  test('markers are half size zoomed far out, growing to full size by zoom 8', () {
    // Over a continent, a full-size dot per contact buries the map.
    expect(mapMarkerScaleAt(0), 0.5);
    expect(mapMarkerScaleAt(3), 0.5);
    expect(mapMarkerScaleAt(5.5), closeTo(0.75, 1e-9));
    expect(mapMarkerScaleAt(8), 1);
    expect(mapMarkerScaleAt(14), 1);
  });

  group('mapZoomFadeOpacity', () {
    const band = (from: 6.0, to: 7.5);

    test('is nothing below the band, everything past it, and linear between', () {
      expect(mapZoomFadeOpacity(band, 5), 0);
      expect(mapZoomFadeOpacity(band, 6), 0);
      expect(mapZoomFadeOpacity(band, 6.75), closeTo(0.5, 1e-9));
      expect(mapZoomFadeOpacity(band, 7.5), 1);
      expect(mapZoomFadeOpacity(band, 12), 1);
    });

    test('no band shows everything, and a band of no width switches rather than dividing by zero', () {
      expect(mapZoomFadeOpacity(null, 0), 1);
      expect(mapZoomFadeOpacity((from: 7.0, to: 7.0), 6.9), 0);
      expect(mapZoomFadeOpacity((from: 7.0, to: 7.0), 7.0), 1);
    });
  });

  group('shapeAt', () {
    // A national forest with a state park inside it, and a trail off to one
    // side: the three ways two references' outlines meet on a real map.
    final forest = parse(
      '{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]],[[0.7,0.7],[0.8,0.7],[0.8,0.8],[0.7,0.8],[0.7,0.7]]]}}',
    ).single;
    final park = mapShapesFromGeojson(
      jsonDecode('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0.2,0.2],[0.4,0.2],[0.4,0.4],[0.2,0.4],[0.2,0.2]]]}}'),
      idPrefix: 'park',
      color: Colors.green,
    ).single;
    final trail = mapShapesFromGeojson(
      jsonDecode('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[2,0],[2,1]]}}'),
      idPrefix: 'trail',
      color: Colors.green,
    ).single;
    final all = [forest, park, trail];

    test('a tap inside nested areas takes the smallest — the park, not the forest around it', () {
      // In list order the forest comes first; first-match would never let the
      // operator reach the park inside it.
      expect(shapeAt(all, const GridLocation(0.3, 0.3), toleranceMeters: 0), same(park));
      expect(shapeAt(all, const GridLocation(0.6, 0.6), toleranceMeters: 0), same(forest));
    });

    test('a tap in a hole is not inside the shape with the hole', () {
      expect(shapeAt(all, const GridLocation(0.75, 0.75), toleranceMeters: 0), isNull);
    });

    test('a trail has no inside, so a tap lands on it only within the slack', () {
      // About 1.1km east of the trail at the equator.
      const beside = GridLocation(0.5, 2.01);
      expect(shapeAt(all, beside, toleranceMeters: 500), isNull);
      expect(shapeAt(all, beside, toleranceMeters: 2000), same(trail));
    });

    test('every shape a tap touches is listed with its size, for a caller ranking them all', () {
      // Inside the park and the forest, and near neither the trail nor any
      // edge: shapeAt would answer the park alone, hiding the forest.
      final hits = shapesAt(all, const GridLocation(0.3, 0.3), toleranceMeters: 0);
      expect(hits.map((hit) => hit.shape), unorderedEquals([park, forest]));
      final size = {for (final hit in hits) hit.shape: hit.size};
      expect(size[park]!, lessThan(size[forest]!));

      expect(shapesAt(all, const GridLocation(0.5, 2.01), toleranceMeters: 2000).map((hit) => hit.shape), [trail], reason: 'a trail within reach counts');
    });

    test('a tap near an edge takes that edge, even over an area it is also inside', () {
      // Just inside the park's west edge, and inside the forest too: the edge
      // the operator aimed at wins.
      expect(shapeAt(all, const GridLocation(0.3, 0.2001), toleranceMeters: 50), same(park));
    });
  });

  test('the GL payload marks a dashed shape, which the fill and solid layers leave out', () {
    final shapes = parse('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}}');

    Map payloadProperties(List<MapShapeData> s) => ((mapShapesPayload(s)['features'] as List).single as Map)['properties'] as Map;
    expect(payloadProperties(shapes)['dashed'], isFalse);
    expect(payloadProperties([shapes.single.asDashed()])['dashed'], isTrue);
  });

  test('a shape and its dashed form are different shapes to a map deciding whether to redraw', () {
    // Opening a suggestion's card turns its outline solid under the same id;
    // equal, the backends would keep the dashed one on screen.
    final solid = parse('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}}').single;
    expect(solid.asDashed(), isNot(solid));
    expect(solid.asDashed().id, solid.id);
  });

  test('the GL payload sends a trail as a LineString, which the fill layer leaves out', () {
    final shapes = parse('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[2,2],[3,3]]}}');

    final geometry = ((mapShapesPayload(shapes)['features'] as List).single as Map)['geometry'] as Map;
    // A Polygon here would reach the fill layer and paint the area inside the
    // trail's two ends.
    expect(geometry['type'], 'LineString');
    expect(geometry['coordinates'], [
      [2, 2],
      [3, 3],
    ]);
  });
}
