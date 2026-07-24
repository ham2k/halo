// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'edition.dart';
import 'main_version.dart';
import 'public_version.dart';

/// The [PublicVersion] and build number read out of `app/lib/config/version.dart`.
typedef VersionFile = ({PublicVersion version, int build});

/// Parses `app/lib/config/version.dart`'s `kPublicVersionInfo` + `kBuildNumber`
/// back out of its Dart source, so halo-ops can read and advance the release
/// identity without the app's toolchain (halo_build_tools can't import app
/// code — the dependency runs the other way).
///
/// Deliberately strict: the file is a plain `const` literal, so a parse failure
/// means the format drifted and the caller should stop loudly rather than cut a
/// release from a half-read version. Throws [FormatException] on any missing
/// field.
VersionFile parseVersionDart(String source) {
  final build = _requireInt(source, RegExp(r'const\s+kBuildNumber\s*=\s*(\d+)\s*;'), 'kBuildNumber');

  // Slice just the kPublicVersionInfo constructor call so the field patterns
  // below can't match a comment or some unrelated declaration.
  final start = source.indexOf('kPublicVersionInfo');
  final open = start < 0 ? -1 : source.indexOf('PublicVersion(', start);
  final close = open < 0 ? -1 : source.indexOf(');', open);
  if (close < 0) {
    throw const FormatException('version.dart: could not find the kPublicVersionInfo = PublicVersion(...) literal');
  }
  final body = source.substring(open, close);

  final year = _requireInt(body, RegExp(r'MainVersion\(\s*year:\s*(\d+)'), 'year');
  final month = _requireInt(body, RegExp(r'month:\s*(\d+)'), 'month');
  final patch = _requireInt(body, RegExp(r'\bpatch:\s*(\d+)'), 'patch');
  final preRelease = _optInt(body, RegExp(r'\bpreRelease:\s*(\d+)'));
  final preReleaseLabel = _optStr(body, RegExp("preReleaseLabel:\\s*'([^']*)'"));
  final preReleasePatch = _optInt(body, RegExp(r'\bpreReleasePatch:\s*(\d+)'));

  final version = PublicVersion(
    main: MainVersion(year: year, month: month),
    patch: patch,
    preRelease: preRelease,
    preReleaseLabel: preReleaseLabel ?? 'pre',
    preReleasePatch: preReleasePatch,
  );
  return (version: version, build: build);
}

/// Returns [source] with `kBuildNumber` set to [build] (the one field a release
/// cut rewrites). Throws if the declaration isn't found.
String rewriteBuildNumber(String source, int build) {
  final re = RegExp(r'const\s+kBuildNumber\s*=\s*\d+\s*;');
  if (!re.hasMatch(source)) {
    throw const FormatException('version.dart: could not find `const kBuildNumber = …;` to rewrite');
  }
  return source.replaceFirst(re, 'const kBuildNumber = $build;');
}

/// The version.dart constant carrying [edition]'s expiration date.
String expirationConstFor(Edition edition) => switch (edition) {
      Edition.dev => 'kDevExpirationDate',
      Edition.next => 'kNextExpirationDate',
      Edition.prod => 'kProdExpirationDate',
    };

/// Reads [edition]'s expiration date (`YYYY-MM-DD`) out of version.dart
/// source; null when the field is empty (= never expires). Throws
/// [FormatException] when the declaration itself is missing — same
/// stop-loudly contract as [parseVersionDart].
String? parseExpirationDate(String source, Edition edition) {
  final name = expirationConstFor(edition);
  final m = RegExp("const\\s+$name\\s*=\\s*'([^']*)'\\s*;").firstMatch(source);
  if (m == null) throw FormatException('version.dart: could not read $name');
  final value = m.group(1)!;
  return value.isEmpty ? null : value;
}

/// Returns [source] with [edition]'s expiration date set to [isoDate]
/// (`YYYY-MM-DD`). Throws when the declaration isn't found.
String rewriteExpirationDate(String source, Edition edition, String isoDate) {
  final name = expirationConstFor(edition);
  final re = RegExp("const\\s+$name\\s*=\\s*'[^']*'\\s*;");
  if (!re.hasMatch(source)) {
    throw FormatException("version.dart: could not find `const $name = '…';` to rewrite");
  }
  return source.replaceFirst(re, "const $name = '$isoDate';");
}

/// Whether [expiration] (a date-only `YYYY-MM-DD` value, i.e. midnight UTC)
/// has passed as of [now]: true starting the day AFTER the expiration date,
/// so a build expiring 2026-08-06 still works for all of the 6th, UTC.
/// Shared by the app's `isBuildExpired` and halo-ops.
bool expirationHasPassed(DateTime expiration, DateTime now) {
  final endOfExpirationDay = DateTime.utc(expiration.year, expiration.month, expiration.day + 1);
  return !now.isBefore(endOfExpirationDay);
}

/// The expiration date (`YYYY-MM-DD`) for a build of [edition] cut or
/// patched on [today]: Dev and Next get two weeks (TODO: extend Next to 3
/// months once the Next line settles down — two weeks fits today's alpha
/// cadence), Regular six calendar months. Shared by `halo-ops release`
/// (stamps version.dart on the cut) and app/tool/stamp_expiration.dart
/// (re-stamps at patch build time, so a patched install's clock restarts).
String expirationDateForBuild(Edition edition, DateTime today) => switch (edition) {
      Edition.dev || Edition.next => isoDate(today.add(const Duration(days: 14))),
      Edition.prod => isoDate(plusCalendarMonths(today, 6)),
    };

/// `2026-08-06` for the given date.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [d] plus [months] calendar months, clamped to the target month's last day
/// (Aug 31 + 6 → Feb 28/29, not Dart's normalized Mar 2/3) so the printed
/// expiration always lands in the intended month.
DateTime plusCalendarMonths(DateTime d, int months) {
  final lastDay = DateTime.utc(d.year, d.month + months + 1, 0).day;
  return DateTime.utc(d.year, d.month + months, d.day > lastDay ? lastDay : d.day);
}

int _requireInt(String s, RegExp re, String field) {
  final m = re.firstMatch(s);
  if (m == null) throw FormatException('version.dart: could not read $field');
  return int.parse(m.group(1)!);
}

int? _optInt(String s, RegExp re) {
  final m = re.firstMatch(s);
  return m == null ? null : int.parse(m.group(1)!);
}

String? _optStr(String s, RegExp re) => re.firstMatch(s)?.group(1);
