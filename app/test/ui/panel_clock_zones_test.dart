// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Zone conversion for the clock pane.
//
// Every instant below is an explicit UTC literal and every expectation is a
// wall time written out by hand, because the failure this guards against is
// code that works on the developer's machine and not on anyone else's:
// `toLocal()` anywhere in the conversion passes on a New York laptop and
// fails on the UTC CI runner, and a cached fixed offset per zone passes all
// year except across a transition.
//
// The transitions are real ones from the bundled database, chosen so each
// pair straddles a change by one minute.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/clock/clock_zones.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  /// `YYYY-MM-DD HH:MM` of the wall time, which is the only part of a
  /// [ZoneReading.wall] that means anything.
  String wallOf(String zone, String utcIso) {
    final r = readZone(zone, DateTime.parse(utcIso));
    final w = r.wall;
    return '${w.year}-${w.month.toString().padLeft(2, '0')}-${w.day.toString().padLeft(2, '0')} '
        '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';
  }

  group('readZone across DST transitions', () {
    test('New York springs forward, skipping 02:00', () {
      expect(wallOf('America/New_York', '2026-03-08T06:59:00Z'), '2026-03-08 01:59');
      expect(wallOf('America/New_York', '2026-03-08T07:00:00Z'), '2026-03-08 03:00');
      expect(readZone('America/New_York', DateTime.parse('2026-03-08T06:59:00Z')).abbreviation, 'EST');
      expect(readZone('America/New_York', DateTime.parse('2026-03-08T07:00:00Z')).abbreviation, 'EDT');
    });

    test('New York falls back, repeating 01:00', () {
      // The same wall time on both sides of the change. A conversion that
      // caches one offset per zone gets exactly one of these two right.
      expect(wallOf('America/New_York', '2026-11-01T05:59:00Z'), '2026-11-01 01:59');
      expect(wallOf('America/New_York', '2026-11-01T06:00:00Z'), '2026-11-01 01:00');
    });

    test('London changes at a different instant than New York', () {
      // Late March is the fortnight when the US and Europe disagree — a
      // hardcoded "DST is from March to November" rule is right for one of
      // them and wrong for the other.
      expect(wallOf('Europe/London', '2026-03-29T00:59:00Z'), '2026-03-29 00:59');
      expect(wallOf('Europe/London', '2026-03-29T01:00:00Z'), '2026-03-29 02:00');
      expect(readZone('Europe/London', DateTime.parse('2026-03-29T01:00:00Z')).abbreviation, 'BST');
    });

    test('Lord Howe shifts by half an hour, not a whole one', () {
      // The only zone with a 30-minute DST step. An implementation that
      // assumes an hour is wrong here and nowhere else.
      expect(wallOf('Australia/Lord_Howe', '2026-04-04T14:59:00Z'), '2026-04-05 01:59');
      expect(wallOf('Australia/Lord_Howe', '2026-04-04T15:00:00Z'), '2026-04-05 01:30');
      expect(
        readZone('Australia/Lord_Howe', DateTime.parse('2026-04-04T15:00:00Z')).offset,
        const Duration(hours: 10, minutes: 30),
      );
    });
  });

  group('readZone offsets', () {
    test('keeps the minutes in a half- and quarter-hour zone', () {
      // Whole-hour arithmetic is right for most of the world and wrong for
      // about a fifth of it.
      expect(wallOf('Asia/Kolkata', '2026-08-08T03:30:00Z'), '2026-08-08 09:00');
      expect(readZone('Asia/Kolkata', DateTime.parse('2026-08-08T03:30:00Z')).offset,
          const Duration(hours: 5, minutes: 30));
      expect(wallOf('Asia/Kathmandu', '2026-08-08T03:30:00Z'), '2026-08-08 09:15');
      expect(readZone('Asia/Kathmandu', DateTime.parse('2026-08-08T03:30:00Z')).offset,
          const Duration(hours: 5, minutes: 45));
    });

    test('crosses the date line in both directions', () {
      // The date, not just the time. Arithmetic done on a non-UTC base lands
      // these on the wrong day while the clock face still looks plausible.
      expect(wallOf('Pacific/Kiritimati', '2026-08-08T03:30:00Z'), '2026-08-08 17:30');
      expect(wallOf('America/New_York', '2026-08-08T03:30:00Z'), '2026-08-07 23:30');
    });

    test('UTC is UTC', () {
      expect(wallOf(utcZoneId, '2026-08-08T03:30:00Z'), '2026-08-08 03:30');
      final r = readZone(utcZoneId, DateTime.parse('2026-08-08T03:30:00Z'));
      expect(r.offset, Duration.zero);
      expect(r.abbreviation, 'UTC');
    });

    test('normalizes a caller who hands over a local DateTime', () {
      // Same instant, spelled two ways. Dropping the `toUtc()` normalization
      // shifts the answer by the DEVELOPER's own offset, which is zero on the
      // CI runner and on any machine in UTC — so the bug ships invisibly and
      // reaches only the operators who are not in London.
      final utc = DateTime.parse('2026-08-08T03:30:00Z');
      final asLocal = utc.toLocal();
      expect(asLocal.isUtc, isFalse);
      final fromLocal = readZone('Asia/Kolkata', asLocal);
      expect('${fromLocal.wall.hour}:${fromLocal.wall.minute}', '9:0');
      expect(fromLocal.wall.hour, readZone('Asia/Kolkata', utc).wall.hour);
    });
  });

  group('readZone on a zone it cannot explain', () {
    test('reads as UTC rather than throwing', () {
      // A saved layout outlives the tzdata release that named its zone. If
      // this threw, the whole Operation View would refuse to open — a pane
      // showing the wrong city is recoverable, a view that will not build is
      // not.
      final r = readZone('Mars/Olympus', DateTime.parse('2026-08-08T03:30:00Z'));
      expect(r.offset, Duration.zero);
      expect(r.wall.hour, 3);
      expect(r.wall.minute, 30);
    });
  });

  group('zoneShortName', () {
    test('names a zone the way a tab can hold it', () {
      expect(zoneShortName('America/New_York', deviceLabel: 'Here'), 'New York');
      expect(zoneShortName('Europe/London', deviceLabel: 'Here'), 'London');
      // Three segments — the region prefix is what the picker needs and what
      // a tab has no room for.
      expect(zoneShortName('America/Argentina/Ushuaia', deviceLabel: 'Here'), 'Ushuaia');
      expect(zoneShortName(utcZoneId, deviceLabel: 'Here'), 'UTC');
      expect(zoneShortName(deviceZoneId, deviceLabel: 'Here'), 'Here');
    });
  });

  group('clockZoneOptions', () {
    test('offers UTC and the device first, then the database', () {
      final options = clockZoneOptions(utcLabel: 'UTC', deviceLabel: 'This device');
      expect(options[0]['value'], utcZoneId);
      expect(options[1]['value'], deviceZoneId);
      expect(options.length, greaterThan(300));
      expect(options.map((o) => o['value']), contains('America/New_York'));
    });

    test('every option is a distinct value with a label', () {
      // A duplicate value leaves the row unable to say which option is
      // selected; a null label takes the whole dialog down when it is cast.
      final options = clockZoneOptions(utcLabel: 'UTC', deviceLabel: 'This device');
      final values = options.map((o) => o['value']).toSet();
      expect(values.length, options.length);
      expect(options.every((o) => (o['label'] as String?)?.isNotEmpty ?? false), isTrue);
    });

    test('re-labels the two special rows when the locale changes', () {
      // The list is memoized for the session, so a locale change would
      // otherwise leave the previous language's two labels standing.
      clockZoneOptions(utcLabel: 'UTC', deviceLabel: 'This device');
      final es = clockZoneOptions(utcLabel: 'UTC', deviceLabel: 'Este dispositivo');
      expect(es[1]['label'], 'Este dispositivo');
    });
  });
}
