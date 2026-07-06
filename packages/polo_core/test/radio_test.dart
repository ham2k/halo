// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:polo_core/polo_core.dart';
import 'package:test/test.dart';

void main() {
  group('bandForFrequency', () {
    test('maps HF frequencies', () {
      expect(bandForFrequency(14074), '20m');
      expect(bandForFrequency(7200), '40m');
      expect(bandForFrequency(28500), '10m');
      expect(bandForFrequency(146520), '2m');
    });

    test('returns null outside any band', () {
      expect(bandForFrequency(13000), isNull);
      expect(bandForFrequency(0), isNull);
    });
  });

  group('parseFreq', () {
    test('parses kHz input', () {
      expect(parseFreq('14285'), 14285);
      expect(parseFreq('14285.5'), 14285.5);
      expect(parseFreq('14,285.5'), 14285.5);
    });

    test('treats small dotted values as MHz', () {
      expect(parseFreq('14.285'), 14285);
      expect(parseFreq('7.2'), 7200);
      expect(parseFreq('146.52'), 146520);
    });

    test('rejects junk', () {
      expect(parseFreq(''), isNull);
      expect(parseFreq('abc'), isNull);
      expect(parseFreq('-5'), isNull);
    });
  });

  group('fmtFreq', () {
    test('groups thousands and trims whole numbers', () {
      expect(fmtFreq(14285), '14,285');
      expect(fmtFreq(14285.5), '14,285.5');
      expect(fmtFreq(472), '472');
      expect(fmtFreq(1296200), '1,296,200');
    });

    test('carries the rounded fraction into the whole part', () {
      // A fraction >= 0.95 rounds to 1.0 at one decimal place; the carry
      // must propagate into the whole part instead of being dropped.
      expect(fmtFreq(14285.96), '14,286');
      expect(fmtFreq(14285.95), '14,286');
      expect(fmtFreq(999.96), '1,000');
    });
  });

  group('defaultRSTFor', () {
    test('phone vs everything else', () {
      expect(defaultRSTFor('SSB'), '59');
      expect(defaultRSTFor('FM'), '59');
      expect(defaultRSTFor('CW'), '599');
      expect(defaultRSTFor('FT8'), '599');
    });
  });

  group('looksLikeCallsign', () {
    test('accepts plausible calls', () {
      expect(looksLikeCallsign('W1AW'), isTrue);
      expect(looksLikeCallsign('KI2D'), isTrue);
      expect(looksLikeCallsign('EA4/KI2D'), isTrue);
      expect(looksLikeCallsign('KI2D/M'), isTrue);
      expect(looksLikeCallsign('lu7abc'), isTrue);
      expect(looksLikeCallsign('9A1A'), isTrue);
    });

    test('rejects fragments', () {
      expect(looksLikeCallsign(''), isFalse);
      expect(looksLikeCallsign('W'), isFalse);
      expect(looksLikeCallsign('123'), isFalse);
      expect(looksLikeCallsign('QRZ'), isFalse);
    });
  });
}
