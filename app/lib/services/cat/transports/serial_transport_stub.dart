// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web fallback. Like the TCP stub this throws rather than no-opping —
// reaching it means a platform gate is missing, and a silent no-op would
// present a radio as merely "not connected" forever. Enumeration returns
// empty instead: "no ports here" is a true answer, and the port picker asks
// before anyone has chosen to connect.
//
// This is what a Chromium web build (Web Serial API) will eventually
// replace — see HALO-64.

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
