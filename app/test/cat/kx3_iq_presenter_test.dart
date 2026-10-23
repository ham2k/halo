// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/kx3_iq_presenter.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

class _Sink implements SpectrumSink {
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  void Function()? onFrame;

  @override
  void reportSpectrum(SpectrumFrame frame) {
    frames.add(frame);
    onFrame?.call();
  }

  @override
  void reportSpectrumSettings(SpectrumSettings settings) => this.settings.add(settings);

  @override
  void reportSpectrumProblem(String? message) => fail('presentation does not own connection problems');
}

Uint8List _tone(double hz, {int samples = 2048, int sampleRate = 48000}) {
  final bytes = Uint8List(samples * 4);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples; i++) {
    final phase = 2 * math.pi * hz * i / sampleRate;
    data.setInt16(i * 4, (12000 * math.cos(phase)).round(), Endian.little);
    data.setInt16(i * 4 + 2, (12000 * math.sin(phase)).round(), Endian.little);
  }
  return bytes;
}

double _peakHz(SpectrumFrame frame) {
  var peak = 0;
  for (var i = 1; i < frame.levels.length; i++) {
    if (frame.levels[i] > frame.levels[peak]) peak = i;
  }
  return frame.lowHz + peak / (frame.levels.length - 1) * (frame.highHz - frame.lowHz);
}

