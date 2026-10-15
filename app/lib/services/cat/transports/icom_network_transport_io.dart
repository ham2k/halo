// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The IC-705 over WiFi. Two UDP sessions — control (login, auth, stream
// request) and serial (CI-V) — plus an audio socket that is bound and never
// read, because the stream request must name a real port.
//
// Verified against a real IC-705: a complete CI-V exchange in ~290 ms, and a
// held connection answering 149 of 150 polls over five minutes. The duration
// matters: the radio stops answering CI-V at about two minutes unless we
// re-authenticate (see [_reauthInterval]), so any claim about this transport
// staying up must come with the duration it was measured over. See
// icom_network_protocol.dart for the five byte-level corrections this needed
// over app-polo's attempt, and docs/design/cat.md for the story.
//
// Worth reading before blaming this radio for anything: reconnecting
// immediately after a disconnect WORKS — verified on hardware with repeated
// disconnect/reconnect cycles. A failure that presents as "the radio may
// still be holding a previous session" has so far always been ours; the
// canonical example is a login-answer matcher that pinned the radio's outer
// sequence counter to 0x0001 (see login()), discarding valid answers
// whenever the radio slipped an idle in first — a race, presenting as radio
// state.
//
// The teardown's order, repetition, and wait-for-acknowledgement are exact —
// see docs/design/ic705-teardown.md, derived from a packet capture of a
// working client.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../transport.dart';
import 'icom_network_protocol.dart';
import 'icom_network_transport_config.dart';
import 'mdns_io.dart';

const _handshakeTimeout = Duration(seconds: 3);

/// Generous next to the 71ms the radio actually took to acknowledge a logout
/// on a packet capture, but this is on the disconnect path: waiting a moment
/// costs the user a spinner, and giving up early costs them the next connect.
const _logoutAckTimeout = Duration(milliseconds: 600);

/// kappanhang's cadences. app-polo ran neither, which is why its sessions
/// died.
///
/// Keepalives alone are NOT enough to stay up: they hold the SOCKET open
/// while the radio quietly stops answering CI-V after about two minutes. See
/// [_reauthInterval] for the measurement.
const _idleInterval = Duration(milliseconds: 100);
const _pingInterval = Duration(seconds: 3);

/// Re-authenticate this often, or the radio stops answering CI-V while the
/// UDP session stays perfectly healthy.
///
/// MEASURED on a real IC-705. Three 300s holds, 150 polls at 2s, one variable,
/// counting CI-V replies per 30s of the run:
///
///   no re-auth   45/150   22 24 22 23  0  0  0  0  0  0   dead from ~117s
///   every 60s   126/150   32 32 30 16  6 14 30 32 30 32   dips, then recovers
///   every 30s   149/150   30 30 30 30 30 30 30 30 30 30   flat
///
/// 30s, because 60s only *recovers* a session that has already started
/// degrading — the dip in the middle row is ~45 seconds of a frozen frequency
/// in front of an operator. The single miss at 30s is 0.7%, ordinary WiFi loss.
///
/// Without any re-auth the failure is invisible from the outside: keepalives
/// keep flowing, the socket is fine, `onLost` never fires because inbound
/// traffic keeps resetting it, and the operator sees a connected radio with a
/// frozen frequency. That is exactly the "green but no frequency displayed"
/// report, and what the 30s stale flag was built to paper over. Any test
/// shorter than the two-minute failure looks perfect and proves nothing.
const _reauthInterval = Duration(seconds: 30);

/// How many sent packets we keep so the radio can ask for one again.
///
/// Tracked idles turn the buffer over at ten a second, so a small buffer
/// (say 32) would mean a retransmit request older than ~3 seconds always
/// missed, evicting the CI-V frames most worth resending. 128 covers ~12s,
/// which is far longer than the radio waits before giving up on a packet.
const _sentBufferSize = 128;

Future<RawDatagramSocket> _bindSocket(InternetAddress address, int port) {
  final binder = IcomNetworkTransport.debugSocketBinder;
  return binder != null ? binder(address, port) : RawDatagramSocket.bind(address, port);
}

class IcomNetworkTransport extends EquipmentTransport with IcomNetworkTransportConfig {
  const IcomNetworkTransport();

  static const transportKey = 'icom-network';

