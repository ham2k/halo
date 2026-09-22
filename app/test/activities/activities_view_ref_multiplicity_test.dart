// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extensions declare whether a ref type may appear more than once on an
// operation. The default matters as much as the flag: an undeclared type
// REPLACES rather than stacks, so a type that means to stack (POTA n-fers)
// has to say `allowsMultiple: true` — and getting the default backwards would
// silently drop a ref the user already added. These tests pin both.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

void main() {
  group('allowsMultipleRefsOfType', () {
    test('defaults to false when neither suggestion nor control says anything', () {
      expect(allowsMultipleRefsOfType('wwff'), isFalse);
      expect(allowsMultipleRefsOfType('wwff', suggestion: const {}, control: const {}), isFalse);
    });

    test('honors the suggestion — that is what a search hit carries', () {
      expect(allowsMultipleRefsOfType('sota', suggestion: const {'allowsMultiple': false}), isFalse);
      expect(allowsMultipleRefsOfType('sota', suggestion: const {'allowsMultiple': true}), isTrue);
    });

    test('falls back to the control descriptor for hand-typed refs', () {
      expect(allowsMultipleRefsOfType('sota', control: const {'allowsMultiple': false}), isFalse);
    });

    test('suggestion wins over the control when both declare it', () {
      expect(allowsMultipleRefsOfType('sota', suggestion: const {'allowsMultiple': true}, control: const {'allowsMultiple': false}), isTrue);
    });

    test('ignores a non-boolean value rather than treating it as true', () {
      expect(allowsMultipleRefsOfType('pota', suggestion: const {'allowsMultiple': 'yes'}), isFalse);
    });
  });

  group('refsKeptWhenAdding', () {
    final refs = <Map<String, dynamic>>[
      {'type': 'pota', 'ref': 'US-0001'},
      {'type': 'sota', 'ref': 'W2/GC-001'},
      {'type': 'pota', 'ref': 'US-0002'},
    ];

    test('keeps every ref when the type allows multiple', () {
      expect(refsKeptWhenAdding(refs: refs, type: 'pota', allowsMultiple: true), refs);
    });

    test('drops only the same type when it does not, leaving other types alone', () {
      expect(refsKeptWhenAdding(refs: refs, type: 'sota', allowsMultiple: false), [
        {'type': 'pota', 'ref': 'US-0001'},
        {'type': 'pota', 'ref': 'US-0002'},
      ]);
    });

    test('drops every ref of a single-ref type, not just the first', () {
      expect(refsKeptWhenAdding(refs: refs, type: 'pota', allowsMultiple: false), [
        {'type': 'sota', 'ref': 'W2/GC-001'},
      ]);
    });

    test('keeps everything for an unknown (null) type — nothing to replace', () {
      expect(refsKeptWhenAdding(refs: refs, type: null, allowsMultiple: false), refs);
    });
  });
}
