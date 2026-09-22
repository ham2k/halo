// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Serial claims across positions (docs/design/contests.md §5.8.1, HALO-476).
// The rule under test throughout: a number a device has resolved for the
// operator is never changed afterwards — every collision is settled before
// `claim` completes, and anything later is a mark on the QSO, not a redraw.
//
// Two services are wired to each other directly, each delivery deferred by
// one event-loop turn so that two claims made in the same turn cross on the
// wire the way they do on a LAN. Nothing here touches a database: `peek` is
// a counter the test owns.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/serial_claims.dart';

const _op = 'op-1';
const _descriptor = SequenceDescriptor(refType: 'cqwpx', field: 'ourSerial', key: 'cqwpx/serial');
const _perBand = SequenceDescriptor(refType: 'r1vhf', field: 'serial', key: 'r1vhf/serial', scope: ['band']);

SequenceRequest _request({String band = '20m'}) => _descriptor.requestFor(Qso(uuid: '', operationUuid: _op, data: {'band': band, 'mode': 'CW'}));

SequenceRequest _bandRequest(String band) => _perBand.requestFor(Qso(uuid: '', operationUuid: _op, data: {'band': band, 'mode': 'CW'}));

/// A LAN of [SerialClaims], delivering with a one-turn delay — or holding a
/// device's outbound traffic back entirely, for the straggler cases.
class _Lan {
  final Map<String, SerialClaims> devices = {};
  final Set<String> offline = {};

  /// Messages parked instead of delivered, per sender — released by [flush].
  final Map<String, List<(String, PeerMessage)>> held = {};
  final Set<String> holding = {};

  /// What crossed the wire, for assertions on traffic.
  final List<(String from, String to, PeerMessage message)> log = [];

  SerialClaims add(String deviceId, {int next = 1, Duration ackTimeout = const Duration(milliseconds: 50)}) {
    var counter = next;
    final service = SerialClaims(
      localDeviceId: deviceId,
      peek: (_, _) async => counter,
      livePeers: () => [
        for (final id in devices.keys)
          if (id != deviceId && !offline.contains(id)) id,
      ],
      send: (to, message) => _send(deviceId, to, message),
      ackTimeout: ackTimeout,
      committedGrace: const Duration(milliseconds: 200),
    );
    devices[deviceId] = service;
    return service;
  }

  bool _send(String from, String to, PeerMessage message) {
    if (offline.contains(to)) return false;
    log.add((from, to, message));
    if (holding.contains(from)) {
      (held[from] ??= []).add((to, message));
      return true;
    }
    _deliver(from, to, message);
    return true;
  }

  void _deliver(String from, String to, PeerMessage message) {
    Future(() {
      final payload = message.serialClaimsOrNull;
      if (payload != null) devices[to]?.onPeerClaims(from, payload);
    });
  }

  Future<void> flush(String from) async {
    holding.remove(from);
    for (final (to, message) in held.remove(from) ?? const <(String, PeerMessage)>[]) {
      _deliver(from, to, message);
    }
    await settle();
  }

  /// Lets every deferred delivery land.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void dispose() {
    for (final device in devices.values) {
      device.dispose();
    }
  }
}

