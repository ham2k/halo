// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `getHistoryForCall`'s options have two implementations — SQL in the app
// (`QsosRepository.historyForCall`) and `HistoryFilter.matches` in the CLI —
// and an extension cannot tell which host answered. Every case below runs
// through both, so a rule changed on one side alone fails here.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

final _day = DateTime.utc(2026, 9, 1).millisecondsSinceEpoch;
const _hour = Duration.millisecondsPerHour;

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async => db.close());

  group('every option means the same in SQL and in the CLI predicate', () {
    late String opA;
    late String opB;
    // Each QSO is tagged so a case names what it expects to see.
    late Map<String, (String, Map<String, Object?>)> log;

    setUp(() async {
      opA = (await operations.create(stationCall: 'N0DEV')).uuid;
      opB = (await operations.create(stationCall: 'N0DEV')).uuid;
      log = {
        'cwt-cw-40': (opA, {'band': '40m', 'mode': 'CW', 'startAtMillis': _day, 'refs': [{'type': 'cwt'}]}),
        'pota-usb-20': (opA, {'band': '20m', 'mode': 'USB', 'startAtMillis': _day + _hour, 'refs': [{'type': 'pota', 'ref': 'US-0001'}]}),
        'ssb-20': (opB, {'band': '20M', 'mode': 'SSB', 'startAtMillis': _day + 23 * _hour, 'refs': [{'type': 'pota'}, {'type': 'cwt'}]}),
        'ft8-20': (opB, {'band': '20m', 'mode': 'FT8', 'startAtMillis': _day + 24 * _hour}),
        'fm-2m': (opB, {'band': '2m', 'mode': 'FM', 'startAtMillis': _day + 25 * _hour}),
        // No band or mode: an exclude filter must keep it, and an include
        // filter must drop it. (`add` stamps a missing start time, so a
        // time-less QSO only reaches the CLI — see the predicate test below.)
        'bare': (opA, {'startAtMillis': _day - _hour, 'refs': 'not-a-list'}),
      };
      for (final entry in log.entries) {
        await qsos.add(entry.value.$1, {
          'their': {'call': 'KI2D'},
          'tag': entry.key,
          ...entry.value.$2,
        });
      }
    });

    final cases = <String, (Map<String, dynamic> Function(String opA, String opB), Set<String>)>{
      'no options': ((a, b) => {}, {'cwt-cw-40', 'pota-usb-20', 'ssb-20', 'ft8-20', 'fm-2m', 'bare'}),
      'refType': ((a, b) => {'refType': 'cwt'}, {'cwt-cw-40', 'ssb-20'}),
      'refType list': ((a, b) => {'refType': ['sota', 'pota']}, {'pota-usb-20', 'ssb-20'}),
      'operation': ((a, b) => {'operation': a}, {'cwt-cw-40', 'pota-usb-20', 'bare'}),
      'excludeOperation': ((a, b) => {'excludeOperation': [a]}, {'ssb-20', 'ft8-20', 'fm-2m'}),
      'band, case-insensitive': ((a, b) => {'band': '20m'}, {'pota-usb-20', 'ssb-20', 'ft8-20'}),
      'excludeBand keeps a band-less QSO': ((a, b) => {'excludeBand': ['20M', '2m']}, {'cwt-cw-40', 'bare'}),
      'SSB folds the sidebands': ((a, b) => {'mode': 'ssb'}, {'pota-usb-20', 'ssb-20'}),
      'USB folds too': ((a, b) => {'mode': 'USB'}, {'pota-usb-20', 'ssb-20'}),
      'PHONE is the family': ((a, b) => {'mode': 'PHONE'}, {'pota-usb-20', 'ssb-20', 'fm-2m'}),
      'DATA is the family': ((a, b) => {'mode': 'DATA'}, {'ft8-20'}),
      'CW plus a literal': ((a, b) => {'mode': ['CW', 'FT8']}, {'cwt-cw-40', 'ft8-20'}),
      'excludeMode keeps a mode-less QSO': ((a, b) => {'excludeMode': 'PHONE'}, {'cwt-cw-40', 'ft8-20', 'bare'}),
      'fromDate is the start of the UTC day': ((a, b) => {'fromDate': '2026-09-02'}, {'ft8-20', 'fm-2m'}),
      'toDate is the end of the UTC day': ((a, b) => {'toDate': '2026-09-01'}, {'bare', 'cwt-cw-40', 'pota-usb-20', 'ssb-20'}),
      'toDateMillis snaps to its day': ((a, b) => {'toDateMillis': _day + 5}, {'bare', 'cwt-cw-40', 'pota-usb-20', 'ssb-20'}),
      'fromTime is exact and inclusive': ((a, b) => {'fromTime': '2026-09-01T01:00:00Z'}, {'pota-usb-20', 'ssb-20', 'ft8-20', 'fm-2m'}),
      'a timestamp with no offset is UTC': ((a, b) => {'toTime': '2026-09-01T01:00:00'}, {'bare', 'cwt-cw-40', 'pota-usb-20'}),
      'an offset is honoured': ((a, b) => {'toTime': '2026-09-01T03:00:00+02:00'}, {'bare', 'cwt-cw-40', 'pota-usb-20'}),
      'the tightest bound wins': ((a, b) => {'fromDate': '2026-09-01', 'fromTimeMillis': _day + 2 * _hour}, {'ssb-20', 'ft8-20', 'fm-2m'}),
      'options combine': ((a, b) => {'band': '20m', 'excludeMode': 'DATA', 'operation': b}, {'ssb-20'}),
    };

    for (final MapEntry(key: name, value: (params, expected)) in cases.entries) {
      test(name, () async {
        final filter = HistoryFilter.fromParams(params(opA, opB));

        final fromSql = await qsos.historyForCall('KI2D', limit: 50, filter: filter);
        expect({for (final qso in fromSql) qso.data['tag']}, expected, reason: 'SQL (app host)');

        final fromPredicate = {
          for (final entry in log.entries)
            if (filter.matches(entry.value.$2, operationUuid: entry.value.$1)) entry.key,
        };
        expect(fromPredicate, expected, reason: 'HistoryFilter.matches (CLI host)');
      });
    }
  });

  group('refPrefix, in SQL and in the CLI predicate', () {
    late String op;
    final log = <String, Map<String, Object?>>{
      'pota-fr': {'refs': [{'type': 'potaActivation', 'ref': 'FR-0123'}]},
      'pota-fr-lower': {'refs': [{'type': 'potaActivation', 'ref': 'fr-0456'}]},
      'pota-us': {'refs': [{'type': 'potaActivation', 'ref': 'US-0001'}]},
      // A US park and a French summit: FR- is on one ref, POTA on the other.
      'pota-us-sota-fr': {'refs': [{'type': 'potaActivation', 'ref': 'US-0002'}, {'type': 'sota', 'ref': 'FR/AB-001'}]},
      'numeric-ref': {'refs': [{'type': 'potaActivation', 'ref': 123}]},
      'accented': {'refs': [{'type': 'other', 'ref': 'éte-1'}]},
      'emoji': {'refs': [{'type': 'other', 'ref': '🦆-1'}]},
    };

    setUp(() async {
      op = (await operations.create(stationCall: 'N0DEV')).uuid;
      for (final entry in log.entries) {
        await qsos.add(op, {'their': {'call': 'KI2D'}, 'tag': entry.key, ...entry.value});
      }
    });

    final cases = <String, (Map<String, dynamic>, Set<String>)>{
      'a prefix alone matches any ref type': ({'refPrefix': 'FR'}, {'pota-fr', 'pota-fr-lower', 'pota-us-sota-fr'}),
      'case does not matter': ({'refPrefix': 'fr-'}, {'pota-fr', 'pota-fr-lower'}),
      'type and prefix must hold for the same ref': (
        {'refType': 'potaActivation', 'refPrefix': 'FR'},
        {'pota-fr', 'pota-fr-lower'},
      ),
      'a list of prefixes matches any of them': ({'refPrefix': ['US-', 'FR-']}, {'pota-fr', 'pota-fr-lower', 'pota-us', 'pota-us-sota-fr'}),
      'a numeric ref never matches a prefix': ({'refPrefix': '12'}, <String>{}),
      // SQLite's upper() folds ASCII only; folding more in Dart would have the
      // CLI match what the app does not.
      'non-ASCII letters match their own case only': ({'refPrefix': 'É'}, <String>{}),
      'ASCII letters beside them still fold': ({'refPrefix': 'éTE'}, {'accented'}),
      'a prefix outside the BMP is measured in characters': ({'refPrefix': '🦆-'}, {'emoji'}),
    };

    for (final MapEntry(key: name, value: (params, expected)) in cases.entries) {
      test(name, () async {
        final filter = HistoryFilter.fromParams(params);

        final fromSql = await qsos.historyForCall('KI2D', limit: 50, filter: filter);
        expect({for (final qso in fromSql) qso.data['tag']}, expected, reason: 'SQL (app host)');

        final fromPredicate = {
          for (final entry in log.entries)
            if (filter.matches(entry.value, operationUuid: op)) entry.key,
        };
        expect(fromPredicate, expected, reason: 'HistoryFilter.matches (CLI host)');
      });
    }
  });

  test('in the CLI, a QSO with no start time never falls inside a bound', () {
    // Treating it as 0 would put it inside every `toTime` and hand back a
    // contact nobody can say was made in the window.
    final undated = {'their': {'call': 'KI2D'}};
    expect(HistoryFilter.fromParams({'toTimeMillis': _day}).matches(undated), isFalse);
    expect(HistoryFilter.fromParams({'fromTimeMillis': 0}).matches(undated), isFalse);
    expect(HistoryFilter.none.matches(undated), isTrue);
  });

  test('a filter applies before the limit, so an older CWT contact survives newer non-CWT ones', () async {
    // The case the option exists for: taking the newest five and filtering
    // them afterwards would answer [] here, and the CWT prefill would lose
    // the station's name and number.
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': 0, 'refs': [{'type': 'cwt'}]});
    for (var i = 1; i <= 6; i++) {
      await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': i, 'refs': [{'type': 'pota'}]});
    }

    final unfiltered = await qsos.historyForCall('KI2D', limit: HistoryFilter.defaultLimit);
    expect(unfiltered.map((q) => q.startAtMillis), [6, 5, 4, 3, 2]);

    final filter = HistoryFilter.fromParams({'refType': 'cwt'});
    final filtered = await qsos.historyForCall('KI2D', limit: filter.limit, filter: filter);
    expect(filtered.map((q) => q.startAtMillis), [0]);
  });

  test('the limit counts contacts, not event markers', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': 0});
    await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'band': 'event', 'startAtMillis': 1});

    expect(await qsos.historyForCall('KI2D', limit: 1), hasLength(1));
  });

  test('one row with malformed JSON does not fail a refType lookup for the rest', () async {
    // json_each throws on it, and SQLite does not promise to short-circuit
    // the AND that would have skipped the row.
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': 0, 'refs': [{'type': 'cwt'}]});
    await db.into(db.qsos).insert(QsosCompanion.insert(
          uuid: 'broken',
          operation: op.uuid,
          theirCall: const Value('KI2D'),
          startAtMillis: const Value(1),
          data: const Value('{not json'),
        ));

    final filter = HistoryFilter.fromParams({'refType': 'cwt'});
    final result = await qsos.historyForCall('KI2D', limit: filter.limit, filter: filter);
    expect(result.map((q) => q.startAtMillis), [0]);
  });

  test('a ref type with a quote in it is a value, not SQL', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'refs': [{'type': "o'hare"}]});

    final filter = HistoryFilter.fromParams({'refType': "o'hare"});
    expect(await qsos.historyForCall('KI2D', filter: filter), hasLength(1));
  });

  group('HistoryFilter.fromParams', () {
    test('an empty exclude option excludes nothing', () {
      final filter = HistoryFilter.fromParams({'call': 'KI2D', 'excludeOperation': [], 'excludeBand': ''});
      expect(filter.matches({'band': '20m'}, operationUuid: 'op-1'), isTrue);
    });

    test('limit defaults to 5 and is capped at 50', () {
      expect(HistoryFilter.fromParams({}).limit, 5);
      expect(HistoryFilter.fromParams({'limit': 12}).limit, 12);
      expect(HistoryFilter.fromParams({'limit': 500}).limit, 50);
    });

    // Dropping a malformed option would answer a narrower question with the
    // whole history, and the caller would trust the answer.
    for (final params in <Map<String, dynamic>>[
      {'limit': 0},
      {'limit': '10'},
      {'band': 20},
      {'mode': ['CW', 3]},
      {'fromDate': 'last tuesday'},
      {'toTimeMillis': '1700000000000'},
      // An include option built from an empty list asks for "none of these";
      // dropping it would answer with everything.
      {'operation': []},
      {'refType': ''},
      {'refPrefix': []},
      {'band': ['  ']},
      // A misspelled option must not quietly answer unfiltered.
      {'refTypes': 'cwt'},
      {'since': '2026-09-01'},
    ]) {
      test('rejects $params', () {
        expect(() => HistoryFilter.fromParams(params), throwsFormatException);
      });
    }
  });
}
