// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Integration test against the real JS engine (in-process mode; isolates and
// FFI don't mix reliably inside flutter_test). Uses the built kernel bundle
// from the app assets plus a small inline test extension, so it exercises lazy
// activation, invoke/invokeAll, per-extension KV namespacing, and error
// isolation without any network.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

// Plain JS (no bundler): registers two lookup hooks, one of which fails,
// and a KV round-trip hook. Declared hooks come AFTER defineExtension to prove
// lazy activation removed the declaration-order footgun.
const _testPluginSource = '''
__polo.defineExtension({
  key: 'test-extension',
  name: 'Test Extension',
  version: '0.0.1',
  onActivation: function (api) {
    // KV (like every identity-bearing host call) goes through the
    // activation-scoped api.hostCall — the raw __polo.hostCall refuses it.
    boundHostCall = api.hostCall
    api.registerHook('lookup', { key: 'good', priority: 10, hook: goodHook })
    api.registerHook('lookup', { key: 'bad', priority: 5, hook: badHook })
    api.registerHook('kv', { key: 'kv', hook: kvHook })
  },
})

var boundHostCall = null

var goodHook = {
  lookupCall: async function (args) {
    return { source: 'good', call: args.callInfo.call, name: 'Test Name' }
  },
}

var badHook = {
  lookupCall: async function () {
    throw new Error('this source always fails')
  },
}

var kvHook = {
  roundTrip: async function (args) {
    await boundHostCall('kvSet', { key: args.key, value: args.value })
    return await boundHostCall('kvGet', { key: args.key })
  },
}
''';

