// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The plan is what the operator approves, so a wrong count here is a lie they
// act on. These cover the shapes where "how many will merge" is not obvious:
// several file records for one log entry, several for each other, and the
// order-dependence that pairwise folding would introduce.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/services/adif_import_plan.dart';

int _at(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

Map<String, dynamic> _data({
  String their = 'W1AW',
  String at = '2024-07-23T12:00:00Z',
  String mode = 'SSB',
  Map<String, dynamic>? theirExtra,
  Map<String, dynamic>? extra,
}) =>
    {
      'our': {'call': 'N0DEV'},
      'their': {'call': their, ...?theirExtra},
      'band': '20m',
      'mode': mode,
      'startAtMillis': _at(at),
      ...?extra,
    };

AdifRecord _record(Map<String, dynamic> data, {int number = 1, List<AdifRecordProblem> problems = const []}) =>
    AdifRecord(number: number, fields: const {}, qso: data, problems: problems);

Qso _logged(Map<String, dynamic> data, {String uuid = 'existing-1'}) =>
    Qso(uuid: uuid, operationUuid: 'op', data: {...data, 'uuid': uuid});

void main() {
  test('a contact the log does not have is an addition', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [_record(_data(their: 'K1ABC'))],
      existing: [_logged(_data(their: 'W1AW'))],
    );

    expect(plan.additions, hasLength(1));
    expect(plan.merges, isEmpty);
    expect(plan.importCount, 1);
  });

  test('a contact already logged becomes a merge, keeping what only the log has', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [_record(_data(theirExtra: {'grid': 'FN31pr'}))],
      existing: [
        _logged(_data(theirExtra: {'name': 'Hiram', 'grid': 'FN31'})),
      ],
    );

    expect(plan.additions, isEmpty);
    expect(plan.merges, hasLength(1));
    final their = plan.merges.single.data['their'] as Map;
    expect(their['name'], 'Hiram');
    expect(their['grid'], 'FN31pr');
  });

  test('two file records for one log entry produce ONE merge', () {
    // writeBatch refuses a batch naming a row twice, rightly — the second
    // update would discard the first's merge. So the plan has to fold first.
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [
        _record(_data(at: '2024-07-23T12:00:00Z', theirExtra: {'name': 'Hiram'}), number: 1),
        _record(_data(at: '2024-07-23T12:02:00Z', theirExtra: {'grid': 'FN31'}), number: 2),
      ],
      existing: [_logged(_data(at: '2024-07-23T12:01:00Z'))],
    );

    expect(plan.merges, hasLength(1));
    final their = plan.merges.single.data['their'] as Map;
    expect(their['name'], 'Hiram');
    expect(their['grid'], 'FN31');
  });

  test('the merge keeps the existing record identity', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [_record(_data(extra: {'uuid': 'from-the-file'}))],
      existing: [_logged(_data(), uuid: 'in-the-log')],
    );

    expect(plan.merges.single.uuid, 'in-the-log');
    expect(plan.merges.single.operationUuid, 'op');
  });

  test('two file records of one contact, new to the log, are one addition', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [
        _record(_data(at: '2024-07-23T12:00:00Z', theirExtra: {'name': 'Hiram'}), number: 1),
        _record(_data(at: '2024-07-23T12:03:00Z', theirExtra: {'grid': 'FN31'}), number: 2),
      ],
      existing: const [],
    );

    expect(plan.additions, hasLength(1));
    expect((plan.additions.single['their'] as Map)['name'], 'Hiram');
    expect((plan.additions.single['their'] as Map)['grid'], 'FN31');
  });

  test('grouping anchors on the first record, so the window does not drift', () {
    // Merging widens the start time BACKWARDS. Folding pairwise as it goes
    // would anchor A+B at 12:00, and C at 12:08 — four minutes after B —
    // would stop matching. Anchoring on A keeps the rule "within five minutes
    // of the contact as the file recorded it".
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [
        _record(_data(at: '2024-07-23T12:00:00Z'), number: 1),
        _record(_data(at: '2024-07-23T12:04:00Z'), number: 2),
        _record(_data(at: '2024-07-23T12:08:00Z'), number: 3),
      ],
      existing: const [],
    );

    // A and B are one contact; C is more than five minutes from A, so it is
    // its own. The point is that this answer does not change with visit order.
    expect(plan.additions, hasLength(2));
  });

  test('records the parser rejected are reported, not imported', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: const [],
      existing: const [],
      unusable: [_record(_data(), problems: [AdifRecordProblem.noCallsign])],
    );

    expect(plan.importCount, 0);
    expect(plan.isEmpty, isTrue);
    expect(plan.unusable, hasLength(1));
  });

  test('an imported record with a problem is flagged but still imported', () {
    // suspectFieldLength, not noTimestamp: a dateless record is refused
    // outright now, so it can never reach `flagged`.
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [
        _record(_data(), problems: [AdifRecordProblem.suspectFieldLength]),
      ],
      existing: const [],
    );

    expect(plan.additions, hasLength(1));
    expect(plan.flagged, hasLength(1));
  });

  test('a failed reference hook rides along on the plan', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [_record(_data())],
      existing: const [],
      failedHooks: {'pota'},
      recordsWithFailedHooks: 1,
    );

    expect(plan.failedHooks, contains('pota'));
    expect(plan.recordsWithFailedHooks, 1);
  });

  test('one program failing is not the runtime failing', () {
    // The distinction the summary's wording rests on. A named hook failing
    // leaves every other program's references intact, so the plan must not
    // report it the way it reports a batch that never ran at all.
    final named = planAdifImport(
      filename: 'f.adi',
      records: [_record(_data())],
      existing: const [],
      failedHooks: {'pota'},
      recordsWithFailedHooks: 1,
    );

    expect(named.refsUnavailable, isFalse);
  });

  test("the runtime never running is flagged by the '*' sentinel", () {
    final dead = planAdifImport(
      filename: 'f.adi',
      records: [_record(_data())],
      existing: const [],
      failedHooks: {'*'},
      recordsUnreachable: 1,
    );

    expect(dead.refsUnavailable, isTrue);
  });

  test('planning does not touch the log records it planned against', () {
    // The dialog shows both the plan and the operation underneath it.
    final logged = _logged(_data(theirExtra: {'name': 'Hiram'}));

    planAdifImport(
      filename: 'f.adi',
      records: [_record(_data(theirExtra: {'grid': 'FN31'}))],
      existing: [logged],
    );

    expect((logged.data['their'] as Map).containsKey('grid'), isFalse);
  });

  test('a record matches the NEAREST logged contact, not the first in range', () {
    // Two real contacts with one station four minutes apart. Scanning in list
    // order, the 12:04 record also matches the 12:00 row — still inside the
    // window — so both would fold into one, mashing two distinct contacts
    // together and leaving the other row untouched.
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [
        _record(_data(at: '2024-07-23T12:00:00Z', theirExtra: {'name': 'Hiram'}), number: 1),
        _record(_data(at: '2024-07-23T12:04:00Z', theirExtra: {'name': 'Grace'}), number: 2),
      ],
      existing: [
        _logged(_data(at: '2024-07-23T12:00:00Z'), uuid: 'first'),
        _logged(_data(at: '2024-07-23T12:04:00Z'), uuid: 'second'),
      ],
    );

    expect(plan.merges.map((m) => m.uuid).toSet(), {'first', 'second'});
    expect(plan.additions, isEmpty);
    // Each landed on its own contact, not both on the first.
    final byUuid = {for (final m in plan.merges) m.uuid: (m.data['their'] as Map)['name']};
    expect(byUuid, {'first': 'Hiram', 'second': 'Grace'});
  });

  test('re-importing an unchanged file produces no merges at all', () {
    // writeBatch re-stamps updatedAtMillis and clears `synced`, so a no-op
    // merge would push a whole operation back through sync and make every
    // other device see those contacts as newer revisions.
    final logged = _logged(_data(theirExtra: {'name': 'Hiram'}));

    final plan = planAdifImport(
      filename: 'f.adi',
      records: [_record(logged.data)],
      existing: [logged],
    );

    expect(plan.merges, isEmpty);
    expect(plan.additions, isEmpty);
    expect(plan.isEmpty, isTrue);
  });

  group('records that cannot be imported', () {
    test('a dateless contact is refused, not stamped with today', () {
      // writeBatch would default startAtMillis to `now`. A fabricated
      // timestamp is wrong data that looks right: it sorts among the wrong
      // contacts, and because it can never match it duplicates on every
      // re-import.
      final undated = Map<String, dynamic>.from(_data())..remove('startAtMillis');

      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(undated)],
        existing: const [],
      );

      expect(plan.additions, isEmpty);
      expect(plan.undated, hasLength(1));
      expect(plan.isEmpty, isTrue);
    });

    test('the two kinds of refusal stay apart', () {
      // The operator is told WHY. Reporting a dateless record as "no callsign"
      // sends them looking for a defect that is not there.
      final undated = Map<String, dynamic>.from(_data())..remove('startAtMillis');

      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(undated)],
        existing: const [],
        unusable: [_record(_data(), problems: [AdifRecordProblem.noCallsign])],
      );

      expect(plan.unusable, hasLength(1));
      expect(plan.undated, hasLength(1));
      expect(plan.refusedCount, 2);
    });

    test('a non-numeric timestamp is refused too, not stamped with today', () {
      // Testing for null alone lets '' or 'unknown' through: it matches
      // nothing during planning and writeBatch then defaults it to now.
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record({..._data(), 'startAtMillis': 'unknown'})],
        existing: const [],
      );

      expect(plan.additions, isEmpty);
      expect(plan.undated, hasLength(1));
    });
  });

  group('imposing the operation station call', () {
    Map<String, dynamic> from(String our, {String at = '2024-07-23T12:00:00Z', String? name}) =>
        {..._data(at: at, theirExtra: name == null ? null : {'name': name}), 'our': {'call': our}};

    test('an addition is rewritten to the operation station', () {
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(from('W1AW/P'))],
        existing: const [],
        stationCall: 'KI2D',
      );

      expect((plan.additions.single['our'] as Map)['call'], 'KI2D');
    });

    test('a foreign call still matches a logged contact', () {
      // Without taking our.call out of the comparison, the file's own call
      // would make every record look like a different contact and the whole
      // file would import as duplicates.
      final plan = planAdifImport(
        filename: 'f.adi',
        // The file contributes a name, so the merge has content — an
        // otherwise-identical record is now correctly skipped as a no-op.
        records: [_record(from('W1AW/P', name: 'Hiram'))],
        existing: [_logged(from('KI2D'))],
        stationCall: 'KI2D',
      );

      expect(plan.merges, hasLength(1));
      expect(plan.additions, isEmpty);
      expect(((plan.merges.single.data['our']) as Map)['call'], 'KI2D');
    });

    test('the warning lists what the file said, in order, once each', () {
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [
          _record(from('W1AW'), number: 1),
          _record(from('W1AW/P', at: '2024-07-23T13:00:00Z'), number: 2),
          _record(from('W1AW', at: '2024-07-23T14:00:00Z'), number: 3),
          _record(from('KI2D', at: '2024-07-23T15:00:00Z'), number: 4),
        ],
        existing: const [],
        stationCall: 'KI2D',
      );

      expect(plan.foreignStations, ['W1AW', 'W1AW/P']);
      expect(plan.stationCall, 'KI2D');
    });

    test('a logged contact nothing merges into is NOT warned about', () {
      // Merging is what rewrites an existing call. Scanning the whole log
      // would warn about contacts this import never touches — here the file is
      // all-new, so nothing logged changes.
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(from('KI2D', at: '2024-07-23T18:00:00Z'))],
        existing: [_logged(from('W1AW/P'))],
        stationCall: 'KI2D',
      );

      expect(plan.merges, isEmpty);
      expect(plan.foreignStations, isEmpty);
    });

    test('an existing contact whose call gets rewritten is warned about too', () {
      // Merging applies the imposed call to the MERGED record, which includes
      // what was already logged. A warning naming only the file's calls would
      // promise less than the code does.
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(from('KI2D', name: 'Hiram'))],
        existing: [_logged(from('W1AW/P'))],
        stationCall: 'KI2D',
      );

      expect(plan.foreignStations, contains('W1AW/P'));
    });

    test('a file already under the operation station warns about nothing', () {
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(from('KI2D'))],
        existing: const [],
        stationCall: 'KI2D',
      );

      expect(plan.foreignStations, isEmpty);
    });

    test('a record whose callsign is not a string does not throw', () {
      // Bucketing reads their.call directly. A hard cast would fail the whole
      // import on a record the matcher would simply not match.
      final odd = {..._data(), 'their': {'call': 42}};

      final plan = planAdifImport(filename: 'f.adi', records: [_record(odd)], existing: const []);

      expect(plan.additions, hasLength(1));
    });

    test('without a station call the file keeps its own', () {
      // The other importers this will serve — a whole-history import for
      // worked-before detection — must not rewrite anything.
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [_record(from('W1AW/P'))],
        existing: const [],
      );

      expect((plan.additions.single['our'] as Map)['call'], 'W1AW/P');
      expect(plan.foreignStations, isEmpty);
    });
  });

  group('operation-level references', () {
    Map<String, dynamic> hunting(String park, {required String at}) => {
          ..._data(at: at),
          'refs': [
            {'type': 'potaActivation', 'ref': 'K-0001', 'for': 'operation'},
            {'type': 'pota', 'ref': park},
          ],
        };

    test('a tagged reference is lifted off the contacts', () {
      // ADIF writes the activation onto all 200 records of a park activation
      // because it has nowhere else to put it. The adifImport hook tags it as
      // the operation's, and this is where it gets moved.
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [
          _record(hunting('K-100', at: '2024-07-23T12:00:00Z'), number: 1),
          _record(hunting('K-200', at: '2024-07-23T13:00:00Z'), number: 2),
        ],
        existing: const [],
      );

      expect(plan.hoistedOperationRefs, [
        {'type': 'potaActivation', 'ref': 'K-0001'},
      ]);
      for (final addition in plan.additions) {
        final refs = (addition['refs'] as List).cast<Map>();
        expect(refs.map((r) => r['type']), everyElement('pota'));
      }
    });

    test('the operation keeps its own activity setup', () {
      // Reported, not applied. The operator chose what this operation is; a
      // file dropped in later does not get to redefine it.
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [
          _record(hunting('K-100', at: '2024-07-23T12:00:00Z'), number: 1),
          _record(hunting('K-200', at: '2024-07-23T13:00:00Z'), number: 2),
        ],
        existing: const [],
      );

      // Nothing on the plan asks the caller to touch the operation's refs.
      expect(plan.hoistedOperationRefs, isNotEmpty);
      expect(plan.additions.every((q) => (q['refs'] as List).length == 1), isTrue);
    });

    test('a merge does not carry an operation reference onto a logged contact', () {
      final plan = planAdifImport(
        filename: 'f.adi',
        records: [
          _record(hunting('K-100', at: '2024-07-23T12:00:00Z'), number: 1),
          _record(hunting('K-200', at: '2024-07-23T13:00:00Z'), number: 2),
        ],
        existing: [_logged(_data(at: '2024-07-23T12:01:00Z'))],
      );

      final merged = plan.merges.single;
      final types = (merged.data['refs'] as List).cast<Map>().map((r) => r['type']);
      expect(types, isNot(contains('potaActivation')));
    });
  });

  test('stacking declarations reach the merge', () {
    final plan = planAdifImport(
      filename: 'f.adi',
      records: [
        _record(_data(extra: {
          'refs': [
            {'type': 'pota', 'ref': 'K-2'},
          ],
        })),
      ],
      existing: [
        _logged(_data(extra: {
          'refs': [
            {'type': 'pota', 'ref': 'K-1'},
          ],
        })),
      ],
      multiRefTypes: {'pota'},
    );

    expect(plan.merges.single.refs, hasLength(2));
  });
}
