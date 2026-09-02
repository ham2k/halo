// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The contest serial numbers this device is holding for the contacts being
// composed, held against every other position sharing an operation
// (docs/design/contests.md §5.8.1, HALO-476).
//
// The one rule everything here serves: a number the operator has been shown
// is never changed. So the negotiation — hearing the other positions'
// claims, losing a tie-break, redrawing — all happens BEFORE `claim`
// resolves, and anything that arrives afterwards is recorded on the QSO
// rather than acted on.
//
// Claims are announcements, not requests. Two positions that claim one
// number inside a round trip each hear the other's and apply the same
// tie-break, so no reply is needed for that to come out right. The ack
// exists to answer a different question — has every live peer heard this
// claim, so no crossing one is still in flight? — and that wait is the only
// thing a claimant blocks on, capped because the human reading the number is
// still typing the callsign.
//
// Every peer sharing the operation competes today. Should peers ever carry a
// role — a position that logs, against a bridge or a spectator that never
// will — only the logging ones need consulting here, and the roster this
// waits on is the place to narrow it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// Sends [message] to [peerDeviceId]; false when it went nowhere.
typedef SerialClaimSend = bool Function(String peerDeviceId, PeerMessage message);

class _LocalClaim {
  final String operationUuid;
  final String label;
  int number;

  /// The claim round this number was announced in. A peer acks a round, and
  /// only the current one counts — an ack for a number since redrawn is stale.
  int seq;

  /// Live peers still to acknowledge [seq]; empty means shown (or showable).
  final Set<String> awaiting = {};
  final Completer<int> settled = Completer<int>();
  Timer? deadline;

  /// Set once the operator has (or may have) read the number: from here on
  /// a losing tie-break marks the claim rather than redrawing it.
  bool shown = false;
  bool conflicted = false;

  _LocalClaim(this.operationUuid, this.label, this.number, this.seq);
}

class SerialClaims extends ChangeNotifier implements SerialNumberSource {
  SerialClaims({
    required this.localDeviceId,
    required this.peek,
    required this.livePeers,
    required this.send,
    this.onCommittedConflict,
    this.ackTimeout = const Duration(milliseconds: 500),
    this.committedGrace = const Duration(seconds: 60),
  });

  /// A number this device already LOGGED turns out to have been shown on
  /// another position too — the loser's mark arrived after the commit, so
  /// the record here has to be marked after the fact.
  final void Function(String operationUuid, SequenceRequest request, int number)? onCommittedConflict;

  /// The tie-break: of two positions claiming one number, the lower device
  /// id keeps it. Any stable total order would do; this one needs no
  /// negotiation.
  final String localDeviceId;

  /// The sequence's own next number — `SequencesRepository.peek` — which a
  /// claim starts from and the peers' holds move past.
  final Future<int> Function(String operationUuid, SequenceRequest request) peek;

  /// The peers a claim is announced to — every established session, on any
  /// transport. A peer on Bluetooth is in the round like any other: leaving
  /// it out saves a wait and costs a duplicate number on the air. Which of
  /// them a claim then WAITS on is narrower: see [_quiet].
  final Iterable<String> Function() livePeers;
  final SerialClaimSend send;

  /// How long a claim waits for acks before showing regardless. Set by the
  /// human, not the network: the claim is taken on the first edit, and nobody
  /// reads the number aloud before finishing the callsign. Real time, never
  /// the app clock — it bounds a wire exchange.
  final Duration ackTimeout;

  /// How long a number this device just LOGGED stays announced as held. The
  /// QSO reaches the peers through the durable sync a moment later and their
  /// `peek` then skips it on its own; until it does, a claim released the
  /// instant it was committed would hand the same number to the next
  /// position to start typing.
  final Duration committedGrace;

  /// This device's claims, by operation then label. Several operations can
  /// be composing at once — an operation opened over another keeps the one
  /// underneath, and its number, exactly where they were.
  final Map<String, Map<String, _LocalClaim>> _local = {};

  /// Numbers committed within [committedGrace], still announced. Operation
  /// to label to number, with the request it was issued under (what a
  /// write-back needs) and the timer that retires it.
  final Map<String, Map<String, Map<int, ({SequenceRequest request, Timer timer})>>> _committed = {};

  /// Every operation this device has held a number in, so a reconnect
  /// snapshot can say "nothing any more" for one it has since let go.
  final Set<String> _touchedOperations = {};

