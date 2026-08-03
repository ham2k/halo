// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Yaesu CAT: an ASCII command protocol, documented per-radio (see the FT-891
// CAT Operation Reference Book). Unlike Icom's CI-V, frequency is a plain
// zero-padded decimal Hz string, not BCD. Every command ends with ";" —
// there is no other framing.
//
// Pure: it builds and parses strings and knows nothing about sockets,
// serial ports or timers. Ported from app-polo's YaesuCatProtocol.js, which
// was the highest-confidence code on that branch precisely because it had
// no I/O in it. See docs/design/cat.md on why the codec is shared while
// the glue around it is not.

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

/// Auto-Information: the radio pushes a status line whenever the VFO
/// changes, instead of us polling for it. The CAT manual doesn't spell out
/// the unsolicited format beyond "reports change of status", which is why
/// [Ft891Driver] polls as well rather than trusting this alone.
String buildAutoInformationCommand(bool on) => 'AI${on ? 1 : 0};';

/// One complete command off the wire.
class YaesuCommand {
  /// The two-letter command, e.g. `FA`.
  final String command;

  /// Everything between the command and the `;`.
  final String params;

  const YaesuCommand(this.command, this.params);

  @override
  bool operator ==(Object other) =>
      other is YaesuCommand && other.command == command && other.params == params;

  @override
  int get hashCode => Object.hash(command, params);

  @override
  String toString() => 'YaesuCommand($command, $params)';
}

/// Splits an ASCII stream into complete `;`-terminated commands, carrying
/// whatever follows the last `;` over to the next call.
///
/// Serial delivers arbitrary chunks — a command can and does arrive split
/// across two reads — so the residual is not an edge case.
class YaesuFramer {
  String _residual = '';

  /// The complete commands in [incoming], with any partial tail retained.
  List<YaesuCommand> add(String incoming) {
    final text = _residual + incoming;
    final parts = text.split(';');
    // Whatever follows the last ';' is incomplete (or empty).
    _residual = parts.removeLast();
    return [
      for (final part in parts)
        if (parseCommand('$part;') case final command?) command,
    ];
  }

  /// Drops any partial command — for a fresh connection, so a truncated
  /// tail from the previous one can't prefix the first real command.
  void reset() => _residual = '';
}

final _commandPattern = RegExp(r'^([A-Z]{2})(.*);$');

/// Parses one complete command, or null if it isn't one.
///
/// Leading junk is skipped rather than fatal. [Ft891Session.handleData]
/// decodes with `allowInvalid`, so one noise byte on the wire becomes a
/// replacement character sitting in FRONT of a perfectly good command —
/// and an anchored match would throw the whole reading away silently. On a
/// 4800-baud line beside a transmitting rig that is the expected case, not
/// a rare one.
YaesuCommand? parseCommand(String line) {
  final start = line.indexOf(_commandStart);
  if (start < 0) return null;
  final match = _commandPattern.firstMatch(start == 0 ? line : line.substring(start));
  return match == null ? null : YaesuCommand(match.group(1)!, match.group(2)!);
}

final _commandStart = RegExp(r'[A-Z]{2}');

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
