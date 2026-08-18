// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PeerService end to end (HALO-310): two services on real sockets finding
// each other by beacon, pairing, and syncing a log — the closest thing to
// "two devices at a park" this suite can run.
//
// Both services share one ephemeral beacon port on loopback, so the test
// never depends on the machine's network or collides with a real HaLo
// running on the standard port.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';

Future<int> freeUdpPort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  probe.close();
  return port;
}

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
  _Device(this.deviceId, this.name, int beaconPort) {
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
      beaconPort: beaconPort,
    );
  }

  final String deviceId;
  final String name;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final OperationsRepository operations;
  late final QsosRepository qsos;
  late final PeerService service;

  Future<void> dispose() async {
    await service.setOpenOperation(null);
    service.dispose();
    await db.close();
  }
}

void main() {
  late int beaconPort;
  late _Device deviceA;
  late _Device deviceB;

  setUp(() async {
    beaconPort = await freeUdpPort();
    // 'device-a' sorts below 'device-b', so A is the side that dials.
    deviceA = _Device('device-a', 'Laptop', beaconPort);
    deviceB = _Device('device-b', 'Phone', beaconPort);
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

  test('devices sharing DIFFERENT operations discover each other but never sync', () async {
    final opA = (await deviceA.operations.create(stationCall: "KI2D", userTitle: "A")).uuid;
    final opB = (await deviceB.operations.create(stationCall: "KI2D", userTitle: "B")).uuid;
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.qsos.add(opA, {'their': {'call': 'W1AW'}});

    await deviceA.service.setOpenOperation(opA);
    await deviceB.service.setOpenOperation(opB);

    // A beacon naming a different operation is filtered before it ever
    // becomes a peer, so B should not even list A.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(deviceB.service.peers, isEmpty);
    expect(await deviceB.qsos.watchForOperation(opB).first, isEmpty);
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

  test('the master switch alone stops and restarts sharing, with the operation still open', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('peers to find each other', () => deviceA.service.peers.isNotEmpty);

    await deviceA.service.setEnabled(false);
    expect(deviceA.service.activeOperationUuid, isNull,
        reason: 'the switch is the whole consent — off means nothing is shared or announced');
    expect(deviceA.service.peers, isEmpty);

    await deviceA.service.setEnabled(true);
    await waitFor('sharing to resume without reopening the operation',
        () => deviceA.service.peers.isNotEmpty);
  });

  test('turning sharing off releases every socket, so it can be turned back on', () async {
    final op = await sharedOperation();
    await deviceA.service.trust.trust('device-b', name: 'Phone');
    await deviceB.service.trust.trust('device-a', name: 'Laptop');
    await deviceA.service.setOpenOperation(op);
    await deviceB.service.setOpenOperation(op);
    await waitFor('peers to find each other', () => deviceA.service.peers.isNotEmpty);

    await deviceA.service.setOpenOperation(null);
    expect(deviceA.service.peers, isEmpty);
    expect(deviceA.service.activeOperationUuid, isNull);

    // The real assertion: the beacon port and listen socket were released, so
    // starting again works rather than failing to bind.
    await deviceA.service.setOpenOperation(op);
    await waitFor('discovery to work a second time', () => deviceA.service.peers.isNotEmpty);
    expect(deviceA.service.error, isNull);
  });
}
