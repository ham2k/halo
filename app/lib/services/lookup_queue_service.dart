// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Background callsign-lookup queue: QSOs get logged immediately and their
// online lookups (QRZ, HamDB…) run afterwards, off the logging path, so a
// slow or absent network never delays the operator. Results are merged back
// onto the stored QSO via `QsosRepository.update`, and the operation view's
// drift watch stream repaints the row on its own.
//
// Lookups run strictly one at a time — each is its own small `lookupCall`
// bridge round-trip, never a single large batch call, so the user's own
// debounced typing lookups (and any other extension traffic) interleave
// freely with a long queue instead of waiting behind it. Results are
// *applied* in small batches instead of per-lookup: every `update` restamps
// the row, which re-arms the operation view's debounced full-log rescore
// and the sync engine's push debounce, so writing after every (often >1s)
// network lookup would trigger a rescore and a sync round per QSO. Grouping
// writes lands them within one debounce window apiece.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show CallLookup;

import 'error_reporting_service.dart';
import 'status_bar_service.dart';

class LookupQueueService {
  /// Same shape as `ExtensionService.lookupCall` — injected as a function so
  /// tests don't need a JS runtime.
  final CallLookup lookup;
  final QsosRepository qsos;
  final OperationsRepository operations;
  final StatusBarService statusBar;

  /// Whether the extension runtime is up (`ExtensionService.ready`). The
  /// lookup function returns null while the runtime is booting or
  /// restarting after a crash — without this gate a batch queued at app
  /// launch would drain instantly, reporting "N of N" with zero lookups
  /// actually performed. Null skips the gate (tests, or a always-ready host).
  final bool Function()? lookupReady;

  /// How long one drain run will wait, in total, for [lookupReady] before
  /// giving up and processing anyway (overridable for tests).
  final Duration runtimeWaitBudget;

  LookupQueueService({
    required this.lookup,
    required this.qsos,
    required this.operations,
    required this.statusBar,
    this.lookupReady,
    this.runtimeWaitBudget = const Duration(seconds: 20),
  });

  /// Status-bar item key for queue progress.
  static const statusKey = 'lookup_queue_progress';

  /// `source` of the hardcoded offline callsign-annotation lookup step
  /// (extensions/core/lookups/src/annotate.ts) — the one entry every lookup
  /// result carries even with no network. Its presence proves nothing about
  /// online enrichment, so it's ignored when deciding whether a QSO already
  /// has real lookup data.
  static const annotationSource = 'callsign-annotation';

  /// How many completed lookups are merged per write burst — see the header
  /// comment on why writes are grouped.
  static const _applyBatchSize = 8;

  final List<_PendingLookup> _queue = [];
  final Set<String> _queuedUuids = {};
  bool _processing = false;

  // Progress counters for the status bar: `_batchTotal` accumulates while
  // work keeps arriving and both reset once the queue drains, so a later
  // enqueue starts a fresh "0 of N" batch instead of continuing an old one.
  int _batchTotal = 0;
  int _batchDone = 0;
  bool _suppressProgress = false;

  // One-entry cache for the lookup context: batches overwhelmingly come
  // from a single operation, so this avoids one operations-table read (and
  // JSON decode) per QSO without inventing real cache machinery.
  Operation? _cachedOperation;

  /// Completes when the queue is idle — for tests and callers that need to
  /// observe a drained queue; enqueuing itself never waits on this.
  Future<void> get idle => _processing ? (_idleCompleter ??= Completer<void>()).future : Future.value();
  Completer<void>? _idleCompleter;

  /// Queues [qso] for a background online lookup. Event markers, deleted
  /// QSOs, and too-short calls (mirroring `lookupCall`'s own gate) are
  /// skipped, as is anything already waiting in the queue. A QSO that
  /// already carries online lookup data is skipped too — pass [force] (the
  /// explicit "Lookup all QSOs" refresh) to re-run those as well.
  void enqueue(Qso qso, {bool force = false}) {
    if (!qso.isRealContact || qso.theirCall.length < 3) return;
    if (!force && _hasOnlineLookup(qso)) return;
    if (!_queuedUuids.add(qso.uuid)) return;
    _queue.add(_PendingLookup(qso.uuid, qso.operationUuid));
    _batchTotal += 1;
    _showProgress();
    _ensureProcessing();
  }

