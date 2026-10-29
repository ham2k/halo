// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Coverage for the Icom UDP transport's socket-error handling
// (icom_network_transport_io.dart's _onSocketError/_failPending/
// _declareLost machinery) — no test drives a socket-level failure through
// any phase of a connect attempt without this file. The radio is scripted
// by test/support/fake_icom_radio.dart, which also records where each
// packet goes, which is how the configured radio ports are checked too.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_protocol.dart' show icomControlPort, icomSerialPort;
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_io.dart';

import '../support/fake_clock.dart';
import '../support/fake_icom_radio.dart';

void main() {
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
  }

  setUp(bindFakeSockets);

  tearDown(() {
    IcomNetworkTransport.debugSocketBinder = null;
  });

  test(
    'a socket error before pkt4 fails the connect immediately, not after the handshake timeout',
    () => runOnFakeClock((async) async {
      // Bound again inside the fake clock's zone: sockets made in setUp
      // deliver their events through the real event loop, which its steps
      // hold up.
      bindFakeSockets();
      // Without an onError on the socket listener, this failure escapes raw
      // and unclassified — or, once onError exists but only calls onLost
      // (not wired up yet this early), vanishes into a debugPrint while the
      // caller waits out the full 3s handshake timeout for no reason.
      control.onSend = (bytes) {
        if (bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
          control.emitSocketError(const SocketException('No route to host'));
        }
      };

      final started = async.elapsed;
      await expectLater(const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()), throwsA(isA<SocketException>()));
      expect(
        async.elapsed - started,
        lessThan(const Duration(seconds: 1)),
        reason: 'a socket error must fail the pending step immediately, not wait out _handshakeTimeout',
      );
    }),
  );

  test('a socket error during the login wait propagates as itself, not the curated IcomLoginTimeout', () {
    // Deliberate: forcing a socket-level failure into IcomLoginTimeout's
    // text ("the radio did not answer... check that no other program is
    // connected") would misdiagnose a "no route to host" as radio-side
    // silence — exactly the speculative-cause substitution IcomLoginTimeout's
    // own doc comment warns against. A raw SocketException surfacing here is
    // the same behavior CatConnectFailure already gives a TCP or serial
    // radio whose connect fails at the socket layer.
    wireIcomSession(
      control,
      answerLogin: false,
      onEachSend: (bytes) {
        if (bytes[0] == 0x80) control.emitSocketError(const SocketException('Network is unreachable'));
      },
    );
    wireIcomSession(serial);

    return expectLater(const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()), throwsA(isA<SocketException>()));
  });

  test(
    'a socket error during awaitStreamToken fails fast instead of being silently dropped',
    () => runOnFakeClock((async) async {
      // Bound again inside the fake clock's zone: sockets made in setUp
      // deliver their events through the real event loop, which its steps
      // hold up.
      bindFakeSockets();
      // awaitStreamToken() polls with realNowUtc(), not _expect(), so without
      // its own _failPending hook a socket error here has nowhere to go —
      // onLost isn't wired up yet either, this early — and vanishes into a
      // debugPrint while the attempt rides out the full 3s poll deadline.
      wireIcomSession(
        control,
        answerStreamToken: false,
        onEachSend: (bytes) {
          if (bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x05) {
            control.emitSocketError(const SocketException('No route to host'));
          }
        },
      );
      wireIcomSession(serial);

      final started = async.elapsed;
      await expectLater(const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()), throwsA(isA<SocketException>()));
      expect(async.elapsed - started, lessThan(const Duration(seconds: 1)), reason: 'must fail immediately, not ride out the ~3s stream-token poll deadline');
    }),
  );

  test('a socket error during connect-failure cleanup logout still closes every socket and keeps the real cause', () async {
    // logout()'s ack-wait must catch more than TimeoutException, or a
    // socket error there escapes uncaught out of the catch block in
    // _attempt that calls it — skipping audio?.close(), serial?.close(),
    // control?.close(), and rethrow. The escaping error would also silently
    // replace the ORIGINAL failure (here, the stream request being
    // rejected) with an unrelated logout-time error.
    wireIcomSession(
      control,
      answerStreams: false,
      answerLogout: false,
      onEachSend: (bytes) {
        if (bytes[0] == 0x90) {
          control.queueReply(icomStreamAnswerAuthFailedReply());
        } else if (bytes.length == 64 && bytes[0] == 0x40 && bytes[21] == 0x01) {
          control.emitSocketError(const SocketException('No route to host (logout)'));
        }
      },
    );
    wireIcomSession(serial);

    await expectLater(
      const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()),
      throwsA(isA<StateError>()),
      reason: 'the stream-request rejection must survive, not the unrelated logout-time socket error',
    );
    expect(control.closeCalled, isTrue, reason: 'the logout socket error must not skip the rest of cleanup');
    expect(serial.closeCalled, isTrue);
    expect(audio.closeCalled, isTrue);
  });

  test(
    'a socket error on serial while control awaits the stream request fails fast with the real cause',
    () => runOnFakeClock((async) async {
      // Bound again inside the fake clock's zone: sockets made in setUp
      // deliver their events through the real event loop, which its steps
      // hold up.
      bindFakeSockets();
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
      wireIcomSession(serial);
      wireIcomSession(
        control,
        answerStreams: false,
        onEachSend: (bytes) {
          if (bytes[0] == 0x90) {
            serial.emitSocketError(const SocketException('No route to host (serial, mid-setup)'));
          }
        },
      );

      final started = async.elapsed;
      await expectLater(const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()), throwsA(isA<SocketException>()));
      expect(
        async.elapsed - started,
        lessThan(const Duration(seconds: 1)),
        reason: 'must fail fast via the interim onLost, not wait out control\'s own stream-answer timeout',
      );
    }),
  );

  test('a socket error on control while serial is opening still surfaces once requestStreams runs', () async {
    // The mirror-image window: control's own handshake (and login and
    // awaitStreamToken) are all done by the time serial starts its own
    // pkt3/pkt4/pkt6 exchange, so control's _failPending is stale there too
    // — and _attempt doesn't race serial's own open() (see the comment on
    // that call), so this one can't fail AS fast as the serial-side case
    // above. It still must fail, once requestStreams is reached, with the
    // real cause rather than silently succeeding on a control session that
    // is already dead.
    wireIcomSession(control);
    wireIcomSession(
      serial,
      onEachSend: (bytes) {
        if (bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
          control.emitSocketError(const SocketException('No route to host (control, mid-setup)'));
        }
      },
    );

    await expectLater(const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()), throwsA(isA<SocketException>()));
  });

  test('a control error survives even when serial\'s own un-raced open() times out on its own', () async {
    // Same window as above, but serial's own handshake also never gets an
    // answer — the same outage that killed control plausibly kills it too.
    // serial.open() isn't raced against `lost` (see _attempt's own
    // comment), so it runs out its own real ~3s handshake timeout on this
    // path; preferLostCause is what still prefers control's already-known
    // SocketException over the generic TimeoutException that produces,
    // once serial's open() finally gives up and throws.
    wireIcomSession(control);
    wireIcomSession(
      serial,
      answerHandshake: false,
      onEachSend: (bytes) {
        if (bytes.length >= 8 && bytes[0] == 0x10 && bytes[4] == 0x03) {
          control.emitSocketError(const SocketException('No route to host (control, mid-setup)'));
        }
      },
    );

    await expectLater(const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken()), throwsA(isA<SocketException>()));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('each session talks to the port the node names, and to the factory one when it names none', () async {
    // The radio's menu and a port forward can both move these. Without
    // them reaching the sockets, a radio on 50101 is dialled on 50001 and
    // the login simply times out.
    wireIcomSession(control);
    wireIcomSession(serial);
    final moved = await const IcomNetworkTransport().connect({...icomTestTarget(), 'controlPort': 50101, 'serialPort': 50202}, cancel: CatCancelToken());
    await moved.close();
    expect(control.sentToPorts, {50101});
    expect(serial.sentToPorts, {50202});

    bindFakeSockets();
    wireIcomSession(control);
    wireIcomSession(serial);
    final factory = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
    await factory.close();
    expect(control.sentToPorts, {icomControlPort});
    expect(serial.sentToPorts, {icomSerialPort});
  });

  test('a socket error once the session is up routes through onLost, same as the radio going quiet', () async {
    // Post-handshake, this is the ping-timeout path's own mechanism
    // (_declareLost) — proves the fast-fail machinery hands off to it
    // cleanly rather than the two paths fighting over the same completer.
    wireIcomSession(control);
    wireIcomSession(serial);

    final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
    addTearDown(() => connection.close());

    control.emitSocketError(const SocketException('No route to host (idle)'));

    await connection.closed.timeout(const Duration(seconds: 1));
  });

  test('an audio socket error is swallowed — nothing is pending on it, and it carries no connection to lose', () async {
    wireIcomSession(control);
    wireIcomSession(serial);

    final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
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
  group('a session that ends on its own says why', () {
    // A DEVLOGCAT capture records the CI-V stream and nothing of this
    // transport's own traffic, so the reason handed up with `closed` is the
    // only thing in it that can tell the phone losing its network from the
    // radio going quiet or letting go. Each cause has its own words, and
    // each names the channel, because control and serial fail separately.
    String? reasonOf(EquipmentConnection connection) => (connection as ExplainsClose).closeReason;

    test('a socket error gives the OS\'s words and the channel, never the address', () async {
      wireIcomSession(control);
      wireIcomSession(serial);
      final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
      addTearDown(() => connection.close());

      control.emitSocketError(SocketException('Read failed', osError: const OSError('Network is unreachable', 101), address: loopback, port: 50001));
      await connection.closed.timeout(const Duration(seconds: 1));

      expect(reasonOf(connection), 'socket error: Network is unreachable (errno 101), on the control channel');
    });

    test('the radio ending the session is told apart from a socket failure', () async {
      wireIcomSession(control);
      wireIcomSession(serial);
      final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());
      addTearDown(() => connection.close());

      serial.queueReply(icomPacket(80, {0: 0x50, 64: 0x01}));
      await connection.closed.timeout(const Duration(seconds: 1));

      expect(reasonOf(connection), 'the radio ended the session (radioDisconnected), on the serial channel');
    });

    test(
      'silence says how many pings went unanswered',
      () => runOnFakeClock((async) async {
        bindFakeSockets();
        wireIcomSession(control);
        wireIcomSession(serial);
        final connection = await const IcomNetworkTransport().connect(icomTestTarget(), cancel: CatCancelToken());

        // Nothing answers the pings from here on: the radio switched off,
        // or out of range.
        await connection.closed;

        expect(reasonOf(connection), startsWith('no reply from the radio to 3 pings, on the '));
      }),
    );
  });
}
