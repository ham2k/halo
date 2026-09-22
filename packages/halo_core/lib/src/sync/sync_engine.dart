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
import '../repo/operations_repository.dart';
import '../repo/qsos_repository.dart';
import 'sync_progress.dart';
import 'sync_types.dart';

class SyncEngine {
  final OperationsRepository operations;
  final QsosRepository qsos;
  final SyncTransportCall transport;
  final SyncSettings settings;

  /// Diagnostic sink (e.g. `debugPrint` in the app). Sync failures degrade
  /// silently into backoff by design, but they must not be *invisible*.
  /// See [defaultRefusalQuarantine]. Injectable so a test can drive the
  /// window; the real clock behind it cannot be wound forward.
  final Duration refusalQuarantine;

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

  /// Called after every periodic round that succeeded, with whether a push
  /// backlog is still draining: the round moved records out and more are
  /// dirty behind them, so the next round follows at once. `false` on any
  /// other successful outcome — caught up, a stalled push, pull-only. A round
  /// that failed or was overtaken by a reconciliation says nothing, so a
  /// `true` can stand until the next success; the app layer bounds that with
  /// its own idle timer. Backfill is NOT counted here; [onProgress] carries
  /// that. Null when the app layer has no use for it (it holds the device
  /// awake through a long first push).
  final void Function(bool draining)? onPushBacklog;

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

  /// The wait after a full page while paging through a large set — the
  /// server's `suggested_sync_loop_delay`, which api-lofi clamps to clear its
  /// own per-client cooldown (`Client#meta_for_client`), so a round that waits
  /// exactly this long is never gated. Also the base of the error backoff.
  static const defaultLoopDelay = Duration(seconds: 20);

  /// The wait between pulls once caught up — the server's
  /// `suggested_sync_check_period`, a different knob from [defaultLoopDelay]
  /// and the only one that sets the idle request rate: a plan whose cooldown
  /// is a second would otherwise have every linked device polling once a
  /// second all day.
  static const defaultCheckPeriod = Duration(seconds: 20);
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

  /// Rows per merge slice while backfilling — see
  /// [mergeQsosReportingProgress]. A prime on purpose: the count the
  /// footer shows climbs in steps that never land on a round number, which
  /// reads as records arriving rather than a meter ticking.
  static const mergeChunkSize = 743;

  /// Records requested per backfill page — a whole number of merge slices,
  /// so every slice but a short last page's is full.
  static const backfillPullLimit = mergeChunkSize * 7;

  /// api-lofi's `MAX_LIMIT` (`paginable.rb`). A request past it is clamped
  /// and still answered, so the limit this engine judges "full page" by must
  /// never exceed what the server can send — a clamped page would read as a
  /// short one, and on a server reporting no `records_left` a short page
  /// means the backfill is done.
  static const serverMaxPullLimit = 20000;

  /// Where each side's opaque server cursor lives in [SyncSettings.state]
  /// (LOFI-41). Four, not two: a cursor names a row's position in ONE sort,
  /// and backfill pages `synced_until` descending while forward mode pages
  /// `synced_since` ascending. The server refuses a cursor minted for the
  /// other window, so a shared key would cost a round every time the phase
  /// flips — and a phase flips back on every forced resync.
  static const backfillCursorKeys = {'operations': 'backfillOperationCursor', 'qsos': 'backfillQSOCursor'};
  static const forwardCursorKeys = {'operations': 'forwardOperationCursor', 'qsos': 'forwardQSOCursor'};

  int _largeBatchSize = defaultLargeBatchSize;

  /// How long a refused record is held out of the push batch before being
  /// offered again.
  ///
  /// Not "never again": a refusal is frequently temporary — a permission
  /// granted, an operation's owner adding this device, a server-side fix — and
  /// a record parked for good would be exactly the silent loss this whole
  /// change exists to end. Not "immediately" either: `unsyncedBatch` is a
  /// LIMIT ordered by time, so a refused record that sorts early refills the
  /// batch every round and starves everything behind it.
  static const defaultRefusalQuarantine = Duration(minutes: 10);

