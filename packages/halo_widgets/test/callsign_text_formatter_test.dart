// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `CallsignTextFormatter` — what a settings or dialog callsign field lets
// through. These fields hold a callsign and NOTHING else, so a stray
// character that slips in is stored. The subtler trap is the opposite one: a
// separator simply deleted runs two calls into one ("W1AWK2ABC") that passes
// every callsign check, so no warning ever tells the operator.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// Applies [text] as one edit from [from] with the caret at the end — a paste
/// when [text] is longer by more than one character, a keystroke otherwise.
String shape(String text, {bool list = false, String from = ''}) {
  final old = TextEditingValue(
    text: from,
    selection: TextSelection.collapsed(offset: from.length),
  );
  final edit = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  return CallsignTextFormatter(list: list).formatEditUpdate(old, edit).text;
}

void main() {
  test('uppercases and drops punctuation other than "/"', () {
    expect(shape('ki2d/p!-'), 'KI2D/P');
  });

  test('a "." is the "/" it was meant to be, on every platform', () {
    // Dropped instead, "KI2D.P" would be stored as KI2DP — somebody else's call.
    expect(shape('ki2d.p'), 'KI2D/P');
  });

  test('in a list, any run of separators is one comma', () {
    expect(shape('w1aw k2abc', list: true), 'W1AW,K2ABC');
    expect(shape('w1aw; k2abc', list: true), 'W1AW,K2ABC');
    expect(shape('n0dev, ', list: true), 'N0DEV,');
  });

  test('a pasted pair in a single-call field stays two words, so it reads as wrong', () {
    expect(shape('w1aw, k2abc'), 'W1AW K2ABC');
  });

  test('a separator typed into a single-call field is refused', () {
    expect(shape('W1AW ', from: 'W1AW'), 'W1AW');
    expect(shape('W1AW,', from: 'W1AW'), 'W1AW');
  });

  test('an edit in the middle keeps the caret where it was typed', () {
    const old = TextEditingValue(text: 'W1AWK2ABC', selection: TextSelection.collapsed(offset: 4));
    const edit = TextEditingValue(text: 'W1AW k2ABC', selection: TextSelection.collapsed(offset: 5));
    final result = const CallsignTextFormatter(list: true).formatEditUpdate(old, edit);
    expect(result.text, 'W1AW,K2ABC');
    expect(result.selection.end, 5);
  });
}
