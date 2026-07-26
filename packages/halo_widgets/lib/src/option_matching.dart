// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Matching a typed exchange against a set of known codes — the search behind a
// `kind: 'options'` logging control (docs/design/contests.md §5.3).
//
// A pure function with its own tests, deliberately separate from the widget:
// this is the ranking an operator feels on every QSO, and it needs exercising
// against real code lists without pumping a widget tree.

/// One selectable value: a code the operator sends, and optionally the name it
/// stands for.
class ExchangeOption {
  /// What actually goes in the log — a county abbreviation, a section, a park.
  final String code;

  /// The human name, matched against as well as shown. A county's full name is
  /// often easier to recall than its abbreviation.
  final String? name;

  const ExchangeOption({required this.code, this.name});

  static ExchangeOption? fromMap(Map<String, dynamic> map) {
    final code = map['code'];
    if (code is! String || code.isEmpty) return null;
    final name = map['name'];
    return ExchangeOption(code: code, name: name is String && name.isNotEmpty ? name : null);
  }
}

/// [options] that match [query], best first.
///
/// The tiers, in order: an exact code, then a code prefix, then a name prefix,
/// then a code substring, then a name substring. An operator who knows the code
/// types the code, so exact and prefix hits on it come first; someone reaching
/// for "the one that starts with Wash" is served by the name tiers.
///
/// [preferred] floats codes up WITHIN their tier rather than above it — a QSO
/// party can surface the caller's likely state without burying an exact match
/// the operator typed in full. §5.3 asks for ranking rather than prefilling
/// here precisely because a guess is wrong often enough to be annoying.
///
/// An empty [query] returns the preferred codes first and everything else in
/// declaration order, so a freshly focused field can show something useful.
///
/// Matching ignores case on both sides. [limit] caps the result because this
/// feeds a suggestion line, not a browsable list.
List<ExchangeOption> matchExchangeOptions(
  String query,
  List<ExchangeOption> options, {
  Set<String> matchOn = const {'code', 'name'},
  List<String> preferred = const [],
  int limit = 8,
}) {
  final preferredSet = {for (final code in preferred) code.toUpperCase()};

  int preferenceRank(ExchangeOption option) => preferredSet.contains(option.code.toUpperCase()) ? 0 : 1;

  final trimmed = query.trim().toUpperCase();
  if (trimmed.isEmpty) {
    final ordered = [
      for (var i = 0; i < options.length; i++) (index: i, option: options[i]),
    ]..sort((a, b) {
        final byPreference = preferenceRank(a.option).compareTo(preferenceRank(b.option));
        return byPreference != 0 ? byPreference : a.index.compareTo(b.index);
      });
    return [for (final entry in ordered.take(limit)) entry.option];
  }

  final matched = <({int index, int tier, ExchangeOption option})>[];
  for (var i = 0; i < options.length; i++) {
    final t = exchangeMatchTier(trimmed, options[i], matchOn: matchOn);
    if (t != null) matched.add((index: i, tier: t, option: options[i]));
  }

  matched.sort((a, b) {
    final byTier = a.tier.compareTo(b.tier);
    if (byTier != 0) return byTier;
    final byPreference = preferenceRank(a.option).compareTo(preferenceRank(b.option));
    if (byPreference != 0) return byPreference;
    // Declaration order last, so a set that arrives already sensibly ordered
    // keeps that order among equals.
    return a.index.compareTo(b.index);
  });

  return [for (final entry in matched.take(limit)) entry.option];
}

/// How closely [option] answers [query] — 0 the best, null not at all.
///
/// The five tiers `matchExchangeOptions` ranks by, exposed because the SPACE
/// shortcut needs to know which of them it is looking at: accepting a suggestion
/// replaces what the operator typed, and only the tiers where their own text is a
/// PREFIX of the answer are safe to do that with.
int? exchangeMatchTier(
  String query,
  ExchangeOption option, {
  Set<String> matchOn = const {'code', 'name'},
}) {
  final trimmed = query.trim().toUpperCase();
  if (trimmed.isEmpty) return null;
  final byCode = matchOn.contains('code');
  final byName = matchOn.contains('name');
  final code = option.code.toUpperCase();
  final name = (option.name ?? '').toUpperCase();
  if (byCode && code == trimmed) return 0;
  if (byCode && code.startsWith(trimmed)) return 1;
  if (byName && name.isNotEmpty && name.startsWith(trimmed)) return 2;
  if (byCode && code.contains(trimmed)) return 3;
  if (byName && name.isNotEmpty && name.contains(trimmed)) return 4;
  return null;
}

/// Whether [option] is a close enough answer to [query] for SPACE to replace
/// what the operator typed with it.
///
/// Only the prefix tiers: an exact code, a code they have started typing, or a
/// name they have started typing. A SUBSTRING hit is fine to show — it is how you
/// find "Alum Creek" from "creek" — but accepting one silently swaps in a code
/// the typed text isn't even the start of. In the shipped Ohio set, `CR` (an
/// operator heading for "Crane Creek") substring-matches "Alum **Cr**eek" and
/// used to log `ALU`: a park they never worked, in a field they were only passing
/// through on their way to the next one.
bool isAcceptableExchangeMatch(
  String query,
  ExchangeOption option, {
  Set<String> matchOn = const {'code', 'name'},
}) {
  final tier = exchangeMatchTier(query, option, matchOn: matchOn);
  return tier != null && tier <= 2;
}

/// Whether [value] is one of [options]' codes. Case-insensitive, because the
/// field upper-cases as you type but a restored or synced value may not have.
bool isKnownExchangeOption(String value, List<ExchangeOption> options) {
  final needle = value.trim().toUpperCase();
  if (needle.isEmpty) return false;
  return options.any((option) => option.code.toUpperCase() == needle);
}
