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

/// One argument: a `{braced name}`, spaces and all, or a bare word.
final _token = RegExp(r'\{([^}]*)\}|(\S+)');

class HrdServerConnection implements CatServerConnection {
  final CatServerRig rig;
  final CatServerSend send;
  final CatServerHangUp hangUp;

  HrdServerConnection(this.rig, {required this.send, required this.hangUp});

  final _buffer = BytesBuilder();

  /// Decided by the client's first bytes and kept for the connection.
  bool? _framed;

  @override
  void receive(Uint8List bytes) {
    _buffer.add(bytes);
    while (true) {
      final pending = _buffer.toBytes();
      if (pending.isEmpty) return;
      _framed ??= pending.length >= 8 ? startsWithHrdFrame(pending) : (pending.contains(0x0a) ? false : null);
      final framed = _framed;
      if (framed == null) return;
      final ({int consumed, String command})? taken;
      try {
        taken = framed ? _takeFrame(pending) : _takeLine(pending);
      } on FormatException {
        hangUp();
        return;
      }
      if (taken == null) return;
      _buffer.clear();
      _buffer.add(pending.sublist(taken.consumed));
      if (taken.command.isEmpty) continue;
      final reply = respond(taken.command);
      send(framed ? encodeHrdFrame(reply) : utf8.encode('$reply\n'));
    }
  }

  @override
  void close() {}

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
    if (_firstLine && isHttpRequestLine(command)) throw const FormatException('an HTTP request, not an HRD client');
    _firstLine = false;
    return (consumed: end + 1, command: command);
  }

  /// The reply text for one command.
  String respond(String raw) {
    final command = raw.replaceFirst(_contextPrefix, '').trim();
    final words = [for (final m in _token.allMatches(command)) m.group(1) ?? m.group(2)!];
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
      // PTT, and HaLo cannot key the radio.
      return 'ERROR: not supported';
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
