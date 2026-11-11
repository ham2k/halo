// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bundles written to take another extension's identity, run in the real
// engine against the real kernel. Every bundle shares the kernel's realm, so
// each of these is a way a bundle could reach what the host keeps for another
// extension — its build secrets, its KV state, its keychain credentials —
// by making the kernel name the wrong caller. Each test fails if the kernel
// or the host goes back to trusting what the bundle can shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// The victim: keeps a value in its KV namespace at activation, and owns a
/// build secret the host holds for it.
const _victim = ExtensionBundle(
  key: 'victim',
  source: '''
__halo.defineExtension({
  key: 'victim',
  name: 'Victim',
  version: '0.0.1',
  onActivation: async function (api) {
    await api.hostCall('kvSet', { key: 'token', value: 'victim-kv' })
    api.registerHook('lookup', { key: 'victim', hook: { lookupCall: async function () { return { from: 'victim' } } } })
    api.registerHook('probe', { key: 'victim', hook: { run: async function () { return await api.hostCall('kvGet', { key: 'token' }) } } })
  },
})
''',
);

const _secrets = {
  'victim': {'TOKEN': 'victim-secret'},
};

/// An attacker bundle under key `attacker` whose `probe` hook runs [body] with
/// `api` (its activation API) in scope and answers what it returns.
ExtensionBundle _attacker(String body, {String prelude = '', String key = 'attacker'}) => ExtensionBundle(
  key: key,
  source:
      '''
$prelude
__halo.defineExtension({
  key: '$key',
  name: 'Attacker',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('probe', { key: '$key', hook: { run: async function () { $body } } })
  },
})
''',
);

Future<ExtensionHost> _start(List<ExtensionBundle> bundles) async {
  final host = await ExtensionHost.start(kernelSource: bundleSource('kernel'), extensions: bundles, useIsolate: false, secrets: _secrets);
  addTearDown(host.dispose);
  return host;
}

final _noHook = isA<ExtensionHostException>().having((e) => e.message, 'message', contains('no hook registered'));

Future<Object?> _probe(ExtensionHost host, {String key = 'attacker'}) => host.invokeHook('probe', key: key, method: 'run');

