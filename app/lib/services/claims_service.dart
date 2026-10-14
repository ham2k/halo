// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps the `claims` table current as the log changes (docs/design/claims.md
// §6). Every registered `chasing` program is asked about every contact that
// changed. What a contact newly claims is written on any device. A slot
// losing the contact that held it needs the runner-up, so only a device
// holding the whole log may lower it, by rescanning that program.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'error_reporting_service.dart';
import 'extensions/extension_service.dart';
import 'settings_service.dart';
import 'status_bar_service.dart';

const _builtVersionsKey = 'claimsBuiltVersions';
const _changesPendingKey = 'claimsChangesPending';

/// Whether this device holds the whole log (docs/design/claims.md §6): once
/// its backfill has reached the start of the account's history, or, with sync
/// off, if it never linked an account at all. A device that linked one and
/// turned sync off before its backfill finished holds part of that history,
/// whatever the switch says now.
bool deviceHoldsWholeLog(SettingsService settings) =>
    settings.syncState['completedFullSync'] == true || (!settings.syncEnabled && settings.syncState['lastSyncAccountUUID'] == null);

/// Contacts per `claimsForQsos` call: one batch is one crossing into the
/// runtime and one timeout (`kClaimsForQsosTimeout`).
const kClaimsBatchSize = 250;

/// Contacts a pass must cover before it shows its progress in the footer:
/// a smaller one is over before the bar could be read.
const kClaimsProgressAbove = 1000;

const _progressKey = 'claims';

class ClaimsService {
  ClaimsService({
    required this.extensions,
    required this.qsos,
    required this.operations,
    required this.claims,
    required this.isEnabled,
    required this.holdsWholeLog,
    required this.builtVersions,
    required this.saveBuiltVersions,
    required this.changesPending,
    required this.saveChangesPending,
    this.settingsChanges,
    this.statusBar,
    this.debounce = const Duration(seconds: 1),
    this.progressAbove = kClaimsProgressAbove,
  });

  /// The service as the app runs it. Claims are kept only under `EXP CHASE`:
  /// the Chasing view is their only reader, and a first rebuild reads the
  /// whole log through every program. The built versions are device-local
  /// bookkeeping, so saving them notifies no one.
  factory ClaimsService.forApp({
    required ExtensionService extensions,
    required QsosRepository qsos,
    required OperationsRepository operations,
    required ClaimsRepository claims,
    required SettingsService settings,
    required StatusBarService statusBar,
  }) => ClaimsService(
    extensions: extensions,
    qsos: qsos,
    operations: operations,
    claims: claims,
    isEnabled: () => settings.experimentEnabled('chase') /* stored key, see experiments.yaml */,
    holdsWholeLog: () => deviceHoldsWholeLog(settings),
    builtVersions: () => {
      for (final MapEntry(:key, :value) in settings.jsonMapPref(_builtVersionsKey).entries)
        if (value is int) key: value,
    },
    saveBuiltVersions: (versions) => settings.prefs.setString(_builtVersionsKey, jsonEncode(versions)),
    changesPending: () => settings.prefs.getBool(_changesPendingKey) ?? false,
    saveChangesPending: (pending) => settings.prefs.setBool(_changesPendingKey, pending),
    settingsChanges: settings,
    statusBar: statusBar,
  );

  final ExtensionService extensions;
  final QsosRepository qsos;
  final OperationsRepository operations;
  final ClaimsRepository claims;

  /// Whether claims are kept at all. Off, changes are not followed, so
  /// turning it back on rebuilds every program on a device that may.
  final bool Function() isEnabled;

  /// Whether this device holds the whole log, so it may lower a slot and
  /// rebuild a program (§6). A device still filling its log from sync holds
  /// part of it, and only raises slots.
  final bool Function() holdsWholeLog;

  /// The version each program was last rebuilt at on this device, from the
  /// whole log. A program missing here, or at another version, is rebuilt
  /// when this device holds the whole log: nothing else says whether the
  /// rows came from every contact or only from those this device happened
  /// to see change.
  final Map<String, int> Function() builtVersions;
  final Future<void> Function(Map<String, int>) saveBuiltVersions;

