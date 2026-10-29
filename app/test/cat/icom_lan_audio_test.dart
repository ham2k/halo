// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An Icom's transmit audio over its network link (icom_lan_audio.dart, and
// the audio session in icom_network_transport_io.dart).
//
// The traps are a radio that drops what it is sent without a word — a header
// field in the wrong byte order, samples in the wrong format — a radio that
// transmits its mic over the recording because DATA OFF MOD was not LAN, an
// operator whose mic stays dead because it was not put back, and the radio
// being offered as the output where nothing can reach it.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_lan_audio.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_protocol.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_io.dart';

import '../support/fake_clock.dart';
import '../support/fake_icom_radio.dart';

class _Link implements TransmitAudioLink {
  final sent = <Uint8List>[];
  final _gone = Completer<void>();

  void lose() => _gone.complete();

  @override
  Future<void> get gone => _gone.future;

  @override
  void send(Uint8List pcm) => sent.add(pcm);
}

class _AudioConnection implements TransmitAudioConnection {
  _AudioConnection(this.link);

  final _Link link;

  @override
  bool get carriesTransmitAudio => true;

  @override
  Future<TransmitAudioLink> openTransmitAudio() async => link;
}

/// A CI-V bus whose radio keeps DATA OFF MOD at [source]: it answers a read
/// of the IC-705's item with it, takes a set unless [refuseSets], and ACKs
/// everything else.
class _Sink implements EquipmentSink, TransmitAudioSink {
  _Sink({this.transmitAudio});

  @override
  TransmitAudioConnection? transmitAudio;

  IcomCivSession? session;
  final sent = <List<int>>[];
  final diagnostics = <String?>[];
  int source = 0;
  bool refuseSets = false;

  /// A model without the item, which NAKs every frame for it.
  bool lacksItem = false;

