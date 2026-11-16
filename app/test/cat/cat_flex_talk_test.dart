// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operator's voice from the station's microphone to a FlexRadio
// (docs/design/audio.md § 5): the dax_tx stream HaLo owns, the transmit
// gate around the key, and the commands a session sends around it. Nothing
// here keys a real radio: the "radio" is a loopback socket.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_dax_switch.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_dax_talk.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

const _stream = 0x84000002;

/// A microphone the test speaks into: every over routes [mic] to the sink.
class _Link implements TalkAudioLink {
  _Link(this.engine) : mic = engine.addPushed();

  @override
  final AudioEngine engine;
  final AudioEndpoint mic;
  String? refuse;
  int opened = 0;
  int closed = 0;

  @override
  TalkRoute? speak(AudioEndpoint sink, {required void Function(String reason) why}) {
    if (refuse case final reason?) {
      why(reason);
      return null;
    }
    opened++;
    final route = engine.connect(mic, sink, max: const Duration(milliseconds: 500));
    return _Route(() {
      route.disconnect();
      closed++;
    });
  }
}

class _Route implements TalkRoute {
  _Route(this._close);
  final void Function() _close;
  @override
  void close() => _close();
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

/// The left channel of a dax_tx packet, or null for one that is not.
List<double>? _samples(Uint8List data) {
  if (data.length < 28) return null;
  final bytes = ByteData.sublistView(data);
  if (bytes.getUint32(0) >> 28 != 1 || bytes.getUint32(4) != _stream) return null;
  return [for (var i = 28; i + 8 <= data.length; i += 8) bytes.getFloat32(i)];
}

double _peak(Iterable<double> samples) => samples.fold(0, (m, v) => math.max(m, v.abs()));

/// Waits until [done], or [max] has passed: what the engine's threads do
/// arrives when the machine gets to it.
Future<void> _until(bool Function() done, {Duration max = const Duration(seconds: 2)}) async {
  final stopwatch = Stopwatch()..start();
  while (!done() && stopwatch.elapsed < max) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late AudioEngine engine;
  late AudioSocket socket;
  late RawDatagramSocket flex;
  late List<Uint8List> packets;
  late _Link link;
  late _Radio radio;
  late List<String> diagnostics;
  late FlexDaxTalk talk;

  setUp(() async {
    engine = AudioEngine();
    socket = engine.openSocket();
    flex = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    packets = [];
    flex.listen((event) {
      if (event == RawSocketEvent.read) packets.add(flex.receive()!.data);
    });
    link = _Link(engine);
    radio = _Radio();
    diagnostics = [];
    talk = FlexDaxTalk(link: link, host: '127.0.0.1', port: flex.port, send: radio.send, diagnose: diagnostics.add);
  });

  tearDown(() {
    talk.stop();
    engine.close();
    flex.close();
  });

  void granted() {
    talk.update(socket: socket, bound: true);
    radio.answer('stream create type=dax_tx', 0, '84000002');
  }

  test('waits for the bind to the GUI client before it asks for the stream', () {
    // Made unbound, the stream would be a transmit object of HaLo's own
    // client, not the one the operator's radio transmits.
    talk.update(socket: socket, bound: false);
    expect(radio.sent, isEmpty);
    talk.update(socket: socket, bound: true);
    expect(radio.sent, ['stream create type=dax_tx']);
  });

  test('a key before the radio grants the stream keys nothing', () {
    talk.update(socket: socket, bound: true);
    expect(talk.key(), isFalse);
    expect(link.opened, 0);
    expect(diagnostics.single, contains('granted'));
  });

  test('a microphone that will not open keys nothing and claims nothing', () async {
    // Claimed, the stream would take the DAX transmit audio of a
    // digital-mode program on the same radio, for an over never sent.
    granted();
    link.refuse = 'no such microphone';
    expect(talk.key(), isFalse);
    expect(radio.sent.where((c) => c.contains('tx=1')), isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(packets, isEmpty, reason: 'nothing sent with no over');
    expect(diagnostics.single, 'no such microphone');
  });

  test('the microphone reaches the radio only between the key and the unkey, and silence is fed past it', () async {
    granted();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(packets, isEmpty, reason: 'nothing sent while not keyed');

    // Spoken before the key: the gate drops it, never sending what the
    // microphone heard before the operator keyed.
    link.mic.push(Float32List.fromList(List.filled(4800, 0.9)));
    expect(talk.key(), isTrue);
    expect(radio.sent.last, 'stream set 0x84000002 tx=1', reason: 'claimed again for each over');
    // Fed as a microphone feeds it, 10 ms at a time: half a second pushed at
    // once overflows the route's 100 ms, and on a loaded machine the sender
    // drains it late enough that the route skips past the whole tone.
    for (var chunk = 0; chunk < 50; chunk++) {
      link.mic.push(Float32List.fromList([for (var i = chunk * 480; i < (chunk + 1) * 480; i++) 0.5 * math.sin(2 * math.pi * 1000 * i / 48000)]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // Waited for, not slept on: the engine's threads are the machine's, and
    // on a loaded one the tone arrives later than on an idle one.
    await _until(() => _peak([for (final p in packets) ...?_samples(p)]) > 0.45);
    final keyed = [for (final p in packets) ...?_samples(p)];
    expect(packets.every((p) => _samples(p) != null), isTrue, reason: 'VITA type 1 on our stream');
    expect(_peak(keyed), closeTo(0.5, 0.05), reason: 'the tone, and never the 0.9 said before the key');

    talk.unkey();
    final atUnkey = packets.length;
    await _until(() => packets.length > atUnkey && _peak(_samples(packets.last)!) < 0.001);
    expect(packets.length, greaterThan(atUnkey), reason: 'silence fed through the unkey');
    expect(_peak(_samples(packets.last)!), lessThan(0.001), reason: 'the gate shut');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final afterTail = packets.length;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(packets.length, afterTail, reason: 'nothing sent once the tail is over');
    expect(link.closed, 1, reason: 'the microphone closed with the over');
    // The over ends on the gate's ramp, not on the route's cut: cut, the
    // voice stops mid-cycle, a click on the air.
    final all = [for (final p in packets) ...?_samples(p)];
    var step = 0.0;
    for (var i = 1; i < all.length; i++) {
      step = math.max(step, (all[i] - all[i - 1]).abs());
    }
    expect(step, lessThan(0.5 * 2 * math.pi * 1000 / 24000 + 0.02), reason: 'no click where the over ends');
  });

  test('a key inside the last over\'s tail closes that over\'s microphone', () async {
    // Its close waits out the gate's ramp; a key that cancels the wait must
    // close it itself, or the microphone stays open for good.
    granted();
    expect(talk.key(), isTrue);
    talk.unkey();
    expect(talk.key(), isTrue);
    expect(link.closed, 1);
    expect(link.opened, 2);
  });

  // The tail it cancelled is what stops the last over's silence: left
  // sending, the radio gets silence until the slice goes.
  test('a key inside the last over\'s tail whose microphone will not open stops the silence', () async {
    granted();
    expect(talk.key(), isTrue);
    talk.unkey();
    link.refuse = 'unplugged';
    expect(talk.key(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final stopped = packets.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(packets.length, stopped);
  });

  test('a stop removes the stream', () {
    granted();
    talk.stop();
    expect(radio.sent.last, 'stream remove 0x84000002');
  });

  group('a session', () {
    late _Sink sink;
    late FlexRadioSession session;
    void feed(String text) => session.handleData(Uint8List.fromList(utf8.encode(text)));

    setUp(() async {
      FlexDaxSwitch.forgetOwed();
      sink = _Sink(link);
      session = FlexRadioSession(sink, meterHost: '127.0.0.1');
      feed('V1.4.0.0\nH5AC2F980\n');
      session.startUpdates();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      feed('S5AC2F980|client 0x1C61D553 connected client_id=GUI-1 program=AetherSDR station=SHACK\n');
      feed('S5AC2F980|slice 0 in_use=1 RF_frequency=14.250000 client_handle=0x1C61D553 index_letter=A mode=USB tx=1\n');
    });

    tearDown(() => session.teardown());

    test('keyed for the voice, it claims its stream and turns DAX on before it keys, and unkeys before DAX goes back', () {
      // Keyed ahead of DAX, the radio sends its own mic's hiss for a
      // moment; DAX put back ahead of the unkey, the end of the over goes
      // out on the mic.
      final create = sink.commands['stream create type=dax_tx'];
      expect(create, isNotNull, reason: '${sink.commands.keys}');
      feed('R$create|0|84000002\n');
      expect(session.talksThroughHalo, isTrue);

      expect(session.setPttTalking(true), isTrue);
      final order = sink.ordered;
      final claim = order.indexOf('stream set 0x84000002 tx=1');
      final dax = order.indexOf('transmit set dax=1');
      final key = order.indexOf('xmit 1');
      expect([claim, dax, key].every((i) => i >= 0), isTrue, reason: '$order');
      expect(claim < key && dax < key, isTrue, reason: '$order');

      feed('S5AC2F980|transmit dax=1\n');
      expect(session.setPttTalking(false), isTrue);
      final after = sink.ordered;
      final unkey = after.lastIndexOf('xmit 0');
      final restore = after.lastIndexOf('transmit set dax=0');
      expect(unkey, greaterThan(key), reason: '$after');
      if (restore >= 0) expect(restore, greaterThan(unkey), reason: '$after');
    });

    test('keyed before the stream is granted, it sends nothing that keys', () {
      expect(session.setPttTalking(true), isFalse);
      expect(sink.ordered.where((c) => c == 'xmit 1' || c == 'transmit set dax=1'), isEmpty);
      expect(sink.audioProblem, isNotNull, reason: 'the row says why the key did nothing');
    });

    // Unkeyed behind the app's back, the app would hold the key for its
    // whole timeout, and the operator's next press would key nothing.
    test('the radio refusing the stream after the key lets go of the key through the app', () {
      final create = sink.commands['stream create type=dax_tx'];
      feed('R$create|0|84000002\n');
      expect(session.setPttTalking(true), isTrue);
      final claim = sink.commands['stream set 0x84000002 tx=1'];
      feed('R$claim|50000016|\n');
      expect(sink.released, 1);
      expect(sink.audioProblem, isNotNull);
    });
  });
}

class _Sink implements EquipmentSink, TalkAudioSink, AudioProblemSink {
  _Sink(this.talkAudio);

  String? audioProblem;
  var released = 0;

  @override
  void reportAudioProblem(String? message) => audioProblem = message;

  @override
  void releaseKey() => released++;

  @override
  final TalkAudioLink? talkAudio;
  final sent = <String>[];

  /// The commands sent, in order, without their `C<seq>|` envelope.
  List<String> get ordered => [
    for (final line in sent)
      for (final command in line.trim().split('\n'))
        if (command.startsWith('C')) command.substring(command.indexOf('|') + 1),
  ];

  /// The sequence number of each command.
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
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}
