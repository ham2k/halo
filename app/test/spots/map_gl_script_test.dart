// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the shared GL script does with the Activities map's camera and fade
// rules. The Dart side only sends flags; the script is what turns them into a
// camera that stays put and dots that fade with a pinch, and every backend
// but the pure-Flutter one runs it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

import '../support/gl_page.dart';

String _marker(String id, {String? fitKey, bool fit = true, bool fades = false}) => jsonEncode({
  'id': id,
  'latitude': 40,
  'longitude': -74,
  'kind': 'qso',
  'color': '#ff0000',
  'strokeColor': '#000000',
  'fit': fit,
  'fitKey': ?fitKey,
  if (fades) 'fades': true,
});

void main() {
  late GlPage page;
  tearDown(() => page.dispose());

  test('a keyed map refits when the key changes, and not when its markers do', () {
    page = GlPage(framed: false);
    page.run('handle.setMarkers([${_marker('a', fitKey: 'search-1')}])');
    expect(page.takeCalls(), contains('fitBounds'));

    // A reference added from a card: its suggestion dot becomes its marker.
    page.run("handle.setMarkers([${_marker('a', fitKey: 'search-1')}, ${_marker('ref-x', fitKey: 'search-1')}])");
    expect(page.takeCalls(), isNot(contains('fitBounds')), reason: 'the camera would jump away from what the operator just picked');

    page.run('handle.setMarkers([${_marker('b', fitKey: 'search-2')}])');
    expect(page.takeCalls(), contains('fitBounds'));
  });

  test('the fit never comes closer than the cap', () {
    page = GlPage(framed: false);
    page.run('handle.setMarkers([${_marker('a')}])');
    expect(page.run('String(window.lastFitOptions.maxZoom)'), '${MapZoomController.fitMaxZoom}');
  });

  test('markers kept out of the fit move nothing', () {
    page = GlPage(framed: false);
    page.run('handle.setMarkers([${_marker('a', fit: false)}])');
    expect(page.takeCalls(), isNot(contains('fitBounds')));
  });

  test('the fades become paint on the live zoom, only for what fades', () {
    page = GlPage(framed: false);
    page.run('handle.setZoomFadesJson(${jsonEncode(jsonEncode(mapZoomFadesPayload(ActivitiesResultsMap.zoomFades)))})');
    page.run('handle.setMarkers([${_marker('a', fades: true)}, ${_marker('ref-x')}])');

    const f = ActivitiesResultsMap.zoomFades;
    final markerOpacity = jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('polo-markers').paint['circle-opacity'])"));
    // A zoom expression, not a number: a number fixed by Dart would jump
    // when the pinch ends instead of following it.
    expect(markerOpacity, [
      'interpolate',
      ['linear'],
      ['zoom'],
      f.markers!.from,
      [
        'case',
        [
          '==',
          ['get', 'fades'],
          true,
        ],
        0,
        1,
      ],
      f.markers!.to,
      1,
    ]);
    final dashed = jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('polo-shapes-dashed').paint['line-opacity'])")) as List;
    expect(dashed.sublist(0, 4), [
      'interpolate',
      ['linear'],
      ['zoom'],
      f.dashedShapes!.from,
    ]);
    expect(dashed[5], f.dashedShapes!.to);
  });

  test('a fade set before the style is ready still lands on the layers', () {
    page = GlPage(framed: false);
    // No layers yet: the fades have to wait for them, not be dropped.
    page.run('handle.setZoomFadesJson(${jsonEncode(jsonEncode(mapZoomFadesPayload(ActivitiesResultsMap.zoomFades)))})');
    page.run('handle.setMarkers([${_marker('a', fades: true)}])');
    expect(page.run("typeof fakeMap.getLayer('polo-markers').paint['circle-opacity']"), 'object');
  });

  test('markers shrink with the zoom: circles and glyphs alike, as paint on the live zoom', () {
    page = GlPage(framed: false);
    page.run('handle.setMarkers([${_marker('a')}])');
    final radius = jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('polo-markers').paint['circle-radius'])")) as List;
    expect(radius.sublist(0, 3), [
      'interpolate',
      ['linear'],
      ['zoom'],
    ]);
    expect(radius[3], mapMarkerSmallAtZoom);
    expect(radius[5], mapMarkerFullAtZoom);
    final iconSize = jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('polo-marker-icons').layout['icon-size'])")) as List;
    expect([iconSize[3], iconSize[4], iconSize[5], iconSize[6]], [mapMarkerSmallAtZoom, mapMarkerSmallScale, mapMarkerFullAtZoom, 1]);
  });

  test('the Map tab\'s own outlines fade in, fill and edge together', () {
    page = GlPage(framed: false);
    const fades = (markers: null, dashedShapes: null, solidShapes: (from: 7.0, to: 8.0));
    page.run('handle.setZoomFadesJson(${jsonEncode(jsonEncode(mapZoomFadesPayload(fades)))})');
    page.run('handle.setMarkers([${_marker('a')}])');
    for (final (layer, property) in [('polo-shapes-fill', 'fill-opacity'), ('polo-shapes-outline', 'line-opacity')]) {
      final paint = jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('$layer').paint['$property'])"));
      expect(paint, isA<List>(), reason: '$layer is a zoom expression, not a fixed opacity');
      expect((paint as List)[3], 7.0);
      expect(paint[4], 0);
    }
  });
}
