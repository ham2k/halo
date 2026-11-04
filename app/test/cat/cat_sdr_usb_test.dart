// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SDR receiver on USB: what it is told, where a signal it samples is
// drawn, and when its connection is given up. The receiver here is a fake
// whose ring holds a tone; the ring itself is the native library's, tested
// in packages/halo_sdr_usb. A session that read the wrong stretch of the
// ring — or labelled it where the receiver was not tuned — would draw the
// carrier somewhere else.

import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_sdr_usb/halo_sdr_usb.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/sdr_spectrum.dart';
import 'package:ham2k_logger/services/cat/drivers/sdr_usb_driver.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/sdr_usb_transport.dart';

/// A receiver whose ring holds a tone [toneHz] above wherever it is tuned.
class _Receiver implements SdrUsbDevice {
  @override
  final SdrUsbKind kind;
  @override
  final List<int> sampleRates;
  @override
  final int minFrequencyHz;
  @override
  final int maxFrequencyHz;
  @override
  final int capacity = 1 << 20;

  _Receiver({this.kind = SdrUsbKind.airspyHf, this.sampleRates = const [192000, 384000, 768000], this.minFrequencyHz = 9000, this.maxFrequencyHz = 260000000});

  int toneHz = 10000;
  int rate = 0;
  int? frequency;
  Object? gain = 'never set';
  bool started = false;
  SdrUsbStreaming? failed;
  final reads = <int>[];

  @override
  int written = 0;

  /// What the receiver samples in [time].
  void sample(Duration time) => written += rate * time.inMicroseconds ~/ Duration.microsecondsPerSecond;

  @override
  void setSampleRate(int rate) => this.rate = rate;

  @override
  void setFrequency(int hz) => frequency = hz;

  @override
  void setGain(int? step) => gain = step;

  /// Set, the next start fails.
  bool refuseStart = false;

  @override
  Future<bool> start() async {
    if (refuseStart) return false;
    started = true;
    return true;
  }

  @override
  Future<void> stop() async => started = false;

  @override
  SdrUsbStreaming get streaming => failed ?? (started ? SdrUsbStreaming.streaming : SdrUsbStreaming.stopped);

  @override
  int read(int from, int count, Float32List into, int at) {
    reads.add(from);
    if (from < written - capacity || from >= written) return 0;
    final n = math.min(count, written - from);
    for (var k = 0; k < n; k++) {
      final phase = 2 * math.pi * toneHz * (from + k) / rate;
      into[at + 2 * k] = math.cos(phase);
      into[at + 2 * k + 1] = math.sin(phase);
    }
    return n;
  }

  @override
  Future<void> close() async {}
}

class _Sink implements EquipmentSink, SpectrumSink, SdrSink {
  final frames = <SpectrumFrame>[];
  final spectrumProblems = <String?>[];
  final drops = <String>[];
  @override
  double? linkedVfoHz;
  @override
  SdrUsbDevice? usbDevice;

  _Sink(this.usbDevice);

