// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When the weather pane asks the service again, and — the expensive half —
// when it must not.
//
// The panel's own State cannot be driven far enough to test this: `fakeAsync`
// does not move the app clock, so a widget test that pumps fifteen minutes
// fires the timer against a `now` that never moved and every branch reads as
// "not due". That is precisely why the decision is a free function.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/weather/weather_panel.dart';
import 'package:ham2k_logger/views/operation/weather/weather_reading.dart';

void main() {
  final real = DateTime.utc(2026, 8, 8, 22, 44);
  final app = DateTime.utc(2026, 8, 8, 22, 44);

  WeatherReading readingAt(DateTime fetchedAtUtc, {int hoursAhead = 12}) {
    final base = DateTime.utc(fetchedAtUtc.year, fetchedAtUtc.month, fetchedAtUtc.day, fetchedAtUtc.hour);
    return WeatherReading(
      temperature: 70,
      code: 1,
      isDay: true,
      humidity: null,
      windSpeed: null,
      windGusts: null,
      windDirection: null,
      hours: [
        for (var i = 0; i < hoursAhead; i++)
          WeatherHour(
            utc: base.add(Duration(hours: i)),
            localHour: base.add(Duration(hours: i)).hour,
            temperature: 70,
            code: 1,
            isDay: true,
            precipitationChance: null,
          ),
      ],
      sunrises: const [],
      sunsets: const [],
      utcOffset: Duration.zero,
      timezoneAbbreviation: 'GMT',
      units: const WeatherUnits(),
      fetchedAtUtc: fetchedAtUtc,
    );
  }

  bool due({
    String? key = 'k1',
    String? attemptKey = 'k1',
    DateTime? attemptedAtReal,
    DateTime? realNow,
    String? readingKey = 'k1',
    WeatherReading? reading,
    DateTime? now,
  }) => weatherFetchIsDue(
    key: key,
    attemptKey: attemptKey,
    attemptedAtReal: attemptedAtReal ?? real,
    realNow: realNow ?? real,
    readingKey: readingKey,
    reading: reading ?? readingAt(app),
    now: now ?? app,
  );

  group('nothing to ask about', () {
    test('no location means no request, whatever else is true', () {
      expect(due(key: null, attemptKey: null, readingKey: null, reading: null), isFalse);
    });
  });

  group('a new question is asked at once', () {
    test('a different place or unit system skips the retry floor', () {
      // The floor exists to stop repetition, not to make an operator who just
      // typed a new location wait a minute to see it.
      expect(due(key: 'k2', attemptKey: 'k1', realNow: real), isTrue);
    });
  });

  group('the same question waits', () {
    test('a failed attempt is not retried inside the floor', () {
      // The storm this prevents is real and cheap to cause: SettingsService
      // notifies on every background sync write, each one reaches the panel,
      // and with no reading in hand every one of them would open a request.
      expect(
        due(readingKey: null, reading: null, attemptedAtReal: real, realNow: real.add(const Duration(seconds: 30))),
        isFalse,
      );
    });

    test('and is retried once the floor passes', () {
      expect(
        due(readingKey: null, reading: null, attemptedAtReal: real, realNow: real.add(const Duration(seconds: 61))),
        isTrue,
      );
    });

    test('the floor is measured on REAL time, so travelling the app clock is not a burst', () {
      // `now` a day ahead would make the reading stale by every other rule
      // here; the floor still holds, because it paces a third-party service.
      expect(
        due(
          attemptedAtReal: real,
          realNow: real.add(const Duration(seconds: 5)),
          now: app.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });
  });

  group('a reading in hand', () {
    test('a fresh one is left alone', () {
      expect(due(attemptedAtReal: real.subtract(const Duration(minutes: 5))), isFalse);
    });

    test('one older than the max age is refetched', () {
      // Deleting the timer, or widening weatherMaxAge, has to fail something
      // — a pane that never refreshes is the one thing an operator on a
      // summit notices last.
      final stale = readingAt(app.subtract(weatherMaxAge + const Duration(minutes: 1)));
      expect(due(reading: stale, attemptedAtReal: real.subtract(const Duration(minutes: 30))), isTrue);
    });

    test('one for somewhere else is not this pane\'s reading at all', () {
      expect(due(readingKey: 'k0', attemptedAtReal: real.subtract(const Duration(minutes: 5))), isTrue);
    });

    test('one that no longer covers the hours being asked about is stale, however new', () {
      // DEVTT moves the app clock in hours. A forecast that arrived seconds
      // ago can stop describing "the next eight hours" without anything
      // being wrong with it.
      expect(
        due(
          reading: readingAt(app, hoursAhead: 12),
          now: app.add(const Duration(hours: 11)),
          attemptedAtReal: real.subtract(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });
  });
}
