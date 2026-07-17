// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'build_id.dart';
import 'public_version.dart';

const _androidMaxVersionCode = 2100000000;
const _iosMaxBuildNumberLength = 18;
const _windowsMaxPart = 65535;

/// The [BuildId] and [PublicVersion] projected into each platform's native
/// version fields, per docs/releases.md §2.2.
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
    required BuildId buildId,
  }) {
    final major = publicVersion.main.year;
    final minor = publicVersion.main.month;
    final windowsLinuxPart = buildId.windowsLinuxPart;

    final androidVersionCode = buildId.value;
    if (androidVersionCode > _androidMaxVersionCode) {
      throw ArgumentError(
        'Android versionCode $androidVersionCode exceeds the '
        '$_androidMaxVersionCode cap',
      );
    }

    final iosBuildNumber = buildId.value.toString();
    if (iosBuildNumber.length > _iosMaxBuildNumberLength) {
      throw ArgumentError(
        'iOS/macOS CFBundleVersion "$iosBuildNumber" exceeds '
        '$_iosMaxBuildNumberLength characters',
      );
    }

    if (windowsLinuxPart > _windowsMaxPart) {
      throw ArgumentError(
        'Windows/Linux build part $windowsLinuxPart exceeds the '
        '$_windowsMaxPart per-field cap',
      );
    }
    if (major == 0) {
      throw ArgumentError('Windows FILEVERSION major component must not be 0');
    }

    return PlatformVersions(
      androidVersionCode: androidVersionCode,
      androidVersionName: publicVersion.value,
      iosBuildNumber: iosBuildNumber,
      iosMarketingVersion: '$major.$minor.${publicVersion.patch}',
      windowsFileVersion: '$major.$minor.$windowsLinuxPart.0',
      linuxPackageVersion: '$major.$minor.$windowsLinuxPart',
    );
  }
}
