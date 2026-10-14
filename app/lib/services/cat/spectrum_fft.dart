// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Turns IQ samples into sweeps, for equipment that streams IQ rather than a
// finished spectrum — a FlexRadio mirrored through DAX IQ, and every SDR.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A windowed FFT over the newest [size] complex samples, emitted every
/// [hop] samples. Not thread-hopping: at 48 kHz and twenty sweeps a second a
/// 2048-point transform is well under a millisecond.
class IqSpectrum {
  final int size;
  int hop;

  final Float64List _re;
  final Float64List _im;
  final Float64List _window;
  final Float64List _ringRe;
  final Float64List _ringIm;
  int _write = 0;
  int _filled = 0;
  int _sinceEmit = 0;
  late final List<int> _bitReversed = _bitReversal(size);

  IqSpectrum({this.size = 2048, required this.hop})
    : assert(size > 0 && size & (size - 1) == 0, 'size must be a power of two'),
      _re = Float64List(size),
      _im = Float64List(size),
      _ringRe = Float64List(size),
      _ringIm = Float64List(size),
      _window = Float64List.fromList([for (var i = 0; i < size; i++) 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1))]);

  /// Interleaved I/Q pairs. Calls [onSweep] with levels in dB, lowest
  /// frequency first, for each sweep these samples complete.
  void add(Float32List interleaved, void Function(Float32List levels) onSweep) {
    for (var i = 0; i + 1 < interleaved.length; i += 2) {
      _ringRe[_write] = interleaved[i];
      _ringIm[_write] = interleaved[i + 1];
      _write = (_write + 1) & (size - 1);
      if (_filled < size) _filled++;
      if (++_sinceEmit >= hop && _filled == size) {
        _sinceEmit = 0;
        onSweep(_transform());
      }
    }
  }

  Float32List _transform() {
    for (var i = 0; i < size; i++) {
      final from = (_write + i) & (size - 1);
      final to = _bitReversed[i];
      _re[to] = _ringRe[from] * _window[i];
      _im[to] = _ringIm[from] * _window[i];
    }
    for (var len = 2; len <= size; len <<= 1) {
      final angle = -2 * math.pi / len;
      final wRe = math.cos(angle), wIm = math.sin(angle);
      for (var start = 0; start < size; start += len) {
        var curRe = 1.0, curIm = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final a = start + k, b = a + len ~/ 2;
          final tRe = _re[b] * curRe - _im[b] * curIm;
          final tIm = _re[b] * curIm + _im[b] * curRe;
          _re[b] = _re[a] - tRe;
          _im[b] = _im[a] - tIm;
          _re[a] += tRe;
          _im[a] += tIm;
          final nextRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = nextRe;
        }
      }
    }
    // Bin 0 is the center; the upper half is the negative frequencies, so
    // the output starts there to run low to high.
    final out = Float32List(size);
    final half = size ~/ 2;
    for (var i = 0; i < size; i++) {
      final bin = (i + half) & (size - 1);
      final power = _re[bin] * _re[bin] + _im[bin] * _im[bin];
      out[i] = 10 * math.log(power / size + 1e-20) / math.ln10;
    }
    return out;
  }

  static List<int> _bitReversal(int n) {
    final bits = n.bitLength - 1;
    return [
      for (var i = 0; i < n; i++)
        () {
          var r = 0;
          for (var b = 0; b < bits; b++) {
            if (i & (1 << b) != 0) r |= 1 << (bits - 1 - b);
          }
          return r;
        }(),
    ];
  }
}

/// [levels] reduced to at most [maxPoints] by keeping the loudest bin of each
/// group: a narrow carrier has to survive pooling.
Float32List poolPeaks(Float32List levels, int maxPoints) {
  if (levels.length <= maxPoints) return levels;
  final factor = (levels.length / maxPoints).ceil();
  final out = Float32List(levels.length ~/ factor);
  for (var i = 0; i < out.length; i++) {
    var peak = levels[i * factor];
    for (var j = 1; j < factor; j++) {
      peak = math.max(peak, levels[i * factor + j]);
    }
    out[i] = peak;
  }
  return out;
}

/// Where a computed sweep's display range sits: the noise, followed slowly so
/// one loud signal does not drag the floor up, and a range the shape of a
/// radio's own panadapter at its default levels.
class NoiseFloor {
  /// How far below the noise the display starts, and how tall it is.
  static const belowNoiseDb = 10.0;
  static const rangeDb = 80.0;

  double? _noise;

  /// Folds [levels] in; null when they hold no usable reading.
  ({double floor, double ceiling})? update(Float32List levels, {double refLevelDb = 0}) {
    final sorted = Float32List.fromList(levels)..sort();
    final noise = sorted[sorted.length ~/ 5];
    if (!noise.isFinite) return null;
    _noise = _noise == null ? noise : _noise! * 0.9 + noise * 0.1;
    final floor = _noise! - belowNoiseDb - refLevelDb;
    return (floor: floor, ceiling: floor + rangeDb);
  }

  void reset() => _noise = null;
}
