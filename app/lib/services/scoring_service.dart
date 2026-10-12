// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Scoring flow: the extension runtime scores every QSO in an operation in
// one coarse batched call (DESIGN.md §4: "score 500 QSOs in one call, not
// 500 calls"). The core writes the per-QSO verdicts into `qsos.score_cache`
// and the day/operation summaries into `operations.local_data`, so list
// scroll and score displays both read from SQLite and never wait on the JS
// runtime.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'error_reporting_service.dart';
import 'extensions/extension_scoring.dart';
import 'extensions/extension_service.dart';
import 'hook_payloads.dart';

/// Decides whether the checkpoints a rescore cached can stand in for the log
/// on the live path, and what has to be replayed onto them. Null means a cold
/// fold: the caller sends nothing and the scorers read the whole log.
///
/// The rule has to be provable, because a checkpoint resumed without the
/// contacts it is missing calls the contact just logged "not a duplicate" —
/// silent, and wrong at exactly the moment the operator is typing the next
/// call. The checkpoint records the newest stamp among the rows it folded
/// and a digest of them ([checkpointDigestOf]: every uuid with its stamp); a
/// resume is offered only when the rows still stamped at or before that
/// newest stamp digest to the same value. Every contact stamped after it is
/// then something the checkpoint never saw, and is replayed as the tail. The
/// digest is the proof: an edit changes a folded contact's stamp, a delete
/// removes one, and either changes the digest so the fold runs cold — a
/// checkpoint cannot un-fold a contact. That holds for a synced edit too: a
/// peer's correction can land carrying a stamp OLDER than the newest one here
/// (its clock, or contacts logged here meanwhile), which a count alone would
/// read as still folded. An undelete replays, which is right: it was not in
/// the log the checkpoint folded. The contact being edited ([excludeUuid]) is
/// the same case as an edit — already inside the sheet — and also folds cold.
///
/// The fold is also a fold OF SOMETHING: the operation as it stood, and the
/// segment markers that shaped its timeline (docs/design/contests.md §5.1.3).
/// The checkpoint carries the operation's own stamp, so a saved change to it
/// — a reference corrected, an exchange edited — folds cold rather than
/// judging the next call under the old reference; and the event rows go into
/// the digest and never into the tail, so a marker added or edited since
/// folds cold too, where a sheet folded under the old timeline would be
/// handed the new one.
///
/// The tail must also come AFTER what the checkpoint folded in log order: a
/// contact entered with a manual time earlier than the checkpoint's last folds
/// cold, because the batch pass folds chronologically and a replay cannot.
///
/// A tail goes only to a scorer whose harness will fold it. A bundle built on
/// an SDK from before the tail existed resumes from the checkpoint and ignores
/// `qsos` — the contact just logged then reads as "not a duplicate", the one
/// failure this exists to prevent — and a third-party extension may stay on
/// that SDK indefinitely. The day beside the sheet (`scoresheetDay`) is what
/// only a tail-aware harness ever returns, so a checkpoint without one is
/// resumed only when there is nothing to replay.
///
/// [qsos] is the list the view holds, deleted rows and event markers included;
/// only real contacts are counted, as the rescore counts them. A contact with
/// no stamp cannot be placed and folds cold. The proof is against that list,
/// not the database the cold fold reads: a contact the stream has not yet
/// re-emitted (its decode still running on a long log) is invisible here for
/// that long, and a checkpoint resumed in that window does not know it. The
/// keystroke debounce is what covers the gap, not this rule.
ScoringResume? resolveScoringResume({
  required Map<String, dynamic>? scoring,
  required int? operationUpdatedAtMillis,
  required List<Qso> qsos,
  String? excludeUuid,
}) {
  if (scoring == null || scoring.isEmpty || excludeUuid != null) return null;

  final sheets = <String, ({Object sheet, int? day})>{};
  Map<String, dynamic>? stamp;
  for (final entry in scoring.entries) {
    final cached = entry.value;
    if (cached is! Map) continue;
    final sheet = cached['scoresheet'];
    final day = cached['scoresheetDay'];
    final cachedStamp = cached['checkpoint'];
    if (sheet == null || cachedStamp is! Map) continue;
    // One pass writes every entry, so their stamps agree; a disagreement means
    // a shape this code does not know, and a cold fold is the safe reading.
    final asMap = cachedStamp.cast<String, dynamic>();
    if (stamp != null && !mapEquals(stamp, asMap)) return null;
    stamp = asMap;
    sheets[entry.key] = (sheet: sheet, day: day is num ? day.toInt() : null);
  }
  final digest = stamp?['digest'];
  final stampedAt = stamp?['updatedAtMillis'];
  final lastStartAt = stamp?['startAtMillis'];
  if (sheets.isEmpty || digest is! int || stampedAt is! int || lastStartAt is! int) return null;
  if (stamp?['operationUpdatedAtMillis'] != operationUpdatedAtMillis) return null;
  // One name for every scorer's checkpoint: a pass writes them all at once.
  final key = checkpointKeyOf(stamp!);
  final checkpoints = <String, ScoringCheckpoint>{for (final entry in sheets.entries) entry.key: (sheet: entry.value.sheet, day: entry.value.day, key: key)};

  final tail = <Map<String, dynamic>>[];
  if (qsos is QsoLog) {
    // The tail is at the end in log order, so it is found from the end: back
    // over the rows stamped after the checkpoint, stopping at the first one
    // stamped at or before it. Behind that row the digest is the only proof:
    // the log carries its digest, and the folded rows' is what is left once
    // the tail's terms leave it, so a row edited, added or removed anywhere
    // earlier moves it and folds cold — with one exception the digest cannot
    // see, a row with no stamp, whose term stays put when its content moves.
    // The log counts those, and one anywhere folds cold, as it does below.
    if (qsos.unstamped > 0) return null;
    var foldedDigest = qsos.digest;
    for (var i = qsos.length - 1; i >= 0; i--) {
      final qso = qsos[i];
      if (qso.deleted) continue;
      final updatedAt = qso.updatedAtMillis!;
      if (updatedAt <= stampedAt) break;
      if (qso.isEvent) return null;
      if ((qso.startAtMillis ?? 0) <= lastStartAt) return null;
      tail.add(qso.data);
      foldedDigest -= qsoDigestTerm(qso);
    }
    if (foldedDigest != digest) return null;
    // Collected newest first; replayed oldest first.
    for (var i = 0, j = tail.length - 1; i < j; i++, j--) {
      final swap = tail[i];
      tail[i] = tail[j];
      tail[j] = swap;
    }
  } else {
    // The same verdict as above, walked forward: the tail is the suffix of
    // rows stamped after the checkpoint, so a folded row past the first tail
    // row — a marker timed after a contact logged with an earlier manual
    // time — makes the tail no suffix, and the checkpoint cannot replay it
    // in the order the batch pass folds.
    final folded = <Qso>[];
    for (final qso in qsos) {
      if (qso.deleted) continue;
      final updatedAt = qso.updatedAtMillis;
      if (updatedAt == null) return null;
      if (updatedAt <= stampedAt) {
        if (tail.isNotEmpty) return null;
        folded.add(qso);
      } else if (qso.isEvent) {
        return null;
      } else {
        if ((qso.startAtMillis ?? 0) <= lastStartAt) return null;
        tail.add(qso.data);
      }
    }
    if (qsoLogDigestOf(folded) != digest) return null;
  }
  if (tail.isNotEmpty) checkpoints.removeWhere((_, checkpoint) => checkpoint.day == null);
  if (checkpoints.isEmpty) return null;
  return (checkpoints: checkpoints, tail: tail);
}

