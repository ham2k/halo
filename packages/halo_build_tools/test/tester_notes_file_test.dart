// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

const _accumulated = '''
# Per-build "what's new for testers" …

upcoming:
  changes:
    - "A change that merged since the last cut"
    - |
      A multi-line note
      spanning two lines

"126":
  changes:
    - "Shipped in build 126"
''';

void main() {
  group('renameUpcomingTesterNotes', () {
    test('renames the key and leaves every other byte alone', () {
      final result = renameUpcomingTesterNotes(_accumulated, 127)!;

      // The identity leg: the round-trip below passes trivially when the
      // function returns its input untouched, so these two are what pin the
      // rename actually happening.
      expect(result, contains('"127":\n  changes:'));
      expect(result, isNot(contains('upcoming:')));
      // The rewrite is textual precisely so a hand-edited file survives it —
      // a yaml round-trip would drop the header comment, re-quote the keys
      // and flatten the block scalar. Nothing outside the key may move.
      expect(result.replaceFirst('"127":', 'upcoming:'), _accumulated);
    });

    test('returns null when nothing accumulated', () {
      // A cut with no tester notes is routine — the caller writes nothing and
      // commits nothing rather than the release failing on an absent key.
      expect(renameUpcomingTesterNotes('"126":\n  changes:\n    - "One"\n', 127), isNull);
    });

    test('accepts the quoted spelling', () {
      // Both spellings are the same yaml key, and the file is hand-edited;
      // matching only the bare one would silently ship the notes unnamed.
      expect(renameUpcomingTesterNotes('"upcoming":\n  changes:\n    - "One"\n', 127), startsWith('"127":'));
    });

    test('renames only the top-level key, never one nested in an entry', () {
      const nested = '''
upcoming:
  changes:
    - "The real note"
"126":
  upcoming: a field that happens to share the name
  changes:
    - "Shipped"
''';
      // Only a column-0 key is the accumulation key. An anchor that also
      // matched the nested one would rewrite it into a `"127":` field inside
      // build 126's entry — corrupting a shipped entry and leaving the real
      // notes unshipped.
      final result = renameUpcomingTesterNotes(nested, 127)!;
      expect(result, startsWith('"127":'));
      expect(result, contains('  upcoming: a field that happens to share the name'));
    });

    test('a key with no changes yet does not consume the cut', () {
      // Authors are told to create the key when the last cut took it, so a
      // stub with nothing under it is a state the process produces. Renaming
      // it would report shipped notes the app then drops as empty, and would
      // take the key away from the author who still has to write them.
      for (final stub in ['upcoming:\n', 'upcoming:\n  changes:\n', 'upcoming:\n  changes: []\n']) {
        expect(renameUpcomingTesterNotes('$stub"126":\n  changes:\n    - "One"\n', 127), isNull, reason: stub);
      }
    });

    test('refuses to rename onto a build that already has an entry, in either spelling', () {
      // Two entries for one build render that build's section twice, so the
      // merge is the operator's call, not a silent overwrite. Quoted and bare
      // are distinct yaml keys, so a text-only check would miss one of them.
      for (final existing in ['"127":', '127:']) {
        expect(
          () => renameUpcomingTesterNotes('upcoming:\n  changes:\n    - "One"\n$existing\n  changes:\n    - "Two"\n', 127),
          throwsFormatException,
          reason: existing,
        );
      }
    });

    test('refuses a document that no longer parses', () {
      // The cut commits, tags and pushes this file unseen, and the app
      // degrades a yaml failure to no notes AT ALL — every build's, not just
      // the broken entry's. A tab, a duplicate key and a stray `: ` in an
      // unquoted note are the hand-edits that do it.
      const broken = [
        'upcoming:\n\tchanges:\n    - "Tab indented"\n',
        'upcoming:\n  changes:\n    - "One"\n"126":\n  changes:\n    - "a"\n"126":\n  changes:\n    - "b"\n',
        'upcoming:\n  changes:\n    - Fixed: the CAT dialog\n',
      ];
      for (final source in broken) {
        expect(() => renameUpcomingTesterNotes(source, 127), throwsFormatException, reason: source);
      }
    });

    test('refuses a top-level key that is neither a build number nor `upcoming`', () {
      // A typo'd key is the one failure both halves of the system ignore in
      // silence: the app skips it as non-numeric and the rename never sees
      // it, so the release reports "nothing accumulated" and the notes sit in
      // the file forever. The cut is the only place that can notice.
      for (final typo in ['Upcoming', 'upcomming', 'unreleased']) {
        expect(() => renameUpcomingTesterNotes('$typo:\n  changes:\n    - "One"\n', 127), throwsFormatException, reason: typo);
      }
    });

    test('refuses an entry whose changes are the wrong shape', () {
      // `changes: "a string"` and a non-text item are both dropped silently
      // by the app's parser, so notes written that way would never ship.
      expect(() => renameUpcomingTesterNotes('upcoming:\n  changes: "not a list"\n', 127), throwsFormatException);
      expect(() => renameUpcomingTesterNotes('upcoming:\n  changes:\n    - 42\n', 127), throwsFormatException);
    });

    test('refuses a key the parser sees but the rename cannot rewrite', () {
      // A flow mapping is valid yaml and a valid accumulation key, but the
      // textual rewrite can't rename it — better a stopped cut than a release
      // that silently reports nothing accumulated.
      expect(() => renameUpcomingTesterNotes('{upcoming: {changes: ["One"]}}\n', 127), throwsFormatException);
    });
  });
}