  /// `<side>:<uuid>:<reason>` for every refusal already sent to the crash
  /// backend this session — see [_reportRejections]. Session-scoped on
  /// purpose: a relaunch is the developer's cue that the state may have
  /// changed, and an unbounded lifetime would be a leak on a device stuck
  /// refusing a large batch.
  final Set<String> _reportedRejections = {};

  /// Refused record uuids, to the real-clock millisecond their quarantine
  /// ends. Two maps because the two sides are selected by separate queries.
  ///
  /// The REAL clock, never the app clock: this is a retry interval, and a
  /// travelled session would otherwise either expire every quarantine at once
  /// or never expire one (docs/design/time.md §4).
  final Map<String, int> _quarantinedOperations = {};
  final Map<String, int> _quarantinedQsos = {};

  /// A ceiling on each quarantine map, so the `NOT IN` these build stays a
  /// statement SQLite will accept. Past it the oldest entries are dropped and
  /// simply get offered again — a device refusing more records than this has a
  /// systemic problem the log already names, and starving its queue further
  /// would not help.
  static const _maxQuarantined = 400;
  Duration _loopDelay = defaultLoopDelay;
  Duration _checkPeriod = defaultCheckPeriod;
  int _errorCount = 0;
  int _authErrorStreak = 0;
  bool _running = false;

  /// Whether the round holding [_running] is a small-batch one.
  bool _runningSmallBatch = false;

  /// A periodic round the loop timer fired while a small-batch round held the
  /// engine. It cannot simply be skipped: a small-batch round that lands
  /// never re-arms the timer and never pulls — so a skipped one is the last,
  /// and the device keeps pushing its own contacts and never receives
  /// another. Run as soon as the engine is free instead — unless the
  /// small-batch round exits with a considered wait of its own (a failure's
  /// backoff, a rejection's), which the deferred round then takes; see
  /// [_scheduleAfter].
  bool _periodicRoundDeferred = false;

  /// The mirror image: a small-batch round that found any round on the
  /// engine. Its write is dirty and the running round's batch was selected
  /// before it, so dropping it leaves the record waiting a whole check
  /// period — behind a periodic round, or behind the previous contact's own
  /// push on a link slower than the debounce. Run once the engine is free;
  /// a deferred round with nothing left to send exits at once.
  bool _smallBatchDeferred = false;
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

  /// Ceiling on the pull limit, halved from the limit actually asked for
  /// each time a pull fails outright, lifted by the first page that lands.
  /// A page is megabytes under a fixed transport
  /// timeout: a link too slow for one page would otherwise time out on the
  /// identical request forever. Halved from what was ASKED for, not divided
  /// off the nominal page: a boosted page sits clamped at the server's cap,
  /// where a divisor takes several failures to change anything.
  int _pullPageCap = serverMaxPullLimit;

  /// Whether the round in flight pulls a page. Read by the failure path to
  /// decide the cap applies, and by the success path to decide it lifts — a
  /// push-only round that lands says nothing about page size.
  bool _pullInFlight = false;

  /// Whether this run has already swept orphaned purged QSOs
  /// (`QsosRepository.hardDeletePurgedOrphans`) — see its call site for why
  /// that sweep is not run on every round.
  bool _sweptPurgedOrphans = false;

  /// When the loop timer will next fire, on the REAL clock — a scheduled
  /// wall-clock instant whose remainder becomes a `Timer` duration, so it
  /// must not travel (docs/design/time.md §1). Read by the offline detail
  /// view to say when the next attempt is due; null while nothing is
  /// scheduled.
  DateTime? _nextAttemptAt;

