// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PeerService end to end (HALO-310): two services finding each other by
// beacon, pairing, and syncing a log — the closest thing to "two devices at
// a park" this suite can run.
//
// Both run the REAL beacon socket, link handling and sessions; only the
// sockets underneath are fake (`peer_network_fakes.dart`), so the test never
// depends on the machine's network, never collides with a HaLo running on
// the standard port, and never puts a broadcast on the operator's LAN.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';

import 'support/peer_network_fakes.dart';

/// Polls until [condition] holds, so a test waits on the thing it cares
/// about rather than on a guessed sleep. Real sockets and timers are
/// involved, so there is no fixed number of pumps that is both reliable and
/// quick.
Future<void> waitFor(
  String what,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('timed out waiting for: $what');
}

class _Device {
  _Device(this.deviceId, this.name, FakeHost host) {
    db = HaLoDatabase(NativeDatabase.memory());
    outbox = PeerOutbox(db);
    // Wired exactly as HaLoServices._onLocalWrite does. Without this the
    // tests drive the outbox by hand and cannot see whether a local write
    // reaches a peer on its own — which is how live push shipped unwired.
    operations = OperationsRepository(db, onChange: outbox.notifyChanged);
    qsos = QsosRepository(db, onChange: outbox.notifyChanged);
    service = PeerService(
      db: db,
      outbox: outbox,
      operations: operations,
      qsos: qsos,
      localDeviceId: deviceId,
      localDeviceName: name,
      beaconPort: fakeBeaconPort,
      network: host.network,
    );
    // One operator's own devices, which is what lets an operation the other
    // has never seen cross at all (`PeerSession`'s header). Wired here the
    // way main.dart wires it, from the account this device is signed in to.
    service.localAccountTag = () => accountTag;
  }

  /// Reassigned by a test about the account gate, before the service starts.
  String? accountTag = 'account-1';

  final String deviceId;
  final String name;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final OperationsRepository operations;
  late final QsosRepository qsos;
  late final PeerService service;

  Future<void> dispose() async {
    // The master switch, not the operation: closing the operation keeps
    // sessions up by design now, and the teardown must be awaited before the
    // database goes away under the sockets.
    await service.setEnabled(false);
    service.dispose();
    await db.close();
  }
}

