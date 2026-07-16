// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('BuildId', () {
    test(
      'the docs/releases.md §2.2 worked example: 26.8, built July 29, seq 1',
      () {
        final buildId = BuildId(
          versionYear: 26,
          versionMonth: 8,
          buildMonth: 7,
          buildDay: 29,
          sequence: 1,
        );

        expect(buildId.value, 260807291);
        expect(buildId.windowsLinuxPart, 7291);
      },
    );

    test('max windows/linux part: Dec 31, seq 9 stays under the 65,535 cap', () {
      final buildId = BuildId(
        versionYear: 26,
        versionMonth: 12,
        buildMonth: 12,
        buildDay: 31,
        sequence: 9,
      );

      expect(buildId.windowsLinuxPart, 12319);
      expect(buildId.windowsLinuxPart, lessThan(65535));
    });

    test('build id fits the Android/iOS cap through year 99', () {
      final buildId = BuildId(
        versionYear: 99,
        versionMonth: 12,
        buildMonth: 12,
        buildDay: 31,
        sequence: 9,
      );

      // ≈991M, comfortably under the 2.1B Android cap and 18-char iOS cap.
      expect(buildId.value, 991212319);
      expect(buildId.value.toString().length, lessThanOrEqualTo(18));
    });
  });

  group('PublicVersion', () {
    test('stable release', () {
      final version = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 0,
      );

      expect(version.value, '26.8.0');
      expect(version.displayName, "August '26");
    });

    test('patch increments', () {
      final version = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 3,
      );

      expect(version.value, '26.8.3');
      expect(version.displayName, "August '26 patch 3");
    });

    test('pre-release', () {
      final version = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 0,
        preRelease: 1,
      );

      expect(version.value, '26.8.0-pre1');
      expect(version.displayName, "August '26 pre 1");
    });

    test('shorebird patch on top of a pre-release', () {
      final version = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 0,
        preRelease: 1,
        preReleasePatch: 1,
      );

      expect(version.value, '26.8.0-pre1.1');
      expect(version.displayName, "August '26 pre 1.1");
    });

    test('patch and pre-release together', () {
      final version = PublicVersion(
        main: MainVersion(year: 26, month: 7),
        patch: 2,
        preRelease: 1,
      );

      expect(version.value, '26.7.2-pre1');
      expect(version.displayName, "July '26 patch 2 pre 1");
    });
  });

  group('MainVersion.displayName', () {
    test('formats month name and two-digit year', () {
      expect(MainVersion(year: 26, month: 8).displayName, "August '26");
      expect(MainVersion(year: 26, month: 1).displayName, "January '26");
      expect(MainVersion(year: 10, month: 12).displayName, "December '10");
    });
  });

  group('PlatformVersions.project', () {
    final buildId = BuildId(
      versionYear: 26,
      versionMonth: 8,
      buildMonth: 7,
      buildDay: 29,
      sequence: 1,
    );

    test('the docs/releases.md §2.2 worked example, official 26.8.0 release', () {
      final publicVersion = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 0,
      );

      final platforms = PlatformVersions.project(
        publicVersion: publicVersion,
        buildId: buildId,
      );

      expect(platforms.androidVersionCode, 260807291);
      expect(platforms.androidVersionName, '26.8.0');
      expect(platforms.iosBuildNumber, '260807291');
      expect(platforms.iosMarketingVersion, '26.8.0');
      expect(platforms.windowsFileVersion, '26.8.7291.0');
      expect(platforms.linuxPackageVersion, '26.8.7291');
    });

    test(
      'a Next pre-release keeps -preN out of the iOS marketing version',
      () {
        final publicVersion = PublicVersion(
          main: MainVersion(year: 26, month: 8),
          patch: 0,
          preRelease: 2,
        );

        final platforms = PlatformVersions.project(
          publicVersion: publicVersion,
          buildId: buildId,
        );

        // Apple requires a pure X.Y.Z marketing version; the pre-release
        // label only shows up in the UI, TestFlight notes, and build number.
        expect(platforms.iosMarketingVersion, '26.8.0');
        expect(platforms.androidVersionName, '26.8.0-pre2');
        expect(platforms.iosBuildNumber, buildId.value.toString());
      },
    );

    test('Windows revision is always .0, as required for Store submission', () {
      final publicVersion = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 0,
      );

      final platforms = PlatformVersions.project(
        publicVersion: publicVersion,
        buildId: buildId,
      );

      expect(platforms.windowsFileVersion, endsWith('.0'));
    });
  });
}
