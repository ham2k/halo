// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Trust-on-first-use pairing state (HALO-310) — see `PeerTrust`'s doc in
// database.dart for why trust is device-local and never synced.

import 'package:drift/drift.dart';

import '../app_clock.dart';
import '../db/database.dart';

class PeerTrustStore {
  final HaLoDatabase db;

  PeerTrustStore(this.db);

  Future<bool> isTrusted(String peerDeviceId) async {
    final row = await (db.select(db.peerTrust)..where((p) => p.peerDeviceId.equals(peerDeviceId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Records the operator's one-time confirmation of [peerDeviceId].
  ///
  /// [name] is refreshed on a re-pair so a renamed device doesn't show under
  /// its old name forever, but `pairedAtMillis` is NOT — it records when this
  /// operator first admitted the device, which is the thing worth being able
  /// to look back at. Real time, not the app clock: this outlives the session
  /// (docs/design/time.md).
  Future<void> trust(String peerDeviceId, {required String name}) async {
    final existing = await (db.select(db.peerTrust)..where((p) => p.peerDeviceId.equals(peerDeviceId)))
        .getSingleOrNull();
    await db.into(db.peerTrust).insertOnConflictUpdate(PeerTrustCompanion.insert(
          peerDeviceId: peerDeviceId,
          name: name,
          pairedAtMillis: existing?.pairedAtMillis ?? realNowMillis(),
          lastSeenAtMillis: Value(existing?.lastSeenAtMillis),
        ));
  }

  /// Withdraws trust. The peer's `PeerCursors` rows are deliberately left
  /// alone: they record what this device already applied, which stays true
  /// whether or not the peer is welcome back, and clearing them would make a
  /// re-pair replay the peer's whole outbox for nothing.
  Future<void> revoke(String peerDeviceId) async {
    await (db.delete(db.peerTrust)..where((p) => p.peerDeviceId.equals(peerDeviceId))).go();
  }

  Future<void> markSeen(String peerDeviceId) async {
    await (db.update(db.peerTrust)..where((p) => p.peerDeviceId.equals(peerDeviceId)))
        .write(PeerTrustCompanion(lastSeenAtMillis: Value(realNowMillis())));
  }

  Future<List<PeerTrustRow>> all() =>
      (db.select(db.peerTrust)..orderBy([(p) => OrderingTerm(expression: p.name)])).get();

  /// Reactive, for a "paired devices" list that has to reflect a pair or
  /// revoke happening elsewhere in the app.
  Stream<List<PeerTrustRow>> watchAll() =>
      (db.select(db.peerTrust)..orderBy([(p) => OrderingTerm(expression: p.name)])).watch();
}
