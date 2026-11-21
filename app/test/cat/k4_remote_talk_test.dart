// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_audio.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_talk.dart';

class _Link implements TalkAudioLink {
  _Link(this.engine) : mic = engine.addPushed();

  @override
  final AudioEngine engine;
  final AudioEndpoint mic;
  String? refuse;
  int opened = 0, closed = 0;

  @override
  TalkRoute? speak(AudioEndpoint sink, {required void Function(String reason) why}) {
    if (refuse case final reason?) {
      why(reason);
      return null;
    }
    opened++;
    final route = engine.connect(mic, sink, start: Duration.zero, max: const Duration(milliseconds: 200));
    return _Route(() {
      closed++;
      route.disconnect();
    });
  }
}

class _Route implements TalkRoute {
  _Route(this._close);
  final void Function() _close;
  @override
  void close() => _close();
}

List<double> _samples(Uint8List packet) {
  final data = ByteData.sublistView(packet);
  return [for (var at = 15; at + 4 <= packet.length - 4; at += 4) data.getInt16(at, Endian.little) / 32767];
}

double _rms(Iterable<double> values) {
  final samples = values.toList();
  return math.sqrt(samples.fold(0.0, (sum, value) => sum + value * value) / samples.length);
}

void main() {
  late AudioEngine engine;
  late _Link link;
  late K4RemoteTalk talk;
  late List<Uint8List> packets;
  late List<String> diagnostics;
  late List<String?> problems;
  late int releases;
  var failSend = false;

  setUp(() {
    engine = AudioEngine();
    link = _Link(engine);
    packets = [];
    diagnostics = [];
    problems = [];
    releases = 0;
    failSend = false;
    talk = K4RemoteTalk(
      link: link,
      send: (packet) {
        if (failSend) throw Exception('connection closed');
        packets.add(packet);
      },
      diagnose: diagnostics.add,
      problem: problems.add,
      onAirRefused: () => releases++,
    );
  });

  tearDown(() {
    talk.stop();
    engine.close();
  });

  void feed(FakeAsync async, {required int milliseconds, double frequency = 1000, double amplitude = .5}) {
    var at = 0;
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 10) {
      link.mic.push(Float32List.fromList([for (var i = 0; i < 480; i++) amplitude * math.sin(2 * math.pi * frequency * (at + i) / AudioEngine.rate)]));
      at += 480;
      async.elapse(const Duration(milliseconds: 10));
    }
  }

  test('prepares without sending and stops packets before the owner can unkey', () {
    fakeAsync((async) {
      expect(talk.keyed(), isFalse);
      expect(talk.prepare(), isTrue);
      feed(async, milliseconds: 180, amplitude: .9);
      expect(packets, isEmpty, reason: 'every packet would key the K4 before the owner keyed it');

      expect(talk.keyed(), isTrue);
      expect(talk.keyed(), isTrue, reason: 'a repeated key must not restart the sequence or timer');
      feed(async, milliseconds: 600);
      expect(packets, hasLength(10), reason: 'one 60 ms packet each tick, without a lead-in');
      expect(packets.map((packet) => packet[10]), orderedEquals(List.generate(10, (i) => i)));
      final audio = [for (final packet in packets.skip(1)) ..._samples(packet)];
      expect(_rms(audio), closeTo(.5 / math.sqrt(2), .02));
      expect(audio.map((value) => value.abs()).reduce(math.max), lessThan(.6), reason: 'audio captured before the key was dropped');
      for (final packet in packets) {
        final data = ByteData.sublistView(packet);
        expect(data.getUint16(12, Endian.little), k4RemoteAudioFrames);
        expect(packet[14], 0, reason: '12 kHz');
        for (var at = 15; at + 4 <= packet.length - 4; at += 4) {
          expect(data.getInt16(at, Endian.little), data.getInt16(at + 2, Endian.little), reason: 'mono copied to both K4 channels');
        }
      }

      talk.unkey();
      expect((talk.ready, talk.active, link.closed), (false, false, 1));
      async.elapse(const Duration(seconds: 1));
      expect(packets, hasLength(10), reason: 'a tail would key the K4 again after RX');
    });
  });

  test('each over opens its own microphone and resets the packet sequence', () {
    fakeAsync((async) {
      for (var over = 0; over < 2; over++) {
        expect(talk.prepare(), isTrue);
        expect(talk.keyed(), isTrue);
        feed(async, milliseconds: 120);
        expect(packets[over * 2][10], 0);
        expect(packets[over * 2 + 1][10], 1);
        talk.unkey();
      }
      expect((link.opened, link.closed), (2, 2));
      talk.stop();
      talk.stop();
      expect(talk.prepare(), isFalse);
    });
  });

  test('a microphone that will not open sends nothing and reports why', () {
    fakeAsync((async) {
      link.refuse = 'no such microphone';
      expect(talk.prepare(), isFalse);
      expect(talk.keyed(), isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(packets, isEmpty);
      expect(diagnostics, ['no such microphone']);
      expect(problems.last, 'no such microphone');
      expect(releases, 0, reason: 'the session has not keyed yet');
    });
  });

  test('a broken audio write closes the microphone and asks the app to release its key once', () {
    fakeAsync((async) {
      expect(talk.prepare(), isTrue);
      expect(talk.keyed(), isTrue);
      failSend = true;
      feed(async, milliseconds: 120);
      expect((talk.ready, talk.active, link.closed, releases), (false, false, 1, 1));
      async.elapse(const Duration(seconds: 1));
      expect(releases, 1);
      expect(diagnostics.single, contains('stream stopped'));
      expect(problems.last, isNotNull);
    });
  });

  test('an engine closing while keyed stops the timer and releases the app key', () {
    fakeAsync((async) {
      expect(talk.prepare(), isTrue);
      expect(talk.keyed(), isTrue);
      engine.close();
      async.elapse(const Duration(milliseconds: 60));
      expect((talk.ready, talk.active, releases), (false, false, 1));
      expect(packets, isEmpty);
      expect(link.closed, 1);
    });
  });

  test('resampling preserves voice and rejects high microphone frequencies that would alias into it', () {
    fakeAsync((async) {
      double level(double frequency) {
        packets.clear();
        expect(talk.prepare(), isTrue);
        expect(talk.keyed(), isTrue);
        feed(async, milliseconds: 600, frequency: frequency);
        talk.unkey();
        return _rms([for (final packet in packets.skip(1)) ..._samples(packet)]);
      }

      final voice = level(1000);
      final aliased = level(11000);
      expect(voice, closeTo(.5 / math.sqrt(2), .02));
      expect(aliased, lessThan(voice / 100), reason: '11 kHz must not appear as a second 1 kHz voice tone');
    });
  });
}
