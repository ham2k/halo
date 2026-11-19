// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.randomBytes(length)` — the sandbox's only secure entropy. An extension
// signing with a private key (LoTW's RSA blinding) uses these where a browser
// would use `crypto`; without them its library falls back to `Math.random()`
// and signs with predictable blinding, which nothing downstream can detect.
// So the property that matters most is the refusal: no secure source must be
// an error, never a weaker answer.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/engine_runtime.dart' show kMaxRandomBytes, secureRandomBase64;

import 'support/bundles.dart';

void main() {
  group('secureRandomBase64', () {
    test('answers exactly the bytes asked for, at both bounds', () {
      for (final length in [1, 32, kMaxRandomBytes]) {
        expect(base64Decode(secureRandomBase64(length)), hasLength(length));
      }
    });

    test('refuses a length outside 1 to the cap, or not an int', () {
      // The SDK checks the same bound, but a bundle can reach the bridge
      // without it, so the host's check is the one that holds.
      for (final length in [0, -1, kMaxRandomBytes + 1, 1.5, '16', null]) {
        expect(() => secureRandomBase64(length), throwsArgumentError, reason: '$length');
      }
    });

    test('a platform with no secure source fails the call rather than falling back', () {
      // `Random.secure()` throws UnsupportedError there. A catch that
      // substituted `Random()` would pass every other test in this file.
      expect(() => secureRandomBase64(16, source: () => throw UnsupportedError('no secure source')), throwsUnsupportedError);
    });

    test('each call draws fresh bytes', () {
      // A cached buffer would hand two signatures the same blinding.
      expect(secureRandomBase64(32), isNot(secureRandomBase64(32)));
    });
  });

  group('through the kernel', () {
    requireBundles();

    // A bundle that hands back what `randomBytes` answers, or the refusal's
    // message, so a rejected call is a value the test can read.
    const probe = '''
      globalThis.__halo.defineExtension({
        key: 'alpha',
        name: 'alpha probe',
        version: '0.0.1',
        onActivation({ registerHook, hostCall }) {
          registerHook('bench', {
            key: 'alpha',
            hook: {
              get: async (args) => {
                try {
                  return { bytes: await hostCall('randomBytes', { length: args.length }) }
                } catch (e) {
                  return { error: String(e && e.message || e) }
                }
              },
            },
          });
        },
      });
    ''';

    Future<Map<String, dynamic>> ask(ExtensionHost host, Object? length) async => Map<String, dynamic>.from(
      await host.invokeHook('bench', key: 'alpha', method: 'get', args: {'length': length}, timeout: const Duration(seconds: 10)) as Map,
    );

    test('a bundle receives the bytes asked for, and a bad length is refused at the host', () async {
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [const ExtensionBundle(key: 'alpha', source: probe)],
        onHostCall: nullHostCall,
      );
      addTearDown(host.dispose);

      final answer = await ask(host, 32);
      expect(base64Decode(answer['bytes'] as String), hasLength(32));

      // Answered by the host itself: the app's handler (nullHostCall here)
      // would answer null for a method it does not know, not refuse it.
      for (final length in [0, kMaxRandomBytes + 1, 'many']) {
        final refused = await ask(host, length);
        expect(refused['bytes'], isNull, reason: '$length');
        expect(refused['error'], contains('randomBytes length'), reason: '$length');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
