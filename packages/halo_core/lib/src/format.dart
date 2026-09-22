// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small language-neutral formatters shared across the app — kept in core Dart
// next to the domain formatters like `fmtFreq` (ham/radio.dart), rather than in
// the app's i18n layer, because the output is numeric with fixed unit letters
// (d/h/m/s) that don't localize.

/// A compact human duration between two epoch-millisecond timestamps, e.g.
/// "2h 15m", "45m", "30s", "1d 3h". The port of app-polo's
/// @ham2k/lib-format-tools `fmtTimeBetween`, used by the logging panel's
/// operation-statistics line ("{count} QSOs in {time}", "{time} since last").
///
/// Shows the two most significant non-zero units; a bare "0s" for a zero (or
/// negative) span. Always uses the absolute value, so argument order doesn't
/// matter.
String fmtTimeBetween(int fromMillis, int toMillis) {
  var seconds = ((toMillis - fromMillis).abs() / 1000).floor();
  if (seconds <= 0) return '0s';

  final days = seconds ~/ 86400;
  seconds %= 86400;
  final hours = seconds ~/ 3600;
  seconds %= 3600;
  final minutes = seconds ~/ 60;
  seconds %= 60;

  final parts = <String>[if (days > 0) '${days}d', if (hours > 0) '${hours}h', if (minutes > 0) '${minutes}m', if (seconds > 0) '${seconds}s'];
  // Two most-significant units is enough resolution for the stats line and
  // keeps it short ("1d 3h", not "1d 3h 12m 7s").
  return parts.take(2).join(' ');
}