  /// Whether changes were waiting for a pass when this device last stopped
  /// following the log. They live in memory until a pass runs, so a quit or
  /// a crash in between loses them; the built versions would still vouch
  /// for the rows, and only this says a rebuild is owed.
  final bool Function() changesPending;
  final Future<void> Function(bool) saveChangesPending;

  /// What [isEnabled] and [holdsWholeLog] are read again on.
  final Listenable? settingsChanges;

  final StatusBarService? statusBar;

  /// How long changed contacts gather before a pass asks about them: logging
  /// a run or syncing a backlog is many writes, and one pass per write would
  /// call every program once per contact.
  final Duration debounce;

  /// See [kClaimsProgressAbove].
  final int progressAbove;

  StreamSubscription<Set<String>?>? _subscription;
  StreamSubscription<String>? _deletions;
  StreamSubscription<List<StoredClaim>>? _merges;
  StreamSubscription<void>? _cleared;
  bool _started = false;
  bool _active = false;
  bool _markedPending = false;

  /// Whether the built versions are already forgotten, so a settings change
  /// owes no pass: settings change on every sync round, chasing on or off.
  bool _forgotten = false;
  bool? _inheritedPending;
  bool _wasWhole = false;
  final _pending = <String>{};
  bool _pendingAll = false;
  Timer? _timer;

  /// Passes run one at a time, in order: a rescan and an upgrade racing for
  /// one slot would let whichever wrote last decide it.
  Future<void> _tail = Future<void>.value();

  /// Completes when every pass queued so far has run.
  @visibleForTesting
  Future<void> get idle => _tail;

  /// Starts hearing about changes to the log, holding them until [start].
  /// Sync and peers merge contacts before the runtime that answers for the
  /// programs is up, and a change nobody heard is never caught up.
  void listen() {
    // Read before this run's own changes can set it.
    _inheritedPending ??= changesPending();
    _subscription ??= qsos.changes.listen(_onChanges);
    // An operation deleted or restored takes its contacts out of the log, or
    // puts them back, without a write to any of them.
    _deletions ??= operations.deletions.listen(_onOperationDeletion);
    _merges ??= claims.merged.listen(_onMerged);
    // Emptied for a new account: nothing is vouched for any more.
    _cleared ??= claims.cleared.listen((_) => _enqueue(_forgetAll, evenIfIdle: true));
  }

  void start() {
    listen();
    _started = true;
    // Changes a previous run heard but never passed on were lost with it.
    if (_inheritedPending == true) {
      _inheritedPending = false;
      _enqueue(() async {
        await _forgetAll();
        await saveChangesPending(_markedPending);
      }, evenIfIdle: true);
    }
    settingsChanges?.addListener(_onSettings);
    extensions.runtimeGeneration.addListener(_onRuntime);
    _onSettings();
    if (_pending.isNotEmpty || _pendingAll) _schedule();
    if (_mergedEarly.isNotEmpty) {
      final early = [..._mergedEarly];
      _mergedEarly.clear();
      _onMerged(early);
    }
  }

  void dispose() {
    _active = false;
    _subscription?.cancel();
    _subscription = null;
    _deletions?.cancel();
    _deletions = null;
    _merges?.cancel();
    _merges = null;
    _cleared?.cancel();
    _cleared = null;
    settingsChanges?.removeListener(_onSettings);
    extensions.runtimeGeneration.removeListener(_onRuntime);
    _timer?.cancel();
  }

  void _onSettings() {
    final enabled = isEnabled();
    final whole = enabled && holdsWholeLog();
    // A built version vouches for rows kept current through every change to
    // the whole log. Off, changes go unfollowed; holding part of the log,
    // slots are only ever raised. Either way the rows stop vouching for
    // themselves, and a rebuild is owed once this device may make one.
    if (!whole && !_forgotten) {
      _forgotten = true;
      _enqueue(_forgetAll, evenIfIdle: true);
    }
    final wake = enabled && (!_active || whole != _wasWhole);
    _active = enabled;
    _wasWhole = whole;
    if (wake) _enqueue(_refresh);
  }

