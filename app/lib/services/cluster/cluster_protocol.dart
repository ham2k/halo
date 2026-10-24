// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a DX cluster node says and what it is told, independent of the
// socket (docs/design/cluster.md). DXSpider, AR-Cluster and CC Cluster all
// speak the same line-oriented telnet dialect to a user: a login prompt, an
// optional password prompt, then `<call> de <node> … >` prompts between
// whatever the node sends.

import 'dart:convert';

/// Turns a node's bytes into lines: telnet negotiation dropped, `\r`
/// dropped, split on `\n`. What follows the last `\n` is held as [partial],
/// because a prompt — `login: `, `KI2D de K1TTT 15-Oct 0354Z arc6>` — is
/// sent with no newline after it, and has to be recognized while it waits.
class ClusterLineDecoder {
  final _pending = StringBuffer();

  /// Telnet command state carried across chunks: an `IAC` at the very end
  /// of one read is the first byte of a command finished in the next.
  _Iac _iac = _Iac.none;

  /// The unterminated text since the last newline.
  String get partial => _pending.toString();

  /// Feeds one read; returns the lines it completed.
  List<String> add(List<int> bytes) {
    final text = StringBuffer();
    for (final byte in bytes) {
      switch (_iac) {
        case _Iac.none:
          if (byte == _iacByte) {
            _iac = _Iac.command;
          } else if (byte != 0x0D && byte != 0x00) {
            text.writeCharCode(byte);
          }
        case _Iac.command:
          // WILL/WONT/DO/DONT carry one option byte; SB runs to IAC SE; an
          // escaped 0xFF is a data byte; anything else is a bare command.
          _iac = switch (byte) {
            >= 251 && <= 254 => _Iac.option,
            250 => _Iac.subnegotiation,
            _ => _Iac.none,
          };
          if (byte == _iacByte) text.writeCharCode(byte);
        case _Iac.option:
          _iac = _Iac.none;
        case _Iac.subnegotiation:
          if (byte == _iacByte) _iac = _Iac.subnegotiationIac;
        case _Iac.subnegotiationIac:
          _iac = byte == 240 ? _Iac.none : _Iac.subnegotiation;
      }
    }
    _pending.write(text);
    final all = _pending.toString();
    final cut = all.lastIndexOf('\n');
    if (cut < 0) return const [];
    _pending
      ..clear()
      ..write(all.substring(cut + 1));
    return all.substring(0, cut).split('\n');
  }

  /// Takes [partial] as a line of its own — once it has been recognized as
  /// a prompt, so it is not glued to the front of whatever comes next.
  String takePartial() {
    final text = _pending.toString();
    _pending.clear();
    return text;
  }
}

const _iacByte = 255;

enum _Iac { none, command, option, subnegotiation, subnegotiationIac }

/// `login: ` or `Please enter your call: ` — every node probed asks one of
/// these, ending on the word and a colon. Both are required because a
/// banner arrives split across reads at any point: "At the login prompt
/// please enter your amateur radio callsign." (K1TTT, W3LPL) and NC7J's
/// "Enter your callsign" line, cut after "login" or "callsign", would
/// otherwise send the call before the node is listening for one.
final _loginPrompt = RegExp(r'\b(call(sign)?|login)\s*:\s*$', caseSensitive: false);

/// `password:` — with the colon, unlike the call prompt: a welcome text
/// split after "set/password" would otherwise send the stored password as a
/// command, and the node's reply echoing it lands in the scrollback every
/// reading extension sees.
final _passwordPrompt = RegExp(r'\bpassword\s*:\s*$', caseSensitive: false);

bool isLoginPrompt(String text) => _loginPrompt.hasMatch(text.trimRight()) && !isPasswordPrompt(text);

bool isPasswordPrompt(String text) => _passwordPrompt.hasMatch(text.trimRight());

/// Whether a COMPLETED line can be a prompt: some nodes end theirs with a
/// newline (K3LR's `Please enter your call:  `). Only with the colon — the
/// banner sentence that names the callsign ends in a full stop — and only
/// as the last thing the node sent, which the caller checks.
bool isPromptLine(String line) => line.trimRight().endsWith(':');

/// The node's command prompt for [call]: `KI2D de K1TTT 15-Oct 0354Z arc6>`
/// (AR-Cluster), `… dxspider >` (DXSpider), `… CCC >` (CC Cluster). What
/// ends a command's reply.
bool isCommandPrompt(String text, String call) {
  final trimmed = text.trim();
  if (!trimmed.endsWith('>')) return false;
  final words = trimmed.split(RegExp(r'\s+'));
  return words.length >= 3 && words[0].toUpperCase() == call.toUpperCase() && words[1].toLowerCase() == 'de';
}

/// A node's own refusals, as a reply line — a spot that is a duplicate, off
/// any band, or from a call that must register first.
final _refusal = RegExp(r'^\s*(sorry|error|invalid|not allowed|you (are|need)|frequency .* not in band)', caseSensitive: false);

bool isRefusal(String line) => _refusal.hasMatch(line);

/// What a node passes on from the network, interleaved with any reply: a
/// spot, a WWV or WCY report, an announcement. Never an answer to the
/// session's own command.
final _broadcast = RegExp(r'^\s*(DX|WWV|WCY|To \S+) de ', caseSensitive: false);

bool isBroadcast(String line) => _broadcast.hasMatch(line);

final _callPattern = RegExp(r'^[A-Z0-9]+(/[A-Z0-9]+){0,2}$');

/// The longest comment a spot carries. Nodes show the first 30 characters in
/// an 80-column `DX de` line, but carry and forward the rest, and the web
/// aggregators show all of it — so the cut is a guard against a runaway
/// comment, not the display width.
const maxSpotCommentLength = 60;

/// `DX <freq> <call> <comment>`, or null with [error] saying why the spot
/// cannot be sent. [freqKHz] is in kHz, as HaLo keeps frequencies.
({String? command, String? error}) spotCommand({required double freqKHz, required String call, String? comment}) {
  final dx = call.trim().toUpperCase();
  if (!_callPattern.hasMatch(dx)) return (command: null, error: 'invalidCall');
  if (!freqKHz.isFinite || freqKHz <= 0) return (command: null, error: 'invalidFrequency');
  final freq = freqKHz == freqKHz.roundToDouble() ? freqKHz.toStringAsFixed(0) : freqKHz.toStringAsFixed(1);
  final text = sanitizeClusterText(comment ?? '');
  final cut = text.length > maxSpotCommentLength ? text.substring(0, maxSpotCommentLength).trimRight() : text;
  return (command: ['DX', freq, dx, if (cut.isNotEmpty) cut].join(' '), error: null);
}

/// [text] as one line a node can take: control characters and newlines
/// gone (a newline would end the command and start another), runs of space
/// collapsed, anything outside Latin-1 replaced — the wire is 8-bit.
String sanitizeClusterText(String text) =>
    text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').replaceAll(RegExp(r'[^\x20-\xFF]'), '?').replaceAll(RegExp(r'\s+'), ' ').trim();

/// [line] as the bytes sent for it. A 0xFF (`ÿ`) is doubled, as telnet
/// requires of a data byte equal to its command byte: sent alone it would
/// start a telnet command to the node.
List<int> encodeClusterLine(String line) => [
  for (final byte in latin1.encode('${sanitizeClusterText(line)}\r\n')) ...(byte == 0xFF ? const [0xFF, 0xFF] : [byte]),
];
