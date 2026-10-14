// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR receiver's spectrum, for whatever protocol delivers its IQ —
// docs/design/cat.md § SDR receivers.
//
// An SDR has no VFO and no scope of its own: it is a tuner and a stream of
// samples. This file turns those samples into sweeps labelled in the linked
// radio's frequencies, and decides where to tune so the radio's dial stays in
// view. A protocol session supplies only the bytes and the two commands
// ([SdrTuner]).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis, realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart';
import '../spectrum.dart';
import '../spectrum_fft.dart';

/// Where the SDR's antenna input comes from.
enum SdrTuning {
  /// Its own antenna (or a splitter): the app tunes it to where the linked
  /// radio is, and may place its window anywhere.
  independent,

  /// The linked radio's IF output: tuned once to the IF, and every sweep is
  /// relabelled around the radio's dial.
  ifTap,
}

const sdrTuningConfigKey = 'sdrTuning';
const sdrIfHzConfigKey = 'sdrIfHz';
const sdrIfInvertedConfigKey = 'sdrIfInverted';
const sdrOffsetHzConfigKey = 'sdrOffsetHz';
const sdrPpmConfigKey = 'sdrPpm';
const sdrGainDbConfigKey = 'sdrGainDb';

/// What an SDR node is set up to do, read from its config.
class SdrConfig {
  final SdrTuning tuning;

  /// The IF the radio's dial sits at, for [SdrTuning.ifTap].
  final int ifHz;

  /// Whether the IF is mirrored — a radio mixing with an oscillator above the
  /// signal, so a frequency rising on the dial falls at the IF.
  final bool ifInverted;

  /// Added to every frequency sent to the device and nowhere else: an
  /// upconverter's oscillator (125 MHz on a Ham It Up), so the device is told
  /// 139 MHz for 14 MHz and every sweep still reads 14 MHz.
  final int offsetHz;

  final int ppm;

  /// Null for the device's own automatic gain.
  final double? gainDb;

  const SdrConfig({this.tuning = SdrTuning.independent, this.ifHz = 0, this.ifInverted = false, this.offsetHz = 0, this.ppm = 0, this.gainDb});

  factory SdrConfig.fromConfig(Map<String, dynamic> config) {
    num? number(String key) => switch (config[key]) {
      final num n => n,
      final String s => num.tryParse(s.trim()),
      _ => null,
    };
    return SdrConfig(
      tuning: config[sdrTuningConfigKey] == SdrTuning.ifTap.name ? SdrTuning.ifTap : SdrTuning.independent,
      ifHz: number(sdrIfHzConfigKey)?.round() ?? 0,
      ifInverted: config[sdrIfInvertedConfigKey] == true || config[sdrIfInvertedConfigKey] == 'true',
      offsetHz: number(sdrOffsetHzConfigKey)?.round() ?? 0,
      ppm: number(sdrPpmConfigKey)?.round() ?? 0,
      gainDb: number(sdrGainDbConfigKey)?.toDouble(),
    );
  }
}

/// The settings every SDR protocol shares, for its driver's
/// [EquipmentDriver.configElements]. Everything but the tuning is an
/// advanced setting: the defaults are right for a receiver on its own
/// antenna.
List<Map<String, dynamic>> sdrConfigElements() {
  final st = t.settings.station;
  return [
    {
      'type': 'field',
      'fieldType': 'select',
      'key': sdrTuningConfigKey,
      'label': st.sdrTuning,
      'description': st.sdrTuningDescription,
      'options': [
        {'value': SdrTuning.independent.name, 'label': st.sdrTuningIndependent},
        {'value': SdrTuning.ifTap.name, 'label': st.sdrTuningIfTap},
      ],
    },
    {'type': 'field', 'fieldType': 'number', 'key': sdrIfHzConfigKey, 'label': st.sdrIfHz, 'description': st.sdrIfHzDescription},
    {'type': 'field', 'fieldType': 'checkbox', 'key': sdrIfInvertedConfigKey, 'label': st.sdrIfInverted},
    {'type': 'field', 'fieldType': 'number', 'key': sdrGainDbConfigKey, 'label': st.sdrGainDb, 'description': st.sdrGainDbDescription, 'advanced': true},
    {'type': 'field', 'fieldType': 'number', 'key': sdrOffsetHzConfigKey, 'label': st.sdrOffsetHz, 'description': st.sdrOffsetHzDescription, 'advanced': true},
    {'type': 'field', 'fieldType': 'number', 'key': sdrPpmConfigKey, 'label': st.sdrPpm, 'advanced': true},
  ];
}

