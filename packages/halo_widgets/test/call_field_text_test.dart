// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The call field's reading rules on their own: which call the operator means
// depends on the text AND the cursor, and every consumer must agree.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/call_field_text.dart';

CallFieldText _at(String text, int cursor, {bool stacking = true}) => CallFieldText(text, cursor: cursor, stacking: stacking);

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
    expect(
      _at('//1AB', 4).expansionInputFor(_at('//1AB', 4).stackSegments(), alreadyExpanded: null),
      isNull,
      reason: 'the whole-field command path already asked',
    );
    expect(
      _at('KI2D//', 6).expansionInputFor(_at('KI2D//', 6).stackSegments(), alreadyExpanded: null),
      isNull,
      reason: 'an empty segment has nothing to expand',
    );
  });

  test('command input keeps the case typed; the call does not', () {
    expect(_at('note Called Bob', 0).commandInput, 'note Called Bob');
    expect(_at('note Called Bob', 0).call, 'NOTE CALLED BOB');
  });

  // A CW message keys `{{ qso.call }}` on the air: the raw field would send
  // every slash and fragment in Morse, and a `nextCall` that disagreed with
  // what the following Enter logs would tell the wrong station they're next.
  test('templateCalls names the call Enter logs, the one after it, and the fragment left over', () {
    const field = 'KN2//KI2D//NK2Y//FR';
    expect(_at(field, field.length).templateCalls, (call: 'NK2Y', nextCall: 'KI2D', nextPartial: 'FR'));
    expect(_at(field, 8).templateCalls, (call: 'KI2D', nextCall: 'NK2Y', nextPartial: 'FR'), reason: 'the cursor on KI2D picks it');
    expect(_at('KI2D//NK2Y', 10).templateCalls, (call: 'NK2Y', nextCall: 'KI2D', nextPartial: 'KI2D'), reason: 'a full call left over is still the fragment');
    expect(_at('KI2D//', 6).templateCalls, (call: 'KI2D', nextCall: '', nextPartial: ''), reason: 'nothing left after it');
    expect(_at('KI2D//NK2Y//', 12).templateCalls, (call: 'NK2Y', nextCall: 'KI2D', nextPartial: 'KI2D'), reason: 'a separator just typed is not a fragment');
  });

  // A CW message keys `call` as it stands: a stack read whole sends every
  // slash in Morse, and a blank one sends a report with no call in front.
  test('templateCalls never names more than one entry, nor a blank one', () {
    const field = 'KN2//KI2D//NK2Y//FR';
    expect(_at(field, 1).templateCalls.call, 'KN2', reason: 'no call to pick: the partial under the cursor, for "{{ qso.call }}?"');
    expect(_at('KR//', 4).templateCalls.call, 'KR', reason: 'a "//" just typed opens an empty segment; the partial before it is still the call');
    expect(_at('W1AW,', 5).templateCalls.call, 'W1AW', reason: 'a trailing comma names the entry before it');
    expect(_at('KI2D//W1AB,', 11).templateCalls.call, 'W1AB', reason: 'inside a stacked list too');
    expect(_at('KI2D//W1AB,W1AC', 13).templateCalls.call, 'W1AC', reason: 'the cursor entry of a stacked list');
  });

  test('templateCalls outside a stack is the call at the cursor, with nothing next', () {
    expect(_at('w1aw', 2).templateCalls, (call: 'W1AW', nextCall: '', nextPartial: ''));
    expect(_at('W1AW, K1ABC', 8).templateCalls, (call: 'K1ABC', nextCall: '', nextPartial: ''));
    expect(_at('KI2D//NK2Y', 3, stacking: false).templateCalls.nextCall, '', reason: 'editing never stacks');
  });
}
