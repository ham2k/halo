// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radios that speak Icom's CI-V — Icom's own, and the Xiegu X6100 that
// imitates them — over a serial port and, for the Icoms with a LAN port or
// the IC-705's WiFi, the network.

import 'package:halo_i18n/halo_i18n.dart';

import 'driver.dart';
import 'drivers/meter_calibration.dart';
import 'drivers/icom_civ_driver.dart';
import 'drivers/civ_power.dart' show civBandMaxWattsConfigKey;
import 'drivers/civ_codec.dart' show civVoiceMemoryCount;
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/bluetooth_serial_transport.dart';
import 'transports/icom_network_protocol.dart';
import 'transports/icom_network_transport.dart';
import 'transports/icom_network_transport_config.dart';
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
const _ic7300mk2NetworkKey = 'ic7300mk2-network';
const _ic7610NetworkKey = 'ic7610-network';
const _ic7760NetworkKey = 'ic7760-network';
const _ic9700SerialKey = 'ic9700-serial';
const _ic9700NetworkKey = 'ic9700-network';
const _ic905SerialKey = 'ic905-serial';
const _ic905NetworkKey = 'ic905-network';
const _ic7850SerialKey = 'ic7850-serial';
const _ic7850NetworkKey = 'ic7850-network';
const _ic7851SerialKey = 'ic7851-serial';
const _ic7851NetworkKey = 'ic7851-network';

/// Every network entry's prefill for the radio's two UDP ports: its factory
/// ones, shown so the operator has the number to change when the radio's
/// menu or a port forward says otherwise.
const _icomLanPorts = {IcomNetworkTransportConfig.controlPortConfigKey: icomControlPort, IcomNetworkTransportConfig.serialPortConfigKey: icomSerialPort};

// The modes each named radio has — see [civRadioModesConfigKey].
const _civHfModes = ['LSB', 'USB', 'AM', 'CW', 'CW-R', 'RTTY', 'RTTY-R', 'FM'];
const _civDataModes = ['DATA-LSB', 'DATA-USB', 'DATA-FM'];
const _ic705Modes = [..._civHfModes, 'WFM', 'DV', ..._civDataModes];
const _ic7100Modes = [..._civHfModes, 'WFM', 'DV', ..._civDataModes];
// DD on the IC-9700's 1200 MHz band, and ATV on the IC-905's, have no
// mode name in civModeCodes, so neither is offered.
const _civVuDvModes = [..._civHfModes, 'DV', ..._civDataModes];
const _civHfDataModes = [..._civHfModes, ..._civDataModes];
const _ic706Modes = [..._civHfModes, 'WFM'];
const _x6100Modes = ['LSB', 'USB', 'CW', 'CW-R', 'AM', 'FM', 'DATA-LSB', 'DATA-USB'];
const _g90Modes = ['LSB', 'USB', 'CW', 'CW-R', 'AM', 'FM'];

const _ic705SerialKey = 'ic705-serial';
const _ic705BluetoothKey = 'ic705-bluetooth';

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

/// The troubleshooting note for a LAN-port Icom's network variant.
///
/// Such a variant pins its serial sibling's overrides and the network
/// side's controller address, and prefills the radio's factory CI-V
/// address. A prefill, unlike the IC-705's pinned A4 ([ic705Model]): CI-V
/// ADDRESS is in each of these radios' menus, and nothing shows that the
/// network ignores it.
///
/// INFERRED for every radio but the IC-705: the protocol is proven only on
/// an IC-705, and these radios are listed with the same RS-BA1 server
/// function in Icom's RS-BA1 guide (A7463-2EX-8).
List<Map<String, dynamic>> _icomLanNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.ic705TroubleshootingTitle}**\n\n'
        '${t.settings.station.icomLanTroubleshooting}'
        '${_icomTransceiveSection()}',
  },
];

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
        // Icom's CI-V default. The radio's Auto setting is NOT a safe
        // alternative: an IC-7300 on Auto can answer for a minute or so and
        // then go silent, which a fixed rate matching this one avoids.
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
        '${t.settings.station.icomCivTroubleshooting}$extra'
        '${_icomTransceiveSection()}',
  },
];

