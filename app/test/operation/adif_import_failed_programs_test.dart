// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Naming the programs whose reference pass failed.
//
// Without this, the set of failed hooks is computed, carried through two
// layers, and read only for `isNotEmpty` — so the summary can say "references
// could not be recovered for 500 contacts" and no more, leaving an operator
// unable to tell "every park in my log is gone" from "an award I have never
// heard of failed".

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation/adif_import_flow.dart';

void main() {
  const available = [
    ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air', shortName: 'POTA'),
    ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'Summits on the Air', shortName: 'SOTA'),
    ExtensionInfo(key: 'gma', file: 'gma.js', core: false, name: 'Global Mountain Activity'),
  ];

  test('a failed hook is named the way the operator names it', () {
    expect(failedProgramNames(available, {'pota'}), ['POTA']);
  });

  test('a program that did NOT fail is not named', () {
    // The whole point of naming them: a message listing every enabled
    // extension would be no more use than the count alone.
    //
    // Asserted as the WHOLE list, not as `isNot(contains('POTA'))` — that form
    // also passes when the function returns nothing at all, so it could not
    // tell "named the right one" from "named none".
    expect(failedProgramNames(available, {'sota'}), ['SOTA']);
  });

  test('a program with no shortName falls back to its full name', () {
    expect(failedProgramNames(available, {'gma'}), ['Global Mountain Activity']);
  });

  test("the '*' sentinel is dropped, not rendered as a program", () {
    // It means no hook ran at all, which is a different sentence — and
    // printing a bare asterisk beside real program names would read as one.
    expect(failedProgramNames(available, {'*'}), isEmpty);
    expect(failedProgramNames(available, {'*', 'pota'}), ['POTA']);
  });

  test('a key the registry has never heard of still says something', () {
    // An extension removed since the import, or one whose registration key is
    // not its extension key. The raw key beats naming nothing.
    expect(failedProgramNames(available, {'mystery'}), ['mystery']);
  });

  test('names are sorted, so the same failure reads the same way twice', () {
    // The set arrives in whatever order the hooks replied across batches, and
    // `invokeHookAll` guarantees none. Dart's Set preserves that order
    // faithfully, which is exactly the problem.
    expect(failedProgramNames(available, {'sota', 'pota'}), ['POTA', 'SOTA']);
    expect(failedProgramNames(available, {'pota', 'sota'}), ['POTA', 'SOTA']);
  });
}
