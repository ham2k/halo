// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Whether a Current Activities row can be tapped to edit its reference is the
// extension's call, and the default is the load-bearing part: a plain ref
// activity (POTA, SOTA) declares nothing, and must NOT offer to retype a code
// its own search already resolved. Getting the default backwards would hand
// every activity a typo path with no lookup behind it.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

void main() {
  test('a type that declares nothing is not editable', () {
    expect(refTypeIsEditable(const {'key': 'pota/activation'}), isFalse);
  });

  test('an unknown ref type — no control at all — is not editable', () {
    expect(refTypeIsEditable(null), isFalse);
  });

  test('a type opts in explicitly', () {
    expect(refTypeIsEditable(const {'key': 'x/y', 'editable': true}), isTrue);
  });

  test('an explicit false stays false', () {
    expect(refTypeIsEditable(const {'key': 'x/y', 'editable': false}), isFalse);
  });

  test('a non-boolean value is not treated as opting in', () {
    expect(refTypeIsEditable(const {'key': 'x/y', 'editable': 'yes'}), isFalse);
    expect(refTypeIsEditable(const {'key': 'x/y', 'editable': 1}), isFalse);
  });
}
