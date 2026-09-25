// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scoring hook calls `ExtensionService` makes — the batched pass and the
// two live paths — with the failure reporting they share. A mixin rather than
// an extension so a test double can still override one call; the host-facing
// members it needs (`host`, `getScoringScopes`) are the service's own.

import 'dart:collection';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:halo_core/halo_core.dart' show HookRef, Hooks;
import 'package:halo_extension_host/halo_extension_host.dart';
// The scorer-selection helpers live beside the host, under one name here so
// a call reads as what it is.
import 'package:halo_extension_host/halo_extension_host.dart' as priority;

import '../error_reporting_service.dart';

/// One scorer's cached end-of-log checkpoint, as `ScoringService` stores it:
/// its scoresheet and the day the sheet ends on, which the harness needs back
/// beside it (`resumeDay`) to keep a scorer's per-day state honest across a
/// resume.
/// resumed fold — and the name the runtime may hold it under (`resumeKey`),
/// derived from the checkpoint's stamp by [checkpointKeyOf], so a live call can
/// name the sheet instead of sending it across the bridge every keystroke.
typedef ScoringCheckpoint = ({Object sheet, int? day, String key});

/// What a harness throws when a request names a checkpoint it does not hold —
/// the SDK's `RESUME_MISSING`. The one error that is answered rather than
/// reported: with the sheet, once.
const kResumeMissing = 'resume-missing';

/// The entry a `scoreCandidates` answer carries to say the named checkpoint
/// is held — the SDK's `CHECKPOINT_HELD_KEY`. Not a candidate's verdict, and
/// the verdict merge skips it as it skips anything that is not a map.
const kCheckpointHeldKey = '\$checkpointHeld';

/// What the live single-QSO path hands the scorers instead of the whole log:
/// each scorer's checkpoint, keyed like `local_data['scoring']`, and the
/// contacts logged since it. One value, because the two halves are only right
/// together — a checkpoint sent without its tail calls the contact just logged
/// "not a duplicate". `ScoringService.resolveScoringResume` is the one place
/// that builds it.
typedef ScoringResume = ({Map<String, ScoringCheckpoint> checkpoints, List<Map<String, dynamic>> tail});

/// A `scoring` hook that threw, timed out, or was unreachable — one scorer
/// failing a pass, never the pass itself. Classified `report` in
/// [ErrorPolicy]: a broken scorer is a defect in that extension, and there is
/// nothing the operator can do about it mid-activation, so it goes to the
/// crash backend without a notice.
///
/// What it costs is worth stating: the pass returns without that scorer's
/// verdicts, so on the spots board its contributions are simply ABSENT — no
/// duplicate strike from `core`, no multiplier accent from a contest scorer.
/// An absence looks like a quiet board rather than like a failure, which is
/// exactly why this reaches the backend rather than only the console.
class ScoringHookFailure implements Exception {
  ScoringHookFailure(this.scorerKey, this.method, this.cause);
  final String scorerKey;
  final String method;
  final Object cause;

  @override
  String toString() => 'ScoringHookFailure: scorer "$scorerKey" failed $method: $cause';
}

/// The [ErrorReportingService.reportIfRepeated] key for one scorer's failures
/// of one method. Per scorer AND per method so a contest scorer stuck on the
/// spots pass cannot mask the core scorer breaking on the logging one.
String _scorerFailureKey(String scorerKey, String method) => 'scoring:$scorerKey:$method';

/// Reports one scorer's failure to the crash backend, at most once per scorer
/// per method until it succeeds again — a pass runs every couple of minutes
/// for as long as an operation is open, so a scorer broken for a four-hour
/// activation is one event, not a hundred. [ErrorReportingService.recordSuccess]
/// on the answering path is what re-arms it, making a second event mean a
/// second outage.
void _reportScorerFailure(String scorerKey, String method, Object error, StackTrace stackTrace) {
  ErrorReportingService.reportIfRepeated(
    _scorerFailureKey(scorerKey, method),
    ScoringHookFailure(scorerKey, method, error),
    stackTrace,
    context: 'scoring:$scorerKey:$method',
    threshold: 1,
  );
}

