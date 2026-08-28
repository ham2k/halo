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

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  // Every contest ships the same delegation, so every contest can recurse. The
  // list had drifted — iaru-hf and naqp shipped without being added, and this is
  // the only place the delegation is exercised at all.
  const contests = ['simple-contest', 'cqww', 'cqwpx', 'arrl-dx', 'iaru-hf', 'naqp', 'stateparks', 'cwt'];

  /// `ref` names WHICH event for a contest that has several (stateparks
  /// contributes nothing without one); the rest ignore the extra keys.
  ///
  /// `ourCategory`/`ourPower` are Ohio's entry class, and MPO with a declared HP
  /// is the awkward pair deliberately: MPO is one of the three categories whose
  /// own definition names neither a transmitter count nor a power, so it is the
  /// case where the Cabrillo must fall back to the declared class for one header
  /// and emit nothing at all for the other.
  Map<String, dynamic> operationFor(String key, {String event = 'OHSP'}) => {
        'uuid': 'op-1',
        'stationCall': 'N0DEV',
        'grid': 'EN91',
        'refs': [
          {
            'type': key,
            'mode': 'CW',
            'exchange': '59 001',
            'ref': event,
            'ourPark': 'HOC',
            'ourCategory': 'MPO',
            'ourPower': 'HP',
          },
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
      final host = await sharedHost(['adif', key]);
      // A generous ceiling: the point is that it RETURNS, not how fast. Before
      // the fix this hung until the host's own timeout.
      final result = await host.invokeHook(
        'export',
        key: key,
        method: 'generateExport',
        args: {
          // Texas, because Ohio is the one event that offers no contest ADIF at
          // all — the recursion this guards against lives in the shared
          // delegation, so exercise it on an operation that really reaches it.
          'operation': operationFor(key, event: 'TXSP'),
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
    // Its own host, not the loop's 'adif,cqwpx' one: both this and the loop
    // guard against a delegation recursion that HANGS, and a hung runtime
    // must not be inherited by whichever test runs next.
    final host = await sharedHost(['adif', 'cqwpx'], cacheKey: 'declines-unoffered');
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

  test('the state park setup form asks each event only what its sponsor uses', () async {
    // The fields are the operator-facing half of the same rules reading as the
    // export options above: a power class where it changes a score or a header,
    // an entry category only where the sponsor publishes one. Asserted through
    // the real runtime because the form is data the extension returns, and a
    // field that never renders is indistinguishable from one never asked for.
    final host = await sharedHost(['stateparks']);
    Future<List<String>> fieldsFor(String event) async {
      final controls = (await host.invokeHook(
        'activity',
        key: 'stateparks',
        method: 'operationControls',
        args: {'operation': operationFor('stateparks', event: event)},
        timeout: const Duration(seconds: 10),
      ) as List).cast<Map>();
      final form = (controls.single['input'] as Map)['form'] as Map;
      return [
        for (final element in (form['elements'] as List).cast<Map>())
          if (element['type'] == 'field') element['key'] as String,
      ];
    }

    // Ohio: the park we are in, its two power classes, its nine categories.
    expect(await fieldsFor('OHSP'), ['ref', 'ourPark', 'ourPower', 'ourCategory']);
    // Texas: power, because §6.3.4 pays for it. No exchange, so no park field.
    expect(await fieldsFor('TXSP'), ['ref', 'ourPower']);
    // Florida and Georgia publish power classes their sponsors take on a web
    // form and score nothing on, so there is nothing to ask here.
    expect(await fieldsFor('FLSP'), ['ref']);
    expect(await fieldsFor('GASP'), ['ref']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a state park event offers only the formats its own sponsor will read', () async {
    // Ohio refuses an ADIF in as many words — "No ADIF, no CSV, no Text files -
    // send in a standard Cabrillo file only" — so offering one is offering a file
    // that gets the log rejected. Texas requires the opposite (§8.2, upload an
    // ADIF), and takes no Cabrillo. polo offers a contest ADIF for all four.
    final host = await sharedHost(['stateparks']);
    Future<List<String>> typesFor(String event) async {
      final options = await host.invokeHook(
        'export',
        key: 'stateparks',
        method: 'suggestExportOptions',
        args: {'operation': operationFor('stateparks', event: event), 'qsos': qsosFor('stateparks')},
        timeout: const Duration(seconds: 10),
      ) as List?;
      return (options ?? []).map((o) => (o as Map)['exportType'] as String).toList();
    }

    expect(await typesFor('OHSP'), ['cabrillo']);
    expect(await typesFor('TXSP'), ['contest-adif']);
    expect(await typesFor('FLSP'), ['contest-adif']);
    expect(await typesFor('GASP'), ['contest-adif']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the Ohio State Parks Cabrillo is written the way the sponsor reads it', () async {
    // The only contest here whose Cabrillo has its own row layout — no signal
    // reports, a park column each side — and nothing executed it. A format the
    // sponsor's checker rejects is not a failure any unit test can see, so the
    // header block and one QSO line are pinned verbatim.
    final host = await sharedHost(['stateparks']);
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
    // The shared scheme (`exportFilename`), dated from the log's first QSO —
    // not the event key alone, which said nothing about which activation of
    // it this was.
    expect(result!['filename'], '2026-09-12 N0DEV for OHSP.log');
    final lines = (result['content'] as String).trim().split('\n');

    expect(lines.first, 'START-OF-LOG: 3.0');
    // The sponsor's own sample Cabrillo says OSPOTA — https://ospota.org/Files/OSPOTA_Sample-rev2.log
    // — and their checker is automated, so the event key (OHSP) and polo's
    // OHSPOTA are both wrong here.
    expect(lines, contains('CONTEST: OSPOTA'), reason: 'the sponsor’s own contest name, not the event key');
    expect(lines, contains('CALLSIGN: N0DEV'));
    expect(lines, contains('LOCATION: HOC'), reason: 'the park we are activating');
    expect(lines, contains('GRID-LOCATOR: EN91'));
    // The entry, which is what tells their automated checker which class it is
    // scoring — https://ospota.org/Files/OSPOTA_Sample-rev2.log names these four.
    expect(lines, contains('CATEGORY-OPERATOR: MPO'));
    expect(lines, contains('CATEGORY-POWER: HIGH'), reason: 'MPO names no power, so the declared class stands');
    expect(lines, contains('CATEGORY-MODE: MIXED'), reason: 'fixed in the sponsor’s own sample');
    // MPO's own definition settles the transmitter count even though its code
    // does not: "using only one transmitter operating at multiple Ohio State
    // Parks (one at a time)". Only INOH and OUT are left open by the rules, and
    // those emit no header at all rather than a guess.
    expect(lines, contains('CATEGORY-TRANSMITTER: SINGLE'));
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
