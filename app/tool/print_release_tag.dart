// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Prints the git ref name and human-readable message for the current release,
// derived from lib/config/version.dart — consumed by scripts/release.sh.
//
//   HALO_TAG_NAME=v26.8.1-alpha1+73        (a valid git ref: no spaces)
//   HALO_TAG_MSG=Release 26.8.1 alpha 1 (73)   (commit + annotated-tag message)
//
// The ref name is `v<public-version>+<build>` (semver build-metadata style); the
// message spells out the same identity for humans. The build number is
// kBuildNumber, unless HALO_BUILD_NUMBER is set in the environment — the release
// script passes the tag-derived *next* number that way so it can preview a tag
// (--dry-run) before writing kBuildNumber into version.dart. Pure Dart, so it
// runs under `dart run` without the Flutter toolchain. The `HALO_` prefix lets
// the caller grep past dart's "Running build hooks..." noise.

import 'dart:io';

import 'package:ham2k_logger/config/version.dart';

void main() {
  final v = kPublicVersionInfo;
  final build =
      int.tryParse(Platform.environment['HALO_BUILD_NUMBER'] ?? '') ??
      kBuildNumber;

  final core = '${v.main.year}.${v.main.month}.${v.patch}';
  final pre = v.preRelease == null
      ? ''
      : ' ${v.preReleaseLabel} ${v.preRelease}'
            '${v.preReleasePatch == null ? '' : '.${v.preReleasePatch}'}';

  print('HALO_TAG_NAME=v${v.value}+$build');
  print('HALO_TAG_MSG=Release $core$pre ($build)');
}