/// Where an SDR session asks for the one piece of app state it reads: the
/// linked radio's dial. Pulled on every sweep rather than pushed, since a
/// sweep is when it is needed, and a driver never reaches into app state.
abstract class SdrSink {
  /// In Hz; null while the linked radio is not connected or not reporting.
  double? get linkedVfoHz;
}

/// What the protocol session does when the spectrum decides to move.
abstract class SdrTuner {
  /// The device's frequency, in Hz, offset included.
  void tuneDevice(int hz);

  void setSampleRate(int rate);
}

/// The outer share of each side of a sweep that is cut: an SDR's
/// anti-alias filter rolls its edges off, and shown they read as a band
/// with no signals in it. Not measured on any device here, and kept apart
/// from the Flex's trim, which was: one is a guess, the other a measurement.
const sdrEdgeTrim = 1 / 16;

/// The half-width actually shown at [rate].
int sdrVisibleHalfWidth(int rate) => (rate * (1 - 2 * sdrEdgeTrim) / 2).round();

/// The most points a sweep carries: enough that a panel's `span` can crop a
/// 2 MHz sweep to a few tens of kHz and still have bins to draw.
const _maxPoints = 2048;

const _sweepsPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

/// The most retunes a second. Each one throws away [_settleSeconds] of
/// samples, and a dial spun fast would otherwise leave nothing to draw.
const _minRetuneMillis = 250;

/// How much IQ to discard after a retune or a rate change: samples already
/// in flight from the device belong to the old setting, and drawn at the new
/// one they smear a signal sideways across the waterfall. Not measured on
/// any device here.
const _settleSeconds = 0.1;

class SdrSpectrum {
  final SdrConfig config;
  final SdrTuner tuner;
  final SpectrumSink? sink;
  final SdrSink? vfo;

  /// The sample rates the device runs at, ascending; each is one span.
  final List<int> rates;

  SdrSpectrum({required this.config, required this.tuner, required this.sink, required this.vfo, required this.rates, int? initialRate})
    : assert(rates.isNotEmpty),
      _rate = initialRate ?? rates[rates.length ~/ 2];

  bool _wanted = false;
  bool get wanted => _wanted;

  int _rate;
  int get rate => _rate;

  /// The RF frequency at the middle of what the device is sampling — the
  /// device itself is told this plus [SdrConfig.offsetHz]. Null until there
  /// is a frequency to tune to.
  int? _centerHz;
  int? get centerHz => _centerHz;

  int _lastRetuneMillis = 0;

  late SpectrumSettings _settings = SpectrumSettings(
    mode: config.tuning == SdrTuning.ifTap ? SpectrumMode.center : SpectrumMode.fixed,
    spanHz: sdrVisibleHalfWidth(_rate),
    refLevelDb: 0,
    speed: SpectrumSpeed.mid,
  );

  IqSpectrum? _fft;
  final _noise = NoiseFloor();
  Float32List _window = Float32List(0);
  int _filled = 0;
  int _skip = 0;

