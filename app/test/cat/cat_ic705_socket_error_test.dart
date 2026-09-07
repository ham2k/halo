// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Coverage for the Icom UDP transport's socket-error handling
// (icom_network_transport_io.dart's _onSocketError/_failPending/
// _declareLost machinery) — no test drives a socket-level failure through
// any phase of a connect attempt without this file.
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
// audio.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_io.dart';

Map<String, dynamic> _target() => {
      'host': '127.0.0.1',
      'username': 'N0CALL',
      'password': 'hunter2',
    };

/// A [length]-byte packet of zeros with specific byte offsets overridden —
/// far less error-prone than hand-concatenating spreads for a wire format
/// this file doesn't otherwise need to build.
List<int> _packet(int length, [Map<int, int> overrides = const {}]) {
  final bytes = List<int>.filled(length, 0);
  overrides.forEach((offset, value) => bytes[offset] = value);
  return bytes;
}

// The radio-side replies these tests script. Field values that the
// transport reads but doesn't validate (session ids, auth ids, the stream
// token) are left at zero — only the bytes _onEvent's predicates actually
// check are set.
List<int> _pkt4Reply() => _packet(16, {0: 0x10, 4: 0x04});
List<int> _pkt6AnswerReply() => _packet(16, {0: 0x10, 4: 0x06, 6: 0x01});
List<int> _loginAcceptedReply() => _packet(96, {0: 0x60});
List<int> _streamTokenReply() => _packet(168, {0: 0xa8});
List<int> _streamAnswerAcceptedReply() => _packet(80, {0: 0x50, 20: 0x02, 66: 0x12, 67: 0x34});
List<int> _streamAnswerAuthFailedReply() => _packet(80, {0: 0x50, 20: 0x02, 48: 0xff, 49: 0xff, 50: 0xff});
List<int> _logoutAckReply() => _packet(64, {0: 0x40, 20: 0x02});

/// A [RawDatagramSocket] double: `send()` is observed synchronously by
/// [onSend], and [queueReply]/[emitSocketError] drive what the transport's
/// `_onEvent`/`_onSocketError` see next, on the same turn of the event loop
/// a real socket's callback would use.
class _FakeIcomSocket extends Stream<RawSocketEvent> implements RawDatagramSocket {
  _FakeIcomSocket(this._replyAddress);

  final InternetAddress _replyAddress;
  final _controller = StreamController<RawSocketEvent>();
  final _incoming = Queue<Datagram>();

  final sent = <List<int>>[];
  var closeCalled = false;
  void Function(List<int> bytes)? onSend;

  void queueReply(List<int> bytes) {
    _incoming.add(Datagram(Uint8List.fromList(bytes), _replyAddress, 0));
    _controller.add(RawSocketEvent.read);
  }

  void emitSocketError(Object error) => _controller.addError(error);

