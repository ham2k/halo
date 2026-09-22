// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:yaml/yaml.dart';

/// The accumulation key at the top of `app/assets/tester-notes.yaml`: notes
/// worth flagging to testers are appended under it as work merges, and the
/// release cut renames it to the build being shipped. Non-numeric on purpose —
/// the app's parser (`config/tester_notes.dart`) skips it, so accumulated
/// notes stay invisible until the build carrying them exists.
const kUpcomingTesterNotesKey = 'upcoming';

/// A top-level `upcoming:` key, quoted either way. `^` in multiline mode is
/// what makes it top-level: nested keys are indented and can't match.
final _upcomingKey = RegExp(
  '^(["\']?)$kUpcomingTesterNotesKey'
  r'\1[ \t]*:',
  multiLine: true,
);

/// Returns `app/assets/tester-notes.yaml` [source] with its `upcoming:` key
/// renamed to [build], or null when there is nothing to ship: no such key, or
/// one whose `changes` the author hasn't filled in. Nothing accumulated
/// between two cuts is a normal state, not an error.
///
/// The rewrite is textual so the hand-edited file keeps its header comment,
/// quoting and block scalars — but the document is parsed on both sides of it,
/// because the cut commits, tags and pushes this file unseen, and the app
/// degrades a yaml failure to NO notes at all, for every build rather than
/// just the broken entry. A hand-edit mistake has to stop the cut, not ship in
/// it. Entry order doesn't matter: the app sorts by build.
///
/// Throws [FormatException] on everything a human must fix first — a document
/// that no longer parses, a top-level key that is neither a build number nor
/// `upcoming` (notes under it reach nobody, silently, on both sides), a
/// mis-shaped `changes` list, a [build] that already has an entry, or a rename
/// that fails to land.
String? renameUpcomingTesterNotes(String source, int build) {
  final doc = _parse(source);

  var accumulating = false;
  for (final key in doc.keys) {
    if (key == kUpcomingTesterNotesKey) {
      accumulating = true;
      continue;
    }
    // Quoted ("125") and bare (125) keys are both build numbers, and both
    // spellings of one number are DISTINCT yaml keys — so the collision check
    // has to compare parsed values, not text.
    final numeric = switch (key) {
      final int k => k,
      final String k => int.tryParse(k),
      _ => null,
    };
    if (numeric == null) {
      throw FormatException(
        "tester-notes.yaml: top-level key '$key' is neither a build number nor "
        "'$kUpcomingTesterNotesKey' — notes under it reach nobody",
      );
    }
    if (numeric == build) {
      throw FormatException('tester-notes.yaml: build $build already has an entry; merge it by hand');
    }
  }
  if (!accumulating) return null;

  final changes = _changesOf(doc[kUpcomingTesterNotesKey], "'$kUpcomingTesterNotesKey'");
  // A key created ahead of the notes themselves must not consume the cut: the
  // plan would report notes that no tester ever sees, and the author would
  // have to recreate the key.
  if (changes.isEmpty) return null;

  final matches = _upcomingKey.allMatches(source).toList();
  if (matches.length != 1) {
    // The parse found the key and this didn't, so it's spelled in a way the
    // rename can't rewrite (a flow mapping, an explicit `? ` key) — or twice,
    // in two spellings yaml counts as distinct keys.
    throw FormatException("tester-notes.yaml: expected exactly one plain '$kUpcomingTesterNotesKey:' key to rename, found ${matches.length}");
  }
  final renamed = source.replaceRange(matches.first.start, matches.first.end, '"$build":');

  final landed = _changesOf(_parse(renamed)['$build'], 'build $build');
  if (landed.length != changes.length) {
    throw FormatException('tester-notes.yaml: renaming to build $build did not preserve the notes');
  }
  return renamed;
}

/// The `changes` under one entry's [body], empty for a stub whose notes aren't
/// written yet. Throws on a shape the app would silently drop.
List<String> _changesOf(Object? body, String label) {
  if (body == null) return const [];
  if (body is! YamlMap) {
    throw FormatException('tester-notes.yaml: $label must be a map holding a `changes` list');
  }
  final raw = body['changes'];
  if (raw == null) return const [];
  if (raw is! YamlList) {
    throw FormatException("tester-notes.yaml: $label's `changes` must be a list");
  }
  return [
    for (final change in raw)
      if (change is String) change else throw FormatException('tester-notes.yaml: $label has a `changes` entry that is not text'),
  ];
}

YamlMap _parse(String source) {
  final Object? doc;
  try {
    doc = loadYaml(source);
  } on Exception catch (e) {
    // Duplicate keys, a tab, a stray `: ` in an unquoted note — all take the
    // whole document down, in the app as well as here.
    throw FormatException('tester-notes.yaml: $e');
  }
  if (doc == null) return YamlMap();
  if (doc is! YamlMap) {
    throw const FormatException('tester-notes.yaml: expected a map of build numbers to entries');
  }
  return doc;
}
