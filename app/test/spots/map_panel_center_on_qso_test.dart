// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Center on Current QSO (MapPreferences.mapCenterOnQso) off means the camera
// moves only when the operator moves it. Each test runs the same steps with
// the option on and off: on, the map does move, so a test whose fixture
// fails to move the camera cannot pass by accident. The traps are the two
// ways a map moves by itself — following the QSO picked in the logging
// panel, and the backend's own refit when a contact is logged — plus the
// two places holding goes too far: before the first contact, and on another
// view's map pane, which keeps its own setting.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/map_preferences.dart';
import 'package:ham2k_logger/services/settings_service.dart';
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
    'updatedAtMillis': 1,
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

  // From New York: two contacts on the US east coast, and Japan far away.
  final east = [_contact('w1aw', 'FN31'), _contact('k2aa', 'FN30')];
  final japan = _contact('ja1aa', 'PM95');

  Widget host(List<Qso> qsos, {String? selected, MapScope scope = MapScope.operation}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: DockPaneVisibility(
          visible: true,
          child: MapPanel(
            operation: Operation(uuid: 'op-map', data: {'grid': 'FN20ab', 'refs': const []}),
            qsos: qsos,
            settings: settings,
            geoshapes: geoshapes,
            activityControls: const [],
            selectedQsoUuid: selected,
            scope: scope,
          ),
        ),
      ),
    ),
  );

  /// On Linux the pane picks the OSM backend, which renders in a test.
  /// Restored inside the body: the binding checks the override before
  /// tearDown runs.
  Future<void> onLinux(WidgetTester tester, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.runAsync(body);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  (double, double) center(WidgetTester tester) {
    final c = MapCamera.of(tester.element(find.byType(TileLayer).first)).center;
    return (c.latitude, c.longitude);
  }

  /// The highlight camera hands its move to a zero-length timer.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    await tester.pump();
  }

  for (final follows in [true, false]) {
    final option = follows ? 'on' : 'off';

    testWidgets('with Center on Current QSO $option, a contact logged far away ${follows ? 'reframes' : 'leaves'} the camera', (tester) async {
      await onLinux(tester, () async {
        await settings.setMapCenterOnQso(MapScope.operation, follows);
        await tester.pumpWidget(host(east));
        await settle(tester);
        final before = center(tester);

        await tester.pumpWidget(host([...east, japan]));
        await settle(tester);
        if (follows) {
          expect(center(tester), isNot(before), reason: 'the backend refits to a log that grew across the Pacific');
        } else {
          expect(center(tester), before);
        }
      });
    });

    testWidgets('with Center on Current QSO $option, picking a QSO ${follows ? 'frames it' : 'leaves the camera'}', (tester) async {
      await onLinux(tester, () async {
        await settings.setMapCenterOnQso(MapScope.operation, follows);
        await tester.pumpWidget(host([...east, japan]));
        await settle(tester);
        final before = center(tester);

        await tester.pumpWidget(host([...east, japan], selected: 'w1aw'));
        await settle(tester);
        if (follows) {
          expect(center(tester), isNot(before), reason: 'the map frames the picked contact and its line home');
        } else {
          expect(center(tester), before);
        }
      });
    });
  }

  testWidgets('turning the option off mid-session holds the same log, and turning it on lets it go', (tester) async {
    await onLinux(tester, () async {
      // One list throughout: a fresh one would rebuild the markers by itself,
      // and the switch alone would never be seen to re-key them.
      final log = [...east, japan];
      List<String?> keys() => [for (final m in tester.widget<OsmMapView>(find.byType(OsmMapView)).markers) m.fitKey];

      await tester.pumpWidget(host(log, selected: 'w1aw'));
      await settle(tester);
      final framed = center(tester);
      expect(keys(), everyElement(isNull));

      await settings.setMapCenterOnQso(MapScope.operation, false);
      await settle(tester);
      expect(keys(), everyElement('held'));

      await tester.pumpWidget(host(log, selected: 'ja1aa'));
      await settle(tester);
      expect(center(tester), framed);

      await settings.setMapCenterOnQso(MapScope.operation, true);
      await settle(tester);
      expect(keys(), everyElement(isNull));
      expect(center(tester), isNot(framed), reason: 'back on, the map frames the QSO picked meanwhile');
    });
  });

  testWidgets('held from the start, the first contact still frames the log, and only the first', (tester) async {
    await onLinux(tester, () async {
      await settings.setMapCenterOnQso(MapScope.operation, false);
      // Only the operation's own location: a close-up of New York.
      await tester.pumpWidget(host(const []));
      await settle(tester);
      final qth = center(tester);

      await tester.pumpWidget(host([japan]));
      await settle(tester);
      final first = center(tester);
      expect(first, isNot(qth), reason: 'held on the QTH close-up, Japan would be off-screen');

      await tester.pumpWidget(host([japan, ...east]));
      await settle(tester);
      expect(center(tester), first);
    });
  });

  testWidgets("another view's map pane keeps its own setting", (tester) async {
    await onLinux(tester, () async {
      // The Logs view's pane: one contact at a time, framed by the refit
      // alone. Held by the operation's setting, a second pick would stay
      // on the first.
      await settings.setMapCenterOnQso(MapScope.operation, false);
      await tester.pumpWidget(host([east.first], scope: MapScope.logs));
      await settle(tester);
      final before = center(tester);

      await tester.pumpWidget(host([japan], scope: MapScope.logs));
      await settle(tester);
      expect(center(tester), isNot(before));
      expect(settings.mapCenterOnQso(MapScope.logs), isTrue);
    });
  });
}