/// How long one scorer gets to answer [ExtensionScoring.scoreQso]. Public so
/// the contest bench can tell a sample that ran out the clock from an answer.
const kScoreQsoTimeout = Duration(seconds: 4);

/// The same for [ExtensionScoring.scoreCandidates] — longer, since it folds
/// the whole log once and then scores every candidate, where the other scores
/// one.
const kScoreCandidatesTimeout = Duration(seconds: 20);

mixin ExtensionScoring {
  ExtensionHost? get host;

  /// Every registered scorer's scope, keyed by scorer — what
  /// `ExtensionService.scorersFor` selects from.
  Future<Map<String, dynamic>> getScoringScopes();

  /// Ticks whenever the runtime is replaced; see `ExtensionService`.
  ValueNotifier<int> get runtimeGeneration;

  /// The checkpoint the running runtime has said it holds, per
  /// `scorer|operation` — ONE, the runtime's own shape, so a caller still
  /// naming the checkpoint before last is sent with its sheet outright rather
  /// than refused and resent. A request whose checkpoint is here crosses the
  /// bridge without its sheet — on a long log, most of the request. Emptied
  /// with the runtime: a new runtime holds nothing, whatever the old one said.
  final Map<String, String> _heldCheckpoints = {};
  int _heldGeneration = -1;

  Map<String, String> get _held {
    final generation = runtimeGeneration.value;
    if (generation != _heldGeneration) {
      _heldCheckpoints.clear();
      _heldGeneration = generation;
    }
    return _heldCheckpoints;
  }

  static String _heldSlot(String scorerKey, Map<String, dynamic> args) => '$scorerKey|${(args['operation'] as Map?)?['uuid'] ?? ''}';

  /// Invokes a scoring method whose request may resume from a checkpoint.
  /// [args] carries the checkpoint in full (`resumeKey`, `resumeFrom`,
  /// `resumeDay`); the sheet is left out when the runtime holds the key, and
  /// sent once more when the runtime answers that it does not — a restart
  /// the generation did not see, or one operation more than it keeps. On
  /// success a held answer records what the runtime now holds: the checkpoint
  /// a batch pass produced (`checkpointKey`), or the one a live call named. A
  /// harness without the cache never says so, and keeps receiving the sheet.
  Future<dynamic> _invokeResumable(ExtensionHost host, String scorerKey, HookRef hook, Map<String, dynamic> args, {required Duration timeout}) async {
    final generation = runtimeGeneration.value;
    final slot = _heldSlot(scorerKey, args);
    final resumeKey = args['resumeKey'];
    final named = resumeKey is String && _held[slot] == resumeKey
        ? ({...args}
            ..remove('resumeFrom')
            ..remove('resumeDay'))
        : args;
    dynamic result;
    try {
      result = await host.invoke(hook, key: scorerKey, args: named, timeout: timeout);
    } on ExtensionHostException catch (e) {
      if (identical(named, args) || !e.message.startsWith(kResumeMissing)) rethrow;
      // Visible on purpose: a runtime and a host that keep disagreeing would
      // pay this double round trip on every keystroke, silently otherwise.
      debugPrint('[scoring] the runtime no longer holds $resumeKey for $scorerKey — sending the checkpoint again');
      _held.remove(slot);
      try {
        result = await host.invoke(hook, key: scorerKey, args: args, timeout: timeout);
      } on ExtensionHostException catch (again) {
        // A runtime refusing the sheet it was just handed is the harness's
        // bug, not the scorer's; the report has to say which.
        throw ExtensionHostException('the resend after $kResumeMissing failed: ${again.message}');
      }
    }
    if (result is Map && (result['checkpointHeld'] == true || result[kCheckpointHeldKey] == true)) {
      final key = hook == Hooks.scoringScoreQsos ? args['checkpointKey'] : resumeKey;
      // Not for a runtime that is already gone: the answer would be filed
      // against its successor.
      if (key is String && runtimeGeneration.value == generation) _held[slot] = key;
    }
    return result;
  }

  /// One scorer's batched pass over an operation's QSOs. [resumeFrom] hands back
  /// that scorer's cached end-of-log scoresheet so only [qsos] — a tail — needs
  /// replaying; omit it for a full pass.
  Future<Map<String, dynamic>?> scoreQsos({required String scorerKey, required Map<String, dynamic> args}) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await _invokeResumable(host, scorerKey, Hooks.scoringScoreQsos, args, timeout: const Duration(seconds: 10));
      if (result is! Map) return null;
      ErrorReportingService.recordSuccess(_scorerFailureKey(scorerKey, Hooks.scoringScoreQsos.method));
      return result.cast<String, dynamic>();
    } catch (e, stackTrace) {
      // One contest's scorer blowing up must not cost the operation its core
      // scoring, so failures are per-scorer.
      _reportScorerFailure(scorerKey, Hooks.scoringScoreQsos.method, e, stackTrace);
      return null;
    }
  }

  /// Scores the single in-progress QSO — the callsign being typed, before
  /// Enter — for the logging panel's live call-info line. Returns
  /// `{notices, alerts}` of scoring keys (`duplicate`, `newBand`, `newMode`,
  /// `newDXCC`, `newState`, `newProvince`, plus whatever a contest scorer emits
  /// — the vocabulary is open), merged across every scorer relevant to the
  /// operation, or null
  /// when the runtime isn't up. Debounced on the caller's side.
  /// [excludeUuid] drops the record being edited so it can't flag itself as
  /// its own duplicate. [operation] must carry `uuid` (the hook reads the log
  /// via it) — pass the same uuid-folded shape command hooks get.
  ///
  /// [operation] is the CURRENT segment, not the base, so scorer selection
  /// follows what the operator is doing right now: a contest that ended at a
  /// break stops contributing pills, one that started at a break begins.
  /// [segments] (`SegmentedOperation.payload`, omitted when unsegmented) is
  /// what lets the hook fold the history under each QSO's own segment
  /// (docs/design/contests.md §5.1.3).
  ///
  /// [huntedRefTypes] are the activity types this operation has hunted —
  /// `Operation.localData['huntedRefTypes']`, cached by `ScoringService`. The
  /// candidate's OWN references are added to them here, so the first contact
  /// with a program still selects its scorer before any rescore has recorded
  /// it. Without either, an operation that activates nothing selects no
  /// activity scorer and the pills fall back to the core dupe rule alone (see
  /// `ExtensionService.scorersFor`).
  ///
  /// [resume] carries the cached end-of-log checkpoints by scorer key and the
  /// contacts logged since them — `ScoringService`'s `resolveScoringResume`
  /// is the one place that decides when they may be sent. A scorer that gets
  /// one skips reading and folding the whole log, which at a few thousand
  /// contacts is the difference between a pill that keeps up with typing and
  /// one that queues every other hook behind it. A scorer with no checkpoint
  /// (one this candidate's own refs just selected) still folds cold; the tail
  /// travels only beside a checkpoint.
  Future<Map<String, dynamic>?> scoreQso({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
    Set<String> huntedRefTypes = const {},
    ScoringResume? resume,
  }) async {
    final host = this.host;
    if (host == null) return null;

    final scorers = priority.scorersFor(operation, await getScoringScopes(), alsoRefTypes: {...huntedRefTypes, ...priority.refTypesOf(qso)});
    if (scorers.isEmpty) return null;

    // Sorted by scorer key so the merged notice/alert order is stable —
    // invokeHookAll gives no ordering guarantee, and the call-info line builds
    // a dedupe signature by joining these lists.
    final notices = SplayTreeSet<String>();
    final alerts = SplayTreeSet<String>();
    var any = false;
    // The fallback scorer's own verdict, held back until every other scorer has
    // answered: once one of them has judged this QSO on the worked-before axis,
    // the fallback's judgement of it yields (see [Scorer],
    // [judgesWorkedBefore]).
    final fallbackNotices = SplayTreeSet<String>();
    final fallbackAlerts = SplayTreeSet<String>();
    var judgedByOther = false;

    await Future.wait(
      scorers.map((scorer) async {
        try {
          final checkpoint = resume?.checkpoints[scorer.key];
          final tail = resume?.tail;
          final result = await _invokeResumable(host, scorer.key, Hooks.scoringScoreQso, {
            'operation': operation,
            'qso': qso,
            'excludeUuid': ?excludeUuid,
            'ref': ?scorer.ref,
            'segments': ?segments,
            // Absent, not null, without one: the harness branches on the key's
            // presence, and a null would resume from nothing.
            'resumeKey': ?checkpoint?.key,
            'resumeFrom': ?checkpoint?.sheet,
            'resumeDay': ?checkpoint?.day,
            if (checkpoint != null && tail != null && tail.isNotEmpty) 'qsos': tail,
          }, timeout: kScoreQsoTimeout);
          if (result is! Map) return;
          any = true;
          ErrorReportingService.recordSuccess(_scorerFailureKey(scorer.key, Hooks.scoringScoreQso.method));
          if (!scorer.fallback && judgesWorkedBefore(result)) judgedByOther = true;
          (scorer.fallback ? fallbackNotices : notices).addAll(((result['notices'] as List?) ?? const []).whereType<String>());
          (scorer.fallback ? fallbackAlerts : alerts).addAll(((result['alerts'] as List?) ?? const []).whereType<String>());
        } catch (e, stackTrace) {
          // A scorer that FAILED judged nothing, so the fallback speaks for this
          // QSO after all rather than the row going bare.
          _reportScorerFailure(scorer.key, Hooks.scoringScoreQso.method, e, stackTrace);
        }
      }),
    );

    if (!any) return null;
    if (judgedByOther) {
      notices.addAll(fallbackNotices.where((n) => !kWorkedBeforeNotices.contains(n)));
      alerts.addAll(fallbackAlerts.where((a) => !kWorkedBeforeAlerts.contains(a)));
    } else {
      notices.addAll(fallbackNotices);
      alerts.addAll(fallbackAlerts);
    }
    return {'notices': notices.toList(), 'alerts': alerts.toList()};
  }

  /// The same live judgement as [scoreQso], for many not-yet-logged candidates
  /// at once — the Spots Panel annotating every spot on screen against the
  /// operation's log. Returns `{candidateKey: {notices, alerts}}` merged across
  /// every scorer relevant to [operation], or null when NO pass happened — the
  /// runtime isn't up, or no scorer applies. A scorer that ran and failed is
  /// not that case: see the return below.
  ///
  /// One bridge crossing per scorer, not per candidate: the runtime folds the
  /// log once and scores every candidate against it (DESIGN.md §4). Calling
  /// [scoreQso] in a loop instead would cost a round-trip AND a whole-log fold
  /// per spot, which is why this exists.
  ///
  /// [candidates] is keyed by whatever the caller can match up afterwards —
  /// candidates have no uuid, since a spot is not a record. Keys absent from
  /// the result had nothing to report.
  ///
  /// [operationUuid] is taken separately and folded in here rather than left to
  /// the caller: it is how the hook reaches the log, and an [operation] map
  /// without it scores every candidate against an EMPTY log — no errors, no
  /// warnings, just nothing ever reported as a duplicate.
  /// [resume] is as [scoreQso]'s: the cached checkpoints by scorer and the
  /// contacts logged since them, from `ScoringService`'s
  /// `resolveScoringResume`, which is the one place that decides when they
  /// may be sent. A scorer that gets one skips the whole-log fold, which on a
  /// long log is the dominant cost of a pass.
  Future<Map<String, Map<String, List<String>>>?> scoreCandidates({
    required Map<String, dynamic> operation,
    required String operationUuid,
    required Map<String, Map<String, dynamic>> candidates,
    List<Map<String, dynamic>>? segments,
    ScoringResume? resume,
    Set<String> huntedRefTypes = const {},
  }) async {
    final host = this.host;
    if (host == null || candidates.isEmpty) return null;

    final withUuid = {...operation, 'uuid': operationUuid};
    // The candidates' own references count as well as the log's: a station
    // worked bare who is now spotted at a park is a NEW reference, and a
    // log-only rule would leave that spot struck as a plain duplicate.
    final scorers = priority.scorersFor(
      withUuid,
      await getScoringScopes(),
      alsoRefTypes: {...huntedRefTypes, for (final candidate in candidates.values) ...priority.refTypesOf(candidate)},
    );
    if (scorers.isEmpty) return null;

    final payload = [
      for (final entry in candidates.entries) {'key': entry.key, 'qso': entry.value},
    ];

    // Sorted like scoreQso's, so a candidate's merged notice order is stable
    // across refreshes and the panel's styling doesn't flicker between two
    // scorers' orderings.
    final merged = <String, ({SplayTreeSet<String> notices, SplayTreeSet<String> alerts})>{};
    // Per CANDIDATE, not per pass: the fallback yields only on the candidates
    // another scorer has judged on the worked-before axis (see [Scorer],
    // [judgesWorkedBefore]). A whole spots board answered with
    // `missingExchange` — which is what a VHF test says about every spot, since
    // a spot carries no exchange — has been judged on no such thing, and the
    // board would otherwise lose its dupe striking outright.
    final fallbackMerged = <String, ({SplayTreeSet<String> notices, SplayTreeSet<String> alerts})>{};
    final judgedByOther = <String>{};
    var any = false;
    // Tracked apart from [any] because the two mean opposite things to the
    // caller. No scorer answering can be a pass that had nothing to say, or a
    // runtime not up yet; a scorer FAILING is a verdict that should exist and
    // doesn't — and the board must not keep showing the last one it had.
    var failed = false;

    await Future.wait(
      scorers.map((scorer) async {
        try {
          final checkpoint = resume?.checkpoints[scorer.key];
          final tail = resume?.tail;
          final result = await _invokeResumable(host, scorer.key, Hooks.scoringScoreCandidates, {
            'operation': withUuid,
            'candidates': payload,
            'ref': ?scorer.ref,
            'segments': ?segments,
            // As scoreQso's: absent, not null, without a checkpoint, and the
            // tail only beside one.
            'resumeKey': ?checkpoint?.key,
            'resumeFrom': ?checkpoint?.sheet,
            'resumeDay': ?checkpoint?.day,
            if (checkpoint != null && tail != null && tail.isNotEmpty) 'qsos': tail,
          }, timeout: kScoreCandidatesTimeout);
          if (result is! Map) return;
          any = true;
          ErrorReportingService.recordSuccess(_scorerFailureKey(scorer.key, Hooks.scoringScoreCandidates.method));
          for (final entry in result.entries) {
            final key = entry.key;
            final value = entry.value;
            if (key is! String || value is! Map) continue;
            if (!scorer.fallback && judgesWorkedBefore(value)) judgedByOther.add(key);
            final target = scorer.fallback ? fallbackMerged : merged;
            final into = target.putIfAbsent(key, () => (notices: SplayTreeSet<String>(), alerts: SplayTreeSet<String>()));
            into.notices.addAll(((value['notices'] as List?) ?? const []).whereType<String>());
            into.alerts.addAll(((value['alerts'] as List?) ?? const []).whereType<String>());
          }
        } catch (e, stackTrace) {
          // Per-scorer, like scoreQso: a contest scorer that throws must not cost
          // the spots their core dupe marking.
          failed = true;
          _reportScorerFailure(scorer.key, Hooks.scoringScoreCandidates.method, e, stackTrace);
        }
      }),
    );

    // A failure returns the surviving scorers' verdicts — an EMPTY map when
    // the only scorer was the one that failed — rather than null. Null means
    // "no pass happened", which the panel answers by keeping the verdicts it
    // has; doing that here would leave a board struck through by a scorer that
    // is no longer running. Losing the strikes is the safe direction: an
    // un-struck worked spot costs a glance, a struck unworked one costs the
    // contact.
    if (!any && !failed) return null;
    for (final entry in fallbackMerged.entries) {
      final judged = judgedByOther.contains(entry.key);
      final notices = judged ? entry.value.notices.where((n) => !kWorkedBeforeNotices.contains(n)) : entry.value.notices;
      final alerts = judged ? entry.value.alerts.where((a) => !kWorkedBeforeAlerts.contains(a)) : entry.value.alerts;
      if (notices.isEmpty && alerts.isEmpty) continue;
      final into = merged.putIfAbsent(entry.key, () => (notices: SplayTreeSet<String>(), alerts: SplayTreeSet<String>()));
      into.notices.addAll(notices);
      into.alerts.addAll(alerts);
    }
    return {
      for (final entry in merged.entries)
        if (entry.value.notices.isNotEmpty || entry.value.alerts.isNotEmpty)
          entry.key: {'notices': entry.value.notices.toList(), 'alerts': entry.value.alerts.toList()},
    };
  }
}
