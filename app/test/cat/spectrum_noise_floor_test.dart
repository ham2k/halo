// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/spectrum_fft.dart';

/// A sweep whose noise — its 20th percentile — is [noise] dB.
Float32List _sweep(double noise) => Float32List.fromList(List.filled(100, noise));

void main() {
  test('the noise it reports is the settled noise, which the reference level does not move', () {
    // A scene places things above the noise: moved with the operator's contrast, they would ride the trace up and down.
    final floor = NoiseFloor();
    expect(floor.update(_sweep(-100), atMillis: 0)!.noise, -100);
    final moved = floor.update(_sweep(-99), refLevelDb: 15, atMillis: 100)!;
    expect(moved.noise, -100, reason: 'held through a dB of wobble, and not the reference');
    expect(moved.floor, -125);
  });

  test('the floor holds through the noise wobbling and a static crash, and moves once the noise has moved for a while', () {
    final floor = NoiseFloor();
    double at(double noise, int millis, {double ref = 0}) => floor.update(_sweep(noise), refLevelDb: ref, atMillis: millis)!.floor;
    final start = at(-100, 0);
    expect(start, -110);
    // Past the first settling time, which follows the noise more eagerly (see the next test).
    const t0 = NoiseFloor.settleMillis;
    for (var t = 100; t <= t0; t += 100) {
      expect(at(-100, t), start);
    }
    // A dB either way, sweep to sweep: a floor following it shimmers the trace and the labels.
    for (var t = t0 + 100; t <= t0 + 2000; t += 100) {
      expect(at((t ~/ 100).isEven ? -99 : -101, t), start);
    }
    // A crash: half a second of band-wide noise 30 dB up, which would lift and drop the whole picture.
    for (var t = t0 + 2100; t <= t0 + 2600; t += 100) {
      expect(at(-70, t), start);
    }
    // The band quiet again for a moment: the crash is forgotten.
    for (var t = t0 + 2700; t <= t0 + 5000; t += 100) {
      expect(at(-100, t), start);
    }
    // The band has really got noisier: the floor waits out the settling time, then follows.
    var moved = start;
    var t = t0 + 5100;
    for (; t <= t0 + 12000; t += 100) {
      moved = at(-90, t);
      if (moved != start) {
        expect(t, greaterThanOrEqualTo(t0 + 5100 + NoiseFloor.settleMillis), reason: 'moved after only ${t - t0 - 5100} ms');
        break;
      }
    }
    expect(moved, greaterThan(start));
    // The operator's reference level is not noise: it shows at once.
    expect(at(-90, t + 100, ref: 10), moved - 10);
  });

  test('a move to another band rescales from its first sweep, while a move within the band waits out the settling time', () {
    final floor = NoiseFloor();
    double at(double noise, int millis, int centerHz) => floor.update(_sweep(noise), centerHz: centerHz, atMillis: millis)!.floor;
    expect(at(-120, 0, 28400000), -130);
    // Up the band, onto a noisier stretch: the settling still applies.
    expect(at(-100, 100, 28900000), -130);
    // 10 m to 40 m, quiet to noisy: without the reset the picture sits 20 dB
    // low, the band's noise drawn as signal, for the whole settling time.
    expect(at(-100, 200, 7074000), -110);
    // And outside the amateur bands is a band of its own.
    expect(at(-80, 300, 9600000), -90);
  });

  test('a first sweep on a new band that is partly the old one does not hold the floor there', () {
    final floor = NoiseFloor();
    double at(double noise, int millis, int centerHz) => floor.update(_sweep(noise), centerHz: centerHz, atMillis: millis)!.floor;
    for (var t = 0; t <= 5000; t += 100) {
      at(-100, t, 7074000);
    }
    // The first sweep keyed to 10 m was mostly taken on 40 m before the move; 10 m's own noise is
    // 20 dB lower. Seeded from it and then held, the floor would sit high for the whole settling time,
    // drawing the new band's noise below the picture.
    at(-100, 5100, 28074000);
    var t = 5200;
    for (; t < 5100 + NoiseFloor.settleMillis; t += 100) {
      at(-120, t, 28074000);
    }
    // Followed in moves past the drift, it ends about a drift from the new noise; held, it would still be 20 dB up.
    expect(at(-120, t, 28074000), closeTo(-130, NoiseFloor.driftDb + 1), reason: 'still scaled to the old band');
    // Once there, it holds still again.
    final settled = at(-120, t += 100, 28074000);
    for (var i = 0; i < 20; i++) {
      expect(at((i.isEven ? -119 : -121), t += 100, 28074000), settled);
    }
  });
}
