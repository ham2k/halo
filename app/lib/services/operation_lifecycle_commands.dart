// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operation's own commands: the segment markers START / BREAK / STOP and
// ROVERQTH, and the lifecycle transitions the logging panel's controls invoke.
//
// They are one file because they are one act — the lifecycle and the segment
// boundaries are the same rows, so starting an operation and opening its first
// segment are the same thing happening once.

import 'dart:async';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/navigation.dart';
import '../views/operation/operation_location_screen.dart';
import 'error_reporting_service.dart';
import 'halo_services.dart';

extension OperationLifecycleCommands on HaLoServices {
  /// Moves [uuid] through the lifecycle: `start`, `pause`, `restart` or
  /// `stop`.
  ///
  /// Routed through [markSegment] rather than writing a status directly,
  /// because the lifecycle and the segment boundaries are the same
  /// rows: starting an operation and opening its first segment are one act,
  /// as ending it and closing the last one are. Going straight to
  /// [OperationsRepository.setStatus] would move the state and leave the
  /// timeline with nothing in it to say why.
  ///
  /// A refusal is surfaced rather than swallowed — a button that silently
  /// does nothing is worse than one that says why it did nothing. Both halves
  /// of a transition can refuse by THROWING rather than answering: the event
  /// row through the QSO write policy, the status through the operation's.
  /// The panel calls this unawaited, so an uncaught one is an unhandled async
  /// error and the operator is told nothing at all.
  ///
  /// [lastActivityMillis] is the panel's own last sign of life, which can be
  /// later than the record's — see `operationLifecycleSpec`.
  ///
  /// One at a time per operation: a move arriving while another is still
  /// writing is dropped. Each reads the timeline before either has written,
  /// so a double-tap on Continue would otherwise write two starts and two
  /// restarts, and both might drop the same pause.
  Future<void> moveOperationLifecycle(String uuid, String kind, {int? lastActivityMillis}) async {
    if (!_movingLifecycles.add(uuid)) return;
    String? failure;
    try {
      // Called directly, not through `handleCommandAction`: that counts a
      // typed command, and these are the panel's buttons.
      final outcome = await markSegment({'uuid': uuid, 'kind': kind, 'lastActivityMillis': ?lastActivityMillis, 'finishAtSilence': true});
      if (outcome == null || !outcome.failed) return;
      failure = outcome.text;
    } on WriteRefused catch (refusal) {
      failure = refusal.reason;
    } catch (error, stack) {
      ErrorReportingService.report(
        error,
        stack,
        context: 'operationLifecycle:$kind',
        notice: ErrorNotice(statusBar, key: 'operation-lifecycle', text: t.operation.lifecycle.moveFailed, persist: false),
      );
      return;
    } finally {
      _movingLifecycles.remove(uuid);
    }
    statusBar.showNotice(key: 'operation-lifecycle', text: failure, persist: false);
  }
}

/// The operations a [OperationLifecycleCommands.moveOperationLifecycle] is
/// writing to right now.
final _movingLifecycles = <String>{};

/// How soon a restart takes back the pause or finish before it outright,
/// leaving neither row: a tap undone that quickly was a slip, not a break.
const _lifecycleBlip = Duration(minutes: 1);

