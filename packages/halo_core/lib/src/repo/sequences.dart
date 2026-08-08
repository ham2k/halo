// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial-number sequences — the numbers a contest sends as part of its
// exchange (docs/design/contests.md §5.8).
//
// Three invariants everything here follows from:
//
//   1. An allocated number is DATA OF RECORD. It went out on the air, so it
//      lives on the QSO — synced, exported, in the ADIF. Deliberately unlike a
//      score, which is derived and lives in a wipeable cache.
//   2. The counter is DERIVED. It is a high-water mark that can always be
//      rebuilt from the log as `max(serial, including soft-deleted) + 1`. Every
//      hard case — delete, edit, crash, inbound sync, ADIF import — is answered
//      by "rebuild the counter, never the numbers."
//   3. Allocation happens ONCE, AT COMMIT, inside the QSO insert transaction.
//      Not at compose time (app-polo's root defect: wiping a half-typed QSO
//      leaks a number, and tapping a spot mid-QSO gives two QSOs the same one),
//      not on edit, and not on rescore.
//
// Invariant 3 is what makes "rescoring never renumbers" structural rather than
// a discipline: nothing in the scoring path can reach a sequence.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../app_clock.dart';
import '../db/database.dart';
import '../models/models.dart';

/// A sequence exactly as an extension declared it, in the `serial` input
/// descriptor's `sequence` binding (docs/design/contests.md §5.3).
///
/// Contests differ in what counts as one series: most number the whole
/// operation, some restart per band. The extension says which by listing
/// [scope]; the core turns that into a distinct label per band/mode combination
/// so nothing else in the system has to know the rule.
class SequenceDescriptor {
  /// Where the allocated number is written — `refs[refType][field]`.
  final String refType;
  final String field;

  /// Namespaced `<extensionKey>/<binding key>`, so two contests active at once
  /// never share a counter.
  final String key;

  /// `'band'` and/or `'mode'` — one sequence per distinct value of each.
  final List<String> scope;

  /// First number this sequence issues.
  final int start;

  const SequenceDescriptor({
    required this.refType,
    required this.field,
    required this.key,
    this.scope = const [],
    this.start = 1,
  });

  /// Reads a `kind: 'serial'` logging control's input descriptor. Returns null
  /// if it isn't one, or is missing anything allocation needs — a malformed
  /// declaration must leave the field alone, never allocate against a
  /// half-formed label.
  static SequenceDescriptor? fromInput(Map<String, dynamic> input, {required String extensionKey}) {
    if (input['kind'] != 'serial') return null;
    final refType = input['refType'];
    final field = input['field'];
    final sequence = input['sequence'];
    if (refType is! String || field is! String || sequence is! Map) return null;
    final key = sequence['key'];
    if (key is! String || key.isEmpty) return null;
    return SequenceDescriptor(
      refType: refType,
      field: field,
      key: '$extensionKey/$key',
      scope: [
        for (final value in (sequence['scope'] as List?) ?? const []) if (value is String) value,
      ],
      start: (sequence['start'] as num?)?.toInt() ?? 1,
    );
  }

  /// Resolves the label for [qso] and returns the request to allocate against.
  SequenceRequest requestFor(Qso qso) {
    final parts = [
      key,
      for (final axis in scope)
        switch (axis) {
          'band' => qso.band ?? '?',
          'mode' => qso.mode ?? '?',
          _ => axis,
        },
    ];
    return SequenceRequest(descriptor: this, label: parts.join('|'));
  }
}

/// One contest's declared sequence, resolved for a specific QSO — the unit
/// every operation in this file works against.
///
/// The `label` is computed by the CORE at commit from the committed QSO, never
/// baked into the extension's descriptor: that descriptor is a snapshot taken
/// when the callsign lookup resolved, and the operator may still change band
/// before pressing Enter.
class SequenceRequest {
  final SequenceDescriptor descriptor;

  /// `<extensionKey>/<key>` plus any scope values.
  final String label;

  const SequenceRequest({required this.descriptor, required this.label});

