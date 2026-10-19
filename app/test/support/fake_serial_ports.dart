// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport_config.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart';

/// Gives native catalogue/form tests a port list independent of the machine.
/// Call from a test or setUp so the enumerator is restored at teardown.
void useSerialPortsForTest(List<SerialPortOption> ports) {
  final previous = SerialTransport.debugPortEnumerator;
  SerialTransport.debugPortEnumerator = () => ports;
  addTearDown(() => SerialTransport.debugPortEnumerator = previous);
}
