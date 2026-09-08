// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Scoring an operation the way the APP scores it: the scorers its refs and its
// log actually call for, and their per-QSO verdicts merged by the shared
// priority rules (docs/design/contests.md §5.1).
//
// Lives here rather than in the command because this is the part worth a test
// against a real runtime — the command around it is argument shuffling. This
// is the tool an operator is pointed at when the app's scoring looks wrong, so
// a CLI that selected or merged differently would describe a program that
// isn't the one running.

import 'package:halo_core/halo_core.dart' show Qso, SegmentedOperation, asQsonBool;
import 'package:halo_extension_host/halo_extension_host.dart';

import 'runtime.dart' show CliUsageError;

/// The operation's segments, resolved from the `break`/`start` rows in [qsos] —
/// the same resolution `ScoringService` does, from the plain maps a QSON file
/// carries rather than from database rows.
SegmentedOperation segmentedOperationOf(
  Map<String, Object?> operation,
  List<Map<String, Object?>> qsos,
) =>
    SegmentedOperation.from(operation: operation.cast<String, dynamic>(), qsos: qsosOf(operation, qsos));

/// [qsos] as the model the segment resolver and the ref readers expect.
List<Qso> qsosOf(Map<String, Object?> operation, List<Map<String, Object?>> qsos) => [
      for (final (index, qso) in qsos.indexed)
        Qso(
          uuid: (qso['uuid'] as String?) ?? 'qso-$index',
          operationUuid: (operation['uuid'] as String?) ?? 'op',
          // `deleted` is a column, not something `data` carries, so a file that
          // spells it out has to be read here: a deleted `break` row that still
          // opened a segment would give this tool boundaries the app never sees.
          // Coerced, because a file exported from polo or dumped from LoFi
          // spells the flag as the integer 1 (see [asQsonBool]).
          deleted: asQsonBool(qso['deleted']),
          data: qso.cast<String, dynamic>(),
        ),
    ];

/// The segment payload a scorer is handed, or null for an unsegmented log —
/// the harness treats a one-entry timeline as no timeline at all, so sending
/// one is pure payload.
List<Map<String, dynamic>>? segmentsOf(
  Map<String, Object?> operation,
  List<Map<String, Object?>> qsos,
) {
  final asQsos = qsosOf(operation, qsos);
  final segmented = SegmentedOperation.from(
    operation: operation.cast<String, dynamic>(),
    qsos: asQsos,
  );
  return segmented.isSegmented ? segmented.payload : null;
}

/// One scorer's `scoreQsos`, checked into the shape the report slices.
Future<Map<String, Object?>> scoreWithOneScorer(
  ExtensionHost host, {
  required String key,
  required Map<String, Object?> operation,
  required List<Map<String, Object?>> qsos,
  Object? ref,
  List<Map<String, dynamic>>? segments,
  Map<String, Object?> extraArgs = const {},
  Duration timeout = const Duration(seconds: 30),
}) async {
  final result = await host.invokeHook(
    'scoring',
    key: key,
    method: 'scoreQsos',
    args: {
      'operation': operation,
      'qsos': qsos,
      'ref': ?ref,
      'segments': ?segments,
      ...extraArgs,
    },
    timeout: timeout,
  );
  if (result is! Map) {
    // A scorer that answers with something else is a bug in that scorer, and
    // slicing `null` for a part would report it as an empty score.
    throw CliUsageError('scoring/$key returned ${result.runtimeType}, not a result object');
  }
  return result.cast<String, Object?>();
}

