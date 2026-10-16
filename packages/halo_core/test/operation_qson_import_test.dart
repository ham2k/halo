// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async => db.close());

  Future<Operation> import(Object payload) => importQsonOperation(
    db: db,
    operations: operations,
    qsos: qsos,
    bytes: payload is List<int> ? payload : utf8.encode(payload is String ? payload : jsonEncode(payload)),
  );

  test('a file exported here imports beside its original, as a separate operation', () async {
    final original = await operations.create(stationCall: 'N0DEV', userTitle: 'Park day');
    await operations.saveData(
      Operation(
        uuid: original.uuid,
        data: {
          ...original.data,
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
          ],
        },
      ),
    );
    final logged = [
      await qsos.add(original.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'CW',
      }),
      await qsos.add(original.uuid, {
        'their': {'call': 'K2ABC'},
        'band': '40m',
        'mode': 'SSB',
      }),
    ];
    final stored = (await operations.get(original.uuid))!;
    // The shape `qsonPayloadFor` writes.
    final copy = await import({
      'operation': {
        ...stored.data,
        'uuid': stored.uuid,
        'operatorCall': '',
        'local': {'operatorCall': ''},
      },
      'qsos': [for (final qso in logged) qso.data],
    });

    // The QSO uuid is a primary key across operations: keeping the file's
    // would refuse this import outright while the original is here.
    expect(copy.uuid, isNot(original.uuid));
    final copied = await qsos.forOperation(copy.uuid);
    expect(copied.map((q) => q.theirCall), unorderedEquals(['W1AW', 'K2ABC']));
    expect(copied.map((q) => q.uuid).toSet().intersection(logged.map((q) => q.uuid).toSet()), isEmpty);
    expect(copied.every((q) => q.data['uuid'] == q.uuid), isTrue, reason: 'a row and its QSON must agree on one identity');
    expect((await qsos.forOperation(original.uuid)).length, 2, reason: 'the original keeps its own contacts');

    expect(copy.stationCall, 'N0DEV');
    expect(copy.data['userTitle'], 'Park day');
    expect(copy.refs.single['ref'], 'US-0001');
    expect(copy.qsoCount, 2, reason: 'the counters the list reads are refreshed by the import');
    expect(copy.createdAtMillis, original.createdAtMillis, reason: 'a copy was created when its original was');
  });

  test('tombstones in the file stay out of the copy', () async {
    final copy = await import({
      'operation': {'uuid': 'a', 'stationCall': 'N0DEV'},
      'qsos': [
        {
          'uuid': 'q1',
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000,
        },
        // app-polo writes `deleted` as a boolean, LoFi as a number.
        {
          'uuid': 'q2',
          'their': {'call': 'K2ABC'},
          'startAtMillis': 2000,
          'deleted': 1,
        },
        {
          'uuid': 'q3',
          'their': {'call': 'N3XYZ'},
          'startAtMillis': 3000,
          'purged': true,
        },
      ],
    });

    expect((await qsos.forOperation(copy.uuid, includeDeleted: true)).map((q) => q.theirCall), ['W1AW']);
  });

  test('an app-polo export carries its operator into the copy', () async {
    final copy = await import({
      'operation': {
        'uuid': 'a',
        'stationCall': 'N0DEV',
        'createdOnMillis': 1700000000000,
        // Blank, as app-polo leaves the slot it moved into `local`: an empty
        // slot is no operator, and would otherwise keep KI2D out.
        'operatorCall': '',
        'local': {'operatorCall': 'KI2D'},
        'syncedAtMillis': 1700000005000,
        // What app-polo's dump adds from the row, and its storage strips.
        'qsoCount': 40,
        'synced': true,
        '_useTemplates': true,
        'startAtMillisMin': 1700000000000,
      },
      'qsos': <Object>[],
    });

    expect(operatorCallFor(copy), 'KI2D');
    expect(copy.createdAtMillis, 1700000000000, reason: "polo's legacy stamp spelling");
    expect(copy.data.containsKey('local'), isFalse, reason: 'the source device\'s local data is not this one\'s');
    expect(copy.data.containsKey('syncedAtMillis'), isFalse, reason: 'a server watermark from the source says nothing about this record');
    expect(copy.synced, isFalse, reason: 'the copy is new, and has to reach the server');
    for (final key in ['qsoCount', 'synced', '_useTemplates', 'startAtMillisMin']) {
      expect(copy.data.containsKey(key), isFalse, reason: '$key would sync, and go stale at the first edit');
    }
  });

  test("an app-polo export's stale coordinate gives way to the grid it was moved to", () async {
    // PoLo's location screen writes `grid` alone, so a pair from before the
    // move survives beside it — and a pair outranks the grid wherever it is
    // read, placing the copy where the operator no longer was.
    final copy = await import({
      'operation': {'uuid': 'a', 'stationCall': 'N0DEV', 'grid': 'FN20', 'lat': 51.5, 'lon': -0.1},
      'qsos': <Object>[],
    });

    expect(copy.data['grid'], 'FN20');
    expect(copy.data.containsKey('lat'), isFalse);
    expect(copy.data.containsKey('lon'), isFalse);
  });

  test('a wrong-typed field costs that field, not the import', () async {
    // band and mode land in typed columns: a value read raw there would throw
    // and roll the whole import back.
    final copy = await import({
      'operation': {'uuid': 'a', 'stationCall': 'N0DEV'},
      'qsos': [
        {
          'uuid': 'q1',
          'their': {'call': 'W1AW'},
          'band': 20,
          'mode': true,
          'startAtMillis': 1000,
        },
      ],
    });

    final copied = (await qsos.forOperation(copy.uuid)).single;
    expect(copied.theirCall, 'W1AW');
    expect(copied.band, isNull);
    expect(copied.mode, isNull);
  });

  test('a lower-case station call is stored as every other operation\'s is', () async {
    // Lookups and the travel marker compare calls as stored; a copy kept in
    // the file's case would not match the original's.
    final copy = await import({
      'operation': {'stationCall': 'n0dev'},
      'qsos': <Object>[],
    });

    expect(copy.stationCall, 'N0DEV');
  });

  test('a file saved with a byte order mark still reads', () async {
    final copy = await import([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(
        jsonEncode({
          'operation': {'stationCall': 'N0DEV'},
          'qsos': <Object>[],
        }),
      ),
    ]);

    expect(copy.stationCall, 'N0DEV');
  });

  test('a file that is not a QSON operation writes nothing, and says which way it is not', () async {
    // The problem, not the English detail, is what the operator is shown.
    Matcher fails(QsonImportProblem problem) => throwsA(isA<QsonImportException>().having((e) => e.problem, 'problem', problem));

    await expectLater(import('not json'), fails(QsonImportProblem.notJson));
    await expectLater(import({'qsos': <Object>[]}), fails(QsonImportProblem.notOperation));
    // Both writers always write `qsos`; without it this is a broken file, not
    // an empty operation.
    await expectLater(
      import({
        'operation': {'stationCall': 'N0DEV'},
      }),
      fails(QsonImportProblem.notOperation),
    );
    // Latin-1 `é`: decoded leniently it would be stored as U+FFFD.
    await expectLater(import([...utf8.encode('{"operation": {"userTitle": "Caf'), 0xE9, ...utf8.encode('"}, "qsos": []}')]), fails(QsonImportProblem.notUtf8));
    await expectLater(
      import({
        'operation': {'stationCall': 'N0DEV'},
        'qsos': 'nope',
      }),
      fails(QsonImportProblem.notOperation),
    );

    expect(await operations.watchAll().first, isEmpty);
  });
}
