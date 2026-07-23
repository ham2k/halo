// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizePreviewName', () {
    test('matches deploy-web-preview.yml: lowercase, non-[a-z0-9-] -> -, trimmed', () {
      expect(sanitizePreviewName('My Feature!'), 'my-feature');
      expect(sanitizePreviewName('  Foo_Bar  '), 'foo-bar');
      expect(sanitizePreviewName('already-ok'), 'already-ok');
    });

    test('strips an optional web-preview- prefix (so a tag name round-trips)', () {
      expect(sanitizePreviewName('web-preview-my-feature'), 'my-feature');
    });

    test('caps at 28 chars', () {
      final long = 'a' * 40;
      expect(sanitizePreviewName(long), 'a' * 28);
    });

    test('rejects empty and the reserved dist/main names', () {
      expect(sanitizePreviewName('   '), isNull);
      expect(sanitizePreviewName('!!!'), isNull); // becomes empty after trim
      expect(sanitizePreviewName('dist'), isNull);
      expect(sanitizePreviewName('MAIN'), isNull);
    });

    test('derives the tag, URL, and DNS host from the sanitized name', () {
      expect(previewTagName('my-feature'), 'web-preview-my-feature');
      expect(previewUrl('my-feature'), 'https://my-feature-halo-dev.ham2k.net');
      expect(previewDnsHost('my-feature'), 'my-feature-halo-dev.ham2k.net');
    });
  });

  group('groupPreviews / previewsOlderThan', () {
    final now = DateTime.utc(2026, 7, 23, 12);
    PreviewDeployment dep(String id, String branch, DateTime created) =>
        PreviewDeployment(id: id, branch: branch, createdOn: created);

    test('groups by branch, drops the production branch, newest-first', () {
      final groups = groupPreviews([
        dep('1', 'main', now), // production — excluded
        dep('2', 'feature-a', now.subtract(const Duration(days: 3))),
        dep('3', 'feature-a', now.subtract(const Duration(days: 1))), // newer
        dep('4', 'feature-b', now.subtract(const Duration(days: 10))),
      ]);

      expect(groups.keys, unorderedEquals(['feature-a', 'feature-b']));
      expect(groups['feature-a']!.map((d) => d.id), ['3', '2']); // newest first
    });

    test('previewsOlderThan selects by the newest deployment per name', () {
      final groups = groupPreviews([
        dep('a1', 'fresh', now.subtract(const Duration(days: 2))),
        dep('b1', 'stale', now.subtract(const Duration(days: 40))),
        dep('b2', 'stale', now.subtract(const Duration(days: 45))),
        // 'mixed' has an old build AND a recent redeploy — the recent one keeps it alive.
        dep('c1', 'mixed', now.subtract(const Duration(days: 50))),
        dep('c2', 'mixed', now.subtract(const Duration(days: 1))),
      ]);

      final old = previewsOlderThan(groups, maxAge: const Duration(days: 30), now: now);
      expect(old, {'stale'});
    });
  });
}
