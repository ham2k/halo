// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/tester_notes.dart';

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
