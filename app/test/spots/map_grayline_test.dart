// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The grayline's caps are built from the sun's position and checked here
// against the sun's altitude worked out independently, point by point. The
// traps are the ones a polygon on a flat map sets: a cap that holds a pole
// closed round the wrong side of it shades the day instead, one carried
// across ±180 wrongly tears in two, and a cap that holds neither pole (any
// twilight near an equinox) must not be closed along one. Then the Map pane:
// the setting turns it on without a new map, and it moves with the clock.

import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/geoshape_service.dart';
import 'package:ham2k_logger/services/map_preferences.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_grayline.dart';
import 'package:ham2k_logger/views/map/osm_map_view.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';

import '../support/map_tile_cache.dart';

/// The sun's altitude, in degrees, at [lat]/[lon] when it stands over [sun].
double _altitude(GridLocation sun, double lat, double lon) {
  double rad(double degrees) => degrees * math.pi / 180;
  final sin = math.sin(rad(lat)) * math.sin(rad(sun.latitude)) + math.cos(rad(lat)) * math.cos(rad(sun.latitude)) * math.cos(rad(lon - sun.longitude));
  return math.asin(sin) * 180 / math.pi;
}

/// Whether [ring] holds the point, taken at each of its copies a world apart:
/// a cap's longitudes run on past ±180.
bool _inside(List<GridLocation> ring, double lat, double lon) {
  bool at(double x) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.latitude > lat) != (b.latitude > lat) && x < (b.longitude - a.longitude) * (lat - a.latitude) / (b.latitude - a.latitude) + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  return at(lon) || at(lon + 360) || at(lon - 360);
}

