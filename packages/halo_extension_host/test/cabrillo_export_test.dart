// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest bundle does not carry a Cabrillo writer. It reaches for the
// kernel's — `__polo.sharedModules['@ham2k/lib-qson-cabrillo']` — and that seam
// is invisible to every test on either side of it:
//
//   * a node test of a contest resolves the package from `node_modules` like
//     any import, so a kernel that shipped the package WITHOUT exposing the
//     writer passes there and writes an empty file in the field;
//   * a scorer test never exports at all.
//
// Only the real kernel joins the two. Hence this file: it exists for the seam,
// not for any one sponsor's layout. What a particular contest's header should
// say belongs with that contest.
//
// The seam is per-KERNEL, so one bundle proves it. The one here is written in
// the test, reaching for the module exactly the way a built bundle's shim
// does, so the check does not depend on which contests the app pre-loads.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// A contest export in miniature: its Cabrillo comes entirely from the
/// kernel's shared writer, with this extension supplying only the header
/// values and each QSO line's exchange columns.
const _contestSource = '''
__polo.defineExtension({
  key: 'cabrillo-contest',
  name: 'Cabrillo Contest',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('export', { key: 'cabrillo-contest', hook: {
      generateExport: async function (args) {
        var writer = __polo.sharedModules['@ham2k/lib-qson-cabrillo']
        var ours = (args.operation.refs || [])[0] || {}
        var content = writer.qsonToCabrillo(args.qsos, {
          headers: [['CONTEST', 'TEST-QP'], ['CALLSIGN', args.operation.stationCall]],
          qsoParts: function (qso) {
            var theirs = (qso.refs || [])[0] || {}
            return [args.operation.stationCall, ours.location, qso.their.call, theirs.location]
          },
        })
        return { filename: 'test.log', mimeType: 'text/plain', content: content }
      },
    }})
  },
})
''';

void main() {
  requireBundles();

  test('a contest Cabrillo is written through the kernel, not just the package', () async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: const [ExtensionBundle(key: 'cabrillo-contest', source: _contestSource)],
      onHostCall: nullHostCall,
    );
    addTearDown(host.dispose);

    final result =
        await host.invokeHook(
              'export',
              key: 'cabrillo-contest',
              method: 'generateExport',
              args: {
                'operation': {
                  'uuid': 'op-1',
                  'stationCall': 'N0DEV',
                  'refs': [
                    {'type': 'cabrillo-contest', 'location': 'ALB'},
                  ],
                },
                'qsos': [
                  {
                    'uuid': 'q1',
                    'their': {'call': 'W1AW'},
                    'band': '40m',
                    'mode': 'CW',
                    'freq': 7035,
                    'startAtMillis': DateTime.utc(2026, 10, 17, 14, 5).millisecondsSinceEpoch,
                    'refs': [
                      {'type': 'cabrillo-contest', 'location': 'ERI'},
                    ],
                  },
                ],
                'exportType': 'cabrillo-contest-cabrillo',
              },
              timeout: const Duration(seconds: 20),
            )
            as Map?;

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
    expect(lines, contains('CONTEST: TEST-QP'));

    // And the contact itself: a header with no QSO line is what a writer that
    // was handed the log but never walked it produces.
    final qsoLines = lines.where((l) => l.startsWith('QSO: ')).toList();
    expect(qsoLines, hasLength(1));
    expect(qsoLines.single, startsWith('QSO: 7035  CW 2026-10-17 1405 '), reason: 'the writer\'s own frequency, mode and time columns');
    expect(qsoLines.single, contains('W1AW'));
    expect(qsoLines.single, contains('ALB'), reason: 'the exchange we sent');
    expect(qsoLines.single, contains('ERI'), reason: 'and the one we received');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
