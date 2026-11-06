// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Thetis's CAT: the `ZZ` command set an Apache Labs ANAN is driven by, served
// by Thetis (the SDR program that runs the radio) over its TCP/IP CAT server.
// The radio itself has no CAT; everything here is answered by the program.
//
// Written from the "Thetis and PowerSDR 3.x CAT Command Reference Guide"
// (K5KDN, G8NJJ; revised 2014-03-06, with the Thetis 2.6.7–2.6.9 status
// pages), which ships with Thetis. Nothing here has met a running Thetis.
//
// The `ZZ` set and not Thetis's Kenwood TS-2000 emulation, which it also
// answers: TS-2000's `MD` has no code for DIGU at all (Thetis reports it as
// FSK-R), and its `IF` packet is laid out differently from the reference's
// `ZZIF`. Every `ZZ` answer names its own command, so nothing here reads a
// field by its position in a longer packet.
//
// Pure: it builds and parses strings and knows nothing about sockets or
// timers. Framing is the shared `;`-terminated envelope (cat_ascii_codec.dart),
// which frames `ZZFA…;` as command `ZZ` — [thetisCommandOf] splits it.

import 'cat_ascii_codec.dart';
import 'rated_power_config.dart';

/// Where Thetis's TCP/IP CAT server listens unless its Setup says otherwise
/// (Setup → Serial/Network/Midi CAT → Network).
const thetisDefaultPort = 13013;

/// `ZZMD` codes, from the reference's table. The app's `CW` is Thetis's
/// CWU and `CW-R` its CWL, the pairing Thetis's own TS-2000 `MD` makes
/// (`3` CWU, `7` CWL). DIGU and DIGL are its data sidebands.
///
/// DSB (`02`), SPEC (`08`) and DRM (`11`) are absent: the app has no mode
/// for them, and naming one would report a plausible wrong mode.
const thetisModeCodes = <String, String>{'LSB': '00', 'USB': '01', 'CW-R': '03', 'CW': '04', 'FM': '05', 'AM': '06', 'DATA-USB': '07', 'DATA-LSB': '09'};

/// Read, never set: SAM (`10`) is synchronous AM, which a log records as AM.
/// Setting `AM` puts the radio in plain AM.
const _thetisReadOnlyModes = <String, String>{'10': 'AM'};

final _thetisModesByCode = {for (final entry in thetisModeCodes.entries) entry.value: entry.key, ..._thetisReadOnlyModes};

/// A `ZZ` answer as its four-letter command and its parameters: the shared
/// framer reads `ZZFA00014074000;` as command `ZZ`, params `FA00014074000`.
/// Null for anything that is not a `ZZ` command — a Kenwood answer, or a
/// `ZZ` too short to name one.
({String command, String params})? thetisCommandOf(AsciiCatCommand frame) {
  if (frame.command != 'ZZ' || frame.params.length < 2) return null;
  final name = frame.params.substring(0, 2).toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(name)) return null;
  return (command: 'ZZ$name', params: frame.params.substring(2));
}

/// Eleven digits of Hz, as `ZZFA` and `ZZFB` both carry it.
const thetisFrequencyDigits = 11;

String buildThetisReadFrequencyCommand() => 'ZZFA;';

/// `ZZFA00014074000;`. VFO A only: the reference says Thetis's VFO A is
/// always the receive VFO, so it is the one the operator is listening on.
/// A value past eleven digits keeps its last eleven, as the radio would read
/// it, rather than making a command the radio ignores.
String buildThetisSetFrequencyCommand(int freqHz) {
  final digits = freqHz.abs().toString().padLeft(thetisFrequencyDigits, '0');
  return 'ZZFA${digits.substring(digits.length - thetisFrequencyDigits)};';
}

/// `00014074000` → 14074000 Hz. Null unless exactly eleven digits.
int? parseThetisFrequencyParams(String params) => RegExp('^\\d{$thetisFrequencyDigits}\$').hasMatch(params) ? int.parse(params) : null;

String buildThetisReadModeCommand() => 'ZZMD;';

