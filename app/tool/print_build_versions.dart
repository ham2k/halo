// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Projects the app's public version (kPublicVersionInfo, the single source of
// truth in lib/config/version.dart, §2.3) into the native per-platform
// build-name / build-number that CI passes to `flutter build`, per
// docs/releases.md §2.2. Emits shell KEY=VALUE lines, so CI does:
//
//   eval "$(cd app && dart run tool/print_build_versions.dart)"
//   flutter build ipa   --build-name="$HALO_MARKETING"    --build-number="$HALO_BUILD_ID"
//   flutter build apk   --build-name="$HALO_ANDROID_NAME"  --build-number="$HALO_BUILD_ID"
//   flutter build windows --build-name="$HALO_DESKTOP_NAME" --build-number=0
//
// The build id is `YYMM·MMDD·S` (version year+month, build month+day, a 1-9
// same-day sequence) — monotonic over time, so iOS/Android accept each upload.
// The build month/day default to today; override with --build-month/--build-day
// (and --sequence for a same-day re-release). Pure Dart: version.dart only
// imports halo_build_tools, so this runs under `dart run` without Flutter.

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:ham2k_logger/config/version.dart';

void main(List<String> arguments) {
  final opts = <String, String>{};
  for (final arg in arguments) {
    if (arg.startsWith('--') && arg.contains('=')) {
      final i = arg.indexOf('=');
      opts[arg.substring(2, i)] = arg.substring(i + 1);
    }
  }

  final now = DateTime.now();
  final v = kPublicVersionInfo;
  final buildId = BuildId(
    versionYear: v.main.year,
    versionMonth: v.main.month,
    buildMonth: int.parse(opts['build-month'] ?? '${now.month}'),
    buildDay: int.parse(opts['build-day'] ?? '${now.day}'),
    sequence: int.parse(opts['sequence'] ?? '1'),
  );
  final p = PlatformVersions.project(publicVersion: v, buildId: buildId);

  // Windows FILEVERSION components are 16-bit, so desktop uses the date-encoded
  // MMDD·10+S part (windowsLinuxPart, always < 65535) as the patch, build 0.
  final desktopName = '${v.main.year}.${v.main.month}.${buildId.windowsLinuxPart}';

  final out = {
    // iOS / macOS: CFBundleShortVersionString (no pre-release suffix) + CFBundleVersion
    'HALO_MARKETING': p.iosMarketingVersion,
    'HALO_BUILD_ID': '${buildId.value}',
    // Android: versionName (keeps the suffix) + versionCode (= build id)
    'HALO_ANDROID_NAME': p.androidVersionName,
    // Windows / Linux: FILEVERSION-safe build-name, paired with --build-number=0
    'HALO_DESKTOP_NAME': desktopName,
  };
  out.forEach((k, value) => print('$k=$value'));
}
