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
    api.registerHook('lookup', { key: 'good', priority: 10, hook: goodHook })
    api.registerHook('lookup', { key: 'bad', priority: 5, hook: badHook })
    api.registerHook('kv', { key: 'kv', hook: kvHook })
  },
})

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
    await __polo.hostCall('kvSet', { ns: 'test-extension', key: args.key, value: args.value })
    return await __polo.hostCall('kvGet', { ns: 'test-extension', key: args.key })
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
    }) as Map;

    expect(result['filename'], '20260705-ki2d-test-op.adi');
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
    expect(content, contains('<SIG:4>POTA'));
    expect(content, contains('<SIG_INFO:7>US-1234'));
    expect(content, contains('<POTA_REF:15>US-1234,US-4321'));
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

    final qsoScores = result['qsoScores'] as Map;
    expect(qsoScores['q1']['dupe']['value'], 1);
    expect(qsoScores['q2']['dupe']['dupe'], true);
    expect(qsoScores['q2']['dupe']['value'], 0);
    expect(qsoScores['q3']['dupe']['value'], 1);

    expect(qsoScores['q1']['dxcc']['entityPrefix'], 'K');
    expect(qsoScores['q3']['dxcc']['entityPrefix'], 'EA');
    expect(qsoScores['q4']['dxcc']['entityPrefix'], 'JA');

    // q5 is a new band (15m) even though its mode (SSB) was already worked
    // on q1/q4 — scoring must credit a QSO as new if EITHER the band or the
    // mode is new, not require BOTH to already be known.
    expect(qsoScores['q5']['bandsAndModes']['value'], 1);
    expect(qsoScores['q5']['bandsAndModes']['band'], '15m');

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
}