void main() {
  test("a toJSON on a host call's params does not change who is calling", () async {
    // The params are the caller's own object: a kernel that stamps identity
    // into them and writes the whole object out lets an own `toJSON` replace
    // it, stamp and all.
    final host = await _start([
      _victim,
      _attacker('''
        const as = (p) => ({ ...p, toJSON: () => ({ ...p, ns: 'victim', extensionKey: 'victim', kvKey: 'victim' }) })
        return {
          secret: await api.hostCall('secret', as({ name: 'TOKEN' })),
          kv: await api.hostCall('kvGet', as({ key: 'token' })),
        }
      '''),
    ]);
    expect(await _probe(host), {'secret': null, 'kv': null});
  });

  test("a toJSON on Object.prototype rewrites none of the kernel's messages", () async {
    // Every message the kernel sends is written out by `JSON.stringify`, which
    // asks each object for a `toJSON`: one on the shared prototype turns an
    // ordinary log line into a host call naming the victim.
    final host = await _start([
      _victim,
      _attacker('''
        const forged = { type: 'hostCall', callId: 987654, method: 'kvSet', caller: { extensionKey: 'victim', ns: 'victim' }, params: { key: 'token', value: 'pwned' } }
        try {
          Object.defineProperty(Object.prototype, 'toJSON', { value: function () { return this && this.type === 'log' ? forged : this }, configurable: true })
        } catch (e) {}
        __halo.log('anything')
        return 'sent'
      '''),
    ]);
    expect(await _probe(host), 'sent');
    expect(await _probe(host, key: 'victim'), 'victim-kv');
  });

  test('a key that answers differently on a later read is read once', () async {
    // Validated on the first reads, read again at activation, where the host
    // call it is handed gets bound to whatever the key says then.
    final host = await _start([
      _victim,
      const ExtensionBundle(
        key: 'attacker',
        source: '''
var defined = false
__halo.defineExtension({
  get key() { return defined ? 'victim' : 'attacker' },
  name: 'Attacker',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('probe', { key: 'attacker', hook: { run: async function () {
      return { secret: await api.hostCall('secret', { name: 'TOKEN' }), kv: await api.hostCall('kvGet', { key: 'token' }) }
    } } })
  },
})
defined = true
''',
      ),
    ]);
    expect(await _probe(host), {'secret': null, 'kv': null});
  });

  test("a rewritten Set.prototype.has does not let identity methods through the public entry", () async {
    // The public `__halo.hostCall` refuses identity methods. A refusal that
    // asks a Set lets a bundle rewrite `has` to say no, and the call then goes
    // out with the caller's own `ns`.
    final host = await _start([
      _victim,
      _attacker('''
        Set.prototype.has = function () { return false }
        try {
          return { kv: await __halo.hostCall('kvGet', { key: 'token', ns: 'victim', extensionKey: 'victim' }) }
        } catch (e) {
          return { refused: true }
        }
      '''),
    ]);
    expect(await _probe(host), {'refused': true});
  });

  test('a rewritten String.prototype.startsWith mints no other identity', () async {
    // A bundle window that accepts a key by asking `startsWith` accepts any
    // key once a bundle makes that answer yes.
    final host = await _start([
      _attacker(
        "return { secret: await api.hostCall('secret', { name: 'TOKEN' }) }",
        key: 'victim',
        prelude: 'String.prototype.startsWith = function () { return true }',
      ).withKey('evil'),
    ]);
    await expectLater(
      host.invokeHook('probe', key: 'victim', method: 'run'),
      throwsA(_noHook),
      reason: 'no hook registered as "victim" from the bundle "evil"',
    );
  });

  test("a bundle defines nothing under another bundle's key or a retired built-in's", () async {
    // `ham2k-custom` defining `ham2k-custom-text` before that bundle loads
    // would take its name; `call` defining `call-notes` would be handed the
    // credentials the retired built-in left stored under that name.
    final host = await _start([
      _attacker("return 'outer'", key: 'outer', prelude: _defineProbe('outer-inner', 'outer') + _defineProbe('call-notes', 'outer')),
      _attacker("return 'inner'", key: 'outer-inner'),
    ]);
    expect(await _probe(host, key: 'outer-inner'), 'inner');
    await expectLater(_probe(host, key: 'call-notes'), throwsA(_noHook));
  });

  test("invokeLocal refuses a method every object has", () async {
    // `valueOf` answers with the hook object itself: another extension's live
    // hook, through which its account reaches the caller.
    final host = await _start([
      _victim,
      _attacker('''
        try {
          const results = await __halo.invokeLocal('lookup', 'valueOf', {})
          return { leaked: results.some((r) => r.ok && r.value && typeof r.value.lookupCall === 'function') }
        } catch (e) {
          return { refused: true }
        }
      '''),
    ]);
    expect(await _probe(host), {'refused': true});
  });

  group('the frozen realm', () {
    test("a bundle cannot watch another extension's host-call answers through Map.prototype.get", () async {
      // The kernel keeps every pending host call in a Map and finds it again
      // with `get` when the answer comes: a `get` a bundle rewrote would hand
      // it the victim's resolver, and with it the victim's credentials.
      final host = await _start([
        _victim,
        _attacker('''
          if (!globalThis.watching) {
            globalThis.watching = true
            globalThis.overheard = []
            try {
              const get = Map.prototype.get
              Map.prototype.get = function (k) {
                const v = get.call(this, k)
                if (v && typeof v.resolve === 'function') {
                  const resolve = v.resolve
                  v.resolve = function (x) { globalThis.overheard.push(x); return resolve(x) }
                }
                return v
              }
            } catch (e) {}
          }
          return globalThis.overheard.slice()
        '''),
      ]);
      await _probe(host);
      expect(await _probe(host, key: 'victim'), 'victim-kv');
      expect(await _probe(host), isEmpty);
    });

    test("a bundle cannot replace the clock every extension's timers run on", () async {
      // The kernel measures every extension's timer deadlines and budgets on
      // the engine's monotonic clock: one a bundle replaced would let it run
      // past its own budget, or charge another extension's timers for time
      // they never took.
      final host = await _start([
        _attacker('''
          try { globalThis.performance = { now: () => 0 } } catch (e) {}
          try { performance.now = () => 0 } catch (e) {}
          const a = performance.now()
          for (let i = 0; i < 200000; i++) {}
          return performance.now() > a
        '''),
      ]);
      expect(await _probe(host), isTrue);
    });

    test("a bundle's code never runs inside another's error", () async {
      // QuickJS reads Error.stackTraceLimit as a number for every error the
      // realm builds, the kernel's and every extension's: an object there
      // runs its valueOf inside each of them.
      final host = await _start([
        _attacker('''
          let ran = 0
          try { Error.stackTraceLimit = { valueOf() { ran++; return 10 } } } catch (e) {}
          void new Error('anyone').stack
          Error.stackTraceLimit = 5
          return { ran: ran, limit: Error.stackTraceLimit }
        '''),
      ]);
      expect(await _probe(host), {'ran': 0, 'limit': 5});
    });

    test("a bundle cannot read what other extensions write to the console", () async {
      // One console serves every bundle: a wrapped log hears what any other
      // extension logs, tokens included.
      final host = await _start([
        _attacker('''
          const heard = []
          try { console.log = (...a) => { heard.push(a.join(' ')) } } catch (e) {}
          try { globalThis.console = { log: (...a) => { heard.push(a.join(' ')) } } } catch (e) {}
          console.log('token')
          return heard
        '''),
      ]);
      expect(await _probe(host), isEmpty);
    });

    test('a bundle cannot reach the kernel through a stack hook', () async {
      // QuickJS hands Error.prepareStackTrace each frame's function: the
      // kernel's own dispatcher among them, for any error thrown under it.
      final host = await _start([
        _attacker('''
          let frames = 0
          try { Error.prepareStackTrace = (e, sites) => { frames = sites.length; return '' } } catch (e) {}
          try { null.x } catch (e) { void e.stack }
          return { hook: typeof Error.prepareStackTrace, frames: frames }
        '''),
      ]);
      expect(await _probe(host), {'hook': 'undefined', 'frames': 0});
    });

    test('a bundle cannot change the shared library data other extensions read', () async {
      // Every bundle is handed the same library objects: an entity renamed in
      // the DXCC table is renamed for every extension that looks it up.
      final host = await _start([
        _attacker('''
          const entity = __halo.sharedModules['@ham2k/lib-dxcc-data'].DXCC_BY_CODE[291]
          const before = entity.name
          try { entity.name = 'PWNED' } catch (e) {}
          return { before: before, after: __halo.sharedModules['@ham2k/lib-dxcc-data'].DXCC_BY_CODE[291].name }
        '''),
      ]);
      final answer = await _probe(host) as Map;
      expect(answer['after'], answer['before']);
    });

    test('ordinary code that assigns over an inherited name still runs', () async {
      // A frozen prototype makes an assignment to a name it holds throw: the
      // Error subclass setting `this.name`, an object given its own toString,
      // a compiled class helper setting `constructor`.
      final host = await _start([
        _attacker('''
          class AppError extends Error { constructor(m) { super(m); this.name = 'AppError' } }
          const o = {}
          o.toString = () => 'mine'
          function Base() {}
          function Derived() { this.constructor = Derived }
          Derived.prototype = Object.create(Base.prototype)
          new Derived()
          return { name: new AppError('x').name, own: String(o), now: typeof Date.now() }
        '''),
      ]);
      expect(await _probe(host), {'name': 'AppError', 'own': 'mine', 'now': 'number'});
    });
  });

  group('hostCallParams', () {
    test('identity comes from the envelope, whatever the params say', () {
      final params = hostCallParams({
        'caller': {'extensionKey': 'attacker', 'ns': 'attacker', 'kvKey': null, 'duringPanelEvent': null},
        'params': {'key': 'token', 'ns': 'victim', 'kvKey': 'victim', 'extensionKey': 'victim', 'duringPanelEvent': true},
      });
      expect(params, {'key': 'token', 'ns': 'attacker', 'extensionKey': 'attacker'});
    });

    test('params that are not an object carry nothing', () {
      // What a `toJSON` returning a string writes out.
      expect(
        hostCallParams({
          'caller': {'extensionKey': 'attacker'},
          'params': 'victim',
        }),
        {'extensionKey': 'attacker'},
      );
    });
  });
}

String _defineProbe(String key, String answer) =>
    "__halo.defineExtension({ key: '$key', name: 'x', version: '0.0.1', onActivation: function (api) { api.registerHook('probe', { key: '$key', hook: { run: async function () { return '$answer' } } }) } })\n";

extension on ExtensionBundle {
  ExtensionBundle withKey(String key) => ExtensionBundle(key: key, source: source);
}
