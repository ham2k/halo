// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The types [SyncEngine] is driven through and answers with: its transport
// and settings seams, the batch it selects, the exceptions its `onError`
// carries, and the choices the app layer hands back. The engine itself is in
// sync_engine.dart.

import '../hook_names.dart';
import '../models/models.dart';

/// Calls the highest-priority `syncTransport` hook's [hook] method with `args`
/// and returns its JSON result. Implemented by the app layer (wrapping
/// `ExtensionHost.invokeHook`) so this package stays free of a Flutter/
/// extension-host dependency — the same reason `halo_core` has no Flutter
/// import today.
typedef SyncTransportCall = Future<Map<String, dynamic>> Function(HookRef hook, Map<String, dynamic> args);

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

/// Records the server accepted the round but refused individually, so the app
/// layer can report them somewhere a developer will see.
///
/// An exception rather than a plain callback argument so it travels the same
/// `onError` path every other sync failure does, and `ErrorPolicy` classifies
/// it in the one place that decision belongs.
///
/// Carries uuids and the server's error KEYS only — never a rejected record's
/// field values, which hold callsigns, names and notes.
class SyncRecordsRejected implements Exception {
  SyncRecordsRejected(this.side, this.reasonsByUuid);

  /// `operations` or `qsos`.
  final String side;
  final Map<String, String> reasonsByUuid;

  @override
  String toString() =>
      'SyncRecordsRejected: the server refused ${reasonsByUuid.length} $side — '
      '${reasonsByUuid.entries.map((e) => '${e.key}: ${e.value}').join('; ')}';
}

/// Records the server could not read at all, so it stored none of them and
/// can name none of them.
///
/// Distinct from [SyncRecordsRejected] because there is no uuid to hold dirty:
/// the entries were unreadable, so this device cannot tell which of the ones
/// it sent are missing, and they are all marked sent. That makes this the one
/// refusal that still loses data silently — which is exactly why it must be
/// reported. An unusable payload is a fault in what this app WROTE, so the
/// count is the whole signal.
class SyncPayloadUnreadable implements Exception {
  SyncPayloadUnreadable(this.side, this.count);

  /// `operations` or `qsos`.
  final String side;
  final int count;

  @override
  String toString() => 'SyncPayloadUnreadable: the server could not read $count $side this device sent';
}

/// A pull that keeps failing on the same request, round after round, while
/// the engine shrinks its page. [limit] is the page the last failure asked
/// for: a stuck pull still failing at the floor is one no page size will fix,
/// while one reported above it may yet clear once the page gets small enough.
///
/// Its own type because the failure underneath is usually a timeout, which on
/// its own is indistinguishable from a slow link: what makes this one worth
/// reading is that the request has not moved. [position] says which request:
/// the watermark each side pages from (null when there is none yet) and
/// whether it carried a row cursor — the server builds a page without one
/// differently, and that is the first thing to check. [pushing] counts the
/// records that went out in the same request: the round is one call, so a push
/// the server fails on every time fails the pull with it.
class SyncPullStuck implements Exception {
  SyncPullStuck({required this.backfilling, required this.limit, required this.position, required this.pushing, required this.cause});

  final bool backfilling;
  final int limit;
  final Map<String, Object?> position;
  final int pushing;
  final Object cause;

  @override
  String toString() =>
      'SyncPullStuck: the ${backfilling ? 'backfill' : 'forward'} pull keeps failing on the same request '
      'at limit $limit — $position, pushing $pushing records; last error: $cause';
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
