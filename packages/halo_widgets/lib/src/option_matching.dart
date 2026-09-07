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
/// operator heading for "Crane Creek") substring-matches "Alum **Cr**eek";
/// accepting that logs `ALU`: a park they never worked, in a field they were
/// only passing through on their way to the next one.
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

/// Where the value the cursor sits in begins and ends, in a field holding
/// several separated values — a QSO party's county line, `ORDES/JEF`.
///
/// The cursor decides, not the end of the text: an operator who goes back to
/// fix the first county must be offered counties for THAT one, and accepting a
/// suggestion must not rewrite the second.
///
/// A cursor sitting just AFTER a separator is in the value that follows it,
/// which is empty until something is typed — so the moment the operator types
/// the separator, the suggestion line stops offering the county they have just
/// finished and waits for the next one.
({int start, int end}) exchangeValueSpan(String text, int cursor, String separator) {
  if (separator.isEmpty) return (start: 0, end: text.length);
  final at = cursor.clamp(0, text.length);
  var start = text.lastIndexOf(separator, at > 0 ? at - 1 : 0);
  start = start < 0 ? 0 : start + separator.length;
  if (start > at) start = at;
  var end = text.indexOf(separator, at);
  if (end < 0) end = text.length;
  return (start: start, end: end);
}

/// The value the cursor is in.
String exchangeValueAt(String text, int cursor, String separator) {
  final span = exchangeValueSpan(text, cursor, separator);
  return text.substring(span.start, span.end);
}

/// [text] with the value the cursor is in replaced by [value], and where the
/// cursor ends up — at the end of what was just written, so the operator can
/// type the separator and carry straight on.
({String text, int cursor}) replaceExchangeValueAt(
  String text,
  int cursor,
  String separator,
  String value,
) {
  final span = exchangeValueSpan(text, cursor, separator);
  final replaced = text.replaceRange(span.start, span.end, value);
  return (text: replaced, cursor: span.start + value.length);
}

/// Every value in [text], in order, with the empty ones dropped — what a
/// multi-value field actually holds. A trailing separator is a value not yet
/// typed, not an empty one.
List<String> splitExchangeValues(String text, String separator) {
  if (separator.isEmpty) {
    final single = text.trim();
    return single.isEmpty ? const [] : [single];
  }
  return [
    for (final part in text.split(separator))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// What a later value in a multi-value field might be short for, or null.
///
/// The multi-state QSO parties let a county line be typed `ORDES/JEF` for
/// `ORDES/ORJEF`, and the scorer and the Cabrillo both read it that way — so
/// the field has to recognize it too, or it paints a perfectly good exchange
/// invalid and offers no suggestions for the second county.
///
/// This answers a CANDIDATE rather than a replacement, and nothing is ever
/// rewritten in the field: after `IDADA/`, `IDA` is either Idaho county's
/// shorthand (`IDIDA`) or the first three characters of `IDIDA` being typed,
/// and `IDIDA`, `UTUTA`, `WAWAH` and `WAWAL` are all real 7QP counties. Only
/// the operator knows which they meant, so both readings are accepted and
/// neither is forced on screen.
String? inheritedCandidate(String first, String value, int prefixLength) {
  if (prefixLength <= 0 || first.length <= prefixLength || value.isEmpty) return null;
  final full = first.length - prefixLength;
  if (value.length > full) return null;
  return '${first.substring(0, prefixLength)}$value';
}

/// Every value in [text], each paired with what it might be short for.
List<(String, String?)> exchangeValueCandidates(
  String text,
  String separator, {
  int inheritPrefix = 0,
}) {
  final values = splitExchangeValues(text, separator);
  return [
    for (final (index, value) in values.indexed)
      (value, index == 0 ? null : inheritedCandidate(values.first, value, inheritPrefix)),
  ];
}

/// Whether every value in [text] is one of [options]' codes.
///
/// All of them, not just the last: a county line whose second county is a typo
/// claims a multiplier that isn't there, and the operator can still fix it
/// while the QSO is in front of them. A field with nothing typed is not
/// invalid — it is unanswered.
bool areKnownExchangeOptions(
  String text,
  List<ExchangeOption> options, {
  String separator = '',
  int inheritPrefix = 0,
}) {
  final values = exchangeValueCandidates(text, separator, inheritPrefix: inheritPrefix);
  if (values.isEmpty) return true;
  // EITHER reading counts: a value that is a county on its own is valid, and so
  // is one that becomes a county once it borrows the first value's prefix.
  return values.every((entry) =>
      isKnownExchangeOption(entry.$1, options) ||
      (entry.$2 != null && isKnownExchangeOption(entry.$2!, options)));
}
