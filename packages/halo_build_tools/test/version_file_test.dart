// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

const _preRelease = '''
const kPublicVersionInfo = PublicVersion(
  main: MainVersion(year: 26, month: 8),
  patch: 1,
  preRelease: 1,
  preReleaseLabel: 'alpha',
);

const kBuildNumber = 82;
''';

const _stable = '''
const kPublicVersionInfo = PublicVersion(
  main: MainVersion(year: 26, month: 9),
  patch: 0,
);
const kBuildNumber = 90;
''';

void main() {
  group('parseVersionDart', () {
    test('reads a pre-release version + build', () {
      final v = parseVersionDart(_preRelease);
      expect(v.build, 82);
      expect(v.version.value, '26.8.1-alpha1');
      expect(v.version.main.year, 26);
      expect(v.version.main.month, 8);
    });

    test('reads a stable version (no pre-release fields)', () {
      final v = parseVersionDart(_stable);
      expect(v.build, 90);
      expect(v.version.value, '26.9.0');
      expect(v.version.preRelease, isNull);
    });

    test('throws (fail loud) when a required field is missing', () {
      expect(() => parseVersionDart('const kBuildNumber = 5;'), throwsFormatException);
      expect(() => parseVersionDart(_preRelease.replaceAll('kBuildNumber = 82', 'x = 1')), throwsFormatException);
    });

    test('parses the real app version.dart — guards against format drift', () {
      // The parser regex-reads a hand-maintained const; if that file's shape
      // changes so the parser can't read it, a release cut would fail — catch
      // it here instead.
      final file = File('../../app/lib/config/version.dart');
      if (!file.existsSync()) return; // not run from the repo (e.g. isolated CI unit run)
      final v = parseVersionDart(file.readAsStringSync());
      expect(v.build, greaterThan(0));
      expect(v.version.value, isNotEmpty);
    });
  });

  group('rewriteBuildNumber', () {
    test('replaces only the build number', () {
      final out = rewriteBuildNumber(_preRelease, 83);
      expect(parseVersionDart(out).build, 83);
      expect(out.contains('year: 26'), isTrue); // nothing else touched
    });

    test('throws when kBuildNumber is absent', () {
      expect(() => rewriteBuildNumber('const x = 1;', 83), throwsFormatException);
    });
  });

  group('PublicVersion release identity', () {
    test('tag name + message for a pre-release', () {
      final v = parseVersionDart(_preRelease).version;
      expect(v.releaseTagName(83), 'v26.8.1-alpha1+83');
      expect(v.releaseMessage(83), 'Release 26.8.1 alpha 1 (83)');
    });

    test('a stable release message has no pre-release clause', () {
      final v = parseVersionDart(_stable).version;
      expect(v.releaseTagName(90), 'v26.9.0+90');
      expect(v.releaseMessage(90), 'Release 26.9.0 (90)');
    });

    test('a shorebird-patched pre-release carries the .M patch counter', () {
      const v = PublicVersion(
        main: MainVersion(year: 26, month: 8),
        patch: 1,
        preRelease: 1,
        preReleaseLabel: 'pre',
        preReleasePatch: 2,
      );
      expect(v.releaseTagName(84), 'v26.8.1-pre1.2+84');
      expect(v.releaseMessage(84), 'Release 26.8.1 pre 1.2 (84)');
    });
  });
}
