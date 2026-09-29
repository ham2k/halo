// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rigctld pairing as a configurable piece of equipment: what the editor
// asks for, what the transport is handed, and what the list row says. The
// pairing reuses the generic TCP transport wholesale — the point of these
// tests is that nothing rigctld-specific leaked into connection handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/rigctld_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/poll_config.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/tcp_transport.dart';

void main() {
  final type = EquipmentRegistry().typeFor('rigctld-tcp')!;

  test('is a transceiver reached over plain TCP', () {
    expect(type.key, 'rigctld-tcp');
    expect(type.category, kCategoryTransceiver);
    expect(type.transportKey, TcpTransport.transportKey);
    expect(type.driver.key, 'rigctld');
  });

  test('defaults to a daemon on the same machine, on rigctld\'s own port', () {
    expect(type.defaultConfig['host'], '127.0.0.1', reason: 'rigctld usually runs beside the logger; a remote daemon is the exception');
    expect(type.defaultConfig['port'], RigctldDriver.defaultPort);
    expect(RigctldDriver.defaultPort, 4532, reason: "rigctld's default listening port");
  });

  test('asks for a host and a port, and nothing else', () {
    final keys = [
      for (final e in type.configElements())
        if (e['type'] == 'field') e['key'],
    ];
    // Plus the meter and poll cadences, which are how often to ask the
    // daemon rather than where it is — the driver's questions, not the
    // transport's.
    expect(keys, ['host', 'port', telemetryIntervalConfigKey, pollIntervalConfigKey]);
  });

  test('and tells the operator the daemon is theirs to run', () {
    // The failure this pairing actually produces is a refused connection,
    // and every cause lives outside the app — the note is where that is
    // worth saying.
    final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
    expect(note['text'], contains('rigctld'), reason: 'how to start the daemon');
    expect(note['text'], contains('-T'), reason: 'accepting connections from another machine');
  });

  test('does not discover: rigctld announces nothing', () {
    expect(type.discoverer, isNull);
  });

  test('ships verified: a real radio has answered it', () {
    // A real IC-705 behind a real backend has answered this driver; the
    // type picker must not tag it Unverified.
  });

  test('hands the transport exactly what it needs to connect', () {
    expect(type.targetFor({'host': ' 10.0.0.5 ', 'port': 4532}), {'host': '10.0.0.5', 'port': 4532});
  });

  test('the list row says where the daemon is', () {
    expect(type.describeTarget({'host': '127.0.0.1', 'port': 4532}), '127.0.0.1:4532');
  });

  test('a node with no host is refused before a socket is opened', () {
    expect(type.validate({'port': 4532}), isNotNull);
    expect(type.validate({'host': '', 'port': 4532}), isNotNull);
    expect(type.validate({'host': '127.0.0.1', 'port': 0}), isNotNull);
    expect(type.validate({'host': '127.0.0.1', 'port': 4532}), isNull);
  });

  test('the registry offers it over the shared TCP transport', () {
    final registry = EquipmentRegistry();
    expect(registry.typeFor('rigctld-tcp')?.key, 'rigctld-tcp');
    // The transport FlexRadio proved, reused — no rigctld transport exists.
    expect(registry.transportFor('tcp'), isNotNull);
  });
}
