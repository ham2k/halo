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

import '../app_clock.dart';
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

/// What a manual [SyncEngine.retryNow] actually managed to do — the offline
/// detail view's "retry now" reports back with this, and an operator who taps
/// and is told nothing has learned nothing about whether we tried.
enum SyncRetryOutcome {
  /// The transport answered. Everything suspended on the offline state
  /// resumes on the same path an automatic recovery takes.
  reached,

  /// The transport did not answer — still offline, and the schedule is left
  /// exactly where it was (see [SyncEngine.retryNow]).
  unreachable,

  /// The round exited before it ever called the transport (nothing to push
  /// on a small batch, an account change waiting on the operator). Nothing
  /// was learned about reachability either way.
  notAttempted,

  /// Refused for coming too soon after the last one — see
  /// [SyncEngine.manualRetryFloor].
  throttled,

  /// A round was already on the network when the operator asked. That round
  /// is the attempt; its result arrives on its own.
  inFlight,

  /// Sync is switched off, so there is no probe to fire.
  disabled,
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

  /// Reports what a round learned about whether the sync service ANSWERED,
  /// which is not the same as whether the round succeeded: a rejected
  /// registration, a server 500 and a merge that threw all prove we reached
  /// it. The app layer feeds this to `ConnectivityService`, where it is the
  /// half of "offline" that OS reachability cannot see — a captive portal, or
  /// a router with no upstream, reports a perfectly good interface.
  ///
  /// Called with `true` every time the transport returns, and with `false`
  /// only when it throws something [isTransportFailure] recognises. Anything
  /// else it throws reports NOTHING: an extension host that is dead or
  /// disposed says nothing about the network, and guessing either way from it
  /// would either quieten real errors or hold the app in a false offline
  /// state.
  final void Function(bool reached)? onReachability;

  /// Called when this engine stops probing — sync switched off, or the engine
  /// disposed. Whatever it last reported through [onReachability] must be
  /// forgotten by the app's connectivity state: a verdict with nothing left
  /// to revise it is a verdict that stands forever, and "offline" standing
  /// forever suspends work and quietens errors on a working network.
  final void Function()? onProbeStopped;

  /// Whether an error thrown by [transport] means "no answer came back"
  /// (timeout, DNS, connection refused or reset) rather than "they answered
  /// and something went wrong". Supplied by the app layer — this package has
  /// no view of `package:http` or the extension host's error shapes, and the
  /// app already classifies exactly this for `ErrorPolicy`.
  ///
  /// Null leaves the engine unable to tell the two apart, which costs the
  /// service-reachability signal and the tighter probe ceiling; nothing else.
  final bool Function(Object error)? isTransportFailure;

  static const smallBatchSize = 10;
  static const defaultLargeBatchSize = 100; // matches sync.js
  static const debounceDelay = Duration(milliseconds: 500);
  static const debounceMaxWait = Duration(seconds: 3);
  static const defaultLoopDelay = Duration(seconds: 20);
  static const maxErrorBackoffShift = 8; // caps the exponential backoff at 2^8s; the loop itself never gives up

  /// The ceiling on the backoff while the failures are transport-shaped —
  /// tighter than [maxErrorBackoffShift]'s ~4.6 minutes, because the delay is
  /// then not just sync's own patience: this round is also the app's
  /// connectivity probe, so it is how long an operator who has walked back
  /// into coverage waits to be told so, and how long every suspended lookup
  /// and spot fetch stays suspended.
  static const unreachableBackoffCeiling = Duration(minutes: 2);

  /// How soon after one manual [retryNow] another may fire. Low on purpose —
  /// an operator tapping twice is asking twice — but not zero, so a held tap
  /// cannot become a request loop.
  static const manualRetryFloor = Duration(seconds: 5);
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