  /// Test seam: overrides every `RawDatagramSocket.bind` this transport
  /// makes (control, serial, audio, always `(InternetAddress.anyIPv4, 0)` —
  /// the three sockets are indistinguishable by bind arguments, so a test
  /// double dispenses them by the fixed call order `_attempt` and
  /// `_IcomSession.open` already use: control, then serial, then audio).
  /// Null in production.
  @visibleForTesting
  static Future<RawDatagramSocket> Function(InternetAddress address, int port)? debugSocketBinder;

  @override
  String get key => transportKey;

  /// DO NOT retry a login timeout automatically. It looks obviously right
  /// — the radio is holding a session and lets go on its own, so why make
  /// the operator wait? — and the radio says otherwise.
  ///
  /// Measured on hardware: with one attempt per Connect, the UDP handshake
  /// succeeded every time (0 pkt4/pkt6 timeouts in ~10 attempts) and only
  /// the login was ignored. With three attempts per Connect, pkt4 started
  /// timing out too. Each attempt opens a session the radio has to track,
  /// so retrying degrades it from "ignores the login" to "ignores the
  /// handshake" — the opposite of riding it out.
  ///
  /// Whatever clears this state, it is time, and more sessions are not it.
  /// The editor's troubleshooting note tells the operator that; this stays
  /// one attempt.
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) => _attempt(target, cancel: cancel);

  Future<EquipmentConnection> _attempt(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    final host = target['host'] as String? ?? '';
    final username = target['username'] as String? ?? '';
    final password = target['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      throw const IcomCredentialsMissing();
    }

    // A radio's address is usually typed as one, and an address needs no
    // lookup — which is real I/O, out of reach of a test's fake clock.
    final address = InternetAddress.tryParse(host) ?? await lookupHost(host);
    // A `.local` lookup can take seconds; a superseded attempt must not go
    // on to open a session the radio then holds against the next one.
    if (cancel.isCancelled) throw const CatCancelledException();
    _IcomSession? control;
    _IcomSession? serial;
    RawDatagramSocket? audio;

    // A session's own _failPending only fails the ONE step it's actively
    // waiting on — every gap between steps (opening the other session,
    // binding audio, the moment between one await returning and the next
    // starting) has nothing pending and no onLost yet either (that's wired
    // by _IcomConnection, which doesn't exist until this whole function
    // returns). `lost` is what a session's onSetupLost (see _onSocketError)
    // reports into instead, and racing every step against it below is what
    // turns a socket error ANYWHERE in this setup into an immediate failure
    // with its real cause, rather than riding out whatever step happens to
    // be in flight next until IT times out with a generic message.
    final lost = Completer<Never>();
    Future<T> raceLost<T>(Future<T> step) => Future.any<T>([step, lost.future]);
    void onSetupLost(_IcomSession session) {
      session.onSetupLost = (error) {
        if (!lost.isCompleted) lost.completeError(error);
      };
    }

    // For the two steps below that can't be raced (see their own comment):
    // if the step ALSO fails on its own — the same outage that killed the
    // other session plausibly kills this one's handshake too — prefer
    // `lost`'s cause over whatever generic error the doomed step produced.
    // It is the earlier, more specific one; without this, a real captured
    // SocketException would be silently replaced by a plain handshake
    // TimeoutException from a session that never had a chance.
    Future<T> preferLostCause<T>(Future<T> Function() step) async {
      try {
        return await step();
      } catch (_) {
        if (lost.isCompleted) await lost.future;
        rethrow;
      }
    }

    try {
      control = await _IcomSession.open(address, icomControlPort, 'control');
      onSetupLost(control);
      if (cancel.isCancelled) throw const CatCancelledException();

      // The radio volunteers a 0x90 during login; it is informational, and
      // taking it instead of sending our own is what left polo's radio
      // never told where to send CI-V.
      final authId = await raceLost(control.login(username: username, password: password));
      final token = await raceLost(control.awaitStreamToken());

      // Both sockets must exist before the request that names their ports.
      // Not raced: assigning through a generic wrapper's return type loses
      // the flow-analysis promotion `serial`/`audio` need for every later
      // use, hence the plain locals below instead. preferLostCause is what
      // still surfaces a control failure from during either wait, in place
      // of whatever these two produce on their own if the same outage
      // takes them down too.
      final serialSession = await preferLostCause(() => _IcomSession.open(address, icomSerialPort, 'serial'));
      serial = serialSession;
      onSetupLost(serialSession);
      final audioSocket = await preferLostCause(() => _bindSocket(InternetAddress.anyIPv4, 0));
      audio = audioSocket;
      // Bound and never read (see the file header) — an error here has no
      // connection to tear down, only a socket to stop draining.
      audioSocket.listen((_) => audioSocket.receive(), onError: (Object e) => debugPrint('[cat] icom audio socket error: $e'));

      if (cancel.isCancelled) throw const CatCancelledException();

      await raceLost(
        control.requestStreams(authId: authId, token: token, username: username, serialPort: serialSession.localPort, audioPort: audioSocket.port),
      );

      serialSession.sendTracked(buildSerialOpen(serialSession.localSid, serialSession.remoteSid, 0, magic: icomSerialOpenMagic));

      control.onSetupLost = null;
      serialSession.onSetupLost = null;
      return _IcomConnection(control: control, serial: serialSession, audio: audioSocket, authId: authId);
    } catch (e) {
      // Log out on the way out too — a half-built session the radio still
      // holds is what makes the NEXT connect fail.
      await control?.logout();
      audio?.close();
      await serial?.close();
      await control?.close();
      rethrow;
    }
  }
}

