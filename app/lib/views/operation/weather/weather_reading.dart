// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the weather panel asks Open-Meteo for, and what it makes of the
// answer. Pure — no widgets, no socket — so the parts that are actually easy
// to get wrong (which eight hours the strip shows, what a reshaped feed
// costs) are testable without pumping a frame or reaching the network.
//
// Times come back as `unixtime`, which is UTC epoch seconds however the
// `timezone` parameter is set; `utc_offset_seconds` is the separate value
// that turns one into the LOCATION's wall clock. Everything here stays in UTC
// and applies that offset only to produce an hour LABEL, so no arithmetic
// depends on the device's own zone — an operator in Colorado looking at a
// summit in Spain gets Spain's hours.

import 'dart:convert';

import 'package:halo_core/halo_core.dart';

/// A point on the map this panel can fetch for.
typedef WeatherPlace = ({double latitude, double longitude});

/// A grid square (`FN31pr`), a `lat,lon` pair, or nothing.
///
/// Returns null rather than guessing: a panel showing the weather somewhere
/// the operator did not ask about is worse than one saying it could not read
/// the location.
///
/// Do not narrow what this accepts. The panel's stored `location` values
/// predate it in both spellings, and a stricter parser turns an operator's
/// working override into an error message they did not cause.
final _latLonPattern = RegExp(r'^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$');

WeatherPlace? parseWeatherPlace(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final pair = _latLonPattern.firstMatch(text);
  if (pair != null) {
    final latitude = double.parse(pair.group(1)!);
    final longitude = double.parse(pair.group(2)!);
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return (latitude: latitude, longitude: longitude);
  }
  final grid = gridToLocation(text);
  if (grid == null) return null;
  return (latitude: grid.latitude, longitude: grid.longitude);
}

/// Three, because the strip is anchored at the CURRENT hour and `hourly`
/// starts at the location's local midnight: at 23:00 local a two-day response
/// holds one hour ahead, not eight.
const int _forecastDays = 3;

/// The labels Open-Meteo puts on the numbers it returned. Read from the
/// response rather than derived from the request, so a unit the API renames
/// shows up as its name and not as ours.
class WeatherUnits {
  final String temperature;
  final String windSpeed;

  const WeatherUnits({this.temperature = '°', this.windSpeed = ''});
}

/// One hour of the forecast.
class WeatherHour {
  /// The start of the hour, in UTC.
  final DateTime utc;

  /// That same instant on the LOCATION's wall clock, 0–23.
  final int localHour;

  final double? temperature;
  final int? code;
  final bool isDay;

  /// Percent, or null where the response carried none — which is not the same
  /// as zero and must not be drawn as a bar of no height.
  final int? precipitationChance;

  const WeatherHour({
    required this.utc,
    required this.localHour,
    required this.temperature,
    required this.code,
    required this.isDay,
    required this.precipitationChance,
  });
}

class WeatherReading {
  final double temperature;
  final int? code;
  final bool isDay;
  final int? humidity;
  final double? windSpeed;
  final double? windGusts;
  final int? windDirection;

  /// Every hour the response carried, ascending. Sliced per build by
  /// [hoursFrom] rather than at parse time: the app clock can move under a
  /// panel (DEVTT), and re-slicing is free where re-fetching is not.
  final List<WeatherHour> hours;

  /// UTC instants, ascending. Kept as lists for the same reason — which
  /// sunrise is "next" is a question about now, not about the response.
  final List<DateTime> sunrises;
  final List<DateTime> sunsets;

  final Duration utcOffset;

  /// What the LOCATION calls its offset, as Open-Meteo names it ("GMT-4",
  /// "CEST"). Shown rather than inferred, and shown at all because this
  /// panel's hours are the only ones in the app that are not UTC: an operator
  /// reading 19 beside a UTC clock reading 23 is owed the reason.
  final String? timezoneAbbreviation;

  final WeatherUnits units;

  /// App-clock, not wall-clock: this is shown to the operator beside a
  /// forecast the same clock chose the hours for, and a reading whose age
  /// disagreed with the Time chip next to it would be the exact contradiction
  /// docs/design/time.md exists to prevent.
  final DateTime fetchedAtUtc;

