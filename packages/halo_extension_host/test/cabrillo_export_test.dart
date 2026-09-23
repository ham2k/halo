// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest bundle does not carry a Cabrillo writer. It reaches for the
// kernel's — `__polo.sharedModules['@ham2k/lib-qson-cabrillo']` — and that seam
// is invisible to every test on either side of it:
//
//   * a node test in `extensions/` resolves the package from `node_modules`
//     like any import (`simple-contest/src/cabrillo.test.ts` says so itself),
//     so a kernel that shipped the package WITHOUT exposing the writer passes
//     there and writes an empty file in the field;
//   * a scorer test never exports at all.
//
// Only the real kernel, booted over the built bundles, joins the two. Hence
// this file: it exists for the seam, not for any one sponsor's layout. What a
// particular contest's header should say belongs with that contest.
//
// The seam is per-KERNEL, so one contest proves it. The sweep at the end is a
// second question — whether each bundle actually reaches the shared module —
// which a bundle that failed to import it would answer on its own.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// A QSO party operation: the one contest here whose Cabrillo needs a county
  /// on both ends, which makes it a fuller exercise of the writer than a
  /// contest whose exchange is a serial.
  Map<String, dynamic> qpOperation() => {
    'uuid': 'op-1',
    'stationCall': 'N0DEV',
    'grid': 'FN32',
    'refs': [
      {'type': 'qp', 'ref': 'NY', 'location': 'ALB'},
    ],
  };

  List<Map<String, dynamic>> qpQsos() => [
    {
      'uuid': 'q1',
      'their': {'call': 'W1AW'},
      'band': '40m',
      'mode': 'CW',
      'freq': 7035,
      'startAtMillis': DateTime.utc(2026, 10, 17, 14, 5).millisecondsSinceEpoch,
      'refs': [
        {'type': 'qp', 'location': 'ERI', 'ourSerial': '1', 'theirSerial': '7'},
      ],
    },
  ];

  Future<Map<String, dynamic>?> cabrilloFrom(String key, Map<String, dynamic> operation, List<Map<String, dynamic>> qsos) async {
    final host = await sharedHost([key]);
    final result =
        await host.invokeHook(
              'export',
              key: key,
              method: 'generateExport',
              args: {'operation': operation, 'qsos': qsos, 'exportType': '$key-cabrillo'},
              timeout: const Duration(seconds: 20),
            )
            as Map?;
    return result?.cast<String, dynamic>();
  }

  test('a contest Cabrillo is written through the kernel, not just the package', () async {
    final result = await cabrilloFrom('qp', qpOperation(), qpQsos());

    expect(result, isNotNull);
    final content = result!['content'] as String;
    expect(content, isNotEmpty, reason: 'an unreachable writer yields an empty file, not an error');

    final lines = content.trim().split('\n');
    // `START-OF-LOG` appears nowhere in the bundle — it comes from the shared
    // module, which is what makes these two lines the seam check rather than a
    // string the contest could have produced by itself.
    expect(lines.first, 'START-OF-LOG: 3.0');
    expect(lines.last, 'END-OF-LOG:');
    expect(lines, contains('CALLSIGN: N0DEV'));
    expect(lines.any((l) => l.startsWith('CONTEST: ')), isTrue, reason: "the sponsor's own contest name");

    // And the contact itself: a header with no QSO line is what a writer that
    // was handed the log but never walked it produces.
    final qsoLines = lines.where((l) => l.startsWith('QSO: ')).toList();
    expect(qsoLines, hasLength(1));
    expect(qsoLines.single, contains('W1AW'));
    expect(qsoLines.single, contains('ALB'), reason: 'the county we sent');
    expect(qsoLines.single, contains('ERI'), reason: 'and the one we received');
  }, timeout: const Timeout(Duration(seconds: 60)));

  /// Every other built-in that writes a Cabrillo, on a deliberately generic
  /// operation: enough to get a file out, never enough to pin a layout. A
  /// contest that needs more than this to export at all belongs in its own
  /// test, not here.
  ///
  /// The roster is the whole point, so it is derived from a rule rather than
  /// typed: every contest registering a `<key>-cabrillo` export type. The
  /// neighbouring `contest_export_test.dart` keeps a hand-written list of the
  /// same shape and says it has drifted twice — a contest added without being
  /// listed is a contest whose seam nobody checks.
  ///
  /// The value each one needs on its ref to export at all: an event key where
  /// it runs several, nothing where it runs one.
  const contests = {
    'cqww': '',
    'cqwpx': '',
    'arrl-dx': '',
    'naqp': '',
    'iaru-hf': '',
    'cwt': '',
    'simple-contest': '',
    'arrl-vhf-tests': 'ARRL-VHF-JUN',
    'stateparks': 'OHSP',
    'fd': '',
    'nrrl-nfd': '',
    'r1-fd': '',
  };

  Map<String, dynamic> genericOperation(String key, String event) => {
    'uuid': 'op-1',
    'stationCall': 'N0DEV',
    'grid': 'FN32',
    'refs': [
      {'type': key, 'mode': 'CW', 'exchange': '59 001', 'ourExchange': '59 001', 'ref': event, 'ourClass': '1D', 'ourSection': 'ENY'},
    ],
  };

  List<Map<String, dynamic>> genericQsos(String key) => [
    for (var i = 0; i < 3; i++)
      {
        'uuid': 'q$i',
        'our': {'call': 'N0DEV'},
        'their': {'call': 'W${i}AW', 'state': 'OH'},
        'band': '20m',
        'mode': 'CW',
        'freq': 14035,
        'startAtMillis': DateTime.utc(2026, 3, 28, 12, i).millisecondsSinceEpoch,
        'refs': [
          {'type': key, 'exchange': '59 00$i', 'theirZone': '5', 'theirExchange': 'MA', 'theirSerial': '$i', 'name': 'BOB', 'location': 'OH'},
        ],
      },
  ];

  contests.forEach((key, event) {
    test('$key reaches the shared Cabrillo writer', () async {
      final result = await cabrilloFrom(key, genericOperation(key, event), genericQsos(key));

      expect(result, isNotNull, reason: 'the export must return');
      final content = result!['content'] as String;
      expect(content, isNotEmpty, reason: 'a bundle that never reached the writer returns an empty file');
      expect(content.trim().split('\n').first, 'START-OF-LOG: 3.0');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('the roster above is every built-in that writes a Cabrillo', () async {
    // The list is hand-written, so this is what keeps it honest: a contest
    // registering a `-cabrillo` export type and missing from it would ship its
    // seam unchecked, which is exactly how the neighbouring file's own list
    // drifted twice.
    final sources = Directory('../../extensions/contests');
    final registered = <String>{};
    for (final dir in sources.listSync().whereType<Directory>()) {
      final index = File('${dir.path}/src/index.ts');
      if (!index.existsSync()) continue;
      if (index.readAsStringSync().contains('"cabrillo"')) registered.add(dir.path.split('/').last);
    }
    expect(registered.difference({...contests.keys, 'qp'}), isEmpty, reason: 'these write a Cabrillo and nothing here checks them');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
