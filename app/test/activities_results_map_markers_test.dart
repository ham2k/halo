// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `activitySuggestionMarkers` decides which search/suggestion results get a
// dot on the results map: entries with no resolvable location are dropped
// rather than plotted at some default one, an exact lat/lon wins over the
// grid square's center when both are present, and an already-added ref is
// dropped for a nearby suggestion (same as the list rows — noise) but kept,
// faded, for a search hit (same as the list rows — "not found" would be
// worse than a marked-up dupe).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
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
      suggestionsAreSearchResults: false,
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
      suggestionsAreSearchResults: false,
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
      suggestionsAreSearchResults: false,
    );
    expect(markers, hasLength(1));
    expect(markers.single.color, defaultColor);
    expect(markers.single.id, '0');
  });

  test('fades an already-added suggestion rather than dropping it, for a search hit', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      refs: [
        {'type': 'pota', 'ref': 'K-1234'},
      ],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
      suggestionsAreSearchResults: true,
    );
    expect(markers, hasLength(1));
    expect(markers.single.color, defaultColor.withValues(alpha: 0.4));
  });

  test('drops an already-added NEARBY suggestion instead of plotting noise', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1234', 'shortLabel': 'K-1234', 'grid': 'FN21ab'},
      ],
      controls: controls,
      refs: [
        {'type': 'pota', 'ref': 'K-1234'},
      ],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
      suggestionsAreSearchResults: false,
    );
    expect(markers, isEmpty, reason: 'matches the list rows: a nearby dupe is noise, not a search result');
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
      suggestionsAreSearchResults: false,
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
      suggestionsAreSearchResults: false,
    );
    expect(markers, hasLength(1));
    // The exact grid center, not merely "not the lat/lon we tried to
    // reject" — a fallback that quietly landed on some other coordinate
    // (e.g. a zero default) would pass a looser assertion.
    expect(markers.single.latitude, closeTo(gridCenter.latitude, 1e-9));
    expect(markers.single.longitude, closeTo(gridCenter.longitude, 1e-9));
  });

  test('marker id is the index into suggestions, skipping unlocatable entries', () {
    final markers = activitySuggestionMarkers(
      [
        {'type': 'pota', 'ref': 'K-1', 'shortLabel': 'K-1'},
        {'type': 'pota', 'ref': 'K-2', 'shortLabel': 'K-2', 'grid': 'FN21ab'},
      ],
      controls: controls,
      refs: const [],
      defaultColor: defaultColor,
      strokeColor: strokeColor,
      suggestionsAreSearchResults: false,
    );
    expect(markers, hasLength(1));
    expect(markers.single.id, '1');
  });
}
