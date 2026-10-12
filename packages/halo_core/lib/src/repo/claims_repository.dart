// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Claims: the only writer to the `claims` table (docs/design/claims.md
// §5–§7). Which claims a contact makes is the `chasing` hook's to say; this
// keeps the best one per slot, by the slot rule for what the log says and by
// the merge rule for what sync brings.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../app_clock.dart';
import '../db/database.dart';
import '../models/claims.dart';
import 'repo_support.dart';

class ClaimsRepository {
  ClaimsRepository(this.db, {this.onChange});

  final HaLoDatabase db;

  /// Fired after a write that leaves rows to push, like the other
  /// repositories' — what nudges sync.
  final void Function()? onChange;

  final _merged = StreamController<List<StoredClaim>>.broadcast();
  final _cleared = StreamController<void>.broadcast();

  /// The rows each [mergeFromSync] accepted. A device holding the whole log
  /// checks them against its contacts: one from a device that has not yet
  /// heard of a deletion can outrank the row here and still name a contact
  /// that is gone (§7).
  Stream<List<StoredClaim>> get merged => _merged.stream;

  /// Fires when [clearAll] empties the table, so whatever vouched for the
  /// rows stops vouching.
  Stream<void> get cleared => _cleared.stream;

  /// The live `log` rows held by any of [qsoUuids]: the slots those contacts
  /// fill today, which an edit or a deletion may take from them.
  Future<List<StoredClaim>> heldBy(Iterable<String> qsoUuids) async {
    final list = qsoUuids.toSet().toList();
    final rows = <ClaimRow>[];
    for (var start = 0; start < list.length; start += inClauseChunkSize) {
      final chunk = list.sublist(start, math.min(start + inClauseChunkSize, list.length));
      rows.addAll(await (db.select(db.claims)..where((c) => c.qso.isIn(chunk) & c.deleted.equals(false) & c.source.equals(kClaimSourceLog))).get());
    }
    return rows.map(_fromRow).toList();
  }

  /// One holder's checklist under [program]: the best live row per slot,
  /// across every source (§5).
  Future<List<StoredClaim>> checklist(String program, String holder, {String edition = ''}) async {
    final rows = await (db.select(
      db.claims,
    )..where((c) => c.program.equals(program) & c.holder.equals(holder) & c.edition.equals(edition) & c.deleted.equals(false))).get();
    final best = <(String, String?, String?), StoredClaim>{};
    for (final claim in rows.map(_fromRow)) {
      final slot = (claim.ref, claim.band, claim.mode);
      final held = best[slot];
      if (held == null || compareClaims(claim, held) > 0) best[slot] = claim;
    }
    return best.values.toList();
  }

  /// Writes each of [candidates] that beats its slot's `log` row, or fills a
  /// slot that has none (§6's upgrade, which any device may make). Several
  /// candidates for one slot settle among themselves first. A row replaced
  /// keeps its epoch: an upgrade is a fact any device may learn, not a
  /// rescan's verdict.
  ///
  /// The contact already holding a slot can also restate it — a new label,
  /// a new program version — and that is written too. What no candidate
  /// can do here is lower a slot: a downgrade needs the whole log
  /// ([writeRescan]). Nor can it replace a row a newer version of the
  /// program computed, live or withdrawn, for the reason [writeRescan]
  /// leaves those alone.
  ///
  /// Returns the rows written.
  Future<int> applyUpgrades(Iterable<StoredClaim> candidates) async {
    final best = <String, StoredClaim>{};
    for (final candidate in candidates) {
      final held = best[candidate.uuid];
      if (held == null || compareClaims(candidate, held) > 0) best[candidate.uuid] = candidate;
    }
    if (best.isEmpty) return 0;
    final written = await db.transaction(() async {
      final existing = await _byUuid(best.keys);
      final now = realNowMillis();
      var written = 0;
      for (final candidate in best.values) {
        final held = existing[candidate.uuid];
        final StoredClaim next;
        if (held != null && held.version > candidate.version) {
          continue;
        } else if (held == null) {
          next = candidate;
        } else if (held.deleted || compareClaims(candidate, held) > 0) {
          next = candidate.copyWith(epoch: held.epoch);
        } else if (candidate.qso == held.qso && compareClaims(candidate, held) == 0) {
          next = candidate.copyWith(epoch: held.epoch);
          if (next.sameContentAs(held)) continue;
        } else {
          continue;
        }
        await _write(next.copyWith(updatedAtMillis: now), synced: false);
        written++;
      }
      return written;
    });
    if (written > 0) onChange?.call();
    return written;
  }

