// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What gets a dot on the results map, and which of the two builders draws
// it. `activitySuggestionMarkers` plots what is NOT on the operation yet:
// entries with no resolvable location are dropped rather than plotted at
// some default one, an exact lat/lon wins over the grid square's center when
// both are present, and an already-added ref is dropped whichever list it
// came from — because `activitySelectedRefMarkers` draws it instead, in its
// reference type's own icon, and two dots on one point read as two
// references.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_marker_icon.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

void main() {
  const controls = <Map<String, dynamic>>[];
  const defaultColor = Colors.blue;
  const strokeColor = Colors.black;

  test('drops a suggestion with no grid', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234'},
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    expect(markers, isEmpty);
  });

  test('drops a suggestion whose grid does not decode', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'not-a-grid'},
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    expect(markers, isEmpty);
  });

  test('plots a suggestion with a valid grid, at full color when not on the operation', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    expect(markers, hasLength(1));
    expect(markers.single.color, defaultColor);
    expect(markers.single.id, 'ref-pota/K-1234');
  });

  test('drops an already-added suggestion, whichever list it came from, once its ref marker covers it', () {
    final suggestion = {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'};
    final refs = [
      {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
    ];
    final markers = activitySuggestionMarkers([suggestion], controls: controls, refs: refs, defaultColor: defaultColor, strokeColor: strokeColor);
    // The list keeps a search hit (faded) and drops a nearby dupe; the map
    // makes no such distinction, because what decides it here is whether the
    // point is already carrying the selected-ref marker below.
    expect(markers, isEmpty);
    expect(
      activitySelectedRefMarkers(refs, controls: controls, defaultColor: defaultColor, strokeColor: strokeColor, glyphFor: (_, _) => null),
      hasLength(1),
      reason: 'dropping it from the suggestions is only safe while this one is drawn',
    );
  });

  test('KEEPS an already-added suggestion when the stored ref has no location to draw', () {
    // The two builders read different maps: the drop is keyed on type+ref,
    // the selected-ref marker on the STORED ref's own location. A reference
    // saved without one (hand-typed, or a form activity nothing geo-decorated)
    // is drawn by neither if the drop ignores that — and it is the search
    // result, not the stored ref, that knows where it is.
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      refs: [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234'},
      ],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    expect(markers, hasLength(1), reason: 'otherwise this reference has no dot on the map at all');
    expect(
      markers.single.color,
      defaultColor.withValues(alpha: 0.4),
      reason: 'at full strength it reads as addable, which its card — offering no Add — contradicts',
    );
  });

  test('a selected ref is identified by what it is, not where it sits in the list', () {
    // A positional id would leave an open reveal card pointing at whichever
    // reference slid into the index when the operator deleted a row above
    // the map.
    final markers = activitySelectedRefMarkers(
      [
        {'type': 'wwff', 'ref': 'KFF-1', 'shortLabel': 'KFF-1', 'grid': 'FN21ab'},
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      defaultColor: defaultColor,
      strokeColor: strokeColor,
      glyphFor: (_, _) => null,
    );
    expect(markers.map((m) => m.id), ['ref-wwff/KFF-1', 'ref-pota/K-1234']);
    expect(markers.first.color, defaultColor);
  });

  test('a selected ref with no resolvable location is dropped, not plotted at a default one', () {
    expect(
      activitySelectedRefMarkers(
        [
          {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234'},
        ],
        controls: controls,
        defaultColor: defaultColor,
        strokeColor: strokeColor,
        glyphFor: (_, _) => null,
      ),
      isEmpty,
    );
  });

  test('a ref whose glyph has not finished rasterizing still gets its dot', () {
    // The pixels arrive a frame or two late (renderMarkerIconImage goes
    // through the engine); a reference must not blink out of the map while
    // they do.
    final markers = activitySelectedRefMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      defaultColor: defaultColor,
      strokeColor: strokeColor,
      glyphFor: (_, _) => null,
    );
    expect(markers.single.glyph, isNull);
    expect(markers.single.color, defaultColor, reason: 'the plain dot still says which program it is');
  });

  test('a rasterized glyph reaches the marker, and crosses to the GL backends as its bytes', () {
    final glyph = MapMarkerGlyph(
      icon: MdiIcons.pineTree,
      color: Colors.white,
      image: MapMarkerImage(id: 'glyph-test', rgba: Uint8List.fromList(const [1, 2, 3, 4]), width: 1, height: 1, pixelRatio: 2),
    );
    final markers = activitySelectedRefMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      defaultColor: defaultColor,
      strokeColor: strokeColor,
      glyphFor: (_, _) => glyph,
    );
    expect(markers.single.glyph, same(glyph));

    // The wire format both GL backends parse: without the image block the
    // marker silently falls back to a plain circle on every platform but
    // Linux, and nothing on the Dart side would notice.
    final payload = mapMarkersPayload(markers);
    expect(payload.single['image'], {
      'id': 'glyph-test',
      'rgba': base64Encode(Uint8List.fromList(const [1, 2, 3, 4])),
      'width': 1,
      'height': 1,
      'pixelRatio': 2.0,
    });
  });

  test('a marker with no glyph carries no image block, so the backends draw their circle', () {
    final payload = mapMarkersPayload(
      activitySelectedRefMarkers(
        [
          {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
        ],
        controls: controls,
        defaultColor: defaultColor,
        strokeColor: strokeColor,
        glyphFor: (_, _) => null,
      ),
    );
    expect(payload.single.containsKey('image'), isFalse);
  });

  test('two icon fonts sharing a code point get different image ids', () async {
    // resolveIconName mints IconData in MDI and FontAwesome alike, so a code
    // point alone is not an identity — and the GL side skips registration
    // when it already holds the id, which would draw the wrong glyph for the
    // rest of the session.
    const codePoint = 0xf0100;
    final mdi = await renderMarkerIconImage(
      icon: const IconData(codePoint, fontFamily: 'MaterialDesignIcons'),
      background: Colors.green,
      foreground: Colors.white,
      strokeColor: strokeColor,
      devicePixelRatio: 1,
    );
    final fontAwesome = await renderMarkerIconImage(
      icon: const IconData(codePoint, fontFamily: 'FontAwesome6Solid'),
      background: Colors.green,
      foreground: Colors.white,
      strokeColor: strokeColor,
      devicePixelRatio: 1,
    );
    expect(mdi.id, isNot(fontAwesome.id));
  });

  test('a rasterized marker is exactly width * height * 4 bytes, at the size it claims', () {
    // addImage rejects a size mismatch outright, and the fallback that
    // catches it is indistinguishable from "this platform has no glyphs".
    return renderMarkerIconImage(
      icon: MdiIcons.pineTree,
      background: Colors.green,
      foreground: Colors.white,
      strokeColor: strokeColor,
      devicePixelRatio: 3,
    ).then((image) {
      expect(image.rgba.length, image.width * image.height * 4);
      expect(image.width / image.pixelRatio, markerIconDiameter);
    });
  });

  test('prefers an exact lat/lon over the grid center when both are present', () {
    final markers = activitySuggestionMarkers(
      [
        {
          'type': 'pota',
          'ref': 'K-1234',
          'shortLabel': 'K-1234',
          // FN21ab decodes to a different point than the exact coordinate
          // below — if the exact one wins, the marker lands there instead.
          'grid': 'FN21ab',
          'lat': 41.0,
          'lon': -74.0,
        },
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    expect(markers, hasLength(1));
    expect(markers.single.latitude, 41.0);
    expect(markers.single.longitude, -74.0);
  });

  test('falls back to the grid center when lat/lon are missing or not numbers', () {
    final gridCenter = gridToLocation('FN21ab')!;
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1', 'shortLabel': 'K-1', 'grid': 'FN21ab', 'lat': 'not-a-number'},
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    expect(markers, hasLength(1));
    // The exact grid center, not merely "not the lat/lon we tried to
    // reject" — a fallback that quietly landed on some other coordinate
    // (e.g. a zero default) would pass a looser assertion.
    expect(markers.single.latitude, closeTo(gridCenter.latitude, 1e-9));
    expect(markers.single.longitude, closeTo(gridCenter.longitude, 1e-9));
  });

  test('a marker is named by its reference, not its place in the list, and drawn once', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1', 'shortLabel': 'K-1'},
        {'type': 'pota', 'ref': 'K-2', 'shortLabel': 'K-2', 'grid': 'FN21ab'},
        {'type': 'pota', 'ref': 'K-2', 'shortLabel': 'K-2 again', 'grid': 'FN21ab'},
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
    );
    // By position, a list re-ranked under an open card would re-point it at
    // whichever park moved into its place.
    expect(markers.map((marker) => marker.id), ['ref-pota/K-2']);
  });
}
