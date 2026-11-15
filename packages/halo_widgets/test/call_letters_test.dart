// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How each letter of a suggested call differs from the text typed: what the
// suggestions line colours them by (logging-fields.md § Draft suggestions).

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

List<String> marked(String typed, String call) => [
  for (final letter in callLetters(typed, call)) letter.kind == CallLetterKind.same ? letter.char : '${letter.kind.name}:${letter.char}',
];

void main() {
  test('a call the text appears inside adds the letters around it', () {
    expect(marked('K1A', 'WK1AB'), ['added:W', 'K', '1', 'A', 'added:B']);
  });

  test('a call one letter off has that letter changed, added or left out', () {
    expect(marked('K1ABC', 'K1ABD'), ['K', '1', 'A', 'B', 'changed:D']);
    expect(marked('K1ABC', 'K1ABCD'), ['K', '1', 'A', 'B', 'C', 'added:D']);
    expect(marked('K1ABC', 'K1AC'), ['K', '1', 'A', 'removed:B', 'C'], reason: 'the letter left out is shown where it was typed');
  });

  // Offered as one edit away; both letters must show, or the call would look
  // like the one typed.
  test('two neighbors that traded places are both marked', () {
    expect(marked('K1ABC', 'K1BAC'), ['K', '1', 'changed:B', 'changed:A', 'C']);
  });

  test('a ? typed stands for any letter, and the one it stands for is added', () {
    expect(marked('K1?BC', 'K1ABC'), ['K', '1', 'added:A', 'B', 'C']);
  });

  test('the whole call typed is all its own letters', () {
    expect(marked('k1abc', 'K1ABC'), ['K', '1', 'A', 'B', 'C']);
  });

  // A span holding half a surrogate pair is text the engine will not lay out:
  // a call an extension sends with a character past U+FFFF must come back
  // whole, one letter per character.
  test('a character past U+FFFF is one letter, never split in two', () {
    expect(marked('K1A', 'K1A😀'), ['K', '1', 'A', 'added:😀']);
  });
}
