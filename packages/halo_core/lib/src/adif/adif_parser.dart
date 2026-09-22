// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A tolerant ADIF tokenizer. ADIF is length-prefixed rather than delimited,
// which makes it trivial to parse when it is well-formed and unrecoverable
// when it is not — a single malformed tag would otherwise desynchronize every
// byte after it. Real logger output is not well-formed often enough that
// recovery is the point of this file, not a nicety: see the recovery rules on
// [parseAdifBytes].
//
// **A declared length counts BYTES, not characters.** That is the ADIF spec,
// and it is why this scans a byte list rather than a Dart string: a `String`
// index is a UTF-16 code unit, so `<NAME:5>José` would consume one unit too
// many, and the overrun would swallow the `<` of the following tag — merging
// two records into one and losing a contact outright, with nothing to show
// for it. Files arrive as bytes anyway; decoding up front was never the right
// shape.
//
// Byte-index scanning also avoids regular expressions. A regex applied
// repeatedly to the tail of a 400KB log re-scans that tail on every match, and
// an alternation over unbounded runs backtracks catastrophically on exactly
// the malformed input this parser exists to survive.

import 'dart:convert';

const int _lt = 0x3c; // <
const int _gt = 0x3e; // >
const int _colon = 0x3a;
const int _tab = 0x09;
const int _lf = 0x0a;
const int _cr = 0x0d;
const int _space = 0x20;

/// Which end marker closed a segment: `<EOH>` opens a file's header, `<EOR>`
/// closes one contact.
enum AdifSegmentType { header, record }

/// Why a field's declared length looks wrong. Carried rather than corrected:
/// the tokenizer stays literal about what the file said, and the layer above
/// turns this into something the operator can read.
enum AdifFieldAnomaly {
  /// The declared length ran past the end of the file — truncated mid-write.
  truncated,

  /// **Recovered.** Reading the length as bytes stopped short of the end of
  /// the value, and reading it as UTF-16 code units landed exactly where a
  /// value should end. The writer counted characters where ADIF specifies
  /// bytes — HamRS does this, and it is what any JavaScript logger gets by
  /// reaching for `String.length`. [AdifField.value] is the recovered value,
  /// so the data is right; this records that the file is non-conformant.
  characterCount,

  /// **Not recovered.** The value did not end at a separator or the next `<`,
  /// and re-reading the length as characters did not help either — so the
  /// reading has almost certainly run into the following tag and this field's
  /// value, plus possibly the rest of the record, is wrong.
  unterminated,
}

/// One `<NAME:LENGTH:TYPE>value` tag.
class AdifField {
  /// As written in the file — case is not normalized here, since a caller
  /// mapping onto its own model has to lowercase anyway and a caller
  /// round-tripping the file needs the original.
  final String name;

  /// The length the tag *declared*, in bytes, which is not necessarily
  /// [value]'s length: see [anomaly].
  final int length;

  /// The optional ADIF data-type indicator (`<NAME:6:D>`). Rarely present.
  final String? type;

  /// Decoded UTF-8. Malformed bytes become replacement characters rather than
  /// costing the whole file — a log with one bad byte is still a log.
  final String value;

  /// Whatever sat between this field's value and the next `<`. Almost always
  /// whitespace; a declared length that was too short leaves the value's real
  /// tail here instead.
  final String extraData;

  /// Null when the declared length landed cleanly.
  final AdifFieldAnomaly? anomaly;

  const AdifField({required this.name, required this.length, required this.value, this.type, this.extraData = '', this.anomaly});
}

/// Everything between one end marker and the next.
class AdifSegment {
  final AdifSegmentType type;

  /// Text before the segment's first tag. ADIF puts a free-text comment at the
  /// top of the file, ahead of the header's tags.
  final String preamble;
  final List<AdifField> fields;

  /// The marker text as written (`EOH`/`EOR`), or empty for a final segment
  /// that the file ended without closing.
  final String endMarker;

  const AdifSegment({required this.type, required this.preamble, required this.fields, required this.endMarker});
}