  @override
  void send(List<int> bytes) {
    sent.add(bytes);
    final menu = bytes.length > 8 && bytes[4] == 0x1A && bytes[5] == 0x05 && bytes[6] == 0x01 && bytes[7] == 0x18;
    if (menu && lacksItem) {
      session?.handleData(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], 0xFA, 0xFD]));
      return;
    }
    if (menu && bytes.length == 9) {
      session?.handleData(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], 0x1A, 0x05, 0x01, 0x18, source, 0xFD]));
      return;
    }
    if (menu && bytes.length == 10 && !refuseSets) source = bytes[8];
    session?.handleData(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], 0xFB, 0xFD]));
  }

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const ic705 = 0xA4;
  const us = icomNetworkControllerAddress;
  const lanMod = [0x01, 0x18, 3];

  group('the transmit audio packet', () {
    test('a 0x18 header, little-endian like the rest, but the audio\'s counter and length big-endian', () {
      final packet = buildAudioData(0xc2fc0000, 0x6186d21b, 0x0102, List.generate(960, (i) => i & 0xFF));
      expect(packet.length, 0x18 + 960);
      expect(packet.sublist(0, 4), [0xd8, 0x03, 0, 0], reason: 'the whole length, little-endian');
      expect(packet.sublist(4, 8), [0, 0, 0, 0], reason: 'type 0; the session stamps the sequence');
      expect(packet.sublist(8, 16), [0xc2, 0xfc, 0, 0, 0x61, 0x86, 0xd2, 0x1b]);
      expect(packet.sublist(16, 18), [0x80, 0x00]);
      expect(packet.sublist(18, 20), [0x01, 0x02], reason: 'the audio counter is big-endian');
      expect(packet.sublist(22, 24), [0x03, 0xc0], reason: '960, big-endian');
      expect(packet.sublist(24, 28), [0, 1, 2, 3]);
    });

    test('the stream request asks for 16-bit PCM both ways, which is what is sent', () {
      final packet = buildRequestStreams(
        local: 1,
        remote: 2,
        innerSeq: 0,
        authId: List.filled(6, 0),
        a8ReplyId: List.filled(16, 0),
        username: 'op',
        ourSerialPort: 1000,
        ourAudioPort: 1001,
        audioSampleRate: icomAudioSampleRate,
        txBufferMs: icomTxBufferMs,
        deviceName: 'IC-705',
      );
      expect(packet.sublist(112, 116), [0x01, 0x01, icomAudioCodecPcm16, icomAudioCodecPcm16]);
      expect(icomAudioCodecPcm16, 0x04);
    });
  });

  group('the output', () {
    late Map<String, Float32List> files;
    late List<String> diagnostics;

    setUp(() {
      files = {};
      diagnostics = [];
    });

    IcomLanAudioOutput open(FakeAsync async, Future<TransmitAudioLink> link) => IcomLanAudioOutput(
      link: link,
      decode: (path, {required rate, required channels}) {
        expect((rate, channels), (48000, 1), reason: 'the format the stream request asks for');
        return files[path] ?? (throw HaloAudioException('open file: no such file'));
      },
      diagnose: diagnostics.add,
      clockMicros: () => async.elapsed.inMicroseconds,
    );

    test('ten milliseconds a packet, as 16-bit little-endian samples, clamped', () {
      fakeAsync((async) {
        final link = _Link();
        final output = open(async, Future.value(link));
        async.flushMicrotasks();
        files['/v/1.wav'] = Float32List.fromList([0.5, -0.5, 1.0, -1.0, 2.0, -2.0, ...List.filled(1000, 0.25)]);
        output.play('/v/1.wav');
        async.elapse(const Duration(milliseconds: 5));
        final first = ByteData.sublistView(link.sent.first);
        expect(link.sent.first.length, 960);
        expect([for (var i = 0; i < 6; i++) first.getInt16(i * 2, Endian.little)], [16384, -16384, 32767, -32767, 32767, -32767]);
        expect(ByteData.sublistView(link.sent[1]).getInt16(0, Endian.little), 8192, reason: 'the next 480 frames follow on');
        expect(link.sent.every((pcm) => pcm.length <= icomAudioMaxBytes), isTrue);
      });
    });

    // Sent faster, the radio's buffer overflows and the end is lost; slower,
    // it runs dry mid-word.
    test('paces packets at the rate the audio plays', () {
      fakeAsync((async) {
        final link = _Link();
        final output = open(async, Future.value(link));
        async.flushMicrotasks();
        files['/v/1.wav'] = Float32List(48000 * 3);
        output.play('/v/1.wav');
        async.elapse(const Duration(seconds: 1));
        expect(link.sent.length, inInclusiveRange(100, 106));
      });
    });

    test('nothing goes out before the audio stream is open, and the message waits for it', () {
      fakeAsync((async) {
        final link = _Link();
        final opening = Completer<TransmitAudioLink>();
        final output = open(async, opening.future);
        files['/v/1.wav'] = Float32List.fromList(List.generate(4800, (i) => i / 4800));
        output.play('/v/1.wav');
        async.elapse(const Duration(milliseconds: 100));
        opening.complete(link);
        async.elapse(const Duration(milliseconds: 5));
        expect(ByteData.sublistView(link.sent.first).getInt16(2, Endian.little), (1 / 4800 * 32767).round(), reason: 'the start, not 100 ms in');
      });
    });

    test('a radio that will not open the stream, or stops answering on it, is not taking audio', () {
      fakeAsync((async) {
        final refused = open(async, Future.error(const TransmitAudioUnavailable('no answer to the handshake')));
        async.flushMicrotasks();
        expect(refused.isAlive, isFalse);
        expect(diagnostics, ['the radio did not open its audio stream: no answer to the handshake']);

        final link = _Link();
        final dropped = open(async, Future.value(link));
        async.flushMicrotasks();
        expect(dropped.isAlive, isTrue);
        link.lose();
        async.flushMicrotasks();
        expect(dropped.isAlive, isFalse);
      });
    });
  });

  group('DATA OFF MOD', () {
    late _Sink sink;
    late IcomCivSession session;

    setUp(IcomLanModSwitch.forgetOwed);

    IcomCivSession connect({TransmitAudioConnection? audio, Object? mod = lanMod, int? source}) {
      sink = _Sink(transmitAudio: audio);
      if (source != null) sink.source = source;
      session = IcomCivSession(sink, radioAddress: ic705, controllerAddress: us, config: {civLanModConfigKey: ?mod, 'host': '10.0.0.5'});
      sink.session = session;
      return session;
    }

    void openOutput() => session.openTransmitAudio((_, {required rate, required channels}) => Float32List(0));

    List<int> menu(List<int> data) => buildCivFrame(to: ic705, from: us, command: 0x1A, data: [0x05, 0x01, 0x18, ...data]);
    final key = buildSetTransmitFrame(to: ic705, from: us, on: true);
    final unkey = buildSetTransmitFrame(to: ic705, from: us, on: false);
    final readMod = menu(const []);

    // Offered where it cannot play, the radio would be what a message goes
    // to, and the CQ would go out as silence.
    test('the radio is offered as the output only over the network, on a model whose source is known', () {
      expect(connect(audio: _AudioConnection(_Link())).sendsTransmitAudio, isTrue);
      expect(connect().sendsTransmitAudio, isFalse, reason: 'a serial port carries no audio');
      expect(connect(audio: _AudioConnection(_Link()), mod: null).sendsTransmitAudio, isFalse, reason: 'its mic would go out over the recording');
      expect(connect(audio: _AudioConnection(_Link()), mod: [1, 2]).sendsTransmitAudio, isFalse);
      expect(connect().openTransmitAudio((_, {required rate, required channels}) => Float32List(0)), isNull);
    });

    test('LAN goes out ahead of the key, and what was there is put back after the unkey and read to see it took', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()));
        sink.source = 1;
        session.openTransmitAudio((_, {required rate, required channels}) => Float32List(0));
        async.flushMicrotasks();
        expect(sink.sent, [readMod], reason: 'read as the output opens, so the key asks nothing first');
        sink.sent.clear();

        expect(session.switchesToComputerAudio, isTrue);
        session.setPttWithComputerAudio(true);
        expect(sink.sent, [
          menu([3]),
          key,
          readMod,
        ], reason: 'read back after the key, to see LAN took');
        expect(sink.source, 3);
        sink.sent.clear();

        session.setPttWithComputerAudio(false);
        expect(sink.sent, [
          unkey,
          menu([1]),
          readMod,
        ]);
        expect(sink.source, 1);
        expect(sink.diagnostics, isEmpty);
      });
    });

    // Read behind the key, the answer would be the LAN just set, and the
    // operator's own source would be lost.
    test('a source never read is read ahead of the LAN set, and that is what is put back', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()));
        sink.source = 1;
        // The radio's answer to the read as the output opens is lost.
        sink.session = null;
        session.openTransmitAudio((_, {required rate, required channels}) => Float32List(0));
        async.elapse(civAnswerTimeout * 2);
        sink.session = session;
        sink.sent.clear();
        session.setPttWithComputerAudio(true);
        expect(sink.sent, [
          readMod,
          menu([3]),
          key,
          readMod,
        ]);
        session.setPttWithComputerAudio(false);
        expect(sink.source, 1);
      });
    });

    test('a radio already on LAN is the operator\'s choice, and left on it', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()));
        sink.source = 3;
        session.openTransmitAudio((_, {required rate, required channels}) => Float32List(0));
        async.flushMicrotasks();
        sink.sent.clear();
        session.setPttWithComputerAudio(true);
        session.setPttWithComputerAudio(false);
        expect(sink.sent, [key, unkey]);

        // Learnt only from the read ahead of the set, it is no restore owed
        // either, and nothing is said about one.
        connect(audio: _AudioConnection(_Link()), source: 3);
        sink.session = null;
        openOutput();
        async.elapse(civAnswerTimeout * 2);
        sink.session = session;
        session.setPttWithComputerAudio(true);
        session.setPttWithComputerAudio(false);
        expect(sink.diagnostics.where((note) => note!.contains('DATA OFF MOD')), isEmpty);
      });
    });

    // The radio's mic is on the air under the recording otherwise, and a
    // wrong menu item for a model would do it on every message.
    test('a LAN set the radio does not take stops the message, and the radio is not offered again', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()), source: 1);
        openOutput();
        async.flushMicrotasks();
        sink.refuseSets = true;
        session.setPttWithComputerAudio(true);
        async.flushMicrotasks();
        expect(session.sendsTransmitAudio, isFalse);
        expect(sink.diagnostics.single, startsWith('the radio read DATA OFF MOD as 1 after the LAN set'));
        expect(session.openTransmitAudio((_, {required rate, required channels}) => Float32List(0)), isNull);
      });
    });

    // Every model's item is from wfview's rig files and none has met a radio:
    // one that is wrong is NAKed, and nothing read would ever say so.
    test('a model that refuses the item outright is not offered, and its message stops', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()));
        sink.lacksItem = true;
        openOutput();
        async.flushMicrotasks();
        expect(session.sendsTransmitAudio, isFalse, reason: 'found out from the read as the output opens, before any key');
        expect(sink.diagnostics.single, startsWith('the radio refused DATA OFF MOD'));

        // And refused only at the key: the message stops there.
        connect(audio: _AudioConnection(_Link()), source: 1);
        openOutput();
        async.flushMicrotasks();
        sink.lacksItem = true;
        session.setPttWithComputerAudio(true);
        async.flushMicrotasks();
        expect(session.sendsTransmitAudio, isFalse);
        session.setPttWithComputerAudio(false);
        expect(sink.diagnostics.where((note) => note!.contains('never read')), isEmpty);
      });
    });

    // The keyer's unkey after its output dies reads whether the session
    // switches: answered no, the restore would never go and the mic stay dead.
    test('an output that dies mid-message still has its source put back at the unkey', () {
      fakeAsync((async) {
        final link = _Link();
        connect(audio: _AudioConnection(link), source: 1);
        openOutput();
        async.flushMicrotasks();
        session.setPttWithComputerAudio(true);
        link.lose();
        async.flushMicrotasks();
        expect(session.switchesToComputerAudio, isTrue);
        sink.sent.clear();
        session.setPttWithComputerAudio(false);
        expect(sink.sent, [
          unkey,
          menu([1]),
          readMod,
        ]);
        expect(session.switchesToComputerAudio, isFalse);
      });
    });

    // Played into a sound device on the same connection, LAN would take the
    // radio's audio from nothing.
    test('played into a sound device, the key is a plain one', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()));
        expect(session.switchesToComputerAudio, isFalse);
        session.setPttWithComputerAudio(true);
        session.setPttWithComputerAudio(false);
        expect(sink.sent, [key, unkey]);
      });
    });

    test('a restore that does not take is sent again, and reported once it never does', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()));
        sink.source = 1;
        session.openTransmitAudio((_, {required rate, required channels}) => Float32List(0));
        async.flushMicrotasks();
        session.setPttWithComputerAudio(true);
        sink.refuseSets = true;
        sink.sent.clear();
        session.setPttWithComputerAudio(false);
        async.elapse(const Duration(seconds: 3));
        expect(sink.sent.where((frame) => frame.length == 10 && frame[8] == 1).length, 3);
        expect(sink.diagnostics, ['DATA OFF MOD left on LAN after 3 restores']);
      });
    });

    // A radio keeps the last of two frames sent back to back: a restore
    // after the unkey could take its place and leave it transmitting.
    test('a connection closing while keyed sends only the unkey, and the next one to the radio puts the source back', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()), source: 1);
        openOutput();
        async.flushMicrotasks();
        session.setPttWithComputerAudio(true);
        sink.sent.clear();
        session.teardown();
        expect(sink.sent, [unkey]);

        final radio = sink.source;
        connect(audio: _AudioConnection(_Link()), source: radio);
        session.startUpdates();
        async.flushMicrotasks();
        expect(sink.source, 1);
        session.teardown();

        // Settled: a session after that one owes nothing.
        connect(audio: _AudioConnection(_Link()), source: 3);
        session.startUpdates();
        async.flushMicrotasks();
        expect(sink.source, 3);
        session.teardown();
      });
    });

    test('a restore owed by an earlier session is forgotten once the operator has moved the source', () {
      fakeAsync((async) {
        connect(audio: _AudioConnection(_Link()), source: 1);
        openOutput();
        async.flushMicrotasks();
        session.setPttWithComputerAudio(true);
        session.teardown();

        connect(audio: _AudioConnection(_Link()), source: 2);
        session.startUpdates();
        async.flushMicrotasks();
        expect(sink.source, 2);
        session.teardown();

        connect(audio: _AudioConnection(_Link()), source: 3);
        session.startUpdates();
        async.flushMicrotasks();
        expect(sink.source, 3, reason: 'nothing owed any more');
        session.teardown();
      });
    });

    test('every network Icom pins its own source, and no serial one does', () {
      final expected = {
        'ic705-network': [0x01, 0x18, 3],
        'ic7300mk2-network': [0x00, 0x84, 5],
        'ic7610-network': [0x00, 0x91, 5],
        'ic7760-network': [0x01, 0x29, 9],
        'ic9700-network': [0x01, 0x15, 5],
        'ic905-network': [0x01, 0x26, 3],
        'ic7850-network': [0x00, 0x63, 9],
        'ic7851-network': [0x00, 0x63, 9],
      };
      final icoms = EquipmentRegistry().types.where((type) => type.driver is IcomCivDriver);
      for (final type in icoms) {
        expect(type.overrides[civLanModConfigKey], expected[type.key], reason: type.key);
      }
      expect(icoms.map((type) => type.key), containsAll(expected.keys));
    });
  });

  group('the audio session', () {
    final loopback = InternetAddress('127.0.0.1');
    late FakeIcomSocket control;
    late FakeIcomSocket serial;
    late FakeIcomSocket audio;

    void bindFakeSockets() {
      control = FakeIcomSocket(loopback);
      serial = FakeIcomSocket(loopback);
      audio = FakeIcomSocket(loopback);
      final dispensed = Queue<FakeIcomSocket>.from([control, serial, audio]);
      IcomNetworkTransport.debugSocketBinder = (address, port) async => dispensed.removeFirst();
      wireIcomSession(control);
      wireIcomSession(serial);
    }

    setUp(bindFakeSockets);

    tearDown(() => IcomNetworkTransport.debugSocketBinder = null);

    // Opened at every connect, the radio would stream receive audio at every
    // operator on WiFi, whether or not they play a message.
    test('is not opened until transmit audio is asked for, and has nothing to end then', () async {
      final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
      await connection.close();
      expect(audio.sent, isEmpty);
      expect(audio.closeCalled, isTrue);
    });

    test('opens on the radio\'s audio port, sends tracked packets, and goes down first', () async {
      wireIcomSession(audio);
      final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
      final audioConnection = connection as TransmitAudioConnection;
      final link = await audioConnection.openTransmitAudio();
      expect(identical(await audioConnection.openTransmitAudio(), link), isTrue, reason: 'one session for the connection');
      expect(audio.sentToPorts, {icomAudioPort});

      audio.sent.clear();
      link.send(Uint8List(960));
      link.send(Uint8List(960));
      final packets = audio.sent.where((p) => p.length == 0x18 + 960).toList();
      expect(packets, hasLength(2));
      expect(packets[1][6] + (packets[1][7] << 8), packets[0][6] + (packets[0][7] << 8) + 1, reason: 'the outer sequence, stamped');
      expect(packets[1].sublist(18, 20), [0, 1], reason: 'the audio counter');

      final order = <String>[];
      audio.onSend = (b) => b.length == 16 && b[4] == 0x05 ? order.add('audio') : null;
      serial.onSend = (b) => b.length == 16 && b[4] == 0x05 ? order.add('serial') : null;
      control.onSend = (b) {
        if (b.length == 64 && b[0] == 0x40 && b[21] == 0x01) control.queueReply(icomLogoutAckReply());
        if (b.length == 16 && b[4] == 0x05) order.add('control');
      };
      await connection.close();
      expect(order, ['audio', 'serial', 'control']);
      await link.gone;
    });

    test(
      'a radio that does not open it leaves the connection up, and is asked again next time',
      () => runOnFakeClock((async) async {
        // Bound inside the fake clock's zone, so its handshake timeout is the
        // fake clock's.
        bindFakeSockets();
        wireIcomSession(audio, answerHandshake: false);
        final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
        final audioConnection = connection as TransmitAudioConnection;
        await expectLater(audioConnection.openTransmitAudio(), throwsA(isA<TransmitAudioUnavailable>()));
        var closed = false;
        unawaited(connection.closed.then((_) => closed = true));
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);

        wireIcomSession(audio);
        expect(await audioConnection.openTransmitAudio(), isA<TransmitAudioLink>());
        await connection.close();
      }),
    );

    // Kept, every later message would key a radio that gets nothing, until
    // a reconnect.
    test('a stream lost while CI-V carries on is ended, and opened afresh for the next message', () async {
      wireIcomSession(audio);
      final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
      addTearDown(connection.close);
      final audioConnection = connection as TransmitAudioConnection;
      final first = await audioConnection.openTransmitAudio();
      audio.sent.clear();
      audio.emitSocketError(const SocketException('No route to host (audio)'));
      await first.gone;
      expect(audio.sent.where((b) => b.length == 16 && b[4] == 0x05), hasLength(1), reason: 'the radio told the session is over');
      final second = await audioConnection.openTransmitAudio();
      expect(identical(second, first), isFalse);
      expect(audio.sent.where((b) => b.length == 16 && b[4] == 0x03), hasLength(1), reason: 'a new handshake');
    });

    test('a disconnect during its handshake ends the radio\'s half of it, and the ask fails', () async {
      // pkt4 answered, pkt6 not: the radio holds a session for us.
      wireIcomSession(audio, answerHandshake: false);
      audio.onSend = (b) {
        if (b.length >= 8 && b[0] == 0x10 && b[4] == 0x03) audio.queueReply(icomPkt4Reply());
      };
      final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
      final asked = expectLater(
        (connection as TransmitAudioConnection).openTransmitAudio(),
        throwsA(isA<TransmitAudioUnavailable>().having((e) => e.reason, 'reason', 'the connection closed')),
      );
      await Future<void>.delayed(Duration.zero);
      await connection.close();
      await asked;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(audio.sent.where((b) => b.length == 16 && b[4] == 0x05), hasLength(1), reason: 'once, as every channel is ended');
    });

    // The radio's audio port is no field, so off its factory ports it is
    // not known, and the radio is not offered rather than sent audio at a
    // port that may be another radio's.
    test('a node on ports other than the factory ones carries no transmit audio', () async {
      final moved = await const IcomNetworkTransport().connect({...icomTestTarget(), 'controlPort': 50101, 'serialPort': 50102}, cancel: CatCancelToken());
      addTearDown(moved.close);
      expect((moved as TransmitAudioConnection).carriesTransmitAudio, isFalse);
    });
  });
}
