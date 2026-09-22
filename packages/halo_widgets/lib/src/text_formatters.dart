// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';

import 'platform_chrome.dart';

/// The one uppercase input formatter for the whole package — logging input
/// is uppercase unless a field is explicitly mixed-case. Any behavior change
/// (e.g. locale-aware uppercasing, or preserving the composing region when
/// the text changes) belongs here so every field stays in agreement. `const`
/// so call sites share one canonical instance instead of allocating per
/// build.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Live-cases a Maidenhead grid locator as it's typed: the field pair and
/// square digits (positions 0-3) uppercase, the subsquare and everything
/// after (position 4+) lowercase — the same convention `normalizeGrid`
/// (halo_core) restores for a complete, well-formed locator, applied
/// character-by-character instead of gated on the whole string already being
/// valid, so a field mid-entry ("FN31p...") already reads in its final case
/// rather than snapping to it only once four more characters land.
class GridCaseTextFormatter extends TextInputFormatter {
  const GridCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(i < 4 ? text[i].toUpperCase() : text[i].toLowerCase());
    }
    final formatted = buffer.toString();
    if (formatted == text) return newValue;
    return newValue.copyWith(text: formatted);
  }
}

/// Capitalizes only the field's first letter, live — for a free-text field
/// that reads as a proper noun (a state, a county) but otherwise takes
/// whatever mixed case the operator types, unlike [UpperCaseTextFormatter]'s
/// whole-field uppercasing.
class CapitalizeFirstLetterTextFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final capitalized = text[0].toUpperCase() + text.substring(1);
    if (capitalized == text) return newValue;
    return newValue.copyWith(text: capitalized);
  }
}

/// Rewrites whichever decimal mark the keyboard produced into the one the
/// operator's Number Formatting setting is using.
///
/// Which key a numeric keyboard puts under the operator's thumb is not
/// something this app decides: a Spanish or German phone offers a comma
/// whatever the app is set to, and a desktop numpad emits a period regardless
/// of region. So a `number` field admits both marks and normalizes here,
/// rather than filtering to the configured one and silently swallowing the
/// other — the swallow is invisible (`1,5` simply becomes `15`) and lands on
/// exactly the operator the explicit period/comma options exist to help.
///
/// Normalizing on the way IN rather than at parse time is what keeps the
/// value unambiguous: a field that can only contain the configured decimal
/// never leaves anyone guessing whether the mark in `14.285` was a decimal
/// point or a thousands separator.
///
/// Length is preserved (one mark for one mark), so the caret does not move.
class LocalizedDecimalMarkFormatter extends TextInputFormatter {
  const LocalizedDecimalMarkFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final decimal = NumberFormatting.instance.decimalSeparator;
    // Only the two marks a keyboard actually offers as a decimal point.
    final foreign = ['.', ','].where((mark) => mark != decimal);
    var text = newValue.text;
    for (final mark in foreign) {
      if (_readsAsGrouping(text, mark)) continue;
      text = text.replaceAll(mark, decimal);
    }
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }

  /// Whether [mark] in [text] is a thousands separator rather than a decimal
  /// point — a single occurrence with exactly three digits after it, and
  /// nothing else following.
  ///
  /// A US operator typing `1,500` watts means fifteen hundred. Rewriting that
  /// comma to a period makes it 1.5 — the same silent thousandfold error this
  /// formatter exists to prevent, in the opposite direction. Left alone, the
  /// mark stays foreign and `parseLocalizedNumber` strips it as the grouping
  /// it is.
  static bool _readsAsGrouping(String text, String mark) {
    final first = text.indexOf(mark);
    if (first < 0 || first != text.lastIndexOf(mark)) return false;
    return RegExp('${RegExp.escape(mark)}[0-9]{3}\$').hasMatch(text);
  }
}