/// The radio's remote-control login is missing. Distinct from a refusal:
/// nothing was attempted.
class IcomCredentialsMissing implements CatUnreachable {
  const IcomCredentialsMissing();

  @override
  String toString() => "The radio's remote-control username and password are required";
}

/// The radio refused the credentials.
///
/// CONFIRMED against hardware: a deliberately wrong password produces this,
/// not silence — so a stale password and an unreachable radio are
/// distinguishable from the operator's side, and the troubleshooting text
/// does not need to lead with "retype the password".
class IcomLoginRejected implements CatUnreachable {
  const IcomLoginRejected();

  @override
  String toString() => "The radio rejected the remote-control username or password";
}

/// The radio never answered the login.
///
/// A genuine silence here most often means another client already holding
/// the radio's single remote-control session.
///
/// Do not put a speculative cause in this string: a message here once blamed
/// "a previous session" when the real cause was our own login-answer matcher
/// discarding valid answers (see the note at the top of this file), and it
/// sent everyone looking at the radio instead. Name the checks that are
/// actually actionable and let the troubleshooting text carry the rest.
class IcomLoginTimeout implements CatUnreachable {
  const IcomLoginTimeout();

  @override
  /// The password is deliberately NOT mentioned. It cannot cause this path:
  /// an empty one throws IcomCredentialsMissing before a packet is sent, and a
  /// wrong one produces IcomLoginRejected — confirmed on hardware. Naming it
  /// here sends the operator to retype a password that is already correct,
  /// which is the wasted loop this branch exists to remove, and it contradicts
  /// the troubleshooting note in the same editor.
  String toString() =>
      'The radio did not answer the login. Check that no other program '
      '(wfview, RS-BA1) is connected to it.';
}

/// One UDP session: handshake, sequencing, keepalives, teardown.
class _IcomSession {
  final RawDatagramSocket _socket;
  final InternetAddress _address;
  final int _port;
  final String _label;

  int localSid = 0;
  int remoteSid = 0;

  /// ONE outer sequence space for everything, idles included. Sending idles
  /// at a constant zero while tracked packets counted up looked like a
  /// stream of duplicates and made login intermittent.
  int _seq = 1;
  int _pingSeq = 0;
  int _innerSeq = 0;

  final _sent = <int, List<int>>{};
  final _listeners = <void Function(List<int>)>[];
  Timer? _idleTimer;
  Timer? _pingTimer;
  Timer? _reauthTimer;
  var _closed = false;

  /// Pings sent since the radio last said anything at all. UDP has no FIN,
  /// so silence is the ONLY way a vanished radio announces itself — a
  /// powered-off rig or a dropped WiFi otherwise leaves the app showing a
  /// live connection with a frozen frequency, forever, and blocks
  /// auto-reconnect because the node still reads as connected.
  int _pingsUnanswered = 0;

  /// Three pings is ~9s of silence. Long enough to ride out a lost datagram
  /// or a busy radio, short enough that an operator notices the row change
  /// rather than trusting a stale frequency into a logged QSO.
  static const _maxPingsUnanswered = 3;

  /// Fires once when the radio has gone quiet for too long. Set only once
  /// this session is part of a live [_IcomConnection] — before that,
  /// [onSetupLost] is what a socket error still in _attempt's setup phase
  /// reaches instead.
  void Function()? onLost;

