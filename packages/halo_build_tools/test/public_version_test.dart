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

  group('PublicVersion.displayParts', () {
    const august = MainVersion(year: 26, month: 8);

    test('a stable first release carries neither a patch nor a pre-release', () {
      // Both null, not zero: `patch 0` names a thing that doesn't exist, and a
      // caller rendering the parts must be able to tell "no patch" from one.
      final parts = const PublicVersion(main: august, patch: 0).displayParts(stageLabel: 'ALPHA');
      expect(parts.mainName, "August '26");
      expect(parts.stageLabel, 'ALPHA');
      expect(parts.patch, isNull);
      expect(parts.preRelease, isNull);
      expect(parts.preReleaseLabel, isNull);
      expect(parts.preReleaseCounter, isNull);
    });

    test('a pre-release names its label and counter, patch included', () {
      final parts = const PublicVersion(
        main: august,
        patch: 2,
        preRelease: 1,
        preReleasePatch: 3,
        preReleaseLabel: 'alpha',
      ).displayParts();
      expect(parts.patch, 2);
      expect(parts.preReleaseLabel, 'alpha');
      // The counter and its patch are one number to a reader — a display that
      // showed `1` here would name a different build than `1.3`.
      expect(parts.preReleaseCounter, '1.3');
      expect(parts.stageLabel, isEmpty);
    });

    test('displayName spells exactly the parts, so the two cannot drift', () {
      // The reason displayParts exists: the UI renders the pieces itself (two
      // lines, translated), and this is what keeps that rendering and the
      // canonical name describing the same version. Adding a component to one
      // without the other fails here.
      for (final version in [
        const PublicVersion(main: august, patch: 0),
        const PublicVersion(main: august, patch: 2),
        const PublicVersion(main: august, patch: 2, preRelease: 1),
        const PublicVersion(main: august, patch: 0, preRelease: 4, preReleasePatch: 2, preReleaseLabel: 'rc'),
      ]) {
        final parts = version.displayParts(stageLabel: 'ALPHA');
        final spelled = [
          parts.mainName,
          parts.stageLabel,
          if (parts.patch != null) 'patch ${parts.patch}',
          if (parts.preRelease != null) '${parts.preReleaseLabel} ${parts.preReleaseCounter}',
        ].where((part) => part.isNotEmpty).join(' ');
        expect(spelled, version.displayName(stageLabel: 'ALPHA'));
      }
    });
  });
}
