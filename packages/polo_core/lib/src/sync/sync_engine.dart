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

import 'dart:async';

import '../models/models.dart';
import '../repo/repositories.dart';

/// Calls the highest-priority `syncTransport` hook's `method` with `args`
/// and returns its JSON result. Implemented by the app layer (wrapping
/// `ExtensionHost.invokeHook`) so this package stays free of a Flutter/
/// extension-host dependency — the same reason `polo_core` has no Flutter
/// import today.
typedef SyncTransportCall = Future<Map<String, dynamic>> Function(String method, Map<String, dynamic> args);

/// Sync-related state the engine reads/writes, backed by the app's
/// SettingsService (SharedPreferences) rather than a drift table — see the
/// design note in DESIGN.md §6: it's a handful of scalars, not per-row data.
abstract class SyncSettings {
  bool get enabled;
  Map<String, dynamic> get state;
  Future<void> setState(Map<String, dynamic> state);
}

class SyncBatch {
  final List<Operation> operations;
  final List<Qso> qsos;
  const SyncBatch({this.operations = const [], this.qsos = const []});
  bool get isEmpty => operations.isEmpty && qsos.isEmpty;
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

  /// Runs one round of syncing: build a payload from [selectBatch], call the
  /// transport, mark what was sent as synced, and merge anything inbound.
  /// A "large batch" round (the periodic loop) reschedules itself — sooner,
  /// with no delay, if there's more to catch up on; after [defaultLoopDelay]
  /// otherwise. A "small batch" round (a debounced reaction to a local edit)
  /// never touches the loop's own schedule.
  Future<void> runOneRound({bool smallBatch = false}) async {
    if (!settings.enabled || _running) return;
    _running = true;
    try {
      final batchSize = smallBatch ? smallBatchSize : _largeBatchSize;
      final batch = await selectBatch(qsoBatchSize: batchSize, operationBatchSize: batchSize);

      if (batch.isEmpty) {
        if (!smallBatch) _scheduleLoop(_loopDelay);
        return;
      }

      final response = await transport('sync', await _buildPayload(batch));

      await operations.markSynced(batch.operations.map((o) => o.uuid));
      await qsos.markSynced(batch.qsos.map((q) => q.uuid));

      final inboundOperations = (response['operations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final inboundQsos = (response['qsos'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (inboundOperations.isNotEmpty) await operations.mergeFromSync(inboundOperations);
      if (inboundQsos.isNotEmpty) await qsos.mergeFromSync(inboundQsos);

      await _processResponseMeta(response);
      _errorCount = 0;

      if (!smallBatch) {
        final morePending = await operations.hasUnsynced() || await qsos.hasUnsynced();
        _scheduleLoop(morePending ? Duration.zero : _loopDelay);
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

  Future<Map<String, dynamic>> _buildPayload(SyncBatch batch) async {
    final operationCounts = await operations.syncCounts();
    final qsoCounts = await qsos.syncCounts();
    final state = settings.state;

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
      },
    };
  }

  Future<void> _processResponseMeta(Map<String, dynamic> response) async {
    final meta = (response['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final account = (response['account'] as Map?)?.cast<String, dynamic>();

    final suggestedBatchSize = (meta['suggestedSyncBatchSize'] as num?)?.toInt();
    if (suggestedBatchSize != null && suggestedBatchSize > 0) _largeBatchSize = suggestedBatchSize;

    final suggestedLoopDelayMillis = (meta['suggestedSyncLoopDelay'] as num?)?.toInt();
    if (suggestedLoopDelayMillis != null && suggestedLoopDelayMillis > 0) {
      _loopDelay = Duration(milliseconds: suggestedLoopDelayMillis);
    }

    final accountUuid = account?['uuid'] as String?;
    if (accountUuid != null && accountUuid != settings.state['lastSyncAccountUUID']) {
      await settings.setState({...settings.state, 'lastSyncAccountUUID': accountUuid});
    }
  }

  void _scheduleLoop(Duration delay) {
    if (!settings.enabled) return;
    _loopTimer?.cancel();
    _loopTimer = Timer(delay, () => unawaited(runOneRound(smallBatch: false)));
  }
}
