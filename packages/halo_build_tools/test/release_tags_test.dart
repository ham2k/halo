// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('parseReleaseTags', () {
    test('parses v<version>+<build> tags, oldest build first', () {
      final tags = parseReleaseTags(['v26.8.1-alpha1+82', 'v26.8.1-alpha1+80', 'v26.8.1-alpha1+81']);
      expect(tags.map((t) => t.build), [80, 81, 82]);
      expect(tags.last.version, '26.8.1-alpha1');
      expect(tags.last.tag, 'v26.8.1-alpha1+82');
    });

    test('ignores tags that are not release tags', () {
      // A branch-marker tag (no +build) and a plain semver tag must not be
      // read as releases — status/next-build would otherwise pick up garbage.
      final tags = parseReleaseTags(['web-preview-operation-settings', 'v1.2.3', 'random']);
      expect(tags, isEmpty);
    });

    test('drops builds outside 1..cap (stray legacy date-encoded ids)', () {
      // A huge date-encoded id would otherwise hijack the "latest build"
      // reading, so anything above the FILEVERSION cap is dropped.
      final tags = parseReleaseTags(['v26.8.1-alpha1+82', 'v0.9+20250101', 'v0.9+0']);
      expect(tags.map((t) => t.build), [82]);
    });

    test('latestRelease is the highest build; null when there are none', () {
      expect(latestRelease(parseReleaseTags(['v26.8.1-alpha1+80', 'v26.8.1-alpha1+82']))!.build, 82);
      expect(latestRelease(parseReleaseTags(['not-a-release'])), isNull);
    });

    test('every edition\'s tags share one counter, and a bare v-tag is Next', () {
      // Builds are numbered once across editions, so the next build is one
      // past the highest of ANY edition: reading Next tags alone would hand a
      // Next cut the number a prod release already took.
      final tags = parseReleaseTags(['v26.9.0+178', 'prod-v26.9.0+179', 'next-v26.10.0+180', 'prod-v26.9.1+181']);
      expect(tags.map((t) => t.edition), [Edition.next, Edition.prod, Edition.next, Edition.prod]);
      expect(latestRelease(tags)!.build, 181);
      expect(latestRelease(tags, edition: Edition.next)!.tag, 'next-v26.10.0+180');
      expect(latestRelease(tags, edition: Edition.prod)!.version, '26.9.1');
      expect(latestRelease(tags, edition: Edition.dev), isNull);
    });

    test('a dev- prefix is not a release tag', () {
      expect(parseReleaseTags(['dev-v26.9.0+5', 'stable']), isEmpty);
    });

    test('releasesByVersion groups each public-version line', () {
      final tags = parseReleaseTags(['v26.8.0+70', 'v26.8.1-alpha1+82', 'v26.8.1-alpha1+81']);
      final byVersion = releasesByVersion(tags);
      expect(byVersion.keys, containsAll(['26.8.0', '26.8.1-alpha1']));
      expect(byVersion['26.8.1-alpha1']!.map((t) => t.build), [81, 82]);
    });
  });
}
