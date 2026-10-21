// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one real `PeerBleGateway`, over the `universal_ble` plugin (HALO-342).
// Deliberately mechanical — plugin calls in, gateway events out; every
// decision lives in `PeerBleTransport` where the fake gateway can test it.
//
// The plugin's surfaces are process-global singletons (static callbacks and
// streams), which is why there is exactly one gateway per app: this class
// owns `onAvailabilityChange` outright, and nothing else in the app may take
// it. The scan is shared with the CAT transport's device picker, so it goes
// through `BleScanCoordinator` rather than the plugin.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:universal_ble/universal_ble.dart';

import '../../ble/ble_scan_coordinator.dart';
import 'peer_ble_framing.dart' show bleMaxChunk, bleSafeChunk;
import 'peer_ble_gateway.dart';

PeerBleGateway? createPeerBleGateway() => UniversalBlePeerGateway();

class UniversalBlePeerGateway implements PeerBleGateway {
  /// The plugin callback is claimed only while someone listens: merely
  /// SETTING `onAvailabilityChange` fires a platform call inside the
  /// plugin, and this gateway is constructed on every launch — the radio
  /// must stay untouched until the sub-switch starts the transport.
  late final StreamController<void> _availability = StreamController<void>.broadcast(
    onListen: () {
      UniversalBle.onAvailabilityChange = (_) {
        if (!_availability.isClosed) _availability.add(null);
      };
    },
    onCancel: () {
      UniversalBle.onAvailabilityChange = null;
    },
  );
  final _sightings = StreamController<PeerBleSighting>.broadcast();
  final _serverEvents = StreamController<PeerBleServerEvent>.broadcast();

  /// Last MTU the platform reported per central — the fallback for
  /// [serverChunkLimit] when `getMaximumNotifyLength` has no answer.
  final Map<String, int> _centralMtu = {};

  StreamSubscription<BlePeripheralCharacteristicSubscriptionChanged>? _subscriptionSub;
  StreamSubscription<BlePeripheralConnectionStateChanged>? _connectionSub;
  StreamSubscription<BlePeripheralMtuChanged>? _mtuSub;
  bool _serverStarted = false;

  @override
  Stream<void> get availabilityChanged => _availability.stream;

  /// How long [prepare] waits for a freshly-created manager to power on.
  /// Both manager queries in the plugin CREATE the manager lazily and
  /// answer with its state synchronously, so the FIRST query of a session
  /// reads `unknown` essentially always — the state settles milliseconds
  /// later, but only the central manager emits an event when it does.
  /// Polling briefly is the difference between "works on enable" and a
  /// permanent '(unknown)' problem row.
  static const _settleTimeout = Duration(seconds: 3);
  static const _settleStep = Duration(milliseconds: 150);
  static int get _settleAttempts => _settleTimeout.inMilliseconds ~/ _settleStep.inMilliseconds;

  @override
  Future<PeerBleReadiness> prepare({required bool requestPermission}) async {
    // Central-side availability doubles as "does this device have a radio".
    AvailabilityState central;
    try {
      central = await UniversalBle.getBluetoothAvailabilityState();
      for (var attempt = 0; (central == AvailabilityState.unknown || central == AvailabilityState.resetting) && attempt < _settleAttempts; attempt++) {
        await Future<void>.delayed(_settleStep);
        central = await UniversalBle.getBluetoothAvailabilityState();
      }
    } catch (e) {
      return PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth unavailable: $e');
    }
    switch (central) {
      case AvailabilityState.poweredOn:
        break;
      case AvailabilityState.poweredOff:
        return const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth is turned off');
      case AvailabilityState.unauthorized:
        return const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth permission was denied');
      case AvailabilityState.unsupported:
        return const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'No Bluetooth radio');
      case AvailabilityState.unknown:
      case AvailabilityState.resetting:
        // Still settling past the poll window — ask the transport to come
        // back rather than parking on a state that announces nothing when
        // it changes.
        return const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth is starting up', transient: true);
    }

