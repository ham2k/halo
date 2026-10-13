// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How the operation sheet's search box reads what was typed: a leading scope
// word, its colon, and the text after them. Pure string work, apart from the
// search's state in activity_search_state.dart.

import '../../services/extensions/extension_info.dart';

/// A search box entry split into an optional scope and the text after it:
/// `pota:` scopes to POTA's own suggestions, `pota: bear mtn` scopes AND
/// searches, and plain `bear mtn` searches everything evenly. A scope word
/// without its colon gives precedence instead: `pota` alone is POTA's own
/// suggestions ahead of everything else's answer to "pota", and `pota bear
/// mtn` is POTA's answer to "bear mtn" ahead of everyone else's answer to
/// the whole text. The words
/// are [activityScopeWordsOf] — a declared ref type's word, or an extension's
/// own key — and the "Activity Types" rows insert the type's word when
/// tapped.
class ActivitySearchQuery {
  /// The activity hook keys to ask — every extension serving the scoped ref
  /// type — or null for "every activity hook".
  final List<String>? activityKeys;

  /// The extensions whose suggestions rank ahead of every other one's, or
  /// null when no scope word led the box. Never set together with
  /// [activityKeys] — preferring is the soft form of scoping, for a word that
  /// came without a colon: the box may still be meant for someone else.
  final List<String>? preferredKeys;

  /// What [activityKeys] / [preferredKeys] search for — empty means "just
  /// show me this scope's own suggestions". A preferred extension asked with
  /// it empty is asked as a scope, since its own list is what the word asked
  /// for.
  final String term;

  /// What every OTHER hook searches for: the whole box, scope word and all.
  /// Only the named extensions get the word stripped: they match a search
  /// against their codes and names as one string, so `bear mtn` finds the
  /// parks and `pota bear mtn` finds nothing. The rest search for the word
  /// too — `llota` is what a search for the program's name types — and
  /// handing them the leftover alone would bury `sota bear` under every park
  /// named Bear. Equals [term] whenever [preferredKeys] is null.
  final String otherTerm;

  const ActivitySearchQuery({this.activityKeys, this.preferredKeys, required this.term, required this.otherTerm});

  static final _scopePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9_-]*):(.*)$', dotAll: true);
  static final _leadingWordPattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9_-]*)(?:\s+(.*))?$', dotAll: true);

  /// A leading scope word, with or without its colon, only counts when
  /// [scopes] actually has it — references and park names carry colons and
  /// lead with words too (`US-0001: Something`, `bear mountain`), and treating
  /// one as a scope would quietly search the wrong extension, or none, while
  /// looking like it worked. [scopes] maps each word to the activity hook
  /// keys that serve it, which is what the query carries: the word is the
  /// operator's, the keys are the runtime's.
  factory ActivitySearchQuery.parse(String input, Map<String, List<String>> scopes) {
    final trimmed = input.trim();

    final scope = _scopePattern.firstMatch(trimmed);
    final scopeKeys = scopes[scope?.group(1)?.toLowerCase()];
    if (scopeKeys != null) {
      final term = (scope!.group(2) ?? '').trim();
      return ActivitySearchQuery(activityKeys: scopeKeys, term: term, otherTerm: term);
    }

    final word = _leadingWordPattern.firstMatch(trimmed);
    final wordKeys = scopes[word?.group(1)?.toLowerCase()];
    if (wordKeys != null) {
      // A word on its own asks the extensions it names for their own list
      // (an empty term), and everyone else for the word as text.
      final rest = (word!.group(2) ?? '').trim();
      return ActivitySearchQuery(preferredKeys: wordKeys, term: rest, otherTerm: trimmed);
    }

    return ActivitySearchQuery(term: trimmed, otherTerm: trimmed);
  }

  /// The text the search field holds for a bare scope — what tapping an
  /// "Activity Types" row types for the user.
  static String scopePrefixFor(String scopeWord) => '$scopeWord: ';
}

/// What's in [typed] past a leading word that is one of [words], or empty
/// when it doesn't lead with one at all — an extension matched by its name or
/// a keyword leaves nothing worth carrying into its scope.
String searchTextAfterScopeWord(String typed, List<String> words) {
  final trimmed = typed.trim();
  final firstWord = trimmed.split(RegExp(r'\s')).first;
  if (!words.contains(firstWord.replaceFirst(RegExp(r':$'), '').toLowerCase())) return '';
  return trimmed.substring(firstWord.length).trim();
}
