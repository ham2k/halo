// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The park-without-WiFi scenario end to end (HALO-342): two full
// PeerServices whose ONLY route to each other is the fake BLE world — each
// beacons on its own loopback port, so LAN discovery is structurally
// impossible and anything that syncs here proves the whole stack (frame
// layer, transport, session, trust, outbox) works over the radio path.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/ble/peer_ble_gateway.dart';
import 'package:ham2k_logger/services/peer/ble/peer_ble_transport.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/peer/serial_claims.dart';

import '../support/peer_ble_fakes.dart';
import '../support/peer_network_fakes.dart';

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
  _Device(this.deviceId, this.name, FakeHost host, FakeBleWorld world, String bleAddress) {
    db = HaLoDatabase(NativeDatabase.memory());
    outbox = PeerOutbox(db);
    operations = OperationsRepository(db, onChange: outbox.notifyChanged);
    qsos = QsosRepository(db, onChange: outbox.notifyChanged);
    gateway = world.gateway(bleAddress);
    service = PeerService(
      db: db,
      outbox: outbox,
      operations: operations,
      qsos: qsos,
      localDeviceId: deviceId,
      localDeviceName: name,
      // Shared by both devices deliberately — they are on separate segments,
      // so the same number cannot let them find each other.
      beaconPort: fakeBeaconPort,
      network: host.network,
      bleGateway: gateway,
      bleHeadStart: const Duration(milliseconds: 50),
      bleJitter: false,
    );
  }

  final String deviceId;
  final String name;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final OperationsRepository operations;
  late final QsosRepository qsos;
  late final FakeBleGateway gateway;
  late final PeerService service;

  Future<void> dispose() async {
    await service.setEnabled(false);
    service.dispose();
    await db.close();
  }
}

