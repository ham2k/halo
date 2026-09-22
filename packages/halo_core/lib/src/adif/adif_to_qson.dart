// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ADIF field maps onto QSON, the shape `Qso.data` already holds.
//
// This layer maps **universal ADIF only** — the fields every logger writes and
// every logger means the same thing by. Program-specific references
// (`SIG`/`SIG_INFO`, `SOTA`, `IOTA`, `CONTEST_ID`, `*_REF`) are deliberately
// NOT mapped here: extensions own every ref on import, the mirror image of the
// `adifFields` hook owning every program field on export. A core that guessed
// at them would have to be un-guessed by the extension that actually knows the
// program, and would put HaLo's ref vocabulary in two places at once.
//
// [AdifRecord.fields] therefore survives on every record — it is the input the
// `adifImport` hook pass reads to produce those refs.
//
// **Nothing here throws, so nothing here may rely on catching.** Every
// conversion is a `tryParse`. What separates a good record from a bad one is
// [_viabilityOf], an explicit predicate — not an exception that would never be
// raised. A parser whose error list cannot fill is worse than one with no
// error list, because "no errors" reads as a clean import.

import 'dart:convert';

import '../ham/radio.dart';
import 'adif_parser.dart';

/// Why a record could not be accepted as a contact.
enum AdifRecordProblem {
  /// No callsign for the station worked. Whatever this record is, it is not a
  /// QSO — an empty `<EOR>`, a stray header, a truncated write.
  noCallsign,

  /// No usable date/time. Importable — app-polo's own logs can carry undated
  /// contacts — but the QSO cannot be placed in the timeline, deduped against
  /// an existing log, or scored for a contest, so the operator has to be told.
  noTimestamp,

  /// At least one field's declared length could not be made to land cleanly
  /// ([AdifFieldAnomaly.unterminated] or [AdifFieldAnomaly.truncated]). The
  /// values on this record may be cut short or may have run into the next tag.
  ///
  /// A length recovered as a character count ([AdifFieldAnomaly.characterCount])
  /// deliberately does NOT raise this: the value came out right, and warning
  /// about it would train the operator to ignore the channel.
  suspectFieldLength,
}

/// One parsed record: what the file said, what it means, and what is wrong
/// with it.
class AdifRecord {
  /// 1-based position among the file's record segments. QSOs are handed back
  /// in time order, so this is the only way back to where a record actually
  /// sat — which is what an operator needs to fix the one line that failed.
  /// Counts every record segment, including ones carrying no fields, or it
  /// would not be a position in the file.
  final int number;

  /// Every ADIF field on the record, names lowercased, values entity-decoded
  /// and stripped of the trailing whitespace an over-declared length drags in.
  /// Kept whole: it is the `adifImport` hook's input, and it is what lets a
  /// later decision about `APP_HAM2K_*` compatibility be made without
  /// re-parsing the file.
  final Map<String, String> fields;

  /// QSON. Populated even for a rejected record — the operator fixing a log
  /// wants to see what was read, and a caller may still want to show it.
  final Map<String, dynamic> qso;

  /// Empty for a clean record. A record with [AdifRecordProblem.noCallsign] is
  /// in [AdifLog.errors]; anything else lands in [AdifLog.warnings] and is
  /// imported.
  final List<AdifRecordProblem> problems;

  const AdifRecord({required this.number, required this.fields, required this.qso, this.problems = const []});
}

/// A parsed ADIF file.
class AdifLog {
  /// Header fields, names lowercased. `programid` identifies the writing
  /// logger and is the only header this layer acts on — see [_genericQslFor].
  final Map<String, String> headers;

  /// Records accepted as contacts, in time order; records sharing a timestamp
  /// keep their file order. May include records that also appear in
  /// [warnings].
  final List<AdifRecord> qsos;

  /// Records that are not contacts and were NOT imported, in file order.
  final List<AdifRecord> errors;

  /// Imported records with something the operator should be told about, in
  /// file order. These are the same objects that appear in [qsos].
  final List<AdifRecord> warnings;

