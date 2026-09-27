// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The HRD, N3FJP and DXLab Commander pairings as configurable equipment:
// a program on the operator's machine that owns the radio, reached over the
// shared TCP transport with nothing of its own in connection handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_brands.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/tcp_transport.dart';

void main() {
  final registry = EquipmentRegistry();

  for (final (key, model, port, enabling) in [
    ('hrd-tcp', 'hrd', 7809, 'IP server'),
    ('n3fjp-tcp', 'n3fjp', 1100, 'TCP API Enabled'),
    ('dxlab-commander-tcp', 'dxlab-commander', 52002, 'Net Serv'),
  ]) {
    group(key, () {
      final type = registry.typeFor(key)!;

      test('is a transceiver reached over plain TCP', () {
        expect(type.category, kCategoryTransceiver);
        expect(type.transportKey, TcpTransport.transportKey);
      });

      test('defaults to the program on the same machine, on its own default port', () {
        expect(type.defaultConfig, {'host': '127.0.0.1', 'port': port});
      });

      test('asks for a host and a port, and nothing else', () {
        final keys = [
          for (final e in type.configElements())
            if (e['type'] == 'field') e['key'],
        ];
        expect(keys, ['host', 'port']);
      });

      test('says where in the program its server is turned on', () {
        // Off by default in every one of these programs, and a refused
        // connection is all the app sees of that.
        final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
        expect(note['text'], contains(enabling));
      });

      test('is shelved with the other programs, not under a maker', () {
        // Nothing derives the shelf list; one left out lands among the radios
        // under "Other Brands".
        expect(softwareIntermediaryModelKeys, contains(model));
        expect(registry.models.where((m) => m.key == model), hasLength(1));
      });

      test('does not discover: the program announces nothing', () {
        expect(type.discoverer, isNull);
      });
    });
  }
}
