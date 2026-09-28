// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Loads experiments.yaml — the catalog of experimental features the EXP
// command (dev-commands extension) and Settings → Developer → Experiments
// toggle. The catalog defines what CAN be toggled; the per-key on/off state
// (and first-enabled/last-disabled stamps) lives in
// SettingsService.experimentStates, which deliberately keeps entries whose
// definition has been removed from the catalog — a returning experiment
// picks its old state back up.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

/// The CAT server experiment's key in experiments.yaml.
const kCatServerExperiment = 'server';

class ExperimentDefinition {
  final String key;
  final String name;
  final String? description;
  final List<String> aliases;

  /// Private experiments still toggle via EXP but are not listed in the
  /// Experiments screen (half-baked or internal-only switches) — until
  /// enabled once, after which they stay listed (see
  /// SettingsService.experimentEverEnabled).
  final bool private;

  const ExperimentDefinition({required this.key, required this.name, this.description, this.aliases = const [], this.private = false});

  /// Whether [token] names this experiment — its key or any alias.
  ///
  /// Case-insensitive because the field a token is typed into decides its
  /// case for its own reasons: the logging panel's call field uppercases all
  /// of it, the ⌘K and Quick Lookup bars only the command word, so "EXP
  /// layouts" arrives here either way.
  bool matches(String token) {
    final lower = token.toLowerCase();
    return key.toLowerCase() == lower || aliases.any((a) => a.toLowerCase() == lower);
  }
}

/// Parses `experiments.yaml`'s `experiments:` list. Same resilience contract
/// as release_notes.dart: a malformed individual entry (missing key/name, a
/// field of the wrong type) is skipped rather than taking the catalog down —
/// the file is hand-edited.
List<ExperimentDefinition> parseExperimentsYaml(String yamlSource) {
  final Object? doc;
  try {
    doc = loadYaml(yamlSource);
  } catch (_) {
    // A whole-file syntax error (bad indentation on a hand-edit) must not
    // escape: loadExperiments caches its future, so a thrown parse would
    // poison every later EXP command and the Experiments screen for the
    // rest of the session.
    return const [];
  }
  if (doc is! YamlMap) return const [];
  final list = doc['experiments'];
  if (list is! YamlList) return const [];
  final definitions = <ExperimentDefinition>[];
  for (final entry in list) {
    if (entry is! YamlMap) continue;
    try {
      final key = entry['key'] as String;
      definitions.add(
        ExperimentDefinition(
          key: key,
          name: (entry['name'] as String?) ?? key,
          description: entry['description'] as String?,
          aliases: [for (final alias in (entry['aliases'] as YamlList?) ?? YamlList()) alias as String],
          private: (entry['private'] as bool?) ?? false,
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return definitions;
}

/// The definition [token] names (key or alias, case-insensitive), or null.
ExperimentDefinition? findExperiment(List<ExperimentDefinition> definitions, String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return null;
  for (final definition in definitions) {
    if (definition.matches(trimmed)) return definition;
  }
  return null;
}

Future<List<ExperimentDefinition>>? _experimentsFuture;

/// Cached across calls, like [loadReleaseNotes] — consumers read this from
/// FutureBuilders that rebuild often.
Future<List<ExperimentDefinition>> loadExperiments() {
  // A failed asset read resolves empty rather than rejecting, for the same
  // reason a parse error does: the future is cached, and the extension host's
  // getSettings awaits it for EVERY hook context — a cached rejection would
  // strip every hook of its settings for the rest of the session.
  return _experimentsFuture ??= rootBundle.loadString('experiments.yaml').then(parseExperimentsYaml).catchError((Object _) => const <ExperimentDefinition>[]);
}

/// Resolves [loadExperiments] synchronously to [definitions] from then on
/// (same rationale as setReleaseNotesForTesting). Call from `setUp()`.
@visibleForTesting
void setExperimentsForTesting(List<ExperimentDefinition> definitions) => _experimentsFuture = Future.value(definitions);
