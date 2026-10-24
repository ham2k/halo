// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

// Which characters this app writes and reads ordinary numbers with — the
// device's own conventions, resolved once and readable from every package.
// Frequencies are the exception: they are always written with periods
// (`frequencyMark`), and nothing here touches them.
//
// A singleton for the same reason AppClock is one: every surface must agree.
// A number FORMATTED with one decimal separator and PARSED with another does
// not round-trip, and the field that shows it is the same field the operator
// edits — so a disagreement between two call sites is not a cosmetic bug, it
// is a value that changes when you look at it.
//
// This package is pure Dart: no Flutter, no `intl`, so it cannot read the
// device locale or consult ICU. That resolution belongs to the app, which
// pushes the answer here at startup.

/// The separators in force, app-wide.
class NumberFormatting {
  NumberFormatting._();

  static final NumberFormatting instance = NumberFormatting._();

  /// Between the whole part and the fraction. Never the same character as
  /// [groupingSeparator] — see [configure].
  String get decimalSeparator => _decimal;
  String _decimal = '.';

  /// Between thousands. Whatever the resolved conventions use, which on a
  /// number of locales (fr, ru, sv, pl) is a narrow no-break space rather
  /// than a visible mark — so a reader must not assume it is a comma or a
  /// period, and must not assume the operator can type it.
  ///
  /// Empty only if something configures it so; [configure] never produces
  /// that on its own, and rejects a pair that would collide.
  String get groupingSeparator => _grouping;
  String _grouping = ',';

  /// A BCP-47 tag naming the conventions [decimalSeparator] and
  /// [groupingSeparator] came from, for the callers that format through
  /// `intl` rather than by hand — grouping is not always every three digits
  /// (hi-IN writes `12,34,567`), and only ICU knows where the breaks go.
  String get formattingLocale => _locale;
  String _locale = 'en_US';

  /// Sets the resolved conventions. Returns false, changing nothing, for a
  /// pair this cannot use. The app calls this; nothing else should.
  ///
  /// [decimal] and [grouping] must differ, and [decimal] must not be empty.
  /// Both are REJECTED at runtime rather than asserted, because an assert is
  /// stripped from release and the values come from locale data read at
  /// launch — so the one build where a bad pair could arrive is the one with
  /// no check at all. What gets through is not merely untidy:
  ///
  /// - an empty decimal makes [parseLocalizedNumber]'s `replaceAll('', …)`
  ///   shred the digits it was given;
  /// - identical separators strip the decimal along with the grouping, so
  ///   `1.5` reads as 15.
  ///
  /// Keeping the previous conventions is the safe failure: US defaults are
  /// wrong for some operators, but a number field that has stopped reading
  /// input correctly is wrong for all of them.
  bool configure({required String decimal, required String grouping, required String locale}) {
    if (decimal.isEmpty || decimal == grouping) return false;
    _decimal = decimal;
    _grouping = grouping;
    _locale = locale;
    return true;
  }

  /// Back to the built-in default — `1,234.5`, US conventions.
  ///
  /// For tests: this is process-wide state, so a test that configures it
  /// leaks into whatever runs next in the same isolate. Call it in a
  /// tearDown, the way an AppClock test resets travel.
  void reset() {
    _decimal = '.';
    _grouping = ',';
    _locale = 'en_US';
  }
}

/// Reads [text] as a number written in the operator's own conventions.
///
/// Null for anything that isn't one, including an empty string — the caller
/// decides whether that means "blank" or "wrong", because those differ by
/// field and this cannot tell them apart.
///
/// Grouping separators are REMOVED before parsing rather than validated:
/// where they may legally fall varies by locale, and a form field is not the
/// place to fail someone for grouping `14285` as `14,285` in a locale that
/// would have written `14285`.
num? parseLocalizedNumber(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final formats = NumberFormatting.instance;
  var cleaned = trimmed;
  if (formats.groupingSeparator.isNotEmpty) {
    cleaned = cleaned.replaceAll(formats.groupingSeparator, '');
  }
  // Non-breaking and thin spaces, which several locales group with and which
  // a keyboard may produce as an ordinary space. Removed unconditionally: no
  // number contains a space for any other reason.
  cleaned = cleaned.replaceAll(RegExp(r'[\s  ]'), '');
  if (formats.decimalSeparator != '.') {
    // Only AFTER grouping is gone, or a period-grouped `14.285` would turn
    // into `14285.` on the way past.
    cleaned = cleaned.replaceAll(formats.decimalSeparator, '.');
  }
  return num.tryParse(cleaned);
}

/// Writes [value] in the operator's own conventions, without grouping.
///
/// The inverse of [parseLocalizedNumber], and the pair is what makes an
/// editable field safe: what it shows is what it will read back. Grouping is
/// left out precisely because this feeds fields — a value that displays as
/// `14,285` and re-parses to `14285` is fine, but one the operator then edits
/// mid-group is not.
String formatLocalizedNumber(num value) {
  final text = value is int || value == value.roundToDouble() && value.abs() < 1e15 ? value.toInt().toString() : value.toString();
  final decimal = NumberFormatting.instance.decimalSeparator;
  return decimal == '.' ? text : text.replaceAll('.', decimal);
}
