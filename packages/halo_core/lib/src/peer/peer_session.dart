// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One live conversation with one PAIRED PEER DEVICE (HALO-310, HALO-334).
// Transport-agnostic by construction: it is handed a [PeerLink] and never
// learns whether that is a LAN socket, BLE, or a relay.
//
// The session binds to the DEVICE, not to an operation. Once established it
// stays up while both apps run, carrying two kinds of traffic:
//
//   - Ephemeral messages (a GPS fix, a radio's VFO, a tune request) — sent
//     any time the session is established, latest-value-wins, never
//     persisted, delivered through [onEphemeral].
//   - The durable QSO/operation sync, which engages only WHILE both sides
//     share the same operation ([setSharing] / the `sharing` message) and
//     disengages — without tearing the session down — when they stop.
//
// The shape of a session, in order:
//   1. Both sides send `hello`, unprompted, on connect.
//   2. Each side independently decides whether it trusts the other's
//      deviceId, asking its operator once if it has never seen it
//      (trust-on-first-use, `PeerTrustStore`).
//   3. Each side that has decided YES sends `trusted`.
//   4. Nothing flows until BOTH have — see [_maybeEstablish]. Trust is
//      per-device and one-directional in the store, so a peer this operator
//      welcomed must still wait to be welcomed back.
//   5. Established. Whenever both sides' shared operation is the same one,
//      each asks for the other's outbox after its own durable cursor,
//      applies what comes back, and acks; the acked side sends the next
//      batch, until there is nothing left and the session reads as caught
//      up. A `sharing` change re-runs this against the new operation.
//
// Cursors, not acks, are the source of truth for what has been applied: the
// receiver advances `PeerCursors` only after `mergeFromPeer` has committed,
// so a link that dies mid-catch-up resumes from the last COMMITTED batch and
// never from an optimistic sender-side count.

import 'dart:async';
import 'dart:convert';

import '../repo/repositories.dart';
import 'peer_link.dart';
import 'peer_protocol.dart';
import 'peer_trust.dart';
import 'peer_outbox.dart';

enum PeerSessionState {
  /// `hello` sent, the peer's not yet received or not yet acted on.
  handshaking,

  /// The peer identified itself and this device has never paired with it.
  /// Waiting on the operator — nothing flows until [acceptPairing].
  needsPairing,

  /// Mutually trusted. Ephemeral traffic flows; the durable sync is idle
  /// because the two sides are not sharing the same operation right now.
  connected,

  /// Mutually trusted and catching up on the operation both sides share.
  syncing,

  /// Caught up on the shared operation; local writes stream as they happen.
  live,

  /// Terminal, with [refusedReason] set — a version mismatch, this device
  /// talking to itself, or the peer declining us.
  refused,

  /// Terminal.
  closed,
}

class PeerSession {
  final PeerLink link;
  final String localDeviceId;
  final String localDeviceName;

  /// What this side advertises it can offer the peer (`gps`, `cat`) —
  /// carried in the hello, surfaced from [peer] on the far side.
  final List<String> localCapabilities;

  final PeerOutbox outbox;
  final PeerCursorStore cursors;
  final PeerTrustStore trust;
  final OperationsRepository operations;
  final QsosRepository qsos;

  /// How many outbox rows one `events` message may carry.
  final int batchLimit;

  /// Fired after any observable change — state, peer identity, progress —
  /// so an app-layer ChangeNotifier can republish it. Plain callback rather
  /// than a Flutter type: halo_core has no Flutter dependency (DESIGN.md §4).
  final void Function(PeerSession session)? onChanged;

  /// Ephemeral traffic from the peer — a `position`, `catStatus`, `catSet`,
  /// or any type a newer build defines. Fired only once the session is
  /// established (mutual trust), so a consumer never has to re-check that an
  /// untrusted device is feeding it positions or tuning its radio.
  ///
  /// Called straight off the link, NOT through the [_enqueue] serialization:
  /// ephemeral messages touch no cursor, and a GPS fix must not queue behind
  /// a large catch-up batch's database work.
  final void Function(PeerSession session, PeerMessage message)? onEphemeral;

  /// Fired once on becoming established — the moment to send snapshots of
  /// latest-value state (current position, current VFO), since the peer
  /// missed everything broadcast before it arrived.
  final void Function(PeerSession session)? onEstablished;

  final void Function(String message)? log;

  PeerSession({
    required this.link,
    required this.localDeviceId,
    required this.localDeviceName,
    required this.outbox,
    required this.cursors,
    required this.trust,
    required this.operations,
    required this.qsos,
    String? sharedOperationUuid,
    this.localCapabilities = const [],
    this.batchLimit = 200,
    this.onChanged,
    this.onEphemeral,
    this.onEstablished,
    this.log,
  }) : _localSharing = sharedOperationUuid;

