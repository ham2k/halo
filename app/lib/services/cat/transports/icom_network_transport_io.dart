// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The IC-705 over WiFi. Two UDP sessions — control (login, auth, stream
// request) and serial (CI-V) — plus an audio socket that is bound and never
// read, because the stream request must name a real port.
//
// Verified against a real IC-705: a complete CI-V exchange in ~290 ms, and a
// held connection answering 149 of 150 polls over five minutes.
//
// That figure used to read "30 of 30 polls over a minute", and the minute was
// the problem: the radio stops answering CI-V at about two minutes unless we
// re-authenticate, so the evidence stopped exactly where the bug started. See
// [_reauthInterval]. Any future claim about this transport staying up should
// come with the duration it was measured over. See
// icom_network_protocol.dart for the five byte-level corrections this needed
// over app-polo's attempt, and docs/design/cat.md for the story.
//
// RESOLVED, and worth reading before blaming this radio for anything again.
// Reconnecting immediately after a disconnect used to fail most of the time,
// and for a long while that was attributed to the radio holding its login
// longer than the logout released it. It was ours: the login-answer matcher
// pinned the radio's outer sequence counter to 0x0001 (see login()), so a
// valid answer was discarded whenever the radio slipped an idle in first, and
// the resulting 3s timeout was reported to the operator as "the radio may
// still be holding a previous session". A race, presenting as radio state.
// Verified on hardware 2026-07-30: repeated disconnect/reconnect cycles.
//
// The teardown was genuinely wrong too — order, repetition, and never waiting
// for the acknowledgement — and is fixed. See docs/design/ic705-teardown.md
// for both, derived from a packet capture of a working client.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../transport.dart';
import 'icom_network_protocol.dart';
import 'icom_network_transport_config.dart';

const _handshakeTimeout = Duration(seconds: 3);

/// Generous next to the 71ms the radio actually took to acknowledge a logout
/// on a packet capture, but this is on the disconnect path: waiting a moment
/// costs the user a spinner, and giving up early costs them the next connect.
const _logoutAckTimeout = Duration(milliseconds: 600);

/// kappanhang's cadences. app-polo ran neither, which is why its sessions
/// died.
///
/// "Ours stay up indefinitely" is what this comment used to say. It was false
/// for the life of the file: keepalives alone hold the SOCKET open while the
/// radio quietly stops answering CI-V after about two minutes. See
/// [_reauthInterval] for the measurement. The claim survived because every
/// test ever run against this transport was shorter than the failure.
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
/// report, and what the 30s stale flag was built to paper over.
///
/// This is why the transport used to claim sessions "stay up indefinitely" —
/// every test ever run against it was shorter than the failure.
const _reauthInterval = Duration(seconds: 30);

/// How many sent packets we keep so the radio can ask for one again.
///
/// 32 was fine while only handshake packets were tracked — a handful, held
/// forever. Now that idles are tracked too the buffer turns over at ten a
/// second, and 32 would mean a retransmit request older than ~3 seconds always
/// missed, evicting the CI-V frames most worth resending. 128 covers ~12s,
/// which is far longer than the radio waits before giving up on a packet.
const _sentBufferSize = 128;

class IcomNetworkTransport extends EquipmentTransport with IcomNetworkTransportConfig {
  const IcomNetworkTransport();