  /// Fires once, with the real cause, for a socket error that arrives after
  /// this session's own handshake is done but before _attempt has built an
  /// [_IcomConnection] to hand it to [onLost]. A gap [onLost] can't cover:
  /// _attempt sets this immediately once the session opens, and clears it
  /// (setting the real onLost instead) once the connection exists — see
  /// _attempt's own use of it for why every await in between needs it.
  void Function(Object error)? onSetupLost;

  _IcomSession._(this._socket, this._address, this._port, this._label);

  int get localPort => _socket.port;

  static Future<_IcomSession> open(InternetAddress address, int port, String label) async {
    final socket = await _bindSocket(InternetAddress.anyIPv4, 0);
    final session = _IcomSession._(socket, address, port, label);
    // Without onError, an async socket-level failure (an ICMP "no route to
    // host" delivered on the stream rather than thrown from send()) escapes
    // this listen() raw and unclassified instead of reading as the radio
    // going quiet, which is what onLost already exists to report.
    socket.listen(session._onEvent, onError: session._onSocketError);
    // From the local PORT alone, little-endian in the top half — a capture
    // settled this; polo derived it from the IP and got intermittency.
    session.localSid = (((socket.port & 0xFF) << 24) | (((socket.port >> 8) & 0xFF) << 16)) & 0xFFFFFFFF;

    // Everything from here can throw on a timeout, and both failures leave
    // something behind if we simply propagate. The socket leaks — one per
    // failed Connect, and a refused reconnect is exactly when someone clicks
    // repeatedly. Worse, a pkt4 that arrives means the radio HAS created a
    // session for us, so walking away without a disconnect manufactures the
    // very "radio is still holding a previous session" state that this
    // transport spent a long time being blamed for.
    try {
      session._send(buildPkt3(session.localSid, 0));
      final pkt4 = await session._expect('pkt4', (b) => b.length == 16 && icomPrefixIs(b, [0x10, 0, 0, 0, 0x04, 0, 0, 0]));
      session.remoteSid = readBe32(pkt4, 8);

      session._send(buildPkt6(session.localSid, session.remoteSid));
      await session._expect('pkt6 answer', (b) => b.length == 16 && icomPrefixIs(b, [0x10, 0, 0, 0, 0x06, 0, 0x01, 0]));
    } catch (_) {
      // Only worth a disconnect once the radio has told us its session id;
      // before pkt4 there is nothing on its side to release.
      if (session.remoteSid != 0) {
        session._send(buildDisconnect(session.localSid, session.remoteSid));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      session._closed = true;
      socket.close();
      rethrow;
    }

    session._startKeepalives();
    return session;
  }

  void _startKeepalives() {
    _idleTimer = Timer.periodic(_idleInterval, (_) {
      // sendTracked, not _send. Idles consume sequence numbers either way,
      // but _send does not record them — and after the first minute idles are
      // ~100% of what the control session emits, so with plain _send the
      // radio's resend requests would almost always find nothing to answer.
      //
      // The seq argument is 0 because sendTracked stamps the real one; passing
      // _seq++ here would burn two numbers per idle.
      if (!_closed) sendTracked(buildIdle(localSid, remoteSid, 0));
    });
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_closed) return;
      if (_pingsUnanswered >= _maxPingsUnanswered) {
        _declareLost();
        return;
      }
      _pingsUnanswered++;
      final seq = _pingSeq++;
      _send(buildPing(localSid, remoteSid, seq, [seq & 0xFF, 0, 0, 0]));
    });
  }

  /// A pending handshake step (pkt3/pkt4/pkt6, login, stream request,
  /// stream token, or logout's own ack) fails right away with the real
  /// cause — an ICMP "no route to host" reaching this listener means the OS
  /// already knows the answer, and waiting out _handshakeTimeout to report
  /// it as a generic silence would throw the diagnosis away. Once nothing
  /// is pending, this reads exactly like the radio going quiet: onSetupLost
  /// while _attempt is still assembling the connection, onLost afterwards
  /// (ping-timeout's own path).
  void _onSocketError(Object error) {
    debugPrint('[cat] icom $_label socket error: $error');
    // Same fire-once-then-forget shape as _declareLost/onLost below: the
    // step that owns _failPending clears it back to null the moment it
    // resolves on its own (see _expect and awaitStreamToken), so non-null
    // here always means genuinely still pending, never a stale leftover.
    final fail = _failPending;
    _failPending = null;
    if (fail != null) {
      fail(error);
      return;
    }
    final setupLost = onSetupLost;
    if (setupLost != null) {
      setupLost(error);
      return;
    }
    _declareLost();
  }

  void _declareLost() {
    final lost = onLost;
    onLost = null;
    lost?.call();
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket.receive();
    if (datagram == null) return;
    // Only the radio we dialled. Nothing below authenticates a datagram — the
    // session ids are never checked against ours — so without this every
    // branch here is reachable by anything that can reach our ephemeral port,
    // and two of those branches answer with traffic. Compared as text because
    // that is stable across the IPv4/IPv6 forms InternetAddress can take.
    if (datagram.address.address != _address.address) return;
    final bytes = datagram.data.toList();

    // Anything at all proves the radio is still there.
    _pingsUnanswered = 0;

    // The radio pings us; not answering gets the session dropped.
    if (bytes.length == 21 && bytes[4] == 0x07 && bytes[16] == 0x00) {
      final seq = icomReadSequence(bytes);
      _send(buildPingReply(localSid, remoteSid, seq, bytes.sublist(17, 21)));
      return;
    }
    // And asks for packets it missed — one sequence number...
    if (bytes.length >= 16 && icomPrefixIs(bytes, [0x10, 0, 0, 0, 0x01, 0])) {
      final packet = _sent[icomReadSequence(bytes)];
      if (packet != null) _send(packet);
      return;
    }
    // ...or a RANGE. The 0x18 form carries (start, end) pairs as 4 bytes
    // each from offset 16, little-endian and inclusive. A radio that lost a
    // burst asks this way — ignoring it would leave the one request that
    // matters after a bad moment on the link unanswered.
    if (bytes.length >= 20 && icomPrefixIs(bytes, [0x18, 0, 0, 0, 0x01, 0])) {
      // Bounded in ONE place, by total rather than per pair — see
      // icomRetransmitRange for why per-pair bounding is not a bound at all.
      for (final seq in icomRetransmitRange(bytes, limit: _sentBufferSize)) {
        final packet = _sent[seq];
        if (packet != null) _send(packet);
      }
      return;
    }
    // The radio telling us the session is over. A STANDING branch, not an
    // _expect: every listener installed during the handshake removes itself
    // on first match, so once connect() returns nothing else on the control
    // session consumes an 0x50 at all — without this branch these notices
    // are simply dropped.
    //
    // Losing them is expensive. `onLost` cannot cover it — it is reset by ANY
    // inbound datagram (see the top of this method) and the radio keeps
    // pinging us at ~100ms — so the only thing that eventually notices is the
    // 30s stale flag: half a minute of a connected row showing a frozen
    // frequency, and no reason to give the operator.
    //
    // Gated on `onLost`, which is only set once _IcomConnection exists — i.e.
    // once the handshake is DONE. That is what keeps this from stealing the
    // handshake's own 0x50: during requestStreams the field is still null, so
    // an auth-failure answer reaches the _expect that reports it precisely,
    // instead of being swallowed here and surfacing three seconds later as a
    // bare timeout.
    if (onLost != null && bytes.length == 80 && icomPrefixIs(bytes, [0x50, 0, 0, 0, 0, 0])) {
      final answer = readStreamAnswer(bytes);
      if (answer == IcomStreamAnswer.authFailed || answer == IcomStreamAnswer.radioDisconnected) {
        debugPrint('[cat] icom $_label: the radio ended the session (${answer.name})');
        final lost = onLost;
        onLost = null;
        lost?.call();
        return;
      }
    }
    for (final listener in [..._listeners]) {
      listener(bytes);
    }
  }

  void _send(List<int> bytes) {
    if (_socket.port == 0) return;
    try {
      _socket.send(bytes, _address, _port);
    } catch (e) {
      debugPrint('[cat] icom $_label send failed: $e');
    }
  }

  void sendTracked(List<int> bytes) {
    // The key and the wire value come from one function, deliberately:
    // computed separately they drift apart past 65535, silently killing
    // every retransmit answer about 1h49m into a session (see
    // icomStampSequence).
    final (:key, :packet) = icomStampSequence(bytes, _seq++);
    _sent[key] = packet;
    if (_sent.length > _sentBufferSize) _sent.remove(_sent.keys.first);
    _send(packet);
  }

  void Function() onMessage(void Function(List<int>) callback) {
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  /// Set by whichever handshake step is currently waiting — `_expect` below,
  /// or `awaitStreamToken`'s own poll loop — and cleared back to null the
  /// moment that step resolves on its own, same as `onLost` is for
  /// `_declareLost`. `_onSocketError` calls this immediately instead of
  /// waiting out the full handshake timeout for a cause the OS already
  /// reported — onLost/onSetupLost, which onSocketError falls back to
  /// otherwise, aren't wired up until later in a session's life.
  void Function(Object error)? _failPending;

  /// Every `_expect` Timer still running, so `close` can cancel them all.
  /// `Future.any` in `_attempt`'s `raceLost` doesn't cancel a losing step —
  /// this session may keep waiting on its own request for up to
  /// `_handshakeTimeout` after the caller has already moved on — and a
  /// SET, not a single slot, is what a losing step's timer needs: `close`
  /// itself calls `logout`, whose own `_expect` starts a second one before
  /// the abandoned first has fired, and a single slot would just lose the
  /// reference to it rather than cancel it.
  final _pendingExpectTimers = <Timer>{};

  Future<List<int>> _expect(String what, bool Function(List<int>) matches, {Duration? timeout}) {
    final completer = Completer<List<int>>();
    late void Function() stop;
    late Timer timer;
    timer = Timer(timeout ?? _handshakeTimeout, () {
      _pendingExpectTimers.remove(timer);
      stop();
      _failPending = null;
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('the radio did not answer: $what'));
      }
    });
    _pendingExpectTimers.add(timer);
    stop = onMessage((bytes) {
      if (!matches(bytes)) return;
      _pendingExpectTimers.remove(timer);
      timer.cancel();
      stop();
      _failPending = null;
      if (!completer.isCompleted) completer.complete(bytes);
    });
    _failPending = (error) {
      if (!completer.isCompleted) completer.completeError(error);
    };
    return completer.future;
  }

  List<int>? _authId;

  Future<List<int>> login({required String username, required String password}) async {
    final start = [Random().nextInt(256), Random().nextInt(256)];
    sendTracked(buildLogin(local: localSid, remote: remoteSid, innerSeq: _innerSeq++, authStartId: start, username: username, password: password));
    final List<int> answer;
    try {
      // Six bytes, NOT eight. Bytes 6..7 are the sender's outer sequence
      // number, and on a radio->client packet that is the RADIO's monotonic
      // counter — not a constant. Requiring 0x0001 there holds only while
      // the radio answers the login before its first idle. Every login
      // answer in the reference capture arrives as 0x0002, because the
      // radio's ~100ms idle timer fires first when it is slow to answer pkt6.
      //
      // The cost of getting this wrong is invisible and wildly misleading: a
      // perfectly good login answer is dropped, _expect times out after 3s,
      // and the operator is told the radio "may still be holding a previous
      // session" — sending everyone, including us, hunting a stateful radio
      // bug that was never there. It is a race, so it presents as flaky.
      //
      // Length 96 plus the 0x60 type identifies this packet uniquely; the
      // sequence field adds no discrimination whatsoever.
      //
      // pkt4 and pkt6 above legitimately pin bytes 6..7: pkt4 is the first
      // packet the radio sends in a session so its counter is structurally 0,
      // and type-6 carries a literal 0x0001 that our OWN pkt6 sets too — it
      // does not consume a counter tick. See docs/design/ic705-teardown.md.
      //
      // Named, not inline, so a test can exercise THIS predicate rather than
      // a copy of it — an inline lambda invites a regression test that
      // passes against the very bug it is written to catch.
      answer = await _expect('login answer', isLoginAnswer);
    } on TimeoutException {
      throw const IcomLoginTimeout();
    }
    if (icomPrefixIs(answer.sublist(48), [0xff, 0xff, 0xff, 0xfe])) {
      throw const IcomLoginRejected();
    }
    final authId = answer.sublist(26, 32);
    _authId = authId;

    sendTracked(buildAuth(local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x02, authId: authId));

    // Started HERE, not in _startKeepalives, because only a session that has
    // logged in has anything to re-authenticate. _startKeepalives runs for the
    // serial session too, where this timer could only ever no-op against a
    // null authId — a periodic timer whose correctness depended on a null
    // check in another method. See [_reauthInterval] for why it exists.
    _reauthTimer = Timer.periodic(_reauthInterval, (_) {
      if (_closed) return;
      sendTracked(buildAuth(local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x05, authId: authId));
    });
    return authId;
  }

  /// The 16-byte token from the radio's unsolicited 0xa8, at offset 66.
  Future<List<int>> awaitStreamToken() async {
    List<int>? token;
    Object? socketError;
    final stop = onMessage((b) {
      if (b.length == 168 && icomPrefixIs(b, [0xa8, 0, 0, 0, 0, 0])) token = b.sublist(66, 82);
    });
    _failPending = (error) => socketError = error;
    sendTracked(buildAuth(local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x05, authId: _authId!));

    // Real time: a protocol timeout measures how long the radio actually took
    // to answer, which has nothing to do with what time the app thinks it is.
    final deadline = realNowUtc().add(_handshakeTimeout);
    while (token == null && socketError == null && realNowUtc().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    stop();
    // Marks this step resolved for _failPending too, same as _expect's own
    // Timer always completing its completer — without this, a plain timeout
    // here (no error, no token) leaves the hook non-null, misreading as
    // still pending to any later caller, which is the exact trap this whole
    // mechanism exists to close.
    _failPending = null;
    socketError ??= token == null ? TimeoutException('the radio never sent its stream token') : null;
    if (socketError != null) throw socketError!;
    return token!;
  }

  Future<void> requestStreams({
    required List<int> authId,
    required List<int> token,
    required String username,
    required int serialPort,
    required int audioPort,
  }) async {
    sendTracked(
      buildRequestStreams(
        local: localSid,
        remote: remoteSid,
        innerSeq: _innerSeq++,
        authId: authId,
        a8ReplyId: token,
        username: username,
        ourSerialPort: serialPort,
        ourAudioPort: audioPort,
        audioSampleRate: icomAudioSampleRate,
        txBufferMs: icomTxBufferMs,
      ),
    );

    // The answer is an 0x50, not the 0x90 the radio also sends unprompted.
    final answer = await _expect('stream answer', (b) => b.length == 80 && icomPrefixIs(b, [0x50, 0, 0, 0, 0, 0]) && b[20] == 0x02);

    // A POSITIVE test — never a hunt for a refusal marker with "not found"
    // treated as success (see readStreamAnswer): an AUTH FAILURE would pass
    // straight through such a guard, and we would then send the serial-open
    // into a stream the radio never opened and give the operator a connected
    // row that never reads.
    switch (readStreamAnswer(answer)) {
      case IcomStreamAnswer.accepted:
        break;
      case IcomStreamAnswer.authFailed:
        // Distinct from IcomLoginRejected: the credentials got us this far, so
        // this is the radio refusing the streams, not the login.
        throw StateError('the radio rejected the stream request (authentication)');
      case IcomStreamAnswer.radioDisconnected:
        throw StateError('the radio dropped the session while opening its streams');
      case IcomStreamAnswer.unknown:
        // Deliberately fatal. An answer we cannot read must not be optimism.
        throw StateError('the radio sent a stream answer we do not understand');
    }
  }

  /// Release the login, and wait for the radio to say it let go. Without this
  /// the radio holds it and refuses the next one — the whole of app-polo's
  /// "inconsistent run to run".
  ///
  /// The acknowledgement is a 64-byte auth packet carrying 0x02 at the offset
  /// where our request carries 0x01. That is read straight off a packet
  /// capture of a working client (see `docs/design/ic705-teardown.md`), and
  /// knowing how to match it is what lets this send **once and confirm**
  /// rather than fire blind repeats.
  Future<void> logout() async {
    final authId = _authId;
    if (authId == null || _closed) return;
    // FIRST. _shutdown runs logout() before close(), and only close() sets
    // _closed — so without this the 30s re-auth timer is still armed for the
    // whole ~600ms we spend awaiting the ack, and a tick landing in that
    // window sends a magic-0x05 auth AFTER our magic-0x01 logout. The radio
    // keeps the login and the next connect is refused by silence: the exact
    // failure this branch exists to fix, reintroduced at roughly 1-in-50
    // disconnects, which is the hardest rate there is to diagnose.
    _reauthTimer?.cancel();
    // Listen before sending: the ack came back in 71ms on the capture, but
    // nothing says it cannot beat our own next line.
    final ack = _expect('logout acknowledgement', isLogoutAck, timeout: _logoutAckTimeout);
    sendTracked(buildAuth(local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x01, authId: authId));
    try {
      await ack;
    } catch (e) {
      // ANY failure to get the ack — a timeout or a socket error alike —
      // leaves the radio in the same state, and this is the caller's last
      // step before closing the socket: nothing upstream can retry it.
      //
      // Worth saying out loud: this is the state in which the next connect
      // is likely to be refused, and it is otherwise invisible.
      debugPrint('[cat] icom: no logout acknowledgement ($e) — the radio may still hold the login');
    }
  }

  Future<void> close({bool serialStream = false, int? serialCloseInnerSeq}) async {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    _pingTimer?.cancel();
    _reauthTimer?.cancel();
    for (final timer in _pendingExpectTimers) {
      timer.cancel();
    }
    _pendingExpectTimers.clear();
    if (serialStream) {
      // sendTracked, not _send: it stamps the outer sequence number, which a
      // working client fills in here rather than leaving at zero.
      // The inner sequence CONTINUES the CI-V stream's counter, which is why
      // the caller passes it in. Using the session's own _innerSeq — which
      // nothing else on the serial session advances — would send the close
      // carrying a number the radio processed long ago. If it dedupes on
      // that counter (the only reason the counter exists) the close is dropped
      // as a stale duplicate and the stream stays registered on the radio.
      // The reference client's close continues the CI-V numbering.
      sendTracked(buildSerialOpen(localSid, remoteSid, serialCloseInnerSeq ?? _innerSeq++, magic: 0x00));
    }
    // Once. A working client sends exactly one disconnect per channel and the
    // radio releases the session; repeating it with delays spreads the
    // teardown over ~300ms per channel, with datagrams two and three
    // referring to a session the radio has already forgotten.
    _send(buildDisconnect(localSid, remoteSid));
    // Let the datagram leave the box before the socket goes; the caller may
    // open a new session immediately after.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _socket.close();
  }
}

