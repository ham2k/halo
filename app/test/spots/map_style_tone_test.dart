// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which basemap the markers, strokes and great-circle lines have to contrast
// against. The trap: reading the app's own dark mode instead — light markers
// on Positron's pale tiles, or dark ones on Dark Matter, are invisible.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/settings_service.dart' show MapStyle, SettingsService;
import 'package:ham2k_logger/views/map/map_gl_script.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

const _park = {
  'type': 'pota',
  'ref': 'US-0001',
  'shortLabel': 'POTA US-0001',
  'lat': 40.0,
  'lon': -75.0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only the automatic style follows the app theme', () {
    expect(mapStyleIsDark(MapStyle.automatic, appIsDark: true), isTrue);
    expect(mapStyleIsDark(MapStyle.automatic, appIsDark: false), isFalse);
  });

  test('Dark Matter is dark even while the app is in light mode', () {
    expect(mapStyleIsDark(MapStyle.darkMatter, appIsDark: false), isTrue);
    expect(mapStyleIsDark(MapStyle.darkMatter, appIsDark: true), isTrue);
  });

  test('every other pinned style is light even while the app is in dark mode', () {
    for (final style in [MapStyle.liberty, MapStyle.bright, MapStyle.positron, MapStyle.voyager]) {
      expect(mapStyleIsDark(style, appIsDark: true), isFalse, reason: style.name);
      expect(mapStyleIsDark(style, appIsDark: false), isFalse, reason: style.name);
    }
  });

  // The classifier above is only half the fix — the bug was in the wiring,
  // and every call site can be reverted to `theme.brightness` with the rest
  // of the suite still green. Pumped on Linux, where the backend is the OSM
  // one, whose own tile source hangs off the same flag.
  testWidgets('a pinned dark basemap gets light markers while the app is in light mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setMapStyle(MapStyle.darkMatter);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: ActivitiesResultsMap(
              suggestions: const [_park],
              controls: const [],
              refs: const [],
              settings: settings,
              onAdd: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final map = tester.widget<OsmMapView>(find.byType(OsmMapView));
      expect(map.isDark, isTrue, reason: 'the basemap is Dark Matter, whatever the app theme says');
      expect(map.markers.first.strokeColor, const Color(0xFFF2F2F2),
          reason: 'a dark ring on dark tiles is the marker disappearing');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