  const AdifLog({required this.headers, required this.qsos, required this.errors, required this.warnings});
}

/// Parses ADIF text into QSON. Convenience wrapper over [parseAdifLogBytes];
/// a caller holding a file should pass its bytes, since ADIF lengths count
/// bytes and a decoded string has already lost them.
AdifLog parseAdifLog(String text) => parseAdifLogBytes(utf8.encode(text));

/// How many records [bytes] holds — the count [parseAdifLogBytes] would
/// convert, without building a single QSON map.
///
/// Tokenized rather than a scan for `<EOR>`: a field VALUE may contain that
/// text, and only the declared lengths say where values end. Empty records are
/// not counted, the same as the conversion skips them.
///
/// With [upTo], stops as soon as the count reaches it. A limit check only
/// needs to know the file is past the limit, and tokenizing the rest of a
/// whole-log file to learn by how much freezes the UI for it.
int countAdifRecords(List<int> bytes, {int? upTo}) {
  var count = 0;
  for (final segment in parseAdifBytes(bytes)) {
    if (segment.type == AdifSegmentType.record && segment.fields.isNotEmpty) count++;
    if (upTo != null && count >= upTo) break;
  }
  return count;
}

/// Parses ADIF bytes into QSON.
///
/// Never throws on malformed input: the tokenizer recovers what it can (see
/// [parseAdifBytes]) and a record this layer cannot accept lands in
/// [AdifLog.errors] with a reason.
AdifLog parseAdifLogBytes(List<int> bytes) {
  final headers = <String, String>{};
  final qsos = <AdifRecord>[];
  final errors = <AdifRecord>[];
  final warnings = <AdifRecord>[];
  var count = 0;
  bool? genericQsl;

  for (final segment in parseAdifBytes(bytes)) {
    if (segment.type == AdifSegmentType.header) {
      for (final field in segment.fields) {
        headers[field.name.toLowerCase()] = _clean(field.value);
      }
      continue;
    }

    // Counted before the empty-segment skip: [AdifRecord.number] is a position
    // in the file, and an empty `<EOR>` occupies one.
    count++;
    if (segment.fields.isEmpty) continue;

    final fields = <String, String>{};
    var suspect = false;
    for (final field in segment.fields) {
      fields[field.name.toLowerCase()] = _clean(field.value);
      if (field.anomaly != null && field.anomaly != AdifFieldAnomaly.characterCount) suspect = true;
    }

    // A file with no `<EOH>` produces no header segment at all, so `headers`
    // is still empty here and the writing program can only be identified from
    // the record's own fields. Without this fallback a LoTW download missing
    // its `<EOH>` gets paper QSLs invented for every contact — the exact
    // failure `_genericQslFor` exists to prevent.
    genericQsl ??= _genericQslFor(headers.isNotEmpty ? headers : fields);

    final qso = _qsoFrom(fields, genericQsl);
    final problems = _viabilityOf(qso, suspect: suspect);
    final record = AdifRecord(number: count, fields: fields, qso: qso, problems: problems);

    if (problems.contains(AdifRecordProblem.noCallsign)) {
      errors.add(record);
      continue;
    }
    qsos.add(record);
    if (problems.isNotEmpty) warnings.add(record);
  }

  qsos.sort((a, b) {
    final at = (a.qso['startAtMillis'] as int?) ?? 0;
    final bt = (b.qso['startAtMillis'] as int?) ?? 0;
    return at != bt ? at.compareTo(bt) : a.number.compareTo(b.number);
  });

  return AdifLog(headers: headers, qsos: qsos, errors: errors, warnings: warnings);
}

