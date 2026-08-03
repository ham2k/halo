// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('formatNumber', () {
    test('formats integers with thousands separators in English (en) locale', () {
      expect(formatNumber(123, locale: 'en'), '123');
      expect(formatNumber(1234, locale: 'en'), '1,234');
      expect(formatNumber(1000000, locale: 'en'), '1,000,000');
    });

    test('formats integers with thousands separators in Spanish (es) locale', () {
      // In Spanish, thousands separator can be a period or a space depending on standard,
      // but intl library uses period (e.g. 1.234) or space depending on the version.
      // Let's verify it matches Spanish formatting characters: either a space or a dot,
      // and not a comma.
      final formatted = formatNumber(1234, locale: 'es');
      expect(formatted.contains(','), isFalse);
      expect(formatted.contains('.') || formatted.contains(' ') || formatted.contains(' '), isTrue);
    });

    test('formats decimals with thousands separators', () {
      expect(formatNumber(1234.56, locale: 'en'), '1,234.56');
    });

    test('an explicit locale overrides the device locale', () {
      // formatNumber() defaults to the device's system locale (independent of
      // the app's own Language setting) — the locale param is how tests (and
      // any future explicit-locale callers) pin it instead.
      expect(formatNumber(1234, locale: 'en'), isNot(formatNumber(1234, locale: 'es')));
    });
  });
}