class _IcomConnection implements EquipmentConnection {
  final _IcomSession control;
  final _IcomSession serial;
  final RawDatagramSocket audio;
  final List<int> authId;

  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  int _civSeq = 1;
  var _open = true;

  _IcomConnection({required this.control, required this.serial, required this.audio, required this.authId}) {
    serial.onMessage((bytes) {
      if (!isCivData(bytes)) return;
      if (!_dataController.isClosed) {
        _dataController.add(Uint8List.fromList(unwrapCiv(bytes)));
      }
    });
    // Either session going quiet means the radio is gone: the control
    // session carries the keepalives, the serial session carries CI-V, and
    // losing either one is a dead link.
    control.onLost = _markLost;
    serial.onLost = _markLost;
  }

  /// The radio stopped answering. Completes `closed` so CatService sees a
  /// disconnect and the row stops claiming a live frequency — the thing UDP
  /// gives us no FIN for.
  void _markLost() {
    if (!_open) return;
    _open = false;
    debugPrint('[cat] icom: radio stopped answering, treating as disconnected');
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_dataController.close());
    // Best-effort: the radio is very likely gone, but if it is merely
    // wedged this still releases the login it is holding.
    unawaited(_shutdown());
  }

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  void send(List<int> bytes) {
    if (!_open) return;
    serial.sendTracked(buildCivData(serial.localSid, serial.remoteSid, _civSeq++, bytes));
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_dataController.close());
    await _shutdown();
  }

  /// Order matters, and it is the order a working client uses: streams down
  /// first, then the logout on the control session.
  ///
  /// Each step guarded independently: a throw part-way must not skip the
  /// rest — that leaves the control socket open and, worse, the radio still
  /// holding the login, which is precisely what makes the NEXT connect fail.
  Future<void> _shutdown() async {
    Future<void> step(String what, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('[cat] icom teardown ($what): $e');
      }
    }

    // The login owns the streams, so the streams go down first and the login
    // last. A capture of a working client tears down audio, then serial, then
    // control — logout and disconnect back to back — inside a single
    // millisecond, and its next connect succeeds two seconds later. Releasing
    // the login first would spend the better part of a second closing streams
    // the radio no longer has a logged-in owner for.
    await step('audio', () async => audio.close());
    await step('serial', () => serial.close(serialStream: true, serialCloseInnerSeq: _civSeq++));
    await step('logout', control.logout);
    await step('control', control.close);
  }
}
