// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVMAPINFO shows the maps' zoom and viewport size, for tuning the zoom
// thresholds the Activities map acts on. The command is the real dev-commands
// extension; the toggle and the readout are the app's.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_info_box.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';
import 'package:ham2k_logger/views/operation/activities_results_map.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  test('"DEVMAPINFO" (any case) dispatches a devMapInfo action', () async {
    final extensions = ExtensionService();
    await extensions.start();
    for (final input in ['DEVMAPINFO', 'devmapinfo']) {
      final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': input});
      final value = entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map;
      expect((value['commands'] as List).single, {'devMapInfo': {}}, reason: 'for input "$input"');
    }
  });

  test('the command says which way it is about to flip the box', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionService()..settings = settings;
    await extensions.start();
    Future<String> describe() async {
      final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': 'DEVMAPINFO'});
      return (entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map)['describe'] as String;
    }

    expect(await describe(), startsWith('Show'));
    await settings.setDevMapInfo(true);
    expect(await describe(), startsWith('Hide'));
  });

  test('the action flips the setting each time, and says which way it went', () async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();

    final on = await services.handleCommandAction('devMapInfo');
    expect(settings.devMapInfo, isTrue);
    final off = await services.handleCommandAction('devMapInfo');
    expect(settings.devMapInfo, isFalse);
    // The same text both ways would leave the operator guessing.
    expect(on!.text, isNot(off!.text));
  });

  group('mapInfoText', () {
    const view = (south: 40.0, west: -76.0, north: 41.0, east: -75.0);

    test('reads the GL zoom and the view across by up, in the operator\'s units', () {
      final settled = (camera: const MapCameraPosition(latitude: 40.5, longitude: -75.5, zoom: 8.37), bounds: view);
      // One degree of longitude at 40.5°N is ~84.6 km; one of latitude ~111 km.
      expect(mapInfoText(settled, miles: false), 'z 8.4 · 85 × 111 km');
      expect(mapInfoText(settled, miles: true), 'z 8.4 · 53 × 69 mi');
    });

    test('a view across the antimeridian is as wide as it looks, not the rest of the world', () {
      final settled = (camera: const MapCameraPosition(latitude: 0, longitude: 180, zoom: 8), bounds: (south: -0.5, west: 179.5, north: 0.5, east: -179.5));
      expect(mapInfoText(settled, miles: false), 'z 8.0 · 111 × 111 km');
    });

    test('says so before the map has reported', () {
      expect(mapInfoText(null, miles: false), contains('waiting'));
    });
  });

  testWidgets('the Activities map shows the box only while the setting is on', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ActivitiesResultsMap(
                suggestions: const [
                  {'type': 'pota', 'ref': 'US-0001', 'lat': 40.0, 'lon': -75.0},
                ],
                controls: const [],
                refs: const [],
                settings: settings,
                onAdd: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^z \d')), findsNothing);

      await settings.setDevMapInfo(true);
      await tester.pumpAndSettle();
      // The map's own fit has reported by now, so the box has numbers.
      expect(find.textContaining(RegExp(r'^z \d+\.\d · ')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