/// Every Icom has a CI-V Transceive setting, and with it off the driver sees
/// a change made on the radio only at its next poll. Not on the Xiegus that
/// speak CI-V: their menus are not known to carry the setting.
String _icomTransceiveSection() => '\n\n**${t.settings.station.civTransceiveTitle}**\n\n${t.settings.station.civTransceive}';

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
      overrides: {
        civRadioModesConfigKey: _civHfDataModes,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        civScopeConfigKey: true,
        voiceCeilingConfigKey: _icomVoiceSeconds,
      },
      notes: _ic7300SerialNotes,
    ),
  ],
);

String _ic7300Name() => t.settings.station.models.ic7300;

/// The shared CI-V "it connected and says nothing" note, plus whatever this
/// radio adds to it — where to find the MK2, for the IC-7300.
///
/// An entry pinned to [_icomUsbBaud] passes [fixedSpeed] — the bullet that
/// replaces "match the number shown here", since it shows no number.
List<Map<String, dynamic>> _civSerialNotes({String extra = '', String? fixedSpeed, bool icom = true}) => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.civAddressTroubleshootingTitle}**\n\n'
        '${fixedSpeed == null ? t.settings.station.civAddressTroubleshooting : t.settings.station.civAddressFixedSpeedTroubleshooting(speed: fixedSpeed)}$extra'
        '${icom ? _icomTransceiveSection() : ''}',
  },
];

List<Map<String, dynamic>> _ic7300SerialNotes() => _civSerialNotes(extra: t.settings.station.ic7300Mk2Note);

List<Map<String, dynamic>> _ic7300mk2SerialNotes() => _civSerialNotes(fixedSpeed: t.settings.station.icomUsbSpeedFollows);

/// The one CI-V speed the IC-7300 MK2, IC-7610 and IC-7760 entries offer —
/// pinned, so there is no field. 115200 is what the scope needs
/// ([civScopeMinBaud]). The MK2 and IC-7760 have no USB speed menu at all:
/// Icom's manuals say they talk at whatever rate the computer uses. The
/// IC-7610's USB speed ships on Auto.
const _icomUsbBaud = 115200;

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
      defaultConfig: {'civAddress': 'B6', 'baudRate': _icomUsbBaud},
      overrides: {..._ic7300mk2Overrides, 'baudRate': _icomUsbBaud},
      // Unlike the original IC-7300's single bridge, the MK2 presents two
      // USB serial ports of Icom's own (0c26:0052).
      restrictions: {'port': _icomCatPort},
      notes: _ic7300mk2SerialNotes,
    ),
    EquipmentVariant(
      key: _ic7300mk2NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': 'B6', ..._icomLanPorts},
      overrides: {..._ic7300mk2Overrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

const _ic7300mk2Overrides = {
  civAntennaPortsConfigKey: 1,
  civRadioModesConfigKey: _civHfDataModes,
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: civVoiceMemoryCount,
  civScopeConfigKey: true,
  voiceCeilingConfigKey: _icomVoiceSeconds,
};

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
      //
      // Nor does its CI-V table have the DATA submode read (0x1A 0x06).
      overrides: {civRadioModesConfigKey: _ic706Modes, cwKeyerConfigKey: false, voiceMemoriesConfigKey: 0, meterInfoConfigKey: '', civDataModeConfigKey: false},
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
      overrides: {civRadioModesConfigKey: _ic7100Modes, cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0},
      notes: _ic7100SerialNotes,
    ),
  ],
);

String _ic7100Name() => t.settings.station.models.ic7100;

