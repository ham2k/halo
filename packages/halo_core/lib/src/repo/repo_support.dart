// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the repositories in this directory share: the encode-on-write
// chokepoint, the row decoders, and the inbound-staleness rule. Not exported
// from the package — these are the repositories' own helpers.
//
// The contract every repository here keeps: repositories are the only
// writers to the database. Every write keeps the indexed columns derived
// from the JSON `data`, marks rows dirty for sync (`synced = false`), and
// maintains the operation's cached counters. Reads for the UI are reactive
// drift streams — the database is the source of truth and, later, the
// multi-window bus (DESIGN.md §8).

import 'dart:convert';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../app_clock.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../models/qson_values.dart';

/// Encodes a QSO's QSON for storage, normalizing wrong-typed fields on the
/// way — see [normalizeQsoQson]. Storage is the one chokepoint every write
/// path already passes through, and normalizing here is what lets a bad
/// value heal instead of being handed to the next reader: the getters coerce
/// on read, but only a write puts the corrected value back.
///
/// The indexed columns are derived from these same fields, so normalizing
/// here is also what keeps a record from aborting the transaction that
/// writes it: without it, a `bool` mode throws out of `_companionFor`,
/// rolls back the whole `mergeFromSync` round, and the server serves the
/// identical record again next round, forever.
@internal
String encodeQsoData(Map<String, dynamic> data, String context) => jsonEncode(_normalizedReporting(data, normalizeQsoQson, context));

/// [encodeQsoData] for an operation.
@internal
String encodeOperationData(Map<String, dynamic> data, String context) => jsonEncode(_normalizedReporting(data, normalizeOperationQson, context));

Map<String, dynamic> _normalizedReporting(
  Map<String, dynamic> data,
  Map<String, dynamic> Function(Map<String, dynamic>, {List<QsonTypeViolation>? violations}) normalize,
  String context,
) {
  final violations = <QsonTypeViolation>[];
  final normalized = normalize(data, violations: violations);
  for (final violation in violations) {
    onQsonTypeViolation?.call(context, violation);
  }
  return normalized;
}

/// Whether an inbound sync record should be skipped in favor of the local
/// row it would overwrite. Both sides carry a revision stamp
/// (`updatedAtMillis`, written on every local edit and round-tripped through
/// the server inside the record's JSON): when both stamps exist, the inbound
/// record only wins if it is strictly newer — same rule as app-polo's
/// `mergeSyncQSOs`. Without unconditional-overwrite protection here, a pull
/// racing a local edit (or a "combine" backfill pulling this device's own
/// older copies back down) silently reverts local changes and marks them
/// synced. When the inbound record has no stamp (pre-stamp history), only
/// local rows with unpushed edits (`synced == false`) are protected; clean
/// rows accept it.
/// Rewrites app-polo's older `*OnMillis` spellings to the `*AtMillis` ones
/// this app reads, in place, the way polo's own `operationsDB.js` does on
/// read. Inbound sync can carry either, and the merge below compares
/// revisions BEFORE anything goes through the model's getters — so without
/// this a legacy record looks revision-less and loses every comparison.
@internal
void normalizeLegacyStamps(Map<String, dynamic> data) {
  for (final (legacy, current) in const [('createdOnMillis', 'createdAtMillis'), ('updatedOnMillis', 'updatedAtMillis')]) {
    final value = data.remove(legacy);
    if (value != null) data.putIfAbsent(current, () => value);
  }
}

@internal
bool inboundIsStale({required int? existingUpdatedAtMillis, required bool existingSynced, required int? incomingUpdatedAtMillis}) {
  if (existingUpdatedAtMillis != null && incomingUpdatedAtMillis != null) {
    return existingUpdatedAtMillis >= incomingUpdatedAtMillis;
  }
  return incomingUpdatedAtMillis == null && !existingSynced;
}

