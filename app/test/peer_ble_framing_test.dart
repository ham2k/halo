// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The BLE frame layer (HALO-342), tested as two conduits joined by hand so
// every packet boundary is visible. The traps these exist to catch: a MSG
// escaping before the HELLO exchange (truncation risk on a lying MTU), a
// window that deadlocks on a frame bigger than itself, and a sender that
// keeps pouring bytes at a peer that stopped ACKing.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/peer/ble/peer_ble_framing.dart';

class _Harness {
  _Harness({int windowBytes = 32 * 1024, int ackStrideBytes = 8 * 1024, int maxMessageBytes = 1024 * 1024}) {
    conduit = BleFrameConduit(
      onMessage: messages.add,
      onSendable: () => sendableCalls++,
      onError: errors.add,
      windowBytes: windowBytes,
      ackStrideBytes: ackStrideBytes,
      maxMessageBytes: maxMessageBytes,
    );
  }

  late final BleFrameConduit conduit;
  final List<Uint8List> messages = [];
  final List<String> errors = [];
  int sendableCalls = 0;

  /// Drains every packet currently allowed out, recording sizes.
  List<Uint8List> drain() {
    final packets = <Uint8List>[];
    for (var packet = conduit.nextPacket(); packet != null; packet = conduit.nextPacket()) {
      packets.add(packet);
    }
    return packets;
  }
}

/// Two conduits with their packet streams cross-fed until quiescent.
void pump(_Harness a, _Harness b) {
  var moved = true;
  while (moved) {
    moved = false;
    for (final packet in a.drain()) {
      b.conduit.feed(packet);
      moved = true;
    }
    for (final packet in b.drain()) {
      a.conduit.feed(packet);
      moved = true;
    }
  }
}

