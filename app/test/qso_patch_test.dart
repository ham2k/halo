// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The merge contract for `processQsoBeforeSave` patches. A patch arrives from
// an extension, so it can be any shape at all; getting the depth wrong here
// destroys the QSO the operator just logged rather than decorating it.

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
    final merged = mergeQsoPatch(_qso(), {
      'their': {'exchange': 'ZN5'},
    });

    expect(merged['their'], {
      'call': 'W1AW',
      'sent': '599',
      'guess': {'name': 'Hiram'},
      'exchange': 'ZN5',
    });
  });

  test('`our` merges one level deep too', () {
    final merged = mergeQsoPatch(_qso(), {
      'our': {'exchange': '001'},
    });
    expect(merged['our'], {'call': 'N0DEV', 'sent': '599', 'exchange': '001'});
  });

  test('a patch cannot rewrite refs', () {
    // refs are shared: the core is about to allocate a serial onto one, and
    // another activity may own a second. A hook projects OUT of its ref; it
    // does not get to reshape the list.
    final merged = mergeQsoPatch(_qso(), {
      'refs': [
        {'type': 'evil'},
      ],
      'their': {'exchange': 'ZN5'},
    });
    expect(merged['refs'], [
      {'type': 'cqww', 'theirZone': '5'},
    ]);
    expect((merged['their'] as Map)['exchange'], 'ZN5');
  });

  test('a patch cannot rewrite the uuid', () {
    final qso = {..._qso(), 'uuid': 'real'};
    final merged = mergeQsoPatch(qso, {'uuid': 'hijacked', 'notes': 'ok'});
    expect(merged['uuid'], 'real');
    expect(merged['notes'], 'ok');
  });

  test('neither input is mutated', () {
    // A call-list batch reuses the same base data for every call, so writing
    // through would leak one station's exchange onto the next.
    final original = _qso();
    final patch = {
      'their': {'exchange': 'ZN5'},
    };
    final merged = mergeQsoPatch(original, patch);

    expect((original['their'] as Map).containsKey('exchange'), isFalse);
    expect(patch, {
      'their': {'exchange': 'ZN5'},
    });
    expect((merged['their'] as Map)['exchange'], 'ZN5');
  });

  test('an empty patch returns the QSO untouched', () {
    final original = _qso();
    expect(identical(mergeQsoPatch(original, {}), original), isTrue);
  });

  test('several extensions patch in turn without clobbering each other', () {
    // Two contests on one operation: each projects its own field, and the
    // second must not erase the first.
    var merged = mergeQsoPatch(_qso(), {
      'their': {'exchange': 'ZN5'},
    });
    merged = mergeQsoPatch(merged, {
      'their': {'state': 'CT'},
    });
    expect((merged['their'] as Map)['exchange'], 'ZN5');
    expect((merged['their'] as Map)['state'], 'CT');
    expect((merged['their'] as Map)['call'], 'W1AW');
  });

  test('a non-map value where a map is expected replaces rather than throwing', () {
    // Extensions are third-party code; a malformed patch must not crash a save.
    final merged = mergeQsoPatch(_qso(), {'their': 'nonsense'});
    expect(merged['their'], 'nonsense');
  });
}
