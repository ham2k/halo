// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scripted Icom radio for the UDP transport (icom_network_transport_io.dart).
//
// A real RawDatagramSocket can't be made to fail on demand without OS-level
// network manipulation, which is exactly the kind of flaky, non-deterministic
// test this project avoids. RawDatagramSocket is `abstract interface class
// ... extends Stream<RawSocketEvent>`, so a fake that extends Stream (for
// its default map/where/etc — the only abstract Stream member is `listen`)
// and implements RawDatagramSocket's handful of I/O members gives full,
// deterministic control over both directions: `send()` observes outgoing
// packets and `queueReply`/`emitSocketError` drive the socket's read side.
// `IcomNetworkTransport.debugSocketBinder` (a test seam, same pattern as
// ErrorPolicy.debugTreatAsWeb) hands the transport these fakes instead of
// real sockets, in the fixed order it always binds them: control, serial,
// audio. The same doubles record where each packet goes.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

Map<String, dynamic> icomTestTarget() => {'host': '127.0.0.1', 'username': 'N0CALL', 'password': 'hunter2'};

/// A [length]-byte packet of zeros with specific byte offsets overridden —
/// far less error-prone than hand-concatenating spreads for a wire format
/// this file doesn't otherwise need to build.
List<int> icomPacket(int length, [Map<int, int> overrides = const {}]) {
  final bytes = List<int>.filled(length, 0);
  overrides.forEach((offset, value) => bytes[offset] = value);
  return bytes;
}

// The radio-side replies these tests script. Field values that the
// transport reads but doesn't validate (session ids, auth ids, the stream
// token) are left at zero — only the bytes _onEvent's predicates actually
// check are set.
/// Carries the radio's session id at 8, which a disconnect names: zero is
/// no session at all.
List<int> icomPkt4Reply() => icomPacket(16, {0: 0x10, 4: 0x04, 8: 0x61, 9: 0x86, 10: 0xd2, 11: 0x1b});
List<int> icomPkt6AnswerReply() => icomPacket(16, {0: 0x10, 4: 0x06, 6: 0x01});
List<int> icomLoginAcceptedReply() => icomPacket(96, {0: 0x60});
List<int> icomStreamTokenReply() => icomPacket(168, {0: 0xa8});
List<int> icomStreamAnswerAcceptedReply() => icomPacket(80, {0: 0x50, 20: 0x02, 66: 0x12, 67: 0x34});
List<int> icomStreamAnswerAuthFailedReply() => icomPacket(80, {0: 0x50, 20: 0x02, 48: 0xff, 49: 0xff, 50: 0xff});
List<int> icomLogoutAckReply() => icomPacket(64, {0: 0x40, 20: 0x02});

/// A [RawDatagramSocket] double: `send()` is observed synchronously by
/// [onSend], and [queueReply]/[emitSocketError] drive what the transport's
/// `_onEvent`/`_onSocketError` see next, on the same turn of the event loop
/// a real socket's callback would use.
class FakeIcomSocket extends Stream<RawSocketEvent> implements RawDatagramSocket {
  FakeIcomSocket(this._replyAddress);

  final InternetAddress _replyAddress;
  final _controller = StreamController<RawSocketEvent>();
  final _incoming = Queue<Datagram>();

  final sent = <List<int>>[];
  final sentToPorts = <int>{};
  var closeCalled = false;
  void Function(List<int> bytes)? onSend;

  void queueReply(List<int> bytes) {
    _incoming.add(Datagram(Uint8List.fromList(bytes), _replyAddress, 0));
    _controller.add(RawSocketEvent.read);
  }

  void emitSocketError(Object error) => _controller.addError(error);

  @override
  StreamSubscription<RawSocketEvent> listen(void Function(RawSocketEvent event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Datagram? receive() => _incoming.isEmpty ? null : _incoming.removeFirst();

  @override
  int send(List<int> buffer, InternetAddress address, int port) {
    final copy = List<int>.from(buffer);
    sent.add(copy);
    sentToPorts.add(port);
    onSend?.call(copy);
    return copy.length;
  }

  @override
  int get port => 40000 + (identityHashCode(this) % 1000);
  @override
  InternetAddress get address => _replyAddress;
  @override
  void close() => closeCalled = true;
  @override
  bool readEventsEnabled = true;
  @override
  bool writeEventsEnabled = true;
  @override
  bool multicastLoopback = true;
  @override
  int multicastHops = 1;
  @override
  NetworkInterface? multicastInterface;
  @override
  bool broadcastEnabled = false;
  @override
  void joinMulticast(InternetAddress group, [NetworkInterface? interface]) {}
  @override
  void leaveMulticast(InternetAddress group, [NetworkInterface? interface]) {}
  @override
  Uint8List getRawOption(RawSocketOption option) => Uint8List(0);
  @override
  void setRawOption(RawSocketOption option) {}
}

/// Wires [socket] to auto-answer whichever handshake steps [answer...]
/// leaves enabled, with the real transport's own request bytes as the
/// discriminator (see icom_network_transport_io.dart / icom_network_protocol.dart
/// for the shapes: pkt3/pkt6 are `0x10` typed at byte 4; login is `0x80`;
/// the post-login ack, stream-token request, and logout request are all
/// `0x40`-typed 64-byte auth packets told apart by the magic byte at 21).
/// A disabled step (or one the test overrides via [onEachSend], called
/// before the auto-responder on every send) is left for the test to drive.
void wireIcomSession(
  FakeIcomSocket socket, {
  bool answerHandshake = true,
  bool answerLogin = true,
  bool answerStreamToken = true,
  bool answerStreams = true,
  bool answerLogout = true,
  void Function(List<int> bytes)? onEachSend,
}) {
  socket.onSend = (bytes) {
    onEachSend?.call(bytes);
    if (answerHandshake && bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
      socket.queueReply(icomPkt4Reply());
    } else if (answerHandshake && bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x06) {
      socket.queueReply(icomPkt6AnswerReply());
    } else if (answerLogin && bytes[0] == 0x80) {
      socket.queueReply(icomLoginAcceptedReply());
    } else if (answerStreamToken && bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x05) {
      socket.queueReply(icomStreamTokenReply());
    } else if (answerStreams && bytes[0] == 0x90) {
      socket.queueReply(icomStreamAnswerAcceptedReply());
    } else if (answerLogout && bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x01) {
      socket.queueReply(icomLogoutAckReply());
    }
  };
}