void main() {
  late _Sink sink;
  late Kx3IqPresenter presenter;

  setUp(() {
    sink = _Sink();
    presenter = Kx3IqPresenter(sampleRate: 48000, sink: sink);
  });

  tearDown(() => presenter.stop());

  void start({int dial = 14050000}) {
    presenter.updateFrequency(dial);
    presenter.start();
    presenter.set(const SpectrumRequest(speed: SpectrumSpeed.fast));
  }

  for (final hz in [-6000.0, 6000.0]) {
    test('complex stereo preserves the ${hz < 0 ? 'lower' : 'upper'} side of the dial', () {
      start();
      presenter.add(_tone(hz));
      expect(sink.frames, hasLength(1));
      expect(_peakHz(sink.frames.single), closeTo(14050000 + hz, 1));
      expect(sink.frames.single.ceilingDb - sink.frames.single.floorDb, 80);
    });
  }

  test('swapping I and Q mirrors the spectrum without shifting the dial', () {
    presenter = Kx3IqPresenter(sampleRate: 48000, swapIq: true, sink: sink);
    start();
    presenter.add(_tone(6000));
    expect(_peakHz(sink.frames.single), closeTo(14044000, 1));
  });

  test('arbitrary callback boundaries preserve PCM words and stereo pairs', () {
    start();
    final tone = _tone(-6000);
    for (var at = 0; at < tone.length;) {
      final end = math.min(tone.length, at + [1, 2, 3, 7, 127][at % 5]);
      presenter.add(Uint8List.sublistView(tone, at, end));
      at = end;
    }
    expect(sink.frames, hasLength(1));
    expect(_peakHz(sink.frames.single), closeTo(14044000, 1));
  });

  test('positive center offset adds to the CAT dial and survives zooming', () {
    presenter = Kx3IqPresenter(sampleRate: 48000, offsetHz: 8000, sink: sink);
    start();
    presenter.set(const SpectrumRequest(spanHz: 2500));
    presenter.add(_tone(1500));
    final frame = sink.frames.single;
    expect(_peakHz(frame), closeTo(14059500, 1));
    expect((frame.lowHz + frame.highHz) / 2, 14058000);
    expect(frame.lowHz, greaterThanOrEqualTo(14055500));
    expect(frame.highHz, lessThanOrEqualTo(14060500));
    expect(sink.settings.last.mode, SpectrumMode.center);
    expect(sink.settings.last.lowHz, isNull);
    expect(sink.settings.last.highHz, isNull);
  });

  for (final partialBytes in [1, 2, 3]) {
    test('retuning discards a partial FFT while preserving a $partialBytes-byte stereo-frame position', () {
      start();
      final old = _tone(6000, samples: 1025);
      final split = 4096 + partialBytes;
      presenter.add(Uint8List.sublistView(old, 0, split));
      presenter.updateFrequency(7100000);
      final tone = _tone(-6000);
      // CAT changes do not restart the physical audio stream: its next
      // callback still finishes the stereo frame begun before the retune.
      presenter.add(Uint8List.fromList([...old.sublist(split), ...tone.sublist(0, 4096)]));
      expect(sink.frames, isEmpty, reason: 'old-dial samples cannot fill the new-dial FFT');
      presenter.add(Uint8List.sublistView(tone, 4096));
      expect(sink.frames, hasLength(1));
      expect(_peakHz(sink.frames.single), closeTo(7094000, 1));
    });

    test('waiting for CAT retains a $partialBytes-byte stereo-frame position', () {
      presenter.start();
      presenter.set(const SpectrumRequest(speed: SpectrumSpeed.fast));
      final tone = _tone(1500, samples: 2049);
      presenter.add(Uint8List.sublistView(tone, 0, partialBytes));
      presenter.updateFrequency(14050000);
      // Even a callback containing only one remaining byte must advance
      // alignment before a later callback supplies the complete new frames.
      presenter.add(Uint8List.sublistView(tone, partialBytes, partialBytes + 1));
      presenter.add(Uint8List.sublistView(tone, partialBytes + 1));
      expect(sink.frames, hasLength(1));
      expect(_peakHz(sink.frames.single), closeTo(14051500, 1));
    });
  }

  test('repeated CAT reports do not starve a partial FFT', () {
    start();
    final tone = _tone(6000);
    presenter.add(Uint8List.sublistView(tone, 0, 4099));
    presenter.updateFrequency(14050000);
    presenter.add(Uint8List.sublistView(tone, 4099));
    expect(sink.frames, hasLength(1));
    expect(_peakHz(sink.frames.single), closeTo(14056000, 1));
  });

  test('no spectrum is labelled until CAT supplies a valid dial', () {
    presenter.start();
    presenter.set(const SpectrumRequest(speed: SpectrumSpeed.fast));
    for (final hz in [null, 0, -1]) {
      presenter.updateFrequency(hz);
      presenter.add(_tone(6000));
    }
    expect(sink.frames, isEmpty);
    presenter.updateFrequency(14050000);
    presenter.add(_tone(6000));
    expect(sink.frames, hasLength(1));
    presenter.reset();
    presenter.add(_tone(6000));
    expect(sink.frames, hasLength(1), reason: 'a replacement connection must provide its own dial');
  });

  test('stop and restart retain local choices and CAT but discard pending audio', () {
    start();
    presenter.set(const SpectrumRequest(spanHz: 5000, refLevelDb: 5));
    presenter.add(Uint8List.sublistView(_tone(1500), 0, 4099));
    presenter.stop();
    presenter.add(_tone(1500));
    expect(presenter.set(const SpectrumRequest(refLevelDb: 1)), isFalse);
    presenter.start();
    expect(sink.settings.last.spanHz, 5000);
    expect(sink.settings.last.refLevelDb, 5);
    expect(sink.settings.last.speed, SpectrumSpeed.fast);
    final tone = _tone(-1500);
    presenter.add(Uint8List.sublistView(tone, 0, 4096));
    expect(sink.frames, isEmpty);
    presenter.add(Uint8List.sublistView(tone, 4096));
    expect(_peakHz(sink.frames.single), closeTo(14048500, 1));
  });

  test('zoom stays inside the sampled band and does not relabel carriers', () {
    start();
    expect(presenter.capabilities.spansHz.last, 24000);
    expect(presenter.capabilities.modes, {SpectrumMode.center});
    expect(presenter.capabilities.canRecenter, isFalse);
    for (final span in [2500, 5000, 1000000]) {
      presenter.set(SpectrumRequest(spanHz: span));
      presenter.add(_tone(1500));
      expect(_peakHz(sink.frames.last), closeTo(14051500, 1));
    }
    final frame = sink.frames.last;
    expect(sink.settings.last.spanHz, 24000);
    expect(frame.lowHz, 14026000);
    expect(frame.highHz, 14073977, reason: 'the last FFT bin lies one bin below positive Nyquist');
  });

  test('invalid requests leave all local settings unchanged', () {
    start();
    final settings = sink.settings.last;
    for (final request in [
      const SpectrumRequest(mode: SpectrumMode.fixed, refLevelDb: 2),
      const SpectrumRequest(centerHz: 7100000),
      const SpectrumRequest(spanHz: 0),
      const SpectrumRequest(refLevelDb: double.nan),
    ]) {
      expect(presenter.set(request), isFalse);
      expect(sink.settings.last, settings);
    }
    presenter.set(const SpectrumRequest(refLevelDb: 100));
    expect(sink.settings.last.refLevelDb, 30);
    presenter.set(const SpectrumRequest(refLevelDb: -100));
    expect(sink.settings.last.refLevelDb, -30);
  });

  test('reference changes the drawing range without changing signal levels', () {
    start();
    final tone = _tone(6000);
    presenter.add(tone);
    final before = sink.frames.single;
    presenter.set(const SpectrumRequest(refLevelDb: 5));
    presenter.add(tone);
    final after = sink.frames.last;
    expect(after.levels, orderedEquals(before.levels));
    expect(after.floorDb, closeTo(before.floorDb - 5, 0.0001));
    expect(after.ceilingDb, closeTo(before.ceilingDb - 5, 0.0001));
  });

  test('speed is paced by samples without depending on audio callback timing', () {
    for (final (speed, expected) in [(SpectrumSpeed.slow, 8), (SpectrumSpeed.mid, 15), (SpectrumSpeed.fast, 24)]) {
      presenter = Kx3IqPresenter(sampleRate: 48000, sink: sink);
      start();
      presenter.set(SpectrumRequest(speed: speed));
      sink.frames.clear();
      presenter.add(_tone(6000, samples: 48000));
      expect(sink.frames, hasLength(expected), reason: 'one second of samples gives a reproducible cadence even in a single callback');
      presenter.stop();
    }
  });

  test('a stop in a sink callback discards the rest of a multi-sweep chunk', () {
    start();
    sink.onFrame = () {
      presenter.stop();
      presenter.start();
    };
    presenter.add(_tone(6000, samples: 10000));
    expect(sink.frames, hasLength(1));
    sink.onFrame = null;
    presenter.add(_tone(-6000));
    expect(sink.frames, hasLength(2));
    expect(_peakHz(sink.frames.last), closeTo(14044000, 1));
  });
}
