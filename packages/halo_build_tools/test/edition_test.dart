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
}
