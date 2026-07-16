// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'main_version.dart';

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

  /// Pre-release counter for Logger Next binaries, e.g. `1` in `-pre1`. Null
  /// for a stable (non-Next) release.
  final int? preRelease;

  /// Shorebird-patch counter applied on top of a pre-release, e.g. the `1` in
  /// `-pre1.1`. Only meaningful when [preRelease] is set.
  final int? preReleasePatch;

  const PublicVersion({
    required this.main,
    required this.patch,
    this.preRelease,
    this.preReleasePatch,
  }) : assert(patch >= 0, 'patch must not be negative, was $patch'),
       assert(
         preReleasePatch == null || preRelease != null,
         'preReleasePatch requires preRelease to be set',
       );

  /// The full public version string, e.g. `26.8.0-pre1.1`.
  String get value {
    final base = '${main.year}.${main.month}.$patch';
    if (preRelease == null) return base;
    final pre = '-pre$preRelease';
    if (preReleasePatch == null) return '$base$pre';
    return '$base$pre.$preReleasePatch';
  }

  /// The human-friendly line name, e.g. `August '26`, `August '26 patch 2`,
  /// `August '26 pre 1`, or `August '26 patch 2 pre 1`.
  String get displayName {
    final parts = <String>[main.displayName];
    if (patch != 0) parts.add('patch $patch');
    if (preRelease != null) {
      parts.add(preReleasePatch == null ? 'pre $preRelease' : 'pre $preRelease.$preReleasePatch');
    }
    return parts.join(' ');
  }

  @override
  String toString() => value;
}
