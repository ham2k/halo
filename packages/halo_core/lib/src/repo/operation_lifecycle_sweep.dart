// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The periodic pass that applies the two time-driven lifecycle transitions
// and derives a status for operations that have never carried one.
//
// Deliberately NOT derive-on-read. Embedding the time rules in every query
// would put a nullable-column comparison in each one — `startAtMillisMax` is
// NULL, not zero, for a QSO-less operation — and a repair-on-read would make
// merely listing operations write rows and push sync. With a sweep, the
// STORED status is the truth and every other query is a plain column read.

import 'dart:async';

import '../app_clock.dart';
import '../dev_log.dart';
import '../models/models.dart';
import '../models/operation_lifecycle.dart';
import 'operations_repository.dart';
import 'write_policy.dart';

/// How often the sweep runs while the app is up.
///
/// Real time, not the app clock: this becomes a [Timer] duration, and a timer
/// under a travelled clock is the one thing that must not travel with it
/// (docs/design/time.md §1). The thresholds it applies are on the app clock —
/// they are log-domain facts that have to line up with QSO times.
///
/// 5 minutes means a threshold can be up to 5 minutes late. Irrelevant for a
/// 12-hour rule and a 7-day one; nothing latency-sensitive may be built on
/// this.
const operationLifecycleSweepPeriod = Duration(minutes: 5);

/// Guards the fixed-point loop. Reaching it means the transition rules have a
/// cycle, which is a bug rather than a state to wait out — so it stops and
/// says so instead of spinning.
const _maxTransitionsPerOperation = 8;

/// Runs [sweptStatusFor] over the candidate operations until nothing changes.
///
/// One instance lives for the app's lifetime: [start] runs a pass immediately
/// (an app closed for a fortnight has a backlog waiting) and every
/// [operationLifecycleSweepPeriod] thereafter.
class OperationLifecycleSweeper {
  final OperationsRepository operations;

  /// Where a failure goes: a pass that could not run, an operation that could
  /// not be swept, or one whose transitions did not settle. This package
  /// reports nothing itself; the app wires its error reporting in. Null
  /// leaves the developer log only.
  final void Function(Object error, StackTrace stackTrace, {String? context})? onError;

  Timer? _timer;
  bool _running = false;

  /// Operations already reported this session, by uuid — `''` for a pass
  /// that could not run at all. One that will not sweep fails
  /// the same way every five minutes, and each pass throws a new error object
  /// the reporting cannot recognise as the one it already sent.
  final _reported = <String>{};

  OperationLifecycleSweeper({required this.operations, this.onError});

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(operationLifecycleSweepPeriod, (_) => unawaited(_runGuarded()));
    unawaited(_runGuarded());
  }

  /// [runOnce], with what it throws handed to [onError].
  ///
  /// The pass is unawaited, so anything it throws — a database error, a blob
  /// that will not decode, a throw out of the save fan-out — would otherwise
  /// land in the zone handler as an unhandled error, and the operator's
  /// notice with it, again every five minutes. What the failure deserves is
  /// ErrorPolicy's call, through the app's reporting
  /// (docs/design/error-reporting.md).
  Future<void> _runGuarded() async {
    try {
      await runOnce();
    } catch (e, st) {
      DevLog.instance.log('lifecycle', {'sweep': 'failed', 'error': e.toString()});
      if (_reported.add('')) onError?.call(e, st, context: 'lifecycle:sweep');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One pass. Returns how many operations it changed.
  ///
  /// Overlapping passes are skipped rather than queued: a pass that outruns
  /// the period has a slow database, and stacking more work on it is the
  /// wrong answer.
  ///
  /// Nothing a pass writes is synced ([OperationsRepository.inferStatus]):
  /// the first pass after an upgrade derives a status for every operation on
  /// the device, and pushed, each would send that device's whole copy out as
  /// the newest revision.
  Future<int> runOnce() async {
    if (_running) return 0;
    _running = true;
    try {
      var changed = 0;
      for (final uuid in await operations.lifecycleSweepCandidates()) {
        if (await _sweepOne(uuid)) changed++;
      }
      return changed;
    } finally {
      _running = false;
    }
  }

  /// Moves one operation to where it belongs, in a single write.
  ///
  /// One that throws is reported and passed over, never the end of the pass:
  /// a blob that will not decode would otherwise leave every candidate after
  /// it unswept for good.
  Future<bool> _sweepOne(String uuid) async {
    try {
      return await operations.inferStatus(uuid, _settle) != null;
    } on WriteRefused {
      // The clock is travelled and this is not test data (time.md §4).
      // Nothing is wrong: the next pass on a real clock picks it up.
      return false;
    } catch (e, st) {
      _report(uuid, e, st);
      return false;
    }
  }

  void _report(String uuid, Object error, StackTrace stackTrace) {
    DevLog.instance.log('lifecycle', {'sweep': 'failed', 'operation': uuid, 'error': error.toString()});
    if (_reported.add(uuid)) onError?.call(error, stackTrace, context: 'lifecycle:sweep:operation');
  }

  /// Where [stored] lands once every threshold it has crossed is applied, or
  /// null where it stays. Iterated in memory, to a fixed point, inside the
  /// write's own transaction: an app closed for a fortnight has operations
  /// that crossed several thresholds at once, and one step per pass would
  /// leave them short of where they belong for another five minutes each —
  /// while a read per step would cost the first pass after an upgrade two
  /// transactions for every operation on the device.
  ({String status, int? atMillis})? _settle(Operation stored) {
    var operation = stored;
    ({String status, int? atMillis})? move;
    for (var step = 0; step < _maxTransitionsPerOperation; step++) {
      final next = sweptStatusFor(operation, nowMillis: nowMillis());
      if (next == null || next == operation.status) return move;
      // A state the sweep infers is dated from the log, not from the pass
      // that noticed it. A pause, from the silence it observed: the panel
      // says how long the pause has lasted, and a sweep stamp would restart
      // that count twelve hours in. A state DERIVED for a log that had none,
      // from its last contact: stamped now, an operation last logged into
      // eleven hours ago would read as live for a day more.
      final atMillis = statusIsUnstarted(operation.status)
          ? operation.startAtMillisMax
          : next == OperationStatus.paused
          ? operationLastActivityMillis(operation)
          : null;
      move = (status: next, atMillis: atMillis);
      operation = Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'status': next, 'statusAtMillis': atMillis ?? nowMillis()},
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
        localData: operation.localData,
      );
    }
    _report(stored.uuid, StateError('lifecycle sweep did not settle: ${stored.status} → ${move?.status}'), StackTrace.current);
    return move;
  }
}
