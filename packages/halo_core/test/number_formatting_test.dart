// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The device's number conventions, for ordinary numbers.
//
// The trap this file exists for is round-tripping. A number field SHOWS
// `formatLocalizedNumber` and READS `parseLocalizedNumber`, and the operator
// edits the string in between — so the two must agree about which mark is the
// decimal, on every convention, or opening a form silently changes a value.
//
// Frequencies are deliberately absent: they never follow these conventions
// (frequency_notation_test.dart).

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  // Process-wide state: without this a comma-configured test leaks into
  // whatever runs next in this isolate.
  tearDown(NumberFormatting.instance.reset);

  void useComma() => NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');

  group('the default, which is what every other suite runs on', () {
    test('is US conventions', () {
      expect(NumberFormatting.instance.decimalSeparator, '.');
      expect(NumberFormatting.instance.groupingSeparator, ',');
      expect(parseLocalizedNumber('1,234.5'), 1234.5);
    });
  });

  group('under comma conventions', () {
    test('a plain number round-trips', () {
      useComma();
      expect(parseLocalizedNumber('1,5'), 1.5);
      expect(parseLocalizedNumber('1.234,5'), 1234.5);
      expect(formatLocalizedNumber(1.5), '1,5');
      expect(formatLocalizedNumber(75), '75', reason: 'a whole number grows no fraction');
      expect(parseLocalizedNumber(formatLocalizedNumber(1.5)), 1.5);
    });

    test('a period-decimal entry is refused rather than silently misread', () {
      useComma();
      // Under comma conventions `1.5` is grouped — and grouping strips to
      // `15`. Reading it as 1.5 instead would mean the conventions do not
      // actually decide anything.
      expect(parseLocalizedNumber('1.5'), 15);
    });
  });

  group('a configuration it cannot use', () {
    // Rejected at RUNTIME, not asserted: an assert is stripped from release,
    // and these values come from locale data read at launch — so the build
    // where a bad pair could actually arrive is the one an assert never runs
    // in. Each case below breaks parsing outright, not cosmetically.
    test('collided separators are refused, and the previous ones survive', () {
      useComma();
      expect(NumberFormatting.instance.configure(decimal: '.', grouping: '.', locale: 'xx'), isFalse);
      expect(NumberFormatting.instance.decimalSeparator, ',', reason: 'the working pair must not be lost');
      expect(parseLocalizedNumber('1,5'), 1.5, reason: 'and parsing still works');
    });

    test('an empty decimal is refused', () {
      // `replaceAll('', …)` would shred the digits of every entry.
      expect(NumberFormatting.instance.configure(decimal: '', grouping: ',', locale: 'xx'), isFalse);
      expect(NumberFormatting.instance.decimalSeparator, '.');
    });

    test('a usable pair is accepted', () {
      expect(NumberFormatting.instance.configure(decimal: ',', grouping: ' ', locale: 'fr_FR'), isTrue);
      expect(NumberFormatting.instance.groupingSeparator, ' ');
    });
  });

  group('a locale that groups with a space', () {
    // fr, ru, sv, pl. The grouping mark is invisible and multi-byte, and it
    // is NOT a character the operator's keyboard produces — so what they type
    // is an ordinary space, which must parse as the same number.
    setUp(() => NumberFormatting.instance.configure(decimal: ',', grouping: '\u202f', locale: 'fr_FR'));

    test('an ordinary typed space groups like the real mark', () {
      expect(parseLocalizedNumber('14 285,5'), 14285.5);
      expect(parseLocalizedNumber('14\u202f285,5'), 14285.5, reason: 'the narrow no-break space itself');
    });
  });
}
