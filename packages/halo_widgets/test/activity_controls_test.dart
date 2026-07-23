// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  final controls = [
    {
      'icon': 'pine-tree',
      'input': {'refType': 'pota'},
    },
  ];

  group('isUnknownRefType', () {
    test('false for a type a control declares', () {
      expect(isUnknownRefType(controls, 'pota'), isFalse);
    });

    test('true for a type no control declares', () {
      expect(isUnknownRefType(controls, 'unsupported-type'), isTrue);
    });

    // No control ever declares a null refType, so a null-typed ref is just
    // as unmatched as an unrecognized string one — same as before this got
    // its own named helper (ham2k/app-halo-dist#261 code review).
    test('true for a null type, same as an unrecognized one', () {
      expect(isUnknownRefType(controls, null), isTrue);
    });
  });
}
