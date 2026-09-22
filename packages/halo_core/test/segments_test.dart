// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Segment resolution (docs/design/contests.md §5.1.3). Everything downstream —
// which scorers run, what operation a scorer sees per QSO, which QSOs an export
// gets, whether the entry row shows a contest's exchange — trusts these rules,
// so they are pinned here rather than inferred from the consumers.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

Qso _qso(int atMillis, {String call = 'W1AW'}) => Qso(
  uuid: 'q$atMillis',
  operationUuid: 'op',
  data: {
    'startAtMillis': atMillis,
    'band': '20m',
    'mode': 'CW',
    'their': {'call': call},
  },
);

Qso _event(int atMillis, String kind, {Map<String, dynamic>? operation, bool deleted = false}) => Qso(
  uuid: 'e$atMillis',
  operationUuid: 'op',
  deleted: deleted,
  data: {
    'startAtMillis': atMillis,
    'band': 'event',
    'event': {'event': kind, 'operation': ?operation},
  },
);

Map<String, dynamic> _base() => {
  'stationCall': 'N0DEV',
  'grid': 'FN31pr',
  'refs': [
    {'type': 'pota', 'ref': 'US-0001'},
  ],
};

Set<String> _refTypes(Map<String, dynamic> operation) => {for (final ref in (operation['refs'] as List).cast<Map<String, dynamic>>()) ref['type'] as String};

