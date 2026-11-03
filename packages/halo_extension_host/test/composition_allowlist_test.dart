// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which hooks one extension may invoke inside the runtime. A composed hook
// runs with its OWN context — its account, its settings — so a bundle that
// could reach ham2k-lofi's `syncTransport` or any `command` hook through
// `__halo.invokeLocal` would act with that extension's credentials. The kernel
// allows only the data categories extensions actually compose, and the
// refusal must hold for a bundle that skips the SDK and its narrowed types,
// which is why these drive `__halo` directly through the REAL kernel. `form`
// and `bench` are refused cases because the app's identity tests probe
// accounts through both; allowing either would hand one probe another's.
// The host's own way in, which reaches every category, is closed to bundles
// separately (host_bridge_test).

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// Answers every category with its name and records each hook that actually
/// ran. `lookup` has a second, lower-priority hook, so a fold has somewhere to
/// go.
const _target = '''
globalThis.__composeRan = []
const answer = (category, from = category, key = 'target', priority = 0) => ({
  key,
  priority,
  hook: {
    ask: async (args) => {
      globalThis.__composeRan.push(from)
      return { from, seen: args.seen ?? [] }
    },
  },
})

__halo.defineExtension({
  key: 'target',
  name: 'target',
  version: '0.0.1',
  onActivation({ registerHook }) {
    for (const category of ['adifFields', 'callNotes', 'export', 'lookupService', 'recentContextLookup', 'syncTransport', 'command', 'account', 'form', 'bench', 'ref:test']) {
      registerHook(category, answer(category))
    }
    registerHook('lookup', answer('lookup', 'lookup', 'target', 1))
    registerHook('lookup', answer('lookup', 'second lookup', 'target_second', 0))
  },
})
''';

/// Composes through `__halo` and reports what came back, or why it was
/// refused.
const _caller = '''
__halo.defineExtension({
  key: 'caller',
  name: 'caller',
  version: '0.0.1',
  onActivation({ registerHook }) {
    registerHook('command', { key: 'caller', hook: { ask: async () => 'own command' } })
    registerHook('bench', {
      key: 'caller',
      hook: {
        compose: async ({ category, key, tamper }) => {
          globalThis.__composeRan = []
          const includes = Array.prototype.includes
          if (tamper) Array.prototype.includes = () => true
          try {
            const entries = await __halo.invokeLocal(category, 'ask', {}, true, key ?? null)
            return { answered: entries.map((e) => e.value), ran: globalThis.__composeRan }
          } catch (e) {
            return { refused: String(e.message), ran: globalThis.__composeRan }
          } finally {
            Array.prototype.includes = includes
          }
        },
        composeInOrder: async ({ category }) => {
          globalThis.__composeRan = []
          try {
            const fold = (args, value) => ({ seen: [...args.seen, value.from] })
            const entries = await __halo.invokeLocalSequential(category, 'ask', { seen: [] }, fold)
            return { answered: entries.map((e) => e.value), ran: globalThis.__composeRan }
          } catch (e) {
            return { refused: String(e.message), ran: globalThis.__composeRan }
          }
        },
      },
    })
  },
})
''';

void main() {
  requireBundles();

  late ExtensionHost host;

  setUpAll(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [
        ExtensionBundle(key: 'target', source: _target),
        ExtensionBundle(key: 'caller', source: _caller),
      ],
      useIsolate: false,
      onHostCall: nullHostCall,
    );
    await host.activated;
  });

  tearDownAll(() => host.dispose());

  Future<Map<String, dynamic>> compose(String category, {String? key, bool inOrder = false, bool tamper = false}) async {
    final result = await host.invokeHook(
      'bench',
      key: 'caller',
      method: inOrder ? 'composeInOrder' : 'compose',
      args: {'category': category, 'key': ?key, 'tamper': tamper},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  group('invokeLocal', () {
    for (final category in ['syncTransport', 'command', 'account', 'form', 'bench', 'ref:test']) {
      test('refuses "$category", naming it, before the target hook runs', () async {
        final outcome = await compose(category);
        expect(outcome['refused'], contains('"$category"'));
        expect(outcome['ran'], isEmpty, reason: 'the refusal must come before any hook acts with its own context');
      });
    }

    test("refuses the caller's own hooks outside the allowed categories too", () async {
      final outcome = await compose('command', key: 'caller');
      expect(outcome['refused'], contains('"command"'));
    });

    test('still refuses after a bundle rewrites Array.prototype.includes to say yes', () async {
      // Every bundle shares the kernel's intrinsics; a check made through one
      // is a check the caller answers.
      final outcome = await compose('syncTransport', tamper: true);
      expect(outcome['refused'], contains('"syncTransport"'));
      expect(outcome['ran'], isEmpty);
    });

    // Each is composed by an extension in this repo; one dropped from the list
    // fails here, where dev-commands would swallow the refusal.
    for (final category in ['adifFields', 'callNotes', 'export', 'lookup', 'lookupService', 'recentContextLookup']) {
      test('answers "$category", which extensions compose today', () async {
        final outcome = await compose(category, key: 'target');
        expect(outcome['refused'], isNull);
        expect(outcome['answered'], [
          {'from': category, 'seen': <dynamic>[]},
        ]);
      });
    }
  });

  group('invokeLocalSequential', () {
    test('refuses a category outside the allowlist before any hook runs', () async {
      final outcome = await compose('syncTransport', inOrder: true);
      expect(outcome['refused'], contains('"syncTransport"'));
      expect(outcome['ran'], isEmpty);
    });

    test('answers an allowed category, each hook seeing the fold of the ones before it', () async {
      final outcome = await compose('lookup', inOrder: true);
      expect(outcome['refused'], isNull);
      expect(outcome['ran'], ['lookup', 'second lookup']);
      expect(outcome['answered'], [
        {'from': 'lookup', 'seen': <dynamic>[]},
        {
          'from': 'second lookup',
          'seen': ['lookup'],
        },
      ]);
    });
  });
}
