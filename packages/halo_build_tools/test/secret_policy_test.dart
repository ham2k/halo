// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which extension may read which build-time secret.
//
// The rule is a NAME PREFIX, and it is load-bearing precisely because nothing
// declares anything: get it wrong in the loose direction and every bundle in
// the app can read TOTA's paid API key; get it wrong in the strict direction
// and SOTA silently cannot log in on a build that has the credentials.
//
// Scoping is also enforced a second time, at the kernel boundary — see
// secrets_test.dart in halo_extension_host. This is the half that decides.

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('an extension reads its own prefix', () {
    test('the shape the rule grants, which nothing in the build now uses', () {
      // Every value an extension once read here has moved into the extension
      // itself as a constant — the award keys because a catalog bundle is a
      // zip anyone can open, SOTA's client id because a native app is a public
      // client with no secret to keep. So the store holds only what Dart
      // reads, and these are the shape of a future grant rather than a live
      // one. The rule stays because withdrawing it would be a second change
      // to reason about on the day a real one arrives.
      expect(extensionMaySeeSecret('tota', 'TOTA_API_KEY'), isTrue);
      expect(extensionMaySeeSecret('sota', 'SOTA_OAUTH_CLIENT_ID_PROD'), isTrue);
    });

    test('a hyphenated key matches the underscored name', () {
      // Extension keys use `-`, environment variable names use `_`. Without
      // this, any such extension would be quietly unable to read its own value.
      expect(extensionMaySeeSecret('call-notes', 'CALL_NOTES_TOKEN'), isTrue);
    });
  });

  group('and nothing else', () {
    test('another extension\'s value', () {
      expect(extensionMaySeeSecret('wwff', 'TOTA_API_KEY'), isFalse);
      expect(extensionMaySeeSecret('pota', 'SOTA_OAUTH_CLIENT_ID_PROD'), isFalse);
    });

    test('a value belonging to no extension', () {
      // The Pusher key lives in the same store because the app reads it
      // directly. That must not make it extension-readable.
      expect(extensionMaySeeSecret('pota', 'PUSHER_KEY'), isFalse);
    });

    test('including an extension whose key spells that value\'s own prefix', () {
      // The hole `appOnlySecrets` exists to close, and the prefix rule alone
      // cannot: the catalog serves Ham2K's own extensions under a reserved
      // prefix which the app STRIPS before asking, so a bundle published as
      // `ham2k-pusher` arrives here as `pusher` — and by name alone it owns
      // `PUSHER_*`. An extension key is not entirely ours to choose.
      expect(extensionMaySeeSecret('pusher', 'PUSHER_KEY'), isFalse);
      expect(extensionMaySeeSecret('pusher', 'PUSHER_CLUSTER'), isFalse);
    });

    test('a longer key that merely starts the same way', () {
      // `sota` must not open `SOTAWATCH_*`, and the boundary is the separator.
      expect(extensionMaySeeSecret('sota', 'SOTAWATCH_API_KEY'), isFalse);
      expect(extensionMaySeeSecret('ota', 'TOTA_API_KEY'), isFalse);
    });

    test('an extension whose key merely starts with the name', () {
      expect(extensionMaySeeSecret('tota-extra', 'TOTA_API_KEY'), isFalse);
    });
  });

  group('the escape hatches', () {
    test('both are empty, which is the state worth defending', () {
      // A value in `sharedSecrets` is one every bundle in the app can read.
      // If this fails, the addition was deliberate — say why in review.
      expect(sharedSecrets, isEmpty);
      expect(grants, isEmpty);
    });

    test('the refusal list is not, and names what Dart alone consumes', () {
      // The opposite direction from the two above: this one only ever takes
      // access away, so an entry LEAVING it is the change worth noticing.
      expect(appOnlySecrets, {'PUSHER_KEY', 'PUSHER_CLUSTER'});
    });
  });
}
