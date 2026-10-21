// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The plugin-free face of BLE for the CAT transport, the same split as the
// peer transport's `PeerBleGateway`: everything `BleSerialTransport` decides —
// which pipe, in what order, what a failure means — happens against this
// interface, so a fake gateway runs it in a plain unit test. The real one
// (`ble_serial_gateway_io.dart`) is plugin calls in, results out.

import 'dart:typed_data';

import 'ble_serial_profiles.dart';

export 'ble_serial_gateway_web.dart' if (dart.library.io) 'ble_serial_gateway_io.dart' show createBleSerialGateway;

/// A failure the platform's Bluetooth stack reported — out of range, refused,
/// a GATT error, Bluetooth switched off — as opposed to one in this app's own
/// code. Only these are the equipment's (`CatUnreachable`, kept out of the
/// crash reports); anything else out of a gateway is a bug and stays loud.
class BleSerialPlatformError implements Exception {
  const BleSerialPlatformError(this.message);

  /// The platform's own words, with the device's handle already taken out
  /// (see [scrubBleDeviceId]).
  final String message;

  @override
  String toString() => message;
}

/// [error]'s words without [deviceId]: platform errors quote the handle, and
/// on Android that is the bridge's hardware address — which nothing that
/// leaves the device may carry.
String scrubBleDeviceId(Object error, String deviceId) =>
    deviceId.isEmpty ? '$error' : '$error'.replaceAll(RegExp(RegExp.escape(deviceId), caseSensitive: false), '<device>');

/// Why the radio cannot be used right now. [ready] is the only usable one.
enum BleSerialReadiness { ready, off, denied, unsupported, starting }

/// A device seen while scanning.
class BleSerialSighting {
  const BleSerialSighting({required this.deviceId, required this.name, this.rssi, this.services = const []});

  /// The platform's handle: an address on Android, Windows and Linux, a
  /// per-host UUID on Apple platforms. Stable for one device on one machine,
  /// which is all a stored node needs — a node is device-local.
  final String deviceId;
  final String name;
  final int? rssi;

  /// Advertised service UUIDs, lower-case and full-length.
  final List<String> services;
}

/// A connected device, before any pipe is chosen.
abstract class BleSerialDevice {
  /// Discovered once, at connect.
  List<BleSerialService> get services;

  /// The largest write this link takes, from the negotiated MTU.
  int get chunkLimit;

  /// Wires [onData] to [characteristic] BEFORE the subscription goes out: a
  /// bridge may push the moment it sees it, and a value stream picked up
  /// after the CCCD write loses those bytes.
  Future<void> subscribe(String service, String characteristic, {required bool indicate, required void Function(Uint8List data) onData});

  /// Completes when the local stack accepted the bytes; throws when the link
  /// is gone.
  Future<void> write(String service, String characteristic, Uint8List bytes, {required bool withoutResponse});

  /// Completes when the link drops, however it drops. Never an error.
  Future<void> get disconnected;

  /// Idempotent; tolerates an already-dead link.
  Future<void> disconnect();
}

abstract class BleSerialGateway {
  /// Where the gateway says what it absorbed rather than threw — a fallback
  /// taken, a failure turned into a readiness — so a field recording still
  /// has it. Set by the transport; never carries a device's handle.
  set onNote(void Function(String text)? note);

  /// Availability and permission, prompting for permission only when
  /// [requestPermission] — an operator pressing Scan is consent to the
  /// prompt; a background reconnect is not.
  Future<BleSerialReadiness> prepare({required bool requestPermission});

  /// Every named device in range, for [duration]. Shares the one platform
  /// scan with peer discovery rather than replacing it.
  Future<List<BleSerialSighting>> scan(Duration duration);

  /// Connects and discovers services. Throws on failure, fully cleaned up.
  Future<BleSerialDevice> connect(String deviceId, {required Duration timeout});
}
