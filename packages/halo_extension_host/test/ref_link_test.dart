// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `linkForRef` through the real bundles, dispatched the way the operation
// sheet asks for it — by `ref:<type>` alone, with no extension key — in both
// activity shapes: the SDK's `referenceActivity` factory (WWFF) and a
// hand-written activity handler (POTA, SOTA).
//
// One host carries every key, because booting one costs ~343ms against a hook
// call's ~1.3ms and none of these hooks touch the host at all — they build a
// string from the reference and nothing else, which is the property that lets
// the operation sheet ask for a link on every refs change.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> startHost() => sharedHost(['ham2k-wwff', 'ham2k-pota', 'ham2k-sota'], onHostCall: nullHostCall);

  Future<Map?> linkFor(String type, String? ref) async {
    final host = await startHost();
    final result = await host.invokeHook(
      'ref:$type',
      method: 'linkForRef',
      args: {
        'ref': {'type': type, 'ref': ?ref},
      },
    );
    return result as Map?;
  }

  group('activities', () {
    test('a factory-built program links to the reference page, upper-cased, and names nothing', () async {
      // Lower case in, upper case out: the operator types what they like and
      // the program's own page is keyed by the canonical code.
      final link = await linkFor('wwffActivation', 'kff-1234');
      expect(link?['url'], 'https://wwff.co/directory/?showRef=KFF-1234');
      // No label: the core names the row instead. A factory handler can be
      // registered for another program's reference types, and a label built
      // from its own program name would have a screen reader announce the
      // wrong program on them.
      expect(link?['label'], isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a reference the program would not accept gets no link', () async {
      // The trap: a half-typed code still has a `ref` on it while the operator
      // is editing, and a link built from one lands on a page that cannot
      // exist. Two digits is short of a WWFF reference.
      expect(await linkFor('wwffActivation', 'KFF-12'), isNull);
      expect(await linkFor('wwffActivation', ''), isNull);
      expect(await linkFor('wwffActivation', null), isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('POTA and SOTA link to their own directories', () async {
      expect((await linkFor('potaActivation', 'us-0370'))?['url'], 'https://pota.app/#/park/US-0370');
      // The summit path carries the association and region as path segments,
      // so SOTA's slash goes through unescaped — percent-encoding it here
      // would 404 on a page that exists.
      expect((await linkFor('sotaActivation', 've6/hc-255'))?['url'], 'https://www.sotadata.org.uk/en/summit/VE6/HC-255');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a hunted reference links the same way an activated one does', () async {
      // Both types register the same handler; a hunter reading about the park
      // they just worked wants the same page the activator sees.
      expect((await linkFor('pota', 'US-0370'))?['url'], 'https://pota.app/#/park/US-0370');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
