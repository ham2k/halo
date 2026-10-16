// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Answers as Hamlib's `rigctld` does, so any program that can drive a
// "Hamlib NET rigctl" radio (WSJT-X, JS8Call, fldigi, GridTracker, Log4OM…)
// drives the Main VFO radio instead.
//
// The replies are pinned against a real rigctld (Hamlib 4.7, `-m 1`), and the
// command set against what Hamlib's own NET client sends while opening and
// polling a radio: `\get_powerstat`, `\chk_vfo`, `\dump_state`, `v`,
// `l KEYSPD`, then `f`, `m`, `F`, `M`, `t`, `\get_lock_mode`. A client
// that gets no answer to any line waits for its timeout, so every line gets
// one — an error code where there is nothing to say.
//
// Two response forms, chosen per command by its first character:
//   - plain: the bare values one per line; a set answers `RPRT 0`.
//   - extended (`+`, `;`, `|` or `,` first): `<long name>: <args>`, then
//     `Label: value` lines, then `RPRT n`, joined by `\n` for `+` and by the
//     character itself otherwise. HaLo's own rigctld driver reads this form.
//     A level is the exception: its value is bare (`get_level: KEYSPD`, `0`),
//     the header line being all that names it.
//
// `\chk_vfo` answers 0: commands carry no VFO argument, whatever the client
// could send, because there is one VFO to address.

import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';

import '../cat/drivers/line_framer.dart';
import '../cat/drivers/rigctld_driver.dart';
import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';

// Hamlib's error codes, as rigctld prints them.
const _ok = 0;
const _invalidParameter = -1;
const _ioError = -6;
const _notAvailable = -11;

/// The Hamlib modes the emulated radio claims, as `rig.h` numbers them: AM,
/// CW, USB, LSB, RTTY, FM, WFM, CWR, RTTYR, PKTLSB, PKTUSB, PKTFM, FMN and
/// AMN. Hamlib's client refuses to set a mode missing from this mask, so a
/// narrower one would stop WSJT-X from selecting its data mode.
const _modeMask = '0x20201dff';

/// The `\dump_state` answer Hamlib's NET client reads on open to learn what
/// the radio can do. Everything after the fixed-position numeric block is
/// `key=value`, and `done` ends it.
///
/// It claims nothing HaLo cannot answer: one VFO, no levels, functions or
/// parameters, and `ptt_type=0` so a client does not offer CAT PTT.
const _dumpState = [
  '1', // protocol version
  '2', // rig model: Hamlib's NET rigctl
  '0', // ITU region
  '100000.000000 1300000000.000000 $_modeMask -1 -1 0x3 0x1', // rx range
  '0 0 0 0 0 0 0',
  '100000.000000 1300000000.000000 $_modeMask 1000 100000 0x3 0x1', // tx range
  '0 0 0 0 0 0 0',
  '$_modeMask 1', // tuning steps
  '0 0',
  '$_modeMask 0', // filters
  '0 0',
  '0', // max RIT
  '0', // max XIT
  '0', // max IF shift
  '0', // announces
  '0 ', // preamps
  '0 ', // attenuators
  '0x0', // has_get_func
  '0x0', // has_set_func
  '0x0', // has_get_level
  '0x0', // has_set_level
  '0x0', // has_get_parm
  '0x0', // has_set_parm
  'vfo_ops=0x0',
  'ptt_type=0x0',
  'targetable_vfo=0x0',
  'has_set_vfo=1',
  'has_get_vfo=1',
  'has_set_freq=1',
  'has_get_freq=1',
  'has_set_conf=0',
  'has_get_conf=0',
  'has_power2mW=0',
  'has_mW2power=0',
  'timeout=0',
  'rig_model=2',
  'done',
];

/// Long names for the single-character commands a client can send, so both
/// spellings reach one handler.
const _longNames = {
  'f': 'get_freq',
  'F': 'set_freq',
  'm': 'get_mode',
  'M': 'set_mode',
  'v': 'get_vfo',
  'V': 'set_vfo',
  't': 'get_ptt',
  'T': 'set_ptt',
  's': 'get_split_vfo',
  'S': 'set_split_vfo',
  'i': 'get_split_freq',
  'I': 'set_split_freq',
  'x': 'get_split_mode',
  'X': 'set_split_mode',
  'l': 'get_level',
  'L': 'set_level',
  'u': 'get_func',
  'U': 'set_func',
  'j': 'get_rit',
  'J': 'set_rit',
  'z': 'get_xit',
  'Z': 'set_xit',
  '_': 'get_info',
  '1': 'dump_caps',
  'q': 'quit',
  'Q': 'quit',
};