  /// Where each side's opaque server cursor lives in [SyncSettings.state]
  /// (LOFI-41). Four, not two: a cursor names a row's position in ONE sort,
  /// and backfill pages `synced_until` descending while forward mode pages
  /// `synced_since` ascending. The server refuses a cursor minted for the
  /// other window, so a shared key would cost a round every time the phase
  /// flips — and a phase flips back on every forced resync.
  static const backfillCursorKeys = {
    'operations': 'backfillOperationCursor',
    'qsos': 'backfillQSOCursor',
  };
  static const forwardCursorKeys = {
    'operations': 'forwardOperationCursor',
    'qsos': 'forwardQSOCursor',
  };

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

  /// Whether this run has already swept orphaned purged QSOs
  /// (`QsosRepository.hardDeletePurgedOrphans`) — see its call site for why
  /// that sweep is not run on every round.
  bool _sweptPurgedOrphans = false;

  /// True once the boost has hit its cap without the cursor moving: the
  /// loop then falls back to the ordinary delay instead of hammering the
  /// server with an identical full-page request at zero delay.
  bool _backfillStuckAtCap = false;

  /// When the loop timer will next fire, on the REAL clock — a scheduled
  /// wall-clock instant whose remainder becomes a `Timer` duration, so it
  /// must not travel (docs/design/time.md §1). Read by the offline detail
  /// view to say when the next attempt is due; null while nothing is
  /// scheduled.
  DateTime? _nextAttemptAt;

  /// Whether the transport answered during the round currently running —
  /// what tells [retryNow] whether its attempt learned anything. A round can
  /// return without ever calling the transport.
  bool? _roundReachedService;

