// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

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