/// The passband a client is told for [hamlibMode], in Hz. HaLo does not
/// track filter widths, and a zero here reads to some clients as "no filter".
int _passbandHz(String hamlibMode) => switch (hamlibMode) {
  'CW' || 'CWR' => 500,
  'AM' || 'AMN' || 'AMS' => 6000,
  'FM' || 'FMN' || 'PKTFM' || 'WFM' => 15000,
  _ => 3000,
};

class RigctldServerConnection implements CatServerConnection {
  final CatServerRig rig;
  final CatServerSend send;

  final CatServerHangUp hangUp;

  /// The client sent `q`: its earlier replies are still owed to it.
  final void Function() quit;

  RigctldServerConnection(this.rig, {required this.send, required this.hangUp, required this.quit});

  final _framer = LineFramer();

  /// Bytes received since the last line end, which [LineFramer] holds.
  var _unterminated = 0;

  bool _firstLine = true;

  @override
  void receive(Uint8List bytes) {
    final lastLineEnd = bytes.lastIndexOf(0x0a);
    _unterminated = lastLineEnd < 0 ? _unterminated + bytes.length : bytes.length - lastLineEnd - 1;
    if (_unterminated > catServerMaxPending) {
      hangUp();
      return;
    }
    for (final line in _framer.add(bytes)) {
      if (_firstLine && isHttpRequestLine(line)) {
        hangUp();
        return;
      }
      _firstLine = false;
      final reply = respond(line);
      if (reply == null) {
        quit();
        return;
      }
      if (reply.isNotEmpty) send(utf8.encode(reply));
    }
  }

  @override
  void close() {}

