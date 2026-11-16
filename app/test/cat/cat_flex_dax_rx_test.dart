// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio slice heard in HaLo (docs/design/audio.md § 6): the control
// that opens and closes its dax_rx stream, and a session that carries it
// end to end — the engine's socket as its udpport, a tone sent there heard
// in the operator's ears.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_dax_rx.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

/// The ears a test hears with: every source the link is asked to play goes
/// to one pulled stereo sink.
class _Link implements RadioAudioLink {
  _Link(this.engine) : ears = engine.addPulled(channels: 2);

  @override
  final AudioEngine engine;
  final AudioEndpoint ears;
  final heard = <AudioEndpoint>[];
  String? refuse;

  @override
  AudioRoute? hear(AudioEndpoint source, {required void Function(String reason) why}) {
    if (refuse case final reason?) {
      why(reason);
      return null;
    }
    heard.add(source);
    return engine.connect(source, ears);
  }
}

/// The commands sent, each with the reply it waits for.
class _Radio {
  final sent = <String>[];
  final _replies = <String, void Function(int code, String body)>{};

  void send(String command, {void Function(int code, String body)? onReply}) {
    sent.add(command);
    if (onReply != null) _replies[command] = onReply;
  }

  void answer(String command, int code, [String body = '']) => _replies.remove(command)!(code, body);
}

class _Sink implements EquipmentSink, ReceiveAudioSink {
  _Sink(this.receiveAudio);

  @override
  final RadioAudioLink? receiveAudio;
  final sent = <String>[];
  final diagnostics = <String?>[];

