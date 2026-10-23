// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/drivers/kx3_iq_spectrum.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transports/iq_audio.dart';

class _Sink implements SpectrumSink {
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  final problems = <String?>[];

  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) => this.settings.add(settings);
  @override
  void reportSpectrumProblem(String? message) => problems.add(message);
}

class _Capture implements IqAudioCapture {
  final opened = Completer<Stream<Uint8List>>();
  // A broadcast cancel returns the SDK's root-zone null future, whose
  // continuation fakeAsync cannot drain. Keep cleanup in this test's zone.
  late final incoming = StreamController<Uint8List>(
    sync: true,
    onCancel: () async {
      if (cancellation case final pending?) await pending.future;
    },
  );
  final starts = <({String deviceId, int sampleRate})>[];
  Completer<void>? cancellation;
  Completer<void>? release;
  int closes = 0;
  bool closed = false;

  @override
  Future<Stream<Uint8List>> start({required String deviceId, required int sampleRate}) {
    starts.add((deviceId: deviceId, sampleRate: sampleRate));
    return opened.future;
  }

  void accept(FakeAsync async) {
    opened.complete(incoming.stream);
    async.flushMicrotasks();
  }

  @override
  Future<void> dispose() async {
    closes++;
    if (release case final pending?) await pending.future;
    closed = true;
  }
}

class _Bench {
  final sink = _Sink();
  final captures = <_Capture>[];
  late final spectrum = Kx3IqSpectrum(
    deviceId: 'usb-stereo-input',
    sampleRate: 48000,
    sink: sink,
    captureFactory: () {
      final capture = _Capture();
      captures.add(capture);
      return capture;
    },
  );

  _Capture open(FakeAsync async) {
    spectrum.start();
    async.flushMicrotasks();
    final capture = captures.last;
    capture.accept(async);
    return capture;
  }

  void close(FakeAsync async) {
    spectrum.teardown();
    async.flushMicrotasks();
  }
}

// One default-speed FFT interval. Signal and bin accuracy live in the
// presenter tests; these samples exercise whether a live source may publish.
Uint8List _samples() => Uint8List(3200 * 4);

