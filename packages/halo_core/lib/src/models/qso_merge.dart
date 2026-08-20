// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Deciding when two QSON records describe the SAME contact, and folding them
// into one when they do.
//
// Used by ADIF import, and deliberately written against plain QSON maps rather
// than anything ADIF-shaped: a QSON import and a cross-device reconciliation
// need exactly this and nothing more.
//
// app-polo does the same job in `src/tools/mergeQSOs.js` plus lib-qson-tools'
// `qsoKey`, and this **deliberately diverges** in three places. Each divergence
// is a behaviour difference between the two apps, so each is documented where
// it happens rather than only here.

import '../ham/radio.dart';

/// How far apart two records' start times may be and still be one contact.
///
/// app-polo rounds times into fixed five-minute buckets instead. That is not
/// the same rule and it fails at the edges: 12:04 and 12:06 land in different
/// buckets and never match, while 12:00 and 12:04 do. A sliding window is what
/// "within five minutes" actually means.
const qsoMergeWindow = Duration(minutes: 5);

/// Whether [a] and [b] are the same contact logged twice.
///
/// Same station, same band, same mode, close enough in time. Mode is compared
/// through [_matchableMode], which differs from app-polo's raw comparison only
/// in folding the sideband spellings together.
///
/// `our.call` participates, so two operators at a multi-operator station who
/// both worked a contact keep their own records of it. **A missing `our.call`
/// on either side is a wildcard, not a mismatch**: Club Log's export carries no
/// `STATION_CALLSIGN` at all, and comparing absent-as-empty would stop such a
/// file from ever merging with anything.
///
/// [stationCall] takes `our.call` out of the comparison entirely — see
/// [qsoForStation]. An importer that is about to rewrite every record to one
/// station cannot also treat the call it is discarding as a difference.
bool qsosAreSameContact(
  Map<String, dynamic> a,
  Map<String, dynamic> b, {
  String? stationCall,
}) {
  final theirA = _sub(a, 'their');
  final theirB = _sub(b, 'their');

  final callA = _text(theirA['call']);
  final callB = _text(theirB['call']);
  if (callA == null || callB == null || callA != callB) return false;

  final bandA = _text(a['band']);
  final bandB = _text(b['band']);
  if (bandA == null || bandB == null || bandA != bandB) return false;

  // A record with no mode is not "the same mode as" anything — merging on a
  // blank would fold every mode-less contact into the first one that matched
  // on call and band.
  final modeA = _matchableMode(a['mode']);
  final modeB = _matchableMode(b['mode']);
  if (modeA == null || modeB == null || modeA != modeB) return false;

  // With [stationCall] set, both records belong to that station by policy —
  // whatever call the file recorded is about to be replaced — so it cannot
  // discriminate between them.
  if (stationCall == null) {
    final ourA = _text(_sub(a, 'our')['call']);
    final ourB = _text(_sub(b, 'our')['call']);
    if (ourA != null && ourB != null && ourA != ourB) return false;
  }

  final startA = _millis(a['startAtMillis']);
  final startB = _millis(b['startAtMillis']);
  if (startA == null || startB == null) return false;
  return (startA - startB).abs() <= qsoMergeWindow.inMilliseconds;
}

