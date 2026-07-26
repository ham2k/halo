// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest's "Contest ADIF" export delegates the actual ADIF build to the core
// `adif` extension inside the runtime. That delegation used to go through
// `hooks.invokeAll`, which fans out to EVERY hook in the `export` category —
// including the calling contest's own `generateExport`, whose only guard was
// `exportType === 'cabrillo'`. So the delegated call re-entered the same hook,
// took the same branch, and delegated again, forever. Being await-based there
// was no stack overflow to stop it: the export simply never returned, the host
// timed out at 30s, and the single-threaded JS runtime spun in the meantime.
//
// Nothing caught it — the unit tests exercise the scorers, and hand-testing had
// only ever exported Cabrillo. It needs the REAL runtime with BOTH bundles
// loaded, because the recursion only exists once `adif` and a contest are
// registered in the same category of the same kernel.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

  // Every contest ships the same delegation, so every contest can recurse. The
  // list had drifted — iaru-hf and naqp shipped without being added, and this is
  // the only place the delegation is exercised at all.
  const contests = ['simple-contest', 'cqww', 'cqwpx', 'arrl-dx', 'iaru-hf', 'naqp', 'stateparks'];

  /// `ref` names WHICH event for a contest that has several (stateparks
  /// contributes nothing without one); the rest ignore the extra keys.
  Map<String, dynamic> operationFor(String key) => {
        'uuid': 'op-1',
        'stationCall': 'N0DEV',
        'grid': 'EN91',
        'refs': [
          {'type': key, 'mode': 'CW', 'exchange': '59 001', 'ref': 'OHSP', 'ourPark': 'HOC'},
        ],
      };

  List<Map<String, dynamic>> qsosFor(String key) => [
    for (var i = 0; i < 5; i++)
      {
        'uuid': 'q$i',
        'our': {'call': 'N0DEV'},
        'their': {'call': 'W${i}AW', 'state': 'OH'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': DateTime.utc(2026, 3, 28, 12, i).millisecondsSinceEpoch,
        'refs': [
          {'type': key, 'exchange': '59 00$i', 'theirZone': '5', 'theirExchange': 'MA', 'theirSerial': '$i', 'park': 'ADA'},
        ],
      },
  ];

  for (final key in contests) {
    test('$key: contest-adif export terminates and produces ADIF', () async {
      if (!bundle('kernel').existsSync() || !bundle(key).existsSync() || !bundle('adif').existsSync()) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }

      final host = await ExtensionHost.start(
        kernelSource: bundle('kernel').readAsStringSync(),
        extensions: [
          ExtensionBundle(key: 'adif', source: bundle('adif').readAsStringSync()),
          ExtensionBundle(key: key, source: bundle(key).readAsStringSync()),
        ],
      );
      addTearDown(host.dispose);

      // A generous ceiling: the point is that it RETURNS, not how fast. Before
      // the fix this hung until the host's own timeout.
      final result = await host.invokeHook(
        'export',
        key: key,
        method: 'generateExport',
        args: {
          'operation': operationFor(key),
          'qsos': qsosFor(key),
          'exportType': 'contest-adif',
        },
        timeout: const Duration(seconds: 10),
      ) as Map?;

      expect(result, isNotNull, reason: 'the export must return, not spin');
      final content = result!['content'] as String?;
      expect(content, isNotNull);
      expect(content, contains('<CALL:'), reason: 'delegation must reach the core adif exporter');
      expect(result['filename'], endsWith('.adi'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  test('a contest declines an exportType it never offered, rather than delegating', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqwpx').existsSync() || !bundle('adif').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [
        ExtensionBundle(key: 'adif', source: bundle('adif').readAsStringSync()),
        ExtensionBundle(key: 'cqwpx', source: bundle('cqwpx').readAsStringSync()),
      ],
    );
    addTearDown(host.dispose);

    // 'adif' is what the core exporter answers for — the contest must not treat
    // it as "anything that isn't cabrillo" and delegate, which is the branch
    // the recursion lived in.
    final result = await host.invokeHook(
      'export',
      key: 'cqwpx',
      method: 'generateExport',
      args: {
        'operation': operationFor('cqwpx'),
        'qsos': qsosFor('cqwpx'),
        'exportType': 'adif',
      },
      timeout: const Duration(seconds: 10),
    ) as Map?;

    expect(result, isNotNull);
    expect(result!['content'], isEmpty, reason: 'not an exportType this hook offers');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the Ohio State Parks Cabrillo is written the way the sponsor reads it', () async {
    if (!bundle('kernel').existsSync() || !bundle('stateparks').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    // The only contest here whose Cabrillo has its own row layout — no signal
    // reports, a park column each side — and nothing executed it. A format the
    // sponsor's checker rejects is not a failure any unit test can see, so the
    // header block and one QSO line are pinned verbatim.
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'stateparks', source: bundle('stateparks').readAsStringSync())],
    );
    addTearDown(host.dispose);

    final result = await host.invokeHook(
      'export',
      key: 'stateparks',
      method: 'generateExport',
      args: {
        'operation': operationFor('stateparks'),
        'qsos': [
          // Their park typed, as the exchange field writes it.
          {
            'uuid': 'q1',
            'their': {'call': 'W1AW'},
            'band': '40m',
            'mode': 'CW',
            'freq': 7035,
            'startAtMillis': DateTime.utc(2026, 9, 12, 14, 5).millisecondsSinceEpoch,
            'refs': [
              {'type': 'stateparks', 'park': 'ALU'},
            ],
          },
          // No park: a US station falls back to their state, per Ohio's rules.
          {
            'uuid': 'q2',
            'their': {'call': 'K2DEF', 'state': 'PA', 'entityPrefix': 'K'},
            'band': '40m',
            'mode': 'SSB',
            'freq': 7185,
            'startAtMillis': DateTime.utc(2026, 9, 12, 14, 9).millisecondsSinceEpoch,
          },
          // Not in the US at all, and not in a park: DX.
          {
            'uuid': 'q3',
            'their': {'call': 'DL1ABC', 'entityPrefix': 'DL'},
            'band': '20m',
            'mode': 'CW',
            'freq': 14035,
            'startAtMillis': DateTime.utc(2026, 9, 12, 15, 0).millisecondsSinceEpoch,
          },
        ],
        'exportType': 'cabrillo',
      },
      timeout: const Duration(seconds: 10),
    ) as Map?;

    expect(result, isNotNull);
    expect(result!['filename'], 'OHSP-N0DEV.log');
    final lines = (result['content'] as String).trim().split('\n');

    expect(lines.first, 'START-OF-LOG: 3.0');
    expect(lines, contains('CONTEST: OHSPOTA'), reason: 'the sponsor’s own contest name, not the event key');
    expect(lines, contains('CALLSIGN: N0DEV'));
    expect(lines, contains('LOCATION: HOC'), reason: 'the park we are activating');
    expect(lines, contains('GRID-LOCATOR: EN91'));
    expect(lines.last, 'END-OF-LOG:');

    final qsoLines = lines.where((l) => l.startsWith('QSO:')).toList();
    expect(qsoLines, hasLength(3));
    // Frequency, mode, date, time, then our call / our park / their call / their
    // park — column widths included, since a fixed-width format is the point.
    expect(
      qsoLines[0],
      'QSO: 7035  CW 2026-09-12 1405 N0DEV              HOC          W1AW              ALU         ',
    );
    expect(qsoLines[1], contains('PA'), reason: 'no park, so their state stands in');
    expect(qsoLines[1], contains('PH'), reason: 'Cabrillo collapses SSB to PH');
    expect(qsoLines[2], contains('DX'), reason: 'and a non-US station with no park is DX');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
