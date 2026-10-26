// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Answers the band, mode and frequency half of the N3FJP logging programs'
// TCP API (https://www.n3fjp.com/help/api.html), for the programs that
// follow a radio through N3FJP — GridTracker's N3FJP integration first.
//
// The message format and the mode tables are the driver's too
// (n3fjp_codec.dart).
//
// N3FJP speaks first when the radio moves: a `READBMFRESPONSE` goes to every
// client whenever band, mode or frequency changes, and a client following the
// radio relies on it rather than polling. So does this, from the moment a
// client connects.
//
// The API's logging commands (UPDATE, ACTION, ADDADIFRECORD, …) are out of
// scope: HaLo's log is not N3FJP's, and a client told a contact was entered
// would be wrong. They answer `CMD_NOT_FOUND`, as N3FJP does for a command
// it does not know. PTT (`RIGTX`/`RIGRX`) has no reply in the API, so one
// that may not key is ignored.

import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';

import '../cat/drivers/n3fjp_codec.dart';
import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';

class N3fjpServerConnection implements CatServerConnection {
  final CatServerRig rig;
  final CatServerSend send;
  final CatServerHangUp hangUp;

  N3fjpServerConnection(this.rig, {required this.send, required this.hangUp}) : _ptt = CatServerPtt(rig) {
    rig.changes.addListener(_onRigChanged);
  }

  final CatServerPtt _ptt;

  var _pending = '';

  /// The last band/mode/frequency report sent, so a change notification that
  /// changed nothing a client sees sends nothing.
  String? _lastReport;

  /// Whether the connection's first line has been seen and is not a web
  /// page's request — decided at the first line end or command end.
  bool _vetted = false;

  @override
  void receive(Uint8List bytes) {
    _pending += utf8.decode(bytes, allowMalformed: true);
    if (!_vetted) {
      final lineEnd = _pending.indexOf('\n');
      final commandEnd = n3fjpCommandEnd.firstMatch(_pending)?.end ?? -1;
      final firstEnd = [lineEnd, commandEnd].where((i) => i >= 0).fold<int?>(null, (a, b) => a == null || b < a ? b : a);
      if (firstEnd != null) {
        if (isHttpRequestLine(_pending.substring(0, firstEnd))) {
          hangUp();
          return;
        }
        _vetted = true;
      }
    }
    while (_vetted) {
      final end = n3fjpCommandEnd.firstMatch(_pending);
      if (end == null) break;
      final message = _pending.substring(0, end.end);
      _pending = _pending.substring(end.end);
      final match = n3fjpCommand.firstMatch(message);
      if (match == null) continue;
      // A tune notifies at once; its report waits until the command's own
      // reply is out, which is the order a client reading replies expects.
      _handling = true;
      final String? reply;
      try {
        reply = respond(match.group(1)!.toUpperCase(), match.group(2)!);
      } finally {
        _handling = false;
      }
      if (reply != null) send(utf8.encode(reply));
      if (_changedWhileHandling) {
        _changedWhileHandling = false;
        _onRigChanged();
      }
    }
    if (_pending.length > catServerMaxPending) hangUp();
  }

  @override
  void close() {
    rig.changes.removeListener(_onRigChanged);
    _ptt.drop();
  }

  bool _handling = false;
  bool _changedWhileHandling = false;

  void _onRigChanged() {
    if (_handling) {
      _changedWhileHandling = true;
      return;
    }
    final report = _bandModeFreq();
    if (report == null || report == _lastReport) return;
    _lastReport = report;
    send(utf8.encode(report));
  }

  /// The reply to one command, or null when it has none.
  String? respond(String name, String body) {
    switch (name) {
      case 'PROGRAM':
        return n3fjpMessage('<PROGRAMRESPONSE><PGM>Ham2K Logger</PGM><VER>1.0</VER><APIVER>2.2</APIVER>');
      case 'APIVER':
        return n3fjpMessage('<APIVERRESPONSE><APIVER>2.2</APIVER>');
      case 'RIGENABLED':
        return n3fjpMessage('<RIGRESPONSE><RIG>${rig.available ? 'HaLo' : 'None'}</RIG>');
      case 'GETRIGPOLLINGRATE':
        return n3fjpMessage('<GETRIGPOLLINGRATERESPONSE><VALUE>500</VALUE>');
      case 'RIGTX' || 'RIGRX':
        _ptt.set(name == 'RIGTX');
        return null;
      case 'READBMF':
        // Answered even with no radio, the way N3FJP answers with none
        // attached: an empty mode and a zero frequency.
        return (_lastReport = _bandModeFreq()) ?? n3fjpMessage('<READBMFRESPONSE><BAND></BAND><MODE></MODE><MODETEST></MODETEST><FREQ>0.000000</FREQ>');
      case 'CHANGEFREQ' || 'CHANGEMODE' || 'CHANGEBM' when !rig.available:
        return null;
      case 'CHANGEFREQ':
        final mhz = double.tryParse(n3fjpTag(body, 'VALUE') ?? '');
        if (mhz == null || !isTunableFrequencyKHz(mhz * 1000)) return null;
        // SUPPRESSMODEDEFAULT asks N3FJP not to pick a mode for the new
        // sub-band. HaLo never picks one on a retune, so there is nothing to
        // suppress.
        rig.tune(freqKHz: mhz * 1000);
        return n3fjpMessage('<CHANGEFREQRESPONSE><VALUE>${n3fjpTag(body, 'VALUE')!.trim()}</VALUE>');
      case 'CHANGEMODE':
        final mode = n3fjpTag(body, 'VALUE')?.trim();
        if (mode != null && mode.isNotEmpty) _tuneMode(mode);
        return null;
      case 'CHANGEBM':
        // N3FJP's own "no rig interface" form. A band alone cannot tune a
        // radio, so only the mode is taken from it.
        final mode = n3fjpTag(body, 'MODE')?.trim();
        if (mode != null && mode.isNotEmpty) _tuneMode(mode);
        return null;
    }
    return n3fjpMessage('<CMD_NOT_FOUND>');
  }

  void _tuneMode(String requested) {
    final mode = tunableAppMode(appModeForN3fjpMode(requested)!);
    if (mode != null) rig.tune(mode: mode);
  }

  /// The current `READBMFRESPONSE`, or null when there is no radio or it has
  /// no frequency.
  String? _bandModeFreq() {
    if (!rig.available) return null;
    final freq = rig.freqKHz;
    if (freq == null) return null;
    final mode = n3fjpModeForRadioMode(radioModeForAppMode(rig.mode, freq));
    final band = bandForFrequency(freq);
    return n3fjpMessage(
      '<READBMFRESPONSE><BAND>${n3fjpBand(band)}</BAND><MODE>$mode</MODE>'
      '<MODETEST>${n3fjpModeTest(mode)}</MODETEST><FREQ>${(freq / 1000).toStringAsFixed(6)}</FREQ>',
    );
  }
}