/// The name a checkpoint is held under in the runtime, from its stamp — every
/// field of it, so two sheets of one operation never share a name, not even
/// the same log folded under an edited operation. The pass that produces a
/// checkpoint names it (`checkpointKey`) and every resume names the same
/// (`resumeKey`), so the two sides agree without exchanging anything.
String checkpointKeyOf(Map<String, dynamic> stamp) =>
    '${stamp['digest']}:${stamp['updatedAtMillis']}:${stamp['startAtMillis']}:${stamp['operationUpdatedAtMillis']}';

/// The identity of a folded log for a checkpoint's stamp: every row's uuid
/// with its stamp, combined so that order does not matter. Not a secure hash —
/// it only has to notice a stamp that moved or a contact that came or went.
/// Each term and the sum stay under 2^53 so the web build's integers carry
/// them.
///
/// A [QsoLog] carries this very digest, maintained by the log stream as it
/// patches the list, so one is read in a step rather than walked: the
/// Operation View fingerprints the log by it on every emission and every
/// build. Anything else is walked, deleted rows left out as a log's are.
int checkpointDigestOf(Iterable<Qso> rows) => rows is QsoLog ? rows.digest : qsoLogDigestOf(rows);

/// The day sections after a pass resumed from a checkpoint: [cached] is what
/// the checkpoint's pass left, [fresh] what the tail's pass returned.
///
/// A resumed pass folds only the tail, so it reports sections for the tail's
/// days alone, and the harness counts a day's contacts from the tail's first
/// (`DayScoreSummary.count`). The scorer's own tallies in `scores` continue
/// the checkpoint and are whole; the count beside them is not. So a day the
/// tail continues keeps the fresh tallies and SUMS the two counts, a day the
/// tail opened is appended, and every earlier day stays as it was. Days come
/// back ascending, which is the order a full pass produces them in.
List<Map<String, dynamic>> mergeDaySections(List<dynamic>? cached, List<dynamic>? fresh) {
  final byDay = <int, Map<String, dynamic>>{};
  for (final section in (cached ?? const []).whereType<Map<dynamic, dynamic>>()) {
    final day = (section['day'] as num?)?.toInt();
    if (day != null) byDay[day] = section.cast<String, dynamic>();
  }
  for (final section in (fresh ?? const []).whereType<Map<dynamic, dynamic>>()) {
    final day = (section['day'] as num?)?.toInt();
    if (day == null) continue;
    final previous = byDay[day];
    final count = ((section['count'] as num?)?.toInt() ?? 0) + ((previous?['count'] as num?)?.toInt() ?? 0);
    byDay[day] = {...section.cast<String, dynamic>(), 'count': count};
  }
  final days = byDay.keys.toList()..sort();
  return [for (final day in days) byDay[day]!];
}