/// What is wrong with a mapped record, if anything.
///
/// This is the whole quality gate. It replaces nothing — there was never an
/// exception to catch — and it is why [AdifLog.errors] can actually fill.
List<AdifRecordProblem> _viabilityOf(Map<String, dynamic> qso, {required bool suspect}) {
  final problems = <AdifRecordProblem>[];
  final their = qso['their'] as Map<String, dynamic>;
  if ((their['call'] as String?)?.isNotEmpty != true) problems.add(AdifRecordProblem.noCallsign);
  if (qso['startAtMillis'] == null) problems.add(AdifRecordProblem.noTimestamp);
  if (suspect) problems.add(AdifRecordProblem.suspectFieldLength);
  return problems;
}

/// Whether the plain `QSL_RCVD`/`QSLRDATE` fields describe a paper QSL.
///
/// In a LoTW download they do not — LoTW writes its own confirmation into the
/// generic fields, so honouring them would invent a paper card the operator
/// never received. Trimmed and case-folded because a logger that over-declares
/// `<PROGRAMID:5>LoTW` by one byte drags the newline into the value, and an
/// exact comparison would then silently take the wrong branch.
bool _genericQslFor(Map<String, String> source) => source['programid']?.trim().toUpperCase() != 'LOTW';

Map<String, dynamic> _qsoFrom(Map<String, String> f, bool genericQsl) {
  final our = <String, dynamic>{};
  final their = <String, dynamic>{};
  final qso = <String, dynamic>{'our': our, 'their': their};

  // A callsign portable-suffixed with `_` instead of `/` — some loggers avoid
  // the slash for filename safety, and the underscore is not part of any call.
  String call(String x) => x.replaceAll('_', '/');

  _set(f, their, 'call', 'call', call);
  _set(f, their, 'contacted_op', 'operator', call);
  _set(f, their, 'eq_call', 'owner', call);

  _set(f, our, 'operator', 'operatorCall', call);
  _set(f, our, 'owner_callsign', 'owner', call);
  // `STATION_CALLSIGN` is the call actually transmitted and `OPERATOR` the
  // person at the key; when both are present the station call is ours. Written
  // in that order so the later assignment wins.
  _set(f, our, 'operator', 'call', call);
  _set(f, our, 'station_callsign', 'call', call);
  // ADIF names no field for a multi-station operating position, so our own
  // export writes one and this reads it back. Only ours: another logger's
  // position rides its own `APP_<PROGRAM>_` field, which means something
  // different at every station that wrote it.
  _set(f, our, 'app_ham2k_position', 'multiIdentifier');

  final freq = _parseFreqKHz(_present(f['freq']));
  if (freq != null) qso['freq'] = freq;

  final band = _present(f['band'])?.toLowerCase();
  if (band != null) {
    qso['band'] = band;
  } else if (freq != null) {
    final derived = bandForFrequency(freq);
    if (derived != null) qso['band'] = derived;
  }

  // Split operation: only worth recording when the two frequencies differ.
  final freqRx = _parseFreqKHz(_present(f['freq_rx']));
  if (freqRx != null && freqRx != freq) {
    their['freq'] = freqRx;
    final rxBand = _present(f['band_rx'])?.toLowerCase() ?? bandForFrequency(freqRx);
    if (rxBand != null) their['band'] = rxBand;
  }

  // The submode is what the operator worked — `MODE=MFSK, SUBMODE=FT4` is an
  // FT4 QSO, and collapsing it to MFSK loses the distinction the log is for.
  // `_present` rather than `??`: loggers write `<SUBMODE:0>`, and `??` only
  // skips null, so an empty submode would erase the mode entirely — and the
  // ADIF exporter defaults a mode-less QSO to SSB, so the contact would come
  // back out as SSB.
  final mode = _present(f['submode']) ?? _present(f['mode']);
  if (mode != null) qso['mode'] = mode;

  _setTimes(f, qso);

  _set(f, their, 'name', 'name');
  _set(f, their, 'cont', 'continent');
  _set(f, their, 'country', 'entityName');
  _set(f, their, 'country', 'country');
  // ADIF's field for the contacted station's city is `QTH`, not `CITY` — the
  // spec is asymmetric here, pairing `QTH` with `MY_CITY` for our own side. So
  // `QTH` lands in `city`, which is the key the app reads and the key the
  // exporter writes `QTH` back out of; a QSON `their.qth` is read by nothing.
  //
  // `CITY` is not an ADIF field at all, but software invents it. Where a record
  // carries both spellings the LATER `_set` wins, and these are ordered so that
  // the winner is the one naming a city and nothing else — `QTH` is routinely
  // filled with a region or a country.
  _set(f, their, 'qth', 'city');
  _set(f, their, 'city', 'city');
  _set(f, their, 'state', 'state');
  _set(f, their, 'region', 'regionCode');
  // QSON `sent` is what this side SENT, so the report we received is theirs.
  _set(f, their, 'rst_rcvd', 'sent');
  _set(f, their, 'cnty', 'county', (x) => _county(their['country'] as String?, x));
  _set(f, their, 'cqz', 'cqZone', int.tryParse);
  _set(f, their, 'cq_zone', 'cqZone', int.tryParse);
  _set(f, their, 'ituz', 'ituZone', int.tryParse);
  _set(f, their, 'itu_zone', 'ituZone', int.tryParse);
  _set(f, their, 'dxcc', 'dxccCode', int.tryParse);
  _set(f, their, 'email', 'email');
  _set(f, their, 'gridsquare', 'grid');
  _set(f, their, 'lat', 'lat', (x) => parseAdifCoordinate(x, latitude: true));
  _set(f, their, 'lon', 'lon', (x) => parseAdifCoordinate(x, latitude: false));
  _set(f, their, 'pfx', 'entityPrefix');

  _set(f, our, 'my_name', 'name');
  _set(f, our, 'my_cont', 'continent');
  _set(f, our, 'my_country', 'entityName');
  _set(f, our, 'my_country', 'country');
  // Our side, where ADIF swaps which spelling is the real one: `MY_CITY` is the
  // field, `MY_QTH` is what software writes by analogy with `QTH`. Same
  // last-wins mechanic as above, ordered so the ADIF field is the winner.
  //
  // Nothing reads `our.city` today and the exporter writes no `MY_*` at all, so
  // unlike the `their` side this fixes no live loss — it keeps one key for one
  // concept, rather than a second dead `our.qth` beside a dead `our.city`.
  _set(f, our, 'my_qth', 'city');
  _set(f, our, 'my_city', 'city');
  _set(f, our, 'my_state', 'state');
  _set(f, our, 'my_region', 'regionCode');
  _set(f, our, 'rst_sent', 'sent');
  _set(f, our, 'my_cnty', 'county', (x) => _county(our['country'] as String?, x));
  _set(f, our, 'my_cqz', 'cqZone', int.tryParse);
  _set(f, our, 'my_cq_zone', 'cqZone', int.tryParse);
  _set(f, our, 'my_ituz', 'ituZone', int.tryParse);
  _set(f, our, 'my_itu_zone', 'ituZone', int.tryParse);
  _set(f, our, 'my_dxcc', 'dxccCode', int.tryParse);
  _set(f, our, 'my_email', 'email');
  _set(f, our, 'my_gridsquare', 'grid');
  _set(f, our, 'my_lat', 'lat', (x) => parseAdifCoordinate(x, latitude: true));
  _set(f, our, 'my_lon', 'lon', (x) => parseAdifCoordinate(x, latitude: false));
  _set(f, our, 'my_pfx', 'entityPrefix');
  // num, not the raw string: `power` is also written by CAT capture
  // (Qso.power) as a number, and the two origins have to agree on a type.
  // Top-level, not under `our` — QSON convention (matching freq/band/mode).
  _set(f, qso, 'tx_pwr', 'power', num.tryParse);
  _set(f, their, 'rx_pwr', 'power', num.tryParse);

  final notes = _present(f['notes']) ?? _present(f['notes_intl']) ?? _present(f['comment']) ?? _present(f['comment_intl']);
  if (notes != null) qso['notes'] = notes;

  final qsl = _qslFrom(f, genericQsl);
  if (qsl.isNotEmpty) qso['qsl'] = qsl;

  return qso;
}