  /// When the last manual retry fired, on the real clock (it gates a
  /// `Timer`-shaped floor, and a travelled clock must not open the gate).
  DateTime? _lastManualRetryAt;

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
    this.onReachability,
    this.onProbeStopped,
    this.isTransportFailure,
  });

  /// Whether sync may run at all right now.
  ///
  /// Ordinary rounds run while the clock is travelled. What a travelled
  /// session may WRITE is constrained instead — only test data (`WritePolicy`,
  /// docs/design/time.md §4) — so everything it can produce is identifiable
  /// and purgeable, and revision stamps are on the real clock regardless.
  /// A clock check here would protect nothing the write gate does not, and
  /// would make sync itself untestable on a travelled clock.
  bool get _mayRun => settings.enabled;

  /// Whether the app clock is time-travelled, which bars the DESTRUCTIVE entry
  /// points ([forceFullResync], [resolveAccountChange]) — not ordinary rounds.
  ///
  /// Those two wipe local data and rely on the round they schedule to refill
  /// it. That is a different hazard from the one the write gate covers: it is
  /// about a dev tool triggering a wipe at all, not about which records get
  /// written, so it stays.
  bool get travelRefusesSync => AppClock.instance.isTravelling;

  void start() {
    if (!_mayRun) {
      onProbeStopped?.call();
      return;
    }
    _scheduleLoop(Duration.zero);
  }

  void dispose() {
    // The flag matters as much as the cancels: a round already executing
    // reaches _scheduleLoop when it finishes and would otherwise resurrect
    // the loop against a disposed engine (and a closed database).
    _disposed = true;
    _debounceTimer?.cancel();
    _loopTimer?.cancel();
    _nextAttemptAt = null;
    onProbeStopped?.call();
  }

  /// Called by the repositories after every local write (wired in via their
  /// `onChange` callback). Debounces a "small batch" round so a burst of
  /// edits (e.g. typing) coalesces into one round, but never waits more than
  /// [debounceMaxWait] if edits keep arriving back-to-back.
  void notifyChanged() {
    if (!_mayRun) return;
    // Real time: the debounce window is a real wait, and its remainder becomes
    // a Timer duration (realNowUtc's doc comment, docs/design/time.md §1).
    final now = realNowUtc();
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
  /// Returns false without reconciling anything when sync may not run
  /// ([travelRefusesSync]) — `replace` wipes local data and both choices rely
  /// on the round scheduled at the end to refill or push, so a half-applied
  /// reconciliation is worse than a deferred one.
  Future<bool> resolveAccountChange(SyncAccountChoice choice) async {
    if (travelRefusesSync) return false;
    // Adopting "no account" is not a reconciliation, it's a de-link: the
    // device forgets which account it belongs to and the next round starts
    // the whole pending-account dance over, discarding whatever the user
    // just answered. Only a caller racing another resolution can get here
    // with nothing pending, and the right move is to let the resolution
    // that already ran stand.
    if (settings.state['pendingAccountUUID'] == null) return false;

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
      for (final key in [...backfillCursorKeys.values, ...forwardCursorKeys.values]) key: null,
    });
    _scheduleLoop(Duration.zero);
    return true;
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
    final data = accountData ?? await _callTransport('getAccountData', const {});
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
  /// Returns false without touching anything when sync may not run
  /// ([travelRefusesSync]).
  Future<bool> forceFullResync() async {
    // BEFORE the wipe, not at the reschedule below. This method deletes every
    // local operation and QSO into the backup tables and relies on the round it
    // schedules to pull them back; `_mayRun` refusing that round would leave the
    // live tables empty with no UI onto the backups and nothing that would ever
    // refill them.
    if (travelRefusesSync) return false;
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
      for (final key in [...backfillCursorKeys.values, ...forwardCursorKeys.values]) key: null,
    });
    _scheduleLoop(Duration.zero);
    return true;
  }

  /// Backs up and clears operations and QSOs as one transaction — a crash
  /// between the two would otherwise leave every QSO orphaned (parents
  /// gone) yet still counted and eligible for push. Both repositories share
  /// one database; their own inner transactions nest inside this one.
  Future<void> _backupAndClearAll() async {
    final backupId = nowUtc().toIso8601String();
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
    if (!_mayRun || _running) return;
    _running = true;
    // Cleared per round, not per call: [retryNow] reads it afterwards to tell
    // "we asked and got nothing" from "we never asked" (an account change
    // waiting on the operator, an empty small batch), which are different
    // answers to give someone who just tapped retry.
    _roundReachedService = null;
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
        final response = await _callTransport('getAccountData', const {});
        if (generation != _generation) return _abandonRound();
        final accountUuid = (response['current_account'] as Map?)?['uuid'] as String?;
        if (accountUuid != null) {
          await settings.setState({...settings.state, 'pendingAccountUUID': accountUuid});
          // The banner went live the moment that state was written, so the
          // user may have answered it while this check was awaiting —
          // adopting now would overwrite their answer with a guess.
          if (await _canAdoptAccountSilently(response)) {
            if (generation != _generation) return _abandonRound();
            // A silent adoption that gets REFUSED (travel started while this
            // round was on the network) must not leave `pendingAccountUUID`
            // behind: the banner it raises asks the operator to choose between
            // combining and WIPING, for an account this code just determined
            // needs no question asked. Put the pending state back and let a
            // later round — on a real clock — adopt it silently as intended.
            if (!await resolveAccountChange(SyncAccountChoice.combine)) {
              await settings.setState({...settings.state, 'pendingAccountUUID': null});
            }
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
      // Which cursor each side went out with, if any. The response alone cannot answer this: the
      // millisecond path hands back a cursor too (that is how a client enters cursor mode), so
      // `next_cursor` in the reply says nothing about how the page that carried it was built.
      // Read from the same state `_buildPayload` reads a line below.
      final sentCursors = <String, String?>{
        if (pull)
          for (final entry in (backfilling ? backfillCursorKeys : forwardCursorKeys).entries)
            entry.key: settings.state[entry.value] as String?,
      };
      final response = await _callTransport(
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
          // Refused (see the never-linked branch above): don't leave a pending
          // account behind, or the operator is asked to combine-or-wipe for an
          // account that needed no question asked.
          if (!await resolveAccountChange(SyncAccountChoice.combine)) {
            await settings.setState({...settings.state, 'pendingAccountUUID': null});
          }
        }
        return;
      }

      // Passes the sent models, not just uuids: markSynced compares each
      // row's revision stamp against the copy that actually went out, so an
      // edit made during the network await above stays dirty and re-pushes.
      await operations.markSynced(batch.operations);
      await qsos.markSynced(batch.qsos);

      // The deferred half of a Test Operation purge (`OperationsRepository.
      // purge`): sweeps every operation that is confirmed both `purged` and
      // `synced`, not just this round's own batch — see `hardDeletePurged`'s
      // doc for why a batch-scoped sweep would leave a crash-orphaned row
      // with no way back. Runs on every successful round, push or pull-only,
      // so a leftover from an earlier round's crash gets caught here too.
      final purgedUuids = await operations.hardDeletePurged();
      for (final uuid in purgedUuids) {
        await qsos.hardDeletePurgedForOperation(uuid);
      }
      final inboundOperations = (response['operations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final inboundQsos = (response['qsos'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (generation != _generation) return _abandonRound();
      final opWatermark = inboundOperations.isEmpty ? null : await operations.mergeFromSync(inboundOperations);
      final qsoWatermark = inboundQsos.isEmpty ? null : await qsos.mergeFromSync(inboundQsos);


      // The QSOs the `hardDeletePurgedForOperation` loop above can no longer
      // reach: their operation row is already gone (an earlier round's
      // sweep, or an operator confirming a received purge) and their own
      // purge tombstone only arrives in a later batch — so this runs AFTER
      // the merge that can create one, not before it, or every orphan waits
      // a whole round (and outlives a session that ends first).
      //
      // Gated, unlike the sweeps above: it scans the QSO table, which is the
      // big one, and a small-batch round fires seconds after every logged
      // QSO. An inbound purge tombstone is the only thing that can strand a
      // new orphan, and the once-per-run pass picks up anything left by an
      // earlier version or a round that never came back.
      if (!_sweptPurgedOrphans || inboundQsos.any((q) => q['purged'] == true)) {
        _sweptPurgedOrphans = true;
        await qsos.hardDeletePurgedOrphans();
      }

      if (generation != _generation) return _abandonRound();
      await _processResponseMeta(
        response,
        pull: pull,
        backfilling: backfilling,
        limit: pullLimit,
        sentCursors: sentCursors,
        inboundOperationsCount: inboundOperations.length,
        inboundQsosCount: inboundQsos.length,
        opWatermark: opWatermark,
        qsoWatermark: qsoWatermark,
      );

      // A received purge this device holds no QSOs for has nothing for the
      // operator to confirm removing, so it is dropped instead of prompted
      // about — see `hardDeleteEmptyReceivedPurges`. After the merges, so
      // this round's own tombstones are gone before the next round can
      // prompt about them, and after the watermarks are persisted, so a
      // deterministic failure in a housekeeping delete costs the sweep and
      // not the cursor — a throw before `_processResponseMeta` would re-pull
      // and re-die on the same page every round, forever, while pushes kept
      // succeeding. Logged because no operator confirmed it: nothing else
      // records that an operation row was removed here.
      final droppedPurges = await operations.hardDeleteEmptyReceivedPurges();
      if (droppedPurges.isNotEmpty) {
        log?.call('[sync] dropped ${droppedPurges.length} received purge(s) with nothing held here: '
            '${droppedPurges.join(', ')}');
      }

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
      final backoff = _loopDelay + Duration(seconds: 1 << backoffShift);
      // A round that failed because nothing answered is the connectivity
      // probe as well as a sync attempt, so it gets the tighter ceiling —
      // see [unreachableBackoffCeiling]. A round that failed for any other
      // reason keeps the general one: the service answered, and nothing is
      // waiting on this round to declare us back online.
      final unreachable = _roundReachedService == false;
      _scheduleLoop(unreachable && backoff > unreachableBackoffCeiling ? unreachableBackoffCeiling : backoff);
    } finally {
      _running = false;
    }
  }

  /// The server's row cursor for one side, or null.
  ///
  /// Both spellings, like every other server-supplied key in this file (see `_processResponseMeta`'s
  /// knobs and `sideDone`'s counts): reading only one would leave a client that gets the other on
  /// the millisecond path with no signal — which is the stall this cursor exists to fix, failing
  /// silently. Type-tolerant for the same reason a throw here is worse than a miss: it would land
  /// after the merge but before the state write, losing the round's cursor AND watermark and
  /// re-pulling the identical page every round forever.
  static String? _cursorFrom(Map<String, dynamic> meta, String side) {
    final value = (meta[side] as Map?)?['next_cursor'] ?? (meta[side] as Map?)?['nextCursor'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// True when the server refused the cursor we sent for [side] (malformed, or minted for a
  /// different window — see LoFi's `decode_pagination_cursor`). It answers on the millisecond
  /// window instead, so the round is still useful; what must not happen is holding the refused
  /// cursor and re-sending it forever.
  static bool _cursorRefused(Map<String, dynamic> response, String side) {
    // Every hop is checked rather than cast: this runs after the merge and before the state
    // write, so a `TypeError` on an unexpected error shape would lose the round's cursor AND
    // watermark and then re-throw on the identical page every round — see [_cursorFrom].
    final errors = response['errors'];
    if (errors is! Map) return false;
    final forSide = errors[side];
    if (forSide is! Map) return false;
    final pagination = forSide['pagination'];
    return pagination is Map && pagination['cursor'] != null;
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
    // Real, not travelled: this value LEAVES the app as `syncedUntilMillis`
    // whenever the state carries no cursor yet (a fresh link, or right after a
    // forced resync), where the server pages backwards from it. See
    // realNowMillis's contract — "values compared against someone else's clock".
    //
    // Travel bars every round, so the only way a travelled value could get here
    // is a round that passed `_mayRun` and was still assembling when travel
    // started. Narrow, and this costs nothing to close.
    final backfillFrom = realNowMillis();

    return {
      if (batch.operations.isNotEmpty)
        'operations': [
          for (final o in batch.operations)
            {...o.data, 'uuid': o.uuid, if (o.deleted) 'deleted': true, if (o.purged) 'purged': true},
        ],
      if (batch.qsos.isNotEmpty)
        'qsos': [
          for (final q in batch.qsos)
            {
              ...q.data,
              'uuid': q.uuid,
              // `null`, never the local `''`, for a contact that belongs to no
              // operation (an ADIF import into the general log). Null is the
              // server's own shape for one: it drops a null operation from a
              // batch's lookup list, while `''` is taken for a uuid it has
              // never seen and sends it down the create-the-missing-operation
              // path — which then fails that operation's `uuid` presence
              // validation. The contact still lands (the failed parent leaves
              // the foreign key null rather than aborting the write), so this
              // is contract rather than repair, but every batch of loose
              // contacts otherwise costs a doomed write it never reports.
              'operation': q.operationUuid.isEmpty ? null : q.operationUuid,
              if (q.deleted) 'deleted': true,
              if (q.purged) 'purged': true,
            },
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
                    'syncedUntilMillis': (state['earliestOperationSyncedAtMillis'] as num?)?.toInt() ?? backfillFrom,
                    if (state[backfillCursorKeys['operations']!] != null)
                      'cursor': state[backfillCursorKeys['operations']!],
                    'limit': limit,
                    'anyClient': true,
                  },
                  'qsos': {
                    'syncedUntilMillis': (state['earliestQSOSyncedAtMillis'] as num?)?.toInt() ?? backfillFrom,
                    if (state[backfillCursorKeys['qsos']!] != null) 'cursor': state[backfillCursorKeys['qsos']!],
                    'limit': limit,
                    'anyClient': true,
                  },
                }
              : {
                  'operations': {
                    'syncedSinceMillis': (state['latestOperationSyncedAtMillis'] as num?)?.toInt() ?? 0,
                    if (state[forwardCursorKeys['operations']!] != null)
                      'cursor': state[forwardCursorKeys['operations']!],
                    'limit': limit,
                    'anyClient': false,
                  },
                  'qsos': {
                    'syncedSinceMillis': (state['latestQSOSyncedAtMillis'] as num?)?.toInt() ?? 0,
                    if (state[forwardCursorKeys['qsos']!] != null) 'cursor': state[forwardCursorKeys['qsos']!],
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
    Map<String, String?> sentCursors = const {},
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
    //
    // A forward page built from a CURSOR is the one case where the highest stamp delivered is not
    // safe to bank: such a page stops exactly at the limit, mid-millisecond included, so records
    // sharing that last stamp may not have been sent. The fallback window is `> watermark`, which
    // would skip them silently and count them nowhere. Banking one millisecond lower re-covers
    // that stamp; the re-delivery is idempotent, and it is only ever read if the cursor is lost.
    // The millisecond path needs no such care — it extends over its whole edge millisecond.
    void bankForward(String key, int? latest, String side) {
      if (latest == null) return;
      final candidate = (!backfilling && sentCursors[side] != null) ? latest - 1 : latest;
      final current = (state[key] as num?)?.toInt() ?? 0;
      if (candidate > current) updates[key] = candidate;
    }

    bankForward('latestOperationSyncedAtMillis', opWatermark?.latestSyncedAtMillis, 'operations');
    bankForward('latestQSOSyncedAtMillis', qsoWatermark?.latestSyncedAtMillis, 'qsos');

    // Forward mode pages `synced_since` ascending, and carries exactly the same tie hazard the
    // backfill hit — a millisecond holding more records than a page can never be paged past.
    // Rarer (it needs that many records to arrive in one millisecond after this device caught
    // up) but identical in shape, and the server offers the cursor on both windows.
    if (!backfilling) {
      for (final side in forwardCursorKeys.keys) {
        final cursor = _cursorFrom(meta, side);
        final inbound = side == 'operations' ? inboundOperationsCount : inboundQsosCount;
        if (cursor != null) {
          updates[forwardCursorKeys[side]!] = cursor;
        } else if (inbound > 0 || _cursorRefused(response, side)) {
          // A page came back and named no position, or the one we sent was refused. Keeping the
          // old cursor would pin us there: the server ignores `syncedSinceMillis` entirely once a
          // valid cursor arrives, so we would be served the same tail every round until a page
          // happened to land exactly on the limit. Dropping it falls back to the watermark, which
          // this round has just advanced.
          //
          // `inbound > 0`, not "no cursor": a cooldown-gated response carries counts and NO page
          // at all, and clearing a live cursor for that would throw away a good position.
          updates[forwardCursorKeys[side]!] = null;
        }
      }
    }

    if (backfilling) {
      var cursorAdvanced = false;
      var timestampTieStuck = false;
      var cursorStuck = false;

      // Advances one side's backfill position.
      //
      // The server's own cursor (LOFI-41) names a ROW — `(syncedAtMillis, id)`, opaque — rather
      // than a millisecond, and is the only thing that can resume inside a tie. Deriving one
      // from the page instead is what stalled N4TRD's backfill: a millisecond cannot address a
      // position within itself, so once a tie grew past a page the same records came back
      // forever.
      //
      // The millisecond watermark is tracked beside it as the fallback for a server that stops
      // honouring cursors — a rolling deploy landing on an older node, a refused cursor after a
      // format bump — and is what `_reportProgress` and a forced resync read.
      //
      // Which value is safe depends on how the page was built, and the two are opposites:
      //
      //   - No cursor sent: `earliest`. The server extends such a page over its whole edge
      //     millisecond, so `< earliest` skips nothing. `earliest + 1` here asks for
      //     `< earliest + 1`, re-requesting that millisecond every round — which is precisely
      //     what stalled N4TRD. app-polo has always stored the stamp as-is.
      //   - Cursor sent: `earliest + 1`. Such a page stops at the limit wherever that lands, so
      //     records sharing `earliest` may not have been delivered, and a fallback to `< earliest`
      //     would skip them permanently while `records_left` counted down to zero around them.
      //     `+ 1` re-covers the stamp idempotently. It cannot reintroduce the stall, because it
      //     is read only when the cursor is already gone.
      void advanceCursor(String side, String millisKey, String cursorKey, SyncWatermark? watermark, int inboundCount) {
        final serverCursor = _cursorFrom(meta, side);
        if (serverCursor != null) {
          updates[cursorKey] = serverCursor;
          if (serverCursor == sentCursors[side] && inboundCount >= limit) {
            // The server handed back the very cursor we sent, on a full page: the next round
            // would re-request this same page. Nothing else bounds that — `timestampTieStuck`
            // cannot fire while a cursor exists, and `_scheduleLoop` runs a full page at zero
            // delay — so say so here, or a server echoing a stuck cursor spins the loop as fast
            // as its own cooldown allows.
            cursorStuck = true;
          } else {
            cursorAdvanced = true;
          }
        } else if (inboundCount > 0 || _cursorRefused(response, side)) {
          // See the forward branch: a page that named no position, or a refused cursor, must not
          // leave us pinned to a stale one. Not on an empty page — that is a cooldown-gated
          // response, and the cursor we hold is still the right place to resume.
          updates[cursorKey] = null;
        }

        final earliest = watermark?.earliestSyncedAtMillis;
        if (earliest == null) return;
        final fallback = sentCursors[side] != null ? earliest + 1 : earliest;
        final current = (state[millisKey] as num?)?.toInt();
        if (current == null || fallback < current) {
          updates[millisKey] = fallback;
          if (serverCursor == null) cursorAdvanced = true;
        } else if (serverCursor == null && inboundCount >= limit && earliest == watermark?.latestSyncedAtMillis) {
          // A full page of one single timestamp that cannot move the cursor: the tie is larger
          // than the page and, with no row-level cursor to resume from, only a bigger page
          // reaches its remainder. Unreachable once the server offers a cursor, which is the
          // point of asking for one.
          timestampTieStuck = true;
        }
      }

      advanceCursor('operations', 'earliestOperationSyncedAtMillis', backfillCursorKeys['operations']!, opWatermark,
          inboundOperationsCount);
      advanceCursor('qsos', 'earliestQSOSyncedAtMillis', backfillCursorKeys['qsos']!, qsoWatermark, inboundQsosCount);

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
        // These name a position in the descending `synced_until` sort, which forward mode does
        // not page. The server refuses a cursor minted for the other window, so leaving them
        // behind would cost a round (and an error in the response) on the first forward pull.
        for (final key in backfillCursorKeys.values) {
          updates[key] = null;
        }
        _backfillLimitBoost = 1;
        _backfillStuckAtCap = false;
      } else if (cursorStuck) {
        // A cursor that will not move is not a page-size problem, so growing the limit is not the
        // answer — only backing off is.
        _backfillStuckAtCap = true;
        log?.call('[sync] backfill cursor came back unchanged; retrying at the loop delay');
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

  /// Every call to [transport] goes through here, which is what makes the
  /// reachability signal a fact about the network rather than an inference
  /// from how the round ended: the answer is observed at the one place it
  /// arrives, before any of the round's own logic can throw over it.
  Future<Map<String, dynamic>> _callTransport(String method, Map<String, dynamic> args) async {
    try {
      final response = await transport(method, args);
      _roundReachedService = true;
      onReachability?.call(true);
      return response;
    } on SyncTransportNotReady {
      // The extension host has not finished loading, so nothing was sent and
      // nothing can be concluded — see the type's own doc comment.
      rethrow;
    } catch (e) {
      // The classifier is injected, so a throw from it would replace the
      // round's real failure on its way up and cost the report that failure
      // was going to get. An unclassifiable error simply says nothing about
      // reachability, which is already this method's answer for one.
      var transport = false;
      try {
        transport = isTransportFailure?.call(e) ?? false;
      } catch (_) {}
      if (transport) {
        _roundReachedService = false;
        onReachability?.call(false);
      }
      rethrow;
    }
  }

  /// When the loop next fires, or null while nothing is scheduled. Real
  /// clock — see [_nextAttemptAt].
  DateTime? get nextAttemptAt => _nextAttemptAt;

  /// Fire a round NOW, abandoning the wait the backoff had scheduled — the
  /// offline detail view's "retry now", for an operator who has just walked
  /// back into coverage and should not have to sit out a two-minute ceiling.
  ///
  /// A failure here leaves the schedule exactly where it was. Tapping retry
  /// is a question, not a failed attempt: letting it feed the backoff would
  /// mean an operator who taps three times pushes their own next automatic
  /// attempt further out, which is the opposite of what they asked for.
  /// Success takes the ordinary path — [runOneRound] resets the count and
  /// reschedules — so recovery by hand and recovery on its own are the same
  /// code.
  Future<SyncRetryOutcome> retryNow() async {
    if (!_mayRun) {
      onProbeStopped?.call();
      return SyncRetryOutcome.disabled;
    }
    // A round already in flight IS the attempt this tap is asking for —
    // [runOneRound] would return instantly and leave `notAttempted` as the
    // answer, which is the wrong thing to tell someone whose request is at
    // that moment on the network. Neither the throttle stamp nor
    // `_roundReachedService` is touched: the latter belongs to the running
    // round, which reads it in its own catch to pick a backoff ceiling.
    if (_running) return SyncRetryOutcome.inFlight;

    final now = realNowUtc();
    final last = _lastManualRetryAt;
    if (last != null && now.difference(last) < manualRetryFloor) return SyncRetryOutcome.throttled;
    _lastManualRetryAt = now;

    final savedErrorCount = _errorCount;
    final savedNextAttemptAt = _nextAttemptAt;
    _roundReachedService = null;
    await runOneRound();
    final reached = _roundReachedService;
    if (reached == null) return SyncRetryOutcome.notAttempted;
    if (reached) return SyncRetryOutcome.reached;

    _errorCount = savedErrorCount;
    // Only when there IS a saved schedule to put back. With none, the round's
    // own catch has just scheduled the right thing — reaching for [_loopDelay]
    // here would replace a considered backoff with a flat 20 seconds, which is
    // neither "where it was" nor anything this method promises.
    final remaining = savedNextAttemptAt?.difference(realNowUtc());
    if (remaining != null) _scheduleLoop(remaining > Duration.zero ? remaining : _loopDelay);
    return SyncRetryOutcome.unreachable;
  }

  void _scheduleLoop(Duration delay) {
    if (!_mayRun || _disposed) {
      // The one place every "no next round" path converges, whichever way it
      // got here — the setting turned off, dispose, a round that failed after
      // either. Announced from here rather than from each of them so a new
      // exit cannot forget to.
      _nextAttemptAt = null;
      onProbeStopped?.call();
      return;
    }
    _loopTimer?.cancel();
    // Real clock: the remainder of this instant becomes a Timer duration, and
    // a travelled session must not push the next sync attempt into next week
    // (docs/design/time.md §1).
    _nextAttemptAt = realNowUtc().add(delay);
    _loopTimer = Timer(delay, () => unawaited(runOneRound(smallBatch: false)));
  }
}
