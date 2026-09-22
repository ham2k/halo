// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ranking for the "add activity" search. The picker shows what this returns, in
// this order, so a suggestion that cannot be ranked is a suggestion the operator
// has to hunt for.
//
// The distance-less band is the reason this exists. Ranking every such result
// equal discards `relevance`, which is the only signal those results have — and
// past 33 entries it does worse than that, because `List.sort` stops preserving
// input order once it leaves insertion sort.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/activity_suggestions.dart';

List<String> _names(List<Map<String, dynamic>> ranked) => [for (final s in ranked) s['name'] as String];

void main() {
  test('relevance divides distance, so a better match counts as closer', () {
    // The original behaviour, unchanged. far-exact is 20km FURTHER than
    // near-weak and still outranks it, because 80/1.0 beats 60/0.6 — which is
    // the whole point of dividing.
    final ranked = rankActivitySuggestions([
      {'name': 'near-weak', 'distance': 60, 'relevance': 0.6},
      {'name': 'far-exact', 'distance': 80, 'relevance': 1.0},
      {'name': 'nearest', 'distance': 10, 'relevance': 0.6},
    ]);
    expect(_names(ranked), ['nearest', 'far-exact', 'near-weak']);
  });

  test('a located suggestion always outranks one with no location', () {
    final ranked = rankActivitySuggestions([
      {'name': 'no-location', 'relevance': 1.0},
      {'name': 'far-away', 'distance': 9999, 'relevance': 0.6},
    ]);
    expect(_names(ranked), ['far-away', 'no-location']);
  });

  test('distance-less suggestions rank by relevance instead of not at all', () {
    // THE fix. POTA sets `relevance` always and `distance` only when a location
    // is known, so a search with no operation grid and no GPS used to discard
    // `relevanceForMatch` completely — an exact code match came back wherever
    // the database happened to put it.
    final ranked = rankActivitySuggestions([
      {'name': 'substring-name', 'relevance': 0.7},
      {'name': 'exact-code', 'relevance': 1.0},
      {'name': 'substring-code', 'relevance': 0.85},
      {'name': 'prefix-name', 'relevance': 0.9},
    ]);
    expect(_names(ranked), ['exact-code', 'prefix-name', 'substring-code', 'substring-name']);
  });

  test('order survives past the point where the sort stops being stable', () {
    // Measured: with every comparison returning 0, List.sort preserves input
    // order at 33 entries and scrambles it at 34. POTA and SOTA only escape by
    // capping at 30, and a QSO-party list of 43 events would not.
    for (final n in [33, 34, 49]) {
      final ranked = rankActivitySuggestions([
        for (var i = 0; i < n; i++) {'name': 'P$i', 'relevance': (n - i) / n},
      ]);
      expect(_names(ranked), [for (var i = 0; i < n; i++) 'P$i'], reason: 'n=$n came back out of relevance order');
    }
  });

  test('equal suggestions keep the order their extension emitted them in', () {
    // Ties break on emission index explicitly rather than by trusting the sort,
    // so an extension that has already ordered its own results keeps that work.
    final ranked = rankActivitySuggestions([
      for (var i = 0; i < 40; i++) {'name': 'same$i', 'relevance': 0.5},
    ]);
    expect(_names(ranked), [for (var i = 0; i < 40; i++) 'same$i']);
  });

  test('a suggestion with no relevance at all is ordered, not dropped', () {
    // Neither field is required by the contract.
    final ranked = rankActivitySuggestions([
      {'name': 'nothing'},
      {'name': 'relevant', 'relevance': 0.5},
      {'name': 'located', 'distance': 5},
    ]);
    expect(_names(ranked), ['located', 'relevant', 'nothing']);
  });

  test('a non-positive relevance is no signal rather than a demotion', () {
    // `relevance: 0` used to send a located suggestion to infinity, losing its
    // distance too.
    final ranked = rankActivitySuggestions([
      {'name': 'far', 'distance': 100, 'relevance': 0},
      {'name': 'near', 'distance': 5, 'relevance': 0},
    ]);
    expect(_names(ranked), ['near', 'far']);
  });

  test('neither the list nor its maps are mutated', () {
    final original = [
      {'name': 'b', 'relevance': 0.5},
      {'name': 'a', 'relevance': 0.9},
    ];
    final ranked = rankActivitySuggestions(original);

    expect(_names(original), ['b', 'a'], reason: 'the caller keeps its own order');
    expect(_names(ranked), ['a', 'b']);
    expect(identical(ranked.first, original[1]), isTrue, reason: 'the maps are shared, not copied');
  });

  group('merging hook entries', () {
    Map<String, dynamic> entry(String key, List<String> names) => {
      'key': key,
      'ok': true,
      'value': [
        for (final name in names) {'name': name, 'distance': 100, 'relevance': 1.0},
      ],
    };

    test('the preferred extension leads, however near the others are', () {
      // The point of naming an extension: a 1km park must not outrank the
      // summits from the extension the operator actually asked for.
      final merged = mergeActivitySuggestions(
        [
          {
            'key': 'pota',
            'ok': true,
            'value': [
              {'name': 'park', 'distance': 1, 'relevance': 1.0},
            ],
          },
          {
            'key': 'sota',
            'ok': true,
            'value': [
              {'name': 'summit-far', 'distance': 90, 'relevance': 1.0},
              {'name': 'summit-near', 'distance': 40, 'relevance': 1.0},
            ],
          },
        ],
        preferredKeys: {'sota'},
      );
      expect(_names(merged), ['summit-near', 'summit-far', 'park']);
    });

    test('each band is ranked among itself', () {
      final merged = mergeActivitySuggestions(
        [
          {
            'key': 'sota',
            'ok': true,
            'value': [
              {'name': 'summit-far', 'distance': 90, 'relevance': 1.0},
              {'name': 'summit-near', 'distance': 9, 'relevance': 1.0},
            ],
          },
          {
            'key': 'pota',
            'ok': true,
            'value': [
              {'name': 'park-far', 'distance': 80, 'relevance': 1.0},
              {'name': 'park-near', 'distance': 8, 'relevance': 1.0},
            ],
          },
        ],
        preferredKeys: {'sota'},
      );
      expect(_names(merged), ['summit-near', 'summit-far', 'park-near', 'park-far']);
    });

    test('without a preferred key everything ranks together', () {
      final merged = mergeActivitySuggestions([
        {
          'key': 'sota',
          'ok': true,
          'value': [
            {'name': 'summit', 'distance': 90, 'relevance': 1.0},
          ],
        },
        {
          'key': 'pota',
          'ok': true,
          'value': [
            {'name': 'park', 'distance': 8, 'relevance': 1.0},
          ],
        },
      ]);
      expect(_names(merged), ['park', 'summit']);
    });

    test('a failed or malformed entry costs only itself', () {
      final merged = mergeActivitySuggestions(
        [
          {'key': 'wwff', 'ok': false, 'error': 'boom'},
          {'key': 'iota', 'ok': true, 'value': 'not a list'},
          entry('pota', ['park']),
        ],
        preferredKeys: {'sota'},
      );
      expect(_names(merged), ['park']);
    });

    test('a hook with no suggest method has NOT failed', () {
      // The kernel reports a missing method as a successful null, and every
      // contest registers an `activity` hook for its setup control without a
      // `suggest`. Reading that as a failure tells an operator running only
      // contests that the search is down, on every keystroke, forever.
      expect(
        allActivitySourcesFailed([
          {'key': 'cqww', 'ok': true, 'value': null},
          {'key': 'naqp', 'ok': true, 'value': null},
        ]),
        isFalse,
      );
    });

    test('every hook erroring IS a failure', () {
      expect(
        allActivitySourcesFailed([
          {'key': 'pota', 'ok': false, 'error': 'boom'},
          {'key': 'sota', 'ok': false, 'error': 'boom'},
        ]),
        isTrue,
      );
    });

    test('one survivor means the search is not down', () {
      expect(
        allActivitySourcesFailed([
          {'key': 'pota', 'ok': false, 'error': 'boom'},
          {'key': 'sota', 'ok': true, 'value': const []},
        ]),
        isFalse,
      );
    });

    test('nobody asked is not everybody failing', () {
      // A runtime still starting has not failed, and saying so on every
      // launch is the fastest way to teach an operator to ignore the message.
      expect(allActivitySourcesFailed(const []), isFalse);
    });

    test('a preferred extension that answered nothing does not blank the list', () {
      final merged = mergeActivitySuggestions(
        [
          {'key': 'sota', 'ok': false, 'error': 'boom'},
          entry('pota', ['park']),
        ],
        preferredKeys: {'sota'},
      );
      expect(_names(merged), ['park']);
    });
  });
}