/// Confirmations, one sub-map per service plus a rolled-up `received`.
///
/// Which services a file can attest to depends on who wrote it, so each block
/// is gated on a field only that service emits. LoTW's own dates are checked
/// before its `_RCVD` flag because a QRZ download carries LoTW dates too.
///
/// Gated on a field having a VALUE, not on the key being present: loggers
/// write empty tags (`<COMMENT:0>` fourteen times in one corpus file), and a
/// present-but-empty confirmation date would otherwise mark the QSO confirmed
/// with nothing behind it.
Map<String, dynamic> _qslFrom(Map<String, String> f, bool genericQsl) {
  final qsl = <String, dynamic>{};

  if (_present(f['app_qrzlog_qsldate']) != null) {
    final qrz = <String, dynamic>{'received': true};
    _set(f, qrz, 'app_qrzlog_logid', 'id');
    _set(f, qrz, 'app_qrzlog_qsldate', 'receivedOn', _dateMillis);
    qsl['qrz'] = qrz;
  }

  if (_present(f['lotw_qslrdate']) != null) {
    final lotw = <String, dynamic>{'received': true};
    _set(f, lotw, 'lotw_qslrdate', 'receivedOn', _dateMillis);
    _set(f, lotw, 'lotw_qslsdate', 'sentOn', _dateMillis);
    qsl['lotw'] = lotw;
  } else if (_present(f['app_lotw_rxqsl']) != null) {
    final lotw = <String, dynamic>{'received': true};
    _set(f, lotw, 'app_lotw_rxqsl', 'receivedOn', _dateMillis);
    _set(f, lotw, 'app_lotw_rxqso', 'sentOn', _dateMillis);
    qsl['lotw'] = lotw;
  } else if (_confirmed(f['lotw_qsl_rcvd'])) {
    qsl['lotw'] = <String, dynamic>{'received': true};
  }

  if (_confirmed(f['eqsl_qsl_rcvd'])) {
    final eqsl = <String, dynamic>{'received': true};
    _set(f, eqsl, 'eqsl_qsl_rdate', 'receivedOn', _dateMillis);
    qsl['eqsl'] = eqsl;
  }

  if (_confirmed(f['app_dxkeeper_clublog_qsl_rcvd'])) {
    final clublog = <String, dynamic>{'received': true};
    _set(f, clublog, 'app_dxkeeper_clublog_qslrdate', 'receivedOn', _dateMillis);
    qsl['clublog'] = clublog;
  }

  if (_confirmed(f['qsl_rcvd']) && genericQsl) {
    final paper = <String, dynamic>{'received': true};
    _set(f, paper, 'qslrdate', 'receivedOn', _dateMillis);
    _set(f, paper, 'qslsdate', 'sentOn', _dateMillis);
    qsl['qsl'] = paper;
  }

  if (qsl.isNotEmpty) qsl['received'] = true;
  return qsl;
}

