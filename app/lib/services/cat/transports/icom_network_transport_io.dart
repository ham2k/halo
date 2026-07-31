// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The IC-705 over WiFi. Two UDP sessions — control (login, auth, stream
// request) and serial (CI-V) — plus an audio socket that is bound and never
// read, because the stream request must name a real port.
//
// Verified against a real IC-705: a complete CI-V exchange in ~290 ms, and a
// held connection answering 30 of 30 polls over a minute. See
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

const _handshakeTimeout = Duration(seconds: 3);

/// Generous next to the 71ms the radio actually took to acknowledge a logout
/// on a packet capture, but this is on the disconnect path: waiting a moment
/// costs the user a spinner, and giving up early costs them the next connect.
const _logoutAckTimeout = Duration(milliseconds: 600);

/// kappanhang's cadences. app-polo ran neither, which is why its sessions
/// died; ours stay up indefinitely.
const _idleInterval = Duration(milliseconds: 100);
const _pingInterval = Duration(seconds: 3);

class IcomNetworkTransport implements EquipmentTransport {
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
      if (!_closed) _send(buildIdle(localSid, remoteSid, _seq++));
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
    final bytes = datagram.data.toList();

    // Anything at all proves the radio is still there.
    _pingsUnanswered = 0;


    // The radio pings us; not answering gets the session dropped.
    if (bytes.length == 21 && bytes[4] == 0x07 && bytes[16] == 0x00) {
      final seq = bytes[6] | (bytes[7] << 8);
      _send(buildPingReply(localSid, remoteSid, seq, bytes.sublist(17, 21)));
      return;
    }
    // And asks for packets it missed.
    if (bytes.length >= 16 && icomPrefixIs(bytes, [0x10, 0, 0, 0, 0x01, 0])) {
      final packet = _sent[bytes[6] | (bytes[7] << 8)];
      if (packet != null) _send(packet);
      return;
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
    final seq = _seq++;
    final stamped = [...bytes];
    stamped[6] = seq & 0xFF;
    stamped[7] = (seq >> 8) & 0xFF;
    _sent[seq] = stamped;
    if (_sent.length > 32) _sent.remove(_sent.keys.first);
    _send(stamped);
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

    // The answer is an 0x50, not the 0x90 the radio also sends. An accepted
    // one echoes the radio's ports at offset 56; a rejection carries 0xffff.
    final answer = await _expect('stream answer',
        (b) => b.length == 80 && icomPrefixIs(b, [0x50, 0, 0, 0, 0, 0]) && b[20] == 0x02);
    // Offsets 66 and 70, NOT 56. The 0x50 answer echoes the two stream ports
    // there — in an accepted answer they read 0xc352 (50002, serial) and
    // 0xc353 (50003, audio), while offsets 56..57 are constant zero. So the
    // guard we had could never fire, and a refused stream request sailed
    // through as success: we would send the serial-open into a stream the
    // radio never opened, and the operator got a connected row that never
    // produces a reading.
    //
    // The 0xffff refusal encoding itself is inherited from the bench work
    // (see icom_network_protocol.dart on the audio fields) and has NOT been
    // observed against a radio here — no refusal was ever captured. What IS
    // confirmed from the capture is where the fields live, which is the part
    // that was wrong.
    if (isStreamRefused(answer)) {
      throw StateError('the radio refused to open its serial stream');
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

  Future<void> close({bool serialStream = false}) async {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    _pingTimer?.cancel();
    if (serialStream) {
      // sendTracked, not _send: it stamps the outer sequence number, which a
      // working client fills in here and we used to leave at zero.
      sendTracked(buildSerialOpen(localSid, remoteSid, _innerSeq++, magic: 0x00));
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
    await step('serial', () => serial.close(serialStream: true));
    await step('logout', control.logout);
    await step('control', control.close);
  }
}
