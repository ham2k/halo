// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// A monthly release line, `YY.M` (e.g. `26.8` for the August 2026 line).
///
/// See docs/releases.md §2.1 — the main version is named after its *target*
/// month, which may run ahead of the calendar month it is actually built in.
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class MainVersion {
  final int year;
  final int month;

  const MainVersion({required this.year, required this.month})
    : assert(year >= 10 && year <= 99, 'year must be a two-digit YY, was $year'),
      assert(month >= 1 && month <= 12, 'month must be 1-12, was $month');

  String get label => '$year.$month';

  /// The full month name, e.g. `August`.
  String get monthName => _monthNames[month - 1];

  /// The human-friendly line name, e.g. `August '26`.
  String get displayName => "$monthName '${year.toString().padLeft(2, '0')}";

  @override
  String toString() => label;
}