  /// "Lookup all QSOs": refreshes lookup data for every eligible QSO, even
  /// ones already enriched. One progress update for the whole batch — an
  /// enqueue-time update per QSO would rebuild the status bar N times in a
  /// single synchronous burst.
  void enqueueAll(Iterable<Qso> qsos) {
    _suppressProgress = true;
    try {
      for (final qso in qsos) {
        enqueue(qso, force: true);
      }
    } finally {
      _suppressProgress = false;
    }
    _showProgress();
  }

  /// Whether the stored record already has lookup data from a real source
  /// (anything beyond the always-present offline annotation step).
  bool _hasOnlineLookup(Qso qso) {
    final lookups = ((qso.data['their'] as Map?)?['lookups'] as List?)?.whereType<Map>();
    if (lookups == null) return false;
    return lookups.any((l) => l['source'] is String && l['source'] != annotationSource);
  }

  void _ensureProcessing() {
    if (_processing) return;
    _processing = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    final completed = <_CompletedLookup>[];
    var waitBudget = runtimeWaitBudget;
    try {
      while (_queue.isNotEmpty) {
        // Removing from the dedup set *now* (not after the lookup) means an
        // explicit re-request arriving while this entry's lookup is in
        // flight queues a fresh attempt instead of being silently dropped.
        final entry = _queue.removeAt(0);
        _queuedUuids.remove(entry.qsoUuid);

        // Hold (bounded) while the extension runtime is booting/restarting,
        // rather than burning the whole queue on null results.
        while (lookupReady != null && !lookupReady!() && waitBudget > Duration.zero) {
          const step = Duration(milliseconds: 250);
          await Future<void>.delayed(step);
          waitBudget -= step;
        }

        try {
          final result = await _lookupOne(entry);
          if (result != null) completed.add(result);
        } catch (e) {
          // One failed lookup (network, runtime restart…) must not stall the
          // rest of the queue — the QSO just keeps whatever data it had.
          debugPrint('[lookup queue] lookup failed for ${entry.qsoUuid}: $e');
        }
        _batchDone += 1;
        _showProgress();

        if (completed.length >= _applyBatchSize || _queue.isEmpty) {
          await _applyResults(completed);
          completed.clear();
        }
      }
    } finally {
      if (completed.isNotEmpty) {
        try {
          await _applyResults(completed);
        } catch (e) {
          debugPrint('[lookup queue] failed to apply results: $e');
        }
      }
      _processing = false;
      _batchTotal = 0;
      _batchDone = 0;
      _cachedOperation = null;
      _idleCompleter?.complete();
      _idleCompleter = null;
    }
  }

  /// Runs the (network) lookup for one entry. Reads, no writes — the merge
  /// happens later in `_applyResults`, in a batch.
  Future<_CompletedLookup?> _lookupOne(_PendingLookup entry) async {
    // Re-read rather than trusting the enqueue-time snapshot: the QSO may
    // have been edited or deleted while earlier entries were processed.
    final qso = await qsos.get(entry.qsoUuid);
    if (qso == null || !qso.isRealContact) return null;
    final call = qso.theirCall;
    if (call.length < 3) return null;

    if (_cachedOperation?.uuid != entry.operationUuid) {
      _cachedOperation = await operations.get(entry.operationUuid);
    }
    final result = await lookup(
      call,
      qso: qso.data,
      operation: _cachedOperation?.data ?? const {},
      online: true,
    );
    // Nothing came back (runtime down mid-call) — leave the record alone.
    if (result == null || (result['guess'] == null && result['lookups'] == null)) return null;
    return _CompletedLookup(entry, call, result);
  }

  Future<void> _applyResults(List<_CompletedLookup> completed) async {
    for (final item in completed) {
      try {
        await _applyOne(item);
      } catch (e, st) {
        // The write path that actually persists a lookup onto a QSO — a
        // failure here means the lookup ran but nothing got saved, which
        // reads to the operator as "lookups just don't work."
        debugPrint('[lookup queue] failed to apply result for ${item.entry.qsoUuid}: $e');
        ErrorReportingService.report(e, st, context: 'lookup-queue:apply-result');
      }
    }
  }

