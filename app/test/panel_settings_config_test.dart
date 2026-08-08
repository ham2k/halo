// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which of a panel form's fields are actually written on Save.
//
// The rule has to serve two opposite cases at once. A config OMITS a field
// nobody has set, while the form renderer seeds an unset checkbox as `false`
// and an unset text field as `''` — so treating those as changes rewrites
// every untouched field on every Save and re-renders the panel for nothing.
// But treating them as unchanged unconditionally means a field whose DEFAULT
// is true can never be turned off, because "off" and "never set" look
// identical from here.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/panel_settings.dart';

void main() {
  group('a field nobody has stored yet', () {
    test('the seeded empties are not changes', () {
      // Save-without-typing on a fresh panel must write nothing at all.
      expect(sameConfigValue(false, null, null), isTrue);
      expect(sameConfigValue('', null, null), isTrue);
      expect(sameConfigValue(null, null, null), isTrue);
    });

    test('a real value against nothing stored is a change', () {
      expect(sameConfigValue(true, null, null), isFalse);
      expect(sameConfigValue('Tokyo', null, null), isFalse);
    });
  });

  group('a field that declares a default', () {
    test('turning off a default-ON checkbox is a change', () {
      // The bug this exists for. Unchecking "Show seconds" on a pane whose
      // config is still empty produces `false` against `null`; under the
      // unset-means-falsy rule that reads as unchanged, so nothing is
      // written, the config stays empty, the panel keeps reading its `?? true`
      // default — and the checkbox is stuck on forever, with the UI showing
      // it unchecked until the dialog is reopened.
      expect(sameConfigValue(false, null, true), isFalse);
    });

    test('leaving a default-ON checkbox alone is not a change', () {
      expect(sameConfigValue(true, null, true), isTrue);
    });

    test('the same rule holds for a non-boolean default', () {
      // A select seeded from its declared `value`.
      expect(sameConfigValue('lcd', null, 'lcd'), isTrue);
      expect(sameConfigValue('swiss', null, 'lcd'), isFalse);
    });
  });

  group('a field with something already stored', () {
    test('equal is unchanged and different is a change, default or not', () {
      // Once a value exists it is the only thing worth comparing against —
      // including clearing a field back to the seeded empty, which IS a
      // change because the stored value has to be overwritten.
      expect(sameConfigValue(true, true, true), isTrue);
      expect(sameConfigValue(false, true, true), isFalse);
      expect(sameConfigValue('', 'Tokyo', null), isFalse);
      expect(sameConfigValue(false, true, null), isFalse);
    });
  });
}
