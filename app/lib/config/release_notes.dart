// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Loads assets/release-notes.yaml — the per-release "what's new" copy shown
// in the startup overlay (release_overlay.dart) and Settings → About →
// Recent Changes. Keyed by the full public version (config/version.dart's
// kPublicVersion). YAML (not JSON) so a `changes` entry can be a multi-line
// block scalar; each entry is rendered as markdown by its consumers.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class ReleaseNotesEntry {
  final String version;
  final String name;
  final String photoCaption;
  final List<String> changes;

  const ReleaseNotesEntry({
    required this.version,
    required this.name,
    required this.photoCaption,
    required this.changes,
  });

  /// The `MAJOR.MINOR` prefix of [version] (e.g. `26.8` for `26.8.0`),
  /// matching the release image filename convention
  /// `assets/images/releases/<MAJOR.MINOR>-photo.jpg`.
  String get mainVersion => version.split('.').take(2).join('.');

  String get imageAssetPath => 'assets/images/releases/$mainVersion-photo.jpg';
}

/// Parses `assets/release-notes.yaml` into release-ordered (newest first,
/// matching the file's own order) entries. A malformed individual entry
/// (e.g. a version key with no body, or a field of the wrong type) is
/// skipped rather than throwing and taking every other entry down with it —
/// this file is hand-edited per release, so a single typo shouldn't blank
/// out the whole release history.
List<ReleaseNotesEntry> parseReleaseNotesYaml(String yamlSource) {
  final doc = loadYaml(yamlSource);
  if (doc is! YamlMap) return const [];
  final entries = <ReleaseNotesEntry>[];
  for (final entry in doc.entries) {
    final body = entry.value;
    if (body is! YamlMap) continue;
    try {
      entries.add(ReleaseNotesEntry(
        version: entry.key as String,
        name: (body['name'] as String?) ?? entry.key as String,
        photoCaption: (body['photoCaption'] as String?) ?? '',
        changes: [for (final change in (body['changes'] as YamlList?) ?? YamlList()) change as String],
      ));
    } catch (_) {
      // A field with the wrong type (e.g. `changes: "oops"` instead of a
      // list) throws on the cast above — skip just this entry, same as the
      // missing-body case, rather than losing the whole parse.
      continue;
    }
  }
  return entries;
}

Future<List<ReleaseNotesEntry>>? _releaseNotesFuture;

/// Cached across calls (same rationale as version_label.dart's
/// `_packageInfoFuture`): callers rebuild often (e.g. theme changes), and a
/// fresh Future each time would flicker any FutureBuilder back to
/// ConnectionState.waiting.
Future<List<ReleaseNotesEntry>> loadReleaseNotes() {
  return _releaseNotesFuture ??= rootBundle.loadString('assets/release-notes.yaml').then(parseReleaseNotesYaml);
}

/// Bypasses `rootBundle.loadString` entirely, resolving [loadReleaseNotes]
/// synchronously to [notes] from then on — a widget test that repeatedly
/// mounts/tears down the full app (database, extension host, asset
/// channel) can leave the real asset load hanging indefinitely on a later
/// test even though it resolved fine on an earlier one; a real yaml parse
/// isn't what those tests are checking anyway. Call from `setUp()`.
@visibleForTesting
void setReleaseNotesForTesting(List<ReleaseNotesEntry> notes) => _releaseNotesFuture = Future.value(notes);
