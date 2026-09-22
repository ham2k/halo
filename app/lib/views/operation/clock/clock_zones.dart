// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which time a clock pane is showing. Pure: every function takes its instant
// as an argument and none reads the wall clock, so the DST assertions in
// panel_clock_zones_test.dart are the same on a New York laptop and on the
// UTC CI runner.
//
// The zone rules come from the `timezone` package's bundled snapshot, which
// is only as current as the pinned version — docs/maintenance.md §10 owns
// that, including why nothing here can detect a stale one.

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

/// The two ids that are not IANA names. `@` cannot appear in an IANA zone
/// name, so neither can collide with one.
const String utcZoneId = 'UTC';
const String deviceZoneId = '@device';

List<Map<String, dynamic>>? _zoneOptions;

/// The zone select's options: UTC, the device's own clock, then every zone
/// the bundled database knows, sorted.
///
/// Memoized because [PanelDefinition] equality compares `formFields.length`
/// and nothing deeper — the registration that consumes this runs from
/// `didChangeDependencies` and early-returns, but only AFTER building its
/// argument, so an unmemoized call rebuilds 340-odd maps on every dependency
/// change. The corollary: the list is fixed for the session, which is right
/// because the database it reads only changes on a package bump.
List<Map<String, dynamic>> clockZoneOptions({required String utcLabel, required String deviceLabel}) {
  final cached = _zoneOptions;
  if (cached != null) {
    // The labels are localized, and a locale change re-runs registration.
    cached[0]['label'] = utcLabel;
    cached[1]['label'] = deviceLabel;
    return cached;
  }
  final names = tz.timeZoneDatabase.locations.keys.toList()..sort();
  // An empty database means `initializeTimeZones` has not run — an entry
  // point that skipped it, or a test that pumps the Operation View without
  // it. Caching THAT would leave the picker offering two rows for the rest of
  // the isolate's life, with no way to recover once the data arrives.
  if (names.isEmpty) return _specialZoneOptions(utcLabel, deviceLabel);
  return _zoneOptions = [
    ..._specialZoneOptions(utcLabel, deviceLabel),
    // The raw IANA name, underscores and all: it is what the operator will
    // type looking for it, and it is the only spelling that is unambiguous
    // between the several Georgetowns and Springfields.
    //
    // A select's values must be unique or the row cannot say which option is
    // chosen. The database spells UTC `Etc/UTC`, so the filter does not
    // currently fire; it is what keeps [utcZoneId] from ever being listed
    // twice.
    for (final name in names)
      if (name != utcZoneId) {'label': name, 'value': name},
  ];
}

/// UTC and the device's own clock, which are not IANA zones and are always
/// offered — including when the database is missing entirely.
List<Map<String, dynamic>> _specialZoneOptions(String utcLabel, String deviceLabel) => [
  {'label': utcLabel, 'value': utcZoneId},
  {'label': deviceLabel, 'value': deviceZoneId},
];

/// What one clock shows at one instant.
@immutable
class ZoneReading {
  /// The wall time in the zone. Read its FIELDS — `hour`, `minute` — not the
  /// instant it claims to be: for an IANA zone this is a `TZDateTime` whose
  /// `isUtc` is false and whose epoch is the true one, and for UTC it is the
  /// original instant.
  final DateTime wall;

  /// `EST`, `+05:30`, or null where the platform cannot say. Null on web for
  /// [deviceZoneId]: dart2js answers `Eastern Daylight Time` where native
  /// answers `EDT`, and a clock face has no room for the long form.
  final String? abbreviation;

  final Duration offset;

  const ZoneReading({required this.wall, required this.abbreviation, required this.offset});
}

/// [zoneId] read against [nowUtc].
///
/// Never throws. A saved layout outlives the tzdata release that named its
/// zone, and a pane that will not build costs the operator the whole
/// Operation View — so an id the database cannot explain reads as UTC.
ZoneReading readZone(String zoneId, DateTime nowUtc) {
  final utc = nowUtc.isUtc ? nowUtc : nowUtc.toUtc();
  if (zoneId == deviceZoneId) {
    final wall = utc.toLocal();
    return ZoneReading(
      wall: wall,
      // Long-form on web, and there is no short form to derive from it —
      // abbreviations are not a function of the offset.
      abbreviation: kIsWeb ? null : wall.timeZoneName,
      offset: wall.timeZoneOffset,
    );
  }
  if (zoneId != utcZoneId) {
    try {
      final wall = tz.TZDateTime.from(utc, tz.getLocation(zoneId));
      return ZoneReading(wall: wall, abbreviation: wall.timeZoneName, offset: wall.timeZoneOffset);
    } catch (_) {
      // Deliberately swallowed, and the only catch in this file. The id came
      // from storage, not from code: an operator whose zone was withdrawn
      // gets a clock reading UTC, which is wrong but legible, rather than a
      // view that will not open.
    }
  }
  return ZoneReading(wall: utc, abbreviation: 'UTC', offset: Duration.zero);
}

/// What the tab and the face call this zone — `UTC`, the device label, or an
/// IANA name's last segment with its underscores opened up
/// (`America/New_York` → `New York`). The region prefix is what makes the
/// picker unambiguous and what makes a tab unreadable.
String zoneShortName(String zoneId, {required String deviceLabel}) {
  if (zoneId == deviceZoneId) return deviceLabel;
  if (zoneId == utcZoneId) return utcZoneId;
  final cut = zoneId.lastIndexOf('/');
  return (cut < 0 ? zoneId : zoneId.substring(cut + 1)).replaceAll('_', ' ');
}

/// `UTC+5:30`, `UTC-8`, `UTC` — how an offset is written where there is room
/// for it. Half- and quarter-hour zones are real (Kolkata, Kathmandu,
/// Chatham), so the minutes are not decoration.
String offsetLabel(Duration offset) {
  if (offset == Duration.zero) return 'UTC';
  final minutes = offset.inMinutes;
  final abs = minutes.abs();
  final sign = minutes < 0 ? '-' : '+';
  final hh = abs ~/ 60;
  final mm = abs % 60;
  return mm == 0 ? 'UTC$sign$hh' : 'UTC$sign$hh:${mm.toString().padLeft(2, '0')}';
}
