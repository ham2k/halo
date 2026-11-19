// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A sweep of its own at a narrower span, computed from IQ a session already
// receives for its own sweep — docs/design/cat.md § Several scopes. For a
// FlexRadio mirrored through DAX IQ and a TCI server: the IQ is the app's to
// transform however it likes, so a narrower display gets a transform fine
// enough for its span rather than a crop of the widest.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_core/halo_core.dart' show nowMillis;

import 'spectrum.dart';
import 'spectrum_fft.dart';

/// The points a sweep is pooled to at most, and the points the transform
/// aims to give the span: as fine as the widest sweep's, never finer than a
/// panel can show.
const _points = 2048;

/// The largest transform: at 384 kHz, 16k points give a 24 kHz span 1024 of
/// its own, 43 ms of IQ each.
const _maxSize = 16384;

const _sweepsPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

class IqSubScope implements SpectrumScope {
  final SpectrumSink sink;

  /// The receiver's frequency in Hz, where the sweep sits until a display
  /// moves it; null where the session has none to say.
  final int? Function() receiverHz;

  /// Called once, as the scope is closed: the session stops feeding it.
  final void Function(IqSubScope scope) closed;

  /// Moves the session's IQ to centre on a frequency in Hz, as a recentre of
  /// its own scope does: for a display moved past what the IQ holds, which no
  /// crop of it reaches. Whether the session took it.
  final bool Function(int hz) moveIq;

  IqSubScope({required this.sink, required this.receiverHz, required this.closed, required this.moveIq});

  /// The half-width asked of it, where a display put its middle, and the
  /// IQ's centre when it did.
  int? _halfWidth, _askedCenter, _askedAtIq;
  SpectrumSettings _settings = const SpectrumSettings(speed: SpectrumSpeed.mid, refLevelDb: 0);
  bool _closed = false;

  IqSpectrum? _fft;
  int _rate = 0;
  final _noise = NoiseFloor();

  /// What the samples being transformed came with, for the sweep they make.
  int _iqCenter = 0, _visibleHalf = 0;

  @override
  bool setSpectrum(SpectrumRequest request) {
    if (_closed) return false;
    if (request.spanHz case final span?) _halfWidth = span;
    if (request.centerHz case final hz?) {
      _askedCenter = hz;
      _askedAtIq = _iqCenter;
      final half = (_halfWidth ?? _visibleHalf).clamp(1, _visibleHalf);
      if (_visibleHalf > 0 && (hz - _iqCenter).abs() > _visibleHalf - half) return moveIq(hz);
    }
    if (request.refLevelDb case final ref?) _report(_settings.copyWith(refLevelDb: ref));
    if (request.speed case final speed?) {
      _report(_settings.copyWith(speed: speed));
      _fft?.hop = _rate ~/ _sweepsPerSecond[speed]!;
    }
    return true;
  }

  /// Samples from before the session's IQ stopped and started again, which
  /// would be drawn in a sweep with the next ones.
  void reset() {
    _fft = null;
    _noise.reset();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    closed(this);
  }

  /// The transform's size for a span [half] either side out of IQ at [rate]:
  /// the smallest giving the span half [_points] of its own or more, so it is
  /// drawn unpooled. Twice that is twice the work and twice the time each
  /// sweep spans, smearing keying across the waterfall's rows.
  @visibleForTesting
  static int sizeFor(int rate, int half) {
    var size = 256;
    while (size < _maxSize && size * 4 * half < _points * rate) {
      size <<= 1;
    }
    return size;
  }

  /// Interleaved I/Q pairs at [rate], centred at [iqCenterHz], their middle
  /// [visibleHalfWidth] either side clear of the decimation filter's edges.
  void feed(Float32List interleaved, {required int rate, required int iqCenterHz, required int visibleHalfWidth}) {
    if (_closed || rate <= 0) return;
    final half = (_halfWidth ?? visibleHalfWidth).clamp(1, visibleHalfWidth);
    final size = sizeFor(rate, half);
    // A middle a display put before the IQ moved elsewhere goes back to the receiver: held, it
    // would draw an edge of the new band.
    if ((_askedCenter, _askedAtIq) case (final asked?, final at?) when at != iqCenterHz && (asked - iqCenterHz).abs() > visibleHalfWidth - half) {
      _askedCenter = null;
    }
    // Samples from before the IQ moved, labelled at its new centre, would draw signals where they are not.
    if (rate != _rate || _fft?.size != size || iqCenterHz != _iqCenter) {
      _rate = rate;
      _fft = IqSpectrum(size: size, hop: rate ~/ _sweepsPerSecond[_settings.speed ?? SpectrumSpeed.mid]!);
      _noise.reset();
    }
    _iqCenter = iqCenterHz;
    _visibleHalf = visibleHalfWidth;
    _fft!.add(interleaved, _emit);
  }

  void _emit(Float32List levels) {
    final n = levels.length, binHz = _rate / n, iqLow = _iqCenter - _rate / 2;
    final half = (_halfWidth ?? _visibleHalf).clamp(1, _visibleHalf);
    // On the receiver until a display moves it, and never past the clear middle of the IQ.
    final wanted = _askedCenter ?? receiverHz() ?? _iqCenter;
    final center = wanted.clamp(_iqCenter - _visibleHalf + half, _iqCenter + _visibleHalf - half);
    final first = ((center - half - iqLow) / binHz).round().clamp(0, n - 2);
    final last = ((center + half - iqLow) / binHz).round().clamp(first + 1, n - 1);
    final pooled = poolPeaks(Float32List.sublistView(levels, first, last + 1), _points);
    final low = (iqLow + first * binHz).round(), high = (iqLow + last * binHz).round();
    final range = _noise.update(pooled, refLevelDb: _settings.refLevelDb ?? 0, centerHz: center);
    if (range == null) return;
    _report(_settings.copyWith(spanHz: half, lowHz: low, highHz: high));
    sink.reportSpectrum(
      SpectrumFrame(lowHz: low, highHz: high, levels: pooled, floorDb: range.floor, ceilingDb: range.ceiling, noiseDb: range.noise, atMillis: nowMillis()),
    );
  }

  void _report(SpectrumSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    sink.reportSpectrumSettings(settings);
  }
}
