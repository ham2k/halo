// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shared by PusherService's reconnect loop and ExtensionService's restart
// loop — pinned here once rather than through either caller, since both
// exercise it only incidentally to their own retry behaviour.

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/tools/backoff.dart';

void main() {
  group('exponentialBackoff', () {
    test('doubles per attempt up to the cap', () {
      const cap = Duration(seconds: 30);
      expect(exponentialBackoff(0, cap: cap), const Duration(seconds: 1));
      expect(exponentialBackoff(1, cap: cap), const Duration(seconds: 2));
      expect(exponentialBackoff(2, cap: cap), const Duration(seconds: 4));
      expect(exponentialBackoff(4, cap: cap), const Duration(seconds: 16));
    });

    test('never exceeds the cap, however large the attempt gets', () {
      const cap = Duration(seconds: 30);
      expect(exponentialBackoff(5, cap: cap), cap, reason: '2^5 = 32 > 30');
      expect(exponentialBackoff(10, cap: cap), cap);
      expect(exponentialBackoff(29, cap: cap), cap);
    });

    test('an unbounded attempt counter never overflows into a negative delay', () {
      // `1 << 63` overflows to a large negative number on the native VM —
      // the whole reason this helper clamps the shift amount before using
      // it, rather than clamping only the final result the way the
      // pre-fix code did.
      const cap = Duration(seconds: 30);
      for (final attempt in [30, 62, 63, 64, 1000]) {
        final delay = exponentialBackoff(attempt, cap: cap);
        expect(delay, cap, reason: 'attempt=$attempt must still clamp to the cap, not go negative');
        expect(delay.isNegative, isFalse, reason: 'attempt=$attempt');
      }
    });
  });
}
