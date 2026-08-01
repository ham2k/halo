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

  group('modeForFrequency', () {
    test('narrowband digital carve-outs win over the wider CW/Data segment', () {
      expect(modeForFrequency(14074), 'FT8');
      expect(modeForFrequency(7047.5), 'FT4');
    });

    test('priority beats scope: a region-scoped carve-out still wins over the wider unscoped segment', () {
      // 80m 3568-3571 kHz is a real, in-use Region 3 FT8 window (priority
      // 100), scoped to that region. It must still win over the wider
      // unscoped CW/Data segments it sits inside — priority is compared
      // before scope, matching the source library, which lets a
      // high-priority segment win regardless of scope.
      expect(modeForFrequency(3570), 'FT8');
    });

    test('a known upstream data bug (12m FT4 has hi < lo) is carried through, not silently fixed', () {
      // band_plan_segments.dart is generated straight from the npm package,
      // which is authoritative — including this segment, which never
      // matches anything. 24920 kHz falls back to the next-narrowest
      // unscoped segment instead (the Data/RTTY one), not FT4.
      expect(modeForFrequency(24920), 'RTTY');
    });

    test('maps CW/Data/Phone sub-bands', () {
      expect(modeForFrequency(7030), 'CW');
      expect(modeForFrequency(3600), 'RTTY');
      expect(modeForFrequency(28400), 'SSB');
      expect(modeForFrequency(146520), 'FM');
    });

    test('an exact tie at a shared segment boundary resolves to the first-listed segment, every time', () {
      // 2m 144100 kHz sits exactly on the boundary between the unscoped CW
      // segment (144000-144100) and the unscoped RTTY segment
      // (144100-144200) — same priority, same scope, same 100kHz width.
      // Asserting the specific value (not just that repeated calls agree
      // with EACH OTHER) matters: a pure function called with the same
      // input is self-consistent within one process regardless of which
      // algorithm computes it — even the old, since-replaced List.sort
      // comparator this test guards against would pass a self-consistency
      // check. What actually distinguishes the fix is that the result is
      // CW, matching CW's earlier position in bandPlanModeSegments — not an
      // artifact of whichever way `List.sort` happens to order equal
      // elements.
      final results = List.generate(20, (_) => modeForFrequency(144100));
      expect(results.toSet(), {'CW'});
    });

    test('falls back to a region/country-scoped segment when no unscoped one matches', () {
      // 20m Phone above 14150 kHz has no globally-unscoped segment in the
      // source band plan (only a Region 1/2 one and a US one) — the
      // scoped fallback must still resolve it to SSB, not null.
      expect(modeForFrequency(14200), 'SSB');
      expect(modeForFrequency(14300), 'SSB');
    });

    test('at equal priority, an unscoped segment wins over a wider scoped "no restriction" marker', () {
      // 160m 1850 kHz: a same-priority (0) unscoped Phone/SSB segment
      // (1843-2000) and a narrower, scoped, mode-less "Australia: no
      // restriction" segment (1800-1875) both cover it. A pure
      // priority-then-width sort with no scope preference would pick the
      // narrower Australia segment and return a null guess for a frequency
      // that's plainly SSB everywhere else — the unscoped one must win
      // instead, precisely because nothing here outranks it on priority.
      expect(modeForFrequency(1850), 'SSB');
      expect(modeForFrequency(1860), 'SSB');
    });

    test('returns null where the band plan does not settle on one mode', () {
      expect(modeForFrequency(5332), isNull); // 60m Channel 1 (a fixed USB channel, modeled as null upstream)
      expect(modeForFrequency(10160), isNull); // no segment at all (above 30m)
    });
  });

  group('modeForFrequency with the operator\'s ITU region/country (HALO-52)', () {
    test('excludes a segment scoped to a different region, even at higher priority', () {
      // 80m 3568-3571 kHz is a Region 3 FT8 window (priority 100). A Region
      // 1 operator never gets it — 3570 kHz falls back to the (unscoped-
      // vs-Region-1 tie won by Region 1, see the next test) CW segment.
      expect(modeForFrequency(3570, ituRegion: 1), 'CW');
      // A Region 3 operator gets the FT8 window, same as the unknown-region
      // default (verified above in the un-scoped group).
      expect(modeForFrequency(3570, ituRegion: 3), 'FT8');
    });

    test('a segment scoped to the operator\'s own region wins a same-priority tie over a NARROWER unscoped one', () {
      // 20m 14130 kHz sits inside both the unscoped 14000-14150 CW segment
      // (width 150, narrower) and the Region-1/2-scoped 14112-14350 Phone
      // segment (width 238, wider). Without knowing the operator's region,
      // the unscoped one wins regardless of width (see the default-behavior
      // assertion below) — but once the operator is confirmed to actually
      // be in Region 2, the matching-scope segment wins even though it's
      // wider, proving scope-match is checked before narrowest-wins, not
      // just riding along with it.
      expect(modeForFrequency(14130, ituRegion: 2), 'SSB');
      expect(modeForFrequency(14130), 'CW');
    });

    test('a country match beats a same-priority unscoped segment (the reported bug: SSB guessed for US data-only spectrum)', () {
      // 40m 7080-7125 kHz is US-only Data (RTTY, in this table's mode
      // vocabulary) — narrower than both the unscoped 7060-7300 Phone/SSB
      // segment and the US-scoped 7000-7125 CW segment it sits inside, so
      // it wins outright once both are still candidates (country match kept
      // in, Phone/SSB not excluded but out-ranked).
      expect(modeForFrequency(7100, countryCode: 'us'), 'RTTY');
      // Without knowing the operator's country, this same frequency still
      // guesses the (wrong, for a US station) unscoped Phone/SSB segment —
      // documenting the bug HALO-52 fixes, not a new assertion about it.
      expect(modeForFrequency(7100), 'SSB');
    });

    test('a country-scoped "no restriction" marker resolves to null once it actually matches, not SSB', () {
      // 160m 1850 kHz: for an unknown operator this returns SSB (see the
      // un-scoped group above) because the Australia-only "no restriction"
      // segment can't be trusted to apply. For an actual Australian
      // operator it now wins outright (country match), correctly returning
      // null — the band plan doesn't dictate a mode there.
      expect(modeForFrequency(1850, countryCode: 'au'), isNull);
    });

    test('a scoped segment for a different country is still excluded even when the operator\'s region is known', () {
      // 160m 1850 kHz for a Region 3 operator who isn't in Australia: the
      // Australia-only marker doesn't match (region alone doesn't satisfy a
      // countries-only scope), so the unscoped SSB segment wins, same as
      // the unknown-operator default.
      expect(modeForFrequency(1850, ituRegion: 3), 'SSB');
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

  group('fmtFreqInput', () {
    test('preserves full precision and round-trips through parseFreq', () {
      // The bug fmtFreq caused on the edit field: 100Hz rounding degraded a
      // stored sub-100Hz frequency just by selecting the QSO.
      for (final khz in [14074.25, 7025.123, 10136.05, 50313.0, 1296200.0]) {
        expect(parseFreq(fmtFreqInput(khz)), khz, reason: 'round-trip $khz');
      }
    });

    test('trims trailing zeros and the dot, and never groups', () {
      expect(fmtFreqInput(7025), '7025');
      expect(fmtFreqInput(14285.5), '14285.5');
      expect(fmtFreqInput(14074.25), '14074.25');
      expect(fmtFreqInput(1296200), '1296200');
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

  group('superModeForMode', () {
    test('classifies CW, phone, and digital modes', () {
      expect(superModeForMode('CW'), 'CW');
      expect(superModeForMode('cw'), 'CW');
      expect(superModeForMode('SSB'), 'Phone');
      expect(superModeForMode('FM'), 'Phone');
      expect(superModeForMode('AM'), 'Phone');
      expect(superModeForMode('DIGITALVOICE'), 'Phone');
      expect(superModeForMode('FT8'), 'Digital');
      expect(superModeForMode('FT4'), 'Digital');
      expect(superModeForMode('RTTY'), 'Digital');
      expect(superModeForMode('PSK31'), 'Digital');
    });

    test('a null mode has no super mode', () {
      expect(superModeForMode(null), isNull);
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

    // The shapes `@ham2k/lib-callsigns` recognizes, since that library is what
    // will parse these calls once they're logged. Anything here that stopped
    // matching would stop being loggable, so they're worth naming one by one.
    test('accepts every prefix form real callsigns come in', () {
      expect(looksLikeCallsign('K1A'), isTrue, reason: 'shortest US call');
      expect(looksLikeCallsign('N0CALL'), isTrue);
      expect(looksLikeCallsign('KD2ABC'), isTrue, reason: 'two-letter prefix');
      expect(looksLikeCallsign('2E0ABC'), isTrue, reason: 'digit-letter-digit prefix');
      expect(looksLikeCallsign('3D2AG'), isTrue, reason: 'three-character prefix');
      expect(looksLikeCallsign('4U1UN'), isTrue, reason: '4U carries no separating digit');
      expect(looksLikeCallsign('5UA99WS'), isTrue, reason: 'nor does 5U');
      expect(looksLikeCallsign('V67C'), isTrue, reason: 'prefix ending in a digit');
      expect(looksLikeCallsign('GB100RSGB'), isTrue, reason: 'special event call');
    });

    test('accepts pre- and postindicators, including stacked ones', () {
      expect(looksLikeCallsign('W1AW/P'), isTrue);
      expect(looksLikeCallsign('N0CALL/QRP'), isTrue);
      expect(looksLikeCallsign('N0CALL/1'), isTrue, reason: 'digit-only indicator');
      expect(looksLikeCallsign('N0CALL/1/QRP/P'), isTrue, reason: 'several at once');
      expect(looksLikeCallsign('MM/N0CALL'), isTrue, reason: 'preindicator without a digit');
      expect(looksLikeCallsign('VP2V/AA7V'), isTrue);
      expect(looksLikeCallsign('V67C/9'), isTrue);
    });

    test('rejects fragments', () {
      expect(looksLikeCallsign(''), isFalse);
      expect(looksLikeCallsign('W'), isFalse);
      expect(looksLikeCallsign('123'), isFalse);
      expect(looksLikeCallsign('QRZ'), isFalse);
      expect(looksLikeCallsign('EA4'), isFalse, reason: 'a bare prefix is not a call');
    });

    // Everything the `radio-commands` extension interprets when typed into the
    // call field. A match here is not cosmetic: it fires an offline+online
    // lookup for a station that does not exist. "20M" used to do exactly that.
    //
    // Both lists are transcribed from that extension's own BAND_MATCH and
    // MODE_MATCH (extensions/core/radio-commands/src/index.ts) — Dart can't
    // read those, so a new band or mode has to be added here by hand.
    test('rejects band commands', () {
      for (final band in ['2200', '630', '160', '80', '60', '40', '30', '20', '17', '15', '12', '10', '6', '4', '2']) {
        expect(looksLikeCallsign('${band}M'), isFalse, reason: '${band}M is a band command');
        expect(looksLikeCallsign(band), isFalse, reason: '$band is a band command');
      }
    });

    test('rejects mode commands', () {
      for (final mode in ['CW', 'SSB', 'USB', 'LSB', 'FM', 'AM', 'FT8', 'FT4', 'FT2', 'RTTY']) {
        expect(looksLikeCallsign(mode), isFalse, reason: '$mode is a mode command');
      }
    });

    // Call stacking (issue #7) separates calls with "//", and the call-notes
    // extension reads a leading "//" as an expansion command. Neither is a
    // single callsign, whatever the segments around it look like.
    test('rejects "//" stacks and expansions', () {
      expect(looksLikeCallsign('K1ABC//W1AW'), isFalse);
      expect(looksLikeCallsign('//JOE'), isFalse);
      expect(looksLikeCallsign('W1AW//'), isFalse);
    });

    test('rejects comma-separated call lists as a single call', () {
      expect(looksLikeCallsign('K1ABC,N2XYZ'), isFalse);
    });
  });
}
