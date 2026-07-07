// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Dart port of app-polo's `_doOneRoundOfSyncing` (src/store/sync/sync.js):
// selects a batch of dirty Operations/QSOs, hands it to a transport, marks
// what was sent as synced, and merges back whatever the server returned.
// Batching, dirty-flag bookkeeping, and the loop itself stay pure Dart on
// purpose (DESIGN.md §4) — sync keeps working even if the JS extension
// runtime is wedged. Only the actual network call crosses into a
// `syncTransport` extension, via the `transport` callback below.
//
// New/changed-account handling (DESIGN.md's sync reconciliation flow) is a
// second state machine layered on top: before ever pushing or pulling real
// data, the engine confirms which account it's talking to and — the first
// time that account is new or different from last time — pauses
// (`pendingAccountUUID`) until the app layer calls [resolveAccountChange].
// Only then does it run a backfill (paginating backward through the
// account's full history) before settling into ordinary forward sync.

import 'dart:async';

import '../models/models.dart';
import '../repo/repositories.dart';

/// Calls the highest-priority `syncTransport` hook's `method` with `args`
/// and returns its JSON result. Implemented by the app layer (wrapping
/// `ExtensionHost.invokeHook`) so this package stays free of a Flutter/
/// extension-host dependency — the same reason `halo_core` has no Flutter
/// import today.
typedef SyncTransportCall = Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args);

/// Sync-related state the engine reads/writes, backed by the app's
/// SettingsService (SharedPreferences) rather than a drift table — see the
/// design note in DESIGN.md §6: it's a handful of scalars, not per-row data.
abstract class SyncSettings {
  bool get enabled;
  Map<String, dynamic> get state;
  Future<void> setState(Map<String, dynamic> state);
  bool get developerMode => false;
  Future<void> setDeveloperMode(bool enabled) async {}
}

class SyncBatch {
  final List<Operation> operations;
  final List<Qso> qsos;
  const SyncBatch({this.operations = const [], this.qsos = const []});
  bool get isEmpty => operations.isEmpty && qsos.isEmpty;
}

/// How to reconcile this device's local data with a new (or newly
/// different) account, once the user answers the Settings banner.
enum SyncAccountChoice {
  /// Keep local data, mark it all dirty (`resetSyncedStatus`) so it merges
  /// into the account alongside whatever backfill pulls down.
  combine,

  /// Back up local data (`backupAndClearAll`) and take the account's
  /// version instead — backfill then repopulates everything from scratch.
  replace,
}

class SyncEngine {
  final OperationsRepository operations;
  final QsosRepository qsos;
  final SyncTransportCall transport;
  final SyncSettings settings;

  static const smallBatchSize = 10;
  static const defaultLargeBatchSize = 10; // matches sync.js's actual (not its stale comment)
  static const debounceDelay = Duration(milliseconds: 500);
  static const debounceMaxWait = Duration(seconds: 3);
  static const defaultLoopDelay = Duration(seconds: 20);
  static const maxErrorRetries = 8;

  int _largeBatchSize = defaultLargeBatchSize;
  Duration _loopDelay = defaultLoopDelay;
  int _errorCount = 0;
  bool _running = false;

  Timer? _debounceTimer;
  DateTime? _debounceStartedAt;
  Timer? _loopTimer;

  SyncEngine({required this.operations, required this.qsos, required this.transport, required this.settings});

  void start() {
    if (!settings.enabled) return;
    _scheduleLoop(Duration.zero);
  }

  void dispose() {
    _debounceTimer?.cancel();
    _loopTimer?.cancel();
  }

  /// Called by the repositories after every local write (wired in via their
  /// `onChange` callback). Debounces a "small batch" round so a burst of
  /// edits (e.g. typing) coalesces into one round, but never waits more than
  /// [debounceMaxWait] if edits keep arriving back-to-back.
  void notifyChanged() {
    if (!settings.enabled) return;
    final now = DateTime.now();
    _debounceStartedAt ??= now;
    _debounceTimer?.cancel();

    if (now.difference(_debounceStartedAt!) >= debounceMaxWait) {
      _debounceStartedAt = null;
      unawaited(runOneRound(smallBatch: true));
      return;
    }
    _debounceTimer = Timer(debounceDelay, () {
      _debounceStartedAt = null;
      unawaited(runOneRound(smallBatch: true));
    });
  }

