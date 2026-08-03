// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The flrig pairing as a configurable piece of equipment: what the editor
// asks for, what the transport is handed, and what the list row says. The
// pairing reuses the generic TCP transport wholesale — the point of these
// tests is that nothing flrig-specific leaked into connection handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/flrig_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/tcp_transport.dart';

void main() {
  final type = flrigTcpType;

  test('is a transceiver reached over plain TCP', () {
    expect(type.key, 'flrig-tcp');
    expect(type.category, kCategoryTransceiver);
    expect(type.transportKey, TcpTransport.transportKey);
    expect(type.driver.key, 'flrig');
  });

  test('defaults to an flrig on the same machine, on flrig\'s own port', () {
    expect(type.defaultConfig['host'], '127.0.0.1',
        reason: 'flrig usually runs beside the logger; a remote instance is the exception');
    expect(type.defaultConfig['port'], FlrigDriver.defaultPort);
    expect(FlrigDriver.defaultPort, 12345, reason: "flrig's default XML-RPC port");
  });

  test('asks for a host and a port, and nothing else', () {
    final keys = [
      for (final e in type.configElements())
        if (e['type'] == 'field') e['key'],
    ];
    expect(keys, ['host', 'port']);
  });

  test('and tells the operator flrig is theirs to run', () {
    // The failure this pairing actually produces is a refused connection,
    // and every cause lives outside the app — the note is where that is
    // worth saying.
    final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
    expect(note['text'], contains('flrig'), reason: 'the program is the operator\'s to run');
    expect(note['text'], contains('12345'), reason: 'where to look when the port was changed');
  });

  test('does not discover: flrig announces nothing', () {
    expect(type.discoverer, isNull);
  });

  test('ships verified: a real radio has answered it', () {
    // A real IC-705 behind a real flrig has answered this driver; the
    // type picker must not tag it Unverified.
    expect(type.hardwareVerified, isTrue);
  });

  test('hands the transport exactly what it needs to connect', () {
    expect(type.targetFor({'host': ' 10.0.0.5 ', 'port': 12345}), {'host': '10.0.0.5', 'port': 12345});
  });

  test('the list row says where flrig is', () {
    expect(type.describeTarget({'host': '127.0.0.1', 'port': 12345}), '127.0.0.1:12345');
  });

  test('a node with no host is refused before a socket is opened', () {
    expect(type.validate({'port': 12345}), isNotNull);
    expect(type.validate({'host': '', 'port': 12345}), isNotNull);
    expect(type.validate({'host': '127.0.0.1', 'port': 0}), isNotNull);
    expect(type.validate({'host': '127.0.0.1', 'port': 12345}), isNull);
  });

  test('the registry offers it over the shared TCP transport', () {
    final registry = EquipmentRegistry();
    expect(registry.typeFor('flrig-tcp'), same(flrigTcpType));
    // The transport FlexRadio proved, reused — no flrig transport exists.
    expect(registry.transportFor('tcp'), isNotNull);
  });
}
