// Copyright ©️ 2026 Ham2K
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

enum CwPaddleProfile { vail, haliKey, tinyMidi }

/// Vail boots in keyboard mode. Select MIDI and an onboard keyer before
/// accepting notes 1 and 2, which also carry paddle holds in passthrough mode.
/// https://github.com/Vail-CW/vail-adapter/blob/master/docs/MIDI_INTEGRATION_SPEC.md
List<List<int>> vailCwSetup({required int wpm, required bool iambicB, required int pitchHz}) => [
  [0xB0, 0, 0],
  [0xC0, iambicB ? 8 : 7],
  [0xB0, 1, (600 / wpm.clamp(5, 100)).round()],
  [0xB0, 2, (69 + 12 * math.log(pitchHz.clamp(1, 20000) / 440) / math.ln2).round().clamp(0, 127)],
];

/// Converts a selected adapter's input to a single stream of CW key edges.
/// All times are monotonic microseconds on the caller's capture clock.
class CwPaddleInput {
  CwPaddleInput({required this.profile, required this.onEdge, required this.nowMicros, int wpm = 20, this._iambicB = true}) : _ditMicros = _ditLength(wpm);

  final CwPaddleProfile profile;
  final void Function(bool down, int atMicros) onEdge;
  final int Function() nowMicros;
  final _parser = MidiMessageParser();

  int _ditMicros;
  bool _iambicB;
  final _vailNotes = <int>{};

  // Host-keyed paddles. A bit in memory represents a press that has not yet
  // been sent. Use a snapshot of the dit length through the current mark/gap
  // so changing speed does not stretch half an element.
  static const _dit = 1;
  static const _dah = 2;
  static const _both = _dit | _dah;
  int _levers = 0;
  int _memory = 0;
  int _lastElement = 0;
  bool _squeezed = false;
  bool _markDown = false;
  bool _suspended = false;
  int _elementDitMicros = 0;
  int? _deadline;
  Timer? _timer;

  // MoMIDI v0.0 adds CC to the note velocity. v0.1 sends the high bits as
  // polyphonic aftertouch and uses ordinary MIDI Note On/Off semantics.
  // https://github.com/NetKeyer/MoMIDI-Spec#23-representing-time-in-midi
  // https://github.com/NetKeyer/midimon#momidi-decoding
  bool? _legacyMoMidi;
  ({int channel, int? note, int value})? _timingHigh;
  int? _lastDeviceEdge;

  static int _ditLength(int wpm) => (1200000 / wpm.clamp(5, 100)).round();

  bool get held => _vailNotes.isNotEmpty || _levers != 0 || _deadline != null;

  /// Physical host-keyed paddle state, excluding queued marks and gaps.
  bool get paddleDown => _levers != 0;

  void configure({required int wpm, required bool iambicB}) {
    _ditMicros = _ditLength(wpm);
    _iambicB = iambicB;
  }

  void accept(List<int> bytes, int atMicros) {
    final packet = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    for (final message in _parser.parse(packet)) {
      final data = message.data;
      if (data.length != 3) continue;
      final type = data[0] & 0xF0;
      final channel = data[0] & 0x0F;
      final note = data[1];
      final velocity = data[2];
      if (profile == CwPaddleProfile.haliKey && type == 0xB0 && _legacyMoMidi != false) {
        _legacyMoMidi = true;
        _timingHigh = (channel: channel, note: null, value: velocity);
        continue;
      }
      if (profile == CwPaddleProfile.haliKey && type == 0xA0 && _isCwNote(note)) {
        _legacyMoMidi = false;
        _timingHigh = (channel: channel, note: note, value: velocity);
        continue;
      }
      if (type != 0x80 && type != 0x90) continue;
      final down = type == 0x90 && (velocity != 0 || _legacyMoMidi == true);
      if (profile == CwPaddleProfile.vail) {
        if (channel != 0 || note > 2) continue;
        final wasDown = _vailNotes.isNotEmpty;
        if (down) {
          _vailNotes.add(note);
        } else {
          _vailNotes.remove(note);
        }
        if (_suspended) {
          _suspended = _vailNotes.isNotEmpty;
        } else if (wasDown != _vailNotes.isNotEmpty) {
          onEdge(!wasDown, atMicros);
        }
        continue;
      }

      // HaliKey's timer counts from the last CW message, including straight
      // key and PTT, even when this input uses only the two paddle notes.
      if (!_isCwNote(note)) continue;
      final edgeAt = profile == CwPaddleProfile.haliKey ? _halikeyTime(channel, note, velocity, atMicros) : atMicros;
      if (note == 20 || note == 21) _paddle(note == 20 ? _dit : _dah, down, edgeAt);
    }
  }