/// Splits ADIF text into header and record segments.
///
/// Convenience wrapper over [parseAdifBytes] for tests and small inputs. A
/// caller holding a file should pass its bytes instead: this re-encodes, and
/// a string that was itself decoded leniently has already lost the byte
/// lengths the format is built on.
Iterable<AdifSegment> parseAdifSegments(String text) => parseAdifBytes(utf8.encode(text));

/// Splits ADIF bytes into header and record segments.
///
/// A `sync*` generator so a caller can process a large log a record at a time.
///
/// Recovery rules, each earned from a real file that crashed a stricter
/// parser:
///
/// - **A tag missing its closing `>`** (`<QSO_DATE_OFF:8` then a newline) is
///   still read as a tag, skipping one separator byte so the value does not
///   start with the newline that stood in for the bracket.
/// - **`<PROGRAMID>` and `<PROGRAMVERSION>` without a length** — some loggers
///   write these two as bare tags. The value runs to the end of the line or to
///   the next `<`, whichever comes first. Deliberately not generalized to
///   every name: a length-less tag is ambiguous, and guessing wrong on a QSO
///   field silently corrupts data rather than losing a header.
/// - **A `<` that begins neither** is a literal character, kept in the
///   surrounding text.
/// - **Fields left open at end of file** are yielded as a final record, so a
///   log truncated mid-write still imports everything before the cut.
///
/// A length that does not land cleanly is recorded on the field as an
/// [AdifFieldAnomaly] rather than silently accepted — recovery and corruption
/// are indistinguishable from the outside unless the parser says which it did.
Iterable<AdifSegment> parseAdifBytes(List<int> bytes) sync* {
  final len = bytes.length;
  var index = 0;

  var preamble = <int>[];
  var fields = <AdifField>[];
  // Accumulated separately from [fields] because a field is immutable once
  // built, and its trailing text is only known when the next `<` arrives.
  var trailing = <int>[];

  /// Bytes before the next tag belong to the last field if there is one, and
  /// to the segment's preamble otherwise.
  void absorb(int from, int to) {
    if (to <= from) return;
    (fields.isEmpty ? preamble : trailing).addAll(bytes.getRange(from, to));
  }

  AdifField withTrailing(AdifField field) =>
      AdifField(name: field.name, length: field.length, type: field.type, value: field.value, anomaly: field.anomaly, extraData: _decode(trailing));

  void addField(AdifField field) {
    if (fields.isNotEmpty) fields.add(withTrailing(fields.removeLast()));
    trailing = <int>[];
    fields.add(field);
  }

  /// Flushes the pending trailing text onto the last field, so a segment's
  /// final field carries its own `extraData` like every other one.
  List<AdifField> sealFields() {
    if (fields.isEmpty) return const [];
    fields.add(withTrailing(fields.removeLast()));
    return fields;
  }

  while (index < len) {
    var open = index;
    while (open < len && bytes[open] != _lt) {
      open++;
    }
    if (open >= len) {
      absorb(index, len);
      break;
    }
    absorb(index, open);
    index = open;

    final tag = _scanTag(bytes, open);
    if (tag == null) {
      absorb(open, open + 1);
      index = open + 1;
      continue;
    }

    if (tag.marker != null) {
      yield AdifSegment(
        type: tag.marker!.toUpperCase() == 'EOH' ? AdifSegmentType.header : AdifSegmentType.record,
        preamble: _decode(preamble),
        fields: sealFields(),
        endMarker: tag.marker!,
      );
      preamble = <int>[];
      fields = <AdifField>[];
      trailing = <int>[];
      index = tag.end;
      continue;
    }

    addField(tag.field!);
    index = tag.end;
  }

  final open = sealFields();
  if (open.isNotEmpty) {
    yield AdifSegment(type: AdifSegmentType.record, preamble: _decode(preamble), fields: open, endMarker: '');
  }
}

String _decode(List<int> bytes) => bytes.isEmpty ? '' : utf8.decode(bytes, allowMalformed: true);

