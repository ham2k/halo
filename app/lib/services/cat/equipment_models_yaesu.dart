// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Yaesu radios in the catalogue: the ASCII CAT line on [Ft891Driver],
// and the FT-817/857/897 on the five-byte binary protocol.

import 'package:halo_i18n/halo_i18n.dart';

import 'driver.dart';
import 'drivers/ft891_driver.dart';
import 'drivers/meter_calibration.dart';
import 'drivers/yaesu_cat_codec.dart' show yaesuVoiceMemoryCount;
import 'drivers/yaesu_binary_driver.dart';
import 'equipment.dart';
import 'equipment_brands.dart';
import 'equipment_registry.dart';
import 'transports/serial_transport.dart';

const _ft891SerialKey = 'ft891-serial';
const _ft991aSerialKey = 'ft991a-serial';
const _ft710SerialKey = 'ft710-serial';
const _ftdx10SerialKey = 'ftdx10-serial';
const _ftx1SerialKey = 'ftx1-serial';
const _ft450SerialKey = 'ft450-serial';
const _ftdx3000SerialKey = 'ftdx3000-serial';
const _ft950SerialKey = 'ft950-serial';
const _ftdx1200SerialKey = 'ftdx1200-serial';
const _ft2000SerialKey = 'ft2000-serial';
const _ftdx5000SerialKey = 'ftdx5000-serial';
const _yaesuSerialKey = 'yaesu-serial';
const _ft817SerialKey = 'ft817-serial';
const _ft857SerialKey = 'ft857-serial';
const _ft897SerialKey = 'ft897-serial';

/// The radio's own CP2105, whose CAT port takes RTS as the CAT handshake
/// rather than PTT: picking a port this suggests turns Hold RTS high on in
/// the editor, so a radio with its CAT RTS menu on keeps answering — with RTS
/// low it sends nothing but the one burst opening the port lets out. Any
/// other port turns it off, since that is a Digirig, a SignaLink or a
/// home-made cable, where RTS is PTT. Where the platform cannot tell the
/// bridge's two ports apart (Linux, the web), the second (PTT and keying)
/// ticks it too, and keys the radio if its PC KEYING menu is set to RTS.
///
/// The pick decides, not a prefill: a new node's port is unknown until then.
const _ownUsbCatPort = {...Ft891Driver.cp2105CatPort, serialRtsHighConfigKey: true};

/// Yaesu FT-891 over its built-in USB-to-serial CAT bridge.
///
/// Baud is the operator's to set, deliberately. app-polo hardcoded 4800 with
/// no UI, which its own notes call out as a silent-failure mode: a radio
/// whose CAT menu says 38400 answers with garbage and no error at all.
const ft891Model = EquipmentModel(
  key: 'ft891',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft891Name,
  // `LM0n;` arms the DVS, but the audio comes off the microphone with the
  // operator on PTT — half the procedure is on the front panel, and nothing
  // in CAT can say so.
  recordingHelp: _ft891RecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ft891SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      // What the entry knows about the radio's keyers — the generic entry
      // asks a developer instead (keyer_config.dart). Twenty seconds a
      // memory, per the Advance Manual.
      // The meter scales, which Yaesu publishes nowhere — see
      // drivers/info/README.md. Named per ENTRY rather than per driver
      // because one driver serves the whole line and the scales do not.
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: yaesuVoiceMemoryCount, voiceCeilingConfigKey: 20, meterInfoConfigKey: 'yaesu/ft-891'},
      restrictions: {'port': _ownUsbCatPort},
      // The failure this driver actually produces is silence: the commands
      // go out, nothing comes back, and nothing anywhere reports an error.
      // Every cause is a setting the operator has to change on the radio or
      // elsewhere on the machine, so the editor is where it is worth saying
      // — by the time the row says "Connected" with no frequency, this form
      // is exactly where they will come looking.
      notes: _ft891SerialNotes,
    ),
  ],
);

String _ft891RecordingHelp() => t.settings.radio.voiceMessages.recordHelpFt891;
String _ft891Name() => t.settings.station.models.ft891;

List<Map<String, dynamic>> _ft891SerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.troubleshootingTitle}**\n\n'
        '${t.settings.station.ft891Troubleshooting}',
  },
];

