// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

Map<String, dynamic> _spot({
  required String call,
  double? freq,
  String? band,
  String? mode,
  List<Map<String, dynamic>>? refs,
  required int timeInMillis,
}) =>
    {
      'their': {'call': call},
      if (freq != null) 'freq': freq,
      if (band != null) 'band': band,
      if (mode != null) 'mode': mode,
      if (refs != null) 'refs': refs,
      'spot': {'timeInMillis': timeInMillis, 'source': 'test'},
    };

void main() {
  group('mergeSpotsByCallAndFreq', () {
    test('same call, close freq and time merges refs into one spot', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, refs: [
          {'type': 'pota', 'ref': 'K-0001'},
        ], timeInMillis: 1000),
        _spot(call: 'K1ABC', freq: 14285.2, refs: [
          {'type': 'pota', 'ref': 'K-0002'},
        ], timeInMillis: 2000),
      ];

      final merged = mergeSpotsByCallAndFreq(spots);

      expect(merged, hasLength(1));
      expect(merged.first['refs'], hasLength(2));
    });

    test('same call, freq just past the 0.5kHz tolerance stays separate', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000),
        _spot(call: 'K1ABC', freq: 14285.51, timeInMillis: 2000),
      ];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(2));
    });

    test('same call, freq just under the 0.5kHz tolerance still merges', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000),
        _spot(call: 'K1ABC', freq: 14285.49, timeInMillis: 2000),
      ];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(1));
    });

    test('same call, just past the 30min tolerance stays separate', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 0),
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 30 * 60 * 1000 + 1),
      ];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(2));
    });

    test('same call, exactly at the 30min tolerance still merges', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 0),
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 30 * 60 * 1000),
      ];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(1));
    });

    test('different calls never merge', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 14285.0, timeInMillis: 1000),
      ];

      expect(mergeSpotsByCallAndFreq(spots), hasLength(2));
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
        _spot(call: 'K1ABC', freq: 14285.0, mode: 'SSB', refs: [
          {'type': 'pota', 'ref': 'K-0001'},
        ], timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 14285.0, mode: 'SSB', refs: [
          {'type': 'pota', 'ref': 'K-0002'},
        ], timeInMillis: 1000),
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
      final spots = [
        _spot(call: 'K1ABC', freq: 7100.0, timeInMillis: 1000),
        _spot(call: 'W1XYZ', timeInMillis: 1000),
      ];

      final sorted = sortSpots(spots, 'frequency');

      expect(sorted.map((s) => (s['their'] as Map)['call']), ['W1XYZ', 'K1ABC']);
    });

    test('does not mutate the input list', () {
      final spots = [
        _spot(call: 'K1ABC', freq: 21000.0, timeInMillis: 1000),
        _spot(call: 'W1XYZ', freq: 7100.0, timeInMillis: 1000),
      ];
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

    test('always groups by band — even age-sorted spots — keeping the incoming order within a band', () {
      // What the panel feeds in when sorting by age: a single most-recent-first
      // list. It must still come out grouped by band (not one flat section),
      // with that age order preserved inside each band.
      final spots = [
        _spot(call: 'K1ABC', band: '20m', timeInMillis: 3000),
        _spot(call: 'W1XYZ', band: '40m', timeInMillis: 2000),
        _spot(call: 'N2BBB', band: '20m', timeInMillis: 1000),
      ];

      final sections = sectionSpots(spots, callsWithNotes: {});

      expect(sections.map((s) => s.key), ['40m', '20m']);
      expect(
        sections.firstWhere((s) => s.key == '20m').spots.map((s) => (s['their'] as Map)['call']),
        ['K1ABC', 'N2BBB'],
      );
    });

    test('an empty spot list produces no sections', () {
      expect(sectionSpots([], callsWithNotes: {}), isEmpty);
    });

    test('callsWithNotes prepends a "notes" section without removing those spots from their band section', () {
      final spots = [
        _spot(call: 'K1ABC', band: '20m', timeInMillis: 1000),
        _spot(call: 'W1XYZ', band: '40m', timeInMillis: 1000),
      ];

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
      final spot = {
        ..._spot(call: 'K1ABC', freq: 14285.0, timeInMillis: 1000),
        'icon': 'pine-tree',
      };

      final suggested = suggestedQsoFromSpot(spot);

      expect(suggested.containsKey('icon'), isFalse);
      expect(suggested.containsKey('spot'), isFalse);
    });
  });

  group('filter pill labels', () {
    final t = AppLocale.en.buildSync();

    test('auto shows only the resolved band/mode, never "Auto"', () {
      expect(spotsFilterBandPillLabel(t, 'auto', '20m'), '20m');
      expect(spotsFilterModePillLabel(t, 'auto', 'SSB'), 'SSB');
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
  });

  group('normalizeModeFilter', () {
    test('super-mode and auto/any values pass through', () {
      for (final v in ['auto', 'any', 'Phone', 'CW', 'Digital']) {
        expect(normalizeModeFilter(v), v);
      }
    });

    test('a stale individual mode maps to its super mode', () {
      expect(normalizeModeFilter('SSB'), 'Phone');
      expect(normalizeModeFilter('FT8'), 'Digital');
    });

    test('the retired "notDigital" resets to auto (it spanned two super modes)', () {
      expect(normalizeModeFilter('notDigital'), 'auto');
    });
  });
}
