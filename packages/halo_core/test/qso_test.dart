// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

Qso _qso(Map<String, dynamic> their) => Qso(uuid: 'u', operationUuid: 'op', data: {'their': their});

Qso _qsoData(Map<String, dynamic> data) => Qso(uuid: 'u', operationUuid: 'op', data: data);

void main() {
  group('Qso.power', () {
    // Top-level, alongside freq/band/mode — not nested under `our` — to
    // match QSON convention elsewhere in the ecosystem (app-polo).
    test('a number from CAT capture reads back as a number', () {
      expect(_qsoData({'power': 100}).power, 100);
      expect(_qsoData({'power': 76.5}).power, 76.5);
    });

    test('no power at all is null, not zero', () {
      expect(_qsoData({}).power, isNull);
    });

    test('a legacy String value (an older import, before the ADIF fix) coerces instead of throwing', () {
      expect(_qsoData({'power': '100'}).power, 100);
      expect(_qsoData({'power': 'garbage'}).power, isNull);
    });
  });

  group('Qso.theirPower', () {
    test('reads back from their.power (ADIF RX_PWR)', () {
      expect(_qso({'power': 50}).theirPower, 50);
    });

    test('no power at all is null, not zero', () {
      expect(_qso({}).theirPower, isNull);
    });

    test('a legacy String value coerces instead of throwing', () {
      expect(_qso({'power': '50'}).theirPower, 50);
      expect(_qso({'power': 'garbage'}).theirPower, isNull);
    });
  });
  group('Qso guess coalescing & provenance', () {
    test('an entered value wins over the guess and is not flagged guessed', () {
      final q = _qso({
        'state': 'NY',
        'guess': {'state': 'CA'},
      });
      expect(q.theirState, 'NY');
      expect(q.theirFieldIsGuessed('state'), isFalse);
    });

    test('falls back to the guess and flags it as guessed', () {
      final q = _qso({
        'guess': {'state': 'CA', 'name': 'Bob', 'grid': 'FN20', 'flag': '🇺🇸', 'entityPrefix': 'K'},
      });
      expect(q.theirState, 'CA');
      expect(q.theirName, 'Bob');
      expect(q.theirFieldIsGuessed('state'), isTrue);
      expect(q.theirFieldIsGuessed('name'), isTrue);
      expect(q.theirFieldIsGuessed('flag'), isTrue);
      expect(q.theirFieldIsGuessed('entityPrefix'), isTrue);
    });

    test('no value and no guess is neither shown nor flagged', () {
      final q = _qso({});
      expect(q.theirState, isNull);
      expect(q.theirFieldIsGuessed('state'), isFalse);
    });

    test('an empty-string entered value counts as entered, matching the getter', () {
      // The coalescing getter returns '' (not the guess) for an empty string,
      // so provenance must agree: '' is an entered value, not a guess.
      final q = _qso({
        'state': '',
        'guess': {'state': 'CA'},
      });
      expect(q.theirState, '');
      expect(q.theirFieldIsGuessed('state'), isFalse);
    });
  });

  group('Qso location', () {
    test("an entered coordinate is the QSO's location", () {
      final q = _qso({'call': 'W1AW', 'lat': 41.7135, 'lon': -72.7278});
      expect(q.theirExactLocation, const GridLocation(41.7135, -72.7278));
    });

    test('a lookup that reported coordinates answers when nothing was entered', () {
      final q = _qso({
        'call': 'W1AW',
        'guess': {'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278},
      });
      expect(q.theirExactLocation, const GridLocation(41.7135, -72.7278));
    });

    test('an ENTERED grid suppresses the guess\'s coordinate', () {
      // The operator typing a locator is correcting the lookup. Coalescing
      // field by field (as theirGrid does) would pair their square with the
      // lookup's coordinate and put the station straight back at the address
      // they just overrode — so this one deliberately does not.
      final q = _qso({
        'call': 'W1AW',
        'grid': 'AA00aa',
        'guess': {'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278},
      });
      expect(q.theirExactLocation, isNull);
      expect(q.theirGrid, 'AA00aa');
    });

    test('an entered coordinate still beats an entered grid', () {
      final q = _qso({'call': 'W1AW', 'grid': 'AA00aa', 'lat': 41.7135, 'lon': -72.7278});
      expect(q.theirExactLocation, const GridLocation(41.7135, -72.7278));
    });

    test('half a coordinate is no coordinate', () {
      expect(_qso({'call': 'W1AW', 'lat': 41.7135}).theirExactLocation, isNull);
    });

    test("our own location falls back to our grid's centre, and is null when the QSO records neither", () {
      expect(_qsoData({'our': {'lat': 41.5, 'lon': -72.5}}).ourLocation, const GridLocation(41.5, -72.5));
      expect(_qsoData({'our': {'grid': 'FN31pr'}}).ourLocation, gridToLocation('FN31pr'));
      expect(_qsoData({}).ourLocation, isNull, reason: "the operation's own location answers for it");
    });
  });

  group('wrong-typed QSON degrades the field instead of throwing', () {
    // Every getter here reads a blob written by a peer, LoFi, an ADIF import
    // or app-polo — none of which this app's types can enforce. A cast that
    // throws does not degrade one field, it takes down whatever is reading
    // it: a cast on `freq` kills every frame that renders the QSO list, and
    // one on `mode` aborts the mergeFromSync transaction. See
    // qson_values.dart.
    test('a String freq is parsed, not thrown on', () {
      expect(_qsoData({'freq': '14074.5'}).freq, 14074.5);
      expect(_qsoData({'freq': 'twenty metres'}).freq, isNull);
    });

    test('a bool mode reads as absent', () {
      expect(_qsoData({'mode': true}).mode, isNull);
    });

    test('band and notes survive a wrong type the same way', () {
      expect(_qsoData({'band': 20}).band, isNull);
      expect(_qsoData({'notes': false}).notes, isNull);
    });

    test('a their that is not a map leaves every their-field absent rather than throwing', () {
      // The container itself, not a field in it — `data['their'] as Map<...>`
      // is the cast that fires before any getter gets a chance to coalesce.
      final q = _qsoData({'their': 'W1AW'});
      expect(q.theirCall, '');
      expect(q.theirName, isNull);
      expect(q.theirGrid, isNull);
    });

    test('a dynamically-keyed their still reads, because the bridge produces them', () {
      final q = _qsoData({'their': <dynamic, dynamic>{'call': 'W1AW'}});
      expect(q.theirCall, 'W1AW');
    });

    test('a refs that is not a list is no refs, not a crash', () {
      expect(_qsoData({'refs': 'POTA'}).refs, isEmpty);
    });

    test('a String startAtMillis is parsed', () {
      // Imports carry these as strings; drift's typed column would throw on
      // one, so the getter is what has to settle it.
      expect(_qsoData({'startAtMillis': '1721736000000'}).startAtMillis, 1721736000000);
    });

    test("an operation's stationCall and stamps degrade too", () {
      final o = Operation(uuid: 'op', data: {'stationCall': 42, 'createdOnMillis': '1721736000000'});
      expect(o.stationCall, '');
      expect(o.createdAtMillis, 1721736000000);
    });
  });

  group('Operation location', () {
    Operation op(Map<String, dynamic> data) => Operation(uuid: 'op', data: data);

    test('measures from the stored coordinate, and shows it as eight characters', () {
      final o = op({'grid': 'FN31', 'lat': 41.7135, 'lon': -72.7278});
      expect(o.exactLocation, const GridLocation(41.7135, -72.7278));
      expect(o.location, const GridLocation(41.7135, -72.7278));
      expect(o.displayGrid, hasLength(8));
    });

    test('a grid alone still places the operation, at its square centre', () {
      final o = op({'grid': 'FN31pr'});
      expect(o.exactLocation, isNull, reason: 'a typed grid is not a coordinate');
      expect(o.location, gridToLocation('FN31pr'));
      expect(o.displayGrid, 'FN31pr');
    });

    test('an operation with no location at all measures from nothing', () {
      expect(op({}).location, isNull);
      expect(op({}).displayGrid, isNull);
    });
  });
}
