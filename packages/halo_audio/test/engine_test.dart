// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The live engine (docs/design/audio.md). Most of it runs on simulated time:
// a pushed source and a pulled sink, driven tick by tick from here, stand in
// for two endpoints on independent clocks, so minutes of drift and jitter
// play out in a second and the same way every run.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';

const rate = AudioEngine.rate;

const readFrames = 240; // the sink reads 5 ms at a time, a device's period
const readMs = 5;

/// A pushed source and a pulled sink on independent clocks, driven tick by
/// tick. The writer's clock runs [ppm] fast against the reader's and pushes
/// packets of [packet] frames (a Flex's 128 at 24 kHz); time carries on from
/// one [run] to the next, as it does for real endpoints.
class Sim {
  Sim(this.source, this.sink, this.route, {this.ppm = 0, this.packet = 256});

  final AudioEndpoint source;
  final AudioEndpoint sink;
  final AudioRoute route;
  final double ppm;
  final int packet;
  int _tick = 0;
  int _written = 0;

  /// The route's statistics after each tick of every run so far.
  final stats = <AudioRouteStats>[];

  /// The route's statistics at [seconds] into the simulation.
  AudioRouteStats at(double seconds) => stats[(seconds * 1000 / readMs).round() - 1];

  /// Runs on for [seconds], the writer pushing [signal] (0.25 without one).
  /// Through each of [stalls] (start, length, in seconds since the
  /// simulation began) it pushes nothing, then everything it held back at
  /// once, as a socket delivers what queued behind a Wi-Fi burst. Through
  /// each of [losses] it pushes nothing, and what it held back never comes.
  /// Returns the sink's output.
  List<double> run(double seconds, {double Function(int frame)? signal, List<(double, double)> stalls = const [], List<(double, double)> losses = const []}) {
    final output = <double>[];
    final writerRate = rate * (1 + ppm * 1e-6);
    final end = _tick + (seconds * 1000 / readMs).round();
    for (; _tick < end; _tick++) {
      final now = _tick * readMs / 1000;
      final stalled = stalls.any((s) => now >= s.$1 && now < s.$1 + s.$2);
      final owed = (now * writerRate).floor();
      if (losses.any((s) => now >= s.$1 && now < s.$1 + s.$2)) {
        _written = owed;
      } else if (!stalled) {
        while (owed - _written >= packet) {
          final samples = Float32List(packet * source.channels);
          for (var i = 0; i < packet; i++) {
            final v = signal?.call(_written + i) ?? 0.25;
            for (var c = 0; c < source.channels; c++) {
              samples[i * source.channels + c] = v;
            }
          }
          source.push(samples);
          _written += packet;
        }
      }
      output.addAll(sink.pull(readFrames));
      stats.add(route.stats);
    }
    return output;
  }
}

/// A pushed mono source routed to a pulled mono sink.
Sim simulation(AudioEngine engine, {double ppm = 0, Duration max = const Duration(milliseconds: 200), bool gated = false, int sinkChannels = 1}) {
  final source = engine.addPushed();
  final sink = engine.addPulled(gated: gated, channels: sinkChannels);
  return Sim(source, sink, engine.connect(source, sink, max: max), ppm: ppm);
}

double sine(int frame) => 0.5 * math.sin(2 * math.pi * 1000 * frame / rate);

/// The largest change between one sample and the next in [samples].
double largestStep(List<double> samples) {
  var largest = 0.0;
  for (var i = 1; i < samples.length; i++) {
    largest = math.max(largest, (samples[i] - samples[i - 1]).abs());
  }
  return largest;
}

