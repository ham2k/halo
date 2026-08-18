// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One live conversation with one peer device about one shared operation
// (HALO-310). Transport-agnostic by construction: it is handed a [PeerLink]
// and never learns whether that is a LAN socket, BLE, or a relay.
//
// The shape of a session, in order:
//   1. Both sides send `hello`, unprompted, on connect.
//   2. Each side independently decides whether it trusts the other's
//      deviceId, asking its operator once if it has never seen it
//      (trust-on-first-use, `PeerTrustStore`).
//   3. Each side that has decided YES sends `trusted`.
//   4. Data flows only once BOTH have — see [_maybeBeginSync]. Trust is
//      per-device and one-directional in the store, so a peer this operator
//      welcomed must still wait to be welcomed back.
//   5. Each side asks for the other's outbox after its own durable cursor,
//      applies what comes back, and acks; the acked side then sends the next
//      batch, until there is nothing left and the session goes live.
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

  /// Mutually trusted, catching up.
  syncing,

  /// Mutually trusted and caught up; local writes stream as they happen.
  live,

  /// Terminal, with [refusedReason] set — a version mismatch, a different
  /// operation, this device talking to itself, or the peer declining us.
  refused,

  /// Terminal.
  closed,
}

class PeerSession {
  final PeerLink link;
  final String localDeviceId;
  final String localDeviceName;
  final String operationUuid;
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

  final void Function(String message)? log;

  PeerSession({
    required this.link,
    required this.localDeviceId,
    required this.localDeviceName,
    required this.operationUuid,
    required this.outbox,
    required this.cursors,
    required this.trust,
    required this.operations,
    required this.qsos,
    this.batchLimit = 200,
    this.onChanged,
    this.log,
  });

  PeerSessionState _state = PeerSessionState.handshaking;
  PeerSessionState get state => _state;

  String? _refusedReason;
  String? get refusedReason => _refusedReason;

  PeerHello? _peer;

  /// Who the far side says it is — null until its `hello` arrives. The
  /// pairing prompt reads this.
  PeerHello? get peer => _peer;

  bool _localTrusts = false;
  bool _peerTrustsUs = false;
  bool _catchUpRequested = false;

  /// The highest outbox `seq` this side has put on the wire. An optimization
  /// only: it saves resending, but the peer's own cursor is what decides
  /// correctness after a reconnect.
  int _lastSentSeq = 0;

  StreamSubscription<List<int>>? _subscription;
  bool _closed = false;

  /// Serializes message handling. Handlers await the database, and two
  /// `events` batches arriving back-to-back must not interleave their
  /// apply-then-advance-cursor sequences — the second could otherwise
  /// advance the cursor past a batch the first has not committed yet.
  Future<void> _tail = Future.value();

  Future<void> start() {
    _subscription = link.inbound.listen(
      (message) => _enqueue(() => _handle(message)),
      onError: (Object e) => log?.call('peer link error: $e'),
    );
    unawaited(link.closed.then((_) => _finish(PeerSessionState.closed)));
    _send(PeerMessage.hello(
      deviceId: localDeviceId,
      deviceName: localDeviceName,
      operationUuid: operationUuid,
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

  /// Called when this device's own outbox has grown. No-op unless the
  /// session is past catch-up, since catch-up already sends everything.
  Future<void> pushLocal() => _enqueue(_pushLocal);

  Future<void> close() async {
    await _finish(PeerSessionState.closed);
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

  Future<void> _handle(List<int> raw) async {
    final message = PeerMessage.decode(raw);
    // Unreadable, or a type from a newer build — dropped, never fatal.
    if (message == null) return;

    switch (message.type) {
      case PeerMessageType.hello:
        await _onHello(message);
      case PeerMessageType.trusted:
        _peerTrustsUs = true;
        await _maybeBeginSync();
      case PeerMessageType.refuse:
        _refusedReason = message.reason ?? PeerRefusal.notTrusted;
        await _finish(PeerSessionState.refused);
      case PeerMessageType.catchUp:
        await _onCatchUp(message.intSinceSeq ?? 0);
      case PeerMessageType.events:
        await _onEvents(message);
      case PeerMessageType.ack:
        await _onAck(message.intSeq ?? 0);
    }
  }

  Future<void> _onHello(PeerMessage message) async {
    final hello = message.helloOrNull;
    if (hello == null) return;
    if (_peer != null) return; // a second hello changes nothing
    _peer = hello;

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
    if (hello.operationUuid != operationUuid) {
      return _refuse(PeerRefusal.differentOperation);
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
    await _maybeBeginSync();
  }

  Future<void> _maybeBeginSync() async {
    if (!_localTrusts || !_peerTrustsUs || _catchUpRequested || _closed) return;
    _catchUpRequested = true;
    _setState(PeerSessionState.syncing);
    final peerDeviceId = _peer!.deviceId;
    final since = await cursors.lastAppliedSeq(peerDeviceId, operationUuid);
    _send(PeerMessage.catchUp(since));
  }

  /// The peer wants this device's outbox from [sinceSeq] on.
  Future<void> _onCatchUp(int sinceSeq) async {
    // Trust is checked on the SENDING side too, not just when admitting a
    // peer: a `catchUp` arriving before this side has decided anything must
    // not extract the log by skipping the handshake.
    if (!_localTrusts) return;
    _lastSentSeq = sinceSeq;
    await _sendBatchAfter(sinceSeq);
  }

  Future<void> _sendBatchAfter(int sinceSeq) async {
    final rows = await outbox.eventsSince(operationUuid, sinceSeq, limit: batchLimit);
    if (rows.isEmpty) {
      _send(PeerMessage.eventsBatch(const [], hasMore: false));
      return;
    }
    final payload = [
      for (final row in rows)
        PeerEventPayload(seq: row.seq, kind: row.kind, data: _decodeRow(row.data)).toJson(),
    ];
    final lastSeq = rows.last.seq;
    if (lastSeq > _lastSentSeq) _lastSentSeq = lastSeq;
    // `hasMore` is honest about the batch limit, not about whether the peer
    // has caught up with a log still being written: a full batch means ask
    // again, and the peer does exactly that on ack.
    _send(PeerMessage.eventsBatch(payload, hasMore: rows.length >= batchLimit));
  }

  Future<void> _onEvents(PeerMessage message) async {
    if (!_localTrusts || _peer == null) return;
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
    _send(PeerMessage.ack(highestSeq));
    _setState(message.hasMore ? PeerSessionState.syncing : PeerSessionState.live);
  }

  Future<void> _onAck(int seq) async {
    if (!_localTrusts) return;
    if (seq > _lastSentSeq) _lastSentSeq = seq;
    // Whatever the peer just acked may not have been everything — either the
    // batch hit its limit, or local writes landed while it was in flight.
    await _sendBatchAfter(seq);
  }

  Future<void> _pushLocal() async {
    if (_state != PeerSessionState.live && _state != PeerSessionState.syncing) return;
    if (!_localTrusts || !_peerTrustsUs) return;
    await _sendBatchAfter(_lastSentSeq);
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