/// `TIME_OFF` without `QSO_DATE_OFF` that reads earlier than `TIME_ON` means
/// the contact crossed midnight, not that it ended before it began.
void _setTimes(Map<String, String> f, Map<String, dynamic> qso) {
  final date = _present(f['qso_date']);
  final timeOn = _present(f['time_on']);
  final timeOff = _present(f['time_off']);
  int? start;
  int? end;

  if (date != null) start = _timestamp(date, timeOn ?? timeOff ?? '000000');

  final dateOff = _present(f['qso_date_off']);
  if (dateOff != null) {
    end = _timestamp(dateOff, timeOff ?? '235959');
  } else if (timeOff != null && date != null) {
    end = _timestamp(date, timeOff);
    if (end != null && start != null && end < start) {
      end += const Duration(days: 1).inMilliseconds;
    }
  }

  start ??= end;
  end ??= start;

  if (start != null) qso['startAtMillis'] = start;
  if (end != null) qso['endAtMillis'] = end;
}

/// Whether a QSL_RCVD-style enumeration says the contact is confirmed.
///
/// `Y` is the common answer and `V` ("verified") is a stronger one — both mean
/// the confirmation exists, and dropping `V` would quietly discard the best
/// evidence a log carries. `ki2d-clublog.adi` writes `V` on 8 of its 14
/// records. Compared case-insensitively because ADIF enumeration values are,
/// and loggers really do lowercase them.
bool _confirmed(String? value) {
  final v = value?.toUpperCase();
  return v == 'Y' || v == 'V';
}

