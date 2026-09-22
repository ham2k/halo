// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The GL backends send the map a patch — what changed by id — instead of the
// whole set on every emission. What these pin down is the rule that decides
// between the two, and that the patch names exactly what a merge on the far
// side needs: a patch that misses a removal leaves a deleted contact's line
// on the map; one that misses a changed marker leaves a stale popup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';

MapLineData _line(String id, {double lat = 40, Color color = Colors.black}) =>
    MapLineData(id: id, points: [GridLocation(lat, -74), GridLocation(41, -73)], color: color);

MapMarkerData _marker(String id, {String title = 'W1AW'}) => MapMarkerData(
  id: id,
  latitude: 40,
  longitude: -74,
  label: 'W1AW',
  kind: MapMarkerKind.qso,
  color: Colors.red,
  strokeColor: Colors.black,
  popupTitle: title,
);

void main() {
  group('diffById', () {
    test('an appended entry is one upsert and nothing removed', () {
      final before = [_line('a/0'), _line('b/0')];
      final diff = diffLines(before, [...before, _line('c/0')]);
      expect(diff.upserts.map((l) => l.id), ['c/0']);
      expect(diff.removeIds, isEmpty);
    });

    test('a dropped entry is a removal; an unchanged one is neither', () {
      final diff = diffLines([_line('a/0'), _line('b/0')], [_line('b/0')]);
      expect(diff.upserts, isEmpty);
      expect(diff.removeIds, ['a/0']);
    });

    test('a line that moved is replaced; one that merely changed position in the list is not', () {
      final a = _line('a/0');
      final b = _line('b/0');
      final diff = diffLines([a, b], [b, _line('a/0', lat: 45)]);
      expect(diff.upserts.map((l) => l.id), ['a/0']);
      expect(diff.removeIds, isEmpty);
    });

    // Marker equality is every field, so a re-worded popup is a change even
    // though the dot has not moved.
    test('a marker whose popup changed is replaced', () {
      final diff = diffMarkers([_marker('q1')], [_marker('q1', title: 'W1AW • 120 km')]);
      expect(diff.upserts.map((m) => m.id), ['q1']);
    });

    test('a new list instance with the same contents is an empty diff', () {
      final diff = diffLines([_line('a/0')], [_line('a/0')]);
      expect(diff.upserts, isEmpty);
      expect(diff.removeIds, isEmpty);
    });

    // The far side inserts a new entry at its index and replaces a changed one
    // in place, which reproduces the host's list only if the entries both
    // lists share kept their order.
    test('a new entry carries its index; unchanged entries that moved make the diff unpatchable', () {
      final a = _line('a/0');
      final c = _line('c/0');
      final mid = diffLines([a, c], [a, _line('b/0'), c]);
      expect(mid.upserts.map((l) => l.id), ['b/0']);
      expect(mid.indices, [1]);
      expect(mid.orderKept, isTrue);

      final reordered = diffLines([a, c], [c, a, _line('b/0')]);
      expect(reordered.orderKept, isFalse, reason: 'a and c swapped: a patch cannot say so');
      expect(patchIsSmaller(reordered, total: 3), isFalse);
    });
  });

  group('patchIsSmaller', () {
    test('one changed line in thousands is a patch; the first paint and a recolouring are sets', () {
      final many = [for (var i = 0; i < 1000; i++) _line('$i/0')];
      expect(patchIsSmaller(diffLines(many, [...many, _line('new/0')]), total: 1001), isTrue);
      expect(patchIsSmaller(diffLines(const [], many), total: many.length), isFalse, reason: 'first paint');
      final recoloured = [for (final l in many) _line(l.id, color: Colors.white)];
      expect(patchIsSmaller(diffLines(many, recoloured), total: many.length), isFalse, reason: 'every line changed');
      expect(patchIsSmaller(diffLines(many, many), total: many.length), isFalse, reason: 'nothing changed: nothing to send at all');
    });
  });

  group('patch payloads', () {
    test('lines travel with the id the far side merges by, and removals as ids', () {
      final payload = mapLinesPatchPayload((upserts: [_line('a/0')], indices: [0], removeIds: ['b/0'], orderKept: true));
      final feature = (payload['upsert'] as List).single as Map;
      expect((feature['properties'] as Map)['id'], 'a/0');
      expect(payload['removeIds'], ['b/0']);
      expect(payload['indices'], [0]);
      // The full set carries the same id, so a set and a later patch merge.
      expect(((mapLinesPayload([_line('a/0')])['features'] as List).single as Map)['properties'], containsPair('id', 'a/0'));
    });

    test('markers travel in the set\'s own wire shape', () {
      final payload = mapMarkersPatchPayload((upserts: [_marker('q1')], indices: [0], removeIds: const [], orderKept: true));
      expect(((payload['upsert'] as List).single as Map)['id'], 'q1');
      expect(payload['removeIds'], isEmpty);
    });
  });
}
