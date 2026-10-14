// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:halo_core/src/ham/band_plan_segments.dart';
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
      expect(modeForFrequency(7100, ituRegion: 2, countryCode: 'us'), 'RTTY');
      // Without knowing the operator's country, this same frequency still
      // guesses the (wrong, for a US station) unscoped Phone/SSB segment —
      // documenting the bug HALO-52 fixes, not a new assertion about it.
      expect(modeForFrequency(7100), 'SSB');
      // The country code rides along with the region or not at all: on its
      // own it is discarded, so this is the unknown-operator answer above,
      // not the US one. A caller cannot half-place the operator.
      expect(modeForFrequency(7100, countryCode: 'us'), 'SSB');
    });

    test('a country-scoped "no restriction" marker resolves to null once it actually matches, not SSB', () {
      // 160m 1850 kHz: for an unknown operator this returns SSB (see the
      // un-scoped group above) because the Australia-only "no restriction"
      // segment can't be trusted to apply. For an actual Australian
      // operator it now wins outright (country match), correctly returning
      // null — the band plan doesn't dictate a mode there.
      expect(modeForFrequency(1850, ituRegion: 3, countryCode: 'au'), isNull);
    });

    test('the operator\'s own COUNTRY outranks a narrower segment scoped only to their region', () {
      // 30m 10125 kHz for a Kenyan operator: the "Africa south of the
      // Equator" marker (10100-10150, no single mode, country-scoped) sits
      // inside the narrower Region 1 CW segment (10100-10130). Ranking by
      // width alone hands back CW and the country-specific entry — the more
      // specific rule, and the only one written for this operator — never
      // applies at all.
      expect(modeForFrequency(10125, ituRegion: 1, countryCode: 'ke'), isNull);
      // The same frequency for a Region 1 operator the marker does not name
      // still gets the region's CW segment.
      expect(modeForFrequency(10125, ituRegion: 1, countryCode: 'gb'), 'CW');
      // 80m 3600 kHz, same shape: Australia's whole-band marker (3500-3800)
      // over the narrower Region 3 Phone segment (3535-3800).
      expect(modeForFrequency(3600, ituRegion: 3, countryCode: 'au'), isNull);
      expect(modeForFrequency(3600, ituRegion: 3, countryCode: 'nz'), 'SSB');
    });

    test('a lone country code places nobody: a region-scoped carve-out is not excluded on a dimension the caller never gave', () {
      // 80m 3568-3571 kHz is the Region 3 FT8 window. Honouring a bare
      // 'us' would exclude it — on the REGION, which the caller never
      // supplied — and hand back the wider CW segment instead. The country
      // and the region always travel together out of the DXCC table
      // (`regionAndCountryForDxccCode`; no entity there has a country code
      // without a region), so a lone country code is discarded rather than
      // half-applied.
      expect(modeForFrequency(3568, countryCode: 'us'), 'FT8');
      expect(modeForFrequency(3568), 'FT8');
      // Told the region as well, the window really is excluded.
      expect(modeForFrequency(3568, ituRegion: 2, countryCode: 'us'), 'CW');
    });

    test('a scoped segment for a different country is still excluded even when the operator\'s region is known', () {
      // 160m 1850 kHz for a Region 3 operator who isn't in Australia: the
      // Australia-only marker doesn't match (region alone doesn't satisfy a
      // countries-only scope), so the unscoped SSB segment wins, same as
      // the unknown-operator default.
      expect(modeForFrequency(1850, ituRegion: 3), 'SSB');
    });
  });

  group('isOutOfBandFrequency', () {
    test('flags a frequency the operator\'s own region does not allocate to amateurs', () {
      // 40m 7200-7300 kHz is Region 1's "Out of band" segment: a Region 2
      // operator transmits there legally every day, so the flag has to be
      // scoped, not a property of the frequency.
      expect(isOutOfBandFrequency(7250, ituRegion: 1), isTrue);
      expect(isOutOfBandFrequency(7250, ituRegion: 2), isFalse);
      // 2m above 146 MHz, same shape.
      expect(isOutOfBandFrequency(146520, ituRegion: 1), isTrue);
      expect(isOutOfBandFrequency(146520, ituRegion: 2), isFalse);
    });

    test('160m: only the sliver Region 1 really lacks, not the phone band above it', () {
      // Region 1's out-of-band sliver is 1800-1810; everything above it on
      // this band is licensed. A span reaching further up — the whole band
      // with only 1810-1838 carved back out, say — fires on 160m phone, the
      // busiest part of the band, and a warning that goes off during
      // ordinary operating is worse than no warning at all: it teaches the
      // operator to ignore the four spans where it is right.
      expect(isOutOfBandFrequency(1805, ituRegion: 1), isTrue);
      for (final khz in [1820.0, 1839.0, 1845.0, 1900.0, 1990.0]) {
        expect(isOutOfBandFrequency(khz, ituRegion: 1), isFalse, reason: '$khz kHz is licensed in Region 1');
      }
      // Region 2 has the whole band and is never warned anywhere on it.
      expect(isOutOfBandFrequency(1805, ituRegion: 2), isFalse);
    });

    test('an allocation\'s own edge frequency is not an accusation', () {
      // An out-of-band span ABUTS an allocation rather than overlapping it,
      // so the frequency they share is the first (or last) one the operator
      // may legally use — and 1810.000 is an ordinary Region 1 CW frequency,
      // not a corner case. Segment edges are inclusive for the mode guess,
      // which is what makes the shared edge land inside the span.
      expect(isOutOfBandFrequency(1810, ituRegion: 1), isFalse, reason: "Region 1's 160m opens here");
      expect(isOutOfBandFrequency(7200, ituRegion: 1), isFalse, reason: "Region 1's 40m ends here");
      expect(isOutOfBandFrequency(440000, ituRegion: 1), isFalse, reason: "Region 1's 70cm ends here");
      // A hair inside is still out of band — the rule gives up the edge
      // itself, not the span.
      expect(isOutOfBandFrequency(1809.9, ituRegion: 1), isTrue);
      expect(isOutOfBandFrequency(7200.1, ituRegion: 1), isTrue);
    });

    test('says nothing when the operator\'s region and country are both unknown', () {
      // Every out-of-band segment in the band plan is region- or
      // country-scoped, so an unscoped caller can never be told they are
      // transmitting illegally — accusing an operator whose location we
      // haven't resolved yet would be worse than staying quiet.
      expect(isOutOfBandFrequency(7250), isFalse);
      expect(isOutOfBandFrequency(146520), isFalse);
    });

    test('is false where the band plan simply has no opinion', () {
      // Not the same answer as "no segment settles on a mode": both make
      // modeForFrequency return null, and collapsing them is exactly the
      // bug this flag exists to undo.
      expect(modeForFrequency(5332), isNull);
      expect(isOutOfBandFrequency(5332), isFalse);
      expect(isOutOfBandFrequency(10160, ituRegion: 1), isFalse);
    });

    test('every out-of-band segment is scoped, which is what lets an unplaced operator be left alone', () {
      // [isOutOfBandFrequency]'s whole safety argument — that an operator we
      // cannot place is never told they are transmitting illegally — is a
      // property of the DATA, not of the code: it holds only while every
      // out-of-band segment carries a region or country restriction. An
      // unscoped one arriving from upstream would start accusing every
      // caller who passed no scope at all, and nothing else here would
      // notice.
      final unscoped = bandPlanModeSegments.where((s) => s.mode == outOfBandMode && s.regions.isEmpty && s.countries.isEmpty);
      expect(unscoped, isEmpty);
    });

    test('the sentinel never escapes as a mode', () {
      // `outOfBandMode` is a display value, not something that can be
      // logged or offered in the Mode dropdown — modeForFrequency folds it
      // back to null for every caller guessing what to log.
      expect(modeForFrequency(7250, ituRegion: 1), isNull);
      expect(modeForFrequency(146520, ituRegion: 1), isNull);
      expect(modes, isNot(contains(outOfBandMode)));
      expect(mainModes, isNot(contains(outOfBandMode)));
      expect(popularModes, isNot(contains(outOfBandMode)));
      expect(adifModes, isNot(contains(outOfBandMode)));
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

  group('parseBandInput', () {
    test('reads a band with its unit, however it was typed', () {
      expect(parseBandInput('20m'), '20m');
      expect(parseBandInput('20M'), '20m');
      expect(parseBandInput(' 20 m '), '20m');
      expect(parseBandInput('70cm'), '70cm');
      expect(parseBandInput('70CM'), '70cm');
      expect(parseBandInput('1.25m'), '1.25m');
      expect(parseBandInput('2190m'), '2190m');
    });

    test('reads a bare number as the band of that wavelength', () {
      // The iOS keyboard for this field carries no letters, so a suffix-only
      // syntax would make band entry desktop-only.
      expect(parseBandInput('20'), '20m');
      expect(parseBandInput('1.25'), '1.25m');
      expect(parseBandInput('2190'), '2190m');
    });

    test('a bare number with no meters band falls through to centimeters', () {
      // 70/33/23 name only cm bands; nothing should have to type the unit
      // just because the band happens to be a short one.
      expect(parseBandInput('70'), '70cm');
      expect(parseBandInput('33'), '33cm');
      expect(parseBandInput('23'), '23cm');
    });

    test('reads every band the app offers, not just the ones with edges', () {
      // `extendedBands` is the whole vocabulary the app knows; `bands` is the
      // narrower frequency-edge table, and matching against it left everything past
      // 23cm unreachable while answering '2m' for the '2mm' a microwave
      // operator typed.
      expect(parseBandInput('2mm'), '2mm');
      expect(parseBandInput('2.5MM'), '2.5mm');
      expect(parseBandInput('1.25cm'), '1.25cm');
      expect(parseBandInput('submm'), 'submm');
      expect(parseBandInput('11m'), '11m');
      for (final band in extendedBands.where((b) => b != 'other')) {
        expect(parseBandInput(band), band, reason: '$band is not reachable by name');
      }
    });

    test('millimeter bands stay out of the bare-number fallback', () {
      // "1" means 1mm to nobody, and a bare number that named the wrong band
      // is worse than one that names none.
      expect(parseBandInput('1'), isNull);
      expect(parseBandInput('2.5'), isNull);
      expect(parseBandInput('2'), '2m', reason: 'the meters band still wins its number');
      expect(parseBandInput('6'), '6m');
    });

    test('the aliases operators actually say', () {
      // 75m is what the phone end of 80m is called on the air, and 2200m is
      // the common name for the band this app's table calls 2190m.
      expect(parseBandInput('75'), '80m');
      expect(parseBandInput('75m'), '80m');
      expect(parseBandInput('2200'), '2190m');
      expect(parseBandInput('2200M'), '2190m');
      expect(parseBandInput('75cm'), isNull, reason: 'the alias is the meters band');
    });

    test('a stated unit is not second-guessed', () {
      // "20cm" is a typo for 20m, not a request for it — silently correcting
      // it would log a contact on a band the operator never named.
      expect(parseBandInput('20cm'), isNull);
      expect(parseBandInput('70m'), isNull);
    });

    test('rejects anything that is not a band name', () {
      expect(parseBandInput(''), isNull);
      expect(parseBandInput('m'), isNull);
      expect(parseBandInput('abc'), isNull);
      expect(parseBandInput('14285'), isNull);
      expect(parseBandInput('-20'), isNull);
      // A band is named by an exact string, not by its numeric value: these
      // spellings appear in no dropdown and mean nothing to the extensions,
      // which compare band strings for equality.
      expect(parseBandInput('20.0m'), isNull);
      expect(parseBandInput('1.250m'), isNull);
    });

    test('no band number is also a frequency inside a band', () {
      // The property that makes the bare-number form safe. If `bands` ever
      // grows an entry that breaks it — a band whose wavelength number lands
      // inside another band's edges — the frequency field would start
      // swallowing real frequencies, and this is the only thing watching.
      // Every name reachable bare — millimeters are not in the fallback, and
      // the aliases are reachable bare too without being in `extendedBands`.
      final reachable = [...extendedBands, ...bandAliases.keys];
      for (final band in reachable.where((b) => b.endsWith('m') && !b.endsWith('mm'))) {
        final asFrequency = parseFreq(band.replaceAll(RegExp(r'(c?m)$'), ''));
        expect(bandForFrequency(asFrequency!), isNull, reason: '$band typed bare parses as $asFrequency kHz, a real frequency');
      }
    });
  });

  group('fmtFreq', () {
    test('groups thousands and trims whole numbers', () {
      expect(fmtFreq(14285), '14,285');
      expect(fmtFreq(14285.5), '14,285.5');
      expect(fmtFreq(472), '472');
      expect(fmtFreq(1296200), '1,296,200');
    });

    test('keeps every digit down to the Hz, and no trailing zero', () {
      // A label names the frequency a QSO logs at: rounding to 100 Hz shows
      // 14,074.25 as "14,074.3", a frequency nobody tuned.
      expect(fmtFreq(14074.25), '14,074.25');
      expect(fmtFreq(14285.432), '14,285.432');
      expect(fmtFreq(14285.0001), '14,285');
    });

    test('keeps at least minDecimals, zeros included, and never more than the Hz', () {
      // A label that follows a moving reading holds its width this way.
      expect(fmtFreq(14075, minDecimals: 1), '14,075.0');
      expect(fmtFreq(14075.1, minDecimals: 2), '14,075.10');
      expect(fmtFreq(14075.123, minDecimals: 1), '14,075.123');
    });

    test('carries into the whole part instead of formatting a fourth digit', () {
      expect(fmtFreq(14285.9996), '14,286');
      expect(fmtFreq(999.9999), '1,000');
    });
  });

  group('fmtFreqToTheHz', () {
    test('always shows three decimals, grouped', () {
      // Trailing zeros are the point: a live reading that changes width as
      // its last digits settle is unreadable.
      expect(fmtFreqToTheHz(14285.4), '14,285.400');
      expect(fmtFreqToTheHz(14285), '14,285.000');
      expect(fmtFreqToTheHz(14285.432), '14,285.432');
      expect(fmtFreqToTheHz(472.5), '472.500');
    });

    test('carries into the whole part instead of formatting a fourth digit', () {
      // Splitting the double directly leaves a fraction that rounds to 1000,
      // and 14285.9996 formats as "14,285.1000".
      expect(fmtFreqToTheHz(14285.9996), '14,286.000');
      expect(fmtFreqToTheHz(999.9999), '1,000.000');
    });
  });

  group('fmtFreqInput', () {
    test('preserves full precision and round-trips through parseFreq', () {
      // A rounded value in the edit field degrades a stored sub-100Hz
      // frequency just by selecting the QSO.
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
      // A connected rig reports the concrete sideband — no CAT protocol has an
      // "SSB" mode and nothing maps it back — so USB/LSB must count as phone,
      // or having a radio attached silently changes the report.
      expect(defaultRSTFor('USB'), '59');
      expect(defaultRSTFor('LSB'), '59');
      expect(defaultRSTFor('CW'), '599');
      expect(defaultRSTFor('PSK31'), '599');
    });

    test('the operator overrides the value, never which band a mode is in', () {
      expect(defaultRSTFor('CW', cw: '5NN'), '5NN');
      expect(defaultRSTFor('RTTY', cw: '5NN'), '5NN', reason: 'RTTY shares the CW band');
      expect(defaultRSTFor('SSB', cw: '5NN'), '59', reason: 'the CW override must not reach phone');
      expect(defaultRSTFor('FT8', snr: '+00'), '+00');
    });

    test('a blank override is not an override', () {
      // Clearing the setting has to restore the standard report — an operator
      // who empties the field would otherwise log a blank one forever.
      expect(defaultRSTFor('CW', cw: ''), '599');
      expect(defaultRSTFor('CW', cw: '   '), '599');
      expect(defaultRSTFor('SSB', phone: null), '59');
    });

    test('the FT modes report signal-to-noise, not RST', () {
      // A three-digit RST on FT8 is meaningless — the exchange is a dB
      // figure, and 599 is what gets exported to a mode nobody sends it in.
      expect(defaultRSTFor('FT8'), '+0');
      expect(defaultRSTFor('FT4'), '+0');
    });
  });

  group('rstLengthFor', () {
    test('two on phone, three on CW and the data modes', () {
      expect(rstLengthFor('SSB'), 2);
      expect(rstLengthFor('USB'), 2);
      expect(rstLengthFor('LSB'), 2);
      expect(rstLengthFor('FM'), 2);
      expect(rstLengthFor('CW'), 3);
      expect(rstLengthFor('RTTY'), 3);
      expect(rstLengthFor('PSK31'), 3);
    });

    test('the FT modes have no complete length, so nothing can call one done', () {
      // -9, +05 and -12 are all real reports. Any fixed number here is wrong
      // for some of them: 3 makes a -9 never finish, 2 throws the operator out
      // of a -12 halfway. The setting does not apply, and says so.
      expect(rstLengthFor('FT8'), isNull);
      expect(rstLengthFor('FT4'), isNull);
      expect(rstLengthFor('FT2'), isNull);
    });

    test('it is the FULL report, so the shorthand forms still fit under it', () {
      // The jump-after-RST setting fires at this length. Were it the length of
      // the significant part expandRST completes from, a CW `44` would jump
      // before its aurora `A` and `5N` before `5NN` — both unreachable.
      expect('44'.length, lessThan(rstLengthFor('CW')!));
      expect('5N'.length, lessThan(rstLengthFor('CW')!));
      expect(expandRST('44', 'CW').length, rstLengthFor('CW'));
    });
  });

  group('expandRST', () {
    test('a lone strength digit gains the readability that goes with it', () {
      // Readability is not always 5: a signal at S1-S3 is not fully readable,
      // so a bare 2 means 32 — the point of the expansion is to save typing
      // the digit an operator would have typed anyway, not to guess wrong.
      expect(expandRST('5', 'SSB'), '55');
      expect(expandRST('5', 'USB'), '55');
      expect(expandRST('9', 'SSB'), '59');
      expect(expandRST('4', 'SSB'), '44');
      expect(expandRST('2', 'SSB'), '32');
      expect(expandRST('5', 'CW'), '559');
      expect(expandRST('2', 'CW'), '329');
    });

    test('the tone digit is filled in for CW and RTTY only', () {
      expect(expandRST('57', 'CW'), '579');
      expect(expandRST('57', 'RTTY'), '579');
      // Phone has no tone to report, and no other digital mode claims one
      // here — only the two the operator actually sends a T in.
      expect(expandRST('57', 'SSB'), '57');
      expect(expandRST('57', 'PSK31'), '57');
    });

    test('aurora reports keep their A instead of gaining a tone', () {
      expect(expandRST('A', 'CW'), '59A');
      expect(expandRST('4A', 'CW'), '44A');
      expect(expandRST('34A', 'CW'), '34A');
    });

    test('the FT modes are left entirely alone', () {
      // -12 and +0 are real reports there; every rule above would mangle one.
      expect(expandRST('-12', 'FT8'), '-12');
      expect(expandRST('5', 'FT8'), '5');
      expect(expandRST('-5', 'FT4'), '-5');
    });

    test('a complete report, and an empty field, come back untouched', () {
      expect(expandRST('599', 'CW'), '599');
      expect(expandRST('5NN', 'CW'), '5NN');
      // Empty never becomes a default here — that is defaultRSTFor's job, and
      // conflating them would have a blurred empty field fill itself in.
      expect(expandRST('', 'CW'), '');
      expect(expandRST('', 'SSB'), '');
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

  group('baseCallOf', () {
    test('drops pre- and postindicators', () {
      expect(baseCallOf('ki2d'), 'KI2D');
      expect(baseCallOf('KI2D/P'), 'KI2D');
      expect(baseCallOf('EA4/KI2D'), 'KI2D');
      expect(baseCallOf('VP2E/KI2D/P'), 'KI2D');
      expect(baseCallOf('KI2D/1/QRP'), 'KI2D');
    });

    // A trailing indicator that looks like a prefix is still an indicator:
    // W1AW operating from Hawaii is W1AW, not a station called KH6.
    test('reads a prefix-shaped postindicator as an indicator', () {
      expect(baseCallOf('W1AW/KH6'), 'W1AW');
    });

    // A known limit shared with lib-callsigns' regex: a country suffix that is
    // shaped like a whole call wins the preindicator slot. Pinned so a change
    // here is a decision, not a drift from the parser it mirrors.
    test('reads a call-shaped postindicator as the base', () {
      expect(baseCallOf('W1AW/C6A'), 'C6A');
    });

    test('passes unparseable text through, trimmed and uppercased', () {
      expect(baseCallOf(' 20m '), '20M');
      expect(baseCallOf('K1ABC//W1AW'), 'K1ABC//W1AW');
      expect(baseCallOf(''), '');
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

  group('isLoggableCall', () {
    // An incomplete call must never also read as a callsign: everything that
    // looks a call up, scores it or spots it is gated on [looksLikeCallsign],
    // so one that passed it would send the letters around its `?` out as a
    // station.
    test('a `?` anywhere makes a call incomplete, and loggable, but never a callsign', () {
      for (final call in ['K1A?C', 'W1AW?', '?', '??', 'DL/K1A?C', 'K1A?C/P']) {
        expect(isIncompleteCall(call), isTrue, reason: call);
        expect(isLoggableCall(call), isTrue, reason: call);
        expect(looksLikeCallsign(call), isFalse, reason: call);
      }
    });

    test('without a `?`, only a plausible callsign logs', () {
      expect(isLoggableCall('W1AW'), isTrue);
      expect(isIncompleteCall('W1AW'), isFalse);
      expect(isLoggableCall('1AB'), isFalse, reason: 'a fragment the operator has not marked');
      expect(isLoggableCall(''), isFalse);
    });
  });

  group('sidebands', () {
    test('a frequency answers on its own, with no band table to agree with', () {
      // The rule is a plain split through HF, not a band lookup: below 9 MHz
      // is lower, at or above it is upper, and 5-6 MHz is the 60m exception.
      // So a frequency in a GAP between bands still gets the answer an
      // operator would give, instead of a shrug — which is what a band-table
      // version answered, and what let a stored sideband be silently rewritten
      // on frequencies nothing allocates.
      expect(expectedSideband(freqKHz: 7185), 'LSB');
      expect(expectedSideband(freqKHz: 3800), 'LSB');
      expect(expectedSideband(freqKHz: 1850), 'LSB');
      expect(expectedSideband(freqKHz: 14250), 'USB');
      expect(expectedSideband(freqKHz: 10120), 'USB');
      // 60m: channelized USB by international agreement despite being below
      // 9 MHz, and the one thing a bare "lower below 9 MHz" rule gets wrong.
      expect(expectedSideband(freqKHz: 5357), 'USB');
      expect(expectedSideband(freqKHz: 5000), 'USB');
      expect(expectedSideband(freqKHz: 5999), 'USB');
      // The edges of the 60m window and of the split itself.
      expect(expectedSideband(freqKHz: 4999), 'LSB');
      expect(expectedSideband(freqKHz: 6000), 'LSB');
      expect(expectedSideband(freqKHz: 8999), 'LSB');
      expect(expectedSideband(freqKHz: 9000), 'USB');
      // Outside every allocation is still answerable — that is the point.
      expect(expectedSideband(freqKHz: 5100), 'USB');
      expect(expectedSideband(freqKHz: 10300), 'USB');
      expect(expectedSideband(freqKHz: 2400), 'LSB');
    });

    test('a band answers when there is no frequency, and both spellings count', () {
      // What a manual band pick leaves behind: a band and nothing else.
      expect(expectedSideband(band: '40m'), 'LSB');
      expect(expectedSideband(band: '80m'), 'LSB');
      expect(expectedSideband(band: '20m'), 'USB');
      expect(expectedSideband(band: '60m'), 'USB');
      // The two bands with two names in circulation. A contact carrying the
      // other spelling arrives from an import or a spot feed, and answering
      // upper for it puts the wrong sideband on the air.
      expect(expectedSideband(band: '75m'), 'LSB');
      expect(expectedSideband(band: '2200m'), 'LSB');
      expect(expectedSideband(band: '2190m'), 'LSB');
    });

    test('the frequency outranks the band, and null means neither was stated', () {
      // The frequency is what every display and the export itself show.
      expect(expectedSideband(freqKHz: 7185, band: '20m'), 'LSB');
      // The only null left. It is what tells a writer "nothing to resolve
      // against" and a display "nothing to accuse" — the two callers that must
      // not guess where `resolveSideband` has to.
      expect(expectedSideband(), isNull);
      expect(expectedSideband(band: ''), isNull);
    });

    test('resolveSideband still answers with a sideband where nothing was stated', () {
      // Pins the difference from [expectedSideband] above. A driver has to be
      // told some sideband, so this one cannot answer null. A caller that must
      // not guess checks [expectedSideband] first — the logging panel's
      // `_modeResolvedToSideband` does, and `RadioService.setVfo` guards on its
      // fields, which for this rule is the same test.
      expect(resolveSideband('SSB', null), 'USB');
      // Anything already naming a sideband, or not voice at all, is untouched.
      expect(resolveSideband('SSB', 7185), 'LSB');
      expect(resolveSideband('LSB', 14250), 'LSB');
      expect(resolveSideband('FT8', 7185), 'FT8');
      expect(resolveSideband(null, 7185), isNull);
    });

    test('isUnexpectedSideband fires only on the sideband that place does not run', () {
      expect(isUnexpectedSideband('USB', freqKHz: 7185), isTrue);
      expect(isUnexpectedSideband('LSB', freqKHz: 7185), isFalse);
      expect(isUnexpectedSideband('lsb', freqKHz: 14250), isTrue);
      expect(isUnexpectedSideband('LSB', freqKHz: 5357), isTrue);
      // A generic SSB names no sideband, so it contradicts nothing — without
      // this every phone contact would be flagged red.
      expect(isUnexpectedSideband('SSB', freqKHz: 7185), isFalse);
      expect(isUnexpectedSideband('FT8', freqKHz: 7185), isFalse);
      expect(isUnexpectedSideband(null, freqKHz: 7185), isFalse);
      // Nothing stated, nothing to contradict.
      expect(isUnexpectedSideband('LSB'), isFalse);
    });

    test('displayMode collapses the expected sideband and spells out the other', () {
      // Which sideband you run is a property of where you are, not something
      // the log should repeat on every contact: a list that spells it out
      // reads as two modes where one was worked, and grows a Mode column for a
      // single-mode operation.
      expect(displayMode('USB', freqKHz: 14250), 'SSB');
      expect(displayMode('LSB', freqKHz: 7185), 'SSB');
      expect(displayMode('SSB', freqKHz: 7185), 'SSB');
      expect(displayMode('USB', band: '20m'), 'SSB');
      expect(displayMode('LSB', band: '40m'), 'SSB');
      // The one case worth an operator's attention.
      expect(displayMode('LSB', freqKHz: 14250), 'LSB');
      expect(displayMode('USB', band: '40m'), 'USB');
      // Nothing stated collapses too — the operator is told nothing rather
      // than shown a sideband nobody can vouch for.
      expect(displayMode('LSB'), 'SSB');
      // Never touches a mode that is not voice, and never invents one.
      expect(displayMode('FT8', freqKHz: 7185), 'FT8');
      expect(displayMode(null, freqKHz: 7185), isNull);
    });
  });
}
