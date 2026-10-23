// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a sync round puts on the wire, and how it reads what comes back: the
// request payload, and the server's cursors, refusals and unreadable-entry
// counts. The round itself — what to send, and what the reply moves — is
// `SyncEngine.runOneRound` and `_processResponseMeta`.

part of 'sync_engine.dart';

extension _Wire on SyncEngine {
  /// The server's count of entries it could not read in what this device
  /// sent. Reported once per session per side and count: the records behind it
  /// are marked sent like any other, because nothing here says which they
  /// were, so this line is the only trace they existed.
  void _reportUnreadable(Map<String, dynamic> response, String side) {
    final errors = response['errors'];
    if (errors is! Map) return;
    final forSide = errors[side];
    if (forSide is! Map) return;
    final entries = forSide['_malformed'];
    if (entries is! List) return;
    var count = 0;
    for (final entry in entries) {
      if (entry is Map) count += (entry['count'] as num?)?.toInt() ?? 0;
    }
    if (count == 0) return;
    log?.call('[sync] server could not read $count $side this device sent');
    if (!_reportedRejections.add('$side:_malformed:$count')) return;
    onError?.call(SyncPayloadUnreadable(side, count), null, context: 'sync:unreadable:$side');
  }

  /// Console and crash reporting, never the operator: "the server refused
  /// this QSO" names nothing they can do about it, and a notice that cannot
  /// be answered is worse than none. `onError` carries it so `ErrorPolicy`
  /// decides its disposition in the one place that decision is made.
  void _reportRejections(Map<String, String> rejected, String side) {
    if (rejected.isEmpty) return;
    final summary = rejected.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    // The log takes every round's refusals: a developer watching the console
    // is watching it live, and silence there would hide a loop.
    log?.call('[sync] server refused ${rejected.length} $side (left dirty): $summary');
    // The crash backend takes each one ONCE. A refused record stays dirty by
    // design, so it is re-sent and re-refused every round for as long as the
    // app runs — reporting each time would upload thousands of copies of one
    // fact. Keyed by reason as well as uuid, so a record whose refusal
    // CHANGES (a permission granted, a different validation failing) is heard
    // again.
    final fresh = {
      for (final entry in rejected.entries)
        if (_reportedRejections.add('$side:${entry.key}:${entry.value}')) entry.key: entry.value,
    };
    if (fresh.isEmpty) return;
    onError?.call(SyncRecordsRejected(side, fresh), null, context: 'sync:rejected:$side');
  }

  Future<Map<String, dynamic>> _buildPayload(SyncBatch batch, {required bool pull, required bool backfilling, required int limit}) async {
    final operationCounts = await operations.syncCounts();
    final qsoCounts = await qsos.syncCounts();
    final state = settings.state;
    // Real, not travelled: this value LEAVES the app as `syncedUntilMillis`
    // whenever the state carries no cursor yet (a fresh link, or right after a
    // forced resync), where the server pages backwards from it. See
    // realNowMillis's contract — "values compared against someone else's clock".
    //
    // Travel bars every round, so the only way a travelled value could get here
    // is a round that passed `_mayRun` and was still assembling when travel
    // started. Narrow, and this costs nothing to close.
    final backfillFrom = realNowMillis();

    return {
      if (batch.operations.isNotEmpty)
        'operations': [
          for (final o in batch.operations) {...o.data, 'uuid': o.uuid, if (o.deleted) 'deleted': true, if (o.purged) 'purged': true},
        ],
      if (batch.qsos.isNotEmpty)
        'qsos': [
          for (final q in batch.qsos)
            {
              ...q.data,
              'uuid': q.uuid,
              // `null`, never the local `''`, for a contact that belongs to no
              // operation (an ADIF import into the general log). Null is the
              // server's own shape for one: it drops a null operation from a
              // batch's lookup list, while `''` is taken for a uuid it has
              // never seen and sends it down the create-the-missing-operation
              // path — which then fails that operation's `uuid` presence
              // validation. The contact still lands (the failed parent leaves
              // the foreign key null rather than aborting the write), so this
              // is contract rather than repair, but every batch of loose
              // contacts otherwise costs a doomed write it never reports.
              'operation': q.operationUuid.isEmpty ? null : q.operationUuid,
              if (q.deleted) 'deleted': true,
              if (q.purged) 'purged': true,
            },
        ],
      if (batch.claims.isNotEmpty) 'claims': [for (final c in batch.claims) c.toRecord()],
      'meta': {
        'operationCount': operationCounts.total,
        'unsyncedOperationCount': operationCounts.pending,
        'qsoCount': qsoCounts.total,
        'unsyncedQSOCount': qsoCounts.pending,
        if (state['lastSyncAccountUUID'] != null) 'lastSyncAccountUUID': state['lastSyncAccountUUID'],
        // Only the periodic loop pulls — a small-batch round is a reaction
        // to a local write and doesn't need to ask "what's new" every time.
        // `inboundSync: true` is what actually gets the server to include
        // any operations/qsos in its response at all — `sync` below is just
        // the window/pagination details for it. Missing this flag (an easy
        // thing to miss porting from sync.js, since it's set right next to
        // `meta.sync` but is a separate field) silently gets an
        // account-info-only response back, no error, nothing to pull ever.
        // Backfill pages backward from `earliest.../now` with `anyClient:
        // true` (the account's whole history, any device); forward mode
        // asks only `syncedSinceMillis`/`anyClient: false` (this client's
        // own recent changes) once backfill has caught everything up.
        if (pull) 'inboundSync': true,
        if (pull)
          'sync': {
            ...backfilling
                ? {
                    'operations': {
                      'syncedUntilMillis': (state['earliestOperationSyncedAtMillis'] as num?)?.toInt() ?? backfillFrom,
                      if (state[SyncEngine.backfillCursorKeys['operations']!] != null) 'cursor': state[SyncEngine.backfillCursorKeys['operations']!],
                      'limit': limit,
                      'anyClient': true,
                    },
                    'qsos': {
                      'syncedUntilMillis': (state['earliestQSOSyncedAtMillis'] as num?)?.toInt() ?? backfillFrom,
                      if (state[SyncEngine.backfillCursorKeys['qsos']!] != null) 'cursor': state[SyncEngine.backfillCursorKeys['qsos']!],
                      'limit': limit,
                      'anyClient': true,
                    },
                  }
                : {
                    'operations': {
                      'syncedSinceMillis': (state['latestOperationSyncedAtMillis'] as num?)?.toInt() ?? 0,
                      if (state[SyncEngine.forwardCursorKeys['operations']!] != null) 'cursor': state[SyncEngine.forwardCursorKeys['operations']!],
                      'limit': limit,
                      'anyClient': false,
                    },
                    'qsos': {
                      'syncedSinceMillis': (state['latestQSOSyncedAtMillis'] as num?)?.toInt() ?? 0,
                      if (state[SyncEngine.forwardCursorKeys['qsos']!] != null) 'cursor': state[SyncEngine.forwardCursorKeys['qsos']!],
                      'limit': limit,
                      'anyClient': false,
                    },
                  },
            if (_claimsOn) 'claims': _claimsWindow(state, limit),
          },
      },
    };
  }
}

