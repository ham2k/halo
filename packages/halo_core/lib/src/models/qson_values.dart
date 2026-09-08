// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Type probes for reading the untyped QSON blob, and the normalizer that
/// keeps wrong-typed values from being written back into it.
///
/// QSON is JSON that arrives from peers, from LoFi, from ADIF imports and
/// from app-polo — none of which this app's types can enforce. A hard
/// `as` cast on such a value does not degrade, it throws, and a getter that
/// throws takes down whatever was reading it: a `String` freq kills every
/// frame that renders the QSO list, and a `bool` mode aborts the whole
/// `mergeFromSync` transaction, so sync retries the same record forever.
///
/// Same idea as `asSpotString`/`asSpotNum` (spots_service.dart), which do
/// this job for the extension bridge.
library;

/// A string, or null for anything else.
///
/// Deliberately does NOT stringify a non-string: `mode: true` would become
/// `'true'`, an invented mode that then reaches exports and scoring as if an
/// operator had typed it. Absent is honest; invented is not.
String? asQsonString(Object? value) => value is String ? value : null;

/// A finite number, parsing a numeric string on the way — `freq: '14.074'`
/// and `power: '5'` both reach us from older imports and from polo, and the
/// number they name is the value the record means.
///
/// Non-finite is rejected rather than passed through, and that is
/// load-bearing on the write path: `num.tryParse` accepts the literals
/// `'NaN'` and `'Infinity'` (and overflows `'1e400'` to `Infinity`) — which
/// is exactly what a JS peer sends for a `NaN` — while `jsonEncode` refuses
/// to encode either and `.toInt()` on either throws. Coercing one of those
/// into a record would abort the very transaction that stores it, so a
/// device would retry the same record forever, which is the failure this
/// whole module exists to prevent.
///
/// The same guard, for the same reason, is in `_millisOf` (repositories),
/// `_millis` (qso_merge) and `_parseFreqKHz` (adif_to_qson).
num? asQsonNum(Object? value) {
  if (value is num) return value.isFinite ? value : null;
  if (value is String) {
    final parsed = num.tryParse(value);
    return (parsed != null && parsed.isFinite) ? parsed : null;
  }
  return null;
}

/// A string-keyed map, or null.
///
/// Accepts a `Map` with any key type and re-casts it: `jsonDecode` yields
/// `Map<String, dynamic>`, but a map built in Dart or handed over the
/// extension bridge is often `Map<dynamic, dynamic>`, which a
/// `as Map<String, dynamic>?` rejects even though every key in it is a
/// string.
Map<String, dynamic>? asQsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

/// A list, or null.
List<Object?>? asQsonList(Object? value) => value is List ? value : null;

/// A record's boolean flag, in every dialect one reaches us in: `true`, the
/// integer `1`, and the strings `'true'` and `'1'`. Anything else — absent,
/// null, `0`, `'false'`, a value we cannot read — is false.
///
/// A flag is NOT a field a strict `== true` can read, because this app is the
/// only writer that spells one as a JSON boolean. PoLo copies its SQLite
/// column straight into the record it pushes, so its `deleted` is the integer
/// `1`; LoFi's own delete endpoint writes the same integer into the stored
/// blob, and LoFi hands a record back with whatever dialect wrote it. A
/// strict check reads all of those as "not deleted" and resurrects a
/// tombstoned operation — silently, and for good, since the record that would
/// correct it compares equal on every later round (`inboundIsStale`).
///
/// Narrower than LoFi's own `ActiveModel::Type::Boolean`, and deliberately
/// so. Rails enumerates the FALSE values and casts everything else true, so
/// `'t'`, `'on'`, `'yes'` and `2` are all deleted there and live here. That
/// asymmetry is the safe one for a flag whose meaning is destructive: a
/// spelling this app does not recognise leaves an operator's log where they
/// can still see it, while the reverse hides a log on a value nobody meant as
/// a delete. No writer produces those spellings today; a writer that starts
/// to belongs on this list, named, rather than swept in by a rule that treats
/// every unknown value as a tombstone.
///
/// Enumerated rather than probed for truthiness for a second reason: `0` is
/// truthy in Ruby, and probing is exactly how the server once marked live
/// QSOs deleted.
bool asQsonBool(Object? value) =>
    value == true || value == 1 || value == 'true' || value == '1';

/// A QSON field whose value was dropped as unusable, as reported to the crash
/// backend — the shape [onQsonTypeViolation]'s wiring hands to
/// `ErrorReportingService`. Mirrors
/// `MalformedSpotDataException`, which does the same job for the extension
/// bridge.
///
/// Carries the write path and the field's dotted path, never the value:
/// these fields hold callsigns, names and notes.
class MalformedQsonDataException implements Exception {
  MalformedQsonDataException(this.writePath, this.violation);
  final String writePath;
  final QsonTypeViolation violation;

  @override
  String toString() => 'MalformedQsonDataException: $writePath — $violation';
}

