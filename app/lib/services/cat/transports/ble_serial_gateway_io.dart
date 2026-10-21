// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one real `BleSerialGateway`, over `universal_ble`. Mechanical, like the
// peer gateway beside it: every decision lives in `BleSerialTransport`, where
// a fake gateway can test it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:universal_ble/universal_ble.dart';

import '../../ble/ble_scan_coordinator.dart';
import 'ble_serial_gateway.dart';
import 'ble_serial_profiles.dart';

BleSerialGateway? createBleSerialGateway() => _UniversalBleSerialGateway();

/// The plugin's own default is a minute, and a close awaits it: a link whose
/// disconnect event never arrives would hold the next connect that long.
const _disconnectTimeout = Duration(seconds: 5);

/// Whether [error] is the Bluetooth stack's rather than this app's — see
/// [BleSerialPlatformError].
bool _isPlatformError(Object error) => error is UniversalBleException || error is PlatformException;

class _UniversalBleSerialGateway implements BleSerialGateway {
  void Function(String text)? _note;

  @override
  set onNote(void Function(String text)? note) => _note = note;

  void _say(String text) {
    debugPrint('[cat] BLE $text');
    _note?.call(text);
  }

  @override
  Future<BleSerialReadiness> prepare({required bool requestPermission}) async {
    AvailabilityState state;
    try {
      state = await UniversalBle.getBluetoothAvailabilityState();
      // The first query of a session creates the manager and answers before
      // it has powered on — the peer gateway's settle poll, for its reason.
      for (var attempt = 0; (state == AvailabilityState.unknown || state == AvailabilityState.resetting) && attempt < 20; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        state = await UniversalBle.getBluetoothAvailabilityState();
      }
    } catch (e) {
      _say('availability check failed, reading as unsupported: $e');
      return BleSerialReadiness.unsupported;
    }
    switch (state) {
      case AvailabilityState.poweredOn:
        break;
      case AvailabilityState.poweredOff:
        return BleSerialReadiness.off;
      case AvailabilityState.unauthorized:
        return BleSerialReadiness.denied;
      case AvailabilityState.unsupported:
        return BleSerialReadiness.unsupported;
      case AvailabilityState.unknown:
      case AvailabilityState.resetting:
        return BleSerialReadiness.starting;
    }
    try {
      if (await UniversalBle.hasPermissions()) return BleSerialReadiness.ready;
      if (!requestPermission) return BleSerialReadiness.denied;
      await UniversalBle.requestPermissions();
      // Re-checked rather than trusting the request: whether a denial throws
      // or returns quietly varies by platform.
      return await UniversalBle.hasPermissions() ? BleSerialReadiness.ready : BleSerialReadiness.denied;
    } catch (e) {
      _say('permission check failed, reading as denied: $e');
      return BleSerialReadiness.denied;
    }
  }

  @override
  Future<List<BleSerialSighting>> scan(Duration duration) async {
    final seen = <String, BleSerialSighting>{};
    final BleScanLease lease;
    try {
      lease = await BleScanCoordinator.instance.acquire(
        onResult: (device) {
          final name = device.name;
          // A device with no name is a beacon, a phone or a tag: nothing an
          // operator could recognize in a list as the bridge on their radio.
          if (name == null || name.isEmpty) return;
          seen[device.deviceId] = BleSerialSighting(
            deviceId: device.deviceId,
            name: name,
            rssi: device.rssi,
            services: [for (final uuid in device.services) ?BleUuidParser.stringOrNull(uuid)],
          );
        },
      );
    } catch (e) {
      if (_isPlatformError(e)) throw BleSerialPlatformError('$e');
      rethrow;
    }
    await Future<void>.delayed(duration);
    try {
      await BleScanCoordinator.instance.release(lease);
    } catch (e) {
      // What was heard was heard: a scan that would not stop cleanly must
      // not turn the devices it found into "none found".
      _say('scan did not stop cleanly: $e');
    }
    return seen.values.toList();
  }

  @override
  Future<BleSerialDevice> connect(String deviceId, {required Duration timeout}) async {
    try {
      // Inside the cleanup: a timeout here abandons only the Dart future,
      // and on Apple platforms the native attempt never expires — left
      // pending, the OS takes the bridge whenever it next powers on and
      // holds it from every other app.
      await UniversalBle.connect(deviceId, timeout: timeout);
      var mtu = 23;
      try {
        mtu = await UniversalBle.requestMtu(deviceId, 247);
      } catch (e) {
        // The ATT default still carries CAT — commands are a few bytes.
        _say('MTU request failed, keeping 23: ${scrubBleDeviceId(e, deviceId)}');
      }
      final services = await UniversalBle.discoverServices(deviceId);
      return _UniversalBleSerialDevice(deviceId, (mtu - 3).clamp(20, 244), [
        for (final service in services)
          BleSerialService(service.uuid.toLowerCase(), [
            for (final c in service.characteristics)
              BleSerialCharacteristic(
                c.uuid.toLowerCase(),
                write: c.properties.contains(CharacteristicProperty.write),
                writeWithoutResponse: c.properties.contains(CharacteristicProperty.writeWithoutResponse),
                notify: c.properties.contains(CharacteristicProperty.notify),
                indicate: c.properties.contains(CharacteristicProperty.indicate),
              ),
          ]),
      ]);
    } catch (e) {
      // Never leak a half-set-up link: nothing above holds it yet. The
      // plugin's disconnect logs and swallows its own failures.
      await UniversalBle.disconnect(deviceId, timeout: _disconnectTimeout);
      if (_isPlatformError(e)) throw BleSerialPlatformError(scrubBleDeviceId(e, deviceId));
      rethrow;
    }
  }
}

class _UniversalBleSerialDevice implements BleSerialDevice {
  _UniversalBleSerialDevice(this._deviceId, this.chunkLimit, this.services);

  final String _deviceId;

  @override
  final int chunkLimit;

  @override
  final List<BleSerialService> services;

  /// Cancelled at [disconnect]: the plugin's value stream is process-global
  /// and never closes, so the subscription is this link's to reclaim.
  StreamSubscription<Uint8List>? _values;

  @override
  Future<void> subscribe(String service, String characteristic, {required bool indicate, required void Function(Uint8List data) onData}) async {
    await _values?.cancel();
    _values = UniversalBle.characteristicValueStream(_deviceId, characteristic).listen(onData);
    try {
      if (indicate) {
        await UniversalBle.subscribeIndications(_deviceId, service, characteristic);
      } else {
        await UniversalBle.subscribeNotifications(_deviceId, service, characteristic);
      }
    } catch (e) {
      if (_isPlatformError(e)) throw BleSerialPlatformError(scrubBleDeviceId(e, _deviceId));
      rethrow;
    }
  }

  @override
  Future<void> write(String service, String characteristic, Uint8List bytes, {required bool withoutResponse}) =>
      UniversalBle.write(_deviceId, service, characteristic, bytes, withoutResponse: withoutResponse);

  @override
  Future<void> get disconnected =>
      // `orElse`: the stream closing with no disconnect event would otherwise
      // complete this with a StateError nobody handles.
      UniversalBle.connectionStream(_deviceId).firstWhere((connected) => !connected, orElse: () => false).then((_) {});

  @override
  Future<void> disconnect() async {
    await _values?.cancel();
    _values = null;
    // Logs and swallows its own failures.
    await UniversalBle.disconnect(_deviceId, timeout: _disconnectTimeout);
  }
}