/// Whether a record [inboundIsStale] just rejected still has one thing to say
/// that the local row got wrong: the row is a tombstone this device
/// resurrected, and the record is the tombstone itself coming back.
///
/// The signature is a row holding the sender's own revision — same stamp,
/// nothing local pending — that nonetheless calls live a record the sender
/// calls deleted. Two things produce it, and the flag alone (never the stale
/// record's `data`) settles both:
///
///  - LoFi's own delete endpoint tombstones an operation WITHOUT touching its
///    `updatedAtMillis`, so the tombstone it hands back ties with the live
///    copy every device already holds. Without this, deleting an operation
///    from the web reaches no device that has the operation — ever.
///  - A `deleted` flag read in a dialect this app did not understand (see
///    [asQsonBool]) dropped a tombstone while storing the record's own stamp.
///    Nothing local can repair that row: `deleted` is removed from the record
///    before the blob is encoded, so it keeps no trace of what it was told,
///    and every later delivery of the correcting record ties and is skipped.
///
/// A tie, not merely stale: a strictly OLDER tombstone against a newer local
/// row describes a revision the operator made after the delete and has
/// already pushed — the server holds that revision too, so re-deleting here
/// would undo an edit rather than repair one.
@internal
bool inboundRepairsTombstone({
  required bool existingDeleted,
  required bool existingSynced,
  required int? existingUpdatedAtMillis,
  required bool incomingDeleted,
  required int? incomingUpdatedAtMillis,
}) => incomingDeleted && !existingDeleted && existingSynced && existingUpdatedAtMillis != null && existingUpdatedAtMillis == incomingUpdatedAtMillis;

/// Normalizing here, not only in [encodeQsoData], is what reaches a record
/// that was already stored: the writers cannot heal a row nothing writes to.
/// It also settles what the rest of the app is handed, because `data` is the
/// map itself — `SyncEngine._buildPayload` and `ExportService` both spread
/// it, so without this an export's ADIF hook reads the raw wrong-typed value
/// while the QSO list beside it shows the coerced one, and a push carries
/// the bad value back out to every other device.
///
/// The scan costs about 2.5µs against `jsonDecode`'s 3.4µs on a typical QSO,
/// and returns the same map untouched when there is nothing to fix — which
/// is every row but the rare bad one.
///
/// Reporting what it heals is not optional here: healing a stored record
/// hands the write path a clean map, so an operator editing that record
/// would otherwise stop reporting it too — losing the signal rather than
/// merely declining to add one. [violations] carries what was found back to
/// a caller that can report it.
///
/// `jsonDecode(...) as Map` is deliberately still a cast: a blob that is not
/// a JSON object is a corrupt row, not a wrong-typed field, and coercing it
/// would swallow real database corruption.
@internal
Qso qsoFromRow(QsoRow row, {List<QsonTypeViolation>? violations}) => Qso(
  uuid: row.uuid,
  operationUuid: row.operation,
  data: normalizeQsoQson(jsonDecode(row.data) as Map<String, dynamic>, violations: violations),
  deleted: row.deleted,
  purged: row.purged,
  scoreCache: row.scoreCache,
);

/// How many violations one decode batch carries back. A log with thousands
/// of bad rows would otherwise build a list the size of the damage and hand
/// every entry to the reporter, when the question being answered — WHICH
/// fields arrive wrong-typed — is settled by the first few. Sampling here
/// rather than at the reporter keeps the cost off the isolate hop too.
const _readViolationSampleLimit = 16;

/// The rows plus what healing them found, because a violation cannot report
/// itself from inside an isolate: `onQsonTypeViolation` is a top-level
/// global, so it is null in a spawned isolate and a report there would
/// simply vanish. Carrying them back as DATA is what keeps coverage uniform
/// — reporting in place would fire for small batches and silently not for
/// large ones, which reads as sampling rather than as a hole.
class _DecodedQsos {
  const _DecodedQsos(this.qsos, this.violations);
  final List<Qso> qsos;
  final List<QsonTypeViolation> violations;
}

_DecodedQsos _decodeQsos(List<QsoRow> rows) {
  final violations = <QsonTypeViolation>[];
  final qsos = [for (final row in rows) qsoFromRow(row, violations: violations.length < _readViolationSampleLimit ? violations : null)];
  return _DecodedQsos(qsos, violations);
}

/// Below this, decoding inline is cheaper than an isolate's spawn cost;
/// above it, [qsoFromRow]'s per-row `jsonDecode` is real enough CPU work
/// (not the framework's usual sub-millisecond synchronous calls) that
/// running it on the UI isolate blocks that isolate's frame pump for long
/// enough to read as a stall rather than a stutter — moving it off-isolate
/// trades a slightly later result for a UI thread that stays free to
/// animate the transition while it waits.
@internal
const qsoRowDecodeIsolateThreshold = 200;

/// SQLite's default bound-variable limit is 999. `historyForCalls`'s query
/// binds a few more params alongside the `IN` clause itself (the `deleted`/
/// `uuid.isNull()` checks), so this stays under that with room to spare
/// rather than pushing all the way to 999. As large as it safely can,
/// though, not just "safe": each chunk is a full query+decode round trip,
/// and a re-import whose `theirCall`s mostly already exist pays for a much
/// bigger result set per chunk than a fresh one does, so fewer, larger
/// chunks matter more here than for a fresh import's near-empty results.
@internal
const inClauseChunkSize = 900;