  /// Replaces [program]'s `log` rows with [best], the best claim per slot
  /// from a pass over the whole log (§6's downgrade and rebuild, which only
  /// a device holding the whole log may make). Every row this changes —
  /// written, replaced, or withdrawn because no contact claims its slot any
  /// more — goes out under an epoch above any this program's rows carry, so
  /// it outranks every row another device computed without seeing the
  /// change (§7). A row the pass agrees with is left as it is, epoch
  /// included: rewriting it would push the whole checklist for nothing.
  ///
  /// A row a newer [version] of the program computed is left alone too,
  /// written or withdrawn: this device's older extension is not the one to
  /// overrule it.
  ///
  /// So is a live row the pass could not judge, unless [best] beats it: one
  /// held by a contact in [unanswered], which the program left out of its
  /// answer, or by a contact [knownContacts] says this device has never
  /// seen, which may beat everything here. Decided inside the write, so a
  /// row sync merged while the pass read the log is judged as well.
  ///
  /// Returns the rows written.
  Future<int> writeRescan(
    String program,
    int version,
    Map<String, StoredClaim> best, {
    Set<String> unanswered = const {},
    Future<Set<String>> Function(Iterable<String> qsoUuids)? knownContacts,
  }) async {
    final written = await db.transaction(() async {
      final rows = await (db.select(db.claims)..where((c) => c.program.equals(program) & c.source.equals(kClaimSourceLog))).get();
      final existing = {for (final row in rows) row.uuid: _fromRow(row)};
      final named = {
        for (final held in existing.values)
          if (!held.deleted && held.qso != null) held.qso!,
      };
      final unseen = knownContacts == null ? const <String>{} : named.difference(await knownContacts(named));
      best = {...best};
      for (final held in existing.values) {
        if (held.deleted || !(unanswered.contains(held.qso) || unseen.contains(held.qso))) continue;
        final other = best[held.uuid];
        if (other == null || compareClaims(held, other) > 0) best[held.uuid] = held;
      }
      final epoch = existing.values.fold(-1, (top, claim) => math.max(top, claim.epoch)) + 1;
      final now = realNowMillis();
      var written = 0;
      for (final claim in best.values) {
        final held = existing[claim.uuid];
        if (held != null && (held.version > version || held.sameContentAs(claim))) continue;
        await _write(claim.copyWith(epoch: epoch, updatedAtMillis: now), synced: false);
        written++;
      }
      for (final held in existing.values) {
        if (held.deleted || held.version > version || best.containsKey(held.uuid)) continue;
        await _write(held.copyWith(epoch: epoch, deleted: true, updatedAtMillis: now), synced: false);
        written++;
      }
      return written;
    });
    if (written > 0) onChange?.call();
    return written;
  }

  /// Merges rows another device wrote (§7): the incoming row replaces the
  /// local one only when [compareClaimRows] ranks it higher. A local row that
  /// ranks higher is marked unsynced, so the next push writes it back; the
  /// order is total, so every device converges on the same rows.
  ///
  /// A record that is not a claim, or whose uuid is not its slot's, is
  /// skipped.
  ///
  /// Returns the rows accepted. A device holding the whole log checks them:
  /// a row from a device that has not yet heard of a deletion can rank
  /// higher here and still name a contact that no longer claims the slot.
  Future<List<StoredClaim>> mergeFromSync(Iterable<Object?> records) async {
    final incoming = <String, StoredClaim>{};
    for (final record in records) {
      final claim = StoredClaim.tryParseRecord(record);
      if (claim == null) continue;
      final held = incoming[claim.uuid];
      if (held == null || compareClaimRows(claim, held) > 0) incoming[claim.uuid] = claim;
    }
    if (incoming.isEmpty) return const [];
    var writeBack = false;
    final accepted = await db.transaction(() async {
      final existing = await _byUuid(incoming.keys);
      final accepted = <StoredClaim>[];
      for (final claim in incoming.values) {
        final held = existing[claim.uuid];
        final order = held == null ? 1 : compareClaimRows(claim, held);
        if (order > 0) {
          await _write(claim, synced: true);
          accepted.add(claim);
        } else if (order < 0) {
          // Restamped past the row it beat: the server keeps the newer
          // `updatedAtMillis`, so a write-back at the old stamp would be
          // dropped there as stale and the worse row would stand.
          final stamp = math.max(realNowMillis(), (claim.updatedAtMillis ?? 0) + 1);
          await (db.update(
            db.claims,
          )..where((c) => c.uuid.equals(claim.uuid))).write(ClaimsCompanion(synced: const Value(false), updatedAtMillis: Value(stamp)));
          writeBack = true;
        }
      }
      return accepted;
    });
    if (writeBack) onChange?.call();
    if (accepted.isNotEmpty) _merged.add(accepted);
    return accepted;
  }

