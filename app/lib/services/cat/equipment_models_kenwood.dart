// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radios that speak Kenwood CAT: Kenwood's own, Elecraft's, and the QRP
// Labs, BG2FX and Lab599 rigs that answer the same protocol.

import 'package:halo_i18n/halo_i18n.dart';

import 'driver.dart';
import 'drivers/kenwood_cat_codec.dart' show kxVoiceMemoryCount;
import 'drivers/kenwood_driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/bluetooth_serial_transport.dart';
import 'transports/serial_transport.dart';

const _kenwoodSerialKey = 'kenwood-serial';
const _qmxSerialKey = 'qmx-serial';
const _fx4crSerialKey = 'fx4cr-serial';
const _qcxSerialKey = 'qcx-serial';
const _ts590sgSerialKey = 'ts590sg-serial';
const _ts480SerialKey = 'ts480-serial';
const _elecraftSerialKey = 'elecraft-serial';
const _kx2SerialKey = 'kx2-serial';
const _kx3SerialKey = 'kx3-serial';
const _tx500SerialKey = 'tx500-serial';
const _tx500mpSerialKey = 'tx500mp-serial';
const _tx500mpBluetoothKey = 'tx500mp-bluetooth';

/// Kenwood TS-590SG over its built-in USB port, at the 115200 its USB speed
/// menu ships on. The operator who reported it working had set 38400.
///
/// Keys CW through Kenwood's own padded `KY`. No voice memories: playing
/// them needs an optional voice unit the app cannot detect, and a play the
/// radio ignores reads as going out. The `IF` mode offset is left to be
/// learned — the report behind this entry did not record it.
const ts590sgModel = EquipmentModel(
  key: 'ts590sg',
  manufacturer: kenwoodBrand,
  category: kCategoryTransceiver,
  name: _ts590sgName,
  variants: [
    EquipmentVariant(
      key: _ts590sgSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 115200},
      overrides: {
        KenwoodDriver.cwDialectKey: 'kenwood',
        KenwoodDriver.voiceDialectKey: '',
        KenwoodDriver.voiceMemoriesKey: 0,
        KenwoodDriver.dataModeKey: true,
        KenwoodDriver.passbandDialectKey: 'ts590sg',
        KenwoodDriver.antennaDialectKey: 'ts590',
      },
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _ts590sgName() => t.settings.station.models.ts590sg;

/// Kenwood TS-480 (SAT and HX) over its RS-232 CAT port, through a cable
/// such as a Digirig, at the 9600 it was reported working on. Same keyer,
/// voice and `IF` reasoning as [ts590sgModel].
const ts480Model = EquipmentModel(
  key: 'ts480',
  manufacturer: kenwoodBrand,
  category: kCategoryTransceiver,
  name: _ts480Name,
  variants: [
    EquipmentVariant(
      key: _ts480SerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      overrides: {
        KenwoodDriver.cwDialectKey: 'kenwood',
        KenwoodDriver.voiceDialectKey: '',
        KenwoodDriver.voiceMemoriesKey: 0,
        KenwoodDriver.antennaDialectKey: 'twoPort',
      },
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _ts480Name() => t.settings.station.models.ts480;

/// Any radio speaking Kenwood CAT over a serial port — the Kenwood line, and
/// equally the SDR front-ends that implement the same protocol. Elecraft is
/// named separately ([elecraftGenericModel]), because that line answers at a
/// rate this one's default would miss.
///
/// Written from published CAT references rather than from a capture, and
/// proven since against a QRP Labs QMX (see [qmxModel]), an Elecraft KX2 and
/// KX3 (see [kx2Model]) and a Kenwood TS-590SG and TS-480 (see
/// [ts590sgModel]). The one field the references disagree
/// about — where the mode sits inside the `IF` status packet — is learned
/// from the radio at runtime instead of assumed, because a wrong offset would
/// report a plausible wrong mode forever rather than failing. See
/// kenwood_driver.dart.
const kenwoodGenericModel = EquipmentModel(
  key: 'kenwood-generic',
  manufacturer: kenwoodBrand,
  category: kCategoryTransceiver,
  name: _kenwoodGenericName,
  variants: [
    EquipmentVariant(
      key: _kenwoodSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      // No keyer until a developer names a dialect: the line disagrees on
      // both (`KY` padded or not, `PB` with a list to open or not), and
      // the catalogue does not know which Kenwood this is.
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate, voiceMemoriesConfigKey: 0},
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _kenwoodGenericName() => t.settings.station.models.kenwoodGeneric;

List<Map<String, dynamic>> _kenwoodSerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.kenwoodTroubleshootingTitle}**\n\n'
        '${t.settings.station.kenwoodTroubleshooting}',
  },
];

/// QRP Labs QMX, which speaks Kenwood CAT over its USB serial port.
///
/// Pins the `IF` mode offset [KenwoodDriver] would otherwise spend the first
/// seconds of every connection learning — this radio's layout is known. The
/// session still checks it against the radio, so a wrong entry here is caught
/// rather than believed.
const qmxModel = EquipmentModel(
  key: 'qmx',
  manufacturer: qrpLabsBrand,
  category: kCategoryTransceiver,
  name: _qmxName,
  variants: [
    EquipmentVariant(
      key: _qmxSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        // hamlib keys a QMX through the Elecraft-shaped `KY`, but no QRP
        // Labs document says so, and it has no voice memories.
        KenwoodDriver.cwDialectKey: '',
        KenwoodDriver.voiceDialectKey: '',
        KenwoodDriver.voiceMemoriesKey: 0,
      },
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _qmxName() => t.settings.station.models.qmx;

/// BG2FX FX-4CR, which speaks Kenwood CAT over its USB serial port.
///
/// Its own entry rather than a line in the Kenwood generic's notes because
/// the brand gives away the protocol no more than the QMX's does, and
/// because a hardware report would otherwise file this radio under Kenwood.
///
/// Everything but the rate is the QMX's, which is where the entry comes
/// from — operators run this radio on [qmxModel] and it answers, so the `IF`
/// layout is the one pinned there. No QRP-Labs-style keyer either: nothing
/// published names a dialect for this radio, and it has no voice memories.
///
/// The rate is the one field no report establishes: those operators were on
/// the QMX entry's 9600 unless they changed it. A mismatch here is answered
/// with silence rather than an error, which is why it sits in the prefill
/// the operator can change and not in the overrides they cannot.
const fx4crModel = EquipmentModel(
  key: 'fx4cr',
  manufacturer: 'BG2FX',
  category: kCategoryTransceiver,
  name: _fx4crName,
  variants: [
    EquipmentVariant(
      key: _fx4crSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 115200},
      overrides: {KenwoodDriver.ifModeOffsetKey: 27, KenwoodDriver.cwDialectKey: '', KenwoodDriver.voiceDialectKey: '', KenwoodDriver.voiceMemoriesKey: 0},
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _fx4crName() => t.settings.station.models.fx4cr;

/// QRP Labs QCX, QCX+ and QCX-mini, which speak Kenwood CAT over a
/// USB-serial cable of the operator's own.
///
/// Everything but the rate is the QMX's: a QCX-mini has run on the QMX entry
/// with its `IF` mode offset declared and never contradicted. The rate is the
/// QCX line's 38400, which that operator had to change the QMX entry's 9600
/// to — a mismatch is answered with silence rather than an error.
const qcxModel = EquipmentModel(
  key: 'qcx',
  manufacturer: qrpLabsBrand,
  category: kCategoryTransceiver,
  name: _qcxName,
  variants: [
    EquipmentVariant(
      key: _qcxSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 38400},
      overrides: {KenwoodDriver.ifModeOffsetKey: 27, KenwoodDriver.cwDialectKey: '', KenwoodDriver.voiceDialectKey: '', KenwoodDriver.voiceMemoriesKey: 0},
      notes: _kenwoodSerialNotes,
    ),
  ],
);

String _qcxName() => t.settings.station.models.qcx;

/// Any Elecraft transceiver over its serial port, such as the K3. The KX2,
/// KX3 and K4 have entries of their own.
///
/// Elecraft speaks Kenwood CAT, so this shares [KenwoodDriver] with
/// [kenwoodGenericModel]. It exists as its own entry because an operator
/// looks for the name on the front of their radio, and because the whole
/// line answers at 38400 rather than the Kenwood default of 9600 — a
/// mismatch there is answered with silence, not an error.
const elecraftGenericModel = EquipmentModel(
  key: 'elecraft-generic',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _elecraftGenericName,
  variants: [
    EquipmentVariant(
      key: _elecraftSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      // No keyer until a developer names a dialect — a K4 plays through
      // `PB`/`DA`, a K3 with a KDVR3 through switch taps, and the entry
      // cannot tell them apart.
      defaultConfig: {'baudRate': _elecraftBaudRate, voiceMemoriesConfigKey: 0},
      overrides: {KenwoodDriver.passbandDialectKey: 'elecraft'},
      notes: _elecraftSerialNotes,
    ),
  ],
);

/// Elecraft KX2 and KX3 — the two rigs the Elecraft pairing is proven
/// against, both reported working on Windows and the KX3 on macOS too.
///
/// Each pins the `IF` mode offset [KenwoodDriver] would otherwise spend the
/// first seconds of every connection learning; 27 is what both radios were
/// observed to use. The session still checks it against the radio, so a
/// wrong entry here is caught rather than believed. The generic Elecraft
/// entry pins nothing — the rest of the line has not been seen.
const kx2Model = EquipmentModel(
  key: 'kx2',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _kx2Name,
  variants: [
    EquipmentVariant(
      key: _kx2SerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': _elecraftBaudRate},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        KenwoodDriver.cwDialectKey: 'elecraft',
        KenwoodDriver.voiceDialectKey: 'kx',
        KenwoodDriver.voiceMemoriesKey: kxVoiceMemoryCount,
        KenwoodDriver.passbandDialectKey: 'elecraft',
        // Two fifteen-second messages, per the owner's manual.
        voiceCeilingConfigKey: 15,
      },
      notes: _elecraftSerialNotes,
    ),
  ],
);

/// See [kx2Model] — the same radio family, the same settings.
const kx3Model = EquipmentModel(
  key: 'kx3',
  manufacturer: elecraftBrand,
  category: kCategoryTransceiver,
  name: _kx3Name,
  variants: [
    EquipmentVariant(
      key: _kx3SerialKey,
      driver: Kx3Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': _elecraftBaudRate, kx3IqRateKey: 48000},
      overrides: {
        KenwoodDriver.ifModeOffsetKey: 27,
        KenwoodDriver.cwDialectKey: 'elecraft',
        KenwoodDriver.voiceDialectKey: 'kx',
        KenwoodDriver.voiceMemoriesKey: kxVoiceMemoryCount,
        KenwoodDriver.passbandDialectKey: 'elecraft',
        // Two fifteen-second messages, per the owner's manual.
        voiceCeilingConfigKey: 15,
      },
      notes: _elecraftSerialNotes,
    ),
  ],
);

/// The rate every Elecraft CAT menu ships on, and the one all three field
/// reports connected at. Not [KenwoodDriver.defaultBaudRate], which is the
/// Kenwood line's 9600.
const _elecraftBaudRate = 38400;

String _elecraftGenericName() => t.settings.station.models.elecraftGeneric;

String _kx2Name() => t.settings.station.models.kx2;

String _kx3Name() => t.settings.station.models.kx3;

List<Map<String, dynamic>> _elecraftSerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.elecraftTroubleshootingTitle}**\n\n'
        '${t.settings.station.elecraftTroubleshooting}',
  },
];

/// Lab599 TX-500, over a CAT cable of the operator's own (Lab599's AD-502,
/// or a LiNK500's) at the 9600 the radio ships on.
///
/// Written from Lab599's getting-started guide and a third-party command
/// reference (github.com/rdcm/lab599-cat), not from a capture. The radio
/// offers two CAT protocols in its menu, and the session tells them apart by
/// `ID;` — see [KenwoodModeDialect.lab599]. No keyer, no voice memories and
/// no `DA`: none is in that reference.
const tx500Model = EquipmentModel(
  key: 'tx500',
  manufacturer: lab599Brand,
  category: kCategoryTransceiver,
  name: _tx500Name,
  variants: [
    EquipmentVariant(
      key: _tx500SerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      overrides: _lab599Overrides,
      notes: _lab599Notes,
    ),
  ],
);

/// Lab599 TX-500MP — the same protocol as [tx500Model], answering `ID505;`
/// instead of `ID500;` on LAB599. Over USB through a LiNK500MP or an AD-511
/// cable, or over Bluetooth through a LiNK500MP: Classic Bluetooth on a
/// computer, where it pairs as two serial ports and CAT is one of them, and
/// Bluetooth LE in its iOS mode (the derived `tx500mp-ble`). It can mix its
/// GPS receiver's NMEA into the CAT channel, which the session drops — see
/// `AsciiCatFramer.dropsNmea`. Lab599's other interface, the LiNK500 for any
/// radio, carries CAT over USB only; its Bluetooth reaches the TNC.
const tx500mpModel = EquipmentModel(
  key: 'tx500mp',
  manufacturer: lab599Brand,
  category: kCategoryTransceiver,
  name: _tx500mpName,
  variants: [
    EquipmentVariant(
      key: _tx500mpSerialKey,
      driver: KenwoodDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      overrides: _lab599Overrides,
      notes: _lab599Notes,
    ),
    EquipmentVariant(
      key: _tx500mpBluetoothKey,
      driver: KenwoodDriver(),
      transport: BluetoothSerialTransport(),
      defaultConfig: {'baudRate': KenwoodDriver.defaultBaudRate},
      overrides: _lab599Overrides,
      notes: _lab599Notes,
    ),
  ],
);

const _lab599Overrides = {
  KenwoodDriver.modeDialectKey: 'lab599',
  KenwoodDriver.cwDialectKey: '',
  KenwoodDriver.voiceDialectKey: '',
  KenwoodDriver.voiceMemoriesKey: 0,
};

String _tx500Name() => t.settings.station.models.tx500;

String _tx500mpName() => t.settings.station.models.tx500mp;

List<Map<String, dynamic>> _lab599Notes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.lab599TroubleshootingTitle}**\n\n'
        '${t.settings.station.lab599Troubleshooting}',
  },
];
