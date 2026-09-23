// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radios that speak Icom's CI-V — Icom's own, and the Xiegu X6100 that
// imitates them — over a serial port and, for the IC-705, the network.

import 'package:halo_i18n/halo_i18n.dart';

import 'driver.dart';
import 'drivers/meter_calibration.dart';
import 'drivers/icom_civ_driver.dart';
import 'drivers/civ_codec.dart' show civVoiceMemoryCount;
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/icom_network_protocol.dart';
import 'transports/icom_network_transport.dart';
import 'transports/serial_transport.dart';

const _icomGenericSerialKey = 'icom-generic-serial';
const _ic7300SerialKey = 'ic7300-serial';
const _ic7300mk2SerialKey = 'ic7300mk2-serial';
const _ic706mkiigSerialKey = 'ic706mkiig-serial';
const _ic7100SerialKey = 'ic7100-serial';
const _ic7610SerialKey = 'ic7610-serial';
const _ic7760SerialKey = 'ic7760-serial';
const _x6100SerialKey = 'x6100-serial';
const _g90SerialKey = 'g90-serial';
const _ic705NetworkKey = 'ic705-network';
const _ic705SerialKey = 'ic705-serial';

/// How long an Icom voice memory holds — "up to 1.5 minutes" per the
/// IC-7300's manual, and the line's figure.
const _icomVoiceSeconds = 90;

/// Where CI-V sits when an Icom presents more than one USB serial port OF ITS
/// OWN — which is what limits who may declare it.
///
/// Icom calls them Port A and Port B, ships both set to CI-V, and puts CI-V
/// on Port A — the first the OS enumerates. The picker POINTS at that port
/// and hides nothing (serial_transport_config.dart), which is what makes one
/// claim across the catalogue reasonable: a radio whose ports the platform
/// cannot split is unaffected, and a radio that turns out to differ costs a
/// bold row on the wrong one while the right one stays a tap away. It is
/// also why the operator who deliberately moved CI-V to Port B is not shut
/// out: were this a filter rather than a ranking, that operator would face a
/// picker offering only the port their radio does not answer on.
///
/// A radio with one USB port, or none at all — the IC-706MKIIG reaches CI-V
/// through a level converter — declares nothing. On those the only ports to
/// rank are the operator's own cable's, and Icom's convention says nothing
/// about which channel of somebody else's dual bridge carries CI-V; the
/// other one is usually PTT, which picks and then answers nothing.
///
/// OBSERVED on two radios: an IC-705 over USB on Android, which presents
/// both ports under its own name with nothing else to tell them apart, and
/// the IC-7300 MK2, whose operators connect on Port A — though some on
/// Port B too, which is why this ranks rather than filters. Every other
/// model here is INFERRED from Icom's convention and their shared CDC/ACM
/// shape, where Port A is the first data interface. Treat a report that
/// contradicts it as the better evidence.
const _icomCatPort = {'index': 0};

/// Any Icom transceiver over CI-V on a serial port — the IC-705's USB
/// connection, and equally an IC-7300 or IC-9700 with a different address.
///
/// The CI-V address is configuration rather than a constant because it is
/// settable on the radio, and because a wrong one is silent: the radio
/// simply ignores frames addressed elsewhere, which looks exactly like a
/// dead cable.
///
/// Verified over the wire as well as over the network: CI-V on a serial port
/// is what an IC-7300 and an IC-706MKIIG both run on here.
const icomGenericModel = EquipmentModel(
  key: 'icom-generic',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _icomGenericName,
  variants: [
    EquipmentVariant(
      key: _icomGenericSerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {
        // The IC-705's factory address, and the most likely radio here.
        'civAddress': 'A4',
        // Icom's CI-V default. The radio can also be set to Auto, which
        // negotiates nothing and simply follows the host.
        'baudRate': 19200,
        // Off until a developer says otherwise — see keyer_config.dart.
        cwKeyerConfigKey: false,
        voiceMemoriesConfigKey: 0,
      },
      restrictions: {'port': _icomCatPort},
      notes: _icomGenericSerialNotes,
    ),
  ],
);

String _icomGenericName() => t.settings.station.models.icomGeneric;

List<Map<String, dynamic>> _icomGenericSerialNotes({String extra = ''}) => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.icomCivTroubleshootingTitle}**\n\n'
        '${t.settings.station.icomCivTroubleshooting}$extra',
  },
];

/// Icom IC-7300 over its built-in USB CI-V port.
///
/// The address is a default rather than an override even though the model is
/// named: CI-V ADDRESS is in the radio's own menu, and a rig sharing a bus is
/// exactly where it gets changed. The MK2 ships on a different address and is
/// its own entry — see [ic7300mk2Model].
const ic7300Model = EquipmentModel(
  key: 'ic7300',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7300Name,
  variants: [
    EquipmentVariant(
      key: _ic7300SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '94', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      notes: _ic7300SerialNotes,
    ),
  ],
);

String _ic7300Name() => t.settings.station.models.ic7300;

