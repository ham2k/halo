// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scope word typed without its colon prefers the extensions it names rather
// than asking them alone, and what they are asked depends on whether the word
// stood alone. Alone, it asks them for their own list, as a scope does — so
// they must be told they are scoped, and their failing is the search failing:
// what the others found for the word as text is not the list that was asked
// for, and "nothing found" would send the operator looking for a park that
// is there. With text after it, they search that text and their failure is
// only a lost ordering.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import '../support/fake_extension_host.dart';

Map<String, Object?> _stubs({required Object? preferred, required List<Map<String, dynamic>> everyone, List<Object?>? asked}) => {
  'activity:ham2k-pota:suggest': preferred is Exception
      ? preferred
      : (Object? args) {
          asked?.add(args);
          return preferred;
        },
  'activity:*:suggest': (Object? args) {
    asked?.add(args);
    return everyone;
  },
};

const _park = {'type': 'pota', 'ref': 'US-0001', 'name': 'Bear Mountain'};

void main() {
  test('a word alone asks the preferred extension for its own list, and the others for the word', () async {
    final asked = <Object?>[];
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost(
        _stubs(
          preferred: const [_park],
          everyone: const [
            {'key': 'ham2k-sota', 'ok': true, 'value': <Object>[]},
          ],
          asked: asked,
        ),
      ),
    );

    await extensions.suggestActivities(const {}, searchTerm: 'pota', preferredKeys: const ['ham2k-pota']);

    final preferredArgs = asked.firstWhere((a) => (a as Map)['scoped'] == true) as Map;
    expect(preferredArgs.containsKey('searchTerm'), isFalse, reason: 'its own list, not a search for "pota"');
    final everyoneArgs = asked.firstWhere((a) => (a as Map)['scoped'] != true) as Map;
    expect(everyoneArgs['searchTerm'], 'pota');
  });

  test('a word alone whose extensions all fail fails the search, whatever the others found', () async {
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost(
        _stubs(
          preferred: ExtensionHostException('POTA timed out'),
          everyone: const [
            {'key': 'ham2k-sota', 'ok': true, 'value': <Object>[]},
          ],
        ),
      ),
    );

    final result = await extensions.suggestActivities(const {}, searchTerm: 'pota', preferredKeys: const ['ham2k-pota']);
    expect(result.allSourcesFailed, isTrue);
  });

  test('a word with text after it loses only its ordering when its extensions fail', () async {
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost(
        _stubs(
          preferred: ExtensionHostException('POTA timed out'),
          everyone: const [
            {
              'key': 'ham2k-sota',
              'ok': true,
              'value': [_park],
            },
          ],
        ),
      ),
    );

    final result = await extensions.suggestActivities(
      const {},
      searchTerm: 'pota bear mtn',
      preferredKeys: const ['ham2k-pota'],
      preferredSearchTerm: 'bear mtn',
    );
    expect(result.allSourcesFailed, isFalse);
    expect(result.suggestions.map((s) => s['ref']), ['US-0001']);
  });
}