  PeerSessionState _state = PeerSessionState.handshaking;
  PeerSessionState get state => _state;

  String? _refusedReason;
  String? get refusedReason => _refusedReason;

  PeerHello? _peer;

  /// Who the far side says it is — null until its `hello` arrives. The
  /// pairing prompt reads this.
  PeerHello? get peer => _peer;

  String? _localSharing;
  String? _peerSharing;

  /// The operation BOTH sides currently share, or null — the only operation
  /// the durable sync may touch.
  String? get syncedOperationUuid =>
      _localSharing != null && _localSharing == _peerSharing ? _localSharing : null;

  bool _localTrusts = false;
  bool _peerTrustsUs = false;
  bool _established = false;

  /// Mutual trust declared, both ways — the gate on every kind of data.
  bool get established => _established;

  /// Which operation the current catch-up was requested for. Also the guard
  /// against requesting twice: null while none is in train.
  String? _catchUpOperation;

  /// The highest outbox `seq` this side has put on the wire, per operation.
  /// An optimization only: it saves resending, but the peer's own cursor is
  /// what decides correctness after a reconnect.
  final Map<String, int> _lastSentSeq = {};

  StreamSubscription<List<int>>? _subscription;
  bool _closed = false;

  /// Serializes the durable-sync handlers. They await the database, and two
  /// `events` batches arriving back-to-back must not interleave their
  /// apply-then-advance-cursor sequences — the second could otherwise
  /// advance the cursor past a batch the first has not committed yet.
  /// Ephemeral messages deliberately do not pass through here.
  Future<void> _tail = Future.value();

  Future<void> start() {
    _subscription = link.inbound.listen(
      _dispatch,
      onError: (Object e) => log?.call('peer link error: $e'),
    );
    unawaited(link.closed.then((_) => _finish(PeerSessionState.closed)));
    _send(PeerMessage.hello(
      deviceId: localDeviceId,
      deviceName: localDeviceName,
      operationUuid: _localSharing,
      capabilities: localCapabilities,
    ));
    return Future.value();
  }

  /// The operator confirmed the peer shown in [peer]. Records the trust so
  /// this never asks again, then lets the session proceed.
  Future<void> acceptPairing() async {
    final peer = _peer;
    if (peer == null || _closed) return;
    await trust.trust(peer.deviceId, name: peer.deviceName);
    await _enqueue(() => _declareTrust());
  }

  /// The operator declined. Refuses rather than silently idling, so the far
  /// side learns it was turned down instead of waiting forever.
  Future<void> rejectPairing() async {
    _send(PeerMessage.refuse(PeerRefusal.notTrusted));
    _refusedReason = PeerRefusal.notTrusted;
    await _finish(PeerSessionState.refused);
  }

  /// This side's shared operation changed — to another one, or to none.
  /// Announces it and re-evaluates the sync, all without touching the link:
  /// the session belongs to the DEVICE, and surviving an operation switch is
  /// the point of it.
  Future<void> setSharing(String? operationUuid) async {
    if (_localSharing == operationUuid || _closed) return;
    _localSharing = operationUuid;
    _send(PeerMessage.sharing(operationUuid));
    await _enqueue(_syncStateChanged);
  }

  /// Called when this device's own outbox has grown. No-op unless the
  /// session is past catch-up, since catch-up already sends everything.
  Future<void> pushLocal() => _enqueue(_pushLocal);

  /// Sends one ephemeral message — dropped, not queued, unless the session
  /// is established. The caller owns choosing a type the peer understands;
  /// an unknown type costs the peer nothing (`PeerMessage.decode`).
  void sendEphemeral(PeerMessage message) {
    if (!_established || _closed) return;
    _send(message);
  }

  Future<void> close() async {
    await _finish(PeerSessionState.closed);
  }

  /// First look at every inbound frame. Ephemeral types are delivered
  /// immediately; everything else joins the serialized sync queue.
  void _dispatch(List<int> raw) {
    final message = PeerMessage.decode(raw);
    // Unreadable — dropped, never fatal.
    if (message == null) return;

    switch (message.type) {
      case PeerMessageType.hello:
      case PeerMessageType.trusted:
      case PeerMessageType.refuse:
      case PeerMessageType.sharing:
      case PeerMessageType.catchUp:
      case PeerMessageType.events:
      case PeerMessageType.ack:
        _enqueue(() => _handle(message));
      default:
        // Every type this build does not handle above is ephemeral by
        // definition — including types a newer build invented, which a
        // consumer is free to ignore. Gated on established: nothing an
        // untrusted device sends reaches the app.
        // `_closed` too, though today's teardown cancels the subscription
        // with no await in between: that ordering is one refactor away from
        // delivering into a torn-down consumer, and this check costs nothing.
        if (_established && !_closed) onEphemeral?.call(this, message);
    }
  }