/// The shared CI-V "it connected and says nothing" note, plus whatever this
/// radio adds to it — where to find the MK2, for the IC-7300.
List<Map<String, dynamic>> _civSerialNotes({String extra = ''}) => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.civAddressTroubleshootingTitle}**\n\n'
        '${t.settings.station.civAddressTroubleshooting}$extra',
  },
];

List<Map<String, dynamic>> _ic7300SerialNotes() => _civSerialNotes(extra: t.settings.station.ic7300Mk2Note);

List<Map<String, dynamic>> _ic7300mk2SerialNotes() => _civSerialNotes();

/// Icom IC-7300 MK2 over its built-in USB CI-V port.
///
/// Its own model rather than a note on [ic7300Model]: an operator picks the
/// name on the front of their radio, and the whole point of a named entry is
/// that the address is already right. The two radios share a driver and
/// differ in the address they ship on and in the USB ports they present.
const ic7300mk2Model = EquipmentModel(
  key: 'ic7300mk2',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7300mk2Name,
  variants: [
    EquipmentVariant(
      key: _ic7300mk2SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'B6', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      // Unlike the original IC-7300's single bridge, the MK2 presents two
      // USB serial ports of Icom's own (0c26:0052).
      restrictions: {'port': _icomCatPort},
      notes: _ic7300mk2SerialNotes,
    ),
  ],
);

String _ic7300mk2Name() => t.settings.station.models.ic7300mk2;

List<Map<String, dynamic>> _ic706mkiigSerialNotes() => _civSerialNotes();

/// Icom IC-706MKIIG over CI-V — an external level converter or CI-V cable,
/// since the radio has no USB of its own. Same driver as every other CI-V
/// rig; only the factory address differs.
const ic706mkiigModel = EquipmentModel(
  key: 'ic706mkiig',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic706mkiigName,
  variants: [
    EquipmentVariant(
      key: _ic706mkiigSerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '58', 'baudRate': 19200},
      // No voice keyer, no text keying and no TX meters on this generation:
      // the driver's defaults are the modern line's, and a play or a message
      // here would show as going out while the radio silently ignored it.
      //
      // The empty meterInfo is the same statement about meters, and it has to
      // be said out loud — inheriting the driver's default would reserve
      // power, SWR and ALC slots on a panel where they can never fill. This
      // radio's CI-V table gives command 0x15 exactly two sub-commands, 01
      // squelch and 02 S-meter; the TX meters arrived a generation later.
      overrides: {cwKeyerConfigKey: false, voiceMemoriesConfigKey: 0, meterInfoConfigKey: ''},
      notes: _ic706mkiigSerialNotes,
    ),
  ],
);

String _ic706mkiigName() => t.settings.station.models.ic706mkiig;

List<Map<String, dynamic>> _ic7100SerialNotes() => _civSerialNotes();

/// Icom IC-7100 over its built-in USB CI-V port.
///
/// Keys through 0x17 like the rest of the line; its voice memories are not
/// known to be reachable over CI-V, so none are offered — a play would show
/// as going out while the radio ignored it.
const ic7100Model = EquipmentModel(
  key: 'ic7100',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7100Name,
  variants: [
    EquipmentVariant(
      key: _ic7100SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '88', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0},
      notes: _ic7100SerialNotes,
    ),
  ],
);

String _ic7100Name() => t.settings.station.models.ic7100;

/// The address note plus the family's two-port one: this radio presents both
/// ports and now has one of them marked, so the operator gets the reason for
/// the marker and the escape hatch if it points the wrong way.
List<Map<String, dynamic>> _ic7610SerialNotes() => _civSerialNotes(extra: '\n\n${t.settings.station.icomCivTroubleshooting}');

/// Icom IC-7610 over its built-in USB CI-V port.
///
/// 9600 is the radio's own default rather than the CI-V family's 19200, and a
/// speed mismatch is answered with silence — so the prefill here is the whole
/// reason the model exists. The radio will run far faster once both ends
/// agree, which is a change made in two places, not one.
const ic7610Model = EquipmentModel(
  key: 'ic7610',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7610Name,
  variants: [
    EquipmentVariant(
      key: _ic7610SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '98', 'baudRate': 9600},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      restrictions: {'port': _icomCatPort},
      notes: _ic7610SerialNotes,
    ),
  ],
);

String _ic7610Name() => t.settings.station.models.ic7610;

List<Map<String, dynamic>> _ic7760SerialNotes() => _civSerialNotes(extra: t.settings.station.ic7760PortNote);

/// Icom IC-7760 over CI-V.
///
/// Two serial ports appear for the one radio and only Port A carries CI-V,
/// which the OS gives no way to tell apart — so the note says which, since
/// the wrong one connects and then says nothing.
const ic7760Model = EquipmentModel(
  key: 'ic7760',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7760Name,
  variants: [
    EquipmentVariant(
      key: _ic7760SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'B2', 'baudRate': 19200},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: civVoiceMemoryCount, voiceCeilingConfigKey: _icomVoiceSeconds},
      restrictions: {'port': _icomCatPort},
      notes: _ic7760SerialNotes,
    ),
  ],
);

String _ic7760Name() => t.settings.station.models.ic7760;

