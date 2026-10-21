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

  group('gridToLocation, finer than six characters', () {
    // An 8-character cell is 30" of longitude by 15" of latitude — roughly
    // 700m x 460m at this latitude. Decoding one as if it were six characters
    // lands on the subsquare's centre instead, up to ~4km away, which is the
    // whole reason the extra digits get stored.
    test('decodes the extended-square digits of an 8-character locator', () {
      final subsquare = gridToLocation('FN31pr')!;
      final extended = gridToLocation('FN31pr99')!;
      expect(extended.latitude, greaterThan(subsquare.latitude));
      expect(extended.longitude, greaterThan(subsquare.longitude));
      // The last cell of the subsquare, so its centre sits just inside the
      // subsquare's northeast corner.
      expect(extended.latitude, closeTo(subsquare.latitude + (1 / 24) * 0.45, 1e-6));
      expect(extended.longitude, closeTo(subsquare.longitude + (2 / 24) * 0.45, 1e-6));
    });

    test('decodes the sub-subsquare letters of a 10-character locator', () {
      final extended = gridToLocation('FN31pr55')!;
      final subSub = gridToLocation('FN31pr55xx')!;
      expect(subSub.latitude, greaterThan(extended.latitude));
      expect(subSub.longitude, greaterThan(extended.longitude));
      expect(subSub.latitude - extended.latitude, lessThan(1 / 24 / 10 / 2));
    });

    test('a locator centred in its cell round-trips through the encoder', () {
      final location = gridToLocation('FN31pr56')!;
      expect(locationToGrid8(location.latitude, location.longitude), 'FN31pr56');
    });

    test('stops at the last level that parses rather than failing outright', () {
      // Read off the air or out of a data file, a malformed tail is still
      // worth the coarser cell the rest of the locator agrees on.
      expect(gridToLocation('FN31przz'), gridToLocation('FN31pr'), reason: 'extended square must be digits');
      expect(gridToLocation('FN31pr5599'), gridToLocation('FN31pr55'), reason: 'sub-subsquare must be letters');
    });
  });

  group('locationToGrid8', () {
    test('is the 6-character locator plus two digits of extended square', () {
      const arrl = GridLocation(41.7135, -72.7278);
      final grid6 = locationToGrid6(arrl.latitude, arrl.longitude);
      final grid8 = locationToGrid8(arrl.latitude, arrl.longitude);
      expect(grid8, hasLength(8));
      expect(grid8.substring(0, 6), grid6);
      expect(int.tryParse(grid8.substring(6)), isNotNull);
    });

    test('two points in the same subsquare but different extended squares differ', () {
      // The mutation this catches: an encoder that appends '00' (or the same
      // rounding for everything) still passes a length check and still starts
      // with the right six characters.
      final west = locationToGrid8(41.7135, -72.7500);
      final east = locationToGrid8(41.7135, -72.7000);
      expect(west.substring(0, 6), east.substring(0, 6));
      expect(west, isNot(east));
    });

    test('clamps at the poles and the antimeridian instead of running off the alphabet', () {
      expect(locationToGrid8(90, 180), isNotEmpty);
      expect(locationToGrid8(-90, -180), isNotEmpty);
    });
  });

  group('locationFromLatLon', () {
    test('takes a numeric pair, whatever numeric type the JSON carried', () {
      expect(locationFromLatLon(41, -72), const GridLocation(41, -72), reason: 'ints, from a hand-written file');
      expect(locationFromLatLon(41.5, -72.5), const GridLocation(41.5, -72.5));
    });

    test('refuses anything that is not a usable coordinate', () {
      expect(locationFromLatLon(null, null), isNull);
      expect(locationFromLatLon(41.5, null), isNull, reason: 'half a coordinate is not a location');
      expect(locationFromLatLon('41.5', '-72.5'), isNull, reason: 'strings are not silently coerced');
      expect(locationFromLatLon(double.nan, 0), isNull);
      expect(locationFromLatLon(double.infinity, 0), isNull);
      expect(locationFromLatLon(91, 0), isNull);
      expect(locationFromLatLon(0, -181), isNull);
    });

    test('refuses a placeholder pair, so the coarser fallbacks still answer', () {
      // Either pair would outrank the grid/state/entity chain and draw the
      // station at Null Island or the South Pole.
      expect(locationFromLatLon(0, 0), isNull, reason: 'the default a writer with no fix leaves behind');
      expect(locationFromLatLon(-89.979167, -179.958333), isNull, reason: 'what QRZ sends beside AA00aa');
      expect(locationFromLatLon(-89.979, -179.958), isNull, reason: 'the same center, rounded');
      expect(locationFromLatLon(-89.5, -179), isNull, reason: 'the AA00 center');
    });

    test('keeps real coordinates that sit near a placeholder', () {
      // A guard wider than the placeholder itself would erase real stations.
      expect(locationFromLatLon(0, 0.5), const GridLocation(0, 0.5), reason: 'on the equator');
      expect(locationFromLatLon(0.5, 0), const GridLocation(0.5, 0), reason: 'on the prime meridian');
      expect(locationFromLatLon(-90, 0), const GridLocation(-90, 0), reason: 'the South Pole station');
      expect(locationFromLatLon(-89.2, -178.5), const GridLocation(-89.2, -178.5), reason: 'inside AA00, but not its center');
    });
  });

  group('gridForDisplay', () {
    tearDown(GridPrecision.reset);

    test('shows six characters for a real coordinate by default', () {
      // Six is the default because a locator's length is a claim, and eight
      // characters states the operator's position to a few hundred metres.
      final shown = gridForDisplay(lat: 41.7135, lon: -72.7278, grid: 'FN31')!;
      expect(shown, hasLength(6));
      expect(shown, locationToGrid6(41.7135, -72.7278));
    });

    test('shows eight characters for a real coordinate once asked to', () {
      GridPrecision.configure(GridPrecision.eight);
      final shown = gridForDisplay(lat: 41.7135, lon: -72.7278, grid: 'FN31')!;
      expect(shown, hasLength(8));
      expect(shown, locationToGrid8(41.7135, -72.7278));
    });

    test('never lengthens a locator whose coordinate is its own center', () {
      // The trap: every writer of a hand-stated grid now stores the square's
      // center beside it, so the pair alone can no longer be read as "this
      // location is known to eight characters". Rendering it would state a
      // precision the operator never claimed — and it would STICK, because
      // the setup sheet seeds its Grid field from this string and saves it
      // back on the next blur.
      GridPrecision.configure(GridPrecision.eight);
      final center = gridToLocation('FN31pr')!;
      expect(gridForDisplay(lat: center.latitude, lon: center.longitude, grid: 'FN31pr'), 'FN31pr');

      // Shorter squares too, and at six characters as readily as at eight.
      final coarse = gridToLocation('FN31')!;
      expect(gridForDisplay(lat: coarse.latitude, lon: coarse.longitude, grid: 'FN31'), 'FN31');
      GridPrecision.reset();
      expect(gridForDisplay(lat: coarse.latitude, lon: coarse.longitude, grid: 'FN31'), 'FN31');
    });

    test('a fix inside the stored square still reports the fix', () {
      // The cap above keys on the coordinate BEING the center, not on it
      // falling inside the square: a real fix that happens to sit in FN31pr
      // is a finer statement than FN31pr, and must not be cut back to it.
      GridPrecision.configure(GridPrecision.eight);
      expect(gridForDisplay(lat: 41.7135, lon: -72.7278, grid: 'FN31pr'), locationToGrid8(41.7135, -72.7278));
      expect(gridForDisplay(lat: 41.7135, lon: -72.7278, grid: 'FN31pr'), isNot('FN31pr'));
    });

    test("the coordinate wins over a stored grid that disagrees with it", () {
      // Both are stored, and a writer that set one without the other is the
      // bug this precedence exists to survive: the coordinate is what every
      // distance is measured from, so it is what the operator must be shown.
      expect(gridForDisplay(lat: 41.7135, lon: -72.7278, grid: 'AA00aa'), startsWith('FN31'));
    });

    test('falls back to the stored grid, normalized, when there is no coordinate', () {
      expect(gridForDisplay(grid: 'fn31PR'), 'FN31pr');
      expect(gridForDisplay(lat: null, lon: null, grid: 'FN31'), 'FN31');
    });

    test('is null when the record names no location at all', () {
      expect(gridForDisplay(), isNull);
      expect(gridForDisplay(grid: '   '), isNull);
    });
  });

  group('isGridCenter', () {
    test('a center is its own center, and a fix inside the square is not', () {
      final center = gridToLocation('FN31pr')!;
      expect(isGridCenter(center, 'FN31pr'), isTrue);
      expect(isGridCenter(const GridLocation(41.7135, -72.7278), 'FN31pr'), isFalse);
    });

    test('a center that arrived by another route still reads as one', () {
      // Not every center this recognises was computed here. `mergeLookup.ts`
      // fills a lookup's coordinate from its grid with @ham2k/lib-geo-tools,
      // which sums the same arithmetic in a different order, and an ADIF
      // round trip stores coordinates to a thousandth of a minute (~1.8 m).
      // Exact equality would answer "no" to centers that plainly are ones,
      // and the locator would then be rendered longer than anyone claimed.
      final center = gridToLocation('FN31pr')!;
      expect(isGridCenter(GridLocation(center.latitude + 1e-12, center.longitude), 'FN31pr'), isTrue);
      double toAdifAndBack(double v) => (v * 60000).round() / 60000;
      expect(isGridCenter(GridLocation(toAdifAndBack(center.latitude), toAdifAndBack(center.longitude)), 'FN31pr'), isTrue);
    });

    test('the tolerance scales with the square, never a fixed number of degrees', () {
      // A hundredth of FN31 is ~1.1 km of latitude; a hundredth of FN31pr55
      // is ~4.6 m. One tolerance in degrees cannot be right for both, and the
      // wrong one either swallows a real fix or rejects a real center.
      final coarse = gridToLocation('FN31')!;
      final fine = gridToLocation('FN31pr55')!;
      expect(isGridCenter(GridLocation(coarse.latitude + 0.005, coarse.longitude), 'FN31'), isTrue);
      expect(isGridCenter(GridLocation(fine.latitude + 0.005, fine.longitude), 'FN31pr55'), isFalse);
    });

    test('a locator that does not decode is nobody\'s center', () {
      expect(isGridCenter(const GridLocation(41.7135, -72.7278), null), isFalse);
      expect(isGridCenter(const GridLocation(41.7135, -72.7278), 'NOT_A_GRID'), isFalse);
    });
  });

  group('locationForStatedGrid', () {
    test("gives the square's own center, so a stated grid carries a coordinate", () {
      expect(locationForStatedGrid('FN31pr'), gridToLocation('FN31pr'));
      expect(locationForStatedGrid(' fn31 '), gridToLocation('FN31'));
    });

    test('refuses a placeholder, which names no location at all', () {
      // AA00 decodes like any other square. Stored as a coordinate it would
      // outrank the entity and region centroids that could have answered
      // honestly, and plant the station off Antarctica.
      expect(locationForStatedGrid('AA00'), isNull);
      expect(locationForStatedGrid('AA00aa'), isNull);
      expect(gridToLocation('AA00'), isNotNull);
    });

    test('is null for nothing to place', () {
      expect(locationForStatedGrid(null), isNull);
      expect(locationForStatedGrid('  '), isNull);
      expect(locationForStatedGrid('NOTAGRID'), isNull);
    });
  });
}