/// Every scorer this operation needs, keyed by scorer, each with its own
/// summaries — and per-QSO verdicts in which a fallback scorer's worked-before
/// judgement has yielded to any scorer that RULED on the same contact.
///
/// Empty when no scorer applies at all, which is not the same as a scorer
/// having nothing to say.
Future<Map<String, Map<String, Object?>>> scoreOperation(
  ExtensionHost host, {
  required Map<String, Object?> operation,
  required List<Map<String, Object?>> qsos,
  Map<String, Object?> extraArgs = const {},
  Duration timeout = const Duration(seconds: 30),
}) async {
  final scopes = {
    for (final entry in await host.invokeHookAll('scoring',
        method: 'scope', args: extraArgs, timeout: timeout))
      if (entry['ok'] == true && entry['value'] != null) entry['key'] as String: entry['value'],
  };

  final asQsos = qsosOf(operation, qsos);
  final segmented = segmentedOperationOf(operation, qsos);

  // What the log HUNTS, which a chaser's operation refs never name. Event rows
  // and deleted ones are excluded, as `ScoringService` excludes them: an extra
  // scorer selected here is not cosmetic, since it can rule and take core's
  // verdict off every contact it rules on.
  final hunted = {
    for (final qso in asQsos)
      if (qso.isRealContact)
        for (final qsoRef in qso.refs)
          if (qsoRef['type'] case final String type) type,
  };

  // What the app scores: `watchForOperation` filters deleted rows in SQL and
  // `ScoringService` drops the event markers, so a file's raw list would have
  // this tool reporting duplicates against contacts the app has deleted. The
  // harness sorts what it is given, so order is its business, not ours.
  final scorable = [
    for (final (index, qso) in qsos.indexed)
      if (asQsos[index].isRealContact) qso,
  ];

  final scorers = scorersFor(
    operation.cast<String, dynamic>(),
    scopes,
    segmentRefs: segmented.isSegmented ? [for (final s in segmented.segments) s.refs] : null,
    alsoRefTypes: hunted,
  );
  if (scorers.isEmpty) return {};

  final results = <String, Map<String, Object?>>{};
  for (final scorer in scorers) {
    try {
      results[scorer.key] = await scoreWithOneScorer(
        host,
        key: scorer.key,
        // Each scorer gets the ref that SELECTED it. A `--ref` of the caller's
        // is refused alongside a merged pass rather than handed to whichever
        // scorer happens to be alone (see the command).
        ref: scorer.ref,
        operation: operation,
        qsos: scorable,
        segments: segmented.isSegmented ? segmented.payload : null,
        extraArgs: extraArgs,
        timeout: timeout,
      );
    } catch (e) {
      // Per scorer, as the app does it: one contest scorer that throws must not
      // cost the operation every other scorer's answer. The failure is reported
      // in its own place in the output rather than replacing it — this is the
      // tool someone reaches for BECAUSE a scorer is misbehaving.
      results[scorer.key] = {'error': '$e'};
    }
  }

  return mergeScoredVerdicts(scorers, results);
}

/// The priority merge over whole-operation results: which QSOs some scorer has
/// ruled on, and each fallback scorer's verdicts reduced accordingly. Separate
/// from the calls above so it can be exercised without a runtime.
Map<String, Map<String, Object?>> mergeScoredVerdicts(
  List<Scorer> scorers,
  Map<String, Map<String, Object?>> results,
) {
  final judged = <String>{};
  for (final scorer in scorers.where((s) => !s.fallback)) {
    final verdicts = (results[scorer.key]?['qsoScores'] as Map?) ?? const {};
    for (final entry in verdicts.entries) {
      if (entry.key is String && entry.value is Map && judgesWorkedBefore(entry.value as Map)) {
        judged.add(entry.key as String);
      }
    }
  }

  for (final scorer in scorers.where((s) => s.fallback)) {
    final verdicts = (results[scorer.key]?['qsoScores'] as Map?)?.cast<String, Object?>();
    if (verdicts == null) continue;
    final merged = <String, Object?>{};
    for (final entry in verdicts.entries) {
      final verdict = entry.value;
      final kept =
          judged.contains(entry.key) && verdict is Map ? withoutWorkedBefore(verdict) : verdict;
      if (kept != null) merged[entry.key] = kept;
    }
    results[scorer.key]!['qsoScores'] = merged;
  }
  return results;
}
