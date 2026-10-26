// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The merge contract for `processQsoBeforeSave` patches. A patch arrives from
// an extension, so it can be any shape at all; getting the depth wrong here
// destroys the QSO the operator just logged rather than decorating it.
//
// `owners` are the ref types the patch's extension claims, as the kernel
// reports them, and they are what confine a ref write to that extension's own
// refs. Most of these tests are about what an
// extension must NOT be able to reach.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/qso_patch.dart';

Map<String, dynamic> _qso() => {
  'band': '20m',
  'mode': 'CW',
  'their': {
    'call': 'W1AW',
    'sent': '599',
    'guess': {'name': 'Hiram'},
  },
  'our': {'call': 'N0DEV', 'sent': '599'},
  'refs': [
    {'type': 'cqww', 'theirZone': '5'},
  ],
};

void main() {
  test('a one-field patch to `their` leaves the rest of `their` alone', () {
    // THE case this exists for: a contest returns {their: {exchange: ...}} and
    // a plain shallow merge would take the callsign and the RST with it.
    final merged = mergeQsoPatch(
      _qso(),
      {
        'their': {'exchange': 'ZN5'},
      },
      owners: {'cqww'},
    );

    expect(merged['their'], {
      'call': 'W1AW',
      'sent': '599',
      'guess': {'name': 'Hiram'},
      'exchange': 'ZN5',
    });
  });

  test('`our` merges one level deep too', () {
    final merged = mergeQsoPatch(
      _qso(),
      {
        'our': {'exchange': '001'},
      },
      owners: {'cqww'},
    );
    expect(merged['our'], {'call': 'N0DEV', 'sent': '599', 'exchange': '001'});
  });

  test('a patch cannot rewrite the uuid', () {
    final qso = {..._qso(), 'uuid': 'real'};
    final merged = mergeQsoPatch(qso, {'uuid': 'hijacked', 'notes': 'ok'}, owners: {'cqww'});
    expect(merged['uuid'], 'real');
    expect(merged['notes'], 'ok');
  });

  test('neither input is mutated', () {
    // A call-list batch reuses the same base data for every call, so writing
    // through would leak one station's exchange onto the next.
    final original = _qso();
    final patch = {
      'their': {'exchange': 'ZN5'},
      'refs': [
        {'type': 'cqww', 'theirZone': '14'},
      ],
    };
    final merged = mergeQsoPatch(original, patch, owners: {'cqww'});

    expect((original['their'] as Map).containsKey('exchange'), isFalse);
    expect(((original['refs'] as List).first as Map)['theirZone'], '5');
    expect(patch['refs'], [
      {'type': 'cqww', 'theirZone': '14'},
    ]);
    expect(((merged['refs'] as List).first as Map)['theirZone'], '14');
  });

  test('an empty patch returns the QSO untouched', () {
    final original = _qso();
    expect(identical(mergeQsoPatch(original, {}, owners: {'cqww'}), original), isTrue);
  });

  test('several extensions patch in turn without clobbering each other', () {
    // Two contests on one operation: each projects its own field, and the
    // second must not erase the first.
    var merged = mergeQsoPatch(
      _qso(),
      {
        'their': {'exchange': 'ZN5'},
      },
      owners: {'cqww'},
    );
    merged = mergeQsoPatch(
      merged,
      {
        'their': {'state': 'CT'},
      },
      owners: {'arrl-dx'},
    );
    expect((merged['their'] as Map)['exchange'], 'ZN5');
    expect((merged['their'] as Map)['state'], 'CT');
    expect((merged['their'] as Map)['call'], 'W1AW');
  });

  test('a non-map value where a map is expected replaces rather than throwing', () {
    // Extensions are third-party code; a malformed patch must not crash a save.
    final merged = mergeQsoPatch(_qso(), {'their': 'nonsense'}, owners: {'cqww'});
    expect(merged['their'], 'nonsense');
  });

  group('ref writes', () {
    test('an extension fills a field on its OWN ref', () {
      // The point of allowing this at all: a contest records the zone it fell
      // back to, so the log, the scorer and the export cannot disagree.
      final merged = mergeQsoPatch(
        _qso(),
        {
          'refs': [
            {'type': 'cqww', 'theirZone': '14'},
          ],
        },
        owners: {'cqww'},
      );

      expect(merged['refs'], [
        {'type': 'cqww', 'theirZone': '14'},
      ]);
    });

    test('writing one field leaves the rest of that ref alone', () {
      // The serial the core allocates moments later lives on this same ref, so
      // a whole-ref replacement would destroy it. Field-wise is what makes the
      // write safe.
      final qso = {
        ..._qso(),
        'refs': [
          {'type': 'cqww', 'theirZone': '5', 'serial': 42},
        ],
      };
      final merged = mergeQsoPatch(
        qso,
        {
          'refs': [
            {'type': 'cqww', 'theirExchange': 'ARRL'},
          ],
        },
        owners: {'cqww'},
      );

      expect((merged['refs'] as List).single, {'type': 'cqww', 'theirZone': '5', 'serial': 42, 'theirExchange': 'ARRL'});
    });

    test('an extension cannot touch another activity\'s ref', () {
      // The whole reason ref writes were refused outright before. A contest
      // that names POTA's ref is ignored, not trusted.
      final qso = {
        ..._qso(),
        'refs': [
          {'type': 'cqww', 'theirZone': '5'},
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      };
      final merged = mergeQsoPatch(
        qso,
        {
          'refs': [
            {'type': 'pota', 'ref': 'HIJACKED'},
          ],
        },
        owners: {'cqww'},
      );

      expect(merged['refs'], [
        {'type': 'cqww', 'theirZone': '5'},
        {'type': 'pota', 'ref': 'US-0001'},
      ]);
    });

    test('a patch never removes a ref, even by omitting it', () {
      final qso = {
        ..._qso(),
        'refs': [
          {'type': 'cqww', 'theirZone': '5'},
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      };
      final merged = mergeQsoPatch(
        qso,
        {
          'refs': [
            {'type': 'cqww', 'theirZone': '14'},
          ],
        },
        owners: {'cqww'},
      );

      expect((merged['refs'] as List), hasLength(2));
      expect(((merged['refs'] as List)[1] as Map)['ref'], 'US-0001');
    });

    test('an extension whose ref is absent gets it appended', () {
      // A QSO logged with nothing typed has no contest ref at all yet — the
      // stamped fallback is what creates it.
      final qso = {..._qso(), 'refs': <dynamic>[]};
      final merged = mergeQsoPatch(
        qso,
        {
          'refs': [
            {'type': 'iaru-hf', 'theirExchange': '28'},
          ],
        },
        owners: {'iaru-hf'},
      );

      expect(merged['refs'], [
        {'type': 'iaru-hf', 'theirExchange': '28'},
      ]);
    });

    test('an extension that claims no ref type writes no ref, but still projects into `their`', () {
      // An entry the kernel reports no ref types for has nothing to check a
      // ref against, so its patch reaches `their` and `our` and no ref.
      final merged = mergeQsoPatch(_qso(), {
        'refs': [
          {'type': 'cqww', 'theirZone': '14'},
        ],
        'their': {'exchange': 'ZN5'},
      }, owners: {});

      expect(((merged['refs'] as List).single as Map)['theirZone'], '5');
      expect((merged['their'] as Map)['exchange'], 'ZN5');
    });

    test('an extension owns every ref type it claims, whatever its key', () {
      // A catalog contest's key is not its ref type (`ham2k-cqww` keeps `cqww`
      // refs), and one extension may claim more than one type.
      final qso = {
        ..._qso(),
        'refs': [
          {'type': 'cqww', 'theirZone': '5'},
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      };
      final merged = mergeQsoPatch(
        qso,
        {
          'refs': [
            {'type': 'cqww', 'theirZone': '14'},
            {'type': 'cqwwExtra', 'note': 'x'},
            {'type': 'pota', 'ref': 'HIJACKED'},
          ],
        },
        owners: {'cqww', 'cqwwExtra'},
      );

      expect(merged['refs'], [
        {'type': 'cqww', 'theirZone': '14'},
        {'type': 'pota', 'ref': 'US-0001'},
        {'type': 'cqwwExtra', 'note': 'x'},
      ]);
    });

    test('a malformed refs patch is ignored rather than replacing the list', () {
      final merged = mergeQsoPatch(_qso(), {'refs': 'nonsense'}, owners: {'cqww'});
      expect(merged['refs'], [
        {'type': 'cqww', 'theirZone': '5'},
      ]);

      final noType = mergeQsoPatch(
        _qso(),
        {
          'refs': [
            {'theirZone': '14'},
          ],
        },
        owners: {'cqww'},
      );
      expect(noType['refs'], [
        {'type': 'cqww', 'theirZone': '5'},
      ]);
    });
  });
}
