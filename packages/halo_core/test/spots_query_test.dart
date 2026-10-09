// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ctx.getSpots`' options, as both hosts read them. The trap on the parse side
// is leniency: a misspelled or mistyped option dropped quietly answers the
// whole board, and the extension trusts that answer as the narrower one it
// asked for.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _spot({String call = 'K1ABC', String? band = '20m', String? mode = 'SSB', int ageMinutes = 1, String hookKey = 'pota'}) => {
  'their': {'call': call},
  'band': ?band,
  'mode': ?mode,
  'spot': {'timeInMillis': nowMillis() - ageMinutes * Duration.millisecondsPerMinute, 'source': 'test'},
  'hookKey': hookKey,
};

bool _passes(SpotsQuery query, Map<String, dynamic> spot) => query.narrow([spot]).isNotEmpty;

void main() {
  group('fromParams', () {
    test('no options is the operator\'s board, annotated', () {
      final query = SpotsQuery.fromParams(const {});
      expect(query.base, SpotsBase.user);
      expect(query.annotate, isTrue);
    });

    // The kernel spreads the caller's options and sends the ones it was not
    // given as undefined; refusing those would refuse every plain call.
    test('null values read as absent', () {
      final query = SpotsQuery.fromParams(const {'filter': null, 'operationUuid': null, 'band': null});
      expect(query.base, SpotsBase.user);
      expect(query.operationUuid, isNull);
      expect(query.bands, isEmpty);
    });

    test('rejects what it cannot answer exactly', () {
      for (final params in <Map<String, dynamic>>[
        {'bands': '20m'}, // misspelled
        {'filter': 'mine'},
        {'maxAgeMinutes': '30'},
        {'maxAgeMinutes': -1},
        {'maxAgeMinutes': double.nan},
        {'maxAgeMinutes': double.infinity},
        {'band': <String>[]}, // "none of these" has no answer
        {'mode': ''},
        {'source': 3},
        {'annotate': 'no'},
        {'operationUuid': 7},
      ]) {
        expect(() => SpotsQuery.fromParams(params), throwsFormatException, reason: '$params');
      }
    });
  });

  group('narrow', () {
    test('maxAgeMinutes is measured on the spot\'s own time', () {
      final query = SpotsQuery.fromParams(const {'maxAgeMinutes': 30});
      expect(_passes(query, _spot(ageMinutes: 10)), isTrue);
      expect(_passes(query, _spot(ageMinutes: 45)), isFalse);
    });

    // Truncated to whole minutes, half a minute would become "posted at or
    // after now" — an empty board for a caller asking for the freshest spots.
    test('a fractional maxAgeMinutes is kept, not truncated', () {
      final query = SpotsQuery.fromParams(const {'maxAgeMinutes': 1.5});
      expect(_passes(query, _spot(ageMinutes: 1)), isTrue);
    });

    test('band ignores case, and a band-less spot is on no band', () {
      final query = SpotsQuery.fromParams(const {
        'band': ['20M', '40m'],
      });
      expect(_passes(query, _spot(band: '20m')), isTrue);
      expect(_passes(query, _spot(band: '40m')), isTrue);
      expect(_passes(query, _spot(band: '15m')), isFalse);
      expect(_passes(query, _spot(band: null)), isFalse);
    });

    // A source reports what the radio on the other end said: USB, not SSB. A
    // literal comparison would hide every phone spot from a caller asking for
    // the family by its everyday name.
    test('mode takes the families getHistoryForCall takes', () {
      expect(_passes(SpotsQuery.fromParams(const {'mode': 'SSB'}), _spot(mode: 'USB')), isTrue);
      expect(_passes(SpotsQuery.fromParams(const {'mode': 'Phone'}), _spot(mode: 'FM')), isTrue);
      expect(_passes(SpotsQuery.fromParams(const {'mode': 'Digital'}), _spot(mode: 'FT8')), isTrue);
      expect(_passes(SpotsQuery.fromParams(const {'mode': 'Digital'}), _spot(mode: 'CW')), isFalse);
      expect(_passes(SpotsQuery.fromParams(const {'mode': 'FT8'}), _spot(mode: 'FT4')), isFalse);
    });

    test('source matches the hook key that offered the spot', () {
      final query = SpotsQuery.fromParams(const {'source': 'sota'});
      expect(_passes(query, _spot(hookKey: 'sota')), isTrue);
      expect(_passes(query, _spot(hookKey: 'pota')), isFalse);
    });
  });
}