/// Yaesu FT-991 and FT-991A over their built-in USB CAT port, one entry
/// because CAT does not tell them apart. The FT-991A is reported working on
/// the FT-891's entry, whose settings this keeps: the factory 4800 baud, the
/// twenty-second voice memories and their recording procedure, and CAT on
/// the first port of the same CP2105 bridge.
///
/// Two things are its own. The meter table, which carries the Vdd meter the
/// FT-891 lacks. And the troubleshooting notes, which are the line's rather
/// than the FT-891's, whose menu numbers are not this radio's.
const ft991aModel = EquipmentModel(
  key: 'ft991a',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft991aName,
  recordingHelp: _ft891RecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ft991aSerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: yaesuVoiceMemoryCount, voiceCeilingConfigKey: 20, meterInfoConfigKey: 'yaesu/ft-991a'},
      restrictions: {'port': _ownUsbCatPort},
      notes: _yaesuUsbSerialNotes,
    ),
  ],
);

String _ft991aName() => t.settings.station.models.ft991a;

/// Yaesu FT-710 over its built-in USB CAT port.
///
/// [Ft891Driver] is the Yaesu CAT driver rather than an FT-891-only one (see
/// [yaesuGenericModel]), and this radio is what proves it: the 710 has been
/// run here under the FT-891's own entry. It gets a name of its own so it is
/// found by what is written on the front of the radio, and so the speed it
/// actually ships on is the one prefilled.
const ft710Model = EquipmentModel(
  key: 'ft710',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft710Name,
  recordingHelp: _yaesuDvsRecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ft710SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      // The radio's own CAT RATE default, unlike the FT-891's 4800.
      defaultConfig: {'baudRate': 38400},
      // `KY0n;`, not the line's `KY6;`-`KYA;`, per its own CAT manual.
      overrides: {
        cwKeyerConfigKey: true,
        yaesuKeyerPlayByChannelConfigKey: true,
        voiceMemoriesConfigKey: yaesuVoiceMemoryCount,
        meterInfoConfigKey: 'yaesu/ft-710',
      },
      // Only a suggestion — an FT-710 has also answered on the Standard
      // port, so the picker leaves it one tap away.
      restrictions: {'port': _ownUsbCatPort},
      notes: _yaesuUsbSerialNotes,
    ),
  ],
);

String _ft710Name() => t.settings.station.models.ft710;

/// Yaesu FTDX10 over its built-in USB CAT port. Same driver and the same
/// reasoning as [ft710Model].
const ftdx10Model = EquipmentModel(
  key: 'ftdx10',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ftdx10Name,
  recordingHelp: _yaesuDvsRecordingHelp,
  variants: [
    EquipmentVariant(
      key: _ftdx10SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 38400},
      // Ninety seconds a memory, on the SD card, per the Operation Manual.
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: yaesuVoiceMemoryCount, voiceCeilingConfigKey: 90, meterInfoConfigKey: 'yaesu/ftdx10'},
      restrictions: {'port': _ownUsbCatPort},
      notes: _yaesuUsbSerialNotes,
    ),
  ],
);

String _ftdx10Name() => t.settings.station.models.ftdx10;

/// Yaesu FTX-1 over its built-in USB CAT port — reported working on the
/// FTDX10's entry, whose settings it keeps.
///
/// Its modes are assumed to follow the FT-891's table, as they did on the
/// FTDX10's entry. Its `PC` is its own — it names the field head or the
/// SPA-1 before the level — so the entry pins that form. It keys CW and
/// plays voice memories through the line's `KM`/`KY` and `PB`, which
/// hamlib's FTX-1 command list carries; neither has been tried on the radio.
const ftx1Model = EquipmentModel(
  key: 'ftx1',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ftx1Name,
  variants: [
    EquipmentVariant(
      key: _ftx1SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': 38400},
      overrides: {cwKeyerConfigKey: true, voiceMemoriesConfigKey: yaesuVoiceMemoryCount, meterInfoConfigKey: 'yaesu/ftx-1', yaesuHeadPowerConfigKey: true},
      restrictions: {'port': _ownUsbCatPort},
      notes: _yaesuUsbSerialNotes,
    ),
  ],
);

String _ftx1Name() => t.settings.station.models.ftx1;

