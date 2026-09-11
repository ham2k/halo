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
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// Hoisted so the shared host is reused rather than rebooted per call — a new
/// closure each time is a new cache key (support/bundles.dart).
Future<Object?> _noBirds(String method, Map<String, dynamic> params) async =>
    method == 'dbLookupSelectAll' ? const [] : null;

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

  // A file uploaded to POTA is POTA's log. Activate a park that is also a
  // lighthouse and an export that asks every `adifFields` hook writes both
  // programs' MY_SIG pairs into every record — two SIG claims in one file,
  // leaving the receiving program to guess which is its. The core exporter
  // asks the hook whose export this IS and no other (`ExportRequest.
  // mainHandler`, app-polo's main handler).
  test('a POTA file carries no other program\'s fields, activated or hunted', () async {
    final host = await sharedHost(['adif', 'pota', 'llota']);
    final result = await host.invokeHook(
      'export',
      key: 'pota',
      method: 'generateExport',
      args: {
        'operation': {
          ...operation(['US-0001']),
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
            {'type': 'llotaActivation', 'ref': 'LLUS-0787'},
          ],
        },
        'qsos': [
          {
            ...qsos.first,
            'refs': [
              {'type': 'pota', 'ref': 'US-9001'},
              {'type': 'llota', 'ref': 'LLUS-9002'},
            ],
          },
        ],
        'exportType': 'pota-adif:US-0001',
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    expect(content, contains('<MY_SIG:4>POTA'));
    expect(content, contains('<MY_POTA_REF:7>US-0001'));
    expect(content, contains('<SIG_INFO:7>US-9001'));
    // Not merely "no MY_SIG:LLOTA" — the lighthouse must leave no trace at
    // all, on either side of the contact.
    expect(content, isNot(contains('LLOTA')));
    expect(content, isNot(contains('LLUS-0787')));
    expect(content, isNot(contains('LLUS-9002')));
    // One claim per record, not two.
    expect('<MY_SIG:'.allMatches(content).length, 1);
    // The free-text fields are the half of a record `mainHandler` does not
    // govern, and QSLMSG's default is the operation's whole reference list —
    // every program it claimed, in a field no hook filtered.
    expect(content, isNot(contains('QSLMSG')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The main handler's key lives in two places — the `adifFields` registration
  // and the export that names itself — and nothing but a matching string keeps
  // them together. A rename on one side alone would otherwise write a file with
  // no program fields at all: valid ADIF, claiming nothing, and indistinguishable
  // from a good one until the program rejects the upload.
  //
  // The GENERATOR is what this pins, called the way a delegating export calls
  // it. What the delegating export then does with the failure — the runtime
  // hands it back as a not-ok entry, and `adifForExport` turns that into a
  // throw rather than a 0-byte file under the log's own name — has no fixture
  // that can break a real extension's key, so it rests on that one line.
  test('a main handler with no adifFields hook fails the export, not the log', () async {
    final host = await startHost();
    await expectLater(
      host.invokeHook(
        'export',
        key: 'adif',
        method: 'generateExport',
        args: {
          'operation': operation(['US-0001']),
          'qsos': qsos,
          'exportType': 'adif',
          'mainHandler': 'pota-typo',
        },
        timeout: const Duration(seconds: 20),
      ),
      throwsA(predicate((e) => '$e'.contains('pota-typo'))),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  // What DESCRIBES a contact is not what CLAIMS it. A park worked through a
  // satellite is still a park activation and POTA's uploader reads
  // PROP_MODE/SAT_NAME, so POTA lists `satellites` in `includeFieldsFrom` —
  // narrowing polo's all-or-nothing `includeOtherRefs` to what the program
  // itself says it accepts. A rival program's claim still stays out.
  test('a POTA file carries the satellite fields POTA asked for, and nothing else', () async {
    // The satellites hook reads its bird table through the host on every
    // export; without an answer it throws, the whole hook's fields are lost,
    // and this test would pass or fail on the harness rather than the
    // whitelist. An empty table is enough — BAND_RX is the only field that
    // needs a match in it.
    final host = await sharedHost(
      ['adif', 'pota', 'satellites', 'llota'],
      cacheKey: 'sat-birds-empty',
      onHostCall: _noBirds,
    );
    final result = await host.invokeHook(
      'export',
      key: 'pota',
      method: 'generateExport',
      args: {
        'operation': {
          ...operation(['US-0001']),
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
            {'type': 'llotaActivation', 'ref': 'LLUS-0787'},
          ],
        },
        'qsos': [
          {
            ...qsos.first,
            'refs': [{'type': 'satellite', 'ref': 'SO-50'}],
          },
        ],
        'exportType': 'pota-adif:US-0001',
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    expect(content, contains('<MY_POTA_REF:7>US-0001'));
    expect(content, contains('<PROP_MODE:3>SAT'));
    expect(content, contains('<SAT_NAME:5>SO-50'));
    // The whitelist is a list, not a door: the lighthouse is not on it.
    expect(content, isNot(contains('LLOTA')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The other half of the same claim: a hook that THREW answers the call, so a
  // guard counting answers would wave it through and write the same
  // reference-less file. `satellites` is the real case — its hook reads the
  // bird table through the host on every contact, so it fails on a bad day
  // rather than on a bad build, and this host deliberately answers nothing.
  //
  // A LISTED hook that throws is refused on the same terms, and this is where
  // the two tolerances part: a listed extension that is turned off answers
  // nothing and is fine, while one that answers and fails would otherwise cost
  // POTA's file its satellite fields in silence — the contact recorded as
  // terrestrial, the upload clean.
  test('a hook that throws fails the export, main handler or listed', () async {
    final host = await sharedHost(['adif', 'pota', 'satellites'], cacheKey: 'no-host-answers');
    await expectLater(
      host.invokeHook(
        'export',
        key: 'pota',
        method: 'generateExport',
        args: {
          'operation': operation(['US-0001']),
          'qsos': [
            {...qsos.first, 'refs': [{'type': 'satellite', 'ref': 'SO-50'}]},
          ],
          'exportType': 'pota-adif:US-0001',
        },
        timeout: const Duration(seconds: 20),
      ),
      // The KEY has to reach the operator: the export panel shows this string
      // and nothing else says which extension went wrong.
      throwsA(predicate((e) => '$e'.contains('satellites'))),
      reason: 'POTA lists satellites, and its hook cannot read its table here',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a main handler whose hook throws fails the export too', () async {
    final host = await sharedHost(['adif', 'satellites'], cacheKey: 'no-host-answers');
    await expectLater(
      host.invokeHook(
        'export',
        key: 'adif',
        method: 'generateExport',
        args: {
          'operation': operation([]),
          'qsos': [
            {...qsos.first, 'refs': [{'type': 'satellite', 'ref': 'SO-50'}]},
          ],
          'exportType': 'adif',
          'mainHandler': 'satellites',
        },
        timeout: const Duration(seconds: 20),
      ),
      throwsA(predicate((e) => '$e'.contains('satellites'))),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The mirror of the narrowing test above, on the same fixture: the FULL ADIF
  // export names no main handler and every hook contributes, which is what
  // makes it the complete copy the operator keeps. Requiring `mainHandler`,
  // defaulting it, or dropping the `invokeAll` branch would quietly turn that
  // file single-program, and nothing else would notice.
  test('the full ADIF export asks every hook, and a shared field is written once', () async {
    final host = await sharedHost(['adif', 'pota', 'llota']);
    final result = await host.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': {
          ...operation(['US-0001']),
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
            {'type': 'llotaActivation', 'ref': 'LLUS-0787'},
          ],
        },
        'qsos': [qsos.first],
        'exportType': 'adif',
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    // Both hooks ran: the lighthouse's own field is in the record next to the
    // park's, which is what "every hook contributes" buys.
    expect(content, contains('<MY_POTA_REF:7>US-0001'));
    expect(content, contains('<MY_LLOTA_REF:9>LLUS-0787'));
    // MY_SIG they BOTH answer, and ADIF gives no meaning to a field written
    // twice in one record — so the first hook asked keeps it, whole: the pair
    // that lands must be one program's, never POTA's name against the
    // lighthouse's reference.
    expect('<MY_SIG:'.allMatches(content).length, 1);
    expect(content, contains('<MY_SIG:4>POTA <MY_SIG_INFO:7>US-0001'));
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
    // A second host only for the eight-character case: the operator's Grid
    // Precision reaches the exporter through `getSettings`, and the kernel
    // caches that answer, so the two precisions cannot share one.
    final host = await startHost();
    final fineHost = await sharedHost(
      ['adif', 'pota'],
      cacheKey: 'grid-precision-eight',
      onHostCall: (method, params) async => method == 'getSettings' ? {'gridPrecision': 8} : null,
    );

    Future<String> adifFor({required bool includePrivateData, ExtensionHost? from}) async {
      final result = await (from ?? host).invokeHook(
        'export',
        key: 'adif',
        method: 'generateExport',
        args: {
          // Grid and coordinate agree: 41.6875 / -74.45 IS the fix FN21sq55
          // was derived from. A fixture whose two halves named different
          // squares would make this test pass or fail on which of them the
          // exporter happened to read, which is the very question it is not
          // about.
          'operation': {...operation(['US-0001']), 'grid': 'FN21sq55', 'lat': 41.6875, 'lon': -74.45},
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
    expect(withheld, contains('<MY_GRIDSQUARE:6>FN21sq'));
    expect(withheld, isNot(contains('FN21sq55')));

    final released = await adifFor(includePrivateData: true);
    // The lookup knew where W0ABC was; the operation knows where we were.
    expect(released, contains('S033 51.600'), reason: 'a southern latitude keeps its own hemisphere letter');
    expect(released, contains('E151 12.600'));
    expect(released, contains('N041 41.250'));
    expect(released, contains('W074 27.000'));
    // Six even with private data released, because that is the claim this
    // operator makes everywhere else: the setting decides how finely the app
    // SPEAKS about a location, and a file must not say more than the screen.
    expect(released, contains('<MY_GRIDSQUARE:6>FN21sq'));
    expect(released, isNot(contains('FN21sq55')));

    final fine = await adifFor(includePrivateData: true, from: fineHost);
    expect(fine, contains('<MY_GRIDSQUARE:8>FN21sq55'),
        reason: 'asked for eight AND released, the finer locator goes out whole');
    // The privacy rule is the ceiling, not the setting: eight characters is a
    // ~700 x 460 m square, and shipping it through the very switch that
    // withholds the coordinate it came from would defeat that switch.
    final fineWithheld = await adifFor(includePrivateData: false, from: fineHost);
    expect(fineWithheld, contains('<MY_GRIDSQUARE:6>FN21sq'));
    expect(fineWithheld, isNot(contains('FN21sq55')));
    // The stored value must not reach the file as-is: a reader taking
    // `-74.45` as ADIF's `XDDD MM.MMM` gets a different place entirely.
    expect(released, isNot(contains('-74.45')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // A locator the operator STATED is a square, and the app stores that
  // square's own center beside it so everything that measures has a
  // coordinate (docs/design/locations.md). A file must not restate that
  // centre as `LAT`/`LON`: ADIF readers take a coordinate over a gridsquare,
  // so the operator would be published standing at a point inside a square
  // they only claimed to be somewhere in.
  test('a grid the operator stated exports as a square, never as the coordinate standing in for it', () async {
    final host = await startHost();
    final result = await host.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': {
          ...operation(['US-0001']),
          'grid': 'FN21rq',
          // Read through the same decoder the app writes them with: a
          // hand-rounded pair is NEAR the center and not the center, and the
          // rule under test is about a pair that IS one.
          'lat': gridToLocation('FN21rq')!.latitude,
          'lon': gridToLocation('FN21rq')!.longitude,
        },
        'qsos': [
          {
            ...qsos.first,
            'their': {
              'call': 'W0ABC',
              'sent': '59',
              'grid': 'FN31pr',
              'lat': gridToLocation('FN31pr')!.latitude,
              'lon': gridToLocation('FN31pr')!.longitude,
            },
          },
        ],
        'exportType': 'adif',
        'includePrivateData': true,
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    // Both operations' pairs above ARE the centers of the grids beside them.
    expect(content, contains('<MY_GRIDSQUARE:6>FN21rq'));
    expect(content, contains('<GRIDSQUARE:6>FN31pr'));
    for (final tag in ['<LAT:', '<LON:', '<MY_LAT:', '<MY_LON:']) {
      expect(content, isNot(contains(tag)), reason: '$tag states a point the operator never claimed');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  // The worked station's square follows the operator's Grid Precision the way
  // their own does, and is derived from the coordinate the log holds rather
  // than read off the stored string: a lookup files a six-character grid
  // beside a coordinate whatever precision is in force, so reading the string
  // would state a coarser square in the file than every screen shows.
  test('the worked station\'s gridsquare is derived from the coordinate, at the operator\'s precision', () async {
    final fineHost = await sharedHost(
      ['adif', 'pota'],
      cacheKey: 'their-grid-precision-eight',
      onHostCall: (method, params) async => method == 'getSettings' ? {'gridPrecision': 8} : null,
    );
    final result = await fineHost.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': operation(['US-0001']),
        'qsos': [
          {
            ...qsos.first,
            'their': {
              'call': 'W0ABC',
              'sent': '59',
              // What a lookup leaves behind: an exact coordinate, and the
              // six-character square the merge derives beside it.
              'guess': {'grid': 'FN31pr', 'lat': 41.7135, 'lon': -72.7278},
            },
          },
        ],
        'exportType': 'adif',
        'includePrivateData': true,
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    expect(content, contains('<GRIDSQUARE:8>${locationToGrid8(41.7135, -72.7278)}'));
    expect(content, isNot(contains('<GRIDSQUARE:6>FN31pr')), reason: 'the stored string is the coarser claim');
    // The coordinate is real, so it still goes out beside the square.
    expect(content, contains('<LAT:'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Grid Precision governs a locator this app DERIVES. A locator it was given
  // is a datum in its own right: on the air a received grid IS the exchange,
  // and cutting what the other station sent back to our own display
  // preference would lose characters nothing in the file admits to losing.
  test('a locator finer than the operator\'s own precision survives export as the other station sent it', () async {
    final host = await startHost();
    final result = await host.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': operation(['US-0001']),
        'qsos': [
          {
            ...qsos.first,
            // Eight characters and no coordinate — what an ADIF import from
            // another logger leaves behind, and what the app stores for a
            // locator typed at eight characters.
            'their': {'call': 'W0ABC', 'sent': '59', 'grid': 'FN31pr56'},
          },
        ],
        'exportType': 'adif',
        'includePrivateData': true,
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    // The default precision is six; the exchange is eight and stays eight.
    expect(content, contains('<GRIDSQUARE:8>FN31pr56'));
    expect(content, isNot(contains('<GRIDSQUARE:6>FN31pr')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Our own side is the exception, and the reason is privacy rather than
  // precision: the switch that withholds the coordinate has to withhold the
  // precision riding with it, or a stored eight-character locator states the
  // position anyway.
  test('our own locator is still capped when private data is withheld, however it was stored', () async {
    final host = await startHost();
    final result = await host.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': {...operation(['US-0001']), 'grid': 'FN21sq55'},
        'qsos': [qsos.first],
        'exportType': 'adif',
        'includePrivateData': false,
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final content = result['content'] as String;

    expect(content, contains('<MY_GRIDSQUARE:6>FN21sq'));
    expect(content, isNot(contains('FN21sq55')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // What app-polo puts on every guess it syncs to us: lib-country-files' DXCC
  // centroid, tagged `locSource: 'prefix'` and carrying cty.dat's
  // WEST-POSITIVE longitude. The pair is neither the station's position nor
  // even the right side of the planet, so it must never leave as one — and
  // the guess's own grid still can.
  test('a country-file centroid on the guess is not exported as the station coordinate', () async {
    final host = await startHost();

    final result = await host.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': operation(['US-0001']),
        'qsos': [
          {
            ...qsos.first,
            'their': {
              'call': 'W0ABC',
              'sent': '59',
              'guess': {'grid': 'FN31pr', 'lat': 37.6, 'lon': 91.87, 'locSource': 'prefix'},
            },
          },
        ],
        'exportType': 'adif',
        'includePrivateData': true,
      },
      timeout: const Duration(seconds: 20),
    ) as Map;
    final adif = result['content'] as String;

    expect(adif, contains('<CALL:5>W0ABC'));
    for (final tag in ['<LAT:', '<LON:']) {
      expect(adif, isNot(contains(tag)));
    }
    expect(adif, contains('FN31pr'), reason: 'the locator the lookup reported is still a fact about the station');
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Who was at the key and which position logged it are stamped on the QSO at
  // log time; the export's job is to say them without repeating what
  // STATION_CALLSIGN already said. The position has no ADIF field of its own,
  // so it goes out as ours and only with private data released — which
  // position of a multi-op made a contact is the station's internal layout,
  // and no program asks for it.
  test('OPERATOR names the operator only when it differs from the station call', () async {
    final host = await startHost();

    Future<String> adifFor(Map<String, dynamic> our, {bool includePrivateData = true}) async {
      final result = await host.invokeHook(
        'export',
        key: 'adif',
        method: 'generateExport',
        args: {
          'operation': operation(['US-0001']),
          'qsos': [
            {...qsos.first, 'our': {...qsos.first['our'] as Map<String, dynamic>, ...our}},
          ],
          'exportType': 'adif',
          'includePrivateData': includePrivateData,
        },
        timeout: const Duration(seconds: 20),
      ) as Map;
      return result['content'] as String;
    }

    final guest = await adifFor({'operatorCall': 'W1ABC', 'multiIdentifier': '2'});
    expect(guest, contains('<OPERATOR:5>W1ABC'));
    expect(guest, contains('<STATION_CALLSIGN:5>N0DEV'));
    expect(guest, contains('<APP_HAM2K_POSITION:1>2'));

    // A single operator running their own call: OPERATOR would be a second
    // copy of STATION_CALLSIGN in every record of every file.
    final self = await adifFor({'operatorCall': 'N0DEV'});
    expect(self, isNot(contains('<OPERATOR:')));

    // The dialog and the OPER command uppercase what they store, but a
    // WSJT-X or N1MM capture keeps whatever the datagram spelled — and
    // `n0dev` at a station running `N0DEV` is the same operator, not a guest.
    final cased = await adifFor({'operatorCall': ' n0dev '});
    expect(cased, isNot(contains('<OPERATOR:')));

    // Nothing stamped at all — the field must not appear empty or as the
    // station call by default.
    final unstamped = await adifFor({});
    expect(unstamped, isNot(contains('<OPERATOR:')));
    expect(unstamped, isNot(contains('<APP_HAM2K_POSITION:')));

    final uploaded = await adifFor({'operatorCall': 'W1ABC', 'multiIdentifier': '2'}, includePrivateData: false);
    expect(uploaded, contains('<OPERATOR:5>W1ABC'), reason: 'who transmitted is part of the contact');
    expect(uploaded, isNot(contains('<APP_HAM2K_POSITION:')));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