  /// What each peer holds, by operation then label — the latest set it
  /// announced for that operation, every number on the label (a live claim
  /// beside a just-committed one, say). Kept whatever THIS device has open:
  /// a peer's hold on an operation this device opens a minute later has to
  /// be known by then, not re-learned — and kept through a session drop: a
  /// phone asleep in a pocket still holds its number until it comes back
  /// and says otherwise.
  final Map<String, Map<String, Map<String, List<PeerSerialClaim>>>> _peerClaims = {};

  /// The last version seen from each peer; a strictly newer one is acked, once.
  final Map<String, int> _peerSeq = {};

  /// Peers that let a claim round run to the cap. A session can stay
  /// established for minutes after the device behind it went to sleep, and a
  /// peer on a build predating this message never answers at all — so a peer
  /// that has missed one deadline is not waited on again until it next says
  /// anything. It is still TOLD every claim: waking up, it must skip them.
  final Set<String> _quiet = {};

  int _seq = 0;

  /// What this device holds on [operationUuid], as its peers are told it.
  List<PeerSerialClaim> localClaimsFor(String operationUuid) => [
        for (final claim in (_local[operationUuid] ?? const {}).values)
          PeerSerialClaim(label: claim.label, number: claim.number, conflicted: claim.conflicted),
        for (final entry in (_committed[operationUuid] ?? const {}).entries)
          for (final number in entry.value.keys) PeerSerialClaim(label: entry.key, number: number, committed: true),
      ];

  /// The peers' holds on [label] in [operationUuid], by device.
  Map<String, Set<int>> peerClaimsFor(String operationUuid, String label) => {
        for (final entry in _peerClaims.entries)
          if (entry.value[operationUuid]?[label] case final claims?)
            if (claims.isNotEmpty) entry.key: {for (final claim in claims) claim.number},
      };

  /// Whether [peerDeviceId] is currently one a claim does not wait on.
  @visibleForTesting
  bool isQuiet(String peerDeviceId) => _quiet.contains(peerDeviceId);

  /// Test seam: what one missed deadline does, without waiting for one.
  @visibleForTesting
  void markQuiet(String peerDeviceId) => _quiet.add(peerDeviceId);

  /// Every number a peer or a fresh commit holds on [label] here.
  Set<int> _taken(String operationUuid, String label) => {
        for (final numbers in peerClaimsFor(operationUuid, label).values) ...numbers,
        ...?_committed[operationUuid]?[label]?.keys,
      };

  @override
  Future<int> claim(String operationUuid, SequenceRequest request) async {
    _touchedOperations.add(operationUuid);
    final claims = _local[operationUuid] ??= {};
    if (claims[request.label] case final existing?) return existing.settled.future;

    final number = await _nextFree(operationUuid, request);
    // `_nextFree` awaited the database; a wipe or a competing claim may have
    // landed meanwhile, and the later one wins the slot.
    if (claims[request.label] case final raced?) return raced.settled.future;
    final claim = _LocalClaim(operationUuid, request.label, number, ++_seq);
    claims[request.label] = claim;
    _announce(claim);
    return claim.settled.future;
  }

  @override
  void release(String operationUuid, {Map<SequenceRequest, int> committed = const {}, Set<String>? labels}) {
    final claims = _local[operationUuid];
    var changed = false;
    if (claims != null) {
      for (final label in labels ?? claims.keys.toList()) {
        final claim = claims.remove(label);
        if (claim == null) continue;
        changed = true;
        claim.deadline?.cancel();
        // A claim released before it settled resolves to what it held — the
        // caller has already stopped caring, and a dangling future leaks.
        if (!claim.settled.isCompleted) claim.settled.complete(claim.number);
      }
      if (claims.isEmpty) _local.remove(operationUuid);
    }
    for (final entry in committed.entries) {
      changed = true;
      _touchedOperations.add(operationUuid);
      final label = entry.key.label;
      final holds = (_committed[operationUuid] ??= {})[label] ??= {};
      holds[entry.value]?.timer.cancel();
      holds[entry.value] = (
        request: entry.key,
        timer: Timer(committedGrace, () {
          final byLabel = _committed[operationUuid];
          final numbers = byLabel?[label];
          if (byLabel == null || numbers == null) return;
          numbers.remove(entry.value);
          if (numbers.isEmpty) byLabel.remove(label);
          if (byLabel.isEmpty) _committed.remove(operationUuid);
          _broadcast(operationUuid);
        }),
      );
    }
    if (!changed) return;
    _broadcast(operationUuid);
    notifyListeners();
  }

