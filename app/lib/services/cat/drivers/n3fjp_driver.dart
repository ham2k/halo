// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Follows and tunes a radio through one of N3FJP's logging programs, over
// its TCP API (n3fjp_codec.dart) — for an operator whose rig is already
// N3FJP's to drive.
//
// Written from N3FJP's published API document and pinned against HaLo's own
// N3FJP emulation; no exchange with a real N3FJP program has been captured.
//
// N3FJP speaks first: a `READBMFRESPONSE` arrives whenever band, mode or
// frequency changes (API 0.8 and later). A `READBMF` poll stays underneath
// it on the AdaptivePoller, which a push defers — so a program that pushes
// is asked almost nothing, and one too old to push is still followed.
//
// The API offers band, mode and frequency and nothing else: no power, no
// PTT state, no meters.
//
// N3FJP answers `READBMF` whether or not a radio is behind it; with none,
// the frequency is whatever was typed into its entry window, and a
// `CHANGEFREQ` goes nowhere. `RIGENABLED` says which, and "None" is reported
// as a problem: the row is connected and answering, and what it follows is
// not a radio. It is asked with every poll, so setting up N3FJP's rig
// interface mid-session clears the problem, and losing it raises one.

import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import 'n3fjp_codec.dart';

class N3fjpDriver extends EquipmentDriver {
  const N3fjpDriver();

  /// N3FJP's default API port.
  static const defaultPort = 1100;

  @override
  String get key => 'n3fjp';

  @override
  String get name => 'N3FJP';

  /// The modes N3FJP's mode field can say, as the app names their radio
  /// form. A sideband, a reverse or a data sideband has no N3FJP spelling
  /// of its own.
  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(['LSB', 'USB', 'CW', 'AM', 'FM', 'RTTY-LSB', 'DATA-USB']);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => N3fjpSession(sink);
}

/// Far past any real message; reached only when the peer is not N3FJP.
const _maxPending = 64 * 1024;

class N3fjpSession implements TransceiverSession {
  final EquipmentSink _sink;

  N3fjpSession(this._sink);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _poll);

  VfoReading? _lastReported;

  var _pending = '';

  Duration get pollInterval => _poller.interval;

  void _send(String inner) => _sink.send(utf8.encode(n3fjpMessage(inner)));

  void _poll() {
    _send('<RIGENABLED>');
    _send('<READBMF>');
  }

  @override
  void handleData(Uint8List chunk) {
    _pending += utf8.decode(chunk, allowMalformed: true);
    while (true) {
      final end = n3fjpCommandEnd.firstMatch(_pending);
      if (end == null) break;
      final message = _pending.substring(0, end.end);
      _pending = _pending.substring(end.end);
      final match = n3fjpCommand.firstMatch(message);
      if (match != null) _handleMessage(match.group(1)!.toUpperCase(), match.group(2)!);
    }
    if (_pending.length > _maxPending) _pending = '';
  }

  void _handleMessage(String name, String body) {
    switch (name) {
      // The API document names what `RIGENABLED` answers, not the tag it
      // answers in; both likely spellings are read.
      case 'RIGRESPONSE' || 'RIGENABLEDRESPONSE':
        final rig = n3fjpTag(body, 'RIG')?.trim() ?? '';
        _sink.reportProblem(rig.isEmpty || rig.toUpperCase() == 'NONE' ? t.settings.station.n3fjpNoRig : null);
      case 'READBMFRESPONSE':
        _poller.noteData();
        final mhz = double.tryParse(n3fjpTag(body, 'FREQ')?.trim() ?? '');
        // N3FJP reports MHz, and 0 with nothing to report.
        final freqKHz = mhz != null && mhz > 0 ? double.parse((mhz * 1000).toStringAsFixed(3)) : null;
        final appMode = appModeForN3fjpMode(n3fjpTag(body, 'MODE'), modeTest: n3fjpTag(body, 'MODETEST'));
        // A log's mode as a radio would state it: `SSB` the sideband the
        // frequency runs, `FT8` the data sideband.
        final mode = radioModeForAppMode(appMode, freqKHz ?? _lastReported?.freqKHz);
        if (freqKHz != null || mode != null) _report(VfoReading(freqKHz: freqKHz, mode: mode));
    }
  }

  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The first reading answers startUpdates' question — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  /// With the mode left alone: without `SUPPRESSMODEDEFAULT`, N3FJP puts
  /// the radio in the mode it thinks the new frequency's sub-band calls for.
  @override
  void setFrequency(double freqKHz) =>
      _send('<CHANGEFREQ><VALUE>${(freqKHz / 1000).toStringAsFixed(6)}</VALUE><SUPPRESSMODEDEFAULT>TRUE</SUPPRESSMODEDEFAULT>');

  @override
  void setMode(String mode) {
    final name = n3fjpModeForRadioMode(mode.toUpperCase());
    if (name.isNotEmpty) _send('<CHANGEMODE><VALUE>$name</VALUE>');
  }

  @override
  void setPower(num watts) {}

  @override
  void startUpdates() {
    _pending = '';
    _poll();
    _poller.start();
  }

  @override
  void stopUpdates() => _poller.stop();

  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() => stopUpdates();
}
