// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How the logging panel reads its call field. The field is rarely one
// callsign: "W1AW, K1ABC" is a list that logs one QSO per call (issue #7),
// "K1ABC//W1AW" is a stack — a second call typed in while the first is still
// queued up — and "//KEY" is a note key asking to be expanded (issue #17).
// Every consumer of the field (the lookup, the score, Enter, Space) has to
// agree on which call the operator means RIGHT NOW, and that depends on the
// cursor as much as on the text. So the rules live here, once, over one
// snapshot of both.

import 'dart:math' as math;

import 'package:halo_core/halo_core.dart';

/// The characters a callsign can be typed from — the call field's own
/// filter, and the test for whether text in it would survive that filter.
/// One class, because a character added to the filter and not to the test
/// would let a free-text parameter be judged safe and then be stripped by
/// the returning filter on the next keystroke.
const callsignCharacters = r'a-zA-Z0-9/.,';

/// The "//"-separated segments of a stack, each one's start offset in the
/// field text, and the index of the segment holding the cursor.
typedef StackSegments = ({List<String> segments, List<int> starts, int cursorIndex});

/// One call the panel is about to log out of a stack: its calls (a stacked
/// segment may itself be a comma list), what is left in the field for the
/// next QSO, and which segment it was.
typedef StackedPick = ({List<String> calls, String remainder, int index});

/// A snapshot of the call field — its text and where the cursor is — and the
/// rules that read one call out of it. Immutable; the panel takes a fresh one
/// off the controller whenever it asks.
class CallFieldText {
  const CallFieldText(this.text, {required this.cursor, required this.stacking});

  /// The field's text, as typed.
  final String text;

  /// The selection's base offset; negative when the field has no selection
  /// (unfocused), which every rule below reads as "the last segment, the one
  /// the operator was most recently typing into".
  final int cursor;

  /// Whether "//" is stack syntax at all — only while composing a new QSO.
  /// Editing an existing one edits that one record, whatever the text says.
  final bool stacking;

  /// The whole field, trimmed and uppercased — a plain callsign.
  String get call => text.trim().toUpperCase();

  /// Trimmed WITHOUT forcing uppercase — for command interpretation only, so
  /// free-text parameters (e.g. NOTE's captured text) keep the case the user
  /// actually typed. Command prefixes themselves are matched
  /// case-insensitively by every extension, so this is safe to use in place
  /// of [call] for that one purpose.
  String get commandInput => text.trim();

  /// Comma-separated calls — "W1AW, K1ABC" logs one QSO per call (issue #7)
  /// rather than one QSO whose call is the literal joined string. A single
  /// call with no comma is just a one-item list, so this also covers the
  /// common case.
  List<String> get callList => call.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  /// Whether the field is using "//" stack syntax (issue #7). The one
  /// predicate every stacking-aware rule below shares, so they can't drift
  /// out of agreement about which fields are stacks.
  ///
  /// A field STARTING with "//" is a stack too — its first segment is just
  /// empty — so "//KEY//W1AW" is both note-expansion syntax (issue #17) and
  /// a stack, and gets both. Whole-field expansion still wins on Enter, but
  /// by ORDER (the panel's log path), not by this predicate carving it out —
  /// exclude it here and "//KEY//W1AW" is neither syntax, so Enter does
  /// nothing at all.
  bool get isStack => stacking && text.contains('//');