  /// Where the allocated number is written — `refs[refType][field]`.
  String get refType => descriptor.refType;
  String get field => descriptor.field;

  /// First number this sequence issues.
  int get start => descriptor.start;

  /// Whether [qso] belongs to THIS sequence — i.e. resolves to the same label.
  /// A per-band sequence must not see another band's numbers when rebuilding
  /// its high-water mark, or every band after the first starts mid-series.
  bool includes(Qso qso) => descriptor.requestFor(qso).label == label;
}

class SequencesRepository {
  final HaLoDatabase db;

  SequencesRepository(this.db);

  /// Memoized `_derivedHighWaterMark` results, keyed `operation|label`.
  ///
  /// The derived mark is a scan of the whole log, and `peek` runs on every
  /// insert (twice, counting the panel's preview refresh) — so deriving it
  /// afresh each time made logging a contest quadratic: measured 0.5ms -> 13.8ms
  /// per insert at 3000 QSOs, on the UI isolate.
  ///
  /// A present key with a null value is a real answer ("scanned, no serials"),
  /// which is why this is `containsKey`-checked rather than null-checked.
  ///
  /// Only ever safe to be too HIGH, never too low: too high leaves a gap, which
  /// every sponsor accepts, while too low re-issues a number that already went
  /// on the air. Hence [noteIssued] only ever raises it, and anything that can
  /// introduce a number this repository did not issue must [invalidate].
  final Map<String, int?> _derived = {};

  String _cacheKey(String operationUuid, String label) => '$operationUuid|$label';

  /// Bumped by [invalidate]. A scan that started before an invalidation must
  /// not write its result into the freshly-cleared map: it read the log as it
  /// was BEFORE whatever prompted the invalidation, so caching it would pin a
  /// stale-low mark permanently — and stale-low re-issues a number that already
  /// went on the air. One `_derived[...] = ...` sits across an `await`, which
  /// is exactly the window this closes.
  int _generation = 0;

  /// Test seam: awaited after the log scan finishes but BEFORE its result is
  /// memoized. That gap is the whole race — an `invalidate()` landing in it
  /// must not be undone by the in-flight scan — and it cannot be hit
  /// deterministically from outside, because an in-memory database completes
  /// the scan before a test can interleave anything. Never set in production.
  @visibleForTesting
  Future<void> Function()? debugAfterScan;

  /// Forgets the memoized marks, so the next `peek` re-derives from the log.
  ///
  /// Call after ANY write that can put a serial in the log without going
  /// through [allocate]/[raiseTo] — an inbound sync, an ADIF import, an edit
  /// that changed a serial by hand. Cheap: the cost is one rescan, once.
  ///
  /// Call it AFTER the write has committed, never before: a scan starting in
  /// between would read the old log and cache that as current.
  void invalidate() {
    _derived.clear();
    _generation++;
  }

  /// Records that [value] is now in the log for this sequence, keeping the
  /// memo exact without a rescan. Raises only — see [_derived].
  void noteIssued(String operationUuid, SequenceRequest request, int value) {
    final key = _cacheKey(operationUuid, request.label);
    final current = _derived[key];
    if (current == null || value > current) _derived[key] = value;
  }

  /// The number this sequence would issue next, without consuming it — for the
  /// logging panel's serial field, so the operator can read the number they're
  /// about to send while they're still typing the callsign.
  ///
  /// In a single-client world this is authoritative: nothing else allocates
  /// between the peek and the commit. That property is exactly what block
  /// allocation preserves if distributed allocation lands later, which is why
  /// the extension-facing API doesn't need to change for it.
  Future<int> peek(String operationUuid, SequenceRequest request) async {
    final stored = await _stored(operationUuid, request.label);
    final derived = await _derivedHighWaterMark(operationUuid, request);
    return _resolve(stored, derived, request.start);
  }

  /// Consumes and returns the next number. Call only from inside the QSO
  /// insert's transaction — see the module note on invariant 3.
  Future<int> allocate(String operationUuid, SequenceRequest request) async {
    final next = await peek(operationUuid, request);
    await _write(operationUuid, request, next + 1);
    return next;
  }

