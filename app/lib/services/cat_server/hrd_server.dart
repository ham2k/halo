// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Answers as Ham Radio Deluxe's Rig Control does on its IP port, for the
// programs that drive a radio "through HRD" (HRD Logbook, DM-780, WSJT-X's
// and its forks' Ham Radio Deluxe option).
//
// The frame and the mode names are the driver's too (hrd_codec.dart). Some
// accounts of the protocol describe it instead as newline-terminated text,
// so a client whose first bytes are not a frame is answered in text, one
// line per command.
//
// A command may carry a context prefix, `[1] get frequency`, where the
// number comes from `get context`. There is one radio here, so the prefix is
// accepted and ignored. Names with spaces travel with `~` in their place
// (`Main~Mode`), and both spellings are accepted.
//
// HRD's commands name its own user interface: a mode is a dropdown, PTT is
// the `TX` button. Only what a client needs to follow and tune a radio is
// answered. What HRD itself replies to a `set` is not documented; this
// answers `OK`, which is what the clients built against it are known to
// ignore.

import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';

import '../cat/drivers/hrd_codec.dart';
import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';

final _contextPrefix = RegExp(r'^\[\d+\]\s*');

/// The arguments of [command]: each a `{braced name}`, spaces and all, or a
/// bare word. A `{` with no `}` after it starts a bare word.
///
/// One pass, not a pattern: tried as a `{…}` at every `{`, a line of `{ { {`
/// with no `}` is scanned to its end from each of them.
List<String> _words(String command) {
  final words = <String>[];
  final lastClose = command.lastIndexOf('}');
  var i = 0;
  while (i < command.length) {
    if (_isSpace(command.codeUnitAt(i))) {
      i++;
      continue;
    }
    if (command.codeUnitAt(i) == 0x7b && i < lastClose) {
      final close = command.indexOf('}', i + 1);
      words.add(command.substring(i + 1, close));
      i = close + 1;
      continue;
    }
    final start = i;
    while (i < command.length && !_isSpace(command.codeUnitAt(i))) {
      i++;
    }
    words.add(command.substring(start, i));
  }
  return words;
}

/// Whitespace as `\s` reads it, which is what a command's words are split on.
bool _isSpace(int unit) =>
    (unit >= 0x09 && unit <= 0x0d) ||
    unit == 0x20 ||
    unit == 0xa0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200a) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202f ||
    unit == 0x205f ||
    unit == 0x3000 ||
    unit == 0xfeff;

class HrdServerConnection implements CatServerConnection {
  final CatServerRig rig;
  final CatServerSend send;
  final CatServerHangUp hangUp;

  HrdServerConnection(this.rig, {required this.send, required this.hangUp}) : _ptt = CatServerPtt(rig);

  final CatServerPtt _ptt;

  final _buffer = BytesBuilder();

  /// Decided by the client's first bytes and kept for the connection.
  bool? _framed;

  /// Takes every whole command in what has arrived, and keeps the rest once,
  /// at the end: kept after each command instead, a read of many short lines
  /// is copied once per line.
  @override
  void receive(Uint8List bytes) {
    _buffer.add(bytes);
    final pending = _buffer.takeBytes();
    var offset = 0;
    try {
      while (offset < pending.length) {
        final rest = Uint8List.sublistView(pending, offset);
        _framed ??= rest.length >= 8 ? startsWithHrdFrame(rest) : (rest.contains(0x0a) ? false : null);
        final framed = _framed;
        if (framed == null) return;
        final ({int consumed, String command})? taken;
        try {
          taken = framed ? _takeFrame(rest) : _takeLine(rest);
        } on FormatException {
          offset = pending.length;
          hangUp();
          return;
        }
        if (taken == null) return;
        offset += taken.consumed;
        if (taken.command.isEmpty) continue;
        final reply = respond(taken.command);
        send(framed ? encodeHrdFrame(reply) : utf8.encode('$reply\n'));
      }
    } finally {
      _buffer.add(Uint8List.sublistView(pending, offset));
    }
  }

  @override
  void close() => _ptt.drop();

  static ({int consumed, String command})? _takeFrame(Uint8List pending) {
    final frame = takeHrdFrame(pending, maxLength: catServerMaxPending);
    return frame == null ? null : (consumed: frame.consumed, command: frame.text);
  }

