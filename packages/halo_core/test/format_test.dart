// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('fmtTimeBetween', () {
    int ms(int seconds) => seconds * 1000;

    test('formats sub-minute spans in seconds', () {
      expect(fmtTimeBetween(0, ms(30)), '30s');
    });

    test('formats minutes, dropping zero seconds', () {
      expect(fmtTimeBetween(0, ms(45 * 60)), '45m');
      expect(fmtTimeBetween(0, ms(2 * 60 + 15)), '2m 15s');
    });

    test('shows the two most significant units', () {
      // 2h 15m 7s ⇒ only "2h 15m" — the stats line stays short.
      expect(fmtTimeBetween(0, ms(2 * 3600 + 15 * 60 + 7)), '2h 15m');
    });

    test('formats multi-day spans', () {
      expect(fmtTimeBetween(0, ms(24 * 3600 + 3 * 3600)), '1d 3h');
    });

    test('skips interior zero units', () {
      // Exactly 2 hours: no minutes/seconds to show, so just "2h".
      expect(fmtTimeBetween(0, ms(2 * 3600)), '2h');
    });

    test('is order-independent (uses the absolute span)', () {
      expect(fmtTimeBetween(ms(100), ms(40)), '1m');
    });

    test('returns 0s for a zero or negative-collapsing span', () {
      expect(fmtTimeBetween(0, 0), '0s');
      expect(fmtTimeBetween(500, 900), '0s'); // <1s rounds down to 0
    });
  });
}