/// The FT-991's, FT-710's, FTDX10's and FTX-1's: a CP2105 bridge built into the radio, with CAT
/// normally on its first port. Not the generic Yaesu note, whose mode-table
/// caveat these proven radios do not need, nor the FT-891's, which quotes
/// that radio's menu numbers.
List<Map<String, dynamic>> _yaesuUsbSerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.troubleshootingTitle}**\n\n'
        '${t.settings.station.yaesuUsbTroubleshooting}',
  },
];

/// Yaesu FT-450 and FT-450D over the RS-232 CAT jack on the back — the
/// line's ASCII CAT, with two differences the entry pins, both from the
/// FT-450D CAT Operation Reference Book and neither tried on a radio:
///
/// - Eight digits of Hz in `FA` and `IF`, not nine. Without the pin every
///   answer is dropped as malformed and every tune is rejected, silently.
/// - Three text memories of forty characters, not five of fifty, so the
///   keyer writes and plays through memory 3 (`KM3`, `KY8`).
///
/// No voice memories are offered: its two play on a one-digit `PB1;` where
/// the driver sends the line's `PB01;`. No meters either — there is no calibration
/// table for it.
///
/// No port restriction: the radio has no USB bridge of its own, so the
/// adapter is whatever the operator bought, and a CP2105 suggestion would
/// point at nothing.
const ft450Model = EquipmentModel(
  key: 'ft450',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft450Name,
  variants: [
    EquipmentVariant(
      key: _ft450SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {
        yaesuFrequencyDigitsConfigKey: 8,
        cwKeyerConfigKey: true,
        yaesuKeyerMemoryConfigKey: 3,
        yaesuKeyerMemoryCharsConfigKey: 40,
        voiceMemoriesConfigKey: 0,
        meterInfoConfigKey: '',
      },
      notes: _yaesuRs232SerialNotes,
    ),
  ],
);

String _ft450Name() => t.settings.station.models.ft450;

/// Yaesu FTDX3000 over its built-in USB CAT port — the line's ASCII CAT with
/// the FT-450's eight digits of Hz in `FA` and `IF`, per its CAT Operation
/// Manual. Without the pin it reads as a radio that never answers: every
/// frequency is dropped as malformed and every tune rejected.
///
/// It shows no passband: its CAT manual has no `ID` (hamlib's `newcat`
/// expects `0462`), and no width profile is known for it. Its five text
/// memories and five voice memories are the line's (`KM`/`KY6`-`KYA`,
/// `PB0n`), the voice ones built in. Neither has been tried on the radio,
/// and no recording procedure has been written for it. Its meter table has
/// no power and no SWR — see the file's notes.
const ftdx3000Model = EquipmentModel(
  key: 'ftdx3000',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ftdx3000Name,
  variants: [
    EquipmentVariant(
      key: _ftdx3000SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {
        yaesuFrequencyDigitsConfigKey: 8,
        cwKeyerConfigKey: true,
        voiceMemoriesConfigKey: yaesuVoiceMemoryCount,
        meterInfoConfigKey: 'yaesu/ftdx3000',
      },
      // Its own USB to dual UART bridge, with menu 037 CAT SELECT on USB.
      restrictions: {'port': _ownUsbCatPort},
      notes: _ftdx3000SerialNotes,
    ),
  ],
);

String _ftdx3000Name() => t.settings.station.models.ftdx3000;

/// The proven radios' USB note, plus what this unproven one adds: its CAT
/// SELECT menu, and that nobody has run it.
List<Map<String, dynamic>> _ftdx3000SerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.troubleshootingTitle}**\n\n'
        '${t.settings.station.yaesuUsbTroubleshooting}\n\n'
        '${t.settings.station.ftdx3000Troubleshooting}',
  },
];

/// Yaesu FT-950 over the RS-232 CAT jack on the back. The same eight-digit
/// line as [ftdx3000Model], per the FT-950 CAT Operation Reference Book.
///
/// No voice memories: `PB` and `LM` reach only the optional DVS-6 unit, and
/// on a radio without one every memory would be offered and none would play.
/// No port restriction, for the same reason as [ft450Model].
const ft950Model = EquipmentModel(
  key: 'ft950',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft950Name,
  variants: [
    EquipmentVariant(
      key: _ft950SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {..._eightDigitDvs6Overrides, meterInfoConfigKey: 'yaesu/ft-950'},
      notes: _yaesuRs232SerialNotes,
    ),
  ],
);

