// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operator's Number Formatting choice, where it meets frequencies.
//
// The trap this file exists for is round-tripping. A frequency field SHOWS
// `fmtFreqInput` and READS `parseFreq`, and the operator edits the string in
// between — so the two must agree about which mark is the decimal, on every
// setting, or selecting a QSO for editing silently changes its frequency.
// Every assertion below that pairs a format with a parse is that one bug.
//
// The second trap is the MHz heuristic. `parseFreq` reads a value under 1000
// with a decimal separator as MHz, and under comma conventions `14.285` and
// `14,285` swap meanings. Getting that backwards puts the operator on a
// different band, which is the kind of wrong that reaches the air.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  // Process-wide state: without this a comma-configured test leaks into
  // whatever runs next in this isolate.
  tearDown(NumberFormatting.instance.reset);

  void useComma() => NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'es_ES');

  group('the default, which is what every other suite runs on', () {
    test('is US conventions, so nothing changes until an operator asks', () {
      expect(NumberFormatting.instance.decimalSeparator, '.');
      expect(NumberFormatting.instance.groupingSeparator, ',');
      expect(fmtFreq(14285.5), '14,285.5');
      expect(parseFreq('14285.5'), 14285.5);
    });
  });

  group('under comma conventions', () {
    test('formats a frequency the way es and de write it', () {
      useComma();
      expect(fmtFreq(14285.5), '14.285,5');
      expect(fmtFreq(7025), '7.025');
      expect(fmtFreqToTheHz(14285.4), '14.285,400');
      expect(fmtFreqInput(14074.25), '14074,25');
    });

    test('reads the decimal separator as the decimal, and the other as grouping', () {
      useComma();
      // The pair that swaps meaning with the setting. Under period
      // conventions these two land the other way round, which is the
      // assertion in the group below.
      expect(parseFreq('14,285'), 14285.0, reason: 'comma is the decimal, so this is 14.285 MHz');
      expect(parseFreq('14.285'), 14285.0, reason: 'period is grouping, so this is 14285 kHz');
      expect(parseFreq('7,1'), 7100.0, reason: '7.1 MHz, not 71 kHz');
      expect(parseFreq('14285,5'), 14285.5);
    });

    test('a frequency survives the trip through an editable field', () {
      useComma();
      for (final khz in [14074.25, 7025.0, 14285.5, 50313.0, 1296000.0]) {
        expect(parseFreq(fmtFreqInput(khz)), khz, reason: '$khz did not round-trip');
      }
    });

    test('and so does a plain number', () {
      useComma();
      expect(parseLocalizedNumber('1,5'), 1.5);
      expect(parseLocalizedNumber('1.234,5'), 1234.5);
      expect(formatLocalizedNumber(1.5), '1,5');
      expect(formatLocalizedNumber(75), '75', reason: 'a whole number grows no fraction');
      expect(parseLocalizedNumber(formatLocalizedNumber(1.5)), 1.5);
    });

    test('a period-decimal entry is refused rather than silently misread', () {
      useComma();
      // The operator asked for comma conventions, so `1.5` is grouped — and
      // grouping strips to `15`. Reading it as 1.5 instead would mean the
      // setting does not actually decide anything.
      expect(parseLocalizedNumber('1.5'), 15);
    });
  });

  group('under period conventions', () {
    test('the same two strings mean the opposite things', () {
      expect(parseFreq('14,285'), 14285.0, reason: 'comma is grouping, so this is 14285 kHz');
      expect(parseFreq('14.285'), 14285.0, reason: 'period is the decimal, so this is 14.285 MHz');
      expect(parseFreq('7.1'), 7100.0);
      expect(parseFreq('7,1'), 71.0, reason: 'grouped, so 71 kHz — not a band, but not our guess to make');
    });
  });

  test('a frequency round-trips under whichever setting is in force', () {
    // The one property that must hold on both settings, asserted as one
    // loop so a change that fixes one and breaks the other cannot pass.
    for (final configure in [NumberFormatting.instance.reset, useComma]) {
      configure();
      for (final khz in [7025.0, 14074.25, 21300.5]) {
        expect(parseFreq(fmtFreqInput(khz)), khz);
      }
    }
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
      expect(parseFreq('14.285'), 14285.0, reason: 'and parsing still works');
    });

    test('an empty decimal is refused', () {
      // `contains('')` is true of every string, so this would read every
      // entry as MHz and multiply it by 1000, while `replaceAll('', …)`
      // shreds the digits.
      expect(NumberFormatting.instance.configure(decimal: '', grouping: ',', locale: 'xx'), isFalse);
      expect(NumberFormatting.instance.decimalSeparator, '.');
    });

    test('a usable pair is accepted', () {
      expect(NumberFormatting.instance.configure(decimal: ',', grouping: ' ', locale: 'fr_FR'), isTrue);
      expect(NumberFormatting.instance.groupingSeparator, ' ');
    });
  });

  group('LF and MF, where the MHz heuristic would run the wrong way', () {
    // 2200m and 630m are the bands whose frequency in kHz is BELOW 1000, so
    // `parseFreq`'s "a decimal means MHz" rule reads 472.5 as 472.5 MHz and
    // lands the operator a thousandfold away. The band plan breaks the tie.
    test('a sub-MHz frequency round-trips through an editable field', () {
      for (final khz in [472.5, 137.5, 475.0, 1810.0]) {
        expect(parseFreq(fmtFreqInput(khz)), khz, reason: '$khz did not round-trip');
      }
    });

    test('and under comma conventions too', () {
      useComma();
      expect(parseFreq(fmtFreqInput(472.5)), 472.5);
      expect(parseFreq('472,5'), 472.5);
    });

    test('the MHz reading still wins when NEITHER naming is a band', () {
      // 5 MHz is WWV, not an allocation — and 5 kHz is nothing at all. The
      // tie-break only rescues the case where the kHz reading is
      // unambiguously right, so this must stay MHz.
      expect(parseFreq('5.0'), 5000.0);
      expect(parseFreq('7.1'), 7100.0, reason: '40m, the ordinary case');
      expect(parseFreq('14.285'), 14285.0);
    });

    test('the MHz form still parses, so old habits keep working', () {
      expect(parseFreq('0.4725'), 472.5);
    });
  });

  group('a locale that groups with a space', () {
    // fr, ru, sv, pl. The grouping mark is invisible and multi-byte, and it
    // is NOT a character the operator's keyboard produces — so what they type
    // is an ordinary space, which must parse as the same number.
    setUp(() => NumberFormatting.instance.configure(decimal: ',', grouping: ' ', locale: 'fr_FR'));

    test('a frequency round-trips through an editable field', () {
      for (final khz in [7025.0, 14074.25, 1296000.0]) {
        expect(parseFreq(fmtFreqInput(khz)), khz, reason: '$khz did not round-trip');
      }
    });

    test('the decimal is the comma, and a period is grouping', () {
      expect(parseFreq('14285,5'), 14285.5);
      expect(parseFreq('7,1'), 7100.0);
    });

    test('an ordinary typed space groups like the real mark', () {
      expect(parseLocalizedNumber('14 285,5'), 14285.5);
      expect(parseLocalizedNumber('14 285,5'), 14285.5, reason: 'the narrow no-break space itself');
    });

    test('and a frequency box tolerates it identically', () {
      // The two parsers must agree: the grouping mark here is one no keyboard
      // produces, so what an operator types or pastes is an ordinary space.
      expect(parseFreq('14 285,5'), 14285.5);
      expect(parseFreq('14 285,5'), 14285.5);
    });
  });
}