  /// The user answered the Settings banner for a new/changed account.
  /// Reconciles local data per [choice], clears the pending state, resets
  /// backfill bookkeeping, and kicks off a round immediately.
  Future<void> resolveAccountChange(SyncAccountChoice choice) async {
    if (choice == SyncAccountChoice.replace) {
      final backupId = DateTime.now().toUtc().toIso8601String();
      await operations.backupAndClearAll(backupId);
      await qsos.backupAndClearAll(backupId);
    } else {
      await operations.resetSyncedStatus();
      await qsos.resetSyncedStatus();
    }

    final state = settings.state;
    await settings.setState({
      ...state,
      'lastSyncAccountUUID': state['pendingAccountUUID'],
      'pendingAccountUUID': null,
      'completedFullSync': false,
      'earliestOperationSyncedAtMillis': null,
      'earliestQSOSyncedAtMillis': null,
    });
    _scheduleLoop(Duration.zero);
  }

  /// The `SYNCALL` debug command: back up and wipe local data, then run a
  /// fresh backfill under whatever account is already linked. Reuses
  /// [SyncAccountChoice.replace]'s mechanism, but there's no account change
  /// here — `lastSyncAccountUUID`/`pendingAccountUUID` are left alone.
  Future<void> forceFullResync() async {
    final backupId = DateTime.now().toUtc().toIso8601String();
    await operations.backupAndClearAll(backupId);
    await qsos.backupAndClearAll(backupId);

    final state = settings.state;
    await settings.setState({
      ...state,
      'completedFullSync': false,
      'earliestOperationSyncedAtMillis': null,
      'earliestQSOSyncedAtMillis': null,
    });
    _scheduleLoop(Duration.zero);
  }

  /// Selects the next batch to send: unsynced QSOs first (bringing along
  /// their still-unsynced parent operations), falling back to unsynced
  /// operations alone when there are no pending QSOs — same shape as
  /// `sync.js`'s batch selection.
  Future<SyncBatch> selectBatch({required int qsoBatchSize, required int operationBatchSize}) async {
    final pendingQsos = await qsos.unsyncedBatch(qsoBatchSize);
    if (pendingQsos.isNotEmpty) {
      final operationUuids = {for (final q in pendingQsos) q.operationUuid}.toList();
      var pendingOperations = await operations.byUuids(operationUuids, onlyUnsynced: true);
      if (pendingOperations.length > operationBatchSize) {
        pendingOperations = pendingOperations.sublist(0, operationBatchSize);
      }
      return SyncBatch(operations: pendingOperations, qsos: pendingQsos);
    }
    return SyncBatch(operations: await operations.unsyncedBatch(operationBatchSize));
  }

