// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the solar panel asks for, and what it makes of the answers. Pure — no
// widgets, no socket — so the parts that are actually easy to get wrong (a
// band grid built from a repeated tag, a series that arrives out of order,
// a reshaped feed) are testable without pumping a frame.
//
// THREE sources answer this panel, and they are not equals:
//
//   hamqsl.com/solarxml.php   N0NBH's indices, and the band-conditions grid.
//                             The one that must succeed — it carries every
//                             headline number.
//   SWPC f107_cm_flux         F10.7 three times a day, for the SFI curve.
//   SWPC noaa-planetary-k-index  Kp every three hours for the last week.
//   SWPC propagated-solar-wind  A week of wind speed, fetched rarely because
//                             it is 1.13MB, and thinned on arrival.
//   SWPC propagated-solar-wind-1-hour  The last hour of it at 7KB, every
//                             round, merged into the week above so the recent
//                             end stays current between the big fetches.
//
// The two SWPC series are additive: either failing costs its own chart and
// nothing else. Kept apart in the model for exactly that reason — a reading
// with a null series is a normal state, not a degraded one.
//
// **Nothing here throws, and the panel depends on it.** The panel classifies
// a failure as a transport one by elimination, so a `_TypeError` escaping a
// parse would tell every operator their network was down on the day a feed
// changed a field's type. Which is why nothing below casts.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

/// How a band group is propagating, as hamqsl rates it. [unknown] covers both
/// a rating the feed has never sent and one it has renamed — drawn as a blank
/// rather than guessed at, because an operator deciding which band to call on
/// is owed the difference between "poor" and "we don't know".
enum BandRating { good, fair, poor, unknown }

BandRating _ratingFor(String raw) => switch (raw.trim().toLowerCase()) {
  'good' => BandRating.good,
  'fair' => BandRating.fair,
  'poor' => BandRating.poor,
  _ => BandRating.unknown,
};

/// One row of the band grid: the group as the feed names it ("80m-40m"), and
/// its day and night ratings.
typedef BandConditions = ({String band, BandRating day, BandRating night});

/// A dated value in one of the SWPC series.
typedef SolarPoint = ({DateTime utc, double value});

/// Everything hamqsl answered with, plus whichever SWPC series arrived.
///
/// The numbers are nullable and are simply not drawn when absent: hamqsl
/// sends `<fof2></fof2>` and `NoRpt` routinely, and a panel that refused to
/// render without a MUF would spend most of the solar cycle blank.
class SolarReading {
  final int? solarFlux;
  final int? sunspots;
  final int? aIndex;
  final int? kIndex;

  /// Free text as the feed spells it — "B9.9", "VR QUIET", "S0-S1". Not
  /// parsed into anything: these are the strings every propagation page in
  /// the hobby prints, and an operator matches them by eye against those.
  final String? xray;
  final String? geomagneticField;
  final String? signalNoise;

  /// The He-304Å line, as `<heliumline>` spells it — "120.4". Text for the
  /// same reason the three above are: it is printed to one decimal
  /// everywhere in the hobby, and re-deriving that from a double is a way to
  /// eventually print it differently from every page an operator compares it
  /// against.
  ///
  /// Parsed but no longer drawn: the block has four columns and the wind
  /// speed took this one. Kept because the feed sends it and dropping the
  /// field would make putting it back a parser change rather than a layout
  /// one.
  final String? heliumLine;

  /// Wind speed in km/s, as `<solarwind>` spells it — "305.6". Same bargain
  /// as the line above.
  final String? solarWind;

  final List<BandConditions> bands;

  /// Daily F10.7, ascending, or empty when SWPC did not answer.
  final List<SolarPoint> flux;

  /// Kp every three hours, ascending, or empty for the same reason.
  final List<SolarPoint> kp;

  /// Wind speed every minute for the last hour, ascending, or empty likewise.
  final List<SolarPoint> wind;

  /// App-clock, not wall-clock: this is shown to the operator beside a UTC
  /// clock the same clock drives, and an age that disagreed with the Time
  /// chip next to it is the exact contradiction docs/design/time.md exists to
  /// prevent.
  final DateTime fetchedAtUtc;

  const SolarReading({
    required this.solarFlux,
    required this.sunspots,
    required this.aIndex,
    required this.kIndex,
    required this.xray,
    required this.geomagneticField,
    required this.signalNoise,
    required this.heliumLine,
    required this.solarWind,
    required this.bands,
    required this.fetchedAtUtc,
    this.flux = const [],
    this.kp = const [],
    this.wind = const [],
  });

