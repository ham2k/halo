// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('PublicVersion.displayName', () {
    const august = MainVersion(year: 26, month: 8);

    test('omits a zero patch and a null pre-release', () {
      expect(const PublicVersion(main: august, patch: 0).displayName(), "August '26");
    });

    test('names the patch and pre-release parts in version order', () {
      expect(
        const PublicVersion(main: august, patch: 2, preRelease: 1).displayName(),
        "August '26 patch 2 pre 1",
      );
      expect(
        const PublicVersion(main: august, patch: 2, preRelease: 1, preReleasePatch: 3).displayName(),
        "August '26 patch 2 pre 1.3",
      );
    });

    test('the stage label sits between the month and the patch, not at the end', () {
      // Trailing it would read as another version component ("patch 1 ALPHA"),
      // which is exactly what the label is not — it qualifies the product, not
      // this version (docs/releases.md §2.1).
      expect(
        const PublicVersion(main: august, patch: 1).displayName(stageLabel: 'ALPHA'),
        "August '26 ALPHA patch 1",
      );
      expect(
        const PublicVersion(main: august, patch: 1, preRelease: 2).displayName(stageLabel: 'ALPHA'),
        "August '26 ALPHA patch 1 pre 2",
      );
    });

    test('an empty stage label leaves no gap — it is how the label is retired', () {
      expect(const PublicVersion(main: august, patch: 1).displayName(stageLabel: ''), "August '26 patch 1");
    });

    test('the stage label is a display concern only — the same version reports it in the name, not the value', () {
      // Tags, plists and store fields all project from `value`, so a label
      // leaking into it would produce an invalid version everywhere
      // downstream. Both assertions run against ONE instance: storing the
      // label on the version — the tempting refactor — is what this catches.
      const v = PublicVersion(main: august, patch: 1);
      expect(v.displayName(stageLabel: 'ALPHA'), contains('ALPHA'));
      expect(v.value, isNot(contains('ALPHA')));
      expect(v.releaseTagName(126), 'v26.8.1+126');
    });
  });
}