/// Folds [older] into [newer], returning one record.
///
/// [newer] takes precedence **per field**: it wins wherever both sides have a
/// value, and a field only [older] carries survives. app-polo replaces
/// wholesale (`{...b}`), which is a different thing — a LoTW download carries
/// almost no station detail, so replacing would erase the name, grid and notes
/// a callsign lookup had filled in. Precedence means winning a contest between
/// two values, not deleting the one value there is.
///
/// Two fields are not a contest and are handled explicitly:
///
/// - **Times widen** to the outer bounds — earliest start, latest end. Same as
///   app-polo. Two records of one contact disagree about its edges because
///   each saw part of it.
/// - **Refs merge**, with [multiRefTypes] deciding which types may stack. A
///   type not listed keeps ONE reference — the newer record's. See
///   [_mergeRefs].
///
/// The result shares no mutable structure with either input: an import preview
/// holds the existing log record alongside the merged candidate, and editing
/// one must not rewrite the other.
Map<String, dynamic> mergeQsos(
  Map<String, dynamic> older,
  Map<String, dynamic> newer, {
  Set<String> multiRefTypes = const {},
  String? stationCall,
}) {
  final merged = _mergeMaps(older, newer);

  final start = _minOf(_millis(older['startAtMillis']), _millis(newer['startAtMillis']));
  if (start != null) merged['startAtMillis'] = start;
  final end = _maxOf(_millis(older['endAtMillis']), _millis(newer['endAtMillis']));
  if (end != null) merged['endAtMillis'] = end;

  final refs = _mergeRefs(_refsOf(older), _refsOf(newer), multiRefTypes);
  if (refs.isNotEmpty) merged['refs'] = refs;

  return stationCall == null ? merged : qsoForStation(merged, stationCall);
}

/// [qso] as though it had been logged by [stationCall].
///
/// A log file records who transmitted, and that is not always who is importing
/// it: a contact worked as `W1AW/P` and pulled into an operation running as
/// `KI2D` belongs to `KI2D` once it lands there, or the operation's own export
/// would claim a station it never was.
///
/// Whether to impose one is the IMPORTER'S policy, not this module's, which is
/// why it is a parameter rather than a rule: importing a file into an
/// operation rewrites the call, while importing a station's whole history for
/// worked-before detection must keep whatever each contact really carried.
///
/// The operator's own record of the other station (`their`) is untouched, and
/// so is `our.operator` — who was at the key is a different fact from which
/// callsign went out.
Map<String, dynamic> qsoForStation(Map<String, dynamic> qso, String stationCall) {
  final result = _deepCopyMap(qso);
  final our = result['our'];
  result['our'] = {
    if (our is Map) ...our.cast<String, dynamic>(),
    'call': stationCall,
  };
  return result;
}

/// A record's start time as this module reads it — the same coercion matching
/// and merging use.
///
/// Public so a caller deciding whether a record is importable asks the same
/// question the matcher will: a record this returns null for can never match
/// anything, and would be written with a fabricated timestamp instead.
int? qsoStartMillis(Map<String, dynamic> qso) => _millis(qso['startAtMillis']);

/// Refs that belong to the operation, and the contacts without them.
typedef HoistedRefs = ({List<Map<String, dynamic>> operationRefs, List<Map<String, dynamic>> qsos});

/// The key a producer uses to say a reference belongs on the operation rather
/// than on the contact carrying it. See `Ref.for` in the extension SDK.
const qsoRefScopeKey = 'for';
const qsoRefScopeOperation = 'operation';

/// Lifts references tagged `for: 'operation'` out of [qsos] into an
/// operation-level list, and drops the tag.
///
/// ADIF has no operation, so an activation is written onto every record —
/// `MY_SIG_INFO` on all 200 contacts of a park activation — while the
/// reference the OTHER station was at belongs to the single contact that
/// worked it. QSON keeps those in different places, and this puts them back.
///
/// **The producer says which is which**; nothing here guesses. An `adifImport`
/// hook sees one record at a time and knows its own program's vocabulary, so
/// it tags the reference as it reads it. The alternative available to this
/// layer — "a reference every record carries is an activation" — cannot tell
/// one from a short log where everyone happened to hunt the same reference,
/// and would quietly discard the parks those contacts earned.
///
/// The tag is consumed. Once a reference sits on the operation its position IS
/// the answer, and a marker left behind would be a second source of truth free
/// to disagree with it.
HoistedRefs hoistOperationRefs(List<Map<String, dynamic>> qsos) {
  bool belongsToOperation(Map<String, dynamic> ref) =>
      _text(ref[qsoRefScopeKey]) == qsoRefScopeOperation.toUpperCase();

  Map<String, dynamic> untagged(Map<String, dynamic> ref) => _deepCopyMap(ref)..remove(qsoRefScopeKey);

  final lifted = <String, Map<String, dynamic>>{};
  for (final qso in qsos) {
    for (final ref in _refsOf(qso)) {
      if (!belongsToOperation(ref)) continue;
      // Every distinct value, so an operator who activated two references at
      // once keeps both.
      lifted.putIfAbsent('${_text(ref['type'])}|${_text(ref['ref'])}', () => untagged(ref));
    }
  }
  if (lifted.isEmpty) {
    // Still strip any `for: 'qso'` a producer wrote explicitly, so the tag
    // never reaches storage.
    return (operationRefs: const [], qsos: [for (final qso in qsos) _withUntaggedRefs(qso)]);
  }

  return (
    operationRefs: lifted.values.toList(),
    qsos: [
      for (final qso in qsos)
        _withUntaggedRefs(qso, drop: belongsToOperation),
    ],
  );
}