void main() {
  final kernelFile = File('../../app/assets/extensions/kernel.js');

  test('kernel + extension end to end: activation, invoke, invokeAll, KV', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [ExtensionBundle(key: 'test-extension', source: _testPluginSource)],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    // Bench hook from the kernel itself.
    final echo = await host.invokeHook('bench', key: 'kernel', method: 'echo', args: {'x': 1});
    expect(echo, {'x': 1});

    // Single-hook invoke hits the highest-priority lookup.
    final single = await host.invokeHook('lookup', key: 'good', method: 'lookupCall',
        args: {'callInfo': {'call': 'W1AW'}});
    expect(single['name'], 'Test Name');

    // invokeAll returns one entry per source; the failing one is isolated.
    final all = await host.invokeHookAll('lookup', method: 'lookupCall',
        args: {'callInfo': {'call': 'W1AW'}});
    expect(all, hasLength(2));
    expect(all[0]['key'], 'good');
    expect(all[0]['ok'], true);
    expect(all[0]['value']['call'], 'W1AW');
    expect(all[1]['key'], 'bad');
    expect(all[1]['ok'], false);
    expect(all[1]['error'], contains('always fails'));

    // KV: extension sees what the host seeded, namespaced.
    host.setKV('test-extension', 'greeting', 'hello');
    final fromHost = await host.invokeHook('kv', key: 'kv', method: 'roundTrip',
        args: {'key': 'other', 'value': 42});
    expect(fromHost, 42);

    // Unknown hooks fail fast with a useful error.
    await expectLater(
      host.invokeHook('lookup', key: 'missing', method: 'lookupCall', args: {}),
      throwsA(isA<ExtensionHostException>()),
    );
  });

  test('kernel passes settings (locale) to hook context', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'locale-test-extension',
          source: '''
__polo.defineExtension({
  key: 'locale-test-extension',
  name: 'Locale Test Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('localeTest', {
      key: 'test',
      hook: {
        checkContext: async function (args, ctx) {
          return { locale: ctx.locale, online: ctx.online }
        }
      }
    })
  },
})
'''
        )
      ],
      useIsolate: false,
      onHostCall: (method, params) async {
        if (method == 'getSettings') {
          return {
            'developerMode': true,
            'locale': 'es',
          };
        }
        return null;
      },
    );
    addTearDown(host.dispose);

    final result = await host.invokeHook('localeTest', key: 'test', method: 'checkContext', args: {});
    expect(result, {
      'locale': 'es',
      'online': true,
    });
  });

  test('ADIF export extension generates a valid file from QSON', () async {
    final adifFile = File('../../app/assets/extensions/adif.js');
    if (!kernelFile.existsSync() || !adifFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [ExtensionBundle(key: 'adif', source: adifFile.readAsStringSync())],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final result = await host.invokeHook('export', key: 'adif', method: 'generateExport', args: {
      'operation': {'uuid': 'op-1', 'stationCall': 'KI2D', 'title': 'Test Op'},
      'qsos': [
        {
          'our': {'call': 'KI2D', 'sent': '59'},
          'their': {'call': 'W1AW', 'sent': '57', 'name': 'ARRL HQ', 'grid': 'FN31pr', 'state': 'CT'},
          'freq': 14285.0,
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': DateTime.utc(2026, 7, 5, 18, 30).millisecondsSinceEpoch,
        },
        {
          'our': {'call': 'KI2D', 'sent': '599'},
          'their': {'call': 'EA4XYZ', 'sent': '579'},
          'freq': 7025.0,
          'band': '40m',
          'mode': 'CW',
          'startAtMillis': DateTime.utc(2026, 7, 5, 18, 45).millisecondsSinceEpoch,
        },
      ],
      // What the app passes for the whole-log export: it declares
      // `alwaysIncludePrivateData`, so this is the complete field set. The
      // withholding default has its own tests in activity_export_test.dart.
      'includePrivateData': true,
    }) as Map;

    expect(result['filename'], '2026-07-05 KI2D Test Op.adi');
    final content = result['content'] as String;
    expect(content, contains('<ADIF_VER:5>3.1.5'));
    expect(content, contains('<EOH>'));
    expect(content, contains('<CALL:4>W1AW'));
    expect(content, contains('<QSO_DATE:8>20260705'));
    expect(content, contains('<TIME_ON:6>183000'));
    expect(content, contains('<FREQ:6>14.285'));
    expect(content, contains('<MODE:3>SSB'));
    expect(content, contains('<NAME:7>ARRL HQ'));
    expect(content, contains('<GRIDSQUARE:6>FN31pr'));
    expect(content, contains('<CALL:6>EA4XYZ'));
    expect(content, contains('<MODE:2>CW'));
    expect('<EOR>'.allMatches(content).length, 2);
  });

  // The "Use compact file names" setting is core-owned but extension-applied:
  // the core only passes `compactFilenames` down, and each hook builds its own
  // name from it (`exportFilename` in the SDK). So the contract worth pinning
  // end-to-end is that the flag survives the bridge and changes the answer —
  // a bundle that ignored it would look identical from the Dart side.
  test('compactFilenames reaches the bundle and changes the name it offers AND writes', () async {
    final adifFile = File('../../app/assets/extensions/adif.js');
    if (!kernelFile.existsSync() || !adifFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [ExtensionBundle(key: 'adif', source: adifFile.readAsStringSync())],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final payload = {
      'operation': {'uuid': 'op-1', 'stationCall': 'KI2D', 'title': 'Test Op'},
      'qsos': [
        {
          'our': {'call': 'KI2D'},
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': DateTime.utc(2026, 7, 5, 18, 30).millisecondsSinceEpoch,
        },
      ],
    };

    Future<String> nameFor(String method, {required bool compact}) async {
      final result = await host.invokeHook(
        'export',
        key: 'adif',
        method: method,
        args: {...payload, 'compactFilenames': compact},
      );
      final value = method == 'suggestExportOptions' ? (result as List).first as Map : result as Map;
      return value['filename'] as String;
    }

    expect(await nameFor('suggestExportOptions', compact: false), '2026-07-05 KI2D Test Op.adi');
    expect(await nameFor('suggestExportOptions', compact: true), 'KI2D-20260705-test-op.adi');
    // Both halves of the contract, because the panel shows one and the file
    // is written under the other.
    expect(await nameFor('generateExport', compact: true), 'KI2D-20260705-test-op.adi');
  });

  test('POTA extension composes ADIF fields into the export (in-runtime hooks)', () async {
    final adifFile = File('../../app/assets/extensions/adif.js');
    final potaFile = File('../../app/assets/extensions/pota.js');
    if (!kernelFile.existsSync() || !adifFile.existsSync() || !potaFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [
        ExtensionBundle(key: 'adif', source: adifFile.readAsStringSync()),
        ExtensionBundle(key: 'pota', source: potaFile.readAsStringSync()),
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    // POTA ref validation works without network.
    final validation = await host.invokeHook('ref:pota', method: 'validateRef',
        args: {'ref': {'type': 'pota', 'ref': 'us-1234'}});
    expect(validation['valid'], true);
    expect(validation['normalized'], 'US-1234');

    final result = await host.invokeHook('export', key: 'adif', method: 'generateExport', args: {
      'operation': {
        'stationCall': 'KI2D',
        'title': 'Park run',
        'refs': [
          {'type': 'potaActivation', 'ref': 'US-5678'},
        ],
      },
      'qsos': [
        {
          'their': {'call': 'W1AW', 'sent': '59'},
          'our': {'call': 'KI2D', 'sent': '59'},
          'mode': 'SSB',
          'band': '20m',
          'startAtMillis': DateTime.utc(2026, 7, 5, 19).millisecondsSinceEpoch,
          'refs': [
            {'type': 'pota', 'ref': 'US-1234'},
            {'type': 'pota', 'ref': 'US-4321'},
          ],
        },
      ],
    }) as Map;

    final content = result['content'] as String;
    // Two hunted parks means two records, one per park, each separately
    // submittable — see nfer_export_test.dart for that rule in full.
    expect(content, contains('<SIG:4>POTA'));
    expect(content, contains('<SIG_INFO:7>US-1234'));
    expect(content, contains('<SIG_INFO:7>US-4321'));
    expect(content, contains('<MY_SIG:4>POTA'));
    expect(content, contains('<MY_SIG_INFO:7>US-5678'));
    expect(content, contains('<MY_POTA_REF:7>US-5678'));
  });

  test('samples list is capped instead of growing without bound', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    const callCount = 2100; // above the 2000-sample cap
    for (var i = 0; i < callCount; i++) {
      await host.invokeHook('bench', key: 'kernel', method: 'echo', args: {'i': i});
    }

    expect(host.samples.length, lessThan(callCount));
    expect(host.samples.length, lessThanOrEqualTo(2000));
  });

  test('radio-commands extension: band, frequency and mode via invokeHookAll', () async {
    final radioCommandsFile = File('../../app/assets/extensions/radio-commands.js');
    if (!kernelFile.existsSync() || !radioCommandsFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [ExtensionBundle(key: 'radio-commands', source: radioCommandsFile.readAsStringSync())],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    // Picks the first non-null result from every registered `command` hook,
    // exactly as ExtensionService.interpretCommand does.
    Future<Map<String, dynamic>?> interpretCommand(String input) async {
      final entries = await host.invokeHookAll('command', method: 'interpret', args: {'input': input});
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) return (entry['value'] as Map).cast<String, dynamic>();
      }
      return null;
    }

    // The bug this extension fixes: MHz-style input with only 2 digits
    // before the decimal point never matched the old Dart regex, which
    // required 3+ digits unconditionally.
    expect(await interpretCommand('14.285'), {
      'describe': 'Change frequency to **14.285 MHz**?',
      'confirm': 'Frequency set to **14.285 MHz**',
      'commands': [
        {'setVfo': {'freq': 14285.0}}
      ]
    });

    // Plain kHz input still works.
    expect(await interpretCommand('14285'), {
      'describe': 'Change frequency to **14.285 MHz**?',
      'confirm': 'Frequency set to **14.285 MHz**',
      'commands': [
        {'setVfo': {'freq': 14285.0}}
      ]
    });

    // Band and mode commands.
    expect(await interpretCommand('20m'), {
      'describe': 'Change band to **20m**?',
      'confirm': 'Band set to **20m**',
      'commands': [
        {'setVfo': {'band': '20m'}}
      ]
    });
    expect(await interpretCommand('20'), {
      'describe': 'Change band to **20m**?',
      'confirm': 'Band set to **20m**',
      'commands': [
        {'setVfo': {'band': '20m'}}
      ]
    });
    expect(await interpretCommand('cw'), {
      'describe': 'Change mode to **CW**?',
      'confirm': 'Mode set to **CW**',
      'commands': [
        {'setVfo': {'mode': 'CW'}}
      ]
    });

    // Nonsense input matches nothing.
    expect(await interpretCommand('QQQ'), isNull);
    expect(await interpretCommand('13000'), isNull); // gap between 30m and 20m, no such ham band

    // 3-digit band tokens (160m, 630m) also resolve correctly — and don't
    // get shadowed by the frequency command, since band priority (100)
    // beats frequency (99) whenever both could theoretically match.
    expect(await interpretCommand('160m'), {
      'describe': 'Change band to **160m**?',
      'confirm': 'Band set to **160m**',
      'commands': [
        {'setVfo': {'band': '160m'}}
      ]
    });
  });

  test('call-notes extension: raw dataFile round-trip, lookup notes, and //KEY expansion', () async {
    final lookupsFile = File('../../app/assets/extensions/lookups.js');
    final callNotesFile = File('../../app/assets/extensions/call-notes.js');
    if (!kernelFile.existsSync() || !lookupsFile.existsSync() || !callNotesFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [
        ExtensionBundle(key: 'lookups', source: lookupsFile.readAsStringSync()),
        ExtensionBundle(key: 'call-notes', source: callNotesFile.readAsStringSync()),
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    // The exact invocations DataFileManager._processRaw makes for a
    // fetchType 'raw' data file: parse the body, then hand the (JSON-cached)
    // result back through onLoadRawData — issue #17's Hams of Note file.
    const body = '# TITLE: Hams of Note\n'
        '\n'
        'KI2D 🤩 Sebastián - Ham2K PoLo Creator\n'
        'KI2D 😁 also an Elmer\n'
        'DAN WD4DAN,WD4JMM\n';
    final parsed = await host.invokeHook('dataFile', key: 'call-notes', method: 'rawToJSONData',
        args: {'body': body, 'url': 'https://ham2k.com/data/hams-of-note.txt', 'options': {}});
    expect((parsed as Map)['KI2D'], hasLength(2));
    await host.invokeHook('dataFile', key: 'call-notes', method: 'onLoadRawData', args: parsed);

    // The full lookup pipeline (annotation pre-step + fan-out + merge)
    // carries the combined note and marker emoji onto the guess.
    final result = await host.invokeHook('lookupService', key: 'core', method: 'lookupCallInfo',
        args: {'callInfo': {'call': 'KI2D'}, 'qso': {}, 'operation': {}});
    final guess = (result['guess'] as Map).cast<String, dynamic>();
    expect(guess['note'], '🤩😁 Sebastián - Ham2K PoLo Creator');
    expect(guess['emoji'], '🤩');

    // A call with no notes gets no note field.
    final blank = await host.invokeHook('lookupService', key: 'core', method: 'lookupCallInfo',
        args: {'callInfo': {'call': 'W1AW'}, 'qso': {}, 'operation': {}});
    expect((blank['guess'] as Map).containsKey('note'), isFalse);

    Future<Map<String, dynamic>?> interpretCommand(String input) async {
      final entries = await host.invokeHookAll('command', method: 'interpret', args: {'input': input});
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) return (entry['value'] as Map).cast<String, dynamic>();
      }
      return null;
    }

    // `//KEY` expands an entry whose note is a plain comma list of calls...
    expect(await interpretCommand('//dan'), {
      'describe': 'Expand to WD4DAN,WD4JMM?',
      'commands': [
        {'setCallField': {'text': 'WD4DAN,WD4JMM'}}
      ]
    });
    // ...but never one with emoji/free-text (issue #17), an unknown key, or
    // ordinary call-stacking input ("//" not at the start).
    expect(await interpretCommand('//KI2D'), isNull);
    expect(await interpretCommand('//NOSUCH'), isNull);
    expect(await interpretCommand('K1ABC//W1AW'), isNull);
  });

  test('SOTA extension composes ADIF fields into the export (in-runtime hooks)', () async {
    final adifFile = File('../../app/assets/extensions/adif.js');
    final sotaFile = File('../../app/assets/extensions/sota.js');
    if (!kernelFile.existsSync() || !adifFile.existsSync() || !sotaFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [
        ExtensionBundle(key: 'adif', source: adifFile.readAsStringSync()),
        ExtensionBundle(key: 'sota', source: sotaFile.readAsStringSync()),
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    // SOTA ref validation works without network.
    final validation = await host.invokeHook('ref:sota', method: 'validateRef',
        args: {'ref': {'type': 'sota', 'ref': 'w6/sd-026'}});
    expect(validation['valid'], true);
    expect(validation['normalized'], 'W6/SD-026');

    final result = await host.invokeHook('export', key: 'adif', method: 'generateExport', args: {
      'operation': {
        'stationCall': 'KI2D',
        'title': 'Summit run',
        'refs': [
          {'type': 'sotaActivation', 'ref': 'W6/SD-026'},
        ],
      },
      'qsos': [
        {
          'their': {'call': 'W1AW', 'sent': '59'},
          'our': {'call': 'KI2D', 'sent': '59'},
          'mode': 'SSB',
          'band': '20m',
          'startAtMillis': DateTime.utc(2026, 7, 5, 19).millisecondsSinceEpoch,
          'refs': [
            {'type': 'sota', 'ref': 'G/LD-001'},
          ],
        },
      ],
    }) as Map;

    final content = result['content'] as String;
    expect(content, contains('<SOTA_REF:8>G/LD-001'));
    expect(content, contains('<MY_SOTA_REF:9>W6/SD-026'));
  });

  test('Scoring extension detects dupes and tallies DXCC/bands/modes in one batched call', () async {
    final scoringFile = File('../../app/assets/extensions/scoring.js');
    if (!kernelFile.existsSync() || !scoringFile.existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: [ExtensionBundle(key: 'scoring', source: scoringFile.readAsStringSync())],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final day1 = DateTime.utc(2026, 7, 5, 18);
    final day2 = DateTime.utc(2026, 7, 6, 12);

    final result = await host.invokeHook('scoring', key: 'core', method: 'scoreQsos', args: {
      'operation': {'uuid': 'op-1', 'stationCall': 'KI2D'},
      'qsos': [
        {
          'uuid': 'q1',
          'our': {'call': 'KI2D'},
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': day1.millisecondsSinceEpoch,
        },
        // Same call/band/mode as q1 — should score as a duplicate.
        {
          'uuid': 'q2',
          'our': {'call': 'KI2D'},
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': day1.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        },
        // Different DXCC entity, still day 1.
        {
          'uuid': 'q3',
          'our': {'call': 'KI2D'},
          'their': {'call': 'EA4XYZ'},
          'band': '40m',
          'mode': 'CW',
          'startAtMillis': day1.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        },
        // Next day — new day section, DXCC/bands/modes tallies carry over.
        {
          'uuid': 'q4',
          'our': {'call': 'KI2D'},
          'their': {'call': 'JA1ABC'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': day2.millisecondsSinceEpoch,
        },
        // New band (15m), but mode (SSB) was already worked on q1/q4 — must
        // still score as a new band, not get zeroed out just because the
        // mode was already known.
        {
          'uuid': 'q5',
          'our': {'call': 'KI2D'},
          'their': {'call': 'G4ABC'},
          'band': '15m',
          'mode': 'SSB',
          'startAtMillis': day2.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        },
      ],
    }) as Map;

    // One verdict per QSO, not one per rule: a scorer's internal rules stay
    // private to its scoresheet, so only points, notices and alerts surface
    // (docs/design/contests.md §5.1).
    final qsoScores = result['qsoScores'] as Map;
    expect(qsoScores['q1']['value'], 1);
    expect(qsoScores['q2']['dupe'], true);
    expect(qsoScores['q2']['value'], 0);
    expect(qsoScores['q3']['value'], 1);

    // Each of these is the operation's first contact with that entity.
    expect(qsoScores['q1']['notices'], contains('newDXCC'));
    expect(qsoScores['q3']['notices'], contains('newDXCC'));
    expect(qsoScores['q4']['notices'], contains('newDXCC'));
    // A duplicate contributes nothing at all — no new band, mode or entity.
    expect(qsoScores['q2']['notices'], anyOf(isNull, isEmpty));

    // q5 is a new band (15m) even though its mode (SSB) was already worked
    // on q1/q4 — scoring must credit a QSO as new if EITHER the band or the
    // mode is new, not require BOTH to already be known.
    expect(qsoScores['q5']['value'], 1);
    expect(qsoScores['q5']['notices'], contains('newBand'));

    final daySections = result['daySections'] as List;
    expect(daySections.length, 2);

    final day1Scores = (daySections[0] as Map)['scores'] as Map;
    expect(day1Scores['qsoCount']['total'], 2); // q1 (new) + q3 (new); q2 is a dupe
    expect(day1Scores['qsoCount']['duplicates'], 1);
    expect(day1Scores['dxcc']['total'], 2); // K, EA

    final day2Scores = (daySections[1] as Map)['scores'] as Map;
    expect(day2Scores['qsoCount']['total'], 2); // q4 + q5
    expect(day2Scores['dxcc']['total'], 4); // K, EA, JA carried over from day 1, plus G

    final operationSummary = result['operationSummary'] as Map;
    expect(operationSummary['qsoCount']['total'], 4);
    expect(operationSummary['qsoCount']['duplicates'], 1);
    expect(operationSummary['dxcc']['total'], 4);
    // q1 (new 20m+SSB) + q3 (new 40m+CW) + q5 (new 15m, even though SSB was
    // already known) = 3; q2 and q4 repeat an already-known band AND mode.
    expect(operationSummary['bandsAndModes']['total'], 3);
  });

  test('form hooks: getDefinition, validateField, transformField, and dynamic showForm', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    ExtensionHost? host;
    host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'form-test-extension',
          source: '''
__polo.defineExtension({
  key: 'form-test-extension',
  name: 'Form Test Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('form', {
      key: 'test-form',
      hook: {
        getDefinition: async function (args) {
          return {
            title: 'Test Static Form',
            elements: [
              { type: 'field', fieldType: 'text', key: 'name', label: 'Name' }
            ]
          }
        },
        validateField: async function (args) {
          if (args.fieldKey === 'name' && args.value === '') {
            return 'Name cannot be empty'
          }
          return null
        },
        transformField: async function (args) {
          if (args.fieldKey === 'name') {
            return args.value.trim().toUpperCase()
          }
          return args.value
        },
        onChangeField: async function (args) {
          if (args.fieldKey === 'name' && args.value === 'trigger') {
            return { otherField: 'triggered' }
          }
          return null
        }
      }
    });

    api.registerHook('testTrigger', {
      key: 'trigger',
      hook: {
        runDynamicForm: async function (args) {
          const result = await globalThis.__polo.host.showForm({
            title: 'Dynamic Form',
            elements: [
              {
                type: 'field',
                fieldType: 'text',
                key: 'call',
                label: 'Callsign',
                validate: (v) => v.length < 3 ? 'Short call' : null,
                transform: (v) => v.toUpperCase()
              }
            ],
            onChange: (fk, val, st) => {
              if (fk === 'call' && val === 'update') {
                return { otherField: 'W1AW' }
              }
            }
          }, { call: 'w1aw' });
          return result;
        }
      }
    });
  },
})
'''
        )
      ],
      useIsolate: false,
      onHostCall: (method, params) async {
        if (method == 'showForm') {
          expect(params['formId'], startsWith('dynamic:'));
          final form = params['form'] as Map;
          expect(form['title'], 'Dynamic Form');
          final elements = form['elements'] as List;
          expect(elements[0]['key'], 'call');

          final formId = params['formId'] as String;

          final validationResult = await host?.invokeHook('form', key: formId, method: 'validateField', args: {
            'fieldKey': 'call',
            'value': 'ki',
            'state': {'call': 'ki'}
          });
          expect(validationResult, 'Short call');

          final validationResultOk = await host?.invokeHook('form', key: formId, method: 'validateField', args: {
            'fieldKey': 'call',
            'value': 'ki2d',
            'state': {'call': 'ki2d'}
          });
          expect(validationResultOk, isNull);

          final transformed = await host?.invokeHook('form', key: formId, method: 'transformField', args: {
            'fieldKey': 'call',
            'value': 'ki2d',
            'state': {'call': 'ki2d'}
          });
          expect(transformed, 'KI2D');

          final onChangeResult = await host?.invokeHook('form', key: formId, method: 'onChangeField', args: {
            'fieldKey': 'call',
            'value': 'update',
            'state': {'call': 'update'}
          });
          expect(onChangeResult, {'otherField': 'W1AW'});

          return {'call': transformed};
        }
        return null;
      }
    );
    addTearDown(host.dispose);

    final def = await host.invokeHook('form', key: 'test-form', method: 'getDefinition', args: {});
    expect(def['title'], 'Test Static Form');
    expect(def['elements'][0]['key'], 'name');

    final err1 = await host.invokeHook('form', key: 'test-form', method: 'validateField', args: {
      'fieldKey': 'name',
      'value': '',
      'state': {'name': ''}
    });
    expect(err1, 'Name cannot be empty');

    final err2 = await host.invokeHook('form', key: 'test-form', method: 'validateField', args: {
      'fieldKey': 'name',
      'value': 'John',
      'state': {'name': 'John'}
    });
    expect(err2, isNull);

    final trans = await host.invokeHook('form', key: 'test-form', method: 'transformField', args: {
      'fieldKey': 'name',
      'value': ' john ',
      'state': {'name': ' john '}
    });
    expect(trans, 'JOHN');

    final changeRes = await host.invokeHook('form', key: 'test-form', method: 'onChangeField', args: {
      'fieldKey': 'name',
      'value': 'trigger',
      'state': {'name': 'trigger'}
    });
    expect(changeRes, {'otherField': 'triggered'});

    final dynamicResult = await host.invokeHook('testTrigger', key: 'trigger', method: 'runDynamicForm', args: {});
    expect(dynamicResult, {'call': 'KI2D'});
  });

  test('invokeHookAll reports an unserializable aggregate as an error, not a timeout', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'circular-extension',
          source: '''
__polo.defineExtension({
  key: 'circular-extension',
  name: 'Circular Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('circularTest', {
      key: 'circular-extension',
      hook: {
        makeCircle: async function () {
          var a = {}
          a.self = a
          return a
        }
      }
    })
  },
})
'''
        )
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    // The per-record try/catch can't see this failure — it happens when the
    // aggregate is stringified for posting. Without invokeHookAll's outer
    // catch it became an unhandled rejection and the caller burned its full
    // timeout reporting "timed out" instead of the real error.
    await expectLater(
      host.invokeHookAll('circularTest', method: 'makeCircle', timeout: const Duration(seconds: 3)),
      throwsA(isA<ExtensionHostException>().having((e) => e.message, 'message', isNot(contains('timed out')))),
    );
  });

  test('a host call whose handler returns an unencodable value fails the hook instead of wedging it', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'weird-extension',
          source: '''
__polo.defineExtension({
  key: 'weird-extension',
  name: 'Weird Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('weirdTest', {
      key: 'weird-extension',
      hook: {
        callWeird: async function () {
          return await __polo.hostCall('weird', {})
        }
      }
    })
  },
})
'''
        )
      ],
      useIsolate: false,
      onHostCall: (method, params) async {
        if (method == 'weird') return Object(); // not JSON-encodable
        return null;
      },
    );
    addTearDown(host.dispose);

    // Encode-before-deliver: the failure must come back as the hook's error
    // (ok:false hostResponse), never as an undelivered response that leaks
    // the kernel's pending call and times the hook out.
    await expectLater(
      host.invokeHook('weirdTest', key: 'weird-extension', method: 'callWeird', timeout: const Duration(seconds: 3)),
      throwsA(isA<ExtensionHostException>().having((e) => e.message, 'message', contains('unencodable'))),
    );
  });

  test('a never-settling hook times out without poisoning later calls', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'stuck-extension',
          source: '''
__polo.defineExtension({
  key: 'stuck-extension',
  name: 'Stuck Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('stuckTest', {
      key: 'stuck-extension',
      hook: {
        never: function () { return new Promise(function () {}) }
      }
    })
  },
})
'''
        )
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    await expectLater(
      host.invokeHook('stuckTest', key: 'stuck-extension', method: 'never', timeout: const Duration(milliseconds: 300)),
      throwsA(isA<ExtensionHostException>().having((e) => e.message, 'message', contains('timed out'))),
    );

    // The abandoned call must not leave the host in a bad state.
    final echo = await host.invokeHook('bench', key: 'kernel', method: 'echo', args: {'ok': true});
    expect(echo, {'ok': true});
  });

  test('an extension cannot read another extension KV namespace by spoofing ns', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'attacker',
          source: '''
__polo.defineExtension({
  key: 'attacker',
  name: 'Attacker',
  version: '0.0.1',
  onActivation: function (api) {
    boundHostCall = api.hostCall
    api.registerHook('attack', { key: 'attacker', hook: {
      // Tries to read the victim's namespace two ways: the bound call with
      // a spoofed ns (kernel overrides it), and the raw kernel hostCall
      // (refused outright for identity-bearing methods).
      viaBound: async function () { return await boundHostCall('kvGet', { ns: 'victim', key: 'secret' }) },
      viaRaw: async function () { return await __polo.hostCall('kvGet', { ns: 'victim', key: 'secret' }) }
    } })
  },
})
var boundHostCall = null
'''
        )
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    host.setKV('victim', 'secret', 'TOP-SECRET');

    // Bound call: ns is overridden to 'attacker', so the victim's key isn't
    // visible — comes back null, not the secret.
    final viaBound = await host.invokeHook('attack', key: 'attacker', method: 'viaBound');
    expect(viaBound, isNull);

    // Raw kernel hostCall refuses identity-bearing methods entirely.
    await expectLater(
      host.invokeHook('attack', key: 'attacker', method: 'viaRaw'),
      throwsA(isA<ExtensionHostException>().having((e) => e.message, 'message', contains('SDK host API'))),
    );
  });

  test('a bundle cannot define an extension key it was not loaded under', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          // The host loads this bundle as 'honest', but its source tries to
          // also mint a 'victim' identity — the kernel rejects it.
          key: 'honest',
          source: '''
__polo.defineExtension({ key: 'honest', name: 'Honest', version: '0.0.1', onActivation: function () {} })
__polo.defineExtension({ key: 'victim', name: 'Impersonator', version: '0.0.1', onActivation: function (api) {
  api.registerHook('impersonate', { key: 'victim', hook: { ping: async function () { return 'i am victim' } } })
} })
'''
        )
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final logs = host.logLines.join('\n');
    expect(logs, contains("tried to define extension 'victim'"));
    // The spoofed hook never registered.
    await expectLater(
      host.invokeHook('impersonate', key: 'victim', method: 'ping'),
      throwsA(isA<ExtensionHostException>()),
    );
  });

  test('host.fetch is refused for a domain the extension did not declare', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'fetcher',
          source: '''
__polo.defineExtension({
  key: 'fetcher',
  name: 'Fetcher',
  version: '0.0.1',
  onActivation: function (api) {
    boundFetch = api.hostCall
    api.registerHook('fetchTest', { key: 'fetcher', hook: {
      grab: async function (args) {
        try { await boundFetch('fetch', { url: args.url }); return 'allowed' }
        catch (e) { return 'blocked: ' + e.message }
      }
    } })
  },
})
var boundFetch = null
'''
        )
      ],
      useIsolate: false,
      fetchAllowlists: const {'fetcher': ['api.allowed.example']},
    );
    addTearDown(host.dispose);

    // A declared host would pass the gate (and then fail the real network,
    // which we don't exercise); an undeclared one is blocked before any I/O.
    final blocked = await host.invokeHook('fetchTest', key: 'fetcher', method: 'grab',
        args: {'url': 'https://evil.example/steal'});
    expect(blocked, startsWith('blocked:'));
    expect(blocked, contains('declared domains'));
  });

  group('resolveFetchUserAgent', () {
    const canonical = 'Ham2K Logger/26.8.0 (macos next 1)';
    const custom = {'User-Agent': 'CustomBot/9'};

    test('stamps the canonical UA when the extension set none', () {
      expect(
        resolveFetchUserAgent(canonical: canonical, extensionKey: 'pota', overrides: const {}, callerHeaders: const {}),
        canonical,
      );
    });

    test('overrides a non-whitelisted extension that set its own UA', () {
      expect(
        resolveFetchUserAgent(canonical: canonical, extensionKey: 'pota', overrides: const {}, callerHeaders: custom),
        canonical,
      );
    });

    test('keeps a whitelisted extension\'s own UA', () {
      expect(
        resolveFetchUserAgent(canonical: canonical, extensionKey: 'sync-x', overrides: const {'sync-x'}, callerHeaders: custom),
        'CustomBot/9',
      );
    });

    test('matches the whitelisted UA header case-insensitively', () {
      expect(
        resolveFetchUserAgent(
            canonical: canonical, extensionKey: 'sync-x', overrides: const {'sync-x'}, callerHeaders: const {'user-agent': 'CustomBot/9'}),
        'CustomBot/9',
      );
    });

    test('still stamps canonical for a whitelisted extension that set none', () {
      expect(
        resolveFetchUserAgent(canonical: canonical, extensionKey: 'sync-x', overrides: const {'sync-x'}, callerHeaders: const {}),
        canonical,
      );
    });

    test('falls back to the caller UA when no canonical is configured', () {
      expect(
        resolveFetchUserAgent(canonical: null, extensionKey: 'pota', overrides: const {}, callerHeaders: custom),
        'CustomBot/9',
      );
    });
  });

  test('hook context (settings) is cached across an invokeAll fan-out and drops on invalidation', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    var getSettingsCalls = 0;
    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [
        ExtensionBundle(
          key: 'ctx-extension',
          source: '''
__polo.defineExtension({
  key: 'ctx-extension',
  name: 'Ctx Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('ctxTest', { key: 'ctx-extension', priority: 10, hook: { probe: async function (args, ctx) { return ctx.locale } } })
    api.registerHook('ctxTest', { key: 'ctx-extension_b', priority: 5, hook: { probe: async function (args, ctx) { return ctx.locale } } })
  },
})
'''
        )
      ],
      useIsolate: false,
      onHostCall: (method, params) async {
        if (method == 'getSettings') {
          getSettingsCalls++;
          return {'locale': 'es'};
        }
        return null;
      },
    );
    addTearDown(host.dispose);

    // Two hooks in one fan-out used to mean two getSettings round trips
    // (and for account-owning extensions, two keychain reads) — per call.
    final all = await host.invokeHookAll('ctxTest', method: 'probe');
    expect(all.map((e) => e['value']), ['es', 'es']);
    expect(getSettingsCalls, 1);

    // Still cached on the next call...
    await host.invokeHookAll('ctxTest', method: 'probe');
    expect(getSettingsCalls, 1);

    // ...until the host says settings changed.
    host.invalidateHookContext();
    await host.invokeHookAll('ctxTest', method: 'probe');
    expect(getSettingsCalls, 2);
  });

  test('a command hook can push a later interpretation via host.updateInterpretation (issue #189)', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      extensions: const [ExtensionBundle(key: 'test-extension', source: _asyncInterpretationSource)],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final updates = <Map<String, dynamic>>[];
    final sub = host.interpretationUpdates.listen(updates.add);
    addTearDown(sub.cancel);

    // interpret() itself returns quickly, with a placeholder — the caller
    // isn't blocked on the "fetch" the hook kicked off in the background.
    final entries = await host.invokeHookAll('command', method: 'interpret', args: {'input': 'SOLAR'});
    expect(entries.single['ok'], true);
    expect((entries.single['value'] as Map)['describe'], 'Fetching…');

    // The background "fetch" pushes the real result via
    // updateInterpretation — same input, a different (later) interpretation
    // than what interpret() itself returned above.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(updates, hasLength(1));
    expect(updates.single['input'], 'SOLAR');
    expect((updates.single['interpretation'] as Map)['confirm'], 'Solar flux: 120');
  });
}

// Registers a `command` hook whose interpret() returns immediately with a
// placeholder, then pushes the real result asynchronously after its own
// Promise has already settled — the SOLAR/WEATHER shape issue #189 needs.
const _asyncInterpretationSource = '''
__polo.defineExtension({
  key: 'test-extension',
  name: 'Test Extension',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('command', { key: 'solar', priority: 10, hook: solarHook })
  },
})

var solarHook = {
  interpret: async function (args) {
    Promise.resolve().then(function () {
      __polo.updateInterpretation(args.input, { confirm: 'Solar flux: 120' })
    })
    return { describe: 'Fetching…' }
  },
}
''';