void main() {
  late _Lan lan;

  setUp(() => lan = _Lan());
  tearDown(() async {
    // The last acks are still crossing the fake wire when a test ends.
    await lan.settle();
    lan.dispose();
  });

  test('alone, the number is the sequence\'s next, straight away', () async {
    final a = lan.add('a', next: 7);
    expect(await a.claim(_op, _request()), 7);
  });

  test('a peer\'s held number is skipped', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    await lan.settle();
    // Same log, same peek — the only reason B takes 2 is that A holds 1.
    expect(await b.claim(_op, _request()), 2);
  });

  test('two claims that cross settle to different numbers before either is shown', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    // Same turn: neither has heard the other when it picks 1.
    final first = a.claim(_op, _request());
    final second = b.claim(_op, _request());
    final numbers = await Future.wait([first, second]);
    // 'a' sorts lower and keeps 1; 'b' redraws to 2. The tie-break is the
    // same on both sides, so no reply was needed to agree.
    expect(numbers, [1, 2]);
    expect(a.isConflicted(_op, _request(), 1), isFalse);
    expect(b.isConflicted(_op, _request(), 2), isFalse);
  });

  test('a claim waits for the live peers\' acks, not the timeout', () async {
    // With an hour's cap, the only thing that can settle this inside the
    // test's own timeout is b's ack — the assertion is that it completes.
    final a = lan.add('a', ackTimeout: const Duration(hours: 1));
    lan.add('b', ackTimeout: const Duration(hours: 1));
    expect(await a.claim(_op, _request()), 1);
    expect(lan.log.where((m) => m.$1 == 'b' && m.$3.serialClaimsOrNull?.ack != null), isNotEmpty);
  });

  test('a peer that is not live is not waited on', () async {
    final a = lan.add('a', ackTimeout: const Duration(hours: 1));
    lan.add('b', ackTimeout: const Duration(hours: 1));
    lan.offline.add('b');
    expect(await a.claim(_op, _request()), 1);
  });

  test('a peer that let a round run to the cap is quiet from then on', () async {
    final a = lan.add('a', ackTimeout: const Duration(milliseconds: 30));
    lan.add('b');
    lan.holding.add('b'); // b's acks never leave: asleep, or an older build
    expect(await a.claim(_op, _request()), 1);
    expect(a.isQuiet('b'), isTrue);
    // b speaks — its held acks flush — and is waited on again.
    await lan.flush('b');
    expect(a.isQuiet('b'), isFalse);
  });

  test('a quiet peer is told the claim but not waited on', () async {
    // An hour's cap: only NOT waiting on b can settle this inside the test.
    final a = lan.add('a', ackTimeout: const Duration(hours: 1));
    lan.add('b');
    lan.holding.add('b');
    a.markQuiet('b');
    expect(await a.claim(_op, _request()), 1);
    expect(lan.log.where((m) => m.$1 == 'a' && m.$2 == 'b'), isNotEmpty, reason: 'still told, so it skips 1 on waking');
  });

  test('a committed number stands against a lower device id', () async {
    final a = lan.add('a', ackTimeout: const Duration(milliseconds: 20));
    final b = lan.add('b', ackTimeout: const Duration(milliseconds: 20));
    // b shows 1 while a hears nothing, and logs it.
    lan.holding.add('b');
    expect(await b.claim(_op, _request()), 1);
    b.release(_op, committed: {_request(): 1});
    // a, which would win a tie-break on id, claims 1 before b's news arrives.
    lan.holding.add('a');
    final pending = a.claim(_op, _request());
    await lan.flush('b');
    // b's announced set says 1 is in a log already: a redraws, being unshown.
    expect(await pending, 2);
  });

  test('a conflict heard before showing redraws instead of marking', () async {
    final a = lan.add('a', ackTimeout: const Duration(milliseconds: 20));
    final b = lan.add('b', ackTimeout: const Duration(milliseconds: 20));
    lan.holding.add('b');
    expect(await b.claim(_op, _request()), 1);
    // a claims 1; b (shown) loses and marks. a has shown nothing when the
    // mark arrives, so a can still take 2 and no QSO needs the alert.
    lan.holding.add('a');
    final pending = a.claim(_op, _request());
    await lan.settle();
    await lan.flush('a');
    await lan.flush('b');
    expect(await pending, 2);
    expect(a.isConflicted(_op, _request(), 2), isFalse);
    expect(b.isConflicted(_op, _request(), 1), isTrue, reason: 'b kept it: its operator may have sent it');
  });

  test('an ack for another operation does not overwrite what the acker holds elsewhere', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    await lan.settle();
    // b claims on op-2; a acks with what it holds on op-2 (nothing).
    expect(await b.claim('op-2', _request()), 1);
    await lan.settle();
    // a's hold on op-1 is still on b's books.
    expect(await b.claim(_op, _request()), 2);
  });

  test('two operations composing at once each hold their own', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    expect(await a.claim('op-2', _request()), 1);
    await lan.settle();
    a.release('op-2');
    await lan.settle();
    expect(await b.claim(_op, _request()), 2, reason: 'releasing op-2 left op-1\'s hold standing');
  });

  test('a band change lets go of the moved label only', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    expect(await a.claim(_op, _bandRequest('2m')), 1);
    await lan.settle();
    a.release(_op, labels: {_bandRequest('2m').label});
    await lan.settle();
    expect(await b.claim(_op, _bandRequest('2m')), 1, reason: 'the moved label is free');
    expect(await b.claim(_op, _request()), 2, reason: 'the unscoped one is still held');
  });

  test('a peer that never acks costs the cap, then the number shows anyway', () async {
    final a = lan.add('a', ackTimeout: const Duration(milliseconds: 30));
    lan.add('b');
    lan.holding.add('b'); // b receives, but its ack never leaves
    expect(await a.claim(_op, _request()), 1);
  });

  test('a losing claim that arrives after the number was shown is kept, and both sides mark it', () async {
    final a = lan.add('a', ackTimeout: const Duration(milliseconds: 20));
    final b = lan.add('b', ackTimeout: const Duration(milliseconds: 20));
    // b's traffic is stuck. b claims 1, hears no ack, and shows it at the
    // cap — its operator may be reading it aloud from here on.
    lan.holding.add('b');
    expect(await b.claim(_op, _request()), 1);
    // a has heard nothing from b, so it claims 1 too; a's claim reaches b,
    // which loses the tie-break — after showing. It keeps the number.
    expect(await a.claim(_op, _request()), 1, reason: 'a wins the tie-break, and heard no ack to say otherwise');
    expect(b.isConflicted(_op, _request(), 1), isTrue, reason: 'kept, not redrawn: the operator may have sent it');
    // b's mark reaches a once its traffic flows, so the winner's QSO carries
    // the alert as well — the log checker sees two, whichever device logs.
    await lan.flush('b');
    expect(a.isConflicted(_op, _request(), 1), isTrue);
  });

  test('a wipe releases the number for the next position', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    await lan.settle();
    a.release(_op);
    await lan.settle();
    expect(await b.claim(_op, _request()), 1);
  });

  test('a number just committed stays held until the log can carry it', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    await lan.settle();
    // Committed, so a's own claim is gone — but b's peek has not seen the
    // QSO yet, and would hand out 1 again without the grace hold.
    a.release(_op, committed: {_request(): 1});
    await lan.settle();
    expect(await b.claim(_op, _request()), 2);
    b.release(_op);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await lan.settle();
    // Grace over: from here the log is what keeps 1 from being reissued.
    expect(await b.claim(_op, _request()), 1);
  });

  test('sequences with different labels never compete', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _bandRequest('2m')), 1);
    await lan.settle();
    expect(await b.claim(_op, _bandRequest('70cm')), 1);
  });

  test('a peer arriving mid-contact is sent what is held', () async {
    final a = lan.add('a');
    expect(await a.claim(_op, _request()), 1);
    final b = lan.add('b');
    a.snapshotTo('b');
    await lan.settle();
    expect(await b.claim(_op, _request()), 2);
    expect(b.peerClaimsFor(_op, _request().label), {
      'a': {1},
    });
  });

  test('a peer whose session drops keeps its hold, and a claim waiting on it stops waiting', () async {
    final a = lan.add('a', ackTimeout: const Duration(hours: 1));
    final b = lan.add('b');
    expect(await b.claim(_op, _request()), 1);
    await lan.settle();
    lan.holding.add('b');
    final pending = a.claim(_op, _request());
    await lan.settle();
    // The phone went to sleep mid-contact. Its operator read 1 aloud.
    lan.offline.add('b');
    a.forgetPeer('b');
    expect(await pending, 2, reason: 'not waited on, but 1 is still theirs');
    a.release(_op);
    expect(await a.claim(_op, _request()), 2, reason: 'still theirs until they come back and say otherwise');
  });

  test('a peer coming back is taken at its word — the snapshot replaces what it held', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await b.claim(_op, _request()), 1);
    await lan.settle();
    lan.offline.add('b');
    a.forgetPeer('b');
    // b wiped while apart, then reconnects: its snapshot for op-1 is empty.
    b.release(_op);
    lan.offline.remove('b');
    a.peerEstablished('b');
    b.peerEstablished('a');
    await lan.settle();
    expect(a.peerClaimsFor(_op, _request().label), isEmpty);
    expect(await a.claim(_op, _request()), 1);
  });

  test('a live claim beside a just-committed number are both skipped', () async {
    // The announced set carries both on one label; losing either to the
    // other is the collision this exists to prevent.
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    a.release(_op, committed: {_request(): 1});
    expect(await a.claim(_op, _request()), 2);
    await lan.settle();
    expect(b.peerClaimsFor(_op, _request().label), {
      'a': {1, 2},
    });
    expect(await b.claim(_op, _request()), 3);
  });

  test('a conflict on a number already logged here is written back', () async {
    final marked = <(String, String, int)>[];
    final a = SerialClaims(
      localDeviceId: 'a',
      peek: (_, _) async => 1,
      livePeers: () => const ['b'],
      send: (_, _) => true,
      onCommittedConflict: (op, request, number) => marked.add((op, request.label, number)),
    );
    addTearDown(a.dispose);
    expect(await a.claim(_op, _request()), 1);
    a.release(_op, committed: {_request(): 1});
    // b showed 1 before hearing anything, lost, and kept it — its mark lands
    // after a's QSO is in the database.
    a.onPeerClaims(
      'b',
      PeerSerialClaimsPayload(
        operationUuid: _op,
        seq: 1,
        claims: [PeerSerialClaim(label: _request().label, number: 1, conflicted: true)],
      ),
    );
    expect(marked, [(_op, _request().label, 1)]);
  });

  test('switching sharing off lets every hold go', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim(_op, _request()), 1);
    expect(await a.claim('op-2', _request()), 1);
    await lan.settle();
    a.releaseAll();
    expect(a.localClaimsFor(_op), isEmpty);
    expect(a.localClaimsFor('op-2'), isEmpty);
    // Peers are not told (their sessions are about to drop) — b's knowledge
    // is stale until a is re-established, which is the cost accepted.
    expect(b.peerClaimsFor(_op, _request().label), {
      'a': {1},
    });
  });

  test('claims for another operation are answered but never compete', () async {
    final a = lan.add('a');
    final b = lan.add('b');
    expect(await a.claim('op-2', _request()), 1);
    await lan.settle();
    expect(await b.claim(_op, _request()), 1);
    expect(b.peerClaimsFor(_op, _request().label), isEmpty);
  });
}
