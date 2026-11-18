// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Elecraft K3 and K3S commands the Kenwood codec does not carry: the
// option-module query, the M1-M4 switch taps, the RX ANT switch, and the
// transmit meters. From the K3S/K3/KX3/KX2 Programmer's Reference (rev. G5)
// and the K3S Owner's Manual (rev. A1), not from a capture.

/// What `OM;` says is fitted, by the fixed letter positions of its answer
/// (`OM APXSDFfLVR--;`, a dash where a module is absent).
typedef K3Modules = ({bool atu, bool rxAntenna, bool voiceRecorder, bool k3s});

String buildK3ReadModulesCommand() => 'OM;';

/// `OM` → the modules, from the params after the command letters: a space,
/// then the letters. `A` is the KAT3 ATU, which brings the ANT2 jack; `X` the
/// KXV3, which brings RX ANT; `D` the KDVR3; `R` the K3S RF board — the
/// reference's preferred way to tell a K3S. Null for an answer in another
/// shape, such as a KX's (`OM APF---TBXI0n`, whose positions differ).
K3Modules? parseK3ModulesParams(String params) {
  const letters = 'APXSDFfLVR';
  if (!params.startsWith(' ') || params.length < letters.length + 1) return null;
  final flags = params.substring(1, letters.length + 1);
  for (var i = 0; i < letters.length; i++) {
    if (flags[i] != letters[i] && flags[i] != '-') return null;
  }
  return (atu: flags[0] == 'A', rxAntenna: flags[2] == 'X', voiceRecorder: flags[4] == 'D', k3s: flags[9] == 'R');
}

/// Four messages per bank, on the M1-M4 keys.
const k3VoiceMemoryCount = 4;

/// The M1-M4 tap identifiers (programmer's reference table 7).
const _k3MessageSwitches = {1: 21, 2: 31, 3: 35, 4: 39};

/// A tap of message [n]'s key, 1-4.
String buildK3PlayVoiceCommand(int n) => 'SWT${_k3MessageSwitches[n.clamp(1, k3VoiceMemoryCount)]};';

String buildK3ReadRxAntennaCommand() => 'AR;';

String buildK3SetRxAntennaCommand(bool on) => 'AR${on ? 1 : 0};';

/// `AR1` → true. Null for anything but `0` or `1`.
bool? parseK3RxAntennaParams(String params) => switch (params) {
  '0' => false,
  '1' => true,
  _ => null,
};

/// The RX ANT jack as the app names it, after the radio's own label.
const k3RxAntennaPort = 'RX ANT';

String buildK3ReadTransmitMeterModeCommand() => 'TM;';

/// `TM0` → false (the bargraph shows RF power), `TM1` → true (ALC). Null
/// otherwise. Read, never set: it is the panel's METER switch, and the
/// operator's choice.
bool? parseK3TransmitMeterAlcParams(String params) => switch (params) {
  '0' => false,
  '1' => true,
  _ => null,
};

String buildK3ReadBargraphCommand() => 'BG;';

/// `BG07T` → 7 bars, transmitting. Transmitting, the bars are power out
/// (0-12) under `TM0` or ALC (0-7) under `TM1`; receiving, the S-meter.
({int bars, bool transmitting})? parseK3BargraphParams(String params) {
  final match = RegExp(r'^(\d\d)([RT])$').firstMatch(params);
  if (match == null) return null;
  return (bars: int.parse(match[1]!), transmitting: match[2] == 'T');
}

/// The ALC bargraph's full scale.
const k3AlcBars = 7;

/// Watts per power bar: the bargraph reads 0-12 W in 1 W bars, or 0-110 W in
/// 10 W bars once the set power passes 12 W (owner's manual, Transmit
/// Metering).
int k3WattsPerPowerBar(num setWatts) => setWatts > 12 ? 10 : 1;

String buildK3ReadSwrCommand() => 'SW;';

/// `SW015` → 1.5. SWR in tenths, 1.0 to 99.9. Null outside that.
double? parseK3SwrParams(String params) {
  if (!RegExp(r'^\d{3}$').hasMatch(params)) return null;
  final tenths = int.parse(params);
  return tenths < 10 ? null : tenths / 10;
}

/// One transmit meter cycle: `TM;BG;SW;` out and their answers back.
const k3MeterCycleBytes = 3 + 4 + 3 + 6 + 3 + 6;

String buildK3ReadCommandModeCommand() => 'K3;';

/// `K31` turns on the K3 command extensions, `K30` turns them off. A radio
/// setting, not a per-connection one: it is still in effect for whatever
/// program talks to the radio next.
String buildK3SetCommandModeCommand(bool extended) => 'K3${extended ? 1 : 0};';

/// `K31` → true (extended). Null for anything but `0` or `1`.
bool? parseK3CommandModeParams(String params) => switch (params) {
  '0' => false,
  '1' => true,
  _ => null,
};

String buildK3ReadDisplayCommand() => 'DS;';

/// `DS` → whether the ATU is in line, from the second icon byte, which
/// carries it only under `K31`: under `K30` that byte is all clear, and
/// would read as bypassed. The params are eight display bytes and two icon
/// bytes, each icon byte with its top bit set; null for anything else.
bool? parseK3DisplayAtuInlineParams(String params) {
  if (params.length != 10) return null;
  final icons = params.codeUnitAt(9);
  if (icons < 0x80 || icons > 0xFF) return null;
  return icons & 0x10 != 0;
}

String buildK3ReadVoxCommand() => 'VX;';

/// `VX1` → true: VOX on, for the mode the radio is in now — the K3 keeps it
/// per mode. Null for anything but `0` or `1`.
bool? parseK3VoxParams(String params) => switch (params) {
  '0' => false,
  '1' => true,
  _ => null,
};

/// A hold of the ATU key, which switches the ATU between in line (AUTO) and
/// bypassed — a toggle, with no command to set either one.
String buildK3ToggleAtuCommand() => 'SWH19;';
