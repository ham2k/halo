// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The call field's reading rules on their own: which call the operator means
// depends on the text AND the cursor, and every consumer must agree.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/call_field_text.dart';

CallFieldText _at(String text, int cursor, {bool stacking = true}) =>
    CallFieldText(text, cursor: cursor, stacking: stacking);

void main() {
  test('a plain call is the whole field, uppercased, wherever the cursor is', () {
    expect(_at(' w1aw ', 2).callAtCursor, 'W1AW');
    expect(_at('w1aw', -1).callAtCursor, 'W1AW');
    expect(_at('w1aw', 2).callList, ['W1AW']);
  });

  test('a comma list follows the cursor, and an unfocused field means the last entry', () {
    expect(_at('W1AW, K1ABC', 2).callAtCursor, 'W1AW');
    expect(_at('W1AW, K1ABC', 4).callAtCursor, 'W1AW', reason: 'the cursor at a segment end is still in it');
    expect(_at('W1AW, K1ABC', 6).callAtCursor, 'K1ABC');
    expect(_at('W1AW, K1ABC', -1).callAtCursor, 'K1ABC');
    expect(_at('W1AW, K1ABC', 0).callList, ['W1AW', 'K1ABC']);
    expect(_at('W1AW, K1ABC', 0).callsInField, ['W1AW', 'K1ABC']);
  });

  test('a stack picks the first callsign-shaped segment scanning left from the cursor', () {
    final t = _at('K1ABC//W1AW', 9);
    expect(t.isStack, isTrue);
    final picked = t.pickStackedCall()!;
    expect(picked.calls, ['W1AW']);
    expect(picked.remainder, 'K1ABC');
    expect(picked.index, 1);
    expect(t.callAtCursor, 'W1AW');
    expect(t.callsInField, ['K1ABC', 'W1AW']);
    // A fragment under the cursor is skipped in favour of the call before it.
    expect(_at('K1ABC//1AB', 9).pickStackedCall()?.calls, ['K1ABC']);
    expect(_at('K1ABC//1AB', 9).callAtCursor, 'K1ABC');
  });

  test('a stacked segment that is itself a list follows the cursor inside it', () {
    // "KI2D//W1AB,W1AC" — the shape a mid-stack note expansion leaves.
    expect(_at('KI2D//W1AB,W1AC', 8).callAtCursor, 'W1AB');
    expect(_at('KI2D//W1AB,W1AC', 13).callAtCursor, 'W1AC');
    // The cursor parked between the two slashes belongs to the segment after
    // them, and reads its FIRST entry — not, via a negative offset, its last.
    expect(_at('KI2D//W1AB,W1AC', 5).callAtCursor, 'W1AB');
    expect(_at('KI2D//W1AB,W1AC', -1).callAtCursor, 'W1AC', reason: 'unfocused: the last entry');
    expect(_at('KI2D//W1AB,W1AC', 8).pickStackedCall()?.calls, ['W1AB', 'W1AC']);
  });

  test('a leading "//" is a note key, not a segment the cursor can be in', () {
    final t = _at('//KEY//W1AW', 0);
    expect(t.stackSegments().cursorIndex, 1);
    expect(t.stackSegments().segments, ['', 'KEY', 'W1AW']);
    expect(t.stackSegments().starts, [0, 2, 7]);
    expect(t.callsInField, ['KEY', 'W1AW']);
  });

  test('stacking is off while editing an existing QSO', () {
    final t = _at('K1ABC//W1AW', 9, stacking: false);
    expect(t.isStack, isFalse);
    expect(t.pickStackedCall(), isNull);
    expect(t.callAtCursor, 'K1ABC//W1AW');
  });

  test('the expansion input names the cursor segment, and refuses the whole field or a spent key', () {
    final t = _at('KI2D//1AB', 9);
    final stack = t.stackSegments();
    expect(t.expansionInputFor(stack, alreadyExpanded: null), '//1AB');
    expect(t.expansionInputFor(stack, alreadyExpanded: '//1AB'), isNull, reason: 'a key expands once per draft');
    expect(_at('//1AB', 4).expansionInputFor(_at('//1AB', 4).stackSegments(), alreadyExpanded: null), isNull,
        reason: 'the whole-field command path already asked');
    expect(_at('KI2D//', 6).expansionInputFor(_at('KI2D//', 6).stackSegments(), alreadyExpanded: null), isNull,
        reason: 'an empty segment has nothing to expand');
  });

  test('command input keeps the case typed; the call does not', () {
    expect(_at('note Called Bob', 0).commandInput, 'note Called Bob');
    expect(_at('note Called Bob', 0).call, 'NOTE CALLED BOB');
  });
}
