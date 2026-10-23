// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis;

import '../spectrum.dart';
import '../spectrum_fft.dart';

/// Presents the KX3's stereo RX I/Q audio using the CAT dial as its reference.
/// Levels use the FFT's relative scale; sound-card gain is not calibrated.
/// The caller owns audio capture, CAT, and connection problems.
class Kx3IqPresenter {
  final int sampleRate;

  /// Added to the CAT dial to locate the FFT center. A positive offset moves
  /// every displayed frequency up; it does not retune the radio.
  final int offsetHz;
  final bool swapIq;
  final SpectrumSink? sink;

  Kx3IqPresenter({required this.sampleRate, this.offsetHz = 0, this.swapIq = false, this.sink}) : assert(sampleRate >= 2);

  static const _spans = [1000, 2500, 5000, 10000, 20000, 40000, 80000];
  static const _sweepsPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

  bool _wanted = false;
  int _epoch = 0;
  int? _frequencyHz;
  IqSpectrum? _fft;
  int _framePosition = 0;
  Uint8List _pending = Uint8List(0);
  final _noise = NoiseFloor();
  late int _spanHz = capabilities.snapSpan(10000);
  double _refLevelDb = 0;
  SpectrumSpeed _speed = SpectrumSpeed.mid;
  SpectrumSettings? _reportedSettings;

  SpectrumCapabilities get capabilities {
    final maximum = sampleRate ~/ 2;
    return SpectrumCapabilities(
      spansHz: [
        for (final span in _spans)
          if (span < maximum) span,
        maximum,
      ],
      refMinDb: -30,
      refMaxDb: 30,
      refStepDb: 1,
      speeds: const {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
    );
  }

  void start() {
    if (_wanted) return;
    _wanted = true;
    _reportSettings(force: true);
  }

  /// The CAT connection outlives a display, so its last dial survives stop.
  void stop() {
    _wanted = false;
    _framePosition = 0;
    _discardSamples();
  }

  /// A replacement CAT connection must report its own dial before publishing.
  void reset() {
    _frequencyHz = null;
    _discardSamples();
  }

  void updateFrequency(int? hz) {
    final frequency = hz != null && hz > 0 && hz + offsetHz >= 0 ? hz : null;
    if (frequency == _frequencyHz) return;
    _frequencyHz = frequency;
    // A partial PCM pair or FFT from the old dial cannot be labelled at the
    // new one: doing so smears carriers across the waterfall during tuning.
    _discardSamples();
  }

  bool set(SpectrumRequest request) {
    if (!_wanted || request.centerHz != null || (request.mode != null && request.mode != SpectrumMode.center)) return false;
    if (request.refLevelDb case final ref? when !ref.isFinite) return false;
    if (request.spanHz case final span? when span <= 0) return false;
    if (request.spanHz case final span?) _spanHz = capabilities.snapSpan(span);
    if (request.refLevelDb case final ref?) _refLevelDb = capabilities.snapRef(ref);
    if (request.speed case final speed?) {
      _speed = speed;
      _fft?.hop = _hop;
    }
    _reportSettings();
    return true;
  }

  /// Stereo little-endian PCM16, with I in the first channel unless [swapIq].
  /// Audio callbacks may split anywhere, including inside either 16-bit word.
  void add(Uint8List pcm) {
    if (!_wanted || pcm.isEmpty) return;
    final position = _framePosition;
    _framePosition = (_framePosition + pcm.length) % 4;
    if (_frequencyHz == null) return;
    // Retuning discards a partial sample's values, but the audio stream
    // continues inside that same four-byte stereo frame. Keep its position
    // even while waiting for CAT, and resume only at the next whole frame.
    final skip = _pending.isEmpty && position != 0 ? 4 - position : 0;
    if (skip >= pcm.length) return;
    final incoming = Uint8List.sublistView(pcm, skip);
    final epoch = _epoch;
    final bytes = _pending.isEmpty
        ? incoming
        : (Uint8List(_pending.length + incoming.length)
            ..setAll(0, _pending)
            ..setAll(_pending.length, incoming));
    final complete = bytes.length - bytes.length % 4;
    _pending = Uint8List.fromList(bytes.sublist(complete));
    if (complete == 0) return;
    final data = ByteData.sublistView(bytes);
    final samples = Float32List(complete ~/ 2);
    for (var at = 0; at < complete; at += 4) {
      final left = data.getInt16(at, Endian.little) / 32768;
      final right = data.getInt16(at + 2, Endian.little) / 32768;
      samples[at ~/ 2] = swapIq ? right : left;
      samples[at ~/ 2 + 1] = swapIq ? left : right;
    }
    final fft = _fft ??= IqSpectrum(hop: _hop);
    fft.add(samples, (levels) {
      // A sink callback can stop capture or retune while a chunk contains
      // several sweeps; none of its remaining samples belong to that source.
      if (_wanted && epoch == _epoch) _emit(levels);
    });
  }

  int get _hop => math.max(1, sampleRate ~/ _sweepsPerSecond[_speed]!);

  void _discardSamples() {
    _epoch++;
    _pending = Uint8List(0);
    _fft = null;
    _noise.reset();
  }

  void _emit(Float32List levels) {
    final mid = levels.length ~/ 2;
    // Zero-IF audio often carries a DC spike at the dial marker.
    levels[mid] = (levels[mid - 1] + levels[mid + 1]) / 2;
    final radius = math.max(1, (_spanHz * levels.length / sampleRate).floor());
    final first = math.max(0, mid - radius);
    final end = math.min(levels.length, mid + radius + 1);
    final shown = Float32List.sublistView(levels, first, end);
    final range = _noise.update(shown, refLevelDb: _refLevelDb);
    if (range == null) return;
    final center = _frequencyHz! + offsetHz;
    // Endpoints name retained bins, so cropping cannot shift a carrier's
    // displayed frequency by stretching bins to the requested window edges.
    int frequency(int bin) => (center + (bin - mid) * sampleRate / levels.length).round();
    sink?.reportSpectrum(
      SpectrumFrame(lowHz: frequency(first), highHz: frequency(end - 1), levels: shown, floorDb: range.floor, ceilingDb: range.ceiling, atMillis: nowMillis()),
    );
  }

  void _reportSettings({bool force = false}) {
    final settings = SpectrumSettings(spanHz: _spanHz, refLevelDb: _refLevelDb, speed: _speed);
    if (!force && settings == _reportedSettings) return;
    _reportedSettings = settings;
    sink?.reportSpectrumSettings(settings);
  }
}
