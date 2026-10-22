// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every text search in the app matches through `matchesWordStart`, so what
// these pin down is what an operator typing a word gets back everywhere at
// once: the command palette, the Settings search, the option pickers, the
// band and mode menus. A run buried mid-word is never what was meant.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('matchesWordStart', () {
    test('a word typed finds a word that starts with it, in any case', () {
      expect(matchesWordStart('Preferred Bands', 'band'), isTrue);
      expect(matchesWordStart('Preferred Bands', 'PREF'), isTrue);
    });

    test('a run buried inside a word does not match', () {
      // The complaint this exists for: SET AND offered the Bands setting.
      expect(matchesWordStart('Preferred Bands', 'and'), isFalse);
      expect(matchesWordStart('USB', 'sb'), isFalse);
    });

    test('a band is not found by the end of a longer one', () {
      // `2m` narrowing the band menu must not keep 12m in it.
      expect(matchesWordStart('12m', '2m'), isFalse);
      expect(matchesWordStart('2m', '2m'), isTrue);
    });

    test('a letter after a digit is not a word start', () {
      // Otherwise `m` begins every band name from 2m to 160m.
      expect(matchesWordStart('160m', 'm'), isFalse);
    });

    test('punctuation, camelCase humps and a digit after letters all start words', () {
      expect(matchesWordStart('IC-705', '705'), isTrue);
      expect(matchesWordStart('showGridField', 'grid'), isTrue);
      expect(matchesWordStart('FT8', '8'), isTrue);
    });

    test('a later occurrence at a word start still counts', () {
      // The first "and" is buried in "Bands"; the second is a word.
      expect(matchesWordStart('Bands and modes', 'and'), isTrue);
    });

    test('a phrase must appear as a phrase', () {
      expect(matchesWordStart('Default report — CW and data', 'cw and'), isTrue);
      expect(matchesWordStart('Default report — CW and data', 'cw data'), isFalse);
    });

    test('letters beyond ASCII separate nothing', () {
      // Treating Ñ as punctuation would make "andu" begin a word in Ñandu.
      expect(matchesWordStart('Ñandu', 'andu'), isFalse);
      expect(matchesWordStart('Ñandu', 'ñan'), isTrue);
    });

    test('an empty needle matches, as it would for contains', () {
      expect(matchesWordStart('anything', ''), isTrue);
    });
  });
}
