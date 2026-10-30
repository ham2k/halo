// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A spot command naming a source (`SPOT discord: hey`), previewed as the app
// will run it. The hook that parsed it has only the word typed; which spot
// sources the word reaches, and what they are called, is the app's to know.

import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show spotSourceMatches;

/// The `sendSpots` action among [interpretation]'s commands that names a
/// `source`, or null.
Map<String, dynamic>? sendSpotsNamingSource(Map<String, dynamic> interpretation) {
  if (interpretation['commands'] case final List<dynamic> commands) {
    for (final command in commands) {
      if (command is! Map) continue;
      final params = command['sendSpots'];
      if (params is Map && params['source'] is String && (params['source'] as String).isNotEmpty) return params.cast<String, dynamic>();
    }
  }
  return null;
}

/// [interpretation] with its `describe` and `confirm` naming the spot sources
/// its `sendSpots` action's `source` reaches ([spotSourceMatches]), by the
/// names their hooks give — `Spotterbot`, not `ham2k-discord-spotterbot`. A
/// word no source in [names] answers to becomes an `error` in place of the
/// command, naming the keys that would, so Enter runs nothing. Unchanged when
/// no action names a source, and when [names] is empty: a runtime with no
/// spot sources, or one that could not be asked, is the Spotting control's
/// to explain when the command runs.
Map<String, dynamic> describeSpotSources(Map<String, dynamic> interpretation, Map<String, String> names) {
  final params = sendSpotsNamingSource(interpretation);
  if (params == null || names.isEmpty) return interpretation;
  final source = params['source'] as String;
  final reached = [
    for (final entry in names.entries)
      if (spotSourceMatches(entry.key, source)) entry.value,
  ];
  if (reached.isEmpty) {
    return {
      for (final entry in interpretation.entries)
        if (entry.key != 'commands' && entry.key != 'describe' && entry.key != 'confirm') entry.key: entry.value,
      'error': t.spotting.noSuchSource(source: source, sources: names.keys.join(', ')),
    };
  }
  final sources = reached.join(', ');
  final typed = params['comment'];
  final comment = typed is String && typed.isNotEmpty ? typed : null;
  final last = params['target'] == 'last';
  return {
    ...interpretation,
    'describe': last
        ? (comment == null ? t.spotting.spotLastTo(sources: sources) : t.spotting.spotLastToWithComment(sources: sources, comment: comment))
        : (comment == null ? t.spotting.selfSpotTo(sources: sources) : t.spotting.selfSpotToWithComment(sources: sources, comment: comment)),
    'confirm': last
        ? (comment == null ? t.spotting.spottingLastTo(sources: sources) : t.spotting.spottingLastToComment(sources: sources, comment: comment))
        : (comment == null ? t.spotting.selfSpottingTo(sources: sources) : t.spotting.selfSpottingToComment(sources: sources, comment: comment)),
  };
}
