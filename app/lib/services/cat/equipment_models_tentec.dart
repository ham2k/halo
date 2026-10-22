// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Ten-Tec radios that speak the Orion command set (tentec_codec.dart):
// the Eagle, the Orion and the Orion II. Ten-Tec's other CAT radios — the
// Omni VII, the Argonaut VI, the Jupiter — speak other protocols and are
// not here.
//
// Written from Ten-Tec's programmer's reference guides and run against no
// radio.

import 'package:halo_i18n/halo_i18n.dart';

import 'drivers/tentec_codec.dart';
import 'drivers/tentec_driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/serial_transport.dart';

/// Ten-Tec Eagle (599, and the 599AT with its tuner), over the USB-B port
/// on its back.
///
/// That port is the radio's own USB serial device, not an adapter: nothing
/// on it is wired to PTT or keying, so RTS and DTR are left as the operator
/// sets them, like any other port.
const tenTecEagleModel = EquipmentModel(
  key: 'tentec-599',
  manufacturer: tenTecBrand,
  category: kCategoryTransceiver,
  name: _eagleName,
  variants: [
    EquipmentVariant(
      key: 'tentec-599-serial',
      driver: TenTecDriver(),
      transport: SerialTransport(),
      // Pinned AND prefilled: the override hides the field, and the prefill is
      // what a Bluetooth LE pairing budgets its link by.
      defaultConfig: {'baudRate': tenTecBaudRate},
      overrides: {TenTecDriver.dialectConfigKey: 'eagle', 'baudRate': tenTecBaudRate},
      notes: _eagleNotes,
    ),
  ],
);

/// Ten-Tec Orion (565), over its DB-9 SERIAL DATA port.
const tenTecOrionModel = EquipmentModel(
  key: 'tentec-565',
  manufacturer: tenTecBrand,
  category: kCategoryTransceiver,
  name: _orionName,
  variants: [
    EquipmentVariant(
      key: 'tentec-565-serial',
      driver: TenTecDriver(),
      transport: SerialTransport(),
      defaultConfig: _orionDefaults,
      overrides: _orionOverrides,
      notes: _orionNotes,
    ),
  ],
);

/// Ten-Tec Orion II (566), on the same guide and port as [tenTecOrionModel].
const tenTecOrionIIModel = EquipmentModel(
  key: 'tentec-566',
  manufacturer: tenTecBrand,
  category: kCategoryTransceiver,
  name: _orionIIName,
  variants: [
    EquipmentVariant(
      key: 'tentec-566-serial',
      driver: TenTecDriver(),
      transport: SerialTransport(),
      defaultConfig: _orionDefaults,
      overrides: _orionOverrides,
      notes: _orionNotes,
    ),
  ],
);

const _orionOverrides = {TenTecDriver.dialectConfigKey: 'orion', 'baudRate': tenTecBaudRate};

/// RTS held high, which almost no other entry does: the Orion's guide wires
/// a straight-through DB-9 with RTS and CTS as its hardware handshake, so on
/// its port RTS says "send to me", and held low it may tell the radio never
/// to answer. A default rather than an override, because an interface that
/// keys PTT from RTS — a Digirig — would transmit with it, and that is the
/// operator's to switch off.
const _orionDefaults = {serialRtsHighConfigKey: true, 'baudRate': tenTecBaudRate};

String _eagleName() => t.settings.station.models.tenTecEagle;
String _orionName() => t.settings.station.models.tenTecOrion;
String _orionIIName() => t.settings.station.models.tenTecOrionII;

List<Map<String, dynamic>> _eagleNotes() => _notes(t.settings.station.tenTecEagleTroubleshooting);
List<Map<String, dynamic>> _orionNotes() => _notes(t.settings.station.tenTecOrionTroubleshooting);

List<Map<String, dynamic>> _notes(String text) => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text': '**${t.settings.station.tenTecTroubleshootingTitle}**\n\n$text',
  },
];
