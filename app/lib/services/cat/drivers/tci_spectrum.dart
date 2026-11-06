// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A TCI server's panadapter, computed here from its IQ stream —
// docs/design/cat.md § Spectrum. TCI defines no spectrum of its own; it
// streams the receiver's IQ as binary frames on the same WebSocket, at a
// rate each client picks for itself. The spec does not say where the IQ is
// centred; this takes it to be the receiver's `DDS`, the centre the spec
// gives a receiver.
//
// Not run against a server. Thetis streams IQ over TCI from 2.10.3.13;
// before that, and on a server that does not, the display says so after
// [_firstFrameDeadline] rather than waiting forever.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../spectrum.dart';
import '../spectrum_fft.dart';
import 'tci_codec.dart';

/// The outer share of each side cut from a sweep, where a decimation filter
/// rolls the band edge off. The Flex's figure (flex_spectrum.dart), not
/// measured on any TCI server.
const _edgeTrim = 1 / 16;

int _visibleHalfWidth(int rate) => (rate * (1 - 2 * _edgeTrim) / 2).round();

/// The half-widths shown for each of [tciIqRates].
final tciIqSpans = [for (final rate in tciIqRates) _visibleHalfWidth(rate)];

/// Sweeps are pooled to at most this many points: a 384 kHz stream's
/// transform is far finer than any panel is wide.
const _maxPoints = 1024;

const _sweepsPerSecond = {SpectrumSpeed.slow: 8, SpectrumSpeed.mid: 15, SpectrumSpeed.fast: 25};

const _firstFrameDeadline = Duration(seconds: 5);

class TciSpectrum {
  final void Function(String command) send;
  final SpectrumSink? sink;

  /// The connection's binary frames; null on one that carries none.
  final Stream<Uint8List>? frames;

  TciSpectrum({required this.send, required this.sink, required this.frames});

  bool _wanted = false;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _watchdog;
  bool _heard = false;

  /// The receiver's centre, from `DDS`. No sweep is placed before it is known.
  int? _centerHz;

  /// The rate asked for, and the one the frames say they are at — they
  /// differ when the server refuses a rate, and the frames are the truth.
  int _askedRate = tciIqRates.first;
  int _rate = tciIqRates.first;

  IqSpectrum? _fft;
  final _noise = NoiseFloor();
  SpectrumSettings _settings = const SpectrumSettings(speed: SpectrumSpeed.mid, refLevelDb: 0);

  bool get wanted => _wanted;

  SpectrumCapabilities get capabilities => SpectrumCapabilities(
    spansHz: tciIqSpans,
    refMinDb: -30,
    refMaxDb: 30,
    refStepDb: 1,
    speeds: const {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
    canRecenter: true,
    autoSpan: true,
  );

  void start() {
    if (_wanted) return;
    _wanted = true;
    _heard = false;
    _subscription = frames?.listen(frame);
    send(buildTciIqRateCommand(_askedRate));
    send(buildTciIqStartCommand());
    sink?.reportSpectrumSettings(_settings);
    _watchdog?.cancel();
    _watchdog = Timer(_firstFrameDeadline, () {
      if (_wanted && !_heard) sink?.reportSpectrumProblem(t.settings.station.spectrumTciNoIq);
    });
  }

  void stop() {
    if (!_wanted) return;
    _release();
    send(buildTciIqStopCommand());
    sink?.reportSpectrumProblem(null);
  }

  /// False when nothing is running to set.
  bool set(SpectrumRequest request) {
    if (!_wanted) return false;
    if (request.refLevelDb case final ref?) _report(_settings.copyWith(refLevelDb: capabilities.snapRef(ref)));
    if (request.speed case final speed?) {
      _report(_settings.copyWith(speed: speed));
      _fft?.hop = _rate ~/ _sweepsPerSecond[speed]!;
    }
    // The centre is the receiver's, which the server's own panadapter shows
    // too: moving it moves the operator's window there as well. Not applied
    // here — the server answers with the `DDS` it took, and a sweep placed
    // where the IQ is not would be labelled wrong.
    if (request.centerHz case final hz?) send(buildTciSetDdsCommand(hz));
    if (request.spanHz case final span?) {
      _askedRate = tciIqRates[tciIqSpans.indexOf(capabilities.snapSpan(span))];
      send(buildTciIqRateCommand(_askedRate));
    }
    return true;
  }

  /// The receiver's centre moved, or was first said.
  void dds(int hz) => _centerHz = hz;

  /// One binary frame. Anything but receiver 0's IQ is someone else's
  /// stream — audio another client asked for is never sent to this one, but
  /// nothing here relies on that.
  void frame(Uint8List data) {
    if (!_wanted) return;
    final header = parseTciStreamHeader(data);
    if (header == null || header.type != tciIqStreamType || header.receiver != tciReceiver) return;
    if (!_heard) {
      _heard = true;
      _watchdog?.cancel();
      _watchdog = null;
      sink?.reportSpectrumProblem(null);
    }
    if (header.sampleRate != _rate && header.sampleRate > 0) {
      _rate = header.sampleRate;
      _fft = null;
      _noise.reset();
    }
    final samples = tciSamples(data, header);
    if (samples.isEmpty) return;
    final fft = _fft ??= IqSpectrum(size: _sizeFor(_rate), hop: _rate ~/ _sweepsPerSecond[_settings.speed ?? SpectrumSpeed.mid]!);
    fft.add(samples, _emit);
  }

  static int _sizeFor(int rate) {
    var size = 256;
    while (size < rate ~/ 24) {
      size <<= 1;
    }
    return size;
  }

  void _emit(Float32List levels) {
    final center = _centerHz;
    if (center == null) return;
    final trim = (levels.length * _edgeTrim).round();
    final pooled = poolPeaks(Float32List.sublistView(levels, trim, levels.length - trim), _maxPoints);
    final range = _noise.update(pooled, refLevelDb: _settings.refLevelDb ?? 0, centerHz: center);
    if (range == null) return;
    final half = _visibleHalfWidth(_rate);
    _report(_settings.copyWith(spanHz: half, lowHz: center - half, highHz: center + half));
    sink?.reportSpectrum(
      SpectrumFrame(
        lowHz: center - half,
        highHz: center + half,
        levels: pooled,
        floorDb: range.floor,
        ceilingDb: range.ceiling,
        noiseDb: range.noise,
        atMillis: nowMillis(),
      ),
    );
  }

  void _report(SpectrumSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    sink?.reportSpectrumSettings(settings);
  }

  void _release() {
    _wanted = false;
    _watchdog?.cancel();
    _watchdog = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _fft = null;
    _noise.reset();
  }

  /// For the session's teardown, over a connection still open.
  void teardown() {
    if (_wanted) stop();
  }
}
