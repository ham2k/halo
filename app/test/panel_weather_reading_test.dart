// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the weather pane makes of a forecast.
//
// The failures these exist to catch are all silent ones: a strip labelled in
// the DEVICE's zone rather than the forecast's looks perfectly plausible to a
// developer sitting in the same zone as their test data, and a reshaped feed
// that throws instead of returning null puts an error notice over the
// operator's log for a panel that could simply have said so.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/weather/weather_reading.dart';

void main() {
  // Boston, so the offset under test (-4h) is one that actually reorders the
  // day: 04:00Z is midnight local, and an hour label taken from UTC would be
  // wrong by a quarter of a day rather than by something a reader might not
  // notice.
  const offsetSeconds = -4 * 3600;
  const midnightLocalUtcSeconds = 1786161600; // 2026-08-08T04:00:00Z

  String fixture({
    double? currentTemperature = 88.9,
    int hourCount = 48,
    List<int?>? chances,
    Map<String, Object?> extraCurrent = const {},
    bool includeHourly = true,
    bool includeDaily = true,
  }) {
    final times = [for (var i = 0; i < hourCount; i++) midnightLocalUtcSeconds + i * 3600];
    return jsonEncode({
      'utc_offset_seconds': offsetSeconds,
      'timezone_abbreviation': 'GMT-4',
      'current_units': {'temperature_2m': '°F', 'wind_speed_10m': 'mp/h'},
      'current': {
        'temperature_2m': ?currentTemperature,
        'relative_humidity_2m': 47,
        'wind_speed_10m': 10.6,
        'wind_gusts_10m': 16.1,
        'wind_direction_10m': 238,
        'weather_code': 1,
        'is_day': 1,
        ...extraCurrent,
      },
      if (includeHourly)
        'hourly': {
          'time': times,
          'temperature_2m': [for (var i = 0; i < hourCount; i++) 70 + (i % 12)],
          'weather_code': [for (var i = 0; i < hourCount; i++) 3],
          'precipitation_probability': chances ?? [for (var i = 0; i < hourCount; i++) i % 101],
          'is_day': [for (var i = 0; i < hourCount; i++) (i % 24) >= 6 && (i % 24) < 20 ? 1 : 0],
        },
      if (includeDaily)
        'daily': {
          'sunrise': [1786182264, 1786268727],
          'sunset': [1786233320, 1786319641],
        },
    });
  }

  WeatherReading read([String? body]) {
    final reading = parseWeatherReading(
      body ?? fixture(),
      fetchedAtUtc: DateTime.utc(2026, 8, 8, 22, 44),
      fahrenheit: true,
    );
    return reading!;
  }

  group('hour labels come from the forecast, not the device', () {
    test('an hour is labelled on the LOCATION\'s wall clock', () {
      final reading = read();
      // 04:00Z is midnight in Boston. A `toLocal()` here would answer with
      // whatever zone the test machine (or CI) happens to sit in, which is
      // the whole class of bug this asserts against — and it would pass for
      // anyone running the suite in US/Eastern.
      expect(reading.hours.first.utc, DateTime.utc(2026, 8, 8, 4));
      expect(reading.hours.first.localHour, 0);
      expect(reading.hours[13].localHour, 13);
      expect(reading.utcOffset, const Duration(hours: -4));
      expect(reading.timezoneAbbreviation, 'GMT-4');
    });

    test('atLocation shifts an instant onto that same wall clock', () {
      final reading = read();
      expect(reading.atLocation(DateTime.utc(2026, 8, 8, 23, 55)).hour, 19);
    });
  });

  group('the window starts at the hour containing now', () {
    test('not the hour after it', () {
      final reading = read();
      // 22:44Z is 18:44 local, inside the 18:00 hour. The big current reading
      // is drawn over the left end of this strip: starting an hour ahead
      // would draw the curve disagreeing with the number on top of it.
      final hours = reading.hoursFrom(DateTime.utc(2026, 8, 8, 22, 44));
      expect(hours.first.localHour, 18);
      expect(hours.length, 8);
      expect([for (final h in hours) h.localHour], [18, 19, 20, 21, 22, 23, 0, 1]);
    });

    test('an exact hour boundary belongs to the hour it opens', () {
      final hours = read().hoursFrom(DateTime.utc(2026, 8, 8, 22));
      expect(hours.first.localHour, 18);
    });

    test('runs short rather than inventing hours when the response ends', () {
      // Three days of `hourly` is what the request asks for precisely so this
      // does not happen in the field; a short window is what the panel treats
      // as stale and refetches, so it has to be reported honestly.
      final reading = read(fixture(hourCount: 24));
      expect(reading.hoursFrom(DateTime.utc(2026, 8, 8, 22, 44)).length, 6);
      expect(reading.hoursFrom(DateTime.utc(2026, 8, 10)), isEmpty);
    });
  });

  group('the next sun event, not the first in the list', () {
    test('after today\'s sunset, sunrise is tomorrow\'s', () {
      final reading = read();
      // Past both of the 8th's events (05:44Z and 19:55Z), so an
      // implementation reaching for `[0]` shows an event already behind the
      // operator — which reads as a forecast, not as history.
      final night = DateTime.utc(2026, 8, 9, 1);
      expect(reading.nextSunrise(night), DateTime.utc(2026, 8, 9, 9, 45, 27));
      expect(reading.nextSunset(night), DateTime.utc(2026, 8, 9, 23, 54, 1));
    });

    test('null once the response has no later one', () {
      expect(read().nextSunrise(DateTime.utc(2026, 8, 20)), isNull);
    });
  });

  group('a bad answer costs the panel, not the app', () {
    WeatherReading? parse(String body) =>
        parseWeatherReading(body, fetchedAtUtc: DateTime.utc(2026), fahrenheit: true);

    test('malformed JSON is null, not a throw', () {
      // A throw here reaches ErrorPolicy and puts a "Something went wrong"
      // card over the operator's log, for a panel that only needed to say it
      // could not read the forecast. Every other shape of hostile body is in
      // panel_weather_hostile_payload_test.dart.
      expect(parse('<html>502</html>'), isNull);
    });

    test('a body that is not an object is null', () {
      expect(parse('[1,2,3]'), isNull);
    });

    test('no current temperature is null — it is the one field with no substitute', () {
      expect(parse(fixture(currentTemperature: null)), isNull);
    });

    test('every field but the temperature and the offset may be missing', () {
      // The offset is the second required one: it is what every hour label,
      // the sunrise and the sunset are built on, and defaulting it to zero
      // would draw a whole panel of plausible, wrong times.
      final reading = parse(jsonEncode({
        'utc_offset_seconds': 0,
        'current': {'temperature_2m': 12},
      }));
      expect(reading, isNotNull);
      expect(reading!.temperature, 12);
      expect(reading.hours, isEmpty);
      expect(reading.humidity, isNull);
      expect(reading.windSpeed, isNull);
      expect(reading.timezoneAbbreviation, isNull);
      // Absent `is_day` reads as day: a moon over a noon forecast is the more
      // alarming way to be wrong.
      expect(reading.isDay, isTrue);
    });

    test('hourly without daily, and daily without hourly, both parse', () {
      expect(read(fixture(includeDaily: false)).sunrises, isEmpty);
      expect(read(fixture(includeHourly: false)).hours, isEmpty);
    });
  });

  group('numbers arrive as ints or doubles in the same field', () {
    test('a whole temperature is read, not dropped', () {
      // Open-Meteo sends 70 for seventy and 70.4 for seventy-point-four in
      // the SAME field, so a plain `as double` cast drops every whole degree
      // — and does it only on the hours that happen to be whole.
      final reading = read();
      expect(reading.hours.first.temperature, 70.0);
    });
  });

  group('no rain and no answer are different things', () {
    test('a null chance stays null rather than becoming a bar of no height', () {
      final reading = read(fixture(chances: [null, 0, 40, ...List.filled(45, 0)]));
      expect(reading.hours[0].precipitationChance, isNull);
      expect(reading.hours[1].precipitationChance, 0);
      expect(reading.hours[2].precipitationChance, 40);
    });
  });

  group('compass points', () {
    test('name the sixteen the hobby already uses', () {
      expect(compassPoint(0), 'N');
      expect(compassPoint(238), 'WSW');
      expect(compassPoint(90), 'E');
    });

    test('wrap past north rather than running off the table', () {
      // 350° rounds to index 16, which is one past the end.
      expect(compassPoint(350), 'N');
      expect(compassPoint(360), 'N');
    });
  });

  group('reading a location', () {
    test('a grid square', () {
      final place = parseWeatherPlace('FN42');
      expect(place, isNotNull);
      expect(place!.latitude, closeTo(42.5, 0.01));
    });

    test('a lat,lon pair, with or without spaces', () {
      expect(parseWeatherPlace('42.36,-71.06'), (latitude: 42.36, longitude: -71.06));
      expect(parseWeatherPlace(' 42.36 , -71.06 '), (latitude: 42.36, longitude: -71.06));
    });

    test('out of range is refused rather than clamped', () {
      // Showing the weather somewhere the operator did not ask about is worse
      // than saying the location could not be read.
      expect(parseWeatherPlace('91,0'), isNull);
      expect(parseWeatherPlace('0,181'), isNull);
    });

    test('nothing, and nonsense, are both null', () {
      expect(parseWeatherPlace(null), isNull);
      expect(parseWeatherPlace(''), isNull);
      expect(parseWeatherPlace('   '), isNull);
      expect(parseWeatherPlace('somewhere nice'), isNull);
      expect(parseWeatherPlace('ZZ99'), isNull);
    });
  });

  group('the request', () {
    test('asks for the location\'s own zone, which is what makes the labels local', () {
      final url = weatherRequestUrl((latitude: 42.36, longitude: -71.06), fahrenheit: true);
      // Without `timezone=auto` the API answers `utc_offset_seconds: 0`, and
      // every hour label silently becomes UTC while still looking local.
      expect(url.queryParameters['timezone'], 'auto');
      expect(url.queryParameters['timeformat'], 'unixtime');
      expect(url.queryParameters['temperature_unit'], 'fahrenheit');
      // Kept in step with the temperature: °F beside km/h is nobody's
      // convention.
      expect(url.queryParameters['wind_speed_unit'], 'mph');
      // Two days is not enough: at 23:00 local, `hourly` starting at local
      // midnight leaves one hour ahead, not eight.
      expect(int.parse(url.queryParameters['forecast_days']!), greaterThanOrEqualTo(3));
      expect(url.queryParameters['hourly'], contains('precipitation_probability'));
    });

    test('metric asks for celsius and km/h together', () {
      final url = weatherRequestUrl((latitude: 0, longitude: 0), fahrenheit: false);
      expect(url.queryParameters['temperature_unit'], 'celsius');
      expect(url.queryParameters['wind_speed_unit'], 'kmh');
    });
  });
}
