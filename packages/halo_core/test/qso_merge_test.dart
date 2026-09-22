// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every case here is a way two records of one contact can differ, or a way two
// records of DIFFERENT contacts can look alike. Getting the second kind wrong
// silently welds two contacts together and loses one.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

int _at(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

Map<String, dynamic> _qso({
  String their = 'W1AW',
  String our = 'N0DEV',
  String band = '20m',
  String mode = 'SSB',
  String at = '2024-07-23T12:00:00Z',
  Map<String, dynamic>? theirExtra,
  Map<String, dynamic>? extra,
}) => {
  'our': {'call': our},
  'their': {'call': their, ...?theirExtra},
  'band': band,
  'mode': mode,
  'startAtMillis': _at(at),
  ...?extra,
};

void main() {
  group('qsosAreSameContact', () {
    test('the same contact logged twice, minutes apart, matches', () {
      expect(qsosAreSameContact(_qso(at: '2024-07-23T12:00:00Z'), _qso(at: '2024-07-23T12:04:30Z')), isTrue);
    });

    test('the window slides, it does not bucket', () {
      // app-polo rounds into fixed 5-minute buckets, so these two land either
      // side of 12:05 and never match — while 12:00 and 12:04 do. Two minutes
      // apart is one contact under any reading.
      expect(qsosAreSameContact(_qso(at: '2024-07-23T12:04:00Z'), _qso(at: '2024-07-23T12:06:00Z')), isTrue);
    });

    test('beyond five minutes is a different contact', () {
      expect(qsosAreSameContact(_qso(at: '2024-07-23T12:00:00Z'), _qso(at: '2024-07-23T12:05:01Z')), isFalse);
    });

    test('the sideband spellings are one mode', () {
      // SSB/USB/LSB name the same emission; which one a logger writes is its
      // own convention.
      expect(qsosAreSameContact(_qso(mode: 'SSB'), _qso(mode: 'USB')), isTrue);
      expect(qsosAreSameContact(_qso(mode: 'USB'), _qso(mode: 'LSB')), isTrue);
      expect(qsosAreSameContact(_qso(mode: 'ssb'), _qso(mode: 'USB')), isTrue);
    });

    test('every other mode stands on its own', () {
      // Bucketing by super mode would make each of these one contact and lose
      // one of the pair — they are separate contacts for award and contest
      // credit. FT8 vs RTTY is the case that matters most: both are "Digital".
      expect(qsosAreSameContact(_qso(mode: 'FT8'), _qso(mode: 'RTTY')), isFalse);
      expect(qsosAreSameContact(_qso(mode: 'FT8'), _qso(mode: 'FT4')), isFalse);
      expect(qsosAreSameContact(_qso(mode: 'SSB'), _qso(mode: 'AM')), isFalse);
      expect(qsosAreSameContact(_qso(mode: 'SSB'), _qso(mode: 'FM')), isFalse);
      expect(qsosAreSameContact(_qso(mode: 'SSB'), _qso(mode: 'CW')), isFalse);
    });

    test('an unrecognized mode matches only itself', () {
      // Under super-mode bucketing anything unknown reads as Digital and so
      // matches every digital record.
      expect(qsosAreSameContact(_qso(mode: 'WHAT'), _qso(mode: 'FT8')), isFalse);
      expect(qsosAreSameContact(_qso(mode: 'WHAT'), _qso(mode: 'WHAT')), isTrue);
    });

    test('a different station, or a different band, is a different contact', () {
      expect(qsosAreSameContact(_qso(their: 'W1AW'), _qso(their: 'K1ABC')), isFalse);
      expect(qsosAreSameContact(_qso(band: '20m'), _qso(band: '40m')), isFalse);
    });

    test('two operators who both worked it keep their own records', () {
      expect(qsosAreSameContact(_qso(our: 'N0DEV'), _qso(our: 'N0XYZ')), isFalse);
    });

    test('a missing our.call is a wildcard, not a mismatch', () {
      // Club Log's export carries no STATION_CALLSIGN at all. Comparing absent
      // as empty would stop such a file merging with anything.
      final clublog = _qso()..remove('our');

      expect(qsosAreSameContact(_qso(our: 'N0DEV'), clublog), isTrue);
    });

    test('a record with no mode matches nothing', () {
      // Merging on a blank would fold every mode-less contact into the first
      // one that happened to share a call and a band.
      final modeless = _qso()..remove('mode');

      expect(qsosAreSameContact(_qso(), modeless), isFalse);
      expect(qsosAreSameContact(modeless, modeless), isFalse);
    });

    test('a record with no timestamp matches nothing', () {
      final undated = _qso()..remove('startAtMillis');

      expect(qsosAreSameContact(_qso(), undated), isFalse);
    });
  });

  group('imposing a station call', () {
    test('takes our.call out of the match', () {
      // An importer about to rewrite every record to one station cannot also
      // treat the call it is discarding as a difference.
      expect(qsosAreSameContact(_qso(our: 'W1AW/P'), _qso(our: 'KI2D')), isFalse);
      expect(
        qsosAreSameContact(
          _qso(our: 'W1AW/P'),
          _qso(our: 'KI2D'),
          stationCall: 'KI2D',
        ),
        isTrue,
      );
    });

    test('the merged record belongs to the imposed station', () {
      final merged = mergeQsos(
        _qso(our: 'KI2D'),
        _qso(our: 'W1AW/P'),
        stationCall: 'KI2D',
      );

      expect((merged['our'] as Map)['call'], 'KI2D');
    });

    test('qsoForStation replaces the call and keeps the rest of `our`', () {
      // Who was at the key is a different fact from which callsign went out.
      final rewritten = qsoForStation(
        _qso(
          extra: {
            'our': {'call': 'W1AW/P', 'operatorCall': 'W1AW', 'grid': 'FN31'},
          },
        ),
        'KI2D',
      );

      expect(rewritten['our'], {'call': 'KI2D', 'operatorCall': 'W1AW', 'grid': 'FN31'});
    });

    test('qsoForStation does not touch the record it was given', () {
      final original = _qso(our: 'W1AW/P');

      qsoForStation(original, 'KI2D');

      expect((original['our'] as Map)['call'], 'W1AW/P');
    });

    test('foreignStationCalls lists what is about to be rewritten, once each', () {
      final calls = foreignStationCalls([_qso(our: 'W1AW'), _qso(our: 'W1AW/P'), _qso(our: 'W1AW'), _qso(our: 'KI2D'), _qso(our: 'ki2d')], 'KI2D');

      // Order first seen, so the warning reads the way the file does. The
      // operation's own call — in either case — is not a surprise.
      expect(calls, ['W1AW', 'W1AW/P']);
    });

    test('a record with no station call is not warned about', () {
      // Filling a blank is not a surprise. Club Log's export has no
      // STATION_CALLSIGN on any record.
      final blank = _qso()..remove('our');

      expect(foreignStationCalls([blank], 'KI2D'), isEmpty);
    });
  });

  group('hoistOperationRefs', () {
    Map<String, dynamic> withRefs(List<Map<String, dynamic>> refs) => _qso(extra: {'refs': refs});

    test('a tagged reference moves to the operation; the rest stay put', () {
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'potaActivation', 'ref': 'K-1', 'for': 'operation'},
          {'type': 'pota', 'ref': 'K-100'},
        ]),
        withRefs([
          {'type': 'potaActivation', 'ref': 'K-1', 'for': 'operation'},
          {'type': 'pota', 'ref': 'K-200'},
        ]),
      ]);

      // The tag is consumed: once it sits on the operation its position IS the
      // answer, and a marker left behind could disagree with it.
      expect(result.operationRefs, [
        {'type': 'potaActivation', 'ref': 'K-1'},
      ]);
      expect(result.qsos[0]['refs'], [
        {'type': 'pota', 'ref': 'K-100'},
      ]);
      expect(result.qsos[1]['refs'], [
        {'type': 'pota', 'ref': 'K-200'},
      ]);
    });

    test('a hunted reference on every contact is NOT hoisted', () {
      // The whole reason the producer tags rather than this layer guessing:
      // structurally this is indistinguishable from an activation, and
      // hoisting would discard the parks these contacts earned.
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'pota', 'ref': 'K-100'},
        ]),
        withRefs([
          {'type': 'pota', 'ref': 'K-100'},
        ]),
      ]);

      expect(result.operationRefs, isEmpty);
      expect(result.qsos[0]['refs'], hasLength(1));
    });

    test('a single contact hoists too', () {
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'potaActivation', 'ref': 'K-1', 'for': 'operation'},
          {'type': 'pota', 'ref': 'K-100'},
        ]),
      ]);

      expect(result.operationRefs, hasLength(1));
      expect(result.qsos.single['refs'], [
        {'type': 'pota', 'ref': 'K-100'},
      ]);
    });

    test('an n-fer activation keeps every reference it activated', () {
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'potaActivation', 'ref': 'K-1', 'for': 'operation'},
          {'type': 'potaActivation', 'ref': 'K-2', 'for': 'operation'},
        ]),
      ]);

      expect(result.operationRefs.map((r) => r['ref']), ['K-1', 'K-2']);
    });

    test('a contact left with no references loses the key, not just the list', () {
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'potaActivation', 'ref': 'K-1', 'for': 'operation'},
        ]),
      ]);

      expect(result.qsos.single.containsKey('refs'), isFalse);
    });

    test("an explicit for: 'qso' is stripped, not stored", () {
      // The tag is transport, not data — it must never reach the database.
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'pota', 'ref': 'K-100', 'for': 'qso'},
        ]),
      ]);

      expect(result.operationRefs, isEmpty);
      expect(result.qsos.single['refs'], [
        {'type': 'pota', 'ref': 'K-100'},
      ]);
    });

    test('untagged refs pass through untouched', () {
      final result = hoistOperationRefs([
        withRefs([
          {'type': 'pota', 'ref': 'K-100'},
        ]),
      ]);

      expect(result.qsos.single['refs'], [
        {'type': 'pota', 'ref': 'K-100'},
      ]);
    });

    test('the records handed in are not modified', () {
      final original = withRefs([
        {'type': 'potaActivation', 'ref': 'K-1', 'for': 'operation'},
      ]);

      hoistOperationRefs([original]);

      expect((original['refs'] as List).single, containsPair('for', 'operation'));
    });
  });

  group('mergeQsos', () {
    test('the newer value wins where both have one', () {
      final merged = mergeQsos(_qso(theirExtra: {'grid': 'FN31'}), _qso(theirExtra: {'grid': 'FN31pr'}));

      expect((merged['their'] as Map)['grid'], 'FN31pr');
    });

    test('a field only the older record has survives', () {
      // The case that decides this whole design: a LoTW download carries
      // almost no station detail, and replacing wholesale — which app-polo
      // does — erases the name a callsign lookup filled in.
      final existing = _qso(theirExtra: {'name': 'Hiram', 'grid': 'FN31', 'state': 'CT'});
      final imported = _qso(theirExtra: {'grid': 'FN31pr'});

      final merged = mergeQsos(existing, imported);

      expect((merged['their'] as Map)['name'], 'Hiram');
      expect((merged['their'] as Map)['state'], 'CT');
      expect((merged['their'] as Map)['grid'], 'FN31pr');
    });

    test('an empty value does not overwrite a real one', () {
      final merged = mergeQsos(_qso(theirExtra: {'name': 'Hiram'}), _qso(theirExtra: {'name': ''}));

      expect((merged['their'] as Map)['name'], 'Hiram');
    });

    test('times widen to the outer bounds', () {
      // Two records of one contact disagree about its edges because each saw
      // part of it.
      final merged = mergeQsos(
        _qso(at: '2024-07-23T12:00:00Z', extra: {'endAtMillis': _at('2024-07-23T12:01:00Z')}),
        _qso(at: '2024-07-23T12:02:00Z', extra: {'endAtMillis': _at('2024-07-23T12:05:00Z')}),
      );

      expect(merged['startAtMillis'], _at('2024-07-23T12:00:00Z'));
      expect(merged['endAtMillis'], _at('2024-07-23T12:05:00Z'));
    });

    test('a stacking type keeps every reference', () {
      // POTA n-fers: the extension declares allowsMultiple, and the caller
      // passes that declaration through.
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'pota', 'ref': 'K-1'},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'pota', 'ref': 'K-2'},
            ],
          },
        ),
        multiRefTypes: {'pota'},
      );

      expect(merged['refs'], [
        {'type': 'pota', 'ref': 'K-2'},
        {'type': 'pota', 'ref': 'K-1'},
      ]);
    });

    test('a type that does not stack keeps one — the newer record\'s', () {
      // Two contest refs on one QSO is not a thing, and _withAllocatedSerial
      // reads refs by type with indexWhere, so a second would be invisible
      // to it anyway.
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'OLD-ONE'},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'ARRL-DX-CW'},
            ],
          },
        ),
      );

      expect(merged['refs'], [
        {'type': 'contest', 'ref': 'ARRL-DX-CW'},
      ]);
    });

    test('an undeclared type does not stack, even for POTA', () {
      // The default is "stack nothing" — a caller that forgets to pass the
      // declarations gets the conservative answer, not the permissive one.
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'pota', 'ref': 'K-1'},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'pota', 'ref': 'K-2'},
            ],
          },
        ),
      );

      expect(merged['refs'], [
        {'type': 'pota', 'ref': 'K-2'},
      ]);
    });

    test('refs of different types both survive regardless of stacking', () {
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'sota', 'ref': 'W2/GC-001'},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'ARRL-DX-CW'},
            ],
          },
        ),
      );

      expect(merged['refs'], [
        {'type': 'contest', 'ref': 'ARRL-DX-CW'},
        {'type': 'sota', 'ref': 'W2/GC-001'},
      ]);
    });

    test('the same ref on both sides lands once, stacking or not', () {
      Map<String, dynamic> same() => _qso(
        extra: {
          'refs': [
            {'type': 'pota', 'ref': 'K-1'},
          ],
        },
      );

      expect(mergeQsos(same(), same(), multiRefTypes: {'pota'})['refs'], hasLength(1));
      expect(mergeQsos(same(), same())['refs'], hasLength(1));
    });

    test('a nested map merges rather than replaces', () {
      // `their` and `our` are maps, and replacing one wholesale is how the
      // older record's fields get lost even when the top level looks merged.
      final merged = mergeQsos(
        _qso(
          extra: {
            'our': {'call': 'N0DEV', 'grid': 'FN20', 'sent': '59'},
          },
        ),
        _qso(
          extra: {
            'our': {'call': 'N0DEV/P'},
          },
        ),
      );

      expect(merged['our'], {'call': 'N0DEV/P', 'grid': 'FN20', 'sent': '59'});
    });

    test('a ref keeps fields the winning side lacks — including its serial', () {
      // The core writes the contest serial onto the ref at commit
      // (_withAllocatedSerial), while an imported ref is only {type, ref}.
      // Replacing wholesale would discard the number the operator sent on the
      // air, which is the same mistake per-field precedence exists to avoid.
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'ARRL-DX-CW', 'serial': 42, 'ourSerial': 17},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'ARRL-DX-CW'},
            ],
          },
        ),
      );

      expect(merged['refs'], [
        {'type': 'contest', 'ref': 'ARRL-DX-CW', 'serial': 42, 'ourSerial': 17},
      ]);
    });

    test('a stacking ref merges with its own counterpart, not another', () {
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'pota', 'ref': 'K-1', 'name': 'First Park'},
              {'type': 'pota', 'ref': 'K-2', 'name': 'Second Park'},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'pota', 'ref': 'K-2'},
            ],
          },
        ),
        multiRefTypes: {'pota'},
      );

      expect(merged['refs'], [
        {'type': 'pota', 'ref': 'K-2', 'name': 'Second Park'},
        {'type': 'pota', 'ref': 'K-1', 'name': 'First Park'},
      ]);
    });

    test('a DIFFERENT reference of the same type is replaced, never grafted', () {
      // Field-merging here would move one summit's name — and a serial issued
      // against it — onto a different summit. That is worse than the loss it
      // avoids, because the result looks like real data and the serial feeds
      // the high-water mark and the export.
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'sota', 'ref': 'W2/GC-001', 'name': 'Mount Greylock', 'ourSerial': 42},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'sota', 'ref': 'W7/XX-999'},
            ],
          },
        ),
      );

      expect(merged['refs'], [
        {'type': 'sota', 'ref': 'W7/XX-999'},
      ]);
    });

    test('merging the same records twice is idempotent', () {
      // A malformed ref has no type to dedupe on. Skipping the check outright
      // doubles it on every merge, so a re-run of an import grows the stored
      // record without bound.
      Map<String, dynamic> record() => _qso(
        extra: {
          'refs': [
            {'ref': 'x'},
            {'type': 'pota', 'ref': 'K-1'},
          ],
        },
      );

      var merged = mergeQsos(record(), record());
      expect(merged['refs'], hasLength(2));

      merged = mergeQsos(merged, merged);
      expect(merged['refs'], hasLength(2));
    });

    test('two DIFFERENT malformed refs both survive', () {
      // Guards the dedupe above from collapsing distinct ones.
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'ref': 'x'},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'ref': 'y'},
            ],
          },
        ),
      );

      expect(merged['refs'], hasLength(2));
    });

    test('the newer ref still wins a field both sides carry', () {
      final merged = mergeQsos(
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'ARRL-DX-CW', 'serial': 1},
            ],
          },
        ),
        _qso(
          extra: {
            'refs': [
              {'type': 'contest', 'ref': 'ARRL-DX-CW', 'serial': 99},
            ],
          },
        ),
      );

      expect(((merged['refs'] as List).single as Map)['serial'], 99);
    });

    test('a whitespace-only value does not erase a real one', () {
      // The ADIF mapper strips a trailing run before this sees it, but QSON
      // import and sync reach the same code without that pass.
      final merged = mergeQsos(_qso(theirExtra: {'name': 'Hiram'}), _qso(theirExtra: {'name': '   '}));

      expect((merged['their'] as Map)['name'], 'Hiram');
    });

    test('a typeless ref survives from either side', () {
      // The rule is that a reference is never dropped for being unwanted.
      // Applying it to one side only silently deletes whatever the OLDER
      // record carried, the moment anything merges into it.
      final typeless = {'ref': 'x'};
      final typed = {'type': 'pota', 'ref': 'K-9'};

      final olderHasIt = mergeQsos(
        _qso(
          extra: {
            'refs': [typeless],
          },
        ),
        _qso(
          extra: {
            'refs': [typed],
          },
        ),
      );
      final newerHasIt = mergeQsos(
        _qso(
          extra: {
            'refs': [typed],
          },
        ),
        _qso(
          extra: {
            'refs': [typeless],
          },
        ),
      );

      expect(olderHasIt['refs'], hasLength(2));
      expect(newerHasIt['refs'], hasLength(2));
    });

    test('a map only the older record carries is copied, not shared', () {
      // A shallow copy shares exactly the keys the newer side does NOT have —
      // those are never visited again, so they stay pointing at the input.
      final older = _qso(
        extra: {
          'event': {'kind': 'break'},
        },
      );
      final newer = _qso();

      final merged = mergeQsos(older, newer);
      (merged['event'] as Map)['kind'] = 'MUTATED';

      expect((older['event'] as Map)['kind'], 'break');
    });

    test('merged refs are copies, not the input ref objects', () {
      // The import preview holds the log record and the merged candidate side
      // by side; editing one must not rewrite the other.
      final older = _qso(
        extra: {
          'refs': [
            {'type': 'pota', 'ref': 'K-1'},
          ],
        },
      );

      final merged = mergeQsos(older, _qso());
      ((merged['refs'] as List).first as Map)['ref'] = 'MUTATED';

      expect(((older['refs'] as List).first as Map)['ref'], 'K-1');
    });

    test('merging is not destructive to its inputs', () {
      // The import plan holds both sides to show the operator a preview, and
      // building the preview must not alter the log it is previewing against.
      final older = _qso(theirExtra: {'name': 'Hiram'});
      final newer = _qso(theirExtra: {'grid': 'FN31'});

      mergeQsos(older, newer);

      expect((older['their'] as Map).containsKey('grid'), isFalse);
      expect((newer['their'] as Map).containsKey('name'), isFalse);
    });
  });

  group('mergeConcurrentEdit', () {
    // The trap: a whole-record save composed from a stale snapshot reverting
    // a concurrent revision's fields — and, restamped newer, winning on
    // every device. Only the fields the editor actually changed may
    // overwrite; everything else must keep the concurrent value.
    test('fields the editor did not touch keep the concurrent revision', () {
      final base = {
        'uuid': 'q1',
        'their': {'call': 'W1AW', 'sent': '59'},
        'notes': 'original',
      };
      final current = {
        'uuid': 'q1',
        'their': {'call': 'W1AW', 'sent': '59', 'name': 'Hiram'},
        'notes': 'original',
        'grid': 'FN31',
      };
      final edited = {
        'uuid': 'q1',
        'their': {'call': 'W1AW', 'sent': '55'},
        'notes': 'edited here',
      };
      final merged = mergeConcurrentEdit(base: base, current: current, edited: edited);
      expect((merged['their'] as Map)['sent'], '55', reason: 'the edit itself must land');
      expect((merged['their'] as Map)['name'], 'Hiram', reason: 'the concurrent name correction must survive');
      expect(merged['notes'], 'edited here');
      expect(merged['grid'], 'FN31', reason: 'a concurrent top-level addition must survive');
    });

    test('a field the editor removed stays removed, even when the concurrent revision changed it', () {
      final base = {'uuid': 'q1', 'notes': 'old', 'mode': 'SSB'};
      final current = {'uuid': 'q1', 'notes': 'concurrently changed', 'mode': 'SSB'};
      final edited = {'uuid': 'q1', 'mode': 'SSB'};
      final merged = mergeConcurrentEdit(base: base, current: current, edited: edited);
      expect(merged.containsKey('notes'), isFalse);
    });

    test('a field the concurrent revision removed stays removed when the editor did not touch it', () {
      final base = {'uuid': 'q1', 'notes': 'old', 'mode': 'SSB'};
      final current = {'uuid': 'q1', 'mode': 'SSB'};
      final edited = {'uuid': 'q1', 'notes': 'old', 'mode': 'CW'};
      final merged = mergeConcurrentEdit(base: base, current: current, edited: edited);
      expect(merged.containsKey('notes'), isFalse);
      expect(merged['mode'], 'CW');
    });

    test('refs are one value: an edited ref list wins wholesale, an untouched one keeps current', () {
      final base = {
        'refs': [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      };
      final current = {
        'refs': [
          {'type': 'pota', 'ref': 'US-0002'},
        ],
      };
      final untouched = mergeConcurrentEdit(
        base: base,
        current: current,
        edited: {
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        },
      );
      expect((untouched['refs'] as List).single, {'type': 'pota', 'ref': 'US-0002'});

      final editedWins = mergeConcurrentEdit(
        base: base,
        current: current,
        edited: {
          'refs': [
            {'type': 'pota', 'ref': 'US-0003'},
          ],
        },
      );
      expect((editedWins['refs'] as List).single, {'type': 'pota', 'ref': 'US-0003'});
    });

    test('the result shares no mutable structure with its inputs', () {
      final current = {
        'their': {'call': 'W1AW', 'name': 'Hiram'},
      };
      final merged = mergeConcurrentEdit(base: const {}, current: current, edited: const {});
      (merged['their'] as Map)['name'] = 'changed';
      expect((current['their'] as Map)['name'], 'Hiram');
    });
  });
}