  static const transportKey = 'icom-network';

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
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) =>
      _attempt(target, cancel: cancel);

  Future<EquipmentConnection> _attempt(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    final host = target['host'] as String? ?? '';
    final username = target['username'] as String? ?? '';
    final password = target['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      throw const IcomCredentialsMissing();
    }

    final address = (await InternetAddress.lookup(host)).first;
    _IcomSession? control;
    _IcomSession? serial;
    RawDatagramSocket? audio;

    try {
      control = await _IcomSession.open(address, icomControlPort, 'control');
      if (cancel.isCancelled) throw const CatCancelledException();

      // The radio volunteers a 0x90 during login; it is informational, and
      // taking it instead of sending our own is what left polo's radio
      // never told where to send CI-V.
      final authId = await control.login(username: username, password: password);
      final token = await control.awaitStreamToken();

      // Both sockets must exist before the request that names their ports.
      serial = await _IcomSession.open(address, icomSerialPort, 'serial');
      audio = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      audio.listen((_) => audio?.receive());

      if (cancel.isCancelled) throw const CatCancelledException();

      await control.requestStreams(
        authId: authId,
        token: token,
        username: username,
        serialPort: serial.localPort,
        audioPort: audio.port,
      );

      serial.sendTracked(buildSerialOpen(serial.localSid, serial.remoteSid, 0,
          magic: icomSerialOpenMagic));

      return _IcomConnection(control: control, serial: serial, audio: audio, authId: authId);
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
class IcomCredentialsMissing implements Exception {
  const IcomCredentialsMissing();

  @override
  String toString() => "The radio's remote-control username and password are required";
}

/// The radio refused the credentials.
///
/// CONFIRMED against hardware 2026-07-30: a deliberately wrong password
/// produces this, not silence. That had been inherited untested from the
/// wfview/kappanhang lineage and hedged as "believed" everywhere it was
/// mentioned, which mattered — while it was unverified, a stale password and
/// an unreachable radio were indistinguishable from the operator's side, so
/// the troubleshooting text had to lead with "retype the password" as the
/// cheapest thing to rule out. It no longer does.
class IcomLoginRejected implements Exception {
  const IcomLoginRejected();

  @override
  String toString() => "The radio rejected the remote-control username or password";
}

/// The radio never answered the login.
///
/// This used to say the radio was "still holding a previous session", because
/// that is what the symptom looked like for a long time. It was wrong, and the
/// wrongness was expensive: the real cause was our own login-answer matcher
/// discarding valid answers (see the note at the top of this file), and this
/// message sent everyone looking at the radio instead. Now that the race is
/// fixed, a genuine silence here means something else — most often another
/// client already holding the radio's single remote-control session.
///
/// Do not put a speculative cause back in this string. Name the checks that
/// are actually actionable and let the troubleshooting text carry the rest.
class IcomLoginTimeout implements Exception {
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

  /// Fires once when the radio has gone quiet for too long.
  void Function()? onLost;

  _IcomSession._(this._socket, this._address, this._port, this._label);

  int get localPort => _socket.port;

  static Future<_IcomSession> open(InternetAddress address, int port, String label) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final session = _IcomSession._(socket, address, port, label);
    socket.listen(session._onEvent);
    // From the local PORT alone, little-endian in the top half — a capture
    // settled this; polo derived it from the IP and got intermittency.
    session.localSid =
        (((socket.port & 0xFF) << 24) | (((socket.port >> 8) & 0xFF) << 16)) & 0xFFFFFFFF;

    // Everything from here can throw on a timeout, and both failures leave
    // something behind if we simply propagate. The socket leaks — one per
    // failed Connect, and a refused reconnect is exactly when someone clicks
    // repeatedly. Worse, a pkt4 that arrives means the radio HAS created a
    // session for us, so walking away without a disconnect manufactures the
    // very "radio is still holding a previous session" state that this
    // transport spent a long time being blamed for.
    try {
      session._send(buildPkt3(session.localSid, 0));
      final pkt4 = await session._expect(
          'pkt4', (b) => b.length == 16 && icomPrefixIs(b, [0x10, 0, 0, 0, 0x04, 0, 0, 0]));
      session.remoteSid = readBe32(pkt4, 8);

      session._send(buildPkt6(session.localSid, session.remoteSid));
      await session._expect('pkt6 answer',
          (b) => b.length == 16 && icomPrefixIs(b, [0x10, 0, 0, 0, 0x06, 0, 0x01, 0]));
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
      // sendTracked, not _send. Idles consume sequence numbers either way, but
      // _send never recorded them — and after the first minute idles are ~100%
      // of what the control session emits (sendTracked ran four times during
      // the handshake and then never again). So when the radio asked us to
      // resend, we almost always could not, and answered with nothing.
      //
      // The seq argument is 0 because sendTracked stamps the real one; passing
      // _seq++ here would burn two numbers per idle.
      if (!_closed) sendTracked(buildIdle(localSid, remoteSid, 0));
    });
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_closed) return;
      if (_pingsUnanswered >= _maxPingsUnanswered) {
        final lost = onLost;
        onLost = null;
        lost?.call();
        return;
      }
      _pingsUnanswered++;
      final seq = _pingSeq++;
      _send(buildPing(localSid, remoteSid, seq, [seq & 0xFF, 0, 0, 0]));
    });
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
    // ...or a RANGE, which we used to ignore entirely. The 0x18 form carries
    // (start, end) pairs as 4 bytes each from offset 16, little-endian and
    // inclusive. A radio that lost a burst asks this way, so ignoring it meant
    // the one request that matters after a bad moment on the link went
    // unanswered.
    if (bytes.length >= 20 && icomPrefixIs(bytes, [0x18, 0, 0, 0, 0x01, 0])) {
      // Bounded in ONE place, by total rather than per pair — see
      // icomRetransmitRange for why the per-pair form was not a bound at all.
      for (final seq in icomRetransmitRange(bytes, limit: _sentBufferSize)) {
        final packet = _sent[seq];
        if (packet != null) _send(packet);
      }
      return;
    }
    // The radio telling us the session is over. A STANDING branch, not an
    // _expect: every listener installed during the handshake removes itself on
    // first match, so once connect() returns nothing on the control session
    // consumes an 0x50 at all and these notices were simply dropped.
    //
    // Losing them was expensive. `onLost` cannot cover it — it is reset by ANY
    // inbound datagram (see the top of this method) and the radio keeps
    // pinging us at ~100ms — so the only thing that eventually noticed was the
    // 30s stale flag: half a minute of a connected row showing a frozen
    // frequency, and no reason to give the operator. The bytes were already
    // decodable by readStreamAnswer; nobody was listening to them.
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
    // The key and the wire value come from one function, deliberately: they
    // used to be computed separately and drifted apart past 65535, which
    // silently killed every retransmit answer about 1h49m into a session.
    final (:key, :packet) = icomStampSequence(bytes, _seq++);
    _sent[key] = packet;
    if (_sent.length > _sentBufferSize) _sent.remove(_sent.keys.first);
    _send(packet);
  }

  void Function() onMessage(void Function(List<int>) callback) {
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  Future<List<int>> _expect(String what, bool Function(List<int>) matches, {Duration? timeout}) {
    final completer = Completer<List<int>>();
    late void Function() stop;
    final timer = Timer(timeout ?? _handshakeTimeout, () {
      stop();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('the radio did not answer: $what'));
      }
    });
    stop = onMessage((bytes) {
      if (!matches(bytes)) return;
      timer.cancel();
      stop();
      if (!completer.isCompleted) completer.complete(bytes);
    });
    return completer.future;
  }

  List<int>? _authId;

  Future<List<int>> login({required String username, required String password}) async {
    final start = [Random().nextInt(256), Random().nextInt(256)];
    sendTracked(buildLogin(
      local: localSid,
      remote: remoteSid,
      innerSeq: _innerSeq++,
      authStartId: start,
      username: username,
      password: password,
    ));
    final List<int> answer;
    try {
      // Six bytes, NOT eight. Bytes 6..7 are the sender's outer sequence
      // number, and on a radio->client packet that is the RADIO's monotonic
      // counter — not a constant. We used to require 0x0001 there, which held
      // only while the radio answered the login before its first idle. Every
      // login answer in the reference capture arrives as 0x0002, because the
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
      // Named, not inline, so a test can exercise THIS predicate rather than a
      // copy of it — an inline lambda here produced a regression test that
      // passed against the very bug it was written to catch.
      answer = await _expect('login answer', isLoginAnswer);
    } on TimeoutException {
      throw const IcomLoginTimeout();
    }
    if (icomPrefixIs(answer.sublist(48), [0xff, 0xff, 0xff, 0xfe])) {
      throw const IcomLoginRejected();
    }
    final authId = answer.sublist(26, 32);
    _authId = authId;

    sendTracked(buildAuth(
        local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x02, authId: authId));

    // Started HERE, not in _startKeepalives, because only a session that has
    // logged in has anything to re-authenticate. _startKeepalives runs for the
    // serial session too, where this timer could only ever no-op against a
    // null authId — a periodic timer whose correctness depended on a null
    // check in another method. See [_reauthInterval] for why it exists.
    _reauthTimer = Timer.periodic(_reauthInterval, (_) {
      if (_closed) return;
      sendTracked(buildAuth(
          local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x05, authId: authId));
    });
    return authId;
  }

  /// The 16-byte token from the radio's unsolicited 0xa8, at offset 66.
  Future<List<int>> awaitStreamToken() async {
    List<int>? token;
    final stop = onMessage((b) {
      if (b.length == 168 && icomPrefixIs(b, [0xa8, 0, 0, 0, 0, 0])) token = b.sublist(66, 82);
    });
    sendTracked(buildAuth(
        local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x05, authId: _authId!));

    final deadline = DateTime.now().add(_handshakeTimeout);
    while (token == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    stop();
    if (token == null) throw TimeoutException('the radio never sent its stream token');
    return token!;
  }

  Future<void> requestStreams({
    required List<int> authId,
    required List<int> token,
    required String username,
    required int serialPort,
    required int audioPort,
  }) async {
    sendTracked(buildRequestStreams(
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
    ));

    // The answer is an 0x50, not the 0x90 the radio also sends unprompted.
    final answer = await _expect('stream answer',
        (b) => b.length == 80 && icomPrefixIs(b, [0x50, 0, 0, 0, 0, 0]) && b[20] == 0x02);

    // A POSITIVE test. Two previous versions of this guard hunted for 0xffff
    // — first at offsets 56..57, then at the port echo at 66/70 — and treated
    // "not found" as success. Both were wrong the same way: the 0xffff
    // encoding has never been observed from a radio, while an AUTH FAILURE
    // carries zeros at 66..71 and so passed straight through. We would then
    // send the serial-open into a stream the radio never opened and give the
    // operator a connected row that never reads.
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
  /// knowing how to match it is what lets this send **once and confirm**.
  /// This previously fired three times and never looked at the answer,
  /// because at the time we had no idea what the answer looked like.
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
    sendTracked(buildAuth(
        local: localSid, remote: remoteSid, innerSeq: _innerSeq++, magic: 0x01, authId: authId));
    try {
      await ack;
    } on TimeoutException {
      // Worth saying out loud: this is the state in which the next connect
      // is likely to be refused, and it is otherwise invisible.
      debugPrint('[cat] icom: no logout acknowledgement — the radio may still hold the login');
    }
  }

  Future<void> close({bool serialStream = false, int? serialCloseInnerSeq}) async {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    _pingTimer?.cancel();
    _reauthTimer?.cancel();
    if (serialStream) {
      // sendTracked, not _send: it stamps the outer sequence number, which a
      // working client fills in here and we used to leave at zero.
      // The inner sequence CONTINUES the CI-V stream's counter, which is why
      // the caller passes it in. This used to use the session's own _innerSeq,
      // which nothing else on the serial session advances — so the close went
      // out carrying a number the radio processed long ago. If it dedupes on
      // that counter (the only reason the counter exists) the close is dropped
      // as a stale duplicate and the stream stays registered on the radio.
      // The reference client's close continues the CI-V numbering.
      sendTracked(buildSerialOpen(localSid, remoteSid, serialCloseInnerSeq ?? _innerSeq++, magic: 0x00));
    }
    // Once. A working client sends exactly one disconnect per channel and the
    // radio releases the session; the previous three-with-delays spread this
    // teardown over ~300ms per channel, and datagrams two and three arrive
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

  _IcomConnection({
    required this.control,
    required this.serial,
    required this.audio,
    required this.authId,
  }) {
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

  /// Order matters, and it is the order a working client uses: log out on
  /// the control session, then tear the streams down.
  ///
  /// Each step guarded independently. A throw part-way used to skip the
  /// rest — leaving the control socket open and, worse, the radio still
  /// holding the login, which is precisely what makes the NEXT connect fail
  /// (see this file's KNOWN LIMITATION).
  Future<void> _shutdown() async {
    Future<void> step(String what, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('[cat] icom teardown ($what): $e');
      }
    }

    // Order matters, and this is the reverse of what it used to be. The login
    // owns the streams, so the streams go down first and the login last.
    // A capture of a working client tears down audio, then serial, then
    // control — logout and disconnect back to back — inside a single
    // millisecond, and its next connect succeeds two seconds later. We used
    // to release the login *first* and then spend the better part of a second
    // closing streams the radio no longer had a logged-in owner for.
    await step('audio', () async => audio.close());
    await step('serial', () => serial.close(serialStream: true, serialCloseInnerSeq: _civSeq++));
    await step('logout', control.logout);
    await step('control', control.close);
  }
}
