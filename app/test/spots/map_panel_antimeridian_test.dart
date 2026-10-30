// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where the Map pane's camera counts a contact whose great-circle line to
// the QTH crosses the antimeridian. Counted where it is drawn, the frame
// takes in the world the other way round and cuts that line at one edge,
// carrying the rest in from the other; counted a turn round, on the side
// its line arrives from, the frame takes the line in whole.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';

import '../support/map_tile_cache.dart';

Qso _contact(String uuid, String grid) => Qso(
  uuid: uuid,
  operationUuid: 'op-map',
  data: {
    'uuid': uuid,
    'their': {'call': uuid.toUpperCase(), 'grid': grid},
    'band': '20m',
    'mode': 'SSB',
    'startAtMillis': 1000,
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempMapTileCache();

  late HaLoDatabase db;
  late SettingsService settings;
  late GeoshapeService geoshapes;
  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    geoshapes = GeoshapeService(extensions: ExtensionService(), lookups: LookupRepository(db));
  });
  tearDown(() => db.close());

  testWidgets('a contact whose line crosses the antimeridian counts on its QTH\'s side of it', (tester) async {
    // On Linux the pane picks the OSM backend, which renders in a test.
    // Restored inside the body: the binding checks the override before
    // tearDown runs.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      // From New York, Japan is reached westward across the Pacific, and
      // England eastward across the Atlantic.
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: MapPanel(
                operation: Operation(uuid: 'op-map', data: {'grid': 'FN20ab', 'refs': const []}),
                qsos: [_contact('ja', 'PM95'), _contact('g', 'JO01')],
                settings: settings,
                geoshapes: geoshapes,
                activityControls: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final backend = tester.widget<OsmMapView>(find.byType(OsmMapView));
      MapMarkerData marker(String id) => backend.markers.singleWhere((m) => m.id == id);
      expect(backend.lines.where((l) => l.id.startsWith('ja/')), hasLength(2), reason: 'the fixture must cross the antimeridian, or this test cannot fail');

      final ja = marker('ja');
      expect(ja.fitLongitude, ja.longitude - 360);
      expect(marker('g').fitLongitude, isNull, reason: 'a line that crosses nothing leaves the frame where it always was');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