void main() {
  test('an operation with no events is one segment covering everything', () {
    final s = SegmentedOperation.from(operation: _base(), qsos: [_qso(100), _qso(200)]);
    expect(s.isSegmented, isFalse);
    expect(s.effectiveAt(100), _base());
    expect(s.effectiveAt(999999), _base());
    // A QSO with no timestamp still resolves rather than throwing.
    expect(s.effectiveAt(null), _base());
  });

  test('a break replaces refs outright — it does not union with the base', () {
    // "I moved to a second park" and "I am now at two parks" are different
    // claims; the segment states which, and nothing merges them back together.
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _qso(100),
        _event(
          200,
          'break',
          operation: {
            'refs': [
              {'type': 'pota', 'ref': 'US-0002'},
            ],
          },
        ),
        _qso(300),
      ],
    );

    expect((s.effectiveAt(100)['refs'] as List).single['ref'], 'US-0001');
    expect((s.effectiveAt(300)['refs'] as List), hasLength(1));
    expect((s.effectiveAt(300)['refs'] as List).single['ref'], 'US-0002');
  });

  test('an attribute a segment does not name falls back to the BASE', () {
    // The base operation is the default that lets an unsegmented log skip
    // segments entirely — not an accumulator.
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(200, 'break', operation: {'grid': 'FN32aa'}),
      ],
    );
    expect(s.effectiveAt(300)['grid'], 'FN32aa');
    expect(s.effectiveAt(300)['stationCall'], 'N0DEV');
    expect((s.effectiveAt(300)['refs'] as List).single['ref'], 'US-0001');
  });

  test('segments do NOT carry forward from one another', () {
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(200, 'break', operation: {'grid': 'FN32aa'}),
        _event(
          400,
          'break',
          operation: {
            'refs': [
              {'type': 'cqww'},
            ],
          },
        ),
      ],
    );
    // Segment one set a grid; segment two never mentions it, so it reverts to
    // the BASE grid rather than inheriting FN32aa. Anything a user wants to
    // persist across segments is written into each of them by whatever creates
    // them — only the user knows "I moved" from "I am now at both".
    expect(s.effectiveAt(300)['grid'], 'FN32aa');
    expect(s.effectiveAt(500)['grid'], 'FN31pr', reason: 'base, not segment one');
    expect(_refTypes(s.effectiveAt(500)), {'cqww'});
  });

  test('a QSO sharing a timestamp with the break belongs to the new segment', () {
    // The break is logged when the operator stops, so anything at that instant
    // is on the far side of it.
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(
          200,
          'break',
          operation: {
            'refs': [
              {'type': 'pota', 'ref': 'US-0002'},
            ],
          },
        ),
      ],
    );
    expect((s.effectiveAt(199)['refs'] as List).single['ref'], 'US-0001');
    expect((s.effectiveAt(200)['refs'] as List).single['ref'], 'US-0002');
  });

  test('out-of-order input still produces an ordered timeline', () {
    // The caller's list may be filtered or reordered; boundaries must be right
    // regardless.
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(400, 'break', operation: {'grid': 'SECOND'}),
        _event(200, 'break', operation: {'grid': 'FIRST'}),
      ],
    );
    expect(s.effectiveAt(300)['grid'], 'FIRST');
    expect(s.effectiveAt(500)['grid'], 'SECOND');
  });

  test('an `end` event is not a segment boundary', () {
    // It closes the operation and carries no override; treating it as a
    // boundary would strand anything logged after it with no refs at all.
    final s = SegmentedOperation.from(operation: _base(), qsos: [_event(200, 'end')]);
    expect(s.isSegmented, isFalse);
    expect((s.effectiveAt(300)['refs'] as List).single['ref'], 'US-0001');
  });

  test('a soft-deleted break stops defining a segment', () {
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(
          200,
          'break',
          deleted: true,
          operation: {
            'refs': [
              {'type': 'pota', 'ref': 'US-0002'},
            ],
          },
        ),
      ],
    );
    expect(s.isSegmented, isFalse);
    expect((s.effectiveAt(300)['refs'] as List).single['ref'], 'US-0001');
  });

  test('a break with no override payload is not a boundary', () {
    // `addEvent` without an override is the ordinary "I stopped for lunch"
    // marker and changes nothing about the operation.
    final s = SegmentedOperation.from(operation: _base(), qsos: [_event(200, 'break')]);
    expect(s.isSegmented, isFalse);
  });

  test('current is the last segment, so the entry row follows the log', () {
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(
          200,
          'break',
          operation: {
            'refs': [
              {'type': 'cqww'},
            ],
          },
        ),
      ],
    );
    expect(_refTypes(s.current), {'cqww'});
  });

  test('allRefTypes spans every segment, so a late contest still gets scored', () {
    // A scorer selected from the base operation alone would never run for a
    // contest that only covers the back half of the log.
    final s = SegmentedOperation.from(
      operation: _base(),
      qsos: [
        _event(
          200,
          'break',
          operation: {
            'refs': [
              {'type': 'cqww'},
            ],
          },
        ),
      ],
    );
    expect(s.allRefTypes, {'pota', 'cqww'});
  });

  group('export segmentation', () {
    // The motivating case: a contest throughout, two parks, and a stretch in
    // the middle at neither.
    late SegmentedOperation segmented;
    late List<Qso> qsos;

    setUp(() {
      qsos = [_qso(100), _qso(300), _qso(500)];
      segmented = SegmentedOperation.from(
        operation: {
          'stationCall': 'N0DEV',
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
            {'type': 'cqww'},
          ],
        },
        qsos: [
          ...qsos,
          // Left the park, still in the contest.
          _event(
            200,
            'break',
            operation: {
              'refs': [
                {'type': 'cqww'},
              ],
            },
          ),
          // Arrived at the second park.
          _event(
            400,
            'break',
            operation: {
              'refs': [
                {'type': 'pota', 'ref': 'US-0002'},
                {'type': 'cqww'},
              ],
            },
          ),
        ],
      );
    });

    test('each park gets its own export slice, not both parks lumped together', () {
      // An activity with multiple references produces one submission per
      // reference — so US-0001's export must not contain US-0002's QSOs, even
      // though both are POTA.
      final parkOne = {'type': 'pota', 'ref': 'US-0001'};
      final parkTwo = {'type': 'pota', 'ref': 'US-0002'};

      expect(segmented.qsosFor(qsos, parkOne).map((q) => q.startAtMillis), [100]);
      expect(segmented.qsosFor(qsos, parkTwo).map((q) => q.startAtMillis), [500]);
    });

    test('the contest reference covers the whole log, since every segment carries it', () {
      expect(segmented.qsosFor(qsos, {'type': 'cqww'}).map((q) => q.startAtMillis), [100, 300, 500]);
    });

    test('a reference present in no segment gets nothing', () {
      expect(segmented.qsosFor(qsos, {'type': 'pota', 'ref': 'US-9999'}), isEmpty);
    });

    test('allRefs is one entry per reference, deduped across segments', () {
      // cqww appears in all three segments and must be offered once.
      expect(segmented.allRefs.map((r) => '${r['type']}/${r['ref']}').toList()..sort(), ['cqww/null', 'pota/US-0001', 'pota/US-0002']);
    });

    test('on an unsegmented operation a reference takes the whole log', () {
      final plain = SegmentedOperation.from(operation: _base(), qsos: qsos);
      expect(plain.qsosFor(qsos, {'type': 'pota', 'ref': 'US-0001'}), hasLength(3));
      expect(plain.qsosFor(qsos, {'type': 'cqww'}), isEmpty);
    });
  });
}