  /// Every callsign the field currently holds, under either multi-call
  /// syntax: the comma-separated list, or the "//" stack's segments — each
  /// of which may itself be a comma list ("KI2D//W1AB,W1AC"), so a stack is
  /// split on both separators, not just "//".
  ///
  /// This is what tells a call being CORRECTED — it leaves the field — from
  /// one merely being typed alongside others, which moves the cursor off it
  /// without replacing it.
  Iterable<String> get callsInField {
    final segments = isStack ? text.split('//') : [text];
    return segments.expand((segment) => segment.split(',')).map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty);
  }

  /// The single call that's actually relevant right now — the whole field
  /// for a plain callsign, whichever "//"-stacked segment [pickStackedCall]
  /// would pick (new QSOs only), or whichever comma-separated segment the
  /// cursor sits in (new or editing). Neither the on-screen lookup preview
  /// nor the DUPE chip make sense against the raw, multi-call field text, so
  /// both key off this instead. "//" takes priority over "," — a field can't
  /// meaningfully be both a stack and a list at once, and "//" is the more
  /// specific syntax.
  String get callAtCursor {
    if (isStack) {
      final picked = pickStackedCall();
      if (picked == null) return call;
      // A stacked segment can itself be a comma list ("KI2D//W1AB,W1AC") —
      // follow the cursor inside it exactly as a top-level list does, but
      // only when the cursor is actually in that segment: the scan-left
      // fallback picks a segment the cursor never entered, and there the
      // first call is the best answer available.
      final stack = stackSegments();
      if (picked.index == stack.cursorIndex) {
        // Floored at 0, but only once there IS a selection: a cursor parked
        // between the two slashes belongs to the segment that follows, and a
        // bare subtraction would hand over a negative offset, which reads as
        // "no selection" and picks the segment's LAST comma entry instead of
        // its first. A genuinely unfocused field keeps its own negative
        // offset, where that last-entry fallback is the intended answer.
        return commaSegmentAtCursor(stack.segments[picked.index], cursor < 0 ? cursor : math.max(0, cursor - stack.starts[picked.index]));
      }
      return picked.calls.first;
    }
    return commaSegmentAtCursor(text, cursor);
  }

  /// The comma-separated segment of [text] that [cursor] — an offset into
  /// [text] — sits in, uppercased and trimmed. A cursor outside the text
  /// (negative, i.e. no selection) falls back to the LAST segment, the one
  /// an unfocused field was most recently typing into.
  static String commaSegmentAtCursor(String text, int cursor) {
    if (!text.contains(',')) return text.trim().toUpperCase();
    final segments = text.split(',');
    var index = segments.length - 1;
    if (cursor >= 0) {
      var offset = 0;
      for (var i = 0; i < segments.length; i++) {
        offset += segments[i].length;
        if (cursor <= offset) {
          index = i;
          break;
        }
        offset += 1; // the "," separator
      }
    }
    return segments[index].trim().toUpperCase();
  }

  /// The "//"-separated segments, each one's start offset, and the index of
  /// the segment holding the cursor (the last segment when there is no
  /// selection). The single place that locates the cursor within a stack, so
  /// stacking, the cursor's own call and mid-stack note expansion can't
  /// disagree about which segment the operator is on.
  StackSegments stackSegments() {
    final segments = text.split('//');
    final starts = <int>[];
    var offset = 0;
    for (final segment in segments) {
      starts.add(offset);
      offset += segment.length + 2; // the "//" separator
    }
    var cursorIndex = segments.length - 1;
    if (cursor >= 0) {
      for (var i = 0; i < segments.length; i++) {
        if (cursor <= starts[i] + segments[i].length) {
          cursorIndex = i;
          break;
        }
      }
    }
    // A note key's leading "//" is a separator, not a segment the operator
    // can be inside. Offset 0 otherwise resolves to that empty first segment,
    // which has nothing to expand and nothing to log — so Enter on "//KEY"
    // would do nothing at all, and one character to the right would work.
    if (cursorIndex == 0 && segments.length > 1 && segments[0].trim().isEmpty) {
      cursorIndex = 1;
    }
    return (segments: segments, starts: starts, cursorIndex: cursorIndex);
  }

  /// Call stacking (issue #7): the field holds "//"-separated calls or
  /// fragments (e.g. "K1ABC//W1AW" — a second call typed in while the first
  /// is still queued up). Scanning left from the cursor, picks the first
  /// segment that reads as a callsign — or as a comma-separated list of
  /// them, the shape a mid-stack note expansion leaves behind
  /// ("KI2D//W1AB,W1AC") — and returns its calls alongside the remaining
  /// segments (still "//"-joined) to leave in the field for the next QSO.
  /// Every call in the picked segment logs, exactly as a top-level comma
  /// list does; the segment leaves the field either way. Null when the field
  /// is not a stack, or no segment reads as a call.
  ///
  /// A field starting with "//" is a stack whose first segment is empty —
  /// that segment holds no calls, so it is simply skipped. `//W1AW` whose
  /// key matches a note never reaches here at all: the panel runs the
  /// whole-field command first and returns. One that matches nothing does,
  /// and logs W1AW as the plain callsign it looks like.
  StackedPick? pickStackedCall() {
    if (!isStack) return null;
    final stack = stackSegments();
    for (var i = stack.cursorIndex; i >= 0; i--) {
      final calls = stack.segments[i].split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toList();
      if (calls.isNotEmpty && calls.every(looksLikeCallsign)) {
        final remainder = [...stack.segments]..removeAt(i);
        return (calls: calls, remainder: remainder.join('//'), index: i);
      }
    }
    return null;
  }

  /// The command input that would expand [stack]'s cursor segment ("//1AB"),
  /// or null when that segment is empty, when it IS the whole field (the
  /// panel's whole-field command path has already asked that exact question
  /// and acted on the answer — asking again buys nothing and costs a second
  /// JS round trip on the Enter path, widening the window two auto-repeated
  /// Enters race in), or when it is [alreadyExpanded] — a key expands at most
  /// once per draft. Checked here, in the one place both the Enter path and
  /// the typing preview build their input, so the preview can't go on
  /// offering an expansion Enter will no longer perform.
  String? expansionInputFor(StackSegments stack, {required String? alreadyExpanded}) {
    final key = stack.segments[stack.cursorIndex].trim();
    if (key.isEmpty) return null;
    final input = '//$key';
    if (input == commandInput) return null;
    return input == alreadyExpanded ? null : input;
  }
}
