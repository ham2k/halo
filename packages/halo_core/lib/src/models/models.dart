// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Domain models are thin typed views over QSON maps — the JSON stays the
// source of truth (it is what syncs and what plugins see), the getters just
// give the core and UI a safe way in.

import 'dart:convert';

import '../ham/grid.dart';
import '../ham/radio.dart' show isIncompleteCall;
import 'operation_title.dart';
import 'qson_values.dart';

/// Whether [call] carries `T` or `TEST` as a whole SEGMENT — `KI2D/T`,
/// `KI2D/TEST`, `KI2D/T/P`, but never `W1AW/TESTER`.
///
/// The one definition of "this is test data", shared by [Operation.isTestOperation]
/// and by the travelled clock's write gate. Segments, not a suffix: a
/// substring match would opt `W1AW/TESTER` in, and matching only the LAST
/// segment would miss `KI2D/T/P`, where the operator said `T` and then added
/// a portable modifier.
///
/// Both `T` and `TEST` count. Neither is a standard modifier — those are
/// `/P`, `/M`, `/MM`, `/AM` — so nothing a real operator signs with is
/// swept in by accident.
/// [Qso.hasIncompleteCall] for a record still in its QSON form — one that
/// crossed the extension bridge, or a draft not yet saved.
bool qsonHasIncompleteCall(Map<String, dynamic>? qso) => isIncompleteCall(asQsonString(asQsonMap(qso?['their'])?['call']) ?? '');

bool isTestCall(String call) => call.toUpperCase().split('/').any((segment) => segment == 'T' || segment == 'TEST');

/// The `gridSource` of a location an operation's refs placed — app-polo's
/// value, which it re-derives the same way (see `locationFollowsRefs`). A
/// location from any other source was stated by the operator or a device,
/// and the refs never override it.
const refsGridSource = 'refs';

/// The square a `refs` location shows for its stored [grid]: at most six
/// characters, however many an older record stored, or null when the stored
/// value is not a locator — then the reader derives one from the pair as it
/// would for any other source.
String? refsGridForDisplay(String? grid) {
  final stored = grid?.trim();
  if (stored == null || !isWellFormedGrid(stored)) return null;
  final normalized = normalizeGrid(stored);
  return normalized.length > 6 ? normalized.substring(0, 6) : normalized;
}

/// The `gridSource` of a location taken from the device's own position.
const gpsGridSource = 'gps';

/// How many decimal places a GPS fix is stored with: about a metre, which is
/// all a phone's receiver can honestly claim, and all a contact needs.
const capturedFixDecimals = 5;

/// The operation fields that state [fix] as where the station is: the
/// coordinate rounded to [capturedFixDecimals], and the locator for it at the
/// operator's [GridPrecision].
Map<String, dynamic> gpsLocationData(GridLocation fix) {
  double round(double value) => double.parse(value.toStringAsFixed(capturedFixDecimals));
  final lat = round(fix.latitude);
  final lon = round(fix.longitude);
  return {'grid': gridForLocation(lat, lon), 'gridSource': gpsGridSource, 'lat': lat, 'lon': lon};
}

/// A logging session: one station, one setup, one stretch of time.
class Operation {
  final String uuid;
  final Map<String, dynamic> data;
  final int qsoCount;
  final int? startAtMillisMin;
  final int? startAtMillisMax;
  final bool deleted;
  final bool synced;

  /// See `Operations.purged` (database.dart) — set only alongside [deleted]
  /// when this operation was purged rather than merely deleted.
  final bool purged;

  /// Device-local state that never syncs — e.g. cached day/operation scoring
  /// summaries written by `ScoringService` under the `scoring` key. Distinct
  /// from `data`, which is the QSON blob that syncs to the server.
  final Map<String, dynamic> localData;

  const Operation({
    required this.uuid,
    required this.data,
    this.qsoCount = 0,
    this.startAtMillisMin,
    this.startAtMillisMax,
    this.deleted = false,
    this.synced = false,
    this.purged = false,
    this.localData = const {},
  });

  String get stationCall => asQsonString(data['stationCall']) ?? '';

