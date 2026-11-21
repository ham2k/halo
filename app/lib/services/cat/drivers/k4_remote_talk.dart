// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station's microphone over the K4's secure connection. The shared
// session owns EM and PTT; this helper owns only the microphone and the
// packets between its key and unkey. Every audio packet keys a K4, so it
// sends no lead-in or tail.
// Uses the existing 12 kHz EM1 framing documented in k4-remote.md from
// QK4's protocol implementation; live microphone use awaits hardware tests.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart' show AudioEndpoint, AudioEngine, HaloAudioException;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart' show TalkAudioLink, TalkRoute;
import 'k4_remote_audio.dart' show k4RemoteAudioFrames;
import 'k4_remote_codec.dart';

const _packetInterval = Duration(microseconds: 1000000 * k4RemoteAudioFrames ~/ k4RemoteAudioRate);
const _inputFrames = k4RemoteAudioFrames * AudioEngine.rate ~/ k4RemoteAudioRate;

class K4RemoteTalk {
  K4RemoteTalk({required this.link, required this.send, required this.diagnose, this.problem, this.onAirRefused});

  final TalkAudioLink link;
  final void Function(Uint8List envelope) send;
  final void Function(String what) diagnose;
  final void Function(String? why)? problem;
  final void Function()? onAirRefused;

  AudioEndpoint? _endpoint;
  TalkRoute? _route;
  Timer? _timer;
  bool _stopped = false;
  int _sequence = 0;
  final _resampler = _Downsample();

  bool get ready => _endpoint != null && _route != null;
  bool get active => _timer != null;

  /// Opens the microphone ahead of the key, with its gate shut. A refusal
  /// sends no packets, so the session can leave EM and PTT alone.
  bool prepare() {
    if (_stopped) return false;
    if (ready) return true;
    try {
      final endpoint = _endpoint = link.engine.addPulled(gated: true);
      final route = link.speak(endpoint, why: _why);
      if (route == null) {
        unkey();
        return false;
      }
      if (_stopped || _endpoint != endpoint) {
        route.close();
        return false;
      }
      _route = route;
      problem?.call(null);
      return ready;
    } on HaloAudioException catch (e) {
      _failed('the engine would not open the microphone stream: ${e.message}');
    } on StateError {
      _failed('the audio engine closed before the microphone stream opened');
    }
    return false;
  }

  /// After EM is ready: drops anything captured before this key and
  /// starts a fresh sequence. The first packet waits for 60 ms of
  /// microphone samples rather than sending silence ahead of the voice.
  bool keyed() {
    if (_stopped || !ready) return false;
    if (active) return true;
    try {
      _endpoint!.gate = true;
    } on StateError {
      _failed('the audio engine closed before the microphone stream keyed');
      return false;
    }
    _sequence = 0;
    _resampler.reset();
    _timer = Timer.periodic(_packetInterval, (_) => _pump());
    return true;
  }

  void _pump() {
    final endpoint = _endpoint;
    if (!active || endpoint == null) return;
    try {
      final samples = _resampler.add(endpoint.pull(_inputFrames));
      final stereo = Int16List(samples.length * 2);
      for (var i = 0; i < samples.length; i++) {
        final value = (samples[i].clamp(-1.0, 1.0) * 32767).round();
        stereo[i * 2] = stereo[i * 2 + 1] = value;
      }
      // One packet per tick: after a scheduler pause the engine supplies
      // current microphone audio, never a burst to catch up with the clock.
      send(encodeK4RemoteAudio(sequence: _sequence++, frames: k4RemoteAudioFrames, samples: stereo));
    } on Exception catch (e) {
      _failed('the microphone stream stopped: ${e.runtimeType}');
    } on StateError {
      _failed('the audio engine closed while the microphone stream was keyed');
    }
  }

  void _why(String why) {
    diagnose(why);
    problem?.call(why);
  }

  void _failed(String what) {
    final wasActive = active;
    unkey();
    diagnose(what);
    problem?.call(t.settings.station.audioProblemEngine);
    if (wasActive) onAirRefused?.call();
  }

  /// Stops the stream before EM restoration. No later timer can send
  /// another packet and extend TX. The microphone closes with its route.
  void unkey() {
    _timer?.cancel();
    _timer = null;
    final route = _route;
    _route = null;
    final endpoint = _endpoint;
    _endpoint = null;
    try {
      route?.close();
    } on StateError {
      // The engine closed first: its routes are already gone.
    }
    endpoint?.close();
  }

  /// The facade or connection left. Safe to call repeatedly.
  void stop() {
    _stopped = true;
    unkey();
  }
}

/// A 4:1 low-pass FIR for the engine's 48 kHz microphone and the K4's
/// 12 kHz stream. Filtering before decimation keeps microphone content
/// above 6 kHz from folding into the transmitted voice. Its 63 taps span
/// 1.3 ms and its history carries across packets, but never across keys.
class _Downsample {
  static const _factor = AudioEngine.rate ~/ k4RemoteAudioRate;
  static const _length = 63;
  static final _taps = () {
    const cutoff = 5000 / AudioEngine.rate;
    final taps = Float64List(_length);
    var total = 0.0;
    for (var i = 0; i < _length; i++) {
      final x = i - (_length - 1) / 2;
      final sinc = x == 0 ? 2 * cutoff : math.sin(2 * math.pi * cutoff * x) / (math.pi * x);
      final window = .42 - .5 * math.cos(2 * math.pi * i / (_length - 1)) + .08 * math.cos(4 * math.pi * i / (_length - 1));
      total += taps[i] = sinc * window;
    }
    for (var i = 0; i < _length; i++) {
      taps[i] /= total;
    }
    return taps;
  }();

  final _history = Float64List(_length);
  int _at = 0, _phase = 0;

  void reset() {
    _history.fillRange(0, _length, 0);
    _at = _phase = 0;
  }

  Float32List add(Float32List samples) {
    final output = Float32List(samples.length ~/ _factor);
    var out = 0;
    for (final sample in samples) {
      _history[_at] = sample.isFinite ? sample : 0;
      _at = (_at + 1) % _length;
      if (++_phase != _factor) continue;
      _phase = 0;
      var value = 0.0;
      for (var tap = 0; tap < _length; tap++) {
        value += _taps[tap] * _history[(_at - 1 - tap + _length) % _length];
      }
      output[out++] = value;
    }
    return output;
  }
}
