// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../dev_log.dart';
import '../models/models.dart';
import 'history_filter.dart';
import 'repo_support.dart';

/// The cross-operation reads of the qsos table — a callsign's history and
/// the station calls on record — kept beside `QsosRepository`'s writers as a
/// mixin so the repository stays one class with one `db`.
mixin QsoHistoryQueries {
  HaLoDatabase get db;

  /// A row of the qsos table that is a contact rather than a start/break/end
  /// marker. The ONE definition — every count the operator reads as "QSOs"
  /// uses it, and LoFi's `QSO.contacts` scope mirrors it so the Sync panel can
  /// put the two numbers side by side.
  Expression<bool> get isContact;

  /// Every non-deleted, non-event QSO with [call] across every operation, most
  /// recent first — for the call-info detail's QSO history. Matches the
  /// denormalized `theirCall` column (stored uppercase), so no JSON parsing.
  ///
  /// Deleting an operation deliberately does NOT tombstone its QSOs — that
  /// would be unrecoverable, since undeleting could no longer tell which of
  /// them the user had deleted individually beforehand. So a cross-operation
  /// query has to join: a QSO counts as gone when its own flag says so OR
  /// when the operation it belongs to is deleted. The join is a LEFT OUTER
  /// one because a QSO can outlive its operation row (an inbound sync batch
  /// can carry QSOs before the operation they belong to arrives) — those
  /// count as present, same as before.
  ///
  /// [limit], when given, bounds the SQL query itself (not a post-fetch
  /// truncation) — for a caller like `call-history`'s lookup source that
  /// only ever reads the most recent match or two: without it, a station
  /// worked hundreds of times ships its entire history across the extension
  /// bridge for an answer that only ever uses the first row. Applied after
  /// every exclusion, event markers included, so it is an exact result count.
  ///
  /// [filter] narrows the history in the same query, before the ordering and
  /// the limit — see [HistoryFilter]. Filtering the limited rows afterwards
  /// would lose an older match behind newer non-matching contacts. Its own
  /// `limit` is the host call's; this method applies only [limit].
  Future<List<Qso>> historyForCall(String call, {int? limit, HistoryFilter filter = HistoryFilter.none}) async {
    final normalized = call.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final query = db.select(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
      ..where(
        db.qsos.theirCall.equals(normalized) &
            db.qsos.deleted.equals(false) &
            isContact &
            (db.operations.deleted.equals(false) | db.operations.uuid.isNull()) &
            filter.toSql(db.qsos, db.operations),
      )
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis, mode: OrderingMode.desc)]);
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return [for (final row in rows) qsoFromRow(row.readTable(db.qsos))];
  }

  /// When each contact [historyForCall] would list started, most recent
  /// first — the call-info's "worked before" pill, which buckets them by
  /// day. One column rather than the rows, so a callsign worked hundreds of
  /// times does not ship every QSO's data to answer a handful of counts.
  ///
  /// [excludingUuid] leaves one QSO out: the QSO being EDITED is already in
  /// the log, and counting it would call a station worked once "worked once
  /// before" while its own QSO is open.
  ///
  /// The same rules as [historyForCall], in SQL: soft-deleted QSOs and QSOs
  /// of deleted operations drop out, and so do event markers — via
  /// [isContact], since a bare `band != 'event'` is NULL for a band-less
  /// QSO and would drop it too. A QSO with no start time still counts, as
  /// a zero.
  Future<List<int>> historyStartTimesForCall(String call, {String? excludingUuid}) async {
    final normalized = call.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final query = db.selectOnly(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
      ..addColumns([db.qsos.startAtMillis])
      ..where(
        db.qsos.theirCall.equals(normalized) &
            db.qsos.deleted.equals(false) &
            isContact &
            (excludingUuid == null ? const Constant(true) : db.qsos.uuid.equals(excludingUuid).not()) &
            (db.operations.deleted.equals(false) | db.operations.uuid.isNull()),
      )
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return [for (final row in rows) row.read(db.qsos.startAtMillis) ?? 0];
  }

  /// [historyForCall] for every one of [calls] in a single query — an ADIF
  /// import matching a large file's counterparties one callsign at a time
  /// turns into thousands of sequential round trips. Chunked at
  /// [inClauseChunkSize] for SQLite's bound-variable limit; [watchForOurCalls]
  /// does not chunk its own `IN` list, since every caller today passes it a
  /// single callsign.
  ///
  /// [onChunk], when given, is called after every chunk with (calls looked
  /// up so far, total calls) — real progress for a caller that would
  /// otherwise have nothing but "still working" for however long the
  /// chunks take.
  Future<List<Qso>> historyForCalls(Iterable<String> calls, {void Function(int done, int total)? onChunk}) async {
    final normalized = calls.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
    if (normalized.isEmpty) return const [];
    final results = <Qso>[];
    for (var i = 0; i < normalized.length; i += inClauseChunkSize) {
      final chunk = normalized.sublist(i, math.min(i + inClauseChunkSize, normalized.length));
      final query = db.select(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
        ..where(db.qsos.theirCall.isIn(chunk) & db.qsos.deleted.equals(false) & (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
      final rows = await query.get();
      // `qsosFromRows`, not a bare `.map(qsoFromRow)` — a chunk from an
      // established callsign can itself clear the isolate-offload
      // threshold, and this runs while the import's progress dialog is
      // animating.
      final decoded = await qsosFromRows([for (final row in rows) row.readTable(db.qsos)]);
      results.addAll(decoded.where((qso) => !qso.isEvent));
      // A caller's progress UI throwing (a disposed notifier, a formatting
      // edge case) must not fail the lookup itself, or discard whatever
      // chunks already decoded cleanly.
      try {
        onChunk?.call(math.min(i + inClauseChunkSize, normalized.length), normalized.length);
      } catch (e) {
        DevLog.instance.log('historyForCalls-onChunk-error', {'error': e.toString()});
      }
    }
    return results;
  }

  /// Every station callsign QSOs have been logged under, across every
  /// operation, with how many QSOs each has — the Logs experiment's
  /// callsign picker (docs card HALO-273), which shows the count as a pill
  /// next to each entry. Matches the denormalized `ourCall` column (stored
  /// uppercase), same join shape as [historyForCall]: a deleted operation's
  /// QSOs drop out even though deleting an operation does not tombstone
  /// them.
  Stream<Map<String, int>> watchDistinctOurCalls() {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
      ..addColumns([db.qsos.ourCall, count])
      ..where(
        db.qsos.ourCall.isNotNull() &
            db.qsos.ourCall.equals('').not() &
            db.qsos.deleted.equals(false) &
            // Event markers (start/break/end) carry no real callsign —
            // excluded the same way `historyForCall` excludes them from a
            // QSO list, or a callsign whose only rows are markers shows up
            // in this picker with nothing behind it. `isContact`, not a
            // bare `band != 'event'`: that reads NULL — not true — for a
            // QSO logged without a band, silently dropping it too.
            isContact &
            (db.operations.deleted.equals(false) | db.operations.uuid.isNull()),
      )
      ..groupBy([db.qsos.ourCall]);
    return query.watch().map((rows) {
      final calls = <String, int>{};
      for (final row in rows) {
        final call = row.read(db.qsos.ourCall);
        if (call != null && call.isNotEmpty) calls[call] = row.read(count) ?? 0;
      }
      return calls;
    });
  }

  /// Every non-deleted QSO logged under any of [calls] (own station
  /// callsign), across every operation, oldest first — the Logs experiment's
  /// QSO table, scoped by its "log filter". Same join shape as
  /// [historyForCall], but on `ourCall` instead of `theirCall`, and live
  /// (the log filter's callsign selection can change under the caller).
  /// Unlike [historyForCalls], [calls] is not chunked — stay well under
  /// SQLite's bound-variable limit (~999) if the log filter ever grows past a
  /// single callsign.
  Stream<List<Qso>> watchForOurCalls(Iterable<String> calls) {
    final normalized = calls.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
    if (normalized.isEmpty) return Stream.value(const []);
    final query = db.select(db.qsos).join([leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation))])
      ..where(db.qsos.ourCall.isIn(normalized) & db.qsos.deleted.equals(false) & (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis)]);
    return query.watch().asyncMap((rows) async {
      final decoded = await qsosFromRows([for (final row in rows) row.readTable(db.qsos)]);
      // Same exclusion `historyForCall` applies — an event marker is not a
      // QSO, and this view has no concept of one to render or edit.
      return decoded.where((qso) => !qso.isEvent).toList();
    });
  }
}