List<Map<String, dynamic>> _x6100SerialNotes() => _civSerialNotes(extra: t.settings.station.x6100PortNote);

/// Xiegu X6100 — a Xiegu radio that happens to speak Icom's CI-V, not the
/// Kenwood protocol its documentation and much of the community suggest.
///
/// Named here because the protocol is not guessable from the brand: an
/// operator hunting for "Xiegu" would otherwise reach for Kenwood - Generic,
/// which connects to the radio and never gets an answer.
const x6100Model = EquipmentModel(
  key: 'x6100',
  manufacturer: xieguBrand,
  category: kCategoryTransceiver,
  name: _x6100Name,
  variants: [
    EquipmentVariant(
      key: _x6100SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'A4', 'baudRate': 19200},
      // Keys through 0x17 like the Icoms it imitates; whether it has voice
      // memories reachable over CI-V is undocumented, so none are offered.
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0},
      // CI-V is on the second of the radio's two serial ports; the picker
      // points at that one where it can, and never hides the other.
      restrictions: {
        'port': {'index': 1},
      },
      notes: _x6100SerialNotes,
    ),
  ],
);

String _x6100Name() => t.settings.station.models.x6100;

/// Xiegu G90, which speaks CI-V on its USB port at hamlib's stock address
/// and rate.
///
/// Unlike the X6100 it ignores a mode set with no filter byte, so the entry
/// pins [civModeWithFilterConfigKey]: an operator on the generic Icom entry
/// reported frequency control working and mode changes doing nothing. Its
/// 20 W ceiling is a device fact, like the IC-705's 10. hamlib sends it no
/// CW text and no voice memories, so neither keyer is offered.
const g90Model = EquipmentModel(
  key: 'g90',
  manufacturer: xieguBrand,
  category: kCategoryTransceiver,
  name: _g90Name,
  variants: [
    EquipmentVariant(
      key: _g90SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '88', 'baudRate': 19200},
      overrides: {civModeWithFilterConfigKey: true, 'maxWatts': 20, cwKeyerConfigKey: false, voiceMemoriesConfigKey: 0},
      notes: _civSerialNotes,
    ),
  ],
);

String _g90Name() => t.settings.station.models.g90;

/// An IC-705 over WiFi, using Icom's RS-BA1 network protocol.
///
/// Both the CI-V address and the controller address are hardcoded rather
/// than asked for: RS-BA1 only ever talks to the one radio it's paired
/// with, at the IC-705's factory address, and the controller side of a
/// network CI-V exchange is always 0xE1 — a fact about the transport, not a
/// setting, so it never becomes a question in the editor.
///
/// Over USB it is a generic CI-V rig, and [icomGenericModel] would connect it —
/// but only for an operator who already knows their radio speaks CI-V. Named
/// here too, it is found the way it is looked for: by the name on the front
/// of the radio, with the cable as the second question.
const ic705Model = EquipmentModel(
  key: 'ic705',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic705Name,
  // WiFi first: the editor opens on a model's first variant, and this is the
  // one proven against a real radio.
  variants: [
    EquipmentVariant(
      key: _ic705NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      overrides: {
        'civAddress': 'A4',
        'civControllerAddress': icomNetworkControllerAddress,
        // The IC-705's real ceiling (10W SSB/CW) — see _assumedMaxWatts in
        // icom_civ_driver.dart. A device fact, not something the operator
        // picked, so it's an override like the addresses above.
        'maxWatts': 10,
        // On its own battery the radio caps actual output well below the
        // SET level it keeps reporting — see civMeterDcInputVoltage.
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        voiceCeilingConfigKey: _icomVoiceSeconds,
      },
      // The failure this transport actually produces is silence: the
      // handshake succeeds and the login is ignored, so a busy radio and a
      // refusal are indistinguishable from here. Every remedy is something
      // the operator does at the radio or to another program.
      notes: _ic705NetworkNotes,
    ),
    EquipmentVariant(
      key: _ic705SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      // The address is the radio's factory setting rather than a fixed fact
      // about it — CI-V ADDRESS is in the IC-705's own menu, and a radio
      // sharing a bus is exactly where it gets changed. So a default here,
      // unlike the network variant's override, where the RS-BA1 protocol
      // really does fix it.
      defaultConfig: {'civAddress': 'A4', 'baudRate': 19200},
      // Unlike the address, the radio's own power ceiling can't change by
      // sharing a bus — a fixed fact about this model, same as the network
      // variant's override above.
      overrides: {
        'maxWatts': 10,
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        voiceCeilingConfigKey: _icomVoiceSeconds,
      },
      // The radio [_icomCatPort] was actually observed on: two ports under
      // one name, nothing but their order to tell them apart.
      restrictions: {'port': _icomCatPort},
      notes: _ic705SerialNotes,
    ),
  ],
);

String _ic705Name() => t.settings.station.models.ic705;

List<Map<String, dynamic>> _ic705SerialNotes() => _icomGenericSerialNotes(extra: t.settings.station.ic705PortNote);

List<Map<String, dynamic>> _ic705NetworkNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.ic705TroubleshootingTitle}**\n\n'
        '${t.settings.station.ic705Troubleshooting}',
  },
];
