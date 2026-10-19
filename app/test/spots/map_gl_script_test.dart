// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the shared GL script does with the Activities map's camera and fade
// rules, and with the Map tab's current QSO. The Dart side only sends flags
// and points; the script is what turns them into a camera that stays put,
// dots that fade with a pinch and a log that steps back behind the QSO being
// worked, and every backend but the pure-Flutter one runs it.

import 'dart:convert';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:ham2k_logger/views/map/map_gl_script.dart' show mapGlScript;
import 'package:ham2k_logger/views/map/map_grayline.dart';
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

  group('Show Callsigns pills', () {
    MapMarkerData qso(String id, {bool highlight = false, bool pill = true}) => MapMarkerData(
      id: id,
      latitude: 40,
      longitude: -74,
      label: id.toUpperCase(),
      kind: MapMarkerKind.qso,
      color: const Color(0xFF2196F3),
      labelColor: pill ? const Color(0xFFFFFFFF) : null,
      strokeColor: const Color(0xFF1A1A1A),
      highlight: highlight,
    );
    const qth = MapMarkerData(
      id: 'qth-FN20',
      latitude: 41,
      longitude: -73,
      label: 'FN20',
      kind: MapMarkerKind.qth,
      color: Color(0xFF000000),
      strokeColor: Color(0xFFFFFFFF),
    );
    void setMarkers(List<MapMarkerData> markers) => page.run('handle.setMarkers(${jsonEncode(mapMarkersPayload(markers))})');
    List<dynamic> features(String source) => (jsonDecode(page.run("JSON.stringify(fakeMap.getSource('$source').data.features)")) as List);

    // Each pill is one picture with its call in it. Drawn as a symbol's
    // text over a pill icon instead, the calls of a stack of pills — a
    // country's contacts on its centre — all show through the top one:
    // MapLibre draws a layer's icons, then all of its text.
    test('a contact with a label colour is a pill image carrying its call, and no dot under it', () {
      page = GlPage(framed: false);
      setMarkers([qso('k1abc'), qso('w2xyz', pill: false), qth]);
      final pill = features('polo-marker-pills').single['properties'] as Map;
      expect(pill['id'], 'k1abc');
      final drawn = jsonDecode(page.run("JSON.stringify(fakeMap.images['${pill['image']}'].image.texts)")) as List;
      expect(drawn, [
        {'text': 'K1ABC', 'fillStyle': '#ffffff'},
      ]);
      expect(page.run("String(fakeMap.getLayer('polo-marker-pills').layout['text-field'])"), 'undefined', reason: 'no text drawn apart from its pill');
      // A pill drawn over its own circle would show the circle's ring at
      // both ends of a short call.
      expect([for (final f in features('polo-markers')) f['properties']['id']], ['w2xyz', 'qth-FN20']);
    });

    test('a call no longer on the map gives its pill image back', () {
      page = GlPage(framed: false);
      // The current QSO's call, as it is typed.
      setMarkers([qso('a'), qso('k1', highlight: true)]);
      setMarkers([qso('a'), qso('k1a', highlight: true)]);
      final images = (jsonDecode(page.run('JSON.stringify(Object.keys(fakeMap.images))')) as List).cast<String>();
      expect(images.where((id) => id.endsWith('-K1')), isEmpty, reason: 'one image per keystroke would stay registered');
      expect(images.where((id) => id.endsWith('-K1A')), hasLength(1));
      expect(images.where((id) => id.endsWith('-A')), hasLength(1), reason: 'a pill still drawn keeps its image');
    });

    // MapLibre copies every image a tile names each time it parses it, and
    // zoomed out one tile holds the whole log: resent with each keystroke,
    // a long log's pills are megabytes copied per letter typed.
    test("a keystroke resends the current QSO's pill and leaves the log's alone", () {
      page = GlPage(framed: false);
      setMarkers([qso('a'), qso('b'), qso('k1', highlight: true)]);
      int sets(String source) => int.parse(page.run("String(fakeMap.getSource('$source').sets)"));
      final logSets = sets('polo-marker-pills');
      setMarkers([qso('a'), qso('b'), qso('k1a', highlight: true)]);
      expect(sets('polo-marker-pills'), logSets);
      expect(features('polo-marker-pills-highlight').single['properties']['id'], 'k1a');

      setMarkers([qso('a'), qso('b'), qso('c'), qso('k1a', highlight: true)]);
      expect(sets('polo-marker-pills'), logSets + 1, reason: 'a logged contact still reaches the map');
    });

    // A basemap or light/dark swap throws every registered image away with
    // the style, and puts the markers back through setMarkers: a script that
    // trusted its own record of what it registered would draw no pills.
    test('pills are drawn again after a style swap drops their images', () {
      page = GlPage(framed: false);
      setMarkers([qso('a')]);
      final image = features('polo-marker-pills').single['properties']['image'] as String;
      page.run('Object.keys(fakeMap.images).forEach(function (id) { delete fakeMap.images[id]; });');
      setMarkers([qso('a')]);
      expect(page.run("String(!!fakeMap.images['$image'])"), 'true');
    });

    test('pills sit under the QTH dots, and the current QSO over the log and its own line', () {
      page = GlPage(framed: false);
      setMarkers([qso('a')]);
      final order = (jsonDecode(page.run('JSON.stringify(fakeMap.layerOrder)')) as List).cast<String>();
      expect(order.indexOf('polo-marker-pills'), lessThan(order.indexOf('polo-markers')));
      expect(order.indexOf('polo-marker-pills-highlight'), greaterThan(order.indexOf('polo-lines-highlight')));
    });

    test("the log's pills step back behind the current QSO", () {
      page = GlPage(framed: false);
      setMarkers([qso('a'), qso('current', highlight: true)]);
      expect(jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('polo-marker-pills').paint['icon-opacity'])")), isNot(1));
      expect(page.run("String(fakeMap.getLayer('polo-marker-pills-highlight').paint)"), 'undefined', reason: 'the current QSO is never dimmed');
    });

    test('shrink with the zoom, less than a dot', () {
      page = GlPage(framed: false);
      setMarkers([qso('a')]);
      final size = jsonDecode(page.run("JSON.stringify(fakeMap.getLayer('polo-marker-pills').layout['icon-size'])")) as List;
      expect([size[3], size[4], size[5], size[6]], [mapMarkerSmallAtZoom, mapPillSmallScale, mapMarkerFullAtZoom, 1]);
      expect(mapPillSmallScale, greaterThan(mapMarkerSmallScale));
    });

    test('a tap on a pill opens its popup', () {
      page = GlPage(framed: false);
      setMarkers([qso('a')]);
      page.run("window.hits = [{ properties: { id: 'a' } }]; fakeMap.fire('click');");
      // The fake answers any query with its hits; leaving the pill layers out
      // of the query is what would make a real tap on a pill land on nothing.
      expect(jsonDecode(page.run('JSON.stringify(window.lastQueryLayers)')), containsAll(['polo-marker-pills', 'polo-marker-pills-highlight']));
      expect(page.run('handle.camera().popup'), 'a');
    });
  });

  group('the grayline', () {
    final grayline = jsonEncode(jsonEncode(mapGraylinePayload(DateTime.utc(2026, 6, 21, 12), dark: false)));
    List<String> order() => (jsonDecode(page.run('JSON.stringify(fakeMap.layerOrder)')) as List).cast<String>();

    /// A basemap of a land fill under a label layer, as every style has.
    void basemap() => page.run("fakeMap.addLayer({ id: 'land', type: 'fill' }); fakeMap.addLayer({ id: 'place-labels', type: 'symbol' });");

    // Over the labels, the night side dims every place name on it; over the
    // host's own layers, it dims the contacts the operator is looking at.
    test('lies under the basemap labels and the contacts, and over the land', () {
      page = GlPage(framed: false);
      basemap();
      page.run('handle.setMarkers([${_marker('a')}])');
      page.run('handle.setGraylineJson($grayline)');
      final layers = order();
      expect(layers.indexOf('polo-grayline'), greaterThan(layers.indexOf('land')));
      expect(layers.indexOf('polo-grayline'), lessThan(layers.indexOf('place-labels')));
      expect(layers.indexOf('polo-grayline'), lessThan(layers.indexOf('polo-shapes-dashed')));
    });

    // A fill layer is drawn twice over the outer quarters of the world on a
    // zoomed-out globe, which a translucent fill shows: the shading is one
    // picture, each step laid on it once at the step's alpha.
    test('is a picture of the world, each step of the night painted on it once', () {
      page = GlPage(framed: false);
      basemap();
      page.run('handle.setGraylineJson($grayline)');
      expect(page.run("fakeMap.getLayer('polo-grayline').type"), 'raster');
      final spec = jsonDecode(page.run("JSON.stringify(fakeMap.getSource('polo-grayline').spec)")) as Map<String, dynamic>;
      expect(spec['type'], 'image');
      final shapes = (jsonDecode(spec['url'] as String) as List).cast<Map<String, dynamic>>();
      expect(shapes, hasLength(graylineSunAltitudes.length));
      for (final shape in shapes) {
        expect(shape['globalAlpha'], graylineStepOpacity(dark: false));
        expect(shape['fillStyle'], '#000814');
      }
    });

    // At noon UTC the night lies across the antimeridian, which is both the
    // picture's left and right edge: a cap drawn only where its longitudes
    // run leaves one of the two edges lit. At an equinox, when no cap holds a
    // pole — a cap that does runs the whole way round, and hides the trap.
    test('shades the night across the antimeridian at both edges of the picture', () {
      page = GlPage(framed: false);
      basemap();
      final equinox = jsonEncode(jsonEncode(mapGraylinePayload(DateTime.utc(2026, 3, 20, 12), dark: false)));
      page.run('handle.setGraylineJson($equinox)');
      final spec = jsonDecode(page.run("JSON.stringify(fakeMap.getSource('polo-grayline').spec)")) as Map<String, dynamic>;
      final shapes = (jsonDecode(spec['url'] as String) as List).cast<Map<String, dynamic>>();
      bool shaded(Map<String, dynamic> shape, double x, double y) {
        var inside = false;
        for (final outline in (shape['outlines'] as List).cast<List>()) {
          final ring = [for (final p in outline.cast<List>()) (x: (p[0] as num).toDouble(), y: (p[1] as num).toDouble())];
          for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
            final a = ring[i], b = ring[j];
            if ((a.y > y) != (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) inside = !inside;
          }
        }
        return inside;
      }

      for (final shape in shapes) {
        expect(shaded(shape, 2, 512), isTrue, reason: 'the left edge at the equator, 180°W');
        expect(shaded(shape, 1022, 512), isTrue, reason: 'the right edge at the equator, 180°E');
        expect(shaded(shape, 512, 512), isFalse, reason: 'noon at Greenwich');
      }
    });

    test('a new instant moves the shading it has, and none takes it away', () {
      page = GlPage(framed: false);
      basemap();
      page.run('handle.setGraylineJson($grayline)');
      final later = jsonEncode(jsonEncode(mapGraylinePayload(DateTime.utc(2026, 6, 21, 13), dark: false)));
      page.run('handle.setGraylineJson($later)');
      expect(order().where((id) => id == 'polo-grayline'), hasLength(1));
      expect(page.run("String(fakeMap.getSource('polo-grayline').sets)"), '1', reason: 'the picture moved on in place, not made again');
      page.run('handle.setGrayline(null)');
      expect(order(), isNot(contains('polo-grayline')));
      expect(page.run("String(!!fakeMap.getSource('polo-grayline'))"), 'false');
    });

    // A style swap throws away every source and layer the host added: one
    // the swap does not put back is a setting that silently stops working
    // the first time the operator changes basemaps.
    test('comes back after a style swap', () {
      page = GlPage(framed: false);
      basemap();
      page.run('handle.setGraylineJson($grayline)');
      page.run('handle.setDark(true)');
      expect(order(), isEmpty);
      basemap();
      page.run("fakeMap.fire('style.load')");
      final layers = order();
      expect(layers, contains('polo-grayline'));
      expect(layers.indexOf('polo-grayline'), lessThan(layers.indexOf('place-labels')));
    });
  });

  // Flutter web injects the script once per Dart lifetime, and a hot restart
  // starts a new one on the same page: kept, the first copy would pair the
  // new Dart with a script missing every call added since it loaded.
  test('injecting the script again replaces the copy already on the page', () {
    page = GlPage(framed: false);
    page.run('window.poloMapGl = { create: function () { return {}; } };');
    page.run(mapGlScript);
    page.run("var again = window.poloMapGl.create(container, 'light-style', 'dark-style', false, function () {}, false, null);");
    expect(page.run('typeof again.fitToJson'), 'function');
  });
}