/// What [_scanTag] found at a `<`: an end marker, a field, or neither.
class _Tag {
  final String? marker;
  final AdifField? field;

  /// Index just past everything this tag consumed, value included.
  final int end;

  const _Tag({this.marker, this.field, required this.end});
}

const _lengthlessTags = {'PROGRAMID', 'PROGRAMVERSION'};

bool _isTagNameByte(int c) =>
    (c >= 0x41 && c <= 0x5a) || // A-Z
    (c >= 0x61 && c <= 0x7a) || // a-z
    (c >= 0x30 && c <= 0x39) || // 0-9
    c == 0x5f; // _

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isSeparator(int c) => c == _space || c == _tab || c == _cr || c == _lf;

/// Reads one tag starting at [open], which must be a `<`. Returns null when
/// what follows is not a tag at all, leaving the caller to treat the `<` as a
/// literal.
_Tag? _scanTag(List<int> bytes, int open) {
  final len = bytes.length;
  var i = open + 1;

  final nameStart = i;
  while (i < len && _isTagNameByte(bytes[i])) {
    i++;
  }
  if (i == nameStart) return null;
  final name = _decode(bytes.sublist(nameStart, i));

  if (i < len && bytes[i] == _gt) {
    final upper = name.toUpperCase();
    if (upper == 'EOH' || upper == 'EOR') {
      return _Tag(marker: name, end: i + 1);
    }
    if (_lengthlessTags.contains(upper)) {
      return _scanLengthlessValue(bytes, name, i + 1);
    }
    return null;
  }

  if (i >= len || bytes[i] != _colon) return null;
  i++;

  final lengthStart = i;
  while (i < len && _isDigit(bytes[i])) {
    i++;
  }
  if (i == lengthStart) return null;
  // `tryParse`, not `parse`: a corrupt byte run in a length field is exactly
  // the malformed input this file exists to survive, and a digit string past
  // 2^63 throws. Anything that long is nonsense anyway — no ADIF value is
  // gigabytes — so it reads as "runs past the end", which the truncation path
  // already handles.
  final declared = int.tryParse(_decode(bytes.sublist(lengthStart, i))) ?? len;

  String? type;
  if (i < len && bytes[i] == _colon) {
    final typeStart = i + 1;
    var j = typeStart;
    while (j < len && _isTagNameByte(bytes[j])) {
      j++;
    }
    if (j > typeStart) {
      type = _decode(bytes.sublist(typeStart, j));
      i = j;
    }
  }

  var valueStart = i;
  if (i < len && bytes[i] == _gt) {
    valueStart = i + 1;
  } else {
    // No closing bracket. Whatever byte stood where the `>` should have been
    // is the file's separator, not the first byte of the value — consume one,
    // and the CRLF pair as one.
    if (valueStart < len && _isSeparator(bytes[valueStart])) {
      final c = bytes[valueStart];
      valueStart++;
      if (c == _cr && valueStart < len && bytes[valueStart] == _lf) valueStart++;
    }
  }

  // A declared length running past EOF truncates rather than throwing: the
  // file was cut mid-write, and the bytes that did arrive are still a QSO.
  final wanted = valueStart + declared;
  var valueEnd = wanted < len ? wanted : len;

  AdifFieldAnomaly? anomaly;
  if (wanted > len) {
    anomaly = AdifFieldAnomaly.truncated;
  } else if (!_endsAtBoundary(bytes, valueEnd)) {
    // A value ends on whitespace or on the next tag, so stopping mid-text
    // means the byte count under-read. The overwhelming cause is a writer that
    // counted characters — try that reading, and take it only if IT lands
    // where a value may end. A speculative re-cut that also fails would
    // replace one wrong value with another and hide the damage.
    final asChars = _advanceCodeUnits(bytes, valueStart, declared);
    if (asChars < 0) {
      // The file ran out before the declared count of units. It is truncated
      // under BOTH readings — calling that a recovery would hand back a short
      // value dressed up as a correct one.
      anomaly = AdifFieldAnomaly.truncated;
    } else if (asChars != valueEnd && _endsAtBoundary(bytes, asChars)) {
      valueEnd = asChars;
      anomaly = AdifFieldAnomaly.characterCount;
    } else {
      // Neither reading found the end of the value, so the length is simply
      // wrong. Give the value back whatever it swallowed up to the last `<`:
      // an over-declared length that eats a `<EOR>` merges two contacts into
      // one segment, where the second's fields overwrite the first's and a
      // contact disappears from the log entirely.
      //
      // This is the one place the declared length does NOT win. A value may
      // legitimately contain `<` — but only when the length was right, and by
      // here it demonstrably was not.
      final lastOpen = _lastTagOpenIn(bytes, valueStart, valueEnd);
      if (lastOpen >= valueStart) valueEnd = lastOpen;
      anomaly = AdifFieldAnomaly.unterminated;
    }
  }

  return _Tag(
    field: AdifField(name: name, length: declared, type: type, value: _decode(bytes.sublist(valueStart, valueEnd)), anomaly: anomaly),
    end: valueEnd,
  );
}

