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
import 'package:ham2k_logger/views/map/map_marker_data.dart';

List<MapShapeData> parse(String json) =>
    mapShapesFromGeojson(jsonDecode(json), idPrefix: 'ref-sotaActivation/W2/GC-116', color: Colors.green);

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

  test('points and lines in the same document contribute nothing — a boundary is an area', () {
    final shapes = parse('''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","geometry":{"type":"Point","coordinates":[-74.4,41.9]}},
        {"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}]}''');

    expect(shapes, isEmpty);
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
}
