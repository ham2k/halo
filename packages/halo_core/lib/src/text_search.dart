// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one rule every text search in the app matches by: what was typed has to
// begin a WORD of the text searched, never land in the middle of one. Without
// it `and` finds "Bands", `2m` finds "12m" and `sb` finds "USB" — runs buried
// mid-word, which is never what anyone typing a word means.
//
// The settings search's subsequence scorer (app/lib/settings/settings_fuzzy.dart)
// anchors each typed word by the same rule over ASCII; past ASCII it counts
// any non-ASCII character as a separator, where this one does not.

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _digit = RegExp(r'\p{N}', unicode: true);

/// Whether [index] in [text] begins a word: the start of the text, the first
/// character after anything that is not a letter or digit, a camelCase hump
/// (`showGridField`), or the first digit after a letter (`FT8`).
///
/// A letter right after a digit is NOT a start — otherwise `m` would begin
/// every band name from `2m` to `160m`.
bool isWordStart(String text, int index) {
  if (index == 0) return true;
  final c = text[index];
  final prev = text[index - 1];
  if (!_letterOrDigit.hasMatch(prev)) return true;
  if (!_letterOrDigit.hasMatch(c)) return false;
  final prevIsDigit = _digit.hasMatch(prev);
  if (_digit.hasMatch(c)) return !prevIsDigit;
  if (prevIsDigit) return false;
  final isUpper = c != c.toLowerCase();
  final prevIsLower = prev != prev.toUpperCase();
  return isUpper && prevIsLower;
}

/// Whether [needle] appears in [haystack], case-insensitively, starting at a
/// word start ([isWordStart]). The needle is matched as typed, spaces and
/// all, so a phrase must appear as a phrase. An empty needle matches, as it
/// would for `contains`.
bool matchesWordStart(String haystack, String needle) {
  if (needle.isEmpty) return true;
  final lower = haystack.toLowerCase();
  final target = needle.toLowerCase();
  // Lowercasing can change a string's length (a few non-ASCII letters), and
  // then positions in `lower` no longer line up with `haystack`'s; the
  // boundary is read from `lower` instead, losing only camelCase humps.
  final source = lower.length == haystack.length ? haystack : lower;
  for (var i = lower.indexOf(target); i >= 0; i = lower.indexOf(target, i + 1)) {
    if (isWordStart(source, i)) return true;
  }
  return false;
}