    try {
      // `neverForLocation` is declared in the manifest, so fine location is
      // deliberately NOT part of this request.
      if (!await UniversalBle.hasPermissions()) {
        if (!requestPermission) {
          return const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth permission not granted');
        }
        await UniversalBle.requestPermissions();
        // Re-checked rather than trusting the request's outcome: whether a
        // denial throws or returns quietly varies by platform, and the one
        // string that must be right is the one a real user produces by
        // tapping Deny on the prompt the sub-switch raised.
        if (!await UniversalBle.hasPermissions()) {
          return const PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth permission was denied');
        }
      }
    } catch (e) {
      return PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth permission was denied: $e');
    }

    // The peripheral role can be missing where the central works (Linux).
    // EVERY non-ready state gets the problem string: a device that can scan
    // but silently never advertises is half the reason two devices at a
    // park would never find each other with every indicator green.
    var canPeripheral = false;
    var transient = false;
    String? problem;
    try {
      var state = await UniversalBlePeripheral.getAvailabilityState();
      // The same settle poll as the central above, and here it is load-
      // bearing: the peripheral manager has NO state-change event in the
      // plugin, so a one-shot query racing its power-on strands the
      // advertise role on '(unknown)' with nothing to ever re-check.
      for (var attempt = 0; state == PeripheralReadinessState.unknown && attempt < _settleAttempts; attempt++) {
        await Future<void>.delayed(_settleStep);
        state = await UniversalBlePeripheral.getAvailabilityState();
      }
      canPeripheral = state == PeripheralReadinessState.ready;
      if (!canPeripheral) {
        transient = state == PeripheralReadinessState.unknown;
        problem = 'This device can look for peers but cannot announce itself over Bluetooth (${state.name})';
      }
    } catch (e) {
      debugPrint('[peer] BLE peripheral availability check failed: $e');
      problem = 'This device can look for peers but cannot announce itself over Bluetooth';
    }
    return PeerBleReadiness(canCentral: true, canPeripheral: canPeripheral, problem: problem, transient: transient);
  }

  // ---- peripheral role ----

  @override
  Future<void> startServer({required String localName}) async {
    if (_serverStarted) return;
    await _installServerPlumbing();
    try {
      await UniversalBlePeripheral.clearServices();
      await UniversalBlePeripheral.addService(
        BlePeripheralService(
          uuid: peerBleServiceUuid,
          characteristics: [
            // Open permissions and no encryption requirement anywhere: an SMP
            // security request is what pops the OS pairing dialog, and the app
            // brings its own trust layer (TOFU + the session handshake).
            BlePeripheralCharacteristic(
              uuid: peerBleRxUuid,
              properties: [CharacteristicProperty.write, CharacteristicProperty.writeWithoutResponse],
              permissions: [PeripheralAttributePermission.readable, PeripheralAttributePermission.writeable],
            ),
            BlePeripheralCharacteristic(
              uuid: peerBleTxUuid,
              properties: [CharacteristicProperty.notify],
              permissions: [PeripheralAttributePermission.readable],
            ),
          ],
        ),
      );
      await UniversalBlePeripheral.startAdvertising(services: [peerBleServiceUuid], localName: localName);
      _serverStarted = true;
    } catch (e) {
      // A half-start must not strand its plumbing: the caller retries this
      // whole method later, and listeners left installed here would double
      // every server event on the retry — each central then subscribed
      // twice, the second event tearing down the first event's link.
      await _teardownServerPlumbing();
      rethrow;
    }
  }

  /// Cancel-before-assign, so a retried start never stacks a second set of
  /// listeners on the plugin's global streams.
  Future<void> _installServerPlumbing() async {
    await _teardownServerPlumbing();
    UniversalBlePeripheral.setWriteRequestHandlers((deviceId, characteristicId, offset, value) {
      // Only whole-value writes to RX are frame bytes. Both platforms
      // forward prepared-write segments (offset > 0) through this same
      // handler, and splicing a partial buffer into the stream desyncs the
      // sender's own link; writes to any other characteristic are not ours
      // to interpret at all.
      final isFrameBytes = offset == 0 && value != null && BleUuidParser.compareStrings(characteristicId, peerBleRxUuid);
      if (isFrameBytes && !_serverEvents.isClosed) {
        _serverEvents.add(PeerBleWriteReceived(deviceId, value));
      }
      return null; // default success response
    });
    _subscriptionSub = UniversalBlePeripheral.characteristicSubscriptionStream.listen((event) {
      if (_serverEvents.isClosed) return;
      _serverEvents.add(event.isSubscribed ? PeerBleCentralSubscribed(event.deviceId) : PeerBleCentralUnsubscribed(event.deviceId));
    });
    _connectionSub = UniversalBlePeripheral.connectionStateStream.listen((event) {
      if (event.connected || _serverEvents.isClosed) return;
      // A central that vanishes mid-air never writes its CCCD goodbye; the
      // consumer treats the duplicate unsubscribe as idempotent.
      _centralMtu.remove(event.deviceId);
      _serverEvents.add(PeerBleCentralUnsubscribed(event.deviceId));
    });
    _mtuSub = UniversalBlePeripheral.mtuChangedStream.listen((event) {
      _centralMtu[event.deviceId] = event.mtu;
    });
  }

  Future<void> _teardownServerPlumbing() async {
    await _subscriptionSub?.cancel();
    _subscriptionSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _mtuSub?.cancel();
    _mtuSub = null;
    UniversalBlePeripheral.setWriteRequestHandlers(null);
  }

  @override
  Future<void> stopServer() async {
    // No started guard: a FAILED start leaves plugin state (a registered
    // service, possibly advertising) that only this path reclaims.
    _serverStarted = false;
    await _teardownServerPlumbing();
    try {
      await UniversalBlePeripheral.stopAdvertising();
      await UniversalBlePeripheral.clearServices();
    } catch (e) {
      debugPrint('[peer] BLE stopServer: $e');
    }
    _centralMtu.clear();
  }

  @override
  Stream<PeerBleServerEvent> get serverEvents => _serverEvents.stream;

  /// Serializes and paces the notify path. Bench-measured on macOS: the
  /// platform's update queue holds ONE notification per connection event —
  /// `updateValue` answers false for the second of any back-to-back pair
  /// and the plugin discards that answer, so the packet silently
  /// evaporates. Neither the false nor the ready callback reaches Dart,
  /// which leaves spacing the sends past the connection interval as the
  /// only reliable delivery the stock plugin allows. Android's peripheral
  /// has the same shape (notifies fired without awaiting
  /// onNotificationSent), so the pacing is unconditional.
  Future<void> _notifyTail = Future.value();
  int _lastNotifyMillis = 0;
  static const _notifySpacing = Duration(milliseconds: 40);

  @override
  Future<void> notify(String centralId, Uint8List packet) {
    final next = _notifyTail.then((_) async {
      final since = realNowMillis() - _lastNotifyMillis;
      if (since < _notifySpacing.inMilliseconds) {
        await Future<void>.delayed(Duration(milliseconds: _notifySpacing.inMilliseconds - since));
      }
      // Bounded: the tail is gateway-global, so ONE platform call that
      // never completes would starve every link's sends forever. The
      // timeout closes the stalled LINK (the throw reaches its send
      // worker); it does not cancel the platform call underneath, so the
      // stamp below is written on the timeout path too — the next send
      // still keeps its distance from a call that may yet be in flight.
      try {
        await UniversalBlePeripheral.updateCharacteristicValue(
          characteristicId: peerBleTxUuid,
          value: packet,
          deviceId: centralId,
        ).timeout(const Duration(seconds: 3));
      } on TimeoutException {
        _lastNotifyMillis = realNowMillis();
        rethrow;
      }
      _lastNotifyMillis = realNowMillis();
    });
    // The tail must survive an individual failure or every later notify
    // chains behind a dead future.
    _notifyTail = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<int> serverChunkLimit(String centralId) async {
    int? limit;
    try {
      limit = await UniversalBlePeripheral.getMaximumNotifyLength(centralId);
    } catch (e) {
      debugPrint('[peer] BLE notify-length query failed for $centralId: $e');
      // Fall through to the tracked MTU.
    }
    limit ??= switch (_centralMtu[centralId]) {
      final mtu? => mtu - 3,
      null => null,
    };
    if (limit == null) {
      // The ATT floor. Correct but ~10x slower than a negotiated size —
      // worth a line, or "BLE is just slow" and "MTU negotiation failed"
      // are indistinguishable in the field.
      debugPrint('[peer] BLE notify size unknown for $centralId; using the ATT floor');
    }
    return (limit ?? bleSafeChunk).clamp(bleSafeChunk, bleMaxChunk);
  }

  @override
  Future<void> disconnectCentral(String centralId) async {
    // The plugin has no peripheral-side disconnect. The link-level
    // keepalive is what reclaims a central whose far end went away.
  }

  // ---- central role ----

  BleScanLease? _scan;

  @override
  Future<void> startScan() async {
    if (_scan != null) return;
    _scan = await BleScanCoordinator.instance.acquire(
      services: {peerBleServiceUuid},
      onResult: (device) {
        if (_sightings.isClosed) return;
        _sightings.add(PeerBleSighting(addressId: device.deviceId, nameHint: device.name));
      },
    );
  }

  @override
  Future<void> stopScan() async {
    final scan = _scan;
    _scan = null;
    if (scan != null) await BleScanCoordinator.instance.release(scan);
  }

  @override
  Stream<PeerBleSighting> get sightings => _sightings.stream;

  @override
  Future<PeerBleClientConnection> connect(String addressId, {required void Function(Uint8List packet) onPacket}) async {
    await UniversalBle.connect(addressId, timeout: const Duration(seconds: 15));
    StreamSubscription<Uint8List>? notifySub;
    try {
      // Android grants a real number; Apple platforms answer from
      // `maximumWriteValueLength`, which can over-report — the HELLO
      // min-exchange downstream is what makes either answer safe.
      var mtu = 23;
      try {
        mtu = await UniversalBle.requestMtu(addressId, 517);
      } catch (e) {
        // The ATT default still works, ~10x slower — logged so a crawling
        // link is attributable.
        debugPrint('[peer] BLE MTU request failed for $addressId, keeping 23: $e');
      }
      final services = await UniversalBle.discoverServices(addressId);
      final hasService = services.any((s) => BleUuidParser.compareStrings(s.uuid, peerBleServiceUuid));
      if (!hasService) {
        throw StateError('peer service not present on $addressId');
      }
      // The listener attaches BEFORE the CCCD write goes out. The peer
      // fires its frame hello the moment it sees the subscription, the
      // value stream is a broadcast that drops events with no listener,
      // and the plugin's own post-subscribe awaits give the event loop
      // room to deliver those notifies — subscribing first loses them,
      // deterministically, and every handshake then times out.
      notifySub = UniversalBle.characteristicValueStream(addressId, peerBleTxUuid).listen(onPacket);
      await UniversalBle.subscribeNotifications(addressId, peerBleServiceUuid, peerBleTxUuid);
      return _UniversalBleClientConnection(addressId, (mtu - 3).clamp(bleSafeChunk, bleMaxChunk), notifySub);
    } catch (e) {
      // Never leak a half-set-up connection: nothing above holds it yet.
      await notifySub?.cancel();
      try {
        await UniversalBle.disconnect(addressId);
      } catch (_) {}
      rethrow;
    }
  }
}

class _UniversalBleClientConnection implements PeerBleClientConnection {
  _UniversalBleClientConnection(this._deviceId, this.chunkLimit, this._notifySub);

  final String _deviceId;

  /// Cancelled at [disconnect] — the plugin's value stream is process-
  /// global and never closes, so this subscription is the connection's to
  /// reclaim.
  final StreamSubscription<Uint8List> _notifySub;

  @override
  final int chunkLimit;

  @override
  Future<void> write(Uint8List packet) => UniversalBle.write(_deviceId, peerBleServiceUuid, peerBleRxUuid, packet, withoutResponse: true);

  @override
  Future<void> get disconnected =>
      // `orElse` keeps the contract's "never an error": without it, the
      // stream closing with no disconnect event completes this future with
      // a StateError nobody handles.
      UniversalBle.connectionStream(_deviceId).firstWhere((connected) => !connected, orElse: () => false).then((_) {});

  @override
  Future<void> disconnect() async {
    await _notifySub.cancel();
    try {
      await UniversalBle.disconnect(_deviceId);
    } catch (e) {
      debugPrint('[peer] BLE disconnect: $e');
    }
  }
}
