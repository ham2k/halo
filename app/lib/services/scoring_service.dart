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

import 'error_reporting_service.dart';
import 'extension_service.dart';

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
        return (key: scorer.key, result: result);
      }));

      // Per-QSO verdicts are namespaced by scorer — `{core: {...}, cqww: {...}}`
      // — so several scorers can annotate the same QSO without colliding.
      final scoresByUuid = <String, Map<String, dynamic>>{};
      final scoringByScorer = <String, dynamic>{};

      for (final entry in results) {
        final result = entry.result;
        if (result == null) continue;

        final qsoScores = (result['qsoScores'] as Map?) ?? const {};
        for (final score in qsoScores.entries) {
          (scoresByUuid[score.key as String] ??= <String, dynamic>{})[entry.key] = score.value;
        }
        scoringByScorer[entry.key] = {
          'daySections': result['daySections'],
          'operationSummary': result['operationSummary'],
          // The end-of-log scoresheet, kept so a later append can resume from it
          // instead of re-folding the whole log.
          'scoresheet': result['scoresheet'],
        };
      }
      if (scoringByScorer.isEmpty) return;

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
