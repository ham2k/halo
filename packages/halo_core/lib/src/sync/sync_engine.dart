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
// (`pendingAccountUUID`) until the app layer calls [resolveAccountChange],
// unless [_canAdoptAccountSilently] finds nothing to reconcile and answers
// on the user's behalf.
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

/// Thrown by a [SyncTransportCall] that cannot run YET, as opposed to one that
/// failed.
///
/// The transport reaches the network through the `ham2k-lofi` extension, so it
/// is unusable until the extension host has finished loading — which on a cold
/// start is after the first periodic round has already fired. Without this
/// distinction, every launch would count a sync failure and file a crash
/// report for a race that resolves itself a moment later.
///
/// [SyncEngine.runOneRound] treats this like its other "nothing to do right
/// now" exits: reschedule, no error count, no onError.
class SyncTransportNotReady implements Exception {
  final String message;
  const SyncTransportNotReady([this.message = 'sync transport is not ready yet']);

  @override
  String toString() => 'SyncTransportNotReady: $message';
}

/// Sync-related state the engine reads/writes, backed by the app's
/// SettingsService (SharedPreferences) rather than a drift table — see the
/// design note in DESIGN.md §6: it's a handful of scalars, not per-row data.
abstract class SyncSettings {
  bool get enabled;
  Map<String, dynamic> get state;
  Future<void> setState(Map<String, dynamic> state);
  bool get developerMode => false;
  Future<void> setDeveloperMode(bool enabled) async {}

  /// The active profile's operator callsign — empty before onboarding sets
  /// one. Used only to decide whether a rejected registration is worth
  /// telling the user about (see `runOneRound`'s handling of a `sync`
  /// response's `error`): a device with no callsign and nothing logged yet
  /// has nothing at stake, so there's nothing to warn about.
  String get operatorCall => '';
}

class SyncBatch {
  final List<Operation> operations;
  final List<Qso> qsos;
  const SyncBatch({this.operations = const [], this.qsos = const []});
  bool get isEmpty => operations.isEmpty && qsos.isEmpty;
}

/// Server-reported sync progress, for the app layer to surface (status bar,
/// Settings). The counts come from the sync response's per-side meta
/// (`records_left` / `total_records`) — the server includes them even in
/// cooldown-gated responses that carry no records, so progress stays fresh
/// between real pages. [backfilling] flips false on the round that
/// completes the backfill, so the surface can finish and dismiss itself.
class SyncProgress {
  final bool backfilling;
  final int? qsosTotal;
  final int? qsosLeft;
  final int? operationsTotal;
  final int? operationsLeft;

  const SyncProgress({
    required this.backfilling,
    this.qsosTotal,
    this.qsosLeft,
    this.operationsTotal,
    this.operationsLeft,
  });
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

  /// Diagnostic sink (e.g. `debugPrint` in the app). Sync failures degrade
  /// silently into backoff by design, but they must not be *invisible*.
  final void Function(String message)? log;

  /// Reports a round failure to crash reporting, in addition to [log]'s
  /// plain-text line — same shape as `ErrorReportingService.report` so the
  /// app layer can wire it in directly (`onError: ErrorReportingService.
  /// report`) rather than wrapping it. Null when the app layer doesn't want
  /// round failures reported (this package stays free of a Sentry/Flutter
  /// dependency itself — file header).
  ///
  /// Fires on the round that reaches [errorReportThreshold] consecutive
  /// failures, and on no other — see the catch in [runOneRound]. [log] still
  /// takes every one.
  final void Function(Object error, StackTrace? stackTrace, {String? context})? onError;

  /// Called once a `sync` round comes back rejected (the transport's
  /// `error`/`error_status`, e.g. a brand-new client registration the server
  /// refuses) for [authErrorNotifyThreshold] consecutive rounds in a row —
  /// a stuck rejection, as opposed to a one-off blip that clears on its
  /// own. Distinct from [onError]: the server saying no is a known, expected
  /// outcome of the sync flow, not a bug, so it is never reported to crash
  /// reporting — the app layer surfaces it to the user instead, with a way
  /// to act on it (e.g. a status bar notice pointing at Settings).
  final void Function(String message, {int? status})? onAuthError;

