// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Yaesu CAT: an ASCII command protocol, documented per-radio (see the FT-891
// CAT Operation Reference Book). Unlike Icom's CI-V, frequency is a plain
// zero-padded decimal Hz string, not BCD. Every command ends with ";" —
// there is no other framing.
//
// Pure: it builds and parses strings and knows nothing about sockets,
// serial ports or timers. The `;` framing itself is shared with Kenwood and
// lives in cat_ascii_codec.dart; this file is only what Yaesu puts inside it. Ported from app-polo's YaesuCatProtocol.js, which
// was the highest-confidence code on that branch precisely because it had
// no I/O in it. See docs/design/cat.md on why the codec is shared while
// the glue around it is not.

export 'cat_ascii_codec.dart' show AsciiCatCommand, AsciiCatFramer, parseAsciiCatCommand;

/// Auto-Information: the radio pushes a status line whenever the VFO changes,
/// instead of us polling for it. Yaesu's CAT manual doesn't spell out the
/// unsolicited format beyond "reports change of status", which is why
/// [Ft891Session] polls as well rather than trusting this alone.
///
/// Yaesu's, not shared: Kenwood spells the same command with a different
/// level (see kenwood_cat_codec.dart).
String buildAutoInformationCommand(bool on) => 'AI${on ? 1 : 0};';

/// P2 mode digit, per the FT-891 CAT manual's MD/MR tables. 'A' is
/// unused/reserved, which is why the letters skip it.
const yaesuModeCodes = <String, String>{
  'LSB': '1',
  'USB': '2',
  'CW': '3',
  'FM': '4',
  'AM': '5',
  'RTTY-LSB': '6',
  'CW-R': '7',
  'DATA-LSB': '8',
  'RTTY-USB': '9',
  'FM-N': 'B',
  'DATA-USB': 'C',
  'AM-N': 'D',
};

final Map<String, String> _modeNamesByCode = {
  for (final entry in yaesuModeCodes.entries) entry.value: entry.key,
};

String? modeNameForCode(String code) => _modeNamesByCode[code];

String? codeForModeName(String? name) => name == null ? null : yaesuModeCodes[name.toUpperCase()];

/// The radio wants Hz as 9 digits, zero-padded (P1 range 000030000–056000000,
/// i.e. 30 kHz–56 MHz).
String encodeFrequencyHz(int freqHz) {
  final digits = freqHz.abs().toString().padLeft(9, '0');
  // Keep the LAST nine: a value too large to express is truncated the same
  // way the radio would read it, rather than producing an over-long command
  // the radio silently rejects.
  return digits.substring(digits.length - 9);
}

String buildSetFrequencyCommand(int freqHz) => 'FA${encodeFrequencyHz(freqHz)};';

String buildReadFrequencyCommand() => 'FA;';

/// Null for a mode the radio has no code for — the caller sends nothing
/// rather than a malformed command.
String? buildSetModeCommand(String? mode) {
  final code = codeForModeName(mode);
  return code == null ? null : 'MD0$code;';
}

String buildReadModeCommand() => 'MD0;';

/// `PC` is a 3-digit level, 005-100 per the FT-891 CAT manual — RF power
/// output in watts directly, unlike Kenwood's implied-watts `PC`, which the
/// FT-891's own manual states explicitly. NOT captured against the bench
/// FT-891 this driver's frequency/mode path was verified on — see
/// ft891_driver.dart's own notes on what has and hasn't met hardware.
/// Clamped, not truncated: a value outside the documented range is more
/// likely operator error than a command the radio would parse differently.
String buildSetPowerCommand(num watts) => 'PC${watts.round().clamp(5, 100).toString().padLeft(3, '0')};';

String buildReadPowerCommand() => 'PC;';

/// `PC100;` → 100. Null unless it's exactly three digits.
int? parsePowerParams(String params) => RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;


/// `KS;` reads the keyer speed; the answer is `KSnnn;`, 004-060 WPM on the
/// FTDX10 and FT-891 alike.
String buildReadKeyerSpeedCommand() => 'KS;';

const yaesuKeyerSpeedMin = 4;
const yaesuKeyerSpeedMax = 60;

String buildSetKeyerSpeedCommand(int wpm) =>
    'KS${wpm.clamp(yaesuKeyerSpeedMin, yaesuKeyerSpeedMax).toString().padLeft(3, '0')};';

/// `KS020;` → 20. Null unless it's exactly three digits.
int? parseKeyerSpeedParams(String params) => RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;

/// Yaesu CAT has no "key this text" command. What it has is five text
/// memories the operator can also fill from the front panel — `KM` writes
/// one (up to [yaesuKeyerMemoryMaxChars]) and `KY` plays one back. Keying
/// a message from the app is therefore WRITE-THEN-PLAY through one memory
/// the app takes over, and the operator's own text in that slot is gone;
/// [yaesuAppKeyerMemory] is the last of the five so the four most people
/// fill first are left alone.
///
/// Playback has no stop command in the manual, which is why
/// [Ft891Session.stopCw] can only stop QUEUING.
const yaesuAppKeyerMemory = 5;
const yaesuKeyerMemoryMaxChars = 50;

/// [text] must already be sanitized (cw_send_queue.dart) and no longer than
/// [yaesuKeyerMemoryMaxChars].
String buildWriteKeyerMemoryCommand(int memory, String text) => 'KM$memory$text;';

/// `KY6;`-`KYA;` play the TEXT memories 1-5 ("Message Keyer" in the manual's
/// words); `KY1;`-`KY5;` play the recorded-from-paddle ones, which are not
/// what `KM` writes.
String buildPlayKeyerMemoryCommand(int memory) => 'KY${(5 + memory).toRadixString(16).toUpperCase()};';

/// `FA014250000;` → 14250000 Hz. Null unless it's exactly nine digits —
/// a truncated or over-long response is not a frequency.
int? parseFrequencyParams(String params) {
  if (!RegExp(r'^\d{9}$').hasMatch(params)) return null;
  return int.tryParse(params);
}

/// The radio's own status packet, which is what Auto-Information actually
/// pushes when the operator turns the dial — NOT `FA`/`MD`, which only ever
/// come back as answers to a read. Ignoring `IF` would leave a connected
/// radio moving only when the 5-second poll comes round.
///
/// Layout, derived from a live FT-891 rather than from the manual's table
/// (`IF001014233700+000000200000;` alongside its own `FA014233700;` and
/// `MD02;`), params being everything between `IF` and `;`:
///
///     001 014233700 +0000 0 0 2 ...
///     |   |         |     | | └─ P6 mode, index 19
///     |   |         |     | └─ TX clarifier
///     |   |         |     └─ RX clarifier
///     |   |         └─ P3 clarifier offset
///     |   └─ P2 frequency in Hz, 9 digits, indices 3..11
///     └─ P1 memory channel
///
/// Returns null for anything that doesn't match, so a short or unexpected
/// packet is skipped rather than reported as a bogus frequency.
({int? freqHz, String? mode})? parseInformationParams(String params) {
  if (params.length < 20) return null;
  final digits = params.substring(3, 12);
  if (!RegExp(r'^\d{9}$').hasMatch(digits)) return null;
  return (freqHz: int.tryParse(digits), mode: modeNameForCode(params[19]));
}

/// `MD01;` → `LSB`. P1 (the fixed `0` for MAIN) is ignored.
String? parseModeParams(String params) {
  if (params.isEmpty) return null;
  return modeNameForCode(params.substring(params.length - 1));
}
