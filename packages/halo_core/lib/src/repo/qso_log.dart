// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:collection';

import '../models/models.dart';
import '../models/operation_lifecycle.dart';

/// An operation's log as the log stream emits it: the rows, oldest first, and
/// the digest of the ones that are not deleted — every uuid with its stamp,
/// summed so that order does not matter ([qsoLogDigestOf]).
///
/// The digest is what a scoring pass stamps its checkpoint with and what the
/// Operation View fingerprints the log by. Computed on demand it costs a walk
/// of every row, on the UI isolate, per emission and per keystroke. Carried
/// here it is maintained by the stream in the cost of each patch, and a
/// consumer that knows the type reads it in one step; one that does not sees
/// a list.
///
/// Unmodifiable: every emission is a new list, and a consumer keeping an
/// earlier one relies on nobody writing into it.
class QsoLog extends UnmodifiableListView<Qso> {
  /// [digest], [unstamped] and [summary] are trusted as read: they must
  /// describe exactly [rows], never a list they were carried over from.
  QsoLog(super.rows, {required this.digest, required this.unstamped, this._summary});

  QsoLogSummary? _summary;

  /// What the log's statistics read from it ([QsoLogSummary]). Folded from
  /// the rows the first time it is asked for, then carried forward by the
  /// stream patch by patch ([knownSummary]), so a per-second redraw of the
  /// stats reads it rather than walking the log.
  QsoLogSummary get summary => _summary ??= QsoLogSummary.of(this);

  /// [summary] when something has already asked for it, and null otherwise:
  /// the stream carries a summary forward only once one is being read, so a
  /// log nobody shows statistics for never pays for one.
  QsoLogSummary? get knownSummary => _summary;

  /// [qsoLogDigestOf] over the rows that are not deleted.
  final int digest;

  /// How many rows that are not deleted carry no `updatedAtMillis`. Such a
  /// row's term cannot move when its content does, so no digest can prove
  /// the row unchanged; a consumer proving anything by [digest] refuses
  /// while this is not zero.
  final int unstamped;
}

/// One row's term in the digest. Not a secure hash — it only has to notice a
/// stamp that moved or a contact that came or went. Each term and the sum
/// stay under 2^53 so the web build's integers carry them.
int qsoDigestTerm(Qso qso) => ((qso.uuid.hashCode & 0xFFFFFFFF) * 31 + (qso.updatedAtMillis ?? 0)) & 0xFFFFFFFF;

/// The digest of [rows] that are not deleted, as [QsoLog.digest] carries it.
int qsoLogDigestOf(Iterable<Qso> rows) {
  var digest = 0;
  for (final qso in rows) {
    if (!qso.deleted) digest += qsoDigestTerm(qso);
  }
  return digest;
}

/// The count of [rows] that are not deleted and carry no stamp, as
/// [QsoLog.unstamped] carries it.
int qsoLogUnstampedOf(Iterable<Qso> rows) => rows.where((qso) => !qso.deleted && qso.updatedAtMillis == null).length;

/// How many of the newest contacts' start times [QsoLogSummary] keeps, at
/// the least: a rate over the last 100 contacts reads the hundredth.
const qsoLogRecentContacts = 100;

/// How far back from the newest contact [QsoLogSummary] keeps every
/// contact's start time, however many that is: a rate over the last hour
/// reads them all, and at a contest's pace that is more than a hundred.
const qsoLogRecentWindow = Duration(minutes: 60);

/// The facts an operation's statistics need from its log, folded in one pass
/// and extended contact by contact rather than walked again.
///
/// Only rows that are not deleted, and only rows with a start time, count —
/// the way every other reader of the timeline counts them.
class QsoLogSummary {
  const QsoLogSummary._({
    required this.contacts,
    required this.firstContactAtMillis,
    required this.lastContactAtMillis,
    required this.startedAtMillis,
    required this.finishedAtMillis,
    required this.recentContactMillis,
    required this.pausedMillis,
    required this._lastRowAtMillis,
    required this._lastRowOpensPause,
    required this._pausedThroughLastRow,
    required this._opened,
  });

  /// The summary of [rows], oldest first.
  factory QsoLogSummary.of(Iterable<Qso> rows) => _empty.extendedBy(rows);

  static const _empty = QsoLogSummary._(
    contacts: 0,
    firstContactAtMillis: null,
    lastContactAtMillis: null,
    startedAtMillis: null,
    finishedAtMillis: null,
    recentContactMillis: [],
    pausedMillis: 0,
    lastRowAtMillis: null,
    lastRowOpensPause: false,
    pausedThroughLastRow: 0,
    opened: false,
  );

  /// The real contacts in the log, those without a start time included: they
  /// count, they only have no place on the timeline.
  final int contacts;