  /// The station callsigns this operation was run under, in the order they
  /// were entered. Usually one; several when a multi-operator station logs
  /// everything in a single operation and each call owes its own submission
  /// (app-polo splits the same idea across `stationCall` +
  /// `stationCallPlusArray`; here it is one comma-separated field).
  ///
  /// Always at least one entry — an operation with no callsign at all yields
  /// `['']` rather than an empty list, so callers that fan out over this
  /// still produce their one set of results instead of silently none.
  List<String> get stationCalls => splitStationCalls(stationCall);

  /// True when any of [stationCalls] is a test call — the operator's own
  /// signal that this operation is for testing, not a real activation.
  /// Changes title, export filenames, spotting and deletion behavior, and is
  /// what the travelled clock may write to at all; see [isTestCall].
  bool get isTestOperation => stationCalls.any(isTestCall);

  /// The user's own title, entered via the operation details dialog —
  /// distinct from [title], which holds the ref-generated one. Empty when
  /// the user hasn't set one.
  String get userTitle => asQsonString(data['userTitle']) ?? '';

  /// The generated title, built from the operation's refs (activity/contest
  /// info) and persisted on save (`ActivitiesView.saveAndClose`,
  /// `app/lib/tools/operation_title.dart`). Empty until the first save after
  /// refs produce a suggestion.
  String get title => asQsonString(data['title']) ?? '';
  String? get grid => asQsonString(data['grid']);

  /// The operation's exact position, when the location it was set from knew
  /// one — a GPS fix, or the published coordinate of a park/summit ref that
  /// was adopted. Null when [grid] came from the operator typing one, which
  /// is all the precision there is in that case.
  ///
  /// Where this is set it is authoritative and [grid] is display only: a
  /// writer that states a grid replaces this pair in the same write — with
  /// the square's own center where that is all it has (see
  /// [locationForStatedGrid]) — so the two never disagree about where the
  /// station is.
  GridLocation? get exactLocation => locationFromLatLon(data['lat'], data['lon']);

  /// Where the station is, as well as this operation knows — its
  /// [exactLocation] if it has one, otherwise the center of its [grid].
  /// What distance, bearing and the map measure from.
  GridLocation? get location => exactLocation ?? gridToLocation(grid);

  /// The locator to show for this operation, at the operator's
  /// [GridPrecision] when it holds a real coordinate, its stored [grid]
  /// otherwise (see [gridForDisplay]).
  ///
  /// A location its refs placed ([refsGridSource]) shows the stored grid
  /// whatever the setting: its pair is the park's published point, which says
  /// where the park is, not where in it the station stands, so it claims no
  /// more than the six characters stored beside it.
  String? get displayGrid {
    if (data['gridSource'] == refsGridSource) {
      if (refsGridForDisplay(grid) case final stated?) return stated;
    }
    return gridForDisplay(lat: data['lat'], lon: data['lon'], grid: grid);
  }

  List<Map<String, dynamic>> get refs =>
      (asQsonList(data['refs']) ?? const []).whereType<Map<dynamic, dynamic>>().map((r) => r.cast<String, dynamic>()).toList();

  /// The ref-derived title/subtitle fragments `OperationTitleService` cached
  /// under `localData['titleSuggestion']` — device-
  /// local like `scoring`, since it's cheaply regenerable from `refs`. A UI
  /// layer localizes the "for"/"at" prepositions and assembles the final
  /// sentence (this model has no BuildContext to do that itself) — that
  /// assembled result is what gets persisted into [title] on save.
  OperationTitleFragments get titleFragments {
    final cached = localData['titleSuggestion'];
    if (cached is! Map) return const OperationTitleFragments();
    return OperationTitleFragments(
      title: asQsonString(cached['title']) ?? '',
      forText: asQsonString(cached['for']) ?? '',
      atText: asQsonString(cached['at']) ?? '',
      subtitle: asQsonString(cached['subtitle']) ?? '',
    );
  }

  DateTime? get startAtMax => startAtMillisMax == null ? null : DateTime.fromMillisecondsSinceEpoch(startAtMillisMax!, isUtc: true);

  /// Falls back to app-polo's older `createdOnMillis` spelling, which
  /// operations synced from a long-lived polo install still carry (polo does
  /// the same on read — `operationsDB.js`). Without the fallback an
  /// operation with no QSOs has no date at all to sort by, so every legacy
  /// empty operation collapses to the bottom of the home list together.
  int? get createdAtMillis => asQsonNum(data['createdAtMillis'] ?? data['createdOnMillis'])?.toInt();

