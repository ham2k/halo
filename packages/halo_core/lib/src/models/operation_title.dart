// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Merges per-ref `suggestOperationTitle` results
// into grouped fragment strings, mirroring app-polo's buildOperationTitle —
// but stopping short of the final "for X at Y" sentence: that needs the
// locale's "for"/"at" words, which this Flutter-less, pure/testable function
// can't supply. A UI-layer helper (with a BuildContext) does that last step.

/// One ref's title contribution — the shape `suggestOperationTitle` hooks
/// return. `title` is a ready-made fragment (no preposition); `forText`/
/// `atText` are the OBJECTS of a "for "/"at " phrase the caller builds
/// later; `subtitle` is free-form detail; `priority` breaks ties within a
/// fragment kind (higher wins, default 0).
class OperationTitleSuggestion {
  final String? title;
  final String? forText;
  final String? atText;
  final String? subtitle;
  final num priority;

  const OperationTitleSuggestion({this.title, this.forText, this.atText, this.subtitle, this.priority = 0});
}

/// The merged result: one joined string per fragment kind, ready for a UI
/// layer to localize the "for"/"at" prepositions and assemble into a
/// sentence. Empty string (not null) when nothing contributed that kind.
class OperationTitleFragments {
  final String title;
  final String forText;
  final String atText;
  final String subtitle;

  const OperationTitleFragments({this.title = '', this.forText = '', this.atText = '', this.subtitle = ''});

  bool get isEmpty => title.isEmpty && forText.isEmpty && atText.isEmpty && subtitle.isEmpty;
}

/// Groups suggestions by fragment kind (title/for/at), highest [priority]
/// first within a kind, and joins each kind's fragments with `, ` — the
/// same locale-agnostic separator convention as the app's existing refs
/// line. Subtitles join with ` • ` instead, matching that same line.
OperationTitleFragments mergeOperationTitleSuggestions(Iterable<OperationTitleSuggestion> suggestions) {
  // Indexed explicitly: List.sort isn't guaranteed stable, and most
  // suggestions share the default priority 0 — without this, same-priority
  // refs could join in a different order every call.
  final indexed = suggestions.indexed.toList()
    ..sort((a, b) {
      final byPriority = b.$2.priority.compareTo(a.$2.priority);
      return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
    });
  final sorted = [for (final (_, suggestion) in indexed) suggestion];

  String joinField(String? Function(OperationTitleSuggestion) selector, String separator) =>
      sorted.map(selector).whereType<String>().where((s) => s.isNotEmpty).join(separator);

  return OperationTitleFragments(
    title: joinField((s) => s.title, ', '),
    forText: joinField((s) => s.forText, ', '),
    atText: joinField((s) => s.atText, ', '),
    subtitle: joinField((s) => s.subtitle, ' • '),
  );
}