  const WeatherReading({
    required this.temperature,
    required this.code,
    required this.isDay,
    required this.humidity,
    required this.windSpeed,
    required this.windGusts,
    required this.windDirection,
    required this.hours,
    required this.sunrises,
    required this.sunsets,
    required this.utcOffset,
    required this.timezoneAbbreviation,
    required this.units,
    required this.fetchedAtUtc,
  });

  /// The [count] hours starting with the one CONTAINING [nowUtc] — not the
  /// one after it. The big current reading sits over the left end of the
  /// curve, and a strip that started an hour ahead would draw them
  /// disagreeing.
  ///
  /// Short, or empty, when the response has run out. The caller decides what
  /// too little forecast is worth doing about; this does not invent hours.
  List<WeatherHour> hoursFrom(DateTime nowUtc, {int count = 8}) {
    final start = hours.indexWhere((h) => h.utc.add(const Duration(hours: 1)).isAfter(nowUtc));
    if (start < 0) return const [];
    return hours.sublist(start, (start + count).clamp(0, hours.length));
  }

  DateTime? nextSunrise(DateTime nowUtc) => _nextAfter(sunrises, nowUtc);
  DateTime? nextSunset(DateTime nowUtc) => _nextAfter(sunsets, nowUtc);

  static DateTime? _nextAfter(List<DateTime> times, DateTime nowUtc) {
    for (final t in times) {
      if (t.isAfter(nowUtc)) return t;
    }
    return null;
  }

  /// [utc] on the location's wall clock. The result is a UTC-flagged
  /// DateTime whose FIELDS read as local time — the standard offset trick,
  /// and the only one available: Dart carries no zone database, so
  /// `toLocal()` would answer with the device's zone rather than the
  /// forecast's.
  DateTime atLocation(DateTime utc) => utc.add(utcOffset);
}

const _compass = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];

/// The 16-point compass name for a bearing. Not localized, and deliberately:
/// these are the same sixteen tokens the WEATHER command writes into the log
/// and that every rotator control and beam-heading table in the hobby uses.
String compassPoint(int degrees) => _compass[((degrees / 22.5).round() % 16 + 16) % 16];

/// The forecast request. Units follow the operator's distance preference
/// standing in for a unit SYSTEM, which is what the WEATHER command already
/// does — the app has no temperature setting to read. Imperfect, knowingly:
/// a UK operator keeps miles and expects Celsius.
Uri weatherRequestUrl(WeatherPlace place, {required bool fahrenheit}) {
  return Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': place.latitude.toStringAsFixed(4),
    'longitude': place.longitude.toStringAsFixed(4),
    'temperature_unit': fahrenheit ? 'fahrenheit' : 'celsius',
    // Kept in step with the temperature rather than left at the API's
    // defaults: °F beside km/h is nobody's convention.
    'wind_speed_unit': fahrenheit ? 'mph' : 'kmh',
    'current':
        'temperature_2m,relative_humidity_2m,wind_speed_10m,wind_gusts_10m,'
        'wind_direction_10m,weather_code,is_day',
    'hourly': 'temperature_2m,weather_code,precipitation_probability,is_day',
    'daily': 'sunrise,sunset',
    'forecast_days': '$_forecastDays',
    // What makes `utc_offset_seconds` the location's rather than zero, which
    // is the whole basis of the hour labels.
    'timezone': 'auto',
    'timeformat': 'unixtime',
  });
}

