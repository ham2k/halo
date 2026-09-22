// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The delete confirmation names the operation being destroyed by its QSO
// count and date span, so the span has to be unambiguous: a one-day operation
// must not read as a range, and an operation with nothing logged yet must
// produce no line at all rather than a dangling dash next to a Delete button.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation_dialogs.dart';

void main() {
  DateTime utc(int year, int month, int day) => DateTime.utc(year, month, day, 12);

  test('a single day is one date, not a range', () {
    expect(formatOperationDateRange(utc(2026, 1, 3), utc(2026, 1, 3)), 'Jan 3');
  });

  test('different times on the same day are still one date', () {
    expect(formatOperationDateRange(DateTime.utc(2026, 1, 3, 1), DateTime.utc(2026, 1, 3, 23)), 'Jan 3');
  });

  test('within a month the month is not repeated', () {
    expect(formatOperationDateRange(utc(2026, 1, 3), utc(2026, 1, 5)), 'Jan 3 – 5');
  });

  test('across months both months are named', () {
    expect(formatOperationDateRange(utc(2026, 1, 30), utc(2026, 2, 1)), 'Jan 30 – Feb 1');
  });

  test('across years both months are named — the day alone would mislead', () {
    expect(formatOperationDateRange(utc(2025, 12, 31), utc(2026, 1, 1)), 'Dec 31 – Jan 1');
  });

  group('missing bounds', () {
    test('no times at all yields nothing, so the caller drops the line', () {
      expect(formatOperationDateRange(null, null), isEmpty);
    });

    test('one known bound is shown as a single date', () {
      expect(formatOperationDateRange(utc(2026, 1, 3), null), 'Jan 3');
      expect(formatOperationDateRange(null, utc(2026, 1, 3)), 'Jan 3');
    });
  });
}
