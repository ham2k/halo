// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `getScores` hands an extension the operation's score as the app holds it:
// each scorer's operation tallies, read from the scoring a rescore keeps, by
// the same rule as the log itself.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

/// A bundle whose `read` answers what `ctx.getScores` handed it, or that the
/// context has no such call.
const _probe = '''
(function () {
'use strict'
__halo.defineExtension({
  key: 'dev-scores',
  name: 'Scores probe',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: 'dev-scores', hook: {
      read: async function (args, ctx) {
        if (typeof ctx.getScores !== 'function') return 'absent'
        return { scores: await ctx.getScores(args.operationUuid) }
      },
    }})
  },
})
})()
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> tally(String key, num total) => {'key': key, 'for': 'operation', 'total': total};

  group('the host call', () {
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
        ..qsos = qsos;
    });

    tearDown(() async => db.close());

    test('answers each scorer’s operation tallies, contests first and core last, and none of the rest', () async {
      final operation = await operations.create(stationCall: 'N0DEV');
      await operations.updateLocalData(operation.uuid, {
        'scoring': {
          'core': {
            'daySections': [
              {'day': 1, 'count': 2, 'scores': {}},
            ],
            'operationSummary': {'qsoCount': tally('qsoCount', 2)},
            'checkpoint': {'count': 2},
          },
          'ham2k-cwt': {
            'daySections': const [],
            'operationSummary': {'contest': tally('contest', 1234)},
            'scoresheet': {'secret': true},
          },
        },
      });

      final scores =
          await extensions.debugHandleHostCall('getScores', {'operationUuid': operation.uuid, 'extensionKey': 'ki2d-contest-live-scoreboard'}) as Map;
      expect(scores.keys, ['ham2k-cwt', 'core']);
      expect(scores['ham2k-cwt'], {'contest': tally('contest', 1234)});
      expect(scores['core'], {'qsoCount': tally('qsoCount', 2)});
    });

    test('answers {} for an operation not scored yet, and skips a scorer that summed up nothing', () async {
      final fresh = await operations.create(stationCall: 'N0DEV');
      expect(await extensions.debugHandleHostCall('getScores', {'operationUuid': fresh.uuid}), isEmpty);

      final partial = await operations.create(stationCall: 'N0DEV');
      await operations.updateLocalData(partial.uuid, {
        'scoring': {
          'core': {'operationSummary': null},
          // The flat shape an older cache can still hold, which is no scorer.
          'daySections': const [],
          'operationSummary': {'qsoCount': tally('qsoCount', 2)},
        },
      });
      expect(await extensions.debugHandleHostCall('getScores', {'operationUuid': partial.uuid}), isEmpty);
    });

    test('answers null, as getQsos does, for an unknown operation or a host with no log', () async {
      expect(await extensions.debugHandleHostCall('getScores', {'operationUuid': 'no-such-operation'}), isNull);
      expect(await extensions.debugHandleHostCall('getQsos', {'operationUuid': 'no-such-operation'}), isNull);
      expect(await ExtensionService().debugHandleHostCall('getScores', {'operationUuid': 'anything'}), isNull);
    });

    test('refuses a call without an operation uuid, naming what it wanted', () async {
      expect(
        () => extensions.debugHandleHostCall('getScores', {
          'operationUuid': {'uuid': 'x'},
        }),
        throwsA(isA<ExtensionHostException>().having((error) => error.toString(), 'message', contains('operationUuid'))),
      );
    });
  });

  group('through the runtime', () {
    test('reaches an extension through ctx.getScores', () async {
      final runtime = ExtensionService();
      final harness = await makeHaLoServices(extensions: runtime);
      runtime
        ..operations = harness.services.operations
        ..qsos = harness.services.qsos;
      await startWithShippedExtensions(runtime);
      await runtime.host!.reloadBundle(ExtensionBundle(key: 'dev-scores', source: _probe, api: 28));
      final operation = await harness.services.operations.create(stationCall: 'KI2D');
      await harness.services.operations.updateLocalData(operation.uuid, {
        'scoring': {
          'ham2k-cwt': {
            'operationSummary': {'contest': tally('contest', 77)},
          },
        },
      });

      final read = await runtime.host!.invokeHook('bench', key: 'dev-scores', method: 'read', args: {'operationUuid': operation.uuid});
      expect(read, {
        'scores': {
          'ham2k-cwt': {'contest': tally('contest', 77)},
        },
      });
      final unknown = await runtime.host!.invokeHook('bench', key: 'dev-scores', method: 'read', args: {'operationUuid': 'no-such-operation'});
      expect(unknown, {'scores': null});
    });
  });
}