  @override
  void reportSpectrum(SpectrumFrame frame) => frames.add(frame);
  @override
  void reportSpectrumSettings(SpectrumSettings settings) {}
  @override
  void reportSpectrumProblem(String? message) => spectrumProblems.add(message);
  @override
  void dropConnection(String why) => drops.add(why);
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportAlive() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

double _peakHz(SpectrumFrame frame) {
  var best = 0;
  for (var i = 1; i < frame.levels.length; i++) {
    if (frame.levels[i] > frame.levels[best]) best = i;
  }
  final step = (frame.highHz - frame.lowHz) / frame.levels.length;
  return frame.lowHz + (best + 0.5) * step;
}

/// A session on [receiver], started, with the dial at [dialHz].
(SdrUsbSession, _Sink) _streaming(_Receiver receiver, {double dialHz = 7100000, Map<String, dynamic> config = const {}, bool gainStep = false}) {
  final sink = _Sink(receiver)..linkedVfoHz = dialHz;
  final session = SdrUsbDriver(gainStep: gainStep).createSession(sink, config) as SdrUsbSession;
  session.startUpdates();
  session.startSpectrum();
  return (session, sink);
}

void main() {
  test("a carrier the receiver hears is drawn where it is, at the radio's dial", () {
    fakeAsync((async) {
      final receiver = _Receiver();
      final (session, sink) = _streaming(receiver);
      expect(receiver.started, isTrue);
      expect(receiver.frequency, 7100000, reason: 'tuned to the dial, its own antenna');
      expect(receiver.sampleRates, contains(receiver.rate));

      for (var i = 0; i < 40; i++) {
        receiver.sample(sdrUsbPollInterval);
        async.elapse(sdrUsbPollInterval);
      }
      expect(sink.frames, isNotEmpty);
      final frame = sink.frames.last;
      final bin = (frame.highHz - frame.lowHz) / frame.levels.length;
      expect(_peakHz(frame), closeTo(7110000, 2 * bin));
      expect(sink.drops, isEmpty);
      session.teardown();
    });
  });

  test('a reader fallen behind takes only the newest of the ring, never what it has overwritten', () {
    fakeAsync((async) {
      final receiver = _Receiver();
      final (session, _) = _streaming(receiver);
      async.flushMicrotasks();
      // A stall: a few seconds' worth arrive at once, more than the ring holds.
      receiver.written += receiver.capacity * 3;
      async.elapse(sdrUsbPollInterval);
      expect(receiver.reads, isNotEmpty);
      expect(receiver.reads.reduce(math.min), greaterThanOrEqualTo(receiver.written - receiver.capacity ~/ 2));
      session.teardown();
    });
  });

  test('a receiver that stops, or goes quiet, is dropped with why, to be opened again', () {
    fakeAsync((async) {
      final unplugged = _Receiver();
      final (session, sink) = _streaming(unplugged);
      unplugged.failed = SdrUsbStreaming.lost;
      async.elapse(sdrUsbPollInterval);
      expect(sink.drops, [t.settings.station.sdrUsbLost], reason: 'reopened, a receiver plugged back in is picked up without the operator');
      async.elapse(sdrUsbPollInterval * 10);
      expect(sink.drops, hasLength(1));
      session.teardown();

      final silent = _Receiver();
      final (other, quiet) = _streaming(silent);
      async.elapse(sdrUsbPollInterval * 39);
      expect(quiet.drops, isEmpty, reason: 'a moment without samples is a USB hiccup');
      async.elapse(sdrUsbPollInterval * 2);
      expect(quiet.drops, [t.settings.station.sdrUsbLost], reason: 'or the display waits forever on a receiver that sends nothing');
      other.teardown();
    });
  });

  test('a receiver that will not start is dropped with why; one stopped while starting never begins reading', () {
    fakeAsync((async) {
      final refusing = _Receiver()..refuseStart = true;
      final (session, sink) = _streaming(refusing);
      async.flushMicrotasks();
      expect(sink.drops, [t.settings.station.sdrUsbLost]);
      session.teardown();

      // Its start runs off the UI isolate: the display can leave before it
      // finishes, and a read loop begun then would run with nothing drawing.
      final receiver = _Receiver();
      final (other, stopped) = _streaming(receiver);
      other.stopSpectrum();
      async.flushMicrotasks();
      receiver.sample(const Duration(seconds: 1));
      async.elapse(sdrUsbPollInterval * 4);
      expect(receiver.reads, isEmpty);
      expect(stopped.drops, isEmpty, reason: 'nor taken for a receiver gone: it was stopped');
    });
  });

  test('stopping the display stops the receiver and reads no more', () {
    fakeAsync((async) {
      final receiver = _Receiver();
      final (session, _) = _streaming(receiver);
      session.stopSpectrum();
      expect(receiver.started, isFalse, reason: 'a receiver streaming to nothing heats the CPU for nothing');
      final reads = receiver.reads.length;
      receiver.sample(const Duration(seconds: 1));
      async.elapse(sdrUsbPollInterval * 4);
      expect(receiver.reads, hasLength(reads));
    });
  });

  test("gain is the operator's step where the receiver takes one, and its own AGC otherwise", () {
    fakeAsync((async) {
      final airspy = _Receiver(kind: SdrUsbKind.airspy, sampleRates: const [2500000, 10000000], minFrequencyHz: 24000000, maxFrequencyHz: 1800000000);
      _streaming(airspy, dialHz: 144200000, config: {sdrUsbGainConfigKey: 14}, gainStep: true).$1.teardown();
      expect(airspy.gain, 14);

      final hf = _Receiver();
      _streaming(hf, config: {sdrUsbGainConfigKey: 14}).$1.teardown();
      expect(hf.gain, isNull, reason: 'an HF+ is left on its AGC: a step it does not have is not passed on');
    });
  });

  test('a dial the receiver cannot reach is said so, not drawn as the band it can', () {
    fakeAsync((async) {
      // An HF+ tops out at 260 MHz.
      final receiver = _Receiver();
      final (session, sink) = _streaming(receiver, dialHz: 432100000);
      for (var i = 0; i < 20; i++) {
        receiver.sample(sdrUsbPollInterval);
        async.elapse(sdrUsbPollInterval);
      }
      expect(sink.frames, isEmpty);
      expect(sink.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);
      session.teardown();
    });
  });

  test("a dial in an HF+'s deaf stretch between its ports is out of reach, not drawn over noise", () {
    fakeAsync((async) {
      // 6 m: the HF port ends at 31 MHz and the VHF one starts at 60.
      final receiver = _Receiver();
      final (session, sink) = _streaming(receiver, dialHz: 50125000);
      for (var i = 0; i < 20; i++) {
        receiver.sample(sdrUsbPollInterval);
        async.elapse(sdrUsbPollInterval);
      }
      expect(sink.frames, isEmpty);
      expect(sink.spectrumProblems.last, t.settings.station.spectrumSdrUnreachable);
      session.teardown();
    });
  });

  test('after a narrower rate, nothing sampled at the wider one is read', () {
    fakeAsync((async) {
      final receiver = _Receiver();
      final (session, _) = _streaming(receiver);
      final spans = session.spectrumCapabilities.spansHz;
      session.setSpectrum(SpectrumRequest(spanHz: spans.last));
      for (var i = 0; i < 10; i++) {
        receiver.sample(sdrUsbPollInterval);
        async.elapse(sdrUsbPollInterval);
      }
      // Sampled at the widest rate since the last read, then narrowed: the
      // settle is counted at the narrow rate, and is shorter than this.
      receiver.sample(sdrUsbPollInterval);
      final before = receiver.written;
      session.setSpectrum(SpectrumRequest(spanHz: spans.first));
      receiver.reads.clear();
      for (var i = 0; i < 10; i++) {
        receiver.sample(sdrUsbPollInterval);
        async.elapse(sdrUsbPollInterval);
      }
      expect(receiver.reads, isNotEmpty);
      expect(receiver.reads.reduce(math.min), greaterThanOrEqualTo(before), reason: 'transformed at the new rate, they draw smeared across the sweep');
      session.teardown();
    });
  });

  group('the transport', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is offered on the desktop only', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(const SdrUsbTransport().isSupportedOnThisPlatform, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(const SdrUsbTransport().isSupportedOnThisPlatform, isFalse);
    });

    test('says what to do instead when a receiver cannot be opened here, rather than an error of its own', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      Future<Object?> failure(String kind) async {
        try {
          await const SdrUsbTransport().connect({sdrUsbKindConfigKey: kind}, cancel: CatCancelToken());
        } catch (e) {
          return e;
        }
        return null;
      }

      final mac = await failure('sdrplay');
      expect(mac, isA<CatUnreachable>(), reason: "the receiver's doing, not a fault to report");
      expect('$mac', t.settings.station.sdrUsbSdrplayOnMac);

      // The test host's library has no USB receivers built in.
      expect('${await failure('airspy')}', t.settings.station.sdrUsbUnavailable);
    });
  });
}
