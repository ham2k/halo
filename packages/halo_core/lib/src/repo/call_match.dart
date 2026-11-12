// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The callsigns that could be the one being typed — `ctx.findCalls` over the
// log and `host.dbLookupFindCalls` over reference data, what a "super check
// partial" reads. One parse and one set of rules for both hosts: the app runs
// [CallMatch.whereSql] in its queries, the CLI runs [CallMatch.kindOf] over
// the QSOs it was handed, and `call_match_test.dart` runs the same cases
// through both.

/// How a callsign matched the text, closest first. A call that matches in
/// several ways is reported by the closest.
enum CallMatchKind {
  /// The whole call, a `?` standing for any one character.
  exact,

  /// The text appears somewhere in the call (`K1A` in `WK1AB`).
  partial,

  /// One edit away: a character changed, added or removed, or two adjacent
  /// ones swapped. Not offered for text with a `?`.
  oneEdit,
}

class CallMatch {
  /// What a call answers when it does not say.
  static const defaultLimit = 20;

  /// A short partial matches a large share of any log; this bounds what one
  /// call ships across the extension bridge.
  static const maxLimit = 100;

  /// What a callsign is spelled with, and so every character [variants]
  /// tries.
  static const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/';

  /// Longer than any callsign, prefix and suffix included. [variants] grows
  /// with the square of the length and is written whole into one SQL
  /// statement, built on the caller's isolate, so text past this rejects
  /// rather than costing megabytes.
  static const maxLength = 20;

  /// Uppercase, of [alphabet] and `?` only — which is what makes the text
  /// safe to write into SQL as a literal and a GLOB pattern.
  final String text;
  final Set<CallMatchKind> kinds;
  final int limit;

  CallMatch(String text, {Set<CallMatchKind>? kinds, this.limit = defaultLimit})
    : text = _normalized(text, 'CallMatch'),
      kinds = kinds ?? CallMatchKind.values.toSet();

  /// The params this class reads; a host call that takes other options too
  /// passes these to theirs as known.
  static const paramKeys = {'call', 'match', 'limit'};

  /// Parses a host call's `call`, `match` and `limit`. A malformed value
  /// throws [FormatException], which the host turns into a rejected promise:
  /// a call it could not read must not answer as if it had asked something
  /// else. `match` is one kind or a list of them, every kind when absent.
  ///
  /// With [alsoKnown], the call's other options, any key that is neither
  /// one of [paramKeys] nor one of those throws too: a misspelled `match`
  /// would otherwise answer every kind. A host call whose other options are
  /// checked elsewhere ([HistoryFilter.fromParams]) leaves it null.
  factory CallMatch.fromParams(Map<String, dynamic> params, {required String hostCall, Set<String>? alsoKnown}) {
    if (alsoKnown != null) {
      for (final key in params.keys) {
        // The kernel names the caller on every host call it makes.
        if (key != 'extensionKey' && !paramKeys.contains(key) && !alsoKnown.contains(key)) throw FormatException('$hostCall: unknown option `$key`');
      }
    }
    final call = params['call'];
    if (call is! String) throw FormatException('$hostCall: `call` must be a string, got $call');
    final match = params['match'];
    final Set<CallMatchKind> kinds;
    if (match == null) {
      kinds = CallMatchKind.values.toSet();
    } else {
      final names = match is String ? [match] : (match is List && match.every((m) => m is String) ? match.cast<String>() : null);
      if (names == null || names.isEmpty) throw FormatException('$hostCall: `match` must be one of exact, partial, oneEdit or a list of them, got $match');
      kinds = {
        for (final name in names)
          CallMatchKind.values.asNameMap()[name] ?? (throw FormatException('$hostCall: `match` must be one of exact, partial, oneEdit, got $name')),
      };
    }
    final limit = params['limit'];
    if (limit != null && (limit is! num || limit < 1)) throw FormatException('$hostCall: `limit` must be a positive number, got $limit');
    return CallMatch._(_normalized(call, hostCall), kinds: kinds, limit: limit == null ? defaultLimit : (limit as num).toInt().clamp(1, maxLimit));
  }

  CallMatch._(this.text, {required this.kinds, required this.limit});

  static String _normalized(String text, String hostCall) {
    final upper = text.trim().toUpperCase();
    if (upper.length > maxLength) throw FormatException('$hostCall: `call` may be at most $maxLength characters, got ${upper.length}');
    for (final unit in upper.codeUnits) {
      if (unit != 0x3f && !alphabet.codeUnits.contains(unit)) {
        throw FormatException('$hostCall: `call` may hold only letters, digits, `/` and `?`, got $text');
      }
    }
    return upper;
  }

  bool get hasWildcard => text.contains('?');

  /// Nothing to match: no text, or only the one-edit kind for text with a
  /// `?`, which that kind is not offered for.
  bool get isEmpty => text.isEmpty || (hasWildcard && kinds.every((kind) => kind == CallMatchKind.oneEdit));

  /// Every call one edit from [text], [text] itself left out. About 400 for
  /// a five-character call — few enough to look up by index, where a scan
  /// computing an edit distance per row would read the whole table.
  late final Set<String> variants = hasWildcard ? const {} : _variantsOf(text);

  static Set<String> _variantsOf(String text) {
    final variants = <String>{};
    for (var i = 0; i < text.length; i++) {
      variants.add(text.substring(0, i) + text.substring(i + 1));
      if (i + 1 < text.length && text[i] != text[i + 1]) {
        variants.add(text.substring(0, i) + text[i + 1] + text[i] + text.substring(i + 2));
      }
      for (final char in alphabet.split('')) {
        variants.add(text.substring(0, i) + char + text.substring(i + 1));
      }
    }
    for (var i = 0; i <= text.length; i++) {
      for (final char in alphabet.split('')) {
        variants.add(text.substring(0, i) + char + text.substring(i));
      }
    }
    return variants
      ..remove(text)
      ..remove('');
  }