Map<String, dynamic> _withUntaggedRefs(
  Map<String, dynamic> qso, {
  bool Function(Map<String, dynamic>)? drop,
}) {
  final raw = qso['refs'];
  if (raw is! List || raw.isEmpty) return qso;
  // Walks the RAW list, not `_refsOf`, so an entry that is not a map survives.
  // It is malformed and nothing will read it, but deleting whatever an
  // existing record carried is the same mistake `_mergeRefs` goes out of its
  // way to avoid one function over.
  final kept = [
    for (final ref in raw)
      if (ref is! Map)
        ref
      else if (drop == null || !drop(ref.cast<String, dynamic>()))
        _deepCopyMap(ref.cast<String, dynamic>())..remove(qsoRefScopeKey),
  ];
  final result = _deepCopyMap(qso);
  if (kept.isEmpty) {
    result.remove('refs');
  } else {
    result['refs'] = kept;
  }
  return result;
}

/// The distinct `our.call` values in [qsos] that are not [stationCall], in the
/// order first seen.
///
/// What an importer needs to WARN with: rewriting a station call silently
/// would let a file of someone else's contacts land in an operation looking
/// like the operator's own. A record carrying no call at all is not in the
/// list — filling a blank is not a surprise worth a warning.
List<String> foreignStationCalls(Iterable<Map<String, dynamic>> qsos, String stationCall) {
  final wanted = _text(stationCall);
  final seen = <String>{};
  final found = <String>[];
  for (final qso in qsos) {
    final raw = _sub(qso, 'our')['call'];
    final call = _text(raw);
    if (call == null || call == wanted) continue;
    if (seen.add(call)) found.add((raw as String).trim());
  }
  return found;
}

