// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The fallback for a platform with neither `dart:io` nor `dart:js_interop`
// — in practice, unreachable: every real target is one or the other. Kept
// as the conditional export's required default, the same way
// tcp_transport_web.dart is. A Chromium web build gets the real
// implementation in serial_transport_web.dart instead; Safari/Firefox,
// which have no Web Serial API at all, get the same "no ports here, and
// connecting throws" behavior this file would give, just from that file
// (its own `navigatorSerial == null` checks), not this one.

import '../transport.dart';
import 'serial_transport_config.dart';

class SerialTransport extends EquipmentTransport with SerialTransportConfig {
  const SerialTransport();

  static const transportKey = 'serial';

  @override
  String get key => transportKey;

  @override
  List<SerialPortOption> get availablePorts => availableSerialPorts();

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    throw UnsupportedError('CAT control needs a serial port, which the web build does not have.');
  }
}

/// Ports the app could open, newest enumeration each call.
List<SerialPortOption> availableSerialPorts() => const [];