String _ft950Name() => t.settings.station.models.ft950;

/// Yaesu FTDX1200 over the RS-232 CAT jack, or USB through the external
/// SCU-17 — not a bridge of its own, so no port restriction. Same eight-digit
/// line and the same optional DVS-6 as [ft950Model], per its CAT Operation
/// Reference Book.
const ftdx1200Model = EquipmentModel(
  key: 'ftdx1200',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ftdx1200Name,
  variants: [
    EquipmentVariant(
      key: _ftdx1200SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {..._eightDigitDvs6Overrides, meterInfoConfigKey: 'yaesu/ftdx1200'},
      notes: _yaesuRs232SerialNotes,
    ),
  ],
);

String _ftdx1200Name() => t.settings.station.models.ftdx1200;

/// Yaesu FT-2000 and FT-2000D over the RS-232 CAT jack — one entry, as their
/// one CAT Operation Reference Book is. The same eight-digit line as
/// [ftdx3000Model], with a `PC` of its own: a 0-255 level of the rated
/// output, which the radio's `ID` names (100 W, or the D's 200 W — see
/// [yaesuRatedWattsById]). Its five voice memories are the line's, and its
/// manual names no option for them.
const ft2000Model = EquipmentModel(
  key: 'ft2000',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft2000Name,
  variants: [
    EquipmentVariant(
      key: _ft2000SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {..._eightDigitRelativePowerOverrides, meterInfoConfigKey: 'yaesu/ft-2000'},
      notes: _yaesuRs232SerialNotes,
    ),
  ],
);

String _ft2000Name() => t.settings.station.models.ft2000;

/// Yaesu FTDX5000 over the RS-232 CAT jack. The same line, `PC` and voice
/// memories as [ft2000Model], at 200 W.
const ftdx5000Model = EquipmentModel(
  key: 'ftdx5000',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ftdx5000Name,
  variants: [
    EquipmentVariant(
      key: _ftdx5000SerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate},
      overrides: {..._eightDigitRelativePowerOverrides, meterInfoConfigKey: 'yaesu/ftdx5000'},
      notes: _yaesuRs232SerialNotes,
    ),
  ],
);

String _ftdx5000Name() => t.settings.station.models.ftdx5000;

/// The FT-2000's and FTDX5000's — see [ft2000Model].
const _eightDigitRelativePowerOverrides = {
  yaesuFrequencyDigitsConfigKey: 8,
  yaesuRelativePowerConfigKey: true,
  cwKeyerConfigKey: true,
  voiceMemoriesConfigKey: yaesuVoiceMemoryCount,
};

/// The FT-950's and FTDX1200's — see [ft950Model].
const _eightDigitDvs6Overrides = {yaesuFrequencyDigitsConfigKey: 8, cwKeyerConfigKey: true, voiceMemoriesConfigKey: 0};

/// The FT-450's, FT-950's, FTDX1200's, FT-2000's and FTDX5000's: an RS-232 jack, reached through
/// whatever adapter the operator bought.
List<Map<String, dynamic>> _yaesuRs232SerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.troubleshootingTitle}**\n\n'
        '${t.settings.station.yaesuRs232Troubleshooting}',
  },
];

/// Yaesu FT-817, FT-817ND and FT-818 over their CAT jack.
///
/// A different protocol from every other Yaesu in this catalogue
/// ([YaesuBinaryDriver]): five binary bytes per command, no framing, and no
/// auto-information, so a dial turn is only ever seen by polling. Written
/// from Yaesu's own CAT chart and run against no radio, which is what
/// [YaesuBinaryDriver.hardwareVerified] says.
///
/// One entry for all three because CAT does not distinguish them — the ND
/// and the 818 answer the same chart the original does.
const ft817Model = EquipmentModel(
  key: 'ft817',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft817Name,
  variants: [
    EquipmentVariant(
      key: _ft817SerialKey,
      driver: YaesuBinaryDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': yaesuBinaryDefaultBaudRate},
      // The failure this driver produces is silence, and every cause is a
      // setting or a cable outside the app — so the editor, which is where
      // an operator with a connected row and no frequency will come
      // looking, is where it is worth saying.
      notes: _yaesuBinarySerialNotes,
    ),
  ],
);

