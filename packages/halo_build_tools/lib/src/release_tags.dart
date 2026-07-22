// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// The 16-bit Windows/Linux FILEVERSION cap (docs/releases.md §2.2); a build
/// number above this can't be a real release, so it's filtered out — dropping
/// any stray legacy date-encoded tag that would otherwise hijack the "latest
/// build" reading.
const int kBuildCap = 65535;

/// One parsed release tag of the shape `v<public-version>+<build>` — the shape
/// `halo-ops release` produces (e.g. `v26.8.1-alpha1+82`). [version] is the
/// public-version string (`26.8.1-alpha1`), [build] the monotonic build number
/// (`82`).
class ReleaseTag {
  final String tag;
  final String version;
  final int build;

  const ReleaseTag({required this.tag, required this.version, required this.build});

  @override
  String toString() => tag;
}

final RegExp _releaseTagPattern = RegExp(r'^v(.+)\+(\d+)$');

/// Parses the `v<version>+<build>` release tags out of [tagNames], oldest build
/// first. Tags that don't match the shape, or whose build is outside
/// `1..`[kBuildCap], are ignored (non-release tags, stray legacy ids).
List<ReleaseTag> parseReleaseTags(Iterable<String> tagNames) {
  final out = <ReleaseTag>[];
  for (final name in tagNames) {
    final trimmed = name.trim();
    final match = _releaseTagPattern.firstMatch(trimmed);
    if (match == null) continue;
    final build = int.parse(match.group(2)!);
    if (build < 1 || build > kBuildCap) continue;
    out.add(ReleaseTag(tag: trimmed, version: match.group(1)!, build: build));
  }
  out.sort((a, b) => a.build.compareTo(b.build));
  return out;
}

/// The most recent release (highest build) among [tags], or null if empty.
ReleaseTag? latestRelease(List<ReleaseTag> tags) => tags.isEmpty ? null : tags.last;

/// The set of release tags for each public-version line, keyed by version
/// string, each list oldest build first — e.g. `{'26.8.1-alpha1': [+73 … +82]}`.
Map<String, List<ReleaseTag>> releasesByVersion(List<ReleaseTag> tags) {
  final byVersion = <String, List<ReleaseTag>>{};
  for (final t in tags) {
    (byVersion[t.version] ??= <ReleaseTag>[]).add(t);
  }
  return byVersion;
}
