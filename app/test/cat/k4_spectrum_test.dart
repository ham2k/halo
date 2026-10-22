// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum_codec.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';

class _Sink implements SpectrumSink {
  final frames = <SpectrumFrame>[];
  final settings = <SpectrumSettings>[];
  final problems = <String?>[];
  void Function(String?)? onProblem;

  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) => this.settings.add(settings);
  @override
  void reportSpectrumProblem(String? message) {
    problems.add(message);
    onProblem?.call(message);
  }
}

class _Connection implements EquipmentConnection {
  final incoming = StreamController<Uint8List>.broadcast(sync: true);
  final gone = Completer<void>();
  final sent = <List<int>>[];
  int closes = 0;

  @override
  Stream<Uint8List> get data => incoming.stream;
  @override
  Future<void> get closed => gone.future;
  @override
  void send(List<int> bytes) => sent.add(List.of(bytes));
  @override
  Future<void> close() async {
    closes++;
    if (!gone.isCompleted) gone.complete();
  }
}

class _Attempt {
  final Map<String, dynamic> target;
  final CatCancelToken cancel;
  final result = Completer<EquipmentConnection>();
  _Attempt(this.target, this.cancel);
}

class _Transport extends EquipmentTransport {
  final attempts = <_Attempt>[];
  @override
  String get key => 'test';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    final attempt = _Attempt(target, cancel);
    attempts.add(attempt);
    return attempt.result.future;
  }

  _Connection accept(FakeAsync async) {
    final connection = _Connection();
    attempts.last.result.complete(connection);
    async.flushMicrotasks();
    return connection;
  }
}

// Synthetic packets isolate presentation and lifecycle from signal conditions.
// Decoder tests separately pin the checksum against independent calculations
// and the unmodified captures under fixtures/k4-spectrum/.
Uint8List _packet({String pan = 'A', int rate = 96000, int center = 14045000, Map<int, int> bins = const {}}) {
  final bytes = Uint8List(k4SpectrumPacketLength);
  bytes.setRange(0, 7, [0xff, 0xfe, 1, 0, 2, 17, pan.codeUnitAt(0)]);
  bytes.setRange(7, 13, rate.toString().padLeft(6, '0').codeUnits);
  bytes.setRange(13, 24, center.toString().padLeft(11, '0').codeUnits);
  bytes.setRange(24, 29, '-1316'.codeUnits);
  bytes[63] = (-bytes.take(63).fold<int>(0, (sum, byte) => sum + byte)) & 0xff;
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < k4SpectrumBinCount; i++) {
    data.setInt16(64 + i * 2, bins[i] ?? -1200, Endian.big);
  }
  data.setUint16(4160, k4SpectrumCrc16(Uint8List.sublistView(bytes, 0, 4160)), Endian.big);
  return bytes;
}

