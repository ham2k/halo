// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The computer's voice keyer on an Elecraft K4: MI switched to LINE IN over
// USB or the LAN CAT port (k4_setting_switch.dart, kenwood_driver.dart), and
// the recording sent over the secure remote connection as EM1 audio packets
// (k4_remote_audio.dart, k4_shared_session.dart).
//
// The traps are a K4 that transmits its mic under the recording because MI
// was not LINE IN, an operator whose mic stays dead because MI was not put
// back, a remote connection left streaming raw audio at ten times its
// bandwidth because EM was not put back, and audio packets — every one of
// which keys the K4 — going out before the key or after the unkey.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_audio.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_setting_switch.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';

/// A K4 holding MI and EM: it answers a read of either with its value, and
/// takes a set unless [refuseSets]. Everything sent is kept, a command each.
/// While [holding], its replies wait for [release]; [dropNext] loses the
/// next one.
class _Radio {
  int mi = 1;
  int em = 3;
  bool refuseSets = false;
  bool holding = false;
  bool dropNext = false;
  final sent = <String>[];
  final _held = <String>[];
  void Function(String reply)? _answer;

  set answer(void Function(String reply) answer) => _answer = answer;

  void _reply(String reply) {
    if (dropNext) {
      dropNext = false;
    } else if (holding) {
      _held.add(reply);
    } else {
      _answer?.call(reply);
    }
  }

  void release() {
    holding = false;
    for (final reply in [..._held]) {
      _answer?.call(reply);
    }
    _held.clear();
  }

  void receive(List<int> bytes) {
    for (final part in ascii.decode(bytes).split(';')) {
      if (part.isEmpty) continue;
      sent.add('$part;');
      switch (part) {
        case 'MI':
          _reply('MI$mi;');
        case 'EM':
          _reply('EM$em;');
        default:
          final set = RegExp(r'^(MI|EM)(\d)$').firstMatch(part);
          if (set == null || refuseSets) continue;
          final value = int.parse(set.group(2)!);
          set.group(1) == 'MI' ? mi = value : em = value;
      }
    }
  }

  /// What was sent about the key and the two settings, in order.
  List<String> get keying => [
    for (final command in sent)
      if (RegExp(r'^(MI|EM|TX|RX)').hasMatch(command)) command,
  ];
}

class _Sink implements EquipmentSink {
  _Sink(this.radio);

  final _Radio radio;
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => radio.receive(bytes);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(K4SettingSwitch.forgetOwed);