  SolarReading withSeries({List<SolarPoint>? flux, List<SolarPoint>? kp, List<SolarPoint>? wind}) => SolarReading(
    solarFlux: solarFlux,
    sunspots: sunspots,
    aIndex: aIndex,
    kIndex: kIndex,
    xray: xray,
    geomagneticField: geomagneticField,
    signalNoise: signalNoise,
    heliumLine: heliumLine,
    solarWind: solarWind,
    bands: bands,
    fetchedAtUtc: fetchedAtUtc,
    flux: flux ?? this.flux,
    kp: kp ?? this.kp,
    wind: wind ?? this.wind,
  );

  /// The [days] ending at [nowUtc]. Sliced per build rather than at parse
  /// time, for the reason `WeatherReading.hoursFrom` is: the app clock can
  /// move under a panel (DEVTT), and re-slicing is free where re-fetching is
  /// not.
  ///
  /// A WINDOW, bounded at both ends. The upper bound is unreachable from any
  /// real response — no feed sends tomorrow's flux — but it is what makes a
  /// clock moved backwards honest: the charts then end where the app's own
  /// `now` does, rather than running on into readings the rest of the app is
  /// saying have not happened yet.
  static List<SolarPoint> lastDays(List<SolarPoint> series, DateTime nowUtc, int days) {
    final cutoff = nowUtc.subtract(Duration(days: days));
    return [
      for (final point in series)
        if (point.utc.isAfter(cutoff) && !point.utc.isAfter(nowUtc)) point,
    ];
  }
}

/// N0NBH's feed. Same document the SOLAR command reads
/// (`extensions/shared/spaceWeather.ts`), so the two can never disagree about
/// what today's numbers are.
///
/// **Proxied on web.** hamqsl.com sends no `Access-Control-Allow-Origin`, so
/// a browser refuses the response and the panel has nothing at all to show —
/// this is its one required source. `services.ham2k.net` is the same proxy
/// the extension host routes `host.fetch` through for this exact host (it is
/// in that allowlist already, for the SOLAR command), spelled again here
/// because a native panel goes nowhere near the host.
///
/// [web] is overridable only so a test can pin both forms; `kIsWeb` itself
/// is a const and cannot be.
Uri solarConditionsUrl({bool web = kIsWeb}) =>
    web ? Uri.parse('https://services.ham2k.net/www.hamqsl.com/solarxml.php') : Uri.parse('https://www.hamqsl.com/solarxml.php');

/// F10.7 as OBSERVED, three times a day.
///
/// Three is the instrument's limit, not a sampling choice: DRAO Penticton
/// measures the 10.7cm flux at 17:00, 20:00 and 22:00 UT and that is all the
/// resolution this quantity has anywhere. The daily product SWPC also
/// publishes is the noon one of these three, which over a week is seven marks
/// — a chart with more corners than data.
///
/// 22KB against the daily file's 1.4KB, which is the whole cost.
Uri solarFluxSeriesUrl() => Uri.parse('https://services.swpc.noaa.gov/json/f107_cm_flux.json');

/// Planetary Kp every three hours, seven days of it (~4.7 KB). The panel
/// draws three; the rest is slack for a device that has been asleep.
Uri solarKpSeriesUrl() => Uri.parse('https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json');

/// Seven days of propagated wind, at 1.13MB the largest thing this panel ever
/// asks for — and the reason it is asked for RARELY. See
/// [solarWindHistoryInterval]: the hourly feed below keeps the recent end
/// current between these, and the two are merged.
///
/// A week is the longest SWPC publishes for this series; there is no 30-day
/// product at any cadence.
Uri solarWindHistoryUrl() => Uri.parse('https://services.swpc.noaa.gov/products/geospace/propagated-solar-wind.json');

/// How often the big file is worth re-fetching, on the REAL clock.
///
/// Six hours rather than every refresh, because it is a megabyte. Nothing is
/// lost in between: each round merges the hourly feed into the series already
/// held, so the recent end keeps extending on its own — this is for healing
/// the hole a device that slept through the night comes back to.
const Duration solarWindHistoryInterval = Duration(hours: 6);

/// The last hour of that same series, a reading a minute, at 7KB.
///
/// The cheap half of the pair: fetched every round and merged into the week
/// above, so the recent end stays current without asking for the megabyte
/// again.
Uri solarWindSeriesUrl() => Uri.parse('https://services.swpc.noaa.gov/products/geospace/propagated-solar-wind-1-hour.json');