void main() {
  group('the sun', () {
    test('stands over the Tropic of Cancer at the June solstice, near Greenwich at noon UTC', () {
      final sun = subsolarPoint(DateTime.utc(2026, 6, 21, 12));
      expect(sun.latitude, closeTo(23.44, 0.1));
      expect(sun.longitude, closeTo(0, 1), reason: 'off by the equation of time alone, a minute or two');
    });

    test('stands over the equator at the March equinox, and the Tropic of Capricorn in December', () {
      expect(subsolarPoint(DateTime.utc(2026, 3, 20, 14, 46)).latitude, closeTo(0, 0.1));
      expect(subsolarPoint(DateTime.utc(2026, 12, 21, 20, 50)).latitude, closeTo(-23.44, 0.1));
    });

    test('moves west fifteen degrees an hour', () {
      final noon = subsolarPoint(DateTime.utc(2026, 9, 1, 12));
      final later = subsolarPoint(DateTime.utc(2026, 9, 1, 15));
      expect(noon.longitude - later.longitude, closeTo(45, 0.1));
    });
  });

  group('the caps', () {
    // Each instant sets a different trap: the solstices hold a pole in every
    // cap, the equinox in none, and noon UTC puts the night across ±180.
    for (final at in [DateTime.utc(2026, 6, 21, 12), DateTime.utc(2026, 12, 21, 3, 30), DateTime.utc(2026, 3, 20, 12), DateTime.utc(2026, 9, 23, 20, 15)]) {
      test('shade exactly where the sun is under each step, at $at', () {
        final sun = subsolarPoint(at);
        final caps = graylineCaps(at);
        expect(caps, hasLength(graylineSunAltitudes.length));
        var checked = 0;
        for (var lat = -80.0; lat <= 80; lat += 5) {
          // Off the round numbers: a cap's ring starts on the meridian
          // through the sun, and a point exactly on an edge is neither in
          // nor out.
          for (var lon = -179.63; lon < 180; lon += 7.5) {
            final altitude = _altitude(sun, lat, lon);
            for (final (step, threshold) in graylineSunAltitudes.indexed) {
              // A ring of straight edges cuts a little inside the curve.
              if ((altitude - threshold).abs() < 1.5) continue;
              checked++;
              expect(_inside(caps[step], lat, lon), altitude < threshold, reason: '$lat/$lon at ${altitude.toStringAsFixed(1)}° against $threshold°');
            }
          }
        }
        expect(checked, greaterThan(2000), reason: 'the margin left most of the Earth to check');
      });
    }

    test('hold the point opposite the sun, and never the point under it', () {
      for (var hour = 0; hour < 24; hour += 5) {
        final at = DateTime.utc(2026, 5, 4, hour);
        final sun = subsolarPoint(at);
        for (final cap in graylineCaps(at)) {
          expect(_inside(cap, -sun.latitude, sun.longitude + 180), isTrue, reason: 'midnight is night, at $at');
          expect(_inside(cap, sun.latitude, sun.longitude), isFalse, reason: 'noon is day, at $at');
        }
      }
    });
  });

  // Without the minute, every rebuild of the pane — one per keystroke in the
  // call field — would hand the map a new instant and a new payload.
  test('a map is handed the minute, the same one all minute long', () {
    expect(graylineInstant(DateTime.utc(2026, 6, 21, 12, 34, 5, 6)), DateTime.utc(2026, 6, 21, 12, 34));
    expect(graylineInstant(DateTime.utc(2026, 6, 21, 12, 34, 59)), graylineInstant(DateTime.utc(2026, 6, 21, 12, 34)));
  });

  // A break marker or a deleted contact after the last real one would move
  // the night to a moment nobody was on the air.
  test("a log's night is its selected contact's, else its last real contact's, to the minute", () {
    Qso at(String uuid, DateTime when, {String band = '20m', bool deleted = false}) =>
        Qso(uuid: uuid, operationUuid: 'op', deleted: deleted, data: {'band': band, 'startAtMillis': when.millisecondsSinceEpoch});
    final last = DateTime.utc(2026, 9, 21, 2, 55, 40);
    final log = [
      at('a', DateTime.utc(2026, 9, 21, 2, 3, 10)),
      at('b', last),
      at('c', DateTime.utc(2026, 9, 21, 1, 30)),
      at('end', DateTime.utc(2026, 9, 21, 3, 10), band: 'event'),
      at('gone', DateTime.utc(2026, 9, 21, 3, 20), deleted: true),
    ];
    expect(graylineAtContact(log), DateTime.utc(2026, 9, 21, 2, 55));
    expect(graylineAtContact(log, selected: 'a'), DateTime.utc(2026, 9, 21, 2, 3));
    expect(graylineAtContact(log, selected: 'not-here'), DateTime.utc(2026, 9, 21, 2, 55), reason: 'a selection off this map is no contact of its own');
    expect(graylineAtContact([at('start', last, band: 'event')]), isNull, reason: 'no contact yet: the caller shades the night outside');
  });

  group('the Map pane', () {
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
    tearDown(() async {
      AppClock.instance.reset();
      await db.close();
    });

    Qso contact(String uuid, DateTime at) => Qso(
      uuid: uuid,
      operationUuid: 'op-map',
      data: {
        'uuid': uuid,
        'their': {'call': 'G0AAA', 'grid': 'JO01aa'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': at.millisecondsSinceEpoch,
      },
    );
    final contacts = [contact('q1', DateTime.utc(2026, 9, 21, 1, 12, 5)), contact('q2', DateTime.utc(2026, 9, 21, 2, 55, 40))];
    final selected = ValueNotifier<String?>(null);

    /// On Linux the pane picks the OSM backend, which renders in a test.
    /// Restored inside the body: the binding checks the override before
    /// tearDown runs.
    Future<void> onLinux(WidgetTester tester, Future<void> Function() body, {bool graylineAtContact = false}) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      selected.value = null;
      try {
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: selected,
                  builder: (context, uuid, _) => MapPanel(
                    operation: Operation(uuid: 'op-map', data: const {'grid': 'FN20ab', 'refs': []}),
                    qsos: contacts,
                    settings: settings,
                    geoshapes: geoshapes,
                    selectedQsoUuid: uuid,
                    graylineAtContact: graylineAtContact,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await body();
        // The minute's timer goes with the pane.
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    DateTime? shading(WidgetTester tester) => tester.widget<OsmMapView>(find.byType(OsmMapView)).graylineAt;

    testWidgets('shades nothing until the setting is on, then the minute it is, on the map already up', (tester) async {
      await onLinux(tester, () async {
        expect(shading(tester), isNull);
        final map = tester.state(find.byType(OsmMapView));

        await settings.setMapShowGrayline(true);
        await tester.pump();
        // Within a minute rather than equal: the clock may pass a minute
        // between the build and this read.
        expect(nowUtc().difference(shading(tester)!).inMinutes, lessThanOrEqualTo(1));
        expect(tester.state(find.byType(OsmMapView)), same(map), reason: 'a new map for a shade is its tiles and camera thrown away');

        await settings.setMapShowGrayline(false);
        await tester.pump();
        expect(shading(tester), isNull);
      });
    });

    // Travel moves the app clock and tells the minute's listeners at once,
    // so this waits on no timer.
    testWidgets('moves on with the clock', (tester) async {
      await settings.setMapShowGrayline(true);
      await onLinux(tester, () async {
        final first = shading(tester)!;
        AppClock.instance.travel(delta: const Duration(hours: 3));
        await tester.pump();
        expect(shading(tester)!.difference(first).inMinutes, closeTo(180, 1));
      });
    });

    testWidgets("an operation's map holds the night of its last contact, however late it is opened", (tester) async {
      await settings.setMapShowGrayline(true);
      await onLinux(tester, graylineAtContact: true, () async {
        expect(shading(tester), DateTime.utc(2026, 9, 21, 2, 55));
        AppClock.instance.travel(delta: const Duration(hours: 3));
        await tester.pump();
        expect(shading(tester), DateTime.utc(2026, 9, 21, 2, 55));
      });
    });

    testWidgets('a contact picked out in the log brings its own night, and letting it go brings back the last', (tester) async {
      await settings.setMapShowGrayline(true);
      await onLinux(tester, graylineAtContact: true, () async {
        final map = tester.state(find.byType(OsmMapView));
        selected.value = 'q1';
        await tester.pump();
        expect(shading(tester), DateTime.utc(2026, 9, 21, 1, 12));
        expect(tester.state(find.byType(OsmMapView)), same(map));
        selected.value = null;
        await tester.pump();
        expect(shading(tester), DateTime.utc(2026, 9, 21, 2, 55));
      });
    });

    // The Chase View's map picks out contacts too, and shades the night
    // outside: it is the band conditions now that the chaser is after.
    testWidgets('a map not following its contacts shades the night outside whatever is picked out', (tester) async {
      await settings.setMapShowGrayline(true);
      await onLinux(tester, () async {
        selected.value = 'q1';
        await tester.pump();
        expect(nowUtc().difference(shading(tester)!).inMinutes, lessThanOrEqualTo(1));
      });
    });
  });
}
