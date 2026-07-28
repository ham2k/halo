// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Domain models are thin typed views over QSON maps — the JSON stays the
// source of truth (it is what syncs and what plugins see), the getters just
// give the core and UI a safe way in.

import 'dart:convert';

import 'operation_title.dart';

/// A logging session: one station, one setup, one stretch of time.
class Operation {
  final String uuid;
  final Map<String, dynamic> data;
  final int qsoCount;
  final int? startAtMillisMin;
  final int? startAtMillisMax;
  final bool deleted;
  final bool synced;

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
    this.localData = const {},
  });

  String get stationCall => (data['stationCall'] as String?) ?? '';

  /// The station callsigns this operation was run under, in the order they
  /// were entered. Usually one; several when a multi-operator station logs
  /// everything in a single operation and each call owes its own submission
  /// (app-polo splits the same idea across `stationCall` +
  /// `stationCallPlusArray`; here it is one comma-separated field).
  ///
  /// Always at least one entry — an operation with no callsign at all yields
  /// `['']` rather than an empty list, so callers that fan out over this
  /// still produce their one set of results instead of silently none.
  List<String> get stationCalls {
    final parts = [
      for (final part in stationCall.split(','))
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

  /// The user's own title, entered via the operation details dialog —
  /// distinct from [title], which holds the ref-generated one. Empty when
  /// the user hasn't set one.
  String get userTitle => (data['userTitle'] as String?) ?? '';

  /// The generated title, built from the operation's refs (activity/contest
  /// info) and persisted on save (`ActivitiesView.saveAndClose`,
  /// `app/lib/tools/operation_title.dart`). Empty until the first save after
  /// refs produce a suggestion.
  String get title => (data['title'] as String?) ?? '';
  String? get grid => data['grid'] as String?;

  List<Map<String, dynamic>> get refs =>
      ((data['refs'] as List?) ?? const []).whereType<Map>().map((r) => r.cast<String, dynamic>()).toList();

  /// The ref-derived title/subtitle fragments `OperationTitleService` cached
  /// under `localData['titleSuggestion']` (ham2k/app-halo-dist#174) — device-
  /// local like `scoring`, since it's cheaply regenerable from `refs`. A UI
  /// layer localizes the "for"/"at" prepositions and assembles the final
  /// sentence (this model has no BuildContext to do that itself) — that
  /// assembled result is what gets persisted into [title] on save.
  OperationTitleFragments get titleFragments {
    final cached = localData['titleSuggestion'];
    if (cached is! Map) return const OperationTitleFragments();
    return OperationTitleFragments(
      title: (cached['title'] as String?) ?? '',
      forText: (cached['for'] as String?) ?? '',
      atText: (cached['at'] as String?) ?? '',
      subtitle: (cached['subtitle'] as String?) ?? '',
    );
  }

  DateTime? get startAtMax =>
      startAtMillisMax == null ? null : DateTime.fromMillisecondsSinceEpoch(startAtMillisMax!, isUtc: true);

  /// Falls back to app-polo's older `createdOnMillis` spelling, which
  /// operations synced from a long-lived polo install still carry (polo does
  /// the same on read — `operationsDB.js`). Without the fallback an
  /// operation with no QSOs has no date at all to sort by, so every legacy
  /// empty operation collapses to the bottom of the home list together.
  int? get createdAtMillis => ((data['createdAtMillis'] ?? data['createdOnMillis']) as num?)?.toInt();

  /// Revision stamp, set by the repositories on every local write (app-polo
  /// convention: it lives in the QSON so it round-trips through sync). Same
  /// legacy fallback as [createdAtMillis] — this one decides which side of a
  /// sync merge wins, so a null would make a legacy record look revision-less.
  int? get updatedAtMillis => ((data['updatedAtMillis'] ?? data['updatedOnMillis']) as num?)?.toInt();
}

/// One contact. QSON shape (same as app-polo):
/// `{our: {call, sent}, their: {call, sent}, freq, band, mode,
///   startAtMillis, notes, refs: [...]}`
class Qso {
  final String uuid;
  final String operationUuid;
  final Map<String, dynamic> data;
  final bool deleted;

  /// Cached scoring results (DESIGN.md §4: the `scoring` hook runs batched
  /// and caches its per-QSO verdicts here, keyed by rule — e.g. `dupe`,
  /// `dxcc`, `bandsAndModes` — so list rendering never waits on the JS
  /// runtime). `null` until `ScoringService` has scored this operation.
  final String? scoreCache;

  const Qso({
    required this.uuid,
    required this.operationUuid,
    required this.data,
    this.deleted = false,
    this.scoreCache,
  });

  Map<String, dynamic>? get scores {
    if (scoreCache == null) return null;
    try {
      final decoded = jsonDecode(scoreCache!);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> get _our => (data['our'] as Map<String, dynamic>?) ?? const {};
  Map<String, dynamic> get _their => (data['their'] as Map<String, dynamic>?) ?? const {};

  Map<String, dynamic> get _theirGuess => (_their['guess'] as Map<String, dynamic>?) ?? const {};

  String get ourCall => (_our['call'] as String?) ?? '';

  /// Our own grid at the time of this QSO, when captured — QSON allows the
  /// station to move mid-operation (e.g. a location change across a break),
  /// so consumers like the Map tab prefer this over `Operation.grid` when
  /// present. Nothing in HaLo writes it yet; imports/sync may carry it.
  String? get ourGrid => _our['grid'] as String?;

  String get theirCall => (_their['call'] as String?) ?? '';
  // `guess` (the merged lookup result — see the Lookups feature,
  // ham2k/app-halo-dist#8) stays nested rather than flattened onto `their`,
  // matching lib-qson-tools' `AnnotatedCallInfo` type; a manually
  // entered/edited top-level value always wins over the guess.
  String? get theirName => (_their['name'] as String?) ?? (_theirGuess['name'] as String?);
  String? get theirGrid => (_their['grid'] as String?) ?? (_theirGuess['grid'] as String?);
  String? get theirState => (_their['state'] as String?) ?? (_theirGuess['state'] as String?);
  // Both set by the callsign-annotation lookup step (ham2k/app-halo-dist#8's
  // `annotateCallsign`) — `entityPrefix` identifies the DXCC entity for the
  // QSO row's DX/domestic column, `flag` is that entity's emoji flag,
  // resolved JS-side (extensions/core/lookups/src/annotate.ts) so Dart
  // doesn't need its own copy of the DXCC entity table.
  String? get theirEntityPrefix => (_their['entityPrefix'] as String?) ?? (_theirGuess['entityPrefix'] as String?);
  String? get theirFlag => (_their['flag'] as String?) ?? (_theirGuess['flag'] as String?);
  String? get sentRST => _our['sent'] as String?;
  String? get receivedRST => _their['sent'] as String?;

  /// The contest/activity exchange the other station sent (QSON `their.exchange`,
  /// alongside their RST) — a serial number, name, zone, etc. HaLo has no
  /// exchange input field yet, so today this is populated only via import/sync
  /// or a lookup guess; the QSO row shows it after the signal reports (#354).
  String? get theirExchange => (_their['exchange'] as String?) ?? (_theirGuess['exchange'] as String?);

  /// Whether the value returned for `their[field]` (e.g. `'name'`, `'grid'`,
  /// `'state'`, `'entityPrefix'`, `'flag'`) is coming from the nested `guess`
  /// rather than an entered value — true exactly when the coalescing getters
  /// above fell back to the guess (no top-level value). Callers like the QSO
  /// row use it to render guessed-but-unconfirmed values more faintly.
  bool theirFieldIsGuessed(String field) => _their[field] == null && _theirGuess[field] != null;

  double? get freq => (data['freq'] as num?)?.toDouble();
  String? get band => data['band'] as String?;
  String? get mode => data['mode'] as String?;
  String? get notes => data['notes'] as String?;

  int? get startAtMillis => (data['startAtMillis'] as num?)?.toInt();
  DateTime? get startAt =>
      startAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(startAtMillis!, isUtc: true);

  /// See `Operation.updatedAtMillis`.
  int? get updatedAtMillis => (data['updatedAtMillis'] as num?)?.toInt();

  List<Map<String, dynamic>> get refs =>
      ((data['refs'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

  /// Start/break/end markers ride the QSO timeline as pseudo-QSOs with
  /// `band == 'event'`, same convention as web-lofi/app-polo — see
  /// `event`/`eventKind`. They interleave with real QSOs via `startAtMillis`
  /// and are excluded from scoring, export, and the operation's QSO count.
  bool get isEvent => band == 'event';

  /// Whether this counts as an actual contact for QSO counts/numbering/
  /// per-band/per-mode stats — excludes event markers and soft-deleted QSOs.
  bool get isRealContact => !isEvent && !deleted;

  Map<String, dynamic>? get event => data['event'] as Map<String, dynamic>?;

  /// The event's kind, e.g. `'start'`, `'break'`, `'end'`. Null for real QSOs.
  String? get eventKind => event?['event'] as String?;
}
