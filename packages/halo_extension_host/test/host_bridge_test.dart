// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The host's way into the kernel — invoking any hook with its extension's
// context, answering host calls, delivering socket events, unloading a
// bundle, moving the clock — is closed to bundles, which share the kernel's
// realm. Left on the global, any bundle could run ham2k-lofi's
// `syncTransport` with LoFi's token, settle another extension's host calls
// or unload it. So the bundles here reach for every entry the way a hostile
// one would, through the REAL kernel, and the kernel's two names are held to
// the extension API levels that use them.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// Every entry the host calls into the kernel (kernel.ts, HOST_ENTRIES), but
/// `socketEvent`, which `__polo` carries as a no-op for older SDKs.
const _hostEntries = [
  'beginBundle',
  'endBundle',
  'activateAll',
  'unloadBundle',
  'activateReloaded',
  'invokeHook',
  'invokeHookBatch',
  'invokeHookAll',
  'invalidateContext',
  'setClockTravel',
  'setMonotonicNow',
  'runTimers',
  'setAppVisible',
  'hostResponse',
];

/// Records whether its command hook ever ran, and holds a socket listener
/// that records any event it is handed.
const _victim = '''
globalThis.__victimRan = false
globalThis.__victimSocketEvents = []
__halo.defineExtension({
  key: 'victim',
  name: 'victim',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'victim', hook: { act: async () => { globalThis.__victimRan = true; return 'acted' } } })
    globalThis.__victimSocket = __halo.registerSocket((event) => { globalThis.__victimSocketEvents.push(event.type) })
  },
})
''';

/// Loaded at extension API 15, so `__polo` answers too and every entry is
/// tried on both names.
const _thief = r'''
const attempt = (fn) => {
  try {
    fn()
    return 'allowed'
  } catch (e) {
    return String(e.message)
  }
}
__halo.defineExtension({
  key: 'thief',
  name: 'thief',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('bench', {
      key: 'thief',
      hook: {
        exposed: async ({ entries }) => entries.filter((name) => name in __halo || name in globalThis.__polo),
        bridge: async ({ token }) => {
          globalThis.__victimRan = false
          return attempt(() => __halo.bridge(token, 'invokeHook', 9001, 'command', 'victim', 'act', '{}'))
        },
        victimRan: async () => globalThis.__victimRan,
        claim: async () => attempt(() => __halo.claimBridge('f'.repeat(64))),
        forgeSocketEvent: async () => {
          const forged = JSON.stringify({ type: 'message', data: 'forged' })
          for (const kernel of [__halo, globalThis.__polo]) {
            try { kernel.socketEvent(globalThis.__victimSocket, forged) } catch (e) {}
          }
          return globalThis.__victimSocketEvents
        },
      },
    })
  },
})
''';

/// Opens a socket at evaluation, before it has a bound host call: the public
/// one refuses it, and the kernel is what must fail it.
const _early = r'''
globalThis.__earlyEvents = []
const earlyId = __halo.registerSocket((event) => { globalThis.__earlyEvents.push(event.type) })
__halo.hostCall('webSocketOpen', { socketId: earlyId, url: 'wss://example.com/' }).catch(() => {})
__halo.defineExtension({
  key: 'early',
  name: 'early',
  version: '0.0.1',
  onActivation({ registerHook, hostCall }) {
    registerHook('bench', {
      key: 'early',
      hook: {
        events: async () => globalThis.__earlyEvents,
        reopen: async () => {
          try {
            await hostCall('webSocketOpen', { socketId: earlyId, url: 'wss://example.com/' })
            return 'opened'
          } catch (e) {
            return String(e.message)
          }
        },
      },
    })
  },
})
''';

/// Reports what the kernel's two names answer, as seen from bundle [key]:
/// whether `__polo` is there, reaches the same kernel, and carries the
/// caller-named form entries `__halo` does not.
String _namesProbe(String key) =>
    '''
__halo.defineExtension({
  key: '$key',
  name: '$key',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('bench', {
      key: '$key',
      hook: {
        names: async () => ({
          polo: typeof globalThis.__polo,
          sameKernel: globalThis.__polo?.defineExtension === globalThis.__halo.defineExtension,
          poloForms: [typeof globalThis.__polo?.registerDynamicForm, typeof globalThis.__polo?.host?.showForm],
          haloForms: [typeof globalThis.__halo.registerDynamicForm, typeof globalThis.__halo.host],
        }),
      },
    })
  },
})
''';

