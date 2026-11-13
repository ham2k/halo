// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Semicolon framing is common to several ASCII CAT dialects. Each framer
// decides how to split a complete command into its prefix and payload.
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
  /// The command prefix, e.g. `FA`.
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
abstract class SemicolonCatFramer {
  String _residual = '';

  /// Decodes one complete frame, including its terminating semicolon.
  AsciiCatCommand? parseCommand(String frame);

  /// Filters the buffered input before splitting and preserves any
  /// unfinished out-of-band data to process with the next read.
  (String, String) prepareInput(String text) => (text, '');

  /// The complete commands in [incoming], with any partial tail retained.
  List<AsciiCatCommand> add(String incoming) {
    final (text, tail) = prepareInput(_residual + incoming);
    final parts = text.split(';');
    _residual = parts.removeLast() + tail;
    return [for (final part in parts) ?parseCommand('$part;')];
  }

  /// Drops any partial command — for a fresh connection, so a truncated
  /// tail from the previous one can't prefix the first real command.
  void reset() => _residual = '';
}

/// The two-letter CAT grammar shared by Kenwood and Yaesu.
class AsciiCatFramer extends SemicolonCatFramer {
  AsciiCatFramer({this.dropsNmea = false});

  @override
  AsciiCatCommand? parseCommand(String frame) => parseAsciiCatCommand(frame);

  /// Whether the stream interleaves GPS NMEA-0183 sentences with the CAT —
  /// a `$`, then everything up to its line end — and they are dropped
  /// before framing. A sentence holds no `;`, so left in, it fuses with the
  /// command after it: `$GPRMC,…\r\nFA…;` would frame as one `GP` command and
  /// lose the `FA`. Never for a family that uses `$` in its commands (the
  /// K4's `MD$;`).
  final bool dropsNmea;

  /// The longest sentence NMEA-0183 allows, `$` and line end included. A
  /// `$` with no line end within it is noise, not a sentence still arriving:
  /// waiting on it would hold every command behind it.
  static const _nmeaMaxLength = 82;

  static final _lineEnd = RegExp('[\r\n]');

  /// Where a `$` stops being a sentence: its line end, or a `;`, which no
  /// sentence holds. A `$` that meets a `;` first is noise, and reading on
  /// to the next line end would swallow every CAT reply in between.
  static final _sentenceEnd = RegExp('[\r\n;]');

  @override
  (String, String) prepareInput(String text) => dropsNmea ? _withoutNmea(text) : super.prepareInput(text);

  /// [text] with every complete sentence cut out, and the incomplete one at
  /// its end — still waiting for its line end — split off. Every line end
  /// goes too, not just the one closing a sentence: CAT has none, and the
  /// `\n` of a `\r\n` would otherwise sit inside the command that follows.
  static (String, String) _withoutNmea(String text) {
    final kept = StringBuffer();
    var at = 0;
    while (true) {
      final start = text.indexOf(r'$', at);
      if (start < 0) break;
      kept.write(text.substring(at, start));
      final end = text.indexOf(_sentenceEnd, start);
      if (end >= 0 && text[end] == ';') {
        at = start + 1;
      } else if (end >= 0 && end - start < _nmeaMaxLength) {
        at = end + 1;
      } else if (end < 0 && text.length - start < _nmeaMaxLength) {
        return ('$kept'.replaceAll(_lineEnd, ''), text.substring(start));
      } else {
        at = start + 1;
      }
    }
    kept.write(text.substring(at));
    return ('$kept'.replaceAll(_lineEnd, ''), '');
  }
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
