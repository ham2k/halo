// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/config/version.dart';

void main() {
  test('parses entries newest-first regardless of file order, accepting quoted and bare keys', () {
    final entries = parseTesterNotesYaml('''
"123":
  changes:
    - "Oldest change"
125:
  changes:
    - "Newest change"
"124":
  changes:
    - "Middle change"
''');

    // The gate shows "everything since the build you last saw", newest
    // first — but the file is hand-appended, so its own order drifts. If
    // the sort silently disappeared, a catch-up tester would read their
    // pending notes oldest-first (or file-order scrambled) with no visible
    // error.
    expect(entries.map((e) => e.build), [125, 124, 123]);
    expect(entries.first.changes, ['Newest change']);
  });

  test('skips malformed entries (non-numeric key, wrong-typed body, empty changes) without losing the rest', () {
    final entries = parseTesterNotesYaml('''
"125":
  changes:
    - "Good change"
"not-a-build":
  changes:
    - "Unreachable"
"124": "no body map"
"123":
  changes: "not a list"
"122":
  changes: []
''');

    // Hand-edited per build: one typo must not blank out every other
    // entry — same tolerance contract as release-notes.yaml's parser. The
    // empty-changes stub (122) matters separately: a heading written ahead
    // of an uncut build must not summon the overlay.
    expect(entries.map((e) => e.build), [125]);
  });

  test('a document-level yaml failure degrades to no entries, not a throw', () {
    // Duplicate keys take loadYaml itself down — the classic hand-append
    // slip. If this threw, the gate would surface a startup error and the
    // cached future would poison every later call.
    expect(
      parseTesterNotesYaml('''
"125":
  changes:
    - "One"
"125":
  changes:
    - "Two"
'''),
      isEmpty,
    );
  });

  test('the accumulation key stays invisible until the release cut names it', () {
    const accumulating =
        '''
$kUpcomingTesterNotesKey:
  changes:
    - "Merged, not yet shipped"
"125":
  changes:
    - "Shipped in 125"
''';

    // Two halves of one contract. Notes are written under `upcoming` as work
    // merges, so until the cut renames it a tester must NOT see them — their
    // build predates the change. If this key ever became readable, every Dev
    // build would advertise work it doesn't carry.
    expect(parseTesterNotesYaml(accumulating).map((e) => e.build), [125]);

    // …and the rename must land on a key this parser reads, or the notes go
    // out silently swallowed.
    final cut = renameUpcomingTesterNotes(accumulating, 126)!;
    expect(parseTesterNotesYaml(cut).map((e) => e.build), [126, 125]);
    expect(parseTesterNotesYaml(cut).first.changes, ['Merged, not yet shipped']);
  });

  test('the SHIPPED file parses, and any accumulated notes are cuttable', () {
    // The real asset, not a fixture. Every task that changes something a
    // tester should try hand-edits this file, and a document-level yaml slip
    // (a tab, a duplicate key, a stray `: `) degrades it to NO notes for any
    // build — silently, and only at the next release cut would anyone find
    // out. parseTesterNotesYaml swallowing that failure is what makes this
    // test the only place it can surface.
    final source = File('assets/tester-notes.yaml').readAsStringSync();
    final entries = parseTesterNotesYaml(source);
    expect(entries, isNotEmpty, reason: 'assets/tester-notes.yaml parses to no entries at all');
    expect(entries.first.build, lessThanOrEqualTo(kBuildNumber), reason: 'an entry above kBuildNumber means a build number was typed by hand');

    // Whatever state the file is in — mid-cycle with notes under `upcoming`,
    // or freshly cut with none — the next cut must be able to name them. This
    // catches a misspelled key and a mis-shaped `changes` list at merge time
    // rather than at release time.
    expect(() => renameUpcomingTesterNotes(source, kBuildNumber + 1), returnsNormally);
  });

  test('quoted and bare spellings of one build de-dup to a single entry', () {
    // "125" and 125 are DISTINCT yaml keys (no duplicate-key error), so
    // without de-dup the overlay renders the same build's section twice.
    final entries = parseTesterNotesYaml('''
"125":
  changes:
    - "Quoted spelling"
125:
  changes:
    - "Bare spelling"
''');
    expect(entries, hasLength(1));
    expect(entries.single.build, 125);
  });
}