/// Null for a field that is absent OR present-but-empty. ADIF files carry
/// plenty of the latter, and for every purpose here they mean the same thing —
/// which `??` chains do not, since `??` only skips null.
String? _present(String? value) => (value == null || value.isEmpty) ? null : value;

// Hoisted, not a literal inside the function: a `RegExp` literal recompiles
// its pattern on every call, and an import runs this up to four times per
// QSO (`LAT`/`LON`/`MY_LAT`/`MY_LON`) — the same cost `_clean` below
// measured as the largest single item in parsing a 38k-QSO file.
final _adifCoordinate = RegExp(r'^([NSEW])\s*(\d{1,3})\s+(\d{1,2}(?:\.\d+)?)$');

/// ADIF's Location data type — `XDDD MM.MMM`, a hemisphere letter, degrees,
/// then minutes to three decimals — as the signed decimal degrees QSON stores.
/// `N041 22.500` is 41.375; `W074 27.000` is -74.45.
///
/// Also accepts bare signed decimal degrees, which is not the ADIF format but
/// is what several exporters write into these fields anyway; the hemisphere
/// letter is what tells the two apart. Returns null for anything else, or for
/// a value outside the axis — [latitude] picks the limit, since a value legal
/// for a longitude is off the map for a latitude.
///
/// Deliberately lenient about the field WIDTHS the spec states (`N41 22.5`
/// parses): this reads other people's files, where a padding rule is the
/// commonest thing to get wrong, and the number is unambiguous either way.
double? parseAdifCoordinate(String raw, {required bool latitude}) {
  final text = raw.trim().toUpperCase();
  if (text.isEmpty) return null;

  final limit = latitude ? 90.0 : 180.0;
  double? inRange(double value) => value.isFinite && value.abs() <= limit ? value : null;

  final match = _adifCoordinate.firstMatch(text);
  if (match == null) return inRange(double.tryParse(text) ?? double.nan);

  final hemisphere = match.group(1)!;
  // A latitude signed E/W (or a longitude signed N/S) is not a coordinate on
  // this axis, whatever the numbers say — likelier a file with its fields
  // swapped than a location, and importing it would put the station somewhere
  // nobody was.
  if (latitude != (hemisphere == 'N' || hemisphere == 'S')) return null;

  final minutes = double.parse(match.group(3)!);
  if (minutes >= 60) return null;
  final magnitude = double.parse(match.group(2)!) + minutes / 60;
  return inRange(hemisphere == 'S' || hemisphere == 'W' ? -magnitude : magnitude);
}

/// Copies `src[field]` (or its `_intl` twin) to `dest[destField]`, converted.
///
/// Absent stays absent — writing an explicit null would make "the file didn't
/// say" indistinguishable from "the file said nothing", which is what a merge
/// against an existing QSO turns on.
void _set(Map<String, String> src, Map<String, dynamic> dest, String field, String destField, [Object? Function(String)? convert]) {
  final raw = _present(src[field]) ?? _present(src['${field}_intl']);
  if (raw == null) return;
  final value = convert == null ? raw : convert(raw);
  if (value == null) return;
  dest[destField] = value;
}