  /// The commands sent, without their `C<seq>|` envelope, and the sequence
  /// number of each.
  Map<String, int> get commands => {
    for (final line in sent)
      for (final command in line.trim().split('\n'))
        if (command.startsWith('C')) command.substring(command.indexOf('|') + 1): int.parse(command.substring(1, command.indexOf('|'))),
  };

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

/// A Flex `dax_rx` packet of a 1 kHz tone, as the capture's: VITA type 3,
/// 128 frames of 24 kHz stereo float32, big-endian.
Uint8List _daxRxPacket(int count, int stream) {
  final data = ByteData(28 + 128 * 8);
  data.setUint32(0, (3 << 28) | (1 << 27) | (1 << 22) | (1 << 20) | ((count & 15) << 16) | data.lengthInBytes ~/ 4);
  data.setUint32(4, stream);
  data.setUint32(8, 0x00001C2D);
  data.setUint32(12, 0x534C03E3);
  for (var i = 0; i < 128; i++) {
    final v = 0.5 * math.sin(2 * math.pi * 1000 * (count * 128 + i) / 24000);
    data.setFloat32(28 + i * 8, v);
    data.setFloat32(28 + i * 8 + 4, v);
  }
  return data.buffer.asUint8List();
}

void main() {
  late AudioEngine engine;
  late AudioSocket socket;
  late _Link link;
  late _Radio radio;
  late List<String> diagnostics;
  late List<String?> problems;
  late FlexDaxReceive rx;

  setUp(() {
    engine = AudioEngine();
    socket = engine.openSocket();
    link = _Link(engine);
    radio = _Radio();
    diagnostics = [];
    problems = [];
    rx = FlexDaxReceive(link: link, slice: 0, send: radio.send, diagnose: diagnostics.add, problem: problems.add);
  });

  tearDown(() => engine.close());

  void update({AudioSocket? on, bool bound = true, int? dax, Set<int> taken = const {}}) =>
      rx.update(socket: on ?? socket, bound: bound, daxChannel: dax, taken: taken);

  group('the stream', () {
    test('waits for the bind to the GUI client and the slice\'s DAX channel', () {
      // Made unbound, a stream may be the probe's own rather than the
      // operator's slice; made before the slice says its channel, it may be
      // the wrong channel's.
      update(bound: false, dax: 1);
      update(dax: null);
      expect(radio.sent, isEmpty);
      update(dax: 1);
      expect(radio.sent, ['stream create type=dax_rx dax_channel=1']);
    });

    test('a slice already on DAX is heard on its own channel, and left on it', () {
      update(dax: 1);
      radio.answer('stream create type=dax_rx dax_channel=1', 0, '4000008');
      expect(link.heard, hasLength(1));
      rx.stop();
      expect(radio.sent, ['stream create type=dax_rx dax_channel=1', 'stream remove 0x04000008'], reason: 'the operator\'s own channel is not touched');
    });

    test('a slice off DAX gets the lowest channel no other slice holds, and is taken off it again', () {
      // A channel another slice holds would mix that slice into this one's
      // audio, and a digital-mode program on it would lose its own.
      update(dax: 0, taken: {1, 2});
      expect(radio.sent, ['slice set 0 dax=3']);
      radio.answer('slice set 0 dax=3', 0);
      expect(radio.sent.last, 'stream create type=dax_rx dax_channel=3', reason: 'on the answer: the radio may not echo the change to this client');
      radio.answer('stream create type=dax_rx dax_channel=3', 0, '4000009');
      rx.stop();
      expect(radio.sent.skip(2), ['stream remove 0x04000009', 'slice set 0 dax=0']);
    });

    test('every channel taken: nothing is asked, and the reason is given', () {
      update(dax: 0, taken: {...flexDaxChannels});
      expect(radio.sent, isEmpty);
      expect(diagnostics.single, contains('every DAX channel'));
      // The operator hears nothing, so the radio's row says why.
      expect(problems.single, contains('every DAX channel'));
    });

    test('follows the slice to another channel, and lets it go when the operator takes it off DAX', () {
      update(dax: 1);
      radio.answer('stream create type=dax_rx dax_channel=1', 0, '4000008');
      update(dax: 2);
      expect(radio.sent.skip(1), ['stream remove 0x04000008', 'stream create type=dax_rx dax_channel=2']);
      radio.answer('stream create type=dax_rx dax_channel=2', 0, '4000009');
      update(dax: 0);
      expect(radio.sent.last, 'stream remove 0x04000009');
      update(dax: 0);
      rx.stop();
      expect(radio.sent.last, 'stream remove 0x04000009', reason: 'taken off DAX by the operator: not put back on, nor off again');
    });

    test('a stream the radio refuses is not asked for again', () {
      update(dax: 1);
      radio.answer('stream create type=dax_rx dax_channel=1', 0x50000016, 'Invalid DAX channel');
      update(dax: 1);
      expect(radio.sent, hasLength(1));
      expect(diagnostics.single, contains('refused'));
    });

    test('a stream granted after the stop is removed at once', () {
      update(dax: 1);
      rx.stop();
      radio.answer('stream create type=dax_rx dax_channel=1', 0, '4000008');
      expect(radio.sent.last, 'stream remove 0x04000008');
      expect(link.heard, isEmpty);
    });

    test('an output that will not open removes the stream it was for', () {
      link.refuse = 'no such device';
      update(dax: 1);
      radio.answer('stream create type=dax_rx dax_channel=1', 0, '4000008');
      expect(radio.sent.last, 'stream remove 0x04000008');
      expect(diagnostics.single, 'no such device');
    });
  });

  // The radio does not always echo a `slice set N dax=X` to the client that
  // sent it: kept at the dax=0 it last stated, the next status (a turn of
  // the dial) reads the slice as taken off DAX, and its audio stops.
  test('a slice HaLo put on DAX stays heard through the statuses that follow, which do not restate it', () async {
    final sink = _Sink(link);
    final session = FlexRadioSession(sink, meterHost: '127.0.0.1');
    void feed(String text) => session.radio.handleData(Uint8List.fromList(utf8.encode(text)));
    feed('V1.4.0.0\nH5AC2F980\n');
    session.startUpdates();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    feed('S5AC2F980|client 0x1C61D553 connected client_id=GUI-1 program=AetherSDR station=SHACK\n');
    feed('S5AC2F980|slice 0 in_use=1 RF_frequency=7.135000 client_handle=0x1C61D553 index_letter=A mode=LSB dax=0\n');
    final assign = sink.commands['slice set 0 dax=1'];
    expect(assign, isNotNull, reason: '${sink.commands.keys}');
    feed('R$assign|0|\n');
    final create = sink.commands['stream create type=dax_rx dax_channel=1'];
    expect(create, isNotNull, reason: '${sink.commands.keys}');
    feed('R$create|0|4000008\n');
    feed('S5AC2F980|slice 0 RF_frequency=7.136000\n');
    expect(sink.commands.keys, isNot(contains('stream remove 0x04000008')));
    session.teardown();
  });

  test('a session heard in HaLo names the engine\'s socket as its udpport, and the slice\'s audio reaches the ears', () async {
    // End to end: the meters' socket must be the engine's, or the DAX
    // packets arrive where nothing claims them, and the stream must be made
    // only once bound.
    final sink = _Sink(link);
    final session = FlexRadioSession(sink, meterHost: '127.0.0.1');
    void feed(String text) => session.handleData(Uint8List.fromList(utf8.encode(text)));
    feed('V1.4.0.0\nH5AC2F980\n');
    session.startUpdates();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final udpport = sink.commands.keys.firstWhere((c) => c.startsWith('client udpport '), orElse: () => 'none');
    final port = int.tryParse(udpport.split(' ').last);
    expect(port, isNotNull, reason: '${sink.commands.keys}');

    feed('S5AC2F980|client 0x1C61D553 connected client_id=GUI-1 program=AetherSDR station=SHACK\n');
    expect(sink.commands.keys.where((c) => c.startsWith('stream create')), isEmpty, reason: 'not bound yet');
    feed('S5AC2F980|slice 0 in_use=1 RF_frequency=7.135000 client_handle=0x1C61D553 index_letter=A mode=LSB dax=1\n');
    expect(sink.commands.keys, contains('client bind client_id=GUI-1'));
    final create = sink.commands['stream create type=dax_rx dax_channel=1'];
    expect(create, isNotNull, reason: '${sink.commands.keys}');
    feed('R$create|0|4000008\n');
    expect(link.heard, hasLength(1));

    final flex = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    for (var p = 0; p < 20; p++) {
      flex.send(_daxRxPacket(p, 0x04000008), InternetAddress.loopbackIPv4, port!);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final out = link.ears.pull(2400);
    final left = [for (var i = 0; i < out.length; i += 2) out[i]].skip(960).toList();
    expect(left.reduce(math.max), closeTo(0.5, 0.03), reason: 'the slice\'s tone, in the ears');

    session.teardown();
    expect(sink.commands.keys, contains('stream remove 0x04000008'));
    flex.close();
  });
}
