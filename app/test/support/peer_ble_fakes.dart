// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A fake BLE world for the peer transport tests (HALO-342): gateways wired
// back-to-back through in-memory pipes, with the same event ordering the
// real plugin produces — Subscribed before the first WriteReceived, writes
// throwing once the pipe is down. What it deliberately does NOT model:
// radio loss, MTU renegotiation, RPA rotation. Those are hands-on-pass
// territory; these fakes exist so the transport's POLICY is testable.

import 'dart:async';
import 'dart:typed_data';

import 'package:ham2k_logger/services/peer/ble/peer_ble_gateway.dart';

class FakeBleWorld {
  final Map<String, FakeBleGateway> byAddress = {};
  int _connectionSeq = 0;

  FakeBleGateway gateway(String address) {
    final gateway = FakeBleGateway._(this, address);
    byAddress[address] = gateway;
    return gateway;
  }

  /// Delivers one round of advertisements — every advertising gateway is
  /// sighted by [to] (or by every scanning gateway when null). The real
  /// radio repeats these continuously; tests call this when they mean
  /// "the peer is (still) in range".
  void tick({FakeBleGateway? to}) {
    for (final scanner in byAddress.values) {
      if (to != null && !identical(scanner, to)) continue;
      if (!scanner.scanning) continue;
      for (final advertiser in byAddress.values) {
        if (identical(advertiser, scanner) || !advertiser.advertising) continue;
        scanner._sightings.add(PeerBleSighting(
          addressId: advertiser.address,
          nameHint: advertiser.advertisedName,
        ));
      }
    }
  }
}

class FakeBlePipe {
  FakeBlePipe(this.server, this.centralId, this.onPacket);

  final FakeBleGateway server;
  final String centralId;

  /// Where notifies land on the client side — wired at connect, like the
  /// real gateway wires the listener before the CCCD write.
  final void Function(Uint8List packet) onPacket;
  final clientDisconnected = Completer<void>();
  bool closed = false;

  void close() {
    if (closed) return;
    closed = true;
    server.pipes.remove(centralId);
    if (!clientDisconnected.isCompleted) clientDisconnected.complete();
    if (!server._serverEvents.isClosed) {
      server._serverEvents.add(PeerBleCentralUnsubscribed(centralId));
    }
  }
}

class FakeBleGateway implements PeerBleGateway {
  FakeBleGateway._(this.world, this.address);

  final FakeBleWorld world;

  /// The BLE-address handle other gateways connect by — NOT a device id.
  final String address;

  bool advertising = false;
  String? advertisedName;
  bool scanning = false;

  /// What [prepare] answers; tests flip these to model a denied permission
  /// or a central-only platform.
  PeerBleReadiness readiness = const PeerBleReadiness(canCentral: true, canPeripheral: true);
  int prepareCalls = 0;
  bool? lastPrepareRequestedPermission;

  /// Small enough to force multi-packet frames through every test.
  int chunkLimit = 30;

  int connectCalls = 0;

  final Map<String, FakeBlePipe> pipes = {};
  final _sightings = StreamController<PeerBleSighting>.broadcast();
  final _serverEvents = StreamController<PeerBleServerEvent>.broadcast();
  final availability = StreamController<void>.broadcast();

  @override
  Stream<void> get availabilityChanged => availability.stream;

  @override
  Future<PeerBleReadiness> prepare({required bool requestPermission}) async {
    prepareCalls++;
    lastPrepareRequestedPermission = requestPermission;
    return readiness;
  }

  @override
  Future<void> startServer({required String localName}) async {
    advertising = true;
    advertisedName = localName;
  }

  @override
  Future<void> stopServer() async {
    advertising = false;
    advertisedName = null;
    for (final pipe in pipes.values.toList()) {
      pipe.close();
    }
  }

  @override
  Stream<PeerBleServerEvent> get serverEvents => _serverEvents.stream;

  @override
  Future<void> notify(String centralId, Uint8List packet) async {
    final pipe = pipes[centralId];
    if (pipe == null || pipe.closed) throw StateError('notify to a gone central');
    pipe.onPacket(packet);
  }

  @override
  Future<int> serverChunkLimit(String centralId) async => chunkLimit;

  @override
  Future<void> disconnectCentral(String centralId) async {
    pipes[centralId]?.close();
  }

  /// While positive, [startScan] throws and decrements — models the
  /// transient failures (Android's "scanning too frequently") the
  /// transport's role retry exists for.
  int failScanStarts = 0;

  @override
  Future<void> startScan() async {
    if (failScanStarts > 0) {
      failScanStarts--;
      throw StateError('scan refused (transient)');
    }
    scanning = true;
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
  }

  @override
  Stream<PeerBleSighting> get sightings => _sightings.stream;

  /// Event-loop turns to yield before [connect] returns. Models the real
  /// race the onPacket-before-subscribe contract exists for: the peer's
  /// first notifies fire off its Subscribed event, which with yields > 0
  /// lands BEFORE the caller's link object exists — exercising the
  /// early-packet buffer that is otherwise dead in every test.
  int connectYields = 0;

  @override
  Future<PeerBleClientConnection> connect(
    String addressId, {
    required void Function(Uint8List packet) onPacket,
  }) async {
    connectCalls++;
    final target = world.byAddress[addressId];
    if (target == null || !target.advertising) {
      throw StateError('nothing advertising at $addressId');
    }
    final centralId = '$address#${world._connectionSeq++}';
    final pipe = FakeBlePipe(target, centralId, onPacket);
    target.pipes[centralId] = pipe;
    // Subscribed lands on the server's event stream BEFORE any write can —
    // the same ordering the GATT server callbacks guarantee.
    target._serverEvents.add(PeerBleCentralSubscribed(centralId));
    for (var i = 0; i < connectYields; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return _FakeClientConnection(pipe, chunkLimit);
  }
}

class _FakeClientConnection implements PeerBleClientConnection {
  _FakeClientConnection(this._pipe, this.chunkLimit);

  final FakeBlePipe _pipe;

  @override
  final int chunkLimit;

  @override
  Future<void> write(Uint8List packet) async {
    if (_pipe.closed) throw StateError('write on a dropped connection');
    if (!_pipe.server._serverEvents.isClosed) {
      _pipe.server._serverEvents.add(PeerBleWriteReceived(_pipe.centralId, packet));
    }
  }

  @override
  Future<void> get disconnected => _pipe.clientDisconnected.future;

  @override
  Future<void> disconnect() async {
    _pipe.close();
  }
}
