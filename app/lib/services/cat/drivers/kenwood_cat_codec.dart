// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Kenwood CAT: the same `;`-terminated ASCII envelope as Yaesu
// (cat_ascii_codec.dart), and a different payload inside it. Also spoken, to
// varying degrees, by Elecraft, several SDR front-ends and anything that
// advertises "Kenwood-compatible CAT".
//
// The two places it differs from Yaesu, both of which have bitten ports of
// this protocol before:
//
//   - frequency is ELEVEN digits, not nine. A nine-digit command is silently
//     ignored by the radio rather than rejected.
//   - `MD` carries no VFO selector. Yaesu's is `MD0<code>;`; Kenwood's is
//     `MD<code>;`, and sending Yaesu's form sets nothing.
//
// Pure: it builds and parses strings and knows nothing about sockets, serial
// ports or timers.

import 'cat_ascii_codec.dart';

/// `MD` code, per the CAT references for the TS-480/570/590/890/990 line.
/// Stable across the family — it is the `IF` packet's LAYOUT that moved
/// between generations, not this table, which is why the layout is learned at
/// runtime (see [kenwoodModeOffsetIn]) and this is not.
///
/// `8` is deliberately absent: it is unassigned on most of the line, and
/// guessing it would be inventing a mode.
const kenwoodModeCodes = <String, String>{'LSB': '1', 'USB': '2', 'CW': '3', 'FM': '4', 'AM': '5', 'RTTY': '6', 'CW-R': '7', 'RTTY-R': '9'};

final Map<String, String> _modeNamesByCode = {for (final entry in kenwoodModeCodes.entries) entry.value: entry.key};

String? kenwoodModeForCode(String code) => _modeNamesByCode[code];

String? kenwoodCodeForMode(String? name) => name == null ? null : kenwoodModeCodes[name.toUpperCase()];

/// How many digits a Kenwood frequency carries, everywhere on the wire: in
/// `FA`, in `FB`, and as the leading field of `IF`.
const kenwoodFrequencyDigits = 11;

/// The radio wants Hz zero-padded to [kenwoodFrequencyDigits].
String encodeKenwoodFrequencyHz(int freqHz) {
  final digits = freqHz.abs().toString().padLeft(kenwoodFrequencyDigits, '0');
  // Keep the LAST eleven: a value too large to express is truncated the way
  // the radio would read it, rather than producing an over-long command it
  // silently ignores.
  return digits.substring(digits.length - kenwoodFrequencyDigits);
}

String buildKenwoodSetFrequencyCommand(int freqHz) => 'FA${encodeKenwoodFrequencyHz(freqHz)};';

String buildKenwoodReadFrequencyCommand() => 'FA;';

/// Null for a mode the radio has no code for — the caller sends nothing
/// rather than a malformed command.
String? buildKenwoodSetModeCommand(String? mode) {
  final code = kenwoodCodeForMode(mode);
  // No VFO selector, unlike Yaesu's MD0<code>.
  return code == null ? null : 'MD$code;';
}

String buildKenwoodReadModeCommand() => 'MD;';

String buildKenwoodSetDataModeCommand({required bool on}) => on ? 'DA1;' : 'DA0;';

String buildKenwoodReadDataModeCommand() => 'DA;';

/// `DA0` / `DA1` → off / on. Null for anything else.
bool? parseKenwoodDataModeParams(String params) => switch (params) {
  '0' => false,
  '1' => true,
  _ => null,
};

String buildKenwoodReadInfoCommand() => 'IF;';

/// `PC` is a 3-digit level, 000-100 — on the TS-480/590/2000-family CAT
/// references this driver otherwise follows, that level IS watts (the
/// command sets RF output power directly, not a percentage of some other
/// maximum). Clamped rather than truncated: a value this driver has never
/// seen a real radio reject beats a malformed command it silently ignores.
String buildKenwoodSetPowerCommand(num watts) => 'PC${watts.round().clamp(0, 100).toString().padLeft(3, '0')};';

String buildKenwoodReadPowerCommand() => 'PC;';

/// `PC100;` → 100. Null unless it's exactly three digits, the same
/// discipline [parseKenwoodFrequencyParams] applies to `FA`.
int? parseKenwoodPowerParams(String params) => RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;

