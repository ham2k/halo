// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `findCalls` has two implementations — SQL in the app
// (`QsosRepository.findCalls`, `LookupRepository.findLookupCalls`) and
// `findCallsAmong` in the CLI — and an extension cannot tell which host
// answered. Every case runs through both, so a rule changed on one side
// alone fails here.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

final _day = DateTime.utc(2026, 9, 1).millisecondsSinceEpoch;
const _hour = Duration.millisecondsPerHour;

void main() {
  group('CallMatch', () {
    test('one edit is a change, an addition, a removal or a swap of neighbours, never the call itself', () {
      final variants = CallMatch('K1AB').variants;
      expect(variants, containsAll(['K1AC', 'K1ABC', 'K1B', 'K1BA', '1KAB']));
      expect(variants, isNot(contains('K1AB')));
      // Two edits: a swap of characters that are not neighbours.
      expect(variants, isNot(contains('B1AK')));
    });

    test('the closest kind wins: a call the text is inside is partial even when one edit away', () {
      final match = CallMatch('K1A');
      expect(match.kindOf('K1A'), CallMatchKind.exact);
      expect(match.kindOf('K1AB'), CallMatchKind.partial);
      expect(match.kindOf('WK1AB'), CallMatchKind.partial);
      expect(match.kindOf('K2A'), CallMatchKind.oneEdit);
      expect(match.kindOf('W2XYZ'), isNull);
    });

    test('? stands for one character, and turns off one-edit matching', () {
      final match = CallMatch('k1?b');
      expect(match.text, 'K1?B');
      expect(match.kindOf('K1AB'), CallMatchKind.exact);
      expect(match.kindOf('WK1ABC'), CallMatchKind.partial);
      expect(match.kindOf('K1B'), isNull);
      expect(match.variants, isEmpty);
    });

    test('text that cannot be a callsign rejects rather than reaching SQL as a pattern', () {
      expect(() => CallMatch.fromParams({'call': "K1'B"}, hostCall: 'findCalls'), throwsFormatException);
      expect(() => CallMatch.fromParams({'call': 'K1*'}, hostCall: 'findCalls'), throwsFormatException);
      expect(() => CallMatch.fromParams({'call': 'K1', 'match': 'fuzzy'}, hostCall: 'findCalls'), throwsFormatException);
      expect(() => CallMatch.fromParams({'call': 'K1', 'limit': 0}, hostCall: 'findCalls'), throwsFormatException);
      expect(CallMatch.fromParams({'call': 'K1', 'limit': 5000}, hostCall: 'findCalls').limit, CallMatch.maxLimit);
    });

    test('text longer than any callsign rejects before its one-edit set, which grows with its square, is built', () {
      expect(CallMatch.fromParams({'call': 'VP2V/K1ABC/QRP'}, hostCall: 'findCalls').text, 'VP2V/K1ABC/QRP');
      expect(() => CallMatch.fromParams({'call': 'K1' * 500}, hostCall: 'findCalls'), throwsFormatException);
      expect(() => CallMatch('A' * (CallMatch.maxLength + 1)), throwsFormatException);
    });
  });

  group('findCalls means the same in SQL and in the CLI', () {
    late HaLoDatabase db;
    late QsosRepository qsos;
    late String opA;
    late String opB;
    // Every contact that counts, as the CLI is handed them.
    late List<({String call, int? startAtMillis, String operation, String band})> counted;

    setUp(() async {
      db = HaLoDatabase(NativeDatabase.memory());
      final operations = OperationsRepository(db);
      qsos = QsosRepository(db);
      opA = (await operations.create(stationCall: 'N0DEV')).uuid;
      opB = (await operations.create(stationCall: 'N0DEV')).uuid;
      counted = [];
      Future<void> log(String op, String call, int hours, {String band = '20m'}) async {
        await qsos.add(op, {
          'their': {'call': call},
          'band': band,
          'mode': 'CW',
          'startAtMillis': _day + hours * _hour,
        });
        counted.add((call: call, startAtMillis: _day + hours * _hour, operation: op, band: band));
      }

      await log(opA, 'K1AB', 1);
      await log(opB, 'K1AB', 2, band: '40m');
      await log(opA, 'K1ABC', 3);
      await log(opA, 'WK1AB', 4);
      await log(opB, 'WK1AB', 5);
      await log(opB, 'WK1AB', 6, band: '40m');
      await log(opA, 'K1AC', 7);
      await log(opA, 'K2AB', 8);
      await log(opA, 'N0XYZ', 9);
      // Never counted: deleted, and an event marker.
      final deleted = await qsos.add(opA, {
        'their': {'call': 'K1ABD'},
        'band': '20m',
        'startAtMillis': _day,
      });
      await qsos.softDelete(deleted);
      await qsos.add(opA, {
        'their': {'call': 'K1AB'},
        'band': 'event',
        'startAtMillis': _day,
      });
    });

    tearDown(() async => db.close());

    final cases = <String, (Map<String, dynamic> Function(String opA, String opB), List<String>)>{
      'every kind, closest first, then most worked': (
        (a, b) => {'call': 'K1AB'},
        // K2AB before K1AC: one contact each, and K2AB's is the later.
        ['K1AB', 'WK1AB', 'K1ABC', 'K2AB', 'K1AC'],
      ),
      'partial only': ((a, b) => {'call': 'K1A', 'match': 'partial'}, ['WK1AB', 'K1AB', 'K1AC', 'K1ABC']),
      'one edit only': (
        (a, b) => {
          'call': 'K1AB',
          'match': ['oneEdit'],
        },
        // WK1AB is one edit too (a W added) — partial, when partial is asked.
        ['WK1AB', 'K2AB', 'K1AC', 'K1ABC'],
      ),
      'a wildcard': ((a, b) => {'call': 'K?AB'}, ['K1AB', 'K2AB', 'WK1AB', 'K1ABC']),
      'the limit cuts after the ordering': ((a, b) => {'call': 'K1AB', 'limit': 2}, ['K1AB', 'WK1AB']),
      'a filter counts only the contacts it keeps': ((a, b) => {'call': 'K1AB', 'band': '40m'}, ['K1AB', 'WK1AB']),
      'an operation filter': ((a, b) => {'call': 'K1A', 'operation': b}, ['WK1AB', 'K1AB']),
      'nothing matches': ((a, b) => {'call': 'ZZ9'}, <String>[]),
    };

    for (final MapEntry(key: name, value: (params, expected)) in cases.entries) {
      test(name, () async {
        final p = params(opA, opB);
        final match = CallMatch.fromParams(p, hostCall: 'findCalls');
        final filter = HistoryFilter.fromParams(p, hostCall: 'findCalls', alsoKnown: CallMatch.paramKeys);
        final sql = await qsos.findCalls(match, filter: filter);
        final cli = findCallsAmong([
          for (final c in counted)
            if (filter.matches({'operation': c.operation, 'band': c.band, 'mode': 'CW', 'startAtMillis': c.startAtMillis}))
              (call: c.call, startAtMillis: c.startAtMillis),
        ], match);
        expect([for (final f in sql) f.call], expected);
        expect([for (final f in sql) foundCallToJson(f)], [for (final f in cli) foundCallToJson(f)]);
      });
    }

    test('each call carries its count and its latest start', () async {
      final found = await qsos.findCalls(CallMatch('WK1AB', kinds: {CallMatchKind.exact}));
      expect(foundCallToJson(found.single), {'call': 'WK1AB', 'match': 'exact', 'count': 3, 'lastAtMillis': _day + 6 * _hour});
    });

    test('a call longer than the old bound-variable limit allows still finds its one-edit neighbours', () async {
      // A 14-character call has over a thousand variants; bound one per
      // variable, an older SQLite refuses the statement.
      await qsos.add(opA, {
        'their': {'call': 'VP2V/K1ABCDEFH'},
        'band': '20m',
        'startAtMillis': _day,
      });
      final match = CallMatch('VP2V/K1ABCDEFG', kinds: {CallMatchKind.oneEdit});
      expect(match.variants.length, greaterThan(999));
      expect([for (final f in await qsos.findCalls(match)) f.call], ['VP2V/K1ABCDEFH']);
    });
  });

  group('findLookupCalls', () {
    late HaLoDatabase db;
    late LookupRepository lookups;

    setUp(() async {
      db = HaLoDatabase(NativeDatabase.memory());
      lookups = LookupRepository(db);
      await lookups.insertLookupBatch([
        for (final call in ['K1AB', 'K1ABC', 'WK1AB', 'K2AB', 'N0XYZ']) LookupRow(category: 'scp', key: call),
        const LookupRow(category: 'other', key: 'K1AB'),
      ]);
    });

    tearDown(() async => db.close());

    test('matches keys of its own category only, closest first, each with its kind', () async {
      final found = await lookups.findLookupCalls('scp', CallMatch('K1AB'));
      expect(
        [for (final (row, kind) in found) '${row.category}:${row.key}:${kind.name}'],
        ['scp:K1AB:exact', 'scp:K1ABC:partial', 'scp:WK1AB:partial', 'scp:K2AB:oneEdit'],
      );
    });

    test('a category is a value, never SQL: one holding a quote matches its own rows', () async {
      await lookups.insertLookupBatch([const LookupRow(category: "o'hare", key: 'K1AB')]);
      final found = await lookups.findLookupCalls("o'hare", CallMatch('K1AB'));
      expect([for (final (row, _) in found) row.category], ["o'hare"]);
    });
  });
}