/// Called once per field whose value was DROPPED while normalizing a record
/// on its way into storage. Null until the app wires it up at boot;
/// `halo_core` is pure Dart and cannot reach the app's crash backend itself.
///
/// The point is to learn what WRITES a value nothing can use — dropping it
/// fixes the symptom and leaves the source of a `bool` mode unknown. A wrong
/// type that COERCES is not reported: `asQsonNum` takes a numeric string by
/// design, so reporting those would drown this signal in records behaving as
/// documented. Wired through `ErrorReportingService.reportIfRepeated`, so a
/// device holding one bad record reports it once rather than once per sync
/// round.
void Function(String context, QsonTypeViolation violation)? onQsonTypeViolation;

/// What [normalizeQsoQson] expects one field to hold.
enum QsonFieldType { string, number, map, list }

/// One field [normalizeQsoQson] could not use and dropped, for a caller that
/// wants to report it. [path] is dotted from the record root (`their.guess.grid`), so
/// a report names the field without the caller reassembling it.
class QsonTypeViolation {
  final String path;
  final QsonFieldType expected;

  /// The offending value's runtime type name — NOT the value. A QSO's fields
  /// carry callsigns, names and notes, and this travels to the crash backend.
  final String actualType;

  const QsonTypeViolation(this.path, this.expected, this.actualType);

  @override
  String toString() => '$path: expected ${expected.name}, got $actualType';
}

/// The fields each model getter reads, and what it reads them as. Only
/// fields a getter actually touches: normalizing a key nothing reads would
/// rewrite a payload we don't understand, and QSON is forward-compatible
/// precisely because unknown keys survive a round trip untouched.
const _qsoFields = <String, QsonFieldType>{
  'band': QsonFieldType.string,
  'mode': QsonFieldType.string,
  'notes': QsonFieldType.string,
  'freq': QsonFieldType.number,
  'power': QsonFieldType.number,
  'startAtMillis': QsonFieldType.number,
  'updatedAtMillis': QsonFieldType.number,
  'lat': QsonFieldType.number,
  'lon': QsonFieldType.number,
  'our': QsonFieldType.map,
  'their': QsonFieldType.map,
  'event': QsonFieldType.map,
  'refs': QsonFieldType.list,
};

const _qsoOurFields = <String, QsonFieldType>{
  'call': QsonFieldType.string,
  // Who was at the key, and which position of a multi-station operation
  // logged it — stamped from the operation at log time so a contact keeps
  // naming them after the device moves on to another operator.
  'operatorCall': QsonFieldType.string,
  'multiIdentifier': QsonFieldType.string,
  'grid': QsonFieldType.string,
  'rig': QsonFieldType.string,
  'antenna': QsonFieldType.string,
  'key': QsonFieldType.string,
  'sent': QsonFieldType.string,
  'lat': QsonFieldType.number,
  'lon': QsonFieldType.number,
};

/// Shared by `their` and the `their.guess` sub-map, which the coalescing
/// getters read field-for-field the same way.
const _qsoTheirFields = <String, QsonFieldType>{
  'call': QsonFieldType.string,
  'name': QsonFieldType.string,
  'grid': QsonFieldType.string,
  'state': QsonFieldType.string,
  // The rest of where they are, as the ADIF importer already writes them
  // (`adif_to_qson.dart`) and the More pane now edits them. The zones are
  // numbers there, so they are numbers here.
  'city': QsonFieldType.string,
  'county': QsonFieldType.string,
  'cqZone': QsonFieldType.number,
  'ituZone': QsonFieldType.number,
  'arrlSection': QsonFieldType.string,
  'country': QsonFieldType.string,
  'entityName': QsonFieldType.string,
  'entityPrefix': QsonFieldType.string,
  'flag': QsonFieldType.string,
  'sent': QsonFieldType.string,
  'exchange': QsonFieldType.string,
  'power': QsonFieldType.number,
  'lat': QsonFieldType.number,
  'lon': QsonFieldType.number,
  // The nested lookup result. Descended into with [_qsoGuessFields] below.
  'guess': QsonFieldType.map,
  // Per-source lookup entries. Read as a list by the call-info panel, so a
  // wrong type here throws there rather than degrading.
  'lookups': QsonFieldType.list,
};

/// `their.guess` reads field-for-field like `their` itself, plus the ref
/// suggestions only a guess carries.
final _qsoGuessFields = <String, QsonFieldType>{
  ..._qsoTheirFields,
  'refs': QsonFieldType.list,
};

/// `event`'s own kind, which [Qso.eventKind] reads.
const _qsoEventFields = <String, QsonFieldType>{'event': QsonFieldType.string};

/// The sub-maps [normalizeQsoQson] descends into, and the one `their`
/// descends into in turn. Hoisted rather than written at the call site: this
/// runs once per row on every query, so a map literal there would allocate
/// per row for a table that never changes.
final _qsoNested = <String, Map<String, QsonFieldType>>{
  'our': _qsoOurFields,
  'their': _qsoTheirFields,
  'event': _qsoEventFields,
};
final _theirNested = <String, Map<String, QsonFieldType>>{'guess': _qsoGuessFields};