  @override
  StreamSubscription<RawSocketEvent> listen(void Function(RawSocketEvent event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _controller.stream
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Datagram? receive() => _incoming.isEmpty ? null : _incoming.removeFirst();

  @override
  int send(List<int> buffer, InternetAddress address, int port) {
    final copy = List<int>.from(buffer);
    sent.add(copy);
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
void _wireSession(
  _FakeIcomSocket socket, {
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
      socket.queueReply(_pkt4Reply());
    } else if (answerHandshake && bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x06) {
      socket.queueReply(_pkt6AnswerReply());
    } else if (answerLogin && bytes[0] == 0x80) {
      socket.queueReply(_loginAcceptedReply());
    } else if (answerStreamToken && bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x05) {
      socket.queueReply(_streamTokenReply());
    } else if (answerStreams && bytes[0] == 0x90) {
      socket.queueReply(_streamAnswerAcceptedReply());
    } else if (answerLogout && bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x01) {
      socket.queueReply(_logoutAckReply());
    }
  };
}

void main() {
  final loopback = InternetAddress('127.0.0.1');
  late _FakeIcomSocket control;
  late _FakeIcomSocket serial;
  late _FakeIcomSocket audio;

  setUp(() {
    control = _FakeIcomSocket(loopback);
    serial = _FakeIcomSocket(loopback);
    audio = _FakeIcomSocket(loopback);
    final dispensed = Queue<_FakeIcomSocket>.from([control, serial, audio]);
    IcomNetworkTransport.debugSocketBinder = (address, port) async => dispensed.removeFirst();
  });

  tearDown(() {
    IcomNetworkTransport.debugSocketBinder = null;
  });

  test('a socket error before pkt4 fails the connect immediately, not after the handshake timeout', () async {
    // Without an onError on the socket listener, this failure escapes raw
    // and unclassified — or, once onError exists but only calls onLost
    // (not wired up yet this early), vanishes into a debugPrint while the
    // caller waits out the full 3s handshake timeout for no reason.
    control.onSend = (bytes) {
      if (bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
        control.emitSocketError(const SocketException('No route to host'));
      }
    };

    final stopwatch = Stopwatch()..start();
    await expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'a socket error must fail the pending step immediately, not wait out _handshakeTimeout');
  });

  test('a socket error during the login wait propagates as itself, not the curated IcomLoginTimeout', () {
    // Deliberate: forcing a socket-level failure into IcomLoginTimeout's
    // text ("the radio did not answer... check that no other program is
    // connected") would misdiagnose a "no route to host" as radio-side
    // silence — exactly the speculative-cause substitution IcomLoginTimeout's
    // own doc comment warns against. A raw SocketException surfacing here is
    // the same behavior CatConnectFailure already gives a TCP or serial
    // radio whose connect fails at the socket layer.
    _wireSession(control, answerLogin: false, onEachSend: (bytes) {
      if (bytes[0] == 0x80) control.emitSocketError(const SocketException('Network is unreachable'));
    });
    _wireSession(serial);

    return expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
  });

  test('a socket error during awaitStreamToken fails fast instead of being silently dropped', () async {
    // awaitStreamToken() polls with realNowUtc(), not _expect(), so without
    // its own _failPending hook a socket error here has nowhere to go —
    // onLost isn't wired up yet either, this early — and vanishes into a
    // debugPrint while the attempt rides out the full 3s poll deadline.
    _wireSession(control, answerStreamToken: false, onEachSend: (bytes) {
      if (bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x05) {
        control.emitSocketError(const SocketException('No route to host'));
      }
    });
    _wireSession(serial);

    final stopwatch = Stopwatch()..start();
    await expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'must fail immediately, not ride out the ~3s stream-token poll deadline');
  });

  test('a socket error during connect-failure cleanup logout still closes every socket and keeps the real cause', () async {
    // logout()'s ack-wait must catch more than TimeoutException, or a
    // socket error there escapes uncaught out of the catch block in
    // _attempt that calls it — skipping audio?.close(), serial?.close(),
    // control?.close(), and rethrow. The escaping error would also silently
    // replace the ORIGINAL failure (here, the stream request being
    // rejected) with an unrelated logout-time error.
    _wireSession(control, answerStreams: false, answerLogout: false, onEachSend: (bytes) {
      if (bytes[0] == 0x90) {
        control.queueReply(_streamAnswerAuthFailedReply());
      } else if (bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x01) {
        control.emitSocketError(const SocketException('No route to host (logout)'));
      }
    });
    _wireSession(serial);

    await expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<StateError>()),
      reason: 'the stream-request rejection must survive, not the unrelated logout-time socket error',
    );
    expect(control.closeCalled, isTrue, reason: 'the logout socket error must not skip the rest of cleanup');
    expect(serial.closeCalled, isTrue);
    expect(audio.closeCalled, isTrue);
  });

  test('a socket error on serial while control awaits the stream request fails fast with the real cause', () async {
    // serial's own handshake is done by the time control sends the stream
    // request (requestStreams sends it synchronously before this callback
    // can fire), so _failPending is a stale, resolved hook on serial by
    // now — and _IcomConnection, which wires up the real onLost, doesn't
    // exist until requestStreams succeeds. Without _attempt's own onSetupLost
    // wiring for this window, a serial socket error here vanishes and the
    // attempt rides out control's ~3s stream-answer timeout instead — with
    // a generic message, not the SocketException asserted below, which is
    // what lets ErrorPolicy's cat-equipment-unreachable rule still recognize
    // it as an ordinary unreachable-radio event rather than an app bug.
    _wireSession(serial);
    _wireSession(control, answerStreams: false, onEachSend: (bytes) {
      if (bytes[0] == 0x90) {
        serial.emitSocketError(const SocketException('No route to host (serial, mid-setup)'));
      }
    });

    final stopwatch = Stopwatch()..start();
    await expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'must fail fast via the interim onLost, not wait out control\'s own stream-answer timeout');
  });

  test('a socket error on control while serial is opening still surfaces once requestStreams runs', () async {
    // The mirror-image window: control's own handshake (and login and
    // awaitStreamToken) are all done by the time serial starts its own
    // pkt3/pkt4/pkt6 exchange, so control's _failPending is stale there too
    // — and _attempt doesn't race serial's own open() (see the comment on
    // that call), so this one can't fail AS fast as the serial-side case
    // above. It still must fail, once requestStreams is reached, with the
    // real cause rather than silently succeeding on a control session that
    // is already dead.
    _wireSession(control);
    _wireSession(serial, onEachSend: (bytes) {
      if (bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
        control.emitSocketError(const SocketException('No route to host (control, mid-setup)'));
      }
    });

    await expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
  });

  test('a control error survives even when serial\'s own un-raced open() times out on its own', () async {
    // Same window as above, but serial's own handshake also never gets an
    // answer — the same outage that killed control plausibly kills it too.
    // serial.open() isn't raced against `lost` (see _attempt's own
    // comment), so it runs out its own real ~3s handshake timeout on this
    // path; preferLostCause is what still prefers control's already-known
    // SocketException over the generic TimeoutException that produces,
    // once serial's open() finally gives up and throws.
    _wireSession(control);
    _wireSession(serial, answerHandshake: false, onEachSend: (bytes) {
      if (bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
        control.emitSocketError(const SocketException('No route to host (control, mid-setup)'));
      }
    });

    await expectLater(
      const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('a socket error once the session is up routes through onLost, same as the radio going quiet', () async {
    // Post-handshake, this is the ping-timeout path's own mechanism
    // (_declareLost) — proves the fast-fail machinery hands off to it
    // cleanly rather than the two paths fighting over the same completer.
    _wireSession(control);
    _wireSession(serial);

    final connection = await const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken());
    addTearDown(() => connection.close());

    control.emitSocketError(const SocketException('No route to host (idle)'));

    await connection.closed.timeout(const Duration(seconds: 1));
  });

  test('an audio socket error is swallowed — nothing is pending on it, and it carries no connection to lose', () async {
    _wireSession(control);
    _wireSession(serial);

    final connection = await const IcomNetworkTransport().connect(_target(), cancel: CatCancelToken());
    addTearDown(() => connection.close());

    var closedFired = false;
    unawaited(connection.closed.then((_) => closedFired = true));

    audio.emitSocketError(const SocketException('No route to host (audio)'));

    // An unhandled error on this stream would fail the test on its own (an
    // uncaught error in the test zone); this only needs to rule out the
    // OTHER quiet failure mode — the audio error being misread as the
    // control/serial session going quiet and tearing the connection down.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(closedFired, isFalse, reason: 'an audio-socket error must not be read as the radio going quiet');
  });
}
