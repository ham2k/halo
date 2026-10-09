// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'edition.dart';

/// The 16-bit Windows/Linux FILEVERSION cap (docs/releases.md §2.2); a build
/// number above this can't be a real release, so it's filtered out — dropping
/// any stray legacy date-encoded tag that would otherwise hijack the "latest
/// build" reading.
const int kBuildCap = 65535;

/// One parsed release tag of the shape `<edition>-v<public-version>+<build>` —
/// the shape `halo-ops release` produces (e.g. `next-v26.10.0+180`,
/// `prod-v26.9.0+179`). A bare `v<version>+<build>` is a Next release cut
/// before tags named their edition. [version] is the public-version string
/// (`26.10.0`), [build] the build number (`180`), which is unique across
/// every edition (docs/releases.md §2.2).
class ReleaseTag {
  final String tag;
  final Edition edition;
  final String version;
  final int build;

  const ReleaseTag({required this.tag, required this.edition, required this.version, required this.build});

  @override
  String toString() => tag;
}

final RegExp _releaseTagPattern = RegExp(r'^(?:(next|prod)-)?v(.+)\+(\d+)$');

/// Parses the release tags of every edition out of [tagNames], oldest build
/// first. Tags that don't match the shape, or whose build is outside
/// `1..`[kBuildCap], are ignored (non-release tags, stray legacy ids).
List<ReleaseTag> parseReleaseTags(Iterable<String> tagNames) {
  final out = <ReleaseTag>[];
  for (final name in tagNames) {
    final trimmed = name.trim();
    final match = _releaseTagPattern.firstMatch(trimmed);
    if (match == null) continue;
    final build = int.parse(match.group(3)!);
    if (build < 1 || build > kBuildCap) continue;
    final edition = match.group(1) == 'prod' ? Edition.prod : Edition.next;
    out.add(ReleaseTag(tag: trimmed, edition: edition, version: match.group(2)!, build: build));
  }
  out.sort((a, b) => a.build.compareTo(b.build));
  return out;
}

/// The most recent release (highest build) among [tags] — of [edition] alone
/// when one is given — or null if there is none. Without [edition] it is the
/// build the shared counter last handed out.
ReleaseTag? latestRelease(List<ReleaseTag> tags, {Edition? edition}) => tags.where((t) => edition == null || t.edition == edition).lastOrNull;

/// The set of release tags for each public-version line, keyed by version
/// string, each list oldest build first — e.g. `{'26.8.1-alpha1': [+73 … +82]}`.
Map<String, List<ReleaseTag>> releasesByVersion(List<ReleaseTag> tags) {
  final byVersion = <String, List<ReleaseTag>>{};
  for (final t in tags) {
    (byVersion[t.version] ??= <ReleaseTag>[]).add(t);
  }
  return byVersion;
}