  /// Whether the last backfill page came back on a cursor the server would
  /// not move (`_processResponseMeta`). Retried at the loop delay like any
  /// full page — unless that delay is zero, when re-serving the same page
  /// with no wait is a tight loop re-merging thousands of rows, so it waits
  /// the check period instead.
  bool _lastPageStuck = false;

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
    this.refusalQuarantine = defaultRefusalQuarantine,
    this.log,
    this.onProgress,
    this.onPushBacklog,
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
    // A reconciliation re-pushes everything, possibly against a different
    // account, so what was refused before says nothing about what will be
    // refused now — and a refusal already reported must be heard again if it
    // survives the change.
    _reportedRejections.clear();
    _quarantinedOperations.clear();
    _quarantinedQsos.clear();
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
  /// user, because this device has no QSOs: combine and replace then have
  /// the same outcome, so the Settings banner would be a question with only
  /// one answer — and it would greet every new install, which starts with
  /// sync on and an empty log.
  ///
  /// An empty ACCOUNT still asks. The log at stake is this device's, and
  /// whether it goes into that account or gets set aside for it is the
  /// operator's call — the account being empty doesn't make that choice.
  ///
  /// Operations alone don't count as local data worth asking about: an
  /// operation with no QSOs in it is a container, not a log, and combining
  /// merges it in rather than losing it.
  ///
  /// app-polo's `askAboutMergingAccounts` additionally requires an operation
  /// to exist before it will skip on an empty local log. We deliberately
  /// don't: there, the rule only runs on a *changed* account, where a device
  /// with nothing at all is a strange state; here the same gate also covers
  /// a first link, which is exactly the moment a device legitimately has
  /// neither operations nor QSOs.
  Future<bool> _canAdoptAccountSilently() async => (await qsos.syncCounts()).total == 0;

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
    _generation++;
    _reportedRejections.clear(); // see resolveAccountChange
    _quarantinedOperations.clear();
    _quarantinedQsos.clear();
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

  /// Where [_rewindForwardCursorOnce] records that it has run.
  static const tombstoneRewindKey = 'tombstoneRewindDone';

  /// Rewinds the forward pull window, once per install, so every record the
  /// account holds is delivered one more time.
  ///
  /// Recovery for a device that resurrected tombstoned records by reading a
  /// `deleted` flag in a dialect it did not understand (see [asQsonBool]).
  /// Such a row cannot be repaired from anything local — the flag is removed
  /// from the record before the blob is encoded — and the record that would
  /// correct it is never asked for again, because the forward cursor moved
  /// past it rounds ago. Only a re-delivery reaches it, and
  /// [inboundRepairsTombstone] is what makes that re-delivery land.
  ///
  /// The forward window ONLY, and no local data: leaving `completedFullSync`
  /// alone keeps a caught-up device out of backfill mode, and touching
  /// nothing in the tables is what separates this from [forceFullResync],
  /// which wipes them and relies on the pull to refill. Every record that
  /// arrives here either merges as it always would or is skipped as stale, so
  /// the cost is one extra pass over the account's history, paced by the
  /// server's own cooldown.
  ///
  /// Both halves are written together on purpose: a crash between marking the
  /// rewind done and clearing the cursor would spend the one chance at it.
  ///
  /// Walking old history through the forward window needs no pull-limit
  /// growth of the kind the backfill grows, and must not be given one: the
  /// server hands back a row cursor on every non-empty page (LOFI-41), which
  /// the forward branch of `_processResponseMeta` follows, and a page built
  /// without one is extended over its whole edge millisecond server-side. A
  /// millisecond holding more records than a page is passable either way.
  Future<Map<String, dynamic>> _rewindForwardCursorOnce(Map<String, dynamic> state) async {
    if (state[tombstoneRewindKey] == true) return state;
    final rewound = {
      ...state,
      tombstoneRewindKey: true,
      'latestOperationSyncedAtMillis': null,
      'latestQSOSyncedAtMillis': null,
      for (final key in forwardCursorKeys.values) key: null,
    };
    await settings.setState(rewound);
    log?.call('[sync] forward cursor rewound once, to re-deliver tombstones this device may have dropped');
    return rewound;
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
    final skipQsos = _activeQuarantine(_quarantinedQsos);
    final skipOperations = _activeQuarantine(_quarantinedOperations);
    final pendingQsos = await qsos.unsyncedBatch(qsoBatchSize, excluding: skipQsos);
    if (pendingQsos.isNotEmpty) {
      final operationUuids = {for (final q in pendingQsos) q.operationUuid}.toList();
      var pendingOperations = await operations.byUuids(operationUuids, onlyUnsynced: true);
      if (pendingOperations.length > operationBatchSize) {
        pendingOperations = pendingOperations.sublist(0, operationBatchSize);
      }
      return SyncBatch(operations: pendingOperations, qsos: pendingQsos);
    }
    return SyncBatch(operations: await operations.unsyncedBatch(operationBatchSize, excluding: skipOperations));
  }