  /// Raises the counter so it can never re-issue [value] — used when the
  /// operator types their own number over the allocated one, and after an
  /// inbound sync brings in QSOs numbered by another device.
  Future<void> raiseTo(String operationUuid, SequenceRequest request, int value) async {
    final current = await peek(operationUuid, request);
    if (value < current) return;
    await _write(operationUuid, request, value + 1);
  }

  /// The operator's own starting point ("I logged the first hour on paper").
  Future<void> setStart(String operationUuid, SequenceRequest request, int start) async {
    await db.into(db.sequences).insertOnConflictUpdate(
          SequencesCompanion(
            operation: Value(operationUuid),
            label: Value(request.label),
            nextValue: Value(await _resolveStart(operationUuid, request, start)),
            startValue: Value(start),
            updatedAtMillis: Value(realNowMillis()),
          ),
        );
  }

  Future<int> _resolveStart(String operationUuid, SequenceRequest request, int start) async {
    final derived = await _derivedHighWaterMark(operationUuid, request);
    // A new start can't retroactively un-issue numbers already on the air.
    return derived == null ? start : (derived + 1 > start ? derived + 1 : start);
  }

  Future<void> _write(String operationUuid, SequenceRequest request, int nextValue) async {
    await db.into(db.sequences).insertOnConflictUpdate(
          SequencesCompanion(
            operation: Value(operationUuid),
            label: Value(request.label),
            nextValue: Value(nextValue),
            startValue: Value(request.start),
            updatedAtMillis: Value(realNowMillis()),
          ),
        );
  }

  Future<SequenceRow?> _stored(String operationUuid, String label) async {
    return (db.select(db.sequences)
          ..where((s) => s.operation.equals(operationUuid) & s.label.equals(label)))
        .getSingleOrNull();
  }

  /// `max(serial already on this operation's QSOs)`, or null if none.
  ///
  /// Soft-deleted rows COUNT: their numbers went out on the air, so re-issuing
  /// one would put a duplicate in the log. A gap is acceptable to every contest
  /// sponsor; a reused number is not.
  ///
  /// This is why the stored counter is only ever a cache — a cold start, an
  /// inbound sync and an ADIF import all resolve through here without anything
  /// having had to notice they happened.
  Future<int?> _derivedHighWaterMark(String operationUuid, SequenceRequest request) async {
    final cacheKey = _cacheKey(operationUuid, request.label);
    if (_derived.containsKey(cacheKey)) return _derived[cacheKey];

    final generation = _generation;
    final rows = await (db.select(db.qsos)..where((q) => q.operation.equals(operationUuid))).get();
    int? highest;
    for (final row in rows) {
      final qso = Qso(
        uuid: row.uuid,
        operationUuid: row.operation,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        deleted: row.deleted,
      );
      if (qso.isEvent || !request.includes(qso)) continue;
      final value = _serialOn(qso, request);
      if (value != null && (highest == null || value > highest)) highest = value;
    }
    if (debugAfterScan != null) await debugAfterScan!();
    // Someone invalidated while this scan was in flight — the rows above are
    // the pre-invalidation log, so answer with them but do NOT memoize them.
    if (generation == _generation) _derived[cacheKey] = highest;
    return highest;
  }

  int? _serialOn(Qso qso, SequenceRequest request) {
    for (final ref in qso.refs) {
      if (ref['type'] != request.refType) continue;
      final raw = ref[request.field];
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw.trim());
      if (raw is num) return raw.toInt();
    }
    return null;
  }

  /// The stored counter wins only when it is AHEAD of the log — a counter that
  /// ran past deleted numbers is correct and must not be pulled back down.
  int _resolve(SequenceRow? stored, int? derived, int start) {
    final fromLog = derived == null ? start : derived + 1;
    final fromStore = stored?.nextValue;
    if (fromStore == null) return fromLog;
    return fromStore > fromLog ? fromStore : fromLog;
  }
}
