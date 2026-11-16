// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The engine's network edge (docs/design/audio.md § 4) on loopback: a Dart
// socket stands in for a FlexRadio, sending its DAX audio and its meters to
// the engine's socket and catching what the engine's sender sends back.

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';

const daxRxStream = 0x04000008;
const daxTxStream = 0x84000002;
const meterStream = 0x00000700;

/// A Flex `dax_rx` packet: VITA type 3 with class, UTC seconds and a sample
/// count, 128 frames of 24 kHz stereo float32, big-endian — [sample] gives
/// frame [index]'s value, the same in both channels.
Uint8List daxRxPacket(int count, int firstFrame, double Function(int index) sample, {int stream = daxRxStream}) {
  final data = ByteData(28 + 128 * 8);
  data.setUint32(0, (3 << 28) | (1 << 27) | (1 << 22) | (1 << 20) | ((count & 15) << 16) | data.lengthInBytes ~/ 4);
  data.setUint32(4, stream);
  data.setUint32(8, 0x00001C2D);
  data.setUint32(12, 0x534C03E3);
  data.setUint32(24, firstFrame);
  for (var i = 0; i < 128; i++) {
    data.setFloat32(28 + i * 8, sample(firstFrame + i));
    data.setFloat32(28 + i * 8 + 4, sample(firstFrame + i));
  }
  return data.buffer.asUint8List();
}

double tone24k(int frame) => 0.5 * math.sin(2 * math.pi * 1000 * frame / 24000);
double tone48k(int frame) => 0.5 * math.sin(2 * math.pi * 1000 * frame / 48000);

/// How many times [samples] crosses zero going up, per second at [rate].
double cyclesPerSecond(List<double> samples, int rate) {
  var crossings = 0;
  for (var i = 1; i < samples.length; i++) {
    if (samples[i - 1] < 0 && samples[i] >= 0) crossings++;
  }
  return crossings * rate / samples.length;
}

double largestStep(List<double> samples) {
  var largest = 0.0;
  for (var i = 1; i < samples.length; i++) {
    largest = math.max(largest, (samples[i] - samples[i - 1]).abs());
  }
  return largest;
}

