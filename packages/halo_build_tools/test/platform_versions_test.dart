// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformVersions.project', () {
    const v = PublicVersion(
      main: MainVersion(year: 26, month: 8),
      patch: 1,
      preRelease: 1,
      preReleaseLabel: 'alpha',
    );

    test('projects one shared build number into every platform field', () {
      final p = PlatformVersions.project(publicVersion: v, build: 73);

      // A single monotonic integer reaches Android/iOS/macOS verbatim...
      expect(p.androidVersionCode, 73);
      expect(p.iosBuildNumber, '73');
      // ...and Windows/Linux carry it in the build slot (Windows adds the
      // mandatory .0 revision required for Store submission).
      expect(p.windowsFileVersion, '26.8.73.0');
      expect(p.linuxPackageVersion, '26.8.73');
    });

    test('keeps the pre-release suffix out of the iOS marketing string', () {
      // Apple rejects a marketing version that is not pure X.Y.Z, so the
      // -alpha1 label must NOT leak into CFBundleShortVersionString even though
      // it stays on the Android versionName.
      final p = PlatformVersions.project(publicVersion: v, build: 73);
      expect(p.iosMarketingVersion, '26.8.1');
      expect(p.androidVersionName, '26.8.1-alpha1');
    });

    test('rejects a build number that overflows the 16-bit desktop field', () {
      // The Windows/Linux FILEVERSION field is the tightest cap; guarding it
      // guards every platform.
      expect(
        () => PlatformVersions.project(publicVersion: v, build: 65536),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive build number', () {
      expect(
        () => PlatformVersions.project(publicVersion: v, build: 0),
        throwsArgumentError,
      );
    });
  });
}