/// The server's row cursor for one side, or null.
///
/// Both spellings, like every other server-supplied key the engine reads (see sync_engine.dart's
/// `_processResponseMeta` knobs and `sideDone` counts): reading only one would leave a client that
/// gets the other on the millisecond path with no signal — which is the stall this cursor exists to
/// fix, failing silently. Type-tolerant for the same reason a throw here is worse than a miss: it
/// would land after the merge but before the state write, losing the round's cursor AND watermark
/// and re-pulling the identical page every round forever.
String? _cursorFrom(Map<String, dynamic> meta, String side) {
  final value = (meta[side] as Map?)?['next_cursor'] ?? (meta[side] as Map?)?['nextCursor'];
  return value is String && value.isNotEmpty ? value : null;
}

/// Keys inside `errors[<side>]` that are NOT a record uuid.
///
/// `pagination` is the cursor refusal [_cursorRefused] reads, and
/// `_malformed` is the server's count of payload entries it could not read
/// at all (never a uuid, because the entries it names had none it could
/// trust). Treating either as a rejected record would hold a row dirty
/// forever against a uuid nothing will ever match.
const _nonRecordErrorKeys = {'pagination', '_malformed'};

/// Which records of [side] the server refused, uuid to its reported reason.
///
/// Every hop is checked rather than cast, for the reason [_cursorFrom]
/// gives: this runs before the state write, so a `TypeError` on an error
/// block shaped differently than expected would cost the round its cursor
/// AND its watermark, and then throw again on the identical page every
/// round after.
Map<String, String> _rejectedUuids(Map<String, dynamic> response, String side) {
  final errors = response['errors'];
  if (errors is! Map) return const {};
  final forSide = errors[side];
  if (forSide is! Map) return const {};
  final rejected = <String, String>{};
  for (final entry in forSide.entries) {
    final key = entry.key;
    if (key is! String || _nonRecordErrorKeys.contains(key)) continue;
    rejected[key] = _describeRejection(entry.value);
  }
  return rejected;
}

/// The only keys whose VALUE may travel: they name the error, never the
/// record. An allowlist rather than a denylist because this string leaves
/// the device — Rails' `errors.details` is `{field: [{error: :symbol, ...}]}`
/// and several stock validators merge the offending value into those
/// options (`:taken` carries `value:`, `:inclusion` likewise), so anything
/// not named here is assumed to be the operator's own data.
const _rejectionReasonKeys = {'error', 'type'};

/// A rejection reason flattened to one short line for the log and the crash
/// report. Keeps the server's error names and the FIELD names it attached
/// them to; never a field's contents, which are callsigns, names and notes.
String _describeRejection(Object? detail) {
  final reasons = <String>{};
  void walk(Object? node) {
    if (node is List) {
      for (final item in node) {
        walk(item);
      }
    } else if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key;
        if (key is String && _rejectionReasonKeys.contains(key)) {
          reasons.add('${entry.value}');
          continue;
        }
        // The key names a field of the record; its value is that field's
        // content and must not be added, only descended into.
        reasons.add('$key');
        walk(entry.value);
      }
    }
  }

  // A scalar detail IS the reason — the server naming it directly rather
  // than in Rails' `{field: [{error: ...}]}` shape. Taken before the walk,
  // which only descends collections: without this it yields nothing, and
  // every distinct reason for one record would collapse onto the same
  // 'refused' dedupe key, so a refusal that CHANGED would never be heard.
  if (detail is String) return detail;
  walk(detail);
  return reasons.isEmpty ? 'refused' : reasons.join(', ');
}

/// True when the server refused the cursor we sent for [side] (malformed, or minted for a
/// different window — see LoFi's `decode_pagination_cursor`). It answers on the millisecond
/// window instead, so the round is still useful; what must not happen is holding the refused
/// cursor and re-sending it forever.
bool _cursorRefused(Map<String, dynamic> response, String side) {
  // Every hop is checked rather than cast: this runs after the merge and before the state
  // write, so a `TypeError` on an unexpected error shape would lose the round's cursor AND
  // watermark and then re-throw on the identical page every round — see [_cursorFrom].
  final errors = response['errors'];
  if (errors is! Map) return false;
  final forSide = errors[side];
  if (forSide is! Map) return false;
  final pagination = forSide['pagination'];
  return pagination is Map && pagination['cursor'] != null;
}