void main() {
  late AudioEngine engine;
  late AudioSocket socket;
  late RawDatagramSocket radio;
  final received = <Datagram>[];

  setUp(() async {
    engine = AudioEngine();
    socket = engine.openSocket();
    radio = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    received.clear();
    radio.listen((event) {
      if (event != RawSocketEvent.read) return;
      for (var d = radio.receive(); d != null; d = radio.receive()) {
        received.add(d);
      }
    });
  });

  tearDown(() {
    engine.close();
    radio.close();
  });

  test('datagrams no endpoint claims reach Dart, with where they came from, and Dart can send', () async {
    final datagrams = <AudioDatagram>[];
    socket.datagrams.listen(datagrams.add);
    radio.send([1, 2, 3], InternetAddress.loopbackIPv4, socket.port);
    radio.send([4, 5], InternetAddress.loopbackIPv4, socket.port);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(datagrams.map((d) => d.data), [
      [1, 2, 3],
      [4, 5],
    ]);
    expect(datagrams.first.port, radio.port);
    expect(datagrams.first.host, '127.0.0.1');

    socket.send('127.0.0.1', radio.port, Uint8List.fromList([9, 8, 7]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received.single.data, [9, 8, 7]);
  });

  // The address is resolved once and kept: a send to another port, or a
  // packet longer than the last, must not go where the last one went or be
  // cut to its length.
  test('a send to a new address goes there, and a longer packet goes whole', () async {
    final other = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(other.close);
    final atOther = <List<int>>[];
    other.listen((event) {
      if (event == RawSocketEvent.read) atOther.add(other.receive()!.data);
    });
    socket.send('127.0.0.1', radio.port, Uint8List.fromList([1]));
    socket.send('127.0.0.1', other.port, Uint8List.fromList([2, 3, 4, 5]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      [for (final d in received) d.data],
      [
        [1],
      ],
    );
    expect(atOther, [
      [2, 3, 4, 5],
    ]);
  });

  test('a burst of DAX IQ packets reaches Dart whole, sent while Dart is busy', () async {
    // A FlexRadio's spectrum is drawn from its 4128-byte DAX IQ packets,
    // some 375 a second at 192 kHz. The send loop holds Dart up as a busy
    // frame does: the queue must carry the burst until Dart drains it, and
    // must not refuse a packet that size.
    final datagrams = <AudioDatagram>[];
    socket.datagrams.listen(datagrams.add);
    final packet = Uint8List(4128);
    for (var i = 0; i < 200; i++) {
      packet[0] = i;
      radio.send(packet, InternetAddress.loopbackIPv4, socket.port);
    }
    for (var i = 0; i < 50 && datagrams.length < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(socket.dropped, 0);
    expect(datagrams, hasLength(200));
    expect(datagrams.every((d) => d.data.length == 4128), isTrue);
  });

  test('a datagram for an isolate that has gone without closing its engine leaves the process running', () async {
    // A hot restart, or an app shutting down, ends the isolate with the
    // engine still open and its receive thread still queuing. A notice sent
    // through a NativeCallable the gone isolate made aborts the process —
    // this whole test run with it.
    final port = await Isolate.run(() => AudioEngine().openSocket().port);
    radio.send([1, 2, 3], InternetAddress.loopbackIPv4, port);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(port, greaterThan(0));
  });

  test("a slice's dax_rx is claimed into its endpoint at the engine's rate; the meters beside it still reach Dart", () async {
    // A radio sends its meters to the same port as its audio: the meters
    // must not be lost to the audio, nor played as audio.
    final datagrams = <AudioDatagram>[];
    socket.datagrams.listen(datagrams.add);
    final slice = engine.addFlexDaxRx(socket, daxRxStream);
    final ears = engine.addPulled(channels: 2);
    final route = engine.connect(slice, ears);
    for (var p = 0; p < 30; p++) {
      radio.send(daxRxPacket(p, p * 128, tone24k), InternetAddress.loopbackIPv4, socket.port);
      if (p == 10) radio.send(daxRxPacket(0, 0, (_) => 0.9, stream: meterStream), InternetAddress.loopbackIPv4, socket.port);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(datagrams, hasLength(1), reason: 'the meter packet');
    expect(datagrams.single.data.length, 28 + 128 * 8);

    final out = ears.pull(4800);
    final left = [for (var i = 0; i < out.length; i += 2) out[i]].sublist(960, 4000);
    // 24 kHz brought to 48 kHz: a 1 kHz tone stays 1 kHz, at its level.
    expect(cyclesPerSecond(left, 48000), closeTo(1000, 20), reason: '${route.stats}');
    expect(left.reduce(math.max), closeTo(0.5, 0.02));
    expect(largestStep(left), lessThan(0.5 * 2 * math.pi * 1000 / 48000 * 1.05));
    expect(left.any((s) => s > 0.6), isFalse, reason: 'no meter in the audio');
  });

  /// Sends [packets] of a cosine at [hz] as a slice's dax_rx, skipping
  /// [lost]; returns the left channel heard and the route.
  Future<(List<double>, AudioRoute, AudioEndpoint)> sendLosing(Set<int> lost, {required double hz, int packets = 30}) async {
    final slice = engine.addFlexDaxRx(socket, daxRxStream);
    final ears = engine.addPulled(channels: 2);
    final route = engine.connect(slice, ears);
    for (var p = 0; p < packets; p++) {
      if (lost.contains(p)) continue; // the counter still counting
      // A cosine, at its peak at a 1 kHz gap's edges: a sine crosses zero
      // there, and would hide a missing fade.
      radio.send(daxRxPacket(p, p * 128, (f) => 0.5 * math.cos(2 * math.pi * hz * f / 24000)), InternetAddress.loopbackIPv4, socket.port);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final out = ears.pull(packets * 256 - 512);
    return ([for (var i = 0; i < out.length; i += 2) out[i]], route, slice);
  }

  int longestQuiet(List<double> samples) {
    var longest = 0, run = 0;
    for (final s in samples) {
      run = s.abs() < 0.02 ? run + 1 : 0;
      longest = math.max(longest, run);
    }
    return longest;
  }

  test('a lost dax_rx packet is filled with the one before, crossfaded: no hole, no click', () async {
    // Wi-Fi loses a few in a hundred of a radio's packets. Dropped from the
    // stream, each jumps the tone mid-cycle — a click — and shortens the
    // timeline until the bridge runs dry; filled with silence, each is a
    // 5 ms hole, heard as choppiness. 700 Hz is out of step with the repeat,
    // so its seams are crossfades of two different phases.
    final (left, route, slice) = await sendLosing({12, 20, 21}, hz: 700);
    expect(slice.receiverStats.lost, 3, reason: '${slice.receiverStats}');
    expect(largestStep(left), lessThan(0.5 * 2 * math.pi * 700 / 48000 + 0.5 / 32 + 0.002), reason: '${route.stats}');
    expect(longestQuiet(left), lessThan(60), reason: 'no hole where the packets were');
    expect(route.stats.underruns, 0, reason: 'the timeline kept: ${route.stats}');
  });

  test('a long dax_rx loss fades to silence rather than buzzing on the repeat', () async {
    // Repeated for 43 ms, one packet less a 1.3 ms hold is a 4 ms buzz.
    final (left, route, _) = await sendLosing({for (var p = 12; p < 20; p++) p}, hz: 1000);
    expect(largestStep(left), lessThan(0.5 * 2 * math.pi * 1000 / 48000 + 0.5 / 64 + 0.002), reason: '${route.stats}');
    // 1056 frames at 24 kHz to fill, 384 of them the repeat and its fade.
    expect(longestQuiet(left), inInclusiveRange(1200, 1500));
    expect(route.stats.underruns, 0, reason: 'the timeline kept: ${route.stats}');
  });

  test('the dax_tx sender paces VITA type 1 packets of the mix at 24 kHz, silence first', () async {
    final mic = engine.addPushed();
    final radioTx = engine.addFlexDaxTx(socket, host: '127.0.0.1', port: radio.port, streamId: daxTxStream);
    engine.connect(mic, radioTx, max: const Duration(seconds: 1));
    // Keyed first: opening the gate drops what the mic held before it, and
    // the sender's next pull, within a packet, is what opens it.
    radioTx.gate = true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    mic.push(Float32List.fromList([for (var i = 0; i < 24000; i++) tone48k(i)]));
    final clock = Stopwatch()..start();
    radioTx.sending = true;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    radioTx.sending = false;
    final elapsed = clock.elapsedMicroseconds;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final stats = radioTx.senderStats;
    // ignore: avoid_print
    print('dax_tx sender over ${elapsed ~/ 1000} ms: $stats');

    final packets = [for (final d in received) ByteData.sublistView(d.data)];
    // 400 ms at 5.33 ms a packet, and the two of silence ahead.
    expect(packets.length, closeTo(elapsed / 5333.3 + 2, 6), reason: '$stats');
    for (var i = 0; i < packets.length; i++) {
      final p = packets[i];
      expect(p.lengthInBytes, 28 + 128 * 8);
      expect(p.getUint32(0) >> 28, 1, reason: 'type 1: a Flex transmits nothing from type 3');
      expect(p.getUint32(0) & 0xffff, (28 + 128 * 8) ~/ 4);
      expect((p.getUint32(0) >> 16) & 15, i & 15);
      expect(p.getUint32(4), daxTxStream);
      expect(p.getUint32(8), 0x00001C2D);
      expect(p.getUint32(12), 0x534C03E3);
      expect(p.getUint32(24), i * 128, reason: 'the sample count');
    }
    double sample(ByteData p, int frame, int channel) => p.getFloat32(28 + frame * 8 + channel * 4);
    expect([for (var f = 0; f < 128; f++) sample(packets[0], f, 0)].every((s) => s == 0), isTrue, reason: 'silence ahead');
    final left = [
      for (final p in packets.skip(10))
        for (var f = 0; f < 128; f++) sample(p, f, 0),
    ];
    final right = [
      for (final p in packets.skip(10))
        for (var f = 0; f < 128; f++) sample(p, f, 1),
    ];
    // 48 kHz brought to 24 kHz: a 1 kHz tone stays 1 kHz, in both channels.
    expect(cyclesPerSecond(left, 24000), closeTo(1000, 20));
    expect(left.reduce(math.max), closeTo(0.5, 0.02));
    expect(right, left);
    expect(largestStep(left), lessThan(0.5 * 2 * math.pi * 1000 / 24000 * 1.05));
  });

  test('a shut gate sends silence; not sending sends nothing', () async {
    final mic = engine.addPushed();
    final radioTx = engine.addFlexDaxTx(socket, host: '127.0.0.1', port: radio.port, streamId: daxTxStream);
    engine.connect(mic, radioTx, max: const Duration(seconds: 1));
    mic.push(Float32List.fromList([for (var i = 0; i < 24000; i++) tone48k(i)]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received, isEmpty, reason: 'not sending');
    radioTx.sending = true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    radioTx.sending = false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(received.length, greaterThan(10));
    for (final d in received) {
      final p = ByteData.sublistView(d.data);
      expect([for (var i = 28; i < p.lengthInBytes; i += 4) p.getFloat32(i)].every((s) => s == 0), isTrue, reason: 'the mic, with the gate shut');
    }
  });

  test('closing the socket closes the endpoints on it', () {
    final slice = engine.addFlexDaxRx(socket, daxRxStream);
    final radioTx = engine.addFlexDaxTx(socket, host: '127.0.0.1', port: radio.port, streamId: daxTxStream);
    final ears = engine.addPulled();
    engine.connect(slice, ears);
    socket.close();
    expect(() => engine.connect(slice, ears), throwsArgumentError);
    expect(() => radioTx.sending = true, throwsStateError);
  });
}