/// Reads a forecast response. Null for a body that is not one — no current
/// temperature, or no `utc_offset_seconds` (see below). Every other field may
/// be absent and is simply not shown.
///
/// **This never throws, and the panel depends on that.** It classifies a
/// failure as a transport one by elimination — anything that is not its own
/// "the service answered badly" exception — so a `_TypeError` escaping from
/// here would tell every operator in the world their network was down on the
/// day Open-Meteo changed a field's type. Which is why nothing below casts:
/// values are read through [_toDouble], [_toInt] and [_string], and epoch
/// seconds through [_utcFromEpochSeconds], which range-checks rather than
/// letting `DateTime.fromMillisecondsSinceEpoch` throw `RangeError`.
/// `weather_reading_is_total_test.dart` holds this to it.
///
/// [fahrenheit] is what the request ASKED for, and is used only where the
/// response failed to label its own units — `89°` beside a wind speed with no
/// unit at all is a reading an operator can misread by 32 degrees.
WeatherReading? parseWeatherReading(String body, {required DateTime fetchedAtUtc, required bool fahrenheit}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  final current = decoded['current'];
  if (current is! Map<String, dynamic>) return null;
  final temperature = _toDouble(current['temperature_2m']);
  if (temperature == null) return null;

  // Required, not defaulted to zero. The request asks for `timezone=auto`
  // precisely to get this, and every hour label, the sunrise and the sunset
  // are built on it — so a response without one would draw a whole panel of
  // times up to fourteen hours wrong, all of them plausible, with nothing on
  // screen able to say so. A reading that cannot be labelled is not a reading.
  final offsetSeconds = _toInt(decoded['utc_offset_seconds']);
  if (offsetSeconds == null) return null;
  final offset = Duration(seconds: offsetSeconds);

  final currentUnits = decoded['current_units'];
  final units = WeatherUnits(
    temperature: _string(currentUnits, 'temperature_2m') ?? (fahrenheit ? '°F' : '°C'),
    windSpeed: _string(currentUnits, 'wind_speed_10m') ?? (fahrenheit ? 'mp/h' : 'km/h'),
  );

  return WeatherReading(
    temperature: temperature,
    code: _toInt(current['weather_code']),
    // Absent reads as day. The alternative is a moon over a noon forecast,
    // which is the more alarming way to be wrong.
    isDay: (_toInt(current['is_day']) ?? 1) != 0,
    humidity: _toInt(current['relative_humidity_2m']),
    windSpeed: _toDouble(current['wind_speed_10m']),
    windGusts: _toDouble(current['wind_gusts_10m']),
    windDirection: _toInt(current['wind_direction_10m']),
    hours: _parseHours(decoded['hourly'], offset),
    sunrises: _parseTimes(decoded['daily'], 'sunrise'),
    sunsets: _parseTimes(decoded['daily'], 'sunset'),
    utcOffset: offset,
    timezoneAbbreviation: _string(decoded, 'timezone_abbreviation'),
    units: units,
    fetchedAtUtc: fetchedAtUtc,
  );
}

List<WeatherHour> _parseHours(Object? hourly, Duration offset) {
  if (hourly is! Map<String, dynamic>) return const [];
  final times = hourly['time'];
  if (times is! List) return const [];
  final temperatures = _listOrEmpty(hourly['temperature_2m']);
  final codes = _listOrEmpty(hourly['weather_code']);
  final chances = _listOrEmpty(hourly['precipitation_probability']);
  final isDay = _listOrEmpty(hourly['is_day']);

  final hours = <WeatherHour>[];
  for (var i = 0; i < times.length; i++) {
    final utc = _utcFromEpochSeconds(_toInt(times[i]));
    if (utc == null) continue;
    hours.add(
      WeatherHour(
        utc: utc,
        localHour: utc.add(offset).hour,
        temperature: _toDouble(_at(temperatures, i)),
        code: _toInt(_at(codes, i)),
        isDay: (_toInt(_at(isDay, i)) ?? 1) != 0,
        precipitationChance: _toInt(_at(chances, i)),
      ),
    );
  }
  return hours;
}

List<DateTime> _parseTimes(Object? daily, String key) {
  if (daily is! Map<String, dynamic>) return const [];
  final values = daily[key];
  if (values is! List) return const [];
  return [for (final value in values) ?_utcFromEpochSeconds(_toInt(value))];
}

List<Object?> _listOrEmpty(Object? value) => value is List ? value : const [];

Object? _at(List<Object?> values, int index) => index < values.length ? values[index] : null;

/// Open-Meteo returns whole values as ints and fractional ones as doubles in
/// the same field, so neither cast alone is safe.
double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

int? _toInt(Object? value) => value is num ? value.round() : null;

/// A string field, or null for absent OR wrong-typed. A cast would be the
/// obvious spelling and is exactly what must not appear here: `as String?`
/// throws `_TypeError` on a number, and this parse may not throw.
String? _string(Object? map, String key) {
  if (map is! Map<String, dynamic>) return null;
  final value = map[key];
  return value is String ? value : null;
}

/// Epoch seconds as UTC, or null when they name an instant `DateTime` cannot
/// hold. `DateTime.fromMillisecondsSinceEpoch` throws `RangeError` past
/// ±8.64e12 seconds, and a feed that has started sending microseconds — or a
/// sentinel like 99999999999999 — reaches that from a field this reads
/// without complaint.
DateTime? _utcFromEpochSeconds(int? seconds) {
  if (seconds == null || seconds.abs() > 8640000000000) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