/// Every flat `<tag>text</tag>` pair in hamqsl's solar XML, trimmed.
///
/// Deliberately the same shape as `parseSolarXml` in
/// `extensions/shared/spaceWeather.ts` — a full XML parser would be a
/// dependency for a document whose scalar readings are all this needs. The
/// nested `<band>`/`<phenomenon>` elements carry attributes and so do not
/// match; [_parseBands] reads those separately.
final _tagPattern = RegExp(r'<(\w+)>([^<>]*)</\1>');

/// One `<band name="80m-40m" time="day">Fair</band>`.
final _bandPattern = RegExp(r'<band\s+name="([^"]*)"\s+time="([^"]*)"\s*>([^<]*)</band>');

/// Reads N0NBH's document. Null for a body that is not one — no solar flux at
/// all, which is the single field the panel's headline is built from and the
/// only one whose absence means the answer was not a reading.
SolarReading? parseSolarReading(String body, {required DateTime fetchedAtUtc}) {
  final scalars = <String, String>{for (final match in _tagPattern.allMatches(body)) match.group(1)!: match.group(2)!.trim()};
  final solarFlux = _toInt(scalars['solarflux']);
  if (solarFlux == null) return null;

  return SolarReading(
    solarFlux: solarFlux,
    sunspots: _toInt(scalars['sunspots']),
    aIndex: _toInt(scalars['aindex']),
    kIndex: _toInt(scalars['kindex']),
    xray: _text(scalars['xray']),
    geomagneticField: _text(scalars['geomagfield']),
    signalNoise: _text(scalars['signalnoise']),
    heliumLine: _text(scalars['heliumline']),
    solarWind: _text(scalars['solarwind']),
    bands: _parseBands(body),
    fetchedAtUtc: fetchedAtUtc,
  );
}

/// The band groups, in the order the feed lists them, each with both of its
/// ratings.
///
/// The feed sends day and night as separate elements, so a group appears
/// twice and the grid is one row per NAME. A group that appears for only one
/// of the two keeps its row with the other side [BandRating.unknown] — half a
/// row is still an answer about that band.
List<BandConditions> _parseBands(String body) {
  final day = <String, BandRating>{};
  final night = <String, BandRating>{};
  final order = <String>[];
  for (final match in _bandPattern.allMatches(body)) {
    final name = match.group(1)!.trim();
    if (name.isEmpty) continue;
    final rating = _ratingFor(match.group(3)!);
    // The VHF block uses `<phenomenon>`, not `<band>`, so nothing here can
    // reach it — this list is the HF grid only.
    if (match.group(2)!.trim().toLowerCase() == 'night') {
      night[name] = rating;
    } else {
      day[name] = rating;
    }
    if (!order.contains(name)) order.add(name);
  }
  return [for (final name in order) (band: name, day: day[name] ?? BandRating.unknown, night: night[name] ?? BandRating.unknown)];
}

/// SWPC's daily flux: `[{"time_tag":"2026-08-24T20:00:00","flux":143}, …]`.
///
/// Empty for anything unreadable. A missing series costs its chart, which the
/// panel treats as a normal state — so there is nothing here for a caller to
/// tell apart, and no reason to return null.
List<SolarPoint> parseFluxSeries(String body) => _parseSeries(body, 'flux');

/// SWPC's planetary Kp, same shape with a `Kp` field. Ascending in the
/// response, and sorted here anyway: the charts index by position, so one
/// out-of-order row would draw a spike backwards through the month.
List<SolarPoint> parseKpSeries(String body) => _parseSeries(body, 'Kp');

/// SWPC's propagated solar wind, which is a different SHAPE from the two
/// above: rows are arrays, and the first row names the columns —
/// `[["time_tag","speed",…],["2026-08-26T12:18:00Z",301.9,…], …]`.
///
/// The header is read rather than assumed. These products have gained columns
/// before, and a fixed index that silently became `density` would draw a
/// perfectly plausible curve of the wrong quantity — the failure mode with no
/// symptom.
List<SolarPoint> parseSolarWindSeries(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  if (decoded is! List || decoded.length < 2) return const [];

  final header = decoded.first;
  if (header is! List) return const [];
  final timeColumn = header.indexOf('time_tag');
  final speedColumn = header.indexOf('speed');
  if (timeColumn < 0 || speedColumn < 0) return const [];

  final points = <SolarPoint>[];
  for (final row in decoded.skip(1)) {
    if (row is! List || row.length <= timeColumn || row.length <= speedColumn) continue;
    // Nulls are routine here — the spacecraft drops readings — and a null
    // speed is a gap, not a zero. Drawn as zero it would be a wind that
    // stopped.
    final value = row[speedColumn];
    if (value is! num) continue;
    final utc = _parseTimeTag(row[timeColumn]);
    if (utc == null) continue;
    points.add((utc: utc, value: value.toDouble()));
  }
  points.sort((a, b) => a.utc.compareTo(b.utc));
  return points;
}

