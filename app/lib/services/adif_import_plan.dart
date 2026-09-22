// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Turning a parsed ADIF file into "here is what would happen", so the operator
// can look before anything is written.
//
// Merging rewrites contacts that were already correct, which is materially
// harder to undo than an append — so planning and committing are two steps,
// and the plan holds enough to describe itself.

import 'package:collection/collection.dart';
import 'package:halo_core/halo_core.dart';

/// What importing a file would do to one operation.
class AdifImportPlan {
  final String filename;

  /// QSON for contacts not already in the operation, in the order the parser
  /// handed them over — which is by time, not by position in the file
  /// (`AdifLog.qsos` is sorted).
  final List<Map<String, dynamic>> additions;

  /// Existing contacts with the file's data merged in, ready for
  /// `QsosRepository.writeBatch`. At most one entry per existing record — see
  /// [planAdifImport] on why that matters.
  final List<Qso> merges;

  /// The plan-time snapshot each merge was folded from, by uuid — handed to
  /// `writeBatch` as `updateBases` so a row that moves while the confirm
  /// dialog sits open (a sync pull, an edit) is re-merged against its
  /// current state instead of being overwritten with this stale fold.
  final Map<String, Qso> mergeBases;

  /// How many existing contacts the file matched at least one record
  /// against — including ones [merges] leaves out because folding in the
  /// file's data changed nothing. A re-import of an unchanged file matches
  /// every record and merges none of them, so this is the only count that
  /// tells the operator "this file is already in your log" rather than
  /// reading as though nothing in it was recognized at all.
  final int alreadyLoggedCount;

  /// Records the parser could not accept as contacts: no callsign. Not
  /// imported.
  final List<AdifRecord> unusable;

  /// Records refused here for having no usable date. Not imported, and kept
  /// APART from [unusable] because the operator is told why — being told
  /// "no callsign" about a record whose callsign is fine sends them looking
  /// for the wrong defect.
  ///
  /// Refused rather than stamped with the time of import: a fabricated
  /// timestamp is wrong data that looks right — it sorts among the wrong
  /// contacts, and because it can never match on a later run it duplicates on
  /// every re-import.
  final List<AdifRecord> undated;

  /// Imported records carrying something the operator should know — a field
  /// length the parser could not make sense of. A record with no usable
  /// timestamp is not here: it is refused outright, in [undated].
  final List<AdifRecord> flagged;

  /// Extension keys whose reference pass failed, plus `'*'` for a whole
  /// crossing that never reached the runtime. Empty on a clean run.
  final Set<String> failedHooks;

  /// Records in a batch that never reached the runtime. No hook ran for them,
  /// so nothing could have been recovered — the one case that supports an
  /// unhedged claim.
  final int recordsUnreachable;

  /// Records in a batch where a NAMED hook failed.
  ///
  /// NOT "records missing references": batches are 500 records and this counts
  /// the WHOLE batch whenever any one hook in it fails, so a single broken
  /// award extension puts every contact of that batch here — including the
  /// ones whose references its other hooks supplied in full. An upper bound on
  /// the damage, and the summary has to word it as one.
  final int recordsWithFailedHooks;

  /// Whether this plan can lose a reference: the stacking ref types could not
  /// be read from the extensions, AND something actually folds.
  ///
  /// A fold stacks only the types named in `multiRefTypes` and keeps ONE of
  /// anything else, so an unknown set is not a neutral default — it drops the
  /// second park off a park-to-park contact. Both fold sites count: folding
  /// into a logged contact produces a merge, folding two file records
  /// together produces an ADDITION, and gating on `merges` alone would stay
  /// silent through the second — which is the shape a one-QSO-per-park export
  /// arrives in.
  final bool mayDropReferences;

  /// Whether any batch never reached the runtime. `'*'` is the service's
  /// sentinel for it.
  bool get refsUnavailable => failedHooks.contains('*');

  /// Station callsigns the file recorded that are NOT the operation's, in the
  /// order first seen. Every one of them will be imported as the operation's
  /// station — which is a thing to say loudly, not a detail.
  final List<String> foreignStations;

  /// The call every imported contact will carry. Null when the importer is
  /// leaving the file's own calls alone.
  final String? stationCall;

  /// References lifted off the contacts because in QSON they describe the
  /// OPERATION — an activation is written onto every ADIF record because ADIF
  /// has nowhere else to put it. The `adifImport` hook tags each reference as
  /// it reads it (`Ref.for`), so nothing here has to guess.
  ///
  /// **Reported, not applied.** Importing into an existing operation leaves
  /// that operation's own activity setup alone: the operator chose it, and a
  /// file dropped in later does not get to redefine what the operation was.
  /// An importer that CREATES an operation from a file is the one that should
  /// use these.
  final List<Map<String, dynamic>> hoistedOperationRefs;