void main() {
  test('nothing but the hello leaves before the peer hello arrives', () {
    final a = _Harness();
    a.conduit.sendHello(180);
    a.conduit.enqueueMessage(utf8.encode('queued before handshake'));

    final packets = a.drain();
    // The hello is sliced at the always-safe size; the MSG stays back — an
    // MTU view the peer has not confirmed cannot be trusted with it.
    expect(packets, isNotEmpty);
    for (final packet in packets) {
      expect(packet.length, lessThanOrEqualTo(bleSafeChunk));
    }
    expect(a.conduit.nextPacket(), isNull);
    expect(a.conduit.ready, isFalse);
  });

  test('handshake completes and messages cross whole, in order, chunked to the min view', () {
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(180);
    b.conduit.sendHello(50);
    final big = Uint8List.fromList(List.generate(5000, (i) => i & 0xFF));
    a.conduit.enqueueMessage(utf8.encode('first'));
    a.conduit.enqueueMessage(big);
    b.conduit.enqueueMessage(utf8.encode('reply'));

    // Capture A's packet sizes while pumping by hand once, then finish.
    final aPackets = <Uint8List>[];
    var moved = true;
    while (moved) {
      moved = false;
      for (final packet in a.drain()) {
        aPackets.add(packet);
        b.conduit.feed(packet);
        moved = true;
      }
      for (final packet in b.drain()) {
        a.conduit.feed(packet);
        moved = true;
      }
    }

    expect(a.conduit.ready, isTrue);
    expect(b.conduit.ready, isTrue);
    expect(b.messages, hasLength(2));
    expect(utf8.decode(b.messages.first), 'first');
    expect(b.messages[1], big);
    expect(utf8.decode(a.messages.single), 'reply');
    // B announced 50: every post-hello packet from A respects the MIN of
    // the two views, not A's own larger one.
    for (final packet in aPackets.skip(2)) {
      expect(packet.length, lessThanOrEqualTo(50));
    }
    expect(a.errors, isEmpty);
    expect(b.errors, isEmpty);
    // The running counter behind the stuck-link cap must return to zero on
    // a full drain — an arithmetic slip that leaves it negative silently
    // disables the cap, one that leaves it positive kills healthy links.
    expect(a.conduit.pendingOutboundBytes, 0);
    expect(b.conduit.pendingOutboundBytes, 0);
  });

  test('a closed window stalls the sender and an ACK reopens it', () {
    // Chunk (40) deliberately smaller than the window (100): a chunk that
    // can swallow the whole payload in one packet makes any window
    // assertion vacuous — deleting the window check would still pass.
    final a = _Harness(windowBytes: 100, ackStrideBytes: 50);
    final b = _Harness(windowBytes: 100, ackStrideBytes: 50);
    a.conduit.sendHello(40);
    b.conduit.sendHello(40);
    // Handshake only.
    pump(a, b);

    // 300 bytes of MSG against a 100-byte window: without B's ACKs the
    // sender must stop at the window, not pour the rest.
    a.conduit.enqueueMessage(Uint8List(300));
    final stalled = a.drain();
    final sentBytes = stalled.fold<int>(0, (sum, p) => sum + p.length);
    expect(sentBytes, lessThanOrEqualTo(100 + 40)); // window + one chunk overshoot
    expect(a.conduit.nextPacket(), isNull);

    // Feeding B lets it ACK; the ACK reopens A. The full frame then lands
    // even though it is three times the window — byte-granular ACKs are
    // what make that terminate instead of deadlocking.
    for (final packet in stalled) {
      b.conduit.feed(packet);
    }
    pump(a, b);
    expect(b.messages.single.length, 300);
  });

  test('ACKs flow even while the receiver’s own window is jammed', () {
    // Both sides streaming: if ACK frames queued behind the MSG window,
    // two full windows would deadlock forever. This pins the bypass.
    final a = _Harness(windowBytes: 64, ackStrideBytes: 32);
    final b = _Harness(windowBytes: 64, ackStrideBytes: 32);
    a.conduit.sendHello(500);
    b.conduit.sendHello(500);
    pump(a, b);

    a.conduit.enqueueMessage(Uint8List(400));
    b.conduit.enqueueMessage(Uint8List(400));
    pump(a, b);
    expect(a.messages.single.length, 400);
    expect(b.messages.single.length, 400);
  });

  test('a hello eaten by the radio is recovered by retransmission', () {
    // The field failure this pins: macOS peripherals silently drop
    // notifies fired right after a central subscribes, so one side's hello
    // (and anything sent on the strength of "hello sent = hello arrived")
    // vanishes. Ready must not report true until the peer ACKED our
    // hello, and a resend must complete the handshake.
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(100);
    b.conduit.sendHello(100);

    // A's first transmission dies on the floor; B's traffic flows.
    a.drain(); // dropped, never fed to B
    for (final packet in b.drain()) {
      a.conduit.feed(packet);
    }
    // A heard B's hello and acked it, but B has heard nothing from A: A
    // must NOT be ready (its hello is unconfirmed), B must not either.
    expect(b.conduit.ready, isFalse);
    expect(a.conduit.ready, isFalse,
        reason: 'handing this link to a session would send messages into the same hole the hello fell in');

    // The retry: A replays its hello; this time the radio carries it.
    a.conduit.resendHello();
    pump(a, b);
    expect(a.conduit.ready, isTrue);
    expect(b.conduit.ready, isTrue);

    // And traffic flows both ways afterwards.
    a.conduit.enqueueMessage(utf8.encode('after the recovery'));
    pump(a, b);
    expect(utf8.decode(b.messages.single), 'after the recovery');
  });

  test('garbage magic fails the stream instead of guessing', () {
    final a = _Harness();
    a.conduit.sendHello(100);
    a.conduit.feed(Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]));
    expect(a.errors, hasLength(1));
    expect(a.conduit.nextPacket(), isNull);
  });

  test('an insane length fails the stream before buffering it', () {
    final a = _Harness(maxMessageBytes: 1000);
    // Header claiming a 2 GB frame.
    a.conduit.feed(Uint8List.fromList([bleFrameMagic, bleFrameTypeMsg, 0xFF, 0xFF, 0xFF, 0x7F]));
    expect(a.errors, hasLength(1));
  });

  test('an oversized outbound message is an error, not a hang', () {
    final a = _Harness(maxMessageBytes: 100);
    a.conduit.sendHello(100);
    a.conduit.enqueueMessage(Uint8List(101));
    expect(a.errors, hasLength(1));
  });

  test('an unknown frame type is skipped and traffic continues', () {
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(100);
    b.conduit.sendHello(100);
    pump(a, b);

    // A future build's frame type, then a normal message. If the unknown
    // frame desynced the parser the message after it would be garbage.
    final unknown = Uint8List.fromList([bleFrameMagic, 0x7E, 3, 0, 0, 0, 9, 9, 9]);
    b.conduit.feed(unknown);
    a.conduit.enqueueMessage(utf8.encode('after'));
    pump(a, b);
    expect(utf8.decode(b.messages.single), 'after');
    expect(b.errors, isEmpty);
  });

  test('a ping crosses as proof of life without surfacing as a message', () {
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(100);
    b.conduit.sendHello(100);
    pump(a, b);

    a.conduit.sendPing();
    pump(a, b);
    expect(b.messages, isEmpty);
    expect(b.errors, isEmpty);
  });

  test('a message split across arbitrary packet boundaries reassembles', () {
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(500);
    b.conduit.sendHello(500);
    pump(a, b);

    a.conduit.enqueueMessage(utf8.encode('boundary torture'));
    // Re-slice A's outbound stream into 1-byte packets: reassembly must not
    // depend on the sender's chunking at all.
    final stream = <int>[];
    for (final packet in a.drain()) {
      stream.addAll(packet);
    }
    for (final byte in stream) {
      b.conduit.feed(Uint8List.fromList([byte]));
    }
    expect(utf8.decode(b.messages.single), 'boundary torture');
  });

  test('a stale ACK never moves the window backwards', () {
    final a = _Harness(windowBytes: 100, ackStrideBytes: 10);
    final b = _Harness(windowBytes: 100, ackStrideBytes: 10);
    a.conduit.sendHello(40);
    b.conduit.sendHello(40);
    pump(a, b);

    // 80 MSG bytes across, fully ACKed by B's real ACKs.
    a.conduit.enqueueMessage(Uint8List(80));
    pump(a, b);

    // A late/reordered ACK carrying an OLD count. Accepting it would wind
    // the window back — the sender then stalls on bytes the peer already
    // confirmed, which over a real link is a permanent one-way jam.
    final stale = ByteData(8)..setUint32(0, 1, Endian.little);
    a.conduit.feed(Uint8List.fromList(
        [bleFrameMagic, bleFrameTypeAck, 8, 0, 0, 0, ...stale.buffer.asUint8List()]));

    // With the accounting intact the whole next message fits the reopened
    // window and all 100 payload bytes leave, as three fragments each
    // carrying its own header; wound back, the sender stalls partway.
    a.conduit.enqueueMessage(Uint8List(100));
    final sent = a.drain().fold<int>(0, (sum, p) => sum + p.length);
    expect(sent, 100 + 3 * 6, reason: 'the message must leave in full');
  });

  test('a ping queued mid-message does not split it', () {
    // The field failure this pins: ACK and PING bypass the window, so one
    // can be queued while a message is half out. Without one frame per
    // packet those bytes land inside the MSG — the receiver eats them as
    // payload and parses the remainder as a header, and a working link
    // dies on the first QSO that crosses while a keepalive is due.
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(40);
    b.conduit.sendHello(40);
    pump(a, b);

    a.conduit.enqueueMessage(Uint8List(300));
    // Two packets out, so the message is mid-flight, then the keepalive.
    b.conduit.feed(a.conduit.nextPacket()!);
    b.conduit.feed(a.conduit.nextPacket()!);
    a.conduit.sendPing();
    pump(a, b);

    expect(b.errors, isEmpty);
    expect(b.messages.single.length, 300);
  });

  test('a fragmented message never puts two frames in one packet', () {
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(40);
    b.conduit.sendHello(40);
    pump(a, b);

    final payload = Uint8List.fromList(List.generate(300, (i) => i & 0xFF));
    a.conduit.enqueueMessage(payload);
    final packets = a.drain();

    // Each packet must stand alone as one whole frame: that is what lets
    // an ACK sit between any two of them without cutting one in half.
    for (final packet in packets) {
      expect(packet.length, lessThanOrEqualTo(40));
      expect(packet[0], bleFrameMagic);
      final length = packet[2] | (packet[3] << 8) | (packet[4] << 16) | (packet[5] << 24);
      expect(packet.length, 6 + length);
    }
    expect(packets.map((p) => p[1]).toList(),
        [...List.filled(packets.length - 1, bleFrameTypeMsgPart), bleFrameTypeMsg]);

    for (final packet in packets) {
      b.conduit.feed(packet);
    }
    expect(b.messages.single, payload);
  });

  test('a version 1 peer is sent the unfragmented stream', () {
    // Shipped builds skip MSGPART as an unknown type and would deliver a
    // TRUNCATED message — worse than the desync fragmenting cures. So the
    // fragmentation is gated on the peer announcing version 2.
    final hello = utf8.encode(jsonEncode({'v': 1, 'chunk': 40}));
    final helloFrame = <int>[bleFrameMagic, bleFrameTypeHello, hello.length, 0, 0, 0, ...hello];
    final ackFrame = <int>[bleFrameMagic, bleFrameTypeAck, 8, 0, 0, 0, ...Uint8List(8)];

    final a = _Harness();
    a.conduit.sendHello(40);
    a.drain();
    a.conduit.feed(Uint8List.fromList([...helloFrame, ...ackFrame]));
    a.drain(); // our answering ack
    expect(a.conduit.ready, isTrue);

    a.conduit.enqueueMessage(Uint8List(300));
    final packets = a.drain();
    // One frame sliced across packets: only the first carries a header.
    expect(packets.first[0], bleFrameMagic);
    expect(packets.first[1], bleFrameTypeMsg);
    expect(packets.map((p) => p.length).reduce((a, b) => a + b), 300 + 6);
    expect(a.conduit.pendingOutboundBytes, 0);

    // And a version 2 receiver still reads it — the reassembler tolerates
    // a frame that arrives across packets.
    final b = _Harness();
    b.conduit.sendHello(40);
    b.conduit.feed(Uint8List.fromList([...helloFrame, ...ackFrame]));
    for (final packet in packets) {
      b.conduit.feed(packet);
    }
    expect(b.messages.single.length, 300);
    expect(b.errors, isEmpty);
  });

  test('the peer version is latched at the first hello', () {
    // A peer retransmits its hello until ITS ready, which can outlast ours
    // — so a duplicate can arrive mid-message. Honouring a changed version
    // there swaps the meaning of the send offset between payload-relative
    // and frame-relative: the peer gets a fragment cut mid-header, or the
    // slice runs off the end of the message and throws out of nextPacket,
    // where the send worker is not looking.
    final a = _Harness();
    final b = _Harness();
    a.conduit.sendHello(40);
    b.conduit.sendHello(40);
    pump(a, b);

    a.conduit.enqueueMessage(Uint8List(300));
    final started = [a.conduit.nextPacket()!, a.conduit.nextPacket()!];
    final hello = utf8.encode(jsonEncode({'v': 1, 'chunk': 40}));
    a.conduit.feed(Uint8List.fromList(
        [bleFrameMagic, bleFrameTypeHello, hello.length, 0, 0, 0, ...hello]));

    for (final packet in [...started, ...a.drain()]) {
      b.conduit.feed(packet);
    }
    expect(b.messages.single.length, 300);
    expect(b.errors, isEmpty);
    expect(a.conduit.peerProtocolVersion, 2);
  });

  test('fragments that never close hit the message cap instead of growing', () {
    // A peer that streams MSGPARTs forever: each frame is legal on its own,
    // so only a cap on the REASSEMBLED size stops the buffer.
    final a = _Harness(maxMessageBytes: 100);
    a.conduit.sendHello(100);
    for (var i = 0; i < 5 && a.errors.isEmpty; i++) {
      a.conduit.feed(Uint8List.fromList(
          [bleFrameMagic, bleFrameTypeMsgPart, 40, 0, 0, 0, ...Uint8List(40)]));
    }
    expect(a.errors, hasLength(1));
    expect(a.messages, isEmpty);
  });
}
