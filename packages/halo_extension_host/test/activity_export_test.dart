// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Activate two parks at once and you owe the program two logs, one claiming
// each (docs/design/activities.md §3.2). This is a different axis from
// nfer_export_test.dart's split: that one multiplies RECORDS within a file by
// the parks the other station was at; this one multiplies FILES by the parks
// you were at.
//
// Driven through the real runtime with both bundles, because the whole
// mechanism is `exportType` round-tripping through the core and the activity
// delegating back to the `adif` extension inside the same kernel — a stub would
// prove neither.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Map<String, dynamic> operation(List<String> parks) => {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'title': 'Park run',
        'refs': [for (final park in parks) {'type': 'potaActivation', 'ref': park}],
      };

  final qsos = [
    for (var i = 0; i < 3; i++)
      {
        'uuid': 'q$i',
        'our': {'call': 'N0DEV', 'sent': '59'},
        'their': {'call': 'W${i}ABC', 'sent': '59'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': DateTime.utc(2026, 7, 1, 12, i).millisecondsSinceEpoch,
      },
  ];

  Future<ExtensionHost> startHost() => sharedHost(['adif', 'pota']);

  test('activating two parks offers one export per park', () async {
    final host = await startHost();
    final options = (await host.invokeHook(
      'export',
      key: 'pota',
      method: 'suggestExportOptions',
      args: {'operation': operation(['US-0001', 'US-0002']), 'qsos': qsos},
      timeout: const Duration(seconds: 20),
    ) as List).cast<Map>();

    expect(options.length, 2);
    // The FORMAT leads the label: a park activated on a contest weekend
    // offers several files for the same reference, and the reference alone
    // said nothing about which of them a row was.
    expect(options.map((o) => o['label']), ['ADIF for POTA US-0001', 'ADIF for POTA US-0002']);
    // The exportType carries which park, since that is all the core gives back.
    expect(options.map((o) => o['exportType']), ['pota-adif:US-0001', 'pota-adif:US-0002']);
    // Distinct filenames, so two selected exports don't collide on disk.
    expect(options[0]['filename'], isNot(options[1]['filename']));
    // Declared so the core slices to segments where POTA was actually running.
    expect(options.every((o) => o['refType'] == 'potaActivation'), isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('each file claims only its own park', () async {
    final host = await startHost();

    Future<String> generate(String exportType) async {
      final result = await host.invokeHook(
        'export',
        key: 'pota',
        method: 'generateExport',
        args: {
          'operation': operation(['US-0001', 'US-0002']),
          'qsos': qsos,
          'exportType': exportType,
        },
        timeout: const Duration(seconds: 20),
      ) as Map;
      return result['content'] as String;
    }

    final first = await generate('pota-adif:US-0001');
    final second = await generate('pota-adif:US-0002');

    // Each file names its own park and does NOT mention the other — that is
    // what makes it separately submittable.
    expect(first, contains('<MY_POTA_REF:7>US-0001'));
    expect(first, isNot(contains('US-0002')));
    expect(second, contains('<MY_POTA_REF:7>US-0002'));
    expect(second, isNot(contains('US-0001')));

    // Same contacts in both: you submit the whole log to each park.
    for (final content in [first, second]) {
      expect('<EOR>'.allMatches(content).length, 3);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an operation activating nothing offers no activity export', () async {
    final host = await startHost();
    final options = await host.invokeHook(
      'export',
      key: 'pota',
      method: 'suggestExportOptions',
      args: {'operation': operation([]), 'qsos': qsos},
      timeout: const Duration(seconds: 20),
    ) as List;

    // A pure hunting log is the plain ADIF export's business.
    expect(options, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a park removed since the panel listed it is refused, not exported empty', () async {
    final host = await startHost();
    // The option list and the export run are read at different moments. Without
    // a guard this filters every activation ref away and produces a valid ADIF
    // claiming no park at all — which looks submittable and isn't.
    await expectLater(
      host.invokeHook(
        'export',
        key: 'pota',
        method: 'generateExport',
        args: {
          'operation': operation(['US-0001']),
          'qsos': qsos,
          'exportType': 'pota-adif:US-0002',
        },
        timeout: const Duration(seconds: 20),
      ),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an exportType it never offered is refused, not delegated', () async {
    final host = await startHost();
    // The delegation to `adif` fans back through the export category; a hook
    // that answered for 'adif' here would delegate to itself and hang the
    // export rather than fail (see contest_export_test.dart).
    await expectLater(
      host.invokeHook(
        'export',
        key: 'pota',
        method: 'generateExport',
        args: {'operation': operation(['US-0001']), 'qsos': qsos, 'exportType': 'adif'},
        timeout: const Duration(seconds: 20),
      ),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The private-data setting reaches the ADIF generator only if the activity
  // FORWARDS it across the delegation. Nothing about the option listing shows
  // whether it did, so this is the only place a dropped forward would be
  // caught — and dropping it would silently leak the operator's notes into
  // every uploaded park log, or silently strip them when asked not to.
  test('an activity export forwards the private-data flag to the ADIF it delegates to', () async {
    final host = await startHost();

    Future<String> adifFor({required bool includePrivateData}) async {
      final result = await host.invokeHook(
        'export',
        key: 'pota',
        method: 'generateExport',
        args: {
          'operation': operation(['US-0001']),
          'qsos': [
            {
              ...qsos.first,
              'their': {'call': 'W0ABC', 'sent': '59', 'name': 'Alice', 'city': 'Dayton', 'grid': 'EM79'},
              'notes': 'met at Hamvention',
            },
          ],
          'exportType': 'pota-adif:US-0001',
          'includePrivateData': includePrivateData,
        },
        timeout: const Duration(seconds: 20),
      ) as Map;
      return result['content'] as String;
    }

    final withheld = await adifFor(includePrivateData: false);
    expect(withheld, contains('<CALL:5>W0ABC'), reason: 'the contact itself is always there');
    for (final private in ['Alice', 'Dayton', 'EM79', 'Hamvention']) {
      expect(withheld, isNot(contains(private)), reason: '$private is the operator\'s own note');
    }

    final released = await adifFor(includePrivateData: true);
    for (final private in ['Alice', 'Dayton', 'EM79', 'Hamvention']) {
      expect(released, contains(private));
    }

    // The operation's own title is the operator's words too, and it sits in
    // the preamble rather than in a QSO record — so it needs gating in its
    // own right, or the switch strips every field a program might read while
    // still shipping the one line the operator wrote.
    expect(withheld, isNot(contains('Park run')));
    expect(released, contains('Park run'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Coordinates are a sharper statement of the same thing GRIDSQUARE gates —
  // the station's position to a few hundred metres rather than a few
  // kilometres — and MY_LAT is the operator's own address. A file uploaded to
  // a program's servers carries neither unless the operator asked for it, and
  // the format is ADIF's own degrees-and-decimal-minutes, not the signed
  // degrees QSON stores.
  test('coordinates are written in the ADIF Location format, and only with private data released', () async {
    final host = await startHost();

    Future<String> adifFor({required bool includePrivateData}) async {
      final result = await host.invokeHook(
        'export',
        key: 'adif',
        method: 'generateExport',
        args: {
          'operation': {...operation(['US-0001']), 'grid': 'FN21rq56', 'lat': 41.6875, 'lon': -74.45},
          'qsos': [
            {
              ...qsos.first,
              'their': {
                'call': 'W0ABC',
                'sent': '59',
                'guess': {'lat': -33.86, 'lon': 151.21},
              },
            },
          ],
          'exportType': 'adif',
          'includePrivateData': includePrivateData,
        },
        timeout: const Duration(seconds: 20),
      ) as Map;
      return result['content'] as String;
    }

    final withheld = await adifFor(includePrivateData: false);
    expect(withheld, contains('<CALL:5>W0ABC'), reason: 'the contact itself is always there');
    for (final tag in ['<LAT:', '<LON:', '<MY_LAT:', '<MY_LON:']) {
      expect(withheld, isNot(contains(tag)));
    }
    // Our own square always ships — award programs read it — but cut back to
    // six characters. The operation stores eight (it was set from a fix), and
    // writing those verbatim would state the position to a few hundred metres
    // through the same switch that is withholding the coordinate itself.
    expect(withheld, contains('<MY_GRIDSQUARE:6>FN21rq'));
    expect(withheld, isNot(contains('FN21rq56')));

    final released = await adifFor(includePrivateData: true);
    // The lookup knew where W0ABC was; the operation knows where we were.
    expect(released, contains('S033 51.600'), reason: 'a southern latitude keeps its own hemisphere letter');
    expect(released, contains('E151 12.600'));
    expect(released, contains('N041 41.250'));
    expect(released, contains('W074 27.000'));
    expect(released, contains('<MY_GRIDSQUARE:8>FN21rq56'), reason: 'released, the finer locator goes out whole');
    // The stored value must not reach the file as-is: a reader taking
    // `-74.45` as ADIF's `XDDD MM.MMM` gets a different place entirely.
    expect(released, isNot(contains('-74.45')));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