void main() {
  setUp(() {
    AppClock.followZoneClock = true;
    AppClock.instance.reset();
  });
  tearDown(() {
    AppClock.instance.reset();
    AppClock.followZoneClock = false;
  });

  test('capture opens once for display demand and releases when the display closes', () {
    fakeAsync((async) {
      final bench = _Bench();
      expect(bench.spectrum.set(const SpectrumRequest(spanHz: 5000)), isFalse);
      expect(bench.captures, isEmpty);
      bench.spectrum.start();
      bench.spectrum.start();
      async.flushMicrotasks();
      expect(bench.captures, hasLength(1));
      final capture = bench.captures.single;
      expect(capture.starts.single, (deviceId: 'usb-stereo-input', sampleRate: 48000));
      capture.accept(async);
      bench.spectrum.updateFrequency(14050000);
      capture.incoming.add(_samples());
      expect(bench.sink.frames, hasLength(1));
      expect(bench.sink.problems.last, isNull);

      bench.spectrum.stop();
      async.flushMicrotasks();
      expect(capture.closes, 1);
      expect(capture.incoming.hasListener, isFalse);
      capture.incoming.add(_samples());
      expect(bench.sink.frames, hasLength(1));
      expect(bench.spectrum.set(const SpectrumRequest(spanHz: 5000)), isFalse);
      async.elapse(const Duration(seconds: 10));
      expect(bench.sink.problems.last, isNull, reason: 'an intentionally closed display must cancel its watchdog');
      bench.close(async);
      expect(capture.closes, 1);
    });
  });

  test('closing before the queued open starts never requests microphone access', () {
    fakeAsync((async) {
      final bench = _Bench();
      bench.spectrum.start();
      bench.spectrum.stop();
      async.flushMicrotasks();
      expect(bench.captures, isEmpty);
      expect(bench.sink.problems.last, isNull);
      bench.close(async);
    });
  });

  test('a pending open is cancelled immediately and fully closed before a replacement starts', () {
    fakeAsync((async) {
      final bench = _Bench();
      bench.spectrum.updateFrequency(14050000);
      bench.spectrum.start();
      async.flushMicrotasks();
      final late = bench.captures.single..release = Completer<void>();
      bench.spectrum.stop();
      expect(late.closes, 1, reason: 'permission or device startup must see disposal before it can continue');
      bench.spectrum.start();
      async.flushMicrotasks();
      expect(bench.captures, hasLength(1));

      late.accept(async);
      expect(late.closes, 1);
      expect(late.closed, isFalse);
      expect(bench.captures, hasLength(1), reason: 'a late native close can tear down the replacement audio session');
      late.incoming.add(_samples());
      expect(bench.sink.frames, isEmpty);
      late.release!.complete();
      async.flushMicrotasks();
      expect(late.closed, isTrue);
      expect(bench.captures, hasLength(2));
      final current = bench.captures.last;
      current.accept(async);
      current.incoming.add(_samples());
      expect(bench.sink.frames, hasLength(1));
      expect(bench.sink.problems.last, isNull);
      bench.close(async);
      expect(current.closes, 1);
    });
  });

  test('a cancelled pending start may fail without reporting a stale problem or closing twice', () {
    fakeAsync((async) {
      final bench = _Bench();
      bench.spectrum.start();
      async.flushMicrotasks();
      final cancelled = bench.captures.single..release = Completer<void>();
      bench.spectrum.stop();
      bench.spectrum.start();
      expect(cancelled.closes, 1);
      final problems = bench.sink.problems.length;
      cancelled.opened.completeError(const IqAudioException(IqAudioFailure.deviceUnavailable));
      async.flushMicrotasks();
      expect(bench.sink.problems, hasLength(problems), reason: 'cancellation must not overwrite the replacement display status');
      expect(cancelled.closes, 1);
      expect(bench.captures, hasLength(1), reason: 'a failed start still owns its pending native disposal');
      cancelled.release!.complete();
      async.flushMicrotasks();
      expect(bench.captures, hasLength(2));
      bench.captures.last.accept(async);
      bench.close(async);
    });
  });

  test('an active capture finishes asynchronous disposal before reopening', () {
    fakeAsync((async) {
      final bench = _Bench();
      final first = bench.open(async)..release = Completer<void>();
      bench.spectrum.stop();
      bench.spectrum.start();
      async.flushMicrotasks();
      expect(first.closes, 1);
      expect(first.closed, isFalse);
      expect(bench.captures, hasLength(1));
      first.release!.complete();
      async.flushMicrotasks();
      expect(first.closed, isTrue);
      expect(bench.captures, hasLength(2));
      bench.captures.last.accept(async);
      bench.close(async);
    });
  });

  test('subscription cleanup finishes before the device closes or replacement opens', () {
    fakeAsync((async) {
      final bench = _Bench();
      final first = bench.open(async)..cancellation = Completer<void>();
      bench.spectrum.stop();
      bench.spectrum.start();
      async.flushMicrotasks();
      expect(first.incoming.hasListener, isFalse);
      expect(first.closes, 0);
      expect(bench.captures, hasLength(1));
      first.incoming.add(_samples());
      expect(bench.sink.frames, isEmpty);
      first.cancellation!.complete();
      async.flushMicrotasks();
      expect(first.closes, 1);
      expect(first.closed, isTrue);
      expect(bench.captures, hasLength(2));
      bench.captures.last.accept(async);
      bench.close(async);
    });
  });

  test('teardown closes a late open and cannot be revived by further demand', () {
    fakeAsync((async) {
      final bench = _Bench();
      bench.spectrum.start();
      async.flushMicrotasks();
      final capture = bench.captures.single;
      bench.close(async);
      expect(capture.closes, 1, reason: 'teardown must cancel startup without waiting for the permission decision');
      capture.accept(async);
      expect(capture.closes, 1);
      expect(capture.incoming.hasListener, isFalse);
      bench.spectrum.start();
      capture.incoming.add(_samples());
      async.elapse(const Duration(seconds: 20));
      expect(bench.captures, hasLength(1));
      expect(bench.sink.frames, isEmpty);
      expect(bench.sink.problems.last, isNull);
    });
  });

  test('audio waits for a CAT dial before publishing and retains that dial across display closure', () {
    fakeAsync((async) {
      final bench = _Bench();
      final capture = bench.open(async);
      capture.incoming.add(_samples());
      expect(bench.sink.frames, isEmpty);
      expect(bench.sink.problems.last, t.settings.station.kx3IqWaitingForRadio);
      bench.spectrum.updateFrequency(7100000);
      capture.incoming.add(_samples());
      expect(bench.sink.frames, hasLength(1));
      expect((bench.sink.frames.single.lowHz + bench.sink.frames.single.highHz) / 2, 7100000);
      expect(bench.sink.problems.last, isNull);
      bench.spectrum.stop();
      async.flushMicrotasks();
      final reopened = bench.open(async);
      reopened.incoming.add(_samples());
      expect(bench.sink.frames, hasLength(2));
      expect((bench.sink.frames.last.lowHz + bench.sink.frames.last.highHz) / 2, 7100000);
      bench.close(async);
    });
  });

  test('lost audio expires on elapsed time and requires explicit renewed demand', () {
    fakeAsync((async) {
      final bench = _Bench();
      bench.spectrum.updateFrequency(14050000);
      final capture = bench.open(async);
      async.elapse(const Duration(seconds: 4));
      capture.incoming.add(_samples());
      AppClock.instance.travel(delta: const Duration(days: 10));
      async.elapse(const Duration(seconds: 4));
      expect(capture.closes, 0, reason: 'valid audio resets the timeout and developer time travel cannot expire it');
      capture.incoming.add(Uint8List(0));
      async.elapse(const Duration(seconds: 2));
      expect(capture.closes, 1, reason: 'empty callbacks are not evidence of live audio');
      expect(bench.sink.problems.last, t.settings.station.kx3IqFailed);
      final frames = bench.sink.frames.length;
      capture.incoming.add(_samples());
      expect(bench.sink.frames, hasLength(frames));
      bench.spectrum.start();
      async.elapse(const Duration(seconds: 10));
      expect(bench.captures, hasLength(1), reason: 'a failure must not create a permission or device retry loop');
      bench.spectrum.stop();
      final retry = bench.open(async);
      retry.incoming.add(_samples());
      expect(bench.sink.problems.last, isNull);
      bench.close(async);
    });
  });

  test('an ended input releases capture and surfaces loss without publishing stale data', () {
    fakeAsync((async) {
      final bench = _Bench();
      final capture = bench.open(async);
      capture.incoming.close();
      async.flushMicrotasks();
      expect(capture.closes, 1);
      expect(bench.sink.problems.last, t.settings.station.kx3IqFailed);
      async.elapse(const Duration(seconds: 10));
      expect(capture.closes, 1);
      expect(bench.captures, hasLength(1));
      bench.close(async);
    });
  });

  test('a capture factory failure does not poison the queue for a later explicit retry', () {
    fakeAsync((async) {
      final sink = _Sink();
      final capture = _Capture();
      var attempts = 0;
      final spectrum = Kx3IqSpectrum(
        deviceId: 'usb-stereo-input',
        sampleRate: 48000,
        sink: sink,
        captureFactory: () {
          if (++attempts == 1) throw const IqAudioException(IqAudioFailure.unsupported);
          return capture;
        },
      );
      spectrum.start();
      async.flushMicrotasks();
      expect(sink.problems.last, t.settings.station.kx3IqUnsupported);
      spectrum.stop();
      spectrum.start();
      async.flushMicrotasks();
      expect(attempts, 2);
      capture.accept(async);
      spectrum.updateFrequency(14050000);
      capture.incoming.add(_samples());
      expect(sink.frames, hasLength(1));
      expect(sink.problems.last, isNull);
      spectrum.teardown();
      async.flushMicrotasks();
      expect(capture.closes, 1);
    });
  });

  for (final (failure, message) in [
    (IqAudioFailure.permissionDenied, () => t.settings.station.kx3IqPermissionDenied),
    (IqAudioFailure.deviceUnavailable, () => t.settings.station.kx3IqDeviceUnavailable),
    (IqAudioFailure.unsupported, () => t.settings.station.kx3IqUnsupported),
    (IqAudioFailure.invalidFormat, () => t.settings.station.kx3IqInvalidFormat),
    (IqAudioFailure.sampleRateMismatch, () => t.settings.station.kx3IqSampleRateMismatch),
  ]) {
    test('${failure.name} releases the failed open and reports an actionable spectrum problem', () {
      fakeAsync((async) {
        final bench = _Bench();
        bench.spectrum.start();
        async.flushMicrotasks();
        final capture = bench.captures.single;
        capture.opened.completeError(IqAudioException(failure));
        async.flushMicrotasks();
        expect(capture.closes, 1);
        expect(bench.sink.problems.last, message());
        async.elapse(const Duration(seconds: 20));
        expect(bench.captures, hasLength(1));
        bench.close(async);
      });
    });
  }
}