  /// The reply to one command line, or null when the client asked to quit.
  String? respond(String line) {
    var text = line.trim();
    if (text.isEmpty) return '';

    String? separator;
    if ('+;|,'.contains(text[0])) {
      separator = text[0] == '+' ? '\n' : text[0];
      text = text.substring(1).trimLeft();
      if (text.isEmpty) return '';
    }

    final String name;
    final List<String> args;
    if (text.startsWith(r'\')) {
      final parts = text.substring(1).split(RegExp(r'\s+'));
      name = parts.first;
      args = parts.sublist(1);
    } else {
      final short = text[0];
      name = _longNames[short] ?? short;
      args = text.substring(1).trim().split(RegExp(r'\s+')).where((a) => a.isNotEmpty).toList();
    }

    if (name == 'quit') return null;
    final result = _handle(name, args);
    return _format(name, args, result, separator);
  }

  _Result _handle(String name, List<String> args) {
    switch (name) {
      case 'dump_state':
        return const _Result.raw(_dumpState);
      case 'chk_vfo':
        return const _Result([('ChkVFO', '0')], plainOnly: true);
      case 'get_powerstat':
        return _Result([('Power Status', rig.available ? '1' : '0')]);
      case 'set_powerstat':
        return const _Result.status(_ok);
      case 'get_lock_mode':
        // A real rigctld follows the plain value with an RPRT line, and
        // Hamlib's client reads both; answering the value alone leaves it
        // reading the NEXT command's reply as this one's status.
        return const _Result([('Locked', '0')], plainStatus: true);
      case 'set_lock_mode':
        return const _Result.status(_ok);
      case 'get_vfo':
        return const _Result([('VFO', 'VFOA')]);
      case 'set_vfo':
        return const _Result.status(_ok);
      case 'get_split_vfo':
        return const _Result([('Split', '0'), ('TX VFO', 'VFOA')]);
      case 'set_split_vfo':
        // Split is not something HaLo can do, so only turning it off agrees.
        return _Result.status(args.isNotEmpty && args.first == '0' ? _ok : _notAvailable);
      case 'get_ptt':
        return _Result([('PTT', rig.transmitting ? '1' : '0')]);
      case 'set_ptt':
        return const _Result.status(_notAvailable);
      case 'get_level':
        // Asked for on open; any other level is one HaLo does not know.
        if (args.isNotEmpty && args.first.toUpperCase() == 'KEYSPD') return const _Result([('Level Value', '0')], bare: true);
        return const _Result.status(_notAvailable);
    }

    if (!rig.available) return const _Result.status(_ioError);

    switch (name) {
      case 'get_freq':
        final freq = rig.freqKHz;
        if (freq == null) return const _Result.status(_ioError);
        return _Result([('Frequency', (freq * 1000).round().toString())]);
      case 'set_freq':
        final hz = args.isEmpty ? null : double.tryParse(args.first);
        if (hz == null || !isTunableFrequencyKHz(hz / 1000)) return const _Result.status(_invalidParameter);
        rig.tune(freqKHz: hz / 1000);
        return const _Result.status(_ok);
      case 'get_mode':
        final mode = hamlibModeForAppMode(radioModeForAppMode(rig.mode, rig.freqKHz));
        if (mode == null) return const _Result.status(_ioError);
        return _Result([('Mode', mode), ('Passband', _passbandHz(mode).toString())]);
      case 'set_mode':
        final mode = args.isEmpty ? null : tunableAppMode(appModeForHamlibMode(args.first));
        if (mode == null) return const _Result.status(_invalidParameter);
        // A passband is accepted and ignored: HaLo does not set filters.
        rig.tune(mode: mode);
        return const _Result.status(_ok);
      case 'get_vfo_info':
        final freq = rig.freqKHz;
        final mode = hamlibModeForAppMode(radioModeForAppMode(rig.mode, freq));
        if (freq == null || mode == null) return const _Result.status(_ioError);
        return _Result([('Freq', (freq * 1000).round().toString()), ('Mode', mode), ('Width', _passbandHz(mode).toString()), ('Split', '0'), ('SatMode', '0')]);
    }
    return const _Result.status(_notAvailable);
  }

  String _format(String name, List<String> args, _Result result, String? separator) {
    final header = args.isEmpty ? '$name:' : '$name: ${args.join(' ')}';
    if (result.raw != null) {
      final body = result.raw!.join('\n');
      // Extended, the block keeps its own newlines whatever the separator:
      // only the header is joined by it (`dump_state:;1\n1\n…\nRPRT 0`).
      return separator == null ? '$body\n' : '$header$separator$body\nRPRT ${result.status}\n';
    }
    if (separator == null || result.plainOnly) {
      if (result.values.isEmpty) return 'RPRT ${result.status}\n';
      final values = result.plainOnly && separator != null ? result.values.map((v) => '${v.$1}: ${v.$2}') : result.values.map((v) => v.$2);
      return [...values, if (result.plainStatus) 'RPRT ${result.status}'].map((l) => '$l\n').join();
    }
    return '${[header, for (final v in result.values) result.bare ? v.$2 : '${v.$1}: ${v.$2}', 'RPRT ${result.status}'].join(separator)}\n';
  }
}

class _Result {
  /// `Label: value` pairs; the plain form prints only the values.
  final List<(String, String)> values;
  final int status;

  /// Lines answered verbatim — bare in the plain form, and inside the header
  /// and status in the extended one.
  final List<String>? raw;

  /// A reply with no extended form: `\chk_vfo` answers `ChkVFO: 0` alone
  /// when asked with `+`, and a bare value otherwise.
  final bool plainOnly;

  /// Whether the plain form still ends in `RPRT n`.
  final bool plainStatus;

  /// Whether the extended form prints the values unlabeled too — a level's
  /// (`get_level: KEYSPD`, then `0`). A client reading Hamlib's form takes
  /// the line after the header as the number; a label there is not one.
  final bool bare;

  const _Result(this.values, {this.plainOnly = false, this.plainStatus = false, this.bare = false}) : status = _ok, raw = null;

  const _Result.status(this.status) : values = const [], raw = null, plainOnly = false, plainStatus = false, bare = false;

  const _Result.raw(this.raw) : values = const [], status = _ok, plainOnly = false, plainStatus = false, bare = false;
}
