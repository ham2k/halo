// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

// Shorebird Dart-patch support for halo-ops (ham2k/app-halo-dist).
//
// A patch may carry only pure-Dart (and asset) changes (docs/releases.md §4.2);
// anything touching native platform code, plugins, or the dependency manifest
// needs a full binary release. `halo-ops patch` diffs the release tag → HEAD and
// classifies the changed paths so it can refuse an un-patchable set BEFORE
// spending a CI build. This is a conservative pre-flight — Shorebird's own
// build-time diff of the compiled artifact is the authoritative gate.

import 'edition.dart';

/// The reusable git tag whose push triggers [edition]'s Codemagic patch
/// workflows — `patch-next` / `patch-dev` (codemagic.yaml). Mirrors how a `v*`
/// tag triggers the release matrix.
String patchTagName(Edition edition) => 'patch-${edition.name}';

/// The platforms with a wired `*-<edition>-patch` Codemagic workflow: Next has
/// iOS/macOS/Android, Dev has iOS/macOS, prod isn't wired yet. An empty list
/// means "no patch plane for this edition."
List<String> patchPlatformsForEdition(Edition edition) {
  switch (edition) {
    case Edition.next:
      return const ['ios', 'macos', 'android'];
    case Edition.dev:
      return const ['ios', 'macos'];
    case Edition.prod:
      return const [];
  }
}

/// Whether a changed [path] (repo-relative, forward slashes) forces a full
/// binary release — i.e. it falls outside the pure-Dart/asset surface a
/// Shorebird patch can carry (docs/releases.md §4.2).
bool isPatchBreakingPath(String path) {
  // Native platform projects (Gradle/Xcode/CMake, entitlements, Info.plist,
  // manifests, plugin registration): a patch can't change compiled native code.
  if (RegExp(r'(^|/)(android|ios|macos|windows|linux)/').hasMatch(path)) return true;
  // Dependency manifests: a changed dep can pull in a new plugin / native code,
  // and even a pure-Dart bump shifts the resolved snapshot — treat as breaking.
  final base = path.split('/').last;
  return base == 'pubspec.yaml' || base == 'pubspec.lock';
}

/// The changed paths since a release, split into the ones that force a full
/// release ([breaking]) and the rest ([safe]).
class PatchCompatibility {
  final List<String> breaking;
  final List<String> safe;

  const PatchCompatibility({required this.breaking, required this.safe});

  /// True when nothing outside the Dart/asset surface changed.
  bool get isPatchable => breaking.isEmpty;
}

/// Classifies [paths] (a `git diff --name-only` list) for patch compatibility.
PatchCompatibility classifyPatchChanges(Iterable<String> paths) {
  final breaking = <String>[];
  final safe = <String>[];
  for (final p in paths) {
    final path = p.trim();
    if (path.isEmpty) continue;
    (isPatchBreakingPath(path) ? breaking : safe).add(path);
  }
  return PatchCompatibility(breaking: breaking, safe: safe);
}