  /// A new runtime may carry new programs, or new versions of them, and may
  /// answer for the changes a pass held because the last one could not.
  void _onRuntime() {
    if (!_active) return;
    _enqueue(_refresh);
    if (_pending.isNotEmpty || _pendingAll) _schedule();
  }

  void _onChanges(Set<String>? uuids) {
    if (_started ? !_active : !isEnabled()) return;
    if (uuids == null) {
      _pendingAll = true;
    } else {
      _pending.addAll(uuids);
    }
    _markPending(true);
    if (_started) _schedule();
  }

  /// Queued like a pass, so [idle] covers the lookup: until it answers,
  /// nothing says which contacts the deletion took out of the log.
  void _onOperationDeletion(String operation) => _enqueue(() async {
    final contacts = await qsos.uuidsInOperation(operation);
    if (contacts.isNotEmpty) _onChanges(contacts.toSet());
  }, evenIfIdle: true);

  /// Rows sync merged before [start]: the check needs the programs, which
  /// the runtime answers for only once it is up.
  final _mergedEarly = <StoredClaim>[];

  void _onMerged(List<StoredClaim> rows) {
    if (!_started) {
      if (isEnabled()) _mergedEarly.addAll(rows);
    } else if (_active) {
      _enqueue(() => _checkMerged(rows));
    }
  }

  /// A row sync brought in that names a contact this device knows is gone —
  /// deleted, or in a deleted operation — came from a device that has not
  /// heard of it yet, and one an older version of the program computed from
  /// a contact here is out of date. Only the whole log can correct either
  /// (§7). A row naming a contact that has not arrived here says nothing.
  Future<void> _checkMerged(List<StoredClaim> rows) async {
    if (!holdsWholeLog()) return;
    final named = {
      for (final row in rows)
        if (!row.deleted && row.qso != null) row.qso!,
    };
    if (named.isEmpty) return;
    final programs = await _chasingPrograms();
    if (programs == null) return;
    final inLog = {for (final qso in await qsos.liveAmong(named)) qso.uuid};
    final gone = (await qsos.knownAmong(named)).difference(inLog);
    final stale = {
      for (final row in rows)
        if (!row.deleted && (gone.contains(row.qso) || (inLog.contains(row.qso) && row.version < (programs[row.program]?.version ?? 0)))) row.program,
    };
    for (final key in stale) {
      if (programs[key] case final program?) await _rescan(program);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => _enqueue(_drain));
  }

  void _markPending(bool pending) {
    if (_markedPending == pending) return;
    _markedPending = pending;
    saveChangesPending(pending).catchError((Object e, StackTrace st) {
      ErrorReportingService.report(e, st, context: 'claims:pending');
    });
  }

  void _enqueue(Future<void> Function() pass, {bool evenIfIdle = false}) {
    _tail = _tail.then((_) => _active || evenIfIdle ? pass() : null).catchError((Object e, StackTrace st) {
      debugPrint('[claims] pass failed: $e');
      ErrorReportingService.report(e, st, context: 'claims:pass');
    });
  }

  /// Rebuilds, on a device that may, each program that this device has not
  /// built from the whole log at its current version. Rows an older version
  /// computed elsewhere are caught as sync brings them ([_checkMerged]); a
  /// rebuild keeps those it cannot judge, so they are no sign one is owed.
  Future<void> _refresh() async {
    if (!holdsWholeLog()) return;
    final programs = await _chasingPrograms();
    if (programs == null) return;
    for (final program in programs.values) {
      if (!_active) return;
      if (builtVersions()[program.key] == program.version) continue;
      await _rescan(program);
    }
  }

