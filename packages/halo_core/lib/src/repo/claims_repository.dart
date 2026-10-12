// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Claims: the only writer to the `claims` table (docs/design/claims.md
// §5–§7). Which claims a contact makes is the `chasing` hook's to say; this
// keeps the best one per slot, by the slot rule for what the log says and by
// the merge rule for what sync brings.

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

  /// Whether [program] has live rows an older version of it computed, which
  /// a device holding the whole log rebuilds (§6). A row from a NEWER version
  /// is left alone: it came from a device running a newer extension, and
  /// rebuilding it here would replace a better answer with an older one. A
  /// withdrawn row is not counted: a rebuild that claims nothing for its
  /// slot leaves it as it is, so counting it would ask for a rebuild on
  /// every launch.
  Future<bool> hasRowsBelowVersion(String program, int version) async {
    final row =
        await (db.select(db.claims)
              ..where((c) => c.program.equals(program) & c.source.equals(kClaimSourceLog) & c.deleted.equals(false) & c.version.isSmallerThanValue(version))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
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
  /// Returns the rows written.
  Future<int> writeRescan(String program, int version, Map<String, StoredClaim> best) async {
    final written = await db.transaction(() async {
      final rows = await (db.select(db.claims)..where((c) => c.program.equals(program) & c.source.equals(kClaimSourceLog))).get();
      final existing = {for (final row in rows) row.uuid: _fromRow(row)};
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
          await (db.update(db.claims)..where((c) => c.uuid.equals(claim.uuid))).write(const ClaimsCompanion(synced: Value(false)));
          writeBack = true;
        }
      }
      return accepted;
    });
    if (writeBack) onChange?.call();
    return accepted;
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