  /// Up to [limit] rows waiting to be pushed, withdrawn ones included.
  Future<List<StoredClaim>> unsyncedBatch(int limit, {Set<String> excluding = const {}}) async {
    final query = db.select(db.claims)
      ..where((c) => excluding.isEmpty ? c.synced.equals(false) : c.synced.equals(false) & c.uuid.isNotIn(excluding))
      ..orderBy([(c) => OrderingTerm(expression: c.updatedAtMillis)])
      ..limit(limit);
    return (await query.get()).map(_fromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row =
        await (db.select(db.claims)
              ..where((c) => c.synced.equals(false))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Marks [sent] synced, each only if it is still the revision that went
  /// out: one rewritten while the push was on the network stays dirty.
  Future<void> markSynced(Iterable<StoredClaim> sent) async {
    final list = sent.toList();
    if (list.isEmpty) return;
    await db.transaction(() async {
      for (final claim in list) {
        final stamp = claim.updatedAtMillis;
        await (db.update(db.claims)..where((c) => c.uuid.equals(claim.uuid) & (stamp == null ? c.updatedAtMillis.isNull() : c.updatedAtMillis.equals(stamp))))
            .write(const ClaimsCompanion(synced: Value(true)));
      }
    });
  }

  /// Empties the table. Claims are rebuilt from the log, and an epoch only
  /// ranks rows that share one history, so a device joining or leaving an
  /// account starts from none.
  Future<void> clearAll() async {
    await db.delete(db.claims).go();
    _cleared.add(null);
  }

  Future<Map<String, StoredClaim>> _byUuid(Iterable<String> uuids) async {
    final list = uuids.toList();
    final found = <String, StoredClaim>{};
    for (var start = 0; start < list.length; start += inClauseChunkSize) {
      final chunk = list.sublist(start, math.min(start + inClauseChunkSize, list.length));
      for (final row in await (db.select(db.claims)..where((c) => c.uuid.isIn(chunk))).get()) {
        found[row.uuid] = _fromRow(row);
      }
    }
    return found;
  }

  Future<void> _write(StoredClaim claim, {required bool synced}) => db
      .into(db.claims)
      .insertOnConflictUpdate(
        ClaimsCompanion.insert(
          uuid: claim.uuid,
          program: claim.program,
          holder: claim.holder,
          edition: Value(claim.edition),
          ref: claim.ref,
          band: Value(claim.band),
          mode: Value(claim.mode),
          source: claim.source,
          level: claim.level.name,
          atMillis: Value(claim.atMillis),
          qso: Value(claim.qso),
          data: Value(jsonEncode(claim.data)),
          version: claim.version,
          epoch: Value(claim.epoch),
          deleted: Value(claim.deleted),
          synced: Value(synced),
          updatedAtMillis: Value(claim.updatedAtMillis),
        ),
      );

  static StoredClaim _fromRow(ClaimRow row) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(row.data);
      data = decoded is Map ? decoded.cast<String, dynamic>() : const {};
    } on FormatException {
      data = const {};
    }
    return StoredClaim(
      uuid: row.uuid,
      program: row.program,
      holder: row.holder,
      edition: row.edition,
      ref: row.ref,
      band: row.band,
      mode: row.mode,
      source: row.source,
      // Only this repository writes the column, always from a `ClaimLevel`.
      level: ClaimLevel.tryParse(row.level) ?? ClaimLevel.worked,
      atMillis: row.atMillis,
      qso: row.qso,
      version: row.version,
      epoch: row.epoch,
      data: data,
      deleted: row.deleted,
      updatedAtMillis: row.updatedAtMillis,
    );
  }
}
