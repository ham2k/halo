// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Dart half of `UsbSerialChannel.kt`: USB-serial ports on Android, over
// usb-serial-for-android. Only serial_transport_io.dart uses it.

import 'dart:async';

import 'package:flutter/services.dart';

import '../transport.dart';

/// One attached USB device, as `UsbSerialChannel.kt`'s `list` describes it.
class AndroidUsbDevice {
  final String deviceName;
  final int vendorId;
  final int productId;
  final String? manufacturer;
  final String? product;
  final String? serial;

  /// The driver the library matched to the device's USB ids or interfaces,
  /// or null when none did.
  final String? driver;

  const AndroidUsbDevice({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    this.manufacturer,
    this.product,
    this.serial,
    this.driver,
  });

  factory AndroidUsbDevice.fromMap(Map<dynamic, dynamic> map) => AndroidUsbDevice(
    deviceName: map['deviceName'] as String,
    vendorId: (map['vendorId'] as num).toInt(),
    productId: (map['productId'] as num).toInt(),
    manufacturer: map['manufacturer'] as String?,
    product: map['product'] as String?,
    serial: map['serial'] as String?,
    driver: map['driver'] as String?,
  );

  /// `vvvv:pppp`, lowercase hex: how `lsusb` and every USB id list write it.
  String get usbId => '${_hex4(vendorId)}:${_hex4(productId)}';

  static String _hex4(int id) => id.toRadixString(16).padLeft(4, '0');
}

/// The failure class a `UsbSerialChannel.kt` error code names. Its codes are
/// [SerialFailure]'s names on purpose; anything else is a cause the native
/// side could not place.
SerialFailure androidUsbFailure(String code) => SerialFailure.values.asNameMap()[code] ?? SerialFailure.other;

abstract final class AndroidUsbSerial {
  static const _channel = MethodChannel('ham2k/usb_serial');

  /// One stream for every open port, demultiplexed by handle. The native
  /// side holds a single sink, so a second `receiveBroadcastStream()` would
  /// take it from the first.
  static final Stream<Map<dynamic, dynamic>> events = const EventChannel(
    'ham2k/usb_serial/events',
  ).receiveBroadcastStream().map((event) => event as Map<dynamic, dynamic>);

  /// Held from the first open on, so the native sink exists before any
  /// port's first bytes do: the stream's first listener is what sets it,
  /// and a connection only subscribes once its open has answered.
  static StreamSubscription<Map<dynamic, dynamic>>? _keepListening;

  static Future<List<AndroidUsbDevice>> list() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('list');
    return [for (final entry in raw ?? const []) AndroidUsbDevice.fromMap(entry as Map)];
  }

  /// Opens [port] (an ordinal among the device's serial ports) and returns
  /// its handle. Puts Android's USB-permission dialog up first when the app
  /// has no grant for the device, and waits on the operator's answer.
  ///
  /// [dtr] and [rts] null leave the line alone. Throws [PlatformException]
  /// whose code [androidUsbFailure] reads.
  static Future<int> open({
    required String deviceName,
    required int port,
    String? driver,
    required int baudRate,
    required int stopBits,
    bool? dtr,
    bool? rts,
  }) async {
    _keepListening ??= events.listen((_) {});
    final handle = await _channel.invokeMethod<int>('open', {
      'deviceName': deviceName,
      'port': port,
      'driver': driver,
      'baudRate': baudRate,
      'stopBits': stopBits,
      'dtr': dtr,
      'rts': rts,
    });
    return handle!;
  }

  static Future<void> write(int handle, Uint8List bytes) => _channel.invokeMethod<void>('write', {'handle': handle, 'bytes': bytes});

  static Future<void> close(int handle) => _channel.invokeMethod<void>('close', {'handle': handle});
}
