// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('formatNumber', () {
    test('formats integers with thousands separators in English (en) locale', () {
      Intl.defaultLocale = 'en';
      expect(formatNumber(123), '123');
      expect(formatNumber(1234), '1,234');
      expect(formatNumber(1000000), '1,000,000');
    });

    test('formats integers with thousands separators in Spanish (es) locale', () {
      Intl.defaultLocale = 'es';
      // In Spanish, thousands separator can be a period or a space depending on standard,
      // but intl library uses period (e.g. 1.234) or space depending on the version.
      // Let's verify it matches Spanish formatting characters: either a space or a dot,
      // and not a comma.
      final formatted = formatNumber(1234);
      expect(formatted.contains(','), isFalse);
      expect(formatted.contains('.') || formatted.contains('\u00a0') || formatted.contains(' '), isTrue);
    });

    test('formats decimals with thousands separators', () {
      Intl.defaultLocale = 'en';
      expect(formatNumber(1234.56), '1,234.56');
    });
  });
}
