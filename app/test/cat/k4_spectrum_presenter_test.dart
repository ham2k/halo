// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum_presenter.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import '../support/fake_clock.dart';

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
    followFakeClock();
    sink = _Sink();
    presenter = K4SpectrumPresenter(sink: sink);
  });

  tearDown(() => presenter.stop());

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

  test('full 1024-bin remote and 2048-bin LAN sweeps preserve frequencies outside the center crop', () {
    fakeAsync((async) {
      presenter.start();
      expect(sink.settings.last.spanHz, isNull);
      for (final (count, highHz) in [(1024, 14092906), (2048, 14092953)]) {
        final levels = Float32List.fromList(List.filled(count, -120));
        levels[count ~/ 2 + count ~/ 4] = -25;
        presenter.add(centerHz: 14045000, sampleRateHz: 96000, levels: levels);
        final frame = sink.frames.last;
        final peak = frame.levels.indexOf(-25);
        expect(peak, isNonNegative, reason: 'a pan toward this carrier must have bins beyond the center crop');
        final peakHz = frame.lowHz + peak / (frame.levels.length - 1) * (frame.highHz - frame.lowHz);
        expect(peakHz, closeTo(14069000, 1));
        expect(frame.levels, hasLength(count));
        expect((frame.lowHz, frame.highHz), (13997000, highHz));
        final settings = sink.settings.last;
        expect((settings.lowHz, settings.highHz, settings.spanHz), (frame.lowHz, frame.highHz, 48000));
        expect(frame.ceilingDb - frame.floorDb, 80);
      }
      expect(sink.frames, hasLength(2), reason: 'a changed source size must be shown immediately');
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

  test('a hardware width request waits for PAN data and coalesces writes until coverage changes', () {
    fakeAsync((async) {
      final writes = <int>[];
      final levels = Float32List.fromList(List.filled(1024, -120));
      void sweep(int rate) => presenter.add(centerHz: 14045000, sampleRateHz: rate, levels: levels);
      bool widen(int width) => presenter.set(SpectrumRequest(hardwareWidthHz: width), writeHardwareSpan: writes.add);

      presenter.start();
      expect(presenter.capabilities.hardwareMaxWidthHz, 384000);
      expect(widen(50000), isFalse);
      sweep(24000);
      expect(presenter.capabilities.hardwareMaxWidthHz, 383625, reason: 'the zoom limit accounts for the first and last bin centres');
      expect(widen(20000), isFalse);
      expect(widen(30000), isTrue);
      expect(widen(35000), isFalse, reason: 'the first command already asks for a 48 kHz packet');
      expect(widen(50000), isTrue, reason: 'a larger request supersedes the earlier request before the first response');
      expect(writes, [25000, 40000]);
      expect(sink.frames.last.highHz - sink.frames.last.lowHz, 23977, reason: 'a command does not change what was received');
      sweep(48000);
      expect(widen(50000), isFalse, reason: 'the intermediate tier does not satisfy the pending request');
      async.elapse(const Duration(seconds: 1));
      expect(widen(50000), isTrue, reason: 'a later gesture can retry a command with no matching packet');
      sweep(96000);
      expect(widen(50000), isFalse);
      sweep(48000);
      expect(widen(50000), isTrue, reason: 'the previous widened packet cleared the pending request');
      presenter.reset();
      expect(widen(50000), isFalse, reason: 'no previous geometry can trigger commands after reconnect');
      sweep(48000);
      expect(widen(50000), isTrue, reason: 'the previous connection cannot suppress a fresh request');
      expect(writes, [25000, 40000, 40000, 40000, 40000]);
    });
  });

  test('a committed zoom can narrow the hardware, and only new PAN data changes the sweep', () {
    fakeAsync((async) {
      final writes = <int>[];
      final levels = Float32List.fromList(List.filled(1024, -120));
      void sweep(int rate) => presenter.add(centerHz: 14045000, sampleRateHz: rate, levels: levels);
      bool fit(int width, {bool narrow = false}) => presenter.set(
        SpectrumRequest(hardwareWidthHz: width, allowHardwareNarrowing: narrow),
        writeHardwareSpan: writes.add,
      );

      presenter.start();
      sweep(96000);
      expect(fit(20000), isFalse, reason: 'intermediate gesture updates cannot narrow');
      expect(fit(60000, narrow: true), isFalse, reason: 'a zoom that remains in the same tier needs no command');
      expect(fit(20000, narrow: true), isTrue);
      expect(writes, [15000]);
      sweep(96000);
      expect(sink.settings.last.spanHz, 48000);
      expect(fit(20000, narrow: true), isFalse, reason: 'an older wider packet does not acknowledge the downshift');
      async.elapse(const Duration(seconds: 1));
      expect(fit(20000, narrow: true), isTrue, reason: 'an unconfirmed downshift can be retried');
      sweep(24000);
      expect(sink.settings.last.spanHz, 12000);
      expect(sink.frames.last.levels, hasLength(1024));
      expect(sink.frames.last.highHz - sink.frames.last.lowHz, 23977);
      expect(fit(20000, narrow: true), isFalse);
      expect(writes, [15000, 15000]);
    });
  });

  test('widening during a pending downshift restores coverage even while wider packets are still arriving', () {
    fakeAsync((async) {
      final writes = <int>[];
      final levels = Float32List.fromList(List.filled(1024, -120));
      void sweep(int rate) => presenter.add(centerHz: 14045000, sampleRateHz: rate, levels: levels);
      bool fit(int width, {bool narrow = false}) => presenter.set(
        SpectrumRequest(hardwareWidthHz: width, allowHardwareNarrowing: narrow),
        writeHardwareSpan: writes.add,
      );

      presenter.start();
      sweep(96000);
      expect(fit(20000, narrow: true), isTrue);
      expect(fit(60000), isTrue, reason: 'the current frame covers the new viewport, but the pending downshift would crop it');
      expect(writes, [15000, 40000]);
      sweep(96000);
      sweep(24000);
      expect(fit(60000), isFalse, reason: 'an old packet at the restored width did not clear the correction');
      sweep(96000);
      sweep(24000);
      expect(fit(60000), isTrue, reason: 'the confirmed correction does not block a later widening');
    });
  });

  test('tier selection fits both rounded edges and can restore the exact former width', () {
    final writes = <int>[];
    final levels = Float32List.fromList(List.filled(2048, -120));
    void sweep(int rate) => presenter.add(centerHz: 14045000, sampleRateHz: rate, levels: levels);
    bool fit(int width, {bool narrow = false}) => presenter.set(
      SpectrumRequest(hardwareWidthHz: width, allowHardwareNarrowing: narrow),
      writeHardwareSpan: writes.add,
    );

    presenter.start();
    sweep(96000);
    expect(fit(47977, narrow: true), isFalse, reason: 'the lower tier has this width but cannot cover both edges about the current midpoint');
    expect(fit(47000, narrow: true), isTrue);
    sweep(48000);
    final oldWidth = sink.frames.last.highHz - sink.frames.last.lowHz;
    expect(oldWidth, 47977);
    expect(fit(20000, narrow: true), isTrue);
    sweep(24000);
    expect(fit(oldWidth), isTrue, reason: 'the exact old LAN width fits its original tier');
    expect(writes, [25000, 15000, 25000]);
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