void main() {
  late _Sink sink;
  late _Transport transport;
  late K4Spectrum spectrum;

  setUp(() {
    AppClock.followZoneClock = true;
    AppClock.instance.reset();
    sink = _Sink();
    transport = _Transport();
    spectrum = K4Spectrum(host: 'radio.example', sink: sink, transport: transport);
  });

  tearDown(() {
    spectrum.teardown();
    AppClock.instance.reset();
    AppClock.followZoneClock = false;
  });

  test('opening is demand-driven and cancellation closes a late socket without adopting it', () {
    fakeAsync((async) {
      expect(spectrum.set(const SpectrumRequest(spanHz: 5000)), isFalse);
      expect(transport.attempts, isEmpty);
      spectrum.start();
      spectrum.start();
      expect(transport.attempts, hasLength(1));
      expect(transport.attempts.single.target, {'host': 'radio.example', 'port': 9201});
      final first = transport.attempts.single;
      spectrum.stop();
      expect(first.cancel.isCancelled, isTrue);
      spectrum.start();
      final active = transport.accept(async);
      final late = _Connection();
      first.result.complete(late);
      async.flushMicrotasks();
      expect(late.closes, 1);
      late.incoming.add(_packet());
      expect(sink.frames, isEmpty);
      active.incoming.add(_packet());
      expect(sink.frames, hasLength(1));
      spectrum.teardown();
      async.flushMicrotasks();
      expect(active.closes, 1);
      expect(active.sent, isEmpty);
      spectrum.start();
      async.elapse(const Duration(seconds: 20));
      expect(transport.attempts, hasLength(2));
    });
  });

  test('the main pan retains its bin scale and actual frequencies when locally cropped', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      connection.incoming.add(_packet(bins: {811: -1500, 1152: -250, 1237: -1450}));
      final frame = sink.frames.single;
      expect(frame.levels, hasLength(427));
      expect((frame.lowHz, frame.highHz), (14035016, 14054984));
      expect(frame.levels.first, -150);
      expect(frame.levels.last, -145);
      final peak = frame.levels.indexOf(-25);
      final peakHz = frame.lowHz + peak / (frame.levels.length - 1) * (frame.highHz - frame.lowHz);
      // A stretched or reversed crop would put a click beside this carrier.
      expect(peakHz, closeTo(14051000, 0.5));
      expect((frame.floorDb, frame.ceilingDb), (-130, -50));
      expect(sink.settings.last.mode, SpectrumMode.fixed);
      expect(sink.settings.last.spanHz, 10000);
      expect(spectrum.capabilities.modes, {SpectrumMode.fixed});
      expect(spectrum.capabilities.canRecenter, isFalse);
      expect(spectrum.capabilities.spansHz, [1000, 2500, 5000, 10000, 20000, 40000, 48000]);
      expect(connection.sent, isEmpty);
    });
  });

  test('span, reference, and speed are local controls; an independent center cannot be moved', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      connection.incoming.add(_packet());
      expect(spectrum.set(const SpectrumRequest(spanHz: 999999, refLevelDb: 10.4, speed: SpectrumSpeed.slow)), isTrue);
      connection.incoming.add(_packet());
      final full = sink.frames.last;
      expect(full.levels, hasLength(2048));
      expect((full.lowHz, full.highHz), (13997000, 14092953));
      expect(full.levels.every((level) => level == -120), isTrue);
      expect((full.floorDb, full.ceilingDb), (-140, -60));
      expect(sink.settings.last.refLevelDb, 10);
      expect(sink.settings.last.speed, SpectrumSpeed.slow);
      expect(spectrum.set(const SpectrumRequest(centerHz: 14200000)), isFalse);
      expect(spectrum.set(const SpectrumRequest(mode: SpectrumMode.center)), isFalse);
      expect(spectrum.set(const SpectrumRequest(refLevelDb: double.nan)), isFalse);
      expect(spectrum.set(const SpectrumRequest(refLevelDb: 100)), isTrue);
      expect(sink.settings.last.refLevelDb, 30);
      connection.incoming.add(_packet(rate: 24000, center: 14036950));
      expect(spectrum.capabilities.spansHz, [1000, 2500, 5000, 10000, 12000]);
      expect(sink.settings.last.spanHz, 12000);
      expect((sink.frames.last.lowHz, sink.frames.last.highHz), (14024950, 14048938));
      expect(connection.sent, isEmpty, reason: 'zoom and level must not change the front-panel panadapter');
    });
  });

  test('Main-only demand ignores Sub and mini pans, and corrupt data recovers to the next main pan', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      for (final pan in ['B', 'Y', 'Z']) {
        connection.incoming.add(_packet(pan: pan));
      }
      expect(sink.frames, isEmpty);
      final corrupt = _packet()..[100] ^= 1;
      final valid = _packet(center: 7100000);
      final bytes = Uint8List.fromList([1, 2, 3, ...corrupt, ...valid]);
      for (var offset = 0; offset < bytes.length; offset += 257) {
        final end = offset + 257 < bytes.length ? offset + 257 : bytes.length;
        connection.incoming.add(Uint8List.sublistView(bytes, offset, end));
      }
      expect(sink.frames, hasLength(1));
      expect((sink.frames.single.lowHz, sink.frames.single.highHz), (7090016, 7109984));
    });
  });

  test('Sub and mini pans cannot mask a stalled Main spectrum stream or overlap retries', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      async.elapse(const Duration(seconds: 4));
      for (final pan in ['B', 'Y', 'Z']) {
        connection.incoming.add(_packet(pan: pan));
      }
      async.elapse(const Duration(milliseconds: 999));
      expect(sink.problems, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(sink.problems.last, t.settings.station.spectrumK4Unavailable);
      expect(connection.closes, 1);
      async.elapse(const Duration(milliseconds: 1999));
      expect(transport.attempts, hasLength(1));
      async.elapse(const Duration(milliseconds: 1));
      expect(transport.attempts, hasLength(2));
      final recovered = transport.accept(async);
      recovered.incoming.add(_packet());
      expect(sink.problems.last, isNull);
      expect(sink.frames, hasLength(1));
      spectrum.stop();
      async.elapse(const Duration(seconds: 20));
      expect(transport.attempts, hasLength(2));
    });
  });

  test('each valid main pan renews the watchdog, but a stream stalled after working reconnects', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      connection.incoming.add(_packet());
      async.elapse(const Duration(seconds: 4));
      connection.incoming.add(_packet());
      async.elapse(const Duration(seconds: 4));
      connection.incoming.add(_packet(pan: 'Y'));
      expect(sink.problems, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(sink.problems.last, t.settings.station.spectrumK4Unavailable);
      expect(connection.closes, 1);
      async.elapse(const Duration(seconds: 2));
      expect(transport.attempts, hasLength(2));
    });
  });

  test('a failed connect and an indefinitely pending connect both retry and remain cancellable', () {
    fakeAsync((async) {
      spectrum.start();
      transport.attempts.single.result.completeError(TimeoutException('unreachable'));
      async.flushMicrotasks();
      expect(sink.problems.last, t.settings.station.spectrumK4Unavailable);
      async.elapse(const Duration(seconds: 2));
      expect(transport.attempts, hasLength(2));
      final pending = transport.attempts.last;
      async.elapse(const Duration(seconds: 5));
      expect(pending.cancel.isCancelled, isTrue);
      spectrum.stop();
      async.elapse(const Duration(seconds: 20));
      expect(transport.attempts, hasLength(2));
      final late = _Connection();
      pending.result.complete(late);
      async.flushMicrotasks();
      expect(late.closes, 1);
    });
  });

  test('repeated failures back off to a minute, and a working stream starts the count over', () {
    fakeAsync((async) {
      spectrum.start();
      for (final seconds in [2, 4, 8, 16, 32, 60, 60]) {
        transport.attempts.last.result.completeError(TimeoutException('refused'));
        async.flushMicrotasks();
        final dialed = transport.attempts.length;
        async.elapse(Duration(seconds: seconds) - const Duration(milliseconds: 1));
        expect(transport.attempts, hasLength(dialed), reason: 'a refusing port must not be redialed every two seconds all session');
        async.elapse(const Duration(milliseconds: 1));
        expect(transport.attempts, hasLength(dialed + 1));
      }
      final connection = transport.accept(async);
      connection.incoming.add(_packet());
      connection.gone.complete();
      async.flushMicrotasks();
      final dialed = transport.attempts.length;
      async.elapse(const Duration(seconds: 2));
      expect(transport.attempts, hasLength(dialed + 1), reason: 'a link that worked again is retried promptly when it next drops');
      spectrum.stop();
    });
  });

  test('a closed socket retries once; stale completion and bytes cannot stop its replacement', () {
    fakeAsync((async) {
      spectrum.start();
      final first = transport.accept(async);
      first.gone.complete();
      async.flushMicrotasks();
      expect(sink.problems.last, t.settings.station.spectrumK4Unavailable);
      async.elapse(const Duration(seconds: 2));
      final second = transport.accept(async);
      first.incoming.add(_packet(center: 7100000));
      expect(sink.frames, isEmpty);
      second.incoming.add(_packet());
      expect(sink.problems.last, isNull);
      expect(sink.frames, hasLength(1));
      expect(second.closes, 0);
      expect(transport.attempts, hasLength(2));
    });
  });

  test('a display stopped by a problem callback neither retries nor publishes the recovering packet', () {
    fakeAsync((async) {
      spectrum.start();
      transport.accept(async);
      sink.onProblem = (_) => spectrum.stop();
      async.elapse(const Duration(seconds: 10));
      expect(transport.attempts, hasLength(1));

      sink.onProblem = null;
      spectrum.start();
      transport.accept(async);
      async.elapse(const Duration(seconds: 7));
      final recovered = transport.accept(async);
      final before = sink.settings.length;
      sink.onProblem = (problem) {
        if (problem == null) spectrum.stop();
      };
      recovered.incoming.add(_packet());
      expect(sink.frames, isEmpty);
      expect(sink.settings, hasLength(before));
      async.elapse(const Duration(seconds: 10));
      expect(transport.attempts, hasLength(3));
    });
  });

  test('teardown cannot reopen a connection while clearing its problem', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      async.elapse(const Duration(seconds: 5));
      expect(sink.problems.last, t.settings.station.spectrumK4Unavailable);
      expect(connection.closes, 1);
      sink.onProblem = (problem) {
        if (problem == null) spectrum.start();
      };

      spectrum.teardown();
      expect(sink.problems.last, isNull);
      expect(transport.attempts, hasLength(1), reason: 'a teardown callback must not create a replacement socket');
      async.elapse(const Duration(seconds: 20));
      expect(transport.attempts, hasLength(1));
      expect(async.pendingTimers, isEmpty, reason: 'teardown cancels the pending retry and cannot arm a new watchdog');
      expect(spectrum.set(const SpectrumRequest(spanHz: 5000)), isFalse);
    });
  });

  test('a reopened display waits for fresh frequency metadata and forgets partial bytes', () {
    fakeAsync((async) {
      spectrum.start();
      final first = transport.accept(async);
      first.incoming.add(_packet());
      final next = _packet(center: 7100000);
      first.incoming.add(Uint8List.sublistView(next, 0, 2000));
      spectrum.stop();
      spectrum.start();
      expect(sink.settings.last.lowHz, isNull);
      expect(sink.settings.last.highHz, isNull);
      final second = transport.accept(async);
      second.incoming.add(Uint8List.sublistView(next, 2000));
      expect(sink.frames, hasLength(1));
      second.incoming.add(_packet(center: 14200000));
      expect(sink.frames, hasLength(2));
      expect(sink.settings.last.lowHz, 14190016);
    });
  });

  test('the default preserves the native 15 Hz stream and travel cannot change frame pacing', () {
    fakeAsync((async) {
      spectrum.start();
      final connection = transport.accept(async);
      final packet = _packet();
      for (var i = 0; i < 10; i++) {
        connection.incoming.add(packet);
        async.elapse(const Duration(milliseconds: 66));
      }
      expect(sink.frames, hasLength(10), reason: 'rounding a 15 Hz limit to 67 ms would discard alternate sweeps');
      spectrum.set(const SpectrumRequest(speed: SpectrumSpeed.slow));
      connection.incoming.add(packet);
      final before = sink.frames.last.atMillis;
      final count = sink.frames.length;
      AppClock.instance.travel(delta: const Duration(days: 3), speed: 100);
      async.elapse(const Duration(milliseconds: 100));
      connection.incoming.add(packet);
      expect(sink.frames, hasLength(count));
      async.elapse(const Duration(milliseconds: 200));
      connection.incoming.add(packet);
      expect(sink.frames, hasLength(count + 1));
      expect(sink.frames.last.atMillis - before, greaterThan(const Duration(days: 3).inMilliseconds));
    });
  });
}