  /// The uuids still inside their quarantine window, dropping the ones whose
  /// window has passed so they are offered again.
  Set<String> _activeQuarantine(Map<String, int> quarantine) {
    if (quarantine.isEmpty) return const {};
    final now = realNowMillis();
    quarantine.removeWhere((_, until) => until <= now);
    return quarantine.keys.toSet();
  }

  /// Holds refused uuids out of the next batches — see [refusalQuarantine].
  /// Re-refusing an already-quarantined record restarts its window, which is
  /// what keeps a permanently refused one out of the way while a transient one
  /// comes back on its own.
  void _quarantine(Iterable<String> uuids, Map<String, int> quarantine) {
    if (uuids.isEmpty) return;
    final until = realNowMillis() + refusalQuarantine.inMilliseconds;
    for (final uuid in uuids) {
      quarantine[uuid] = until;
    }
    if (quarantine.length <= _maxQuarantined) return;
    final byExpiry = quarantine.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in byExpiry.take(quarantine.length - _maxQuarantined)) {
      quarantine.remove(entry.key);
    }
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
  /// The pull limit as it stands this round: the page, grown by the backfill
  /// tie boost, held under the failure cap, and never past what the server
  /// will send or below one merge slice.
  int get _pullLimit => (backfillPullLimit * _backfillLimitBoost).clamp(mergeChunkSize, _pullPageCap.clamp(mergeChunkSize, serverMaxPullLimit));