/// `AC;` reads the antenna tuner on the TS-480/590/890/990 line. The answer
/// is `ACP1P2P3;`: P1 the receive-side AT (`0` through, `1` in), P2 the
/// transmit-side AT (`0` through, `1` in), P3 `1` while a tune is running.
/// From the CAT references, not a capture; the rest of the radios on this
/// protocol are expected to refuse it (see [kenwoodRefusal]).
String buildKenwoodReadTunerCommand() => 'AC;';

/// Sets the transmit-side AT and nothing else: [rxInline] is the P1 the
/// radio last reported, handed back unchanged because the receive-side AT
/// is the operator's choice. P3 is always `0` — `1` STARTS A TUNE, a carrier
/// on the air, and this app reads a tune but never starts one, which is why
/// there is no parameter for it.
String buildKenwoodSetTunerCommand({required bool rxInline, required bool inline}) => 'AC${rxInline ? 1 : 0}${inline ? 1 : 0}0;';

/// `AC010;` → its three flags. Null unless it is exactly three `0`/`1`
/// characters — anything else is not the Kenwood tuner answer.
({bool rxInline, bool txInline, bool tuning})? parseKenwoodTunerParams(String params) {
  if (!RegExp(r'^[01]{3}$').hasMatch(params)) return null;
  return (rxInline: params[0] == '1', txInline: params[1] == '1', tuning: params[2] == '1');
}

/// Which shape of `AN` selects a radio's own antenna ports — pinned per
/// catalogue entry like [KenwoodPassbandDialect], because a one-port radio on
/// this driver may still answer `AN1;` (the KX3 accepts every K3 command), and
/// two ports read off a radio with one would offer a choice it does not have.
enum KenwoodAntennaDialect {
  /// `ANn;`, n `1` for ANT1 and `2` for ANT2, one port for receive and
  /// transmit both — the TS-480, per Kenwood's PC Control Command Reference
  /// for the TS-480HX/SAT (2003). The K3S/K3/KX3 Programmer's Reference
  /// (rev. F6) gives the K3's `AN` the same shape, but its RX ANT state is
  /// not in that answer, so on a K3 receiving there this reports the wrong
  /// receive port.
  twoPort,

  /// The TS-590S and TS-590SG, per Kenwood's PC Control Command Reference
  /// Guide for them (rev. 2019): `ANabc;` with a ANT1/ANT2, b the RX ANT
  /// jack in use for receive (`1`) or not (`0`), c the DRV jack's output,
  /// and `9` in a set for "no change".
  ts590,
}

/// The radio's own names for its ports, as its references print them.
const kenwoodAntennaPorts = ['ANT1', 'ANT2'];
const ts590RxAntennaPort = 'RX ANT';

String buildKenwoodReadAntennaCommand() => 'AN;';

/// `ANn;` — [port] 1 or 2.
String buildKenwoodSetAntennaCommand(int port) => 'AN$port;';

/// `AN1;` → 1. Null for anything but a single `1` or `2`.
int? parseKenwoodAntennaParams(String params) => RegExp(r'^[12]$').hasMatch(params) ? int.parse(params) : null;

/// The TS-590's three-field set, `9` wherever nothing changes. The DRV field
/// is always `9`: on the TS-590SG its menu can make that jack an antenna
/// output, which is the operator's to switch, not this app's.
String buildTs590SetAntennaCommand({int? port, bool? rxAntenna}) => 'AN${port ?? 9}${rxAntenna == null ? 9 : (rxAntenna ? 1 : 0)}9;';

/// `AN110;` → ANT1 with the RX ANT jack receiving. Null unless it is exactly
/// the answer's three fields — an answer never carries `9`.
({int port, bool rxAntenna})? parseTs590AntennaParams(String params) {
  if (!RegExp(r'^[12][01][01]$').hasMatch(params)) return null;
  return (port: int.parse(params[0]), rxAntenna: params[1] == '1');
}