  /// The earliest and latest start times among the contacts.
  final int? firstContactAtMillis;
  final int? lastContactAtMillis;

  /// When the operation was marked as started: the EARLIEST `start` marker.
  /// `markSegment` writes at most one, but a log that arrived by sync or
  /// import can carry more, and the operation began at the first.
  final int? startedAtMillis;

  /// The latest `stop` or `end` marker.
  final int? finishedAtMillis;

  /// The newest contacts' start times, oldest first: at least the last
  /// [qsoLogRecentContacts], and every one within [qsoLogRecentWindow] of the
  /// newest. Enough for a rate over the last 10 or 100 contacts or the last
  /// 10 or 60 minutes, measured to the newest contact or to now — which is
  /// what lets a rate decay while nothing is logged — and weighted by age if
  /// it decays that way instead.
  final List<int> recentContactMillis;

  /// The time the log spent paused or finished, from its first contact or
  /// start marker to its last contact or lifecycle marker: each gap between
  /// two rows that a `pause` or finish opens, that a `restart` closes, or that
  /// runs [operationPauseAfterSilence] or longer.
  ///
  /// All three, because each way back leaves a different trace: Continue
  /// writes a `restart`, logging a contact into a paused log writes none, and
  /// a pause the sweep inferred from the silence has no row of its own at all.
  final int pausedMillis;

  // What extending needs and no reader does: the last row the gaps were
  // measured to, whether it opens a pause, the gaps through it — some past
  // the last contact or marker, which count only once one follows — and
  // whether the first contact or start marker has been reached yet.
  final int? _lastRowAtMillis;
  final bool _lastRowOpensPause;
  final int _pausedThroughLastRow;
  final bool _opened;

  /// This summary with [rows] appended — rows that start no earlier than any
  /// row already folded, oldest first. A row anywhere else changes facts an
  /// append cannot: fold the whole log again with [QsoLogSummary.of].
  QsoLogSummary extendedBy(Iterable<Qso> rows) {
    var contacts = this.contacts;
    var first = firstContactAtMillis;
    var last = lastContactAtMillis;
    var started = startedAtMillis;
    var finished = finishedAtMillis;
    var paused = pausedMillis;
    var lastRowAt = _lastRowAtMillis;
    var lastOpensPause = _lastRowOpensPause;
    var pausedThroughLastRow = _pausedThroughLastRow;
    var opened = _opened;
    ListQueue<int>? recent;

    for (final row in rows) {
      if (row.deleted) continue;
      final contact = !row.isEvent;
      final at = row.startAtMillis;
      if (at == null) {
        if (contact) contacts++;
        continue;
      }
      final kind = row.isEvent ? row.eventKind : null;
      if (contact) {
        contacts++;
        if (first == null || at < first) first = at;
        if (last == null || at > last) last = at;
        recent ??= ListQueue.of(recentContactMillis);
        recent.add(at);
        while (recent.length > qsoLogRecentContacts && recent.first < recent.last - qsoLogRecentWindow.inMilliseconds) {
          recent.removeFirst();
        }
      } else if (kind == 'start') {
        if (started == null || at < started) started = at;
      } else if (kind == 'stop' || kind == 'end') {
        if (finished == null || at > finished) finished = at;
      }

      if (!opened) {
        // Nothing before the first contact or start marker is time the log
        // spent anything: it had not begun.
        if (contact || kind == 'start') {
          opened = true;
        }
      } else if (lastRowAt != null) {
        final gap = at - lastRowAt;
        if (lastOpensPause || kind == 'restart' || gap >= operationPauseAfterSilence.inMilliseconds) pausedThroughLastRow += gap;
        if (contact || _lifecycleMarkers.contains(kind)) paused = pausedThroughLastRow;
      }
      lastRowAt = at;
      lastOpensPause = kind == 'pause' || kind == 'stop' || kind == 'end';
    }

    return QsoLogSummary._(
      contacts: contacts,
      firstContactAtMillis: first,
      lastContactAtMillis: last,
      startedAtMillis: started,
      finishedAtMillis: finished,
      recentContactMillis: recent == null ? recentContactMillis : List.unmodifiable(recent),
      pausedMillis: paused,
      lastRowAtMillis: lastRowAt,
      lastRowOpensPause: lastOpensPause,
      pausedThroughLastRow: pausedThroughLastRow,
      opened: opened,
    );
  }

  /// Whether [a] in place of [b] leaves a summary as it was: neither is a
  /// contact or a marker the other is not, and both start when they did.
  static bool sameFacts(Qso a, Qso b) => a.deleted == b.deleted && a.isEvent == b.isEvent && a.eventKind == b.eventKind && a.startAtMillis == b.startAtMillis;
}

/// The markers a span of the timeline ends on, beside its contacts.
const _lifecycleMarkers = {'start', 'stop', 'end', 'pause', 'restart'};