  /// Once linked, a "small batch" round (a debounced reaction to a local
  /// edit) always has something to push, by construction, and never pulls.
  /// A "large batch" round (the periodic loop) always calls the transport,
  /// requesting either a backward-paging backfill page (until the account's
  /// full history has been fetched) or, once caught up, a forward page of
  /// anything new since the last watermark — so a device with nothing new
  /// to log still learns about QSOs logged elsewhere. It reschedules
  /// itself: with no delay while there's a local backlog to push, after the
  /// loop delay when a full page implies more is waiting server-side (the
  /// server sets that delay to clear its cooldown, so asking sooner only
  /// buys a gated, empty answer), and after the check period once caught
  /// up. If the account turns out to have
  /// changed mid-stream, that response is discarded and the pending-account
  /// flow starts over, the same as a fresh link.
  Future<void> runOneRound({bool smallBatch = false}) async {
    if (!_mayRun) return;
    if (_running) {
      if (smallBatch) {
        _smallBatchDeferred = true;
      } else if (_runningSmallBatch) {
        _periodicRoundDeferred = true;
      }
      return;
    }
    _running = true;
    _runningSmallBatch = smallBatch;
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
      var state = settings.state;

      if (state['pendingAccountUUID'] != null) {
        _scheduleAfter(smallBatch, _checkPeriod);
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
          if (await _canAdoptAccountSilently()) {
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
        _scheduleAfter(smallBatch, _checkPeriod);
        return;
      }

      state = await _rewindForwardCursorOnce(state);

      final backfilling = state['completedFullSync'] != true;
      final batchSize = smallBatch ? smallBatchSize : _largeBatchSize;
      // Every pull asks for big pages, not the plan's batch size: every page
      // costs a loop-delay wait and merges at ~0.1 ms/row, so the page count
      // is the catch-up's duration. That holds in forward mode as much as in
      // the backfill — a device away for a season, or one re-walking history
      // after a cursor rewind, has thousands of rows ahead of its watermark,
      // and at the plan's 50-row batch every 35 s it takes an hour of
      // foreground time that a phone opened for minutes at a stretch never
      // accumulates. A caught-up device asks for the same page and gets a
      // handful of rows; the limit is a cap, not a cost. The push batch
      // stays at the plan's size — that is where the server does per-record
      // work.
      final pullLimit = _pullLimit;
      final batch = await selectBatch(qsoBatchSize: batchSize, operationBatchSize: batchSize);

      if (batch.isEmpty && smallBatch) return;

      final pull = !smallBatch;
      // Which cursor each side went out with, if any. The response alone cannot answer this: the
      // millisecond path hands back a cursor too (that is how a client enters cursor mode), so
      // `next_cursor` in the reply says nothing about how the page that carried it was built.
      // Read from the same state `_buildPayload` reads a line below.
      final sentCursors = <String, String?>{
        if (pull)
          for (final entry in (backfilling ? backfillCursorKeys : forwardCursorKeys).entries) entry.key: settings.state[entry.value] as String?,
      };
      _pullInFlight = pull;
      final response = await _callTransport('sync', await _buildPayload(batch, pull: pull, backfilling: backfilling, limit: pullLimit));
      if (_pullInFlight) _pullPageCap = serverMaxPullLimit;
      _pullInFlight = false;
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
          _scheduleAfter(smallBatch, _checkPeriod);
          return;
        }
        _authErrorStreak++;
        log?.call('[sync] round rejected (streak #$_authErrorStreak): $responseError');
        if (_authErrorStreak == authErrorNotifyThreshold) {
          onAuthError?.call(responseError, status: response['error_status'] as int?);
        }
        final backoffShift = _authErrorStreak < maxErrorBackoffShift ? _authErrorStreak : maxErrorBackoffShift;
        _scheduleAfter(smallBatch, _loopDelay + Duration(seconds: 1 << backoffShift));
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
        if (await _canAdoptAccountSilently()) {
          // Same race as the never-linked branch above.
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

      // Records the server refused, per uuid. Marking one synced would leave
      // it flagged as sent while the server holds nothing of it — the local
      // copy then diverges permanently, and no later round ever offers it
      // again, because "pending" is the only thing that makes a round send
      // anything. So a refused record stays dirty.
      final rejectedOperations = _rejectedUuids(response, 'operations');
      final rejectedQsos = _rejectedUuids(response, 'qsos');
      _reportRejections(rejectedOperations, 'operations');
      _reportRejections(rejectedQsos, 'qsos');
      _reportUnreadable(response, 'operations');
      _reportUnreadable(response, 'qsos');
      _quarantine(rejectedOperations.keys, _quarantinedOperations);
      _quarantine(rejectedQsos.keys, _quarantinedQsos);

      // Passes the sent models, not just uuids: markSynced compares each
      // row's revision stamp against the copy that actually went out, so an
      // edit made during the network await above stays dirty and re-pushes.
      final acceptedOperations = [
        for (final o in batch.operations)
          if (!rejectedOperations.containsKey(o.uuid)) o,
      ];
      final acceptedQsos = [
        for (final q in batch.qsos)
          if (!rejectedQsos.containsKey(q.uuid)) q,
      ];
      await operations.markSynced(acceptedOperations);
      await qsos.markSynced(acceptedQsos);

      // Whether this round moved the push forward at all. Two ways it did not,
      // and they need the same answer: nothing was sent (everything still
      // pending is quarantined), or everything sent came back refused. In both
      // cases only WAITING changes the outcome, and the zero-delay drain below
      // would otherwise loop against the server for as long as the app runs —
      // records stay dirty by design here, so "something is pending" is no
      // longer evidence that trying again immediately can achieve anything.
      final pushProgressed = !batch.isEmpty && (acceptedOperations.isNotEmpty || acceptedQsos.isNotEmpty);

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
      final qsoWatermark = inboundQsos.isEmpty
          ? null
          : await mergeQsosReportingProgress(
              qsos,
              inboundQsos,
              response,
              sliceSize: mergeChunkSize,
              onProgress: backfilling ? onProgress : null,
              abandoned: () => generation != _generation,
            );

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
        log?.call(
          '[sync] dropped ${droppedPurges.length} received purge(s) with nothing held here: '
          '${droppedPurges.join(', ')}',
        );
      }

      _errorCount = 0;

      if (!smallBatch) {
        final morePending = pushProgressed && (await operations.hasUnsynced() || await qsos.hasUnsynced());
        onPushBacklog?.call(morePending);
        final fullPage = inboundOperations.length >= pullLimit || inboundQsos.length >= pullLimit;
        // Three different waits. A push backlog goes straight back out:
        // pushes are not cooldown-gated. A full page waits the loop delay,
        // never less — a sooner request lands inside the server's cooldown
        // and buys an empty, gated answer that costs the server two counts
        // over the account's whole QSO table — and that includes a page the
        // server keeps re-serving on a stuck cursor: the loop delay is the
        // fastest the cooldown allows, and there is no slower rate to fall
        // back to that is not the idle one. Caught up, the check period sets
        // the idle rate.
        _scheduleLoop(
          morePending
              ? Duration.zero
              : fullPage && !(_lastPageStuck && _loopDelay == Duration.zero)
              ? _loopDelay
              : _checkPeriod,
        );
      }
    } on SyncTransportNotReady catch (e) {
      // Not a failure: the extension host simply has not finished loading. Do
      // not count it, do not report it - just come back. Deliberately a short
      // fixed delay rather than the error backoff, because this clears in
      // seconds and the backoff would push the first real sync out for no
      // reason.
      log?.call('[sync] transport not ready, retrying shortly: $e');
      _scheduleAfter(smallBatch, const Duration(seconds: 2));
    } catch (e, st) {
      _errorCount++;
      log?.call('[sync] round failed (error #$_errorCount${smallBatch ? ', small batch' : ''}): $e');
      if (_pullInFlight && _pullLimit > mergeChunkSize) {
        _pullPageCap = _pullLimit ~/ 2;
        log?.call('[sync] pull failed; shrinking the page to $_pullLimit');
      }
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
      _scheduleAfter(false, unreachable && backoff > unreachableBackoffCeiling ? unreachableBackoffCeiling : backoff);
    } finally {
      // Whichever way the round ended — including the not-ready path above,
      // which never reaches the reassignment beside the transport call.
      _pullInFlight = false;
      _running = false;
      if (_periodicRoundDeferred) {
        _periodicRoundDeferred = false;
        _scheduleLoop(Duration.zero);
      }
      if (_smallBatchDeferred) {
        _smallBatchDeferred = false;
        // From a timer, never synchronously: this round's caller (`retryNow`) resumes only after
        // this `finally`, and the deferred round clears `_roundReachedService` before its first
        // await — started here it would overwrite the answer the caller is about to read. A
        // microtask is not late enough either; it runs before the caller's continuation. Not
        // through _scheduleLoop, so its dispose guard is restated: a round landing after
        // `dispose` must not start another against a closed database.
        Timer.run(() {
          if (!_disposed) unawaited(runOneRound(smallBatch: true));
        });
      }
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

  /// Keys inside `errors[<side>]` that are NOT a record uuid.
  ///
  /// `pagination` is the cursor refusal [_cursorRefused] reads, and
  /// `_malformed` is the server's count of payload entries it could not read
  /// at all (never a uuid, because the entries it names had none it could
  /// trust). Treating either as a rejected record would hold a row dirty
  /// forever against a uuid nothing will ever match.
  static const _nonRecordErrorKeys = {'pagination', '_malformed'};

  /// Which records of [side] the server refused, uuid to its reported reason.
  ///
  /// Every hop is checked rather than cast, for the reason [_cursorFrom]
  /// gives: this runs before the state write, so a `TypeError` on an error
  /// block shaped differently than expected would cost the round its cursor
  /// AND its watermark, and then throw again on the identical page every
  /// round after.
  static Map<String, String> _rejectedUuids(Map<String, dynamic> response, String side) {
    final errors = response['errors'];
    if (errors is! Map) return const {};
    final forSide = errors[side];
    if (forSide is! Map) return const {};
    final rejected = <String, String>{};
    for (final entry in forSide.entries) {
      final key = entry.key;
      if (key is! String || _nonRecordErrorKeys.contains(key)) continue;
      rejected[key] = _describeRejection(entry.value);
    }
    return rejected;
  }

  /// The only keys whose VALUE may travel: they name the error, never the
  /// record. An allowlist rather than a denylist because this string leaves
  /// the device — Rails' `errors.details` is `{field: [{error: :symbol, ...}]}`
  /// and several stock validators merge the offending value into those
  /// options (`:taken` carries `value:`, `:inclusion` likewise), so anything
  /// not named here is assumed to be the operator's own data.
  static const _rejectionReasonKeys = {'error', 'type'};

  /// A rejection reason flattened to one short line for the log and the crash
  /// report. Keeps the server's error names and the FIELD names it attached
  /// them to; never a field's contents, which are callsigns, names and notes.
  static String _describeRejection(Object? detail) {
    final reasons = <String>{};
    void walk(Object? node) {
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
      } else if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key;
          if (key is String && _rejectionReasonKeys.contains(key)) {
            reasons.add('${entry.value}');
            continue;
          }
          // The key names a field of the record; its value is that field's
          // content and must not be added, only descended into.
          reasons.add('$key');
          walk(entry.value);
        }
      }
    }

    // A scalar detail IS the reason — the server naming it directly rather
    // than in Rails' `{field: [{error: ...}]}` shape. Taken before the walk,
    // which only descends collections: without this it yields nothing, and
    // every distinct reason for one record would collapse onto the same
    // 'refused' dedupe key, so a refusal that CHANGED would never be heard.
    if (detail is String) return detail;
    walk(detail);
    return reasons.isEmpty ? 'refused' : reasons.join(', ');
  }

  /// The server's count of entries it could not read in what this device
  /// sent. Reported once per session per side and count: the records behind it
  /// are marked sent like any other, because nothing here says which they
  /// were, so this line is the only trace they existed.
  void _reportUnreadable(Map<String, dynamic> response, String side) {
    final errors = response['errors'];
    if (errors is! Map) return;
    final forSide = errors[side];
    if (forSide is! Map) return;
    final entries = forSide['_malformed'];
    if (entries is! List) return;
    var count = 0;
    for (final entry in entries) {
      if (entry is Map) count += (entry['count'] as num?)?.toInt() ?? 0;
    }
    if (count == 0) return;
    log?.call('[sync] server could not read $count $side this device sent');
    if (!_reportedRejections.add('$side:_malformed:$count')) return;
    onError?.call(SyncPayloadUnreadable(side, count), null, context: 'sync:unreadable:$side');
  }

  /// Console and crash reporting, never the operator: "the server refused
  /// this QSO" names nothing they can do about it, and a notice that cannot
  /// be answered is worse than none. `onError` carries it so `ErrorPolicy`
  /// decides its disposition in the one place that decision is made.
  void _reportRejections(Map<String, String> rejected, String side) {
    if (rejected.isEmpty) return;
    final summary = rejected.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    // The log takes every round's refusals: a developer watching the console
    // is watching it live, and silence there would hide a loop.
    log?.call('[sync] server refused ${rejected.length} $side (left dirty): $summary');
    // The crash backend takes each one ONCE. A refused record stays dirty by
    // design, so it is re-sent and re-refused every round for as long as the
    // app runs — reporting each time would upload thousands of copies of one
    // fact. Keyed by reason as well as uuid, so a record whose refusal
    // CHANGES (a permission granted, a different validation failing) is heard
    // again.
    final fresh = {
      for (final entry in rejected.entries)
        if (_reportedRejections.add('$side:${entry.key}:${entry.value}')) entry.key: entry.value,
    };
    if (fresh.isEmpty) return;
    onError?.call(SyncRecordsRejected(side, fresh), null, context: 'sync:rejected:$side');
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

  Future<Map<String, dynamic>> _buildPayload(SyncBatch batch, {required bool pull, required bool backfilling, required int limit}) async {
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
          for (final o in batch.operations) {...o.data, 'uuid': o.uuid, if (o.deleted) 'deleted': true, if (o.purged) 'purged': true},
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
                    if (state[backfillCursorKeys['operations']!] != null) 'cursor': state[backfillCursorKeys['operations']!],
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
                    if (state[forwardCursorKeys['operations']!] != null) 'cursor': state[forwardCursorKeys['operations']!],
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
    // real server response, so the loop keeps its 20s defaults: idle polling
    // at whatever the plan's check period should have said, and paging that
    // never learns the cooldown it could have kept pace with.
    final flags = (meta['flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Type-tolerant, like `_cursorFrom`, and for the same reason: these flags are a hand-edited
    // jsonb column on the server (`plans.flags`), and a throw here lands after the merge but
    // before the state write below — the cursor and watermark are lost and the identical page is
    // re-pulled every round, with nothing naming the flag. A value that is not a number is
    // ignored and said so.
    int? knob(String camel, String snake) {
      final value = meta[camel] ?? meta[snake] ?? flags[snake];
      if (value == null) return null;
      final parsed = value is num ? value.toInt() : (value is String ? int.tryParse(value) : null);
      if (parsed == null) log?.call('[sync] ignoring unreadable server flag $snake=$value');
      return parsed;
    }

    final suggestedBatchSize = knob('suggestedSyncBatchSize', 'suggested_sync_batch_size');
    if (suggestedBatchSize != null && suggestedBatchSize > 0) _largeBatchSize = suggestedBatchSize;

    // Zero is a value here, not an absence: a plan with no cooldown says so
    // by suggesting no delay, and treating it as unset would page at the
    // 20 s default instead. Only the check period refuses zero — that one
    // sets the idle rate, and zero there is a hot loop.
    final suggestedLoopDelayMillis = knob('suggestedSyncLoopDelay', 'suggested_sync_loop_delay');
    if (suggestedLoopDelayMillis != null && suggestedLoopDelayMillis >= 0) {
      _loopDelay = Duration(milliseconds: suggestedLoopDelayMillis);
    }

    final suggestedCheckPeriodMillis = knob('suggestedSyncCheckPeriod', 'suggested_sync_check_period');
    if (suggestedCheckPeriodMillis != null && suggestedCheckPeriodMillis > 0) {
      _checkPeriod = Duration(milliseconds: suggestedCheckPeriodMillis);
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
            // will re-request this same page, every loop delay, for as long as the server keeps
            // echoing it. Named so the boost logic below does not read it as a timestamp tie and
            // grow the limit for a page whose size is not the problem.
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

      advanceCursor('operations', 'earliestOperationSyncedAtMillis', backfillCursorKeys['operations']!, opWatermark, inboundOperationsCount);
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
        _lastPageStuck = false;
      } else if (cursorStuck) {
        // A cursor that will not move is not a page-size problem, so growing the limit is not the
        // answer; the full page it came on is scheduled at the loop delay (see [_lastPageStuck]).
        _lastPageStuck = true;
        log?.call('[sync] backfill cursor came back unchanged; retrying at the loop delay');
      } else if (timestampTieStuck) {
        _lastPageStuck = !cursorAdvanced;
        if (_backfillLimitBoost < maxBackfillLimitBoost) {
          _backfillLimitBoost *= 2;
          log?.call('[sync] backfill cursor stuck on a timestamp tie; growing pull limit to ${_backfillLimitBoost}x');
        } else if (!cursorAdvanced) {
          log?.call('[sync] backfill cursor still stuck at the maximum pull limit; retrying at the loop delay');
        }
      } else {
        _backfillLimitBoost = 1;
        _lastPageStuck = false;
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
    final (:qsosLeft, :qsosTotal, :operationsLeft, :operationsTotal) = serverCounts(meta);
    if (!completed && qsosLeft == null && qsosTotal == null && operationsLeft == null && operationsTotal == null) return;

    onProgress!(
      SyncProgress(
        backfilling: !completed,
        qsosTotal: qsosTotal,
        qsosLeft: completed ? 0 : qsosLeft,
        operationsTotal: operationsTotal,
        operationsLeft: completed ? 0 : operationsLeft,
      ),
    );
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

  /// A round's own choice of next wait. A periodic round always sets it; a
  /// small-batch round sets it only when a periodic round is waiting behind
  /// it — that wait is the deferred round's, and running it at once instead
  /// would hit the same dead network or stale registration a second time
  /// and count it twice.
  void _scheduleAfter(bool smallBatch, Duration delay) {
    if (smallBatch && !_periodicRoundDeferred) return;
    _periodicRoundDeferred = false;
    _scheduleLoop(delay);
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
