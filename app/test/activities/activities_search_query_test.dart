// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The activity search box doubles as a scope selector: a leading `pota:` asks
// only the extensions serving that reference type, and a bare `pota` merely
// puts their answers first. The risk is over-eager parsing — references and
// park names contain colons AND lead with words too, and treating one as a
// scope would silently search the wrong extension (or none) while looking
// like it worked. These tests pin what counts as a scope, what counts as a
// preference, and what stays plain search text — and which words an
// extension answers to: its declared ref types' words and its own key.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation/activities_enable_tier.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

/// The scope words the loaded activity controls would supply, each mapped to
/// the hook keys that serve it.
const _knownKeys = {
  'pota': ['pota'],
  'sota': ['sota'],
  'ham2k-lofi': ['ham2k-lofi'],
  'my_key': ['my_key'],
};

void main() {
  group('no scope', () {
    test('plain text searches everything', () {
      final query = ActivitySearchQuery.parse('bear mountain', _knownKeys);
      expect(query.activityKeys, isNull);
      expect(query.preferredKeys, isNull);
      expect(query.term, 'bear mountain');
      expect(query.otherTerm, 'bear mountain');
    });

    test('an empty box is neither scoped nor a search', () {
      final query = ActivitySearchQuery.parse('   ', _knownKeys);
      expect(query.activityKeys, isNull);
      expect(query.preferredKeys, isNull);
      expect(query.term, isEmpty);
    });

    test('a colon after something that is not an extension key stays text', () {
      final query = ActivitySearchQuery.parse('US-0001: Something', _knownKeys);
      expect(query.activityKeys, isNull);
      expect(query.preferredKeys, isNull);
      expect(query.term, 'US-0001: Something');
    });

    test('a leading colon is not a scope', () {
      final query = ActivitySearchQuery.parse(':pota', _knownKeys);
      expect(query.activityKeys, isNull);
      expect(query.term, ':pota');
    });

    test('a first word that merely STARTS with a key is not one', () {
      // `sotabeams` names an antenna maker, not the SOTA extension.
      final query = ActivitySearchQuery.parse('sotabeams dipole', _knownKeys);
      expect(query.activityKeys, isNull);
      expect(query.preferredKeys, isNull);
      expect(query.term, 'sotabeams dipole');
    });
  });

  group('preferred', () {
    test('a leading key without a colon prefers rather than scopes', () {
      final query = ActivitySearchQuery.parse('sota W7A/MN-001', _knownKeys);
      expect(query.activityKeys, isNull, reason: 'the other extensions are still asked');
      expect(query.preferredKeys, ['sota']);
    });

    test('only the preferred extension gets the word stripped', () {
      // SOTA matches its search against codes and names as one string, so
      // handed `sota w7a/mn-001` it finds nothing. Handing the leftover to
      // everyone else instead buries the summits under every park named
      // whatever followed.
      final query = ActivitySearchQuery.parse('sota bear', _knownKeys);
      expect(query.term, 'bear');
      expect(query.otherTerm, 'sota bear');
    });

    test('a word alone asks its extensions for their own list, and everyone for the word', () {
      // `llota` is what a search for the program's name types, so the others
      // must still search for it — scoping to LLOTA alone would hide every
      // other extension's answer to "llota". An empty term is what asks the
      // preferred ones as a scope.
      final query = ActivitySearchQuery.parse('pota', _knownKeys);
      expect(query.activityKeys, isNull, reason: 'a word without its colon never scopes');
      expect(query.preferredKeys, ['pota']);
      expect(query.term, isEmpty);
      expect(query.otherTerm, 'pota');
    });

    test('the key is lowercased, so typing SOTA still matches the hook', () {
      expect(ActivitySearchQuery.parse('SOTA W2', _knownKeys).preferredKeys, ['sota']);
    });

    test('extra whitespace after the word is not part of the term', () {
      final query = ActivitySearchQuery.parse('  pota   bear mtn  ', _knownKeys);
      expect(query.preferredKeys, ['pota']);
      expect(query.term, 'bear mtn');
      expect(query.otherTerm, 'pota   bear mtn');
    });
  });

  group('scoped', () {
    test('a bare key means "this extension\'s nearby suggestions"', () {
      final query = ActivitySearchQuery.parse('pota:', _knownKeys);
      expect(query.activityKeys, ['pota']);
      expect(query.term, isEmpty);
    });

    test('text after the key scopes AND searches', () {
      final query = ActivitySearchQuery.parse('pota: bear mtn', _knownKeys);
      expect(query.activityKeys, ['pota']);
      expect(query.term, 'bear mtn');
    });

    test('the key is lowercased, so typing SOTA: still matches the hook', () {
      expect(ActivitySearchQuery.parse('SOTA: W2', _knownKeys).activityKeys, ['sota']);
    });

    test('keys may carry digits, dashes and underscores', () {
      expect(ActivitySearchQuery.parse('ham2k-lofi: x', _knownKeys).activityKeys, ['ham2k-lofi']);
      expect(ActivitySearchQuery.parse('my_key: x', _knownKeys).activityKeys, ['my_key']);
    });

    test('only the FIRST colon splits — later ones stay in the search text', () {
      final query = ActivitySearchQuery.parse('pota: US-0001: park', _knownKeys);
      expect(query.activityKeys, ['pota']);
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
    // already typed after the word.
    const sotaWords = ['sota', 'ham2k-sota'];

    test('the reference after any of the extension\'s words survives', () {
      expect(searchTextAfterScopeWord('sota w7a/mn-001', sotaWords), 'w7a/mn-001');
      expect(searchTextAfterScopeWord('sota: w7a/mn-001', sotaWords), 'w7a/mn-001');
      // A catalog SOTA is `ham2k-sota`, and the operator typed its type's
      // word: matching the key alone would drop the reference.
      expect(searchTextAfterScopeWord('ham2k-sota w7a/mn-001', sotaWords), 'w7a/mn-001');
    });

    test('a box that merely NAMED the extension carries nothing', () {
      // Matched by name or keyword rather than by a word — "summits on the
      // air" is not a reference to search for once SOTA is on.
      expect(searchTextAfterScopeWord('summits on the air', sotaWords), isEmpty);
    });

    test('the word alone leaves nothing to carry', () {
      expect(searchTextAfterScopeWord('sota', sotaWords), isEmpty);
      expect(searchTextAfterScopeWord('  SOTA:  ', sotaWords), isEmpty);
    });
  });

  group('a user-published extension serving a stock reference type', () {
    // Keyed by its author's callsign, but the parks it adds are POTA parks:
    // the operator scopes with the type's word, and the query carries the
    // hook key that actually answers.
    const scopes = {
      'pota': ['ki2d-pota'],
    };

    test('the ref type word scopes to the serving hook key', () {
      final query = ActivitySearchQuery.parse('pota: bear', scopes);
      expect(query.activityKeys, ['ki2d-pota']);
      expect(query.term, 'bear');
      expect(ActivitySearchQuery.parse('pota bear', scopes).preferredKeys, ['ki2d-pota']);
    });

    test('a word two extensions serve scopes to both hooks', () {
      // Scoping to parks means every supplier of parks, or the second
      // extension's data is never searched and nothing says so.
      const shared = {
        'pota': ['pota', 'ki2d-pota'],
      };
      expect(ActivitySearchQuery.parse('pota: bear', shared).activityKeys, ['pota', 'ki2d-pota']);
      expect(ActivitySearchQuery.parse('pota bear', shared).preferredKeys, ['pota', 'ki2d-pota']);
    });

    test('an extension\'s key scopes to that extension alone', () {
      // How an operator picks one supplier of parks over another: the type's
      // word asks both, the key asks one.
      const both = {
        'pota': ['ham2k-pota', 'ki2d-pota'],
        'ham2k-pota': ['ham2k-pota'],
        'ki2d-pota': ['ki2d-pota'],
      };
      expect(ActivitySearchQuery.parse('ki2d-pota: bear', both).activityKeys, ['ki2d-pota']);
      expect(ActivitySearchQuery.parse('ham2k-pota:', both).activityKeys, ['ham2k-pota']);
      expect(ActivitySearchQuery.parse('pota:', both).activityKeys, ['ham2k-pota', 'ki2d-pota']);
    });
  });

  group('activityScopeWordsOf', () {
    // The words come from the manifest, under the extension's own key —
    // which is the key its hooks are registered under. A catalog `ham2k-pota`
    // keys its controls `pota/…`, so a word read off a control key would ask
    // a hook nobody registered and fail every scoped search.
    test('a declared type\'s word, then the extension\'s own key', () {
      expect(activityScopeWordsOf(key: 'ham2k-pota', hooks: const ['activity', 'ref:pota', 'ref:potaActivation', 'spots']), ['pota', 'ham2k-pota']);
    });

    test('a contest with one type answers to it and to its key', () {
      expect(activityScopeWordsOf(key: 'ham2k-cwt', hooks: const ['activity', 'ref:cwt']), ['cwt', 'ham2k-cwt']);
    });

    test('a qualified claim makes no word', () {
      // `ref:qp/ny` reaches back for old `{type: qp, ref: NY}` refs; `qp:`
      // asking every party that claims one would scope to fifty extensions.
      expect(activityScopeWordsOf(key: 'ham2k-ny-qso-party', hooks: const ['ref:ny-qso-party', 'ref:qp/ny']), ['ny-qso-party', 'ham2k-ny-qso-party']);
    });

    test('an extension declaring no type still answers to its key', () {
      expect(activityScopeWordsOf(key: 'Ham2K-Custom', hooks: const ['activity']), ['ham2k-custom']);
    });
  });

  group('activityScopeWord', () {
    test('an activation type and its hunting type share the base word', () {
      expect(activityScopeWord('potaActivation'), 'pota');
      expect(activityScopeWord('pota'), 'pota');
      expect(activityScopeWord('k2hrcLlotaActivation'), 'k2hrcllota');
    });

    test('only a trailing Activation is the suffix', () {
      expect(activityScopeWord('activationParks'), 'activationparks');
    });
  });

  test('the prefix tapping a type inserts round-trips back to that scope', () {
    final query = ActivitySearchQuery.parse(ActivitySearchQuery.scopePrefixFor('sota'), _knownKeys);
    expect(query.activityKeys, ['sota']);
    expect(query.term, isEmpty);
  });
}
