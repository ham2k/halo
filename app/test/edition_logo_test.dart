// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';

void main() {
  test('each edition loads its own square mark and arc wordmark', () {
    // The colors are baked into the SVG per edition, so the edition is chosen by
    // which file we load (docs/releases.md §2.6).
    expect(ham2kSquareLogoAssetFor(Edition.dev), 'assets/images/ham2k-dev-square.svg');
    expect(ham2kSquareLogoAssetFor(Edition.next), 'assets/images/ham2k-next-square.svg');
    expect(ham2kSquareLogoAssetFor(Edition.prod), 'assets/images/ham2k-prod-square.svg');
    expect(ham2kArcLogoAssetFor(Edition.dev), 'assets/images/ham2k-dev-arc.svg');
    expect(ham2kArcLogoAssetFor(Edition.next), 'assets/images/ham2k-next-arc.svg');
    expect(ham2kArcLogoAssetFor(Edition.prod), 'assets/images/ham2k-prod-arc.svg');
  });

  test('the edition badge shows for Dev/Next and is absent for Regular', () {
    expect(ham2kEditionBadgeAssetFor(Edition.dev), 'assets/images/edition-dev.svg');
    expect(ham2kEditionBadgeAssetFor(Edition.next), 'assets/images/edition-next.svg');
    expect(ham2kEditionBadgeAssetFor(Edition.prod), isNull);
  });

  test('the current build (default Dev) uses the Dev mark', () {
    // `flutter test` runs with no --dart-define, so kEdition is Dev.
    expect(kEdition, Edition.dev);
    expect(ham2kSquareLogoAsset, 'assets/images/ham2k-dev-square.svg');
  });
}