/// One series from two feeds covering different spans, where [fresher] wins
/// any timestamp they share.
///
/// The wind's two feeds are a week and an hour, and they overlap by that
/// hour. Preferring the fresher reading at every shared stamp keeps the
/// recent end current without losing the week behind it.
List<SolarPoint> mergeSeries(List<SolarPoint> base, List<SolarPoint> fresher) {
  final byStamp = <DateTime, double>{for (final point in base) point.utc: point.value, for (final point in fresher) point.utc: point.value};
  final merged = [for (final entry in byStamp.entries) (utc: entry.key, value: entry.value)];
  merged.sort((a, b) => a.utc.compareTo(b.utc));
  return merged;
}

/// The three-hour grid the Kp bars sit on: 00, 03, 06 … UTC.
///
/// Named because two series answer to it. A wind bucket and a Kp bar covering
/// different three hours would put a storm beside the wind of some other
/// afternoon, which is the one comparison stacking these charts exists to
/// make.
const Duration solarBucket = Duration(hours: 3);

/// [points] averaged into [solarBucket]-wide buckets aligned to UTC, so a
/// wind mark and a Kp bar at the same position cover the same three hours.
///
/// This DOES average, where the flux curve deliberately does not: a
/// three-hour mean wind speed is a quantity in its own right, and the raw
/// series is a reading a minute — nine thousand of them across a week, for a
/// chart a few hundred pixels wide. What is drawn is the period, not a
/// sample of it, and the hover label says so by naming the period's start,
/// exactly as the Kp bars do.
///
/// Empty buckets are absent rather than interpolated. The spacecraft drops
/// readings, and a gap invented as the mean of its neighbours is a wind
/// nobody measured.
List<SolarPoint> averageIntoBuckets(List<SolarPoint> points, [Duration bucket = solarBucket]) {
  if (points.isEmpty) return const [];
  final width = bucket.inMilliseconds;
  if (width <= 0) return points;

  final sums = <int, double>{};
  final counts = <int, int>{};
  for (final point in points) {
    // Floored against the EPOCH rather than against the series' first
    // reading, which is what aligns these to 00/03/06 UTC — and so to the Kp
    // stamps — no matter what minute the feed happens to start on.
    final start = (point.utc.millisecondsSinceEpoch ~/ width) * width;
    sums[start] = (sums[start] ?? 0) + point.value;
    counts[start] = (counts[start] ?? 0) + 1;
  }

  final starts = sums.keys.toList()..sort();
  return [for (final start in starts) (utc: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true), value: sums[start]! / counts[start]!)];
}

List<SolarPoint> _parseSeries(String body, String field) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];

  final points = <SolarPoint>[];
  for (final row in decoded) {
    if (row is! Map<String, dynamic>) continue;
    final value = row[field];
    if (value is! num) continue;
    final utc = _parseTimeTag(row['time_tag']);
    if (utc == null) continue;
    points.add((utc: utc, value: value.toDouble()));
  }
  points.sort((a, b) => a.utc.compareTo(b.utc));
  return points;
}

/// `"2026-08-24T20:00:00"` — no zone marker, and UTC regardless. Parsed as
/// UTC explicitly rather than through `DateTime.parse`, which would read an
/// unmarked stamp as the DEVICE's local time and slide the whole series by
/// the operator's offset.
DateTime? _parseTimeTag(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  try {
    return DateTime.parse(text.endsWith('Z') ? text : '${text}Z');
  } on FormatException {
    return null;
  }
}

/// A number the feed sent as text, with hamqsl's own leading spaces (it sends
/// the A index as `` <aindex> 6</aindex> ``) and its non-numeric sentinels
/// ("NoRpt", "No Report") both reading as absent.
int? _toInt(String? raw) => raw == null ? null : int.tryParse(raw.trim());

/// A text field, or null when the feed sent it empty — which it does for
/// `fof2` and `muffactor` most days. An empty string would draw a label with
/// nothing beside it.
String? _text(String? raw) {
  final text = raw?.trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Where the numbers come from, for the credit line. Not localized: one is a
/// domain and the other an agency's initials.
///
/// TWO, because the pane is two feeds: hamqsl carries every number and the
/// band grid, and both charts are NOAA's. A line crediting only the first
/// would be putting a name to a month of SWPC data that never came from it.
const String solarSourceHost = 'hamqsl.com';
const String solarSeriesSource = 'NOAA';