  late final RegExp _exactPattern = RegExp('^${text.replaceAll('?', '.')}\$');
  late final RegExp _partialPattern = RegExp(text.replaceAll('?', '.'));

  /// How [call] matches, or null when it does not — under [kinds] only.
  /// [call] is compared as it is spelled; callers uppercase it first, as
  /// the log's `theirCall` column already is.
  CallMatchKind? kindOf(String call) {
    if (isEmpty) return null;
    if (kinds.contains(CallMatchKind.exact) && _exactPattern.hasMatch(call)) return CallMatchKind.exact;
    if (kinds.contains(CallMatchKind.partial) && _partialPattern.hasMatch(call)) return CallMatchKind.partial;
    if (kinds.contains(CallMatchKind.oneEdit) && variants.contains(call)) return CallMatchKind.oneEdit;
    return null;
  }

  /// [kindOf] as a SQL condition on [column] (a quoted column reference):
  /// that it is one of the values of [key] in [table] that match, those
  /// rows narrowed by [also] when given.
  ///
  /// The matching values are looked for apart, and the outer query seeks
  /// each in its index: a pattern scan reads the whole index of [key] once,
  /// and the whole call and its one-edit [variants] are looked up by value.
  /// One condition testing every row against all of them reads that index
  /// three times as slowly, the variant list costing more than the scan.
  ///
  /// The literals are written inline rather than bound: [variants] can
  /// outnumber the bound variables an older SQLite allows in one statement,
  /// and [text] holds nothing that needs quoting beyond the quotes.
  String whereSql(String column, {required String table, required String key, String also = ''}) {
    if (isEmpty) return '0';
    final narrowed = also.isEmpty ? '' : ' AND $also';
    final patterns = [
      if (kinds.contains(CallMatchKind.exact) && hasWildcard) "$key GLOB '$text'",
      if (kinds.contains(CallMatchKind.partial)) "$key GLOB '*$text*'",
    ];
    final values = {if (kinds.contains(CallMatchKind.exact) && !hasWildcard) text, if (kinds.contains(CallMatchKind.oneEdit)) ...variants};
    final selects = [
      if (patterns.isNotEmpty) 'SELECT $key FROM $table WHERE (${patterns.join(' OR ')})$narrowed',
      if (values.isNotEmpty) 'SELECT $key FROM $table WHERE $key IN (${values.map((v) => "'$v'").join(', ')})$narrowed',
    ];
    return selects.isEmpty ? '0' : '$column IN (${selects.join(' UNION ')})';
  }

  /// The [CallMatchKind.index] of a row [whereSql] kept, so a query can put
  /// the closest matches first before its limit cuts the list. Null when
  /// only one-edit matches are asked for, which all rank alike: a bare
  /// integer in an ORDER BY names a result column, not a value.
  String? rankSql(String column) {
    final exact = kinds.contains(CallMatchKind.exact) ? 'WHEN ${_exactSql(column)} THEN 0 ' : '';
    final partial = kinds.contains(CallMatchKind.partial) ? "WHEN $column GLOB '*$text*' THEN 1 " : '';
    return exact.isEmpty && partial.isEmpty ? null : 'CASE $exact${partial}ELSE 2 END';
  }

  String _exactSql(String column) => hasWildcard ? "$column GLOB '$text'" : "$column = '$text'";
}

/// A callsign [CallMatch] found in the log: how it matched, how many
/// contacts it has, and when the latest started.
typedef FoundCall = ({String call, CallMatchKind match, int count, int? lastAtMillis});

/// [FoundCall]s closest first, then the most worked, then the most recent,
/// then by call — the order both hosts answer in. A contact with no start
/// time is older than any that has one, as SQLite orders a NULL.
int compareFoundCalls(FoundCall a, FoundCall b) {
  final byKind = a.match.index.compareTo(b.match.index);
  if (byKind != 0) return byKind;
  final byCount = b.count.compareTo(a.count);
  if (byCount != 0) return byCount;
  final (aLast, bLast) = (a.lastAtMillis, b.lastAtMillis);
  if (aLast != bLast) {
    if (aLast == null) return 1;
    if (bLast == null) return -1;
    return bLast.compareTo(aLast);
  }
  return a.call.compareTo(b.call);
}

/// `QsoHistoryQueries.findCalls` over contacts already held — the CLI's
/// log. [contacts] are the ones that count, each its call as stored and
/// start time; the caller has already left out the deleted, the event
/// markers and those a filter rejects.
List<FoundCall> findCallsAmong(Iterable<({String call, int? startAtMillis})> contacts, CallMatch match) {
  final byCall = <String, ({CallMatchKind match, int count, int? last})>{};
  for (final (:call, :startAtMillis) in contacts) {
    final kind = match.kindOf(call);
    if (kind == null) continue;
    final held = byCall[call];
    final last = held?.last;
    byCall[call] = (
      match: kind,
      count: (held?.count ?? 0) + 1,
      last: startAtMillis == null ? last : (last == null || startAtMillis > last ? startAtMillis : last),
    );
  }
  final found = [for (final MapEntry(key: call, value: held) in byCall.entries) (call: call, match: held.match, count: held.count, lastAtMillis: held.last)]
    ..sort(compareFoundCalls);
  return found.take(match.limit).toList();
}

Map<String, Object?> foundCallToJson(FoundCall found) => {
  'call': found.call,
  'match': found.match.name,
  'count': found.count,
  'lastAtMillis': found.lastAtMillis,
};