  /// Every hold this device has, gone — peer sharing switched off. Nothing
  /// announces it: the peers' sessions are about to drop, and a hold they
  /// keep for a device that left costs a gap, never a duplicate.
  void releaseAll() {
    for (final operationUuid in _local.keys.toList()) {
      for (final claim in _local[operationUuid]!.values) {
        claim.deadline?.cancel();
        if (!claim.settled.isCompleted) claim.settled.complete(claim.number);
      }
    }
    _local.clear();
    for (final byLabel in _committed.values) {
      for (final holds in byLabel.values) {
        for (final hold in holds.values) {
          hold.timer.cancel();
        }
      }
    }
    _committed.clear();
    notifyListeners();
  }

  @override
  bool isConflicted(String operationUuid, SequenceRequest request, int number) {
    final claim = _local[operationUuid]?[request.label];
    return claim != null && claim.number == number && claim.conflicted;
  }

  /// A peer announced (or acknowledged with) its claim set for one operation.
  void onPeerClaims(String peerDeviceId, PeerSerialClaimsPayload payload) {
    // Anything at all from a peer means it is awake and answering.
    _quiet.remove(peerDeviceId);

    // `seq` versions the sender's state: a message at or past the last one
    // seen carries that operation's current set (an ack re-sends it,
    // unbumped), an older one is a straggler and says nothing. Only a strictly
    // newer version is acked, and once.
    final previous = _peerSeq[peerDeviceId];
    final isNewRound = previous == null || payload.seq > previous;
    if (previous == null || payload.seq >= previous) {
      _peerSeq[peerDeviceId] = payload.seq;
      final byLabel = <String, List<PeerSerialClaim>>{};
      for (final claim in payload.claims) {
        (byLabel[claim.label] ??= []).add(claim);
      }
      (_peerClaims[peerDeviceId] ??= {})[payload.operationUuid] = byLabel;
    }

    // Tie-breaks BEFORE the ack is counted: an ack can carry the crossing
    // claim itself, and settling first would show a number about to be lost.
    var marked = false;
    final mineByLabel = _local[payload.operationUuid] ?? const <String, _LocalClaim>{};
    for (final theirs in payload.claims) {
      // A mark on a number this device has already logged: the record is
      // in the database, so the alert goes on after the fact.
      if (theirs.conflicted) {
        final hold = _committed[payload.operationUuid]?[theirs.label]?[theirs.number];
        if (hold != null) onCommittedConflict?.call(payload.operationUuid, hold.request, theirs.number);
      }
      final mine = mineByLabel[theirs.label];
      if (mine == null || mine.number != theirs.number) continue;
      // Theirs stands regardless of id when it is already in their log
      // (committed), or when they kept it after losing — their operator may
      // have sent it. Otherwise the lower device id keeps the number.
      final theirsStands = theirs.committed || theirs.conflicted || peerDeviceId.compareTo(localDeviceId) < 0;
      if (!theirsStands) continue;
      if (mine.shown) {
        marked = marked || !mine.conflicted;
        mine.conflicted = true;
      } else {
        _redraw(mine);
      }
    }

    if (payload.ack case final acked?) {
      for (final claim in mineByLabel.values) {
        if (claim.seq == acked && claim.awaiting.remove(peerDeviceId)) _maybeSettle(claim);
      }
    }

    // Ack a version exactly once — a re-announced set with the same seq is
    // the snapshot a reconnect sends, not a new round. A conflict this
    // device just recorded has to reach the winner too, which the ack carries
    // when there is one and a broadcast does otherwise.
    if (isNewRound && payload.ack == null) {
      _ackTo(peerDeviceId, payload);
    } else if (marked) {
      _broadcast(payload.operationUuid);
    }
    notifyListeners();
  }

  /// A peer's session dropped. What it held STAYS held: its operator may be
  /// mid-contact on a phone that went to sleep, and the number they read
  /// aloud is theirs until they come back and say otherwise ([peerEstablished]).
  /// Only its pending ack is let go, or every claim in flight would sit out
  /// the whole timeout for a device that is gone.
  void forgetPeer(String peerDeviceId) {
    for (final claims in _local.values) {
      for (final claim in claims.values) {
        if (claim.awaiting.remove(peerDeviceId)) _maybeSettle(claim);
      }
    }
    notifyListeners();
  }