  bool _firstLine = true;

  ({int consumed, String command})? _takeLine(Uint8List pending) {
    final end = pending.indexOf(0x0a);
    if (end < 0) {
      if (pending.length > catServerMaxPending) throw const FormatException('HRD line too long');
      return null;
    }
    final command = utf8.decode(pending.sublist(0, end), allowMalformed: true).trim();
    if (_firstLine && isBrowserRequestLine(command)) throw const FormatException('an HTTP request, not an HRD client');
    _firstLine = false;
    return (consumed: end + 1, command: command);
  }

  /// The reply text for one command.
  String respond(String raw) {
    final command = raw.replaceFirst(_contextPrefix, '').trim();
    final words = _words(command);
    if (words.isEmpty) return 'ERROR: unknown command';
    final verb = words.first.toLowerCase();
    final what = words.length > 1 ? words[1].toLowerCase() : '';
    final args = words.length > 2 ? words.sublist(2) : const <String>[];

    if (verb == 'get') {
      switch (what) {
        case 'id':
          return 'Ham2K Logger';
        case 'version':
          return 'v6.0';
        case 'context':
          return '1';
        case 'radio':
          return 'HaLo';
        case 'radios':
          return '1:HaLo';
        case 'dropdowns':
          return 'Mode';
        case 'dropdown-list':
          return _isModeDropdown(args) ? hrdModesByAppMode.values.join(',') : '';
        case 'buttons':
          return 'TX';
        case 'button-select':
          return args.isNotEmpty && _name(args.first) == 'TX' ? (rig.transmitting ? '1' : '0') : '0';
        case 'sliders':
          return '';
      }
    } else if (verb == 'set' && what == 'button-select') {
      // `set button-select TX 1`: PTT. No other button is offered.
      if (args.length < 2 || _name(args.first) != 'TX') return 'ERROR: unknown button';
      final ptt = int.tryParse(args[1]);
      if (ptt == null) return 'ERROR: invalid value';
      return _ptt.set(ptt != 0) ? 'OK' : 'ERROR: not allowed';
    }

    if (!rig.available) return 'ERROR: no radio';

    if (verb == 'get') {
      switch (what) {
        case 'frequency':
          final freq = rig.freqKHz;
          return freq == null ? 'ERROR: no frequency' : (freq * 1000).round().toString();
        case 'frequencies':
          final freq = rig.freqKHz;
          if (freq == null) return 'ERROR: no frequency';
          final hz = (freq * 1000).round();
          return '$hz-$hz';
        case 'dropdown-text':
          if (!_isModeDropdown(args)) return '';
          final mode = _hrdMode();
          return mode == null ? 'ERROR: no mode' : '${_name(args.first)}: $mode';
      }
    } else if (verb == 'set') {
      switch (what) {
        case 'frequency-hz' || 'frequencies-hz':
          final hz = args.isEmpty ? null : double.tryParse(args.first);
          if (hz == null || !isTunableFrequencyKHz(hz / 1000)) return 'ERROR: invalid frequency';
          rig.tune(freqKHz: hz / 1000);
          return 'OK';
        case 'dropdown':
          // `set dropdown Mode USB 1`: the name, the item, the item's index.
          if (args.length < 2 || !_isModeDropdown(args.sublist(0, 1))) return 'ERROR: unknown dropdown';
          final mode = tunableAppMode(appModeForHrdMode(args[1]));
          if (mode == null) return 'ERROR: unknown mode';
          rig.tune(mode: mode);
          return 'OK';
      }
    }
    return 'ERROR: unknown command';
  }

  String? _hrdMode() {
    final mode = radioModeForAppMode(rig.mode, rig.freqKHz);
    if (mode == null) return null;
    return hrdModesByAppMode[mode] ?? mode;
  }

  /// Whether [args] start with the mode dropdown's name, which radios call
  /// `Mode`, `Main Mode` or `Mode A`.
  static bool _isModeDropdown(List<String> args) => args.isNotEmpty && _name(args.first).toLowerCase().contains('mode');

  static String _name(String raw) => raw.replaceAll('~', ' ').trim();
}
