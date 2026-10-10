// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show bands;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/spot_board.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

Map<String, dynamic> _spot({required String call, double? freq, String? band, String? mode, List<Map<String, dynamic>>? refs, required int timeInMillis}) => {
  'their': {'call': call},
  'freq': ?freq,
  'band': ?band,
  'mode': ?mode,
  'refs': ?refs,
  'spot': {'timeInMillis': timeInMillis, 'source': 'test'},
};

void main() {
  group('mergeSpotsByCallAndFreq', () {
    test('same call, close freq and time merges refs into one spot', () {
      final spots = [
        _spot(
          call: 'K1ABC',
          freq: 14285.0,
          refs: [
            {'type': 'pota', 'ref': 'K-0001'},
          ],
          timeInMillis: 1000,
        ),
        _spot(
          call: 'K1ABC',
          freq: 14285.2,
          refs: [
            {'type': 'pota', 'ref': 'K-0002'},
          ],
          timeInMillis: 2000,
        ),
      ];

      final merged = mergeSpotsByCallAndFreq(spots);

      expect(merged, hasLength(1));
      expect(merged.first['refs'], hasLength(2));
    });

    test('same call, freq just past the 0.5kHz tolerance stays separate', () {
      final spots = [_spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000), _spot(call: 'K1ABC', freq: 14285.51, timeInMillis: 2000)];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(2));
    });

    test('same call, freq just under the 0.5kHz tolerance still merges', () {
      final spots = [_spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000), _spot(call: 'K1ABC', freq: 14285.49, timeInMillis: 2000)];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(1));
    });

    test('same call, just past the 30min tolerance stays separate', () {
      final spots = [_spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 0), _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 30 * 60 * 1000 + 1)];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(2));
    });

    test('same call, exactly at the 30min tolerance still merges', () {
      final spots = [_spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 0), _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 30 * 60 * 1000)];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(1));
    });

    test('different calls never merge', () {
      final spots = [_spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000), _spot(call: 'W1XYZ', freq: 14285.0, timeInMillis: 1000)];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(2));
    });
  });

  group('wrong-typed fields (a bridge-crossing extension enforces nothing about JS field types)', () {
    test('a String freq (the crash this file was named after) degrades to no freq, not a throw', () {
      final spots = [
        {
          'their': {'call': 'K1ABC'},
          'freq': '14285.0', // numeric string, not a num
          'spot': {'timeInMillis': 1000},
        },
        _spot(call: 'W1XYZ', freq: 14285.0, timeInMillis: 1000),
      ];

      final merged = mergeSpotsByFreqAndRefs(mergeSpotsByCallAndFreq(spots));

      // Neither pass crashed, and the malformed spot's own String freq never
      // matches the good one's num freq for merge purposes — the two stay
      // distinct rather than being silently collapsed together.
      expect(merged, hasLength(2));
      expect(merged.map((s) => (s['their'] as Map)['call']), containsAll(['K1ABC', 'W1XYZ']));
    });

    test('a non-Map their field does not throw out of the merge', () {
      final spots = [
        {
          'their': 'K1ABC', // wrong shape entirely
          'freq': 14285.0,
          'spot': {'timeInMillis': 1000},
        },
      ];

      expect(() => mergeSpotsByFreqAndRefs(mergeSpotsByCallAndFreq(spots)), returnsNormally);
    });

    test('a call-less spot already in `merged` is never chosen as a match TARGET either', () {
      // The mirror of the guard above: that one only stops a call-less spot
      // from being the spot BEING merged. Without the matching guard on the
      // `other` side, a later valid spot at the same freq/time/refs matches
      // against the call-less one already sitting in `merged`, producing
      // `existingCall = ''` and a dangling ",W1AW" instead of two rows.
      final spots = [
        {
          'their': <String, dynamic>{}, // present but no call
          'freq': 14285.0,
          'spot': {'timeInMillis': 1000},
        },
        _spot(call: 'W1AW', freq: 14285.05, timeInMillis: 1000),
      ];

      final merged = mergeSpotsByFreqAndRefs(mergeSpotsByCallAndFreq(spots));

      expect(merged, hasLength(2));
      final calls = merged.map((s) => (s['their'] as Map)['call']).toList();
      expect(calls, isNot(contains(',W1AW')));
      expect(calls, contains('W1AW'));
    });

    test('a non-List refs field does not throw and reads as no refs', () {
      final spots = [
        {
          'their': {'call': 'K1ABC'},
          'freq': 14285.0,
          'refs': 'K-0001', // wrong shape entirely
          'spot': {'timeInMillis': 1000},
        },
      ];

      final merged = mergeSpotsByFreqAndRefs(mergeSpotsByCallAndFreq(spots));
      expect(merged.single['refs'], isEmpty);
    });
  });

  group('mergeSpotsByFreqAndRefs', () {
    test('same freq and identical ref set merges callsigns', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 14285.05, mode: 'SSB', refs: refs, timeInMillis: 1500),
      ];

      final merged = mergeSpotsByFreqAndRefs(spots);

      expect(merged, hasLength(1));
      expect((merged.first['their'] as Map)['call'], 'K1ABC,W1XYZ');
    });

    test('different ref sets never merge, even at the same frequency', () {
      final spots = [
        _spot(
          call: 'K1ABC',
          freq: 14285.0,
          mode: 'SSB',
          refs: [
            {'type': 'pota', 'ref': 'K-0001'},
          ],
          timeInMillis: 1000,
        ),
        _spot(
          call: 'W1XYZ',
          freq: 14285.0,
          mode: 'SSB',
          refs: [
            {'type': 'pota', 'ref': 'K-0002'},
          ],
          timeInMillis: 1000,
        ),
      ];

      expect(mergeSpotsByFreqAndRefs(spots), hasLength(2));
    });

    test('digital modes never merge callsigns, even with identical refs and frequency', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spots = [
        _spot(call: 'K1ABC', freq: 14074.0, mode: 'FT8', refs: refs, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 14074.0, mode: 'FT8', refs: refs, timeInMillis: 1000),
      ];

      expect(mergeSpotsByFreqAndRefs(spots), hasLength(2));
    });

    test('just past the 0.1kHz tolerance stays separate', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 14285.11, mode: 'SSB', refs: refs, timeInMillis: 1000),
      ];

      expect(mergeSpotsByFreqAndRefs(spots), hasLength(2));
    });

    test('just under the 0.1kHz tolerance still merges', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 14285.09, mode: 'SSB', refs: refs, timeInMillis: 1000),
      ];

      expect(mergeSpotsByFreqAndRefs(spots), hasLength(1));
    });

    test('just past the 10min tolerance stays separate', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 0),
        _spot(call: 'W1XYZ', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 10 * 60 * 1000 + 1),
      ];

      expect(mergeSpotsByFreqAndRefs(spots), hasLength(2));
    });

    test('exactly at the 10min tolerance still merges', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 0),
        _spot(call: 'W1XYZ', freq: 14285.0, mode: 'SSB', refs: refs, timeInMillis: 10 * 60 * 1000),
      ];

      expect(mergeSpotsByFreqAndRefs(spots), hasLength(1));
    });
  });

  group('sortSpots', () {
    test('"time" sorts most-recent-first', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 7100.0, timeInMillis: 3000),
        _spot(call: 'N1AAA', freq: 21000.0, timeInMillis: 2000),
      ];

      final sorted = sortSpots(spots, 'time');

      expect(sorted.map((s) => (s['their'] as Map)['call']), ['W1XYZ', 'N1AAA', 'K1ABC']);
    });

    test('"frequency" sorts lowest-frequency-first', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 21000.0, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 7100.0, timeInMillis: 1000),
        _spot(call: 'N1AAA', freq: 14285.0, timeInMillis: 1000),
      ];

      final sorted = sortSpots(spots, 'frequency');

      expect(sorted.map((s) => (s['their'] as Map)['call']), ['W1XYZ', 'N1AAA', 'K1ABC']);
    });

    test('a missing frequency sorts as 0, ahead of any real frequency', () {
      final spots = [_spot(call: 'K1ABC', freq: 7100.0, timeInMillis: 1000), _spot(call: 'W1XYZ', timeInMillis: 1000)];

      final sorted = sortSpots(spots, 'frequency');

      expect(sorted.map((s) => (s['their'] as Map)['call']), ['W1XYZ', 'K1ABC']);
    });

    test('does not mutate the input list', () {
      final spots = [_spot(call: 'K1ABC', freq: 21000.0, timeInMillis: 1000), _spot(call: 'W1XYZ', freq: 7100.0, timeInMillis: 1000)];
      final original = [...spots];

      sortSpots(spots, 'frequency');

      expect(spots, original);
    });
  });

  group('sectionSpots', () {
    test('groups spots by band, band-list ordered, unknown band last', () {
      final spots = [
        _spot(call: 'K1ABC', band: '20m', timeInMillis: 1000),
        _spot(call: 'W1XYZ', band: '40m', timeInMillis: 1000),
        _spot(call: 'N1AAA', timeInMillis: 1000), // no band
        _spot(call: 'N2BBB', band: '20m', timeInMillis: 1000),
      ];

      final sections = sectionSpots(spots, callsWithNotes: {});

      expect(sections.map((s) => s.key), ['40m', '20m', '?']);
      expect(sections.firstWhere((s) => s.key == '20m').spots, hasLength(2));
      expect(sections.firstWhere((s) => s.key == '?').spots, hasLength(1));
    });

    test('groupByBand (the default) groups by band, keeping the incoming order within a band', () {
      final spots = [
        _spot(call: 'K1ABC', band: '20m', timeInMillis: 3000),
        _spot(call: 'W1XYZ', band: '40m', timeInMillis: 2000),
        _spot(call: 'N2BBB', band: '20m', timeInMillis: 1000),
      ];

      final sections = sectionSpots(spots, callsWithNotes: {});

      expect(sections.map((s) => s.key), ['40m', '20m']);
      expect(sections.firstWhere((s) => s.key == '20m').spots.map((s) => (s['their'] as Map)['call']), ['K1ABC', 'N2BBB']);
    });

    test('groupByBand: false produces one flat "spots" section, not band groups', () {
      // Band-grouping a most-recent-first list would re-order it (all of one
      // band's spots ahead of a more recent spot on another band), defeating
      // the sort the user picked.
      final spots = [
        _spot(call: 'K1ABC', band: '20m', timeInMillis: 3000),
        _spot(call: 'W1XYZ', band: '40m', timeInMillis: 2000),
        _spot(call: 'N2BBB', band: '20m', timeInMillis: 1000),
      ];

      final sections = sectionSpots(spots, callsWithNotes: {}, groupByBand: false);

      expect(sections.map((s) => s.key), ['spots']);
      expect(sections.single.spots.map((s) => (s['their'] as Map)['call']), ['K1ABC', 'W1XYZ', 'N2BBB']);
    });

    test('groupByBand: false still pins a "notes" section ahead of the flat "spots" section', () {
      final spots = [_spot(call: 'K1ABC', band: '20m', timeInMillis: 2000), _spot(call: 'W1XYZ', band: '40m', timeInMillis: 1000)];

      final sections = sectionSpots(spots, callsWithNotes: {'W1XYZ'}, groupByBand: false);

      expect(sections.map((s) => s.key), ['notes', 'spots']);
    });

    test('groupByBand: false with no spots produces no sections', () {
      expect(sectionSpots([], callsWithNotes: {}, groupByBand: false), isEmpty);
    });

    test('an empty spot list produces no sections', () {
      expect(sectionSpots([], callsWithNotes: {}), isEmpty);
    });

    test('callsWithNotes prepends a "notes" section without removing those spots from their band section', () {
      final spots = [_spot(call: 'K1ABC', band: '20m', timeInMillis: 1000), _spot(call: 'W1XYZ', band: '40m', timeInMillis: 1000)];

      final sections = sectionSpots(spots, callsWithNotes: {'K1ABC'});

      expect(sections.map((s) => s.key), ['notes', '40m', '20m']);
      expect((sections.first.spots.single['their'] as Map)['call'], 'K1ABC');
      // K1ABC is still present in its own band section too — a pinned
      // duplicate, not moved out of the normal grouping.
      expect(sections.firstWhere((s) => s.key == '20m').spots, hasLength(1));
    });

    test('a callsWithNotes entry matching nothing adds no "notes" section', () {
      final spots = [_spot(call: 'K1ABC', band: '20m', timeInMillis: 1000)];

      final sections = sectionSpots(spots, callsWithNotes: {'W1XYZ'});

      expect(sections.map((s) => s.key), ['20m']);
    });

    test('a multi-op spot is pinned when ANY of its operators has a note (#316)', () {
      // A merged multi-op spot's call is the comma-joined compound; the notes
      // set holds individual calls, so pinning must match on any operator.
      final spots = [_spot(call: 'K1ABC,W1XYZ', band: '20m', timeInMillis: 1000)];

      // Note on the SECOND op only — the compound never equals 'W1XYZ'.
      final sections = sectionSpots(spots, callsWithNotes: {'W1XYZ'});

      expect(sections.map((s) => s.key), ['notes', '20m']);
      expect((sections.first.spots.single['their'] as Map)['call'], 'K1ABC,W1XYZ');
    });

    test('selfSpots pin a "self" section ahead of everything, "notes" included', () {
      // The self section is where the operator finds their own announcement to
      // tap back to — anything sorting above it (even the notes pin) buries it.
      final spots = [_spot(call: 'K1ABC', band: '20m', timeInMillis: 1000), _spot(call: 'W1XYZ', band: '40m', timeInMillis: 1000)];
      final self = [_spot(call: 'N0CALL', band: '30m', timeInMillis: 2000)];

      final sections = sectionSpots(spots, selfSpots: self, callsWithNotes: {'K1ABC'});

      expect(sections.map((s) => s.key), ['self', 'notes', '40m', '20m']);
      expect((sections.first.spots.single['their'] as Map)['call'], 'N0CALL');
    });

    test('selfSpots alone still produce their section on an otherwise-empty board', () {
      // The caller passes selfSpots UNfiltered: the filters emptying the rest
      // of the list — a band filter following a wandering VFO — is exactly the
      // moment the pin exists for, so it must not vanish with them.
      final self = [_spot(call: 'N0CALL', band: '20m', timeInMillis: 1000)];

      final sections = sectionSpots([], selfSpots: self, callsWithNotes: {});

      expect(sections.map((s) => s.key), ['self']);
    });
  });

  group('spotIsSelfOnly', () {
    test('a spot for exactly our station is self-only, case-insensitively', () {
      final spot = _spot(call: 'n0call', band: '20m', timeInMillis: 1000);

      expect(spotIsSelfOnly(spot, ourBaseCalls: {'N0CALL'}), isTrue);
    });

    test('a merged multi-op spot that merely includes us is NOT self-only', () {
      // The self affordances (pin, tap-to-retune, no slide-to-log) all key
      // off this answer. Any-of matching here would steal the tap from a
      // row that still carries another workable station.
      final spot = _spot(call: 'W1XYZ,N0CALL', band: '20m', timeInMillis: 1000);

      expect(spotIsSelfOnly(spot, ourBaseCalls: {'N0CALL'}), isFalse);
    });

    // Operating KI2D, a spot of KI2D/P is our own signal: pinning it, and
    // withholding slide-to-log, keeps us from logging ourselves.
    test('a spot of our base call with an indicator is self-only', () {
      expect(
        spotIsSelfOnly(
          _spot(call: 'N0CALL/P', band: '20m', timeInMillis: 1000),
          ourBaseCalls: {'N0CALL'},
        ),
        isTrue,
      );
      expect(
        spotIsSelfOnly(
          _spot(call: 'KH6/N0CALL', band: '20m', timeInMillis: 1000),
          ourBaseCalls: {'N0CALL'},
        ),
        isTrue,
      );
      expect(
        spotIsSelfOnly(
          _spot(call: 'N0CALLS', band: '20m', timeInMillis: 1000),
          ourBaseCalls: {'N0CALL'},
        ),
        isFalse,
      );
    });

    // A multi-call operation owns every one of its calls, so a merged row of
    // two of them is ours alone.
    test('a merged spot of only our station calls is self-only', () {
      final spot = _spot(call: 'N0CALL,W1AW/P', band: '20m', timeInMillis: 1000);

      expect(spotIsSelfOnly(spot, ourBaseCalls: {'N0CALL', 'W1AW'}), isTrue);
    });

    test('no station call, or a call-less spot, is never self-only', () {
      final spot = _spot(call: 'N0CALL', band: '20m', timeInMillis: 1000);

      expect(spotIsSelfOnly(spot), isFalse);
      expect(spotIsSelfOnly({'refs': const <Map<String, dynamic>>[]}, ourBaseCalls: {'N0CALL'}), isFalse);
    });
  });

  group('suggestedQsoFromSpot', () {
    test('extracts call/freq/band/mode/refs into QSON shape', () {
      final refs = [
        {'type': 'pota', 'ref': 'K-0001'},
      ];
      final spot = _spot(call: 'K1ABC', freq: 14285.0, band: '20m', mode: 'SSB', refs: refs, timeInMillis: 1000);

      final suggested = suggestedQsoFromSpot(spot);

      expect(suggested, {
        'their': {'call': 'K1ABC'},
        'freq': 14285.0,
        'band': '20m',
        'mode': 'SSB',
        'refs': refs,
      });
    });

    test('omits freq/band/mode when the spot has none, but always includes refs', () {
      final spot = _spot(call: 'K1ABC', timeInMillis: 1000);

      final suggested = suggestedQsoFromSpot(spot);

      expect(suggested, {
        'their': {'call': 'K1ABC'},
        'refs': const [],
      });
    });

    test('never carries spot-only metadata (icon, spot.*) into the suggestion', () {
      final spot = {..._spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000), 'icon': 'pine-tree'};

      final suggested = suggestedQsoFromSpot(spot);

      expect(suggested.containsKey('icon'), isFalse);
      expect(suggested.containsKey('spot'), isFalse);
    });
  });

  group('filter pill labels', () {
    final t = AppLocale.en.buildSync();

    test('auto leads with the resolved band/mode and tags it, so "20m (Auto)" not "Auto (20m)"', () {
      expect(spotsFilterBandPillLabel(t, 'auto', '20m'), '20m (Auto)');
      expect(spotsFilterModePillLabel(t, 'auto', 'Phone'), 'Phone (Auto)');
    });

    test('auto with no resolved band/mode falls back to all-bands/modes, not "Auto"', () {
      expect(spotsFilterBandPillLabel(t, 'auto', null), t.operation.spots.allBands);
      expect(spotsFilterModePillLabel(t, 'auto', null), t.operation.spots.allModes);
    });

    test('explicit band/mode selections pass through unchanged', () {
      expect(spotsFilterBandPillLabel(t, '40m', '20m'), '40m');
      expect(spotsFilterModePillLabel(t, 'CW', 'SSB'), 'CW');
    });

    test('"any" keeps the all-bands/all-modes label', () {
      expect(spotsFilterBandPillLabel(t, 'any', '20m'), t.operation.spots.allBands);
      expect(spotsFilterModePillLabel(t, 'any', 'Phone'), t.operation.spots.allModes);
    });

    test('the Phone & CW option shows its own label, not the raw filter value', () {
      expect(spotsFilterModePillLabel(t, phoneCwModeFilter, 'Phone'), t.operation.spots.phoneAndCw);
    });
  });

  group('normalizeModeFilter', () {
    test('super-mode and auto/any values pass through', () {
      for (final v in ['auto', 'any', 'Phone', 'CW', 'Digital', phoneCwModeFilter]) {
        expect(normalizeModeFilter(v), v);
      }
    });

    test('a stale individual mode maps to its super mode', () {
      expect(normalizeModeFilter('SSB'), 'Phone');
      expect(normalizeModeFilter('FT8'), 'Digital');
    });

    test('the retired "notDigital" becomes the Phone & CW option, which means the same thing', () {
      expect(normalizeModeFilter('notDigital'), phoneCwModeFilter);
    });
  });

  group('superModesForModeFilter', () {
    test('Phone & CW admits both and nothing else, so a Digital spot is out', () {
      final admitted = superModesForModeFilter(phoneCwModeFilter, 'FT8')!;
      expect(admitted, containsAll(['Phone', 'CW']));
      expect(admitted, isNot(contains('Digital')));
    });

    test('auto follows the VFO super mode, and stops narrowing when the VFO has none', () {
      expect(superModesForModeFilter('auto', 'USB'), {'Phone'});
      expect(superModesForModeFilter('auto', null), isNull);
    });

    test('any never narrows; a super mode admits only itself', () {
      expect(superModesForModeFilter('any', 'CW'), isNull);
      expect(superModesForModeFilter('CW', 'USB'), {'CW'});
    });
  });

  group('defaultGroupByBand', () {
    test('time sort defaults to ungrouped, matching the pre-groupByBand shape', () {
      expect(defaultGroupByBand('time'), isFalse);
    });

    test('frequency sort (and anything else) defaults to grouped', () {
      expect(defaultGroupByBand('frequency'), isTrue);
      expect(defaultGroupByBand('anything-else'), isTrue);
    });
  });

  group('spotPassesContinentFilter (#316)', () {
    // Resolver from a per-call continent map, mirroring _callNotes.
    String? Function(String) continentOf(Map<String, String?> byCall) =>
        (c) => byCall[c];
    final continents = continentOf({'K1ABC': 'NA', 'W1XYZ': 'NA', 'DL1ABC': 'EU', 'JA1ABC': 'AS'});

    test('single-op spot on a disabled continent is hidden', () {
      expect(spotPassesContinentFilter('DL1ABC', {'EU'}, continents), isFalse);
    });

    test('single-op spot on an enabled continent passes', () {
      expect(spotPassesContinentFilter('K1ABC', {'EU'}, continents), isTrue);
    });

    test('a call with an unresolved continent always passes (never hidden by the filter)', () {
      expect(spotPassesContinentFilter('UNKNOWN', {'EU'}, continents), isTrue);
    });

    test('empty disabled set never narrows', () {
      expect(spotPassesContinentFilter('DL1ABC', const {}, continents), isTrue);
    });

    // The #316 regression: a multi-op spot's their.call is the comma-joined
    // compound; the old code looked the whole string up in the per-call map,
    // always missed, and let every multi-op spot bypass the filter.
    test('multi-op spot where EVERY operator is on a disabled continent is hidden', () {
      expect(spotPassesContinentFilter('DL1ABC,DL1ABC', {'EU'}, continents), isFalse);
    });

    test('multi-op spot passes when ANY operator is on an enabled continent', () {
      // DL1ABC (EU, disabled) + K1ABC (NA, enabled) — the NA op is workable, keep it.
      expect(spotPassesContinentFilter('DL1ABC,K1ABC', {'EU'}, continents), isTrue);
    });

    test('multi-op spot passes when any operator\'s continent is still unresolved', () {
      expect(spotPassesContinentFilter('DL1ABC,UNKNOWN', {'EU'}, continents), isTrue);
    });

    test('multi-op spot hidden only when all its disabled-continent ops are known', () {
      // Both ops on disabled continents (EU + AS both disabled) → hidden.
      expect(spotPassesContinentFilter('DL1ABC,JA1ABC', {'EU', 'AS'}, continents), isFalse);
      // Same spot but AS re-enabled → the JA op is workable → passes.
      expect(spotPassesContinentFilter('DL1ABC,JA1ABC', {'EU'}, continents), isTrue);
    });

    test('a call-less spot passes', () {
      expect(spotPassesContinentFilter('', {'EU'}, continents), isTrue);
      expect(spotPassesContinentFilter(null, {'EU'}, continents), isTrue);
    });
  });

  group('spotsOnEnabledBands', () {
    List<Map<String, dynamic>> spotsOn(List<String?> bandList) => [for (final band in bandList) _spot(call: 'K1ABC', band: band, timeInMillis: 1000)];
    List<String?> bandsOf(List<Map<String, dynamic>> spots) => [for (final s in spots) s['band'] as String?];

    // The operator configured 40m and 20m; a 15m spot is not theirs to work,
    // so it has no business in the list when no band is chosen.
    test('drops spots on bands the operator has not enabled', () {
      expect(bandsOf(spotsOnEnabledBands(spotsOn(['40m', '15m', '20m']), {'40m', '20m'})), ['40m', '20m']);
    });

    // Fail-open, both directions: deselecting every band in Settings must not
    // blank the panel, and a spot the source never gave a band cannot be
    // attributed to a band the operator disabled.
    test('an empty enabled list narrows nothing', () {
      expect(bandsOf(spotsOnEnabledBands(spotsOn(['40m', '15m']), {})), ['40m', '15m']);
    });

    test('a spot with no band survives the narrowing', () {
      expect(bandsOf(spotsOnEnabledBands(spotsOn(['15m', null]), {'40m'})), [null]);
    });
  });

  group('spotsFilterBandOptions', () {
    // The dropdown is the settings list first: this is the whole bug report —
    // 40m/20m enabled, 19 bands offered.
    test('offers the enabled bands, not the whole band table', () {
      expect(spotsFilterBandOptions(enabledBands: {'40m', '20m'}, bandSpotCounts: {}, selected: 'auto'), ['40m', '20m']);
    });

    // Spots on a non-enabled band still reach the screen under an explicit
    // pick, so the band must remain selectable or those spots are unfilterable.
    test('adds a non-enabled band that currently has spots', () {
      expect(spotsFilterBandOptions(enabledBands: {'40m'}, bandSpotCounts: {'15m': 3}, selected: 'auto'), ['40m', '15m']);
    });

    test('a non-enabled band with zero spots stays out', () {
      expect(spotsFilterBandOptions(enabledBands: {'40m'}, bandSpotCounts: {'15m': 0}, selected: 'auto'), ['40m']);
    });

    // A filter persisted before its band was disabled: dropping it would leave
    // the dropdown showing something other than what is actually filtering.
    test('keeps the selected band even when disabled and spotless', () {
      expect(spotsFilterBandOptions(enabledBands: {'40m'}, bandSpotCounts: {}, selected: '15m'), ['40m', '15m']);
    });

    test('orders options by the band table, not by how they qualified', () {
      expect(spotsFilterBandOptions(enabledBands: {'10m', '80m'}, bandSpotCounts: {'160m': 2}, selected: '40m'), ['160m', '80m', '40m', '10m']);
    });

    test('an empty enabled list offers every band', () {
      expect(spotsFilterBandOptions(enabledBands: {}, bandSpotCounts: {}, selected: 'auto'), hasLength(bands.length));
    });
  });

  group('spotsFilterSourceList', () {
    test('lists a source that offered no spots because it was in trouble', () {
      // The sharp end of the bug: a source that times out or errors has no
      // key in spotsBySource at all, so listing only those keys erases it
      // from the filter — the operator cannot see it was even consulted, and
      // reads a board missing every SOTA spot as a quiet afternoon.
      expect(spotsFilterSourceList(installed: const [], withSpots: ['pota'], unavailable: ['sota'], failed: ['wwbota']), ['pota', 'sota', 'wwbota']);
    });

    test('a source named in two of the inputs appears once', () {
      // The three arguments are independent lists from a caller's point of
      // view — nothing in the signature stops them overlapping — so the
      // dedupe is the function's own guarantee, not a property inherited
      // from how SpotsService happens to populate them today.
      expect(spotsFilterSourceList(installed: const [], withSpots: ['pota', 'sota'], unavailable: ['sota'], failed: const []), ['pota', 'sota']);
    });

    test('lists an installed source that offered nothing', () {
      // An idle source (QSO Party Spots between party weekends) answers with
      // an empty list and so has no key in spotsBySource; without the
      // installed list it has no row, and the operator cannot tell it is
      // installed or turn it off before it starts spotting.
      expect(spotsFilterSourceList(installed: ['qp', 'pota'], withSpots: ['pota'], unavailable: const [], failed: const []), ['pota', 'qp']);
    });

    test('lists a source with spots that the name lookup missed', () {
      // The source names come from one lookup at panel open; a source that
      // starts offering spots afterwards must still get a row to toggle.
      expect(spotsFilterSourceList(installed: ['pota'], withSpots: ['sota', 'pota'], unavailable: const [], failed: const []), ['pota', 'sota']);
    });
  });
}
