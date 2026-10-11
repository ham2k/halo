// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The BLE transport's policy (HALO-342), over the fake world: when it
// connects, when it deliberately does not, and that what it hands over
// honors the PeerLink contract.
//
// Real timers by DEFAULT — the delays under test ARE timer behavior — kept
// fast via injected durations, and asserted only in the direction a loaded
// machine cannot break: a timer can fire late, never early, so "not yet" is
// safe and "still, after a while" is not.
//
// An assertion that needs the UNSAFE direction — that something is still
// alive after a wait, which a timer firing late is exactly what breaks —
// does not belong on real timers at all. Put it on `fakeAsync`, and give
// whatever the code under test reads the time from the same fake clock, or
// the two run on different clocks and the test quietly stops testing. The
// keepalive test at the bottom is the worked example and the only one here
// that needs it.

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/ble/peer_ble_gateway.dart';
import 'package:ham2k_logger/services/peer/ble/peer_ble_transport.dart';

import '../support/peer_ble_fakes.dart';
import '../support/wait_for.dart';

class _Side {
  _Side(FakeBleWorld world, String address, this.deviceId) {
    gateway = world.gateway(address);
    transport = PeerBleTransport(
      gateway: gateway,
      localDeviceId: deviceId,
      onLink: links.add,
      connectedDeviceIds: () => connectedIds,
      onStatus: (problem) => status = problem,
      headStart: const Duration(milliseconds: 50),
      handshakeTimeout: const Duration(milliseconds: 500),
      jitter: false,
    );
  }

  final String deviceId;
  late final FakeBleGateway gateway;
  late final PeerBleTransport transport;
  final List<PeerLink> links = [];
  List<String> connectedIds = [];
  String? status;
}