/// On mobile, "." often gets typed where "/" was meant — portable/mobile
/// suffixes like "/P" or "/QRP" sit behind an extra keyboard layer, while
/// "." is right on the main keys (issue #7). Converts "." to "/", but only
/// once the text looks like the start of a callsign (a letter, or a
/// digit then a letter) rather than digits alone, so typing a plain
/// frequency ("14.285") keeps its decimal point. See isMobilePlatform.
///
/// A LEADING "." counts too, but only when a letter or another separator
/// follows it: an operator entering a suffix-first call types "/P" the same
/// wrong way, and ".." is the "//" of a call with no prefix yet. Alone or
/// before a digit it stays a full stop, so "." and ".285" — a frequency
/// mid-typing — are left as they are. Note what this rescues is the LEADING
/// period only: what still holds "14.2P" together is its digit-only prefix,
/// exactly as before, and not where in the text the period sits.
///
/// A leading "/" opens a call the same way, under the same rule — and it is
/// what this formatter leaves behind after the first keystroke, so without it
/// "//KI..KN" stops converting the moment its own leading ".." became "//",
/// and "/P.QRP" the moment ".P" became "/P".
///
/// The FIRST word only. A callsign holds no whitespace, so past the first
/// one there is nothing left this could be correcting — what is there is a
/// command's free-text parameter, where a full stop is a full stop: without
/// this bound, "REPORT it crashes. every time" files its card reading
/// "crashes/ every time".
///
/// Public (not `_`-prefixed) so other callsign-entry fields — e.g.
/// HomeQuickLookup in app/lib/views/home_view.dart — can reuse it instead
/// of leaving the same mobile keyboard quirk unhandled there.
class MobileDotToSlashFormatter extends TextInputFormatter {
  static final _callsignPrefix = RegExp(r'^([A-Z]|[0-9][A-Z]|[./][./A-Z])', caseSensitive: false);
  static final _whitespace = RegExp(r'\s');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (!text.contains('.') || !_callsignPrefix.hasMatch(text)) {
      return newValue;
    }
    final end = text.indexOf(_whitespace);
    if (end < 0) return newValue.copyWith(text: text.replaceAll('.', '/'));
    final head = text.substring(0, end);
    if (!head.contains('.')) return newValue;
    return newValue.copyWith(text: head.replaceAll('.', '/') + text.substring(end));
  }
}

/// The input shaping for a field that holds a callsign and nothing else — a
/// settings or dialog field, not the logging panel's Call field, which also
/// takes commands and frequencies and so admits more. Live, not at save time:
/// a hardware keyboard ignores `TextCapitalization`, and a stray character the
/// operator can't see in a field is one they can't fix.
///
/// Uppercases, turns "." into the "/" it was meant to be (on a phone "/" sits
/// behind a second keyboard layer; this field holds no frequency for a "." to
/// belong to), and drops anything but letters, digits and "/".
///
/// A separator — whitespace, ";" or "," — is never simply dropped: with it
/// gone, two calls run together ("W1AW K2ABC" → "W1AWK2ABC") and read as one
/// plausible callsign that no validation warns about. So with [list] (a field
/// holding several calls, see `splitStationCalls`) a run of separators becomes
/// one comma, and without it a single space, which keeps a pasted pair
/// visibly wrong. A lone separator TYPED into a single-call field is refused
/// instead: there it can only be a slip, and the key visibly doing nothing is
/// feedback enough.
///
/// Pair with `autocorrect: false` and `enableSuggestions: false`, or the soft
/// keyboard still suggests and corrects a callsign into a word.
class CallsignTextFormatter extends TextInputFormatter {
  final bool list;

  const CallsignTextFormatter({this.list = false});

  static final _separators = RegExp(r'[\s;,]+');
  static final _listDisallowed = RegExp(r'[^A-Z0-9/,]');
  static final _singleDisallowed = RegExp(r'[^A-Z0-9/ ]');

  String _shape(String text) {
    final mapped = text.toUpperCase().replaceAll('.', '/').replaceAll(_separators, list ? ',' : ' ');
    return mapped.replaceAll(list ? _listDisallowed : _singleDisallowed, '');
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final caret = newValue.selection.isValid ? newValue.selection.end.clamp(0, text.length) : text.length;
    if (!list && text.length == oldValue.text.length + 1 && caret > 0 && _separators.hasMatch(text[caret - 1])) {
      return oldValue;
    }
    // Shaped either side of the caret so it stays put relative to what was typed.
    final before = _shape(text.substring(0, caret));
    var after = _shape(text.substring(caret));
    final separator = list ? ',' : ' ';
    if (before.endsWith(separator) && after.startsWith(separator)) after = after.substring(1);
    final shaped = before + after;
    if (shaped == text) return newValue;
    return TextEditingValue(
      text: shaped,
      selection: TextSelection.collapsed(offset: before.length),
    );
  }
}

/// Routes a space typed on an on-screen keyboard to [onSpace] — the same
/// handler the panel's hardware Space shortcut ([_LoggingControlsState._handleSpace])
/// uses to rotate focus / run call-field command shortcuts.
///
/// A virtual keyboard sends a space as a text edit, not a key event, so the
/// panel's `SingleActivator(LogicalKeyboardKey.space)` never fires for it: the
/// space is instead inserted (State/Grid, which allow it) or silently stripped
/// by a field's character filter (Call/Sent/Rcvd/Freq). Either way Space
/// couldn't rotate focus on mobile. This formatter, placed first, drops a lone
/// inserted space and invokes the shared handler after the edit resolves.
///
/// On a hardware keyboard the shortcut consumes the key before it reaches text
/// input, so this never triggers there — the two paths don't double-fire.
class VirtualSpaceFormatter extends TextInputFormatter {
  final VoidCallback onSpace;

