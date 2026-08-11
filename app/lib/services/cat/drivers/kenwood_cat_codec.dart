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
const kenwoodModeCodes = <String, String>{
  'LSB': '1',
  'USB': '2',
  'CW': '3',
  'FM': '4',
  'AM': '5',
  'RTTY': '6',
  'CW-R': '7',
  'RTTY-R': '9',
};

final Map<String, String> _modeNamesByCode = {
  for (final entry in kenwoodModeCodes.entries) entry.value: entry.key,
};

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
int? parseKenwoodPowerParams(String params) =>
    RegExp(r'^\d{3}$').hasMatch(params) ? int.tryParse(params) : null;

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
String? parseKenwoodModeParams(String params) =>
    params.length == 1 ? kenwoodModeForCode(params) : null;

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

/// Kenwood's Auto-Information has two levels, and the difference matters:
/// `AI1` reports only what the radio itself changed, `AI2` also reports what
/// the host changed. `AI2` is the one that reflects a dial turn promptly on
/// the whole modern line.
String buildKenwoodAutoInformationCommand(bool on) => on ? 'AI2;' : 'AI0;';

/// Re-exported so a driver needs one import for the whole protocol.
typedef KenwoodFramer = AsciiCatFramer;
