// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Parses N1MM Logger+'s UDP broadcast `<contactinfo>` datagram — sent once
// per QSO logged — into QSON. See "Listen for other apps".
//
// Only `<contactinfo>` is handled, N1MM's message for a NEWLY LOGGED QSO.
// `<contactreplace>` (an edited QSO) and a deleted contact are different
// message shapes and are deliberately not parsed here: an edit or delete
// made in N1MM after capture does not reach the log. Every other datagram
// N1MM broadcasts (`<RadioInfo>`, `<lookupinfo>`, `<dynamicresults>`, ...)
// is ignored the same way — [parseN1mmContactInfo] returns null for any
// root element that isn't `contactinfo`.
//
// A hand-rolled tag scan rather than a real XML parser: N1MM's fields are
// flat (no nesting, no attributes), so this is the same tradeoff
// `adif_parser.dart` makes for ADIF's own flat tags, and it avoids a new
// dependency for one message shape.

import '../ham/radio.dart';

/// One `<contactinfo>` datagram, decoded into QSON.
class N1mmContactInfo {
  /// QSON: `our`/`their`/`band`/`mode`/`freq`/`startAtMillis`/`notes`, same
  /// shape `Qso.data` uses.
  final Map<String, dynamic> qso;

  /// The station call N1MM sent as (`<mycall>`), before any station-call
  /// override is applied — the caller compares this against the operation's
  /// own station call to decide whether to warn (see `qsoForStation`,
  /// `foreignStationCalls` in `qso_merge.dart`, the same mechanism ADIF
  /// import uses).
  final String myCall;

  const N1mmContactInfo({required this.qso, required this.myCall});
}

/// Parses a UDP datagram's text as N1MM's `<contactinfo>` message. Returns
/// null for any other message N1MM broadcasts, for malformed XML, or for a
/// record with no callsign or no usable timestamp — nothing capturable
/// either way.
N1mmContactInfo? parseN1mmContactInfo(String datagram) {
  // N1MM prefixes every datagram with an XML declaration
  // (`<?xml version="1.0" encoding="utf-8"?>`) ahead of the root element —
  // confirmed against a live capture, not just the remembered spec.
  final withoutDeclaration = datagram.trim().replaceFirst(RegExp(r'^<\?xml[^>]*\?>\s*'), '');
  final root = RegExp(r'^\s*<([a-zA-Z][\w:-]*)>(.*)</\1>\s*$', dotAll: true).firstMatch(withoutDeclaration);
  if (root == null || root.group(1)!.toLowerCase() != 'contactinfo') return null;

  final f = _fields(root.group(2)!);
  final call = _present(f['call']);
  final startAtMillis = _timestamp(f['timestamp']);
  if (call == null || startAtMillis == null) return null;

  final myCall = _present(f['mycall']) ?? '';

  final our = <String, dynamic>{if (myCall.isNotEmpty) 'call': myCall};
  _put(our, 'operator', _present(f['operator']));
  _put(our, 'sent', _present(f['snt']));
  _put(our, 'grid', _present(f['gridsquare']));

  final their = <String, dynamic>{'call': call};
  _put(their, 'sent', _present(f['rcv']));
  _put(their, 'name', _present(f['name']));

  final qso = <String, dynamic>{'our': our, 'their': their, 'startAtMillis': startAtMillis};

  final mode = _present(f['mode']);
  if (mode != null) qso['mode'] = mode;

  // `txfreq`/`rxfreq` are the authoritative source for band — confirmed
  // against a live capture: N1MM sends them in tens of Hz (a 14.200MHz QSO
  // arrives as "1420000"), not kHz as first assumed. `band` is a fallback,
  // read as a Cabrillo-style band code (nominal MHz, e.g. "14" for 20m,
  // "1.8" for 160m — also confirmed live) rather than meters.
  final freq = _freqKHz(f['txfreq'] ?? f['rxfreq']);
  if (freq != null) qso['freq'] = freq;
  final band = (freq == null ? null : bandForFrequency(freq)) ?? _bandFromN1mmCode(f['band']);
  if (band != null) qso['band'] = band;

  final notes = _notesFor(f);
  if (notes != null) qso['notes'] = notes;

  return N1mmContactInfo(qso: qso, myCall: myCall);
}

