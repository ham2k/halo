// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Loads assets/tester-notes.yaml — the per-build "what's new for testers"
// copy shown in the tester overlay (views/tester_overlay.dart). Unlike
// release-notes.yaml (keyed by public version, shown to everyone), this file
// is keyed by the native build number (config/version.dart's kBuildNumber)
// and shown only on the Dev and Next editions. Each entry's changes are
// rendered as markdown by the overlay.
//
// Notes are written as work merges, under the file's `upcoming` key, and the
// release cut renames that key to the build shipping them. Dropping
// non-numeric keys (below) is therefore load-bearing, not just tolerance:
// it's what keeps accumulated notes invisible until their build exists.

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class TesterNotesEntry {
  final int build;
  final List<String> changes;

  const TesterNotesEntry({required this.build, required this.changes});
}

/// Parses `assets/tester-notes.yaml` into build-ordered (newest first,
/// regardless of the file's own order — hand-appended entries drift) entries.
/// A malformed individual entry (a non-numeric key, a body of the wrong
/// type) is skipped rather than throwing and taking every other entry down
/// with it — same tolerance, and same rationale, as
/// release_notes.dart's parseReleaseNotesYaml.
List<TesterNotesEntry> parseTesterNotesYaml(String yamlSource) {
  final Object? doc;
  try {
    doc = loadYaml(yamlSource);
  } on Exception {
    // A document-level failure (duplicate keys, a tab/indentation typo)
    // takes loadYaml itself down — one bad hand-append must degrade to "no
    // tester notes", never to a startup error.
    return const [];
  }
  if (doc is! YamlMap) return const [];
  final entries = <TesterNotesEntry>[];
  for (final entry in doc.entries) {
    // Quoted ("125") and bare (125) keys both appear in hand-edited yaml;
    // accept either rather than silently dropping one spelling.
    final build = switch (entry.key) {
      final int key => key,
      final String key => int.tryParse(key),
      _ => null,
    };
    final body = entry.value;
    if (build == null || body is! YamlMap) continue;
    try {
      final changes = [for (final change in (body['changes'] as YamlList?) ?? YamlList()) change as String];
      // A stub with no changes (a heading written ahead of an uncut build)
      // must not summon the whole overlay just to show an empty section.
      if (changes.isEmpty) continue;
      entries.add(TesterNotesEntry(build: build, changes: changes));
    } catch (_) {
      // A field with the wrong type throws on the cast above — skip just
      // this entry rather than losing the whole parse.
      continue;
    }
  }
  entries.sort((a, b) => b.build.compareTo(a.build));
  // Quoted and bare spellings of the same number are DISTINCT yaml keys, so
  // duplicate-key detection can't catch them — de-dup here or the overlay
  // renders the same build's section twice.
  final seen = <int>{};
  return [
    for (final entry in entries)
      if (seen.add(entry.build)) entry,
  ];
}

Future<List<TesterNotesEntry>>? _testerNotesFuture;

/// Cached across calls, same rationale as release_notes.dart's
/// `_releaseNotesFuture`: a fresh Future each call would flicker any
/// FutureBuilder back to ConnectionState.waiting. Never rejects: a missing
/// asset resolves to no entries — a rejected future here would both surface
/// a startup error and stay cached, poisoning every later call.
Future<List<TesterNotesEntry>> loadTesterNotes() {
  return _testerNotesFuture ??=
      rootBundle.loadString('assets/tester-notes.yaml').then(parseTesterNotesYaml).catchError((Object error) {
    debugPrint('[tester-notes] unavailable: $error');
    return const <TesterNotesEntry>[];
  });
}

/// Bypasses `rootBundle.loadString`, resolving [loadTesterNotes]
/// synchronously to [notes] from then on — same full-app-teardown asset-load
/// hang as release_notes.dart's setReleaseNotesForTesting. Call from
/// `setUp()`.
@visibleForTesting
void setTesterNotesForTesting(List<TesterNotesEntry> notes) => _testerNotesFuture = Future.value(notes);
