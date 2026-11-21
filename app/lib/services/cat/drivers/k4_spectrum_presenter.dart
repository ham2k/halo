// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis, realNowMillis;

import '../spectrum.dart';
import '../spectrum_fft.dart';

/// Presents either K4 spectrum source and fits the radio's pan on request.
/// Source lifetimes and connection problems remain the caller's responsibility.
class K4SpectrumPresenter {
  final SpectrumSink? sink;

  K4SpectrumPresenter({required this.sink});

  static const _spans = [1000, 2500, 5000, 10000, 20000, 40000, 80000, 160000];
  static const _sweepIntervalMillis = {SpectrumSpeed.slow: 250, SpectrumSpeed.mid: 125, SpectrumSpeed.fast: 0};
  // Pair each nominal PAN width with a #SPN value inside its tier, clear of
  // the radio's span thresholds for switching between PAN widths.
  static const _panTiers = [
    (rateHz: 24000, spanHz: 15000),
    (rateHz: 48000, spanHz: 25000),
    (rateHz: 96000, spanHz: 40000),
    (rateHz: 192000, spanHz: 100000),
    (rateHz: 384000, spanHz: 200000),
  ];
  static const _hardwareRetryMillis = 1000;

  bool _wanted = false;
  int _epoch = 0;
  final _noise = NoiseFloor();
  int? _lastEmitMillis;
  int? _rate;
  int? _centerHz;
  int? _binCount;
  ({int rate, int atMillis})? _pendingHardwareSpan;

  /// An explicit scope span survives a change in sample rate. Without one,
  /// every display can choose its own view over the full sweep.
  int? _requestedSpanHz;
  int? _spanHz;
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
      hardwareMaxWidthHz: _binCount == null ? _panTiers.last.rateHz : _panWidth(_panTiers.last.rateHz),
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
    _pendingHardwareSpan = null;
  }

  bool set(SpectrumRequest request, {void Function(int)? writeHardwareSpan}) {
    if (!_wanted || request.centerHz != null || (request.mode != null && request.mode != SpectrumMode.fixed)) return false;
    if (request.hardwareWidthHz case final width?) {
      if (writeHardwareSpan == null || request.spanHz != null || request.refLevelDb != null || request.speed != null) return false;
      return _fitHardwareSpan(width, request.allowHardwareNarrowing, writeHardwareSpan);
    }
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

  /// CAT sets the radio's displayed span in Hz. The radio chooses a
  /// PAN tier with room around that display. Keep packet edges authoritative.
  bool _fitHardwareSpan(int width, bool allowNarrowing, void Function(int) writeSpan) {
    final currentRate = _rate;
    if (width <= 0 || currentRate == null || _binCount == null || _centerHz == null) return false;
    final pending = _pendingHardwareSpan;
    final now = realNowMillis();
    final pendingIsRecent = pending != null && _awaitingHardwareSpan(pending.atMillis, now);
    final pendingRate = pendingIsRecent ? pending.rate : currentRate;
    int coverageAt(int rate) => _panWidth(rate, centeredOnRate: rate < currentRate ? currentRate : null);
    // Protect the current tier and a wider one already requested. A pan
    // that no longer fits a pending downshift must cancel that downshift.
    if (!allowNarrowing && width <= coverageAt(currentRate) && width <= coverageAt(pendingRate)) return false;
    final minimumRate = allowNarrowing ? 0 : math.max(currentRate, pendingRate);
    final target = _panTiers.firstWhere((tier) => tier.rateHz >= minimumRate && coverageAt(tier.rateHz) >= width, orElse: () => _panTiers.last);
    if (target.rateHz < minimumRate || (target.rateHz == currentRate && pendingRate == currentRate)) return false;
    if (pendingIsRecent && pendingRate == target.rateHz) return false;
    writeSpan(target.spanHz);
    _pendingHardwareSpan = (rate: target.rateHz, atMillis: now);
    return true;
  }

  int _panWidth(int rate, {int? centeredOnRate}) {
    final lastBin = _binCount! - 1;
    final low = _frequencyAt(0, rate), high = _frequencyAt(lastBin, rate);
    if (centeredOnRate == null) return high - low;
    // PAN centers its bins about the first bin to the right of the
    // midpoint. A lower rate shifts the midpoint by half the bin-width
    // difference, so cover both edges of the requested window.
    final twiceCenter = _frequencyAt(0, centeredOnRate) + _frequencyAt(lastBin, centeredOnRate);
    return math.min(twiceCenter - 2 * low, 2 * high - twiceCenter);
  }

  static bool _awaitingHardwareSpan(int asked, int now) => now >= asked && now - asked < _hardwareRetryMillis;

  void add({required int centerHz, required int sampleRateHz, required Float32List levels}) {
    if (!_wanted || centerHz < 0 || sampleRateHz < 2 || levels.length < 2 || levels.any((level) => !level.isFinite)) return;
    final epoch = _epoch;
    final previousRate = _rate;
    final sourceChanged = previousRate != sampleRateHz || _binCount != levels.length;
    _centerHz = centerHz;
    if (sourceChanged) {
      _rate = sampleRateHz;
      _binCount = levels.length;
      if (_requestedSpanHz case final span?) _spanHz = capabilities.snapSpan(span);
      _noise.reset();
      _lastEmitMillis = null;
    }
    // Reversing a pending command can target the rate already arriving. Old
    // packets at that rate alone do not confirm the reversal right away.
    if (_pendingHardwareSpan case (:final rate, :final atMillis) when sampleRateHz == rate) {
      if (previousRate != rate || !_awaitingHardwareSpan(atMillis, realNowMillis())) _pendingHardwareSpan = null;
    }
    _reportSettings(force: sourceChanged);
    if (!_wanted || epoch != _epoch) return;

    // Rendering is paced in real elapsed time; developer time travel changes
    // the frame's displayed timestamp, never the amount of network work.
    final now = realNowMillis();
    if (_lastEmitMillis case final last? when now >= last && now - last < _sweepIntervalMillis[_speed]!) return;
    _lastEmitMillis = now;
    final crop = _crop();
    final shown = Float32List.sublistView(levels, crop.first, crop.end);
    final range = _noise.update(shown, refLevelDb: _refLevelDb, centerHz: centerHz);
    if (range == null) return;
    sink?.reportSpectrum(
      SpectrumFrame(
        lowHz: crop.lowHz,
        highHz: crop.highHz,
        levels: shown,
        floorDb: range.floor,
        ceilingDb: range.ceiling,
        noiseDb: range.noise,
        atMillis: nowMillis(),
      ),
    );
  }

  ({int first, int end, int lowHz, int highHz}) _crop() {
    final rate = _rate!, count = _binCount!;
    final radius = switch (_spanHz) {
      final span? => math.max(1, (span * count / rate).floor()),
      null => count ~/ 2,
    };
    final first = math.max(0, count ~/ 2 - radius);
    final end = math.min(count, count ~/ 2 + radius + 1);
    // Each endpoint names a retained bin, not the requested window edge:
    // stretching a subset to the latter would mislabel narrow carriers.
    return (first: first, end: end, lowHz: _frequencyAt(first, rate), highHz: _frequencyAt(end - 1, rate));
  }

  int _frequencyAt(int bin, int rate) => (_centerHz! + (bin - _binCount! / 2) * rate / _binCount!).round();

  void _reportSettings({bool force = false}) {
    final crop = _centerHz == null ? null : _crop();
    final settings = SpectrumSettings(
      mode: SpectrumMode.fixed,
      spanHz: _spanHz ?? (_binCount == null ? null : _rate! ~/ 2),
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
