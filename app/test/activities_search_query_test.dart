// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The activity search box doubles as a scope selector: a leading `pota:` asks
// only that extension, and a bare `pota ` merely puts POTA's answers first.
// The risk is over-eager parsing — references and park names contain colons
// AND lead with words too, and treating one as a scope would silently search
// the wrong extension (or none) while looking like it worked. These tests pin
// what counts as a scope, what counts as a preference, and what stays plain
// search text.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

/// The keys the loaded activity controls would supply.
const _knownKeys = {'pota', 'sota', 'ham2k-lofi', 'my_key'};

void main() {
  group('no scope', () {
    test('plain text searches everything', () {
      final query = ActivitySearchQuery.parse('bear mountain', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.preferredKey, isNull);
      expect(query.term, 'bear mountain');
      expect(query.otherTerm, 'bear mountain');
    });

    test('an empty box is neither scoped nor a search', () {
      final query = ActivitySearchQuery.parse('   ', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.preferredKey, isNull);
      expect(query.term, isEmpty);
    });

    test('a colon after something that is not an extension key stays text', () {
      final query = ActivitySearchQuery.parse('US-0001: Something', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.preferredKey, isNull);
      expect(query.term, 'US-0001: Something');
    });

    test('a leading colon is not a scope', () {
      final query = ActivitySearchQuery.parse(':pota', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.term, ':pota');
    });

    test('a first word that merely STARTS with a key is not one', () {
      // `sotabeams` names an antenna maker, not the SOTA extension.
      final query = ActivitySearchQuery.parse('sotabeams dipole', _knownKeys);
      expect(query.activityKey, isNull);
      expect(query.preferredKey, isNull);
      expect(query.term, 'sotabeams dipole');
    });
  });

  group('preferred', () {
    test('a leading key without a colon prefers rather than scopes', () {
      final query = ActivitySearchQuery.parse('sota W7A/MN-001', _knownKeys);
      expect(query.activityKey, isNull, reason: 'the other extensions are still asked');
      expect(query.preferredKey, 'sota');
    });

    test('only the preferred extension gets the key stripped', () {
      // Handing the leftover "bear" to every extension is what this exists to
      // avoid: it buries the SOTA summits under every park named Bear.
      final query = ActivitySearchQuery.parse('sota bear', _knownKeys);
      expect(query.term, 'bear');
      expect(query.otherTerm, 'sota bear');
    });

    test('the key is lowercased, so typing SOTA still matches the hook', () {
      expect(ActivitySearchQuery.parse('SOTA W2', _knownKeys).preferredKey, 'sota');
    });

    test('extra whitespace after the key is not part of the term', () {
      final query = ActivitySearchQuery.parse('  pota   bear mtn  ', _knownKeys);
      expect(query.preferredKey, 'pota');
      expect(query.term, 'bear mtn');
      expect(query.otherTerm, 'pota   bear mtn');
    });
  });

  group('scoped', () {
    test('a bare key means "this extension\'s nearby suggestions"', () {
      final query = ActivitySearchQuery.parse('pota:', _knownKeys);
      expect(query.activityKey, 'pota');
      expect(query.term, isEmpty);
    });

    test('a key alone, no colon, scopes just the same', () {
      // Nothing else is in the box for the other extensions to answer, so the
      // soft form has nothing to be soft about.
      final query = ActivitySearchQuery.parse('pota', _knownKeys);
      expect(query.activityKey, 'pota');
      expect(query.preferredKey, isNull);
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

  group('candidates for a switched-off extension', () {
    // A disabled extension has no controls, so its key is not a known one and
    // the whole box arrives here as plain text. Matching the first word is
    // what turns "sota w7a/mn-001" into an offer to enable SOTA instead of an
    // empty list.
    test('the first word is a key, the whole box is a loose search', () {
      final candidates = extensionSearchCandidates('sota w7a/mn-001');
      expect(candidates.key, 'sota');
      expect(candidates.search, 'sota w7a/mn-001');
    });

    test('the key candidate is lowercased, so SOTA still matches sota', () {
      expect(extensionSearchCandidates('SOTA W2').key, 'sota');
    });

    test('a trailing colon is dropped from both', () {
      expect(extensionSearchCandidates('sota:').key, 'sota');
      expect(extensionSearchCandidates('sota:').search, 'sota');
      expect(extensionSearchCandidates('sota: w7a').key, 'sota');
    });

    test('an empty box asks for nothing', () {
      expect(extensionSearchCandidates('   ').search, isEmpty);
      expect(extensionSearchCandidates(':').search, isEmpty);
    });
  });

  group('text carried into a newly enabled extension\'s scope', () {
    // Tapping "enable SOTA" must not cost the operator the reference they had
    // already typed after the key.
    test('the reference after the key survives', () {
      expect(searchTextAfterKey('sota w7a/mn-001', 'sota'), 'w7a/mn-001');
      expect(searchTextAfterKey('sota: w7a/mn-001', 'sota'), 'w7a/mn-001');
    });

    test('a box that merely NAMED the extension carries nothing', () {
      // Matched by name or keyword rather than by its key — "summits on the
      // air" is not a reference to search for once SOTA is on.
      expect(searchTextAfterKey('summits on the air', 'sota'), isEmpty);
    });

    test('the key alone leaves nothing to carry', () {
      expect(searchTextAfterKey('sota', 'sota'), isEmpty);
      expect(searchTextAfterKey('  SOTA:  ', 'sota'), isEmpty);
    });
  });

  test('the prefix tapping a type inserts round-trips back to that scope', () {
    final query = ActivitySearchQuery.parse(ActivitySearchQuery.scopePrefixFor('sota'), _knownKeys);
    expect(query.activityKey, 'sota');
    expect(query.term, isEmpty);
  });
}