void main() {
  late FakeLan lan;
  late _Device deviceA;
  late _Device deviceB;

  setUp(() async {
    lan = FakeLan();
    // 'device-a' sorts below 'device-b', so A is the side that dials.
    deviceA = _Device('device-a', 'Laptop', lan.host());
    deviceB = _Device('device-b', 'Phone', lan.host());
  });

  tearDown(() async {
    await deviceA.dispose();
    await deviceB.dispose();
  });

  /// Creates one operation on A and hands B a copy, the way LoFi sync or an
  /// earlier peer session would have.
  Future<String> sharedOperation() async {
    final op = await deviceA.operations.create(stationCall: 'KI2D', userTitle: 'Park');
    await deviceB.operations.mergeFromPeer([
      {'uuid': op.uuid, 'stationCall': 'KI2D', 'updatedAtMillis': op.updatedAtMillis},
    ]);
    return op.uuid;
  }

  test('two devices discover each other, pair once, and sync both ways', () async {
    final op = await sharedOperation();
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}, 'band': '20m'});

    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);

    // Discovery is by broadcast beacon; nobody told either side the other
    // exists.
    await waitFor('each side to see the other', () =>
        deviceA.service.peers.containsKey('device-b') && deviceB.service.peers.containsKey('device-a'));

    // Neither has paired before, so both should be waiting on their operator.
    await waitFor('both to ask for pairing',
        () => deviceA.service.pendingPairing != null && deviceB.service.pendingPairing != null);
    expect(deviceB.service.pendingPairing!.session!.peer!.deviceName, 'Laptop',
        reason: 'the prompt has to be able to say WHICH device is asking');

    await deviceA.service.acceptPairing('device-b');
    await deviceB.service.acceptPairing('device-a');

    await waitFor('A\'s QSO to reach B',
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect((await deviceB.qsos.watchForOperation(op).first).single.theirCall, 'W1AW');

    // And the reverse direction, live, with no reconnect.
    await deviceB.qsos.add(op, {'their': {'call': 'K1ABC'}, 'band': '40m'});
    await deviceB.service.pushLocal();
    await waitFor('B\'s QSO to reach A',
        () async => (await deviceA.qsos.watchForOperation(op).first).length == 2);

    final onA = await deviceA.qsos.watchForOperation(op).first;
    expect(onA.map((q) => q.theirCall).toSet(), {'W1AW', 'K1ABC'});
  });

  test('a QSO logged while live reaches the peer with NOTHING driving it by hand', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('the link to go live',
        () => deviceA.service.peers['device-b']?.session?.state == PeerSessionState.live);

    // The whole point: log it and touch nothing else. No scanNow, no
    // pushLocal — just the repository write an operator's Enter key makes.
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});

    await waitFor('the QSO to arrive on its own',
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect((await deviceB.qsos.watchForOperation(op).first).single.theirCall, 'W1AW');
  });

  test('a QSO logged after both are live streams across without a prompt', () async {
    final op = await sharedOperation();
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('pairing prompts',
        () => deviceA.service.pendingPairing != null && deviceB.service.pendingPairing != null);
    await deviceA.service.acceptPairing('device-b');
    await deviceB.service.acceptPairing('device-a');
    await waitFor('the link to go live', () =>
        deviceA.service.peers['device-b']?.session?.state == PeerSessionState.live);

    await deviceA.qsos.add(op, {'their': {'call': 'EA4XYZ'}});
    await deviceA.service.pushLocal();

    await waitFor('the new QSO to arrive',
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect((await deviceB.qsos.watchForOperation(op).first).single.theirCall, 'EA4XYZ');
  });

  test('an already-trusted pair connects with no prompt at all', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});

    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);

    await waitFor('sync with no operator involvement',
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect(deviceA.service.pendingPairing, isNull);
    expect(deviceB.service.pendingPairing, isNull);
  });

  test('accepting a pairing puts the device in the linked set, and forgetting takes it out', () async {
    // The status bar counts [linkedDeviceIds], a cache this service keeps
    // rather than a live query — so what it shows is only ever as true as the
    // refreshes on the two paths that write trust. Drop either refresh and the
    // operator pairs a device and is told nothing is linked, or forgets one
    // and is told it still is, with the store itself perfectly correct.
    final op = await sharedOperation();
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('pairing prompts',
        () => deviceA.service.pendingPairing != null && deviceB.service.pendingPairing != null);
    expect(deviceA.service.linkedDeviceIds, isEmpty);

    await deviceA.service.acceptPairing('device-b');
    await deviceB.service.acceptPairing('device-a');
    expect(deviceA.service.linkedDeviceIds, {'device-b'});

    await deviceA.service.revokeTrust('device-b');
    expect(deviceA.service.linkedDeviceIds, isEmpty);
  });

  test('a trust-store read that fails leaves the count alone instead of escaping', () async {
    // [refreshLinkedDevices] runs from a fire-and-forget at construction and
    // from the middle of [revokeTrust]'s teardown — an error thrown out of
    // there would abort the teardown, leaving a device the operator just
    // forgot connected and syncing.
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceA.service.refreshLinkedDevices();
    expect(deviceA.service.linkedDeviceIds, {'device-b'});

    await deviceA.db.close();
    await expectLater(deviceA.service.refreshLinkedDevices(), completes);
    expect(deviceA.service.linkedDeviceIds, {'device-b'}, reason: 'a failed read reports nothing new, it does not empty the set');
  });

  test('devices on DIFFERENT operations each receive the other\'s, kept apart', () async {
    // Sessions bind to the paired device, and each side receives whatever
    // the other has open — so the operation B has never seen arrives whole,
    // under its own uuid. What must NOT happen is the two logs mixing: a
    // record lands under the operation it names or not at all.
    final opA = (await deviceA.operations.create(stationCall: "KI2D", userTitle: "A")).uuid;
    final opB = (await deviceB.operations.create(stationCall: "KI2D", userTitle: "B")).uuid;
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.qsos.add(opA, {'their': {'call': 'W1AW'}});

    await deviceA.service.setOpenOperation(opA);
    await deviceB.service.setOpenOperation(opB);

    await waitFor("A's operation to reach B",
        () async => (await deviceB.qsos.watchForOperation(opA).first).isNotEmpty);
    expect((await deviceB.operations.get(opA))?.userTitle, 'A',
        reason: 'the operation record travels with its log, or B has QSOs under nothing');
    expect(await deviceB.qsos.watchForOperation(opB).first, isEmpty,
        reason: "A's contact must not land under the operation B has open");
  });

  test('an unseen operation does not cross to a device on another account', () async {
    // The wiring test for the account gate: the session decides, but only
    // because the service hands it this device's account. Without that hand-
    // off every pair reads as account-less and nothing new ever crosses —
    // or, defaulted the other way, everything would.
    deviceB.accountTag = 'account-2';
    final opA = (await deviceA.operations.create(stationCall: "KI2D", userTitle: "A")).uuid;
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.qsos.add(opA, {'their': {'call': 'W1AW'}});

    await deviceA.service.setOpenOperation(opA);
    await deviceB.service.setOpenOperation(null);

    await waitFor('the pair to establish',
        () => deviceB.service.peers['device-a']?.session?.state == PeerSessionState.connected);
    // Time for a wrong catch-up to have delivered before the negative.
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await deviceB.operations.get(opA), isNull);
    expect(await deviceB.qsos.watchForOperation(opA).first, isEmpty);
  });

  test('switching operations moves the sync without re-pairing or reconnecting', () async {
    // The park flow: the pair is already up when the laptop opens an
    // operation. The session that formed while there was nothing to carry
    // must carry it the instant there is — no new link, no prompt.
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});

    await deviceA.service.setOpenOperation(null);
    await deviceB.service.setOpenOperation(null);
    await waitFor('the pair to establish with neither side in an operation',
        () => deviceB.service.peers['device-a']?.session?.state == PeerSessionState.connected);
    final sessionBefore = deviceB.service.peers['device-a']!.session;

    await deviceA.service.setOpenOperation(op);

    await waitFor('the backlog to arrive over the existing session',
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect((await deviceB.qsos.watchForOperation(op).first).single.theirCall, 'W1AW');
    expect(identical(deviceB.service.peers['device-a']!.session, sessionBefore), isTrue,
        reason: 'the SAME session must carry it — reconnecting would defeat device-bound sessions');
  });

  test('accepting stops asking, even while the other side has not answered', () async {
    final op = await sharedOperation();
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('B to be asked', () => deviceB.service.pendingPairing != null);

    // Only B's operator answers. A's has not reached their device yet, so
    // the session stays at needsPairing — the state alone would keep B's
    // prompt eligible, and acceptPairing notifies, so B's operator would be
    // re-asked immediately and then on every beacon after it.
    await deviceB.service.acceptPairing('device-a');

    expect(deviceB.service.pendingPairing, isNull);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(deviceB.service.pendingPairing, isNull,
        reason: 'beacons keep arriving; an operator who has answered must not be asked again');
  });

  test('declining leaves the peer un-trusted and stops asking', () async {
    final op = await sharedOperation();
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('B to be asked', () => deviceB.service.pendingPairing != null);

    await deviceB.service.rejectPairing('device-a');

    expect(await deviceB.service.trust.isTrusted('device-a'), isFalse);
    // Beacons keep arriving; the operator must not be re-prompted for a
    // device they already turned down.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(deviceB.service.pendingPairing, isNull);
    expect(await deviceB.qsos.watchForOperation(op).first, isEmpty);
  });

  test('revoking trust drops the live session instead of syncing until it happens to drop', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('the link to go live',
        () => deviceA.service.peers['device-b']?.session?.state == PeerSessionState.live);

    await deviceB.service.revokeTrust('device-a');
    expect(await deviceB.service.trust.isTrusted('device-a'), isFalse);
    expect(deviceB.service.peers['device-a']?.session, isNull);
  });

  test('a peer arriving and then going away announces both edges', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    final events = <String>[];
    deviceB.service.onPeerConnectionChanged = (deviceId, deviceName, {required connected}) {
      events.add('${connected ? 'connected' : 'lost'}:$deviceId:$deviceName');
    };
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);

    await waitFor('B to report the connection', () => events.isNotEmpty);
    // The NAME, not the id: the operator is told which of their devices this
    // is, and the id is what the panel shows when they need to be sure.
    expect(events.first, 'connected:device-a:Laptop');

    // A carried out of range — from B's side an ordinary disappearance, and
    // the only edge that tells B's operator their devices stopped talking.
    await deviceA.service.setEnabled(false);
    await waitFor('B to report the loss', () => events.length > 1);
    expect(events[1], 'lost:device-a:Laptop');
  });

  test('a disconnection the operator asked for says nothing', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    final events = <String>[];
    deviceB.service.onPeerConnectionChanged = (deviceId, deviceName, {required connected}) {
      events.add(connected ? 'connected' : 'lost');
    };
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('the link to go live',
        () => deviceB.service.peers['device-a']?.session?.state == PeerSessionState.live);
    await waitFor('B to report the connection', () => events.isNotEmpty);

    // Revoking trust drops the session — the operator did that, and being
    // told the connection was lost is telling them what they just did.
    await deviceB.service.revokeTrust('device-a');
    // Then the master switch, the other half of the same rule. Long enough
    // for the close to have travelled: this assertion is a negative, so a
    // check that runs before the teardown would pass on anything.
    await deviceB.service.setEnabled(false);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(events, ['connected'], reason: 'neither the revoke nor the switch may report a loss');
  });

  test('the master switch alone stops and restarts sharing, with the operation still open', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('peers to find each other', () => deviceA.service.peers.isNotEmpty);

    await deviceA.service.setEnabled(false);
    expect(deviceA.service.running, isFalse,
        reason: 'the switch is the whole consent — off means nothing is announced or connected');
    expect(deviceA.service.peers, isEmpty);

    await deviceA.service.setEnabled(true);
    await waitFor('sharing to resume without reopening the operation',
        () => deviceA.service.peers.isNotEmpty);
  });

  test('the master switch releases every socket, so it can be turned back on', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('peers to find each other', () => deviceA.service.peers.isNotEmpty);

    // B's, still up — so the counts below are A's alone.
    final othersSockets = lan.openSockets - 1;
    final othersServers = lan.openLinkServers - 1;

    await deviceA.service.setEnabled(false);
    expect(deviceA.service.peers, isEmpty);
    expect(deviceA.service.running, isFalse);

    // RELEASED, not merely dereferenced. Asserted as a count because over an
    // in-memory segment no later bind can fail: "starting again works" is
    // evidence on real sockets and none at all here, so a teardown that
    // leaked both would look identical without this.
    await waitFor('A\'s sockets to be released',
        () => lan.openSockets == othersSockets && lan.openLinkServers == othersServers);

    await deviceA.service.setEnabled(true);
    await waitFor('discovery to work a second time', () => deviceA.service.peers.isNotEmpty);
    expect(deviceA.service.error, isNull);
  });

  test('closing the operation keeps the pair connected', () async {
    // What setOpenOperation(null) means now: the durable sync idles, the
    // session — and everything ephemeral riding it — survives. The operator
    // backing out to the home screen must not drop their phone's GPS.
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('the link to go live',
        () => deviceA.service.peers['device-b']?.session?.state == PeerSessionState.live);

    // BOTH: closing on one side alone only stops what that side serves —
    // the peer is still in the operation, and still feeding it across.
    await deviceA.service.setOpenOperation(null);
    await deviceB.service.setOpenOperation(null);
    await waitFor('both sides to idle at connected', () =>
        deviceA.service.peers['device-b']?.session?.state == PeerSessionState.connected &&
        deviceB.service.peers['device-a']?.session?.state == PeerSessionState.connected);

    // And back: the same pair resumes syncing with no prompt and no redial.
    await deviceB.service.setOpenOperation(op);
    await waitFor('the sync to resume', () =>
        deviceA.service.peers['device-b']?.session?.state == PeerSessionState.live);
  });
}
