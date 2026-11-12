// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `findCalls`, `dbLookupFindCalls` and `scoreCandidates` are what a super
// check partial reads: the calls the typed text could be, from the log and
// from a callsign dataset, and what logging each would be. The matching
// rules themselves are halo_core's (`call_match_test.dart`); these cover
// the app's side of the bridge.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late ExtensionService extensions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    extensions = ExtensionService()
      ..operations = operations
      ..qsos = qsos
      ..lookups = LookupRepository(db);
  });

  tearDown(() async => db.close());

  group('findCalls', () {
    test('answers [] when no log is attached', () async {
      expect(await ExtensionService().debugHandleHostCall('findCalls', {'call': 'K1AB'}), isEmpty);
    });

    test('counts every operation but a deleted one, with the caller key the kernel stamps on every call', () async {
      final opA = await operations.create(stationCall: 'N0DEV');
      final opB = await operations.create(stationCall: 'N0DEV');
      final gone = await operations.create(stationCall: 'N0DEV');
      // k1ab is stored as written, and matched as stored: never by K1AB, as
      // the CLI's own test pins too.
      for (final (op, call, start) in [(opA, 'K1AB', 1000), (opB, 'K1AB', 2000), (opA, 'WK1AB', 3000), (gone, 'K1ABC', 4000), (opA, 'k1ab', 5000)]) {
        await qsos.add(op.uuid, {
          'their': {'call': call},
          'band': '20m',
          'startAtMillis': start,
        });
      }
      await operations.softDelete(gone.uuid);

      final result = await extensions.debugHandleHostCall('findCalls', {'call': 'k1ab', 'extensionKey': 'ham2k-partial-calls'});
      expect(result, [
        {'call': 'K1AB', 'match': 'exact', 'count': 2, 'lastAtMillis': 2000},
        {'call': 'WK1AB', 'match': 'partial', 'count': 1, 'lastAtMillis': 3000},
      ]);
    });

    test('rejects text that is no callsign, and an option it does not know, even with no log', () async {
      final bare = ExtensionService();
      await expectLater(bare.debugHandleHostCall('findCalls', {'call': "K1'AB"}), throwsFormatException);
      await expectLater(bare.debugHandleHostCall('findCalls', {'call': 'K1AB', 'matches': 'partial'}), throwsFormatException);
    });
  });

  test('dbLookupFindCalls rejects an option it does not know: a misspelled match would answer every kind', () async {
    await expectLater(extensions.debugHandleHostCall('dbLookupFindCalls', {'category': 'scp', 'call': 'K1AB', 'matches': 'exact'}), throwsFormatException);
  });

  test('dbLookupFindCalls answers rows of the category, each with its match and its data', () async {
    await extensions.lookups!.insertLookupBatch([
      const LookupRow(category: 'scp', key: 'K1AB', data: '{"rate":12}'),
      const LookupRow(category: 'scp', key: 'K2AB'),
      const LookupRow(category: 'pota', key: 'K1AB'),
    ]);
    final result = await extensions.debugHandleHostCall('dbLookupFindCalls', {'category': 'scp', 'call': 'K1AB', 'extensionKey': 'x'}) as List;
    expect(
      [
        for (final row in result.cast<Map<String, dynamic>>()) {'key': row['key'], 'match': row['match'], 'data': row['data']},
      ],
      [
        {
          'key': 'K1AB',
          'match': 'exact',
          'data': {'rate': 12},
        },
        {'key': 'K2AB', 'match': 'oneEdit', 'data': null},
      ],
    );
  });

  group('scoreCandidates', () {
    test('is answered for the operation the caller named', () async {
      Map<String, Map<String, dynamic>>? asked;
      String? askedFor;
      extensions.onScoreCandidates = (candidates, operationUuid) async {
        asked = candidates;
        askedFor = operationUuid;
        return {
          'a': {
            'notices': ['duplicate'],
            'alerts': <String>[],
          },
        };
      };
      final result = await extensions.debugHandleHostCall('scoreCandidates', {
        'operationUuid': 'op-1',
        'candidates': {
          'a': {
            'their': {'call': ' k1ab '},
            'band': '20m',
          },
        },
      });
      expect(askedFor, 'op-1');
      expect(asked!['a'], {
        'their': {'call': ' k1ab '},
        'band': '20m',
      });
      expect(result, {
        'a': {
          'notices': ['duplicate'],
          'alerts': <String>[],
        },
      });
    });

    test('rejects an operationUuid that is no string, worded as its other refusals are', () async {
      await expectLater(
        extensions.debugHandleHostCall('scoreCandidates', {'operationUuid': 42, 'candidates': <String, dynamic>{}}),
        throwsA(isA<ExtensionHostException>()),
      );
    });

    test('answers null with no operation in front to judge against', () async {
      expect(
        await extensions.debugHandleHostCall('scoreCandidates', {
          'candidates': {
            'a': {
              'their': {'call': 'K1AB'},
            },
          },
        }),
        isNull,
      );
    });

    test('refuses more candidates than one call may ask about, before any scorer runs', () async {
      var ran = false;
      extensions.onScoreCandidates = (candidates, operationUuid) async {
        ran = true;
        return const {};
      };
      final candidates = {
        for (var i = 0; i <= 20; i++)
          '$i': {
            'their': {'call': 'K${i}AB'},
          },
      };
      await expectLater(extensions.debugHandleHostCall('scoreCandidates', {'candidates': candidates}), throwsA(isA<Exception>()));
      expect(ran, isFalse);
    });
  });
}