  SpectrumCapabilities get capabilities => SpectrumCapabilities(
    spansHz: [for (final rate in rates) sdrVisibleHalfWidth(rate)],
    refMinDb: -30,
    refMaxDb: 30,
    refStepDb: 1,
    modes: config.tuning == SdrTuning.ifTap ? const {SpectrumMode.center} : const {SpectrumMode.center, SpectrumMode.fixed},
    speeds: const {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
    // An IF tap shows wherever the radio's own mixer puts it.
    canRecenter: config.tuning == SdrTuning.independent,
  );

  /// The settings and the device's starting point, sent once the protocol
  /// can take commands.
  void start() {
    if (_wanted) return;
    _wanted = true;
    tuner.setSampleRate(_rate);
    if (config.tuning == SdrTuning.ifTap) {
      if (config.ifHz > 0) _tune(config.ifHz, force: true);
    } else {
      _centerHz = null;
      _follow();
    }
    sink?.reportSpectrumSettings(_settings);
    _reportWaiting();
  }

  void stop() {
    if (!_wanted) return;
    _wanted = false;
    _restartWindow();
    _noise.reset();
    sink?.reportSpectrumProblem(null);
  }

  bool set(SpectrumRequest request) {
    if (!_wanted) return false;
    final caps = capabilities;
    if (request.refLevelDb case final ref?) _report(_settings.copyWith(refLevelDb: caps.snapRef(ref)));
    if (request.speed case final speed?) {
      _report(_settings.copyWith(speed: speed));
      _restartWindow();
    }
    if (request.mode case final mode? when caps.modes.contains(mode)) {
      _report(_withWindow(_settings.copyWith(mode: mode)));
      _follow();
    }
    if (request.spanHz case final span?) {
      final rate = rates[caps.spansHz.indexOf(caps.snapSpan(span))];
      if (rate != _rate) {
        _rate = rate;
        tuner.setSampleRate(rate);
        _restartWindow(settle: true);
        _report(_withWindow(_settings.copyWith(spanHz: sdrVisibleHalfWidth(rate))));
      }
    }
    // Only a window the app places, and only when it is not pinned to the
    // dial: in center mode the next sweep would put it straight back.
    if (request.centerHz case final hz? when caps.canRecenter && _settings.mode == SpectrumMode.fixed) _tune(hz, force: true);
    return true;
  }

  /// [count] complex samples, of which [convert] writes the ones asked for —
  /// samples `from` to `from + n` as interleaved I/Q floats into `into` at
  /// `at`. Most of a fast stream is never converted: a display shows a few
  /// thousand samples per sweep out of millions a second.
  void feed(int count, void Function(int from, int n, Float32List into, int at) convert) {
    if (!_wanted) return;
    final size = _fftSize;
    if (_window.length != size * 2) {
      _window = Float32List(size * 2);
      _filled = 0;
    }
    var i = 0;
    while (i < count) {
      if (_skip > 0) {
        final n = math.min(_skip, count - i);
        _skip -= n;
        i += n;
        continue;
      }
      final n = math.min(size - _filled, count - i);
      convert(i, n, _window, _filled * 2);
      _filled += n;
      i += n;
      if (_filled == size) {
        _filled = 0;
        _skip = math.max(0, _hop - size);
        // Only ever whole windows, so the transform has nothing of the last
        // one left in it to keep or clear.
        final fft = _fft?.size == size ? _fft! : (_fft = IqSpectrum(size: size, hop: size));
        fft.add(_window, _emit);
      }
    }
  }

  int get _hop => _rate ~/ _sweepsPerSecond[_settings.speed ?? SpectrumSpeed.mid]!;

  /// About 300 Hz a bin at 2.4 MHz: fine enough for a narrow `span`, and
  /// still a millisecond or two of work per sweep.
  int get _fftSize {
    var size = 1024;
    while (size < _rate ~/ 300 && size < 16384) {
      size <<= 1;
    }
    return size;
  }

  void _restartWindow({bool settle = false}) {
    _filled = 0;
    _skip = settle ? (_rate * _settleSeconds).round() : 0;
  }

  void _emit(Float32List levels) {
    // Sweeps keep coming while the dial moves, so this is where the window
    // catches up with it.
    // Labelled where the samples were taken: a sweep that moves the window
    // was tuned to the old one, and drawn at the new it would put every
    // signal on it off by the move.
    final center = _centerHz;
    _follow();
    if (center == null || center != _centerHz) return;
    // The DC offset every zero-IF receiver has, as a spike at the middle bin
    // — exactly where the dial marker is drawn in center mode.
    final mid = levels.length ~/ 2;
    levels[mid] = (levels[mid - 1] + levels[mid + 1]) / 2;
    final trim = (levels.length * sdrEdgeTrim).round();
    final shown = Float32List.sublistView(levels, trim, levels.length - trim);
    final half = sdrVisibleHalfWidth(_rate);
    var labelCenter = center;
    if (config.tuning == SdrTuning.ifTap) {
      // The IF is where the dial is: the sweep is the dial's neighbourhood,
      // mirrored where the radio's mixer mirrors it.
      final dial = vfo?.linkedVfoHz;
      _reportWaiting();
      if (dial == null) return;
      labelCenter = dial.round();
    }
    final pooled = poolPeaks(shown, _maxPoints);
    if (config.tuning == SdrTuning.ifTap && config.ifInverted) _reverse(pooled);
    final range = _noise.update(pooled, refLevelDb: _settings.refLevelDb ?? 0);
    if (range == null) return;
    sink?.reportSpectrum(
      SpectrumFrame(
        lowHz: labelCenter - half,
        highHz: labelCenter + half,
        levels: pooled,
        floorDb: range.floor,
        ceilingDb: range.ceiling,
        atMillis: nowMillis(),
      ),
    );
  }

  /// Keeps the linked radio's dial in view. In center mode the window sits
  /// on the dial; in fixed mode it moves only when the dial leaves it, so a
  /// panel's `follow` can place it with margins and is not fought over.
  void _follow() {
    if (!_wanted || config.tuning == SdrTuning.ifTap) return;
    final dial = vfo?.linkedVfoHz?.round();
    final center = _centerHz;
    if (dial == null) {
      _reportWaiting();
      return;
    }
    if (center == null) {
      _tune(dial, force: true);
      return;
    }
    final half = sdrVisibleHalfWidth(_rate);
    final outside = dial < center - half || dial > center + half;
    // A dial that left the window is followed at once; the pacing is for a
    // knob turning inside it.
    if (outside) {
      _tune(dial, force: true);
    } else if (_settings.mode == SpectrumMode.center && dial != center) {
      _tune(dial);
    }
  }

  void _tune(int hz, {bool force = false}) {
    if (hz == _centerHz) return;
    // Real time: this paces commands to a real device.
    final now = realNowMillis();
    if (!force && now - _lastRetuneMillis < _minRetuneMillis) return;
    _lastRetuneMillis = now;
    final first = _centerHz == null;
    _centerHz = hz;
    tuner.tuneDevice(hz + config.offsetHz);
    _restartWindow(settle: true);
    if (first) _reportWaiting();
    _report(_withWindow(_settings));
  }

  /// A receiver tuned against a radio has nothing to show until the radio
  /// says where it is.
  void _reportWaiting() {
    if (!_wanted) return;
    // Without an IF, tuning would send the device to 0 Hz, and the noise it
    // hears there drawn as the dial's neighbourhood looks like a quiet band.
    if (config.tuning == SdrTuning.ifTap && config.ifHz <= 0) {
      sink?.reportSpectrumProblem(t.settings.station.spectrumSdrNoIf);
      return;
    }
    final waiting = switch (config.tuning) {
      SdrTuning.independent => _centerHz == null,
      SdrTuning.ifTap => vfo?.linkedVfoHz == null,
    };
    sink?.reportSpectrumProblem(waiting ? t.settings.station.spectrumSdrNoRadio : null);
  }

  /// [settings] with the window's edges, which are reported only for a window
  /// the app holds still — in center mode, and on an IF tap, the window is
  /// wherever the dial is.
  SpectrumSettings _withWindow(SpectrumSettings settings) {
    final center = _centerHz;
    final fixed = config.tuning == SdrTuning.independent && settings.mode == SpectrumMode.fixed && center != null;
    final half = sdrVisibleHalfWidth(_rate);
    return SpectrumSettings(
      mode: settings.mode,
      spanHz: settings.spanHz,
      lowHz: fixed ? center - half : null,
      highHz: fixed ? center + half : null,
      refLevelDb: settings.refLevelDb,
      speed: settings.speed,
    );
  }

  /// In place: each sweep's levels are a list of its own.
  static void _reverse(Float32List levels) {
    for (var i = 0, j = levels.length - 1; i < j; i++, j--) {
      final swap = levels[i];
      levels[i] = levels[j];
      levels[j] = swap;
    }
  }

  void _report(SpectrumSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    sink?.reportSpectrumSettings(settings);
  }
}
