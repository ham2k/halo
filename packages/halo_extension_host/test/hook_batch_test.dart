// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// invokeHookBatch against the real kernel: several single-hook calls in one
// crossing, each answered as invokeHook would answer it.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';
import 'support/fake_clock.dart';

// Two extensions answering one ref type: `alpha` claims the whole family, and
// `kilo` claims only the codes beginning with K — the shape the QSO parties
// use to answer legacy references. Plus a hook that throws and one that never
// answers.
const _alphaSource = '''
__polo.defineExtension({
  key: 'alpha',
  name: 'Alpha',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('ref:alpha', { key: 'alpha', hook: {
      decorateRef: async function (args) { return Object.assign({}, args.ref, { name: 'Alpha ' + args.ref.ref }) },
    } })
    api.registerHook('ref:broken', { key: 'alpha', hook: {
      decorateRef: async function () { throw new Error('this program is down') },
    } })
    api.registerHook('ref:stalled', { key: 'alpha', hook: {
      decorateRef: function () { return new Promise(function () {}) },
    } })
    api.registerHook('ref:circular', { key: 'alpha', hook: {
      decorateRef: async function () { var a = {}; a.self = a; return a },
    } })
  },
})
''';

const _kiloSource = '''
__polo.defineExtension({
  key: 'kilo',
  name: 'Kilo',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('ref:alpha/k', { key: 'kilo', hook: {
      decorateRef: async function (args) { return Object.assign({}, args.ref, { name: 'Kilo ' + args.ref.ref }) },
    } })
  },
})
''';

HookCall _decorate(String type, String code) => (
  category: 'ref:$type',
  key: null,
  method: 'decorateRef',
  args: {
    'ref': {'type': type, 'ref': code},
  },
);

void main() {
  requireBundles();

  Future<ExtensionHost> start() async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: const [
        ExtensionBundle(key: 'alpha', source: _alphaSource),
        ExtensionBundle(key: 'kilo', source: _kiloSource),
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);
    await host.activated;
    return host;
  }

  test('each call is routed by its own reference, as invokeHook routes it', () async {
    // A batch that chose one hook per CATEGORY would send K-1 to `alpha`, and
    // a party's legacy reference would be decorated by the wrong program.
    final host = await start();
    final entries = await host.invokeHookBatch([_decorate('alpha', 'K-1'), _decorate('alpha', 'X-1')]);

    expect([for (final e in entries) (e['value'] as Map)['name']], ['Kilo K-1', 'Alpha X-1']);
    expect((await host.invokeHook('ref:alpha', method: 'decorateRef', args: _decorate('alpha', 'K-1').args))['name'], 'Kilo K-1');
  });

  test('answers in call order, one entry per call, in ONE crossing', () async {
    final host = await start();
    final before = host.samples.length;
    final entries = await host.invokeHookBatch([for (var i = 0; i < 5; i++) _decorate('alpha', 'X-$i')]);

    expect([for (final e in entries) (e['value'] as Map)['ref']], ['X-0', 'X-1', 'X-2', 'X-3', 'X-4']);
    // One sample per crossing: five calls through invokeHook would record five.
    expect(host.samples.length - before, 1);
  });

  test('a call that fails, or has no hook, is its own entry and costs the others nothing', () async {
    final host = await start();
    final entries = await host.invokeHookBatch([_decorate('broken', 'B-1'), _decorate('alpha', 'X-1'), _decorate('nobody', 'N-1')]);

    expect(entries[0]['ok'], false);
    expect(entries[0]['error'], contains('this program is down'));
    expect(entries[1]['ok'], true);
    expect(entries[2]['ok'], false);
    expect(entries[2]['error'], contains('no hook registered'));
    // Flagged, not left to the message: "no program handles this" is an answer
    // about the reference, and a host that read it as a failure would keep
    // asking a question nothing will ever answer.
    expect(entries[2]['noHandler'], true);
    expect(entries[0]['noHandler'], isNull, reason: 'a hook that threw is a failure, not an absent handler');
  });

  test('a hook answering something JSON cannot carry fails alone', () async {
    // The answers cross as ONE message, so an answer that cannot be
    // serialized — a circular object, a BigInt — would otherwise fail every
    // call in the batch along with its own.
    final host = await start();
    final entries = await host.invokeHookBatch([_decorate('circular', 'C-1'), _decorate('alpha', 'X-1')]);

    expect(entries[0]['ok'], false);
    expect((entries[1]['value'] as Map)['name'], 'Alpha X-1');
  });

  test('a call whose arguments cannot be encoded fails alone', () async {
    // Encoded together, one reference carrying a value JSON cannot hold would
    // fail every call in the batch along with its own.
    final host = await start();
    final entries = await host.invokeHookBatch([
      (
        category: 'ref:alpha',
        key: null,
        method: 'decorateRef',
        args: {
          'ref': {'type': 'alpha', 'ref': 'X-0', 'bad': Object()},
        },
      ),
      _decorate('alpha', 'X-1'),
    ]);

    expect(entries[0]['ok'], false);
    expect(entries[0]['error'], contains('not JSON-encodable'));
    expect((entries[1]['value'] as Map)['name'], 'Alpha X-1');
  });

  test(
    'a call that never answers keeps the ones that did, when partial results are asked for',
    () => runOnFakeClock((_) async {
      // The runtime answers a batch with ONE message, so without the narration a
      // host that stops waiting would throw away every reference that was
      // decorated long before the stalled one gave up.
      final host = await start();
      final entries = await host.invokeHookBatch(
        [_decorate('alpha', 'X-1'), _decorate('stalled', 'S-1'), _decorate('alpha', 'X-2')],
        timeout: const Duration(seconds: 1),
        partialOnTimeout: true,
      );

      expect(entries, hasLength(3));
      expect((entries[0]['value'] as Map)['name'], 'Alpha X-1');
      expect(entries[1]['ok'], false);
      expect(entries[1]['timedOut'], true, reason: 'a call that never answered must be distinguishable from one that answered with an error');
      expect((entries[2]['value'] as Map)['name'], 'Alpha X-2', reason: 'salvaged entries arrive in settle order and must come back in call order');
    }),
  );

  test(
    'a batch of one that runs out of time answers with its own timed-out entry',
    () => runOnFakeClock((_) async {
      // A batch of one is not narrated — there is nothing else to salvage — so
      // its timed-out entry is made up host-side rather than thrown as the
      // whole batch failing.
      final host = await start();
      final entries = await host.invokeHookBatch([_decorate('stalled', 'S-1')], timeout: const Duration(seconds: 1), partialOnTimeout: true);

      expect(entries, hasLength(1));
      expect(entries.single['ok'], false);
      expect(entries.single['timedOut'], true);
    }),
  );

  test(
    'still throws on a timeout when the caller did not ask for partial results',
    () => runOnFakeClock((_) async {
      final host = await start();
      await expectLater(
        host.invokeHookBatch([_decorate('alpha', 'X-1'), _decorate('stalled', 'S-1')], timeout: const Duration(seconds: 1)),
        throwsA(isA<HookTimeoutException>()),
      );
    }),
  );

  test('an empty batch answers without crossing', () async {
    final host = await start();
    final before = host.samples.length;
    expect(await host.invokeHookBatch(const []), isEmpty);
    expect(host.samples.length, before);
  });
}
