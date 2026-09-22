// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The seven-segment table and the segment geometry behind the LCD face.
//
// A wrong digit here is not a crash and not a blank — it is a plausible
// number. `6` without its top bar is the calculator six, `9` without its
// bottom bar is a lowercase q, and both read as "a slightly odd font" rather
// than as a bug, on a pane whose whole job is to be trusted at a glance.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/clock/clock_math.dart';

void main() {
  group('segmentsForDigit', () {
    // Spelled out rather than generated: a table generated from the same
    // reasoning as the code under test agrees with it by construction.
    const expected = {0: 'abcdef', 1: 'bc', 2: 'abged', 3: 'abgcd', 4: 'fgbc', 5: 'afgcd', 6: 'afgecd', 7: 'abc', 8: 'abcdefg', 9: 'abcdfg'};

    test('lights the segments each digit is made of', () {
      for (final entry in expected.entries) {
        final want = entry.value.split('').map((c) => ClockSegment.values.byName(c)).toSet();
        expect(segmentsForDigit(entry.key), want, reason: '${entry.key} is wrong');
      }
    });

    test('8 lights everything, and every other digit is a subset of it', () {
      // Catches a segment name that exists in one row and nowhere else — a
      // typo that would otherwise only show as one malformed digit.
      expect(segmentsForDigit(8), ClockSegment.values.toSet());
      for (var d = 0; d <= 9; d++) {
        expect(segmentsForDigit(8).containsAll(segmentsForDigit(d)), isTrue);
      }
    });

    test('1 is the only two-segment digit, and 7 has no upper-left bar', () {
      // `7` gaining `f` is the single most common seven-segment slip: it
      // turns into a shape most people still read as a 7.
      expect(segmentsForDigit(1).length, 2);
      expect(segmentsForDigit(7).contains(ClockSegment.f), isFalse);
      final byLength = {for (var d = 0; d <= 9; d++) d: segmentsForDigit(d).length};
      expect(byLength.values.where((n) => n == 2).length, 1);
    });

    test('no digit lights nothing, and null lights nothing', () {
      // A suppressed leading zero is drawn as an empty cell. If null fell
      // through to `0` instead, every hour before ten would read `0X`.
      expect(segmentsForDigit(null), isEmpty);
      for (var d = 0; d <= 9; d++) {
        expect(segmentsForDigit(d), isNotEmpty);
      }
      // Out of range is empty rather than a RangeError: the digit comes from
      // arithmetic on a clock, and a crash in a painter takes the pane down.
      expect(segmentsForDigit(10), isEmpty);
      expect(segmentsForDigit(-1), isEmpty);
    });
  });

  group('segmentPath', () {
    const cell = Size(100, 180);
    const stroke = 18.0;

    Rect boundsOf(ClockSegment s) => segmentPath(s, cellSize: cell, stroke: stroke).getBounds();

    test('every segment stays inside its cell', () {
      // A segment escaping the cell overlaps its neighbour, and the digits
      // smear into each other only at certain stroke widths.
      for (final s in ClockSegment.values) {
        final b = boundsOf(s);
        expect(b.left, greaterThanOrEqualTo(-0.01), reason: '$s left');
        expect(b.top, greaterThanOrEqualTo(-0.01), reason: '$s top');
        expect(b.right, lessThanOrEqualTo(cell.width + 0.01), reason: '$s right');
        expect(b.bottom, lessThanOrEqualTo(cell.height + 0.01), reason: '$s bottom');
      }
    });

    test('bars run the way their position requires', () {
      // Catches a swapped case in the switch — `b` drawn where `a` goes is a
      // digit that is wrong in a way no table test can see.
      for (final s in [ClockSegment.a, ClockSegment.d, ClockSegment.g]) {
        final b = boundsOf(s);
        expect(b.width, greaterThan(b.height), reason: '$s should be a horizontal bar');
      }
      for (final s in [ClockSegment.b, ClockSegment.c, ClockSegment.e, ClockSegment.f]) {
        final b = boundsOf(s);
        expect(b.height, greaterThan(b.width), reason: '$s should be a vertical bar');
      }
    });

    test('the three bars stack top, middle, bottom in that order', () {
      expect(boundsOf(ClockSegment.a).center.dy, lessThan(boundsOf(ClockSegment.g).center.dy));
      expect(boundsOf(ClockSegment.g).center.dy, lessThan(boundsOf(ClockSegment.d).center.dy));
      // The middle bar is the cell's middle, not merely between the others.
      expect(boundsOf(ClockSegment.g).center.dy, closeTo(cell.height / 2, 0.01));
    });

    test('the uprights sit left and right, upper and lower', () {
      expect(boundsOf(ClockSegment.f).center.dx, lessThan(boundsOf(ClockSegment.b).center.dx));
      expect(boundsOf(ClockSegment.e).center.dx, lessThan(boundsOf(ClockSegment.c).center.dx));
      expect(boundsOf(ClockSegment.f).center.dy, lessThan(boundsOf(ClockSegment.e).center.dy));
      expect(boundsOf(ClockSegment.b).center.dy, lessThan(boundsOf(ClockSegment.c).center.dy));
    });
  });
}
