// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionHost.reloadBundle` — swapping one extension's code while the rest
// of the runtime keeps running, which is what the extension dev loop iterates
// on (HALO-118, docs/extensions/development.md).
//
// The reason it needs its own tests rather than riding on the boot path: a
// reload is the ONLY operation that removes something from the kernel's
// registry, and a registry that grows correctly can still shrink wrongly. The
// failure mode is quiet in the worst way — the old hooks stay registered
// alongside the new ones, so the extension appears to reload (its new answer
// is there) while the previous version answers too.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bundles.dart';

/// One extension whose hook answers [answer], so a reload is observable as a
/// changed return value. Also round-trips KV, to show what a reload keeps.
String _versioned(String answer) =>
    '''
__polo.defineExtension({
  key: 'reloadable',
  name: 'Reloadable',
  version: '0.0.1',
  onActivation: function (api) {
    boundHostCall = api.hostCall
    api.registerHook('bench', { key: 'reloadable', hook: {
      answer: async function () { return '$answer' },
      kvSet: async function (args) { await boundHostCall('kvSet', { key: 'k', value: args.value }) },
      kvGet: async function () { return await boundHostCall('kvGet', { key: 'k' }) },
    }})
  },
})
var boundHostCall = null
''';

/// A bystander: nothing about a reload of `reloadable` may disturb it.
const _bystanderSource = '''
__polo.defineExtension({
  key: 'bystander',
  name: 'Bystander',
  version: '0.0.1',
  onActivation: function (api) {
    boundHostCall = api.hostCall
    api.registerHook('bench', { key: 'bystander', hook: {
      answer: async function () { return 'bystander' },
      kvSet: async function (args) { await boundHostCall('kvSet', { key: 'k', value: args.value }) },
      kvGet: async function () { return await boundHostCall('kvGet', { key: 'k' }) },
    }})
  },
})
var boundHostCall = null
''';

/// One BUNDLE defining two extension keys — `bundleMayDefine` lets a bundle
/// define its own key plus any key it prefixes. Unload works per bundle for
/// exactly this reason, and a version keyed only on the extension name would
/// leave the second one behind.
String _multiKey(String answer) =>
    '''
__polo.defineExtension({
  key: 'multi',
  name: 'Multi',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: 'multi', hook: { answer: async function () { return '$answer' } }})
  },
})
__polo.defineExtension({
  key: 'multi-extra',
  name: 'Multi Extra',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: 'multi-extra', hook: { answer: async function () { return '$answer-extra' } }})
  },
})
''';

