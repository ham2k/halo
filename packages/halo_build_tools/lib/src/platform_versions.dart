// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'public_version.dart';

// The build number lands in the 16-bit Windows/Linux FILEVERSION field, the
// tightest of the platform caps (Android allows ~2.1 B, iOS 18 digits), so a
// single 0–65535 check covers every platform.
const _windowsMaxPart = 65535;

/// The [PublicVersion] and a shared build number projected into each platform's
/// native version fields, per docs/releases.md §2.2.
class PlatformVersions {
  final int androidVersionCode;
  final String androidVersionName;

  /// `CFBundleVersion`.
  final String iosBuildNumber;

  /// `CFBundleShortVersionString` — pure `X.Y.Z`, no pre-release suffix
  /// (Apple requires this; the pre-release label lives in the UI, TestFlight
  /// notes, and the build number instead).
  final String iosMarketingVersion;

  /// `FILEVERSION`/MSIX `a.b.c.d`; revision is always `0`, as required for
  /// Store submission.
  final String windowsFileVersion;

  final String linuxPackageVersion;

  const PlatformVersions({
    required this.androidVersionCode,
    required this.androidVersionName,
    required this.iosBuildNumber,
    required this.iosMarketingVersion,
    required this.windowsFileVersion,
    required this.linuxPackageVersion,
  });

  factory PlatformVersions.project({
    required PublicVersion publicVersion,
    required int build,
  }) {
    final major = publicVersion.main.year;
    final minor = publicVersion.main.month;

    if (build < 1) {
      throw ArgumentError('build must be a positive integer, was $build');
    }
    if (build > _windowsMaxPart) {
      throw ArgumentError(
        'build $build exceeds the $_windowsMaxPart Windows/Linux '
        'FILEVERSION cap',
      );
    }
    if (major == 0) {
      throw ArgumentError('Windows FILEVERSION major component must not be 0');
    }

    return PlatformVersions(
      androidVersionCode: build,
      androidVersionName: publicVersion.value,
      iosBuildNumber: build.toString(),
      iosMarketingVersion: '$major.$minor.${publicVersion.patch}',
      windowsFileVersion: '$major.$minor.$build.0',
      linuxPackageVersion: '$major.$minor.$build',
    );
  }
}
