// Copyright ©️ 2026 Ham2K
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import '../cat/cat_service.dart';
import '../cat/driver.dart';
import 'cw_paddle_input.dart';
import 'cw_sidetone.dart';
import 'midi_backend.dart';

/// One explicitly selected paddle device. Keeps a burst on the same radio
/// session and aborts before switching, even when the station's radio changes.
class LiveMidiCw {
  LiveMidiCw({required this.cat, required this.profile, required this.send, required this.nowMicros, required this.onIdle, required this.iambicB}) {
    _input = CwPaddleInput(profile: profile, onEdge: _edge, nowMicros: nowMicros, iambicB: iambicB);
    _sidetone?.prepare();
  }

  static const _pitchHz = 600;
  static const _tail = Duration(milliseconds: 1250);
  static const _markLimit = Duration(milliseconds: 2300);
  static const _paddleHoldLimit = Duration(seconds: 10);
  static const _vailQuietMicros = 500000;

  final CatService cat;
  final CwPaddleProfile profile;
  final void Function(List<int>) send;
  final int Function() nowMicros;
  final void Function() onIdle;
  bool iambicB;

  late final CwPaddleInput _input;
  late final _sidetone = profile == CwPaddleProfile.vail ? null : CwSidetone();
  LiveCwSession? _session;
  Timer? _timeout;
  Timer? _paddleHold;
  int? _lastVailActivity;
  int? _clockOffset;
  List<List<int>>? _vailSetup;
  bool _vailMidiEnabled = false;
  bool _closed = false;

  void sync() {
    final radio = cat.localRadio1;
    if (_session != null && !identical(cat.liveCwSessionFor(radio), _session)) stop();
    if (_input.held || _session != null) return;

    final wpm = radio == null ? 20 : cat.stateFor(radio).keyerSpeed ?? 20;
    _input.configure(wpm: wpm, iambicB: iambicB);
    if (profile != CwPaddleProfile.vail) return;

    final config = vailCwSetup(wpm: wpm, iambicB: iambicB, pitchHz: _pitchHz);
    final previous = _vailSetup;
    for (var i = 0; i < config.length; i++) {
      // Speed and keyer type write to the adapter's EEPROM. Touch only
      // changed values, and only after the current element is up.
      if (previous == null || config[i].last != previous[i].last) {
        send(config[i]);
        if (i == 0) _vailMidiEnabled = true;
      }
    }
    _vailSetup = config;
  }

  void accept(MidiInputPacket packet) {
    if (_closed || (profile == CwPaddleProfile.vail && _vailSetup == null)) return;
    final arrival = nowMicros();
    if (_lastVailActivity case final last?) {
      if (arrival - last < _vailQuietMicros) {
        _lastVailActivity = arrival;
        return;
      }
      _lastVailActivity = null;
    }

    // Preserve intervals from the MIDI callback while expressing them
    // on the same monotonic clock as the software keyer's timers.
    final stamp = packet.atMicros;
    var captured = arrival;
    if (stamp != null) {
      final offset = _clockOffset ??= arrival - stamp;
      if (stamp + offset < arrival) captured = stamp + offset;
    }
    _input.accept(packet.data, captured);
    if (_input.paddleDown && _session != null) {
      // A missing raw paddle-up can repeat valid marks indefinitely with
      // normal key-up gaps, so the radio's per-mark timer cannot catch it.
      _paddleHold ??= Timer(_paddleHoldLimit, stop);
    } else {
      _paddleHold?.cancel();
      _paddleHold = null;
    }
  }

  void _edge(bool down, int atMicros) {
    final radio = cat.localRadio1;
    if (down && nowMicros() - atMicros > 250000) {
      stop();
      return;
    }
    if (_session == null) {
      if (!down) return;
      if (radio == null) {
        _suspendInput();
        return;
      }
      final session = cat.liveCwSessionFor(radio);
      if (session == null || !cat.beginLiveCw(uuid: radio, session: session, owner: this, stop: stop)) {
        _suspendInput();
        return;
      }
      _session = session;
    }

    final session = _session!;
    if (!identical(cat.liveCwSessionFor(radio), session) || !session.sendLiveCwEdge(down: down, atMicros: atMicros)) {
      stop();
      return;
    }
    _sidetone?.setKeyDown(down, pitchHz: _pitchHz);
    _timeout?.cancel();
    // Retain ownership through the K4's playout buffer so Escape and other
    // transmit actions can still stop a mark just after the key comes up.
    _timeout = down
        ? Timer(_markLimit, stop)
        : Timer(_tail, () {
            _finish();
            onIdle();
          });
  }

  void _finish() {
    _timeout?.cancel();
    _timeout = null;
    _session = null;
    cat.finishLiveCw(this);
  }

  void _suspendInput() {
    if (profile == CwPaddleProfile.vail) {
      // Vail sends elements, so a held lever can make another note after an
      // abort. Require a gap in its stream before accepting a fresh burst.
      _input.reset();
      _lastVailActivity = nowMicros();
    } else {
      _input.suspend();
    }
  }

  void stop() {
    try {
      _session?.stopLiveCw();
    } finally {
      _finish();
      _paddleHold?.cancel();
      _paddleHold = null;
      _sidetone?.setKeyDown(false, pitchHz: _pitchHz);
      _suspendInput();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      stop();
    } finally {
      _input.reset();
      _sidetone?.close();
      if (_vailMidiEnabled) {
        _vailMidiEnabled = false;
        send([0xB0, 0, 0x7F]); // Restore the adapter's default keyboard mode.
      }
    }
  }
}