/// Tries to take `__polo` before any older bundle evaluates, both ways a
/// bundle could: assigning it, and defining it.
const _squatter = '''
const fake = { defineExtension() {} }
try { globalThis.__polo = fake } catch (e) {}
try { Object.defineProperty(globalThis, '__polo', { value: fake }) } catch (e) {}
__halo.defineExtension({ key: 'squatter', name: 'squatter', version: '0.0.1', onActivation() {} })
''';

const _absent = ['undefined', 'undefined'];

Future<ExtensionHost> _start(List<ExtensionBundle> extensions) async {
  final host = await ExtensionHost.start(kernelSource: bundleSource('kernel'), extensions: extensions, useIsolate: false, onHostCall: nullHostCall);
  await host.activated;
  return host;
}

Future<dynamic> _bench(ExtensionHost host, String key, String method, [Map<String, dynamic> args = const {}]) =>
    host.invokeHook('bench', key: key, method: method, args: args);

void main() {
  requireBundles();

  group('a bundle', () {
    late ExtensionHost host;

    setUpAll(() async {
      host = await _start([const ExtensionBundle(key: 'victim', source: _victim), const ExtensionBundle(key: 'thief', source: _thief, api: 15)]);
    });

    tearDownAll(() => host.dispose());

    test('finds none of the host entries on the kernel', () async {
      expect(await _bench(host, 'thief', 'exposed', {'entries': _hostEntries}), isEmpty);
    });

    for (final (label, token) in [('none', null), ('empty', ''), ('a guess', '0' * 64)]) {
      test("cannot call the bridge without the host's token ($label)", () async {
        expect(await _bench(host, 'thief', 'bridge', {'token': token}), contains("the host's to call"));
        // Asked a round trip later: a hook the bridge let through runs after
        // the call that asked for it has returned.
        expect(await _bench(host, 'thief', 'victimRan'), isFalse, reason: "another extension's hook must not run with that extension's context");
      });
    }

    test('cannot claim the bridge after the host has', () async {
      expect(await _bench(host, 'thief', 'claim'), contains('already claimed'));
    });

    test("cannot hand an event to another extension's socket", () async {
      expect(await _bench(host, 'thief', 'forgeSocketEvent'), isEmpty);
    });

    test('the host still reaches every extension through the bridge', () async {
      expect(await host.invokeHook('command', key: 'victim', method: 'act'), 'acted');
    });
  });

  /// What a bundle reading both names sees once a bundle below API 16 is in.
  const olderNames = {
    'polo': 'object',
    'sameKernel': true,
    'poloForms': ['function', 'function'],
    'haloForms': _absent,
  };

  test('a socket opened before activation is failed by the kernel, and its id is never open again', () async {
    final host = await _start([const ExtensionBundle(key: 'early', source: _early)]);
    addTearDown(host.dispose);
    // Without the kernel failing it, the socket sits connecting for good.
    expect(await _bench(host, 'early', 'events'), ['error', 'close']);
    // Without the id taken at refusal, any bundle could open its own
    // connection on it and feed that listener.
    expect(await _bench(host, 'early', 'reopen'), contains('is not reserved, or already in use'));
  });

  group('the kernel is __halo, and __polo', () {
    test('answers nothing when every bundle is at extension API 16 or built with the app', () async {
      final host = await _start([
        ExtensionBundle(key: 'current', source: _namesProbe('current'), api: 16),
        ExtensionBundle(key: 'builtin', source: _namesProbe('builtin')),
      ]);
      addTearDown(host.dispose);
      expect(await _bench(host, 'current', 'names'), {'polo': 'undefined', 'sameKernel': false, 'poloForms': _absent, 'haloForms': _absent});
    });

    test('is the same kernel, with the caller-named form entries, once a bundle below extension API 16 is loaded', () async {
      final host = await _start([
        ExtensionBundle(key: 'current', source: _namesProbe('current'), api: 16),
        ExtensionBundle(key: 'older', source: _namesProbe('older').replaceAll('__halo.defineExtension', '__polo.defineExtension'), api: 15),
      ]);
      addTearDown(host.dispose);
      expect(await _bench(host, 'older', 'names'), olderNames);
    });

    test('cannot be taken by a bundle that evaluates before an older one', () async {
      final host = await _start([
        const ExtensionBundle(key: 'squatter', source: _squatter, api: 16),
        ExtensionBundle(key: 'older', source: _namesProbe('older').replaceAll('__halo.defineExtension', '__polo.defineExtension'), api: 15),
      ]);
      addTearDown(host.dispose);
      // The older bundle defined itself through `__polo`, so it reached the
      // real kernel at all only if the squat failed.
      expect(await _bench(host, 'older', 'names'), olderNames);
    });
  });
}
