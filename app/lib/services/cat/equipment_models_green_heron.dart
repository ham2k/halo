// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Green Heron Engineering's Everyware server, and the rotors and switches it
// carries (docs/design/cat.md § Green Heron Everyware).

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/everyware_codec.dart';
import 'drivers/everyware_devices.dart';
import 'drivers/everyware_server.dart';
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transports/everyware_transport.dart';

const greenHeronBrand = 'Green Heron Engineering';

const everywareServerTypeKey = 'gh-everyware-tcp';
const everywareRotorTypeKey = 'gh-everyware-rotor';
const everywareSwitchTypeKey = 'gh-everyware-switch';
const everywareDirectionalTypeKey = 'gh-everyware-directional';

/// The server: an address and a login. Added from the catalogue; its devices
/// are added by ticking them in its editor.
const everywareServerModel = EquipmentModel(
  key: 'gh-everyware',
  category: kCategoryStationController,
  name: _serverName,
  manufacturer: greenHeronBrand,
  variants: [
    EquipmentVariant(
      key: everywareServerTypeKey,
      driver: EverywareServerDriver(),
      transport: EverywareServerTransport(),
      defaultConfig: {'port': everywareDefaultPort},
      notes: _serverNotes,
    ),
  ],
);

/// A rotor on a server. Never offered in the catalogue: it exists only under
/// its server.
const everywareRotorModel = EquipmentModel(
  key: 'gh-everyware-rotor',
  category: kCategoryRotator,
  name: _rotorName,
  manufacturer: greenHeronBrand,
  hiddenFromCatalog: true,
  variants: [EquipmentVariant(key: everywareRotorTypeKey, driver: EverywareRotorDriver(), transport: EverywareDeviceTransport())],
);

/// A switch on a server, for its rotor's reason.
const everywareSwitchModel = EquipmentModel(
  key: 'gh-everyware-switch',
  category: kCategoryAntennaSwitch,
  name: _switchName,
  manufacturer: greenHeronBrand,
  hiddenFromCatalog: true,
  variants: [
    EquipmentVariant(
      key: everywareSwitchTypeKey,
      driver: EverywareSwitchDriver(),
      transport: EverywareDeviceTransport(),
      defaultConfig: {everywareFollowRadioConfigKey: everywareFollowRadioA},
    ),
  ],
);

/// A directional switch on a server — a 4-square, a crossfire array — as a
/// rotator: picking one of its directions points the antenna, and the
/// rotator panel is where an operator points one.
const everywareDirectionalModel = EquipmentModel(
  key: 'gh-everyware-directional',
  category: kCategoryRotator,
  name: _directionalName,
  manufacturer: greenHeronBrand,
  hiddenFromCatalog: true,
  variants: [EquipmentVariant(key: everywareDirectionalTypeKey, driver: EverywareDirectionalDriver(), transport: EverywareDeviceTransport())],
);

const greenHeronModels = [everywareServerModel, everywareRotorModel, everywareSwitchModel, everywareDirectionalModel];

String _serverName() => t.settings.station.models.everywareServer;
String _rotorName() => t.settings.station.models.everywareRotor;
String _switchName() => t.settings.station.models.everywareSwitch;
String _directionalName() => t.settings.station.models.everywareDirectional;

List<Map<String, dynamic>> _serverNotes() => [
  {'type': 'markdown', 'collapsible': true, 'title': t.settings.station.troubleshootingNotes, 'text': t.settings.station.everywareTroubleshooting},
];
