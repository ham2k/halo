// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Projects the app's public version (kPublicVersionInfo, the single source of
// truth in lib/config/version.dart, §2.3) plus the shared build number
// (kBuildNumber) into the native per-platform build-name / build-number that CI
// passes to `flutter build`, per docs/releases.md §2.2. Emits shell KEY=VALUE
// lines, so CI does:
//
//   eval "$(cd app && dart run tool/print_build_versions.dart)"
//   flutter build ipa    --build-name="$HALO_MARKETING"    --build-number="$HALO_BUILD_ID"
//   flutter build apk    --build-name="$HALO_ANDROID_NAME"  --build-number="$HALO_BUILD_ID"
//   flutter build windows --build-name="$HALO_DESKTOP_NAME" --build-number=0
//
// The build number is a single monotonic integer bumped per release; it fits
// every platform's field (it is capped at 16 bits for Windows/Linux), so all
// platforms share one value. Pure Dart: version.dart only imports
// halo_build_tools, so this runs under `dart run` without Flutter.

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:ham2k_logger/config/version.dart';

void main() {
  final v = kPublicVersionInfo;
  final p = PlatformVersions.project(publicVersion: v, build: kBuildNumber);

  final out = {
    // iOS / macOS: CFBundleShortVersionString (no pre-release suffix) + CFBundleVersion
    'HALO_MARKETING': p.iosMarketingVersion,
    'HALO_BUILD_ID': '$kBuildNumber',
    // Android: versionName (keeps the suffix) + versionCode (= build number)
    'HALO_ANDROID_NAME': p.androidVersionName,
    // Windows / Linux: FILEVERSION-safe build-name (major.minor.build), paired
    // with --build-number=0.
    'HALO_DESKTOP_NAME': p.linuxPackageVersion,
  };
  out.forEach((k, value) => print('$k=$value'));
}