  group('MI over USB or the LAN CAT port', () {
    late _Radio radio;
    late _Sink sink;
    late KenwoodSession session;

    KenwoodSession connect({int? mi, bool isK4 = true, bool remote = false}) {
      radio = _Radio();
      if (mi != null) radio.mi = mi;
      sink = _Sink(radio);
      session = KenwoodSession(sink, isK4: isK4, remote: remote, config: const {'port': '/dev/cu.usbserial-K4'});
      radio.answer = (reply) => session.handleData(Uint8List.fromList(ascii.encode(reply)));
      return session;
    }

    test('LINE IN goes out ahead of the key, and the operator\'s input is put back after the unkey, each read to see it took', () {
      connect(mi: 1);
      expect(session.switchesToComputerAudio, isTrue);
      session.setPttWithComputerAudio(true);
      expect(radio.keying, ['MI;', 'MI2;', 'TX;', 'MI;'], reason: 'read ahead of the set, so the rear mic is what goes back');
      expect(radio.mi, 2);
      radio.sent.clear();

      session.setPttWithComputerAudio(false);
      expect(radio.keying, ['RX;', 'MI1;', 'MI;']);
      expect(radio.mi, 1);
      expect(sink.diagnostics, isEmpty);
      session.teardown();
    });

    test('an input known before the key is set without asking again', () {
      connect(mi: 0);
      session.setPttWithComputerAudio(true);
      session.setPttWithComputerAudio(false);
      radio.sent.clear();
      session.setPttWithComputerAudio(true);
      expect(radio.keying, ['MI2;', 'TX;', 'MI;']);
      session.setPttWithComputerAudio(false);
      expect(radio.mi, 0);
      session.teardown();
    });

    test('an input already on LINE IN is the operator\'s choice, and left on it', () {
      connect(mi: 2);
      session.setPttWithComputerAudio(true);
      radio.sent.clear();
      session.setPttWithComputerAudio(false);
      expect(radio.keying, ['RX;'], reason: 'nothing to put back');
      expect(radio.mi, 2);
      session.teardown();
    });

    // The radio is on the air with its mic: the message must stop, and the
    // next one not key the mic again for its key-up delay.
    test('a LINE IN set the radio does not take unkeys it, stops the message, and keys plainly after', () {
      connect(mi: 1);
      radio.refuseSets = true;
      var stopped = 0;
      session.setPttWithComputerAudio(true, refused: () => stopped++);
      expect(radio.keying, ['MI;', 'MI2;', 'TX;', 'MI;', 'RX;']);
      expect(stopped, 1);
      expect(sink.diagnostics.single, contains('MI1'));

      // The keyer's own unkey, as the message stops.
      radio.refuseSets = false;
      session.setPttWithComputerAudio(false);
      expect(session.switchesToComputerAudio, isFalse, reason: 'MI read back as the operator had it');
      radio.sent.clear();
      session.setPttWithComputerAudio(true);
      expect(radio.keying, ['TX;']);
      session.teardown();
    });

    // A second phone memory pressed while the first plays: the first's
    // restore check, answered late, is not the second's, and taken as it the
    // second's unkey would leave the mic dead for good.
    test('a message keyed before the last one\'s restore is read back still puts MI back after it', () {
      connect(mi: 1);
      session.setPttWithComputerAudio(true);
      radio.holding = true;
      session.setPttWithComputerAudio(false);
      session.setPttWithComputerAudio(true);
      radio.release();
      expect(radio.mi, 2);
      radio.sent.clear();
      session.setPttWithComputerAudio(false);
      expect(radio.keying, ['RX;', 'MI1;', 'MI;']);
      expect(radio.mi, 1);
      expect(sink.diagnostics, isEmpty);
      session.teardown();
    });

    // Matched in order, one lost reply would make the next message's check
    // the restore's: a restore sent again mid-message puts the mic on the
    // air, and the reply after it reads as a refusal.
    test('a reply that never comes is given up on, and the restore it checked is sent again', () {
      fakeAsync((async) {
        connect(mi: 1);
        session.setPttWithComputerAudio(true);
        radio.dropNext = true;
        session.setPttWithComputerAudio(false);
        radio.sent.clear();
        async.elapse(const Duration(seconds: 3));
        expect(radio.keying, ['MI1;', 'MI;']);

        radio.sent.clear();
        session.setPttWithComputerAudio(true);
        async.elapse(const Duration(seconds: 1));
        expect(radio.keying, ['MI2;', 'TX;', 'MI;']);
        expect(radio.mi, 2);
        expect(sink.diagnostics, isEmpty);
        session.setPttWithComputerAudio(false);
        expect(radio.mi, 1);
        session.teardown();
      });
    });

    test('a restore that does not take is sent again, and reported once it never does', () {
      fakeAsync((async) {
        connect(mi: 1);
        session.setPttWithComputerAudio(true);
        radio.refuseSets = true;
        radio.sent.clear();
        session.setPttWithComputerAudio(false);
        async.elapse(const Duration(seconds: 3));
        expect(radio.keying.where((command) => command == 'MI1;').length, 3);
        expect(sink.diagnostics, ['MI left at 2 after 3 restores']);
        session.teardown();
      });
    });

    test('a connection closing while keyed unkeys, then puts MI back, and the next session to the radio settles it', () {
      fakeAsync((async) {
        connect(mi: 1);
        session.setPttWithComputerAudio(true);
        // The restore behind the unkey is lost with the link.
        radio.refuseSets = true;
        radio.sent.clear();
        session.teardown();
        expect(radio.keying, ['RX;', 'MI1;']);

        final left = radio.mi;
        expect(left, 2);
        connect(mi: left);
        session.startUpdates();
        async.flushMicrotasks();
        expect(radio.mi, 1, reason: 'still LINE IN, so put back');
        session.teardown();
        async.flushTimers();

        // Settled: a session after that one owes nothing.
        connect(mi: 2);
        session.startUpdates();
        async.flushMicrotasks();
        expect(radio.mi, 2);
        session.teardown();
        async.flushTimers();
      });
    });

    test('a restore owed by an earlier session is forgotten once the operator has moved MI', () {
      fakeAsync((async) {
        connect(mi: 1);
        session.setPttWithComputerAudio(true);
        radio.refuseSets = true;
        session.teardown();

        connect(mi: 0);
        session.startUpdates();
        async.flushMicrotasks();
        expect(radio.mi, 0);
        session.teardown();
        async.flushTimers();

        connect(mi: 2);
        session.startUpdates();
        async.flushMicrotasks();
        expect(radio.mi, 2, reason: 'nothing owed any more');
        session.teardown();
        async.flushTimers();
      });
    });

    // Over the secure connection the recording is its own stream, and on
    // another Kenwood-protocol rig MI is not the K4's input select.
    test('only a K4 on USB or the LAN CAT port switches MI', () {
      expect(connect(remote: true).switchesToComputerAudio, isFalse);
      session.setPttWithComputerAudio(true);
      expect(radio.keying, ['TX;']);
      expect(connect(isK4: false).switchesToComputerAudio, isFalse);
    });
  });

