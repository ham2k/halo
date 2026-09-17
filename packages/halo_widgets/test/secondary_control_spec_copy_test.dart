// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pins every field of `SecondaryControlSpec` to its `copyWith`.
//
// The logging panel wraps each spec it builds on the way to the row
// (`LoggingFocusLadder.withKeyboardNavigation`), which is a copy — and a copy that re-lists
// fields silently drops any the class grows afterwards. Nothing reports
// that: the omitted field falls back to its default, the analyzer sees a
// well-formed constructor call, and the chip renders as if the caller had
// never set it. The symptom is "my new spec field does nothing", pointing
// at the feature rather than at the copy.
//
// Read from source because there is no other way to enumerate a Dart
// class's fields — no mirrors in Flutter — and a hand-written round-trip
// test would need the same field added to its fixture, which is the exact
// step being forgotten.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `final <Type> <name>;` at one level of indentation inside the class. The
/// type pattern spans generics and nullables (`ValueGetter<String>?`) so a
/// field declared with either is still seen.
final _fieldDeclaration = RegExp(r'^  final\s+[\w<>,\s?]+?\s+(\w+);$', multiLine: true);

/// The class body, from its declaration to the first `}` at column 0.
String _sliceClass(String source, String name) {
  final start = source.indexOf('class $name {');
  expect(start, isNonNegative, reason: 'class $name not found');
  final end = source.indexOf('\n}\n', start);
  expect(end, isNonNegative, reason: 'unterminated class $name');
  return source.substring(start, end);
}

void main() {
  test('every SecondaryControlSpec field is carried by copyWith', () {
    // Package tests run from the package root.
    final source = File('lib/src/secondary_control_row.dart').readAsStringSync();
    final body = _sliceClass(source, 'SecondaryControlSpec');

    final fields = _fieldDeclaration.allMatches(body).map((m) => m.group(1)!).toList();
    // Guards the regex itself: a pattern that silently matched nothing would
    // make every assertion below vacuous, and this test would pass forever.
    expect(fields, contains('summary'), reason: 'the field regex stopped matching — fix it, not this expectation');
    expect(fields.length, greaterThanOrEqualTo(5));

    final copyWithStart = body.indexOf('SecondaryControlSpec copyWith({');
    expect(copyWithStart, isNonNegative, reason: 'SecondaryControlSpec.copyWith is gone');
    final copyWith = body.substring(copyWithStart);

    for (final field in fields) {
      expect(
        copyWith,
        contains(RegExp('[\\s,(]$field,')),
        reason: '`$field` is not a parameter of copyWith',
      );
      expect(
        copyWith,
        contains('$field: $field ?? this.$field'),
        reason: '`$field` is not forwarded by copyWith, so a copy silently resets it',
      );
    }
  });
}
