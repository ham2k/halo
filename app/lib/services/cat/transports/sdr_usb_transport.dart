// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR receiver on this computer's USB — docs/design/cat.md § SDR
// receivers. Not a byte stream: the receiver is opened through its vendor's
// library (halo_sdr_usb) and the connection carries it to the session, which
// reads its samples directly. Which receiver comes from the variant's
// [sdrUsbKindConfigKey] override; one transport serves every kind.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_sdr_usb/halo_sdr_usb.dart';

import '../transport.dart';

/// Which receiver: an [SdrUsbKind] name, set by the variant, never shown.
const sdrUsbKindConfigKey = 'sdrUsbKind';

/// One receiver of several of a kind; blank takes the first one found.
const sdrUsbSerialConfigKey = 'sdrUsbSerial';

/// Why a USB receiver could not be opened, in the operator's words: the
/// receiver's own doing, or the computer's, never a fault of ours.
class SdrUsbUnreachable implements CatUnreachable {
  final String message;
  const SdrUsbUnreachable(this.message);

  @override
  String toString() => message;
}

/// The open receiver, carried to the session ([SdrSink.usbDevice]). It has
/// no bytes: [data] never emits, and [send] has nothing to send.
class SdrUsbConnection implements EquipmentConnection {
  final SdrUsbDevice device;
  final _closed = Completer<void>();

  SdrUsbConnection(this.device);

  @override
  Stream<Uint8List> get data => const Stream.empty();

  @override
  Future<void> get closed => _closed.future;

  @override
  void send(List<int> bytes) {}

  @override
  Future<void> close() async {
    if (_closed.isCompleted) return;
    _closed.complete();
    await device.close();
  }
}

class SdrUsbTransport extends EquipmentTransport {
  const SdrUsbTransport();

  static const transportKey = 'sdrUsb';

  @override
  String get key => transportKey;

  /// The desktop app only: the receivers' libraries are desktop libraries.
  @override
  bool get isSupportedOnThisPlatform =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
        _ => false,
      };

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey(sdrUsbSerialConfigKey))
      {
        'type': 'field',
        'fieldType': 'text',
        'key': sdrUsbSerialConfigKey,
        'label': t.settings.station.sdrUsbSerial,
        'description': t.settings.station.sdrUsbSerialDescription,
        'advanced': true,
      },
  ];

  @override
  Set<String> get recognizedConfigKeys => {sdrUsbKindConfigKey, sdrUsbSerialConfigKey};

  @override
  String describeTarget(Map<String, dynamic> config) => switch (config[sdrUsbSerialConfigKey]) {
    final String serial when serial.trim().isNotEmpty => 'USB $serial',
    _ => 'USB',
  };

  static SdrUsbKind? kindOf(Map<String, dynamic> config) => switch (config[sdrUsbKindConfigKey]) {
    final String name => SdrUsbKind.values.where((k) => k.name == name).firstOrNull,
    _ => null,
  };

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final kind = kindOf(target);
    if (kind == null) throw ArgumentError('no $sdrUsbKindConfigKey in $target');
    final st = t.settings.station;
    if (kind == SdrUsbKind.sdrplay && defaultTargetPlatform == TargetPlatform.macOS) throw SdrUsbUnreachable(st.sdrUsbSdrplayOnMac);
    final SdrUsbDevice device;
    try {
      device = await openSdrUsb(kind, serial: (target[sdrUsbSerialConfigKey] as String?) ?? '');
    } on SdrUsbOpenException catch (e) {
      if (!e.unavailable) throw SdrUsbUnreachable(st.sdrUsbOpenFailed(why: e.message));
      throw SdrUsbUnreachable(kind == SdrUsbKind.sdrplay ? st.sdrUsbSdrplayMissing : st.sdrUsbUnavailable);
    }
    // Superseded while it opened: let it go, or it stays held by no one.
    if (cancel.isCancelled) {
      await device.close();
      throw const CatCancelledException();
    }
    return SdrUsbConnection(device);
  }
}
