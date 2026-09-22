// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The framing Yaesu CAT and Kenwood CAT share exactly: two upper-case letters,
// a payload, and a `;`. Nothing else terminates a command, and nothing about
// the payload is common between the two families — so this file knows about
// the envelope and nothing about what is inside it.
//
// Not even the commands that LOOK common. Both families have `AI`, and they
// disagree about it: Yaesu's useful level is 1 and Kenwood's is 2, so each
// codec builds its own. A shared builder here would be in scope in both
// drivers and compile in either, quietly asking the wrong radio for the wrong
// level.
//
// Shared rather than copied because docs/design/cat.md is explicit about
// where the bugs live: "Duplicating glue is cheap; duplicating frame parsing
// duplicates parsing bugs." Every app-polo bug was in an I/O layer, and the
// residual buffer below is exactly the kind of thing that gets subtly
// different in a second copy.
//
// Pure: it builds and parses strings and knows nothing about sockets, serial
// ports or timers.

/// One complete command off the wire.
class AsciiCatCommand {
  /// The two-letter command, e.g. `FA`.
  final String command;

  /// Everything between the command and the `;`.
  final String params;

  const AsciiCatCommand(this.command, this.params);

  @override
  bool operator ==(Object other) => other is AsciiCatCommand && other.command == command && other.params == params;

  @override
  int get hashCode => Object.hash(command, params);

  @override
  String toString() => 'AsciiCatCommand($command, $params)';
}

/// Splits an ASCII stream into complete `;`-terminated commands, carrying
/// whatever follows the last `;` over to the next call.
///
/// Serial delivers arbitrary chunks — a command can and does arrive split
/// across two reads — so the residual is not an edge case.
class AsciiCatFramer {
  String _residual = '';

  /// The complete commands in [incoming], with any partial tail retained.
  List<AsciiCatCommand> add(String incoming) {
    final text = _residual + incoming;
    final parts = text.split(';');
    // Whatever follows the last ';' is incomplete (or empty).
    _residual = parts.removeLast();
    return [for (final part in parts) ?parseAsciiCatCommand('$part;')];
  }

  /// Drops any partial command — for a fresh connection, so a truncated
  /// tail from the previous one can't prefix the first real command.
  void reset() => _residual = '';
}

final _commandPattern = RegExp(r'^([A-Z]{2})(.*);$');
final _commandStart = RegExp(r'[A-Z]{2}');

/// Parses one complete command, or null if it isn't one.
///
/// Leading junk is skipped rather than fatal. Sessions decode with
/// `allowInvalid`, so one noise byte on the wire becomes a replacement
/// character sitting in FRONT of a perfectly good command — and an anchored
/// match would throw the whole reading away silently. On a 4800-baud line
/// beside a transmitting rig that is the expected case, not a rare one.
AsciiCatCommand? parseAsciiCatCommand(String line) {
  final start = line.indexOf(_commandStart);
  if (start < 0) return null;
  final match = _commandPattern.firstMatch(start == 0 ? line : line.substring(start));
  return match == null ? null : AsciiCatCommand(match.group(1)!, match.group(2)!);
}