const _operationFields = <String, QsonFieldType>{
  'stationCall': QsonFieldType.string,
  'userTitle': QsonFieldType.string,
  'title': QsonFieldType.string,
  'grid': QsonFieldType.string,
  'lat': QsonFieldType.number,
  'lon': QsonFieldType.number,
  // No getter for these five — `operation_dialogs.dart`,
  // `activities_view.dart` and `operation_location_screen.dart` read them
  // straight off the blob. Normalized here so what they read is a string by
  // the time they see it.
  'notes': QsonFieldType.string,
  'operatorCall': QsonFieldType.string,
  'gridSource': QsonFieldType.string,
  'state': QsonFieldType.string,
  'county': QsonFieldType.string,
  'createdAtMillis': QsonFieldType.number,
  'updatedAtMillis': QsonFieldType.number,
  // app-polo's older spellings, which `Operation.createdAtMillis` and
  // `.updatedAtMillis` still fall back to.
  'createdOnMillis': QsonFieldType.number,
  'updatedOnMillis': QsonFieldType.number,
  'refs': QsonFieldType.list,
};

Object? _coerce(Object? value, QsonFieldType type) => switch (type) {
      QsonFieldType.string => asQsonString(value),
      QsonFieldType.number => asQsonNum(value),
      QsonFieldType.map => asQsonMap(value),
      QsonFieldType.list => asQsonList(value),
    };

/// True when [value] already satisfies [type] with nothing to rewrite, so a
/// clean record can be returned unchanged rather than rebuilt.
bool _isClean(Object? value, QsonFieldType type) => switch (type) {
      QsonFieldType.string => value is String,
      QsonFieldType.number => value is num,
      QsonFieldType.map => value is Map,
      QsonFieldType.list => value is List,
    };

Map<String, dynamic> _normalize(
  Map<String, dynamic> data,
  Map<String, QsonFieldType> fields,
  String prefix,
  List<QsonTypeViolation>? found,
  Map<String, Map<String, QsonFieldType>> nested,
) {
  Map<String, dynamic>? rebuilt;
  Map<String, dynamic> mutable() => rebuilt ??= Map<String, dynamic>.of(data);

  for (final entry in fields.entries) {
    final key = entry.key;
    if (!data.containsKey(key)) continue;
    final value = data[key];
    // An absent field and a null one are the same ordinary absence every
    // getter already handles — only a PRESENT wrong type is a violation.
    if (value == null || _isClean(value, entry.value)) continue;

    // Reported only when the value is LOST, which is why this sits after the
    // coercion rather than before it. A wrong type that coerces cleanly is
    // not a defect to report: [asQsonNum] accepts a numeric string on
    // purpose, naming `freq: '14.074'` and `power: '5'` as shapes that
    // legitimately reach us from older imports and from polo — so reporting
    // those buries the case the report exists for (a `mode: true` that is
    // DROPPED, taking the operator's data with it) under thousands of
    // records behaving exactly as documented.
    final coerced = _coerce(value, entry.value);
    if (coerced == null) {
      found?.add(QsonTypeViolation('$prefix$key', entry.value, value.runtimeType.toString()));
      mutable().remove(key);
    } else {
      mutable()[key] = coerced;
    }
  }

  // Descend only into sub-maps that came back as maps — a `their` that was a
  // string has already been dropped above, and there is nothing under it.
  for (final entry in nested.entries) {
    final key = entry.key;
    final sub = asQsonMap((rebuilt ?? data)[key]);
    if (sub == null) continue;
    final normalizedSub = _normalize(
      sub,
      entry.value,
      '$prefix$key.',
      found,
      key == 'their' ? _theirNested : const {},
    );
    if (!identical(normalizedSub, sub)) mutable()[key] = normalizedSub;
  }

  return rebuilt ?? data;
}

/// A QSO's QSON with every field the getters read holding the type they read
/// it as: a numeric string parsed, anything else unusable dropped. Returns
/// [data] itself, unchanged and un-copied, when there was nothing to fix —
/// which is the overwhelmingly common case, so the normal write path pays
/// only the scan.
///
/// Every violation found is appended to [violations] when one is supplied,
/// so the caller can report what it saw. Reporting belongs to the caller
/// because the two callers want opposite things: the write paths report what
/// they find, while the row decoders (`_qsoFromRow`) pass no list at all —
/// they run per row on every query, and a record healed there has no writer
/// left to name. Passing no list also costs no allocation, which is what
/// keeps the read path to the scan alone.
Map<String, dynamic> normalizeQsoQson(
  Map<String, dynamic> data, {
  List<QsonTypeViolation>? violations,
}) =>
    _normalize(data, _qsoFields, '', violations, _qsoNested);

/// [normalizeQsoQson] for an operation's QSON.
Map<String, dynamic> normalizeOperationQson(
  Map<String, dynamic> data, {
  List<QsonTypeViolation>? violations,
}) =>
    _normalize(data, _operationFields, '', violations, const {});