  /// When set, decides whether a given edit's space is ours to take. A field
  /// that accepts literal spaces passes this in so only the double-space that
  /// EXITS the field is intercepted; every other space is typed as normal.
  /// Absent means every lone space is ours — the plain callsign/RST/State/Grid
  /// case, where a space has no meaning other than "next field".
  final bool Function(TextEditingValue oldValue)? shouldIntercept;

  /// Called instead of [onSpace] when iOS's "." shortcut is recognized, with
  /// the text as it stood BEFORE the whole gesture (the value minus its
  /// trailing space). The exit can't be expressed as "strip what's there now":
  /// by the time this runs iOS's second edit has already re-added the space
  /// after the period, so the only reliable target is the text we saw going in.
  final void Function(String baseText)? onPeriodShortcut;

  const VirtualSpaceFormatter(this.onSpace, {this.shouldIntercept, this.onPeriodShortcut});

  /// iOS's "." shortcut, which fires exactly where our exit gesture does: with
  /// a space already in the text, a second space-bar press is turned into a
  /// period. It never arrives as a space insertion, so the check below can't
  /// see it and a period lands in the field instead.
  ///
  /// It arrives as TWO edits, and this matches the first: the trailing space is
  /// REPLACED BY A PERIOD, same length, caret still at the end — the space that
  /// iOS then re-adds is a separate edit. Both were traced landing in the SAME
  /// event-loop turn, which the exit depends on: [onPeriodShortcut] runs on a
  /// microtask, so it sees the finished text and restores the pre-gesture value
  /// over it. Were iOS ever to send the second edit a turn later, it would
  /// arrive after the restore and put the period back — the symptom to look for
  /// if this regresses on a future iOS is "focus moves but '.' is left behind".
  /// Traced on an iPhone 17 Pro simulator, iOS 26.5:
  ///
  ///     old="NOTE HI " sel=8,8  ->  new="NOTE HI."  sel=8,8   <- this
  ///     old="NOTE HI." sel=8,8  ->  new="NOTE HI. " sel=9,9
  ///
  /// Only reachable in a space-accepting field: everywhere else the first space
  /// is consumed before it enters the text, leaving iOS nothing to convert.
  /// A human can't produce this edit — typing "." with the caret at the end of
  /// "NOTE HI " gives "NOTE HI ." (longer, space intact), never "NOTE HI." — so
  /// matching it can't swallow a period somebody meant. The cost is that the
  /// shortcut is unavailable in these fields: to get a period, type one.
  ///
  /// The traits are NOT the lever here, tempting as it looks: this was traced
  /// with `autocorrect: false` live on the field and the shortcut still fired.
  /// It follows the system-wide "." Shortcut setting, which an app cannot turn
  /// off — recognizing the edit is the only option.
  static bool _isIOSPeriodShortcut(TextEditingValue oldValue, TextEditingValue newValue) {
    // iOS only. The shape is generic enough that an Android IME doing its own
    // smart punctuation could produce it, and there a deliberately typed "."
    // would be swallowed as the exit gesture — a silent edit to the operator's
    // text. Android's own double-space-period is a Gboard setting nobody has
    // traced here, so it stays out until someone does.
    if (!isIOSPlatform) return false;
    if (!oldValue.text.endsWith(' ')) return false;
    final replaced = '${oldValue.text.substring(0, oldValue.text.length - 1)}.';
    return newValue.text == replaced && newValue.selection.end == replaced.length;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // The exit gesture, arriving disguised as punctuation. Gated on the same
    // predicate as a real space, so it stays confined to the fields that opted
    // into space-accepting behavior.
    if (shouldIntercept != null && onPeriodShortcut != null && _isIOSPeriodShortcut(oldValue, newValue) && shouldIntercept!(oldValue)) {
      // The text as it was before the gesture — see [onPeriodShortcut]. Both of
      // iOS's edits are applied synchronously before any microtask runs, so a
      // handler that looked at the controller instead would find "NOTE HI. "
      // and strip only the space, leaving the period behind.
      final base = oldValue.text.substring(0, oldValue.text.length - 1);
      scheduleMicrotask(() => onPeriodShortcut!(base));
      return oldValue;
    }
    // Only a genuine single-space insertion at the cursor — not a paste that
    // merely contains a space, and not a selection replacement.
    if (newValue.text.length == oldValue.text.length + 1) {
      final caret = newValue.selection.end;
      if (caret > 0 &&
          caret <= newValue.text.length &&
          newValue.text[caret - 1] == ' ' &&
          newValue.text.substring(0, caret - 1) + newValue.text.substring(caret) == oldValue.text &&
          (shouldIntercept?.call(oldValue) ?? true)) {
        // Deferred: mutating focus or a controller synchronously from inside a
        // formatter (mid-text-input) is unsafe. The microtask runs right after
        // this edit applies and before the next frame.
        scheduleMicrotask(onSpace);
        return oldValue;
      }
    }
    return newValue;
  }
}
