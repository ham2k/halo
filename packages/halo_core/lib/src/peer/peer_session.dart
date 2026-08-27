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
//   - The durable QSO/operation sync, whose two directions are INDEPENDENT
//     (HALO-365): what this device receives follows the operation the PEER
//     declares it is sharing, and what it sends follows its own
//     ([setSharing] / the `sharing` message).
//
// What may be received is narrower than what a peer offers (HALO-365). An
// operation this device has never seen is taken only from a peer signed in
// to the SAME cloud account — one of the operator's own devices. From any
// other peer, and from every peer when neither side is signed in at all,
// only an operation this device already has will sync: what two operators
// have already shared keeps flowing, and nothing new crosses between
// accounts without a consent step that does not exist yet.
//
// Stopping is asymmetric with it: closing an operation stops what this
// device SERVES, never what it receives, since the peer is still in that
// operation and still logging. The master switch and unpairing are what
// stop the inbound side.
//
// That asymmetry is what lets an operation created on one device reach the
// other at all. A device can only ever declare an operation it HAS, so
// requiring the two declarations to match — as this once did — left a brand
// new operation unreachable: the far side had nothing to name. Following the
// peer's declaration instead, it pulls the operation and its log, and the
// operator finds it in their list. It stays receive-only there until they
// open it: the outbox only ever holds the operation this device has open, so
// nothing is served for an operation the operator is not in.
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
//   5. Established. Whenever the peer names an operation it is sharing, this
//      side asks for that operation's outbox after its own durable cursor,
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
  /// because neither side has named an operation to carry.
  connected,

  /// Mutually trusted, with a batch in train in either direction.
  syncing,

  /// Caught up in both directions; local writes stream as they happen.
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

  /// This device's account stand-in, or null when signed in to none — see
  /// [PeerHello.accountTag] for what it may and may not be.
  final String? localAccountTag;

  final PeerOutbox outbox;
  final PeerCursorStore cursors;
  final PeerTrustStore trust;
  final OperationsRepository operations;
  final QsosRepository qsos;

  /// How many outbox rows one `events` message may carry. The default is
  /// sized for fast links; a slower transport passes its own smaller limit.
  /// This constant is the single owner of the default, so attach paths
  /// never restate it as a second magic number.
  static const int defaultBatchLimit = 200;

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
    this.localAccountTag,
    this.localCapabilities = const [],
    this.batchLimit = defaultBatchLimit,
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

  /// What each side has open. [_localSharing] is the only operation this
  /// device SERVES; [_peerSharing] is the only one it RECEIVES, whether or
  /// not it is the same one — an operation this device has never seen can
  /// only ever arrive under the name its owner gives it.
  String? _localSharing;
  String? _peerSharing;

  bool _localTrusts = false;
  bool _peerTrustsUs = false;
  bool _established = false;

  /// Mutual trust declared, both ways — the gate on every kind of data.
  bool get established => _established;

  /// Which operation this side has asked the peer for — a mirror of the
  /// peer's declaration that outlives the catch-up itself, since the same
  /// operation keeps arriving as live pushes afterwards. Two jobs: it
  /// suppresses a duplicate request when nothing moved, and it is the
  /// admission gate in [_onEvents]. Null only while the peer names nothing.
  String? _catchUpOperation;

  /// The operation the PEER last asked this side for, or null. Only ever set
  /// to something [_onCatchUp] accepted, so it names an operation this
  /// device has open — the send direction's counterpart to
  /// [_catchUpOperation], and what tells [_pushLocal] there is somebody
  /// listening. A peer that never asked is not owed a live push.
  String? _servingOperation;

  /// Whether each direction has a batch in train — what [_refreshSyncState]
  /// reads. Both must be quiet for the session to read as caught up, or the
  /// device doing the SENDING would report itself idle while it feeds the
  /// other one a whole log.
  bool _receiveBusy = false;
  bool _serveBusy = false;

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
      accountTag: localAccountTag,
      capabilities: localCapabilities,
    ));
    return Future.value();
  }

  /// Whether THIS side has declared trust — the operator answered, or the
  /// peer was already in the trust store.
  ///
  /// Not the same question as [state] leaving [PeerSessionState.needsPairing]:
  /// that needs BOTH sides, so a session sits in `needsPairing` after this
  /// operator has confirmed, while the far one has not. A caller asking
  /// "should I prompt?" must read this, or it re-asks an operator who has
  /// already answered, once per notification, until the far side confirms.
  bool get localTrusts => _localTrusts;

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
    // Whatever was being served is over: the peer re-requests on hearing the
    // change below, and until it does, a stale [_serveBusy] left over from an
    // abandoned batch would read as a batch in train the moment this device
    // returns to the same operation.
    _servingOperation = null;
    _serveBusy = false;
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

  /// Re-derives what the RECEIVE direction should be doing from the peer's
  /// sharing declaration. Runs on establish and on either side's `sharing`
  /// change — this side's own change matters here only because it can turn
  /// the session from carrying nothing into carrying something.
  Future<void> _syncStateChanged() async {
    if (!_established || _closed) return;
    final incoming = _peerSharing;
    if (incoming == null) {
      // Any catch-up in train is for an operation the peer has since left.
      // Batches still in flight name their operation, so the guards in
      // _onEvents / _onCatchUp make them harmless; the request state resets.
      _catchUpOperation = null;
      _receiveBusy = false;
      _refreshSyncState();
      return;
    }
    if (_catchUpOperation == incoming) {
      _refreshSyncState();
      return;
    }
    if (!await _mayReceive(incoming)) {
      // Silently, and without refusing the session: the pair stays up for
      // ephemeral traffic and for any operation they DO share. Nothing is
      // requested, so the guard in _onEvents drops an unsolicited batch.
      _catchUpOperation = null;
      _receiveBusy = false;
      _refreshSyncState();
      return;
    }
    _catchUpOperation = incoming;
    _receiveBusy = true;
    _refreshSyncState();
    final peerDeviceId = _peer!.deviceId;
    final since = await cursors.lastAppliedSeq(peerDeviceId, incoming);
    _send(PeerMessage.catchUp(incoming, since));
  }

  /// Whether an operation the peer offers may be taken — see this file's
  /// header. Re-asked on every change of what the peer shares, never cached:
  /// the answer moves when an operation arrives here by another route.
  ///
  /// Deliberately NOT re-asked when that happens without the peer moving —
  /// an operation landing from cloud sync while the peer sits in it engages
  /// nothing until either side next changes what it has open, or the link
  /// reconnects. It is already arriving over the other channel.
  Future<bool> _mayReceive(String operationUuid) async {
    if (_peer?.sameAccountAs(localAccountTag) ?? false) return true;
    return await operations.get(operationUuid) != null;
  }

  /// Both directions in one label. `connected` only when there is nothing to
  /// carry either way; anything in train is `syncing`; quiet with something
  /// shared is `live`.
  ///
  /// Each busy flag counts only while its own direction is still running.
  /// A serve interrupted mid-backlog — the operator closes the operation
  /// between a full batch and its ack — leaves [_serveBusy] set with no ack
  /// coming to clear it, and reading it unconditionally would pin a healthy
  /// session at `syncing` for as long as it lives.
  void _refreshSyncState() {
    if (!_established || _closed) return;
    final receiving = _catchUpOperation != null;
    final serving = _servingOperation != null && _servingOperation == _localSharing;
    if (!receiving && !serving) {
      _setState(PeerSessionState.connected);
      return;
    }
    final busy = (receiving && _receiveBusy) || (serving && _serveBusy);
    _setState(busy ? PeerSessionState.syncing : PeerSessionState.live);
  }

  /// The peer wants this device's outbox for an operation from `sinceSeq` on.
  Future<void> _onCatchUp(PeerMessage message) async {
    // Trust is checked on the SENDING side too, not just when admitting a
    // peer: a `catchUp` arriving before this side has decided anything must
    // not extract the log by skipping the handshake.
    if (!_localTrusts) return;
    final operationUuid = message.operationUuid;
    // Only the operation this side currently has open is served. A peer
    // asking for anything else — stale, confused, or probing — gets silence,
    // and its own _syncStateChanged re-requests when this side next opens it.
    if (operationUuid == null || operationUuid != _localSharing) return;
    final sinceSeq = message.intSinceSeq ?? 0;
    _lastSentSeq[operationUuid] = sinceSeq;
    // Somebody is listening: from here on, local writes push live to them,
    // whether or not they share anything back.
    _servingOperation = operationUuid;
    _serveBusy = true;
    _refreshSyncState();
    await _sendBatchAfter(operationUuid, sinceSeq);
  }

  Future<void> _sendBatchAfter(String operationUuid, int sinceSeq) async {
    final rows = await outbox.eventsSince(operationUuid, sinceSeq, limit: batchLimit);
    if (rows.isEmpty) {
      _send(PeerMessage.eventsBatch(operationUuid, const [], hasMore: false));
      _serveBusy = false;
      _refreshSyncState();
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
    final hasMore = rows.length >= batchLimit;
    _send(PeerMessage.eventsBatch(operationUuid, payload, hasMore: hasMore));
    _serveBusy = hasMore;
    _refreshSyncState();
  }

  Future<void> _onEvents(PeerMessage message) async {
    if (!_localTrusts || _peer == null) return;
    final operationUuid = message.operationUuid;
    // Only the catch-up actually in train is applied: a batch must name the
    // operation this side asked for, which is the one the peer declared.
    // Anything else — a batch still in flight when sharing moved, an
    // unsolicited push at an operation nobody asked about — is dropped
    // WITHOUT advancing any cursor, so its records are re-served from where
    // the cursor stands if sharing later lines up.
    //
    // What this does NOT do is bound a trusted peer to one operation: the
    // declaration it is checked against is the PEER's, so a paired device
    // can reach any operation whose uuid it knows by declaring it first.
    // That is inside the protocol's stated trust model, not outside it —
    // the same device can already tune this station's radio, and nothing
    // here authenticates anyone (see peer_protocol.dart's header). The
    // gate is against a misdirected batch, not against a hostile peer.
    if (operationUuid == null || operationUuid != _catchUpOperation) return;
    final events = message.events;
    if (events.isEmpty) {
      _receiveBusy = message.hasMore;
      _refreshSyncState();
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
    _receiveBusy = message.hasMore;
    _refreshSyncState();
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
    if (!_established || _closed) return;
    final operationUuid = _localSharing;
    // Gated on the PEER having asked for this operation, not on what it
    // shares back: the device a peer is pulling FROM sees that peer sharing
    // nothing, and gating on a shared operation would hand it the backlog
    // once and then never another QSO until the link dropped.
    if (operationUuid == null || operationUuid != _servingOperation) return;
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
