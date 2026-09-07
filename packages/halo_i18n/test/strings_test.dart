// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two things a consumer relies on without ever checking: `t` answers
// from the base locale with no setup at all (services read it before any
// widget mounts), and the Spanish translations, which are a deferred import
// on web, load and answer too.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';

void main() {
  test('the global t answers in the base locale with no setup', () {
    expect(LocaleSettings.currentLocale, AppLocale.en);
    expect(t.common.cancel, 'Cancel');
  });

  test('every locale builds and answers the same key', () async {
    for (final locale in AppLocale.values) {
      final translations = await locale.build();
      expect(translations.common.cancel, isNotEmpty, reason: '$locale');
    }
  });
}