/// Newer first, so the survivor of a single-valued type is the newer record's.
///
/// Only a type in [multiRefTypes] may stack; every other type keeps ONE, which
/// is app-polo's rule (`mergeQSOs.js`, which names POTA in the code). The set
/// is a PARAMETER rather than a table here because which programs allow
/// several references at once is knowledge the activity extensions hold —
/// `referenceActivity` has an `allowsMultiple` flag, mirrored onto the type's
/// logging control, and the app reads it with `allowsMultipleRefsOfType`.
/// `halo_core` cannot reach any of that, and a copy here would be a second,
/// drifting definition of the ref vocabulary.
///
/// Defaulting to empty therefore means "stack nothing" — the same default the
/// rest of the app applies to an undeclared type: one reference of a kind is
/// the safe assumption, and a type that genuinely stacks says so.
///
/// A ref with no usable `type` is kept, from either side. It is malformed —
/// nothing will match it and no scorer will read it — but dropping it from the
/// OLDER side only, as this once did, silently deleted whatever an existing
/// record carried the moment anything merged into it.
List<Map<String, dynamic>> _mergeRefs(
  List<Map<String, dynamic>> older,
  List<Map<String, dynamic>> newer,
  Set<String> multiRefTypes,
) {
  final multi = {for (final type in multiRefTypes) type.toUpperCase()};
  final result = <Map<String, dynamic>>[];
  final placed = <String, int>{};
  final typeless = <String>{};
  for (final ref in [...newer, ...older]) {
    final type = _text(ref['type']);
    // A typeless ref has no type to dedupe on, so it dedupes on its whole
    // content instead. Dropping that guard entirely makes merging
    // non-idempotent for these: re-running an import doubles them every time.
    if (type == null) {
      if (!typeless.add(_canonical(ref))) continue;
      result.add(_deepCopyMap(ref));
      continue;
    }
    // A stacking type is identified by WHICH reference it names; any other
    // type is identified by the type alone, so a second one does not get its
    // own slot.
    final key = multi.contains(type) ? '$type|${_text(ref['ref'])}' : type;
    final at = placed[key];
    if (at == null) {
      placed[key] = result.length;
      result.add(_deepCopyMap(ref));
      continue;
    }
    // Field-merge ONLY when the two name the same reference. Then the loser's
    // extra fields are worth keeping: a ref carries more than `type` and
    // `ref` — the core writes the contest serial onto it at commit
    // (`_withAllocatedSerial`) — and an imported ref is only `{type, ref}`, so
    // replacing wholesale would discard the number the operator sent.
    //
    // When the references DIFFER, the newer one wins outright. Grafting there
    // would move one reference's name, and a serial issued against it, onto a
    // different reference — which is worse than the loss it was avoiding,
    // because the result looks like real data.
    if (_text(result[at]['ref']) == _text(ref['ref'])) {
      result[at] = _mergeMaps(_deepCopyMap(ref), result[at]);
    }
  }
  return result;
}

/// A stable string for a whole ref, so a malformed one can dedupe on content.
String _canonical(Map<String, dynamic> ref) {
  final keys = ref.keys.toList()..sort();
  return [for (final key in keys) '$key=${ref[key]}'].join(' ');
}

/// Recursive per-field merge: [newer]'s value wins, [older]'s fills a gap, and
/// two maps at the same key merge rather than replace — which is what keeps
/// `their.name` alive when the newer record's `their` holds only a callsign.
Map<String, dynamic> _mergeMaps(Map<String, dynamic> older, Map<String, dynamic> newer) {
  // Deep, not `Map.from`: a shallow copy shares every nested map and list that
  // the newer side does NOT also carry — those keys are copied by reference and
  // never touched again — so editing the merged record would rewrite the log
  // record it was merged from.
  final result = _deepCopyMap(older);
  for (final entry in newer.entries) {
    final incoming = entry.value;
    if (_isBlank(incoming)) continue;
    final existing = result[entry.key];
    if (existing is Map && incoming is Map) {
      result[entry.key] = _mergeMaps(existing.cast<String, dynamic>(), incoming.cast<String, dynamic>());
    } else {
      result[entry.key] = _deepCopy(incoming);
    }
  }
  return result;
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) => {
      for (final entry in source.entries) entry.key: _deepCopy(entry.value),
    };

Object? _deepCopy(Object? value) {
  if (value is Map) return _deepCopyMap(value.cast<String, dynamic>());
  if (value is List) return [for (final item in value) _deepCopy(item)];
  return value;
}

/// A null or empty value is "the record didn't say", not "the record says
/// nothing is here" — the same rule the ADIF mapper applies on the way in.
/// Without it a newer record's empty string would overwrite a real value.
/// Whitespace counts as empty, matching [_text]. The ADIF mapper already
/// strips a trailing run before this sees it, but this module also serves QSON
/// import and sync, where a space-only field would otherwise erase a real
/// value on the strength of saying nothing.
bool _isBlank(Object? value) =>
    value == null || (value is String && value.trim().isEmpty) || (value is Iterable && value.isEmpty);

/// One contact logged as `SSB` and again as `USB` is one contact — the two
/// name the same emission, and which one a logger writes is a matter of its
/// own conventions.
const _sidebandSpellings = {'SSB', 'USB', 'LSB'};