  Future<void> _enqueue(Future<void> Function() work) {
    final next = _tail.then((_) async {
      if (_closed) return;
      try {
        await work();
      } catch (e) {
        log?.call('peer session error: $e');
      }
    });
    _tail = next;
    return next;
  }

  Future<void> _handle(PeerMessage message) async {
    switch (message.type) {
      case PeerMessageType.hello:
        await _onHello(message);
      case PeerMessageType.trusted:
        _peerTrustsUs = true;
        await _maybeEstablish();
      case PeerMessageType.refuse:
        _refusedReason = message.reason ?? PeerRefusal.notTrusted;
        await _finish(PeerSessionState.refused);
      case PeerMessageType.sharing:
        _peerSharing = message.operationUuid;
        await _syncStateChanged();
      case PeerMessageType.catchUp:
        await _onCatchUp(message);
      case PeerMessageType.events:
        await _onEvents(message);
      case PeerMessageType.ack:
        await _onAck(message);
    }
  }

  Future<void> _onHello(PeerMessage message) async {
    final hello = message.helloOrNull;
    if (hello == null) return;
    if (_peer != null) return; // a second hello changes nothing
    _peer = hello;
    _peerSharing = hello.operationUuid;

    if (hello.protocolVersion != peerProtocolVersion) {
      return _refuse(PeerRefusal.protocolVersion);
    }
    // Its own announcement, reflected back by a broadcast it can hear — or
    // a genuine second install carrying a cloned id. Either way this device
    // must not sync with itself: the outbox and the cursor would chase each
    // other, and every record would look like it came from elsewhere.
    if (hello.deviceId == localDeviceId) {
      return _refuse(PeerRefusal.sameDevice);
    }

    if (await trust.isTrusted(hello.deviceId)) {
      await trust.markSeen(hello.deviceId);
      await _declareTrust();
    } else {
      _setState(PeerSessionState.needsPairing);
    }
  }

  Future<void> _declareTrust() async {
    if (_localTrusts) return;
    _localTrusts = true;
    _send(PeerMessage.trusted());
    await _maybeEstablish();
  }

  Future<void> _maybeEstablish() async {
    if (!_localTrusts || !_peerTrustsUs || _established || _closed) return;
    _established = true;
    // Before _syncStateChanged, which sets the state this notification
    // should not clobber — and snapshots sent from here must already pass
    // sendEphemeral's established gate.
    onEstablished?.call(this);
    await _syncStateChanged();
  }

  /// Re-derives what the durable sync should be doing from the two sharing
  /// declarations. Runs on establish and on either side's `sharing` change.
  Future<void> _syncStateChanged() async {
    if (!_established || _closed) return;
    final shared = syncedOperationUuid;
    if (shared == null) {
      // Any catch-up in train is for an operation no longer shared. Batches
      // still in flight name their operation, so the guards in _onEvents /
      // _onCatchUp make them harmless; the request state just resets.
      _catchUpOperation = null;
      _setState(PeerSessionState.connected);
      return;
    }
    if (_catchUpOperation == shared) return;
    _catchUpOperation = shared;
    _setState(PeerSessionState.syncing);
    final peerDeviceId = _peer!.deviceId;
    final since = await cursors.lastAppliedSeq(peerDeviceId, shared);
    _send(PeerMessage.catchUp(shared, since));
  }

  /// The peer wants this device's outbox for an operation from `sinceSeq` on.
  Future<void> _onCatchUp(PeerMessage message) async {
    // Trust is checked on the SENDING side too, not just when admitting a
    // peer: a `catchUp` arriving before this side has decided anything must
    // not extract the log by skipping the handshake.
    if (!_localTrusts) return;
    final operationUuid = message.operationUuid;
    // Only the operation this side currently shares is served. A peer asking
    // for anything else — stale, confused, or probing — gets silence, and
    // its own _syncStateChanged re-requests when sharing next lines up.
    if (operationUuid == null || operationUuid != _localSharing) return;
    final sinceSeq = message.intSinceSeq ?? 0;
    _lastSentSeq[operationUuid] = sinceSeq;
    await _sendBatchAfter(operationUuid, sinceSeq);
  }

  Future<void> _sendBatchAfter(String operationUuid, int sinceSeq) async {
    final rows = await outbox.eventsSince(operationUuid, sinceSeq, limit: batchLimit);
    if (rows.isEmpty) {
      _send(PeerMessage.eventsBatch(operationUuid, const [], hasMore: false));
      return;
    }
    final payload = [
      for (final row in rows)
        PeerEventPayload(seq: row.seq, kind: row.kind, data: _decodeRow(row.data)).toJson(),
    ];
    final lastSeq = rows.last.seq;
    if (lastSeq > (_lastSentSeq[operationUuid] ?? 0)) _lastSentSeq[operationUuid] = lastSeq;
    // `hasMore` is honest about the batch limit, not about whether the peer
    // has caught up with a log still being written: a full batch means ask
    // again, and the peer does exactly that on ack.
    _send(PeerMessage.eventsBatch(operationUuid, payload, hasMore: rows.length >= batchLimit));
  }

