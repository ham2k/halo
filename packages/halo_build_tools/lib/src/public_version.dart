// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'main_version.dart';

/// The pieces of a version's human name, in the order a name spells them —
/// `September '26` `ALPHA` `patch 1` `pre 2`. A part that doesn't apply to this
/// version is null (or empty, for the stage marker), so a caller renders what
/// is there rather than re-deriving which parts exist.
class VersionDisplayParts {
  /// The release line, e.g. `September '26`.
  final String mainName;

  /// The product-wide stage marker (`ALPHA`), or empty when the product names
  /// no stage. Not part of the version — see [PublicVersion.displayName].
  final String stageLabel;

  /// The patch number, or null on the first release of a version.
  final int? patch;

  /// The pre-release stage token (`pre`, `alpha`), or null for a stable
  /// release. Lower-case as the version string spells it; a display that wants
  /// it upper-cased says so itself.
  final String? preReleaseLabel;

  /// The pre-release counter, or null for a stable release.
  final int? preRelease;

  /// The Shorebird-patch counter applied on top of a pre-release, if any.
  final int? preReleasePatch;

  /// Private: [PublicVersion.displayParts] is the only way to build these, so
  /// no caller can hand a display a combination a version can't have — a
  /// counter with no label renders `null 1` where one consumer guards on the
  /// label and another on the counter.
  const VersionDisplayParts._({
    required this.mainName,
    required this.stageLabel,
    required this.patch,
    required this.preReleaseLabel,
    required this.preRelease,
    required this.preReleasePatch,
  });

  /// `1` or `1.2` — the pre-release counter with its patch, null for a stable
  /// release. The two are one number to a reader, and every display that shows
  /// the counter shows the patch with it.
  String? get preReleaseCounter => preRelease == null ? null : '$preRelease${preReleasePatch == null ? '' : '.$preReleasePatch'}';
}

/// The human-readable `MAJOR.MINOR.PATCH[-preN[.M]]` version shown in the UI,
/// logs, and sync metadata. See docs/releases.md §2.1.
///
/// This is the *patchable* identity: it lives in compiled Dart
/// (`kPublicVersion`) so a Shorebird patch can rewrite it. No store validates
/// it, which is why the `-preN` pre-release label is safe to use here even
/// though it can't appear in the native marketing version (see
/// [PlatformVersions.iosMarketingVersion]).
class PublicVersion {
  final MainVersion main;
  final int patch;

  /// Pre-release counter, e.g. `1` in `-pre1` or `0` in `-alpha0`. Null for a
  /// stable release.
  final int? preRelease;

  /// The pre-release stage label, e.g. `pre` (the default, → `-pre1`), `alpha`
  /// (→ `-alpha0`), `beta`, or `rc`. Only meaningful when [preRelease] is set.
  final String preReleaseLabel;

  /// Shorebird-patch counter applied on top of a pre-release, e.g. the `1` in
  /// `-pre1.1`. Only meaningful when [preRelease] is set.
  final int? preReleasePatch;

  const PublicVersion({required this.main, required this.patch, this.preRelease, this.preReleaseLabel = 'pre', this.preReleasePatch})
    : assert(patch >= 0, 'patch must not be negative, was $patch'),
      assert(preReleaseLabel != '', 'preReleaseLabel must not be empty'),
      assert(preReleasePatch == null || preRelease != null, 'preReleasePatch requires preRelease to be set');

  /// The full public version string, e.g. `26.8.0-pre1.1` or `26.8.0-alpha0`.
  String get value {
    final base = '${main.year}.${main.month}.$patch';
    if (preRelease == null) return base;
    final pre = '-$preReleaseLabel$preRelease';
    if (preReleasePatch == null) return '$base$pre';
    return '$base$pre.$preReleasePatch';
  }

  /// This version's name broken into its pieces, in the order a name spells
  /// them. For displays that render the pieces themselves — a UI that splits
  /// the name across two lines, or translates the words — rather than
  /// re-deriving which parts a version has from [patch] and [preRelease].
  ///
  /// [displayName] composes these same parts, so a new component added here
  /// reaches every caller by way of one grammar.
  VersionDisplayParts displayParts({String stageLabel = ''}) => VersionDisplayParts._(
    mainName: main.displayName,
    stageLabel: stageLabel,
    // Patch 0 is not a patch: the first release of a version names no
    // patch at all, and `patch 0` would name a thing that doesn't exist.
    patch: patch == 0 ? null : patch,
    preReleaseLabel: preRelease == null ? null : preReleaseLabel,
    preRelease: preRelease,
    preReleasePatch: preRelease == null ? null : preReleasePatch,
  );

  /// The human-friendly line name, e.g. `August '26`, `August '26 patch 2`,
  /// `August '26 pre 1`, `August '26 alpha 0`, or `August '26 patch 2 pre 1`.
  ///
  /// This spelling is CANONICAL: it reaches notice-rule matching, the
  /// extension host and release tags, so it stays English whatever the app's
  /// locale. A UI that wants the operator's language builds its own text from
  /// [displayParts].
  ///
  /// [stageLabel] is a product-wide stage marker (`ALPHA`, `BETA`) that is NOT
  /// part of the version: it applies to every version and every edition for as
  /// long as the product sits in that stage, independent of this version's own
  /// optional `-preN` suffix, and `''` drops it. It goes directly after the
  /// main version, ahead of the patch and pre-release parts —
  /// `August '26 ALPHA patch 1 pre 2`.
  String displayName({String stageLabel = ''}) {
    final parts = displayParts(stageLabel: stageLabel);
    return [
      parts.mainName,
      if (parts.stageLabel.isNotEmpty) parts.stageLabel,
      if (parts.patch != null) 'patch ${parts.patch}',
      if (parts.preReleaseLabel != null) '${parts.preReleaseLabel} ${parts.preReleaseCounter}',
    ].join(' ');
  }

  /// The git ref name for a release of this version at [build] —
  /// `v<value>+<build>` (e.g. `v26.8.1-alpha1+82`). Semver build-metadata
  /// style, and a valid ref (no spaces). See docs/releases.md §2.2.
  String releaseTagName(int build) => 'v$value+$build';

  /// The human release message used for the release commit and annotated tag —
  /// e.g. `Release 26.8.1 alpha 1 (82)`. Note this spells the numeric core
  /// (`26.8.1`), not the [displayName] (`August '26 alpha 1`).
  String releaseMessage(int build) {
    final core = '${main.year}.${main.month}.$patch';
    final pre = preRelease == null ? '' : ' $preReleaseLabel $preRelease${preReleasePatch == null ? '' : '.$preReleasePatch'}';
    return 'Release $core$pre ($build)';
  }

  @override
  String toString() => value;
}
