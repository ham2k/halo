// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `parseWeatherReading` must never throw, and the panel's correctness rests
// on it.
//
// The panel classifies a failure by ELIMINATION — anything that is not its
// own "the service answered badly" exception is a transport failure — so a
// `_TypeError` escaping the parse would tell every operator in the world that
// their network was down, on the day Open-Meteo changed a field's type. They
// would go looking for signal that was never the problem.
//
// The two ways to write this parse that do throw are the obvious ones: a
// plain `as String?` cast (a `_TypeError` on a number) and
// `DateTime.fromMillisecondsSinceEpoch` (a `RangeError` past ±8.64e12
// seconds). Both are reachable from a feed change alone.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/weather/weather_reading.dart';

void main() {
  WeatherReading? parse(Object? body) =>
      parseWeatherReading(body is String ? body : jsonEncode(body), fetchedAtUtc: DateTime.utc(2026, 8, 8, 22, 44), fahrenheit: true);

  Map<String, Object?> wellFormed({Map<String, Object?> overrides = const {}}) => {
    'utc_offset_seconds': -14400,
    'timezone_abbreviation': 'GMT-4',
    'current_units': {'temperature_2m': '°F', 'wind_speed_10m': 'mp/h'},
    'current': {'temperature_2m': 70, 'weather_code': 1, 'is_day': 1},
    'hourly': {
      'time': [1786161600, 1786165200],
      'temperature_2m': [70, 71],
    },
    'daily': {
      'sunrise': [1786182264],
      'sunset': [1786233320],
    },
    ...overrides,
  };

  group('a field that changed type does not throw', () {
    test('numbers where strings are expected', () {
      // `as String?` is the natural spelling and is exactly what must not be
      // in the parse: it throws `_TypeError` on this body.
      expect(
        () => parse(
          wellFormed(
            overrides: {
              'current_units': {'temperature_2m': 1, 'wind_speed_10m': 2},
              'timezone_abbreviation': 7,
            },
          ),
        ),
        returnsNormally,
      );
      final reading = parse(
        wellFormed(
          overrides: {
            'current_units': {'temperature_2m': 1, 'wind_speed_10m': 2},
            'timezone_abbreviation': 7,
          },
        ),
      );
      expect(reading, isNotNull);
      expect(reading!.timezoneAbbreviation, isNull);
      // Falls back to what the REQUEST asked for, so a reading is never
      // labelled with a bare degree sign an operator can misread by 32.
      expect(reading.units.temperature, '°F');
      expect(reading.units.windSpeed, 'mp/h');
    });

    test('strings where numbers are expected', () {
      final reading = parse(
        wellFormed(
          overrides: {
            'current': {'temperature_2m': 70, 'relative_humidity_2m': '47', 'wind_speed_10m': 'calm'},
          },
        ),
      );
      expect(reading, isNotNull);
      expect(reading!.humidity, isNull);
      expect(reading.windSpeed, isNull);
    });

    test('a whole structure replaced by a scalar', () {
      for (final broken in [
        {'current_units': 5},
        {'hourly': 'none'},
        {'daily': 3},
        {
          'hourly': {'time': 'nope'},
        },
      ]) {
        expect(() => parse(wellFormed(overrides: broken)), returnsNormally, reason: '$broken');
      }
    });
  });

  group('an epoch value out of range does not throw', () {
    test('an hourly time past what DateTime can hold is dropped, not fatal', () {
      // `DateTime.fromMillisecondsSinceEpoch` throws RangeError past
      // ±8.64e12 seconds — a feed that switched to microseconds reaches that
      // from a field this reads without complaint.
      final reading = parse(
        wellFormed(
          overrides: {
            'hourly': {
              'time': [1786161600, 99999999999999, 1786165200],
              'temperature_2m': [70, 71, 72],
            },
          },
        ),
      );
      expect(reading, isNotNull);
      expect(reading!.hours, hasLength(2));
    });

    test('a sunrise past what DateTime can hold is dropped, not fatal', () {
      final reading = parse(
        wellFormed(
          overrides: {
            'daily': {
              'sunrise': [99999999999999],
              'sunset': [1786233320],
            },
          },
        ),
      );
      expect(reading, isNotNull);
      expect(reading!.sunrises, isEmpty);
      expect(reading.sunsets, hasLength(1));
    });
  });

  group('garbage of every shape returns null rather than throwing', () {
    test('bodies that are not a forecast', () {
      for (final body in [
        '',
        '   ',
        '<html>502 Bad Gateway</html>',
        'null',
        '[]',
        '[1,2,3]',
        '"a string"',
        '42',
        '{}',
        '{"current":null}',
        '{"current":[]}',
        '{"current":{}}',
        '{"current":{"temperature_2m":"warm"}}',
      ]) {
        expect(() => parse(body), returnsNormally, reason: body);
        expect(parse(body), isNull, reason: body);
      }
    });
  });

  group('the offset is required, not defaulted', () {
    test('a response without one is refused', () {
      // Zero is a perfectly valid offset, so defaulting to it draws a whole
      // panel of times up to fourteen hours wrong — every one of them
      // plausible, with nothing on screen able to say so. The request asks
      // for `timezone=auto` precisely to get this field.
      final body = wellFormed()..remove('utc_offset_seconds');
      expect(parse(body), isNull);
    });

    test('and one that is not a number is refused too', () {
      expect(parse(wellFormed(overrides: {'utc_offset_seconds': '-14400'})), isNull);
    });

    test('a real offset is kept', () {
      expect(parse(wellFormed())!.utcOffset, const Duration(hours: -4));
    });
  });
}
