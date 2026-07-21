// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  const alpha1 = PublicVersion(
    main: MainVersion(year: 26, month: 8),
    patch: 1,
    preRelease: 1,
    preReleaseLabel: 'alpha',
  );
  const pre4 = PublicVersion(
    main: MainVersion(year: 26, month: 8),
    patch: 1,
    preRelease: 4,
    preReleaseLabel: 'pre',
  );
  const stable = PublicVersion(main: MainVersion(year: 26, month: 8), patch: 2);

  group('compactName (machine-facing; CI appends -<platform>.<ext>)', () {
    test('halo-<edition>-<version>-(<build>)', () {
      expect(
        compactName(edition: Edition.next, version: alpha1, build: 73),
        'halo-next-26.8.1-alpha1-(73)',
      );
      expect(
        compactName(edition: Edition.dev, version: pre4, build: 123),
        'halo-dev-26.8.1-pre4-(123)',
      );
    });
  });

  group('fullName (human-facing; CI appends descriptor/ext)', () {
    test('carries the (Edition) qualifier + build for a pre-release', () {
      expect(
        fullName(edition: Edition.next, version: alpha1, build: 73),
        'Ham2K Logger (Next) 26.8.1-alpha1 (73)',
      );
      expect(
        fullName(edition: Edition.dev, version: alpha1, build: 73),
        'Ham2K Logger (Dev) 26.8.1-alpha1 (73)',
      );
    });

    test('drops the qualifier and the build for a stable (prod) release', () {
      // e.g. the final artifact "Ham2K Logger 26.8.2 macOS.zip".
      expect(
        fullName(edition: Edition.prod, version: stable, build: 200),
        'Ham2K Logger 26.8.2',
      );
    });
  });
}
