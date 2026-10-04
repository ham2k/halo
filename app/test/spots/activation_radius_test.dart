// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A reference's activation radius is a number an extension put on the ref,
// stored on the operation verbatim. Read wrong, the map tells an activator
// they are in range when they are not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/outline_issue_dialog.dart';
import 'package:ham2k_logger/views/map/ref_shapes.dart';

void main() {
  group('activationRadiusMeters', () {
    test('meters win over feet when a reference carries both', () {
      expect(activationRadiusMeters({'activationRadiusInMeters': 500, 'activationRadiusInFeet': 5280}), 500);
    });

    test('feet are converted, not read as meters', () {
      expect(activationRadiusMeters({'activationRadiusInFeet': 1000}), closeTo(304.8, 1e-9));
    });

    test('anything but a positive, finite number is no radius — and falls through to the other unit', () {
      for (final bad in [0, -100, double.nan, double.infinity, '1000', null]) {
        expect(activationRadiusMeters({'activationRadiusInMeters': bad}), isNull, reason: '$bad');
      }
      expect(activationRadiusMeters({'activationRadiusInMeters': 0, 'activationRadiusInFeet': 100}), closeTo(30.48, 1e-9));
    });
  });

  group('activationRadiusShape', () {
    test('traces back to its reference\'s marker, so a tap on it opens that card', () {
      final circle = activationRadiusShape(
        {'type': 'wcaActivation', 'ref': 'F-01234', 'lat': 48.0, 'lon': 2.0, 'activationRadiusInMeters': 1000},
        id: 'ref-wcaActivation/F-01234',
        color: Colors.brown,
      )!;
      expect(markerIdOfShape(circle), 'ref-wcaActivation/F-01234');
    });

    test('a changed radius or a moved reference is a different shape to a map that compares by id', () {
      // A map skips redrawing a list equal to the last one, and shapes are
      // equal by id — so either change left out of it keeps the old circle.
      MapShapeData circle(num meters, {double lat = 48.0}) =>
          activationRadiusShape({'lat': lat, 'lon': 2.0, 'activationRadiusInMeters': meters}, id: 'ref', color: Colors.brown)!;
      expect(circle(1000), isNot(circle(500)));
      expect(circle(1000), isNot(circle(1000, lat: 48.5)));
      expect(markerIdOfShape(circle(1000, lat: 48.5)), 'ref');
    });

    test('is never drawn around a grid square', () {
      expect(activationRadiusShape({'grid': 'JN18eu', 'activationRadiusInMeters': 1000}, id: 'ref', color: Colors.brown), isNull);
    });
  });

  test('an activation radius is not offered for an outline report', () {
    final circle = activationRadiusShape({'lat': 48.0, 'lon': 2.0, 'activationRadiusInMeters': 1000}, id: 'ref-a', color: Colors.brown)!;
    const outline = MapShapeData(
      id: 'ref-b/0',
      rings: [
        [GridLocation(48, 2), GridLocation(48.1, 2), GridLocation(48.1, 2.1), GridLocation(48, 2)],
      ],
      color: Colors.green,
      sourceUrl: 'https://shapes.test/b',
    );
    expect(
      [
        for (final c in outlineIssueCandidates([circle, outline])) c.refId,
      ],
      ['ref-b'],
    );
    // An unpicked suggestion's circle is drawn dashed; losing the flag there
    // would offer it for a report as though it were a fetched outline.
    expect(outlineIssueCandidates([circle.asDashed()]), isEmpty);
  });
}
