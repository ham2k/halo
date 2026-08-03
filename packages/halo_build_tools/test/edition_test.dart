// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('Edition', () {
    test('only dev is unofficial; next and prod are official', () {
      expect(Edition.dev.isOfficial, isFalse);
      expect(Edition.next.isOfficial, isTrue);
      expect(Edition.prod.isOfficial, isTrue);
    });

    test('label qualifies the non-stable editions and is null for prod', () {
      // prod is the plain "Ham2K Logger" and needs no qualifier, so its label
      // is null — the signal callers use to omit the suffix entirely.
      expect(Edition.dev.label, 'Dev');
      expect(Edition.next.label, 'Next');
      expect(Edition.prod.label, isNull);
    });

    test('productName parenthesises the qualifier (installed + artifact name)', () {
      // The non-stable editions carry a parenthesised qualifier consistently —
      // the installed app name and the base of every artifact name (§2.2).
      expect(Edition.prod.productName, 'Ham2K Logger');
      expect(Edition.next.productName, 'Ham2K Logger (Next)');
      expect(Edition.dev.productName, 'Ham2K Logger (Dev)');
    });
  });

  group('kEdition', () {
    test('defaults to dev when HALO_EDITION is unset', () {
      // No --dart-define in a plain `dart test` run, so this pins the safe
      // default: a build that never opted into an official edition is dev
      // (docs/releases.md §2.6).
      expect(kEdition, Edition.dev);
    });
  });

  group('editionFromName (--edition flag)', () {
    test('parses the three names, case-insensitively', () {
      expect(editionFromName('dev'), Edition.dev);
      expect(editionFromName('NEXT'), Edition.next);
      expect(editionFromName(' Prod '), Edition.prod);
    });

    test('is null for anything else, so the caller can reject it', () {
      expect(editionFromName('staging'), isNull);
      expect(editionFromName(''), isNull);
    });
  });

  group('editionForBranch (#241)', () {
    test('main (and the transitional dist name) map to next — where Next is cut today', () {
      // A pushed v* tag from main builds the Next matrix, so a release cut from
      // main is a Next release. `dist` is the pre-rename name, kept while the
      // transitional compat branch exists.
      expect(editionForBranch('main'), Edition.next);
      expect(editionForBranch('dist'), Edition.next);
      expect(editionForBranch('next'), Edition.next);
      expect(editionForBranch('prod'), Edition.prod);
    });

    test('a feature branch is dev, which halo-ops refuses to tag (needs --edition)', () {
      // The safety default: you can't accidentally cut a release from a random
      // work branch — halo-ops shows the plan but won't tag a dev edition.
      expect(editionForBranch('241-halo-ops'), Edition.dev);
    });
  });
}