void main() {
  requireBundles();

  Future<ExtensionHost> hostWith(List<ExtensionBundle> extensions, {Map<String, List<String>> allowlists = const {}, http.Client? httpClient}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: extensions,
      fetchAllowlists: allowlists,
      httpClient: httpClient,
      userAgent: 'Ham2K-Test/1.0',
      useIsolate: false,
    );
    addTearDown(host.dispose);
    await host.activated;
    return host;
  }

  Future<Object?> answerOf(ExtensionHost host, String key) => host.invokeHook('bench', key: key, method: 'answer');

  test('a reload replaces the extension\'s code, leaving every other one running', () async {
    final host = await hostWith([
      ExtensionBundle(key: 'reloadable', source: _versioned('first')),
      const ExtensionBundle(key: 'bystander', source: _bystanderSource),
    ]);
    expect(await answerOf(host, 'reloadable'), 'first');

    await host.reloadBundle(ExtensionBundle(key: 'reloadable', source: _versioned('second')));

    expect(await answerOf(host, 'reloadable'), 'second');
    expect(await answerOf(host, 'bystander'), 'bystander', reason: 'reloading one bundle must not disturb any other');
  });

  test('the previous version is unregistered, not merely outranked', () async {
    final host = await hostWith([ExtensionBundle(key: 'reloadable', source: _versioned('first'))]);
    await host.reloadBundle(ExtensionBundle(key: 'reloadable', source: _versioned('second')));

    // The mutation this catches: an unload that drops the extension from the
    // registry but leaves its hooks in the array. `invokeHook` would still
    // answer 'second' (the newer record wins the priority sort at equal
    // priority), so only the fan-out reveals the old version still standing.
    final all = await host.invokeHookAll('bench', method: 'answer');
    final answers = [for (final entry in all) entry['value']];
    expect(answers, ['second'], reason: 'the first version must be gone, not shadowed');
  });

  test('a bundle that defines several extensions unloads all of them', () async {
    final host = await hostWith([ExtensionBundle(key: 'multi', source: _multiKey('first'))]);
    expect(await answerOf(host, 'multi-extra'), 'first-extra');

    await host.reloadBundle(ExtensionBundle(key: 'multi', source: _multiKey('second')));

    // Both keys came from the one bundle, so both must have been replaced. An
    // unload keyed on the extension name rather than the DEFINING BUNDLE drops
    // 'multi' and leaves 'multi-extra' behind, whereupon its redefinition is
    // refused as a duplicate key and the stale one answers forever.
    final all = await host.invokeHookAll('bench', method: 'answer');
    expect([for (final e in all) e['value']]..sort(), ['second', 'second-extra']);
  });

  test('KV survives a reload, so iterating does not wipe what the extension stored', () async {
    final host = await hostWith([ExtensionBundle(key: 'reloadable', source: _versioned('first'))]);
    await host.invokeHook('bench', key: 'reloadable', method: 'kvSet', args: {'value': 'kept'});

    await host.reloadBundle(ExtensionBundle(key: 'reloadable', source: _versioned('second')));

    // KV lives host-side, namespaced per extension, and a dev reload is not a
    // reinstall — an author editing a hook should not have to re-enter the
    // credentials or re-fetch whatever the extension had cached.
    expect(await host.invokeHook('bench', key: 'reloadable', method: 'kvGet'), 'kept');
  });

  test('a bundle that fails to evaluate leaves the extension unloaded, and the next reload recovers', () async {
    final host = await hostWith([
      ExtensionBundle(key: 'reloadable', source: _versioned('first')),
      const ExtensionBundle(key: 'bystander', source: _bystanderSource),
    ]);

    await expectLater(
      host.reloadBundle(const ExtensionBundle(key: 'reloadable', source: 'this is not valid javascript {')),
      throwsA(isA<ExtensionHostException>()),
    );

    // Deliberately unloaded rather than reverted: nothing keeps the old source
    // to put back, and a dev server that failed to build has nothing to serve.
    // The operator sees the build error; the runtime does not pretend.
    await expectLater(answerOf(host, 'reloadable'), throwsA(isA<ExtensionHostException>()));
    expect(await answerOf(host, 'bystander'), 'bystander', reason: 'a broken bundle must not take the runtime down with it');

    // The recovery path is the one an author actually walks — save a typo,
    // fix it, save again — so a runtime that could not accept the fix would
    // make the whole loop useless.
    await host.reloadBundle(ExtensionBundle(key: 'reloadable', source: _versioned('third')));
    expect(await answerOf(host, 'reloadable'), 'third');
  });

  test('reloading applies the manifest\'s fetch allowlist as it stood at that build', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.host);
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });

    const fetcher = '''
__polo.defineExtension({
  key: 'fetcher',
  name: 'Fetcher',
  version: '0.0.1',
  onActivation: function (api) {
    boundHostCall = api.hostCall
    api.registerHook('bench', { key: 'fetcher', hook: {
      get: async function (args) {
        try {
          await boundHostCall('fetch', { url: args.url })
          return 'allowed'
        } catch (e) {
          return 'blocked'
        }
      },
    }})
  },
})
var boundHostCall = null
''';

    final host = await hostWith(
      [const ExtensionBundle(key: 'fetcher', source: fetcher)],
      allowlists: {
        'fetcher': const ['first.example.com'],
      },
      httpClient: client,
    );
    expect(await host.invokeHook('bench', key: 'fetcher', method: 'get', args: {'url': 'https://second.example.com/x'}), 'blocked');

    // `domains` is a manifest field, so a dev build can change it between two
    // saves. Without carrying it through the reload the runtime would enforce
    // the allowlist from boot for the rest of the session, and an author who
    // just added a domain would see their fetch blocked with nothing in the
    // code to explain it.
    await host.reloadBundle(
      const ExtensionBundle(key: 'fetcher', source: fetcher),
      domains: const ['first.example.com', 'second.example.com'],
    );
    expect(await host.invokeHook('bench', key: 'fetcher', method: 'get', args: {'url': 'https://second.example.com/x'}), 'allowed');
    expect(requested, ['second.example.com']);
  });

  test('an omitted domains list leaves the capability as it was', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    const fetcher = '''
__polo.defineExtension({
  key: 'fetcher', name: 'Fetcher', version: '0.0.1',
  onActivation: function (api) {
    boundHostCall = api.hostCall
    api.registerHook('bench', { key: 'fetcher', hook: {
      get: async function (args) {
        try { await boundHostCall('fetch', { url: args.url }); return 'allowed' }
        catch (e) { return 'blocked' }
      },
    }})
  },
})
var boundHostCall = null
''';
    final host = await hostWith(
      [const ExtensionBundle(key: 'fetcher', source: fetcher)],
      allowlists: {
        'fetcher': const ['first.example.com'],
      },
      httpClient: client,
    );

    // The dev client omits `domains` when it has no manifest to hand. Reading
    // that as "no domains" would silently revoke the extension's network
    // access on every reload.
    await host.reloadBundle(const ExtensionBundle(key: 'fetcher', source: fetcher));
    expect(await host.invokeHook('bench', key: 'fetcher', method: 'get', args: {'url': 'https://first.example.com/x'}), 'allowed');
  });
}
