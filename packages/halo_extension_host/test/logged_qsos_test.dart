// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A full rescore names the contacts it read (`qsoUuids`) and the kernel folds
// them from its copy of the log (`withLoggedQsos`). The traps: folding what
// the copy holds rather than what was named — a contact logged since would be
// folded here, then replayed by the next pass and counted twice — and folding
// an empty log when the copy cannot be read, whose zero totals would replace
// the operation's cached score.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Map<String, dynamic> qso(int i, String call) => {
    'uuid': 'q$i',
    'startAtMillis': DateTime.utc(2026, 3, 28, 12, i).millisecondsSinceEpoch,
    'band': '20m',
    'mode': 'CW',
    'our': {'call': 'N0DEV'},
    'their': {'call': call},
  };
  const contest = {'type': 'k2hrcCqww', 'mode': 'CW'};
  final log = [qso(0, 'W1AW'), qso(1, 'K1ABC'), qso(2, 'N0DEV')];

  Future<ExtensionHost> start(Object? Function(Map<String, dynamic> params) changes) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'k2hrc-cqww', source: bundleSource('k2hrc-cqww'))],
      onHostCall: (method, params) async => method == 'getQsoChanges' ? changes(params) : null,
    );
    addTearDown(host.dispose);
    return host;
  }

  Future<Object?> fold(ExtensionHost host, List<String> uuids) => host.invokeHook(
    'scoring',
    key: 'k2hrc-cqww',
    method: 'scoreQsos',
    args: {
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [contest],
      },
      'qsoUuids': uuids,
      'ref': contest,
    },
    timeout: const Duration(seconds: 20),
  );

  test('a full pass folds exactly the contacts it names, not whatever the log holds by then', () async {
    final host = await start((_) => {'cursor': 'c', 'reset': true, 'qsos': log, 'removed': const <String>[], 'count': log.length});
    final result = (await fold(host, ['q0', 'q1'])) as Map;
    expect((result['qsoScores'] as Map).keys, unorderedEquals(['q0', 'q1']), reason: 'q2 was logged after the host read the log');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a log that cannot be read fails the pass instead of scoring it empty', () async {
    final host = await start((_) => null);
    await expectLater(fold(host, ['q0', 'q1']), throwsA(isA<ExtensionHostException>()));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