  Future<void> _applyOne(_CompletedLookup item) async {
    // Re-read: the network round-trip is the long pole, and an edit made
    // meanwhile must not be clobbered by our older snapshot. Only the nested
    // guess/lookups are replaced — manually entered top-level `their` fields
    // (name, grid…) always win over the guess (see Qso model) and are left
    // untouched.
    final current = await qsos.get(item.entry.qsoUuid);
    if (current == null || current.deleted) return;
    // The callsign was corrected while the lookup was in flight — this
    // result belongs to a different station; the corrected call gets its
    // own lookup when (re-)enqueued.
    if (current.theirCall != item.call) return;

    final their = ((current.data['their'] as Map?)?.cast<String, dynamic>()) ?? <String, dynamic>{};
    final newGuess = item.result['guess'];
    final newLookups = item.result['lookups'];

    // Fail-safe against a crossed lookup result. The merged guess is seeded
    // from the callsign we asked for (annotate.ts always sets `guess.call` to
    // the uppercased lookup call), so a guess whose call disagrees is a result
    // that got mixed up in flight — persisting it is exactly the reported
    // "wrong station's name on a QSO" bug. Drop it rather than write it, and
    // log loudly: this path is unreproduced locally, so a hit in the wild is
    // the trace we need. A guess with no `call` at all still passes through.
    final guessCall = (newGuess is Map ? newGuess['call'] : null) as String?;
    if (guessCall != null && guessCall.toUpperCase() != item.call.toUpperCase()) {
      debugPrint('[lookup queue] DROPPED crossed result: asked for ${item.call}, '
          'guess was for $guessCall (qso ${item.entry.qsoUuid})');
      ErrorReportingService.report(
        StateError('crossed lookup result: asked for ${item.call}, guess was for $guessCall'),
        StackTrace.current,
        context: 'lookup-queue:crossed-result',
      );
      return;
    }

    // A degraded result (offline, or a source erroring) must not wipe
    // richer stored data: the pipeline always returns at least the offline
    // annotation entry, so "sources that answered" is the real signal. Only
    // write when the new result covers every source already stored.
    Set<String> sourcesOf(dynamic lookups) => ((lookups as List?) ?? const [])
        .whereType<Map>()
        .map((l) => l['source'])
        .whereType<String>()
        .toSet();
    if (!sourcesOf(newLookups).containsAll(sourcesOf(their['lookups']))) return;

    // Identical result — don't dirty the record: an update restamps
    // `updatedAtMillis` and re-syncs the row, and a vacuous newer stamp can
    // even win the last-write-wins merge against another device's real edit.
    const eq = DeepCollectionEquality();
    if (eq.equals(newGuess, their['guess']) && eq.equals(newLookups, their['lookups'])) return;

    await qsos.update(
      Qso(
        uuid: current.uuid,
        operationUuid: current.operationUuid,
        data: {
          ...current.data,
          'their': {
            ...their,
            'guess': ?newGuess,
            'lookups': ?newLookups,
          },
        },
        deleted: current.deleted,
        scoreCache: current.scoreCache,
      ),
    );
  }

  void _showProgress() {
    // The zero check is reachable: enqueueAll's trailing update fires even
    // when every QSO was skipped (nothing enqueued, no batch to report).
    if (_suppressProgress || _batchTotal == 0) return;
    statusBar.setProgress(
      key: statusKey,
      icon: 'account-search',
      title: 'Callsign lookups',
      text: '$_batchDone of $_batchTotal',
      value: _batchDone / _batchTotal,
    );
  }
}

class _PendingLookup {
  final String qsoUuid;
  final String operationUuid;
  const _PendingLookup(this.qsoUuid, this.operationUuid);
}

class _CompletedLookup {
  final _PendingLookup entry;

  /// The callsign the lookup was issued for — compared against the stored
  /// record again at apply time.
  final String call;
  final Map<String, dynamic> result;
  const _CompletedLookup(this.entry, this.call, this.result);
}
