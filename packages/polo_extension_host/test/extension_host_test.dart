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
import 'package:polo_extension_host/polo_extension_host.dart';

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
}
