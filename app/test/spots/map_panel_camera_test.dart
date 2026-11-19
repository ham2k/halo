// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A map pane's Map Movements (MapMovement) say how it moves to the current
// QSO, and its Map Framing (MapFraming) what it shows with none. Each test
// sets up a move the other options would make, so a test whose fixture fails
// to move the camera cannot pass by accident. The traps: a "center" that
// zooms, a "zoom" that does not, a framing that the backend's own refit to
// the log undoes as soon as a contact is logged, a frame that is not given
// back when the QSO is put down, and "don't change" holding a close-up of
// the operation's QTH before its first contact.

import 'dart:math' as math;

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
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_frames.dart';
import 'package:ham2k_logger/views/map/map_pane_config.dart';
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
  final japanAt = gridToLocation('PM95')!;

  Widget host(
    List<Qso> qsos, {
    String? selected,
    MapMovement movement = MapMovement.zoomLine,
    MapFraming framing = MapFraming.allQsos,
    String? ourEntityPrefix,
  }) => TranslationProvider(
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
            options: MapPaneOptions(movement: movement, framing: framing),
            ourEntityPrefix: ourEntityPrefix,
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

  MapCamera camera(WidgetTester tester) => MapCamera.of(tester.element(find.byType(TileLayer).first));
  (double, double) center(WidgetTester tester) => (camera(tester).center.latitude, camera(tester).center.longitude);

  /// The highlight camera hands its move to a zero-length timer.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    await tester.pump();
  }

  /// Whether the camera shows [box]'s middle — on the map's projection,
  /// where a degree of latitude grows toward the poles.
  Matcher middleOf(MapBox box) {
    double y(double latitude) => math.log(math.tan(math.pi / 4 + latitude * math.pi / 360));
    final middle = (2 * math.atan(math.exp((y(box.south) + y(box.north)) / 2)) - math.pi / 2) * 180 / math.pi;
    return isA<(double, double)>()
        .having((c) => c.$1, 'latitude', closeTo(middle, 1))
        .having((c) => c.$2, 'longitude', closeTo(((box.west + box.east) / 2 + 540) % 360 - 180, 1));
  }

  final atJapan = isA<(double, double)>()
      .having((c) => c.$1, 'latitude', closeTo(japanAt.latitude, 0.2))
      .having((c) => c.$2, 'longitude', closeTo(japanAt.longitude, 0.2));

  group('Map Movements', () {
    for (final movement in [MapMovement.zoomLine, MapMovement.none]) {
      testWidgets('${movement.name}: picking a QSO ${movement == MapMovement.none ? 'leaves the camera' : 'frames it'}', (tester) async {
        await onLinux(tester, () async {
          await tester.pumpWidget(host([...east, japan], movement: movement));
          await settle(tester);
          final before = center(tester);

          await tester.pumpWidget(host([...east, japan], selected: 'w1aw', movement: movement));
          await settle(tester);
          if (movement == MapMovement.none) {
            expect(center(tester), before);
          } else {
            expect(center(tester), isNot(before), reason: 'the map frames the picked contact and its line home');
          }
        });
      });
    }

    testWidgets('zoomLocation: picking a QSO closes in on the region around it', (tester) async {
      await onLinux(tester, () async {
        await tester.pumpWidget(host([...east, japan], movement: MapMovement.zoomLocation));
        await settle(tester);
        await tester.pumpWidget(host([...east, japan], selected: 'ja1aa', movement: MapMovement.zoomLocation));
        await settle(tester);
        expect(center(tester), atJapan);
        final shown = camera(tester).visibleBounds;
        expect(shown.east - shown.west, inInclusiveRange(5, 15), reason: 'the region around Japan, some 550 km, not the log');
      });
    });

    for (final movement in [MapMovement.centerLocation, MapMovement.centerLine]) {
      testWidgets('${movement.name}: picking a QSO moves the map to it, at the zoom it was at', (tester) async {
        await onLinux(tester, () async {
          await tester.pumpWidget(host([...east, japan], movement: movement));
          await settle(tester);
          final zoom = camera(tester).zoom;

          await tester.pumpWidget(host([...east, japan], selected: 'ja1aa', movement: movement));
          await settle(tester);
          expect(camera(tester).zoom, zoom);
          final (latitude, longitude) = center(tester);
          if (movement == MapMovement.centerLocation) {
            expect((latitude, longitude), atJapan);
          } else {
            // Between Japan and New York, on the line's own box.
            expect(longitude, isNot(closeTo(japanAt.longitude, 1)));
            expect(latitude, greaterThan(japanAt.latitude), reason: 'the line runs north, over the pole side');
          }
        });
      });
    }
  });

  testWidgets('centerLocation: a contact logged while a QSO is picked leaves the map on the pick', (tester) async {
    await onLinux(tester, () async {
      await tester.pumpWidget(host(east, selected: 'w1aw', movement: MapMovement.centerLocation));
      await settle(tester);
      final picked = center(tester);

      // The log grows across the Pacific: the backend's own fit would frame it.
      await tester.pumpWidget(host([...east, japan], selected: 'w1aw', movement: MapMovement.centerLocation));
      await settle(tester);
      expect(center(tester), picked);
    });
  });

  group('Map Framing', () {
    for (final framing in [MapFraming.allQsos, MapFraming.none]) {
      testWidgets('${framing.name}: a contact logged far away ${framing == MapFraming.none ? 'leaves' : 'reframes'} the camera', (tester) async {
        await onLinux(tester, () async {
          await tester.pumpWidget(host(east, framing: framing));
          await settle(tester);
          final before = center(tester);

          await tester.pumpWidget(host([...east, japan], framing: framing));
          await settle(tester);
          if (framing == MapFraming.none) {
            expect(center(tester), before);
          } else {
            expect(center(tester), isNot(before), reason: 'the backend refits to a log that grew across the Pacific');
          }
        });
      });
    }

    testWidgets('none: held from the start, the first contact still frames the log, and only the first', (tester) async {
      await onLinux(tester, () async {
        // Only the operation's own location: a close-up of New York.
        await tester.pumpWidget(host(const [], framing: MapFraming.none));
        await settle(tester);
        final qth = center(tester);

        await tester.pumpWidget(host([japan], framing: MapFraming.none));
        await settle(tester);
        final first = center(tester);
        expect(first, isNot(qth), reason: 'held on the QTH close-up, Japan would be off-screen');

        await tester.pumpWidget(host([japan, ...east], framing: MapFraming.none));
        await settle(tester);
        expect(center(tester), first);
      });
    });

    testWidgets('world: frames the world, and holds it as contacts are logged', (tester) async {
      await onLinux(tester, () async {
        await tester.pumpWidget(host(east, framing: MapFraming.world));
        await settle(tester);
        expect(center(tester), middleOf(worldBox));

        await tester.pumpWidget(host([...east, japan], framing: MapFraming.world));
        await settle(tester);
        expect(center(tester), middleOf(worldBox), reason: "the backend's own refit to the log stands aside");
      });
    });

    testWidgets("country and continent: frame the operator's entity's box, or its continent's", (tester) async {
      await onLinux(tester, () async {
        await tester.pumpWidget(host(east, framing: MapFraming.country, ourEntityPrefix: 'K'));
        await settle(tester);
        final k = entityBounds['K']!;
        expect(center(tester), middleOf((south: k.south, west: k.west, north: k.north, east: k.east)));

        await tester.pumpWidget(host(east, framing: MapFraming.continent, ourEntityPrefix: 'K'));
        await settle(tester);
        expect(center(tester), middleOf(continentBoxes['NA']!));

        // Guantanamo Bay has no land of its own in the bounds; its continent
        // does not depend on it.
        expect(entityBounds['KG4'], isNull, reason: 'the fixture must be an entity without a box, or this cannot fail');
        await tester.pumpWidget(host([...east, japan], framing: MapFraming.continent, ourEntityPrefix: 'KG4'));
        await settle(tester);
        expect(center(tester), middleOf(continentBoxes['NA']!));
      });
    });

    testWidgets('a country framing follows a new entity', (tester) async {
      await onLinux(tester, () async {
        final log = [...east, japan];
        await tester.pumpWidget(host(log, framing: MapFraming.country, ourEntityPrefix: 'DL'));
        await settle(tester);
        final dl = entityBounds['DL']!;
        expect(center(tester), middleOf((south: dl.south, west: dl.west, north: dl.north, east: dl.east)));

        await tester.pumpWidget(host(log, framing: MapFraming.country, ourEntityPrefix: 'K'));
        await settle(tester);
        final k = entityBounds['K']!;
        expect(center(tester), middleOf((south: k.south, west: k.west, north: k.north, east: k.east)));
      });
    });

    testWidgets('country: with no entity to fit, frames the log', (tester) async {
      await onLinux(tester, () async {
        await tester.pumpWidget(host([...east, japan]));
        await settle(tester);
        final log = center(tester);
        await tester.pumpWidget(const SizedBox());

        await tester.pumpWidget(host([...east, japan], framing: MapFraming.country));
        await settle(tester);
        expect(center(tester), log);
      });
    });

    testWidgets('putting a picked QSO down gives the framing back', (tester) async {
      await onLinux(tester, () async {
        await tester.pumpWidget(host([...east, japan], framing: MapFraming.world));
        await settle(tester);
        await tester.pumpWidget(host([...east, japan], selected: 'ja1aa', framing: MapFraming.world));
        await settle(tester);
        expect(center(tester), isNot(middleOf(worldBox)), reason: 'the pick moved the map, or this test cannot fail');

        await tester.pumpWidget(host([...east, japan], framing: MapFraming.world));
        await settle(tester);
        expect(center(tester), middleOf(worldBox));
      });
    });

    testWidgets("switching to don't-change mid-session holds the same log, and switching back lets it go", (tester) async {
      await onLinux(tester, () async {
        // One list throughout: a fresh one would rebuild the markers by
        // itself, and the switch alone would never be seen to re-key them.
        final log = [...east, japan];
        List<String?> keys() => [for (final m in tester.widget<OsmMapView>(find.byType(OsmMapView)).markers) m.fitKey];

        await tester.pumpWidget(host(log, selected: 'w1aw'));
        await settle(tester);
        final framed = center(tester);
        expect(keys(), everyElement(isNull));

        await tester.pumpWidget(host(log, selected: 'w1aw', movement: MapMovement.none, framing: MapFraming.none));
        await settle(tester);
        expect(keys(), everyElement('held'));

        await tester.pumpWidget(host(log, selected: 'ja1aa', movement: MapMovement.none, framing: MapFraming.none));
        await settle(tester);
        expect(center(tester), framed);

        await tester.pumpWidget(host(log, selected: 'ja1aa'));
        await settle(tester);
        expect(keys(), everyElement(isNull));
        expect(center(tester), isNot(framed), reason: 'back on, the map frames the QSO picked meanwhile');
      });
    });

    testWidgets('a framing picked mid-session shows at once', (tester) async {
      await onLinux(tester, () async {
        final log = [...east, japan];
        await tester.pumpWidget(host(log));
        await settle(tester);
        expect(center(tester), isNot(middleOf(worldBox)), reason: 'the log, or this test cannot fail');

        await tester.pumpWidget(host(log, framing: MapFraming.world));
        await settle(tester);
        expect(center(tester), middleOf(worldBox));
      });
    });
  });
}