class ScoringService {
  final ExtensionService extensions;
  final QsosRepository qsos;
  final OperationsRepository operations;

  /// The operations whose whole log THIS runtime has folded and written,
  /// each with the host that folded it. A pass or a live path may resume from
  /// a cached checkpoint only for one of these, and only while that host is
  /// still the one answering ([_foldedByCurrentHost]): a checkpoint from an
  /// earlier launch, or from before an extension was installed, updated or
  /// switched off, was written by a scorer that may no longer exist or no
  /// longer agree, and resuming from it would carry its verdicts forward with
  /// no error anywhere (docs/design/contests.md §5.1.2). Added only once a
  /// full pass has WRITTEN, by the host it started under — a pass that found
  /// no scorer, an empty log or a failing runtime spends nothing — and
  /// cleared whenever the runtime generation ticks.
  ///
  /// The host is what closes the gap the generation alone leaves: a new
  /// runtime answers hooks while its extensions activate, before the
  /// generation ticks, and a pass whose results came from the old runtime can
  /// finish writing after the tick.
  final _foldedBy = <String, ExtensionHost>{};

  /// The pass in flight per operation. A second request queues behind it and
  /// reads the operation afresh when its turn comes, so it continues the
  /// write it waited for: two passes reading the same stale checkpoint and
  /// racing to write would let the slower one persist a sheet the other had
  /// already superseded.
  final _inFlight = <String, Future<void>>{};

  ScoringService({required this.extensions, required this.qsos, required this.operations}) {
    extensions.runtimeGeneration.addListener(_onRuntimeGenerationChanged);
  }

  void _onRuntimeGenerationChanged() => _foldedBy.clear();

  bool _foldedByCurrentHost(String uuid) {
    final host = extensions.host;
    return host != null && identical(_foldedBy[uuid], host);
  }

  /// [resolveScoringResume] for the live paths — the call-info pills and the
  /// spots board — under the guard a pass uses: only for an operation whose
  /// whole log the current runtime has folded ([_foldedBy]). Without it, a scorer
  /// just installed or updated is handed a checkpoint its predecessor wrote,
  /// one it may not read or no longer agrees with. Null folds cold, which is
  /// slower and always right.
  ScoringResume? liveResumeFor(Operation operation, List<Qso> qsos, {String? excludeUuid}) {
    if (!_foldedByCurrentHost(operation.uuid)) return null;
    return resolveScoringResume(
      scoring: operation.localData['scoring'] as Map<String, dynamic>?,
      operationUpdatedAtMillis: operation.updatedAtMillis,
      qsos: qsos,
      excludeUuid: excludeUuid,
    );
  }

