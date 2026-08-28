// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Splits a byte stream into `\n`-terminated text lines, carrying whatever
// follows the last newline over to the next chunk.
//
// The framing the SmartSDR API and the 4O3A Antenna Genius share — 4O3A
// built the Genius protocol in the same shape, down to the `C<seq>|`
// commands and `R<seq>|` replies. Shared rather than copied for the reason
// docs/design/cat.md gives: "Duplicating glue is cheap; duplicating frame
// parsing duplicates parsing bugs." app-polo's FlexRadio driver split each
// chunk on `\n` with no residual at all, so a status line straddling two TCP
// reads was mangled — exactly the bug a second hand-rolled copy reintroduces.
//
// Its `;`-terminated counterpart for Yaesu and Kenwood is
// cat_ascii_codec.dart; the two share no envelope, only the idea.
//
// Pure: bytes in, strings out, no sockets and no timers.

import 'dart:convert';
import 'dart:typed_data';

const _lineFeed = 0x0a;
const _carriageReturn = 0x0d;

class LineFramer {
  /// Whether a carriage return ends a line as well as a line feed.
  ///
  /// False — the default, and what the SmartSDR-family peers need — drops CR
  /// wherever it falls, which is what makes a CRLF peer and a bare-LF one
  /// produce the same lines.
  ///
  /// True for a peer whose terminator IS the carriage return, as the Sierra
  /// Radio DCN's end of packet is. Empty lines are then suppressed, so a
  /// peer that sends CRLF still yields one line per packet rather than a
  /// blank after each — which is also why this cannot simply be the
  /// behaviour in both modes: a protocol whose blank line means something
  /// (an Antenna Genius terminates a multi-line answer with one) would lose
  /// it.
  final bool crTerminates;

  LineFramer({this.crTerminates = false});

  /// Bytes received since the last complete line.
  final _residual = <int>[];

  /// The complete lines in [chunk], with any partial tail retained.
  ///
  /// Decoded with `allowMalformed`, so one corrupt byte costs a replacement
  /// character rather than throwing away a line that is otherwise readable.
  List<String> add(Uint8List chunk) {
    final lines = <String>[];
    for (final byte in chunk) {
      if (byte == _lineFeed || (crTerminates && byte == _carriageReturn)) {
        final line = utf8.decode(_residual, allowMalformed: true);
        _residual.clear();
        if (crTerminates && line.isEmpty) continue;
        lines.add(line);
      } else if (byte != _carriageReturn) {
        _residual.add(byte);
      }
    }
    return lines;
  }

  /// Drops any partial line — for a fresh connection, so a truncated tail
  /// from the previous one cannot prefix the first real line of the next.
  void reset() => _residual.clear();
}
