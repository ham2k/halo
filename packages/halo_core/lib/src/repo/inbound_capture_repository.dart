// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Contacts captured from other programs (WSJT-X, N1MM) before an operation
// claims them. The contract every repository keeps is stated in
// repo_support.dart.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_clock.dart';
import '../db/database.dart';

import 'repo_support.dart';

/// The QSON [row] carried, decoded from its stored blob. See `InboundCaptures`.
extension InboundCaptureRowQson on InboundCaptureRow {
  Map<String, dynamic> get qso => (jsonDecode(data) as Map).cast<String, dynamic>();
}

/// See `InboundCaptures` — QSOs captured from another logging program
/// ("Listen for other apps"), buffered until the operator decides whether to
/// add them to an operation's log.
class InboundCaptureRepository {
  final HaLoDatabase db;
  final void Function()? onChange;

  InboundCaptureRepository(this.db, {this.onChange});

  /// Records a capture, unless [dedupeKey] already exists — a program that
  /// broadcasts the same contact twice (a resend, a second listener sharing
  /// the port) must not queue it twice. Returns the stored row either way,
  /// so the caller doesn't need to care which happened.
  ///
  /// `insertOrIgnore` against the table's unique `dedupeKey` index, not a
  /// preceding `SELECT`: two datagrams for the same contact land through two
  /// independent socket callbacks (`InboundQsoListenerService`'s handlers
  /// fire-and-forget via `unawaited`), so a check-then-insert has a real race
  /// window between them — the index is what actually makes this atomic.
  Future<InboundCaptureRow> capture({required String source, required String dedupeKey, required Map<String, dynamic> qsoData}) async {
    final uuid = uuidGenerator.v4();
    await db
        .into(db.inboundCaptures)
        .insert(
          InboundCapturesCompanion.insert(
            uuid: uuid,
            source: source,
            dedupeKey: dedupeKey,
            // Deliberately NOT normalized (unlike every other QSON write
            // here): this table stages what a peer app actually sent, and
            // repairing it in place would destroy the evidence of what
            // arrived. Normalization happens when a capture is promoted into
            // a real QSO.
            data: jsonEncode(qsoData),
            receivedAtMillis: nowMillis(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    // By dedupeKey, not [uuid]: a conflict means [uuid] was never written,
    // and the winner (whichever insert the unique index actually accepted)
    // is what the caller needs back either way. Whether OUR insert was the
    // winner is decided by comparing uuids, not `insert()`'s return value —
    // that's `sqlite3`'s `last_insert_rowid()`, which only changes on a
    // successful insert ANYWHERE on the connection, so it stays nonzero
    // (and useless as a "did this call insert anything" signal) the moment
    // any row has ever been inserted at all.
    final row = await (db.select(db.inboundCaptures)..where((c) => c.dedupeKey.equals(dedupeKey))).getSingle();
    if (row.uuid == uuid) onChange?.call();
    return row;
  }

  /// Every capture not yet added to any operation, oldest first — across all
  /// sources: "Listen for other apps" is one feature to the operator, not
  /// one per protocol, so its pending list is one list, not one per source.
  /// [source] survives on the row (and the dedupe key) purely as metadata.
  Stream<List<InboundCaptureRow>> watchPending() =>
      (db.select(db.inboundCaptures)
            ..where((c) => c.addedToOperation.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.receivedAtMillis)]))
          .watch();

  /// Marks [uuids] as added to [operationUuid]. Kept rather than deleted, so
  /// a re-arriving duplicate broadcast is still recognized by its dedupe key
  /// instead of being queued a second time.
  Future<void> markAdded(Iterable<String> uuids, String operationUuid) async {
    if (uuids.isEmpty) return;
    await (db.update(db.inboundCaptures)..where((c) => c.uuid.isIn(uuids))).write(InboundCapturesCompanion(addedToOperation: Value(operationUuid)));
    onChange?.call();
  }

  /// Discards [uuids] without adding them — the operator dismissing a bad
  /// capture (wrong station, a garbled datagram).
  Future<void> discard(Iterable<String> uuids) async {
    if (uuids.isEmpty) return;
    await (db.delete(db.inboundCaptures)..where((c) => c.uuid.isIn(uuids))).go();
    onChange?.call();
  }
}
