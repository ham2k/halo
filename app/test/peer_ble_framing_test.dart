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

    // With the accounting intact the whole next frame fits the reopened
    // window and every byte leaves; wound back, the sender stalls partway.
    a.conduit.enqueueMessage(Uint8List(100));
    final sent = a.drain().fold<int>(0, (sum, p) => sum + p.length);
    expect(sent, 100 + 6, reason: 'the frame (payload + header) must leave in full');
  });
}