void main() {
  late AudioEngine engine;

  setUp(() => engine = AudioEngine());
  tearDown(() => engine.close());

  group('the clock bridge', () {
    // Two crystals a few hundred ppm apart: without the resampler's steering
    // the slow writer drains the ring and the fast one floods it, a few
    // milliseconds a minute — a dropout, or a delay nobody chose.
    for (final ppm in [-200.0, 200.0]) {
      test('holds its depth over two minutes against a writer ${ppm > 0 ? 'fast' : 'slow'} by ${ppm.abs()} ppm', () {
        final sim = simulation(engine, ppm: ppm)..run(120);
        final end = sim.stats.last;
        expect(end.underruns, 0, reason: '$end');
        expect(end.skips, 0, reason: '$end');
        expect(end.ratioPpm, closeTo(ppm, 40), reason: 'the reader ends up consuming at the writer\'s rate: $end');
        // Steering by the depth's error alone holds it off its target by the
        // drift — 2 ms at 200 ppm, the whole safety margin — until the drift
        // is learnt.
        expect(end.depthMs, closeTo(end.targetMs, 0.5), reason: '$end');
        for (final seconds in [30.0, 60.0, 90.0, 120.0]) {
          expect(sim.at(seconds).depthMs, lessThan(12), reason: 'at $seconds s: ${sim.at(seconds)}');
        }
      });
    }

    test('passes a tone through clean while it corrects for drift', () {
      // A click is a jump no 1 kHz tone at 0.5 makes from one sample to the
      // next: a cut, an underrun, or an interpolator that is wrong.
      final sim = simulation(engine, ppm: 300)..run(2, signal: sine);
      final output = sim.run(28, signal: sine);
      expect(largestStep(output), lessThan(0.5 * 2 * math.pi * 1000 / rate * 1.02));
      expect(output.reduce(math.max), closeTo(0.5, 0.01));
      expect(sim.stats.last.underruns, 0);
    });

    test('a stall the writer catches up on raises the depth to cover the next one, and is forgotten later', () {
      // Wi-Fi power save holds packets back and then delivers them at once.
      // The first such stall runs the ring dry; the same stall again must
      // not, and once they stop the delay they cost must drain away.
      final sim = simulation(engine)
        ..run(
          120,
          stalls: [
            for (final at in [10.0, 15.0, 20.0, 25.0]) (at, 0.06),
          ],
        );
      expect(sim.at(12).underruns, 1, reason: 'the first stall: ${sim.at(12)}');
      expect(sim.at(30).underruns, 1, reason: 'the repeats: ${sim.at(30)}');
      expect(sim.at(30).depthMs, greaterThan(60), reason: '${sim.at(30)}');
      expect(sim.at(120).depthMs, lessThan(15), reason: 'ninety seconds without one: ${sim.at(120)}');
      expect(sim.stats.last.underruns, 1);
    });

    test('run dry, it fills again to the depth its stalls called for, not to its start', () {
      // A Wi-Fi access point drops what it held through a long stall, and
      // nothing catches the ring up. Refilled only to its start, it grows
      // back at the steering's 2 ms a second and runs dry at every stall.
      final sim = simulation(engine, max: const Duration(milliseconds: 500))..run(17, losses: [(10.0, 0.1), (15.0, 0.1)]);
      expect(sim.at(12).underruns, 1, reason: '${sim.at(12)}');
      expect(sim.at(17).underruns, 2, reason: '${sim.at(17)}');
      expect(sim.at(17).targetMs, inInclusiveRange(100, 160), reason: 'the wait to refill is no stall: ${sim.at(17)}');
      expect(sim.at(17).depthMs, greaterThan(sim.at(17).targetMs * 0.8), reason: 'refilled to the target: ${sim.at(17)}');
    });

    test('a writer far ahead is cut back to its target without a click', () {
      final sim = simulation(engine, max: const Duration(milliseconds: 40))..run(1, signal: sine);
      // A burst of 100 ms on top of a running stream: more than the maximum.
      final output = sim.run(2, signal: sine, stalls: [(1.0, 0.1)]);
      expect(sim.stats.last.skips, greaterThanOrEqualTo(1), reason: '${sim.stats.last}');
      expect(sim.stats.last.depthMs, lessThan(40));
      // The cut fades out and in over a millisecond, never jumps.
      expect(largestStep(output), lessThan(0.5 * 2 * math.pi * 1000 / rate + 0.5 / 48 + 0.001));
    });
    test('a burst bigger than the ring is dropped without a click', () {
      // The writer finds the ring full, and what it cannot write leaves a
      // seam in the stream: faded on both sides, it is a dip, not a click.
      final sim = simulation(engine, max: const Duration(milliseconds: 40))..run(1, signal: sine);
      final output = sim.run(3, signal: sine, stalls: [(1.0, 0.5)]);
      expect(sim.stats.last.dropped, greaterThan(0), reason: '${sim.stats.last}');
      expect(largestStep(output), lessThan(0.5 * 2 * math.pi * 1000 / rate + 0.5 / 48 + 0.001));
    });

    test('an empty write between an overflow and the next write leaves the seam faded', () {
      // The writer fades in the first write after a seam; an empty one in
      // between must not count as that write, or the next starts at full
      // level against the faded-out end.
      final source = engine.addPushed();
      final sink = engine.addPulled();
      final route = engine.connect(source, sink, max: const Duration(milliseconds: 40));
      final level = Float32List(480)..fillRange(0, 480, 0.5);
      for (var i = 0; i < 40; i++) {
        source.push(level); // far more than the ring holds: the last ends in a seam
      }
      // Cut back to its target, the seam still ahead in the ring, and read
      // across it without running dry.
      final output = <double>[...sink.pull(480)];
      source.push(Float32List(0));
      for (var i = 0; i < 20; i++) {
        source.push(level);
        output.addAll(sink.pull(480));
      }
      expect(route.stats.underruns, 0, reason: '${route.stats}');
      // The writer's fade may meet the reader's own around its cut: two
      // 1 ms ramps at once, still nothing like the jump to full level.
      expect(largestStep(output), lessThan(0.5 * 2 / 48 + 1e-3));
    });

    test('honours a long maximum rather than cutting a burst short of it', () {
      final source = engine.addPushed();
      final sink = engine.addPulled();
      final route = engine.connect(source, sink, max: const Duration(minutes: 1));
      source.push(Float32List(48000)..fillRange(0, 48000, 0.25)); // a second at once
      sink.pull(4800);
      expect(route.stats.skips, 0, reason: '${route.stats}');
      expect(route.stats.depthMs, greaterThan(800));
    });
  });

  group('the transmit gate', () {
    test('passes nothing while shut, whatever the route says', () {
      final sim = simulation(engine, gated: true);
      expect(sim.run(1).every((s) => s == 0), isTrue);
    });

    test('opening drops what was said before the key and ramps in; shutting ramps out', () {
      final sim = simulation(engine, gated: true);
      // Said before the key, at 0.9: none of it may go out after it.
      sim.run(0.5, signal: (_) => 0.9);
      sim.sink.gate = true;
      final keyed = sim.run(0.5, signal: (_) => 0.1);
      expect(keyed.reduce(math.max), closeTo(0.1, 1e-6), reason: 'only what was said after the key');
      expect(largestStep(keyed), lessThan(0.1 / 48 + 1e-6), reason: 'ramped, never stepped');
      sim.sink.gate = false;
      final unkeyed = sim.run(0.1, signal: (_) => 0.1);
      expect(largestStep(unkeyed), lessThanOrEqualTo(0.1 / 240 + 1e-6));
      expect(unkeyed.skip(240).every((s) => s == 0), isTrue, reason: 'silent within 5 ms');
    });
  });

  group('mixing', () {
    test('a mono source pans into a stereo sink, ramped', () {
      final sim = simulation(engine, sinkChannels: 2)..run(0.2);
      sim.route.setGain(1, 0);
      final output = sim.run(0.2);
      final left = [for (var i = 0; i < output.length; i += 2) output[i]];
      final right = [for (var i = 1; i < output.length; i += 2) output[i]];
      expect(left.every((s) => (s - 0.25).abs() < 1e-6), isTrue);
      expect(largestStep(right), lessThanOrEqualTo(0.25 / 240 + 1e-6));
      expect(right.skip(240).every((s) => s == 0), isTrue);
    });

    test('a gain above unity ramps in 5 ms like any other', () {
      final sim = simulation(engine)..run(0.2);
      sim.route.setGain(4, 4);
      final output = sim.run(0.05);
      expect(output[239], closeTo(1.0, 1e-5), reason: '0.25 at 4x, 5 ms after the change');
    });

    test('an endpoint is mono or stereo', () {
      expect(() => engine.addPushed(channels: 6), throwsArgumentError);
      expect(() => engine.addPulled(channels: 0), throwsArgumentError);
    });

    test('routes into one sink add up', () {
      final a = engine.addPushed();
      final b = engine.addPushed();
      final sink = engine.addPulled();
      engine.connect(a, sink);
      final route = engine.connect(b, sink);
      final samples = Float32List(256)..fillRange(0, 256, 0.25);
      for (var i = 0; i < 20; i++) {
        a.push(samples);
        b.push(samples);
      }
      sink.pull(2400);
      expect(sink.pull(240).every((s) => (s - 0.5).abs() < 1e-5), isTrue, reason: '${route.stats}');
    });

    test('refuses a route the wrong way round', () {
      final source = engine.addPushed();
      final sink = engine.addPulled();
      expect(() => engine.connect(sink, source), throwsArgumentError);
      expect(() => engine.connect(source, source), throwsArgumentError);
    });
  });

  group('sound devices (null backend)', () {
    setUpAll(() {
      try {
        HaloAudio.useNullBackend();
      } on StateError {
        // Chosen already by another test in this process.
      }
    });

    test('an output device plays its routes, and routes change under it while it runs', () async {
      // The device's thread reads the routes while this one replaces them:
      // a route freed while the callback still reads it crashes here.
      final output = engine.openOutput();
      final source = engine.addPushed();
      final route = engine.connect(source, output, start: const Duration(milliseconds: 20));
      final spare = engine.addPushed();
      final clock = Stopwatch()..start();
      var written = 0;
      while (clock.elapsedMilliseconds < 500) {
        final owed = clock.elapsedMicroseconds * rate ~/ 1000000 - written;
        source.push(Float32List.fromList([for (var i = 0; i < owed; i++) sine(written + i)]));
        written += owed;
        for (var k = 0; k < 20; k++) {
          engine.connect(spare, output).disconnect();
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(output.takePeak(), greaterThan(0.3), reason: '${route.stats}');
      spare.close();
      output.close();
      expect(() => route.stats, throwsStateError, reason: 'the route went with its sink');
    });

    test('an input device feeds its routes', () async {
      final input = engine.openInput();
      final sink = engine.addPulled();
      final route = engine.connect(input, sink);
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sink.pull(480);
      }
      expect(route.stats.running, isTrue, reason: '${route.stats}');
      input.close();
    });
  });
}