  /// Scores the QSOs logged for the operation [operation] names and caches
  /// the results. Degrades silently if the extension runtime isn't ready or
  /// the hook call fails — scoring is a display enhancement, never
  /// load-bearing, so callers don't need to handle a thrown error.
  ///
  /// A pass folds the whole log only when it has to. When the log is exactly
  /// what the cached checkpoints folded plus appended contacts
  /// ([resolveScoringResume], the one rule the live paths use too), every
  /// scorer gets its checkpoint and just those contacts to replay, and only
  /// their verdicts are written: a fold is forward-only, so an append never
  /// changes an earlier contact's verdict. The whole log goes over when the
  /// rule says cold; when this runtime has not yet folded the operation in
  /// full ([_foldedBy]); when a scorer the log just started needing has no
  /// checkpoint, or one fails on the tail — a pass writes every scorer's
  /// verdict for a contact together, and a contact carrying half of them
  /// would render without the rest; when there is nothing to replay although
  /// something moved (a stamp the rule cannot see); and when the caller asks
  /// with [full].
  ///
  /// The operation is read afresh when the pass runs, not taken from the
  /// caller's copy: the caller's may predate a pass that just wrote.
  Future<void> rescoreOperation(Operation operation, {bool full = false}) {
    final uuid = operation.uuid;
    final previous = _inFlight[uuid] ?? Future<void>.value();
    final next = previous.then((_) => _run(uuid, full: full));
    _inFlight[uuid] = next;
    // A block body, deliberately: `whenComplete` waits on a future its
    // callback returns, and `Map.remove` returns the very future being
    // completed.
    return next.whenComplete(() {
      if (identical(_inFlight[uuid], next)) _inFlight.remove(uuid);
    });
  }

