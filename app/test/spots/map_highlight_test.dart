// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The map highlights the QSO currently in the logging panel: a marker and a
// great-circle line drawn on top of everything else, in the panel's accent
// colour — orange while composing a new QSO, blue while editing one. This
// covers the colour/location logic, the order the GL script builds its
// layers in, and the OSM backend stepping everything else back while a
// highlight is shown. The GL script's own dimming is map_gl_script_test.dart's;
// whether the pixels land that way is checked in a browser.

import 'dart:typed_data';

import 'package:flutter/material.dart' show Color, Colors, HSLColor, IconData, MaterialApp, Opacity, Scaffold, Widget;
import 'package:flutter_map/flutter_map.dart' show MarkerLayer, PolylineLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation, gridToLocation;
import 'package:halo_widgets/halo_widgets.dart' show CallInfoData;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/map/map_gl_script.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';

import '../support/map_tile_cache.dart';

void main() {
  useTempMapTileCache();

  const composing = Color(0xFFFF8800); // stand-in for colorScheme.tertiary
  const editing = Color(0xFF0088FF); // stand-in for colorScheme.secondary
  const stroke = Color(0xFF1A1A1A);

  ({List<MapMarkerData> markers, List<MapLineData> lines}) build(CallInfoData? info, {GridLocation? qth, String? grid = 'CM87'}) =>
      buildHighlightData(callInfo: info, operationLocation: qth ?? gridToLocation(grid), composingColor: composing, editingColor: editing, strokeColor: stroke);

  test('nothing to highlight when there is no call info', () {
    expect(build(null).markers, isEmpty);
    expect(build(null).lines, isEmpty);
  });

  test('nothing to highlight when the location cannot be resolved', () {
    expect(build(CallInfoData(call: 'W1AW')).markers, isEmpty, reason: 'no guess at all');
    expect(
      build(CallInfoData(call: 'W1AW', guess: {})).markers,
      isEmpty,
      reason: 'guess with no location keys',
    );
  });

  test('a resolved location produces one highlight marker in the composing colour', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}));
    expect(result.markers, hasLength(1));
    final marker = result.markers.single;
    expect(marker.highlight, isTrue, reason: 'so backends draw it on top');
    expect(marker.color, composing, reason: 'composing a new QSO uses the orange/tertiary accent');
    expect(marker.label, 'W1AW');
    expect(marker.kind, MapMarkerKind.qso);
    // buildHighlightData has no say in the Show Callsigns setting: the call
    // being typed is a pill even on a map of plain dots.
    expect(marker.labelColor, isNotNull, reason: 'drawn as a pill with its call, so it reads as the current QSO');
  });

  test("the pill's call is legible on either accent", () {
    ({List<MapMarkerData> markers, List<MapLineData> lines}) onAccents(bool isEditing) => buildHighlightData(
      callInfo: CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}, isEditing: isEditing),
      operationLocation: gridToLocation('CM87'),
      composingColor: const Color(0xFFFFEE58),
      editingColor: const Color(0xFF0D47A1),
      strokeColor: stroke,
    );
    // A fixed label colour would pass one of these and fail the other.
    expect(onAccents(false).markers.single.labelColor, const Color(0xFF000000), reason: 'black on a pale yellow accent');
    expect(onAccents(true).markers.single.labelColor, const Color(0xFFFFFFFF), reason: 'white on a deep blue one');
  });

  // The guess carries a coordinate whenever the lookup knew one (QRZ reports
  // lat/lon, and the merge derives the grid FROM it). Dropping `exact:` from
  // the resolve call leaves this passing at the square's centre instead —
  // ~4km away here — so the assertion is on the coordinate, not on "is there
  // a marker".
  test("a guess's own coordinate places the marker, not the centre of its grid", () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278}));
    final marker = result.markers.single;
    expect(marker.latitude, closeTo(41.7135, 1e-9));
    expect(marker.longitude, closeTo(-72.7278, 1e-9));

    final squareCentre = gridToLocation('FN31pr')!;
    expect((marker.latitude - squareCentre.latitude).abs(), greaterThan(1e-4), reason: 'the fixture must not sit on the grid centre, or this test cannot fail');
  });

  test('editing an existing QSO uses the editing colour for the marker and line', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}, isEditing: true));
    expect(result.markers.single.color, editing, reason: 'editing uses the blue/secondary accent');
    expect(result.lines, isNotEmpty);
    expect(result.lines.every((l) => l.color == editing), isTrue);
  });

  test('with an operation grid, the highlight includes a great-circle line, all flagged highlight', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}));
    expect(result.lines, isNotEmpty);
    expect(result.lines.every((l) => l.highlight), isTrue);
    expect(result.lines.every((l) => l.color == composing), isTrue);
  });

  test('without an operation grid there is a marker but no line to draw', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}), grid: null);
    expect(result.markers, hasLength(1));
    expect(result.lines, isEmpty);
  });

  // The GL backends paint in layer-creation order, and there is nothing in the
  // script itself that would fail if that order were disturbed — the symptom is
  // a line quietly passing under a dot, on web and desktop only. Whether the
  // pixels actually land that way is checked in a browser, not here.
  test('the GL script creates the base marker layer before the highlight line', () {
    final added = RegExp(r"ensureLayer\(\w+\('([\w-]+)'").allMatches(mapGlScript).map((match) => match.group(1)).toList();

    expect(added, [
      'polo-lines',
      'polo-marker-pills',
      'polo-markers',
      'polo-lines-highlight',
      'polo-markers-highlight',
      'polo-marker-pills-highlight',
    ], reason: "the current QSO's line has to come after the base markers, dots and pills, or it passes under them");
  });

  // A maplibregl.Marker is a DOM element above the canvas, which no layer can
  // paint over — reaching for one again would undo the layering above.
  test('the GL script draws markers in the canvas, not as DOM overlays', () {
    expect(mapGlScript, isNot(contains('new maplibregl.Marker')));
  });

  test('mapHighlightColor brightens a muted hue without shifting it', () {
    // The theme's light-mode tertiary — a dark, brownish orange.
    const mutedOrange = Color(0xFF964900);
    final bright = mapHighlightColor(mutedOrange);
    final before = HSLColor.fromColor(mutedOrange);
    final after = HSLColor.fromColor(bright);
    expect(after.hue, closeTo(before.hue, 1.0), reason: 'same hue, just brighter');
    expect(after.lightness, greaterThan(before.lightness), reason: 'brighter — the muted orange is dark');
    expect(after.saturation, greaterThanOrEqualTo(before.saturation), reason: 'at least as vivid (forced to full)');
    expect(after.saturation, 1.0);
  });

  // The log steps back behind the current QSO; what the log is about does
  // not. A QTH is where the lines run from, the current QSO's included, and
  // the glyph markers are the operation's own references and location.
  test('only the log dims behind a highlight', () {
    MapMarkerData marker(MapMarkerKind kind, {MapMarkerGlyph? glyph}) =>
        MapMarkerData(id: 'm', latitude: 0, longitude: 0, label: 'X', kind: kind, color: Colors.red, strokeColor: stroke, glyph: glyph);
    final glyph = MapMarkerGlyph(
      icon: const IconData(0xe000),
      color: Colors.green,
      image: MapMarkerImage(id: 'pin', rgba: Uint8List(4), width: 1, height: 1, pixelRatio: 1),
    );
    expect(marker(MapMarkerKind.qso).dimsBehindHighlight, isTrue, reason: 'a contact is the log');
    expect(marker(MapMarkerKind.qth).dimsBehindHighlight, isFalse);
    expect(marker(MapMarkerKind.qso, glyph: glyph).dimsBehindHighlight, isFalse, reason: "a reference pin is the operation's");
    expect(mapMarkersPayload([marker(MapMarkerKind.qth)]).single['steady'], isTrue, reason: 'the GL script reads the rule from the payload');
    expect(mapMarkersPayload([marker(MapMarkerKind.qso)]).single.containsKey('steady'), isFalse);
  });

  // The current QSO has to be findable against a log of hundreds: drawn on
  // top is not enough when its line runs through a fan of others in the same
  // weight of colour, so everything else steps back while it is shown — and
  // only then, or a map with nothing being entered reads as faded out. The
  // QTH is where those lines run from, the current QSO's included, so it is
  // never what steps back.
  group('the OSM backend dims everything but the highlight and the QTH', () {
    final base = (
      marker: MapMarkerData(
        id: 'q1',
        latitude: 40,
        longitude: -74,
        label: 'W1AW',
        kind: MapMarkerKind.qso,
        color: Colors.red,
        strokeColor: stroke,
        popupTitle: 'W1AW',
      ),
      line: MapLineData(id: 'q1/0', points: [const GridLocation(40, -74), const GridLocation(41, -73)], color: Colors.black),
      qth: MapMarkerData(
        id: 'qth-FN31',
        latitude: 41,
        longitude: -73,
        label: 'FN31',
        kind: MapMarkerKind.qth,
        color: Colors.blue,
        strokeColor: stroke,
        popupTitle: 'FN31',
      ),
    );
    final current = build(CallInfoData(call: 'K2ABC', guess: {'grid': 'FN20'}));

    Widget host({required bool highlighted}) => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OsmMapView(
            markers: [base.marker, base.qth, if (highlighted) ...current.markers],
            lines: [base.line, if (highlighted) ...current.lines],
            isDark: false,
          ),
        ),
      ),
    );

    // Product of every Opacity above [layer]: what it is drawn at.
    double strength(WidgetTester tester, Finder layer) {
      var result = 1.0;
      tester.element(layer).visitAncestorElements((ancestor) {
        if (ancestor.widget case final Opacity o) result *= o.opacity;
        return true;
      });
      return result;
    }

    testWidgets('while a QSO is highlighted, only it keeps full strength', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(host(highlighted: true));
        await tester.pump();
        final lineLayers = find.byType(PolylineLayer);
        final markerLayers = find.byType(MarkerLayer);
        expect(tester.widget<MarkerLayer>(markerLayers.last).markers, hasLength(1), reason: 'the fixture must put the highlight in its own layer');

        expect(strength(tester, lineLayers.first), mapDimmedOpacity, reason: "the log's lines step back");
        expect(strength(tester, markerLayers.first), mapDimmedOpacity, reason: "the log's markers step back");
        expect(strength(tester, lineLayers.last), 1.0, reason: "the current QSO's line stays at full strength");
        expect(strength(tester, markerLayers.last), 1.0, reason: "the current QSO's marker stays at full strength");
        final qthLayer = find.byWidgetPredicate((w) => w is MarkerLayer && w.markers.length == 1 && w.markers.single.point.latitude == base.qth.latitude);
        expect(strength(tester, qthLayer), 1.0, reason: 'the QTH the lines run from stays at full strength');
      });
    });

    testWidgets('with nothing highlighted, nothing is dimmed — and the base layer is not remounted to get there', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(host(highlighted: true));
        await tester.pump();
        final dimmed = tester.element(find.byType(MarkerLayer).first);

        await tester.pumpWidget(host(highlighted: false));
        await tester.pump();
        expect(strength(tester, find.byType(PolylineLayer).first), 1.0);
        expect(strength(tester, find.byType(MarkerLayer).first), 1.0);
        // Typing a call toggles this on the first keystroke and off on
        // logging: a tree that only wraps while dimmed rebuilds every
        // contact's marker each time.
        expect(identical(tester.element(find.byType(MarkerLayer).first), dimmed), isTrue);
      });
    });
  });
}