/// The mode as this comparison sees it: the sideband spellings folded
/// together, everything else left alone.
///
/// Deliberately NOT [superModeForMode], which buckets every non-CW, non-phone
/// mode as `Digital` — that would make an FT8 contact and an RTTY contact
/// three minutes apart the same contact, and lose one. They are separate
/// contacts for award and contest credit. It would also fold AM and FM into
/// SSB, and match any unrecognized mode string against every digital record.
/// `superModeForMode` is right for scoring, where the question is which
/// category a contact counts in; the question here is whether two records are
/// the same contact, which is a stricter one.
String? _matchableMode(Object? mode) {
  final normalized = _text(mode);
  if (normalized == null) return null;
  return _sidebandSpellings.contains(normalized) ? 'SSB' : normalized;
}

Map<String, dynamic> _sub(Map<String, dynamic> qso, String key) {
  final value = qso[key];
  return value is Map ? value.cast<String, dynamic>() : const {};
}

List<Map<String, dynamic>> _refsOf(Map<String, dynamic> qso) {
  final refs = qso['refs'];
  if (refs is! List) return const [];
  return refs.whereType<Map>().map((r) => r.cast<String, dynamic>()).toList();
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed.toUpperCase();
}

/// Mirrors `QsosRepository._millisOf`. If the two disagree, a record with a
/// string timestamp matches nothing during planning and is then inserted
/// anyway — arriving as a duplicate of a contact already in the log.
int? _millis(Object? value) {
  if (value is num) return value.isFinite ? value.toInt() : null;
  if (value is String) return int.tryParse(value);
  return null;
}

int? _minOf(int? a, int? b) => a == null ? b : (b == null ? a : (a < b ? a : b));
int? _maxOf(int? a, int? b) => a == null ? b : (b == null ? a : (a > b ? a : b));

/// Three-way merge for a concurrent edit: [edited] was composed from [base],
/// but the stored row has since moved on to [current] (a sync pull, a peer
/// merge, a background lookup landing). Fields the editor actually changed —
/// different in [edited] than in [base], additions and removals included —
/// keep the edit; every other field keeps [current], so the concurrent
/// revision survives wherever this edit didn't touch it. Without this,
/// writing [edited] wholesale reverts the concurrent revision — and,
/// restamped newer, the reversion wins on every device at the next sync.
///
/// `their`/`our` merge per FIELD, one level deep: edits are field-scoped
/// there, and treating the whole map as one value would make a local edit to
/// `their.sent` discard a concurrent correction to `their.name`. Every other
/// key — `refs` included — is one value: a half-merged ref list is worse
/// than a decided winner.
///
/// The result shares no mutable structure with any input, same as
/// [mergeQsos].
Map<String, dynamic> mergeConcurrentEdit({
  required Map<String, dynamic> base,
  required Map<String, dynamic> current,
  required Map<String, dynamic> edited,
}) =>
    _threeWayLevel(base, current, edited, mergeParties: true);

Map<String, dynamic> _threeWayLevel(
  Map<String, dynamic> base,
  Map<String, dynamic> current,
  Map<String, dynamic> edited, {
  required bool mergeParties,
}) {
  final result = <String, dynamic>{};
  // A key living only in [base] was removed on both sides — it never
  // appears. A key only in [current] is an untouched concurrent addition
  // (kept); one only in [edited] is the editor's own addition (kept).
  for (final key in {...current.keys, ...edited.keys}) {
    if (mergeParties && (key == 'their' || key == 'our')) {
      final merged = _threeWayLevel(
        _mapValue(base[key]),
        _mapValue(current[key]),
        _mapValue(edited[key]),
        mergeParties: false,
      );
      if (merged.isNotEmpty) result[key] = merged;
      continue;
    }
    final editorChanged = base.containsKey(key) != edited.containsKey(key) || !_deepEquals(base[key], edited[key]);
    if (editorChanged) {
      if (edited.containsKey(key)) result[key] = _deepCopy(edited[key]);
      // Removed by the editor: stays removed.
    } else if (current.containsKey(key)) {
      result[key] = _deepCopy(current[key]);
    }
    // Untouched by the editor and removed in [current]: stays removed.
  }
  return result;
}

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !_deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
