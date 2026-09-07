// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/main.dart';

void main() {
  group('dev flag values', () {
    test('the documented "=1" spelling counts as on', () {
      // The trap this exists for: `bool.fromEnvironment` recognizes only the
      // literals "true"/"false", so `--dart-define=POLO_OPEN_FIRST_OP=1` —
      // the spelling DEVELOPMENT.md documents for both the dart-define and
      // the environment variable — read as FALSE. The app launched, reported
      // the flag off, and looked like the define had been forgotten.
      expect(isDevFlagSet('1'), isTrue);
    });

    test('"true" counts too, in any case', () {
      expect(isDevFlagSet('true'), isTrue);
      expect(isDevFlagSet('TRUE'), isTrue);
      expect(isDevFlagSet(' True '), isTrue);
    });

    test('an unset or off value does not', () {
      expect(isDevFlagSet(''), isFalse);
      expect(isDevFlagSet('0'), isFalse);
      expect(isDevFlagSet('false'), isFalse);
      // Not "anything non-empty is on": a flag left at its placeholder should
      // read as off, not as an accidental yes.
      expect(isDevFlagSet('no'), isFalse);
    });
  });
}