/// Null for a mode Thetis has no code for — nothing is sent rather than a
/// malformed command.
String? buildThetisSetModeCommand(String mode) {
  final code = thetisModeCodes[mode.toUpperCase()];
  return code == null ? null : 'ZZMD$code;';
}

/// `07` → `DATA-USB`. Null for a code with no app mode, and for anything
/// but two digits.
String? parseThetisModeParams(String params) => RegExp(r'^\d{2}$').hasMatch(params) ? _thetisModesByCode[params] : null;

String buildThetisReadDriveCommand() => 'ZZPC;';

/// `ZZPC` is the PA drive, 000–100: a share of the radio's rated output, not
/// watts. Clamped, since the radio ignores a value out of range.
String buildThetisSetDriveCommand(num watts, {required num ratedWatts}) => 'ZZPC${driveShareFor(watts, ratedWatts: ratedWatts).toString().padLeft(3, '0')};';

/// `050` → 50 (percent). Null unless exactly three digits, 100 or under.
int? parseThetisDriveParams(String params) {
  if (!RegExp(r'^\d{3}$').hasMatch(params)) return null;
  final level = int.parse(params);
  return level <= 100 ? level : null;
}

/// `ZZXV;` reads the combined VFO status word — the narrow question for
/// whether the radio is on the air, where `ZZIF` would answer 36 characters.
String buildThetisReadVfoStatusCommand() => 'ZZXV;';

/// MOX (bit 6) and TUNE (bit 7) of the `ZZXV` word.
const _thetisMoxBit = 1 << 6;
const _thetisTuneBit = 1 << 7;

/// Whether the radio is transmitting, from a `ZZXV` answer: MOX or TUNE,
/// because a tune carrier is RF on the air like any other, and nothing may
/// switch an antenna under it.
///
/// The reference draws the answer three characters wide and describes it as
/// `0000` to `1023`, ten bits; three or four digits are both taken. Null for
/// anything else.
bool? parseThetisTransmittingParams(String params) {
  if (!RegExp(r'^\d{3,4}$').hasMatch(params)) return null;
  final word = int.parse(params);
  return word & (_thetisMoxBit | _thetisTuneBit) != 0;
}

/// What one TX watch costs on the wire: `ZZXV;` and `ZZXVnnnn;`.
const thetisTxWatchBytes = 5 + 9;

/// `ZZTX1;` sets MOX, `ZZTX0;` clears it.
String buildThetisSetMoxCommand(bool on) => on ? 'ZZTX1;' : 'ZZTX0;';

/// What one `ZZKY` carries: up to 24 characters, the empty places spaces.
const thetisKeyerMaxChars = 24;

/// `ZZKY ` and [text] padded to [thetisKeyerMaxChars] — Thetis's CWX keyer
/// sends it. [text] must already be sanitized (cw_send_queue.dart).
String buildThetisSendCwCommand(String text) => 'ZZKY ${text.padRight(thetisKeyerMaxChars)};';

/// `ZZSS;` stops CWX at once, mid-character.
String buildThetisStopCwCommand() => 'ZZSS;';

/// CWX's speed range, per `ZZKS`.
const thetisKeyerSpeedRange = (min: 1, max: 99);

String buildThetisReadKeyerSpeedCommand() => 'ZZKS;';

String buildThetisSetKeyerSpeedCommand(int wpm) => 'ZZKS${wpm.clamp(thetisKeyerSpeedRange.min, thetisKeyerSpeedRange.max).toString().padLeft(3, '0')};';

/// `025` → 25. Null unless exactly three digits within CWX's range.
int? parseThetisKeyerSpeedParams(String params) {
  if (!RegExp(r'^\d{3}$').hasMatch(params)) return null;
  final wpm = int.parse(params);
  return wpm >= thetisKeyerSpeedRange.min && wpm <= thetisKeyerSpeedRange.max ? wpm : null;
}

/// `ZZVN;` reads the program's version, said once as a diagnostic.
String buildThetisReadVersionCommand() => 'ZZVN;';