  /// A peer's session (re)established. Whatever was on its books is dropped
  /// in favour of the snapshot it sends now, which says what it still holds
  /// — a wipe while it was away, or a restart, is otherwise a hold nothing
  /// ever lifts. Its version counter starts over with it, since a restarted
  /// peer's counts from zero; and this device's own holds go to it, so a
  /// position arriving between two keystrokes still skips them.
  void peerEstablished(String peerDeviceId) {
    _peerClaims.remove(peerDeviceId);
    _peerSeq.remove(peerDeviceId);
    _quiet.remove(peerDeviceId);
    snapshotTo(peerDeviceId);
    notifyListeners();
  }

  /// This device's holds, per operation it has ever held one in — an empty
  /// set included, which is how an operation let go while apart is cleared.
  void snapshotTo(String peerDeviceId) {
    for (final operationUuid in _touchedOperations) {
      send(
        peerDeviceId,
        PeerMessage.serialClaims(
          operationUuid: operationUuid,
          seq: _seq,
          claims: localClaimsFor(operationUuid),
        ),
      );
    }
  }

  Future<int> _nextFree(String operationUuid, SequenceRequest request) async {
    var number = await peek(operationUuid, request);
    final taken = _taken(operationUuid, request.label);
    while (taken.contains(number)) {
      number++;
    }
    return number;
  }

  void _announce(_LocalClaim claim) {
    final message = PeerMessage.serialClaims(
      operationUuid: claim.operationUuid,
      seq: claim.seq,
      claims: localClaimsFor(claim.operationUuid),
    );
    claim.awaiting.clear();
    for (final peerDeviceId in livePeers()) {
      if (!send(peerDeviceId, message)) continue;
      if (!_quiet.contains(peerDeviceId)) claim.awaiting.add(peerDeviceId);
    }
    claim.deadline?.cancel();
    if (claim.awaiting.isEmpty) {
      _settle(claim);
      return;
    }
    claim.deadline = Timer(ackTimeout, () {
      // Whoever has not answered by now is not waited on next time.
      _quiet.addAll(claim.awaiting);
      _settle(claim);
    });
  }

  /// This device's number is not going to stand and nothing has been shown:
  /// take the next free number above it and start the round again. Counted
  /// up from the lost number rather than re-peeked, so it needs no database
  /// round trip and can never land back on the number just conceded.
  void _redraw(_LocalClaim claim) {
    claim.deadline?.cancel();
    var number = claim.number + 1;
    final taken = _taken(claim.operationUuid, claim.label);
    while (taken.contains(number)) {
      number++;
    }
    claim.number = number;
    claim.seq = ++_seq;
    _announce(claim);
  }

  void _maybeSettle(_LocalClaim claim) {
    if (claim.awaiting.isEmpty && !claim.shown) _settle(claim);
  }

  void _settle(_LocalClaim claim) {
    claim.deadline?.cancel();
    claim.deadline = null;
    claim.awaiting.clear();
    if (claim.shown) return;
    claim.shown = true;
    if (!claim.settled.isCompleted) claim.settled.complete(claim.number);
    notifyListeners();
  }

  /// Answers [payload]'s round with this device's own holds on the same
  /// operation — empty when it has none there, which is itself the answer.
  void _ackTo(String peerDeviceId, PeerSerialClaimsPayload payload) {
    send(
      peerDeviceId,
      PeerMessage.serialClaims(
        operationUuid: payload.operationUuid,
        seq: _seq,
        claims: localClaimsFor(payload.operationUuid),
        ack: payload.seq,
      ),
    );
  }

  /// The current set for [operationUuid] to every live peer, outside a claim
  /// round: a release, or a kept-after-conflict mark the winner has to hear
  /// about. A new version, so a peer that saw the previous set takes this one.
  void _broadcast(String operationUuid) {
    final message = PeerMessage.serialClaims(
      operationUuid: operationUuid,
      seq: ++_seq,
      claims: localClaimsFor(operationUuid),
    );
    for (final peerDeviceId in livePeers()) {
      // Every later message carries the whole set again, so a drop costs
      // nothing lasting — but a live peer refusing a send is worth a trace.
      if (!send(peerDeviceId, message)) debugPrint('[peer] serialClaims to $peerDeviceId went nowhere');
    }
  }

  @override
  void dispose() {
    releaseAll();
    super.dispose();
  }
}