/// Reports on THIS isolate whatever the decode healed, wherever it ran —
/// see [_DecodedQsos] for why the violations travel as data.
List<Qso> _reportedQsos(_DecodedQsos decoded) {
  for (final violation in decoded.violations) {
    onQsonTypeViolation?.call('qsos:read', violation);
  }
  return decoded.qsos;
}

@internal
Future<List<Qso>> qsosFromRows(List<QsoRow> rows) async {
  if (rows.length < qsoRowDecodeIsolateThreshold) return _reportedQsos(_decodeQsos(rows));
  try {
    return _reportedQsos(await Isolate.run(() => _decodeQsos(rows)));
  } catch (_) {
    // Isolate.spawn doesn't exist on web (dart2js/DDC) — halo_core is pure
    // Dart with no Flutter dependency, so there's no `kIsWeb` to branch on
    // up front — and any other isolate-infrastructure failure (spawn
    // refused under memory pressure, etc.) deserves the same recovery:
    // `watchForOperation`'s callers `.listen()` this without an `onError`,
    // so an error here would otherwise silently kill live rescoring instead
    // of just costing a slower decode. A genuinely malformed row still
    // throws the same way it did before this existed — inline decoding
    // doesn't change what a bad row does, only where a healthy one runs.
    return _reportedQsos(_decodeQsos(rows));
  }
}

/// Runs after a local write that changes what an operation's log SAYS — a
/// contact added, edited or deleted. The lifecycle follows the log through it
/// (`OperationsRepository.followContact`); a null hook simply leaves the
/// status alone, which is what every test and non-app host wants. Sync- and
/// peer-received revisions never reach it: they carry their own status.
///
/// Event rows are excluded at every call site — a `start` or `stop` marker IS
/// a lifecycle transition being written, and feeding it back in would have the
/// transition fight itself.
///
/// [bulk] marks contacts written by [QsosRepository.writeBatch] — an import or
/// a paste, not the operator logging at the radio — with [atMillis] the
/// newest of their own times.
typedef LocalContactHook = Future<void> Function(String operationUuid, {required bool isNewContact, int? atMillis, bool bulk});

/// What a [QsosRepository.writeBatch] has to tell the lifecycle about itself:
/// whether it added a contact, and the newest contact time it wrote.
///
/// Called ONCE per batch, not once per record: an import of three thousand
/// contacts owes the lifecycle one transition, and the hook's own work is per
/// operation anyway. Without it the whole bulk path — ADIF import, paste, bulk
/// edits, a segment's station-call restamp — is invisible to the lifecycle: an
/// operation filled entirely by an import would sit at `new` with three
/// thousand contacts in it, and a re-import over a processed log would never
/// report that the upload went stale. An insert anywhere in the batch makes it
/// a new contact; a batch of pure updates is an edit, and the mix cannot
/// happen the other way round — adding contacts is what reopens a log, and it
/// outranks a revert made in the same breath.
///
/// Null when the batch touched no contact at all — a batch of `break` markers
/// is not a contact, and treating one as an edit would revert a processed
/// operation on a write that changed no contact. Event rows are excluded here
/// as they are at every other call site.
///
/// The time comes from the RECORDS, not from the operation's counters: a large
/// import chunks itself and passes `refreshCounters: false` until the last
/// chunk, so the column still holds whatever it held before the import while
/// the first chunks are landing. Reading it there would stamp a year-old log
/// as active right now.
({bool inserted, int newestMillis})? summarizeBatchForLifecycle(List<Map<String, dynamic>> inserts, List<Qso> updates) {
  var sawContact = false;
  var inserted = false;
  var newest = 0;
  void note(Map<String, dynamic> data, {required bool isInsert}) {
    if (asQsonString(data['band']) == 'event') return; // Qso.isEvent
    sawContact = true;
    if (isInsert) inserted = true;
    // The same fallback the stored row takes: a record with no time of its own
    // is written at `now`, so that is what it contributes here. Reading the
    // absence as "nothing to report" would let a batch of them leave the stamp
    // on whatever the column happened to hold.
    final at = asQsonNum(data['startAtMillis'])?.toInt() ?? nowMillis();
    if (at > newest) newest = at;
  }

  for (final data in inserts) {
    note(data, isInsert: true);
  }
  for (final qso in updates) {
    note(qso.data, isInsert: false);
  }
  return sawContact ? (inserted: inserted, newestMillis: newest) : null;
}