  /// Called with server-reported counts after each backfill round (and once
  /// more, with `backfilling: false`, on the round that completes it) — see
  /// [SyncProgress]. Null when the app layer doesn't surface progress.
  final void Function(SyncProgress progress)? onProgress;

  static const smallBatchSize = 10;
  static const defaultLargeBatchSize = 100; // matches sync.js
  static const debounceDelay = Duration(milliseconds: 500);
  static const debounceMaxWait = Duration(seconds: 3);
  static const defaultLoopDelay = Duration(seconds: 20);
  static const maxErrorBackoffShift = 8; // caps the exponential backoff at 2^8s; the loop itself never gives up
  static const authErrorNotifyThreshold = 3; // ~a minute of retries before bothering the user

  /// Consecutive failed rounds before one is worth crash-reporting.
  ///
  /// The loop retries forever by design, so reporting every failure files an
  /// event every few minutes for as long as a device is offline — thousands
  /// of them, all describing a tunnel, none actionable. Waiting for a streak
  /// costs nothing real: a deterministic fault repeats every round (a failed
  /// round marks nothing synced, so the very same batch comes back) and
  /// still arrives, about a minute late, while a blip never arrives at all.
  static const errorReportThreshold = 3;

  /// Cap for [_backfillLimitBoost] — see `_processResponseMeta`'s
  /// stuck-cursor handling.
  static const maxBackfillLimitBoost = 64;

  int _largeBatchSize = defaultLargeBatchSize;
  Duration _loopDelay = defaultLoopDelay;
  int _errorCount = 0;
  int _authErrorStreak = 0;
  bool _running = false;
  bool _disposed = false;

  /// Bumped by [resolveAccountChange]/[forceFullResync] so a round whose
  /// network call was in flight when the tables were wiped (or the account
  /// switched) abandons its response instead of marking rows synced,
  /// merging a pre-wipe page into freshly cleared tables, or clobbering the
  /// just-reset sync state with its stale snapshot.
  int _generation = 0;

  /// Multiplier on the backfill pull limit, doubled whenever a full page
  /// fails to advance the cursor (every record sharing one syncedAtMillis)
  /// and reset once it moves — see `_processResponseMeta`.
  int _backfillLimitBoost = 1;

  /// True once the boost has hit its cap without the cursor moving: the
  /// loop then falls back to the ordinary delay instead of hammering the
  /// server with an identical full-page request at zero delay.
  bool _backfillStuckAtCap = false;

  Timer? _debounceTimer;
  DateTime? _debounceStartedAt;
  Timer? _loopTimer;

  SyncEngine({
    required this.operations,
    required this.qsos,
    required this.transport,
    required this.settings,
    this.log,
    this.onProgress,
    this.onError,
    this.onAuthError,
  });

  void start() {
    if (!settings.enabled) return;
    _scheduleLoop(Duration.zero);
  }

