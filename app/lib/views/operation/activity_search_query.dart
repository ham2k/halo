// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How the operation sheet's search box reads what was typed: a leading scope
// word, its colon, and the text after them. Pure string work, apart from the
// search's state in activity_search_state.dart.

/// The word the search box scopes a reference type by: the type's base name,
/// lowercased — `potaActivation` and `pota` are both `pota`.
///
/// A ref TYPE, not the extension's key, on purpose: a user-published
/// extension is keyed by its author's callsign (`ki2d-pota`), and the
/// operator adding parks from it is still adding POTA parks. The scope names
/// what is being searched for, and two extensions serving the same type
/// share it.
///
/// `<base>Activation` / `<base>` is the convention every activity's pair of
/// ref types follows (see `activityRefTypes`), which is what makes the base
/// name derivable at all.
String activityScopeWord(String refType) => refType.replaceFirst(RegExp(r'Activation$'), '').toLowerCase();

/// A search box entry split into an optional scope and the text after it:
/// `pota:` scopes to POTA's own suggestions, `pota: bear mtn` scopes AND
/// searches, `pota bear mtn` merely gives POTA precedence, and plain `bear
/// mtn` searches everything evenly. The scope is what the "Activity Types"
/// rows insert when tapped, and is a ref type's [activityScopeWord] rather
/// than an extension key — see there for why.
class ActivitySearchQuery {
  /// The activity hook keys to ask — every extension serving the scoped ref
  /// type — or null for "every activity hook".
  final List<String>? activityKeys;

  /// The extensions whose suggestions rank ahead of every other one's, or
  /// null when no leading word was typed. Never set together with
  /// [activityKeys] — preferring is the soft form of scoping, for when the
  /// word came without a colon and the rest of the box may still be meant for
  /// someone else.
  final List<String>? preferredKeys;

  /// What [activityKeys] / [preferredKeys] search for — empty means "just
  /// show me this scope's nearby suggestions".
  final String term;

  /// What every OTHER hook searches for: the raw input, leading key word and
  /// all. Only the named extension gets its own key stripped — handing the
  /// leftover text to the rest would bury `sota bear` under every park named
  /// Bear, and precedence is supposed to narrow the list, not widen it.
  /// Equals [term] whenever [preferredKeys] is null.
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
      final rest = (word!.group(2) ?? '').trim();
      // A word on its own scopes exactly like `word:` does: there is nothing
      // else in the box that the other extensions could be answering.
      if (rest.isEmpty) return ActivitySearchQuery(activityKeys: wordKeys, term: '', otherTerm: '');
      return ActivitySearchQuery(preferredKeys: wordKeys, term: rest, otherTerm: trimmed);
    }

    return ActivitySearchQuery(term: trimmed, otherTerm: trimmed);
  }

  /// The text the search field holds for a bare scope — what tapping an
  /// "Activity Types" row types for the user.
  static String scopePrefixFor(String scopeWord) => '$scopeWord: ';
}

/// What's in [typed] past a leading [key], or empty when it doesn't lead with
/// that key at all — an extension matched by its name or a keyword leaves
/// nothing worth carrying into its scope.
String searchTextAfterKey(String typed, String key) {
  final trimmed = typed.trim();
  final firstWord = trimmed.split(RegExp(r'\s')).first;
  if (firstWord.replaceFirst(RegExp(r':$'), '').toLowerCase() != key.toLowerCase()) return '';
  return trimmed.substring(firstWord.length).trim();
}
