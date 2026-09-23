// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `SerialStepFormatter` — a period steps a serial up and a comma steps it
// down. The traps: the punctuation itself surviving into a digits-only field
// (the step would be silently lost to the filter after it), a step through
// zero leaving a serial no sequence issues, a padded `007` losing its width,
// and an edit that merely CONTAINS the punctuation — a paste, a keystroke over
// a selection — being read as a step of a number that is no longer there.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// Types [text] as one edit onto [from], caret at the end.
TextEditingValue step(String from, String text) => const SerialStepFormatter().formatEditUpdate(
  TextEditingValue(
    text: from,
    selection: TextSelection.collapsed(offset: from.length),
  ),
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  ),
);

void main() {
  test('a period adds one and a comma takes one away, wherever it was typed', () {
    expect(step('41', '41.').text, '42');
    expect(step('41', '.41').text, '42');
    expect(step('41', '41,').text, '40');
    expect(step('41', '4.1').text, '42');
  });

  test('the caret lands at the end of the stepped number', () {
    expect(step('9', '9.').selection, const TextSelection.collapsed(offset: 2));
  });

  test('an empty field steps from zero, and nothing steps below one', () {
    expect(step('', '.').text, '1');
    expect(step('', ',').text, '');
    expect(step('1', '1,').text, '1');
  });

  test('leading zeros keep their width', () {
    expect(step('007', '007.').text, '008');
    expect(step('099', '099.').text, '100');
  });

  test('only one step key added to the old value steps; a paste or a typed-over selection is left to the digits filter', () {
    expect(step('', '1,234').text, '1,234', reason: 'a pasted thousands separator is not a decrement');
    expect(step('123', '.').text, '.', reason: 'replacing a selection steps nothing that is still there');
    expect(step('41', '41..').text, '41..');
  });

  test('an edit with neither passes through untouched', () {
    final value = step('4', '42');
    expect(value.text, '42');
  });
}