/// Whether a value ending at [from] ends where an ADIF value may end: on
/// whitespace, on the next tag, or at end of file.
///
/// Deliberately looks at ONE byte rather than scanning ahead to the next `<`.
/// Whitespace after a value does not have to run all the way to the next tag —
/// LoTW writes a human-readable annotation there (`US,NY,ORANGE // New York`),
/// which is exactly what `extraData` exists to hold. Scanning ahead would read
/// every one of those as damage and flag a clean file end to end.
bool _endsAtBoundary(List<int> bytes, int from) => from >= bytes.length || _isSeparator(bytes[from]) || bytes[from] == _lt;

/// The last `<` in `[from, to)`, or -1. Used to hand back a tag opener that an
/// over-declared length swallowed, rather than losing the tag it began.
int _lastTagOpenIn(List<int> bytes, int from, int to) {
  for (var i = to - 1; i >= from; i--) {
    if (bytes[i] == _lt) return i;
  }
  return -1;
}

/// The byte offset [count] UTF-16 code units past [start], or **-1** if the
/// data ran out first.
///
/// The sentinel matters: clamping to the end instead would make the caller's
/// "does it land where a value may end?" test pass trivially at EOF, so a
/// file cut mid-write would be reported as a clean recovery.
///
/// Code *units*, not code points, because the writers that get this wrong are
/// reaching for a string length — JavaScript's `String.length`, or any
/// UTF-16-backed runtime — and that counts an astral character as two. For
/// everything in the BMP the two are identical, so this only differs on emoji.
int _advanceCodeUnits(List<int> bytes, int start, int count) {
  var i = start;
  var units = 0;
  while (i < bytes.length && units < count) {
    final b = bytes[i];
    if (b >= 0xf0) {
      i += 4;
      units += 2; // a surrogate pair in UTF-16
    } else if (b >= 0xe0) {
      i += 3;
      units += 1;
    } else if (b >= 0xc0) {
      i += 2;
      units += 1;
    } else {
      // ASCII, or a stray continuation byte we count as its own character
      // rather than desynchronizing on it.
      i += 1;
      units += 1;
    }
  }
  if (units < count || i > bytes.length) return -1;
  return i;
}

/// The value of a bare `<PROGRAMID>`-style tag: to end of line, or to the next
/// tag if one opens first.
_Tag _scanLengthlessValue(List<int> bytes, String name, int valueStart) {
  final len = bytes.length;
  var end = valueStart;
  while (end < len && bytes[end] != _lf && bytes[end] != _lt) {
    end++;
  }

  var stop = end;
  if (stop > valueStart && bytes[stop - 1] == _cr) stop--;

  final value = _decode(bytes.sublist(valueStart, stop));
  return _Tag(
    field: AdifField(name: name, length: value.length, value: value),
    end: end,
  );
}