  Future<void> _run(String uuid, {required bool full}) async {
    final host = extensions.host;
    if (host == null) return;
    final operation = await operations.get(uuid);
    if (operation == null) return;

    final all = await qsos.forOperation(operation.uuid);
    final qsoList = all.where((q) => !q.isEvent).toList();

    // The activities this log HUNTS, which the operation's own refs never name
    // — a chaser activates nothing (docs/design/activities.md §4). Written
    // before any of the early returns below, and from an empty log as an empty
    // list: the live paths select their scorers from this, so a stale entry
    // makes them invoke a scorer for a program the log no longer contains,
    // paying a whole-log fold per pass to be told nothing.
    //
    // ONLY when it actually changes. Every `local_data` write pushes an event
    // down the operation stream and rebuilds the Operation View; an
    // unconditional one per rescore is a rebuild per rescore that tells the UI
    // nothing, and the value moves perhaps once in an operation's life.
    final huntedRefTypes = ExtensionService.huntedRefTypesOf(qsoList);
    // Where this pass's checkpoints end, for [resolveScoringResume]: the newest
    // stamp among the rows they fold (the event markers included, since the
    // timeline is part of the fold), a digest of those rows, the time of the
    // last contact in log order, and the operation's own stamp. Taken from the
    // very list the scorers are about to fold, never re-read.
    var newestStamp = 0;
    var lastStartAt = 0;
    for (final qso in all) {
      final at = qso.updatedAtMillis ?? 0;
      if (at > newestStamp) newestStamp = at;
      if (qso.isEvent) continue;
      final startAt = qso.startAtMillis ?? 0;
      if (startAt > lastStartAt) lastStartAt = startAt;
    }
    final checkpoint = {
      'digest': checkpointDigestOf(all),
      'updatedAtMillis': newestStamp,
      'startAtMillis': lastStartAt,
      'operationUpdatedAtMillis': operation.updatedAtMillis,
    };
    final cached = ((operation.localData['huntedRefTypes'] as List?) ?? const []).whereType<String>().toSet();
    if (!setEquals(cached, huntedRefTypes)) {
      await operations.updateLocalData(operation.uuid, {'huntedRefTypes': huntedRefTypes.toList()..sort()});
    }

    if (qsoList.isEmpty) return;

    // Resolved from the FULL list — the event rows carrying the segment
    // overrides are exactly what `qsoList` just filtered out
    // (docs/design/contests.md §5.1.3).
    final segmented = SegmentedOperation.from(operation: operation.data, qsos: all);

    try {
      // Only the scorers this operation actually needs: `always` scorers (core
      // dupe/DXCC/bands) plus any whose declared refTypes match a ref on the
      // operation. A user with dozens of extensions enabled never pays for the
      // ones this operation doesn't reference (docs/design/contests.md §5.1).
      final scopes = await extensions.getScoringScopes();
      final scorers = ExtensionService.scorersFor(operation.data, scopes, segments: segmented, alsoRefTypes: huntedRefTypes);
      if (scorers.isEmpty) return;

      final cachedScoring = operation.localData['scoring'] as Map<String, dynamic>?;
      final resume = full || !_foldedByCurrentHost(uuid)
          ? null
          : resolveScoringResume(scoring: cachedScoring, operationUpdatedAtMillis: operation.updatedAtMillis, qsos: all);
      final append = resume != null && resume.tail.isNotEmpty && scorers.every((scorer) => resume.checkpoints.containsKey(scorer.key));

      final payload = {
        ...qsonPayloadFor(operation: operation, qsos: append ? const [] : qsoList),
        if (append) 'qsos': resume.tail,
        // The runtime keeps this pass's end sheet under this name, so the live
        // paths can name it rather than send it back on every keystroke.
        'checkpointKey': checkpointKeyOf(checkpoint),
        // Only when there is something to resolve — an unsegmented operation
        // sends nothing extra and the harness takes its existing path.
        if (segmented.isSegmented) 'segments': segmented.payload,
      };

      // Independent per-scorer calls — a contest scorer that throws must not
      // cost the operation its core scoring, so each result is collected on its
      // own and a failed one is simply absent below.
      final results = await Future.wait(
        scorers.map((scorer) async {
          final resumedFrom = append ? resume.checkpoints[scorer.key] : null;
          final result = await extensions.scoreQsos(
            scorerKey: scorer.key,
            args: {...payload, 'ref': ?scorer.ref, 'resumeKey': ?resumedFrom?.key, 'resumeFrom': ?resumedFrom?.sheet, 'resumeDay': ?resumedFrom?.day},
          );
          return (key: scorer.key, fallback: scorer.fallback, scorer: scorer, result: result);
        }),
      );
      // On a full pass a scorer that failed is absent from every contact
      // alike; on a tail it would be absent from the newest contact alone.
      if (append && results.any((entry) => entry.result == null)) return _run(uuid, full: true);

      // Per-QSO verdicts are namespaced by scorer — `{core: {...}, cqww: {...}}`
      // — so several scorers can annotate the same QSO without colliding.
      final scoresByUuid = <String, Map<String, dynamic>>{};
      final scoringByScorer = <String, dynamic>{};
      // A fallback scorer's verdicts are held back per QSO: on a contact
      // another scorer has judged on the worked-before axis, only what it says
      // apart from that is written (see [Scorer],
      // [ExtensionService.judgesWorkedBefore]). Per QSO rather than per
      // operation because a contest skips whole SEGMENTS it wasn't running for,
      // and those contacts still need core's dupe rule.
      final fallbackScores = <String, Map<String, dynamic>>{};
      final judgedByOther = <String>{};
      // Built only if a hunt-only scorer's verdicts are read (see
      // [judgedVerdicts]).
      late final refsByUuid = {
        for (final qso in qsoList) qso.uuid: {'refs': qso.refs},
      };

      for (final entry in results) {
        final result = entry.result;
        if (result == null) continue;

        final qsoScores = judgedVerdicts(entry.scorer, scopes[entry.key], (result['qsoScores'] as Map?) ?? const {}, (uuid) => refsByUuid[uuid]);
        for (final score in qsoScores.entries) {
          // A verdict that isn't a map is one this scorer never made: the live
          // paths read it the same way, and the three must agree about which
          // QSOs a scorer has spoken for.
          if (score.key is! String || score.value is! Map) continue;
          final uuid = score.key as String;
          final verdict = (score.value as Map).cast<String, dynamic>();
          if (entry.fallback) {
            (fallbackScores[uuid] ??= <String, dynamic>{})[entry.key] = verdict;
          } else {
            if (judgesWorkedBefore(verdict)) judgedByOther.add(uuid);
            (scoresByUuid[uuid] ??= <String, dynamic>{})[entry.key] = verdict;
          }
        }
        scoringByScorer[entry.key] = {
          'daySections': append
              ? mergeDaySections((cachedScoring?[entry.key] as Map?)?['daySections'] as List?, result['daySections'] as List?)
              : result['daySections'],
          'operationSummary': result['operationSummary'],
          // The end-of-log checkpoint, kept so a later append and the live paths
          // can resume from it instead of re-folding the whole log — and the
          // stamp that says which log it folded, without which no caller can
          // tell a current checkpoint from a stale one.
          'scoresheet': result['scoresheet'],
          'scoresheetDay': ?result['scoresheetDay'],
          'checkpoint': checkpoint,
        };
      }
      if (scoringByScorer.isEmpty) return;

      for (final entry in fallbackScores.entries) {
        final judged = judgedByOther.contains(entry.key);
        for (final verdict in entry.value.entries) {
          final value = judged ? withoutWorkedBefore(verdict.value as Map) : verdict.value;
          if (value == null) continue;
          (scoresByUuid[entry.key] ??= <String, dynamic>{})[verdict.key] = value;
        }
      }

      await qsos.updateScoreCache(operation.uuid, {for (final entry in scoresByUuid.entries) entry.key: jsonEncode(entry.value)});
      await operations.updateLocalData(operation.uuid, {'scoring': scoringByScorer});
      if (!append) _foldedBy[uuid] = host;
    } catch (e, st) {
      debugPrint('[scoring] rescoreOperation failed: $e');
      ErrorReportingService.report(e, st, context: 'scoring:rescore-operation');
    }
  }
}