String _ft817Name() => t.settings.station.models.ft817;

/// Yaesu FT-857 and FT-857D, on the same protocol and driver as
/// [ft817Model].
///
/// Its own entry rather than a line in the 817's notes because of
/// [yaesuBinaryNarrowFmConfigKey]: this radio takes a narrow-FM set code the
/// FT-817 has no parameter for, and a radio told to use one it does not have
/// changes mode to something nobody asked for.
const ft857Model = EquipmentModel(
  key: 'ft857',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft857Name,
  variants: [
    EquipmentVariant(
      key: _ft857SerialKey,
      driver: YaesuBinaryDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': yaesuBinaryDefaultBaudRate},
      overrides: {yaesuBinaryNarrowFmConfigKey: true},
      notes: _yaesuBinarySerialNotes,
    ),
  ],
);

String _ft857Name() => t.settings.station.models.ft857;

/// Yaesu FT-897 and FT-897D. Same protocol, driver and narrow-FM code as
/// [ft857Model].
const ft897Model = EquipmentModel(
  key: 'ft897',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _ft897Name,
  variants: [
    EquipmentVariant(
      key: _ft897SerialKey,
      driver: YaesuBinaryDriver(),
      transport: SerialTransport(),
      defaultConfig: {'baudRate': yaesuBinaryDefaultBaudRate},
      overrides: {yaesuBinaryNarrowFmConfigKey: true},
      notes: _yaesuBinarySerialNotes,
    ),
  ],
);

String _ft897Name() => t.settings.station.models.ft897;

List<Map<String, dynamic>> _yaesuBinarySerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.yaesuBinaryTroubleshootingTitle}**\n\n'
        '${t.settings.station.yaesuBinaryTroubleshooting}',
  },
];

/// Shared by the FTDX10 and the FT-710: the same DVS procedure, and one
/// string rather than two copies that can drift apart in translation. The
/// FT-891's is its own — that radio wants its REC indicator counted through
/// four blinks first, where these two only wait for it to appear.
String _yaesuDvsRecordingHelp() => t.settings.radio.voiceMessages.recordHelpYaesuDvs;

/// Any Yaesu speaking CAT over a serial port — the entry for a radio with no
/// definition of its own.
///
/// Shares [Ft891Driver], and that is the honest arrangement rather than a
/// shortcut: Yaesu CAT is one ASCII protocol across the line, the codec was
/// always generic (`yaesu_cat_codec.dart`), and the class is named after the
/// single radio it has been proven against, not after what it can talk to.
///
/// The one place the line genuinely diverges is the MODE table, which is the
/// FT-891's — so a radio numbering its modes differently reports and sets the
/// wrong one for those, while the frequency stays right. The notes say so,
/// and that caveat outlives the pairing being proven: what a proven radio
/// proves is the protocol, never another radio's mode table.
const yaesuGenericModel = EquipmentModel(
  key: 'yaesu-generic',
  manufacturer: yaesuBrand,
  category: kCategoryTransceiver,
  name: _yaesuGenericName,
  variants: [
    EquipmentVariant(
      key: _yaesuSerialKey,
      driver: Ft891Driver(),
      transport: SerialTransport(),
      // The FT-891's factory rate. Every Yaesu CAT menu offers it, and it is
      // the one a radio nobody has configured is most likely already on.
      // Off until a developer says otherwise: the catalogue does not know
      // which Yaesu this is, and a rig with no keyer must not be offered
      // as one (keyer_config.dart).
      defaultConfig: {'baudRate': Ft891Driver.defaultBaudRate, cwKeyerConfigKey: false, voiceMemoriesConfigKey: 0},
      notes: _yaesuSerialNotes,
    ),
  ],
);

String _yaesuGenericName() => t.settings.station.models.yaesuGeneric;

List<Map<String, dynamic>> _yaesuSerialNotes() => [
  {
    'type': 'markdown',
    'collapsible': true,
    'title': t.settings.station.troubleshootingNotes,
    'text':
        '**${t.settings.station.yaesuTroubleshootingTitle}**\n\n'
        '${t.settings.station.yaesuTroubleshooting}',
  },
];