  group('the remote audio packet', () {
    test('type 1, version 1, the sequence, EM1, frames little-endian, 12 kHz, then stereo samples little-endian', () {
      final samples = Int16List(720 * 2)..setAll(0, [0x0102, 0x0102, -2, -2]);
      final envelope = encodeK4RemoteAudio(sequence: 0x1ff, frames: 720, samples: samples);
      final data = ByteData.sublistView(envelope);
      expect(envelope.sublist(0, 4), [0xfe, 0xfd, 0xfc, 0xfb]);
      expect(data.getUint32(4, Endian.big), 7 + 720 * 4, reason: 'the envelope length is big-endian');
      expect(envelope.sublist(8, 12), [1, 1, 0xff, 1], reason: 'the sequence wraps at a byte');
      expect(data.getUint16(12, Endian.little), 720);
      expect(envelope[14], 0, reason: 'rate code 0 is 12 kHz');
      expect(envelope.sublist(15, 19), [0x02, 0x01, 0x02, 0x01]);
      expect(data.getInt16(19, Endian.little), -2);
      expect(envelope.sublist(envelope.length - 4), [0xfb, 0xfc, 0xfd, 0xfe]);
      expect(K4RemoteDecoder().add(envelope), isEmpty, reason: 'the decoder reads it as audio, which it discards');
    });
  });

  group('the remote output', () {
    late Map<String, Float32List> files;
    late List<Uint8List> packets;

    setUp(() {
      files = {};
      packets = [];
    });

    K4RemoteAudioOutput open(FakeAsync async) => K4RemoteAudioOutput(
      send: packets.add,
      decode: (path, {required rate, required channels}) {
        expect((rate, channels), (12000, 1));
        return files[path] ?? (throw HaloAudioException('open file: no such file'));
      },
      clockMicros: () => async.elapsed.inMicroseconds,
    );

    int sequenceOf(Uint8List envelope) => envelope[10];

    // Every packet keys the K4: one before TX; goes out unkeyed-to-keyed
    // with no say from the operator, one after RX; keys it again.
    test('nothing goes out but the message: no silence before it, none after it', () {
      fakeAsync((async) {
        final output = open(async);
        files['/v/1.wav'] = Float32List(12000);
        output.keyed();
        output.startSilence('/v/1.wav');
        async.elapse(const Duration(milliseconds: 250));
        expect(packets, isEmpty, reason: 'the key-up delay is silent on the wire');

        final playback = output.play('/v/1.wav');
        async.elapse(const Duration(seconds: 3));
        expect(packets.length, (12000 / k4RemoteAudioFrames).ceil());
        expect(playback.isPlaying, isFalse);
      });
    });

    test('mono copied to both channels, clamped, and paced one packet ahead', () {
      fakeAsync((async) {
        final output = open(async);
        files['/v/1.wav'] = Float32List.fromList([0.5, -2.0, ...List.filled(12000 * 2, 0.0)]);
        output.keyed();
        output.play('/v/1.wav');
        async.elapse(const Duration(milliseconds: 5));
        final first = ByteData.sublistView(packets.first, 15);
        expect([for (var i = 0; i < 4; i++) first.getInt16(i * 2, Endian.little)], [16384, 16384, -32767, -32767]);
        expect(packets.length, 2, reason: 'the one playing and one ahead');
        async.elapse(const Duration(seconds: 1));
        expect(packets.length, inInclusiveRange(17, 19), reason: '60 ms a packet');
      });
    });

    test('each transmission numbers its packets from 0', () {
      fakeAsync((async) {
        final output = open(async);
        files['/v/1.wav'] = Float32List(1440);
        output.keyed();
        output.play('/v/1.wav');
        async.elapse(const Duration(seconds: 1));
        expect(packets.map(sequenceOf), [0, 1]);
        packets.clear();
        output.keyed();
        output.play('/v/1.wav');
        async.elapse(const Duration(seconds: 1));
        expect(packets.map(sequenceOf), [0, 1]);
      });
    });
  });

