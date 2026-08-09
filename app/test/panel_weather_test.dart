// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The weather pane's states, and what it does and does not put on the wire.
//
// The fetch is injected, so nothing here opens a socket. That is not only
// about speed: the two failure states an operator is told apart — the service
// never answered versus answered with nonsense — are unreachable from a test
// that depends on the real Open-Meteo being down in a particular way.
//
// Fixtures are built around the real clock rather than a pinned instant, so
// nothing here rots on a future run. What the HOURS mean is pinned instead in
// panel_weather_reading_test.dart, which needs no widget.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/weather/weather_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_panel_extensions.dart';

void main() {
  final t = AppLocale.en.buildSync().operation.layout.panels;

  const fields = [
    {'type': 'field', 'key': weatherLocationKey, 'fieldType': 'text'},
  ];

  // Kathmandu's offset: not a whole number of hours, and essentially never
  // the machine running the suite. A whole-hour offset would let a truncating
  // bug pass, and the device's own offset would let `toLocal()` pass.
  const offsetSeconds = 5 * 3600 + 45 * 60;

  /// The wall-clock hour at the location, worked out from epoch seconds with
  /// integer arithmetic — deliberately NOT via DateTime's zone facilities,
  /// which are the thing under test.
  String localHourLabel(DateTime utc) {
    final seconds = utc.millisecondsSinceEpoch ~/ 1000 + offsetSeconds;
    return ((seconds ~/ 3600) % 24).toString().padLeft(2, '0');
  }

  String hhmm(DateTime utc) {
    final seconds = utc.millisecondsSinceEpoch ~/ 1000 + offsetSeconds;
    final minutes = (seconds ~/ 60) % 60;
    return '${(seconds ~/ 3600) % 24}'.padLeft(2, '0') + ':${minutes.toString().padLeft(2, '0')}';
  }

  /// The response, laid out around [now] the way Open-Meteo lays one out:
  /// hourly slots on the LOCATION's hour boundaries, running well past the
  /// eight the panel wants.
  ({String body, DateTime firstHour, DateTime sunset}) forecast(
    DateTime now, {
    int? code = 1,
    double temperature = 88.9,
  }) {
    // The location's hour boundaries, which a non-whole offset puts at :15
    // past each UTC hour.
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final firstLocalHourStart = ((epochSeconds + offsetSeconds) ~/ 3600) * 3600 - offsetSeconds;
    // Start a day back, as a real response does — the panel has to find the
    // current hour inside the list rather than assuming it opens there.
    final start = firstLocalHourStart - 24 * 3600;
    final sunset = now.add(const Duration(hours: 1));
    return (
      firstHour: DateTime.fromMillisecondsSinceEpoch(firstLocalHourStart * 1000, isUtc: true),
      sunset: sunset,
      body: jsonEncode({
        'utc_offset_seconds': offsetSeconds,
        'timezone_abbreviation': '+0545',
        'current_units': {'temperature_2m': '°F', 'wind_speed_10m': 'mp/h'},
        'current': {
          'temperature_2m': temperature,
          'relative_humidity_2m': 47,
          'wind_speed_10m': 10.6,
          'wind_gusts_10m': 16.1,
          'wind_direction_10m': 238,
          'weather_code': code,
          'is_day': 1,
        },
        'hourly': {
          'time': [for (var i = 0; i < 72; i++) start + i * 3600],
          'temperature_2m': [for (var i = 0; i < 72; i++) 70 + (i % 12)],
          'weather_code': [for (var i = 0; i < 72; i++) 3],
          'precipitation_probability': [for (var i = 0; i < 72; i++) i % 101],
          'is_day': [for (var i = 0; i < 72; i++) 1],
        },
        'daily': {
          // Only events still ahead, so "the next one" is unambiguous.
          'sunrise': [now.millisecondsSinceEpoch ~/ 1000 + 8 * 3600],
          'sunset': [sunset.millisecondsSinceEpoch ~/ 1000],
        },
      }),
    );
  }

  PanelService serviceWith(FakePanelExtensions extensions) {
    final service = PanelService(extensions);
    service.registerNative(const PanelDefinition(
      id: weatherPanelId,
      title: 'Weather',
      source: PanelSource.native,
      formFields: fields,
    ));
    return service;
  }

  late List<Uri> requested;

  setUp(() => requested = []);

  Future<void> pump(
    WidgetTester tester, {
    Map<String, dynamic>? config,
    String? operationGrid = 'FN42',
    required WeatherFetch fetch,
    bool dockVisible = true,
    Size size = const Size(440, 320),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final service = serviceWith(FakePanelExtensions(configs: {
      if (config != null) weatherPanelId: config,
    }));

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: DockPaneVisibility(
            visible: dockVisible,
            child: WeatherPanel(
              panelId: weatherPanelId,
              panels: service,
              settings: settings,
              operationGrid: operationGrid,
              fetch: fetch,
            ),
          ),
        ),
      ),
    ));
    // Config load, then the fetch it triggers. Deliberately NOT
    // pumpAndSettle: the loading state is a CircularProgressIndicator, which
    // never settles, so a settle here would time out and be reported against
    // whatever ran next.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  WeatherFetch answering(String responseBody, {int status = 200}) => (url) async {
    requested.add(url);
    return (status: status, body: responseBody);
  };

  Future<({int status, String body})> failing(Uri url) async {
    requested.add(url);
    throw const NothingAnswered();
  }

  group('a reading on screen', () {
    testWidgets('shows the current temperature large, over the next eight hours', (tester) async {
      final now = nowUtc();
      final data = forecast(now);
      await pump(tester, fetch: answering(data.body));

      expect(find.text('89°F'), findsOneWidget);
      expect(find.text('Mainly Sunny'), findsOneWidget);
      expect(find.text('+0545'), findsOneWidget);

      // Labelled on the LOCATION's wall clock. Taken from UTC — or from the
      // device via `toLocal()` — these read as a perfectly good panel, which
      // is why the expectation is computed from epoch seconds here rather
      // than from a DateTime.
      for (var i = 0; i < 8; i++) {
        final hour = data.firstHour.add(Duration(hours: i));
        expect(find.text(localHourLabel(hour)), findsOneWidget, reason: 'hour $i');
      }
    });

    testWidgets('shows wind with its gusts and compass point, and humidity', (tester) async {
      // Wide, because the chips are fitted to a MEASURED width and this
      // harness loads no real fonts: every glyph is a full em square, so a
      // pane that fits all three in the app can drop one here. The width is
      // the fixture, not the subject — what fits at a given width is
      // "the chips never wrap" below.
      await pump(tester, fetch: answering(forecast(nowUtc()).body), size: const Size(900, 340));
      expect(find.text('11 mp/h WSW gusts 16'), findsOneWidget);
      expect(find.text('47%'), findsOneWidget);
    });

    testWidgets('the chips never wrap, whatever the pane width', (tester) async {
      // The one property that protects the forecast. The chips sit directly
      // above the curve in a Column, so a run that wraps takes the band the
      // curve was going to get — at a middling pane size that is the whole
      // eight hours gone to make room for a humidity reading.
      for (final width in [900.0, 620.0, 460.0, 360.0, 280.0, 220.0]) {
        await pump(tester, fetch: answering(forecast(nowUtc()).body), size: Size(width, 340));

        final tops = <double>[];
        for (final icon in [
          MdiIcons.weatherWindy,
          MdiIcons.waterPercent,
          MdiIcons.weatherSunsetUp,
          MdiIcons.weatherSunsetDown,
        ]) {
          final found = find.byIcon(icon);
          if (found.evaluate().isNotEmpty) tops.add(tester.getTopLeft(found.first).dy);
        }
        expect(tops.toSet(), hasLength(lessThanOrEqualTo(1)), reason: 'chips wrapped at width $width');

        // And humidity is what goes first. An operator with a mast up cares
        // about wind, then about how long the light lasts; humidity only ever
        // confirms what the sky already said.
        final hasHumidity = find.byIcon(MdiIcons.waterPercent).evaluate().isNotEmpty;
        final hasWind = find.byIcon(MdiIcons.weatherWindy).evaluate().isNotEmpty;
        if (hasHumidity) {
          expect(hasWind, isTrue, reason: 'humidity survived a width that dropped wind ($width)');
        }
      }
    });

    testWidgets('names the next sun event, on the location\'s clock', (tester) async {
      final now = nowUtc();
      final data = forecast(now);
      await pump(tester, fetch: answering(data.body));
      // Sunset is an hour out, sunrise eight — so the one worth the row is
      // the sunset, and it is the sunset that must be shown.
      expect(find.text(hhmm(data.sunset)), findsOneWidget);
    });

    testWidgets('an unknown weather code says so rather than picking a sky', (tester) async {
      await pump(tester, fetch: answering(forecast(nowUtc(), code: 4242).body));
      expect(find.text('Unknown'), findsOneWidget);
    });
  });

  group('nowhere to look', () {
    testWidgets('no operation grid and no override asks for a location, and fetches nothing', (tester) async {
      await pump(tester, operationGrid: null, fetch: answering(forecast(nowUtc()).body));
      expect(find.text(t.weatherNoLocation), findsOneWidget);
      expect(requested, isEmpty);
    });

    testWidgets('an unreadable override is reported against the text typed, and fetches nothing', (tester) async {
      // Falling back to the operation's grid here would show a perfectly good
      // forecast for somewhere the operator did not ask about, with their
      // typo silently ignored.
      await pump(
        tester,
        config: {weatherLocationKey: 'somewhere nice'},
        fetch: answering(forecast(nowUtc()).body),
      );
      expect(find.textContaining('somewhere nice'), findsOneWidget);
      expect(requested, isEmpty);
    });

    testWidgets('nothing goes out before the pane has read its own location', (tester) async {
      // The pane's config is read asynchronously, but `didChangeDependencies`
      // runs first and knows the operation's grid. Acting there sends exactly
      // one request for the wrong place, per mount, and draws its answer
      // until the right one lands — with nothing on screen looking broken.
      await pump(
        tester,
        config: {weatherLocationKey: '51.48,-0.10'},
        operationGrid: 'FN42',
        fetch: answering(forecast(nowUtc()).body),
      );
      expect(requested.map((u) => u.queryParameters['latitude']), everyElement('51.4800'));
    });

    testWidgets('an override wins over the operation grid', (tester) async {
      await pump(
        tester,
        config: {weatherLocationKey: '51.48,-0.10'},
        fetch: answering(forecast(nowUtc()).body),
      );
      expect(requested.single.queryParameters['latitude'], '51.4800');
    });
  });

  group('a failure says which failure it was', () {
    testWidgets('nothing answered — go and look for signal', (tester) async {
      await pump(tester, fetch: failing);
      expect(find.text(t.weatherUnreachable), findsOneWidget);
    });

    testWidgets('something answered badly — signal is not the problem', (tester) async {
      // An operator told "no network" by a 503 goes looking for bars that are
      // already there. The two sentences send them to different places.
      await pump(tester, fetch: answering('{}', status: 503));
      expect(find.text(t.weatherUnreadable), findsOneWidget);
    });

    testWidgets('a reshaped feed reads as answered-badly, not as no network', (tester) async {
      await pump(tester, fetch: answering('{"nope":true}'));
      expect(find.text(t.weatherUnreadable), findsOneWidget);
    });

    testWidgets('a body that is not JSON at all does not escape as an error notice', (tester) async {
      // A throw out of the parse reaches ErrorPolicy and puts a "Something
      // went wrong" card over the operator's log, for a panel that only
      // needed to say it could not read the forecast.
      await pump(tester, fetch: answering('<html>502 Bad Gateway</html>'));
      expect(find.text(t.weatherUnreadable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a pane the dock has squeezed', () {
    // The dock floors a pane extent at 0 and enforces its 120pt minimum only
    // while DRAGGING, so a layout saved in a wide window and reopened in a
    // narrow one arrives at sizes no operator ever chose. Both of these throw
    // out of `build` — on every frame — if the arithmetic is unguarded.
    for (final size in [
      const Size(24, 300), // narrower than the 32pt inset: a negative content width
      const Size(300, 40), // shorter than the temperature row's own floor
      const Size(24, 40),
      const Size(1, 1),
    ]) {
      testWidgets('lays out at $size without throwing', (tester) async {
        await pump(tester, fetch: answering(forecast(nowUtc()).body), size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('two requests in flight', () {
    testWidgets('a superseded answer landing last does not blank the pane', (tester) async {
      // Editing the location starts a second request without cancelling the
      // first, so the older answer can arrive last. Installed, it leaves the
      // reading keyed to a place the pane is no longer showing — which
      // resolves to no reading, no failure and no spinner: a blank pane, held
      // until the fifteen-minute timer comes round.
      final gates = <String, Completer<({int status, String body})>>{};
      Future<({int status, String body})> gated(Uri url) {
        final latitude = url.queryParameters['latitude']!;
        requested.add(url);
        return (gates[latitude] ??= Completer()).future;
      }

      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final service = serviceWith(FakePanelExtensions(configs: const {}));

      Future<void> pumpWithGrid(String grid) => tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: WeatherPanel(
              panelId: weatherPanelId,
              panels: service,
              settings: settings,
              operationGrid: grid,
              fetch: gated,
            ),
          ),
        ),
      ));

      await pumpWithGrid('FN42');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(gates, hasLength(1), reason: 'the first place was asked about');

      await pumpWithGrid('JN47');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(gates, hasLength(2), reason: 'the second place was asked about too');

      final first = gates.keys.first;
      final second = gates.keys.last;

      // The NEWER request answers first, and the pane shows it.
      gates[second]!.complete((status: 200, body: forecast(nowUtc(), temperature: 44.4).body));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text('44°F'), findsOneWidget);

      // Then the superseded one lands.
      gates[first]!.complete((status: 200, body: forecast(nowUtc(), temperature: 88.8).body));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text('44°F'), findsOneWidget, reason: 'the newer reading still stands');
      expect(find.text('89°F'), findsNothing, reason: 'the superseded answer was not installed');
      expect(tester.takeException(), isNull);
    });
  });

  group('what the pane costs while nobody is looking', () {
    testWidgets('a pane behind another dock tab fetches nothing', (tester) async {
      // A dock group is an IndexedStack: the pane stays MOUNTED behind its
      // neighbour. Without the visibility gate every weather pane in a saved
      // layout keeps a 15-minute fetch running for a view nobody has open.
      await pump(tester, dockVisible: false, fetch: answering(forecast(nowUtc()).body));
      expect(requested, isEmpty);
    });
  });

  group('one request per thing being asked about', () {
    testWidgets('a fresh reading is not refetched on a rebuild', (tester) async {
      await pump(tester, fetch: answering(forecast(nowUtc()).body));
      expect(requested, hasLength(1));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      expect(requested, hasLength(1));
    });

    testWidgets('the request carries the units the operator chose', (tester) async {
      await pump(tester, fetch: answering(forecast(nowUtc()).body));
      // Kilometres is the default, so the panel must ask for Celsius. A
      // request that always asked for Fahrenheit would still render — just
      // labelled °F by the response's own units, with nothing looking wrong.
      expect(requested.single.queryParameters['temperature_unit'], 'celsius');
    });
  });
}

/// Stands in for whatever the http client throws when nothing answers. The
/// panel's rule is "anything that is not a bad ANSWER is a transport
/// failure", so the exact type is not what is under test — that it is not the
/// panel's own bad-answer exception is.
class NothingAnswered implements Exception {
  const NothingAnswered();
}
