// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ring every receiver's samples go through, read through the test tone
// (tool/build_host.sh): no hardware here, and none needed — the vendor
// libraries only ever call hsu_ring_write, which is what these exercise.
// A reader that got a sample out of order, or half of one written, would
// draw a carrier smeared across the sweep.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_sdr_usb/halo_sdr_usb.dart';
import 'package:halo_sdr_usb/src/sdr_usb_ffi.dart' show openSdrUsbTestTone;

/// Until [done], on the real clock: the tone is a thread writing in real
/// time, which may run late but not early, so the deadline only stops a hang
/// (docs/design/time.md §7).
Future<void> until(bool Function() done, {Duration limit = const Duration(seconds: 60)}) async {
  final watch = Stopwatch()..start();
  while (!done() && watch.elapsed < limit) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue, reason: 'still waiting after $limit');
}

/// The phase step between each pair of samples in [iq], radians.
List<double> steps(Float32List iq) => [
  for (var i = 0; i + 3 < iq.length; i += 2)
    () {
      final (re, im) = (iq[i + 2] * iq[i] + iq[i + 3] * iq[i + 1], iq[i + 3] * iq[i] - iq[i + 2] * iq[i + 1]);
      return math.atan2(im, re);
    }(),
];

void main() {
  test('samples are read back in order, each whole', () async {
    const rate = 48000, offset = 1000;
    final device = await openSdrUsbTestTone(rate, offset);
    addTearDown(device.close);
    expect(device.sampleRates, [rate]);
    expect(device.streaming, SdrUsbStreaming.stopped);

    expect(await device.start(), isTrue);
    expect(device.streaming, SdrUsbStreaming.streaming);
    await until(() => device.written > 8192);
    final from = device.written - 4096;
    final iq = Float32List(4096 * 2);
    expect(device.read(from, 4096, iq, 0), 4096);
    for (final step in steps(iq)) {
      expect(step, closeTo(2 * math.pi * offset / rate, 1e-3));
    }

    expect(device.read(device.written + 10, 5, iq, 0), 0, reason: 'nothing past the newest is there to read');
  });

  test('a reader too far behind gets nothing, and the newest reads whole across the end of the ring', () async {
    // Fast enough to go round the ring in a couple of seconds.
    const rate = 1024000, offset = 10000;
    final device = await openSdrUsbTestTone(rate, offset);
    addTearDown(device.close);
    expect(await device.start(), isTrue);
    final capacity = device.capacity;
    await until(() => device.written > capacity + 8192);

    final iq = Float32List(4096 * 2);
    expect(device.read(0, 4096, iq, 0), 0, reason: 'overwritten: what was there is gone, not half-replaced');

    // A window that straddles the point where the ring starts over.
    final wrap = device.written ~/ capacity * capacity;
    expect(device.read(wrap - 2048, 4096, iq, 0), 4096);
    for (final step in steps(iq)) {
      expect(step, closeTo(2 * math.pi * offset / rate, 1e-3));
    }
  });

  test('a stopped receiver writes nothing more', () async {
    final device = await openSdrUsbTestTone(48000, 1000);
    addTearDown(device.close);
    expect(await device.start(), isTrue);
    await until(() => device.written > 1000);
    // Awaited, not polled: while the stop is queued, streaming already reads
    // stopped, and the tone writes on until the worker reaches it.
    await device.stop();
    expect(device.streaming, SdrUsbStreaming.stopped);
    final written = device.written;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(device.written, written);
  });

  test('a build without USB receivers says so rather than failing to open', () async {
    // The host library is built without libusb (tool/build_host.sh), as a
    // Linux machine without libusb's development files builds the app.
    await expectLater(openSdrUsb(SdrUsbKind.airspy), throwsA(isA<SdrUsbOpenException>().having((e) => e.unavailable, 'unavailable', isTrue)));
  });

  test('a closed receiver reads as gone at once, while its worker lets go of it', () async {
    final device = await openSdrUsbTestTone(48000, 1000);
    expect(await device.start(), isTrue);
    final closing = device.close();
    // From the call on: a read of a handle the worker is about to free would
    // take the app down rather than throw.
    expect(device.streaming, SdrUsbStreaming.lost);
    expect(device.read(0, 16, Float32List(32), 0), 0);
    await closing;
  });
}