  /// Revision stamp, set by the repositories on every local write (app-polo
  /// convention: it lives in the QSON so it round-trips through sync). Same
  /// legacy fallback as [createdAtMillis] — this one decides which side of a
  /// sync merge wins, so a null would make a legacy record look revision-less.
  int? get updatedAtMillis => asQsonNum(data['updatedAtMillis'] ?? data['updatedOnMillis'])?.toInt();
}

/// The callsigns in one operation's `stationCall` field — see
/// [Operation.stationCalls], whose contract this is. Split out so a field
/// still being TYPED can be read by the same rules as a stored one.
List<String> splitStationCalls(String raw) {
  final parts = [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim().toUpperCase(),
  ];
  // Deduped, order preserved: "N0DEV, N0DEV" is a typo, not a request for
  // two identical sets of files that would then collide on filename.
  final seen = <String>{};
  final unique = [
    for (final call in parts)
      if (seen.add(call)) call,
  ];
  return unique.isEmpty ? const [''] : unique;
}

/// One contact. QSON shape (same as app-polo):
/// `{our: {call, sent}, their: {call, sent}, freq, band, mode,
///   startAtMillis, notes, refs: [...]}`
class Qso {
  final String uuid;
  final String operationUuid;
  final Map<String, dynamic> data;
  final bool deleted;

  /// See `Operation.purged`.
  final bool purged;

  /// Cached scoring results (DESIGN.md §4: the `scoring` hook runs batched
  /// and caches its per-QSO verdicts here, keyed by rule — e.g. `dupe`,
  /// `dxcc`, `bandsAndModes` — so list rendering never waits on the JS
  /// runtime). `null` until `ScoringService` has scored this operation.
  final String? scoreCache;

  const Qso({required this.uuid, required this.operationUuid, required this.data, this.deleted = false, this.purged = false, this.scoreCache});