  void dispose() {
    // The flag matters as much as the cancels: a round already executing
    // reaches _scheduleLoop when it finishes and would otherwise resurrect
    // the loop against a disposed engine (and a closed database).
    _disposed = true;
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
    // Adopting "no account" is not a reconciliation, it's a de-link: the
    // device forgets which account it belongs to and the next round starts
    // the whole pending-account dance over, discarding whatever the user
    // just answered. Only a caller racing another resolution can get here
    // with nothing pending, and the right move is to let the resolution
    // that already ran stand.
    if (settings.state['pendingAccountUUID'] == null) return;

    _generation++; // invalidate any round whose transport call is in flight
    if (choice == SyncAccountChoice.replace) {
      await _backupAndClearAll();
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
      'latestOperationSyncedAtMillis': null,
      'latestQSOSyncedAtMillis': null,
    });
    _scheduleLoop(Duration.zero);
  }

  /// Whether a new or changed account can be adopted without asking the
  /// user, because one of the two logs about to meet is empty: this device
  /// has no QSOs, or the account has neither operations nor QSOs. Combine
  /// and replace then have the same outcome, so the Settings banner would
  /// be a question with only one answer — and it would greet every new
  /// install, which starts with sync on and an empty log.
  ///
  /// Operations alone don't count as local data worth asking about: an
  /// operation with no QSOs in it is a container, not a log, and combining
  /// merges it in rather than losing it.
  ///
  /// app-polo's `askAboutMergingAccounts` tests the same two sides but
  /// additionally requires an operation to exist before it will skip on an
  /// empty local log. We deliberately don't: there, the rule only runs on a
  /// *changed* account, where a device with nothing at all is a strange
  /// state; here the same gate also covers a first link, which is exactly
  /// the moment a device legitimately has neither operations nor QSOs.
  ///
  /// [accountData] is a `getAccountData` payload when the caller already has
  /// one; null makes this fetch its own — only reached when the local side
  /// didn't already answer yes. Both totals must be present and zero: a
  /// payload that reports neither says nothing about the account, and
  /// reading that silence as "empty" would adopt an account whose history
  /// this device is about to be merged into unasked.
  Future<bool> _canAdoptAccountSilently(Map<String, dynamic>? accountData) async {
    if ((await qsos.syncCounts()).total == 0) return true;
    final data = accountData ?? await transport('getAccountData', const {});
    return _accountTotal(data, 'operations') == 0 && _accountTotal(data, 'qsos') == 0;
  }

  /// One side's record count out of a `getAccountData` payload, or null when
  /// the payload doesn't carry it. Deliberately shape-tolerant: `qsos` is a
  /// counts map there but a LIST of records in a `sync` response, and the
  /// two payloads meet in [_canAdoptAccountSilently].
  static int? _accountTotal(Map<String, dynamic> data, String side) {
    final counts = data[side];
    return counts is Map ? (counts['total'] as num?)?.toInt() : null;
  }

  /// The `SYNCALL` debug command: back up and wipe local data, then run a
  /// fresh backfill under whatever account is already linked. Reuses
  /// [SyncAccountChoice.replace]'s mechanism, but there's no account change
  /// here — `lastSyncAccountUUID`/`pendingAccountUUID` are left alone.
  Future<void> forceFullResync() async {
    _generation++; // see resolveAccountChange
    await _backupAndClearAll();

    final state = settings.state;
    await settings.setState({
      ...state,
      'completedFullSync': false,
      'earliestOperationSyncedAtMillis': null,
      'earliestQSOSyncedAtMillis': null,
      'latestOperationSyncedAtMillis': null,
      'latestQSOSyncedAtMillis': null,
    });
    _scheduleLoop(Duration.zero);
  }

  /// Backs up and clears operations and QSOs as one transaction — a crash
  /// between the two would otherwise leave every QSO orphaned (parents
  /// gone) yet still counted and eligible for push. Both repositories share
  /// one database; their own inner transactions nest inside this one.
  Future<void> _backupAndClearAll() async {
    final backupId = DateTime.now().toUtc().toIso8601String();
    await operations.db.transaction(() async {
      await operations.backupAndClearAll(backupId);
      await qsos.backupAndClearAll(backupId);
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
    // Snapshot the reconciliation generation: if resolveAccountChange or
    // forceFullResync runs while this round awaits the network, everything
    // this round knows (its batch, its backfill flags, its state snapshot)
    // describes a world that no longer exists — abandon the response.
    final generation = _generation;
    try {
      final state = settings.state;

      if (state['pendingAccountUUID'] != null) {
        if (!smallBatch) _scheduleLoop(_loopDelay);
        return;
      }

      if (state['lastSyncAccountUUID'] == null) {
        final response = await transport('getAccountData', const {});
        if (generation != _generation) return _abandonRound();
        final accountUuid = (response['current_account'] as Map?)?['uuid'] as String?;
        if (accountUuid != null) {
          await settings.setState({...settings.state, 'pendingAccountUUID': accountUuid});
          // The banner went live the moment that state was written, so the
          // user may have answered it while this check was awaiting —
          // adopting now would overwrite their answer with a guess.
          if (await _canAdoptAccountSilently(response)) {
            if (generation != _generation) return _abandonRound();
            await resolveAccountChange(SyncAccountChoice.combine);
            return;
          }
        }
        if (!smallBatch) _scheduleLoop(_loopDelay);
        return;
      }

      final backfilling = state['completedFullSync'] != true;
      final batchSize = smallBatch ? smallBatchSize : _largeBatchSize;
      // The pull limit grows past the push batch size only while a backfill
      // cursor is stuck on a page of identical timestamps — see
      // _processResponseMeta.
      final pullLimit = backfilling ? batchSize * _backfillLimitBoost : batchSize;
      final batch = await selectBatch(qsoBatchSize: batchSize, operationBatchSize: batchSize);

      if (batch.isEmpty && smallBatch) return;

      final pull = !smallBatch;
      final response = await transport(
        'sync',
        await _buildPayload(batch, pull: pull, backfilling: backfilling, limit: pullLimit),
      );
      if (generation != _generation) return _abandonRound();

      // The transport turns a rejected round into data instead of throwing
      // (see ham2k-lofi's `sync`) — a stale registration is a known outcome
      // of the sync flow, not a transport failure, so it does not count
      // against _errorCount or reach onError/crash reporting. It only
      // reaches the user, via onAuthError, once it's stuck rather than a
      // one-off blip.
      final responseError = response['error'] as String?;
      if (responseError != null) {
        if (settings.operatorCall.isEmpty && batch.isEmpty) {
          // Nothing at stake: no callsign configured yet and nothing local
          // to push this round either, so a rejected registration has
          // nothing to warn about — stay fully silent, not even counted
          // toward the streak, rather than nagging someone who hasn't
          // started using the app yet.
          if (!smallBatch) _scheduleLoop(_loopDelay);
          return;
        }
        _authErrorStreak++;
        log?.call('[sync] round rejected (streak #$_authErrorStreak): $responseError');
        if (_authErrorStreak == authErrorNotifyThreshold) {
          onAuthError?.call(responseError, status: response['error_status'] as int?);
        }
        final backoffShift = _authErrorStreak < maxErrorBackoffShift ? _authErrorStreak : maxErrorBackoffShift;
        if (!smallBatch) _scheduleLoop(_loopDelay + Duration(seconds: 1 << backoffShift));
        return;
      }
      _authErrorStreak = 0;

      final responseAccountUuid = (response['account'] as Map?)?['uuid'] as String?;
      if (responseAccountUuid != null && responseAccountUuid != state['lastSyncAccountUUID']) {
        // Re-registered under a different account mid-stream: don't mark
        // anything synced or merge this response — same pause-and-ask
        // treatment as a fresh link. (Fresh state read: the snapshot above
        // predates the network call.)
        await settings.setState({...settings.state, 'pendingAccountUUID': responseAccountUuid});
        // A `sync` response carries the bare account, no totals, so the
        // server side of this test costs its own fetch — which is why it
        // only happens when the local side didn't already settle it.
        if (await _canAdoptAccountSilently(null)) {
          // Same race as the never-linked branch above, and a wider window:
          // this check makes its own network call.
          if (generation != _generation) return _abandonRound();
          await resolveAccountChange(SyncAccountChoice.combine);
        }
        return;
      }

      // Passes the sent models, not just uuids: markSynced compares each
      // row's revision stamp against the copy that actually went out, so an
      // edit made during the network await above stays dirty and re-pushes.
      await operations.markSynced(batch.operations);
      await qsos.markSynced(batch.qsos);

      final inboundOperations = (response['operations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final inboundQsos = (response['qsos'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (generation != _generation) return _abandonRound();
      final opWatermark = inboundOperations.isEmpty ? null : await operations.mergeFromSync(inboundOperations);
      final qsoWatermark = inboundQsos.isEmpty ? null : await qsos.mergeFromSync(inboundQsos);

      if (generation != _generation) return _abandonRound();
      await _processResponseMeta(
        response,
        pull: pull,
        backfilling: backfilling,
        limit: pullLimit,
        inboundOperationsCount: inboundOperations.length,
        inboundQsosCount: inboundQsos.length,
        opWatermark: opWatermark,
        qsoWatermark: qsoWatermark,
      );
      _errorCount = 0;

      if (!smallBatch) {
        final morePending = await operations.hasUnsynced() || await qsos.hasUnsynced();
        final fullPage = inboundOperations.length >= pullLimit || inboundQsos.length >= pullLimit;
        _scheduleLoop((morePending || (fullPage && !_backfillStuckAtCap)) ? Duration.zero : _loopDelay);
      }
    } on SyncTransportNotReady catch (e) {
      // Not a failure: the extension host simply has not finished loading. Do
      // not count it, do not report it - just come back. Deliberately a short
      // fixed delay rather than the error backoff, because this clears in
      // seconds and the backoff would push the first real sync out for no
      // reason.
      log?.call('[sync] transport not ready, retrying shortly: $e');
      if (!smallBatch) _scheduleLoop(const Duration(seconds: 2));
    } catch (e, st) {
      _errorCount++;
      log?.call('[sync] round failed (error #$_errorCount${smallBatch ? ', small batch' : ''}): $e');
      // Exactly at the threshold, never past it: a device that stays
      // offline for a day would otherwise just swap a flood of first
      // failures for a flood of streak reports. A success resets the count
      // below, which is what makes it mean "still broken".
      if (_errorCount == errorReportThreshold) {
        onError?.call(e, st, context: 'sync:round #$_errorCount${smallBatch ? ' (small batch)' : ''}');
      }
      // Keep retrying no matter how many failures pile up (an extended
      // outage shouldn't permanently stop the periodic loop) — just cap
      // how far the backoff grows. A failed small-batch round pulls the
      // next periodic round forward too: its data would otherwise sit
      // dirty until whatever _loopDelay the server last suggested.
      final backoffShift = _errorCount < maxErrorBackoffShift ? _errorCount : maxErrorBackoffShift;
      _scheduleLoop(_loopDelay + Duration(seconds: 1 << backoffShift));
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

    // The real server nests its tuning knobs under `meta.flags` in
    // snake_case (api-lofi's Client#meta_for_client); accept app-polo's
    // full fallback chain — top-level camelCase, top-level snake_case, then
    // flags. Reading only top-level camelCase would silently ignore every
    // real server response, so the loop keeps its 20s default delay and each
    // post-page follow-up request lands inside the server's sync cooldown.
    final flags = (meta['flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    int? knob(String camel, String snake) => ((meta[camel] ?? meta[snake] ?? flags[snake]) as num?)?.toInt();

    final suggestedBatchSize = knob('suggestedSyncBatchSize', 'suggested_sync_batch_size');
    if (suggestedBatchSize != null && suggestedBatchSize > 0) _largeBatchSize = suggestedBatchSize;

    final suggestedLoopDelayMillis = knob('suggestedSyncLoopDelay', 'suggested_sync_loop_delay');
    if (suggestedLoopDelayMillis != null && suggestedLoopDelayMillis > 0) {
      _loopDelay = Duration(milliseconds: suggestedLoopDelayMillis);
    }

    // A small-batch round never requested a `meta.sync` page, so there's
    // nothing page-oriented (backfill cursor / forward watermark) to track.
    if (!pull) return;

    final state = settings.state;
    final updates = <String, dynamic>{};

    // The forward watermark accumulates from every merged record's
    // server-side syncedAtMillis — during backfill too. Substituting the
    // local clock at backfill completion would permanently skip records
    // other devices synced *while* this backfill ran (their
    // stamps fall between the backfill cursor and "now"), and anything in a
    // local-vs-server clock-skew window. Server stamps only, app-polo style.
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

    if (backfilling) {
      var cursorAdvanced = false;
      var timestampTieStuck = false;

      // The next cursor is the page's earliest stamp *plus one*, not the
      // stamp itself: several records can share one syncedAtMillis (server
      // bulk imports), and a page can end mid-tie. Asking "older than
      // earliest" next would silently skip the tie's remaining records;
      // "older than earliest+1" re-covers every record sharing that stamp
      // (idempotent — mergeFromSync skips what's already current) under
      // both `<` and `<=` server paging semantics.
      void advanceCursor(String key, SyncWatermark? watermark, int inboundCount) {
        final earliest = watermark?.earliestSyncedAtMillis;
        if (earliest == null) return;
        final newCursor = earliest + 1;
        final current = (state[key] as num?)?.toInt();
        if (current == null || newCursor < current) {
          updates[key] = newCursor;
          cursorAdvanced = true;
        } else if (inboundCount >= limit && earliest == watermark?.latestSyncedAtMillis) {
          // A full page of one single timestamp that can't move the cursor:
          // the tie is larger than the page and only a bigger page reaches
          // its remainder.
          timestampTieStuck = true;
        }
      }

      advanceCursor('earliestOperationSyncedAtMillis', opWatermark, inboundOperationsCount);
      advanceCursor('earliestQSOSyncedAtMillis', qsoWatermark, inboundQsosCount);

      // Trust the server's own records-left counts to decide whether older
      // history remains: a cooldown-gated or otherwise
      // short response must never be mistaken for "nothing left", or
      // completedFullSync flips permanently with a hole in the history.
      // Only when the server doesn't report a count does the old inference
      // — a page shorter than what was asked for — apply.
      bool sideDone(String key, int inboundCount) {
        final side = meta[key] as Map?;
        final left = ((side?['recordsLeft'] ?? side?['records_left']) as num?)?.toInt();
        return left != null ? left == 0 : inboundCount < limit;
      }

      if (sideDone('operations', inboundOperationsCount) && sideDone('qsos', inboundQsosCount)) {
        // Nothing older is left server-side. Backfill is done — forward
        // mode picks up from the largest server stamp accumulated above.
        updates['completedFullSync'] = true;
        _backfillLimitBoost = 1;
        _backfillStuckAtCap = false;
      } else if (timestampTieStuck) {
        if (_backfillLimitBoost < maxBackfillLimitBoost) {
          _backfillLimitBoost *= 2;
          log?.call('[sync] backfill cursor stuck on a timestamp tie; growing pull limit to ${_backfillLimitBoost}x');
        } else if (!cursorAdvanced) {
          _backfillStuckAtCap = true;
          log?.call('[sync] backfill cursor still stuck at the maximum pull limit; retrying at the loop delay');
        }
      } else {
        _backfillLimitBoost = 1;
        _backfillStuckAtCap = false;
      }

      _reportProgress(meta, completed: updates['completedFullSync'] == true);
    }

    // Fresh read, not the `state` snapshot from before this round's network
    // call — anything written during the await (e.g. a server-suggested
    // knob, an account flag) must not be clobbered by re-spreading it.
    if (updates.isNotEmpty) await settings.setState({...settings.state, ...updates});
  }

  /// Emits [onProgress] from a backfill round's response meta. Counts are
  /// read per side as `records_left`/`total_records` (either spelling) —
  /// present on real pages and cooldown responses alike. A response with no
  /// counts at all emits nothing (unless the backfill just completed, so
  /// the surface always gets its terminal update).
  void _reportProgress(Map<String, dynamic> meta, {required bool completed}) {
    if (onProgress == null) return;
    int? count(String side, String camel, String snake) {
      final sideMeta = meta[side] as Map?;
      return ((sideMeta?[camel] ?? sideMeta?[snake]) as num?)?.toInt();
    }

    final qsosLeft = count('qsos', 'recordsLeft', 'records_left');
    final qsosTotal = count('qsos', 'totalRecords', 'total_records');
    final operationsLeft = count('operations', 'recordsLeft', 'records_left');
    final operationsTotal = count('operations', 'totalRecords', 'total_records');
    if (!completed && qsosLeft == null && qsosTotal == null && operationsLeft == null && operationsTotal == null) return;

    onProgress!(SyncProgress(
      backfilling: !completed,
      qsosTotal: qsosTotal,
      qsosLeft: completed ? 0 : qsosLeft,
      operationsTotal: operationsTotal,
      operationsLeft: completed ? 0 : operationsLeft,
    ));
  }

  /// A round overtaken by a reconciliation: its response was discarded, but
  /// the round the reconciliation itself scheduled may already have no-op'd
  /// against `_running` while this one held it — reschedule so the fresh
  /// generation actually gets its round.
  void _abandonRound() {
    log?.call('[sync] round abandoned: a reconciliation ran while its network call was in flight');
    _scheduleLoop(Duration.zero);
  }

  void _scheduleLoop(Duration delay) {
    if (!settings.enabled || _disposed) return;
    _loopTimer?.cancel();
    _loopTimer = Timer(delay, () => unawaited(runOneRound(smallBatch: false)));
  }
}