  group('EM over the secure connection', () {
    late _Radio radio;
    late List<Uint8List> audio;
    late K4SharedSession owner;
    late NetworkTransmitAudioSession main;
    late NetworkTransmitAudioSession sub;
    late _Sink sink;

    void connect({bool carriesAudio = true, int em = 3}) {
      radio = _Radio()..em = em;
      audio = [];
      sink = _Sink(radio);
      owner = K4SharedSession(send: radio.receive, pan: const Stream.empty(), config: const {'host': '10.0.0.4'}, sendAudio: carriesAudio ? audio.add : null);
      radio.answer = (reply) => owner.handleData(Uint8List.fromList(ascii.encode(reply)));
      main = owner.attach(sink, receiver: 'main') as NetworkTransmitAudioSession;
      sub = owner.attach(_Sink(radio), receiver: 'sub') as NetworkTransmitAudioSession;
      main.startUpdates();
      sub.startUpdates();
      addTearDown(() {
        owner.teardown();
        main.teardown();
        sub.teardown();
      });
    }

    AudioOutput? openOutput(NetworkTransmitAudioSession session) => session.openTransmitAudio((_, {required rate, required channels}) => Float32List(12000));

    // Offered where it cannot play, the radio would be what a message goes
    // to, and the CQ would go out as silence.
    test('the radio is offered as the output only on a connection that carries audio', () {
      connect(carriesAudio: false);
      expect(main.sendsTransmitAudio, isFalse);
      expect(openOutput(main), isNull);
      expect(main.switchesToComputerAudio, isFalse);
    });

    test('EM1 goes out ahead of the key, and the connection\'s own EM is put back after the unkey, each read to see it took', () {
      connect();
      expect(main.sendsTransmitAudio, isTrue);
      radio.sent.clear();
      openOutput(main);
      expect(radio.keying, ['EM;'], reason: 'read as the output opens, so the key asks nothing first');
      radio.sent.clear();

      expect(main.switchesToComputerAudio, isTrue);
      main.setPttWithComputerAudio(true);
      expect(radio.keying, ['EM1;', 'TX;', 'EM;']);
      expect(radio.em, 1);
      radio.sent.clear();

      main.setPttWithComputerAudio(false);
      expect(radio.keying, ['RX;', 'EM3;', 'EM;']);
      expect(radio.em, 3);
    });

    test('Sub plays into the one transmitter too, and Main cannot unkey it', () {
      connect();
      openOutput(sub);
      sub.setPttWithComputerAudio(true);
      radio.sent.clear();
      main.setPttWithComputerAudio(false);
      expect(radio.keying, isEmpty);
      sub.setPttWithComputerAudio(false);
      expect(radio.keying, ['RX;', 'EM3;', 'EM;']);
    });

    // The K4 would read raw samples as Opus, or drop them: the message
    // must stop rather than key a silent transmitter for its length.
    test('an EM set the radio does not take stops the message, and the radio is not offered again', () {
      connect();
      final output = openOutput(main)!;
      radio.refuseSets = true;
      main.setPttWithComputerAudio(true);
      expect(output.isAlive, isFalse);
      expect(main.sendsTransmitAudio, isFalse);
      expect(sink.diagnostics.last, contains('EM3'));
      radio.refuseSets = false;
      main.setPttWithComputerAudio(false);
      expect(radio.em, 3);
    });

    // The keyer is still playing: packets after the unkey would key the
    // radio again with nobody's message on the air.
    test('a receiver leaving while it holds the key stops the audio, unkeys and puts EM back', () {
      connect();
      final output = openOutput(main)!;
      main.setPttWithComputerAudio(true);
      radio.sent.clear();
      main.stopUpdates();
      expect(output.isAlive, isFalse);
      expect(radio.keying, ['RX;', 'EM3;', 'EM;']);
    });

    test('the connection closing while keyed unkeys, then puts EM back', () {
      connect();
      final output = openOutput(main)!;
      main.setPttWithComputerAudio(true);
      radio.sent.clear();
      owner.teardown();
      expect(radio.keying, ['RX;', 'EM3;']);
      expect(output.isAlive, isFalse);
    });

    // Each receiver has its own keyer, and each opens its output as it is
    // made: Sub connecting must not cut short a CQ playing on Main.
    test('one receiver opening its output leaves the other\'s playing', () {
      fakeAsync((async) {
        connect();
        final playing = openOutput(main)!;
        main.setPttWithComputerAudio(true);
        final playback = playing.play('/v/1.wav');
        openOutput(sub);
        async.elapse(const Duration(milliseconds: 100));
        expect(playing.isAlive, isTrue);
        expect(playback.isPlaying, isTrue);
        main.setPttWithComputerAudio(false);
      });
    });

    // Two streams interleaved on the one transmitter would be neither
    // message.
    test('the other receiver keying stops a message still playing', () {
      fakeAsync((async) {
        connect();
        final playing = openOutput(main)!;
        main.setPttWithComputerAudio(true);
        playing.play('/v/1.wav');
        final next = openOutput(sub)!;
        sub.setPttWithComputerAudio(true);
        expect(playing.isAlive, isFalse);
        expect(next.isAlive, isTrue);
        sub.setPttWithComputerAudio(false);
      });
    });

    test('played into a sound device, the key is a plain one', () {
      connect();
      main.setPttWithComputerAudio(true);
      expect(radio.keying.where((command) => command.startsWith('EM')), isEmpty);
    });
  });
}