  const AdifImportPlan({
    required this.filename,
    this.additions = const [],
    this.merges = const [],
    this.mergeBases = const {},
    this.alreadyLoggedCount = 0,
    this.unusable = const [],
    this.undated = const [],
    this.flagged = const [],
    this.failedHooks = const {},
    this.recordsUnreachable = 0,
    this.recordsWithFailedHooks = 0,
    this.mayDropReferences = false,
    this.foreignStations = const [],
    this.stationCall,
    this.hoistedOperationRefs = const [],
  });

  int get importCount => additions.length + merges.length;

  /// Everything the file offered that will not be written.
  int get refusedCount => unusable.length + undated.length;

  /// Whether there is anything to write. A file of nothing but unusable
  /// records still produces a plan — the operator needs to be told why.
  bool get isEmpty => importCount == 0;
}

/// Works out what [records] would do to [existing], without writing anything.
///
/// [existing] must be the operation's LIVE contacts —
/// `QsosRepository.watchForOperation` excludes soft-deleted rows, which is
/// what keeps a merge from landing inside a tombstone where the operator would
/// never see it.
///
/// [multiRefTypes] are the ref types the extensions declare as stacking; it is
/// passed straight to [mergeQsos].
///
/// **Every match is made against the ORIGINAL records, never a partly-merged
/// one.** Merging widens a contact's start time backwards while the match
/// window stays five minutes, so folding pairwise as it goes would make the
/// result depend on the order records happen to be visited: A@12:00 merged
/// with B@12:04 anchors at 12:00, and C@12:08 — which B would have matched —
/// no longer does.
///
/// At most one merge is produced per existing contact. Two records of one
/// contact in the same file both match the same log entry, and
/// `writeBatch` refuses a batch that names a row twice — rightly, since the
/// second update would discard the first's merge.
AdifImportPlan planAdifImport({
  required String filename,
  required List<AdifRecord> records,
  required List<Qso> existing,
  Set<String> multiRefTypes = const {},
  Set<String> failedHooks = const {},
  int recordsUnreachable = 0,
  int recordsWithFailedHooks = 0,
  bool stackingTypesUnknown = false,
  List<AdifRecord> unusable = const [],
  String? stationCall,
}) {
  // Split before anything else: a dateless record is not importable, and
  // `writeBatch` would otherwise stamp it with the time of import.
  final datable = <AdifRecord>[];
  final undated = <AdifRecord>[];
  for (final record in records) {
    // Read through the same coercion the merge and the write use. Testing for
    // `null` alone would pass a record carrying '' or 'unknown', which then
    // matches nothing and gets stamped with the time of import — the exact
    // outcome refusing it exists to prevent.
    if (qsoStartMillis(record.qso) == null) {
      undated.add(record);
    } else {
      datable.add(record);
    }
  }
  records = datable;

  final flagged = [
    for (final record in records)
      if (record.problems.isNotEmpty) record,
  ];

  // Rewritten up front rather than at each merge, so matching, folding and the
  // records finally written all see the same station.
  final restationed = stationCall == null
      ? records
      : [
          for (final record in records)
            AdifRecord(number: record.number, fields: record.fields, qso: qsoForStation(record.qso, stationCall), problems: record.problems),
        ];

  // Before matching, so an operation-level reference is never carried onto an
  // existing contact by a merge.
  final hoisted = hoistOperationRefs([for (final r in restationed) r.qso]);
  final incoming = [
    for (var i = 0; i < restationed.length; i++)
      AdifRecord(number: restationed[i].number, fields: restationed[i].fields, qso: hoisted.qsos[i], problems: restationed[i].problems),
  ];

  // Bucketed by callsign, which is the first and most selective thing a match
  // tests. A linear scan per record is O(records x existing) with six string
  // allocations per comparison — a 3,000-contact file into a 3,000-QSO
  // operation is millions of comparisons, synchronous, on the UI isolate, with
  // the window frozen and no way to cancel.
  final existingByCall = <String, List<Qso>>{};
  for (final qso in existing) {
    final call = _callKey(qso.data);
    if (call != null) existingByCall.putIfAbsent(call, () => []).add(qso);
  }
  final byUuid = {for (final qso in existing) qso.uuid: qso};

  // Existing contact uuid -> the file's records that belong to it.
  final byExisting = <String, List<Map<String, dynamic>>>{};
  // Records matching nothing in the log, each with the file records folded
  // into it. Keyed by the FIRST record of the group, which is what stops the
  // anchor from drifting as a group grows.
  final fresh = <_FreshGroup>[];
  final freshByCall = <String, List<_FreshGroup>>{};
  // Whether ANY fold ran — into an existing contact or between two file
  // records. `merges` covers only the first, and both drop a ref when the
  // stacking types are unknown, so `merges` is the wrong thing to warn on.
  var foldedAny = false;

  for (final record in incoming) {
    final call = _callKey(record.qso);
    // NEAREST in time, not first in log order. A log holding two real contacts
    // with one station four minutes apart would otherwise fold BOTH file
    // records into the first row — the second is still inside the window, and
    // list order reaches it first — welding two distinct contacts together and
    // leaving the other row untouched.
    //
    // Claimed rows deliberately stay in the running: two file records CAN
    // belong to one logged contact, and excluding a claimed row would send the
    // second off to become a spurious addition.
    final match = _nearest(existingByCall[call] ?? const <Qso>[], record.qso, (qso) => qso.data, stationCall);
    if (match != null) {
      byExisting.putIfAbsent(match.uuid, () => []).add(record.qso);
      continue;
    }
    final candidates = call == null ? const <_FreshGroup>[] : (freshByCall[call] ?? const <_FreshGroup>[]);
    final group = _nearest(candidates, record.qso, (g) => g.anchor, stationCall);
    if (group != null) {
      // A fold between two FILE records, which becomes an addition rather
      // than a merge — and drops a ref just as readily, so it counts.
      foldedAny = true;
      group.folded = mergeQsos(group.folded, record.qso, multiRefTypes: multiRefTypes, stationCall: stationCall);
    } else {
      final created = _FreshGroup(record.qso);
      fresh.add(created);
      if (call != null) freshByCall.putIfAbsent(call, () => []).add(created);
    }
  }

  final merges = <Qso>[];
  final mergeBases = <String, Qso>{};
  // The targets as they are TODAY. The merged records already carry the
  // imposed station call, so they cannot answer "whose call is about to
  // change".
  final targetsBefore = <Map<String, dynamic>>[];
  for (final entry in byExisting.entries) {
    final target = byUuid[entry.key]!;
    targetsBefore.add(target.data);
    var data = target.data;
    // In the order the parser handed them over — by time — each later record
    // taking precedence over what came before, the same rule that governs the
    // file against the log.
    for (final record in entry.value) {
      foldedAny = true;
      data = mergeQsos(data, record, multiRefTypes: multiRefTypes, stationCall: stationCall);
    }
    // A merge that changes nothing is not a merge. `writeBatch` re-stamps
    // `updatedAtMillis` and clears `synced`, so emitting one would push a
    // whole re-imported operation back through sync and make every other
    // device see those contacts as newer revisions — for a write with no
    // content.
    if (const DeepCollectionEquality().equals(data, target.data)) continue;
    merges.add(Qso(uuid: target.uuid, operationUuid: target.operationUuid, data: data, deleted: target.deleted, scoreCache: target.scoreCache));
    mergeBases[target.uuid] = target;
  }

  // After matching, and over the merge TARGETS rather than the whole log:
  // merging applies the imposed call to the merged record, so a logged contact
  // is rewritten only if something merges into it. Scanning all of `existing`
  // would warn about contacts nothing is going to touch.
  final foreign = stationCall == null ? const <String>[] : foreignStationCalls([for (final r in records) r.qso, ...targetsBefore], stationCall);

  return AdifImportPlan(
    filename: filename,
    additions: [for (final group in fresh) group.folded],
    merges: merges,
    mergeBases: mergeBases,
    alreadyLoggedCount: byExisting.length,
    unusable: unusable,
    undated: undated,
    flagged: flagged,
    failedHooks: failedHooks,
    recordsUnreachable: recordsUnreachable,
    recordsWithFailedHooks: recordsWithFailedHooks,
    mayDropReferences: stackingTypesUnknown && foldedAny,
    foreignStations: foreign,
    stationCall: stationCall,
    hoistedOperationRefs: hoisted.operationRefs,
  );
}

