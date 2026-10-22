// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_i18n/halo_i18n.dart';

import 'driver.dart';
import 'drivers/kenwood_driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/serial_transport.dart';
import 'transports/tcp_transport.dart';
import 'transports/k4_remote_transport.dart';

const _keyers = {KenwoodDriver.cwDialectKey: 'elecraft', KenwoodDriver.voiceDialectKey: 'k4', KenwoodDriver.voiceMemoriesKey: 8, voiceCeilingConfigKey: 90};

/// The local links carry plain CAT; the secure remote link multiplexes CAT
/// and spectrum on one authenticated connection.
const k4Model = EquipmentModel(
  key: 'k4',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _name,
  variants: [
    EquipmentVariant(
      key: 'k4-serial',
      driver: KenwoodDriver.k4(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 38400},
      overrides: _keyers,
      notes: _serialNotes,
    ),
    EquipmentVariant(
      key: 'k4-tcp',
      driver: KenwoodDriver.k4(lanSpectrum: true),
      transport: TcpTransport(portConfigKey: 'tcpPort'),
      defaultConfig: {'tcpPort': 9200},
      overrides: _keyers,
      notes: _tcpNotes,
    ),
    EquipmentVariant(
      key: 'k4-remote',
      driver: KenwoodDriver.k4(remote: true),
      transport: K4RemoteTransport(),
      defaultConfig: {'remotePort': 9204},
      overrides: _keyers,
      notes: _remoteNotes,
    ),
  ],
);

String _name() => t.settings.station.models.k4;

List<Map<String, dynamic>> _serialNotes() => _notes(t.settings.station.k4SerialNotes);
List<Map<String, dynamic>> _tcpNotes() => _notes(t.settings.station.k4TcpNotes);
List<Map<String, dynamic>> _remoteNotes() => _notes(t.settings.station.k4RemoteNotes);

List<Map<String, dynamic>> _notes(String text) => [
  {'type': 'markdown', 'collapsible': true, 'title': t.settings.station.troubleshootingNotes, 'text': text},
];