  Future<void> _onEvents(PeerMessage message) async {
    if (!_localTrusts || _peer == null) return;
    final operationUuid = message.operationUuid;
    // A batch for an operation this side is not syncing any more — sharing
    // moved while it was in flight. Dropped WITHOUT advancing any cursor:
    // the records are durable and will be re-served when sharing lines up
    // again, from the cursor exactly where it stands.
    if (operationUuid == null || operationUuid != syncedOperationUuid) return;
    final events = message.events;
    if (events.isEmpty) {
      _setState(message.hasMore ? PeerSessionState.syncing : PeerSessionState.live);
      return;
    }

    final operationRecords = <Map<String, dynamic>>[];
    final qsoRecords = <Map<String, dynamic>>[];
    var highestSeq = 0;
    for (final event in events) {
      if (event.seq > highestSeq) highestSeq = event.seq;
      switch (event.kind) {
        case PeerEventKind.operation:
          operationRecords.add(event.data);
        case PeerEventKind.qso:
          qsoRecords.add(event.data);
        // A kind this build doesn't know still advances the cursor: it came
        // from a peer on the SAME protocol version, so refusing to move past
        // it would wedge catch-up forever on a record we can never apply.
      }
    }

    try {
      // Operations first: a QSO can reference an operation this device has
      // never seen, and applying the parent first means the counters its
      // insert refreshes land on a row that exists.
      if (operationRecords.isNotEmpty) await operations.mergeFromPeer(operationRecords);
      if (qsoRecords.isNotEmpty) await qsos.mergeFromPeer(qsoRecords);
    } catch (e) {
      // The cursor deliberately does NOT advance — see this file's header:
      // it may only move past what committed. But the session must not just
      // stop either: the peer is waiting on an ack it will never get, with
      // no timeout behind it, so both sides would sit in `syncing` forever
      // on one bad record or a transient lock. Ending the session lets the
      // service's normal reconnect retry the same batch from the same
      // cursor, which is the only recovery that can actually make progress.
      log?.call('apply failed, dropping the session so catch-up can retry: $e');
      await _finish(PeerSessionState.closed);
      return;
    }

    await cursors.advanceTo(_peer!.deviceId, operationUuid, highestSeq);
    _send(PeerMessage.ack(operationUuid, highestSeq));
    _setState(message.hasMore ? PeerSessionState.syncing : PeerSessionState.live);
  }

  Future<void> _onAck(PeerMessage message) async {
    if (!_localTrusts) return;
    final operationUuid = message.operationUuid;
    if (operationUuid == null || operationUuid != _localSharing) return;
    final seq = message.intSeq ?? 0;
    if (seq > (_lastSentSeq[operationUuid] ?? 0)) _lastSentSeq[operationUuid] = seq;
    // Whatever the peer just acked may not have been everything — either the
    // batch hit its limit, or local writes landed while it was in flight.
    await _sendBatchAfter(operationUuid, seq);
  }

  Future<void> _pushLocal() async {
    if (_state != PeerSessionState.live && _state != PeerSessionState.syncing) return;
    if (!_established) return;
    final operationUuid = syncedOperationUuid;
    if (operationUuid == null) return;
    await _sendBatchAfter(operationUuid, _lastSentSeq[operationUuid] ?? 0);
  }

  Future<void> _refuse(String reason) async {
    _send(PeerMessage.refuse(reason));
    _refusedReason = reason;
    await _finish(PeerSessionState.refused);
  }

  void _send(PeerMessage message) {
    if (_closed) return;
    link.send(message.encode());
  }

  Future<void> _finish(PeerSessionState finalState) async {
    if (_closed) return;
    _closed = true;
    _setState(finalState);
    await _subscription?.cancel();
    _subscription = null;
    await link.close();
  }

  void _setState(PeerSessionState next) {
    if (_state == next) return;
    _state = next;
    onChanged?.call(this);
  }

  Map<String, dynamic> _decodeRow(String json) {
    final decoded = jsonDecodeMap(json);
    return decoded ?? const {};
  }
}

/// Tolerant JSON-object decode — a row this device wrote itself should always
/// parse, so a failure is a corrupt row rather than untrusted input, and
/// dropping just that row beats failing the whole batch.
Map<String, dynamic>? jsonDecodeMap(String json) {
  try {
    final decoded = jsonDecode(json);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}
