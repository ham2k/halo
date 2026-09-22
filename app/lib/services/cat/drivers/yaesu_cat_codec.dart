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

final Map<String, String> _modeNamesByCode = {for (final entry in yaesuModeCodes.entries) entry.value: entry.key};

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

/// Asks whether the radio is transmitting.
///
/// READ ONLY — `TX1;`/`TX2;` would KEY the radio, so the bare `TX;` is the
/// only form this app ever sends. (The Kenwood line has no read form at
/// all, which is why its driver reads the flag out of `IF` instead.)
String buildReadTransmitStatusCommand() => 'TX;';

/// Also a playing memory's clock: a radio that unkeys itself at the end of
/// one does not always SAY so unprompted, so a voice play asks this every
/// second (see [Ft891Session]).
///
/// `TX0;` receiving, `TX1;` transmitting from the radio's own PTT, `TX2;`
/// transmitting because CAT asked. Null for anything else, which is a
/// radio that does not answer the command rather than one that is
/// receiving — the difference decides whether an antenna relay may move.
bool? parseTransmitStatusParams(String params) => switch (params.trim()) {
  '0' => false,
  '1' || '2' => true,
  _ => null,
};

/// The meter reads, by the numbers Yaesu's own CAT manuals give them.
///
/// The spec, for both radios this driver has met:
/// https://www.yaesu.com/Files/4CB893D7-1018-01AF-FA97E9E9AD48B50C/FT-891_CAT_OM_ENG_1909-C.pdf
/// https://www.yaesu.com/Files/4CB893D7-1018-01AF-FA97E9E9AD48B50C/FTDX10_CAT_OM_ENG_2308-F.pdf
///
/// They agree on the three that matter — 4 ALC, 5 PO, 6 SWR — and on a
/// reading of 0-255. What neither publishes, anywhere, is what that number
/// MEANS: there is no table from 0-255 to watts or to an SWR ratio. That
/// missing scale is why nothing here converts.
///
/// Reading a numbered meter is SAFE, unlike on a Kenwood: which meter the
/// front panel displays is a separate command (`MS`), so asking for one
/// here does not change what the operator is looking at. Only `RM0` and
/// `RM2` are tied to the panel — they read "whatever it is showing" — which
/// is why neither is ever asked for.
///
/// Worse than undocumented, the scale is per-RADIO. The technical
/// supplements align these meters in service mode, per band, on each
/// individual unit (`100W MTR 1.8` and its siblings), so a table taken off
/// one FTDX10 describes that FTDX10. Anything shipped from a capture is a
/// starting point, not a calibration. The raw values are captured
/// against a rig on the bench (see [Ft891Session]) so a real table can be
/// built from real readings, rather than a curve being invented and then
/// compared against an SWR threshold the operator is warned at.
const yaesuMeterAlc = 4;
const yaesuMeterPowerOut = 5;
const yaesuMeterSwr = 6;

/// DC input voltage — on the FTDX10, which has it; the FT-891's table stops
/// at 7 (ID) and answers this with nothing useful. Asked anyway during a
/// capture: a radio that does not have the meter simply does not answer,
/// and the alternative is a second capture pass to find out.
const yaesuMeterVdd = 8;

/// The meters a capture reads, in the order asked.
const yaesuCaptureMeters = [yaesuMeterPowerOut, yaesuMeterSwr, yaesuMeterAlc, yaesuMeterVdd];

String buildReadMeterCommand(int meter) => 'RM$meter;';

/// `RM5123;` → (meter: 5, level: 123).
///
/// TWO answer shapes, and this is exactly the kind of difference that makes
/// "the Yaesu line is all the same" wrong. The FT-891 answers
/// `RM P1 P2P2P2;`; the FTDX10 answers `RM P1 P2P2P2 P3P3P3;` with a P3 its
/// manual documents as fixed `000`. A parser that took only the shorter form
/// would read NOTHING from an FTDX10 — silently, since an unparsed answer
/// looks exactly like a radio that never replied.
///
/// The fixed tail is dropped rather than checked: it is documented as a
/// constant, so a radio that put something else there is telling us
/// something this parser has no way to interpret, and refusing the whole
/// reading over it would lose the part we do understand.
///
/// Null for anything else — including `RM0;`, which selects what the front
/// panel displays rather than answering a question.
({int meter, int level})? parseMeterParams(String params) {
  if (params.length != 4 && params.length != 7) return null;
  final meter = int.tryParse(params[0]);
  final level = int.tryParse(params.substring(1, 4));
  if (meter == null || level == null) return null;
  return (meter: meter, level: level);
}

/// `KS;` reads the keyer speed; the answer is `KSnnn;`, 004-060 WPM on the
/// FTDX10 and FT-891 alike.
String buildReadKeyerSpeedCommand() => 'KS;';

const yaesuKeyerSpeedMin = 4;
const yaesuKeyerSpeedMax = 60;

String buildSetKeyerSpeedCommand(int wpm) => 'KS${wpm.clamp(yaesuKeyerSpeedMin, yaesuKeyerSpeedMax).toString().padLeft(3, '0')};';

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

/// The voice memories ("DVS" in the CAT manuals) across the line: five on
/// the FT-891, FT-710, FT-991A and FTDX10 alike. `PB` plays one and `LM`
/// records one, both with a fixed `0` ahead of the channel digit.
const yaesuVoiceMemoryCount = 5;

/// `PB` starts the DVS but does NOT key the transmitter — an unkeyed radio
/// plays the memory to the monitor only, and nothing goes on the air. The
/// caller keys first with [buildSetTxCommand]; see [Ft891Session.playVoiceMemory].
String buildPlayVoiceMemoryCommand(int n) => 'PB0${n.clamp(1, yaesuVoiceMemoryCount)};';

/// `TX1;` transmits under CAT ("RADIO TX OFF / CAT TX ON" in the manual's
/// P1 table), `TX0;` returns to receive. P1 2 is answer-only — the radio
/// saying its own PTT is down — so it is never sent.
String buildSetTxCommand(bool on) => 'TX${on ? 1 : 0};';

/// `PB00;` — stops playback.
String buildStopVoiceMemoryCommand() => 'PB00;';

/// `PB0;` — the answer, `PB0n;`, names the channel playing, or 0.
String buildReadVoicePlaybackCommand() => 'PB0;';

/// Starts recording into memory [n] — the same command sent again stops it,
/// which is why [buildStopVoiceRecordingCommand] exists: a stop that does not
/// have to know which channel was recording.
String buildRecordVoiceMemoryCommand(int n) => 'LM0${n.clamp(1, yaesuVoiceMemoryCount)};';

/// `LM00;` — recording stop.
String buildStopVoiceRecordingCommand() => 'LM00;';

/// `LM0;` — documented as answering `LM0n;` with the channel recording. The
/// FT-891 answers `00` while its panel blinks REC, so the read says nothing
/// about whether a recording is running and no driver here asks it (see
/// [Ft891Session]'s voice tracker). Kept because the command is real and the
/// manual's shape is worth stating where the next reader looks for it.
String buildReadVoiceRecordingCommand() => 'LM0;';

/// `0n` → n, for both `PB` and `LM` answers. Null for anything else.
int? parseVoiceChannelParams(String params) => RegExp(r'^0\d$').hasMatch(params) ? int.tryParse(params.substring(1)) : null;

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
