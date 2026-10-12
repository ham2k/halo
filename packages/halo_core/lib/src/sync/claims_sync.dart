// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The claims side of a sync round (docs/design/claims.md §7): a third kind
// of record beside operations and contacts, opt-in on both ends.
//
// A server that predates claims answers 200 and drops them, so they are sent
// and asked for only after a reply carrying `meta.flags.claims`
// ([SyncEngine.claimsSupportedKey]), and marked synced only on such a reply.
//
// Claims are never backfilled. They are paged forward from the start, during
// a backfill too, so a device still downloading its history reads every
// checklist at once ([SyncEngine.claimWatermarkKey],
// [SyncEngine.claimCursorKey]). They take no part in `completedFullSync`.

part of 'sync_engine.dart';

extension _ClaimsSide on SyncEngine {
  bool get _claimsOn => claims != null && settings.state[SyncEngine.claimsSupportedKey] == true;

  /// Claims go alongside whatever else is pushed, never instead of it: they
  /// depend on no other record.
  Future<List<StoredClaim>> _pendingClaims(int limit) async =>
      _claimsOn ? await claims!.unsyncedBatch(limit, excluding: _activeQuarantine(_quarantinedClaims)) : const <StoredClaim>[];

  /// Every client's rows until the first catch-up after the claims were
  /// cleared ([SyncEngine.claimsCaughtUpKey]), since a device starting over
  /// (a new account, SYNCALL) needs back the rows it pushed itself. Other
  /// clients' only after that: this device's own would come straight back
  /// after every push, a whole rebuild's worth at a time.
  Map<String, dynamic> _claimsWindow(Map<String, dynamic> state, int limit) => {
    'syncedSinceMillis': (state[SyncEngine.claimWatermarkKey] as num?)?.toInt() ?? 0,
    if (state[SyncEngine.claimCursorKey] != null) 'cursor': state[SyncEngine.claimCursorKey],
    'limit': limit,
    'anyClient': state[SyncEngine.claimsCaughtUpKey] != true,
  };

  /// Settles what the server took of [batch]'s claims and returns what it
  /// sent back. Whether it takes claims at all is read from this reply, not
  /// from the state that sent the batch: one that stopped (a rollback)
  /// answers 200 and drops them, and marking them synced on that answer
  /// would leave the server without them for good.
  Future<({List<StoredClaim> accepted, List<Map<String, dynamic>> inbound})> _receiveClaims(
    Map<String, dynamic> response,
    SyncBatch batch, {
    required bool requested,
  }) async {
    final rejected = SyncEngine._rejectedUuids(response, 'claims');
    _reportRejections(rejected, 'claims');
    _reportUnreadable(response, 'claims');
    _quarantine(rejected.keys, _quarantinedClaims);

    final takes = _takesClaims(response);
    if (claims == null || takes == null) return (accepted: const <StoredClaim>[], inbound: const <Map<String, dynamic>>[]);
    if (takes != (settings.state[SyncEngine.claimsSupportedKey] == true)) {
      await settings.setState({...settings.state, SyncEngine.claimsSupportedKey: takes});
    }
    if (!takes) return (accepted: const <StoredClaim>[], inbound: const <Map<String, dynamic>>[]);

    final accepted = [
      for (final claim in batch.claims)
        if (!rejected.containsKey(claim.uuid)) claim,
    ];
    if (accepted.isNotEmpty) await claims!.markSynced(accepted);
    final inbound = requested
        ? (response['claims'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const <Map<String, dynamic>>[]
        : const <Map<String, dynamic>>[];
    return (accepted: accepted, inbound: inbound);
  }

  /// The claims watermark and cursor follow the forward rules of
  /// `_processResponseMeta` in every round that asked for claims, whether or
  /// not the other sides are still backfilling: a page built from a cursor
  /// banks one millisecond short, and a page that named no position, or a
  /// refused cursor, drops the cursor.
  Future<void> _bankClaims(Map<String, dynamic> response, {required String? sentCursor, required List<Map<String, dynamic>> inbound}) async {
    final meta = (response['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final updates = <String, dynamic>{};
    int? latest;
    for (final claim in inbound) {
      final stamp = claim['syncedAtMillis'];
      if (stamp is num && (latest == null || stamp > latest)) latest = stamp.toInt();
    }
    if (latest != null) {
      final candidate = sentCursor != null ? latest - 1 : latest;
      if (candidate > ((settings.state[SyncEngine.claimWatermarkKey] as num?)?.toInt() ?? 0)) updates[SyncEngine.claimWatermarkKey] = candidate;
    }
    final cursor = SyncEngine._cursorFrom(meta, 'claims');
    if (cursor != null) {
      updates[SyncEngine.claimCursorKey] = cursor;
    } else if (inbound.isNotEmpty || SyncEngine._cursorRefused(response, 'claims')) {
      updates[SyncEngine.claimCursorKey] = null;
    }
    final side = meta['claims'];
    final left = side is Map ? side['records_left'] ?? side['recordsLeft'] : null;
    if (left == 0 && settings.state[SyncEngine.claimsCaughtUpKey] != true) updates[SyncEngine.claimsCaughtUpKey] = true;
    if (updates.isNotEmpty) await settings.setState({...settings.state, ...updates});
  }
}

/// Whether [response] says the server stores claims, or null for a reply that
/// carries no flags at all and so says nothing either way.
bool? _takesClaims(Map<String, dynamic> response) {
  final flags = (response['meta'] as Map?)?['flags'];
  if (flags is! Map) return null;
  return flags['claims'] == true;
}
