// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../drivers/k4_remote_codec.dart';
import '../transport.dart';

class K4AudioNotSent implements Exception {
  final String why;

  const K4AudioNotSent(this.why);

  @override
  String toString() => 'K4AudioNotSent: $why';
}

/// Multiplexes CAT and spectrum over an already authenticated TLS stream,
/// and carries the voice keyer's transmit audio the other way. Every audio
/// packet keys the K4: [sendAudio] is for a message playing, nothing else.
class K4RemoteConnection implements EquipmentConnection {
  final EquipmentConnection _secure;
  final _decoder = K4RemoteDecoder();
  late final _data = StreamController<Uint8List>(
    sync: true,
    onListen: _updateBackpressure,
    onPause: _updateBackpressure,
    onResume: _updateBackpressure,
    // CatService cancels its reader before session teardown sends RX. Only
    // explicit connection.close may close the underlying TLS connection.
    onCancel: _updateBackpressure,
  );
  final _pan = StreamController<K4RemotePanPacket>.broadcast(sync: true);
  final _closed = Completer<void>();
  final _closeDone = Completer<void>();
  StreamSubscription<Uint8List>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  bool _paused = false;

  K4RemoteConnection(this._secure) {
    _subscription = _secure.data.listen(_receive, onDone: close, onError: (Object _, StackTrace _) => close());
    _updateBackpressure();
    unawaited(_secure.closed.then((_) => close(), onError: (Object _, StackTrace _) => close()));
    _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) => send(ascii.encode('PING;')));
    _armWatchdog();
  }

  Stream<K4RemotePanPacket> get pan => _pan.stream;

  @override
  Stream<Uint8List> get data => _data.stream;

  @override
  Future<void> get closed => _closed.future;

  // A paused CAT consumer pauses the shared source, propagating all the way
  // to TCP instead of buffering an unbounded stream in this adapter.
  void _updateBackpressure() {
    if (_closed.isCompleted || _subscription == null) return;
    final pause = !_data.hasListener || _data.isPaused;
    if (pause == _paused) return;
    _paused = pause;
    pause ? _subscription!.pause() : _subscription!.resume();
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 10), close);
  }

  void _receive(Uint8List bytes) {
    if (_closed.isCompleted) return;
    for (final packet in _decoder.add(bytes)) {
      if (_closed.isCompleted) return;
      _armWatchdog();
      switch (packet) {
        case K4RemoteCatPacket():
          _data.add(packet.data);
        case K4RemotePanPacket():
          _pan.add(packet);
      }
    }
  }

  @override
  void send(List<int> bytes) {
    if (_closed.isCompleted) return;
    try {
      _secure.send(encodeK4RemoteCat(bytes));
    } catch (_) {
      unawaited(close());
    }
  }

  /// An audio envelope from [encodeK4RemoteAudio]. Throws [K4AudioNotSent]
  /// when the link will not take it, so the message stops rather than
  /// playing on into a closed connection.
  void sendAudio(Uint8List envelope) {
    if (_closed.isCompleted) throw const K4AudioNotSent('the connection is closed');
    try {
      _secure.send(envelope);
    } catch (e) {
      unawaited(close());
      throw K4AudioNotSent('$e');
    }
  }

  @override
  Future<void> close() async {
    if (_closed.isCompleted) return _closeDone.future;
    _closed.complete();
    _heartbeat?.cancel();
    _watchdog?.cancel();
    _decoder.reset();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    // A listener may disconnect from inside a synchronous CAT/PAN callback.
    // Finish that dispatch before delivering either stream's done event.
    scheduleMicrotask(() {
      unawaited(_data.close());
      unawaited(_pan.close());
    });
    try {
      await _secure.close();
    } finally {
      _closeDone.complete();
    }
  }
}