/// The address note plus the family's two-port one: this radio presents both
/// ports and now has one of them marked, so the operator gets the reason for
/// the marker and the escape hatch if it points the wrong way.
List<Map<String, dynamic>> _ic7610SerialNotes() =>
    _civSerialNotes(fixedSpeed: t.settings.station.ic7610UsbSpeed, extra: '\n\n${t.settings.station.icomCivTroubleshooting}');

/// Icom IC-7610 over its built-in USB CI-V port.
///
/// At [_icomUsbBaud], which its CI-V USB Baud Rate menu has to match — a
/// speed mismatch is answered with silence.
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
      defaultConfig: {'civAddress': '98', 'baudRate': _icomUsbBaud},
      overrides: {..._ic7610Overrides, 'baudRate': _icomUsbBaud},
      restrictions: {'port': _icomCatPort},
      notes: _ic7610SerialNotes,
    ),
    EquipmentVariant(
      key: _ic7610NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': '98', ..._icomLanPorts},
      overrides: {..._ic7610Overrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

const _ic7610Overrides = {
  civAntennaPortsConfigKey: 2,
  civRadioModesConfigKey: _civHfDataModes,
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: civVoiceMemoryCount,
  civScopeConfigKey: true,
  voiceCeilingConfigKey: _icomVoiceSeconds,
};

String _ic7610Name() => t.settings.station.models.ic7610;

List<Map<String, dynamic>> _ic7760SerialNotes() =>
    _civSerialNotes(fixedSpeed: t.settings.station.icomUsbSpeedFollows, extra: t.settings.station.ic7760PortNote);

/// Icom IC-7760 over CI-V.
///
/// Two serial ports appear for the one radio and only Port A carries CI-V,
/// which the OS gives no way to tell apart — so the note says which, since
/// the wrong one connects and then says nothing. A 200 W radio: on the
/// driver's assumed 100 W ceiling every power reading shows half.
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
      defaultConfig: {'civAddress': 'B2', 'baudRate': _icomUsbBaud},
      overrides: {..._ic7760Overrides, 'baudRate': _icomUsbBaud},
      restrictions: {'port': _icomCatPort},
      notes: _ic7760SerialNotes,
    ),
    EquipmentVariant(
      key: _ic7760NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': 'B2', ..._icomLanPorts},
      overrides: {..._ic7760Overrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

const _ic7760Overrides = {
  civAntennaPortsConfigKey: 4,
  civRadioModesConfigKey: _civHfDataModes,
  'maxWatts': 200,
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: civVoiceMemoryCount,
  civScopeConfigKey: true,
  voiceCeilingConfigKey: _icomVoiceSeconds,
};

String _ic7760Name() => t.settings.station.models.ic7760;

/// Icom IC-9700 over CI-V or its LAN port.
///
/// From Icom's IC-9700 CI-V guide (A7508-3EX-4) and basic manual
/// (A7508H-1EX-7): address A2; no 0x12, one antenna connector per band;
/// scope, eight voice memories and 0x17 CW. Its USB CI-V speed ships on
/// Auto, which the shared note says to change to the number here. Rated
/// 100 W on 2 m, 75 W on 70 cm and 10 W on 23 cm, each band's 0x14 0x0A
/// scale running to its own.
const ic9700Model = EquipmentModel(
  key: 'ic9700',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic9700Name,
  variants: [
    EquipmentVariant(
      key: _ic9700SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'A2', 'baudRate': 19200},
      overrides: _ic9700Overrides,
      restrictions: {'port': _icomCatPort},
      notes: _civSerialNotes,
    ),
    EquipmentVariant(
      key: _ic9700NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': 'A2', ..._icomLanPorts},
      overrides: {..._ic9700Overrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

const _ic9700Overrides = {
  civRadioModesConfigKey: _civVuDvModes,
  civBandMaxWattsConfigKey: [
    [300000000, 75],
    [1000000000, 10],
  ],
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: civVoiceMemoryCount,
  civScopeConfigKey: true,
  voiceCeilingConfigKey: _icomVoiceSeconds,
};

String _ic9700Name() => t.settings.station.models.ic9700;

/// Icom IC-905 over CI-V or its controller's LAN port.
///
/// From Icom's IC-905 CI-V guide (A7711-9EX-2) and basic manual
/// (A7711D-1EX): address AC; no 0x12; scope, eight voice memories and 0x17
/// CW. It has no CI-V speed menu at all — a USB virtual COM port only — so
/// the prefill is the 115200 the scope needs. Icom says any rate works on
/// the IC-7760's and IC-7300 MK2's ports; it does not say so for this
/// one. Its 10 GHz band takes
/// six-byte frequencies (see [encodeBcdFrequency]); the scope's centre
/// does too there, which [CivScopeAssembler] does not read, so a sweep on
/// that band is not drawn. 10 W on 144-1200 MHz and 2 W on 2400 and 5600
/// MHz (the basic manual), and 0.5 W on 10 GHz — INFERRED: the basic manual
/// defers to the CX-10G's.
const ic905Model = EquipmentModel(
  key: 'ic905',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic905Name,
  variants: [
    EquipmentVariant(
      key: _ic905SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': 'AC', 'baudRate': 115200},
      overrides: _ic905Overrides,
      restrictions: {'port': _icomCatPort},
      notes: _civSerialNotes,
    ),
    EquipmentVariant(
      key: _ic905NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': 'AC', ..._icomLanPorts},
      overrides: {..._ic905Overrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

const _ic905Overrides = {
  civRadioModesConfigKey: _civVuDvModes,
  'maxWatts': 10,
  civBandMaxWattsConfigKey: [
    [2000000000, 2],
    [10000000000, 0.5],
  ],
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: civVoiceMemoryCount,
  civScopeConfigKey: true,
  voiceCeilingConfigKey: _icomVoiceSeconds,
};

String _ic905Name() => t.settings.station.models.ic905;

/// Icom IC-7850 and IC-7851 — two entries for one radio line, so that each
/// is found by the name on its front panel.
///
/// From Icom's IC-7850/7851 instruction manual (A7205H-1EX-3): address 8E
/// on both, four antenna ports on 0x12, 200 W, eight voice memories and
/// 0x17 CW. The scope (0x27) arrived in firmware 1.10. The USB CI-V speed
/// ships on Auto, and before firmware 1.40 the USB port shares the [REMOTE]
/// jack's speed, which tops out at 19200 — the rate prefilled here. Its
/// PSK modes have no name in civModeCodes, so they are not offered. No CAT
/// port is claimed: nothing says it presents two USB ports of its own.
const _ic785xOverrides = {
  civAntennaPortsConfigKey: 4,
  civRadioModesConfigKey: _civHfDataModes,
  'maxWatts': 200,
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: civVoiceMemoryCount,
  civScopeConfigKey: true,
  voiceCeilingConfigKey: _icomVoiceSeconds,
};

/// See [_ic785xOverrides].
const ic7850Model = EquipmentModel(
  key: 'ic7850',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7850Name,
  variants: [
    EquipmentVariant(
      key: _ic7850SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '8E', 'baudRate': 19200},
      overrides: _ic785xOverrides,
      notes: _civSerialNotes,
    ),
    EquipmentVariant(
      key: _ic7850NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': '8E', ..._icomLanPorts},
      overrides: {..._ic785xOverrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

String _ic7850Name() => t.settings.station.models.ic7850;

/// See [_ic785xOverrides].
const ic7851Model = EquipmentModel(
  key: 'ic7851',
  manufacturer: icomBrand,
  category: kCategoryTransceiver,
  name: _ic7851Name,
  variants: [
    EquipmentVariant(
      key: _ic7851SerialKey,
      driver: IcomCivDriver(),
      transport: SerialTransport(),
      defaultConfig: {'civAddress': '8E', 'baudRate': 19200},
      overrides: _ic785xOverrides,
      notes: _civSerialNotes,
    ),
    EquipmentVariant(
      key: _ic7851NetworkKey,
      driver: IcomCivDriver(),
      transport: IcomNetworkTransport(),
      defaultConfig: {'civAddress': '8E', ..._icomLanPorts},
      overrides: {..._ic785xOverrides, 'civControllerAddress': icomNetworkControllerAddress},
      notes: _icomLanNotes,
    ),
  ],
);

String _ic7851Name() => t.settings.station.models.ic7851;

List<Map<String, dynamic>> _x6100SerialNotes() => _civSerialNotes(extra: t.settings.station.x6100PortNote, icom: false);

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
      //
      // 10 W is its rating on external DC. No batteryMaxWatts for its 5 W on
      // the internal pack: the battery check is a raw threshold measured on
      // the IC-705's 7.4 V pack, and a 12 V pack would not be expected to
      // read below it. So on its own pack it reports up to 10 W while
      // putting out 5.
      //
      // No filter-width command (hamlib's `x1ax03_supported`), so the width
      // is never asked.
      overrides: {civRadioModesConfigKey: _x6100Modes, 'maxWatts': 10, cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0, civFilterWidthConfigKey: false},
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
/// CW text and no voice memories, so neither keyer is offered. Like the
/// X6100 it has no filter-width command (hamlib's `x1ax03_supported`); its
/// tuner read is the Icom one (`0x1C 0x01`, per the Radioddity CAT manual
/// hamlib cites).
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
      overrides: {
        civRadioModesConfigKey: _g90Modes,
        civModeWithFilterConfigKey: true,
        civDataModeConfigKey: false,
        civFilterWidthConfigKey: false,
        'maxWatts': 20,
        cwKeyerConfigKey: false,
        voiceMemoriesConfigKey: 0,
      },
      notes: _g90SerialNotes,
    ),
  ],
);

String _g90Name() => t.settings.station.models.g90;

List<Map<String, dynamic>> _g90SerialNotes() => _civSerialNotes(icom: false);

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
      defaultConfig: _icomLanPorts,
      overrides: {
        civRadioModesConfigKey: _ic705Modes,
        'civAddress': 'A4',
        'civControllerAddress': icomNetworkControllerAddress,
        // The IC-705's real ceiling (10W SSB/CW) — see civAssumedMaxWatts in
        // civ_power.dart. A device fact, not something the operator
        // picked, so it's an override like the addresses above.
        'maxWatts': 10,
        // On its own battery the radio caps actual output well below the
        // SET level it keeps reporting — see civMeterDcInputVoltage.
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        civScopeConfigKey: true,
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
        civRadioModesConfigKey: _ic705Modes,
        'maxWatts': 10,
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        civScopeConfigKey: true,
        voiceCeilingConfigKey: _icomVoiceSeconds,
      },
      // The radio [_icomCatPort] was actually observed on: two ports under
      // one name, nothing but their order to tell them apart.
      restrictions: {'port': _icomCatPort},
      notes: _ic705SerialNotes,
    ),
    // The radio's Bluetooth "data device" carries CI-V once it is paired with
    // this machine. The same serial settings as the USB variant, which the
    // registry's self-checks require — the editor shows one box per key.
    EquipmentVariant(
      key: _ic705BluetoothKey,
      driver: IcomCivDriver(),
      transport: BluetoothSerialTransport(),
      defaultConfig: {'civAddress': 'A4', 'baudRate': 19200},
      overrides: {
        civRadioModesConfigKey: _ic705Modes,
        'maxWatts': 10,
        'batteryMaxWatts': 5,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: civVoiceMemoryCount,
        voiceCeilingConfigKey: _icomVoiceSeconds,
      },
      notes: _icomGenericSerialNotes,
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
        '${t.settings.station.ic705Troubleshooting}'
        '${_icomTransceiveSection()}',
  },
];