  /// Runs one round of syncing.
  ///
  /// Before ever touching real data, this gates on account identity:
  /// - If a combine/replace choice is still pending, it does nothing (the
  ///   Settings banner is waiting on the user).
  /// - If this device has never linked an account, it makes a lightweight
  ///   `getAccountData` call (no push, no pull) just to learn the account
  ///   uuid, then marks it pending for the user to resolve.
  ///
  /// Once linked, a "small batch" round (a debounced reaction to a local
  /// edit) always has something to push, by construction, and never pulls.
  /// A "large batch" round (the periodic loop) always calls the transport,
  /// requesting either a backward-paging backfill page (until the account's
  /// full history has been fetched) or, once caught up, a forward page of
  /// anything new since the last watermark — so a device with nothing new
  /// to log still learns about QSOs logged elsewhere. It reschedules
  /// itself — sooner, with no delay, if there's more to catch up on (a
  /// local backlog, or a full page implying more is waiting server-side) —
  /// after [defaultLoopDelay] otherwise. If the account turns out to have
  /// changed mid-stream, that response is discarded and the pending-account
  /// flow starts over, the same as a fresh link.
  Future<void> runOneRound({bool smallBatch = false}) async {
    if (!settings.enabled || _running) return;
    _running = true;
    try {
      final state = settings.state;

      if (state['pendingAccountUUID'] != null) {
        if (!smallBatch) _scheduleLoop(_loopDelay);
        return;
      }

      if (state['lastSyncAccountUUID'] == null) {
        final response = await transport('getAccountData', const {});
        final accountUuid = (response['current_account'] as Map?)?['uuid'] as String?;
        if (accountUuid != null) {
          await settings.setState({...settings.state, 'pendingAccountUUID': accountUuid});
        }
        if (!smallBatch) _scheduleLoop(_loopDelay);
        return;
      }

      final backfilling = state['completedFullSync'] != true;
      final batchSize = smallBatch ? smallBatchSize : _largeBatchSize;
      final batch = await selectBatch(qsoBatchSize: batchSize, operationBatchSize: batchSize);

      if (batch.isEmpty && smallBatch) return;

      final pull = !smallBatch;
      final response = await transport(
        'sync',
        await _buildPayload(batch, pull: pull, backfilling: backfilling, limit: batchSize),
      );

      final responseAccountUuid = (response['account'] as Map?)?['uuid'] as String?;
      if (responseAccountUuid != null && responseAccountUuid != state['lastSyncAccountUUID']) {
        // Re-registered under a different account mid-stream: don't mark
        // anything synced or merge this response — same pause-and-ask
        // treatment as a fresh link.
        await settings.setState({...state, 'pendingAccountUUID': responseAccountUuid});
        return;
      }

      await operations.markSynced(batch.operations.map((o) => o.uuid));
      await qsos.markSynced(batch.qsos.map((q) => q.uuid));

      final inboundOperations = (response['operations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final inboundQsos = (response['qsos'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final opWatermark = inboundOperations.isEmpty ? null : await operations.mergeFromSync(inboundOperations);
      final qsoWatermark = inboundQsos.isEmpty ? null : await qsos.mergeFromSync(inboundQsos);

      await _processResponseMeta(
        response,
        pull: pull,
        backfilling: backfilling,
        limit: batchSize,
        inboundOperationsCount: inboundOperations.length,
        inboundQsosCount: inboundQsos.length,
        opWatermark: opWatermark,
        qsoWatermark: qsoWatermark,
      );
      _errorCount = 0;

      if (!smallBatch) {
        final morePending = await operations.hasUnsynced() || await qsos.hasUnsynced();
        final fullPage = inboundOperations.length >= batchSize || inboundQsos.length >= batchSize;
        _scheduleLoop((morePending || fullPage) ? Duration.zero : _loopDelay);
      }
    } catch (_) {
      _errorCount++;
      if (!smallBatch && _errorCount < maxErrorRetries) {
        _scheduleLoop(_loopDelay + Duration(seconds: 1 << _errorCount));
      }
    } finally {
      _running = false;
    }
  }

  Future<Map<String, dynamic>> _buildPayload(
    SyncBatch batch, {
    required bool pull,
    required bool backfilling,
    required int limit,
  }) async {
    final operationCounts = await operations.syncCounts();
    final qsoCounts = await qsos.syncCounts();
    final state = settings.state;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    return {
      if (batch.operations.isNotEmpty)
        'operations': [
          for (final o in batch.operations) {...o.data, 'uuid': o.uuid, if (o.deleted) 'deleted': true},
        ],
      if (batch.qsos.isNotEmpty)
        'qsos': [
          for (final q in batch.qsos)
            {...q.data, 'uuid': q.uuid, 'operation': q.operationUuid, if (q.deleted) 'deleted': true},
        ],
      'meta': {
        'operationCount': operationCounts.total,
        'unsyncedOperationCount': operationCounts.pending,
        'qsoCount': qsoCounts.total,
        'unsyncedQSOCount': qsoCounts.pending,
        if (state['lastSyncAccountUUID'] != null) 'lastSyncAccountUUID': state['lastSyncAccountUUID'],
        // Only the periodic loop pulls — a small-batch round is a reaction
        // to a local write and doesn't need to ask "what's new" every time.
        // `inboundSync: true` is what actually gets the server to include
        // any operations/qsos in its response at all — `sync` below is just
        // the window/pagination details for it. Missing this flag (an easy
        // thing to miss porting from sync.js, since it's set right next to
        // `meta.sync` but is a separate field) silently gets an
        // account-info-only response back, no error, nothing to pull ever.
        // Backfill pages backward from `earliest.../now` with `anyClient:
        // true` (the account's whole history, any device); forward mode
        // asks only `syncedSinceMillis`/`anyClient: false` (this client's
        // own recent changes) once backfill has caught everything up.
        if (pull) 'inboundSync': true,
        if (pull)
          'sync': backfilling
              ? {
                  'operations': {
                    'syncedUntilMillis': (state['earliestOperationSyncedAtMillis'] as num?)?.toInt() ?? nowMillis,
                    'limit': limit,
                    'anyClient': true,
                  },
                  'qsos': {
                    'syncedUntilMillis': (state['earliestQSOSyncedAtMillis'] as num?)?.toInt() ?? nowMillis,
                    'limit': limit,
                    'anyClient': true,
                  },
                }
              : {
                  'operations': {
                    'syncedSinceMillis': (state['latestOperationSyncedAtMillis'] as num?)?.toInt() ?? 0,
                    'limit': limit,
                    'anyClient': false,
                  },
                  'qsos': {
                    'syncedSinceMillis': (state['latestQSOSyncedAtMillis'] as num?)?.toInt() ?? 0,
                    'limit': limit,
                    'anyClient': false,
                  },
                },
      },
    };
  }

  Future<void> _processResponseMeta(
    Map<String, dynamic> response, {
    required bool pull,
    required bool backfilling,
    required int limit,
    required int inboundOperationsCount,
    required int inboundQsosCount,
    SyncWatermark? opWatermark,
    SyncWatermark? qsoWatermark,
  }) async {
    final meta = (response['meta'] as Map?)?.cast<String, dynamic>() ?? const {};

    final suggestedBatchSize = (meta['suggestedSyncBatchSize'] as num?)?.toInt();
    if (suggestedBatchSize != null && suggestedBatchSize > 0) _largeBatchSize = suggestedBatchSize;

    final suggestedLoopDelayMillis = (meta['suggestedSyncLoopDelay'] as num?)?.toInt();
    if (suggestedLoopDelayMillis != null && suggestedLoopDelayMillis > 0) {
      _loopDelay = Duration(milliseconds: suggestedLoopDelayMillis);
    }

    // A small-batch round never requested a `meta.sync` page, so there's
    // nothing page-oriented (backfill cursor / forward watermark) to track.
    if (!pull) return;

    final state = settings.state;
    final updates = <String, dynamic>{};

    if (backfilling) {
      final newEarliestOp = opWatermark?.earliestSyncedAtMillis;
      if (newEarliestOp != null) {
        final current = (state['earliestOperationSyncedAtMillis'] as num?)?.toInt();
        if (current == null || newEarliestOp < current) updates['earliestOperationSyncedAtMillis'] = newEarliestOp;
      }
      final newEarliestQso = qsoWatermark?.earliestSyncedAtMillis;
      if (newEarliestQso != null) {
        final current = (state['earliestQSOSyncedAtMillis'] as num?)?.toInt();
        if (current == null || newEarliestQso < current) updates['earliestQSOSyncedAtMillis'] = newEarliestQso;
      }

      if (inboundOperationsCount < limit && inboundQsosCount < limit) {
        // Both sides came back short: nothing older is left server-side.
        // Backfill is done — hand off to forward mode, watermarked from now.
        final nowMillis = DateTime.now().millisecondsSinceEpoch;
        updates['completedFullSync'] = true;
        updates['latestOperationSyncedAtMillis'] = nowMillis;
        updates['latestQSOSyncedAtMillis'] = nowMillis;
      }
    } else {
      final newOpWatermark = opWatermark?.latestSyncedAtMillis;
      if (newOpWatermark != null) {
        final current = (state['latestOperationSyncedAtMillis'] as num?)?.toInt() ?? 0;
        if (newOpWatermark > current) updates['latestOperationSyncedAtMillis'] = newOpWatermark;
      }
      final newQsoWatermark = qsoWatermark?.latestSyncedAtMillis;
      if (newQsoWatermark != null) {
        final current = (state['latestQSOSyncedAtMillis'] as num?)?.toInt() ?? 0;
        if (newQsoWatermark > current) updates['latestQSOSyncedAtMillis'] = newQsoWatermark;
      }
    }

    if (updates.isNotEmpty) await settings.setState({...state, ...updates});
  }

  void _scheduleLoop(Duration delay) {
    if (!settings.enabled) return;
    _loopTimer?.cancel();
    _loopTimer = Timer(delay, () => unawaited(runOneRound(smallBatch: false)));
  }
}
