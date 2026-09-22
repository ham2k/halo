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
import 'extension_scoring.dart';
import 'extension_service.dart';

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

  final checkpoints = <String, ScoringCheckpoint>{};
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
    checkpoints[entry.key] = (sheet: sheet, day: day is num ? day.toInt() : null);
  }
  final digest = stamp?['digest'];
  final stampedAt = stamp?['updatedAtMillis'];
  final lastStartAt = stamp?['startAtMillis'];
  if (checkpoints.isEmpty || digest is! int || stampedAt is! int || lastStartAt is! int) return null;
  if (stamp?['operationUpdatedAtMillis'] != operationUpdatedAtMillis) return null;

  final tail = <Map<String, dynamic>>[];
  final folded = <Qso>[];
  for (final qso in qsos) {
    if (qso.deleted) continue;
    final updatedAt = qso.updatedAtMillis;
    if (updatedAt == null) return null;
    if (updatedAt <= stampedAt) {
      folded.add(qso);
    } else if (qso.isEvent) {
      return null;
    } else {
      if ((qso.startAtMillis ?? 0) <= lastStartAt) return null;
      tail.add(qso.data);
    }
  }
  if (checkpointDigestOf(folded) != digest) return null;
  if (tail.isNotEmpty) checkpoints.removeWhere((_, checkpoint) => checkpoint.day == null);
  if (checkpoints.isEmpty) return null;
  return (checkpoints: checkpoints, tail: tail);
}

/// The identity of a folded log for a checkpoint's stamp: every row's uuid
/// with its stamp, combined so that order does not matter. Not a secure hash —
/// it only has to notice a stamp that moved or a contact that came or went.
/// Built by hand rather than with `Object.hash`, whose seed changes per run:
/// the stamp is persisted, and a digest that never matched after a relaunch
/// would fold every keystroke cold until the first rescore. Each term and the
/// sum stay under 2^53 so the web build's integers carry them.
int checkpointDigestOf(Iterable<Qso> rows) {
  var digest = 0;
  for (final qso in rows) {
    digest += ((qso.uuid.hashCode & 0xFFFFFFFF) * 31 + (qso.updatedAtMillis ?? 0)) & 0xFFFFFFFF;
  }
  return digest;
}

class ScoringService {
  final ExtensionService extensions;
  final QsosRepository qsos;
  final OperationsRepository operations;

  ScoringService({required this.extensions, required this.qsos, required this.operations});

  /// Scores every QSO currently logged for [operation] and caches the
  /// results. Degrades silently if the extension runtime isn't ready or the
  /// hook call fails — scoring is a display enhancement, never load-bearing,
  /// so callers don't need to handle a thrown error.
  Future<void> rescoreOperation(Operation operation) async {
    final host = extensions.host;
    if (host == null) return;

    final all = await qsos.watchForOperation(operation.uuid).first;
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
      final scorers = ExtensionService.scorersFor(
        operation.data,
        scopes,
        segments: segmented,
        alsoRefTypes: huntedRefTypes,
      );
      if (scorers.isEmpty) return;

      final payload = {
        ...qsonPayloadFor(operation: operation, qsos: qsoList),
        // Only when there is something to resolve — an unsegmented operation
        // sends nothing extra and the harness takes its existing path.
        if (segmented.isSegmented) 'segments': segmented.payload,
      };

      // Independent per-scorer calls — a contest scorer that throws must not
      // cost the operation its core scoring, so each result is collected on its
      // own and a failed one is simply absent below.
      final results = await Future.wait(scorers.map((scorer) async {
        final result = await extensions.scoreQsos(
          scorerKey: scorer.key,
          args: {...payload, 'ref': ?scorer.ref},
        );
        return (key: scorer.key, fallback: scorer.fallback, result: result);
      }));

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

      for (final entry in results) {
        final result = entry.result;
        if (result == null) continue;

        final qsoScores = (result['qsoScores'] as Map?) ?? const {};
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
          'daySections': result['daySections'],
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
          final value = judged
              ? withoutWorkedBefore(verdict.value as Map)
              : verdict.value;
          if (value == null) continue;
          (scoresByUuid[entry.key] ??= <String, dynamic>{})[verdict.key] = value;
        }
      }

      await qsos.updateScoreCache({
        for (final entry in scoresByUuid.entries) entry.key: jsonEncode(entry.value),
      });
      await operations.updateLocalData(operation.uuid, {'scoring': scoringByScorer});
    } catch (e, st) {
      debugPrint('[scoring] rescoreOperation failed: $e');
      ErrorReportingService.report(e, st, context: 'scoring:rescore-operation');
    }
  }
}
