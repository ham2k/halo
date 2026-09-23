// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The held checkpoint and the copy-on-write view, on the REAL engine. The SDK's
// own tests prove both under node; what only this can prove is that QuickJS
// runs the Proxy the same way (an engine's Proxy invariants, array methods
// through traps) and that a `resume-missing` thrown in the sandbox reaches
// the Dart caller as the exception the host answers.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  late ExtensionHost host;
  const operation = {'uuid': 'op-1', 'stationCall': 'N0DEV'};

  Map<String, dynamic> qso(String call, {String band = '20m'}) => {
    'uuid': '$call-$band',
    'our': {'call': 'N0DEV'},
    'their': {'call': call},
    'band': band,
    'mode': 'SSB',
    'startAtMillis': DateTime.utc(2026, 7, 5, 12).millisecondsSinceEpoch,
  };

  setUpAll(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'scoring', source: bundleSource('scoring'))],
      useIsolate: false,
    );
  });
  tearDownAll(() => host.dispose());

  Future<dynamic> core(String method, Map<String, dynamic> args) =>
      host.invokeHook('scoring', key: 'core', method: method, args: args, timeout: const Duration(seconds: 20));

  test('a pass names its checkpoint, and a board named the checkpoint is judged through views on the engine', () async {
    final folded =
        await core('scoreQsos', {
              'operation': operation,
              'qsos': [qso('W1AW')],
              'checkpointKey': 'k1',
            })
            as Map;
    expect(folded['checkpointHeld'], isTrue);

    // Two spots for one unworked call, and one for a worked one: through
    // the views, the first spot never makes the second a duplicate, and the
    // worked one is one — the same verdicts node gives, now from QuickJS.
    final board =
        await core('scoreCandidates', {
              'operation': operation,
              'resumeKey': 'k1',
              'candidates': [
                {'key': 'a', 'qso': qso('K1ABC')},
                {'key': 'b', 'qso': qso('K1ABC')},
                {'key': 'c', 'qso': qso('W1AW')},
              ],
            })
            as Map;
    expect((board['a'] as Map)['alerts'], isEmpty);
    expect((board['b'] as Map)['alerts'], isEmpty, reason: 'the first candidate leaked into the second');
    expect((board['c'] as Map)['alerts'], contains('duplicate'));
    expect(board['\$checkpointHeld'], isTrue);

    // And the held sheet itself took none of it.
    final again = await core('scoreQso', {'operation': operation, 'resumeKey': 'k1', 'qso': qso('K1ABC')}) as Map;
    expect(again['alerts'], isEmpty, reason: 'a candidate scored on the board entered the held checkpoint');
    expect(again['checkpointHeld'], isTrue);
  });

  test('a checkpoint the engine does not hold is refused as resume-missing, all the way to Dart', () async {
    await expectLater(
      core('scoreQso', {'operation': operation, 'resumeKey': 'never-sent', 'qso': qso('W1AW')}),
      throwsA(isA<ExtensionHostException>().having((e) => e.message, 'message', startsWith('resume-missing'))),
    );
  });
}