/// The dedupe key for a capture: same station worked on the same band/mode
/// at the same second is the same QSO, even if N1MM (or a second listener
/// sharing the port) broadcasts it twice.
String n1mmDedupeKey(N1mmContactInfo info) {
  final their = info.qso['their'] as Map<String, dynamic>;
  return [info.myCall, their['call'], info.qso['band'], info.qso['mode'], info.qso['startAtMillis']].join('|');
}

/// The operator's free-text `<comment>`, plus N1MM's contest-specific
/// fields joined below it. QSON's core mapping has no per-field home for a
/// contest exchange — extensions own that vocabulary (see
/// `adif_to_qson.dart`'s header comment), and there is no `adifImport`-style
/// hook a live UDP capture can call into. Preserved as text rather than
/// dropped.
String? _notesFor(Map<String, String> f) {
  final parts = <String>[];
  final comment = _present(f['comment']);
  if (comment != null) parts.add(comment);

  final exchangeParts = <String>[];
  void add(String label, String key) {
    final v = _present(f[key]);
    if (v != null) exchangeParts.add('$label: $v');
  }

  add('Contest', 'contestname');
  add('Exch', 'exchange1');
  add('Section', 'section');
  add('Sent#', 'sntnr');
  add('Rcvd#', 'rcvnr');
  if (exchangeParts.isNotEmpty) parts.add('N1MM exchange — ${exchangeParts.join(', ')}');

  return parts.isEmpty ? null : parts.join('\n');
}

/// N1MM's `band` field is a Cabrillo-style band code — the band's nominal
/// frequency in MHz (`"14"` for 20m, `"1.8"` for 160m, `"144"` for 2m),
/// confirmed against a live capture. NOT meters, despite the name.
String? _bandFromN1mmCode(String? code) {
  final c = _present(code);
  if (c == null) return null;
  final mhz = double.tryParse(c);
  if (mhz == null || !mhz.isFinite || mhz <= 0) return null;
  return bandForFrequency(mhz * 1000);
}

/// N1MM's `txfreq`/`rxfreq` are in tens of Hz, confirmed against a live
/// capture (`"1420000"` for 14.200MHz) — not kHz as the field's own name
/// suggests.
double? _freqKHz(String? value) {
  final v = _present(value);
  if (v == null) return null;
  final deciHz = double.tryParse(v);
  if (deciHz == null || !deciHz.isFinite || deciHz <= 0) return null;
  return deciHz / 100;
}

/// `yyyy-MM-dd HH:mm:ss`, always UTC — N1MM's own broadcast format.
int? _timestamp(String? value) {
  final v = _present(value);
  if (v == null) return null;
  return DateTime.tryParse('${v.replaceFirst(' ', 'T')}Z')?.millisecondsSinceEpoch;
}

String? _present(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();

void _put(Map<String, dynamic> dest, String key, String? value) {
  if (value != null) dest[key] = value;
}

/// Every `<tag>value</tag>` pair in [inner], names lowercased, entities
/// decoded. Only ever called on the content BETWEEN the root element's own
/// tags — N1MM's fields don't nest, so this is a flat scan, not a real
/// parse.
final _fieldPattern = RegExp(r'<([a-zA-Z][\w:-]*)>(.*?)</\1>', dotAll: true);

Map<String, String> _fields(String inner) {
  final fields = <String, String>{};
  for (final match in _fieldPattern.allMatches(inner)) {
    fields[match.group(1)!.toLowerCase()] = _decodeEntities(match.group(2)!.trim());
  }
  return fields;
}

const _namedEntities = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'"};
final _entityPattern = RegExp(r'&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);');

String _decodeEntities(String value) {
  if (!value.contains('&')) return value;
  return value.replaceAllMapped(_entityPattern, (match) {
    final body = match[1]!;
    if (body.startsWith('#')) {
      final isHex = body[1] == 'x' || body[1] == 'X';
      final code = int.tryParse(isHex ? body.substring(2) : body.substring(1), radix: isHex ? 16 : 10);
      if (code == null || code < 0 || code > 0x10ffff) return match[0]!;
      return String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? match[0]!;
  });
}