void main() {
  late FakeBleWorld world;
  late _Side a;
  late _Side b;

  setUp(() {
    world = FakeBleWorld();
    // A's id sorts below B's, so A is the natural dialler when hints are
    // visible.
    a = _Side(world, 'addr-a', 'aaaaaaaa-1111-2222-3333-444444444444');
    b = _Side(world, 'addr-b', 'bbbbbbbb-1111-2222-3333-444444444444');
  });

  tearDown(() async {
    await a.transport.stop();
    await b.transport.stop();
  });

  Future<(PeerLink, PeerLink)> establishPair() async {
    await a.transport.start();
    await b.transport.start();
    // Only A hears the advertisement, so exactly one connection forms and
    // the test knows which side was central.
    world.tick(to: a.gateway);
    await waitFor('both sides to hand over a link', () => a.links.isNotEmpty && b.links.isNotEmpty);
    return (a.links.single, b.links.single);
  }

  test('two transports form one working link pair, message boundaries intact', () async {
    final (linkA, linkB) = await establishPair();

    final receivedOnB = <List<int>>[];
    final receivedOnA = <List<int>>[];
    linkB.inbound.listen(receivedOnB.add);
    linkA.inbound.listen(receivedOnA.add);

    // Bigger than the 30-byte fake chunk: this crosses fragmented and must
    // come out as ONE element, or PeerSession's decode gets garbage.
    final big = List<int>.generate(500, (i) => i & 0xFF);
    linkA.send(big);
    linkA.send([1, 2, 3]);
    linkB.send([9, 9]);

    await waitFor('messages to cross', () => receivedOnB.length == 2 && receivedOnA.length == 1);
    expect(receivedOnB[0], big);
    expect(receivedOnB[1], [1, 2, 3]);
    expect(receivedOnA[0], [9, 9]);
  });

  test('the PeerLink contract: close is idempotent, send after death never throws', () async {
    final (linkA, linkB) = await establishPair();

    await linkA.close();
    await linkA.close(); // idempotent
    await linkA.closed;
    // The far side learns through the disconnect, not through a message.
    await linkB.closed.timeout(const Duration(seconds: 5));

    // MUST NOT throw — callers write from timers with no try/catch.
    linkA.send([1, 2, 3]);
    linkB.send([4, 5, 6]);
  });

  test('a peer whose advertised token matches a connected device is not dialled', () async {
    await a.transport.start();
    await b.transport.start();
    // B's token is bbbbbbbb; A already holds a session with that device
    // (over LAN, say).
    a.connectedIds = ['bbbbbbbb-1111-2222-3333-444444444444'];
    world.tick(to: a.gateway);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(a.gateway.connectCalls, 0, reason: 'a BLE dial here could only be duplicate-closed; the hint exists to skip it');
  });

  test('the head start: no dial before the delay, a dial after it', () async {
    await a.transport.start();
    await b.transport.start();
    world.tick(to: a.gateway);
    // A timer can fire late but never early — this direction is safe on
    // any machine.
    expect(a.gateway.connectCalls, 0);
    await waitFor('the head-start delay to elapse', () => a.gateway.connectCalls > 0);
  });

  test('a link that dies young puts its address on cooldown', () async {
    final (linkA, _) = await establishPair();
    // The duplicate-session close, as PeerService would issue it.
    await linkA.close();
    // The transport's own closed-handler (which starts the cooldown) runs
    // as a separate microtask after the completer fires.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    a.links.clear();
    world.tick(to: a.gateway);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(a.gateway.connectCalls, 1, reason: 'redialling immediately after a young close is the churn loop the backoff exists for');
  });

  test('a mute peer times the handshake out instead of handing over a dead link', () async {
    // B advertises but its transport never runs — nothing will answer the
    // hello. Modeled by starting the server at the gateway level only.
    await b.gateway.startServer(localName: 'H2K:bbbbbbbb');
    await a.transport.start();
    world.tick(to: a.gateway);
    await waitFor('the dial to happen', () => a.gateway.connectCalls > 0);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(a.links, isEmpty, reason: 'a link whose handshake never completed must not reach PeerService');
  });

  test('stop() closes handed-off links on both sides — the switch means the radio goes quiet', () async {
    final (linkA, linkB) = await establishPair();
    await a.transport.stop();
    await linkA.closed.timeout(const Duration(seconds: 5));
    await linkB.closed.timeout(const Duration(seconds: 5));
  });

  test('a radio problem is reported, not swallowed', () async {
    a.gateway.readiness = const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth is turned off');
    await a.transport.start();
    expect(a.status, 'Bluetooth is turned off');
    // And recovery: the radio comes back, availability fires, roles start.
    a.gateway.readiness = const PeerBleReadiness(canCentral: true, canPeripheral: true);
    a.gateway.availability.add(null);
    await waitFor('the roles to start on recovery', () => a.gateway.advertising && a.gateway.scanning);
    expect(a.status, isNull);
  });

  test('packets arriving before the link object exists are buffered, not dropped', () async {
    // The real ordering: the peripheral fires its hello off the CCCD
    // subscription, DURING the central's connect — before _tryConnect has
    // a link to feed. The yields force that ordering through the fake so
    // the early-packet buffer actually runs; without them it is dead code
    // in every test. (The 1s hello retransmit would eventually recover a
    // dropped buffer too, so this pins the path, and the framing suite
    // pins the recovery.)
    a.gateway.connectYields = 12;
    await a.transport.start();
    await b.transport.start();
    world.tick(to: a.gateway);
    await waitFor('both sides to hand over a link', () => a.links.isNotEmpty && b.links.isNotEmpty);
  });

  test('a transient role-start failure is retried, not terminal for the session', () async {
    a.gateway.failScanStarts = 1;
    await a.transport.start();
    expect(a.gateway.scanning, isFalse);
    expect(a.status, contains('scan failed'));
    // No availability event, no switch toggle — the retry backoff alone
    // must bring the role up, or one refused scan means BLE is off until
    // the operator notices and flips something.
    await waitFor('the retry to start the scan', () => a.gateway.scanning, timeout: const Duration(seconds: 10));
    expect(a.status, isNull);
  });

  test('transient readiness — a manager still powering on — is retried until it settles', () async {
    // The trap this pins: the plugin's peripheral manager reports `unknown`
    // to the query that CREATED it and emits no event on settling, so
    // waiting for the availability stream here waits forever.
    a.gateway.readiness = const PeerBleReadiness(canCentral: true, canPeripheral: false, problem: 'cannot announce (unknown)', transient: true);
    await a.transport.start();
    expect(a.gateway.advertising, isFalse);
    expect(a.status, contains('cannot announce'));

    a.gateway.readiness = const PeerBleReadiness(canCentral: true, canPeripheral: true);
    // Deliberately NO availability event: the retry backoff alone must
    // re-prepare and bring the advertise role up.
    await waitFor('the retry to start advertising', () => a.gateway.advertising, timeout: const Duration(seconds: 10));
    expect(a.status, isNull);
  });

  test('only the first prepare may prompt for the OS permission', () async {
    await a.transport.start();
    expect(a.gateway.lastPrepareRequestedPermission, isTrue);
    a.gateway.availability.add(null);
    await waitFor('the re-prepare', () => a.gateway.prepareCalls >= 2);
    expect(a.gateway.lastPrepareRequestedPermission, isFalse, reason: 'a Bluetooth blip must never pop a permission dialog the operator did not invite');
  });

  test('the keepalive clock does NOT time travel', () {
    // `realNowMillis` is what keeps the keepalive measuring real silence;
    // `nowMillis` instead reads as an ordinary application of the house rule,
    // and scripts/test.sh's clock-discipline check would not fire. The whole
    // suite would stay green while a developer time-travelling the app
    // dropped every BLE link on the network at once, mid-field-day, for
    // reasons nothing would explain. On the app clock, three days of travel
    // read as three days of silence at the next keepalive tick.
    final followed = AppClock.followZoneClock;
    AppClock.followZoneClock = true;
    addTearDown(() => AppClock.followZoneClock = followed);
    addTearDown(AppClock.instance.reset);
    fakeAsync((async) {
      late PeerBleLink linkA;
      late PeerBleLink linkB;
      linkA = PeerBleLink(
        sendPacket: (packet) async => linkB.feed(packet),
        shutdown: () async {},
        keepaliveInterval: const Duration(milliseconds: 50),
        idleCutoff: const Duration(milliseconds: 200),
      );
      linkB = PeerBleLink(
        sendPacket: (packet) async => linkA.feed(packet),
        shutdown: () async {},
        keepaliveInterval: const Duration(milliseconds: 50),
        idleCutoff: const Duration(milliseconds: 200),
      );
      var aClosed = false;
      unawaited(linkA.closed.then((_) => aClosed = true));
      linkA.start(50);
      linkB.start(50);
      async.flushMicrotasks();

      AppClock.instance.travel(delta: const Duration(days: 3));
      async.elapse(const Duration(milliseconds: 100));
      expect(aClosed, isFalse, reason: 'a protocol timeout reads the real clock (docs/design/time.md §1)');

      unawaited(linkA.close());
      unawaited(linkB.close());
      async.flushMicrotasks();
    });
  });

  test('keepalive: a silent peer is dropped, a pinging one is kept', () {
    // The ONE test in this file on a fake clock, and it has to be: every
    // other test here asserts only in the direction a loaded machine cannot
    // break (see the header — a timer can fire late, never early). This one
    // asserts a link is STILL OPEN after a while, which a keepalive firing
    // late is exactly what breaks. On real timers it failed under a loaded
    // suite, and the failure landed on whichever test ran next.
    //
    // The link's staleness check reads the real clock and its pings come off
    // a Timer — two different clocks unless something drives both. With the
    // app clock following the fake one `elapse` advances, they move in
    // lockstep and every gap below is exact rather than a bet on scheduler
    // latency.
    final followed = AppClock.followZoneClock;
    AppClock.followZoneClock = true;
    addTearDown(() => AppClock.followZoneClock = followed);
    fakeAsync((async) {
      // Link-level, wired directly — the death being detected is the one the
      // radio cannot report.
      Future<void> Function(Uint8List) feedInto(PeerBleLink Function() link, bool Function() drop) {
        return (packet) async {
          if (!drop()) link().feed(packet);
        };
      }

      var dropTowardsA = false;
      late PeerBleLink linkA;
      late PeerBleLink linkB;
      linkA = PeerBleLink(
        sendPacket: feedInto(() => linkB, () => false),
        shutdown: () async {},
        keepaliveInterval: const Duration(milliseconds: 50),
        idleCutoff: const Duration(milliseconds: 200),
      );
      linkB = PeerBleLink(
        sendPacket: feedInto(() => linkA, () => dropTowardsA),
        shutdown: () async {},
        keepaliveInterval: const Duration(milliseconds: 50),
        idleCutoff: const Duration(milliseconds: 200),
      );
      var aReady = false;
      var bReady = false;
      unawaited(linkA.ready.then((value) => aReady = value));
      unawaited(linkB.ready.then((value) => bReady = value));
      var aClosed = false;
      unawaited(linkA.closed.then((_) => aClosed = true));

      linkA.start(50);
      linkB.start(50);
      async.flushMicrotasks();
      expect(aReady && bReady, isTrue, reason: 'the handshake crosses without any time passing');

      // Healthy but idle: pings alone must keep it alive well past the
      // cutoff. Two and a half seconds of it — twelve cutoffs' worth, which
      // on the real clock would have meant sleeping for exactly that long.
      async.elapse(const Duration(milliseconds: 2500));
      expect(aClosed, isFalse, reason: 'pings are proof of life; an idle link is not a dead one');

      // Now B's traffic stops reaching A entirely. A hears nothing, and its
      // own pings still leave — so only the staleness check can notice.
      dropTowardsA = true;
      // Comfortably INSIDE the cutoff, not exactly on it: landing on the
      // boundary tick would pin `>` against `>=`, and one millisecond of a
      // 65-second protocol timeout is nobody's intended invariant — it would
      // only make a behaviourally identical refactor fail.
      async.elapse(const Duration(milliseconds: 150));
      expect(aClosed, isFalse, reason: 'the cutoff spans three missed pings; one is not a death');
      async.elapse(const Duration(milliseconds: 150));
      expect(aClosed, isTrue, reason: 'silent past the cutoff, so the link is dropped');

      unawaited(linkB.close());
      async.flushMicrotasks();
    });
  });
}
