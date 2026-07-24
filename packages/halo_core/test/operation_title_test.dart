// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// mergeOperationTitleSuggestions (ham2k/app-halo-dist#174): the pure
// grouping/join step between per-ref `suggestOperationTitle` hook results
// and the UI's final "for X at Y" sentence assembly.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('mergeOperationTitleSuggestions', () {
    test('empty input produces empty, non-null fragments', () {
      final fragments = mergeOperationTitleSuggestions(const []);
      expect(fragments.isEmpty, isTrue);
      expect(fragments.title, isEmpty);
      expect(fragments.forText, isEmpty);
      expect(fragments.atText, isEmpty);
      expect(fragments.subtitle, isEmpty);
    });

    test('a single suggestion carries each field straight through', () {
      final fragments = mergeOperationTitleSuggestions(const [
        OperationTitleSuggestion(atText: 'K-1234', subtitle: 'Some Park'),
      ]);
      expect(fragments.atText, 'K-1234');
      expect(fragments.subtitle, 'Some Park');
      expect(fragments.forText, isEmpty);
      expect(fragments.isEmpty, isFalse);
    });

    test('same-kind fragments from multiple refs join with a comma, subtitles with a bullet', () {
      final fragments = mergeOperationTitleSuggestions(const [
        OperationTitleSuggestion(atText: 'K-1234', subtitle: 'Park One'),
        OperationTitleSuggestion(atText: 'W6/SD-123', subtitle: 'Summit One'),
      ]);
      expect(fragments.atText, 'K-1234, W6/SD-123');
      expect(fragments.subtitle, 'Park One • Summit One');
    });

    test('different-kind fragments stay in their own field, not mixed together', () {
      final fragments = mergeOperationTitleSuggestions(const [
        OperationTitleSuggestion(atText: 'K-1234'),
        OperationTitleSuggestion(forText: 'Field Day'),
        OperationTitleSuggestion(title: 'Special Event'),
      ]);
      expect(fragments.atText, 'K-1234');
      expect(fragments.forText, 'Field Day');
      expect(fragments.title, 'Special Event');
    });

    test('higher priority orders first within a kind, default priority is 0', () {
      final fragments = mergeOperationTitleSuggestions(const [
        OperationTitleSuggestion(forText: 'Low'),
        OperationTitleSuggestion(forText: 'High', priority: 100),
      ]);
      expect(fragments.forText, 'High, Low', reason: 'priority 100 must sort before the default priority 0');
    });

    test('same-priority suggestions keep their input order deterministically', () {
      // Most real suggestions share the default priority 0 — List.sort
      // isn't guaranteed stable, so this must be enforced explicitly rather
      // than relying on sort() to preserve input order for ties.
      final input = [for (var i = 0; i < 8; i++) OperationTitleSuggestion(forText: 'R$i')];
      for (var attempt = 0; attempt < 5; attempt++) {
        expect(mergeOperationTitleSuggestions(input).forText, 'R0, R1, R2, R3, R4, R5, R6, R7');
      }
    });

    test('a suggestion with only empty/null fields contributes nothing', () {
      final fragments = mergeOperationTitleSuggestions(const [OperationTitleSuggestion()]);
      expect(fragments.isEmpty, isTrue);
    });

    test('a subtitle-only suggestion (no title/for/at) still counts as non-empty content', () {
      // OperationTitleService caches `null` instead of the fragments when
      // isEmpty is true (dropping the subtitle entirely) — a future hook
      // that contributes detail without an at/for/title fragment must not
      // be silently discarded this way.
      final fragments = mergeOperationTitleSuggestions(const [OperationTitleSuggestion(subtitle: 'Some detail')]);
      expect(fragments.isEmpty, isFalse);
      expect(fragments.subtitle, 'Some detail');
    });
  });

  group('Operation.titleFragments', () {
    Operation operation({Map<String, dynamic>? localData}) =>
        Operation(uuid: 'u', data: const {}, localData: localData ?? const {});

    test('empty when nothing has been cached yet', () {
      expect(operation().titleFragments.isEmpty, isTrue);
    });

    test('reads OperationTitleService\'s cached fragments', () {
      final fragments = operation(localData: {
        'titleSuggestion': {'title': '', 'for': '', 'at': 'K-1234', 'subtitle': 'Some Park'},
      }).titleFragments;
      expect(fragments.atText, 'K-1234');
      expect(fragments.subtitle, 'Some Park');
    });

    test('tolerates a null cache entry (cleared when refs became empty)', () {
      expect(operation(localData: const {'titleSuggestion': null}).titleFragments.isEmpty, isTrue);
    });
  });
}