void main() {
  late FakeBleWorld world;
  late _Device deviceA;
  late _Device deviceB;
  late Timer advertising;

  setUp(() async {
    world = FakeBleWorld();
    // SEPARATE LAN segments, so LAN discovery cannot happen however the
    // ports line up and any contact is BLE's. Two devices on one segment
    // that merely disagreed about the port would start passing the moment
    // someone made the port a constant. The ids sort a-before-b for the
    // hint election.
    deviceA = _Device('aaaaaaaa-0000-0000-0000-000000000001', 'Laptop', FakeLan().host(), world, 'addr-a');
    deviceB = _Device('bbbbbbbb-0000-0000-0000-000000000002', 'Phone', FakeLan().host(), world, 'addr-b');
    // The radio repeats advertisements continuously; so does the fake.
    advertising = Timer.periodic(const Duration(milliseconds: 100), (_) => world.tick());
  });

  tearDown(() async {
    advertising.cancel();
    await deviceA.dispose();
    await deviceB.dispose();
  });

  Future<void> bleOn(_Device device) async {
    await device.service.setEnabled(true);
    await device.service.setBleEnabled(true);
  }

  Future<String> sharedOperation() async {
    final op = await deviceA.operations.create(stationCall: 'KI2D', userTitle: 'Park');
    await deviceB.operations.mergeFromPeer([
      {'uuid': op.uuid, 'stationCall': 'KI2D', 'updatedAtMillis': op.updatedAtMillis},
    ]);
    return op.uuid;
  }

  test('two devices with no shared network pair over BLE and sync both ways', () async {
    final op = await sharedOperation();
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}, 'band': '20m'});

    await bleOn(deviceA);
    await bleOn(deviceB);
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);

    await waitFor('both to ask for pairing',
        () => deviceA.service.pendingPairing != null && deviceB.service.pendingPairing != null);
    // The prompt must be able to say WHICH device asks, from the protocol
    // hello alone — BLE advertisements carry no name.
    expect(deviceB.service.pendingPairing!.session!.peer!.deviceName, 'Laptop');

    await deviceA.service.acceptPairing(deviceB.deviceId);
    await deviceB.service.acceptPairing(deviceA.deviceId);

    await waitFor("A's QSO to reach B",
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect((await deviceB.qsos.watchForOperation(op).first).single.theirCall, 'W1AW');

    // Live, the reverse way, no reconnect.
    await deviceB.qsos.add(op, {'their': {'call': 'K1ABC'}, 'band': '40m'});
    await deviceB.service.pushLocal();
    await waitFor("B's QSO to reach A",
        () async => (await deviceA.qsos.watchForOperation(op).first).length == 2);

    // And the panel can say how they are connected.
    final session = deviceA.service.peers[deviceB.deviceId]!.session!;
    expect(session.link, isA<PeerBleLink>());
    // The transport-fit batch size: the LAN default (200 rows ≈ 220 KB per
    // frame) would park every ephemeral message behind half a minute of
    // head-of-line blocking on a real radio. Two QSOs cannot exercise the
    // limit, so the wiring is pinned directly.
    expect(session.batchLimit, lessThanOrEqualTo(20));
  });

  test('an already-trusted pair connects over BLE with no prompt, and one link total', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust(deviceB.deviceId, name: 'Phone');
    await deviceB.service.trust.trust(deviceA.deviceId, name: 'Laptop');
    await deviceA.qsos.add(op, {'their': {'call': 'W1AW'}});

    await bleOn(deviceA);
    await bleOn(deviceB);
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);

    await waitFor('sync with no operator involvement',
        () async => (await deviceB.qsos.watchForOperation(op).first).isNotEmpty);
    expect(deviceA.service.pendingPairing, isNull);
    expect(deviceB.service.pendingPairing, isNull);

    // Let the higher-id side's delayed dial timer come due, then prove the
    // hint held: B never dialled a peer it already had a session with.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(deviceB.gateway.connectCalls, 0,
        reason: 'the connected-peer hint exists so the pair does not chew the radio with duplicate dials');
  });

  test('a serial claim crosses a BLE link, where a stream still does not', () async {
    // A position on Bluetooth left out of the claim round shows the same
    // number as one on the LAN — a duplicate serial on the air. So the
    // claims' send opts into BLE, while the default keeps refusing it: the
    // drafts and screen frames it guards would park every claim behind the
    // credit window.
    await deviceA.service.trust.trust(deviceB.deviceId, name: 'Phone');
    await deviceB.service.trust.trust(deviceA.deviceId, name: 'Laptop');
    await bleOn(deviceA);
    await bleOn(deviceB);
    await waitFor('the BLE session to establish', () => deviceA.service.hasSession(deviceB.deviceId));
    expect(deviceA.service.hasLanSession(deviceB.deviceId), isFalse);

    final received = <PeerMessage>[];
    deviceB.service.onEphemeral = (_, message) => received.add(message);
    final claim = PeerMessage.serialClaims(
      operationUuid: 'op-1',
      seq: 1,
      claims: const [PeerSerialClaim(label: 'serial', number: 7)],
    );

    expect(deviceA.service.sendEphemeralTo(deviceB.deviceId, claim), isFalse,
        reason: 'the default send is the LAN-only guard for streams');
    expect(deviceA.service.sendEphemeralTo(deviceB.deviceId, claim, allowBle: true), isTrue);
    await waitFor('the claim to arrive over BLE',
        () => received.any((m) => m.serialClaimsOrNull?.claims.single.number == 7));
  });

  test('a claim round runs across a BLE link, wired the way the app wires it', () async {
    // The test above proves the transport gate; this one proves the WIRING.
    // Rewire either side to the LAN-only roster or the LAN-only send and
    // the phone never hears the laptop's claim, so it claims 1 as well.
    await deviceA.service.trust.trust(deviceB.deviceId, name: 'Phone');
    await deviceB.service.trust.trust(deviceA.deviceId, name: 'Laptop');
    SerialClaims claimsFor(_Device device) => SerialClaims(
          localDeviceId: device.deviceId,
          peek: (_, _) async => 1,
          livePeers: () => [
            for (final id in device.service.peers.keys)
              if (device.service.hasSession(id)) id,
          ],
          send: (id, message) => device.service.sendEphemeralTo(id, message, allowBle: true),
        );
    final claimsA = claimsFor(deviceA);
    final claimsB = claimsFor(deviceB);
    addTearDown(claimsA.dispose);
    addTearDown(claimsB.dispose);
    // What `PeerChannels` does for the `serialClaims` type, and nothing else.
    deviceA.service.onEphemeral = (id, message) {
      if (message.serialClaimsOrNull case final payload?) claimsA.onPeerClaims(id, payload);
    };
    deviceB.service.onEphemeral = (id, message) {
      if (message.serialClaimsOrNull case final payload?) claimsB.onPeerClaims(id, payload);
    };

    await bleOn(deviceA);
    await bleOn(deviceB);
    await waitFor('both sides to hold the BLE session',
        () => deviceA.service.hasSession(deviceB.deviceId) && deviceB.service.hasSession(deviceA.deviceId));

    const descriptor = SequenceDescriptor(refType: 'cqwpx', field: 'ourSerial', key: 'cqwpx/serial');
    final request = descriptor.requestFor(Qso(uuid: '', operationUuid: 'op-1', data: const {'band': '20m'}));
    expect(await claimsA.claim('op-1', request), 1);
    // Settled on the phone's ack, not on the cap: an idle BLE link answers
    // well inside it, and a link that carried the claim but not the ack
    // would leave the phone quiet.
    expect(claimsA.isQuiet(deviceB.deviceId), isFalse);
    expect(await claimsB.claim('op-1', request), 2);
  });

  test('the sub-switch alone turns the radio off and drops the BLE session', () async {
    await deviceA.service.trust.trust(deviceB.deviceId, name: 'Phone');
    await deviceB.service.trust.trust(deviceA.deviceId, name: 'Laptop');
    await bleOn(deviceA);
    await bleOn(deviceB);
    await waitFor('the pair to connect',
        () => deviceA.service.peers[deviceB.deviceId]?.isConnected ?? false);

    await deviceA.service.setBleEnabled(false);
    expect(deviceA.gateway.advertising, isFalse, reason: 'sub-switch off means the radio goes quiet');
    expect(deviceA.gateway.scanning, isFalse);
    await waitFor('the session to drop with the transport',
        () => !(deviceA.service.peers[deviceB.deviceId]?.isConnected ?? false));
    // The master switch stayed on: LAN (were it reachable) would be
    // unaffected, and the service still runs.
    expect(deviceA.service.running, isTrue);
  });

  test('turning the Bluetooth sub-switch off reports no lost connection', () async {
    // The third operator-caused disconnection, beside the master switch and
    // a revoke, and the one a reader of PeerService is least likely to spot:
    // the drop happens inside the BLE transport's stop, two calls away.
    await deviceA.service.trust.trust(deviceB.deviceId, name: 'Phone');
    await deviceB.service.trust.trust(deviceA.deviceId, name: 'Laptop');
    final events = <String>[];
    deviceA.service.onPeerConnectionChanged = (deviceId, deviceName, {required connected}) {
      events.add(connected ? 'connected' : 'lost');
    };
    await bleOn(deviceA);
    await bleOn(deviceB);
    await waitFor('the pair to connect',
        () => deviceA.service.peers[deviceB.deviceId]?.isConnected ?? false);
    await waitFor('A to report the connection', () => events.isNotEmpty);

    await deviceA.service.setBleEnabled(false);
    await waitFor('the session to drop with the transport',
        () => !(deviceA.service.peers[deviceB.deviceId]?.isConnected ?? false));
    // Long enough for a report to have travelled: this is a negative, so an
    // assertion made before the close landed would pass on anything.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(events, ['connected'], reason: 'the operator flipped the switch — telling them it dropped is noise');
  });

  test('a Bluetooth problem is the operator-visible bleError, apart from the LAN error', () async {
    deviceA.gateway.readiness =
        const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth is turned off');
    await bleOn(deviceA);
    await waitFor('the problem to surface', () => deviceA.service.bleError != null);
    expect(deviceA.service.bleError, 'Bluetooth is turned off');
    expect(deviceA.service.error, isNull, reason: 'a BLE problem must not read as LAN sync being down');
  });
}
