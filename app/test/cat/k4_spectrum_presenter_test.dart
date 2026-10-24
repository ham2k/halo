// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum_presenter.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

class _Sink implements SpectrumSink {
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  void Function()? onSettings;

  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) {
    this.settings.add(settings);
    onSettings?.call();
  }

  @override
  void reportSpectrumProblem(String? message) => fail('presentation does not own connection problems');
}

void main() {
  late _Sink sink;
  late K4SpectrumPresenter presenter;

  setUp(() {
    AppClock.followZoneClock = true;
    sink = _Sink();
    presenter = K4SpectrumPresenter(sink: sink);
  });

  tearDown(() {
    presenter.stop();
    AppClock.followZoneClock = false;
  });

  for (final (speed, expectedFrames) in [(SpectrumSpeed.slow, 15), (SpectrumSpeed.mid, 30), (SpectrumSpeed.fast, 60)]) {
    test('${speed.name} renders a distinct cadence from the native 15 Hz stream', () {
      fakeAsync((async) {
        presenter.start();
        presenter.set(SpectrumRequest(speed: speed));
        final levels = Float32List.fromList(List.filled(1024, -120));
        for (var i = 0; i < 60; i++) {
          presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: levels);
          async.elapse(const Duration(microseconds: 66667));
        }
        expect(sink.frames, hasLength(expectedFrames), reason: 'four seconds of native sweeps must give each speed a distinct waterfall cadence');
      });
    });
  }

  test('fast preserves every sweep delivered together in a network batch', () {
    fakeAsync((async) {
      presenter.start();
      final levels = Float32List.fromList(List.filled(1024, -120));
      for (var i = 0; i < 5; i++) {
        presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: levels);
      }
      expect(sink.frames, hasLength(5));
    });
  });

  test('a zoom clamped by a narrow stream comes back when the stream widens again', () {
    fakeAsync((async) {
      presenter.start();
      final levels = Float32List.fromList(List.filled(1024, -120));
      // Before any packet the width is unknown; the choice must not be
      // narrowed to the placeholder width the capabilities assume meanwhile.
      presenter.set(const SpectrumRequest(spanHz: 80000));
      presenter.add(centerHz: 14045000, sampleRateHz: 192000, levels: levels);
      expect(sink.settings.last.spanHz, 80000);
      presenter.add(centerHz: 14045000, sampleRateHz: 24000, levels: levels);
      expect(sink.settings.last.spanHz, 12000, reason: 'a narrower stream shows all it has');
      presenter.add(centerHz: 14045000, sampleRateHz: 192000, levels: levels);
      expect(sink.settings.last.spanHz, 80000, reason: 'narrowing the radio for a moment must not lose the operator\'s zoom');
    });
  });

  test('a 1024-bin remote sweep retains the same frequency scale as a 2048-bin LAN sweep', () {
    fakeAsync((async) {
      presenter.start();
      for (final count in [1024, 2048]) {
        final levels = Float32List.fromList(List.filled(count, -120));
        levels[count ~/ 2 + count ~/ 16] = -25;
        presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: levels);
        final frame = sink.frames.last;
        final peak = frame.levels.indexOf(-25);
        final peakHz = frame.lowHz + peak / (frame.levels.length - 1) * (frame.highHz - frame.lowHz);
        expect(peakHz, closeTo(14051000, 1));
        expect(frame.ceilingDb - frame.floorDb, 80);
      }
      expect(sink.frames, hasLength(2), reason: 'a changed source size must be shown immediately');
      expect(sink.frames[0].levels, hasLength(213));
      expect(sink.frames[1].levels, hasLength(427));
    });
  });

  test('closing a display ignores input and resetting preserves choices without stale frequency', () {
    fakeAsync((async) {
      final levels = Float32List.fromList(List.filled(1024, -120));
      presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: levels);
      expect(sink.frames, isEmpty);
      expect(presenter.set(const SpectrumRequest(refLevelDb: 5)), isFalse);
      presenter.start();
      presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: levels);
      presenter.set(const SpectrumRequest(spanHz: 5000, refLevelDb: 5, speed: SpectrumSpeed.slow));
      presenter.stop();
      presenter.add(centerHz: 7100000, sampleRateHz: 96000, levels: levels);
      expect(sink.frames, hasLength(1));
      presenter.start();
      expect(sink.settings.last.lowHz, isNull);
      expect(sink.settings.last.highHz, isNull);
      expect(sink.settings.last.spanHz, 5000);
      expect(sink.settings.last.refLevelDb, 5);
      expect(sink.settings.last.speed, SpectrumSpeed.slow);
      presenter.add(centerHz: 7100000, sampleRateHz: 96000, levels: levels);
      expect(sink.frames, hasLength(2));
      expect(sink.frames.last.floorDb, -135);
    });
  });

  test('invalid source metadata cannot replace a usable sweep or poison the noise average', () {
    fakeAsync((async) {
      presenter.start();
      final good = Float32List.fromList(List.filled(1024, -120));
      presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: good);
      final settings = sink.settings.last;
      presenter.add(centerHz: -1, sampleRateHz: 96000, levels: good);
      presenter.add(centerHz: 7100000, sampleRateHz: 1, levels: good);
      presenter.add(centerHz: 7100000, sampleRateHz: 96000, levels: Float32List(1));
      presenter.add(centerHz: 7100000, sampleRateHz: 96000, levels: Float32List.fromList([double.nan, -120]));
      expect(sink.frames, hasLength(1));
      expect(sink.settings.last, settings);
      async.elapse(const Duration(milliseconds: 100));
      presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: good);
      expect(sink.frames.last.floorDb, -130);
    });
  });

  test('a settings callback can stop or replace the source before its sweep is published', () {
    presenter.start();
    sink.onSettings = () {
      presenter.stop();
      presenter.start();
    };
    // The callback must not recursively restart itself while republishing.
    final callback = sink.onSettings!;
    sink.onSettings = () {
      sink.onSettings = null;
      callback();
    };
    presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: Float32List.fromList(List.filled(1024, -120)));
    expect(sink.frames, isEmpty);
    expect(sink.settings.last.lowHz, isNull);
  });
}
