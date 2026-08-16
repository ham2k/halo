// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The results map's "you are here" dot: it must be the exact color the
// search band's location pill is showing (green GPS, dark gray manual —
// see activities_view.dart's `currentLocation`/`locationColor`), and it
// must not appear at all when the caller has no location to give it —
// showing a dot with a made-up color would tell the operator "you are
// located" when the pill right above says otherwise.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _parkSuggestion = {
  'type': 'pota',
  'ref': 'US-0001',
  'shortLabel': 'POTA US-0001',
  'grid': 'FN31pr',
};

Widget _harness(Widget child) => TranslationProvider(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plots a dot for the current location, in the given color', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    const green = Color(0xFF1B5E20);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(_harness(ActivitiesResultsMap(
        suggestions: const [_parkSuggestion],
        controls: const [],
        refs: const [],
        settings: settings,
        onAdd: (_) {},
        suggestionsAreSearchResults: false,
        currentLocation: const GridLocation(41.0, -74.0),
        currentLocationColor: green,
      )));
      await tester.pumpAndSettle();

      final markers = tester.widget<OsmMapView>(find.byType(OsmMapView)).markers;
      final dot = markers.singleWhere((m) => m.id == 'current-location');
      expect(dot.color, green);
      expect(dot.latitude, 41.0);
      expect(dot.longitude, -74.0);
      // The park suggestion is still there too — the dot is additional, not
      // a replacement.
      expect(markers, hasLength(2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('no dot when there is no current location to show', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(_harness(ActivitiesResultsMap(
        suggestions: const [_parkSuggestion],
        controls: const [],
        refs: const [],
        settings: settings,
        onAdd: (_) {},
        suggestionsAreSearchResults: false,
      )));
      await tester.pumpAndSettle();

      final markers = tester.widget<OsmMapView>(find.byType(OsmMapView)).markers;
      expect(markers.where((m) => m.id == 'current-location'), isEmpty);
      expect(markers, hasLength(1), reason: 'just the park suggestion');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