/// Which receive-filter commands a radio on this driver answers, and what
/// their numbers mean — pinned per catalogue entry like [KenwoodCwDialect].
/// No answer's shape tells the families apart: `IS nnnn` is Hz on both, while
/// `FW` is Hz on a Kenwood and 10 Hz units on an Elecraft, and Kenwood's
/// `SL`/`SH` index tables differ from model to model.
enum KenwoodPassbandDialect {
  /// The TS-590SG, per Kenwood's PC Control Command Reference Guide for the
  /// TS-590S/SG (rev. 2019): `SL`/`SH` table indexes in SSB — low/high cut,
  /// or width/shift as its menus 028 (SSB) and 029 (SSB-DATA) choose — and in
  /// CW `FW` (width, Hz), `IS` (filter centre, Hz) and menu 040 (pitch). Its
  /// shift table and menu numbers are not the TS-590S's.
  ts590sg,

  /// Elecraft K3, K3S, KX2, KX3 and K4, per the K3S/K3/KX3 Programmer's
  /// Reference (rev. F6) and the K4's (rev. D12): `BW` the width in 10 Hz
  /// units, `IS` the AF centre of the passband ("IF shift" in name only),
  /// `CW` the sidetone pitch in 10 Hz units.
  elecraft,
}

/// `SL` low-cut and `SH` high-cut, by index, in SSB with the TS-590SG's menu
/// set to HI/LO.
const ts590sgLowCutsHz = [0, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
const ts590sgHighCutsHz = [1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800, 3000, 3400, 4000, 5000];

/// `SL` width and `SH` shift — the passband's centre — by index, in SSB with
/// the TS-590SG's menu set to WIDTH/SHIFT. The widths are also what `FW`
/// takes in CW, in Hz; any other value lands on the next LOWER one, so a set
/// sends one of these rather than leaving the rounding to the radio.
const ts590sgWidthsHz = [50, 80, 100, 150, 200, 250, 300, 400, 500, 600, 1000, 1500, 2000, 2500];
const ts590sgShiftsHz = [1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1750, 1800, 1900, 2000, 2100, 2210];

/// The TS-590SG menus the passband depends on: whether `SL`/`SH` mean
/// low/high cut (`0`) or width/shift (`1`) in SSB and in SSB-DATA, and the CW
/// pitch (300 Hz + 50 Hz per step).
const ts590sgSsbFilterMenu = 28;
const ts590sgSsbDataFilterMenu = 29;
const ts590sgCwPitchMenu = 40;

/// The index in [table] nearest [hz]; the lower on a tie.
int nearestIndex(List<int> table, int hz) {
  var best = 0;
  for (var i = 1; i < table.length; i++) {
    if ((table[i] - hz).abs() < (table[best] - hz).abs()) best = i;
  }
  return best;
}

String buildKenwoodReadLowCutCommand() => 'SL;';
String buildKenwoodReadHighCutCommand() => 'SH;';
String buildKenwoodSetLowCutCommand(int index) => 'SL${index.toString().padLeft(2, '0')};';
String buildKenwoodSetHighCutCommand(int index) => 'SH${index.toString().padLeft(2, '0')};';

/// `SL05` / `SH09` → the table index. Null unless exactly two digits.
int? parseKenwoodCutIndexParams(String params) => RegExp(r'^\d{2}$').hasMatch(params) ? int.parse(params) : null;

String buildKenwoodReadFilterWidthCommand() => 'FW;';
String buildKenwoodSetFilterWidthCommand(int hz) => 'FW${hz.clamp(0, 9999).toString().padLeft(4, '0')};';

/// `FW0500` → 500 Hz on a Kenwood. Null unless exactly four digits.
int? parseKenwoodFilterWidthParams(String params) => RegExp(r'^\d{4}$').hasMatch(params) ? int.parse(params) : null;

/// `EX0280000;` — read menu [menu] (P2 `00`, P3 `0`, P4 `0`, as the guide fixes them).
String buildKenwoodReadMenuCommand(int menu) => 'EX${menu.toString().padLeft(3, '0')}0000;';

/// `EX0400000` + P5 → the menu and its setting, P5 read as a number (the
/// guide gives it no fixed width). Null for any other shape.
({int menu, int value})? parseKenwoodMenuParams(String params) {
  final match = RegExp(r'^(\d{3})0000(\d+)$').firstMatch(params);
  if (match == null) return null;
  return (menu: int.parse(match[1]!), value: int.parse(match[2]!));
}

String buildKenwoodReadShiftCommand() => 'IS;';

/// `IS 0600` → 600 Hz: a space then four digits, on the TS-590 and the K3
/// line alike. The K4 also documents `IS0060` → 600, in 10 Hz units with no
/// space, as its own format — accepted only when [k4]. Anything else, a
/// signed shift included, is some other radio's `IS`.
int? parseKenwoodShiftParams(String params, {bool k4 = false}) {
  if (RegExp(r'^ \d{4}$').hasMatch(params)) return int.parse(params.substring(1));
  if (k4 && RegExp(r'^\d{4}$').hasMatch(params)) return int.parse(params) * 10;
  return null;
}

/// `IS nnnn;` — the Elecraft passband's AF centre, in Hz. Null from 9000 up,
/// where the K3 line reads `IS 9xxx` as "re-centre for the mode" rather than
/// as a frequency, and for a centre below zero.
String? buildElecraftSetCentreCommand(int hz) => hz < 0 || hz >= 9000 ? null : 'IS ${hz.toString().padLeft(4, '0')};';

String buildElecraftReadBandwidthCommand() => 'BW;';

/// `BWxxxx;` in 10 Hz units; the radio quantizes and limits it per mode.
String buildElecraftSetBandwidthCommand(int hz) => 'BW${(hz / 10).round().clamp(0, 9999).toString().padLeft(4, '0')};';

/// `BW0270` → 2700 Hz. Null unless exactly four digits.
int? parseElecraftBandwidthParams(String params) => RegExp(r'^\d{4}$').hasMatch(params) ? int.parse(params) * 10 : null;

String buildElecraftReadPitchCommand() => 'CW;';

/// `CW60` → 600 Hz. Null unless exactly two digits.
int? parseElecraftPitchParams(String params) => RegExp(r'^\d{2}$').hasMatch(params) ? int.parse(params) * 10 : null;

/// What the line answers a command it does not have, or will not take now:
/// `?;`, naming neither the command nor the reason. It never frames as an
/// [AsciiCatCommand] — there are no letters in it — and no answer this
/// driver asks for carries a `?` of its own, so a `?` arriving at all is a
/// refusal of SOMETHING.
const kenwoodRefusal = '?';

/// `FA00014250000;` → 14250000 Hz. Null unless it is exactly eleven digits —
/// a truncated or over-long response is not a frequency.
int? parseKenwoodFrequencyParams(String params) {
  if (!RegExp('^\\d{$kenwoodFrequencyDigits}\$').hasMatch(params)) return null;
  return int.tryParse(params);
}

/// `MD2;` → `USB`. Kenwood sends the code alone; a radio that answered with a
/// leading selector would be speaking Yaesu, so only the single-character
/// form is accepted rather than "the last character", which would quietly
/// mis-read anything unexpected.
String? parseKenwoodModeParams(String params) => params.length == 1 ? kenwoodModeForCode(params) : null;

/// The frequency at the head of an `IF` packet.
///
/// This offset is the one part of `IF` that has NOT moved across Kenwood
/// generations: the packet opens with the eleven-digit frequency on every
/// one of them. Everything after it shifts, which is why nothing else here
/// reads `IF` by a fixed offset.
int? parseKenwoodInfoFrequency(String params) {
  if (params.length < kenwoodFrequencyDigits) return null;
  return parseKenwoodFrequencyParams(params.substring(0, kenwoodFrequencyDigits));
}

/// Where in an `IF` packet the mode digit sits — learned from the radio
/// rather than assumed, because the field widths ahead of it differ between
/// the TS-2000-era layout and the TS-480/590/890 one, and a wrong offset
/// reports a plausible WRONG mode instead of failing.
///
/// [params] is the packet, [modeCode] the code a `MD;` answer just gave for
/// the same moment. Returns the single position holding that code, or null
/// when it appears in several places (ambiguous — try again on a different
/// mode) or in none (not this packet's layout, or the radio moved between
/// the two reads).
///
/// Deliberately refuses to guess: null keeps the caller polling `MD`, which
/// is correct but slower. A wrong answer here would be silent and permanent.
int? kenwoodModeOffsetIn(String params, String modeCode) {
  if (modeCode.length != 1) return null;
  int? found;
  // The frequency occupies the head of the packet and cannot be the mode, so
  // start past it — otherwise a mode code of '1' matches the first digit of
  // almost any frequency.
  for (var i = kenwoodFrequencyDigits; i < params.length; i++) {
    if (params[i] != modeCode) continue;
    if (found != null) return null;
    found = i;
  }
  return found;
}

/// The mode at a [offset] previously learned by [kenwoodModeOffsetIn].
String? parseKenwoodInfoModeAt(String params, int offset) {
  if (offset < 0 || offset >= params.length) return null;
  return kenwoodModeForCode(params[offset]);
}

/// Whether the radio is transmitting, read out of an `IF` packet whose mode
/// position is already known.
///
/// The Kenwood line has NO readable transmit-status command — its `TX;` is
/// the command that KEYS the radio, sent only by the operator's own key
/// ([buildKenwoodSetTxCommand]) and never as a question — so the flag in
/// `IF` is the only way to ask. It sits in the character
/// immediately before the mode across every documented generation of the
/// packet (P8 RX/TX, then P9 mode), which is why this takes the mode offset
/// rather than an offset of its own: it inherits whatever confidence that
/// one has, including the driver's refusal to guess it.
///
/// Null for a packet too short, or a character that is neither `0` nor `1` —
/// a layout this does not fit, rather than a radio that is receiving.
bool? parseKenwoodInfoTransmittingBeforeMode(String params, int modeOffset) {
  final offset = modeOffset - 1;
  if (offset < 0 || offset >= params.length) return null;
  return switch (params[offset]) {
    '0' => false,
    '1' => true,
    _ => null,
  };
}

/// `TX;` keys the transmitter, `RX;` returns to receive. The bare `TX;`,
/// with no P1: SEND on the TS-590/890/990, and the form the Elecraft K3, K4
/// and KX references give.
String buildKenwoodSetTxCommand(bool on) => on ? 'TX;' : 'RX;';

/// Kenwood's Auto-Information has two levels, and the difference matters:
/// `AI1` reports only what the radio itself changed, `AI2` also reports what
/// the host changed. `AI2` is the one that reflects a dial turn promptly on
/// the whole modern line.
String buildKenwoodAutoInformationCommand(bool on) => on ? 'AI2;' : 'AI0;';

/// How a radio on this driver keys CW from text — two shapes of the same
/// `KY` command. Pinned per catalogue entry through config like the voice
/// dialect; a rig with none declares no dialect and keys nothing.
enum KenwoodCwDialect {
  /// Kenwood proper (TS-590 and the older line): `KY ` then the text padded
  /// with spaces to 24, a fixed 28-byte command the radio otherwise
  /// ignores; `KY0;` empties the buffer. 4-60 WPM. From hamlib's account
  /// of the line rather than a Kenwood document.
  kenwood,

  /// Elecraft (K3, KX2, KX3, K4 — and a QRP Labs QMX): `KY text;` as is,
  /// up to 24 characters; `KY @;` terminates the message, the `@` the
  /// programmer's reference reserves for exactly that. 8-50 WPM.
  elecraft,
}

/// What one `KY` command may carry on either dialect — the K3 family's
/// limit, and the block a Kenwood pads to. The K4 takes 60, which is not
/// exploited: a chunk boundary on a word gap is invisible on the air.
const kenwoodKeyerMaxChars = 24;

/// [text] must already be sanitized (cw_send_queue.dart) and at most
/// [kenwoodKeyerMaxChars] long.
String buildKenwoodSendCwCommand(KenwoodCwDialect dialect, String text) => switch (dialect) {
  KenwoodCwDialect.kenwood => 'KY ${text.padRight(kenwoodKeyerMaxChars)};',
  KenwoodCwDialect.elecraft => 'KY $text;',
};

String buildKenwoodStopCwCommand(KenwoodCwDialect dialect) => switch (dialect) {
  KenwoodCwDialect.kenwood => 'KY0;',
  KenwoodCwDialect.elecraft => 'KY @;',
};

({int min, int max}) kenwoodKeyerSpeedRange(KenwoodCwDialect dialect) => switch (dialect) {
  KenwoodCwDialect.kenwood => (min: 4, max: 60),
  KenwoodCwDialect.elecraft => (min: 8, max: 50),
};

/// `KS;` reads the keyer speed; the answer is `KSnnn;` on both dialects.
String buildKenwoodReadKeyerSpeedCommand() => 'KS;';

String buildKenwoodSetKeyerSpeedCommand(KenwoodCwDialect dialect, int wpm) {
  final range = kenwoodKeyerSpeedRange(dialect);
  return 'KS${wpm.clamp(range.min, range.max).toString().padLeft(3, '0')};';
}

/// `KS020;` → 20. Null unless it's exactly three digits.
int? parseKenwoodKeyerSpeedParams(String params) => RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;

/// How a radio on this driver plays its voice memories — the line agrees
/// on `PB` for playback but on little else, and the KX2/KX3 have no `PB`
/// at all. Pinned per catalogue entry through config, like the `IF` mode
/// offset; a rig with none (a QMX) declares no dialect.
enum KenwoodVoiceDialect {
  /// `PBn;` plays, `PB0;` stops, `PB;` reads what is playing — the TS-590
  /// generation, and what Kenwood's own reference documents. No recording.
  pb,

  /// The Elecraft K4: `PBn;` as an alias of `DAMPn;`, `DA;` answering `DA0;`
  /// idle / `DAPM…;` playing / `DARM…;` recording, and recording over CAT —
  /// `DARM;` records from the microphone, `DAMSn;` saves it to memory n.
  k4,

  /// The Elecraft KX2 and KX3: no message command, only front-panel switch
  /// emulation — a tap of MSG (`SWT11;`) then of the message's number key.
  /// `RX;` ends message play per the programmer's reference. No recording.
  kx,
}

/// `PBn;` — the same across the pb and k4 dialects.
String buildKenwoodPlayVoiceCommand(int n) => 'PB$n;';

/// `PB0;` cancels playback — the pb dialect's stop; the K4 stops through
/// [buildK4StopDigitalAudioCommand] instead.
String buildKenwoodStopVoiceCommand() => 'PB0;';

String buildKenwoodReadVoicePlaybackCommand() => 'PB;';

/// `PBn` → n. Null for anything but a single digit.
int? parseKenwoodVoicePlaybackParams(String params) => RegExp(r'^\d$').hasMatch(params) ? int.tryParse(params) : null;

String buildK4ReadDigitalAudioCommand() => 'DA;';

/// `DA0;` — "stop any digital audio action (stop transmitting, stop
/// recording, etc.)", the K4's one stop for playback and recording alike.
String buildK4StopDigitalAudioCommand() => 'DA0;';

/// `DA;`'s answer, reduced to what the session needs: whether a message is
/// playing to the transmitter (`DAPM…`), a recording is running (`DARM…`),
/// or neither (`DA0`, or any of the speaker-side states).
({bool playing, bool recording})? parseK4DigitalAudioParams(String params) {
  if (params == '0') return (playing: false, recording: false);
  if (params.startsWith('PM')) return (playing: true, recording: false);
  if (params.startsWith('RM')) return (playing: false, recording: true);
  if (params.startsWith('PW') || params.startsWith('RS') || params.startsWith('PS')) {
    return (playing: false, recording: false);
  }
  return null;
}

/// `DARM;` — record a voice message from the microphone.
String buildK4RecordVoiceCommand() => 'DARM;';

/// `DAMSn;` — save the last recording as message [n], 1-8.
String buildK4SaveVoiceCommand(int n) => 'DAMS$n;';

/// The KX3/KX2 keypad digits as switch identifiers (programmer's reference
/// tables 8 and 8A): '1' is PRE on both, '2' is ATTN on the KX3 and FIL on
/// the KX2, both 27. Two messages is all either radio's DVR holds.
const kxVoiceMemoryCount = 2;
const _kxMsgSwitch = 11;
const _kxDigitSwitches = {1: 19, 2: 27};

/// A tap of MSG then of the digit: two commands, in this order.
List<String> buildKxPlayVoiceCommands(int n) => ['SWT$_kxMsgSwitch;', 'SWT${_kxDigitSwitches[n.clamp(1, kxVoiceMemoryCount)]};'];

/// `RX;` — "terminates transmit in all modes, including message play".
String buildKxStopVoiceCommand() => 'RX;';

/// `TQ;` — `TQ1;` transmitting, `TQ0;` not; the cheapest way the
/// programmer's reference offers to learn a message has ended.
String buildElecraftReadTransmitQueryCommand() => 'TQ;';

bool? parseElecraftTransmitQueryParams(String params) => switch (params) {
  '0' => false,
  '1' => true,
  _ => null,
};

/// Re-exported so a driver needs one import for the whole protocol.
typedef KenwoodFramer = AsciiCatFramer;
