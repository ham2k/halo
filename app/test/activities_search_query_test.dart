// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The activity search box doubles as a scope selector: a leading `pota:` asks
// only that extension. The risk is over-eager parsing — references and park
// names contain colons too, and treating one as a scope would silently search
// the wrong extension (or none) while looking like it worked. These tests pin
// what counts as a scope and what stays plain search text.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

/// The keys the loaded activity controls would supply.
const _knownKeys = {'pota', 'sota', 'ham2k-lofi', 'my_key'};

void main() {
  group('no scope', () {
    test('plain text searches everything', () {
      final query = ActivitySearchQuery.parse('bear mountain', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.term, 'bear mountain');
    });

    test('an empty box is neither scoped nor a search', () {
      final query = ActivitySearchQuery.parse('   ', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.term, isEmpty);
    });

    test('a colon after something that is not an extension key stays text', () {
      final query = ActivitySearchQuery.parse('US-0001: Something', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.term, 'US-0001: Something');
    });

    test('a leading colon is not a scope', () {
      final query = ActivitySearchQuery.parse(':pota', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.term, ':pota');
    });
  });

  group('scoped', () {
    test('a bare key means "this extension\'s nearby suggestions"', () {
      final query = ActivitySearchQuery.parse('pota:', _knownKeys);
      expect(query.activityKey, 'pota');
      expect(query.term, isEmpty);
    });

    test('text after the key scopes AND searches', () {
      final query = ActivitySearchQuery.parse('pota: bear mtn', _knownKeys);
      expect(query.activityKey, 'pota');
      expect(query.term, 'bear mtn');
    });

    test('the key is lowercased, so typing SOTA: still matches the hook', () {
      expect(ActivitySearchQuery.parse('SOTA: W2', _knownKeys).activityKey, 'sota');
    });

    test('keys may carry digits, dashes and underscores', () {
      expect(ActivitySearchQuery.parse('ham2k-lofi: x', _knownKeys).activityKey, 'ham2k-lofi');
      expect(ActivitySearchQuery.parse('my_key: x', _knownKeys).activityKey, 'my_key');
    });

    test('only the FIRST colon splits — later ones stay in the search text', () {
      final query = ActivitySearchQuery.parse('pota: US-0001: park', _knownKeys);
      expect(query.activityKey, 'pota');
      expect(query.term, 'US-0001: park');
    });
  });

  test('the prefix tapping a type inserts round-trips back to that scope', () {
    final query = ActivitySearchQuery.parse(ActivitySearchQuery.scopePrefixFor('sota'), _knownKeys);
    expect(query.activityKey, 'sota');
    expect(query.term, isEmpty);
  });
}