  Map<String, dynamic>? get scores {
    if (scoreCache == null) return null;
    try {
      final decoded = jsonDecode(scoreCache!);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> get _our => asQsonMap(data['our']) ?? const {};
  Map<String, dynamic> get _their => asQsonMap(data['their']) ?? const {};

  Map<String, dynamic> get _theirGuess => asQsonMap(_their['guess']) ?? const {};

  String get ourCall => asQsonString(_our['call']) ?? '';

  /// Our own grid at the time of this QSO, when captured — QSON allows the
  /// station to move mid-operation (e.g. a location change across a break),
  /// so consumers like the Map tab prefer this over `Operation.grid` when
  /// present. Nothing in HaLo writes it yet; imports/sync may carry it.
  String? get ourGrid => asQsonString(_our['grid']);

  /// Our exact position at the time of this QSO, when captured — the same
  /// relationship to [ourGrid] that [Operation.location] has to
  /// `Operation.grid`, and the same precedence: where it is set it is what
  /// distance, bearing and the map use. ADIF's `MY_LAT`/`MY_LON` land here on
  /// import.
  GridLocation? get ourExactLocation => locationFromLatLon(_our['lat'], _our['lon']);

  /// Where we were for this QSO as well as the QSO itself knows — its own
  /// coordinate, else the center of its own [ourGrid]. Null when the QSO
  /// records no location of its own, which is the usual case: the operation's
  /// location answers for it then.
  GridLocation? get ourLocation => ourExactLocation ?? gridToLocation(ourGrid);

  /// The locator to show for our end of this QSO — at the operator's
  /// [GridPrecision] when it carries a real coordinate (see
  /// [gridForDisplay]).
  String? get ourDisplayGrid => gridForDisplay(lat: _our['lat'], lon: _our['lon'], grid: ourGrid);

  /// Station Configuration's "Track Station Info for each QSO" — the
  /// transceiver/antenna/CW key display name captured at log time, when the
  /// operator has that field turned on. Null whenever tracking is off, the
  /// field isn't selected, or nothing was designated to capture from.
  String? get ourRig => asQsonString(_our['rig']);
  String? get ourAntenna => asQsonString(_our['antenna']);
  String? get ourKey => asQsonString(_our['key']);

  /// Who was at the key, and in which operating position, when this contact
  /// was made — both empty on a contact made by a plain single-operator
  /// station, which names no operator apart from [ourCall] and sits in no
  /// position. See `operation_operator.dart` for what a position is.
  String get ourOperatorCall => asQsonString(_our['operatorCall']) ?? '';
  String get ourMultiIdentifier => asQsonString(_our['multiIdentifier']) ?? '';

  String get theirCall => asQsonString(_their['call']) ?? '';
  // `guess` (the merged lookup result) stays nested rather than flattened
  // onto `their`,
  // matching lib-qson-tools' `AnnotatedCallInfo` type; a manually
  // entered/edited top-level value always wins over the guess.
  String? get theirName => asQsonString(_their['name']) ?? asQsonString(_theirGuess['name']);
  String? get theirGrid => asQsonString(_their['grid']) ?? asQsonString(_theirGuess['grid']);

  /// The other station's exact position, when something knew one — imported
  /// ADIF `LAT`/`LON`, or a callsign lookup that reported coordinates
  /// (`their.guess.lat`/`.lon`, which QRZ and the Ham2K lookup both fill in).
  ///
  /// An ENTERED grid suppresses a guessed coordinate, rather than the usual
  /// entered-beats-guess coalescing done field by field: an operator who
  /// types `their.grid` is correcting the lookup, and pairing their square
  /// with the lookup's coordinate would put the station back at the address
  /// they just overrode. An entered coordinate still wins over an entered
  /// grid — same precedence as everywhere else.
  ///
  /// A country-file centroid is not a coordinate at either level — see
  /// [locationFromGuess]. A synced QSO carries one on `their` itself, not only
  /// on `their.guess`, so the top-level pair goes through the same rule rather
  /// than being trusted for being top-level.
  GridLocation? get theirExactLocation {
    if (locationFromGuess(_their) case final entered?) return entered;
    if (asQsonString(_their['grid']) != null) return null;
    return locationFromGuess(_theirGuess);
  }

  String? get theirState => asQsonString(_their['state']) ?? asQsonString(_theirGuess['state']);
  // Both set by the callsign-annotation lookup step
  // (`annotateCallsign`) — `entityPrefix` identifies the DXCC entity for the
  // QSO row's DX/domestic column, `flag` is that entity's emoji flag,
  // resolved JS-side (extensions/core/lookups/src/annotate.ts) so Dart
  // doesn't need its own copy of the DXCC entity table.
  String? get theirEntityPrefix => asQsonString(_their['entityPrefix']) ?? asQsonString(_theirGuess['entityPrefix']);
  String? get theirFlag => asQsonString(_their['flag']) ?? asQsonString(_theirGuess['flag']);

  /// The DXCC entity's name and two-letter continent code (`NA`, `EU`…), from
  /// the same callsign annotation — or, for an ADIF import, its COUNTRY and
  /// CONT fields.
  String? get theirEntityName => asQsonString(_their['entityName']) ?? asQsonString(_theirGuess['entityName']);
  String? get theirContinent => asQsonString(_their['continent']) ?? asQsonString(_theirGuess['continent']);

  /// The marker emoji the Callsign Notes lookup reported for this station,
  /// as looked up at logging time — only ever a guess (nothing enters one),
  /// and the FIRST note's marker alone, even when the call appears in
  /// several (`combineNotes` keeps the run across notes in the note text,
  /// not here).
  String? get theirNoteEmoji => asQsonString(_theirGuess['emoji']);
  String? get sentRST => asQsonString(_our['sent']);
  String? get receivedRST => asQsonString(_their['sent']);

  /// The contest/activity exchange the other station sent (QSON `their.exchange`,
  /// alongside their RST) — a serial number, name, zone, etc. HaLo has no
  /// exchange input field yet, so today this is populated only via import/sync
  /// or a lookup guess; the QSO row shows it after the signal reports.
  String? get theirExchange => asQsonString(_their['exchange']) ?? asQsonString(_theirGuess['exchange']);

  /// The exchange we sent (QSON `our.exchange`) — a contest's serial number,
  /// or a serial-plus-grid. Only a contest whose exchange varies per QSO
  /// projects one here (a fixed exchange lives on the operation, not the
  /// QSO); the QSO row shows it ahead of [theirExchange] when present.
  String? get ourExchange => asQsonString(_our['exchange']);

  /// The other station's transmit power in watts — nested under `their`
  /// (unlike [power], which is ours and lives top-level), matching how
  /// `sentRST`/`receivedRST` split. Nothing in HaLo captures this at log
  /// time; the ADIF import target for `RX_PWR` (`adif_to_qson.dart`) is the
  /// only writer today.
  num? get theirPower => asQsonNum(_their['power']);

  /// Whether the value returned for `their[field]` (e.g. `'name'`, `'grid'`,
  /// `'state'`, `'entityPrefix'`, `'flag'`) is coming from the nested `guess`
  /// rather than an entered value — true exactly when the coalescing getters
  /// above fell back to the guess (no top-level value). Callers like the QSO
  /// row use it to render guessed-but-unconfirmed values more faintly.
  bool theirFieldIsGuessed(String field) => asQsonString(_their[field]) == null && asQsonString(_theirGuess[field]) != null;

  double? get freq => asQsonNum(data['freq'])?.toDouble();
  String? get band => asQsonString(data['band']);
  String? get mode => asQsonString(data['mode']);
  String? get notes => asQsonString(data['notes']);

  /// Whether [notes] says anything. A blank note is no note: an edit form
  /// saves its untouched field as `''`.
  bool get hasNotes => (notes ?? '').trim().isNotEmpty;

  /// Our transmit power in watts — top-level, alongside [freq]/[band]/[mode],
  /// matching QSON convention elsewhere in the ecosystem (app-polo) rather
  /// than nesting under `our`. Station Configuration's "Track Station Info
  /// for each QSO" captures it at log time; the ADIF import target for
  /// `TX_PWR` (`adif_to_qson.dart`) writes here too, so an imported QSO may
  /// carry this even when HaLo's own tracking is off.
  ///
  /// A QSO imported by an older build, or synced from a client that never
  /// converted `TX_PWR`, stores this as a raw String, which
  /// [asQsonNum] parses rather than rejecting.
  num? get power => asQsonNum(data['power']);

  int? get startAtMillis => asQsonNum(data['startAtMillis'])?.toInt();
  DateTime? get startAt => startAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(startAtMillis!, isUtc: true);

  /// See `Operation.updatedAtMillis`.
  int? get updatedAtMillis => asQsonNum(data['updatedAtMillis'])?.toInt();

  List<Map<String, dynamic>> get refs =>
      (asQsonList(data['refs']) ?? const []).whereType<Map<dynamic, dynamic>>().map((r) => r.cast<String, dynamic>()).toList();

  /// The QSON key under which a QSO says a contest serial it carries was
  /// also sent by another position (docs/design/contests.md §5.8.1). Set at
  /// commit, kept through edits and sync like any other field; nothing
  /// clears it, since the number that went out cannot be unsent.
  static const serialConflictKey = 'serialConflict';

  /// See [serialConflictKey].
  bool get serialConflict => data[serialConflictKey] == true;

  /// Start/break/end markers ride the QSO timeline as pseudo-QSOs with
  /// `band == 'event'`, same convention as web-lofi/app-polo — see
  /// `event`/`eventKind`. They interleave with real QSOs via `startAtMillis`
  /// and are excluded from scoring, export, and the operation's QSO count.
  bool get isEvent => band == 'event';

  /// Whether this counts as an actual contact for QSO counts/numbering/
  /// per-band/per-mode stats — excludes event markers and soft-deleted QSOs.
  bool get isRealContact => !isEvent && !deleted;

  /// Whether [theirCall] was logged as not fully copied ([isIncompleteCall]).
  /// A real contact still — it counts, numbers and exports — but no scorer
  /// ever sees it (`ScoringService`).
  bool get hasIncompleteCall => qsonHasIncompleteCall(data);

  Map<String, dynamic>? get event => asQsonMap(data['event']);

  /// The event's kind, e.g. `'start'`, `'break'`, `'stop'` (`'end'` in older
  /// rows). Null for real QSOs.
  String? get eventKind => asQsonString(event?['event']);
}

/// Whether a TODO [event] is checked off: `data.done` when it is set, the
/// bare `done` older logs carry only when it is not — app-polo's
/// `event.data?.done ?? event.done`. OR-ing the two instead disagrees with
/// polo on the record polo writes when it unchecks an older TODO (`done:
/// true` left beside `data: {done: false}`), which polo shows open.
bool eventTodoDone(Map<String, dynamic>? event) => (asQsonMap(event?['data'])?['done'] ?? event?['done']) == true;
