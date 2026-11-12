// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ctx.findCalls` and `ctx.scoreCandidates` through the real runtime. The
// trap is the second: answering it runs the scorers, in the same runtime
// whose hook is waiting on the answer, so a runtime that served one hook
// call at a time would hang here rather than in a unit test of either half.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

const _probe = '''
(function () {
'use strict'
__halo.defineExtension({
  key: 'dev-partial-probe',
  name: 'Partial calls probe',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: 'dev-partial-probe', hook: {
      check: async function (args, ctx) {
        var found = await ctx.findCalls(args.call)
        var candidates = {}
        found.forEach(function (f) { candidates[f.call] = { their: { call: f.call.toLowerCase() }, band: '20m', mode: 'CW' } })
        return { found: found, verdicts: await ctx.scoreCandidates(candidates) }
      },
    }})
  },
})
})()
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late HaLoHarness harness;
  late Operation operation;

  setUp(() async {
    extensions = ExtensionService();
    harness = await makeHaLoServices(extensions: extensions);
    extensions
      ..operations = harness.services.operations
      ..qsos = harness.services.qsos;
    await startWithShippedExtensions(extensions);
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'dev-partial-probe', source: _probe, api: 25));
    operation = await harness.services.operations.create(stationCall: 'KI2D');
    // The operation in front, as operation_view.dart answers for it.
    extensions.onScoreCandidates = (candidates, operationUuid) async {
      if (operationUuid != operation.uuid) return null;
      return extensions.scoreCandidates(operation: operation.data, operationUuid: operation.uuid, candidates: candidates);
    };
  });

  test('a hook finds the calls the text could be and learns which are duplicates, from the scorers in its own runtime', () async {
    await harness.services.qsos.add(operation.uuid, {
      'their': {'call': 'K1AB'},
      'band': '20m',
      'mode': 'CW',
      'startAtMillis': 1000,
    });
    await harness.services.qsos.add(operation.uuid, {
      'their': {'call': 'K1AC'},
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    final result =
        (await extensions.host!.invokeHook(
                  'bench',
                  key: 'dev-partial-probe',
                  method: 'check',
                  args: {
                    'call': 'K1AB',
                    'operation': {...operation.data, 'uuid': operation.uuid},
                  },
                )
                as Map)
            .cast<String, dynamic>();

    expect([for (final found in (result['found'] as List).cast<Map<dynamic, dynamic>>()) '${found['call']}:${found['match']}'], ['K1AB:exact', 'K1AC:oneEdit']);
    final verdicts = (result['verdicts'] as Map).cast<String, dynamic>();
    bool duplicate(String call) => [...?(verdicts[call] as Map?)?['notices'] as List?, ...?(verdicts[call] as Map?)?['alerts'] as List?].contains('duplicate');
    expect(duplicate('K1AB'), isTrue, reason: 'worked on 20m CW already, though asked about in lowercase, which no scorer keys its log by');
    expect(duplicate('K1AC'), isFalse, reason: 'worked on 40m only, and asked about 20m');
  });
}
