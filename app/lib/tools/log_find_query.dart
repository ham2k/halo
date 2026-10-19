// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// What the Find bar over a log was asked for — read from its text by
/// [LogFindQuery.parse]:
///
/// - digits alone — the contact with that Number ([number]); a callsign
///   always holds a letter, so digits alone are never one;
/// - a call with a period at the end — that exact callsign ([exact]);
/// - anything else — every callsign holding it anywhere.
///
/// Callsigns compare uppercase, the way they are stored.
class LogFindQuery {
  /// The Number column's value to jump to, or null for a callsign search.
  final int? number;

  /// The callsign, or the part of one, searched for — uppercase, and empty
  /// for a [number] query.
  final String call;

  /// Whether [call] must be the whole callsign rather than any part of it.
  final bool exact;

  const LogFindQuery._({this.number, this.call = '', this.exact = false});

  /// Null for text that asks for nothing: empty, blank, or a period alone.
  static LogFindQuery? parse(String text) {
    var query = text.trim().toUpperCase();
    if (query.isEmpty) return null;
    if (RegExp(r'^\d{1,9}$').hasMatch(query)) return LogFindQuery._(number: int.parse(query));
    final exact = query.endsWith('.');
    if (exact) query = query.substring(0, query.length - 1).trimRight();
    if (query.isEmpty) return null;
    return LogFindQuery._(call: query, exact: exact);
  }

  /// Whether [theirCall] is a callsign this query finds. A [number] query
  /// filters nothing, so it finds every one.
  bool matchesCall(String theirCall) {
    if (number != null) return true;
    final upper = theirCall.toUpperCase();
    return exact ? upper == call : upper.contains(call);
  }
}
