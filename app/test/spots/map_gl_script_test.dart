// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the shared GL script does with the Activities map's camera and fade
// rules, and with the Map tab's current QSO. The Dart side only sends flags
// and points; the script is what turns them into a camera that stays put,
// dots that fade with a pinch and a log that steps back behind the QSO being
// worked, and every backend but the pure-Flutter one runs it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

import '../support/gl_page.dart';

String _marker(String id, {String? fitKey, bool fit = true, bool fades = false, bool steady = false, bool highlight = false}) => jsonEncode({
  'id': id,
  'latitude': 40,
  'longitude': -74,
  'kind': 'qso',
  'highlight': highlight,
  if (steady) 'steady': true,
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

  group("the Map tab's current QSO", () {
    String paint(String layer, String property) => page.run("JSON.stringify(fakeMap.getLayer('$layer').paint['$property'])");
    // A steady marker (MapMarkerData.dimsBehindHighlight) keeps full
    // strength; everything else drops to the dimmed one.
    final dimmedUnlessSteady = [
      'case',
      [
        '==',
        ['get', 'steady'],
        true,
      ],
      1,
      mapDimmedOpacity,
    ];
    String lines({required bool highlight}) => jsonEncode({
      'opacity': 0.6,
      'features': [
        {
          'type': 'Feature',
          'properties': {'id': 'q/0', 'color': '#000000', 'highlight': highlight},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-74, 40],
              [-73, 41],
            ],
          },
        },
      ],
    });

    test('while it is shown, every marker but the steady ones steps back — dots and glyphs alike', () {
      page = GlPage(framed: false);
      page.run("handle.setMarkers([${_marker('a')}, ${_marker('qth', steady: true)}, ${_marker('current', highlight: true)}])");
      for (final (layer, property) in [('polo-markers', 'circle-opacity'), ('polo-markers', 'circle-stroke-opacity'), ('polo-marker-icons', 'icon-opacity')]) {
        expect(jsonDecode(paint(layer, property)), dimmedUnlessSteady, reason: '$layer $property');
      }
      expect(
        page.run("String(fakeMap.getLayer('polo-markers-highlight').paint['circle-opacity'])"),
        'undefined',
        reason: 'the highlight layer is never dimmed',
      );

      // The highlight goes: the log comes back to full strength.
      page.run("handle.setMarkers([${_marker('a')}, ${_marker('qth', steady: true)}])");
      expect(jsonDecode(paint('polo-markers', 'circle-opacity')), 1);
      expect(jsonDecode(paint('polo-marker-icons', 'icon-opacity')), 1);
    });

    test('under a zoom fade, the dimming rides inside the interpolate', () {
      // A zoom expression has to be the outermost one: dimming wrapped
      // around it is a style error, and the markers stop drawing at all.
      page = GlPage(framed: false);
      page.run('handle.setZoomFadesJson(${jsonEncode(jsonEncode(mapZoomFadesPayload(ActivitiesResultsMap.zoomFades)))})');
      page.run("handle.setMarkers([${_marker('a', fades: true)}, ${_marker('current', highlight: true)}])");
      final opacity = jsonDecode(paint('polo-markers', 'circle-opacity')) as List;
      expect(opacity[0], 'interpolate');
      expect((opacity[4] as List).last, dimmedUnlessSteady, reason: 'what does not fade, dimmed');
      expect(opacity[6], dimmedUnlessSteady);
    });

    test("the log's lines step back with the highlighted marker, keeping their own alpha", () {
      page = GlPage(framed: false);
      page.run('handle.setLines(${lines(highlight: false)})');
      expect(jsonDecode(paint('polo-lines', 'line-opacity')), 0.6);
      page.run("handle.setMarkers([${_marker('a')}, ${_marker('current', highlight: true)}])");
      expect(jsonDecode(paint('polo-lines', 'line-opacity')), closeTo(0.6 * mapDimmedOpacity, 1e-9));
      // New lines while it is shown — the highlight's own arriving after its
      // marker — stay stepped back.
      page.run('handle.setLines(${lines(highlight: true)})');
      expect(jsonDecode(paint('polo-lines', 'line-opacity')), closeTo(0.6 * mapDimmedOpacity, 1e-9));
      page.run("handle.setMarkers([${_marker('a')}])");
      expect(jsonDecode(paint('polo-lines', 'line-opacity')), 0.6);
    });

    // Every keystroke in the call field reaches the map as a marker patch and
    // a line patch. Re-setting the layers' paint on each — and walking the
    // whole log to decide it — is work a log of thousands pays per letter
    // typed, for an answer that only changes when the highlight comes or goes.
    test('a keystroke while the highlight is shown sets only the lines\' opacity', () {
      page = GlPage(framed: false);
      page.run("handle.setMarkers([${_marker('a')}, ${_marker('current', highlight: true)}])");
      page.run('handle.setLines(${lines(highlight: true)})');
      page.run(
        "var paintCalls = []; var setPaint = fakeMap.setPaintProperty; fakeMap.setPaintProperty = function (id, name, value) { paintCalls.push(id + ' ' + name); return setPaint.call(this, id, name, value); };",
      );

      page.run("handle.patchMarkers({ upsert: [${_marker('current', highlight: true)}], removeIds: [], indices: [1] })");
      page.run('handle.patchLines({ upsert: ${jsonEncode((jsonDecode(lines(highlight: true)) as Map)['features'])}, removeIds: [], indices: [0] })');
      expect(jsonDecode(page.run('JSON.stringify(paintCalls)')), ['polo-lines line-opacity']);
    });

    test('a QSO framed before the markers arrive survives their first fit', () {
      page = GlPage(framed: false);
      page.run('handle.fitToJson(${jsonEncode(jsonEncode(mapFitPayload(const [GridLocation(35, 139), GridLocation(36, 140)])))})');
      page.run("handle.setMarkers([${_marker('a')}])");
      expect(jsonDecode(page.run('JSON.stringify(window.lastFitPoints)')), [
        [139, 35],
        [140, 36],
      ], reason: 'the base fit would undo the pick the operator just made');
    });

    test('while a QSO is framed, a change to the log does not pull the camera off it', () {
      // A contact logged elsewhere — by sync, by another operator — would
      // otherwise take the map away from the QSO being edited.
      page = GlPage(framed: false);
      page.run("handle.setMarkers([${_marker('a')}])");
      page.run('handle.fitToJson(${jsonEncode(jsonEncode(mapFitPayload(const [GridLocation(35, 139)])))})');
      page.takeCalls();
      page.run("handle.setMarkers([${_marker('a')}, ${_marker('b', fit: true)}].map(function (m, i) { m.latitude += i; return m; }))");
      expect(page.takeCalls(), isNot(contains('fitBounds')));

      page.run('handle.refit()');
      expect(page.takeCalls(), contains('fitBounds'), reason: 'the refit takes in the new contact');
      expect(jsonDecode(page.run('JSON.stringify(window.lastFitPoints)')), hasLength(2));
    });

    test('after a refit, the markers frame the camera again', () {
      page = GlPage(framed: false);
      page.run('handle.fitToJson(${jsonEncode(jsonEncode(mapFitPayload(const [GridLocation(35, 139)])))})');
      page.run('handle.refit()');
      page.run("handle.setMarkers([${_marker('a')}])");
      expect(jsonDecode(page.run('JSON.stringify(window.lastFitPoints)')), [
        [-74, 40],
      ]);
      page.takeCalls();
      page.run('handle.refit()');
      expect(page.takeCalls(), contains('fitBounds'), reason: 'refit returns to the markers it last fit');
      expect(jsonDecode(page.run('JSON.stringify(window.lastFitPoints)')), [
        [-74, 40],
      ]);
    });
  });
}