  /// Asks every program about the contacts that changed since the last pass,
  /// a page at a time: an import or a sync backlog names tens of thousands.
  Future<void> _drain() async {
    final generation = claims.generation;
    final uuids = [..._pending];
    final all = _pendingAll;
    _pending.clear();
    _pendingAll = false;

    final programs = await _chasingPrograms();
    if (programs == null) {
      // The runtime could not say which programs exist: these changes wait,
      // still marked on disk, for the next pass.
      _pending.addAll(uuids);
      _pendingAll = _pendingAll || all;
      return;
    }
    // A program missing from this pass — its extension off, or the runtime
    // between generations — misses these changes, and only a rebuild
    // catches it up.
    final built = builtVersions();
    if (built.keys.any((key) => !programs.containsKey(key))) {
      await saveBuiltVersions({...built}..removeWhere((key, _) => !programs.containsKey(key)));
    }

    // A write that may have reached any contact names none; what it removed
    // only the whole log can tell. A device holding part of it still raises
    // slots from the contacts that were named alongside it.
    if (all && holdsWholeLog()) {
      for (final program in programs.values) {
        await _rescan(program);
      }
      _settled();
      return;
    }
    if (uuids.isEmpty) return _settled();

    final missed = <String>{};
    final lowered = <String>{};
    try {
      for (var start = 0; start < uuids.length; start += kClaimsBatchSize) {
        if (!_active) return;
        _progress(t.chase.claims.checking, start, uuids.length);
        final page = uuids.sublist(start, math.min(start + kClaimsBatchSize, uuids.length));
        final live = await qsos.liveAmong(page);
        final inLog = {for (final qso in live) qso.uuid};
        final held = await claims.heldBy(page);

        for (final program in programs.values) {
          if (missed.contains(program.key)) continue;
          final answer = await _claimsFor(program, live);
          if (answer == null) {
            // This program missed these contacts; only a rebuild catches it up.
            missed.add(program.key);
            await _forget(program.key);
            continue;
          }
          await claims.applyUpgrades(answer.values.expand((claims) => claims), generation: generation);

          final dropped = held.any((row) {
            if (row.program != program.key) return false;
            final qso = row.qso;
            if (qso == null) return false;
            if (!inLog.contains(qso)) return true;
            final restated = answer[qso];
            // Not answered: the program left the contact out (a malformed
            // answer, reported where it was read), so what it claims is
            // unknown, not withdrawn.
            if (restated == null) return false;
            return !restated.any((claim) => claim.uuid == row.uuid && compareClaims(claim, row) >= 0);
          });
          if (dropped) lowered.add(program.key);
        }
      }
    } finally {
      statusBar?.clear(_progressKey);
    }

    // Settled only once the rescans that lower slots are done: a quit before
    // then leaves the marker set, and the next launch rebuilds.
    if (holdsWholeLog()) {
      for (final program in programs.values) {
        if (lowered.contains(program.key) && !missed.contains(program.key)) await _rescan(program);
      }
    }
    _settled();
    // One more try for a program that failed here, rather than leaving its
    // checklist behind until the next launch or runtime. It is not repeated:
    // a program that fails every time would otherwise rescan in a loop.
    if (missed.isNotEmpty) _enqueue(_refresh);
  }

  /// Clears the pending marker once every change heard so far has reached a
  /// pass. A program a pass missed holds no built version, so it needs none.
  void _settled() {
    if (_pending.isEmpty && !_pendingAll) _markPending(false);
  }

  /// The registered programs, once per runtime
  /// ([ExtensionChasing.chasingPrograms]); null when the runtime could not be
  /// asked.
  Future<Map<String, ChasingProgram>?> _chasingPrograms() => extensions.chasingPrograms();

