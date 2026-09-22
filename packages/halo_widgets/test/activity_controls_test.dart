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
    // as unmatched as an unrecognized string one.
    test('true for a null type, same as an unrecognized one', () {
      expect(isUnknownRefType(controls, null), isTrue);
    });
  });

  group('a null or empty refType matches nothing', () {
    // The lookup is equality, so a control that declares no refType of its
    // own — an extension shipping a malformed entry, which crosses the bridge
    // as unvalidated JSON — would otherwise ANSWER for a null. Everything
    // that claims no activity (the whole-log ADIF export, a ref with no type)
    // would then wear that extension's icon and accent.
    final withTypeless = [
      {'icon': 'trophy', 'color': '#3C8C3C', 'input': <String, dynamic>{}},
      ...controls,
    ];

    test('a typeless control does not answer for a null type', () {
      expect(controlForRefType(withTypeless, null), isNull);
      expect(iconForRefType(withTypeless, null), isNull);
      expect(colorForRefType(withTypeless, null), isNull);
      expect(isUnknownRefType(withTypeless, null), isTrue);
    });

    test('nor for an empty one', () {
      expect(controlForRefType(withTypeless, ''), isNull);
    });

    test('and a real type still matches past it', () {
      expect(controlForRefType(withTypeless, 'pota')?['icon'], 'pine-tree');
    });
  });

  group('unhandledRefsIn', () {
    const potaControl = {
      'key': 'pota/activation',
      'input': {'kind': 'refList', 'refType': 'pota'},
    };

    test('reports only what no control handles', () {
      expect(
        unhandledRefsIn(
          const [
            {'type': 'pota', 'ref': 'US-0001'},
            {'type': 'qp', 'ref': 'NY'},
          ],
          const [potaControl],
        ),
        [(type: 'qp', code: 'NY')],
      );
    });

    test('a ref field that is not a string reads as no code, and does not throw', () {
      // Operation refs are JSON written by extensions and by app-polo. Callers
      // are deciding what to OFFER; taking the screen down over one odd row
      // is never the better answer.
      expect(
        unhandledRefsIn(const [
          {'type': 'qp', 'ref': 42},
          {'type': 42, 'ref': 'NY'},
        ], const []),
        [(type: 'qp', code: null)],
      );
    });
  });
}