/// The trailing whitespace an over-declared length drags into a value, plus
/// HTML entity decoding. Real files over-declare by one routinely
/// (`<qth:37>` for a 36-byte value), and the newline it swallows would
/// otherwise ride along into the QSO — and, for `PROGRAMID`, defeat the
/// comparison in [_genericQslFor]. `trimRight()`, not a regex: this runs
/// once per field of every record, and a `RegExp` literal re-compiles its
/// pattern on every call rather than once — measured as the single largest
/// cost in parsing a 38k-QSO file (~1.4s of it).
String _clean(String value) => _decodeEntities(value).trimRight();

/// ADIF `CNTY` is `STATE,COUNTY` with no country in it, while QSON county
/// codes are country-qualified. `??/` marks a county from a country whose
/// scheme we don't know rather than asserting a wrong one.
final _usCountry = RegExp(r'(United States|Hawaii|Alaska)', caseSensitive: false);
final _countyCountries = RegExp(r'(Puerto Rico)', caseSensitive: false);
final _countySeparator = RegExp(r',\s*');

String _county(String? country, String county) {
  final parts = county.replaceFirst(_countySeparator, '/');
  if (country != null && _usCountry.hasMatch(country)) return 'US/$parts';
  if (country != null && _countyCountries.hasMatch(country)) return parts;
  return '??/$parts';
}

/// ADIF `FREQ` is MHz; QSON `freq` is kHz. A non-numeric frequency is dropped
/// rather than coerced — QSON types it as a number, and a band was very likely
/// written alongside it anyway.
double? _parseFreqKHz(String? freq) {
  if (freq == null) return null;
  final mhz = double.tryParse(freq);
  // `double.tryParse` accepts the literals `NaN` and `Infinity`, and `.round()`
  // on either throws — which would abort the whole import over one garbage
  // field, in a file whose header promises nothing here throws.
  if (mhz == null || !mhz.isFinite) return null;
  // Two decimals of kHz is 10Hz, finer than any log records, and rounding here
  // keeps 14.07582 MHz from arriving as 7075.820000000001.
  return (mhz * 100000).round() / 100;
}

/// `YYYYMMDD` + `HHMMSS` (or `HHMM`), always UTC — ADIF times have no zone.
///
/// Components are range-checked because `DateTime.utc` NORMALIZES instead of
/// rejecting: February 30th would silently become March 2nd, and hour 99 would
/// roll into the following week. A QSO on the wrong day sorts among the wrong
/// contacts and scores in the wrong contest period, so a nonsense date has to
/// read as no date at all.
int? _timestamp(String date, String time) {
  if (date.length < 8) return null;
  final year = int.tryParse(date.substring(0, 4));
  final month = int.tryParse(date.substring(4, 6));
  final day = int.tryParse(date.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  int? part(int from, int to) {
    if (time.length < to) return 0;
    return int.tryParse(time.substring(from, to));
  }

  final hour = part(0, 2);
  final minute = part(2, 4);
  final second = part(4, 6);
  if (hour == null || minute == null || second == null) return null;
  if (hour > 23 || minute > 59 || second > 59) return null;

  final stamp = DateTime.utc(year, month, day, hour, minute, second);
  // Normalization is the only thing that can still fire — April 31st is
  // in-range componentwise and lands on May 1st.
  if (stamp.month != month || stamp.day != day) return null;
  return stamp.millisecondsSinceEpoch;
}

/// A confirmation date, in either shape loggers write it: ADIF's own
/// `YYYYMMDD`, or the `YYYY-MM-DD HH:MM:SS` stamp LoTW uses for
/// `APP_LOTW_RXQSL` — and that Station Master Pro writes into plain
/// `LOTW_QSLRDATE` for a third of its records.
int? _dateMillis(String value) {
  final plain = _timestamp(value, '000000');
  if (plain != null) return plain;
  return DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z')?.millisecondsSinceEpoch;
}

const _namedEntities = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' '};

/// Undoes the HTML escaping some loggers apply to `_INTL` and free-text
/// fields. Named entities are limited to the handful an escaper actually
/// emits; anything unrecognized is left verbatim, because a bare `&` is far
/// more common in a log than an exotic entity and mangling it would be worse
/// than not decoding it.
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