extension OperationSegmentCommands on HaLoServices {
  /// START / BREAK / STOP / ROVERQTH: writes the segment boundary the scoring
  /// model reads (docs/design/contests.md §5.1.3). A `break` row states what
  /// is true for the stretch that FOLLOWS it, and the base operation is only
  /// a default under the segments, not an accumulator — so a log getting its
  /// first break also gets a `start` at its top holding what the contacts so
  /// far were made under; otherwise, the moment the base moves, they would
  /// all silently move with it. `stop` moves an existing stop row to now
  /// rather than stacking a second one, as polo does.
  ///
  /// With `setLocation` (ROVERQTH) the Location screen opens afterwards, and
  /// what it returns is saved onto the operation; `onLocalSave` then restamps
  /// the break just written, which is how the new stretch resolves to the
  /// new square. A cancelled screen leaves a break restating the old
  /// location, which scores exactly as before.
  ///
  /// Returns null on success — the hook's own `confirm` already told the
  /// operator what is happening, as `updateOperation` does.
  Future<CommandActionOutcome?> markSegment(Map<String, dynamic> params) async {
    final kind = asQsonString(params['kind']) ?? '';
    if (kind != 'start' && kind != 'break' && kind != 'stop' && kind != 'restart' && kind != 'pause') {
      // Only a malformed extension action reaches this, so it must name the
      // real fault rather than borrow the no-operation message.
      return (text: t.commands.unknownSegmentKind(kind: kind), failed: true);
    }
    final uuid = asQsonString(params['uuid']) ?? '';
    final operation = uuid.isEmpty ? null : await operations.get(uuid);
    if (operation == null) return (text: t.commands.noOperationOpen, failed: true);

    // Event rows only: the whole log would be decoded to read a handful of
    // them, and the one thing needed from the contacts is the earliest time.
    // The deleted ones come along for [markAt] to revive, in the same read.
    final allEvents = await qsos.eventsForOperation(operation.uuid, includeDeleted: true);
    final events = [
      for (final q in allEvents)
        if (!q.deleted) q,
    ];
    final override = segmentOverrideOf(operation.data);
    // `kind` decides the wording: a break says what is NOW true, a start (or
    // the start a first break has to open) states it plainly. Composed only
    // where a row carries one — each is an extension round trip per ref, and
    // the operator is waiting on the transition to log again. A pause or a
    // restart into a started log writes no description at all.
    Future<String?> describe(String as) => segmentDescription(operation, override, kind: as);
    final hasStart = events.any((q) => q.eventKind == 'start');
    final hasSegment = events.any((q) => eventKindOpensSegment(q.eventKind));

    Future<void> addStart() async {
      final firstAt = await qsos.firstContactMillis(operation.uuid);
      await qsos.addEvent(
        operation.uuid,
        kind: 'start',
        atMillis: firstAt == null ? nowMillis() : firstAt - 1000,
        operation: override,
        description: await describe('start'),
      );
    }

    // The lifecycle and the segment boundaries are the SAME rows, not two
    // vocabularies sharing a timeline: starting an operation and
    // opening its first segment are one act, as ending it and closing the
    // last one are. So these commands move the status alongside the row they
    // write.
    //
    // `evenIfUnchanged`: every one of these is the operator saying something
    // about the operation, so it is stamped as having been said — even when
    // the state it names is the state the record already holds. REOPEN on an
    // operation that is still `active` is the case that matters, and the one
    // the whole reopening story rests on.
    Future<void> moveStatusTo(String status, {int? atMillis}) async {
      await operations.setStatus(operation.uuid, status, evenIfUnchanged: true, atMillis: atMillis);
    }

    // The lifecycle rows at the very end of the log, with nothing logged
    // after them, are the operator's moves since they last made a contact —
    // and those collapse rather than stack: pause, restart, pause reads as one
    // pause; a pause then a finish is one finish, at the pause; a restart
    // inside [_lifecycleBlip] undoes the pause or finish it follows. Without
    // this, an operator who steps away twice in a quiet hour leaves the log a
    // ladder of markers that says nothing a single pair would not.
    final lastContactAt = await qsos.lastContactMillis(operation.uuid);
    final live = [...events];
    Qso? trailing(Set<String> kinds) {
      final last = live.lastOrNull;
      if (last == null || !kinds.contains(last.eventKind)) return null;
      if (lastContactAt != null && (last.startAtMillis ?? 0) < lastContactAt) return null;
      return last;
    }

    // Markers already deleted at the very end of the log — after its last
    // live row and its last contact. A pause or restart the operator takes
    // back and then makes again revives one of these rather than leaving a
    // tombstone beside a fresh row.
    final liveEnd = [lastContactAt ?? 0, live.lastOrNull?.startAtMillis ?? 0].reduce((a, b) => a > b ? a : b);
    final dropped = [
      for (final q in allEvents)
        if (q.deleted && (q.startAtMillis ?? 0) >= liveEnd) q,
    ];

    Future<void> drop(Qso row) async {
      await qsos.softDelete(row);
      live.remove(row);
      dropped.add(row);
    }

    // Turns a lifecycle row into another kind IN PLACE rather than deleting it
    // and writing a new one: the row the operator already has, and a peer
    // already synced, stays the same row. A kind that is no segment boundary
    // carries no override and no description.
    Future<void> rekind(Qso row, String kind, {required int atMillis, Map<String, dynamic>? override, String? description}) async {
      await qsos.update(
        Qso(
          uuid: row.uuid,
          operationUuid: row.operationUuid,
          data: {
            ...row.data,
            'startAtMillis': atMillis,
            'their': {...?(row.data['their'] as Map?)?.cast<String, dynamic>(), 'call': kind.toUpperCase()},
            'event': {
              ...{...?row.event}
                ..remove('operation')
                ..remove('description'),
              'event': kind,
              'operation': ?override,
              'description': ?description,
            },
          },
        ),
      );
    }

    // Writes a lifecycle row at [atMillis]: the latest dropped one of the
    // same kind, revived and moved, or a new one when there is none.
    Future<void> markAt(String kind, int atMillis) async {
      final revived = dropped.where((q) => q.eventKind == kind).lastOrNull;
      if (revived == null) {
        await qsos.addEvent(operation.uuid, kind: kind, atMillis: atMillis);
        return;
      }
      dropped.remove(revived);
      await rekind(revived, kind, atMillis: atMillis);
      await qsos.undelete(revived);
    }

    switch (kind) {
      case 'start':
        // Reported, not silent: the operator asked to mark the start NOW,
        // and the row that exists sits at the top of the log with an older
        // timestamp. A bare success would read as though it had moved.
        //
        // Except where the STATUS says the log never started. An operation
        // started before the lifecycle existed carries a `start` marker and no
        // status at all, and refusing there would leave the panel offering a
        // START button that raises the same notice every time it is pressed,
        // forever. A paused or finished log is refused whether or not it has a
        // `start` row — one filled without pressing START has none: START
        // reopening it would write no restart, and the timeline would end on
        // the pause or the finish of a log that runs on. Only an `active` log
        // missing its marker gets one.
        //
        // Falls THROUGH rather than returning: `setLocation` is handled below
        // and the hook has already told the operator the Location screen is
        // coming. Only the row is skipped.
        final neverStarted = statusIsUnstarted(operation.status);
        if (!neverStarted && (hasStart || operation.status != OperationStatus.active)) {
          return (text: t.commands.operationAlreadyStarted, failed: true);
        }
        if (!hasStart) await addStart();
        await moveStatusTo(OperationStatus.active);
      case 'pause':
        // Its own kind, never a `break`: a break is a segment boundary
        // (`eventKindOpensSegment`), and every stretch after a lunch break would
        // resolve to whatever that break restated. Pausing states nothing about
        // what the station is doing. No `start` is back-filled either, for the
        // same reason: this opens no stretch that the contacts so far would
        // need protecting from.
        if (trailing(const {'restart'}) case final restart?) await drop(restart);
        // Folded back into an earlier pause, the log has been paused since
        // THAT row — the panel's "Paused for" and the stats' active time both
        // count from the status stamp.
        final earlier = trailing(const {'pause'});
        if (earlier == null) await markAt('pause', nowMillis());
        await moveStatusTo(OperationStatus.paused, atMillis: earlier?.startAtMillis);
      case 'restart':
        // Bare, and deliberately not a segment boundary
        // (`eventKindOpensSegment`). Coming back to the radio resumes the
        // stretch already running — a boundary would reset the log to the base
        // operation every time the operator returned.
        //
        // A `start` is written first if the log has none, for the same reason
        // a `break` does: without one, the contacts made before this point
        // would silently follow the base operation wherever it moves next.
        if (trailing(const {'pause', 'stop'}) case final closing?) {
          final closedAt = closing.startAtMillis ?? 0;
          if (nowMillis() - closedAt < _lifecycleBlip.inMilliseconds) {
            await drop(closing);
            await moveStatusTo(OperationStatus.active);
            break;
          }
          // A finish that is being taken back was a pause after all, and the
          // `stop` must not stay to close a segment the log has reopened.
          if (closing.eventKind == 'stop') await rekind(closing, 'pause', atMillis: closedAt);
        }
        if (!hasSegment) await addStart();
        await markAt('restart', nowMillis());
        await moveStatusTo(OperationStatus.active);
      case 'break':
        if (!hasSegment) await addStart();
        await qsos.addEvent(operation.uuid, kind: 'break', atMillis: nowMillis(), operation: override, description: await describe('break'));
      case 'stop':
        final description = await describe('stop');
        if (trailing(const {'restart'}) case final restart?) await drop(restart);
        // The log ended when the operator stepped away, not when they came
        // back to say so — and that pause's row becomes the finish.
        Qso? previous;
        for (final q in live) {
          if (q.eventKind == 'stop') previous = q;
        }
        //
        // With no pause row to fold into, the panel's Finish on a log it
        // presents as paused — the sweep inferred it, or it has been quiet
        // past [operationQuietAfter] — ends where the silence began: that is
        // the pause the operator was looking at when they pressed it. A typed
        // STOP was shown no such thing, and stops at now; the row's time is
        // the operator's to edit.
        final atSilence = params['finishAtSilence'] == true;
        final lastActivity = atSilence ? operationLastActivityMillis(operation, seenMillis: asQsonNum(params['lastActivityMillis'])?.toInt()) : null;
        final finishAt = !atSilence
            ? nowMillis()
            : operation.status == OperationStatus.paused
            ? operation.statusAtMillis ?? lastActivity ?? nowMillis()
            : (lastActivity != null && nowMillis() - lastActivity >= operationQuietAfter.inMilliseconds)
            ? lastActivity
            : nowMillis();
        if (trailing(const {'pause'}) case final pause?) {
          // One finish per log: a stop left from before the pause would
          // otherwise close the log twice.
          if (previous != null) await drop(previous);
          await rekind(pause, 'stop', atMillis: pause.startAtMillis ?? nowMillis(), override: override, description: description);
        } else if (previous == null) {
          await qsos.addEvent(operation.uuid, kind: 'stop', atMillis: finishAt, operation: override, description: description);
        } else {
          await qsos.update(
            Qso(
              uuid: previous.uuid,
              operationUuid: previous.operationUuid,
              data: {
                ...previous.data,
                'startAtMillis': finishAt,
                // The override is being restated, so a description that
                // could not be composed in full is CLEARED rather than kept:
                // the old line would describe the stretch this row no longer
                // states (see [segmentDescription]).
                'event': {...?previous.event, 'operation': override, 'description': description}
                  ..removeWhere((key, value) => key == 'description' && value == null),
              },
            ),
          );
        }
        // A log already sent stays sent. `processed → completed` is the
        // signal that its uploads went stale, which only an edit to its
        // contacts raises, and an archived log stays out of the working set.
        if (operation.status != OperationStatus.processed && operation.status != OperationStatus.archived) {
          await moveStatusTo(OperationStatus.completed);
        }
    }

    if (params['setLocation'] != true) return null;
    final context = navigatorKey.currentContext;
    // The hook's confirm already said "now set your new location". Going
    // quiet here would leave the operator holding that promise while the
    // next stretch scores from the old square.
    if (context == null || !context.mounted) return (text: t.commands.couldNotOpenLocation, failed: true);
    final patch = await showHaloDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperationLocationScreen(services: this, operation: operation),
    );
    if (patch == null) return null;
    // The counters and local data ride along: `rescoreOperation` reads
    // `localData['huntedRefTypes']` to decide whether to write, and an
    // operation rebuilt without it looks uncached every time — a local_data
    // write, and the Operation View rebuild behind it, on every ROVERQTH.
    final updated = Operation(
      uuid: operation.uuid,
      data: {...operation.data, ...patch},
      qsoCount: operation.qsoCount,
      startAtMillisMin: operation.startAtMillisMin,
      startAtMillisMax: operation.startAtMillisMax,
      localData: operation.localData,
    );
    await operations.saveData(updated);
    unawaited(scoring.rescoreOperation(updated));
    return null;
  }
}
