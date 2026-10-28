// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio's DAX transmit audio as this app sends it (flex_dax_tx.dart).
//
// The traps are packets the radio drops without a word — the wrong VITA type
// (type 3, what the radio's own audio packets carry, transmits nothing), the
// wrong byte order, a stream id the radio never granted — audio sent faster
// or slower than it plays, and a radio left keyed with nothing arriving on
// its DAX, which goes out as noise.

import 'dart:io' show OSError, SocketException;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_dax_tx.dart';

void main() {
  late List<(String, void Function(int, String)?)> commands;
  late List<Uint8List> packets;
  late Map<String, Float32List> files;
  late List<String> diagnostics;
  late Object? sendFailure;
  late List<String> decoded;

  setUp(() {
    commands = [];
    packets = [];
    files = {};
    diagnostics = [];
    sendFailure = null;
    decoded = [];
  });

  FlexDaxOutput open(FakeAsync async) => FlexDaxOutput(
    send: (command, {onReply}) => commands.add((command, onReply)),
    sendPacket: (packet) {
      if (sendFailure case final e?) throw e;
      packets.add(packet);
    },
    diagnose: diagnostics.add,
    decode: (path, {required rate, required channels}) {
      expect((rate, channels), (24000, 2), reason: "the radio's DAX format");
      decoded.add(path);
      return files[path] ?? (throw HaloAudioException('open file: no such file'));
    },
    clockMicros: () => async.elapsed.inMicroseconds,
  );

  void grant(int id) => commands.firstWhere((c) => c.$1 == 'stream create type=dax_tx').$2!(0, id.toRadixString(16));

  /// [seconds] of a ramp, so every sample is told apart from its neighbours.
  Float32List ramp(double seconds) {
    final frames = (seconds * 24000).round();
    return Float32List.fromList([
      for (var i = 0; i < frames; i++) ...[i / frames, -i / frames],
    ]);
  }

  // The output is opened as the radio connects, long before any message.
  // Claimed then, the stream would take the DAX transmit audio of a
  // digital-mode program on the same radio, which would go out silent.
  test('creates a transmit stream, and claims it only as a message starts', () {
    fakeAsync((async) {
      final output = open(async);
      expect(commands.map((c) => c.$1), ['stream create type=dax_tx']);
      grant(0x84000002);
      expect(commands.map((c) => c.$1), ['stream create type=dax_tx'], reason: 'nothing to send yet');
      files['/v/1.wav'] = ramp(0.1);
      output.startSilence('/v/1.wav');
      expect(commands.map((c) => c.$1).last, 'stream set 0x84000002 tx=1');
    });
  });

  test('a message started before the grant claims the stream as it comes', () {
    fakeAsync((async) {
      files['/v/1.wav'] = ramp(0.1);
      open(async).startSilence('/v/1.wav');
      grant(0x84000002);
      expect(commands.map((c) => c.$1).last, 'stream set 0x84000002 tx=1');
    });
  });

  test('sends type-1 packets of 128 big-endian stereo frames on the granted stream', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(0.1);
      output.play('/v/1.wav');
      async.elapse(const Duration(milliseconds: 20));
      final first = ByteData.sublistView(packets.first);
      final header = first.getUint32(0);
      expect(header >> 28, 1, reason: 'type 1, IF data with a stream id: type 3 transmits nothing');
      expect((header >> 27) & 1, 1, reason: 'class id present');
      expect(header & 0xffff, 263, reason: '28-byte header and 1024 bytes of audio, in words');
      expect(packets.first.length, 1052);
      expect(first.getUint32(4), 0x84000002);
      expect(first.getUint32(8), 0x00001C2D);
      expect(first.getUint32(12), 0x534C03E3);
      final samples = files['/v/1.wav']!;
      for (var i = 0; i < 256; i++) {
        expect(first.getFloat32(28 + i * 4, Endian.big), samples[i]);
      }
      final second = ByteData.sublistView(packets[1]);
      expect((second.getUint32(0) >> 16) & 15, 1, reason: 'the packet count steps');
      expect(second.getUint32(24) - first.getUint32(24), 128, reason: 'the sample count steps by a packet');
      expect(second.getFloat32(28, Endian.big), samples[256]);
    });
  });

  test('nothing goes out before the radio grants the stream, and the message waits for it rather than losing its start', () {
    fakeAsync((async) {
      final output = open(async);
      files['/v/1.wav'] = ramp(0.1);
      output.play('/v/1.wav');
      async.elapse(const Duration(milliseconds: 50));
      expect(packets, isEmpty);
      grant(0x84000002);
      async.elapse(const Duration(milliseconds: 10));
      expect(ByteData.sublistView(packets.first).getFloat32(28, Endian.big), files['/v/1.wav']![0]);
    });
  });

  // Sent faster, the radio's buffer overflows and drops audio; slower, it
  // runs dry mid-word.
  test('paces packets at the rate the audio plays, a few ahead', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(3);
      output.play('/v/1.wav');
      async.elapse(const Duration(seconds: 1));
      // 24000 / 128 = 187.5 packets a second, plus the 4 sent ahead.
      expect(packets.length, inInclusiveRange(188, 193));
    });
  });

  // The keyer unkeys a tail after the end, and the radio takes a moment to
  // drop out of transmit: with nothing arriving on its DAX meanwhile, it
  // transmits noise.
  test('says done when the audio has gone, then keeps the radio fed with silence for a second', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(0.5);
      final playback = output.play('/v/1.wav');
      var done = false;
      playback.done.then((_) => done = true);
      async.elapse(const Duration(milliseconds: 400));
      expect(done, isFalse);
      async.elapse(const Duration(milliseconds: 200));
      expect(done, isTrue);
      final atEnd = packets.length;
      async.elapse(const Duration(milliseconds: 500));
      expect(packets.length, greaterThan(atEnd + 80), reason: 'silence, still paced');
      expect(ByteData.sublistView(packets.last).getFloat32(28, Endian.big), 0);
      async.elapse(const Duration(seconds: 1));
      final settled = packets.length;
      async.elapse(const Duration(seconds: 1));
      expect(packets.length, settled, reason: 'quiet once the radio is surely unkeyed');
    });
  });

  // The keyer keys the radio and waits out its key-up delay before the
  // message: with nothing arriving on its DAX meanwhile, the radio transmits
  // noise ahead of every message.
  test('silence started ahead of the key feeds the radio until the message, which follows on the same clock', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(1);
      output.startSilence('/v/1.wav');
      async.elapse(const Duration(milliseconds: 250));
      // 250 ms is 46.9 packets, plus the 4 ahead.
      expect(packets.length, inInclusiveRange(50, 51));
      expect(packets.every((packet) => ByteData.sublistView(packet).getFloat32(28, Endian.big) == 0), isTrue);
      output.play('/v/1.wav');
      final silent = packets.length;
      async.elapse(const Duration(milliseconds: 20));
      final first = ByteData.sublistView(packets[silent]);
      expect(first.getFloat32(28, Endian.big), files['/v/1.wav']![0], reason: 'the message starts in the next packet');
      expect(first.getUint32(24) - ByteData.sublistView(packets[silent - 1]).getUint32(24), 128, reason: 'no gap in the sample count');
      async.elapse(const Duration(milliseconds: 500));
      // Still paced from when the silence started: 770 ms is 144.4 packets,
      // plus the 4 ahead.
      expect(packets.length, inInclusiveRange(148, 149));
    });
  });

  test('a stop silences the audio at once, and the silence still follows it', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(3);
      final playback = output.play('/v/1.wav');
      async.elapse(const Duration(milliseconds: 100));
      playback.stop();
      expect(playback.isPlaying, isFalse);
      final at = packets.length;
      async.elapse(const Duration(milliseconds: 100));
      expect(packets.length, greaterThan(at));
      expect(ByteData.sublistView(packets.last).getFloat32(28, Endian.big), 0);
    });
  });

  test('closing removes the stream and stops sending', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(3);
      output.play('/v/1.wav');
      async.elapse(const Duration(milliseconds: 100));
      output.close();
      expect(commands.map((c) => c.$1).last, 'stream remove 0x84000002');
      final at = packets.length;
      async.elapse(const Duration(seconds: 2));
      expect(packets.length, at);
      expect(output.isAlive, isFalse);
    });
  });

  // Decoded as it plays, the feed stops for the whole decode — a long
  // recording, on the UI isolate — and the keyed radio transmits noise
  // until it is done, at the start of every message.
  test('the next file is decoded as the silence starts, before the key, not as it plays', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(0.5);
      output.startSilence('/v/1.wav');
      expect(decoded, ['/v/1.wav']);
      async.elapse(const Duration(milliseconds: 250));
      output.play('/v/1.wav');
      expect(decoded, ['/v/1.wav'], reason: 'played from what the silence decoded');
    });
  });

  test('a file that will not decode throws as the silence starts, before anything is keyed', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      expect(() => output.startSilence('/v/missing.wav'), throwsA(isA<HaloAudioException>()));
      async.elapse(const Duration(milliseconds: 50));
      expect(packets, isEmpty);
    });
  });

  // A refused stream is a radio that will not transmit this audio: the keyer
  // has to hear of it rather than key a dead carrier.
  test('a stream the radio refuses is an output gone', () {
    fakeAsync((async) {
      final output = open(async);
      var gone = false;
      output.gone.then((_) => gone = true);
      commands.single.$2!(0x50000064, '');
      async.flushMicrotasks();
      expect(gone, isTrue);
      expect(output.isAlive, isFalse);
      expect(diagnostics, ['stream create refused: 50000064'], reason: 'the CAT recording says why the radio sent no audio');
    });
  });

  // The radio's own sources can outrank a client's: with the claim refused,
  // keying puts some other audio, or none, on the air.
  test('a claim the radio refuses is an output gone', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(0.1);
      output.startSilence('/v/1.wav');
      commands.last.$2!(0x50000016, 'not owner');
      async.flushMicrotasks();
      expect(output.isAlive, isFalse);
      expect(diagnostics, ['stream set tx=1 refused: 50000016 not owner']);
    });
  });

  // Without an answer the output would stay "alive" holding back every
  // packet, and the keyer would key a dead carrier for each message.
  test('a stream the radio never answers for is an output gone', () {
    fakeAsync((async) {
      final output = open(async);
      async.elapse(flexDaxGrantTimeout - const Duration(milliseconds: 1));
      expect(output.isAlive, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(output.isAlive, isFalse);
      expect(diagnostics.single, contains('no answer'));
    });
  });

  // A failing socket fails every packet: thrown out of the pacing timer, that
  // is an error every 5 ms while the radio stays keyed with nothing arriving.
  test('a packet the socket will not send is an output gone, and the sending stops', () {
    fakeAsync((async) {
      final output = open(async);
      grant(0x84000002);
      files['/v/1.wav'] = ramp(0.5);
      final playback = output.play('/v/1.wav');
      async.elapse(const Duration(milliseconds: 20));
      final sent = packets.length;
      sendFailure = const SocketException('Send failed', osError: OSError('No route to host', 65));
      async.elapse(const Duration(milliseconds: 20));
      expect(output.isAlive, isFalse);
      expect(playback.isPlaying, isFalse);
      sendFailure = null;
      async.elapse(const Duration(milliseconds: 100));
      expect(packets.length, sent);
    });
  });

  test('a stream granted after the output closed is handed back', () {
    fakeAsync((async) {
      open(async).close();
      grant(0x84000002);
      expect(commands.map((c) => c.$1).last, 'stream remove 0x84000002');
    });
  });
}