  static bool _isCwNote(int note) => note == 20 || note == 21 || note == 30 || note == 31;

  int _halikeyTime(int channel, int note, int velocity, int capturedAt) {
    final high = _timingHigh;
    _timingHigh = null;
    final previous = _lastDeviceEdge;
    if (previous == null || velocity == 0 || velocity == 127) return _lastDeviceEdge = capturedAt;

    final highBits = high != null && high.channel == channel && (high.note == null || high.note == note) ? high.value : 0;
    return _lastDeviceEdge = math.min(capturedAt, previous + (highBits * 126 + velocity) * 1000);
  }

  void _paddle(int lever, bool down, int atMicros) {
    // Give a release exactly on a deadline a say in the next element.
    _advance(atMicros - 1);
    if (_suspended) {
      _levers = down ? _levers | lever : _levers & ~lever;
      _suspended = _levers != 0;
      return;
    }
    final wasDown = _levers & lever != 0;
    if (wasDown != down) {
      if (down) {
        _levers |= lever;
        _memory |= lever;
        if (_levers == _both) _squeezed = true;
        if (_deadline == null) _startElement(lever, atMicros);
      } else {
        _levers &= ~lever;
        if (_levers == 0 && _squeezed) {
          // Mode A ends the squeeze with the current mark. Mode B sends one
          // more mark of the opposite kind, even if both levers are up.
          _memory = _iambicB ? _both ^ _lastElement : 0;
          _squeezed = false;
        }
      }
    }
    _advance(atMicros);
    _schedule();
  }

  void _startElement(int element, int atMicros) {
    _lastElement = element;
    _memory &= ~element;
    _squeezed = _levers == _both;
    _markDown = true;
    _elementDitMicros = _ditMicros;
    _deadline = atMicros + (element == _dit ? _elementDitMicros : 3 * _elementDitMicros);
    onEdge(true, atMicros);
  }

  void _advance(int untilMicros) {
    final due = _deadline;
    if (due == null || due > untilMicros) return;
    if (_markDown) {
      _markDown = false;
      _deadline = due + _elementDitMicros;
      onEdge(false, due);
    }

    final gapEnd = _deadline;
    if (_markDown || gapEnd == null || gapEnd > untilMicros) return;
    _deadline = null;
    final ready = _levers | _memory;
    if (ready == 0) return;
    final next = ready == _both ? _both ^ _lastElement : ready;

    // A stalled event loop may miss a boundary. Re-anchor instead of sending
    // a burst of old elements from time the operator could not hear.
    final startsAt = untilMicros - gapEnd >= _elementDitMicros ? untilMicros : gapEnd;
    _startElement(next, startsAt);
  }

  void _schedule() {
    _timer?.cancel();
    final due = _deadline;
    _timer = due == null
        ? null
        : Timer(Duration(microseconds: math.max(0, due - nowMicros())), () {
            _advance(nowMicros());
            _schedule();
          });
  }

  /// After aborting a stream, wait until the device reports everything up.
  /// The owner releases the radio and sidetone.
  void suspend() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _memory = _lastElement = 0;
    _markDown = _squeezed = false;
    _suspended = _vailNotes.isNotEmpty || _levers != 0;
  }

  /// Drops pending input without emitting edges or carrying device state
  /// across a disconnect.
  void reset() {
    suspend();
    _parser.reset();
    _vailNotes.clear();
    _levers = 0;
    _suspended = false;
    _legacyMoMidi = null;
    _timingHigh = null;
    _lastDeviceEdge = null;
  }
}
