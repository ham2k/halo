// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis, realNowMillis;

import '../spectrum.dart';
import '../spectrum_fft.dart';

/// Presents either K4 spectrum source without changing the radio's own pan.
/// Source lifetimes and connection problems remain the caller's responsibility.
class K4SpectrumPresenter {
  final SpectrumSink? sink;

  K4SpectrumPresenter({required this.sink});

  static const _spans = [1000, 2500, 5000, 10000, 20000, 40000, 80000, 160000];
  static const _sweepIntervalMillis = {SpectrumSpeed.slow: 250, SpectrumSpeed.mid: 125, SpectrumSpeed.fast: 0};

  bool _wanted = false;
  int _epoch = 0;
  final _noise = NoiseFloor();
  int? _lastEmitMillis;
  int? _rate;
  int? _centerHz;
  int? _binCount;

  /// The operator's choice, kept apart from [_spanHz] so a stream that
  /// narrows and widens again gets that choice back rather than the clamp.
  int _requestedSpanHz = 10000;
  int _spanHz = 10000;
  double _refLevelDb = 0;
  SpectrumSpeed _speed = SpectrumSpeed.fast;
  SpectrumSettings? _reportedSettings;

  SpectrumCapabilities get capabilities {
    final maximum = (_rate ?? 20000) ~/ 2;
    return SpectrumCapabilities(
      spansHz: [
        for (final span in _spans)
          if (span < maximum) span,
        maximum,
      ],
      refMinDb: -30,
      refMaxDb: 30,
      refStepDb: 1,
      modes: const {SpectrumMode.fixed},
      speeds: const {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
    );
  }

  void start() {
    if (_wanted) return;
    _wanted = true;
    _reportSettings(force: true);
  }

  void stop() {
    _wanted = false;
    reset();
  }

  /// A new source must supply its own center and noise; local choices survive.
  void reset() {
    _epoch++;
    _noise.reset();
    _lastEmitMillis = null;
    _centerHz = null;
    _binCount = null;
  }

  bool set(SpectrumRequest request) {
    if (!_wanted || request.centerHz != null || (request.mode != null && request.mode != SpectrumMode.fixed)) return false;
    if (request.refLevelDb case final ref? when !ref.isFinite) return false;
    if (request.spanHz case final span? when span <= 0) return false;
    if (request.spanHz case final span?) {
      _requestedSpanHz = span;
      _spanHz = capabilities.snapSpan(span);
    }
    if (request.refLevelDb case final ref?) _refLevelDb = capabilities.snapRef(ref);
    if (request.speed case final speed?) _speed = speed;
    _lastEmitMillis = null;
    _reportSettings();
    return true;
  }

  void add({required int centerHz, required int sampleRateHz, required Float32List levels}) {
    if (!_wanted || centerHz < 0 || sampleRateHz < 2 || levels.length < 2 || levels.any((level) => !level.isFinite)) return;
    final epoch = _epoch;
    final sourceChanged = _rate != sampleRateHz || _binCount != levels.length;
    if (sourceChanged) {
      _rate = sampleRateHz;
      _binCount = levels.length;
      _spanHz = capabilities.snapSpan(_requestedSpanHz);
      _noise.reset();
      _lastEmitMillis = null;
    }
    _centerHz = centerHz;
    _reportSettings(force: sourceChanged);
    if (!_wanted || epoch != _epoch) return;

    // Rendering is paced in real elapsed time; developer time travel changes
    // the frame's displayed timestamp, never the amount of network work.
    final now = realNowMillis();
    if (_lastEmitMillis case final last? when now >= last && now - last < _sweepIntervalMillis[_speed]!) return;
    _lastEmitMillis = now;
    final crop = _crop();
    final shown = Float32List.sublistView(levels, crop.first, crop.end);
    final range = _noise.update(shown, refLevelDb: _refLevelDb);
    if (range == null) return;
    sink?.reportSpectrum(
      SpectrumFrame(lowHz: crop.lowHz, highHz: crop.highHz, levels: shown, floorDb: range.floor, ceilingDb: range.ceiling, atMillis: nowMillis()),
    );
  }

  ({int first, int end, int lowHz, int highHz}) _crop() {
    final rate = _rate!, count = _binCount!;
    final radius = math.max(1, (_spanHz * count / rate).floor());
    final first = math.max(0, count ~/ 2 - radius);
    final end = math.min(count, count ~/ 2 + radius + 1);
    // Each endpoint names a retained bin, not the requested window edge:
    // stretching a subset to the latter would mislabel narrow carriers.
    int frequency(int bin) => (_centerHz! + (bin - count / 2) * rate / count).round();
    return (first: first, end: end, lowHz: frequency(first), highHz: frequency(end - 1));
  }

  void _reportSettings({bool force = false}) {
    final crop = _centerHz == null ? null : _crop();
    final settings = SpectrumSettings(
      mode: SpectrumMode.fixed,
      spanHz: _spanHz,
      lowHz: crop?.lowHz,
      highHz: crop?.highHz,
      refLevelDb: _refLevelDb,
      speed: _speed,
    );
    if (!force && settings == _reportedSettings) return;
    _reportedSettings = settings;
    sink?.reportSpectrumSettings(settings);
  }
}
