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
      const v = PublicVersion(main: MainVersion(year: 26, month: 8), patch: 1, preRelease: 1, preReleaseLabel: 'pre', preReleasePatch: 2);
      expect(v.releaseTagName(84), 'v26.8.1-pre1.2+84');
      expect(v.releaseMessage(84), 'Release 26.8.1 pre 1.2 (84)');
    });
  });

  // Build expiration: the release cut writes the cutting edition's date into
  // version.dart and the app nags once it has passed. These tests pin the
  // contract the two sides share: per-edition fields, empty = never expires,
  // and a date-only expiry that lasts through the WHOLE expiration day (UTC)
  // — a build must not start nagging at midnight the morning of its own
  // printed date.
  group('expiration dates', () {
    const source = '''
const kBuildNumber = 95;
const kDevExpirationDate = '2026-08-01';
const kNextExpirationDate = '';
const kProdExpirationDate = '2027-01-23';
''';

    test('reads per-edition fields; empty means never', () {
      expect(parseExpirationDate(source, Edition.next), isNull);
      expect(parseExpirationDate(source, Edition.prod), '2027-01-23');
      expect(parseExpirationDate(source, Edition.dev), '2026-08-01');
    });

    test('a missing declaration is a loud failure, not a silent never', () {
      expect(() => parseExpirationDate('const kBuildNumber = 1;', Edition.next), throwsFormatException);
    });

    test('rewrites round-trip and touch only the target edition', () {
      var s = rewriteExpirationDate(source, Edition.next, '2026-08-06');
      s = rewriteExpirationDate(s, Edition.dev, '2026-08-06');
      expect(parseExpirationDate(s, Edition.next), '2026-08-06');
      expect(parseExpirationDate(s, Edition.dev), '2026-08-06');
      expect(parseExpirationDate(s, Edition.prod), '2027-01-23', reason: 'prod must survive a next cut (which also re-stamps dev)');
    });

    test('build horizons: two weeks for dev/next, six clamped months for prod', () {
      final today = DateTime.utc(2026, 7, 24);
      expect(expirationDateForBuild(Edition.dev, today), '2026-08-07');
      expect(expirationDateForBuild(Edition.next, today), '2026-08-07');
      expect(expirationDateForBuild(Edition.prod, today), '2027-01-24');
      // Month-end cuts clamp instead of normalizing into the next month —
      // an Aug 31 prod cut must expire in February, not slide to March 3.
      expect(expirationDateForBuild(Edition.prod, DateTime.utc(2026, 8, 31)), '2027-02-28');
    });

    test('expiry starts the day AFTER the printed date, UTC', () {
      final expiration = DateTime.parse('2026-08-06');
      expect(expirationHasPassed(expiration, DateTime.utc(2026, 8, 6, 23, 59)), isFalse, reason: 'the expiration day itself still works');
      expect(expirationHasPassed(expiration, DateTime.utc(2026, 8, 7)), isTrue);
    });
  });
}
