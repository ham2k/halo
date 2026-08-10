// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.secret(name)` — how an extension reads a build-time value. Both real
// credentials (an award's API key) and per-build configuration (an OAuth client
// id that differs per edition) live in the same store, the way every cloud
// platform means the word.
//
// The property under test here is the KERNEL half of scoping: the host holds
// only what each extension may see, and the caller's identity is stamped on by
// the kernel, so no argument can reach another extension's set. WHICH names an
// extension may see is decided a layer up, by name prefix — see
// app/test/secret_policy_test.dart. That binding only exists once the
// kernel is dispatching, so this runs against the real one — with hand-written
// probe bundles rather than real extensions, because what is under test is the
// binding, not any award's code.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// A bundle that hands back whatever `host.secret` gives it, including when
  /// it tries to name somebody else's identity explicitly.
  String probe(String key) => '''
    globalThis.__polo.defineExtension({
      key: '$key',
      name: '$key probe',
      version: '0.0.1',
      onActivation({ registerHook, hostCall }) {
        registerHook('bench', {
          key: '$key',
          hook: {
            get: async (args) => await hostCall('secret', { name: args.name }),
            // Identity params are injected kernel-side and cannot be spoofed;
            // whatever this passes must be ignored.
            spoof: async (args) =>
              await hostCall('secret', { name: args.name, extensionKey: 'other' }),
          },
        });
      },
    });
  ''';

  Future<ExtensionHost> startWith(Map<String, Map<String, String>> secrets) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [
        ExtensionBundle(key: 'alpha', source: probe('alpha')),
        ExtensionBundle(key: 'other', source: probe('other')),
      ],
      secrets: secrets,
      onHostCall: nullHostCall,
    );
    addTearDown(host.dispose);
    return host;
  }

  Future<dynamic> ask(ExtensionHost host, String who, String name, {bool spoof = false}) =>
      host.invokeHook('bench', key: who, method: spoof ? 'spoof' : 'get',
          args: {'name': name}, timeout: const Duration(seconds: 10));

  test('an extension reads the values resolved for it', () async {
    // Several names per extension, because one is not the shape: SOTA has a
    // client id and a redirect for each build edition.
    final host = await startWith(const {
      'alpha': {'ALPHA_KEY': 'a-key', 'ALPHA_CLIENT_ID': 'a-client'},
      'other': {'OTHER_KEY': 'o-key'},
    });

    expect(await ask(host, 'alpha', 'ALPHA_KEY'), 'a-key');
    expect(await ask(host, 'alpha', 'ALPHA_CLIENT_ID'), 'a-client');
    expect(await ask(host, 'other', 'OTHER_KEY'), 'o-key');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a name outside its own set is not readable', () async {
    // The host only ever holds what the policy resolved, so asking for
    // somebody else's name reaches nothing even though the build has it.
    final host = await startWith(const {
      'alpha': {'ALPHA_KEY': 'a-key'},
      'other': {'OTHER_KEY': 'o-key'},
    });

    expect(await ask(host, 'alpha', 'OTHER_KEY'), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('naming another extension in the call does not reach its values', () async {
    // `alpha` asks as `other`. The kernel overwrites the identity, so the
    // lookup still happens in alpha's own set — and finds nothing.
    final host = await startWith(const {
      'alpha': {'ALPHA_KEY': 'a-key'},
      'other': {'OTHER_KEY': 'o-key'},
    });

    expect(await ask(host, 'alpha', 'OTHER_KEY', spoof: true), isNull);
    expect(await ask(host, 'alpha', 'ALPHA_KEY', spoof: true), 'a-key');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a build with nothing configured hands back null, not an error', () async {
    // A fresh checkout, a fork and every CI build without the values are all
    // this case. Consumers degrade — no spots — rather than failing.
    final host = await startWith(const {});
    expect(await ask(host, 'alpha', 'ALPHA_KEY'), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
