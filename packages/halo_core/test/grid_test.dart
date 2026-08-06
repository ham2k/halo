// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('gridToLocation', () {
    test('decodes a 6-character grid to near its real-world location', () {
      // FN31pr is ARRL HQ's grid square (Newington, CT — ~41.71N, 72.73W).
      final location = gridToLocation('FN31pr')!;
      expect(location.latitude, closeTo(41.71, 0.05));
      expect(location.longitude, closeTo(-72.71, 0.05));
    });

    test('decodes a 4-character grid to the center of its square', () {
      final location = gridToLocation('FN31')!;
      expect(location.latitude, closeTo(41.5, 0.5));
      expect(location.longitude, closeTo(-73, 1));
    });

    test('is case-insensitive', () {
      final upper = gridToLocation('FN31PR')!;
      final lower = gridToLocation('fn31pr')!;
      expect(lower.latitude, upper.latitude);
      expect(lower.longitude, upper.longitude);
    });

    test('returns null for invalid input', () {
      expect(gridToLocation(null), isNull);
      expect(gridToLocation(''), isNull);
      expect(gridToLocation('F1'), isNull); // too short
      expect(gridToLocation('991a'), isNull); // field chars must be letters
      expect(gridToLocation('FNaa'), isNull); // square chars must be digits
    });
  });

  group('normalizeGrid', () {
    // Grid input fields are uppercase-only like every other logging
    // control, so stored values depend on this restoring the conventional
    // Maidenhead casing — without it, a typed FN31PR and a lookup-guessed
    // FN31pr would count as different values (e.g. the More pane's
    // touched-vs-displayed comparison).
    test('restores conventional casing regardless of input case', () {
      expect(normalizeGrid('FN31PR'), 'FN31pr');
      expect(normalizeGrid('fn31pr'), 'FN31pr');
      expect(normalizeGrid('fn31PR'), 'FN31pr');
      expect(normalizeGrid('fn31'), 'FN31');
      expect(normalizeGrid('fn31pr60'), 'FN31pr60');
      expect(normalizeGrid('fn31pr60ax'), 'FN31pr60ax');
    });

    test('trims whitespace', () {
      expect(normalizeGrid(' fn31pr '), 'FN31pr');
    });

    test('leaves non-locator text unchanged — it formats, not validates', () {
      expect(normalizeGrid('W1AW'), 'W1AW'); // a callsign, not a grid
      expect(normalizeGrid('fn3'), 'fn3'); // too short
      expect(normalizeGrid('YZ31pr'), 'YZ31pr'); // field letters out of range
      expect(normalizeGrid(''), '');
    });
  });

  group('isWellFormedGrid', () {
    test('accepts every locator length, in any case', () {
      expect(isWellFormedGrid('FN31'), isTrue);
      expect(isWellFormedGrid('FN31pr'), isTrue);
      expect(isWellFormedGrid('FN31pr60'), isTrue);
      expect(isWellFormedGrid('FN31pr60ax'), isTrue);
      expect(isWellFormedGrid('fn31PR'), isTrue);
      expect(isWellFormedGrid(' FN31pr '), isTrue, reason: 'typed values arrive with whitespace');
    });

    test('rejects what an operator can type by mistake', () {
      expect(isWellFormedGrid('FN'), isFalse, reason: 'half a locator');
      expect(isWellFormedGrid('FN3'), isFalse);
      expect(isWellFormedGrid('FN31p'), isFalse, reason: 'half a subsquare');
      expect(isWellFormedGrid('YZ31pr'), isFalse, reason: 'field letters stop at R');
      expect(isWellFormedGrid('W1AW'), isFalse, reason: 'a callsign');
      expect(isWellFormedGrid(''), isFalse);
      expect(isWellFormedGrid(null), isFalse);
    });

    test('is stricter than the decoder, which is the point', () {
      // gridToLocation falls back to the square's centre for a subsquare it
      // can't read, so it answers for text no operator meant to type. Using it
      // as the validator would accept both of these.
      expect(gridToLocation('FN31ZZ'), isNotNull);
      expect(isWellFormedGrid('FN31ZZ'), isFalse);
      expect(gridToLocation('FN31pr!!'), isNotNull);
      expect(isWellFormedGrid('FN31pr!!'), isFalse);
    });
  });
}
