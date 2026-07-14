// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
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

  group('hzDigitsNeeded', () {
    test('zero when every frequency lands on an exact kHz', () {
      expect(hzDigitsNeeded([14074, 7200, null]), 0);
    });

    test('one digit for a lone tenths-of-kHz value', () {
      // 14074.5 kHz -> 500 Hz -> "500" -> 1 significant digit.
      expect(hzDigitsNeeded([14074, 14074.5]), 1);
    });

    test('takes the max digit count across all QSOs', () {
      // 14074.5 -> 500 Hz (1 digit); 14074.05 -> 50 Hz (2 digits).
      expect(hzDigitsNeeded([14074.5, 14074.05]), 2);
    });

    test('three digits for single-Hz precision', () {
      // 14074.005 kHz -> 5 Hz -> "005" -> 3 significant digits.
      expect(hzDigitsNeeded([14074.005]), 3);
    });

    test('a floating-point boundary value that rounds exactly to a whole kHz needs zero digits', () {
      // 8.158 * 1000 is the double 8157.999999999999 — the old
      // floor/subtract approach would round its Hz remainder up to 1000,
      // clamp to 999, and report 3 digits needed for what is actually an
      // exact-kHz frequency.
      expect(hzDigitsNeeded([8.158 * 1000]), 0);
    });
  });

  group('freqDisplayParts', () {
    test('splits MHz/kHz with no Hz segment when hzDigits is 0', () {
      final parts = freqDisplayParts(14074, hzDigits: 0);
      expect(parts.mhz, '14');
      expect(parts.khz, '074');
      expect(parts.hz, isNull);
    });

    test('pads the Hz segment to the requested digit count', () {
      // 500 Hz sliced to 2 digits reads "50" (padding on the right, since
      // the underlying value is already zero-padded to 3 digits).
      final parts = freqDisplayParts(14074.5, hzDigits: 2);
      expect(parts.hz, '50');
    });

    test('an exact-kHz QSO still renders the operation-wide Hz width', () {
      final parts = freqDisplayParts(14074, hzDigits: 2);
      expect(parts.hz, '00');
    });

    test('three-digit Hz precision', () {
      final parts = freqDisplayParts(14074.005, hzDigits: 3);
      expect(parts.mhz, '14');
      expect(parts.khz, '074');
      expect(parts.hz, '005');
    });

    test('carries into kHz/MHz instead of clamping when floating-point error rounds Hz up to 1000', () {
      // parseFreq('8.158') computes 8.158 * 1000, which is the IEEE-754
      // double 8157.999999999999 — flooring/subtracting that in pieces (the
      // old implementation) rounds the Hz remainder up to 1000 and clamps it
      // back to 999, displaying "8.157.999" instead of "8.158.000".
      final khz = 8.158 * 1000;
      final parts = freqDisplayParts(khz, hzDigits: 3);
      expect(parts.mhz, '8');
      expect(parts.khz, '158');
      expect(parts.hz, '000');
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
