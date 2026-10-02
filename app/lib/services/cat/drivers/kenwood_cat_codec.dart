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
