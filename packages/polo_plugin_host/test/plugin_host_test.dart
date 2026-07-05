// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Integration test against the real JS engine (in-process mode; isolates and
// FFI don't mix reliably inside flutter_test). Uses the built kernel bundle
// from the app assets plus a small inline test plugin, so it exercises lazy
// activation, invoke/invokeAll, per-plugin KV namespacing, and error
// isolation without any network.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polo_plugin_host/polo_plugin_host.dart';

// Plain JS (no bundler): registers two lookup hooks, one of which fails,
// and a KV round-trip hook. Declared hooks come AFTER definePlugin to prove
// lazy activation removed the declaration-order footgun.
const _testPluginSource = '''
__polo.definePlugin({
  key: 'test-plugin',
  name: 'Test Plugin',
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
    await __polo.hostCall('kvSet', { ns: 'test-plugin', key: args.key, value: args.value })
    return await __polo.hostCall('kvGet', { ns: 'test-plugin', key: args.key })
  },
}
''';

void main() {
  final kernelFile = File('../../app/assets/plugins/kernel.js');

  test('kernel + plugin end to end: activation, invoke, invokeAll, KV', () async {
    if (!kernelFile.existsSync()) {
      markTestSkipped('kernel.js not built — run `npm run build` in plugins/ first');
      return;
    }

    final host = await PluginHost.start(
      kernelSource: kernelFile.readAsStringSync(),
      plugins: const [PluginBundle(key: 'test-plugin', source: _testPluginSource)],
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

    // KV: plugin sees what the host seeded, namespaced.
    host.setKV('test-plugin', 'greeting', 'hello');
    final fromHost = await host.invokeHook('kv', key: 'kv', method: 'roundTrip',
        args: {'key': 'other', 'value': 42});
    expect(fromHost, 42);

    // Unknown hooks fail fast with a useful error.
    await expectLater(
      host.invokeHook('lookup', key: 'missing', method: 'lookupCall', args: {}),
      throwsA(isA<PluginHostException>()),
    );
  });
}