  /// What each of [batch] — at most [kClaimsBatchSize] contacts, one crossing
  /// into the runtime — claims under [program] as stored rows, keyed by
  /// contact; null when the program failed.
  ///
  /// A claim record ([claimEventOf]) is not asked about: it is a claim the
  /// program already made when its file was imported, and claims what it says
  /// under its own program and nothing under any other.
  Future<Map<String, List<StoredClaim>>?> _claimsFor(ChasingProgram program, List<Qso> batch) async {
    if (batch.isEmpty) return const {};
    final recorded = <String, List<StoredClaim>>{};
    final contacts = <Qso>[];
    for (final qso in batch) {
      if (claimEventOf(qso.data) case final event?) {
        recorded[qso.uuid] = [
          if (event.program == program.key)
            StoredClaim.fromQso(program: program.key, version: program.version, claim: event.claim, qso: qso.uuid, atMillis: event.atMillis),
        ];
      } else {
        contacts.add(qso);
      }
    }
    if (contacts.isEmpty) return recorded;
    final byUuid = {for (final qso in contacts) qso.uuid: qso};
    final answer = await extensions.claimsForQsos(program.key, [
      for (final qso in contacts) {...qso.data, 'uuid': qso.uuid},
    ]);
    if (answer == null) return null;
    return {
      ...recorded,
      for (final MapEntry(key: uuid, value: claims) in answer.entries)
        // A program answering for a contact it was not asked about is not
        // describing anything in this log.
        if (byUuid[uuid] case final qso?)
          uuid: [
            for (final claim in claims)
              StoredClaim.fromQso(program: program.key, version: program.version, claim: claim, qso: uuid, atMillis: qso.startAtMillis),
          ],
    };
  }

  /// Recomputes [program]'s checklist from every contact in the log and
  /// writes what changed (§6). Abandoned, writing nothing, if the program
  /// fails on any batch: a checklist built from part of the log would
  /// withdraw every slot the rest of it holds. A contact it leaves out of
  /// an answer keeps the slots it holds, for the same reason.
  Future<void> _rescan(ChasingProgram program) async {
    final generation = claims.generation;
    final title = t.chase.claims.rebuilding(program: program.label);
    final total = await qsos.liveCount();
    final best = <String, StoredClaim>{};
    final unanswered = <String>[];
    var done = 0;
    String? after;
    try {
      while (true) {
        if (!_active) return;
        _progress(title, done, total);
        final page = await qsos.livePage(afterUuid: after, limit: kClaimsBatchSize);
        if (page.isEmpty) break;
        after = page.last.uuid;
        final answer = await _claimsFor(program, page);
        if (answer == null) return _forget(program.key);
        // Left out: a malformed answer, reported where it was read.
        unanswered.addAll([
          for (final qso in page)
            if (!answer.containsKey(qso.uuid)) qso.uuid,
        ]);
        for (final claim in answer.values.expand((claims) => claims)) {
          final held = best[claim.uuid];
          if (held == null || compareClaims(claim, held) > 0) best[claim.uuid] = claim;
        }
        done += page.length;
      }
      // Kept as they stand unless something here beats them, decided where
      // the rows are written so a row sync merges meanwhile is judged too: a
      // contact the program left out, and one that has not reached this
      // device yet, may each beat everything here.
      await claims.writeRescan(program.key, program.version, best, unanswered: unanswered.toSet(), knownContacts: qsos.knownAmong, generation: generation);
    } finally {
      statusBar?.clear(_progressKey);
    }
    await saveBuiltVersions({...builtVersions(), program.key: program.version});
    _forgotten = false;
  }

  /// Shows in the footer how far a pass over [total] contacts has got, once
  /// it is large enough to see ([progressAbove]).
  void _progress(String title, int done, int total) {
    if (total <= progressAbove) return;
    statusBar?.setProgress(
      key: _progressKey,
      icon: 'binoculars',
      title: title,
      // Contacts logged while a rescan pages through the log can carry it
      // past the count it started from.
      text: t.chase.claims.progress(done: formatNumber(math.min(done, total)), total: formatNumber(total)),
      value: math.min(done, total) / total,
    );
  }

  Future<void> _forgetAll() async {
    if (builtVersions().isNotEmpty) await saveBuiltVersions(const {});
  }

  Future<void> _forget(String programKey) async {
    final built = builtVersions();
    if (!built.containsKey(programKey)) return;
    await saveBuiltVersions({...built}..remove(programKey));
  }
}