/// The candidate whose start time is closest to [record]'s, among those that
/// match it at all.
///
/// "First that matches" is not the same question: inside a five-minute window
/// several contacts can qualify, and taking whichever the list happens to
/// reach first welds the wrong pair together.
T? _nearest<T>(Iterable<T> candidates, Map<String, dynamic> record, Map<String, dynamic> Function(T) dataOf, String? stationCall) {
  final at = qsoStartMillis(record);
  T? best;
  int? bestGap;
  for (final candidate in candidates) {
    final data = dataOf(candidate);
    if (!qsosAreSameContact(data, record, stationCall: stationCall)) continue;
    final other = qsoStartMillis(data);
    if (at == null || other == null) return candidate;
    final gap = (at - other).abs();
    if (bestGap == null || gap < bestGap) {
      best = candidate;
      bestGap = gap;
    }
  }
  return best;
}

/// The bucket key: the other station's callsign, normalized the way
/// [qsosAreSameContact] normalizes it. A record with no callsign matches
/// nothing anyway, so it needs no bucket.
String? _callKey(Map<String, dynamic> qso) {
  // Coerced loosely, like every other reader here: a record whose `their.call`
  // is not a string — synced from another client, or written by an extension —
  // should simply not match, not throw and fail the whole import.
  final their = qso['their'];
  final raw = their is Map ? their['call'] : null;
  if (raw is! String) return null;
  final call = raw.trim().toUpperCase();
  return call.isEmpty ? null : call;
}

/// A contact the log doesn't have yet, plus whatever else in the file turned
/// out to be the same contact.
class _FreshGroup {
  /// The first record of the group, kept unchanged so later records are
  /// matched against where the contact actually started rather than against a
  /// merged time that keeps sliding earlier.
  final Map<String, dynamic> anchor;
  Map<String, dynamic> folded;

  _FreshGroup(this.anchor) : folded = anchor;
}
